-- ============================================================================
-- ConfigCalc.lua - Config 计算函数 (从 Config.lua 分离)
-- 职责: 纯计算逻辑, 不含数据定义
-- 依赖: Config (由 Install 注入), StageConfig (锻造段位, 延迟require)
-- ============================================================================

local M = {}

---@param Config table Config表, 由 Config.lua 尾部调用时传入
function M.Install(Config)

-- ============================================================================
-- 章节数值缩放
-- ============================================================================

--- 装备Tier系数: 对数增长, ch100达到100倍
---@param chapter number 章节编号(从1开始)
---@return number tierMul 装备词条乘数
function Config.GetChapterTier(chapter)
    if chapter <= 1 then return 1.0 end
    local maxMul = 100
    local maxCh = 100
    return 1.0 + (maxMul - 1) * math.log(chapter) / math.log(maxCh)
end

--- 属性点缩放因子: tierMul 的平方根
---@param chapter number 章节编号(从1开始)
---@return number attrScale 缩放因子
function Config.GetAttrScale(chapter)
    return math.sqrt(Config.GetChapterTier(chapter))
end

-- ============================================================================
-- P2: Item Power 计算
-- ============================================================================

--- 基础 IP: 对数增长, ch1=100, ch16≈568, ch100=925
---@param chapter number 章节编号(从1开始)
---@return number baseIP
function Config.CalcBaseIP(chapter)
    if chapter <= 1 then return 100 end
    return math.floor(100 + 825 * math.log(chapter) / math.log(100))
end

--- 从 itemPower 反推等效 tierMul (用于宝石属性缩放等旧公式兼容)
--- tierMul 与 baseIP 共享 ln(ch)/ln(100) 因子:
---   baseIP  = 100 + 825 * x   =>  x = (ip - 100) / 825
---   tierMul = 1   + 99  * x
---@param ip number 装备的 itemPower
---@return number tierMul 等效 tierMul
function Config.IPToTierMul(ip)
    if not ip or ip <= 100 then return 1.0 end
    return 1.0 + 99 * (ip - 100) / 825
end

-- ============================================================================
-- 伤害减免公式
-- ============================================================================

--- 抗性减伤倍率 (三段曲线, 角色与怪物共用)
---@param resist number 抗性值
---@return number 伤害倍率 (>0)
function Config.ResistMul(resist)
    if resist < 0 then
        return 1 - resist / 2
    elseif resist < 0.75 then
        return 1 - resist
    else
        return 1 / (1 + resist / 4)
    end
end

--- DEF减伤倍率 (角色与怪物共用)
---@param def number 防御值 (已扣减debuff后)
---@param K number 减免常数
---@return number 伤害倍率 (0~1)
function Config.DefMul(def, K)
    if def <= 0 then return 1.0 end
    return 1 - def / (def + K)
end

-- ============================================================================
-- 经验公式
-- ============================================================================

--- 旧经验公式 (v1, 仅用于存档迁移计算)
---@param lv number 等级
---@return number 所需经验
function Config.OldLevelExp(lv)
    return math.floor(50 * lv * (1 + lv * 0.3) * 1.06 ^ lv)
end

local manualExp = { 30, 35, 40, 45, 52, 58, 65, 72, 80 }
--- 经验公式 v2: lv1-9 手动曲线 + lv10+ 指数公式
---@param lv number 等级
---@return number 所需经验
function Config.LevelExp(lv)
    if lv >= 1 and lv <= 9 then
        return manualExp[lv]
    end
    return math.floor(300 * 1.04 ^ lv)
end

-- ============================================================================
-- 金币缩放
-- ============================================================================

--- 金币缩放因子: scaleMul^0.3
---@param scaleMul number 关卡难度缩放值
---@return number 金币缩放系数
function Config.GetGoldScale(scaleMul)
    return scaleMul ^ 0.3
end

-- ============================================================================
-- 装备升级
-- ============================================================================

--- 升级每级所需强化石
---@param level number 当前等级(升之前), 从 0 开始
---@param chapter number|nil 装备所属章节, 默认1
---@return number 强化石数量
function Config.UpgradeCost(level, chapter)
    local base = math.max(2, math.floor(2 + level * 1.2 + level * level * 0.06))
    local ch = chapter or 1
    return math.floor(base * ch)
end

-- ============================================================================
-- 装备图标
-- ============================================================================

--- 获取装备部位图标路径 (套装专属 → 通用 fallback)
---@param slotId string 槽位ID
---@param setId string|nil 套装ID
---@return string iconPath
function Config.GetEquipSlotIcon(slotId, setId)
    if setId and Config.EQUIP_SET_SLOT_ICONS[setId] then
        local icon = Config.EQUIP_SET_SLOT_ICONS[setId][slotId]
        if icon then return icon end
    end
    return Config.EQUIP_ICON_PATHS[slotId] or ""
end

-- ============================================================================
-- 掉落批次
-- ============================================================================

--- 获取章节所属的掉落批次范围
---@param chapter number 章节号
---@return number batchStart, number batchEnd
function Config.GetDropBatch(chapter)
    for _, batch in ipairs(Config.DROP_BATCHES) do
        if chapter >= batch[1] and chapter <= batch[2] then
            return batch[1], batch[2]
        end
    end
    return chapter, chapter
end

--- 判断套装是否属于指定批次
---@param setCfg table 套装定义 (含 chapter, chapterRange)
---@param batchStart number 批次起始章节
---@param batchEnd number 批次结束章节
---@return boolean
function Config.IsSetInBatch(setCfg, batchStart, batchEnd)
    if setCfg.chapterRange then
        return setCfg.chapterRange[1] >= batchStart and setCfg.chapterRange[2] <= batchEnd
    end
    return setCfg.chapter >= batchStart and setCfg.chapter <= batchEnd
end

-- ============================================================================
-- 锻造
-- ============================================================================

--- 获取指定段内玩家已通关的最高Boss关的scaleMul
---@param segmentId number 段ID (1/2/3)
---@param maxChapter number 玩家最高章节
---@param maxStage number 玩家最高关卡
---@return number|nil scaleMul, number|nil chapter
function Config.GetForgeSegmentScaleMul(segmentId, maxChapter, maxStage)
    local StageConfig = require("StageConfig")
    local seg = Config.FORGE_SEGMENTS[segmentId]
    if not seg then return nil end

    local bestScaleMul = nil
    local bestChapter = nil

    for ch = seg.chapterRange[1], seg.chapterRange[2] do
        if ch > maxChapter then break end
        local stageCount = StageConfig.GetStageCount(ch)
        local maxStInCh = (ch == maxChapter) and maxStage or stageCount
        for st = maxStInCh, 1, -1 do
            local stageCfg = StageConfig.GetStage(ch, st)
            if stageCfg and stageCfg.isBoss then
                local sm = StageConfig.GetScaleMul(ch, st)
                if not bestScaleMul or sm > bestScaleMul then
                    bestScaleMul = sm
                    bestChapter = ch
                end
                break
            end
        end
    end

    return bestScaleMul, bestChapter
end

--- 计算锻造金币消耗
---@param scaleMul number Boss关的scaleMul
---@param lockSlot boolean 是否锁定部位
---@return number goldCost
function Config.GetForgeGoldCost(scaleMul, lockSlot)
    local base = lockSlot and Config.FORGE_GOLD_BASE_LOCK or Config.FORGE_GOLD_BASE
    return math.floor(base * math.sqrt(scaleMul))
end

--- 计算锻造强化石消耗
---@param lockSlot boolean 是否锁定部位
---@return number stoneCost
function Config.GetForgeStoneCost(lockSlot)
    return lockSlot and Config.FORGE_STONE_COST_LOCK or Config.FORGE_STONE_COST
end

-- ============================================================================
-- 宝石
-- ============================================================================

--- 获取宝石图标路径
---@param gemTypeId string
---@param qualityIdx number
---@return string
function Config.GetGemIcon(gemTypeId, qualityIdx)
    return "Textures/Gems/gem_" .. gemTypeId .. "_" .. qualityIdx .. ".png"
end

--- 根据宝石类型、品质、装备类型计算属性值 (数据驱动)
---@param gemTypeId string 宝石类型 id
---@param qualityIdx number 品质索引 (1-5)
---@param equipCategory string 装备类型 ("weapon"/"armor"/"jewelry")
---@param tierMul number 装备的 tierMul
---@return string statKey, number value
function Config.CalcGemStat(gemTypeId, qualityIdx, equipCategory, tierMul)
    local gemDef = Config.GEM_TYPE_MAP[gemTypeId]
    if not gemDef then return nil, 0 end
    local quality = Config.GEM_QUALITIES[qualityIdx]
    if not quality then return nil, 0 end

    local statKey = gemDef.effects[equipCategory]
    if not statKey then return nil, 0 end

    -- 检查 override 配置
    local ov = gemDef.overrides and gemDef.overrides[equipCategory]
    if ov then
        if ov.base then
            local baseVal = Config[ov.base] or 0
            return statKey, baseVal * quality.gemMul * tierMul
        elseif ov.baseStat then
            local refDef = Config.EQUIP_STATS[ov.baseStat]
            local discount = ov.discount and Config[ov.discount] or 1
            local baseVal = refDef and refDef.base or 0
            return statKey, baseVal * discount * quality.gemMul * tierMul
        end
    end

    -- 通用公式: base × gemMul × tierMul
    local statDef = Config.EQUIP_STATS[statKey]
    if not statDef then return statKey, 0 end
    return statKey, statDef.base * quality.gemMul * tierMul
end

end -- M.Install

return M
