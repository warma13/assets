-- Game/ChestData.lua
-- 宝箱系统数据与开箱逻辑（对齐咸鱼之王）
-- 5种品质宝箱，开箱获得货币+碎片，积分进度奖励

local Config = require("Game.Config")
local HeroData = require("Game.HeroData")

local ChestData = {}

-- 宝箱库存 { wood=N, bronze=N, gold=N, platinum=N, diamond=N }
ChestData.inventory = {}
-- 当前积分（一轮内）
ChestData.score = 0
-- 已领取的积分里程碑索引
ChestData.claimedMilestones = {}

--- 初始化默认数据
function ChestData.InitDefault()
    ChestData.inventory = {}
    for _, ct in ipairs(Config.CHEST_TYPES) do
        ChestData.inventory[ct.id] = Config.CHEST_INITIAL[ct.id] or 0
    end
    ChestData.score = 0
    ChestData.claimedMilestones = {}
end

--- 从 HeroData 加载宝箱存档
function ChestData.Load()
    local saved = HeroData.chestData
    if saved and saved.inventory then
        ChestData.inventory = saved.inventory
        ChestData.score = saved.score or 0
        ChestData.claimedMilestones = saved.claimedMilestones or {}
        -- 确保所有宝箱类型都有键
        for _, ct in ipairs(Config.CHEST_TYPES) do
            if not ChestData.inventory[ct.id] then
                ChestData.inventory[ct.id] = 0
            end
        end
    else
        ChestData.InitDefault()
    end
end

--- 保存到 HeroData（通过 setter 自动包装 SafeTable 混淆）
function ChestData.Save()
    HeroData.SetChestData({
        inventory = ChestData.inventory,
        score = ChestData.score,
        claimedMilestones = ChestData.claimedMilestones,
    })
    HeroData.Save()
end

--- 获取宝箱配置
---@param chestId string
---@return table|nil
function ChestData.GetChestDef(chestId)
    for _, ct in ipairs(Config.CHEST_TYPES) do
        if ct.id == chestId then return ct end
    end
    return nil
end

--- 获取库存数量
---@param chestId string
---@return number
function ChestData.GetCount(chestId)
    return ChestData.inventory[chestId] or 0
end

--- 添加宝箱
---@param chestId string
---@param count number
function ChestData.Add(chestId, count)
    ChestData.inventory[chestId] = (ChestData.inventory[chestId] or 0) + count
end

--- 通关奖励宝箱
---@param stageNum number
function ChestData.GrantStageDrop(stageNum)
    local drop = Config.CHEST_STAGE_DROP
    -- 每关都给
    if drop.perStage then
        for id, count in pairs(drop.perStage) do
            ChestData.Add(id, count)
        end
    end
    -- 每5关
    if drop.per5Stage and stageNum % 5 == 0 then
        for id, count in pairs(drop.per5Stage) do
            ChestData.Add(id, count)
        end
    end
    -- 每10关
    if drop.per10Stage and stageNum % 10 == 0 then
        for id, count in pairs(drop.per10Stage) do
            ChestData.Add(id, count)
        end
    end
    ChestData.Save()
    print("[ChestData] Stage " .. stageNum .. " drop granted")
end

--- 执行单次掉落判定
---@param dropDef table  { type, rarity, min, max, chance }
---@return table|nil  { type, amount, heroId?, heroName? }
local function RollDrop(dropDef)
    if math.random() > dropDef.chance then return nil end

    local amount = math.random(dropDef.min, dropDef.max)

    if dropDef.type == "fragment_random" then
        -- 从指定稀有度随机一个英雄
        local pool = Config.RECRUIT_POOL[dropDef.rarity]
        if not pool or #pool == 0 then return nil end
        local heroId = pool[math.random(1, #pool)]
        local heroName = heroId
        for _, td in ipairs(Config.TOWER_TYPES) do
            if td.id == heroId then heroName = td.name; break end
        end
        return {
            type = "fragment",
            rarity = dropDef.rarity,
            heroId = heroId,
            heroName = heroName,
            amount = amount,
        }
    else
        -- 货币类型
        return {
            type = dropDef.type,
            amount = amount,
        }
    end
end

--- 开箱（批量）
---@param chestId string
---@param count number  要开的数量（最多10）
---@return boolean success
---@return table|string  results数组 或 错误信息
function ChestData.Open(chestId, count)
    local def = ChestData.GetChestDef(chestId)
    if not def then return false, "未知宝箱类型" end

    local available = ChestData.GetCount(chestId)
    if available <= 0 then return false, "宝箱数量不足" end

    count = math.min(count, available, 10)

    -- 每次开箱独立记录
    local drops = {}    -- { {type, id, name, amount, rarity}, ... } 按顺序记录每个掉落
    local totalScore = 0

    for _ = 1, count do
        -- 扣库存
        ChestData.inventory[chestId] = ChestData.inventory[chestId] - 1
        -- 加积分
        totalScore = totalScore + def.score

        -- 判定掉落
        for _, dropDef in ipairs(def.drops) do
            local result = RollDrop(dropDef)
            if result then
                if result.type == "fragment" then
                    -- 咸鱼之王机制：首次获得解锁，重复给碎片
                    local isNew = not HeroData.IsUnlocked(result.heroId)
                    if isNew then
                        HeroData.UnlockHero(result.heroId)
                    else
                        HeroData.AddFragments(result.heroId, result.amount)
                    end
                    drops[#drops + 1] = {
                        kind = "fragment",
                        heroId = result.heroId,
                        heroName = result.heroName,
                        rarity = result.rarity,
                        amount = isNew and 0 or result.amount,
                        isNew = isNew,
                    }
                else
                    -- 货币
                    drops[#drops + 1] = {
                        kind = "currency",
                        currType = result.type,
                        amount = result.amount,
                    }
                    if HeroData.currencies[result.type] ~= nil then
                        HeroData.currencies[result.type] = HeroData.currencies[result.type] + result.amount
                    end
                end
            end
        end
    end

    -- 加积分
    ChestData.score = ChestData.score + totalScore

    -- 开服好礼任务追踪
    local ok, LGD = pcall(require, "Game.LaunchGiftData")
    if ok and LGD then LGD.AddProgress("chest", count) end
    -- 每日任务追踪
    local ok2, DTD = pcall(require, "Game.DailyTaskData")
    if ok2 and DTD then DTD.AddProgress("chest", count) end

    ChestData.Save()

    print("[ChestData] Opened " .. count .. "x " .. def.name ..
        " score+" .. totalScore .. " totalScore=" .. ChestData.score)

    return true, {
        count = count,
        chestName = def.name,
        drops = drops,
        scoreGained = totalScore,
        totalScore = ChestData.score,
    }
end

--- 计算各里程碑的累计积分阈值
---@return table  { {cumScore=10, delta=10, reward="bronze", index=1}, ... }
function ChestData.GetMilestoneThresholds()
    local thresholds = {}
    local cumulative = 0
    for i, ms in ipairs(Config.CHEST_SCORE_MILESTONES) do
        cumulative = cumulative + ms.delta
        thresholds[i] = {
            cumScore = cumulative,
            delta = ms.delta,
            reward = ms.reward,
            index = i,
        }
    end
    return thresholds
end

--- 检查当前里程碑是否可领取
---@return boolean canClaim
---@return table|nil milestoneInfo  { index, cumScore, reward }
function ChestData.CanClaimMilestone()
    local thresholds = ChestData.GetMilestoneThresholds()
    for _, t in ipairs(thresholds) do
        if not ChestData.claimedMilestones[t.index] then
            -- 找到第一个未领取的里程碑
            if ChestData.score >= t.cumScore then
                return true, t
            end
            return false, t
        end
    end
    return false, nil
end

--- 手动领取当前里程碑奖励
---@return boolean success
---@return table|nil reward  { type="chest", id=string, amount=1 }
function ChestData.ClaimMilestone()
    local canClaim, milestone = ChestData.CanClaimMilestone()
    if not canClaim or not milestone then
        print("[ChestData] ClaimMilestone: nothing to claim")
        return false, nil
    end

    -- 标记已领取
    ChestData.claimedMilestones[milestone.index] = true
    -- 发放奖励宝箱 x1
    ChestData.Add(milestone.reward, 1)

    local reward = { type = "chest", id = milestone.reward, amount = 1 }
    print("[ChestData] Milestone " .. milestone.index .. " claimed (cumScore=" .. milestone.cumScore .. " reward=" .. milestone.reward .. ")")

    -- 检查是否一轮全部领完 → 循环重置
    local thresholds = ChestData.GetMilestoneThresholds()
    local allClaimed = true
    for i = 1, #thresholds do
        if not ChestData.claimedMilestones[i] then
            allClaimed = false
            break
        end
    end
    if allClaimed and ChestData.score >= Config.CHEST_SCORE_CYCLE then
        ChestData.score = ChestData.score - Config.CHEST_SCORE_CYCLE
        ChestData.claimedMilestones = {}
        print("[ChestData] Cycle complete, score reset to " .. ChestData.score)
    end

    ChestData.Save()
    return true, reward
end

--- 获取当前里程碑进度信息
---@return table info { score, segStart, segEnd, remaining, nextChestId, allClaimed, cycleMax }
function ChestData.GetScoreProgress()
    local thresholds = ChestData.GetMilestoneThresholds()
    local prevCum = 0

    for _, t in ipairs(thresholds) do
        if not ChestData.claimedMilestones[t.index] then
            return {
                score = ChestData.score,
                segStart = prevCum,
                segEnd = t.cumScore,
                remaining = math.max(0, t.cumScore - ChestData.score),
                nextChestId = t.reward,
                allClaimed = false,
                cycleMax = Config.CHEST_SCORE_CYCLE,
            }
        end
        prevCum = t.cumScore
    end

    -- 全部已领取
    return {
        score = ChestData.score,
        segStart = prevCum,
        segEnd = Config.CHEST_SCORE_CYCLE,
        remaining = 0,
        nextChestId = nil,
        allClaimed = true,
        cycleMax = Config.CHEST_SCORE_CYCLE,
    }
end

--- 重置积分（手动）
function ChestData.ResetScore()
    ChestData.score = 0
    ChestData.claimedMilestones = {}
    ChestData.Save()
    print("[ChestData] Score reset manually")
end

return ChestData
