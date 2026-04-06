-- ============================================================================
-- state/StatCalc.lua - 属性计算模块 (从 GameState.lua 提取)
-- ============================================================================
-- P1 重构: 旧 10 属性加点 → 4 核心属性 (STR/DEX/INT/WIL)
-- 所有 Get* 函数通过 getCoreAttrBonus(targetStat) 获取核心属性贡献
-- ============================================================================

local StatCalc = {}

function StatCalc.Install(GameState)
    local Config = require("Config")
    local StatDefs = require("state.StatDefs")
    local SM = require("state.StatModifiers")

    -- 称号加成 (延迟加载, 避免循环依赖)
    local TitleSystem_ = nil
    local function getTitleBonus(statKey)
        if not TitleSystem_ then
            local ok, ts = pcall(require, "TitleSystem")
            if ok then TitleSystem_ = ts end
        end
        if TitleSystem_ then return TitleSystem_.GetBonus(statKey) end
        return 0
    end

    -- ========================================================================
    -- 套装BUFF运行时状态 (初始化)
    -- ========================================================================

    GameState.setBuff = {}    -- { [buffId] = { timer = N, ... } }
    GameState.setBuffCD = {}  -- { [buffId] = remainingCD }

    -- ========================================================================
    -- 装备属性求和辅助 (遍历主词条+所有副词条)
    -- ========================================================================

    --- 装备属性求和辅助 (P2: 从统一 affixes[] 收集 + 宝石属性)
    local function equipSum(stat)
        local total = 0
        for _, item in pairs(GameState.equipment) do
            if item then
                -- P2: 统一词缀
                if item.affixes then
                    for _, aff in ipairs(item.affixes) do
                        if aff.id == stat then
                            total = total + (aff.value or 0)
                        end
                    end
                end
                -- 宝石属性
                if item.gems and item.sockets then
                    local gemStats = GameState.GetGemStats(item)
                    if gemStats[stat] then
                        total = total + gemStats[stat]
                    end
                end
            end
        end
        return total
    end

    -- 暴露给其他子模块 (Combat.lua 需要)
    GameState._equipSum = equipSum

    --- 获取最高通关章节 (用于 attrScale 计算, 避免回退章节时属性缩水)
    local function getMaxChapter()
        return (GameState.records and GameState.records.maxChapter) or (GameState.stage and GameState.stage.chapter) or 1
    end

    -- ========================================================================
    -- 核心属性加成查询 (统一入口)
    -- ========================================================================

    --- 查询核心属性对指定目标属性的加成总和
    --- 内部调用 StatDefs.CalcCoreBonus, 自动传入 attrScale 和 allocatedPoints
    ---@param targetStat string 目标属性ID (如 "def", "dodge", "crit", "hpPct", "skillDmg" 等)
    ---@return number
    local function getCoreAttrBonus(targetStat)
        local attrScale = Config.GetAttrScale(getMaxChapter())
        return StatDefs.CalcCoreBonus(targetStat, attrScale, GameState.player.allocatedPoints)
    end

    -- ========================================================================
    -- 六大属性: ATK, SPD, CRT, CDM, RNG, LCK
    -- ========================================================================

    --- 总攻击力 = (基础 + 装备) × 修饰器
    --- P1: 攻击力不再来自加点, 纯装备+技能+称号
    GameState.GetTotalAtk = function()
        local p = GameState.player
        local base = p.baseAtk + equipSum("atk")
        return math.floor(SM.Apply("atk", base))
    end

    --- 攻击药水伤害增幅倍率 (1.0 = 无增幅, 1.05 = +5%)
    GameState.GetAtkPotionMul = function()
        local v = GameState.GetPotionBuff("atk")
        if v > 0 then return 1 + v end
        return 1.0
    end

    --- 攻速渐近线递减: 实际 = 1 + cap × Δ/(Δ+K), cap随章节缩放
    local function applyAtkSpeedDR(rawSpeed)
        local dr = Config.ATK_SPEED_DR
        local delta = rawSpeed - 1.0
        if delta <= 0 then return rawSpeed end
        local cap = dr.baseCap * Config.GetAttrScale(getMaxChapter())
        return 1.0 + cap * delta / (delta + dr.K)
    end

    --- 原始攻速 (装备+套装乘算, 递减前)
    --- P1: 攻速不再来自加点
    GameState.GetAtkSpeedRaw = function()
        local p = GameState.player
        local base = p.atkSpeed + equipSum("spd")
        -- 套装被动乘算 (如 swift_hunter 2件 +12%)
        local mulBonus = GameState.GetSetBonusStatsMul()
        if mulBonus.atkSpeed then
            base = base * (1 + mulBonus.atkSpeed)
        end
        return base
    end

    --- 攻击速度 (渐近线递减 + 修饰器)
    --- 流程: 原始基础值 → 渐近线递减 → SM.Apply(buff乘+debuff减) → 下限0.15
    GameState.GetAtkSpeed = function()
        local effective = applyAtkSpeedDR(GameState.GetAtkSpeedRaw())
        effective = SM.Apply("atkSpeed", effective)
        return math.max(0.15, effective)
    end

    --- 暴击率 (DEX 职业效果 + 装备 + 技能 + 称号)
    GameState.GetCritRateRaw = function()
        local p = GameState.player
        local base = p.critRate + getCoreAttrBonus("crit") + equipSum("crit")
        -- 奥术感知: 每级+3%暴击率
        local senseLv = GameState.GetSkillLevel("arcane_sense")
        base = base + senseLv * 0.03
        -- 称号加成: 暴击率
        base = base + getTitleBonus("crit")
        return base
    end

    --- 实际暴击率 (上限100%, debuff经SM修饰器)
    GameState.GetCritRate = function()
        local rate = GameState.GetCritRateRaw()
        rate = SM.Apply("crit", rate)
        return math.max(0, math.min(1.0, rate))
    end

    --- 暴击率溢出部分 (超过100%的部分)
    GameState.GetCritOverflow = function()
        return math.max(0, GameState.GetCritRateRaw() - 1.0)
    end

    --- 技能冷却倍率 (渐近线递减, 无硬顶)
    --- P1: CDR 来自 WIL 职业效果 + 天赋 + 装备 + 套装
    GameState.GetSkillCdMul = function()
        local totalCDR = 0
        -- 天赋: 法力亲和
        local lv = GameState.GetSkillLevel("mana_affinity")
        totalCDR = totalCDR + lv * 0.04
        -- 装备词缀
        totalCDR = totalCDR + equipSum("skillCdReduce")
        -- 套装被动CDR (如 rune_weaver 2件 skillCdReduce=0.15)
        local mulBonus = GameState.GetSetBonusStatsMul()
        totalCDR = totalCDR + (mulBonus.skillCdReduce or 0)
        -- WIL 职业效果贡献 CDR
        totalCDR = totalCDR + getCoreAttrBonus("cdr")
        -- 渐近线递减
        if totalCDR <= 0 then return 1.0 end
        local dr = Config.CDR_DR
        return 1.0 - dr.maxCDR * totalCDR / (totalCDR + dr.K)
    end

    --- 技能伤害加成 (独立乘区, 装备+套装+INT职业效果 加算后整体乘算)
    --- 返回加算总值, 调用方使用 × (1 + skillDmg)
    GameState.GetSkillDmg = function()
        local total = equipSum("skillDmg")
        -- 套装被动 skillDmg (statsMul 和 stats 两种来源)
        local mulBonus = GameState.GetSetBonusStatsMul()
        total = total + (mulBonus.skillDmg or 0)
        local setStats = GameState.GetSetBonusStats()
        total = total + (setStats.skillDmg or 0)
        -- INT 职业效果贡献技能伤害
        total = total + getCoreAttrBonus("skillDmg")
        return total
    end

    -- ========================================================================
    -- 法力(Mana)系统 — D4 资源机制
    -- ========================================================================

    --- 法力上限 = base + level × perLevel
    GameState.GetMaxMana = function()
        local p = GameState.player
        local mc = Config.MANA
        return mc.base + p.level * mc.perLevel
    end

    --- 每秒法力回复量 (D4 完整公式)
    --- = regenBase × (1 + manaRegenSpeed%)^2 × (1 + resourceGen%) × (1 + willResourceGen%)
    --- 意志资源生成: 每点 WIL = +0.1% (Config.MANA.willRegenPer)
    GameState.GetManaRegen = function()
        local mc = Config.MANA
        local base = mc.regenBase

        -- 法力回复速度% (装备词缀, 暂未定义则为 0)
        local manaRegenSpeed = equipSum("manaRegenSpeed")
        -- 资源生成% (装备词缀, 暂未定义则为 0)
        local resourceGen = equipSum("resourceGen")
        -- 意志资源生成%: 每点 WIL × 0.001
        local wilPts = GameState.player.allocatedPoints.WIL or 0
        local willResourceGen = wilPts * mc.willRegenPer

        local result = base * (1 + manaRegenSpeed) ^ 2
                           * (1 + resourceGen)
                           * (1 + willResourceGen)
        -- 强化寒冰甲: 激活时法力回复+30%[x]
        if GameState.iceArmorActive and GameState._hasIceArmorEnhanced then
            result = result * 1.30
        end
        -- 巫师暴风雪: 激活时每20点法力上限+1法力回复
        if GameState.blizzardActive and GameState._hasBlizzardWizard then
            local maxMana = GameState.GetMaxMana()
            local bonusRegen = math.floor(maxMana / 20)
            result = result + bonusRegen
        end
        return result
    end

    --- 暴击伤害倍率 (全加算, 含溢出暴击率转换)
    --- P1: 暴伤不再来自加点, 纯装备+溢出+套装+称号
    GameState.GetCritDmg = function()
        local p = GameState.player
        local base = p.critDmg + equipSum("critDmg")
        -- 溢出暴击率按比率转为暴击伤害
        base = base + GameState.GetCritOverflow() * Config.CRIT_OVERFLOW_RATIO
        -- 套装被动 + 称号加成 (全加算, 不再乘算)
        local mulBonus = GameState.GetSetBonusStatsMul()
        base = base + (mulBonus.critDmg or 0) + getTitleBonus("critDmg")
        return base
    end

    --- 原始范围增量 (递减前, 用于面板展示)
    --- P1: 范围不再来自加点, 纯装备
    GameState.GetRangeRawBonus = function()
        return equipSum("range")
    end

    --- 攻击范围 (渐近线递减, 绝对值, 用于普攻距离/AI走位)
    --- 公式: baseRange + maxBonus × rawBonus / (rawBonus + K)
    GameState.GetRange = function()
        local rawBonus = GameState.GetRangeRawBonus()
        if rawBonus <= 0 then return Config.PLAYER.baseRange end
        local dr = Config.RANGE_DR
        return Config.PLAYER.baseRange + dr.maxBonus * rawBonus / (rawBonus + dr.K)
    end

    --- 范围倍率因子 (用于技能施法距离/精灵攻击范围缩放)
    --- = currentRange / baseRange, 基础为 1.0, 随 RNG 属性提升
    GameState.GetRangeFactor = function()
        return GameState.GetRange() / Config.PLAYER.baseRange
    end

    --- 幸运值 (影响掉落品质和金币量, 含药水buff)
    --- P1: 幸运不再来自加点, 纯装备+药水+称号
    GameState.GetLuck = function()
        return equipSum("luck")
             + GameState.GetPotionBuff("luck")
             + getTitleBonus("luck")
    end

    -- ========================================================================
    -- 生存属性 (HP, DEF, HPREG, HEAL%, SHLD%, LS%)
    -- ========================================================================

    --- 最大生命值 = (基础 + 等级 + 装备) × (1 + STR职业hpPct + 装备hpPct + 称号 + 套装 + 药水)
    GameState.GetMaxHP = function()
        local p = GameState.player
        local base = Config.PLAYER.baseHP
                  + p.level * Config.PLAYER.hpPerLevel
                  + math.floor(equipSum("hp"))
        -- hpPct 乘区: STR 职业效果 + 装备 hpPct + 称号 hp
        local hpPctBonus = getCoreAttrBonus("hpPct") + equipSum("hpPct") + getTitleBonus("hp")
        -- 套装乘算 (如 permafrost_heart 2件: hp+20%)
        local mulBonus = GameState.GetSetBonusStatsMul()
        local hpMul = 1.0 + (mulBonus.hp or 0) + hpPctBonus
        -- 生命药水: 百分比增加生命上限
        local hpPotionBuff = GameState.GetPotionBuff("hp")
        if hpPotionBuff > 0 then
            hpMul = hpMul + hpPotionBuff
        end
        return math.floor(base * hpMul)
    end

    --- 总防御力 = (基础 + 等级 + STR护甲 + 装备) × (1 + 套装def + 称号def)
    GameState.GetTotalDEF = function()
        local p = GameState.player
        local base = Config.PLAYER.baseDEF
             + p.level * Config.PLAYER.defPerLevel
             + getCoreAttrBonus("def")   -- STR 通用效果: 护甲 (已含 attrScale)
             + equipSum("def")
        -- 倍率池 (加算汇总, 最终一次乘算)
        local mulPool = 0
        local mulBonus = GameState.GetSetBonusStatsMul()
        mulPool = mulPool + (mulBonus.def or 0)
        mulPool = mulPool + getTitleBonus("def")
        return math.floor(base * (1 + mulPool))
    end

    --- 玩家受伤DEF伤害保留率 (0~1)
    --- v3.1: K 随怪物等级缩放 (替代固定 Config.PLAYER.defK)
    ---@param monsterLevel number|nil 攻击者的怪物等级 (nil=自动推算)
    GameState.GetDEFMul = function(monsterLevel)
        local def = GameState.GetTotalDEF()
        -- 腐蚀debuff: 每层降低一定比率的DEF
        if GameState.corrosionStacks > 0 and GameState.corrosionDefReduce > 0 then
            local reducePct = GameState.corrosionStacks * GameState.corrosionDefReduce
            def = math.max(0, def * (1 - reducePct))
        end
        -- 自动推算怪物等级: 优先传入值 → 玩家等级 fallback
        local lvl = monsterLevel or GameState.player.level or 1
        local DF = require("DefenseFormula")
        return DF.PlayerDefMul(def, lvl)
    end

    --- 每秒回血量
    --- P1: 回血不再来自加点, 纯装备
    GameState.GetHPRegen = function()
        return equipSum("hpRegen")
    end

    --- 治疗倍率 (1.0 = 100%基准)
    --- P1: WIL 通用效果 healPct
    GameState.GetHealMul = function()
        return 1.0 + getCoreAttrBonus("healPct") + equipSum("healPct")
    end

    --- 护盾倍率 (1.0 = 100%基准)
    --- P1: 护盾不再来自加点, 纯装备
    GameState.GetShieldMul = function()
        return 1.0 + equipSum("shldPct")
    end

    --- 吸血百分比 (从装备获得, 基础为0)
    GameState.GetLifeSteal = function()
        return equipSum("lifeSteal")
    end

    -- ========================================================================
    -- 新增属性: 闪避 / 全抗 / 超杀 (P1 新机制)
    -- ========================================================================

    --- 闪避概率 (DEX 通用效果, cap 30%)
    GameState.GetDodgeChance = function()
        local dodge = getCoreAttrBonus("dodge")
        return math.min(StatDefs.DODGE_CAP, dodge)
    end

    --- 全元素抗性加成 (INT 通用效果, cap 40%)
    --- 叠加到 DamageFormula 的抗性乘区
    GameState.GetAllResist = function()
        local allRes = getCoreAttrBonus("allResist")
        return math.min(StatDefs.ALL_RESIST_CAP, allRes)
    end

    --- 超杀伤害加成 (WIL 通用效果)
    --- 当目标 HP < OVERKILL_HP_THRESHOLD 时, 额外伤害乘区
    GameState.GetOverkillDmg = function()
        return getCoreAttrBonus("overkill")
    end

    -- ========================================================================
    -- 元素增伤 & 反应增伤 (装备提供)
    -- ========================================================================

    --- 元素增伤倍率 (匹配武器元素的具体增伤 + 存量全元素增伤 + 称号)
    GameState.GetElemDmg = function()
        local weaponElem = GameState.GetWeaponElement()
        local ELEM_TO_STAT = {
            fire = "fireDmg", ice = "iceDmg", poison = "poisonDmg",
            arcane = "arcaneDmg", water = "waterDmg",
        }
        local specificKey = ELEM_TO_STAT[weaponElem]
        local specific = specificKey and equipSum(specificKey) or 0
        -- 存量全元素增伤 (不再产出新词条, 旧装备保留原值)
        local allElem = equipSum("elemDmg")
        -- 称号加成: 全元素增伤
        return specific + allElem + getTitleBonus("allElemDmg")
    end

    --- 获取指定元素的增伤数值 (用于角色面板展示)
    GameState.GetSpecificElemDmg = function(elemStatKey)
        local specific = equipSum(elemStatKey)
        -- 存量全元素增伤 (不再产出新词条, 旧装备保留原值)
        local allElem = equipSum("elemDmg")
        -- 称号加成: 全元素增伤
        return specific + allElem + getTitleBonus("allElemDmg")
    end

    --- 反应增伤倍率 (装备 reactionDmg): reactionMul = base × (1 + reactionDmg)
    GameState.GetReactionDmgFromEquip = function()
        return equipSum("reactionDmg")
    end

    -- ========================================================================
    -- 套装系统
    -- ========================================================================

    --- 统计当前装备的套装件数
    --- @return table<string, number> setId → 穿戴件数
    GameState.GetEquippedSetCounts = function()
        local counts = {}
        for _, item in pairs(GameState.equipment) do
            if item and item.setId then
                counts[item.setId] = (counts[item.setId] or 0) + 1
            end
        end
        return counts
    end

    --- 获取所有激活的套装被动属性加成
    --- @return table<string, number> stat → bonus value
    GameState.GetSetBonusStats = function()
        local result = {}
        local counts = GameState.GetEquippedSetCounts()
        for setId, count in pairs(counts) do
            local setCfg = Config.EQUIP_SET_MAP[setId]
            if setCfg then
                for threshold, bonus in pairs(setCfg.bonuses) do
                    if count >= threshold and bonus.stats then
                        for stat, val in pairs(bonus.stats) do
                            result[stat] = (result[stat] or 0) + val
                        end
                    end
                end
            end
        end
        return result
    end

    --- 获取套装乘算加成 (如 hp+20%)
    --- @return table<string, number> stat → multiplier bonus (0.20 = +20%)
    GameState.GetSetBonusStatsMul = function()
        local result = {}
        local counts = GameState.GetEquippedSetCounts()
        for setId, count in pairs(counts) do
            local setCfg = Config.EQUIP_SET_MAP[setId]
            if setCfg then
                for threshold, bonus in pairs(setCfg.bonuses) do
                    if count >= threshold and bonus.statsMul then
                        for stat, val in pairs(bonus.statsMul) do
                            result[stat] = (result[stat] or 0) + val
                        end
                    end
                end
            end
        end
        return result
    end

    -- ========================================================================
    -- 韧性(TEN) - 通用减益抗性
    -- ========================================================================

    --- 通用减益抗性 (0~0.8)
    --- P1: 韧性不再来自加点, 纯称号(+未来装备)
    GameState.GetDebuffResist = function()
        local resist = getTitleBonus("debuffResist")
        return math.min(Config.TENACITY.maxResist, resist)
    end

    --- 向后兼容别名
    GameState.GetSlowResist = GameState.GetDebuffResist

    -- ========================================================================
    -- 武器元素, DPS, 综合战力
    -- ========================================================================

    --- 获取当前武器元素 (决定普攻附带的元素)
    --- @return string 元素类型
    GameState.GetWeaponElement = function()
        local weapon = GameState.equipment["weapon"]
        if weapon and weapon.element and weapon.element ~= "physical" then
            return weapon.element
        end
        return Config.WEAPON_ELEMENTS.default  -- 术士默认火元素
    end

    --- 每秒伤害 DPS
    GameState.GetDPS = function()
        local atk = GameState.GetTotalAtk()
        local spd = GameState.GetAtkSpeed()
        local crit = GameState.GetCritRate()
        local critDmg = GameState.GetCritDmg()
        return math.floor(atk * spd * (1 + crit * (critDmg - 1)))
    end

    --- 综合战力 (P1: 新增 dodge/allResist/skillDmg/overkill)
    GameState.GetPower = function()
        local atk = GameState.GetTotalAtk()
        local spd = GameState.GetAtkSpeed()
        local crit = GameState.GetCritRate()
        local critDmg = GameState.GetCritDmg()
        local range = GameState.GetRange()
        local luck = GameState.GetLuck()
        local maxHP = GameState.GetMaxHP()
        local def = GameState.GetTotalDEF()
        local dodge = GameState.GetDodgeChance()
        local allRes = GameState.GetAllResist()
        local skillDmg = GameState.GetSkillDmg()
        local overkill = GameState.GetOverkillDmg()
        local elemDmg = GameState.GetElemDmg()
        local reactionDmg = GameState.GetReactionDmgFromEquip()
        return math.floor(atk * 2 + spd * 50 + crit * 100 + critDmg * 40
                        + range * 1.5 + luck * 80
                        + maxHP * 0.1 + def * 3
                        + dodge * 500 + allRes * 300
                        + skillDmg * 80 + overkill * 60
                        + elemDmg * 60 + reactionDmg * 60)
    end

    -- ========================================================================
    -- 装备战力 & 属性格式化
    -- ========================================================================

    --- 属性战力重要度 → 统一由 StatDefs.EQUIP_IMPORTANCE 管理

    --- 品质基础战力 (白/绿/蓝/紫/橙)
    local QUALITY_BASE_POWER = { 0, 5, 15, 30, 60 }

    --- 计算装备战力评分 (P2: ItemScore, 基于统一词缀)
    --- 归一化: value / (base × ipFactor) → roll 品质 → × 重要度
    GameState.ItemPower = function(item)
        if not item then return 0 end
        local power = 0

        -- 品质基础分
        power = power + (QUALITY_BASE_POWER[item.qualityIdx] or 0)

        -- P2: 统一词缀评分
        local ip = item.itemPower or 100
        if item.affixes then
            for _, aff in ipairs(item.affixes) do
                local def = Config.AFFIX_POOL_MAP[aff.id]
                if def and def.base > 0 and aff.value then
                    local ipFactor = 1 + (ip / 100 - 1) * def.ipScale
                    local maxVal = def.base * ipFactor
                    local normalized = (maxVal > 0) and (aff.value / maxVal) or 0
                    power = power + normalized * StatDefs.GetImportance(aff.id) * (ip / 100)
                end
            end
        end

        -- 宝石加分
        if item.gems and item.sockets then
            local gemStats = GameState.GetGemStats(item)
            for statKey, value in pairs(gemStats) do
                local sd = Config.EQUIP_STATS[statKey]
                if sd and sd.base > 0 then
                    local normalized = value / sd.base
                    power = power + normalized * StatDefs.GetImportance(statKey)
                end
            end
        end

        -- 套装加分
        if item.setId then power = power + 15 end

        return math.floor(power)
    end

    --- 格式化单个属性值
    --- @param statKey string 属性ID
    --- @param value number 数值
    --- @return string 格式化文本 (如 "+60" 或 "+15.0%")
    GameState.FormatStatValue = function(statKey, value)
        local def = Config.EQUIP_STATS[statKey]
        -- 智能格式化: 整数不带小数, 非整数最多显示到有效位
        local function smartFmt(v, maxDec)
            local rounded = math.floor(v * 10^maxDec + 0.5) / 10^maxDec
            if math.abs(rounded - math.floor(rounded + 0.5)) < 0.001 then
                return string.format("%d", math.floor(rounded + 0.5))
            elseif maxDec >= 2 and math.abs(rounded * 10 - math.floor(rounded * 10 + 0.5)) < 0.01 then
                return string.format("%.1f", rounded)
            else
                return string.format("%." .. maxDec .. "f", rounded)
            end
        end
        if not def then return "+" .. smartFmt(value, 2) end
        if def.isPercent then
            return "+" .. smartFmt(value * 100, 1) .. "%"
        elseif def.fmtSub then
            return string.format("+" .. def.fmtSub, value)
        else
            return "+" .. smartFmt(value, 2)
        end
    end

    --- 格式化装备简短显示 (P2: 显示 IP)
    GameState.FormatItemStat = function(item)
        if not item then return "" end
        if item.itemPower then
            return "IP " .. item.itemPower
        end
        return ""
    end

    -- ========================================================================
    -- 工具格式化
    -- ========================================================================

    --- 格式化秒数为时:分:秒
    GameState.FormatSeconds = function(secs)
        if secs <= 0 then return "" end
        secs = math.floor(secs)
        local h = math.floor(secs / 3600)
        local m = math.floor((secs % 3600) / 60)
        local s = secs % 60
        if h > 0 then
            return string.format("%d:%02d:%02d", h, m, s)
        else
            return string.format("%d:%02d", m, s)
        end
    end

    --- 大数字缩写 (统一使用 Utils.FormatNumber)
    --- @param n number
    --- @return string
    GameState.FormatBigNumber = function(n)
        local FmtUtils = require("Utils")
        return FmtUtils.FormatNumber(n)
    end

    -- ========================================================================
    -- 元素增幅技能参数查询
    -- ========================================================================

    --- 元素附着时长加成 (秒)
    GameState.GetElementDurationBonus = function()
        local lv = GameState.GetSkillLevel("elem_affinity")
        return lv * 0.5  -- 每级+0.5s
    end

    --- 反应伤害加成倍率 (1.0 = 无加成)
    --- v3.0 STUB: 旧反应伤害加成 (返回1.0=无加成, 兼容旧调用)
    GameState.GetReactionDmgBonus = function()
        return 1.0
    end

    --- v3.0 STUB: 元素印记已移除
    GameState.GetElementMarkBonus = function()
        return 0
    end

    --- v3.0 STUB: 双元附着已移除
    GameState.GetDualAttachChance = function()
        return 0
    end

    --- v3.0 STUB: 元素蔓延已移除
    GameState.GetElementSpreadChance = function()
        return 0
    end

    --- v3.0 STUB: 万象终焉已移除
    GameState.GetConvergenceBonus = function()
        return 0
    end

    -- ========================================================================
    -- 永久修饰器注册 (技能 + 称号, 无 conditionFn)
    -- ========================================================================

    -- 力量灌注: 每级+8% ATK
    SM.Register({
        id = "skill_base_atk_boost", stat = "atk", type = "pctPool",
        valueFn = function() return GameState.GetSkillLevel("base_atk_boost") * 0.08 end,
    })

    -- 称号 ATK 加成
    SM.Register({
        id = "title_atk", stat = "atk", type = "pctPool",
        valueFn = function() return getTitleBonus("atk") end,
    })

    -- 速射: 每级+8% 攻速 (独立乘算, DR后阶段)
    SM.Register({
        id = "skill_normal_speed", stat = "atkSpeed", type = "pctMul",
        valueFn = function() return GameState.GetSkillLevel("normal_speed") * 0.08 end,
    })
end

return StatCalc
