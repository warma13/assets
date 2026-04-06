-- ============================================================================
-- battle/skills/FireSkills.lua - 火系技能施放
-- fire_bolt, fireball, incinerate, flame_shield, hydra, firewall,
-- fire_storm, meteor
-- ============================================================================

local GameState      = require("GameState")
local CombatUtils    = require("battle.CombatUtils")
local H              = require("battle.skills.Helpers")
local ShieldManager  = require("state.ShieldManager")

local function Register(SkillCaster)

-- ============================================================================
-- 火焰弹 (fire_bolt) — 基础火系单体
-- ============================================================================
function SkillCaster._Cast_fire_bolt(bs, skillCfg, lv, p)
    local element = "fire"
    local range = 200 * GameState.GetRangeFactor()
    local dmgScale = skillCfg.effect(lv) / 100
    local target = H.FindNearestEnemy(bs.enemies, p.x, p.y, range)

    if target then
        local bonuses = {}
        if H.HasEnhance("fire_bolt_enhanced") and target.burnTimer and target.burnTimer > 0 then
            bonuses.enhanced = 0.30
        end
        local dmg, isCrit = H.HitEnemySkill(bs, target, dmgScale, element, bonuses, p.x, p.y, CombatUtils.KNOCKBACK_SKILL)
        if H.HasEnhance("fire_bolt_potent") and not target.dead then
            H.ApplyBurn(target, 0.04, 6.0)
        end
    end

    CombatUtils.TriggerShake(bs, CombatUtils.SHAKE_NORMAL)
    table.insert(bs.skillEffects, {
        type = "fire_bolt", x = p.x, y = p.y,
        targetX = target and target.x or p.x,
        targetY = target and target.y or p.y,
        radius = 20, life = 0.3, maxLife = 0.3,
    })
end

-- ============================================================================
-- 火球 (fireball) — AoE 爆炸
-- ============================================================================
function SkillCaster._Cast_fireball(bs, skillCfg, lv, p)
    local element = "fire"
    local dmgScale = skillCfg.effect(lv) / 100
    local radius = 80
    if H.HasEnhance("fireball_enhanced") then radius = radius * 1.5 end

    local bestX, bestY = H.FindBestAoeCenter(bs.enemies, radius, p.x, p.y)
    local hitCount = 0

    for _, e in ipairs(bs.enemies) do
        if not e.dead then
            local dx, dy = e.x - bestX, e.y - bestY
            if math.sqrt(dx * dx + dy * dy) <= radius then
                hitCount = hitCount + 1
                local bonuses = {}
                if H.HasEnhance("fireball_destructive") then
                    bonuses.destructive = hitCount >= 3 and 0.30 or 0.20
                end
                H.HitEnemySkill(bs, e, dmgScale, element, bonuses, bestX, bestY, CombatUtils.KNOCKBACK_SKILL * 1.2)
            end
        end
    end

    if H.HasEnhance("fireball_greater") then
        table.insert(bs.fireZones, {
            x = bestX, y = bestY,
            radius = radius,
            duration = 4.0, maxDuration = 4.0,
            dmgPct = 0.25, tickRate = 0.5, tickCD = 0,
            element = "fire", source = "fireball_greater",
        })
    end

    CombatUtils.TriggerShake(bs, CombatUtils.SHAKE_BLAST)
    CombatUtils.PlaySfx("elemBlast", 0.7)
    table.insert(bs.skillEffects, {
        type = "fireball", x = bestX, y = bestY,
        radius = radius, life = 0.5, maxLife = 0.5,
    })
end

-- ============================================================================
-- 焚烧 (incinerate) — 引导火焰持续伤害
-- ============================================================================
function SkillCaster._Cast_incinerate(bs, skillCfg, lv, p)
    local element = "fire"
    local dmgScale = skillCfg.effect(lv) / 100

    local hasDestructive = H.HasEnhance("incinerate_destructive")

    for _, e in ipairs(bs.enemies) do
        if not e.dead then
            local eb = {}
            if hasDestructive and e.burnTimer and e.burnTimer > 0 then
                eb.destructive = 0.30
            end
            H.HitEnemySkill(bs, e, dmgScale, element, eb, p.x, p.y, CombatUtils.KNOCKBACK_SKILL)
            if not e.dead then
                H.ApplyBurn(e, 0.05, 3.0)
            end
        end
    end

    CombatUtils.TriggerShake(bs, CombatUtils.SHAKE_SKILL)
    table.insert(bs.skillEffects, {
        type = "incinerate",
        life = 0.6, maxLife = 0.6,
        areaW = bs.areaW, areaH = bs.areaH,
    })
end

-- ============================================================================
-- 火焰护盾 (flame_shield) — 屏障
-- ============================================================================
function SkillCaster._Cast_flame_shield(bs, skillCfg, lv, p)
    local shieldPct = skillCfg.effect(lv) / 100
    local duration = 6.0
    if H.HasEnhance("flame_shield_enhanced") then duration = duration + 2.0 end

    local maxHP = GameState.GetMaxHP()
    local shieldValue = math.floor(maxHP * shieldPct)

    ShieldManager.Add("flame_shield", shieldValue)
    GameState.flameShieldTimer = duration

    CombatUtils.TriggerShake(bs, CombatUtils.SHAKE_SKILL)
    table.insert(bs.skillEffects, {
        type = "flame_shield", x = p.x, y = p.y,
        life = 0.5, maxLife = 0.5,
        radius = 60,
    })
end

-- ============================================================================
-- 九头蛇 (hydra) — 召唤物
-- ============================================================================
function SkillCaster._Cast_hydra(bs, skillCfg, lv, p)
    local duration = skillCfg.effect(lv)
    local dmgScale = skillCfg.summonDamage(lv) / 100
    local headCount = 3
    if H.HasEnhance("hydra_enhanced") then duration = duration + 2.0 end
    if H.HasEnhance("hydra_greater") then headCount = headCount + 1 end

    for i = 1, headCount do
        table.insert(GameState.spirits, {
            x = p.x + (i - 1) * 30 - (headCount - 1) * 15,
            y = p.y - 30,
            timer = duration,
            atkCD = 0,
            atkInterval = 1.0,
            dmgScale = dmgScale,
            atkRange = 200,
            element = "fire",
            orbitAngle = math.random() * math.pi * 2,
            source = "hydra",
            applyVulnerable = H.HasEnhance("hydra_destructive") and 2.0 or nil,
        })
    end

    table.insert(bs.skillEffects, {
        type = "hydra_summon", x = p.x, y = p.y,
        life = 0.5, maxLife = 0.5,
    })
end

-- ============================================================================
-- 火墙 (firewall) — 火焰区域
-- ============================================================================
function SkillCaster._Cast_firewall(bs, skillCfg, lv, p)
    local dmgScale = skillCfg.effect(lv) / 100
    local duration = 6.0
    if H.HasEnhance("firewall_enhanced") then duration = duration + 2.0 end
    local radius = 70

    local bestX, bestY = H.FindBestAoeCenter(bs.enemies, radius, p.x, p.y)

    if H.HasEnhance("firewall_greater") then
        for _, e in ipairs(bs.enemies) do
            if not e.dead then
                local dx, dy = e.x - bestX, e.y - bestY
                if math.sqrt(dx * dx + dy * dy) <= radius then
                    CombatUtils.ApplyKnockback(e, bestX, bestY, CombatUtils.KNOCKBACK_SKILL * 1.5)
                end
            end
        end
    end

    table.insert(bs.fireZones, {
        x = bestX, y = bestY,
        radius = radius,
        duration = duration, maxDuration = duration,
        dmgPct = dmgScale, tickRate = 0.5, tickCD = 0,
        element = "fire", source = "firewall",
        bonusDmg = H.HasEnhance("firewall_destructive") and 0.15 or 0,
    })

    CombatUtils.TriggerShake(bs, CombatUtils.SHAKE_SKILL)
    table.insert(bs.skillEffects, {
        type = "firewall", x = bestX, y = bestY,
        radius = radius, life = 0.5, maxLife = 0.5,
    })
end

-- ============================================================================
-- 烈焰风暴 (fire_storm) — 全屏火焰
-- ============================================================================
function SkillCaster._Cast_fire_storm(bs, skillCfg, lv, p)
    local element = "fire"
    local dmgScale = skillCfg.effect(lv) / 100
    local hasDestructive = H.HasEnhance("fire_storm_destructive")

    for _, e in ipairs(bs.enemies) do
        if not e.dead then
            local bonuses = {}
            if hasDestructive and e.burnTimer and e.burnTimer > 0 then
                bonuses.destructive = 0.25
            end
            H.HitEnemySkill(bs, e, dmgScale, element, bonuses, bs.areaW * 0.5, e.y, CombatUtils.KNOCKBACK_SKILL * 1.5)
        end
    end

    if H.HasEnhance("fire_storm_greater") then
        table.insert(bs.fireZones, {
            x = bs.areaW * 0.5, y = bs.areaH * 0.5,
            radius = math.floor(math.min(bs.areaW, bs.areaH) * 0.4),
            duration = 3.0, maxDuration = 3.0,
            dmgPct = 0.25, tickRate = 0.5, tickCD = 0,
            element = "fire", source = "fire_storm_greater",
        })
    end

    CombatUtils.TriggerShake(bs, CombatUtils.SHAKE_STORM * 1.5)
    table.insert(bs.skillEffects, {
        type = "fire_storm",
        life = 1.0, maxLife = 1.0,
        areaW = bs.areaW, areaH = bs.areaH,
    })
end

-- ============================================================================
-- 陨石 (meteor) — 巨型火焰爆炸
-- ============================================================================
function SkillCaster._Cast_meteor(bs, skillCfg, lv, p)
    local element = "fire"
    local dmgScale = skillCfg.effect(lv) / 100
    local hasPrime = H.HasEnhance("meteor_prime")
    if hasPrime then dmgScale = dmgScale * 1.5 end

    for _, e in ipairs(bs.enemies) do
        if not e.dead then
            H.HitEnemySkill(bs, e, dmgScale, element, {}, bs.areaW * 0.5, bs.areaH * 0.5, CombatUtils.KNOCKBACK_SKILL * 2)
            if hasPrime and not e.dead then
                H.ApplyBurn(e, 0.08, 8.0)
            end
        end
    end

    CombatUtils.TriggerShake(bs, CombatUtils.SHAKE_STORM * 2)
    CombatUtils.PlaySfx("stormWarn", 0.8)
    table.insert(bs.skillEffects, {
        type = "meteor",
        life = 1.5, maxLife = 1.5,
        areaW = bs.areaW, areaH = bs.areaH,
    })
end

end -- Register

return { Register = Register }
