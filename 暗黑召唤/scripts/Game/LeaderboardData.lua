-- Game/LeaderboardData.lua
-- 排行榜数据模块：主线关卡、试练塔、资源副本排行榜
-- 基于 clientCloud iscores 排行榜 API

local HeroData = require("Game.HeroData")

local LB = {}

-- ============================================================================
-- 排行榜 key 定义（iscores 中的 key）
-- ============================================================================

LB.KEY_CAMPAIGN    = "lb_campaign"     -- 主线最高关卡
LB.KEY_TOWER       = "lb_tower"        -- 试练塔最高层
LB.KEY_DUNGEON     = "lb_dungeon"      -- 资源副本当天最高波次（每日重置上传）

-- 本地缓存
LB._cache = {
    campaign = nil,  -- { list, myRank, myScore, total, loadedCount }
    tower    = nil,
    dungeon  = nil,
}

-- ============================================================================
-- 分数上传
-- ============================================================================

--- 上传主线最高关卡到排行榜
---@param bestStage number
function LB.UploadCampaign(bestStage)
    if not bestStage or bestStage <= 0 then return end
    if not clientCloud then return end
    clientCloud:SetInt(LB.KEY_CAMPAIGN, bestStage, {
        ok = function()
            print("[LB] Campaign score uploaded: " .. bestStage)
        end,
    })
end

--- 上传试练塔最高层到排行榜
---@param floor number
function LB.UploadTower(floor)
    if not floor or floor <= 0 then return end
    if not clientCloud then return end
    clientCloud:SetInt(LB.KEY_TOWER, floor, {
        ok = function()
            print("[LB] Tower score uploaded: " .. floor)
        end,
    })
end

--- 上传资源副本当天最高波次
---@param wave number
function LB.UploadDungeon(wave)
    if not wave or wave <= 0 then return end
    if not clientCloud then return end
    clientCloud:SetInt(LB.KEY_DUNGEON, wave, {
        ok = function()
            print("[LB] Dungeon score uploaded: " .. wave)
        end,
    })
end

--- 同步所有排行榜分数（游戏初始化 / Save 时调用）
function LB.SyncAll()
    if not clientCloud then return end
    local bestStage = (HeroData.stats and HeroData.stats.bestStage) or 0
    if bestStage > 0 then
        LB.UploadCampaign(bestStage)
    end
    local ok1, TTD = pcall(require, "Game.TrialTowerData")
    if ok1 then
        local tData = TTD.GetData()
        local floor = (tData.currentFloor or 1) - 1  -- currentFloor 是下一层，所以 -1 = 已通关层
        if floor > 0 then
            LB.UploadTower(floor)
        end
    end
    -- 资源副本取所有副本中最高的 bestWave
    local ok2, RD = pcall(require, "Game.ResourceDungeonData")
    if ok2 then
        local maxWave = 0
        for _, def in ipairs(RD.DUNGEON_DEFS) do
            local w = RD.GetBestWave(def.key)
            if w > maxWave then maxWave = w end
        end
        if maxWave > 0 then
            LB.UploadDungeon(maxWave)
        end
    end
end

-- ============================================================================
-- 排行榜查询
-- ============================================================================

--- 加载排行榜列表
---@param key string      排行榜 key
---@param start number    起始位置 (0-based)
---@param count number    获取数量
---@param callback function(list, myRank, myScore, total)
function LB.FetchRankList(key, start, count, callback)
    if not clientCloud then
        if callback then callback(nil) end
        return
    end

    clientCloud:GetRankList(key, start, count, {
        ok = function(rankList)
            local list = {}
            local userIds = {}
            for i, item in ipairs(rankList) do
                list[#list + 1] = {
                    rank = start + i,
                    userId = item.userId,
                    score = item.iscore[key] or 0,
                    isMe = item.userId == clientCloud.userId,
                    nickname = nil,
                }
                userIds[#userIds + 1] = item.userId
            end
            -- 获取昵称
            if #userIds > 0 then
                GetUserNickname({
                    userIds = userIds,
                    onSuccess = function(nicknames)
                        local map = {}
                        for _, info in ipairs(nicknames) do
                            map[info.userId] = info.nickname or ""
                        end
                        for _, entry in ipairs(list) do
                            entry.nickname = map[entry.userId] or "玩家"
                        end
                        if callback then callback(list) end
                    end,
                    onError = function()
                        -- 昵称查询失败，使用默认
                        for _, entry in ipairs(list) do
                            entry.nickname = "玩家"
                        end
                        if callback then callback(list) end
                    end,
                })
            else
                if callback then callback(list) end
            end
        end,
        error = function()
            if callback then callback(nil) end
        end,
    })
end

--- 获取自己的排名
---@param key string
---@param callback function(rank, score)  rank=nil 表示未上榜
function LB.FetchMyRank(key, callback)
    if not clientCloud then
        if callback then callback(nil, 0) end
        return
    end
    clientCloud:GetUserRank(clientCloud.userId, key, {
        ok = function(rank, scoreValue)
            if callback then callback(rank, scoreValue or 0) end
        end,
        error = function()
            if callback then callback(nil, 0) end
        end,
    })
end

--- 获取排行榜总人数
---@param key string
---@param callback function(total)
function LB.FetchRankTotal(key, callback)
    if not clientCloud then
        if callback then callback(0) end
        return
    end
    clientCloud:GetRankTotal(key, {
        ok = function(total)
            if callback then callback(total or 0) end
        end,
        error = function()
            if callback then callback(0) end
        end,
    })
end

-- ============================================================================
-- 主线关卡号显示格式化（关卡号 → "大关-小关"）
-- ============================================================================

--- 格式化关卡号为 "第X关" 格式
---@param stageNum number
---@return string
function LB.FormatStage(stageNum)
    if not stageNum or stageNum <= 0 then return "—" end
    return "第" .. stageNum .. "关"
end

--- 格式化试练塔层数为 "第X层" 格式
---@param floor number
---@return string
function LB.FormatTower(floor)
    if not floor or floor <= 0 then return "—" end
    return "第" .. floor .. "层"
end

--- 格式化资源副本波次为 "第X波" 格式
---@param wave number
---@return string
function LB.FormatDungeon(wave)
    if not wave or wave <= 0 then return "—" end
    return "第" .. wave .. "波"
end

return LB
