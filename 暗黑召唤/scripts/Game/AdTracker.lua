-- Game/AdTracker.lua
-- 统一广告观看统计
-- 所有广告成功回调后调用 AdTracker.Record()，集中统计今日/总计观看数

local HeroData = require("Game.HeroData")

local AdTracker = {}

---@return string
local function TodayStr()
    return os.date("%Y-%m-%d")
end

--- 获取内部数据（懒加载）
---@return table { date: string, todayCount: number, totalCount: number }
local function GetData()
    local d = HeroData.stats.adTracker
    if not d then
        d = { date = TodayStr(), todayCount = 0, totalCount = 0 }
        HeroData.stats.adTracker = d
    end
    -- 跨天重置今日计数
    if d.date ~= TodayStr() then
        d.date = TodayStr()
        d.todayCount = 0
    end
    return d
end

--- 记录一次成功的广告观看
function AdTracker.Record()
    local d = GetData()
    d.todayCount = d.todayCount + 1
    d.totalCount = (d.totalCount or 0) + 1
    HeroData.Save()
    print("[AdTracker] Ad watched: today=" .. d.todayCount .. " total=" .. d.totalCount)
end

--- 获取今日已观看广告数
---@return number
function AdTracker.GetTodayCount()
    return GetData().todayCount
end

--- 获取总计观看广告数
---@return number
function AdTracker.GetTotalCount()
    return GetData().totalCount or 0
end

return AdTracker
