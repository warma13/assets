-- ============================================================================
-- battle/skills/LightningSkills.lua - 闪电系 + 奥术技能施放
-- spark, arcane_strike, charged_bolts, chain_lightning, teleport,
-- lightning_spear, thunderstorm, energy_pulse, thunder_storm
-- ============================================================================

local GameState      = require("GameState")
local CombatUtils    = require("battle.CombatUtils")
local H              = require("battle.skills.Helpers")
local ShieldManager  = require("state.ShieldManager")

local function Register(SkillCaster)

-- ============================================================================
-- 电花 (spark) — 基础闪电多段
-- ============================================================================
function SkillCaster._Cast_spark(bs, skillCfg, lv, p)
    local element = "lightning"
    local dmgPerHit = skillCfg.effect(lv) / 100
    local hitCount = skillCfg.hitCount or 4
    if H.HasEnhance("spark_potent") then
        hitCount = hitCount + 2
    end

    local alive = H.GetAliveEnemies(bs.enemies)
    if #alive == 0 then return end

    for i = 1, hitCount do
        local target = alive[math.random(#alive)]
        local bonuses = {}
        H.HitEnemySkill(bs, target, dmgPerHit, element, bonuses, p.x, p.y, CombatUtils.KNOCKBACK_SKILL * 0.5)
    end

    CombatUtils.TriggerShake(bs, CombatUtils.SHAKE_NORMAL)
    table.insert(bs.skillEffects, {
        type = "spark", x = p.x, y = p.y,
        life = 0.4, maxLife = 0.4,
        areaW = bs.areaW, areaH = bs.areaH,
    })
end

-- ============================================================================
-- 奥术打击 (arcane_strike) — 基础近战 + 击退
-- ============================================================================
function SkillCaster._Cast_arcane_strike(bs, skillCfg, lv, p)
    local element = "fire"  -- 奥术打击走火伤
    local range = 100 * GameState.GetRangeFactor()
    local dmgScale = skillCfg.effect(lv) / 100

    local kbMul = CombatUtils.KNOCKBACK_SKILL * 1.5
    if H.HasEnhance("arcane_strike_enhanced") then
        kbMul = kbMul * 1.5
    end

    for _, e in ipairs(bs.enemies) do
        if not e.dead then
            local dx, dy = e.x - p.x, e.y - p.y
            if math.sqrt(dx * dx + dy * dy) <= range then
                local bonuses = {}
                local _, isCrit = H.HitEnemySkill(bs, e, dmgScale, element, bonuses, p.x, p.y, kbMul)
                if H.HasEnhance("arcane_strike_potent") and isCrit and not e.dead then
                    CombatUtils.ApplyKnockback(e, p.x, p.y, kbMul)
                end
            end
        end
    end

    CombatUtils.TriggerShake(bs, CombatUtils.SHAKE_SKILL)
    table.insert(bs.skillEffects, {
        type = "arcane_strike", x = p.x, y = p.y,
        radius = range, life = 0.3, maxLife = 0.3,
    })
end

-- ============================================================================
-- 电荷弹 (charged_bolts) — 闪电AoE
-- ============================================================================
function SkillCaster._Cast_charged_bolts(bs, skillCfg, lv, p)
    local element = "lightning"
    local dmgScale = skillCfg.effect(lv) / 100
    local radius = 90

    local bestX, bestY = H.FindBestAoeCenter(bs.enemies, radius, p.x, p.y)

    for _, e in ipairs(bs.enemies) do
        if not e.dead then
            local dx, dy = e.x - bestX, e.y - bestY
            if math.sqrt(dx * dx + dy * dy) <= radius then
                local bonuses = {}
                H.HitEnemySkill(bs, e, dmgScale, element, bonuses, bestX, bestY, CombatUtils.KNOCKBACK_SKILL)
            end
        end
    end

    CombatUtils.TriggerShake(bs, CombatUtils.SHAKE_BLAST)
    CombatUtils.PlaySfx("elemBlast", 0.6)
    table.insert(bs.skillEffects, {
        type = "charged_bolts", x = bestX, y = bestY,
        radius = radius, life = 0.5, maxLife = 0.5,
    })
end

-- ============================================================================
-- 连锁闪电 (chain_lightning) — 弹跳闪电
-- ============================================================================
function SkillCaster._Cast_chain_lightning(bs, skillCfg, lv, p)
    local element = "lightning"
    local dmgScale = skillCfg.effect(lv) / 100
    local bounces = skillCfg.bounceCount or 5
    local bounceBonus = H.HasEnhance("chain_lightning_greater") and 0.10 or 0
    local critPerBounce = H.HasEnhance("chain_lightning_enhanced") and 0.03 or 0

    local alive = H.GetAliveEnemies(bs.enemies)
    if #alive == 0 then return end

    local lastTarget = alive[math.random(#alive)]
    for i = 1, bounces do
        if lastTarget and not lastTarget.dead then
            local bonuses = { bounceRamp = bounceBonus * (i - 1) }
            local xSources = {}
            H.HitEnemySkill(bs, lastTarget, dmgScale * (1 + bounceBonus * (i - 1)), element, bonuses, p.x, p.y, CombatUtils.KNOCKBACK_SKILL * 0.5)
            local nextTarget = nil
            local nextDist = math.huge
            for _, e in ipairs(bs.enemies) do
                if not e.dead and e ~= lastTarget then
                    local dx, dy = e.x - lastTarget.x, e.y - lastTarget.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist < nextDist then
                        nextTarget = e
                        nextDist = dist
                    end
                end
            end
            lastTarget = nextTarget or alive[math.random(#alive)]
        end
    end

    CombatUtils.TriggerShake(bs, CombatUtils.SHAKE_SKILL)
    table.insert(bs.skillEffects, {
        type = "chain_lightning",
        life = 0.6, maxLife = 0.6,
        areaW = bs.areaW, areaH = bs.areaH,
    })
end

-- ============================================================================
-- 传送 (teleport) — 位移 + 闪电伤害
-- ============================================================================
function SkillCaster._Cast_teleport(bs, skillCfg, lv, p)
    local element = "lightning"
    local dmgScale = skillCfg.effect(lv) / 100
    local radius = 80

    local bestX, bestY = H.FindBestAoeCenter(bs.enemies, radius, p.x, p.y)
    local hitCount = 0

    for _, e in ipairs(bs.enemies) do
        if not e.dead then
            local dx, dy = e.x - bestX, e.y - bestY
            if math.sqrt(dx * dx + dy * dy) <= radius then
                hitCount = hitCount + 1
                H.HitEnemySkill(bs, e, dmgScale, element, {}, bestX, bestY, CombatUtils.KNOCKBACK_SKILL)
            end
        end
    end

    CombatUtils.TriggerShake(bs, CombatUtils.SHAKE_SKILL)
    table.insert(bs.skillEffects, {
        type = "teleport", x = bestX, y = bestY,
        radius = radius, life = 0.4, maxLife = 0.4,
    })
end

-- ============================================================================
-- 闪电矛 (lightning_spear) — 追踪闪电持续攻击
-- ============================================================================
function SkillCaster._Cast_lightning_spear(bs, skillCfg, lv, p)
    local element = "lightning"
    local dmgScale = skillCfg.effect(lv) / 100
    local duration = 6.0
    if H.HasEnhance("lightning_spear_greater") then duration = duration + 2.0 end

    table.insert(GameState.spirits, {
        x = p.x, y = p.y - 20,
        timer = duration,
        atkCD = 0,
        atkInterval = 0.8,
        dmgScale = dmgScale,
        atkRange = 250,
        element = "lightning",
        orbitAngle = math.random() * math.pi * 2,
        source = "lightning_spear",
    })

    table.insert(bs.skillEffects, {
        type = "lightning_spear", x = p.x, y = p.y,
        life = 0.4, maxLife = 0.4,
    })
end

-- ============================================================================
-- 雷暴 (thunderstorm) — 闪电持续区域
-- ============================================================================
function SkillCaster._Cast_thunderstorm(bs, skillCfg, lv, p)
    local duration = 6.0
    local tickDmg = skillCfg.effect(lv) / 100
    local radius = 100
    if H.HasEnhance("thunderstorm_enhanced") then radius = math.floor(radius * 1.25) end

    local bestX, bestY = H.FindBestAoeCenter(bs.enemies, radius, p.x, p.y)

    table.insert(bs.fireZones, {
        x = bestX, y = bestY,
        radius = radius,
        duration = duration, maxDuration = duration,
        dmgPct = tickDmg, tickRate = 1.0, tickCD = 0,
        element = "lightning", source = "thunderstorm",
        bonusDmg = H.HasEnhance("thunderstorm_destructive") and 0.20 or 0,
        endStun = H.HasEnhance("thunderstorm_greater") and 1.5 or nil,
    })

    CombatUtils.TriggerShake(bs, CombatUtils.SHAKE_STORM)
    CombatUtils.PlaySfx("stormWarn", 0.6)
    table.insert(bs.skillEffects, {
        type = "thunderstorm", x = bestX, y = bestY,
        radius = radius, life = 1.0, maxLife = 1.0,
    })
end

-- ============================================================================
-- 能量脉冲 (energy_pulse) — 全方向能量波
-- ============================================================================
function SkillCaster._Cast_energy_pulse(bs, skillCfg, lv, p)
    local element = "lightning"
    local dmgScale = skillCfg.effect(lv) / 100
    local radius = 130

    local kbMul = CombatUtils.KNOCKBACK_SKILL * 1.5
    if H.HasEnhance("energy_pulse_enhanced") then kbMul = kbMul * 1.5 end

    for _, e in ipairs(bs.enemies) do
        if not e.dead then
            local dx, dy = e.x - p.x, e.y - p.y
            if math.sqrt(dx * dx + dy * dy) <= radius then
                local bonuses = {}
                if H.HasEnhance("energy_pulse_destructive") then
                    if e.hp and e.maxHP and e.maxHP > 0 and e.hp / e.maxHP < 0.30 then
                        bonuses.destructive = 0.40
                    end
                end
                local _, isCrit = H.HitEnemySkill(bs, e, dmgScale, element, bonuses, p.x, p.y, kbMul)
                if H.HasEnhance("energy_pulse_greater") and isCrit then
                    local shield = math.floor(GameState.GetMaxHP() * 0.05)
                    ShieldManager.Add("energy_pulse", shield)
                end
            end
        end
    end

    CombatUtils.TriggerShake(bs, CombatUtils.SHAKE_BLAST)
    table.insert(bs.skillEffects, {
        type = "energy_pulse", x = p.x, y = p.y,
        radius = radius, life = 0.6, maxLife = 0.6,
    })
end

-- ============================================================================
-- 雷霆风暴 (thunder_storm) — 持续闪电风暴
-- ============================================================================
function SkillCaster._Cast_thunder_storm(bs, skillCfg, lv, p)
    local element = "lightning"
    local dmgScale = skillCfg.effect(lv) / 100
    local duration = 8.0
    if H.HasEnhance("thunder_storm_prime") then duration = duration + 2.0 end

    for _, e in ipairs(bs.enemies) do
        if not e.dead then
            H.HitEnemySkill(bs, e, dmgScale * 0.5, element, {}, bs.areaW * 0.5, e.y, CombatUtils.KNOCKBACK_SKILL)
        end
    end

    table.insert(bs.fireZones, {
        x = bs.areaW * 0.5, y = bs.areaH * 0.5,
        radius = math.floor(math.min(bs.areaW, bs.areaH) * 0.45),
        duration = duration, maxDuration = duration,
        dmgPct = dmgScale * 0.3, tickRate = 1.0, tickCD = 0,
        element = "lightning", source = "thunder_storm",
    })

    CombatUtils.TriggerShake(bs, CombatUtils.SHAKE_STORM * 2)
    CombatUtils.PlaySfx("stormWarn", 0.8)
    table.insert(bs.skillEffects, {
        type = "thunder_storm",
        life = 1.5, maxLife = 1.5,
        areaW = bs.areaW, areaH = bs.areaH,
    })
end

end -- Register

return { Register = Register }
