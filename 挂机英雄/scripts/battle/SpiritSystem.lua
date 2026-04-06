-- ============================================================================
-- battle/SpiritSystem.lua - 元素精灵 AI (v3.0 D4模型, 无反应)
-- ============================================================================

local Config            = require("Config")
local GameState         = require("GameState")
local Particles         = require("battle.Particles")
local CombatUtils       = require("battle.CombatUtils")
local DamageFormula     = require("battle.DamageFormula")

local SpiritSystem = {}

-- ============================================================================
-- 元素精灵 AI
-- ============================================================================

function SpiritSystem.UpdateElementSpirits(dt, bs)
    local p = bs.playerBattle

    for i = #GameState.spirits, 1, -1 do
        local sp = GameState.spirits[i]
        sp.timer = sp.timer - dt
        if sp.timer <= 0 then
            table.remove(GameState.spirits, i)
        else
            -- 精灵绕玩家公转
            sp.orbitAngle = sp.orbitAngle + dt * 2.5
            local orbitR = 40
            sp.x = p.x + math.cos(sp.orbitAngle) * orbitR
            sp.y = p.y + math.sin(sp.orbitAngle) * orbitR

            -- 攻击逻辑
            sp.atkCD = sp.atkCD - dt
            if sp.atkCD <= 0 then
                sp.atkCD = sp.atkInterval
                -- 找范围内最近敌人
                local bestE, bestD = nil, math.huge
                for _, e in ipairs(bs.enemies) do
                    if not e.dead then
                        local dx, dy = e.x - sp.x, e.y - sp.y
                        local dist = math.sqrt(dx * dx + dy * dy)
                        if dist <= sp.atkRange and dist < bestD then
                            bestE = e
                            bestD = dist
                        end
                    end
                end

                if bestE then
                    -- 六桶管线 (召唤物 = 技能伤害, 不暴击)
                    local ctx = DamageFormula.BuildContext({
                        target     = bestE,
                        bs         = bs,
                        multiplier = sp.dmgScale,
                        damageTag  = "skill",
                        element    = sp.element,
                        forceCrit  = false,
                    })
                    local finalDmg = DamageFormula.Calculate(ctx)

                    require("battle.EnemySystem").ApplyDamage(bestE, finalDmg, bs)
                    GameState.LifeStealHeal(finalDmg, Config.LIFESTEAL.efficiency.summon)
                    Particles.SpawnDmgText(bs.particles, bestE.x, bestE.y - (bestE.radius or 16) - 5, finalDmg, false, false, { 80, 180, 255 })
                    CombatUtils.SpawnProjectile(bs, sp.x, sp.y, bestE.x, bestE.y, false)
                end
            end
        end
    end
end

return SpiritSystem
