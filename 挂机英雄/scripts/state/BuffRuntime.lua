-- ============================================================================
-- state/BuffRuntime.lua - Buff/Debuff 运行时状态与逻辑
-- 统一管理: debuff施加(9种) + 每帧tick + 正面buff计时(狂热/战意/狂暴)
--           + 护盾管理 + 药水buff系统
-- 通过 Install(GameState) 注入, 调用方式不变: GameState.ApplySlowDebuff(...)
-- ============================================================================

local BuffRuntime = {}

function BuffRuntime.Install(GameState)
    local Config = require("Config")
    local ShieldManager = require("state.ShieldManager")
    local CombatUtils = require("battle.CombatUtils")

    -- 注册护盾上限 = 最大生命值
    ShieldManager.SetMaxGetter(function()
        return GameState.GetMaxHP()
    end)

    -- ========================================================================
    -- 状态初始化 / 重置
    -- ========================================================================

    --- 初始化所有 buff/debuff 状态字段 (GameState.Init 调用)
    GameState.InitBuffState = function()
        GameState.ResetBuffs()
        GameState.potionBuffs = {}
    end

    --- 重置所有战斗 buff/debuff (ResetHP 调用)
    GameState.ResetBuffs = function()
        ShieldManager.Reset()
        GameState.antiHealRate = 0
        GameState.antiHealTimer = 0
        GameState.playerSlowRate = 0
        GameState.playerSlowTimer = 0
        GameState.corrosionStacks = 0
        GameState.corrosionDefReduce = 0
        GameState.corrosionTimer = 0
        GameState.corrosionMaxStacks = 0
        GameState.inkBlindRate = 0
        GameState.inkBlindTimer = 0
        GameState.sandStormCritReduce = 0
        GameState.sandStormTimer = 0
        GameState.venomStackCount = 0
        GameState.venomStackDmgPct = 0
        GameState.venomStackTimer = 0
        GameState.venomStackMaxStacks = 0
        GameState.venomStackTickCD = 0
        GameState.sporeCloudAtkSpdReduce = 0
        GameState.sporeCloudTimer = 0
        -- 灼烧 debuff (第15章: DoT + 攻速减, 叠层)
        GameState.blazeStacks = 0
        GameState.blazeDmgPct = 0
        GameState.blazeAtkSpdReduce = 0
        GameState.blazeMaxStacks = 0
        GameState.blazeTimer = 0
        GameState.blazeTickCD = 0
        GameState.blazeBossAtk = 0
        -- 焚灼 debuff (第15章: 受伤增幅, 叠层)
        GameState.scorchStacks = 0
        GameState.scorchDmgAmp = 0
        GameState.scorchMaxStacks = 0
        GameState.scorchTimer = 0
        -- 浸蚀 debuff (第16章: 暴击降低+火抗降低, 叠层)
        GameState.drenchStacks = 0
        GameState.drenchCritReduce = 0
        GameState.drenchFireResReduce = 0
        GameState.drenchMaxStacks = 0
        GameState.drenchTimer = 0
        -- 潮蚀 debuff (第16章: 水属性受伤增幅, 叠层)
        GameState.tidalCorrosionStacks = 0
        GameState.tidalCorrosionDmgAmp = 0
        GameState.tidalCorrosionMaxStacks = 0
        GameState.tidalCorrosionTimer = 0
        -- 元素附着
        GameState.attachedElement = nil
        GameState.attachedElementTimer = 0
        -- 寒冰甲状态
        GameState.shieldTimer = 0
        GameState.iceArmorActive = false
        GameState.iceArmorFrostbiteTimer = 0
        GameState.iceArmorManaSpent = 0
        -- 暴风雪状态
        GameState.blizzardActive = false
        GameState.blizzardTimer = 0
        -- 深度冻结 CC 免疫
        GameState.ccImmune = false
        GameState.ccImmuneTimer = 0
        GameState._deepFreezeActive = false
        GameState._deepFreezeBurstPct = 0
        GameState._deepFreezeRadius = 0
        GameState._deepFreezeBs = nil
    end

    -- ========================================================================
    -- 护盾管理
    -- ========================================================================

    --- 添加护盾 (走护盾管线: base × SHLD%, 不受 HEAL% 和 antiHeal 影响)
    --- @param baseShield number 基础护盾值
    --- @param sourceId? string 护盾来源标识，默认 "passive"
    --- @return number 实际获得护盾量
    GameState.AddShield = function(baseShield, sourceId)
        if GameState.playerDead then return 0 end
        local shldMul = GameState.GetShieldMul()
        local actual = math.floor(baseShield * shldMul)
        local maxShield = GameState.GetMaxHP() * 0.5  -- 护盾上限 = HP × 50%
        local before = ShieldManager.GetTotal()
        local room = math.max(0, maxShield - before)
        actual = math.min(actual, room)
        if actual > 0 then
            ShieldManager.Add(sourceId or "passive", actual)
        end
        return actual
    end

    --- 击杀触发护盾
    GameState.OnKillShield = function()
        if GameState.playerDead then return end
        local base = Config.SHIELD.onKillBase + GameState.player.level * Config.SHIELD.onKillPerLevel
        GameState.AddShield(base)
    end

    -- ========================================================================
    -- 深度冻结: CC 免疫激活 / 到期爆炸
    -- ========================================================================

    --- 激活深度冻结 (IceSkills 调用)
    --- @param duration number 免疫持续时间
    --- @param burstPct number 结束爆炸伤害% (小数)
    --- @param radius number AOE 半径
    --- @param bs table battleState 引用
    GameState.ActivateDeepFreeze = function(duration, burstPct, radius, bs)
        GameState.ccImmune = true
        GameState.ccImmuneTimer = duration
        GameState._deepFreezeActive = true
        GameState._deepFreezeBurstPct = burstPct
        GameState._deepFreezeRadius = radius
        GameState._deepFreezeBs = bs
    end

    -- ========================================================================
    -- Debuff 施加 (9种, 均经过韧性衰减)
    -- ========================================================================

    --- 施加减速 debuff
    --- @param slowRate number 减速比率 (0~1)
    --- @param duration number 持续时间(秒)
    GameState.ApplySlowDebuff = function(slowRate, duration)
        if GameState.playerDead then return end
        if GameState.ccImmune then return end  -- 深度冻结免疫
        local resist = GameState.GetDebuffResist()
        local durFactor = Config.TENACITY.durFactor
        local actualSlow = slowRate * (1 - resist)
        local actualDur  = duration * (1 - resist * durFactor)
        if actualSlow < 0.01 then return end
        if actualSlow > GameState.playerSlowRate or GameState.playerSlowTimer <= 0 then
            GameState.playerSlowRate = actualSlow
            GameState.playerSlowTimer = actualDur
        end
    end

    --- 施加减疗 debuff
    --- @param rate number 减疗比率
    --- @param duration number 持续时间(秒)
    GameState.ApplyAntiHealDebuff = function(rate, duration)
        if GameState.playerDead then return end
        local resist = GameState.GetDebuffResist()
        local durFactor = Config.TENACITY.durFactor
        local actualRate = rate * (1 - resist)
        local actualDur  = duration * (1 - resist * durFactor)
        if actualRate < 0.01 then return end
        if actualRate > GameState.antiHealRate or GameState.antiHealTimer <= 0 then
            GameState.antiHealRate = actualRate
            GameState.antiHealTimer = actualDur
        end
    end

    --- 施加腐蚀 debuff (叠加制, 降低DEF)
    --- @param defReducePct number 每层DEF降低比率
    --- @param maxStacks number 最大层数
    --- @param duration number 持续时间(秒)
    GameState.ApplyCorrosionDebuff = function(defReducePct, maxStacks, duration)
        if GameState.playerDead then return end
        if GameState.ccImmune then return end  -- 深度冻结免疫
        local resist = GameState.GetDebuffResist()
        local durFactor = Config.TENACITY.durFactor
        local actualReduce = defReducePct * (1 - resist)
        local actualDur    = duration * (1 - resist * durFactor)
        GameState.corrosionDefReduce = actualReduce
        GameState.corrosionMaxStacks = maxStacks
        GameState.corrosionTimer = actualDur
        if GameState.corrosionStacks < maxStacks then
            GameState.corrosionStacks = GameState.corrosionStacks + 1
        end
    end

    --- 施加墨汁致盲 debuff (降低ATK)
    --- @param atkReducePct number ATK降低比率
    --- @param duration number 持续时间(秒)
    GameState.ApplyInkBlindDebuff = function(atkReducePct, duration)
        if GameState.playerDead then return end
        if GameState.ccImmune then return end  -- 深度冻结免疫
        local resist = GameState.GetDebuffResist()
        local durFactor = Config.TENACITY.durFactor
        local actualReduce = atkReducePct * (1 - resist)
        local actualDur    = duration * (1 - resist * durFactor)
        if actualReduce < 0.01 then return end
        if actualReduce > GameState.inkBlindRate or GameState.inkBlindTimer <= 0 then
            GameState.inkBlindRate = actualReduce
            GameState.inkBlindTimer = actualDur
        end
    end

    --- 施加沙暴 debuff (降低暴击率)
    --- @param critReducePct number 暴击率降低值
    --- @param duration number 持续时间(秒)
    GameState.ApplySandStormDebuff = function(critReducePct, duration)
        if GameState.playerDead then return end
        local resist = GameState.GetDebuffResist()
        local durFactor = Config.TENACITY.durFactor
        local actualReduce = critReducePct * (1 - resist)
        local actualDur    = duration * (1 - resist * durFactor)
        if actualReduce < 0.01 then return end
        if actualReduce > GameState.sandStormCritReduce or GameState.sandStormTimer <= 0 then
            GameState.sandStormCritReduce = actualReduce
            GameState.sandStormTimer = actualDur
        end
    end

    --- 施加毒蛊叠加 debuff (每层按%maxHP每秒持续伤害)
    --- @param dmgPctPerStack number 每层每秒伤害(%maxHP)
    --- @param maxStacks number 最大叠加层数
    --- @param duration number 持续时间(秒)
    GameState.ApplyVenomStackDebuff = function(dmgPctPerStack, maxStacks, duration)
        if GameState.playerDead then return end
        local resist = GameState.GetDebuffResist()
        local durFactor = Config.TENACITY.durFactor
        local actualDmgPct = dmgPctPerStack * (1 - resist)
        local actualDur    = duration * (1 - resist * durFactor)
        if actualDmgPct < 0.001 then return end
        GameState.venomStackDmgPct = actualDmgPct
        GameState.venomStackMaxStacks = maxStacks
        GameState.venomStackTimer = actualDur
        if GameState.venomStackCount < maxStacks then
            GameState.venomStackCount = GameState.venomStackCount + 1
        end
    end

    --- 施加孢子云 debuff (降低攻速)
    --- @param atkSpeedReducePct number 攻速降低比率
    --- @param duration number 持续时间(秒)
    GameState.ApplySporeCloudDebuff = function(atkSpeedReducePct, duration)
        if GameState.playerDead then return end
        if GameState.ccImmune then return end  -- 深度冻结免疫
        local resist = GameState.GetDebuffResist()
        local durFactor = Config.TENACITY.durFactor
        local actualReduce = atkSpeedReducePct * (1 - resist)
        local actualDur    = duration * (1 - resist * durFactor)
        if actualReduce < 0.01 then return end
        if actualReduce > GameState.sporeCloudAtkSpdReduce or GameState.sporeCloudTimer <= 0 then
            GameState.sporeCloudAtkSpdReduce = actualReduce
            GameState.sporeCloudTimer = actualDur
        end
    end

    --- 施加灼烧 debuff (叠加制, 每层DoT + 攻速降低) (第15章)
    --- @param dmgPct number 每层每秒伤害(%bossATK)
    --- @param atkSpdReduce number 每层攻速降低比率
    --- @param maxStacks number 最大叠加层数
    --- @param duration number 持续时间(秒)
    --- @param bossAtk number|nil Boss ATK快照
    GameState.ApplyBlazeDebuff = function(dmgPct, atkSpdReduce, maxStacks, duration, bossAtk)
        if GameState.playerDead then return end
        local resist = GameState.GetDebuffResist()
        local durFactor = Config.TENACITY.durFactor
        local actualDmgPct = dmgPct * (1 - resist)
        local actualSpdReduce = atkSpdReduce * (1 - resist)
        local actualDur = duration * (1 - resist * durFactor)
        if actualDmgPct < 0.001 and actualSpdReduce < 0.001 then return end
        GameState.blazeDmgPct = actualDmgPct
        GameState.blazeAtkSpdReduce = actualSpdReduce
        GameState.blazeMaxStacks = maxStacks
        GameState.blazeTimer = actualDur
        if bossAtk then
            GameState.blazeBossAtk = bossAtk
        end
        if GameState.blazeStacks < maxStacks then
            GameState.blazeStacks = GameState.blazeStacks + 1
        end
    end

    --- 施加焚灼 debuff (叠加制, 每层增加受到伤害%) (第15章)
    --- @param dmgAmpPct number 每层受伤增幅比率
    --- @param maxStacks number 最大叠加层数
    --- @param duration number 持续时间(秒)
    GameState.ApplyScorchDebuff = function(dmgAmpPct, maxStacks, duration)
        if GameState.playerDead then return end
        local resist = GameState.GetDebuffResist()
        local durFactor = Config.TENACITY.durFactor
        local actualAmp = dmgAmpPct * (1 - resist)
        local actualDur = duration * (1 - resist * durFactor)
        if actualAmp < 0.001 then return end
        GameState.scorchDmgAmp = actualAmp
        GameState.scorchMaxStacks = maxStacks
        GameState.scorchTimer = actualDur
        if GameState.scorchStacks < maxStacks then
            GameState.scorchStacks = GameState.scorchStacks + 1
        end
    end

    --- 施加浸蚀 debuff (叠加制, 每层: 暴击-2.5% + 火抗-4%) (第16章)
    --- @param stacksToAdd number 本次叠加层数
    --- @param maxStacks number 最大叠加层数
    --- @param duration number 持续时间(秒)
    GameState.ApplyDrenchDebuff = function(stacksToAdd, maxStacks, duration)
        if GameState.playerDead then return end
        local resist = GameState.GetDebuffResist()
        local durFactor = Config.TENACITY.durFactor
        local actualDur = duration * (1 - resist * durFactor)
        -- 每层效果常量 (经韧性衰减)
        local critPerStack = 0.025 * (1 - resist)
        local fireResPerStack = 0.04 * (1 - resist)
        if critPerStack < 0.001 then return end
        GameState.drenchCritReduce = critPerStack
        GameState.drenchFireResReduce = fireResPerStack
        GameState.drenchMaxStacks = maxStacks
        GameState.drenchTimer = actualDur
        local newStacks = math.min(GameState.drenchStacks + stacksToAdd, maxStacks)
        GameState.drenchStacks = newStacks
    end

    --- 施加潮蚀 debuff (叠加制, 每层: 水属性受伤+3.5%) (第16章)
    --- @param stacksToAdd number 本次叠加层数
    --- @param maxStacks number 最大叠加层数
    --- @param duration number 持续时间(秒)
    GameState.ApplyTidalCorrosionDebuff = function(stacksToAdd, maxStacks, duration)
        if GameState.playerDead then return end
        local resist = GameState.GetDebuffResist()
        local durFactor = Config.TENACITY.durFactor
        local actualAmp = 0.035 * (1 - resist)
        local actualDur = duration * (1 - resist * durFactor)
        if actualAmp < 0.001 then return end
        GameState.tidalCorrosionDmgAmp = actualAmp
        GameState.tidalCorrosionMaxStacks = maxStacks
        GameState.tidalCorrosionTimer = actualDur
        local newStacks = math.min(GameState.tidalCorrosionStacks + stacksToAdd, maxStacks)
        GameState.tidalCorrosionStacks = newStacks
    end

    -- ========================================================================
    -- Debuff 每帧 Tick
    -- ========================================================================

    --- 每帧更新 debuff 计时器
    GameState.UpdateDebuffs = function(dt)
        -- 减疗 debuff
        if GameState.antiHealTimer > 0 then
            GameState.antiHealTimer = GameState.antiHealTimer - dt
            if GameState.antiHealTimer <= 0 then
                GameState.antiHealRate = 0
                GameState.antiHealTimer = 0
            end
        end
        -- 减速 debuff
        if GameState.playerSlowTimer > 0 then
            GameState.playerSlowTimer = GameState.playerSlowTimer - dt
            if GameState.playerSlowTimer <= 0 then
                GameState.playerSlowRate = 0
                GameState.playerSlowTimer = 0
            end
        end
        -- 腐蚀 debuff
        if GameState.corrosionTimer > 0 then
            GameState.corrosionTimer = GameState.corrosionTimer - dt
            if GameState.corrosionTimer <= 0 then
                GameState.corrosionStacks = 0
                GameState.corrosionDefReduce = 0
                GameState.corrosionTimer = 0
                GameState.corrosionMaxStacks = 0
            end
        end
        -- 墨汁致盲 debuff
        if GameState.inkBlindTimer > 0 then
            GameState.inkBlindTimer = GameState.inkBlindTimer - dt
            if GameState.inkBlindTimer <= 0 then
                GameState.inkBlindRate = 0
                GameState.inkBlindTimer = 0
            end
        end
        -- 沙暴 debuff
        if GameState.sandStormTimer > 0 then
            GameState.sandStormTimer = GameState.sandStormTimer - dt
            if GameState.sandStormTimer <= 0 then
                GameState.sandStormCritReduce = 0
                GameState.sandStormTimer = 0
            end
        end
        -- 毒蛊叠加 debuff
        if GameState.venomStackTimer > 0 and GameState.venomStackCount > 0 then
            GameState.venomStackTimer = GameState.venomStackTimer - dt
            if GameState.venomStackTimer <= 0 then
                GameState.venomStackCount = 0
                GameState.venomStackDmgPct = 0
                GameState.venomStackTimer = 0
                GameState.venomStackMaxStacks = 0
                GameState.venomStackTickCD = 0
            else
                GameState.venomStackTickCD = GameState.venomStackTickCD - dt
                if GameState.venomStackTickCD <= 0 then
                    GameState.venomStackTickCD = 1.0
                    local maxHP = GameState.GetMaxHP()
                    local venomDmg = math.floor(maxHP * GameState.venomStackDmgPct * GameState.venomStackCount)
                    if venomDmg > 0 then
                        GameState.DamagePlayer(venomDmg)
                    end
                end
            end
        end
        -- 孢子云 debuff
        if GameState.sporeCloudTimer > 0 then
            GameState.sporeCloudTimer = GameState.sporeCloudTimer - dt
            if GameState.sporeCloudTimer <= 0 then
                GameState.sporeCloudAtkSpdReduce = 0
                GameState.sporeCloudTimer = 0
            end
        end
        -- 灼烧 debuff (第15章)
        if GameState.blazeTimer > 0 and GameState.blazeStacks > 0 then
            GameState.blazeTimer = GameState.blazeTimer - dt
            if GameState.blazeTimer <= 0 then
                GameState.blazeStacks = 0
                GameState.blazeDmgPct = 0
                GameState.blazeAtkSpdReduce = 0
                GameState.blazeTimer = 0
                GameState.blazeMaxStacks = 0
                GameState.blazeTickCD = 0
                GameState.blazeBossAtk = 0
            else
                GameState.blazeTickCD = GameState.blazeTickCD - dt
                if GameState.blazeTickCD <= 0 then
                    GameState.blazeTickCD = 1.0
                    local blazeDmg = math.floor(GameState.blazeBossAtk * GameState.blazeDmgPct * GameState.blazeStacks)
                    if blazeDmg > 0 then
                        GameState.DamagePlayer(blazeDmg)
                    end
                end
            end
        end
        -- 焚灼 debuff (第15章)
        if GameState.scorchTimer > 0 and GameState.scorchStacks > 0 then
            GameState.scorchTimer = GameState.scorchTimer - dt
            if GameState.scorchTimer <= 0 then
                GameState.scorchStacks = 0
                GameState.scorchDmgAmp = 0
                GameState.scorchTimer = 0
                GameState.scorchMaxStacks = 0
            end
        end
        -- 浸蚀 debuff (第16章)
        if GameState.drenchTimer > 0 and GameState.drenchStacks > 0 then
            GameState.drenchTimer = GameState.drenchTimer - dt
            if GameState.drenchTimer <= 0 then
                GameState.drenchStacks = 0
                GameState.drenchCritReduce = 0
                GameState.drenchFireResReduce = 0
                GameState.drenchTimer = 0
                GameState.drenchMaxStacks = 0
            end
        end
        -- 潮蚀 debuff (第16章)
        if GameState.tidalCorrosionTimer > 0 and GameState.tidalCorrosionStacks > 0 then
            GameState.tidalCorrosionTimer = GameState.tidalCorrosionTimer - dt
            if GameState.tidalCorrosionTimer <= 0 then
                GameState.tidalCorrosionStacks = 0
                GameState.tidalCorrosionDmgAmp = 0
                GameState.tidalCorrosionTimer = 0
                GameState.tidalCorrosionMaxStacks = 0
            end
        end
        -- 元素附着衰减
        if GameState.attachedElementTimer > 0 then
            GameState.attachedElementTimer = GameState.attachedElementTimer - dt
            if GameState.attachedElementTimer <= 0 then
                GameState.attachedElement = nil
                GameState.attachedElementTimer = 0
            end
        end
        -- 寒冰甲屏障持续时间
        if GameState.shieldTimer > 0 then
            GameState.shieldTimer = GameState.shieldTimer - dt
            if GameState.shieldTimer <= 0 then
                GameState.shieldTimer = 0
                ShieldManager.Remove("ice_armor")
                GameState.iceArmorActive = false
                GameState.iceArmorFrostbiteTimer = 0
                GameState.iceArmorManaSpent = 0
            end
        end
        -- 火焰护盾持续时间
        if GameState.flameShieldTimer and GameState.flameShieldTimer > 0 then
            GameState.flameShieldTimer = GameState.flameShieldTimer - dt
            if GameState.flameShieldTimer <= 0 then
                GameState.flameShieldTimer = 0
                ShieldManager.Remove("flame_shield")
            end
        end
        -- 暴风雪持续时间
        if GameState.blizzardTimer and GameState.blizzardTimer > 0 then
            GameState.blizzardTimer = GameState.blizzardTimer - dt
            if GameState.blizzardTimer <= 0 then
                GameState.blizzardTimer = 0
                GameState.blizzardActive = false
            end
        end
        -- 深度冻结 CC 免疫计时
        if GameState.ccImmuneTimer > 0 then
            GameState.ccImmuneTimer = GameState.ccImmuneTimer - dt
            if GameState.ccImmuneTimer <= 0 then
                GameState.ccImmune = false
                GameState.ccImmuneTimer = 0
                -- 深度冻结到期: 结束爆炸
                if GameState._deepFreezeActive then
                    GameState._deepFreezeActive = false
                    local bs = GameState._deepFreezeBs
                    local p = bs and bs.playerBattle
                    if bs and p then
                        local px, py = p.x, p.y
                        local burstPct = GameState._deepFreezeBurstPct
                        local radius = GameState._deepFreezeRadius
                        local totalAtk = GameState.GetTotalAtk()
                        local burstDmg = math.floor(totalAtk * burstPct)
                        local DamageFormula = require("battle.DamageFormula")
                        local H = require("battle.skills.Helpers")
                        local Particles = require("battle.Particles")
                        for _, e in ipairs(bs.enemies) do
                            if not e.dead then
                                local dx, dy = e.x - px, e.y - py
                                if math.sqrt(dx * dx + dy * dy) <= radius then
                                    local ctx = DamageFormula.BuildContext({
                                        target    = e,
                                        bs        = bs,
                                        baseDmg   = burstDmg,
                                        damageTag = "skill",
                                        element   = "ice",
                                    })
                                    local finalDmg = DamageFormula.Calculate(ctx)
                                    local EnemySys = require("battle.EnemySystem")
                                    finalDmg = EnemySys.ApplyDamageReduction(e, finalDmg)
                                    EnemySys.ApplyDamage(e, finalDmg, bs)
                                    GameState.LifeStealHeal(finalDmg, Config.LIFESTEAL.efficiency.fireZone)
                                    Particles.SpawnDmgText(bs.particles, e.x, e.y - 10, finalDmg, false, false, { 100, 200, 255 })
                                end
                            end
                        end
                        -- 爆炸视觉效果
                        CombatUtils.TriggerShake(bs, CombatUtils.SHAKE_BLAST)
                        CombatUtils.PlaySfx("frostImpact", 0.8)
                        table.insert(bs.skillEffects, {
                            type = "deep_freeze_burst",
                            x = px, y = py,
                            radius = radius,
                            life = 0.8, maxLife = 0.8,
                        })
                        -- 初级深度冻结: 结束时获得屏障
                        if H.HasEnhance("deep_freeze_prime") then
                            local shieldBase = GameState.GetMaxHP() * 0.50
                            GameState.AddShield(shieldBase, "deep_freeze")
                        end
                    end
                    GameState._deepFreezeBs = nil
                end
            end
        end
        -- 神秘寒冰甲: 周期性冻伤 (每1.5秒)
        if GameState.iceArmorActive and GameState._hasIceArmorMystical then
            GameState.iceArmorFrostbiteTimer = (GameState.iceArmorFrostbiteTimer or 0) + dt
            if GameState.iceArmorFrostbiteTimer >= 1.5 then
                GameState.iceArmorFrostbiteTimer = GameState.iceArmorFrostbiteTimer - 1.5
                -- 对近距离敌人施加冻伤 (实际施加在 BattleSystem tick 中处理)
                GameState._iceArmorFrostbitePending = true
            end
        end
    end

    -- ========================================================================
    -- 药水 Buff 系统
    -- ========================================================================

    --- 购买药水 (叠加时间)
    --- @param typeId string "exp"|"hp"|"atk"|"luck"
    --- @param sizeIdx number 1=小 2=中 3=大
    --- @return boolean success, string|nil error
    GameState.BuyPotion = function(typeId, sizeIdx)
        local sizeCfg = Config.POTION_SIZES[sizeIdx]
        if not sizeCfg then return false, "无效尺寸" end
        local baseCost = Config.POTION_BASE_COST[typeId]
        if not baseCost then return false, "无效类型" end

        local cost = math.floor(baseCost * sizeCfg.costMul)
        if not GameState.SpendGold(cost) then return false, "金币不足" end

        local baseValue = Config.POTION_VALUES[typeId] or 0
        local hpMul = Config.HP_POTION_MUL and Config.HP_POTION_MUL[sizeCfg.id]
        local value = baseValue * ((typeId == "hp" and hpMul) and hpMul or sizeCfg.valueMul)
        local duration = sizeCfg.duration

        local queue = GameState.potionBuffs[typeId]
        if not queue or type(queue) ~= "table" or queue.timer then
            if queue and queue.timer and queue.timer > 0 then
                queue = { { timer = queue.timer, value = queue.value or 0 } }
            else
                queue = {}
            end
            GameState.potionBuffs[typeId] = queue
        end

        local merged = false
        for _, entry in ipairs(queue) do
            if math.abs(entry.value - value) < 0.001 then
                entry.timer = entry.timer + duration
                merged = true
                break
            end
        end

        if not merged then
            table.insert(queue, { timer = duration, value = value })
        end

        table.sort(queue, function(a, b) return a.value > b.value end)

        return true, nil
    end

    --- 更新药水buff计时器 (每帧调用)
    GameState.UpdatePotionBuffs = function(dt)
        for typeId, queue in pairs(GameState.potionBuffs) do
            if type(queue) == "table" and queue.timer then
                if queue.timer > 0 then
                    queue = { { timer = queue.timer, value = queue.value or 0 } }
                else
                    queue = {}
                end
                GameState.potionBuffs[typeId] = queue
            end

            if #queue > 0 then
                local head = queue[1]
                head.timer = head.timer - dt
                if head.timer <= 0 then
                    table.remove(queue, 1)
                end
            end
        end
    end

    --- 获取药水buff效果值 (0 = 无buff)
    GameState.GetPotionBuff = function(typeId)
        local queue = GameState.potionBuffs[typeId]
        if type(queue) == "table" and not queue.timer and #queue > 0 then
            local head = queue[1]
            if head.timer > 0 then return head.value end
        elseif type(queue) == "table" and queue.timer and queue.timer > 0 then
            return queue.value
        end
        return 0
    end

    --- 获取药水剩余总时间
    GameState.GetPotionTimer = function(typeId)
        local queue = GameState.potionBuffs[typeId]
        if type(queue) == "table" and not queue.timer then
            local total = 0
            for _, entry in ipairs(queue) do
                total = total + math.max(0, entry.timer)
            end
            return total
        elseif type(queue) == "table" and queue.timer then
            return math.max(0, queue.timer)
        end
        return 0
    end

    --- 获取指定档位剩余时间
    --- @param typeId string
    --- @param value number 药水效果值
    --- @return number 该档位剩余秒数
    GameState.GetPotionTierTimer = function(typeId, value)
        local queue = GameState.potionBuffs[typeId]
        if type(queue) == "table" and not queue.timer then
            for _, entry in ipairs(queue) do
                if math.abs(entry.value - value) < 0.001 and entry.timer > 0 then
                    return entry.timer
                end
            end
        end
        return 0
    end

    --- 格式化剩余时间显示
    GameState.FormatPotionTimer = function(typeId)
        local secs = GameState.GetPotionTimer(typeId)
        if secs <= 0 then return "" end
        local h = math.floor(secs / 3600)
        local m = math.floor((secs % 3600) / 60)
        local s = math.floor(secs % 60)
        if h > 0 then
            return string.format("%d:%02d:%02d", h, m, s)
        else
            return string.format("%d:%02d", m, s)
        end
    end
    -- ========================================================================
    -- 条件修饰器注册 (buff/debuff, 有 conditionFn)
    -- ========================================================================

    local SM = require("state.StatModifiers")

    -- ---- ATK 修饰器 ----

    -- 铁壁要塞4件: 护盾溢出→ATK加成 (延迟加载BuffManager)
    SM.Register({
        id = "set_ironBastion_atk", stat = "atk", type = "pctPool",
        valueFn = function()
            local ok, BM = pcall(require, "battle.BuffManager")
            if ok and BM.GetIronBastionAtkBonus then
                return BM.GetIronBastionAtkBonus()
            end
            return 0
        end,
    })

    -- 墨汁致盲: -inkBlindRate% ATK
    SM.Register({
        id = "debuff_inkBlind", stat = "atk", type = "pctReduce",
        valueFn = function() return GameState.inkBlindRate or 0 end,
        conditionFn = function() return (GameState.inkBlindTimer or 0) > 0 end,
    })

    -- ---- AtkSpeed 修饰器 ----

    -- 迅捷猎手6件: 连击风暴攻速 (延迟加载BuffManager)
    SM.Register({
        id = "set_swiftHunter_spd", stat = "atkSpeed", type = "pctMul",
        valueFn = function()
            local ok, BM = pcall(require, "battle.BuffManager")
            if ok and BM.GetSwiftHunterAtkSpeedBonus then
                return BM.GetSwiftHunterAtkSpeedBonus()
            end
            return 0
        end,
    })

    -- 裂变之力6件: 脉冲后攻速 (延迟加载BuffManager)
    SM.Register({
        id = "set_fissionForce_spd", stat = "atkSpeed", type = "pctMul",
        valueFn = function()
            local ok, BM = pcall(require, "battle.BuffManager")
            if ok and BM.GetFissionForceAtkSpeedBonus then
                return BM.GetFissionForceAtkSpeedBonus()
            end
            return 0
        end,
    })

    -- 减速debuff: x(1-slowRate)
    SM.Register({
        id = "debuff_slow", stat = "atkSpeed", type = "pctReduce",
        valueFn = function() return GameState.playerSlowRate or 0 end,
        conditionFn = function() return (GameState.playerSlowTimer or 0) > 0 end,
    })

    -- 孢子云debuff: x(1-reduce)
    SM.Register({
        id = "debuff_sporeCloud", stat = "atkSpeed", type = "pctReduce",
        valueFn = function() return GameState.sporeCloudAtkSpdReduce or 0 end,
        conditionFn = function() return (GameState.sporeCloudTimer or 0) > 0 end,
    })

    -- 灼烧debuff: 叠层×每层攻速降低
    SM.Register({
        id = "debuff_blaze_spd", stat = "atkSpeed", type = "pctReduce",
        valueFn = function()
            return (GameState.blazeStacks or 0) * (GameState.blazeAtkSpdReduce or 0)
        end,
        conditionFn = function()
            return (GameState.blazeTimer or 0) > 0 and (GameState.blazeStacks or 0) > 0
        end,
    })

    -- ---- Crit 修饰器 ----

    -- 沙暴debuff: 降低暴击率
    SM.Register({
        id = "debuff_sandStorm", stat = "crit", type = "flatSub",
        valueFn = function() return GameState.sandStormCritReduce or 0 end,
        conditionFn = function() return (GameState.sandStormTimer or 0) > 0 end,
    })

    -- 浸蚀debuff: 叠层×每层暴击降低 (第16章)
    SM.Register({
        id = "debuff_drench", stat = "crit", type = "flatSub",
        valueFn = function()
            return (GameState.drenchStacks or 0) * (GameState.drenchCritReduce or 0)
        end,
        conditionFn = function()
            return (GameState.drenchTimer or 0) > 0 and (GameState.drenchStacks or 0) > 0
        end,
    })
end

return BuffRuntime
