-- ============================================================================
-- battle/PlayerAI.lua - 玩家自动战斗 AI & 技能释放
-- ============================================================================

local Config = require("Config")
local GameState = require("GameState")
local FamilyMechanics = require("battle.FamilyMechanics")

local PlayerAI = {}

-- ============================================================================
-- 辅助
-- ============================================================================

function PlayerAI.FindNearestEnemy(px, py, enemies)
    local nearestIdx, nearestDist = nil, math.huge
    for i, e in ipairs(enemies) do
        if not e.dead and not FamilyMechanics.IsUntargetable(e) then
            local dx, dy = e.x - px, e.y - py
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < nearestDist then
                nearestDist = dist
                nearestIdx  = i
            end
        end
    end
    return nearestIdx, nearestDist
end

-- ============================================================================
-- 普攻 AI  (风筝走位: 保持攻击范围边缘, 边打边退)
-- ============================================================================

--- 计算所有活着敌人的威胁排斥力 (用于远离密集敌群)
---@param px number
---@param py number
---@param enemies table
---@param dangerRadius number 排斥生效半径
---@return number, number 归一化排斥方向 (rx, ry), 无威胁时返回 0,0
local function CalcRepulsion(px, py, enemies, dangerRadius)
    local rx, ry = 0, 0
    for _, e in ipairs(enemies) do
        if not e.dead then
            local dx, dy = px - e.x, py - e.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < dangerRadius and dist > 1 then
                -- 距离越近排斥越强 (反比权重)
                local weight = (dangerRadius - dist) / dangerRadius
                weight = weight * weight  -- 平方衰减, 近处更强
                rx = rx + (dx / dist) * weight
                ry = ry + (dy / dist) * weight
            end
        end
    end
    local len = math.sqrt(rx * rx + ry * ry)
    if len > 0.01 then
        return rx / len, ry / len
    end
    return 0, 0
end

-- ============================================================================
-- 威胁感知 (模板系统 Boss 专用)
-- ============================================================================

--- 从威胁表计算躲避向量 (dangerZone / expandingRing 等)
---@param px number
---@param py number
---@param bs table BattleSystem
---@return number, number 归一化躲避方向
local function CalcThreatAvoidance(px, py, bs)
    if not bs or not bs.threats then return 0, 0 end
    local ThreatSystem = require("battle.ThreatSystem")
    local threats = ThreatSystem.GetThreats(bs)
    if not threats or #threats == 0 then return 0, 0 end

    local ax, ay = 0, 0
    for _, t in ipairs(threats) do
        if t.type == "dangerZone" then
            local dx, dy = px - t.x, py - t.y
            local dist = math.sqrt(dx * dx + dy * dy)
            local r = t.radius or 50
            if dist < r and dist > 1 then
                local urgency = (r - dist) / r
                urgency = urgency * urgency  -- 越近越强
                ax = ax + (dx / dist) * urgency * 2.0
                ay = ay + (dy / dist) * urgency * 2.0
            end
        elseif t.type == "pull" then
            -- 漩涡拉力: AI 尝试远离中心
            local dx, dy = px - t.x, py - t.y
            local dist = math.sqrt(dx * dx + dy * dy)
            local r = t.radius or 60
            if dist < r and dist > 1 then
                local urgency = (r - dist) / r
                ax = ax + (dx / dist) * urgency * 1.5
                ay = ay + (dy / dist) * urgency * 1.5
            end
        end
    end

    local len = math.sqrt(ax * ax + ay * ay)
    if len > 0.01 then
        return ax / len, ay / len
    end
    return 0, 0
end

--- 评估威胁目标: 如果存在优先攻击目标(可摧毁物), 返回其索引
---@param px number
---@param py number
---@param enemies table
---@param bs table
---@return integer|nil 优先目标在 enemies 中的索引
local function EvaluateThreatTargets(px, py, enemies, bs)
    if not bs or not bs.threats then return nil end
    local ThreatSystem = require("battle.ThreatSystem")
    local threats = ThreatSystem.GetThreats(bs)
    if not threats then return nil end

    -- 查找 priorityTarget 类型威胁
    for _, t in ipairs(threats) do
        if t.type == "priorityTarget" then
            -- 找到对应的 enemies 条目
            for i, e in ipairs(enemies) do
                if not e.dead and e.isBossDestroyable then
                    local dx, dy = e.x - t.x, e.y - t.y
                    if math.abs(dx) < 5 and math.abs(dy) < 5 then
                        return i
                    end
                end
            end
        end
    end
    return nil
end

---@param dt number
---@param p table  playerBattle
---@param enemies table
---@param areaW number
---@param areaH number
---@param onAttack fun(targetIdx: integer)
---@param bs table|nil BattleSystem 引用 (模板系统威胁感知)
function PlayerAI.Update(dt, p, enemies, areaW, areaH, onAttack, bs)
    -- 攻击闪光衰减
    if p.atkFlash > 0 then p.atkFlash = p.atkFlash - dt * 4 end
    p.atkTimer = math.max(0, p.atkTimer - dt)

    local nearestIdx, nearestDist = PlayerAI.FindNearestEnemy(p.x, p.y, enemies)
    if not nearestIdx then
        p.state = "idle"
        p.targetIdx = nil
        return
    end

    -- 锁定冷却: 切换目标后一段时间内不再切换, 防止频繁转向
    local LOCK_COOLDOWN = 0.1  -- 锁定冷却时间（秒）
    p.targetLockTimer = (p.targetLockTimer or 0) - dt

    -- 威胁系统: 检查是否有优先攻击目标 (可摧毁物)
    local priorityIdx = EvaluateThreatTargets(p.x, p.y, enemies, bs)

    -- 迟滞阈值 + 冷却: 当前目标仍存活时, 冷却期内不切换
    if priorityIdx then
        -- 优先攻击可摧毁物 (覆盖常规目标选择)
        p.targetIdx = priorityIdx
        p.targetLockTimer = LOCK_COOLDOWN
    elseif p.targetIdx and enemies[p.targetIdx] and not enemies[p.targetIdx].dead then
        if p.targetLockTimer <= 0 then
            local cur = enemies[p.targetIdx]
            local cdx, cdy = cur.x - p.x, cur.y - p.y
            local curDist = math.sqrt(cdx * cdx + cdy * cdy)
            if nearestDist < curDist * 0.75 then
                p.targetIdx = nearestIdx
                p.targetLockTimer = LOCK_COOLDOWN
            end
        end
        -- 冷却中或距离不够: 保持当前目标
    else
        p.targetIdx = nearestIdx
        p.targetLockTimer = LOCK_COOLDOWN
    end

    local target = enemies[p.targetIdx]
    local dx, dy = target.x - p.x, target.y - p.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if math.abs(dx) > 1 then p.faceDirX = dx > 0 and 1 or -1 end

    local atkRange = GameState.GetRange()
    -- 理想站位距离: 攻击范围的 85%, 留一定余量确保命中
    local idealDist = atkRange * 0.85
    -- 敌人攻击范围 (用最近敌人的, 默认 35)
    local enemyRange = target.atkRange or 35
    -- 危险距离: 敌人攻击范围 + 缓冲区
    local dangerDist = enemyRange + 10

    -- ================================================================
    -- 移动决策
    -- ================================================================
    local moveX, moveY = 0, 0

    if dist > atkRange then
        -- 太远: 直接接近目标
        p.state = "moving"
        moveX, moveY = dx / dist, dy / dist
    elseif dist < dangerDist and atkRange > dangerDist then
        -- 太近 (在敌人攻击范围内且我方射程有优势): 后撤到理想距离
        p.state = "moving"
        -- 后撤方向 = 远离目标
        local backX, backY = -dx / dist, -dy / dist
        -- 混合横向分量实现弧线后撤, 不是直线退
        local sideX, sideY = -backY, backX  -- 垂直方向
        -- 选择远离边界的侧向
        local centerX, centerY = areaW * 0.5, areaH * 0.5
        local toCenterX, toCenterY = centerX - p.x, centerY - p.y
        local sideDot = sideX * toCenterX + sideY * toCenterY
        if sideDot < 0 then sideX, sideY = -sideX, -sideY end
        -- 后撤 70% + 侧移 30%
        moveX = backX * 0.7 + sideX * 0.3
        moveY = backY * 0.7 + sideY * 0.3
    elseif dist < idealDist * 0.7 then
        -- 距离明显小于理想距离: 轻微后撤
        p.state = "moving"
        moveX, moveY = -dx / dist, -dy / dist
    else
        -- 在理想范围内: 站定攻击, 但如果多个敌人靠近则微调
        p.state = "attacking"
        -- 检查周围是否有密集敌群
        local repX, repY = CalcRepulsion(p.x, p.y, enemies, dangerDist)
        if math.abs(repX) > 0.01 or math.abs(repY) > 0.01 then
            -- 有近距离威胁, 缓慢漂移躲避 (不影响攻击)
            local driftSpeed = Config.PLAYER.moveSpeed * 0.3
            p.x = p.x + repX * driftSpeed * dt
            p.y = p.y + repY * driftSpeed * dt
        end
    end

    -- 执行移动
    if moveX ~= 0 or moveY ~= 0 then
        local len = math.sqrt(moveX * moveX + moveY * moveY)
        moveX, moveY = moveX / len, moveY / len
        -- 叠加群体排斥力 (避免扎堆)
        local repX, repY = CalcRepulsion(p.x, p.y, enemies, dangerDist)
        moveX = moveX + repX * 0.3
        moveY = moveY + repY * 0.3
        -- 叠加威胁躲避 (Boss 技能区域)
        local threatX, threatY = CalcThreatAvoidance(p.x, p.y, bs)
        moveX = moveX + threatX * 0.6
        moveY = moveY + threatY * 0.6
        -- 重新归一化
        len = math.sqrt(moveX * moveX + moveY * moveY)
        if len > 0.01 then
            moveX, moveY = moveX / len, moveY / len
        end
        p.x = p.x + moveX * Config.PLAYER.moveSpeed * dt
        p.y = p.y + moveY * Config.PLAYER.moveSpeed * dt
    end

    -- 边界限制
    p.x = math.max(20, math.min(areaW - 20, p.x))
    p.y = math.max(20, math.min(areaH - 20, p.y))

    -- 攻击判定: 只要在攻击范围内就可以攻击 (包括边移动边攻击)
    if dist <= atkRange and p.atkTimer <= 0 then
        onAttack(nearestIdx)
        p.atkTimer = 1.0 / GameState.GetAtkSpeed()
        p.atkFlash = 1.0
    end
end

-- ============================================================================
-- 技能自动释放
-- ============================================================================

---@param dt number
---@param p table  playerBattle
---@param enemies table
---@param onCastSkill fun(skillCfg: table, lv: integer)
function PlayerAI.UpdateSkills(dt, p, enemies, onCastSkill)
    local cdMul = GameState.GetSkillCdMul()

    -- 符文编织6件: 共鸣期间CD流速翻倍 (dt加速)
    local cdFlowMul = 1.0
    local ok_bm, BuffManager = pcall(require, "battle.BuffManager")
    if ok_bm and BuffManager.GetRuneResonanceCdMul then
        cdFlowMul = BuffManager.GetRuneResonanceCdMul()
    end
    local effectiveDt = dt * cdFlowMul

    -- CD 始终倒计时 (包括空闲期), 但施法仅在非空闲时
    local isIdle = (p.state == "idle")

    -- v3.0: 使用已装备的主动技能列表 (SkillTreeConfig 驱动)
    local equippedList = GameState.GetEquippedSkillList()
    for _, entry in ipairs(equippedList) do
        local skillCfg = entry.cfg
        local lv = entry.level
        -- 核心技能走攻速槽位 (CombatCore.PlayerAttack), 不走CD通道
        if skillCfg.coreSkill then
            -- skip: 由攻速计时器驱动
        else
        local cd = skillCfg.cooldown or 0
        if cd > 0 then
            local timer = p.skillTimers[entry.id] or 0
            timer = timer - effectiveDt
            if timer <= 0 then
                if not isIdle then
                    onCastSkill(skillCfg, lv)
                end
                -- 无论是否施法, CD 重置 (空闲时技能转好后等待下一波立刻施放)
                if timer <= 0 then
                    timer = isIdle and 0 or (cd * cdMul)
                end
            end
            p.skillTimers[entry.id] = timer
        end
        end -- else (non-coreSkill)
    end
end

return PlayerAI
