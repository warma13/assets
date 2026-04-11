-- Game/LaunchGiftData.lua
-- 开服好礼系统：每日免费20抽 + 每日任务积分 + 里程碑奖励

local HeroData = require("Game.HeroData")
local Currency = require("Game.Currency")

local LaunchGiftData = {}

-- ============================================================================
-- 配置
-- ============================================================================

--- 每日免费招募次数
LaunchGiftData.DAILY_FREE_PULLS = 20

--- 活动持续天数（开服后7天）
LaunchGiftData.EVENT_DAYS = 7

--- 每日任务定义 { id, desc, target, points }
LaunchGiftData.DAILY_TASKS = {
    { id = "summon",  desc = "召唤5次英雄",   target = 5,  points = 10 },
    { id = "merge",   desc = "合成3次英雄",   target = 3,  points = 10 },
    { id = "stage",   desc = "通关1个关卡",   target = 1,  points = 15 },
    { id = "chest",   desc = "开启3个宝箱",   target = 3,  points = 10 },
    { id = "signin",  desc = "完成每日签到",   target = 1,  points = 5  },
}

--- 里程碑奖励 { threshold, rewards, desc }
LaunchGiftData.MILESTONES = {
    { threshold = 10,  desc = "冥晶x200",
      rewards = { { type = "currency", id = "nether_crystal", amount = 200 } } },
    { threshold = 25,  desc = "噬魂石x20",
      rewards = { { type = "currency", id = "devour_stone", amount = 20 } } },
    { threshold = 40,  desc = "虚空契约x10",
      rewards = { { type = "currency", id = "void_pact", amount = 10 } } },
    { threshold = 60,  desc = "锻魂铁x20",
      rewards = { { type = "currency", id = "forge_iron", amount = 20 } } },
    { threshold = 80,  desc = "朽木宝箱x10",
      rewards = { { type = "chest", id = "bronze_chest", amount = 10 } } },
    { threshold = 100, desc = "万能UR碎片箱x3",
      rewards = { { type = "item", id = "ur_shard_box", amount = 3 } } },
}

-- ============================================================================
-- 数据访问
-- ============================================================================

--- 获取当前日期字符串（YYYY-MM-DD）
---@return string
local function TodayStr()
    return os.date("%Y-%m-%d")
end

--- 确保数据结构存在（懒初始化）
---@return table data
function LaunchGiftData.EnsureData()
    if not HeroData.launchGiftData then
        HeroData.launchGiftData = {
            startDate = TodayStr(),       -- 活动开始日期
            dailyClaimed = "",            -- 上次领取每日免费抽的日期
            taskProgress = {},            -- { summon=N, merge=N, ... } 今日进度
            taskClaimed = {},             -- { summon=true, ... } 今日已领取
            lastTaskDate = "",            -- 任务进度所属日期
            totalPoints = 0,              -- 累计积分（永不重置）
            milestonesClaimed = {},       -- { [1]=true, [2]=true, ... } 已领取里程碑
        }
    end
    return HeroData.launchGiftData
end

--- 检查今日是否需要重置任务进度
local function CheckDailyReset(data)
    local today = TodayStr()
    if data.lastTaskDate ~= today then
        data.taskProgress = {}
        data.taskClaimed = {}
        data.lastTaskDate = today
    end
end

--- 活动是否仍在有效期内
---@return boolean
function LaunchGiftData.IsActive()
    local data = LaunchGiftData.EnsureData()
    if not data.startDate or data.startDate == "" then return true end
    -- 简单判断：开始日期后 EVENT_DAYS 天
    local startY, startM, startD = data.startDate:match("(%d+)-(%d+)-(%d+)")
    if not startY then return true end
    local startTime = os.time({ year = tonumber(startY), month = tonumber(startM),
                                day = tonumber(startD), hour = 0 })
    local endTime = startTime + LaunchGiftData.EVENT_DAYS * 86400
    return os.time() < endTime
end

--- 获取活动剩余天数
---@return number
function LaunchGiftData.GetRemainingDays()
    local data = LaunchGiftData.EnsureData()
    if not data.startDate or data.startDate == "" then return LaunchGiftData.EVENT_DAYS end
    local startY, startM, startD = data.startDate:match("(%d+)-(%d+)-(%d+)")
    if not startY then return LaunchGiftData.EVENT_DAYS end
    local startTime = os.time({ year = tonumber(startY), month = tonumber(startM),
                                day = tonumber(startD), hour = 0 })
    local endTime = startTime + LaunchGiftData.EVENT_DAYS * 86400
    local remaining = math.ceil((endTime - os.time()) / 86400)
    return math.max(0, remaining)
end

-- ============================================================================
-- 每日免费招募
-- ============================================================================

--- 今日是否已领取免费招募
---@return boolean
function LaunchGiftData.HasClaimedDailyPulls()
    local data = LaunchGiftData.EnsureData()
    return data.dailyClaimed == TodayStr()
end

--- 领取每日免费招募（加虚空契约）
---@return boolean success
---@return string msg
function LaunchGiftData.ClaimDailyPulls()
    if not LaunchGiftData.IsActive() then
        return false, "活动已结束"
    end
    local data = LaunchGiftData.EnsureData()
    if data.dailyClaimed == TodayStr() then
        return false, "今日已领取"
    end
    data.dailyClaimed = TodayStr()
    Currency.Add("void_pact", LaunchGiftData.DAILY_FREE_PULLS)
    HeroData.Save()
    print("[LaunchGift] Claimed daily " .. LaunchGiftData.DAILY_FREE_PULLS .. " pulls")
    return true, "获得 " .. LaunchGiftData.DAILY_FREE_PULLS .. " 次免费招募"
end

-- ============================================================================
-- 每日任务
-- ============================================================================

--- 增加任务进度（由各系统 hook 调用）
---@param taskId string  "summon"|"merge"|"stage"|"chest"|"signin"
---@param amount number
function LaunchGiftData.AddProgress(taskId, amount)
    if not LaunchGiftData.IsActive() then return end
    local data = LaunchGiftData.EnsureData()
    CheckDailyReset(data)
    data.taskProgress[taskId] = (data.taskProgress[taskId] or 0) + amount
    -- 不存档（由调用方保存或下次统一保存）
end

--- 获取任务进度
---@param taskId string
---@return number current, number target, boolean claimed
function LaunchGiftData.GetTaskProgress(taskId)
    local data = LaunchGiftData.EnsureData()
    CheckDailyReset(data)
    local taskDef = nil
    for _, t in ipairs(LaunchGiftData.DAILY_TASKS) do
        if t.id == taskId then taskDef = t; break end
    end
    if not taskDef then return 0, 0, false end
    local current = data.taskProgress[taskId] or 0
    local claimed = data.taskClaimed[taskId] or false
    return current, taskDef.target, claimed
end

--- 领取任务奖励（加积分）
---@param taskId string
---@return boolean success
---@return string msg
---@return number|nil pointsAwarded
function LaunchGiftData.ClaimTask(taskId)
    if not LaunchGiftData.IsActive() then
        return false, "活动已结束"
    end
    local data = LaunchGiftData.EnsureData()
    CheckDailyReset(data)

    local taskDef = nil
    for _, t in ipairs(LaunchGiftData.DAILY_TASKS) do
        if t.id == taskId then taskDef = t; break end
    end
    if not taskDef then return false, "未知任务" end

    if data.taskClaimed[taskId] then
        return false, "已领取"
    end
    local current = data.taskProgress[taskId] or 0
    if current < taskDef.target then
        return false, "未完成"
    end

    data.taskClaimed[taskId] = true
    data.totalPoints = data.totalPoints + taskDef.points
    HeroData.Save()
    print("[LaunchGift] Task " .. taskId .. " claimed, +" .. taskDef.points .. " pts, total=" .. data.totalPoints)
    return true, "+" .. taskDef.points .. " 积分", taskDef.points
end

--- 获取总积分
---@return number
function LaunchGiftData.GetTotalPoints()
    local data = LaunchGiftData.EnsureData()
    return data.totalPoints
end

-- ============================================================================
-- 里程碑奖励
-- ============================================================================

--- 检查里程碑是否可领取
---@param index number
---@return boolean canClaim, boolean claimed, boolean reached
function LaunchGiftData.GetMilestoneStatus(index)
    local data = LaunchGiftData.EnsureData()
    local milestone = LaunchGiftData.MILESTONES[index]
    if not milestone then return false, false, false end
    local claimed = data.milestonesClaimed[index] or false
    local reached = data.totalPoints >= milestone.threshold
    return reached and not claimed, claimed, reached
end

--- 领取里程碑奖励
---@param index number
---@return boolean success
---@return string msg
function LaunchGiftData.ClaimMilestone(index)
    if not LaunchGiftData.IsActive() then
        return false, "活动已结束"
    end
    local data = LaunchGiftData.EnsureData()
    local milestone = LaunchGiftData.MILESTONES[index]
    if not milestone then return false, "无效里程碑" end
    if data.milestonesClaimed[index] then
        return false, "已领取"
    end
    if data.totalPoints < milestone.threshold then
        return false, "积分不足"
    end

    data.milestonesClaimed[index] = true
    Currency.GrantRewards(milestone.rewards)
    HeroData.Save()
    print("[LaunchGift] Milestone " .. index .. " claimed: " .. milestone.desc)
    return true, "获得 " .. milestone.desc
end

--- 是否有任何可领取的内容（用于红点提示）
---@return boolean
function LaunchGiftData.HasClaimable()
    if not LaunchGiftData.IsActive() then return false end
    local data = LaunchGiftData.EnsureData()
    CheckDailyReset(data)

    -- 每日免费抽
    if data.dailyClaimed ~= TodayStr() then return true end

    -- 任务奖励（已完成但未领取）
    for _, t in ipairs(LaunchGiftData.DAILY_TASKS) do
        local current = data.taskProgress[t.id] or 0
        local claimed = data.taskClaimed[t.id] or false
        if current >= t.target and not claimed then return true end
    end

    -- 里程碑（已达成但未领取）
    for i, m in ipairs(LaunchGiftData.MILESTONES) do
        if data.totalPoints >= m.threshold and not (data.milestonesClaimed[i]) then
            return true
        end
    end

    return false
end

return LaunchGiftData
