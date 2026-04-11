-- Game/HeroSkills.lua
-- 英雄技能效果系统
-- 被动技能随升星升级，主动技能随进阶升级
-- 技能倍率 × 觉醒倍率 乘算

local Config = require("Game.Config")
local State = require("Game.State")
local HeroData = require("Game.HeroData")

local HeroSkills = {}

-- ============================================================================
-- 技能等级计算
-- ============================================================================

--- 根据英雄星级计算被动技能等级
--- Lv1 = 基础; 达到 PASSIVE_UPGRADE_STARS 节点后 +1 级
---@param heroStar number  0-30
---@return number  1-7
function HeroSkills.GetPassiveSkillLevel(heroStar)
    local level = 1
    for _, threshold in ipairs(Config.PASSIVE_UPGRADE_STARS) do
        if heroStar >= threshold then
            level = level + 1
        end
    end
    return level
end

--- 根据进阶等级计算主动技能等级
--- Lv1 = 基础; 达到 ACTIVE_UPGRADE_GATES 节点后 +1 级
---@param advanceLevel number  0-20
---@return number  1-5
function HeroSkills.GetActiveSkillLevel(advanceLevel)
    local level = 1
    for _, threshold in ipairs(Config.ACTIVE_UPGRADE_GATES) do
        if advanceLevel >= threshold then
            level = level + 1
        end
    end
    return level
end

--- 计算被动技能等级带来的累积倍率
--- Lv1=1.0, Lv2=1.3, Lv3=1.69, ... Lv7≈9.88
---@param passiveLevel number  1-7
---@return number
function HeroSkills.GetPassiveMultiplier(passiveLevel)
    local mult = 1.0
    for i = 1, passiveLevel - 1 do
        mult = mult * (Config.PASSIVE_UPGRADE_MULTS[i] or 1.0)
    end
    return mult
end

--- 计算主动技能伤害累积倍率
---@param activeLevel number  1-5
---@return number
function HeroSkills.GetActiveMultiplier(activeLevel)
    local mult = 1.0
    for i = 1, activeLevel - 1 do
        mult = mult * (Config.ACTIVE_UPGRADE_MULTS[i] or 1.0)
    end
    return mult
end

--- 计算主动技能CD累积倍率
---@param activeLevel number  1-5
---@return number cdMult
function HeroSkills.GetActiveCDMultiplier(activeLevel)
    local mult = 1.0
    for i = 1, activeLevel - 1 do
        mult = mult * (Config.ACTIVE_UPGRADE_CD_MULTS[i] or 1.0)
    end
    return mult
end

-- ============================================================================
-- 工具函数
-- ============================================================================

--- 检查塔是否拥有指定技能
---@param tower table
---@param skillId string
---@return table|nil  skill definition if has it
function HeroSkills.HasSkill(tower, skillId)
    if not tower.skills then return nil end
    for _, skill in ipairs(tower.skills) do
        if skill.id == skillId then
            return skill
        end
    end
    return nil
end

--- 对技能定义做一份浅拷贝
---@param skillDef table
---@return table
local function CloneSkill(skillDef)
    local copy = {}
    for k, v in pairs(skillDef) do
        copy[k] = v
    end
    return copy
end

--- 可被倍率缩放的数值型字段
local NUMERIC_KEYS = {
    "chance", "damagePct", "bonusDmg", "duration",
    "burnDuration", "bonusPerWave", "maxBonus", "slowPct",
    "newSlowRate", "dotMultiplier", "bossAtkPct", "chainRange",
    "curseDmgAtkPct", "killDmgBonus", "atkSpdBonus", "slowRate",
    "slowDuration", "dotAtkPct", "armorBreak", "fullStackBonus",
    "ampRate", "atkBuff", "spdBuff", "atkBuffPct", "burstMult",
    "rangeBonus", "hpPct", "critRate", "critDmg", "critRateBuff",
    "healReduction", "doubleDmgChance", "critSplashPct",
    "killAtkBonus", "globalAtkBuff", "cdResetAmount", "armorReduce",
    "spreadRatio", "bossExtraDmg",
}

--- 对技能应用倍率（仅数值型参数，概率上限保护）
---@param skill table  cloned skill definition
---@param mult number  multiplier
local function ApplySkillMult(skill, mult)
    if mult <= 1.0 then return end
    for _, key in ipairs(NUMERIC_KEYS) do
        if skill[key] then
            skill[key] = skill[key] * mult
        end
    end
    -- 概率上限保护
    if skill.chance then
        skill.chance = math.min(skill.chance, skill.maxChance or 0.80)
    end
    -- 主动技能CD缩短（interval 除以倍率）
    if skill.interval and mult > 1.0 then
        skill.interval = skill.interval / mult
    end
end

-- ============================================================================
-- 初始化塔技能
-- ============================================================================

--- 初始化塔的技能列表（召唤/合成时调用）
--- 最终数值 = 基础 × 技能等级倍率 × 觉醒倍率
---@param tower table
function HeroSkills.InitTowerSkills(tower)
    local heroId = tower.typeDef.id
    local baseSkills = HeroData.GetUnlockedSkills(heroId)

    -- 获取英雄养成数据
    local heroInfo = HeroData.Get(heroId)
    local heroStar = (heroInfo and heroInfo.star) or 0
    local advanceLevel = (heroInfo and heroInfo.advanceLevel) or 0
    local awaken = (heroInfo and heroInfo.awakening) or 0
    local awakenDefs = Config.HERO_AWAKENING[heroId]

    -- 计算技能等级
    local passiveLevel = HeroSkills.GetPassiveSkillLevel(heroStar)
    local activeLevel = HeroSkills.GetActiveSkillLevel(advanceLevel)
    local passiveMult = HeroSkills.GetPassiveMultiplier(passiveLevel)
    local activeDmgMult = HeroSkills.GetActiveMultiplier(activeLevel)
    local activeCdMult = HeroSkills.GetActiveCDMultiplier(activeLevel)

    tower.skills = {}
    tower.skillLevels = { passive = passiveLevel, active = activeLevel }

    for i, skillDef in ipairs(baseSkills) do
        local skill = CloneSkill(skillDef)

        -- 1) 技能等级倍率
        if skill.type == "passive" then
            ApplySkillMult(skill, passiveMult)
        elseif skill.type == "active" then
            ApplySkillMult(skill, activeDmgMult)
            -- 主动CD独立缩短
            if skill.interval then
                skill.interval = skill.interval * activeCdMult
            end
        end

        -- 2) 觉醒倍率（与技能等级乘算）
        if awaken > 0 and awakenDefs then
            for a = 1, math.min(awaken, #awakenDefs) do
                local node = awakenDefs[a]
                if node then
                    if node.skillIdx == i then
                        ApplySkillMult(skill, node.mult or 1.5)
                    end
                    if node.allMult and a <= awaken then
                        -- allMult 只在最后一个觉醒节点且已达到时应用
                        -- 检查这个节点是否是 allMult 节点
                        if not node.skillIdx then
                            ApplySkillMult(skill, node.allMult)
                        end
                    end
                end
            end
        end

        tower.skills[#tower.skills + 1] = skill
    end

    -- 初始化运行时状态
    tower.skillTimers = {}
    tower.skillStacks = {}  -- 用于叠加型技能
    for _, skill in ipairs(tower.skills) do
        if skill.type == "active" and skill.interval then
            tower.skillTimers[skill.id] = skill.interval
        end
    end

    -- 永恒魔君击杀加攻叠层
    tower.killAtkStacks = 0
    -- 灵魂收割击杀伤害叠层
    tower.soulReapStacks = 0
end

-- ============================================================================
-- 被动技能效果 — 伤害修正
-- ============================================================================

--- 修正攻击伤害（被动技能影响）
---@param tower table
---@param target table  enemy
---@param baseDamage number
---@return number  modified damage
function HeroSkills.ModifyDamage(tower, target, baseDamage)
    local damage = baseDamage

    -- 暗影穿透: 概率无视护盾
    local pierce = HeroSkills.HasSkill(tower, "shadow_pierce")
    if pierce and target.shield and target.shield > 0 then
        if math.random() < (pierce.chance or 0.15) then
            target.piercedThisHit = true
        end
    end

    -- 弱点标记 / 致命标记 / 神罚之光: 目标受伤加成
    if target.ampDamage and target.ampDamage > 0 then
        damage = damage * (1 + target.ampDamage)
    end

    -- 破甲叠加满层额外伤害
    if target.armorBreakStacks then
        local breakerSkill = HeroSkills.HasSkill(tower, "armor_stack")
        if breakerSkill and target.armorBreakStacks >= (breakerSkill.maxStacks or 3) then
            local bonus = HeroSkills.HasSkill(tower, "fatal_weakness")
            if bonus then
                damage = damage * (1 + (bonus.fullStackBonus or 0.20))
            end
        end
    end

    -- 猎杀本能 / 虚空撕裂: 对BOSS额外伤害
    local huntSkill = HeroSkills.HasSkill(tower, "hunt_instinct")
    if not huntSkill then huntSkill = HeroSkills.HasSkill(tower, "void_tear") end
    if huntSkill and target.isBoss then
        damage = damage * (1 + (huntSkill.bossExtraDmg or 0.50))
    end

    -- 灵魂收割: 击杀叠层加伤（攻击后清零）
    if tower.soulReapStacks and tower.soulReapStacks > 0 then
        local reap = HeroSkills.HasSkill(tower, "soul_reap")
        if reap then
            damage = damage * (1 + tower.soulReapStacks * (reap.killDmgBonus or 0.30))
            tower.soulReapStacks = 0  -- 攻击后清零
        end
    end

    -- 永恒之力: 击杀叠层攻击加成
    if tower.killAtkStacks and tower.killAtkStacks > 0 then
        local eternal = HeroSkills.HasSkill(tower, "eternal_power")
        if eternal then
            damage = damage * (1 + tower.killAtkStacks * (eternal.killAtkBonus or 0.01))
        end
    end

    -- 剧毒瘴气: DOT期间护甲抵抗降低（在 Combat 的 CalcFinalDamage 中处理更合适）
    -- 这里通过标记传递给 Combat
    local toxic = HeroSkills.HasSkill(tower, "toxic_miasma")
    if toxic and target.dotTimer and target.dotTimer > 0 then
        target.armorReduceFromDot = toxic.armorReduce or 0.05
    end

    -- 命运织者: 因果律 — 全体友方15%概率双倍伤害
    -- 通过全局 buff 检查
    if State.causalityActive then
        if math.random() < (State.causalityChance or 0.15) then
            damage = damage * 2
        end
    end

    return damage
end

-- ============================================================================
-- 被动技能效果 — 命中触发
-- ============================================================================

--- 攻击后触发效果
---@param tower table
---@param target table  enemy
---@param killed boolean  是否击杀
function HeroSkills.OnHit(tower, target, killed)
    -- 灵魂收割: 击杀叠层（下次攻击消耗）
    if killed then
        local reap = HeroSkills.HasSkill(tower, "soul_reap")
        if reap then
            tower.soulReapStacks = math.min(
                (tower.soulReapStacks or 0) + 1,
                reap.maxStacks or 3
            )
        end
    end

    -- 永恒之力: 击杀叠攻击
    if killed then
        local eternal = HeroSkills.HasSkill(tower, "eternal_power")
        if eternal then
            tower.killAtkStacks = math.min(
                (tower.killAtkStacks or 0) + 1,
                math.floor((eternal.maxBonus or 0.50) / (eternal.killAtkBonus or 0.01))
            )
        end
    end

    -- 君主意志: 击杀时概率重置主动技能CD
    if killed then
        local lordWill = HeroSkills.HasSkill(tower, "lord_will")
        if lordWill and math.random() < (lordWill.chance or 0.08) then
            if tower.skillTimers then
                for skillId, timer in pairs(tower.skillTimers) do
                    tower.skillTimers[skillId] = math.max(0, timer - (lordWill.cdResetAmount or 1.0))
                end
            end
        end
    end

    -- 致命标记 / 幽魂刺客: 标记目标增伤
    local markSkill = HeroSkills.HasSkill(tower, "lethal_mark")
    if not markSkill then markSkill = HeroSkills.HasSkill(tower, "weak_mark") end
    if markSkill and target.alive then
        target.ampDamage = markSkill.ampRate or markSkill.bonusDmg or 0.10
        target.ampDamageTimer = markSkill.duration or 3.0
    end

    -- 背刺: 对已标记目标概率双倍（在 ModifyDamage 阶段更好，但这里简化处理）
    -- 已通过 ampDamage 间接加伤

    -- 吸血本能: 概率减速
    local vampInst = HeroSkills.HasSkill(tower, "vampire_instinct")
    if vampInst and target.alive then
        if math.random() < (vampInst.chance or 0.10) then
            local Enemy = require("Game.Enemy")
            Enemy.ApplySlow(target, vampInst.slowDuration or 1.0, vampInst.slowRate or 0.10)
        end
    end

    -- 精准打击 / 破甲叠加: 护甲削减
    local armorBreak = HeroSkills.HasSkill(tower, "precise_strike")
    if armorBreak and target.alive then
        target.armorBreakStacks = (target.armorBreakStacks or 0) + 1
        local stackSkill = HeroSkills.HasSkill(tower, "armor_stack")
        local maxStacks = (stackSkill and stackSkill.maxStacks) or 1
        target.armorBreakStacks = math.min(target.armorBreakStacks, maxStacks)
        target.armorBreakValue = armorBreak.armorBreak or 0.12
        target.armorBreakTimer = armorBreak.armorBreakDuration or 5.0
    end

    -- 冰冻概率: 概率冰冻（BOSS免疫→降级减速）
    local freeze = HeroSkills.HasSkill(tower, "freeze_chance")
    if freeze and target.alive then
        if math.random() < (freeze.chance or 0.10) then
            local Enemy = require("Game.Enemy")
            if target.isBoss then
                if Config.BOSS_BALANCE.freezeImmune then
                    -- BOSS 免疫冰冻，降级为减速
                    Enemy.ApplySlow(target, freeze.freezeDuration or 1.5,
                        (freeze.bossFallbackSlow or 0.50) * (Config.BOSS_BALANCE.slowEfficiency or 0.50))
                end
            else
                -- 普通敌人：冰冻 = 100%减速
                Enemy.ApplySlow(target, freeze.freezeDuration or 1.5, 1.0)
                target.frozen = true
                target.frozenTimer = freeze.freezeDuration or 1.5
                State.floatingTexts[#State.floatingTexts + 1] = {
                    text = "冰冻",
                    x = target.x + (math.random() - 0.5) * 10,
                    y = target.y - (target.typeDef.size or 8) - 16,
                    life = 0.6,
                    color = { 100, 180, 255, 255 },
                    fontSize = 12,
                }
            end
        end
    end

    -- 终焉审判: HP<15% 处决（BOSS免疫→固定ATK伤害）
    local judgment = HeroSkills.HasSkill(tower, "final_judgment")
    if judgment and target.alive then
        local threshold = judgment.executeThreshold or 0.15
        if target.hp / target.maxHP < threshold then
            local Enemy = require("Game.Enemy")
            if target.isBoss then
                if Config.BOSS_BALANCE.executeImmune then
                    local baseDmg = tower.attack * (judgment.bossFixedAtkMult or 15)
                    local Combat = require("Game.Combat")
                    local finalDmg = Combat.CalcFinalDamage(tower, target, baseDmg)
                    Enemy.TakeDamage(target, finalDmg)
                end
            else
                -- 处决
                Enemy.TakeDamage(target, target.hp + 1)
            end
        end
    end

    -- 龙息灼烧: 链式附带DOT
    local dragonDot = HeroSkills.HasSkill(tower, "dragon_breath_dot")
    if dragonDot and target.alive then
        local dotDmg = tower.attack * (dragonDot.dotAtkPct or 0.10)
        local Enemy = require("Game.Enemy")
        Enemy.ApplyDOT(target, dotDmg, dragonDot.dotDuration or 3.0)
    end

    -- 感染扩散: DOT扩散给附近敌人（不二次扩散）
    local spread = HeroSkills.HasSkill(tower, "infection_spread")
    if spread and target.alive and target.dotTimer and target.dotTimer > 0 and not target.dotSpread then
        local Enemy = require("Game.Enemy")
        local spreadCount = 0
        for _, e in ipairs(State.enemies) do
            if e.alive and e ~= target and spreadCount < (spread.spreadMaxTargets or 2) then
                local dx = e.x - target.x
                local dy = e.y - target.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < (spread.spreadRange or 30) then
                    -- BOSS 的 DOT 不可扩散
                    if not (target.isBoss and Config.BOSS_BALANCE.dotSpreadImmune) then
                        local spreadDmg = (target.dotDamage or 0) * (spread.spreadRatio or 0.50)
                        Enemy.ApplyDOT(e, spreadDmg, target.dotTimer)
                        e.dotSpread = true  -- 标记不二次扩散
                        spreadCount = spreadCount + 1
                    end
                end
            end
        end
    end

    -- 火焰蔓延: DOT目标死亡传递剩余DOT
    if killed then
        local fireSpread = HeroSkills.HasSkill(tower, "fire_spread")
        if fireSpread and target.dotTimer and target.dotTimer > 0 then
            local Enemy = require("Game.Enemy")
            local bestDist = 60
            local bestEnemy = nil
            for _, e in ipairs(State.enemies) do
                if e.alive and e ~= target then
                    local dx = e.x - target.x
                    local dy = e.y - target.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist < bestDist then
                        bestDist = dist
                        bestEnemy = e
                    end
                end
            end
            if bestEnemy then
                -- BOSS 的 DOT 不可扩散
                if not (target.isBoss and Config.BOSS_BALANCE.dotSpreadImmune) then
                    Enemy.ApplyDOT(bestEnemy, target.dotDamage or 0, target.dotTimer)
                end
            end
        end
    end
end

-- ============================================================================
-- 被动技能效果 — 减速/DOT 修正
-- ============================================================================

--- 修正减速效果
---@param tower table
---@param baseSlowRate number
---@param target table|nil
---@return number
function HeroSkills.ModifySlowRate(tower, baseSlowRate, target)
    -- 深度冻结 / 极寒之触 / 沉重一击
    local deepFreeze = HeroSkills.HasSkill(tower, "deep_freeze")
    if deepFreeze then return deepFreeze.newSlowRate or 0.45 end

    local extremeCold = HeroSkills.HasSkill(tower, "extreme_cold")
    if extremeCold then return extremeCold.newSlowRate or 0.35 end

    local heavyStrike = HeroSkills.HasSkill(tower, "heavy_strike")
    if heavyStrike then return heavyStrike.newSlowRate or 0.30 end

    -- BOSS 减速效率衰减
    if target and target.isBoss then
        baseSlowRate = baseSlowRate * (Config.BOSS_BALANCE.slowEfficiency or 0.50)
    end

    return baseSlowRate
end

--- 修正DOT伤害
---@param tower table
---@param baseDotDmg number
---@param target table|nil  enemy target
---@return number
function HeroSkills.ModifyDotDamage(tower, baseDotDmg, target)
    -- 强化灼烧 / 烈焰喷息
    local enhanced = HeroSkills.HasSkill(tower, "enhanced_burn")
    if enhanced then
        baseDotDmg = baseDotDmg * (enhanced.dotMultiplier or 1.5)
    end
    local flameBreath = HeroSkills.HasSkill(tower, "flame_breath")
    if flameBreath then
        baseDotDmg = baseDotDmg * (flameBreath.dotMultiplier or 1.3)
    end

    -- 涅槃之炎: 对BOSS DOT改为ATK×bossAtkPct每秒
    local nirvana = HeroSkills.HasSkill(tower, "nirvana_flame")
    if nirvana and target and target.isBoss then
        local atkBasedDmg = tower.attack * (nirvana.bossAtkPct or 3.0)
        if atkBasedDmg > baseDotDmg then
            baseDotDmg = atkBasedDmg
        end
    end

    return baseDotDmg
end

-- ============================================================================
-- 被动技能效果 — 攻速/连射/范围
-- ============================================================================

--- 检查是否触发连射
---@param tower table
---@return boolean
function HeroSkills.ShouldMultiShot(tower)
    local multi = HeroSkills.HasSkill(tower, "multi_shot")
    if multi then
        return math.random() < (multi.chance or 0.20)
    end
    return false
end

--- 修正攻速
---@param tower table
---@param baseSpeed number  attack interval
---@return number
function HeroSkills.ModifyAttackSpeed(tower, baseSpeed)
    -- 亡灵韧性: 固定攻速加成
    local tenacity = HeroSkills.HasSkill(tower, "undead_tenacity")
    if tenacity then
        baseSpeed = baseSpeed / (1 + (tenacity.atkSpdBonus or 0.05))
    end

    -- 恶魔之怒: 随波次加速（每波重置由 State 管理）
    local fury = HeroSkills.HasSkill(tower, "demon_fury")
    if fury then
        local bonus = math.min(
            State.currentWave * (fury.bonusPerWave or 0.005),
            fury.maxBonus or 0.25
        )
        baseSpeed = baseSpeed / (1 + bonus)
    end

    -- 战鼓光环攻速加成（通过全局 buff 检查）
    if tower.auraSpdBuff and tower.auraSpdBuff > 0 then
        baseSpeed = baseSpeed / (1 + tower.auraSpdBuff)
    end

    return baseSpeed
end

--- 修正攻击范围
---@param tower table
---@param baseRange number
---@return number
function HeroSkills.ModifyRange(tower, baseRange)
    -- 风暴之眼: 范围加成
    local stormEye = HeroSkills.HasSkill(tower, "storm_eye")
    if stormEye then
        baseRange = baseRange + (stormEye.rangeBonus or 20)
    end
    return baseRange
end

-- ============================================================================
-- 被动技能效果 — 减速扩散
-- ============================================================================

--- 处理减速扩散（灵魂锁链）
---@param tower table
---@param target table  被减速的原始目标
---@param slowDuration number
---@param slowRate number
function HeroSkills.HandleSlowSpread(tower, target, slowDuration, slowRate)
    local chain = HeroSkills.HasSkill(tower, "soul_chain")
    if not chain then return end

    local Enemy = require("Game.Enemy")
    local spreadCount = 0
    for _, e in ipairs(State.enemies) do
        if e.alive and e ~= target and spreadCount < (chain.chainMaxTargets or 2) then
            local dx = e.x - target.x
            local dy = e.y - target.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < (chain.chainRange or 40) then
                -- 不二次扩散
                if not e.slowSpread then
                    Enemy.ApplySlow(e, slowDuration, slowRate)
                    e.slowSpread = true
                    spreadCount = spreadCount + 1
                end
            end
        end
    end
end

-- ============================================================================
-- 光环系统
-- ============================================================================

--- 更新光环效果（每帧调用，在所有塔之间传递）
---@param towers table  所有塔列表
---@param gridOffsetX number
---@param gridOffsetY number
function HeroSkills.UpdateAuras(towers, gridOffsetX, gridOffsetY)
    local Grid = require("Game.Grid")

    -- 重置所有塔的光环buff
    for _, tower in ipairs(towers) do
        tower.auraAtkBuff = 0
        tower.auraSpdBuff = 0
        tower.auraCritRateBuff = 0
    end

    -- 全局buff重置
    State.causalityActive = false
    State.causalityChance = 0

    for _, source in ipairs(towers) do
        local sx, sy = Grid.CellToScreen(source.col, source.row, gridOffsetX, gridOffsetY)

        -- 暗影支配: 全体攻击加成
        local dominion = HeroSkills.HasSkill(source, "shadow_dominion")
        if dominion then
            for _, target in ipairs(towers) do
                target.auraAtkBuff = target.auraAtkBuff + (dominion.globalAtkBuff or 0.05)
            end
        end

        -- 战鼓祭司光环: 攻击 + 攻速
        local morale = HeroSkills.HasSkill(source, "morale_boost")
        local rhythm = HeroSkills.HasSkill(source, "war_rhythm")
        local typeDef = source.typeDef
        if typeDef.special == "support" then
            local auraRange = typeDef.auraRange or 80
            local atkBuff = (morale and morale.atkBuff) or typeDef.atkBuff or 0.10
            local spdBuff = (rhythm and rhythm.spdBuff) or typeDef.spdBuff or 0

            for _, target in ipairs(towers) do
                if target ~= source then
                    local tx, ty = Grid.CellToScreen(target.col, target.row, gridOffsetX, gridOffsetY)
                    local dx = tx - sx
                    local dy = ty - sy
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist <= auraRange then
                        target.auraAtkBuff = target.auraAtkBuff + atkBuff
                        target.auraSpdBuff = target.auraSpdBuff + spdBuff
                    end
                end
            end
        end

        -- 堕落荣光: 暴击率光环
        local glory = HeroSkills.HasSkill(source, "fallen_glory")
        if glory then
            local auraRange = glory.auraRange or 100
            for _, target in ipairs(towers) do
                if target ~= source then
                    local tx, ty = Grid.CellToScreen(target.col, target.row, gridOffsetX, gridOffsetY)
                    local dx = tx - sx
                    local dy = ty - sy
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist <= auraRange then
                        target.auraCritRateBuff = target.auraCritRateBuff + (glory.critRateBuff or 0.12)
                    end
                end
            end
        end

        -- 命运之线: 全局降低敌人治愈（标记到State）
        local fateThread = HeroSkills.HasSkill(source, "fate_thread")
        if fateThread then
            State.healReduction = math.max(State.healReduction or 0, fateThread.healReduction or 0.30)
        end

        -- 因果律: 全体友方概率双倍伤害
        local causality = HeroSkills.HasSkill(source, "causality")
        if causality then
            State.causalityActive = true
            State.causalityChance = math.max(State.causalityChance or 0, causality.doubleDmgChance or 0.15)
        end
    end
end

-- ============================================================================
-- 主动技能
-- ============================================================================

--- 更新主动技能冷却（每帧调用）
---@param tower table
---@param dt number
function HeroSkills.UpdateActive(tower, dt)
    if not tower.skills or not tower.skillTimers then return end

    for _, skill in ipairs(tower.skills) do
        if skill.type == "active" and skill.interval then
            local timerId = skill.id
            tower.skillTimers[timerId] = (tower.skillTimers[timerId] or 0) - dt

            if tower.skillTimers[timerId] <= 0 then
                tower.skillTimers[timerId] = skill.interval
                HeroSkills.TriggerActive(tower, skill)
            end
        end
    end
end

--- 触发主动技能
---@param tower table
---@param skill table
function HeroSkills.TriggerActive(tower, skill)
    local Enemy = require("Game.Enemy")
    local Combat = require("Game.Combat")

    -- === 全屏伤害型 ===
    if skill.id == "void_storm" or skill.id == "shadow_devour"
        or skill.id == "angel_judgment" or skill.id == "divine_thunder" then
        local baseDmg = tower.attack * (skill.damagePct or 0.30)
        for _, e in ipairs(State.enemies) do
            if e.alive and not e.phaseActive then
                local finalDmg = Combat.CalcFinalDamage(tower, e, baseDmg)
                Enemy.TakeDamage(e, finalDmg)
            end
        end
        -- 天降雷霆附带减速
        if skill.slowPct and skill.slowDuration then
            for _, e in ipairs(State.enemies) do
                if e.alive then
                    local slowRate = skill.slowPct
                    if e.isBoss then
                        slowRate = slowRate * (Config.BOSS_BALANCE.slowEfficiency or 0.50)
                    end
                    Enemy.ApplySlow(e, skill.slowDuration, slowRate)
                end
            end
        end
        State.skillFlash = { type = skill.id, timer = 0.5, tower = tower }
    end

    -- === 龙王之怒: 全屏伤害 + 减速 ===
    if skill.id == "dragon_wrath" then
        local baseDmg = tower.attack * (skill.damagePct or 0.50)
        for _, e in ipairs(State.enemies) do
            if e.alive and not e.phaseActive then
                local finalDmg = Combat.CalcFinalDamage(tower, e, baseDmg)
                Enemy.TakeDamage(e, finalDmg)
                if e.alive and skill.slowPct then
                    local slowRate = skill.slowPct
                    if e.isBoss then
                        slowRate = slowRate * (Config.BOSS_BALANCE.slowEfficiency or 0.50)
                    end
                    Enemy.ApplySlow(e, skill.slowDuration or 3.0, slowRate)
                end
            end
        end
        State.skillFlash = { type = "dragon_wrath", timer = 0.5, tower = tower }
    end

    -- === 暴风雪: 全屏减速 ===
    if skill.id == "blizzard" then
        for _, e in ipairs(State.enemies) do
            if e.alive then
                local slowRate = skill.slowPct or 0.40
                if e.isBoss then
                    slowRate = slowRate * (Config.BOSS_BALANCE.slowEfficiency or 0.50)
                end
                Enemy.ApplySlow(e, skill.duration or 3.0, slowRate)
            end
        end
        State.skillFlash = { type = "blizzard", timer = 0.5, tower = tower }
    end

    -- === 英勇战歌: 全体塔攻击加成（临时buff） ===
    if skill.id == "heroic_anthem" then
        State.heroicAnthemBuff = {
            atkMult = skill.atkBuffPct or 0.25,
            timer = skill.duration or 5.0,
        }
        State.skillFlash = { type = "heroic_anthem", timer = 0.5, tower = tower }
    end

    -- === 深渊之箭 / 灭世之炎: 对最高血量敌人 %HP 伤害 ===
    if skill.id == "abyss_arrow" or skill.id == "worldfire" then
        local bestHP = 0
        local bestEnemy = nil
        for _, e in ipairs(State.enemies) do
            if e.alive and e.hp > bestHP then
                bestHP = e.hp
                bestEnemy = e
            end
        end
        if bestEnemy then
            local baseDmg = bestEnemy.hp * (skill.hpPct or 0.08)
            -- BOSS: ATK上限
            if bestEnemy.isBoss and skill.bossAtkCap then
                local cap = tower.attack * skill.bossAtkCap
                baseDmg = math.min(baseDmg, cap)
            end
            local finalDmg = Combat.CalcFinalDamage(tower, bestEnemy, baseDmg)
            Enemy.TakeDamage(bestEnemy, finalDmg)
        end
        State.skillFlash = { type = skill.id, timer = 0.5, tower = tower }
    end

    -- === 瘟疫爆发: 引爆全部DOT ===
    if skill.id == "plague_burst" then
        for _, e in ipairs(State.enemies) do
            if e.alive and e.dotTimer and e.dotTimer > 0 then
                local burstDmg = (e.dotDamage or 0) * e.dotTimer * (skill.burstMult or 2.0)
                Enemy.TakeDamage(e, burstDmg)
                e.dotTimer = 0  -- 清除DOT
            end
        end
        State.skillFlash = { type = "plague_burst", timer = 0.5, tower = tower }
    end

    -- === 时间编织: 重置全体友方塔主动技能CD ===
    if skill.id == "time_weave" then
        for _, t in ipairs(State.towers) do
            if t.skillTimers then
                for sId, _ in pairs(t.skillTimers) do
                    if sId ~= "time_weave" then  -- 不重置自己
                        t.skillTimers[sId] = 0
                    end
                end
            end
        end
        State.skillFlash = { type = "time_weave", timer = 0.5, tower = tower }
    end

    -- === 箭雨 / 地狱之门（旧兼容占位） ===
    if skill.id == "arrow_rain" then
        State.skillFlash = { type = "arrow_rain", timer = 0.5, tower = tower }
    end
    if skill.id == "hell_gate" then
        State.skillFlash = { type = "hell_gate", timer = 0.5, tower = tower }
    end
end

-- ============================================================================
-- 眩晕处理（BOSS减半）
-- ============================================================================

--- 应用眩晕效果（考虑BOSS减半）
---@param target table
---@param duration number
function HeroSkills.ApplyStun(target, duration)
    if target.isBoss then
        duration = duration * (Config.BOSS_BALANCE.stunDurationMult or 0.50)
    end
    -- 仅在首次施加时显示飘字
    if not target.stunTimer or target.stunTimer <= 0 then
        State.floatingTexts[#State.floatingTexts + 1] = {
            text = "眩晕",
            x = target.x + (math.random() - 0.5) * 10,
            y = target.y - (target.typeDef.size or 8) - 16,
            life = 0.6,
            color = { 255, 220, 60, 255 },
            fontSize = 12,
        }
    end
    target.stunTimer = math.max(target.stunTimer or 0, duration)
end

-- ============================================================================
-- 诅咒标记DOT（每帧更新）
-- ============================================================================

--- 更新诅咒标记DOT（死灵术士：被减速敌人每秒受ATK×5%伤害）
---@param dt number
function HeroSkills.UpdateCurseDOT(dt)
    local Enemy = require("Game.Enemy")
    for _, tower in ipairs(State.towers) do
        local curse = HeroSkills.HasSkill(tower, "curse_mark")
        if curse then
            for _, e in ipairs(State.enemies) do
                if e.alive and e.slowTimer and e.slowTimer > 0 then
                    local dmg = tower.attack * (curse.curseDmgAtkPct or 0.05) * dt
                    Enemy.TakeDamage(e, dmg)
                end
            end
        end
    end
end

-- ============================================================================
-- 英勇战歌buff更新
-- ============================================================================

--- 更新临时全局buff
---@param dt number
function HeroSkills.UpdateGlobalBuffs(dt)
    -- 英勇战歌
    if State.heroicAnthemBuff then
        State.heroicAnthemBuff.timer = State.heroicAnthemBuff.timer - dt
        if State.heroicAnthemBuff.timer <= 0 then
            State.heroicAnthemBuff = nil
        end
    end

    -- 重置每帧状态
    State.healReduction = 0
end

-- ============================================================================
-- 获取塔的实际攻击力（含光环+临时buff）
-- ============================================================================

--- 获取塔的最终攻击力
---@param tower table
---@return number
function HeroSkills.GetEffectiveAttack(tower)
    local atk = tower.attack
    -- 光环攻击加成
    if tower.auraAtkBuff and tower.auraAtkBuff > 0 then
        atk = atk * (1 + tower.auraAtkBuff)
    end
    -- 英勇战歌临时加成
    if State.heroicAnthemBuff then
        atk = atk * (1 + State.heroicAnthemBuff.atkMult)
    end
    return atk
end

--- 获取塔的最终暴击率（含光环buff）
---@param tower table
---@return number
function HeroSkills.GetEffectiveCritRate(tower)
    local rate = tower.critRate or 0
    if tower.auraCritRateBuff and tower.auraCritRateBuff > 0 then
        rate = rate + tower.auraCritRateBuff
    end
    return rate
end

-- ============================================================================
-- 命运终章（致命一击溅射）
-- ============================================================================

--- 检查命运终章溅射（在暴击命中后调用）
---@param tower table  造成暴击的塔
---@param target table  被暴击的敌人
---@param damage number  暴击伤害
function HeroSkills.CheckCritSplash(tower, target, damage)
    -- 在场上查找命运织者
    for _, t in ipairs(State.towers) do
        local splash = HeroSkills.HasSkill(t, "fate_finale")
        if splash then
            local splashDmg = damage * (splash.critSplashPct or 0.50)
            local Enemy = require("Game.Enemy")
            for _, e in ipairs(State.enemies) do
                if e.alive and e ~= target then
                    local dx = e.x - target.x
                    local dy = e.y - target.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist < 60 then
                        Enemy.TakeDamage(e, splashDmg)
                    end
                end
            end
            break  -- 只触发一次
        end
    end
end

-- ============================================================================
-- 每波重置
-- ============================================================================

--- 每波开始时重置波次相关的技能状态
function HeroSkills.OnWaveStart()
    for _, tower in ipairs(State.towers) do
        -- 永恒之力: 每波重置击杀叠层
        tower.killAtkStacks = 0
        -- 恶魔之怒: bonusPerWave 基于 State.currentWave 自动计算
    end
    -- 清除敌人减速扩散标记
    for _, e in ipairs(State.enemies) do
        e.slowSpread = nil
        e.dotSpread = nil
    end
end

return HeroSkills
