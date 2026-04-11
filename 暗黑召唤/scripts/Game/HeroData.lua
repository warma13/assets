-- Game/HeroData.lua
-- 英雄养成数据管理（局外永久数据）
-- 升星(0-30) + 觉醒(0-4) + 进阶(0-20) 系统，对齐咸鱼之王

local Config = require("Game.Config")
local SaveManager = require("Game.SaveManager")
local SafeTable = require("Game.SafeTable")

local HeroData = {}

-- 英雄数据存储
HeroData.heroes = {}       -- heroId -> { unlocked, fragments, level, star, awakening }
HeroData.deployed = {}     -- 已上阵随从英雄ID列表（最多 MAX_DEPLOYED 个，不含主角）
-- 快照函数（存档时调用，返回明文 table）
local currencySnapshot = nil
local heroesSnapshot = nil
local statsSnapshot = nil
local chestSnapshot = nil
local equipSnapshot = nil

HeroData.currencies = {    -- 局外货币（新体系）- 运行时会被 SafeTable 代理替换
    nether_crystal = 0,     -- 冥晶（升级用）
    devour_stone = 0,       -- 噬魂石（进阶用）
    forge_iron = 0,         -- 锻魂铁（装备用）
    void_pact = 0,          -- 虚空契约（招募用）
    shadow_essence = 0,     -- 暗影精华（兑换用）
    dark_soul = 0,          -- 暗魂（战斗内掉落）
    -- 兼容旧存档字段
    gold = 0,
    diamonds = 0,
    advanceStones = 0,
    recruitTokens = 0,
}
HeroData.recruitData = {   -- 招募系统数据
    pityCounter = 0,        -- 保底计数器（每10次重置）
    totalPulls = 0,         -- 历史总抽数
    freeDaily = "",         -- 今日免费抽标记（日期字符串 "YYYY-MM-DD"）
}
HeroData.stats = {
    bestStage = 0,
    totalGames = 0,
}
HeroData.chestData = nil      -- 宝箱系统数据（由 ChestData 模块管理）
HeroData.equipData = nil      -- 装备系统数据（由 EquipData 模块管理）
HeroData.activityData = nil   -- 活动系统数据（由 ActivityData 模块管理）
HeroData.launchGiftData = nil -- 开服好礼数据（由 LaunchGiftData 模块管理）
HeroData.dailyTaskData = nil  -- 每日任务数据（由 DailyTaskData 模块管理）

--- 初始化默认数据（新玩家）
function HeroData.InitDefault()
    HeroData.heroes, heroesSnapshot = SafeTable.CreateDeep({})
    HeroData.currencies, currencySnapshot = SafeTable.Create({
        nether_crystal = 0,
        devour_stone = 0,
        forge_iron = 0,
        void_pact = 0,
        shadow_essence = 0,
        dark_soul = 0,
        -- 旧字段置零
        gold = 0, diamonds = 0, advanceStones = 0, recruitTokens = 0,
    })
    HeroData.recruitData = { pityCounter = 0, totalPulls = 0, freeDaily = "" }
    HeroData.stats, statsSnapshot = SafeTable.Create({ bestStage = 0, totalGames = 0 })
    HeroData.deployed = {}
    for _, heroId in ipairs(Config.DEFAULT_DEPLOYED) do
        HeroData.deployed[#HeroData.deployed + 1] = heroId
    end

    HeroData.chestData = nil  -- ChestData 模块自行初始化
    chestSnapshot = nil
    HeroData.equipData = nil  -- EquipData 模块懒初始化
    equipSnapshot = nil
    HeroData.activityData = nil  -- ActivityData 模块懒初始化
    HeroData.launchGiftData = nil -- LaunchGiftData 模块懒初始化
    HeroData.dailyTaskData = nil  -- DailyTaskData 模块懒初始化

    -- 所有英雄初始化为未解锁
    for _, towerDef in ipairs(Config.TOWER_TYPES) do
        HeroData.heroes[towerDef.id] = {
            unlocked = false,
            fragments = 0,
            level = 1,
            star = 0,
            awakening = 0,
            advanceLevel = 0,
        }
    end

    -- 默认解锁英雄
    for _, heroId in ipairs(Config.DEFAULT_UNLOCKED) do
        if HeroData.heroes[heroId] then
            HeroData.heroes[heroId].unlocked = true
            HeroData.heroes[heroId].fragments = 5
        end
    end

    -- 初始化主角英雄（始终解锁，无星级/觉醒/碎片）
    HeroData.heroes[Config.LEADER_HERO.id] = {
        unlocked = true,
        fragments = 0,
        level = 1,
        star = 0,
        awakening = 0,
        advanceLevel = 0,
    }

    print("[HeroData] Initialized default data")
end

--- 从本地存档加载（兼容旧路径，新路径走 SlotSaveSystem）
function HeroData.Load()
    local data = SaveManager.Load()
    HeroData.RestoreFromSnapshot(data)
    print("[HeroData] Loaded from local save")
end

--- 获取当前运行时数据的明文快照（用于序列化/存档）
---@return table  完整存档数据
function HeroData.GetSaveSnapshot()
    return {
        heroes = heroesSnapshot and heroesSnapshot() or HeroData.heroes,
        currencies = currencySnapshot and currencySnapshot() or HeroData.currencies,
        recruitData = HeroData.recruitData,
        deployed = HeroData.deployed,
        stats = statsSnapshot and statsSnapshot() or HeroData.stats,
        chestData = chestSnapshot and chestSnapshot() or HeroData.chestData,
        equipData = equipSnapshot and equipSnapshot() or HeroData.equipData,
        towerData = HeroData.towerData,
        activityData = HeroData.activityData,
        launchGiftData = HeroData.launchGiftData,
        dailyTaskData = HeroData.dailyTaskData,
        lastSaveTime = os.time(),
    }
end

--- 从存档快照恢复运行时数据（含旧版字段迁移+SafeTable包装）
---@param data table  存档数据（明文）
function HeroData.RestoreFromSnapshot(data)
    if not data or not data.heroes then
        HeroData.InitDefault()
        return
    end

    -- 先用普通 table 完成迁移，最后再包装为 SafeTable
    HeroData.heroes = data.heroes
    local rawCurrencies = data.currencies or { gold = 0, diamonds = 0 }
    HeroData.currencies = rawCurrencies
    local rawStats = data.stats or { bestStage = 0, totalGames = 0 }
    HeroData.stats = rawStats
    HeroData.lastSaveTime = data.lastSaveTime or 0

    -- 存档迁移: rank→star
    local rankToStar = { [1] = 0, [2] = 5, [3] = 10, [4] = 15, [5] = 20, [6] = 25 }
    for heroId, h in pairs(HeroData.heroes) do
        if h.rank and not h.star then
            h.star = rankToStar[h.rank] or 0
            h.awakening = 0
            h.rank = nil
            print("[HeroData] Migrated " .. heroId .. " rank→star=" .. h.star)
        end
    end

    -- 旧字段迁移: advanceStones → devour_stone
    if HeroData.currencies.advanceStones and HeroData.currencies.advanceStones > 0 then
        HeroData.currencies.devour_stone = (HeroData.currencies.devour_stone or 0) + HeroData.currencies.advanceStones
        HeroData.currencies.advanceStones = nil
    end
    if HeroData.currencies.devour_stone == nil then
        HeroData.currencies.devour_stone = 0
    end

    -- 旧字段迁移: recruitTokens → void_pact
    if HeroData.currencies.recruitTokens and HeroData.currencies.recruitTokens > 0 then
        HeroData.currencies.void_pact = (HeroData.currencies.void_pact or 0) + HeroData.currencies.recruitTokens
        HeroData.currencies.recruitTokens = nil
    end
    if HeroData.currencies.void_pact == nil then
        HeroData.currencies.void_pact = Config.RECRUIT_INITIAL_TOKENS
    end

    -- 旧字段迁移: gold → nether_crystal
    if HeroData.currencies.gold and HeroData.currencies.gold > 0 then
        HeroData.currencies.nether_crystal = (HeroData.currencies.nether_crystal or 0) + HeroData.currencies.gold
        HeroData.currencies.gold = nil
    end
    if HeroData.currencies.nether_crystal == nil then
        HeroData.currencies.nether_crystal = 0
    end

    -- 旧字段迁移: diamonds → shadow_essence
    if HeroData.currencies.diamonds and HeroData.currencies.diamonds > 0 then
        HeroData.currencies.shadow_essence = (HeroData.currencies.shadow_essence or 0) + HeroData.currencies.diamonds
        HeroData.currencies.diamonds = nil
    end
    if HeroData.currencies.shadow_essence == nil then
        HeroData.currencies.shadow_essence = 0
    end

    -- 新增: forge_iron（旧存档没有此字段）
    if HeroData.currencies.forge_iron == nil then
        HeroData.currencies.forge_iron = 0
    end

    -- 补齐 recruitData（旧存档没有此字段）
    HeroData.recruitData = data.recruitData or { pityCounter = 0, totalPulls = 0, freeDaily = "" }

    -- 补齐 deployed（旧存档没有此字段）
    if data.deployed and #data.deployed > 0 then
        HeroData.deployed = data.deployed
    else
        -- 旧存档迁移: 默认上阵所有已解锁英雄（最多5个）
        HeroData.deployed = {}
        for _, towerDef in ipairs(Config.TOWER_TYPES) do
            if HeroData.heroes[towerDef.id] and HeroData.heroes[towerDef.id].unlocked then
                HeroData.deployed[#HeroData.deployed + 1] = towerDef.id
                if #HeroData.deployed >= Config.MAX_DEPLOYED then break end
            end
        end
        print("[HeroData] Migrated: deployed " .. #HeroData.deployed .. " heroes")
    end

    -- 补齐新英雄（配置新增了但存档里没有的）
    for _, towerDef in ipairs(Config.TOWER_TYPES) do
        if not HeroData.heroes[towerDef.id] then
            HeroData.heroes[towerDef.id] = {
                unlocked = false,
                fragments = 0,
                level = 1,
                star = 0,
                awakening = 0,
                advanceLevel = 0,
            }
        end
        -- 确保旧存档里的英雄也有新字段
        local h = HeroData.heroes[towerDef.id]
        if h.awakening == nil then
            h.awakening = 0
        end
        if h.star == nil then
            h.star = 0
        end
        if h.advanceLevel == nil then
            h.advanceLevel = 0
        end
    end

    -- 补齐主角英雄（旧存档没有 leader）
    if not HeroData.heroes[Config.LEADER_HERO.id] then
        HeroData.heroes[Config.LEADER_HERO.id] = {
            unlocked = true,
            fragments = 0,
            level = 1,
            star = 0,
            awakening = 0,
            advanceLevel = 0,
        }
        print("[HeroData] Migrated: added leader hero")
    else
        -- 确保旧存档 leader 也有新字段
        local lh = HeroData.heroes[Config.LEADER_HERO.id]
        if lh.advanceLevel == nil then lh.advanceLevel = 0 end
    end

    -- 补齐 chestData（旧存档没有此字段）
    HeroData.chestData = data.chestData or nil
    -- 补齐 equipData（旧存档没有此字段）
    HeroData.equipData = data.equipData or nil
    -- 补齐 towerData（试练塔进度）
    HeroData.towerData = data.towerData or nil
    -- 补齐 activityData（旧存档没有此字段）
    HeroData.activityData = data.activityData or nil
    -- 补齐 launchGiftData（旧存档没有此字段）
    HeroData.launchGiftData = data.launchGiftData or nil
    -- 补齐 dailyTaskData（旧存档没有此字段）
    HeroData.dailyTaskData = data.dailyTaskData or nil

    -- 迁移完成后，用 SafeTable 包装（内存混淆）
    HeroData.currencies, currencySnapshot = SafeTable.Create(rawCurrencies)
    HeroData.heroes, heroesSnapshot = SafeTable.CreateDeep(HeroData.heroes)
    HeroData.stats, statsSnapshot = SafeTable.Create(rawStats)
    if HeroData.chestData then
        HeroData.chestData, chestSnapshot = SafeTable.CreateDeep(HeroData.chestData)
    else
        chestSnapshot = nil
    end
    if HeroData.equipData then
        HeroData.equipData, equipSnapshot = SafeTable.CreateDeep(HeroData.equipData)
    else
        equipSnapshot = nil
    end

    print("[HeroData] RestoreFromSnapshot complete")
end

--- 保存数据（自动分流：SlotSaveSystem 活跃时标记脏，否则走本地）
function HeroData.Save()
    local SlotSave = require("Game.SlotSaveSystem")
    if SlotSave.GetActiveSlot() > 0 then
        SlotSave.MarkDirty()
    else
        -- 未加载槽位时使用旧路径（兼容初始化阶段）
        SaveManager.Save(HeroData.GetSaveSnapshot())
    end
    -- 数据变更后即时刷新标签栏红点
    local ok, TabNav = pcall(require, "Game.TabNav")
    if ok and TabNav.RefreshRedDots then
        TabNav.RefreshRedDots()
    end
end

--- 设置 chestData 并自动包装 SafeTable（供 ChestData.Save 调用）
---@param data table  明文宝箱数据
function HeroData.SetChestData(data)
    if data then
        HeroData.chestData, chestSnapshot = SafeTable.CreateDeep(data)
    else
        HeroData.chestData = nil
        chestSnapshot = nil
    end
end

--- 设置 equipData 并自动包装 SafeTable（供 EquipData 调用）
---@param data table  明文装备数据
function HeroData.SetEquipData(data)
    if data then
        HeroData.equipData, equipSnapshot = SafeTable.CreateDeep(data)
    else
        HeroData.equipData = nil
        equipSnapshot = nil
    end
end

--- 获取英雄数据
---@param heroId string
---@return table|nil
function HeroData.Get(heroId)
    return HeroData.heroes[heroId]
end

--- 英雄是否已解锁
---@param heroId string
---@return boolean
function HeroData.IsUnlocked(heroId)
    local h = HeroData.heroes[heroId]
    return h and h.unlocked or false
end

--- 获取已解锁英雄列表
---@return table  -- array of heroId strings
function HeroData.GetUnlockedList()
    local list = {}
    for _, towerDef in ipairs(Config.TOWER_TYPES) do
        if HeroData.IsUnlocked(towerDef.id) then
            list[#list + 1] = towerDef.id
        end
    end
    return list
end

-- ============================================================================
-- 上阵/部署系统
-- ============================================================================

--- 英雄是否已上阵
---@param heroId string
---@return boolean
function HeroData.IsDeployed(heroId)
    for _, id in ipairs(HeroData.deployed) do
        if id == heroId then return true end
    end
    return false
end

--- 获取已上阵英雄列表
---@return string[]
function HeroData.GetDeployedList()
    return HeroData.deployed
end

--- 获取已上阵英雄数量
---@return number
function HeroData.GetDeployedCount()
    return #HeroData.deployed
end

--- 上阵英雄
---@param heroId string
---@return boolean success
---@return string msg
function HeroData.Deploy(heroId)
    if not HeroData.IsUnlocked(heroId) then
        return false, "英雄未解锁"
    end
    if heroId == Config.LEADER_HERO.id then
        return false, "主角始终上阵，无需操作"
    end
    if HeroData.IsDeployed(heroId) then
        return false, "已在阵中"
    end
    if #HeroData.deployed >= Config.MAX_DEPLOYED then
        return false, "阵位已满(最多" .. Config.MAX_DEPLOYED .. "个)"
    end
    HeroData.deployed[#HeroData.deployed + 1] = heroId
    HeroData.Save()
    print("[HeroData] Deployed " .. heroId .. " (" .. #HeroData.deployed .. "/" .. Config.MAX_DEPLOYED .. ")")
    return true, "上阵成功"
end

--- 下阵英雄
---@param heroId string
---@return boolean success
---@return string msg
function HeroData.Undeploy(heroId)
    for i, id in ipairs(HeroData.deployed) do
        if id == heroId then
            table.remove(HeroData.deployed, i)
            HeroData.Save()
            print("[HeroData] Undeployed " .. heroId .. " (" .. #HeroData.deployed .. "/" .. Config.MAX_DEPLOYED .. ")")
            return true, "下阵成功"
        end
    end
    return false, "不在阵中"
end

--- 交换阵位
---@param idx1 number
---@param idx2 number
function HeroData.SwapDeployed(idx1, idx2)
    if idx1 < 1 or idx1 > #HeroData.deployed then return end
    if idx2 < 1 or idx2 > #HeroData.deployed then return end
    HeroData.deployed[idx1], HeroData.deployed[idx2] = HeroData.deployed[idx2], HeroData.deployed[idx1]
    HeroData.Save()
end

-- ============================================================================
-- 升星系统
-- ============================================================================

--- 根据星数计算所在段号(1-6)
---@param star number  0-30
---@return number  tierNum 1-6 (0星返回1表示黄星段)
function HeroData.GetTierFromStar(star)
    if star <= 0 then return 1 end
    for i, tier in ipairs(Config.STAR_TIERS) do
        if star >= tier.starRange[1] and star <= tier.starRange[2] then
            return i
        end
    end
    return #Config.STAR_TIERS
end

--- 计算已完成的段进阶次数
---@param star number
---@return number  0-5
function HeroData.GetCompletedAdvances(star)
    if star <= 0 then return 0 end
    local advances = 0
    for _, tier in ipairs(Config.STAR_TIERS) do
        if star >= tier.starRange[1] then
            advances = advances + 1
        else
            break
        end
    end
    -- advances 代表已进入的段数(1-6)，完成的进阶 = 进入段数 - 1
    return math.max(0, advances - 1)
end

--- 获取星级段信息
---@param heroId string
---@return table  { tierNum, name, color, starInTier, totalInTier }
function HeroData.GetStarTierInfo(heroId)
    local h = HeroData.heroes[heroId]
    local star = (h and h.star) or 0
    if star <= 0 then
        local tier = Config.STAR_TIERS[1]
        return { tierNum = 0, name = "无星", color = { 200, 200, 200 }, starInTier = 0, totalInTier = 5 }
    end
    local tierNum = HeroData.GetTierFromStar(star)
    local tier = Config.STAR_TIERS[tierNum]
    local starInTier = star - tier.starRange[1] + 1
    local totalInTier = tier.starRange[2] - tier.starRange[1] + 1
    return {
        tierNum = tierNum,
        name = tier.name,
        color = tier.color,
        starInTier = starInTier,
        totalInTier = totalInTier,
    }
end

--- 获取星级段颜色（供 Renderer 使用）
---@param heroId string
---@return table  { r, g, b }
function HeroData.GetStarTierColor(heroId)
    local info = HeroData.GetStarTierInfo(heroId)
    return info.color
end

--- 计算升星所需碎片（当前星→下一星）
---@param star number  当前星数
---@return number cost, boolean isTierAdvance
function HeroData.GetStarUpCost(star)
    if star >= Config.MAX_HERO_STAR then
        return 0, false
    end
    local nextStar = star + 1
    local nextTier = HeroData.GetTierFromStar(nextStar)
    local costPerStar = Config.STAR_COST_PER_TIER[nextTier] or 400
    -- 判断是否为段进阶（进入新段的第1颗星）
    local currentTier = star > 0 and HeroData.GetTierFromStar(star) or 0
    local isTierAdvance = (nextTier > currentTier)
    return costPerStar, isTierAdvance
end

--- 升星（消耗碎片）
---@param heroId string
---@return boolean, string  -- success, message
function HeroData.StarUp(heroId)
    local h = HeroData.heroes[heroId]
    if not h or not h.unlocked then
        return false, "英雄未解锁"
    end
    if h.star >= Config.MAX_HERO_STAR then
        return false, "已达最高星级(30星)"
    end

    local cost, isTierAdvance = HeroData.GetStarUpCost(h.star)
    if h.fragments < cost then
        return false, "碎片不足(需要" .. cost .. "，当前" .. h.fragments .. ")"
    end

    h.fragments = h.fragments - cost
    h.star = h.star + 1

    -- 检查觉醒
    HeroData.CheckAwakening(heroId)

    HeroData.Save()

    local tierInfo = HeroData.GetStarTierInfo(heroId)
    local msg = tierInfo.name .. " " .. tierInfo.starInTier .. "/" .. tierInfo.totalInTier
    if isTierAdvance then
        msg = "突破! " .. msg
    end
    print("[HeroData] " .. heroId .. " star up to " .. h.star .. " (" .. msg .. ")")
    return true, msg
end

--- 计算升星带来的全属性倍率（乘算，对齐咸鱼之王）
--- 黄紫橙红: 每星 ×1.10 | 皇冠紫晶: 每星 ×1.15 | 段突破: ×1.40
--- 30星满: 1.10^20 × 1.15^10 × 1.40^4 ≈ ×104.5
---@param heroId string
---@return number
function HeroData.GetStarMultiplier(heroId)
    local h = HeroData.heroes[heroId]
    if not h then return 1.0 end
    local star = h.star or 0
    if star <= 0 then return 1.0 end

    local mult = 1.0
    local crownStart = Config.STAR_CROWN_START  -- 21
    local normalMult = Config.STAR_NORMAL_MULT  -- 1.10
    local crownMult = Config.STAR_CROWN_MULT    -- 1.15
    local tierAdvMult = Config.TIER_ADVANCE_MULT -- 1.40

    -- 逐星计算（含段进阶）
    local prevTier = 0
    for s = 1, star do
        local curTier = HeroData.GetTierFromStar(s)
        -- 进入新段时触发段进阶加成
        if curTier > prevTier and prevTier > 0 then
            mult = mult * tierAdvMult
        end
        -- 每星乘算
        if s >= crownStart then
            mult = mult * crownMult
        else
            mult = mult * normalMult
        end
        prevTier = curTier
    end

    return mult
end

-- ============================================================================
-- 觉醒系统
-- ============================================================================

--- 根据星级检查并更新觉醒等级
---@param heroId string
function HeroData.CheckAwakening(heroId)
    local h = HeroData.heroes[heroId]
    if not h then return end
    local oldAwaken = h.awakening or 0
    local newAwaken = 0
    for i, threshold in ipairs(Config.AWAKENING_STAR_THRESHOLDS) do
        if h.star >= threshold then
            newAwaken = i
        end
    end
    if newAwaken > oldAwaken then
        h.awakening = newAwaken
        print("[HeroData] " .. heroId .. " awakened to level " .. newAwaken .. "!")
    end
end

-- ============================================================================
-- 技能系统（等级解锁）
-- ============================================================================

--- 获取英雄已解锁的技能列表（按等级解锁）
---@param heroId string
---@return table  -- array of skill definitions
function HeroData.GetUnlockedSkills(heroId)
    local h = HeroData.heroes[heroId]
    if not h or not h.unlocked then return {} end

    local skillDefs = Config.HERO_SKILLS[heroId]
    if not skillDefs then return {} end

    local skills = {}
    for i, skillDef in ipairs(skillDefs) do
        local unlockLv = Config.SKILL_UNLOCK_LEVELS[i] or 999
        if h.level >= unlockLv then
            skills[#skills + 1] = skillDef
        end
    end
    return skills
end

-- ============================================================================
-- 等级系统（6000级 + 进阶石门槛）
-- ============================================================================

--- 获取英雄已完成的进阶次数
---@param heroId string
---@return number  0-20
function HeroData.GetAdvanceLevel(heroId)
    local h = HeroData.heroes[heroId]
    return (h and h.advanceLevel) or 0
end

--- 获取下一个进阶门槛（如果当前等级恰好在门槛处）
--- 返回 nil 表示无需进阶
---@param heroId string
---@return table|nil  { level, stones, bonus, gateIndex }
function HeroData.GetPendingAdvanceGate(heroId)
    local h = HeroData.heroes[heroId]
    if not h then return nil end
    local advLv = h.advanceLevel or 0
    local nextGateIdx = advLv + 1
    local gate = Config.ADVANCE_GATES[nextGateIdx]
    if gate and h.level >= gate.level then
        return { level = gate.level, stones = gate.stones, bonus = gate.bonus, gateIndex = nextGateIdx }
    end
    return nil
end

--- 获取主角英雄等级
---@return number
function HeroData.GetLeaderLevel()
    local leader = HeroData.heroes[Config.LEADER_HERO.id]
    return (leader and leader.level) or 1
end

--- 获取当前等级上限（受进阶限制 + 主角等级限制）
--- 随从英雄: min(进阶上限, 主角等级)
--- 主角英雄: 仅受进阶上限
---@param heroId string
---@return number
function HeroData.GetCurrentLevelCap(heroId)
    local h = HeroData.heroes[heroId]
    if not h then return 1 end
    local advLv = h.advanceLevel or 0
    local nextGateIdx = advLv + 1
    local gate = Config.ADVANCE_GATES[nextGateIdx]
    local advanceCap = gate and gate.level or Config.MAX_LEVEL

    -- 随从英雄等级上限 = min(进阶上限, 主角等级)
    if heroId ~= Config.LEADER_HERO.id then
        local leaderLevel = HeroData.GetLeaderLevel()
        return math.min(advanceCap, leaderLevel)
    end

    return advanceCap
end

--- 进阶（消耗进阶石，突破等级门槛）
---@param heroId string
---@return boolean, string
function HeroData.Advance(heroId)
    local h = HeroData.heroes[heroId]
    if not h or not h.unlocked then
        return false, "英雄未解锁"
    end
    local gate = HeroData.GetPendingAdvanceGate(heroId)
    if not gate then
        return false, "无需进阶"
    end
    if (HeroData.currencies.devour_stone or 0) < gate.stones then
        return false, "噬魂石不足(需要" .. gate.stones .. "，当前" .. (HeroData.currencies.devour_stone or 0) .. ")"
    end

    HeroData.currencies.devour_stone = HeroData.currencies.devour_stone - gate.stones
    h.advanceLevel = gate.gateIndex
    HeroData.Save()
    print("[HeroData] " .. heroId .. " advanced to gate " .. gate.gateIndex .. " (Lv" .. gate.level .. "+)")
    return true, "进阶成功! 等级上限提升"
end

-- ============================================================================
-- 属性计算（对齐咸鱼之王量级）
-- 四维属性(ATK/HP/DEF/SPD): 基础 × 等级倍率 × 进阶倍率 × 升星倍率
--   等级倍率 = 1 + (level-1) × growthPct（百分比线性成长）
-- 战斗子属性(破甲/暴击/暴伤): 基础 + 等级线性成长（不受星/阶乘算）
--   → 后续装备/宝石/宠物等系统通过加算叠加到这些属性上
-- ============================================================================

--- 计算等级带来的全属性乘算倍率（百分比线性成长，对齐咸鱼之王）
--- 公式: 1 + (level - 1) × growthPct
--- 例: N级 growthPct=0.01, Lv30 → 1.29 (+29%), Lv100 → 1.99 (+99%)
---@param growthPct number  每级成长百分比（如 0.01 = 1%/级）
---@param level number  当前等级
---@return number  倍率（≥1.0）
local function CalcLevelMultiplier(growthPct, level)
    if level <= 1 then return 1.0 end
    return 1.0 + (level - 1) * growthPct
end

--- 计算进阶倍率（每阶 ×1.10，乘算，对齐咸鱼之王）
--- 20阶满: 1.10^20 ≈ ×6.73
---@param heroId string
---@return number
local function CalcAdvanceMultiplier(heroId)
    local h = HeroData.heroes[heroId]
    if not h then return 1.0 end
    local advLv = h.advanceLevel or 0
    if advLv <= 0 then return 1.0 end
    local mult = 1.0
    for i = 1, advLv do
        local gate = Config.ADVANCE_GATES[i]
        if gate then mult = mult * (1.0 + gate.bonus) end
    end
    return mult
end

--- 获取英雄完整属性（二维 + 战斗子属性）
--- 二维(ATK/SPD): 基础 × 等级倍率 × 进阶 × 升星
--- 战斗子属性(破甲/暴击/暴伤): 基础 + 等级线性成长（后续+装备+宝石等）
---@param heroId string
---@return table  { atk, spd, armorPen, critRate, critDmg, baseAtk, ... }
function HeroData.GetHeroStats(heroId)
    local base = Config.HERO_BASE_STATS[heroId]
    if not base then
        return {
            atk = 0, spd = 0,
            armorPen = 0, critRate = 0, critDmg = 0,
            baseAtk = 0, baseSpd = 0,
        }
    end
    local h = HeroData.heroes[heroId]
    local level = (h and h.level) or 1

    -- 等级成长倍率（百分比乘算，按品质查表）
    local rarity = Config.HERO_RARITY[heroId] or "N"
    local growthPct = Config.RARITY_GROWTH_PCT[rarity] or 0.01
    local levelMult = CalcLevelMultiplier(growthPct, level)

    -- 等级后裸属性
    local rawAtk = math.floor(base.atk * levelMult)

    -- 进阶倍率 × 升星倍率（仅作用于三维）
    local advMult = CalcAdvanceMultiplier(heroId)
    local starMult = HeroData.GetStarMultiplier(heroId)

    -- SPD: 分段线性增长，直接计算攻速加成比例（0 ~ SPD_BONUS_MAX）
    local totalMult = levelMult * advMult * starMult
    local spdBonus = 0
    local curve = Config.SPD_BONUS_CURVE
    if totalMult >= curve[#curve][1] then
        spdBonus = Config.SPD_BONUS_MAX
    else
        for i = 2, #curve do
            if totalMult <= curve[i][1] then
                local x0, y0 = curve[i - 1][1], curve[i - 1][2]
                local x1, y1 = curve[i][1], curve[i][2]
                spdBonus = y0 + (totalMult - x0) / (x1 - x0) * (y1 - y0)
                break
            end
        end
    end

    -- 战斗子属性: 基础 + 等级线性成长（不受星/阶乘算影响）
    -- 来源分离: 等级提供基础值，后续装备/宝石等系统加算叠加
    local n = math.max(0, level - 1)
    local armorPen = (base.armorPen or 0) + n * (base.armorPenGrowth or 0)
    local critRate = (base.critRate or 0) + n * (base.critRateGrowth or 0)
    local critDmg  = (base.critDmg or 0)  + n * (base.critDmgGrowth or 0)

    return {
        atk = math.floor(rawAtk * advMult * starMult),
        spd = math.floor(base.spd * (1 + spdBonus)),  -- 面板值: baseSpd × (1 + 加成)
        spdBonus = spdBonus,                            -- 攻速加成比例 (0~0.30)
        -- 战斗子属性（小数比例: 0.30 = 30%）
        armorPen = armorPen,
        critRate = critRate,
        critDmg  = critDmg,
        dmgBonus = 0,  -- 伤害加成%（由装备等系统赋值）
        elemDmgBonus = { fire = 0, ice = 0, lightning = 0, poison = 0, shadow = 0 },  -- 各元素伤害加成（由装备/宝石等系统赋值）
        baseAtk = base.atk,
        baseSpd = base.spd,
    }
end

--- 计算等级带来的射程加成
---@param heroId string
---@return number
function HeroData.GetLevelRangeBonus(heroId)
    local h = HeroData.heroes[heroId]
    if not h then return 0 end
    return (h.level - 1) * Config.LEVEL_RANGE_BONUS
end

--- 计算升级费用（分段公式，对齐咸鱼之王曲线）
--- 阶段1(1~100):    前期极便宜，快速冲级    ~57/级
--- 阶段2(101~500):  平稳过渡               ~60→1020/级
--- 阶段3(501~1500): 中期成长               ~1040→5.1万/级
--- 阶段4(1501~3600): 后期陡峭              ~5.1万→808万/级
--- 阶段5(3601+):    封顶固定值 807.8万/级
---@param level number 当前等级
---@return number
function HeroData.GetLevelUpCost(level)
    if level >= 3601 then
        return Config.LEVEL_COST_CAP  -- 807.8万 固定
    elseif level >= 1501 then
        -- 1501~3600: 二次增长，从~5.1万 平滑过渡到 ~808万
        local t = level - 1500
        return math.floor(51000 + t * 1200 + t * t * 1.249)
    elseif level >= 501 then
        -- 501~1500: 从~1040 到 ~5.1万
        local t = level - 500
        return math.floor(1040 + t * 20 + t * t * 0.03)
    elseif level >= 101 then
        -- 101~500: 从~61 到 ~1020
        local t = level - 100
        return math.floor(60 + t * 1.2 + t * t * 0.003)
    else
        -- 1~100: 10 + level × 0.5，极便宜
        return math.floor(10 + level * 0.5)
    end
end

--- 升级英雄（消耗金币，受进阶门槛限制）
---@param heroId string
---@return boolean, string  -- success, message
function HeroData.LevelUp(heroId)
    local h = HeroData.heroes[heroId]
    if not h or not h.unlocked then
        return false, "英雄未解锁"
    end

    if h.level >= Config.MAX_LEVEL then
        return false, "已达最高等级(Lv6000)"
    end

    -- 检查是否被等级上限卡住（进阶门槛 或 主角等级）
    local cap = HeroData.GetCurrentLevelCap(heroId)
    if h.level >= cap then
        -- 区分限制原因：主角等级不足 vs 需要进阶
        if heroId ~= Config.LEADER_HERO.id then
            local leaderLevel = HeroData.GetLeaderLevel()
            local advLv = h.advanceLevel or 0
            local nextGateIdx = advLv + 1
            local gate = Config.ADVANCE_GATES[nextGateIdx]
            local advanceCap = gate and gate.level or Config.MAX_LEVEL
            if leaderLevel < advanceCap then
                return false, "主角等级不足(Lv" .. leaderLevel .. ")，请先提升主角"
            end
        end
        return false, "需要进阶才能继续升级(Lv" .. cap .. ")"
    end

    local cost = HeroData.GetLevelUpCost(h.level)
    if (HeroData.currencies.nether_crystal or 0) < cost then
        return false, "冥晶不足(需要" .. cost .. ")"
    end

    HeroData.currencies.nether_crystal = HeroData.currencies.nether_crystal - cost
    h.level = h.level + 1
    HeroData.Save()
    print("[HeroData] " .. heroId .. " leveled up to Lv." .. h.level)
    return true, "升级成功 Lv." .. h.level
end

-- ============================================================================
-- 碎片 & 解锁
-- ============================================================================

--- 添加碎片（纯加碎片，不触发解锁）
---@param heroId string
---@param amount number
function HeroData.AddFragments(heroId, amount)
    local h = HeroData.heroes[heroId]
    if not h then return end
    h.fragments = h.fragments + amount
end

--- 首次获得英雄：直接解锁并设为1星（咸鱼之王机制）
---@param heroId string
function HeroData.UnlockHero(heroId)
    local h = HeroData.heroes[heroId]
    if not h or h.unlocked then return end
    h.unlocked = true
    h.star = 1
    print("[HeroData] " .. heroId .. " unlocked! (first pull, star=1)")
end

-- ============================================================================
-- 结算奖励
-- ============================================================================

--- 通关结算奖励（只有通关才调用，失败无奖励）
---@param stageNum number 通关的关卡号
---@param score number 得分
---@return table  -- { gold, fragments = {heroId=n}, diamonds, totalFragments }
function HeroData.SettleRewards(stageNum, score)
    local rewards = {
        nether_crystal = Config.SETTLE_BASE_GOLD + stageNum * Config.SETTLE_STAGE_GOLD,
        shadow_essence = math.floor(stageNum / Config.SETTLE_DIAMOND_INTERVAL) * Config.SETTLE_DIAMOND_AMOUNT,
        devour_stone = math.floor(stageNum / 5) * Config.SETTLE_STONE_PER_5,
        forge_iron = math.floor(stageNum / 3) * 2,
        void_pact = Config.SETTLE_TOKEN_BASE + math.floor(stageNum / 10) * Config.SETTLE_TOKEN_PER_10,
        fragments = {},  -- heroId -> count
        totalFragments = 0,
    }

    -- 碎片奖励: 基础 + 每5关额外
    local fragCount = Config.SETTLE_FRAGMENT_BASE + math.floor(stageNum / 5) * Config.SETTLE_FRAGMENT_PER_5
    local unlockedList = HeroData.GetUnlockedList()
    if #unlockedList == 0 then
        unlockedList = Config.DEFAULT_UNLOCKED
    end
    for i = 1, fragCount do
        local heroId = unlockedList[math.random(1, #unlockedList)]
        rewards.fragments[heroId] = (rewards.fragments[heroId] or 0) + 1
        rewards.totalFragments = rewards.totalFragments + 1
    end

    -- 发放奖励（新货币体系）
    local Currency = require("Game.Currency")
    Currency.Add("nether_crystal", rewards.nether_crystal)
    Currency.Add("shadow_essence", rewards.shadow_essence)
    Currency.Add("devour_stone", rewards.devour_stone)
    Currency.Add("forge_iron", rewards.forge_iron)
    Currency.Add("void_pact", rewards.void_pact)
    for heroId, count in pairs(rewards.fragments) do
        HeroData.AddFragments(heroId, count)
    end

    -- 更新统计
    HeroData.stats.totalGames = HeroData.stats.totalGames + 1
    if stageNum > (HeroData.stats.bestStage or 0) then
        HeroData.stats.bestStage = stageNum
        -- 上传主线排行榜
        local ok, LB = pcall(require, "Game.LeaderboardData")
        if ok then LB.UploadCampaign(stageNum) end
    end

    HeroData.Save()
    print("[HeroData] Settlement: stage " .. stageNum ..
          " crystal+" .. rewards.nether_crystal ..
          " essence+" .. rewards.shadow_essence ..
          " stone+" .. rewards.devour_stone ..
          " iron+" .. rewards.forge_iron ..
          " pact+" .. rewards.void_pact ..
          " fragments+" .. rewards.totalFragments)
    return rewards
end

-- ============================================================================
-- 挂机离线收益
-- ============================================================================

--- 计算离线挂机收益（不发放，仅计算）
---@return table|nil  rewards { seconds, nether_crystal, devour_stone, forge_iron } 或 nil（时间不足）
function HeroData.CalcIdleRewards()
    local lastTime = HeroData.lastSaveTime or 0
    if lastTime <= 0 then return nil end

    local now = os.time()
    local elapsed = now - lastTime
    if elapsed < Config.IDLE_MIN_SECONDS then return nil end

    -- 上限4小时
    local capped = math.min(elapsed, Config.IDLE_MAX_SECONDS)
    local hours = capped / 3600

    -- 关卡决定每小时收益
    local stage = HeroData.stats.bestStage or 0
    local crystalPerH = Config.IDLE_CRYSTAL_BASE + stage * Config.IDLE_CRYSTAL_PER_STAGE
    local stonePerH = Config.IDLE_STONE_PER_HOUR + math.floor(stage / 5)
    local ironPerH = Config.IDLE_IRON_PER_HOUR + math.floor(stage / 8)

    -- 宝箱掉落计算
    local chestDrops = {}  -- { wood=N, bronze=N, ... }
    -- 阶梯掉落
    if Config.IDLE_CHEST_DROPS then
        for _, rule in ipairs(Config.IDLE_CHEST_DROPS) do
            if hours >= rule.minHours then
                for id, count in pairs(rule.chests) do
                    chestDrops[id] = (chestDrops[id] or 0) + count
                end
            end
        end
    end
    -- 随机掉落（每小时判定一次）
    if Config.IDLE_CHEST_RANDOM then
        local fullHours = math.floor(hours)
        for _, rule in ipairs(Config.IDLE_CHEST_RANDOM) do
            for _ = 1, fullHours do
                if math.random() < rule.chancePerHour then
                    chestDrops[rule.id] = (chestDrops[rule.id] or 0) + 1
                end
            end
        end
    end

    return {
        seconds = capped,
        nether_crystal = math.floor(crystalPerH * hours),
        devour_stone = math.floor(stonePerH * hours),
        forge_iron = math.floor(ironPerH * hours),
        chestDrops = chestDrops,
        isOffline = true,  -- 标记为离线收益（区别于在线挂机）
    }
end

--- 领取挂机收益（发放到账户）
---@param rewards table  CalcIdleRewards 的返回值
function HeroData.ClaimIdleRewards(rewards)
    if not rewards then return end
    local Currency = require("Game.Currency")
    Currency.Add("nether_crystal", rewards.nether_crystal)
    Currency.Add("devour_stone", rewards.devour_stone)
    Currency.Add("forge_iron", rewards.forge_iron)

    -- 发放宝箱
    if rewards.chestDrops then
        local ChestData = require("Game.ChestData")
        for id, count in pairs(rewards.chestDrops) do
            if count > 0 then
                ChestData.Add(id, count)
                print("[HeroData] Idle chest drop: " .. id .. " x" .. count)
            end
        end
        ChestData.Save()
    end

    -- 重置时间戳
    HeroData.lastSaveTime = os.time()
    HeroData.Save()
    print("[HeroData] Idle rewards claimed: crystal+" .. rewards.nether_crystal ..
          " stone+" .. rewards.devour_stone ..
          " iron+" .. rewards.forge_iron ..
          " (" .. math.floor(rewards.seconds / 60) .. " min)")
end

return HeroData
