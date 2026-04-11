-- Game/Combat.lua
-- 暗黑塔防游戏 - 战斗计算系统
-- v3: 链式攻击、光环系统、BOSS平衡、技能升级集成

local Config = require("Game.Config")
local State = require("Game.State")
local Enemy = require("Game.Enemy")
local HeroSkills = require("Game.HeroSkills")
local AudioManager = require("Game.AudioManager")

-- 音效节流：避免高频攻击时音效堆叠
local lastAttackSfxTime = 0
local lastHitSfxTime = 0
local SFX_ATTACK_INTERVAL = 0.15   -- 攻击音效最小间隔
local SFX_HIT_INTERVAL = 0.12      -- 命中音效最小间隔
local Tower = require("Game.Tower")
local LootDrop = require("Game.LootDrop")

local Combat = {}

--- 获取元素伤害的飘字颜色（弱点=元素色高亮，抗性=灰色，普通=塔色）
---@param heroElement string|nil
---@param elemMult number
---@param towerColor table
---@return table color
---@return string|nil suffix  弱点/抗性后缀
local function GetElementDmgColor(heroElement, elemMult, towerColor)
    if not heroElement or elemMult == 1.0 then
        return towerColor, nil
    end
    local elemDef = Config.ELEMENTS[heroElement]
    if elemMult > 1.05 then
        -- 弱点：元素色
        return elemDef and elemDef.color or towerColor, nil
    elseif elemMult < 0.95 then
        -- 抗性：灰暗色
        return { 140, 140, 140 }, nil
    end
    return towerColor, nil
end

--- 计算最终伤害（护甲系数 × 暴击倍率）
--- 集成破甲叠加、光环暴击加成
---@param tower table
---@param enemy table
---@param damage number
---@return number finalDamage
---@return boolean isCrit
local function CalcFinalDamage(tower, enemy, damage)
    -- 敌方有效 DEF = baseDEF - 穿甲削减 - 破甲叠层 - 剧毒瘴气
    local enemyDEF = enemy.def or 0

    -- 英雄穿甲：按比例削减敌方 DEF（armorPen 0.30 = 削减30% DEF）
    local armorPen = tower.armorPen or 0
    if armorPen > 0 then
        enemyDEF = enemyDEF * (1 - armorPen)
    end

    -- 破甲叠层：每层削减固定比例 DEF
    if enemy.armorBreakStacks and enemy.armorBreakStacks > 0 and enemy.armorBreakValue then
        local breakPct = enemy.armorBreakStacks * enemy.armorBreakValue
        enemyDEF = enemyDEF * (1 - breakPct)
    end

    -- 剧毒瘴气：额外削减 DEF
    if enemy.armorReduceFromDot then
        enemyDEF = enemyDEF * (1 - enemy.armorReduceFromDot)
        enemy.armorReduceFromDot = nil  -- 单次使用
    end

    -- DEF 不低于 0
    enemyDEF = math.max(0, enemyDEF)

    -- 伤害公式: damage × ATK / (ATK + DEF)
    -- 当 DEF=0 时满伤，DEF=ATK 时半伤
    local atk = damage  -- damage 已经是有效攻击力
    local defReduction = atk / (atk + enemyDEF)

    -- 暴击判定（含光环加成）
    local isCrit = false
    local critMult = 1.0
    local critRate = HeroSkills.GetEffectiveCritRate(tower)
    if critRate > 0 and math.random() < critRate then
        isCrit = true
        critMult = Config.BASE_CRIT_MULT + (tower.critDmg or 0)
    end

    -- 元素抗性: finalDmg *= (1 - resistance)
    local elemMult = 1.0
    local heroElement = Config.HERO_ELEMENT[tower.typeDef.id]
    if heroElement and enemy.typeDef and enemy.typeDef.themeId then
        local resists = Config.THEME_ELEMENT_RESIST[enemy.typeDef.themeId]
        if resists and resists[heroElement] then
            elemMult = 1.0 - resists[heroElement]
        end
    end

    -- 伤害加成: 独立乘区 (1 + dmgBonus)
    local dmgBonusMult = 1.0 + (tower.dmgBonus or 0)

    -- 单元素伤害加成: 匹配英雄元素时，额外乘 (1 + bonus)
    local elemDmgMult = 1.0
    if heroElement and tower.elemDmgBonus then
        elemDmgMult = 1.0 + (tower.elemDmgBonus[heroElement] or 0)
    end

    return damage * defReduction * critMult * elemMult * dmgBonusMult * elemDmgMult, isCrit, heroElement, elemMult
end
Combat.CalcFinalDamage = CalcFinalDamage

--- 计算两点距离
local function Distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

--- 寻找塔攻击范围内最近的敌人
local function FindTarget(tower, towerX, towerY)
    -- 应用范围修正
    local effectiveRange = HeroSkills.ModifyRange(tower, tower.range)
    local bestDist = effectiveRange
    local bestEnemy = nil

    for _, e in ipairs(State.enemies) do
        if e.alive and not e.phaseActive then
            -- 眩晕/冰冻的敌人也可以被攻击
            local dist = Distance(towerX, towerY, e.x, e.y)
            -- 隐匿词缀
            if e.affixIds and e.affixIds["stealth"] then
                local stealthRange = 60
                for _, a in ipairs(e.affixes) do
                    if a.stealthRange then stealthRange = a.stealthRange end
                end
                if dist > stealthRange then
                    goto continue
                end
            end
            if dist < bestDist then
                bestDist = dist
                bestEnemy = e
            end
            ::continue::
        end
    end
    return bestEnemy
end

--- 寻找链式攻击的下一个目标
---@param source table  当前被击中的敌人
---@param hitSet table  已被击中的敌人id集合
---@param range number  链式搜索范围
---@return table|nil
local function FindChainTarget(source, hitSet, range)
    local bestDist = range
    local bestEnemy = nil
    for _, e in ipairs(State.enemies) do
        if e.alive and not hitSet[e.id] then
            local dist = Distance(source.x, source.y, e.x, e.y)
            if dist < bestDist then
                bestDist = dist
                bestEnemy = e
            end
        end
    end
    return bestEnemy
end

--- 塔发起攻击
local function TowerAttack(tower, towerX, towerY, target)
    -- 应用攻速加成
    local effectiveSpeed = HeroSkills.ModifyAttackSpeed(tower, tower.speed)
    tower.cooldown = effectiveSpeed
    tower.target = target

    -- 获取有效攻击力（含光环buff）
    local effectiveAtk = HeroSkills.GetEffectiveAttack(tower)

    -- 攻击动画（有精灵图的角色都播放）
    tower.attackAnimTimer = 0.3

    -- 播放攻击音效（节流）
    if State.time - lastAttackSfxTime >= SFX_ATTACK_INTERVAL then
        AudioManager.PlayAttack()
        lastAttackSfxTime = State.time
    end

    -- 创建弹道
    State.projectiles[#State.projectiles + 1] = {
        x = towerX,
        y = towerY,
        targetId = target.id,
        tx = target.x,
        ty = target.y,
        speed = 300,
        damage = effectiveAtk,
        tower = tower,
        life = 2.0,
        color = tower.typeDef.color,
        spriteSheet = tower.typeDef.icon or nil,
    }

    -- 连射技能: 概率额外发射
    if HeroSkills.ShouldMultiShot(tower) then
        State.projectiles[#State.projectiles + 1] = {
            x = towerX + 3,
            y = towerY + 3,
            targetId = target.id,
            tx = target.x,
            ty = target.y,
            speed = 280,
            damage = effectiveAtk,
            tower = tower,
            life = 2.0,
            color = tower.typeDef.color,
        }
    end
end

--- 处理链式攻击命中
---@param tower table
---@param firstTarget table
---@param damage number
local function HandleChainAttack(tower, firstTarget, damage)
    local typeDef = tower.typeDef
    local chainCount = typeDef.chainCount or 3
    local chainDecay = typeDef.chainDecay or 0.7

    local hitSet = { [firstTarget.id] = true }
    local currentTarget = firstTarget
    local currentDmg = damage

    for c = 2, chainCount do
        currentDmg = currentDmg * chainDecay
        local nextTarget = FindChainTarget(currentTarget, hitSet, 80)
        if not nextTarget then break end

        hitSet[nextTarget.id] = true
        local modDmg = HeroSkills.ModifyDamage(tower, nextTarget, currentDmg)
        local finalDmg, isCrit, heroElem, elemMult = CalcFinalDamage(tower, nextTarget, modDmg)
        local killed = Enemy.TakeDamage(nextTarget, finalDmg)

        -- 伤害飘字（元素着色）
        local elemColor = GetElementDmgColor(heroElem, elemMult, tower.typeDef.color)
        local chainDmgText = tostring(math.floor(finalDmg))
        if isCrit then
            State.floatingTexts[#State.floatingTexts + 1] = {
                text = chainDmgText .. "!",
                x = nextTarget.x + (math.random() - 0.5) * 12,
                y = nextTarget.y - (nextTarget.typeDef.size or 8) - 10,
                life = 0.8,
                color = { 255, 60, 60, 255 },
                fontSize = 16,
                isCrit = true,
            }
            HeroSkills.CheckCritSplash(tower, nextTarget, finalDmg)
        else
            State.floatingTexts[#State.floatingTexts + 1] = {
                text = chainDmgText,
                x = nextTarget.x + (math.random() - 0.5) * 14,
                y = nextTarget.y - (nextTarget.typeDef.size or 8) - 6,
                life = 0.6,
                color = elemColor,
                fontSize = 11,
            }
        end

        HeroSkills.OnHit(tower, nextTarget, killed)

        -- 链式特殊效果
        if typeDef.special == "slow" and nextTarget.alive then
            local slowRate = typeDef.slowRate or 0.25
            slowRate = HeroSkills.ModifySlowRate(tower, slowRate, nextTarget)
            Enemy.ApplySlow(nextTarget, 2.0, slowRate)
        end

        -- 链闪电粒子
        State.particles[#State.particles + 1] = {
            x = (currentTarget.x + nextTarget.x) / 2,
            y = (currentTarget.y + nextTarget.y) / 2,
            vx = 0, vy = -20,
            life = 0.3, maxLife = 0.3,
            color = tower.typeDef.color,
            size = 3,
        }

        currentTarget = nextTarget
    end
end

--- 弹道命中处理
local function OnProjectileHit(proj)
    local tower = proj.tower
    local typeDef = tower.typeDef

    -- 查找目标
    local target = nil
    for _, e in ipairs(State.enemies) do
        if e.id == proj.targetId and e.alive then
            target = e
            break
        end
    end

    if not target then return end

    -- 播放命中音效（节流）
    if State.time - lastHitSfxTime >= SFX_HIT_INTERVAL then
        AudioManager.PlayEnemyHit()
        lastHitSfxTime = State.time
    end

    -- === 链式攻击 ===
    if typeDef.attackType == "chain" then
        local damage = HeroSkills.ModifyDamage(tower, target, proj.damage)
        local finalDmg, isCrit, heroElem, elemMult = CalcFinalDamage(tower, target, damage)
        local killed = Enemy.TakeDamage(target, finalDmg)

        -- 伤害飘字（元素着色）
        local elemColor = GetElementDmgColor(heroElem, elemMult, proj.color)
        local dmgText = tostring(math.floor(finalDmg))
        if isCrit then
            State.floatingTexts[#State.floatingTexts + 1] = {
                text = dmgText .. "!",
                x = target.x + (math.random() - 0.5) * 12,
                y = target.y - (target.typeDef.size or 8) - 10,
                life = 0.8,
                color = { 255, 60, 60, 255 },
                fontSize = 16,
                isCrit = true,
            }
            HeroSkills.CheckCritSplash(tower, target, finalDmg)
        else
            State.floatingTexts[#State.floatingTexts + 1] = {
                text = dmgText,
                x = target.x + (math.random() - 0.5) * 14,
                y = target.y - (target.typeDef.size or 8) - 6,
                life = 0.6,
                color = elemColor,
                fontSize = 11,
            }
        end
        HeroSkills.OnHit(tower, target, killed)

        -- 链式弹跳
        HandleChainAttack(tower, target, proj.damage)

    elseif typeDef.attackType == "aoe" then
        -- === AOE 伤害 ===
        for _, e in ipairs(State.enemies) do
            if e.alive then
                local dist = Distance(proj.tx, proj.ty, e.x, e.y)
                if dist < 50 then
                    local dmgMult = 1.0 - (dist / 50) * 0.5
                    local damage = HeroSkills.ModifyDamage(tower, e, proj.damage * dmgMult)
                    local finalDmg, isCrit, heroElem, elemMult = CalcFinalDamage(tower, e, damage)
                    local killed = Enemy.TakeDamage(e, finalDmg)

                    -- 伤害飘字（元素着色）
                    local elemColor = GetElementDmgColor(heroElem, elemMult, proj.color)
                    local dmgText = tostring(math.floor(finalDmg))
                    if isCrit then
                        State.floatingTexts[#State.floatingTexts + 1] = {
                            text = dmgText .. "!",
                            x = e.x + (math.random() - 0.5) * 12,
                            y = e.y - (e.typeDef.size or 8) - 10,
                            life = 0.8,
                            color = { 255, 60, 60, 255 },
                            fontSize = 16,
                            isCrit = true,
                        }
                        HeroSkills.CheckCritSplash(tower, e, finalDmg)
                    else
                        State.floatingTexts[#State.floatingTexts + 1] = {
                            text = dmgText,
                            x = e.x + (math.random() - 0.5) * 14,
                            y = e.y - (e.typeDef.size or 8) - 6,
                            life = 0.6,
                            color = elemColor,
                            fontSize = 11,
                        }
                    end
                    HeroSkills.OnHit(tower, e, killed)
                end
            end
        end
    else
        -- === 单体伤害 ===
        local damage = HeroSkills.ModifyDamage(tower, target, proj.damage)
        local finalDmg, isCrit, heroElem, elemMult = CalcFinalDamage(tower, target, damage)
        local killed = Enemy.TakeDamage(target, finalDmg)

        -- 伤害飘字（元素着色）
        local elemColor = GetElementDmgColor(heroElem, elemMult, proj.color)
        local dmgText = tostring(math.floor(finalDmg))
        if isCrit then
            State.floatingTexts[#State.floatingTexts + 1] = {
                text = dmgText .. "!",
                x = target.x + (math.random() - 0.5) * 12,
                y = target.y - (target.typeDef.size or 8) - 10,
                life = 0.8,
                color = { 255, 60, 60, 255 },
                fontSize = 16,
                isCrit = true,
            }
            HeroSkills.CheckCritSplash(tower, target, finalDmg)
        else
            State.floatingTexts[#State.floatingTexts + 1] = {
                text = dmgText,
                x = target.x + (math.random() - 0.5) * 14,
                y = target.y - (target.typeDef.size or 8) - 6,
                life = 0.6,
                color = elemColor,
                fontSize = 11,
            }
        end
        HeroSkills.OnHit(tower, target, killed)
    end

    -- === 特殊效果 ===
    if typeDef.special == "slow" and target.alive then
        local slowRate = typeDef.slowRate or 0.3
        slowRate = HeroSkills.ModifySlowRate(tower, slowRate, target)
        local slowDur = 2.0
        if target.isBoss then
            -- BOSS减速效率已在ModifySlowRate处理
        end
        Enemy.ApplySlow(target, slowDur, slowRate)
        -- 灵魂锁链扩散
        HeroSkills.HandleSlowSpread(tower, target, slowDur, slowRate)
    elseif typeDef.special == "dot" and target.alive then
        local dotDmg = typeDef.dotDamage or 5
        dotDmg = HeroSkills.ModifyDotDamage(tower, dotDmg, target)
        Enemy.ApplyDOT(target, dotDmg, typeDef.dotDuration or 2.0)
    elseif typeDef.special == "amp_damage" and target.alive then
        -- 增伤标记（首次施加时飘字）
        if not target.ampDamageTimer or target.ampDamageTimer <= 0 then
            State.floatingTexts[#State.floatingTexts + 1] = {
                text = "易伤",
                x = target.x + (math.random() - 0.5) * 10,
                y = target.y - (target.typeDef.size or 8) - 16,
                life = 0.5,
                color = { 200, 100, 255, 255 },
                fontSize = 11,
            }
        end
        target.ampDamage = typeDef.ampRate or 0.08
        target.ampDamageTimer = typeDef.ampDuration or 3.0
    elseif typeDef.special == "armor_break" and target.alive then
        -- 破甲（首次施加或叠层时飘字）
        local oldStacks = target.armorBreakStacks or 0
        target.armorBreakStacks = math.min(oldStacks + 1, 3)
        target.armorBreakValue = typeDef.armorBreak or 0.08
        target.armorBreakTimer = typeDef.armorBreakDuration or 5.0
        if oldStacks == 0 then
            State.floatingTexts[#State.floatingTexts + 1] = {
                text = "破甲",
                x = target.x + (math.random() - 0.5) * 10,
                y = target.y - (target.typeDef.size or 8) - 16,
                life = 0.5,
                color = { 255, 180, 60, 255 },
                fontSize = 11,
            }
        end
    elseif typeDef.special == "aoe_control" and target.alive then
        -- AOE控制（眩晕）
        if typeDef.stunChance and math.random() < typeDef.stunChance then
            HeroSkills.ApplyStun(target, typeDef.stunDuration or 1.0)
        end
        if typeDef.slowRate then
            local slowRate = typeDef.slowRate
            slowRate = HeroSkills.ModifySlowRate(tower, slowRate, target)
            Enemy.ApplySlow(target, 2.0, slowRate)
        end
    elseif typeDef.special == "boss_killer" and target.alive then
        -- BOSS额外伤害已在 ModifyDamage 中通过 hunt_instinct / void_tear 处理
    end

    -- 命中粒子
    for i = 1, 4 do
        local angle = math.random() * math.pi * 2
        local spd = 20 + math.random() * 30
        State.particles[#State.particles + 1] = {
            x = proj.tx,
            y = proj.ty,
            vx = math.cos(angle) * spd,
            vy = math.sin(angle) * spd,
            life = 0.3 + math.random() * 0.3,
            maxLife = 0.6,
            color = proj.color,
            size = 2 + math.random() * 2,
        }
    end
end

--- 重置音效节流计时器（过关/重开时调用）
function Combat.Reset()
    lastAttackSfxTime = 0
    lastHitSfxTime = 0
end

--- 更新战斗系统
function Combat.Update(dt, gridOffsetX, gridOffsetY)
    local Grid = require("Game.Grid")

    -- 更新光环系统
    HeroSkills.UpdateAuras(State.towers, gridOffsetX, gridOffsetY)

    -- 更新全局buff
    HeroSkills.UpdateGlobalBuffs(dt)

    -- 更新诅咒标记DOT
    HeroSkills.UpdateCurseDOT(dt)

    -- 更新塔攻击 + 朝向
    for _, tower in ipairs(State.towers) do
        local tx, ty = Grid.CellToScreen(tower.col, tower.row, gridOffsetX, gridOffsetY)
        local target = FindTarget(tower, tx, ty)

        -- 更新朝向
        if target then
            tower.faceLeft = target.x < tx
        end

        if tower.cooldown <= 0 and target then
            TowerAttack(tower, tx, ty, target)
        end
    end

    -- 更新弹道
    for i = #State.projectiles, 1, -1 do
        local p = State.projectiles[i]
        p.life = p.life - dt

        if not p.isEnemyProjectile then
            -- === 塔弹道 ===
            local target = nil
            for _, e in ipairs(State.enemies) do
                if e.id == p.targetId and e.alive then
                    target = e
                    break
                end
            end

            if target then
                p.tx = target.x
                p.ty = target.y
            end

            local dx = p.tx - p.x
            local dy = p.ty - p.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < 8 or p.life <= 0 then
                OnProjectileHit(p)
                table.remove(State.projectiles, i)
            else
                local move = p.speed * dt
                p.x = p.x + dx / dist * move
                p.y = p.y + dy / dist * move
            end
        end
    end

    -- 更新粒子
    for i = #State.particles, 1, -1 do
        local pt = State.particles[i]
        pt.life = pt.life - dt
        pt.x = pt.x + pt.vx * dt
        pt.y = pt.y + pt.vy * dt
        pt.vy = pt.vy + 40 * dt
        if pt.life <= 0 then
            table.remove(State.particles, i)
        end
    end

    -- 更新飘字
    for i = #State.floatingTexts, 1, -1 do
        local ft = State.floatingTexts[i]
        ft.life = ft.life - dt
        ft.y = ft.y - 30 * dt
        if ft.life <= 0 then
            table.remove(State.floatingTexts, i)
        end
    end

    -- 更新掉落物（飞行动画 + 到达后加货币）
    LootDrop.Update(dt)

    -- 更新技能闪光
    if State.skillFlash then
        State.skillFlash.timer = State.skillFlash.timer - dt
        if State.skillFlash.timer <= 0 then
            State.skillFlash = nil
        end
    end

    -- 更新敌人buff计时器
    for _, e in ipairs(State.enemies) do
        -- 增伤标记衰减
        if e.ampDamageTimer and e.ampDamageTimer > 0 then
            e.ampDamageTimer = e.ampDamageTimer - dt
            if e.ampDamageTimer <= 0 then
                e.ampDamage = nil
                e.ampDamageTimer = nil
            end
        end
        -- 破甲叠层衰减
        if e.armorBreakTimer and e.armorBreakTimer > 0 then
            e.armorBreakTimer = e.armorBreakTimer - dt
            if e.armorBreakTimer <= 0 then
                e.armorBreakStacks = nil
                e.armorBreakValue = nil
                e.armorBreakTimer = nil
            end
        end
        -- 眩晕衰减
        if e.stunTimer and e.stunTimer > 0 then
            e.stunTimer = e.stunTimer - dt
        end
        -- 冰冻衰减
        if e.frozenTimer and e.frozenTimer > 0 then
            e.frozenTimer = e.frozenTimer - dt
            if e.frozenTimer <= 0 then
                e.frozen = nil
            end
        end
    end
end

return Combat
