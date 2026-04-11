-- Game/LeaderboardUI.lua
-- 排行榜 UI 面板：主线关卡排行，滚动列表 + 加载更多

local LB = require("Game.LeaderboardData")
local Toast = require("Game.Toast")

local LeaderboardUI = {}

---@type any
local UI = nil

-- 状态
local rankList = {}        -- 已加载的排名列表
local myRank = nil         -- 我的排名 (1-based, nil=未上榜)
local myScore = 0          -- 我的分数
local rankTotal = 0        -- 排行榜总人数
local loadedCount = 0      -- 已加载条数
local isLoading = false    -- 是否正在加载
local MAX_LOAD = 100       -- 最多加载 100 条
local PAGE_SIZE = 20       -- 每页 20 条

-- 配色
local C = {
    bg         = { 0, 0, 0, 200 },
    cardBg     = { 20, 16, 35, 245 },
    cardBorder = { 100, 60, 180, 180 },
    headerBg   = { 30, 22, 50, 255 },
    rowBg      = { 28, 22, 45, 220 },
    rowAlt     = { 35, 28, 55, 220 },
    rowMe      = { 60, 30, 100, 255 },
    gold       = { 255, 215, 80, 255 },
    silver     = { 200, 200, 220, 255 },
    bronze     = { 200, 150, 80, 255 },
    white      = { 245, 238, 225, 255 },
    dim        = { 150, 140, 160, 200 },
    purple     = { 160, 120, 240, 255 },
    green      = { 120, 220, 100, 255 },
    loadMore   = { 100, 80, 180, 255 },
}

-- ============================================================================
-- 创建排行榜浮层
-- ============================================================================

function LeaderboardUI.CreateOverlay(uiModule)
    UI = uiModule

    return UI.Panel {
        id = "leaderboardOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        visible = false,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = C.bg,
        pointerEvents = "auto",
        onClick = function(self)
            LeaderboardUI.Hide()
        end,
        children = {
            -- 居中卡片
            UI.Panel {
                width = 340, height = "80%",
                maxHeight = 520,
                flexDirection = "column",
                backgroundColor = C.cardBg,
                borderRadius = 16,
                borderWidth = 2,
                borderColor = C.cardBorder,
                overflow = "hidden",
                pointerEvents = "auto",
                onClick = function() end, -- 阻止冒泡关闭
                children = {
                    -- 标题栏
                    UI.Panel {
                        width = "100%", height = 46,
                        flexDirection = "row",
                        alignItems = "center",
                        justifyContent = "center",
                        backgroundColor = C.headerBg,
                        flexShrink = 0,
                        children = {
                            UI.Label {
                                text = "排行榜",
                                fontSize = 18,
                                fontWeight = "bold",
                                fontColor = C.gold,
                                pointerEvents = "none",
                            },
                            -- 关闭按钮
                            UI.Panel {
                                position = "absolute",
                                top = 4, right = 4,
                                width = 36, height = 36,
                                justifyContent = "center",
                                alignItems = "center",
                                pointerEvents = "auto",
                                onClick = function()
                                    LeaderboardUI.Hide()
                                end,
                                children = {
                                    UI.Label {
                                        text = "✕",
                                        fontSize = 18,
                                        fontColor = C.dim,
                                        pointerEvents = "none",
                                    },
                                },
                            },
                        },
                    },
                    -- 排名列表（ScrollView）
                    UI.ScrollView {
                        id = "lb_scrollView",
                        width = "100%",
                        flex = 1,
                        children = {
                            UI.Panel {
                                id = "lb_listContainer",
                                width = "100%",
                                flexDirection = "column",
                                children = {
                                    -- 初始加载提示
                                    UI.Panel {
                                        id = "lb_loadingHint",
                                        width = "100%", height = 60,
                                        justifyContent = "center",
                                        alignItems = "center",
                                        children = {
                                            UI.Label {
                                                text = "加载中...",
                                                fontSize = 14,
                                                fontColor = C.dim,
                                                pointerEvents = "none",
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    -- 底部固定：我的排名
                    UI.Panel {
                        id = "lb_myRankCard",
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        paddingLeft = 14, paddingRight = 14,
                        paddingTop = 10, paddingBottom = 10,
                        backgroundColor = { 40, 25, 65, 255 },
                        borderTopWidth = 1,
                        borderColor = { 80, 50, 120, 100 },
                        flexShrink = 0,
                        gap = 8,
                        children = {
                            UI.Label {
                                id = "lb_myRankLabel",
                                text = "加载中...",
                                fontSize = 13,
                                fontColor = C.purple,
                                pointerEvents = "none",
                            },
                        },
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- 显示 / 隐藏
-- ============================================================================

function LeaderboardUI.Show()
    local GameUI = require("Game.GameUI")
    local root = GameUI.GetUIRoot()
    if not root then return end

    local overlay = root:FindById("leaderboardOverlay")
    if overlay then
        overlay:SetVisible(true)
    end

    -- 重置状态并加载数据
    rankList = {}
    myRank = nil
    myScore = 0
    rankTotal = 0
    loadedCount = 0
    isLoading = false

    LeaderboardUI.LoadMyRank()
    LeaderboardUI.LoadMore()
end

function LeaderboardUI.Hide()
    local GameUI = require("Game.GameUI")
    local root = GameUI.GetUIRoot()
    if not root then return end

    local overlay = root:FindById("leaderboardOverlay")
    if overlay then
        overlay:SetVisible(false)
    end
end

-- ============================================================================
-- 数据加载
-- ============================================================================

function LeaderboardUI.LoadMyRank()
    LB.FetchMyRank(LB.KEY_CAMPAIGN, function(rank, score)
        myRank = rank
        myScore = score or 0
        LeaderboardUI.UpdateMyRankCard()
    end)

    LB.FetchRankTotal(LB.KEY_CAMPAIGN, function(total)
        rankTotal = total or 0
        LeaderboardUI.UpdateMyRankCard()
    end)
end

function LeaderboardUI.LoadMore()
    if isLoading then return end
    if loadedCount >= MAX_LOAD then
        Toast.Show("已加载全部排名", C.dim)
        return
    end

    isLoading = true
    local start = loadedCount  -- 0-based

    LB.FetchRankList(LB.KEY_CAMPAIGN, start, PAGE_SIZE, function(list)
        isLoading = false
        if not list then
            Toast.Show("加载排行榜失败", { 255, 100, 100 })
            return
        end

        for _, entry in ipairs(list) do
            rankList[#rankList + 1] = entry
        end
        loadedCount = loadedCount + #list

        LeaderboardUI.RebuildList(#list >= PAGE_SIZE and loadedCount < MAX_LOAD)
    end)
end

-- ============================================================================
-- UI 刷新
-- ============================================================================

function LeaderboardUI.UpdateMyRankCard()
    if not UI then return end
    local GameUI = require("Game.GameUI")
    local root = GameUI.GetUIRoot()
    if not root then return end

    local label = root:FindById("lb_myRankLabel")
    if not label then return end

    local text
    if myRank and myRank > 0 then
        text = "我的排名: 第" .. myRank .. "名 · " .. LB.FormatStage(myScore)
    else
        if myScore > 0 then
            text = "我的成绩: " .. LB.FormatStage(myScore) .. " · 未上榜"
        else
            text = "暂无排名数据"
        end
    end
    label:SetText(text)
end

function LeaderboardUI.RebuildList(hasMore)
    if not UI then return end
    local GameUI = require("Game.GameUI")
    local root = GameUI.GetUIRoot()
    if not root then return end

    local container = root:FindById("lb_listContainer")
    if not container then return end

    container:ClearChildren()

    -- 排名行
    for i, entry in ipairs(rankList) do
        container:AddChild(LeaderboardUI.BuildRankRow(entry, i))
    end

    -- "加载更多" 按钮
    if hasMore then
        container:AddChild(UI.Panel {
            width = "100%", height = 44,
            justifyContent = "center",
            alignItems = "center",
            backgroundColor = { 35, 28, 55, 180 },
            pointerEvents = "auto",
            onClick = function()
                LeaderboardUI.LoadMore()
            end,
            children = {
                UI.Label {
                    text = "点击加载更多",
                    fontSize = 13,
                    fontColor = C.loadMore,
                    pointerEvents = "none",
                },
            },
        })
    elseif #rankList > 0 then
        container:AddChild(UI.Panel {
            width = "100%", height = 30,
            justifyContent = "center",
            alignItems = "center",
            children = {
                UI.Label {
                    text = "— 已显示全部 —",
                    fontSize = 11,
                    fontColor = C.dim,
                    pointerEvents = "none",
                },
            },
        })
    else
        container:AddChild(UI.Panel {
            width = "100%", height = 60,
            justifyContent = "center",
            alignItems = "center",
            children = {
                UI.Label {
                    text = "暂无排名数据",
                    fontSize = 14,
                    fontColor = C.dim,
                    pointerEvents = "none",
                },
            },
        })
    end
end

-- ============================================================================
-- 排名行组件
-- ============================================================================

function LeaderboardUI.BuildRankRow(entry, index)
    local rank = entry.rank
    local isMe = entry.isMe

    -- 排名颜色
    local rankColor = C.white
    local rankText = tostring(rank)
    if rank == 1 then
        rankColor = C.gold
        rankText = "🥇"
    elseif rank == 2 then
        rankColor = C.silver
        rankText = "🥈"
    elseif rank == 3 then
        rankColor = C.bronze
        rankText = "🥉"
    end

    -- 行背景
    local rowBg = isMe and C.rowMe or (index % 2 == 0 and C.rowAlt or C.rowBg)

    -- 昵称（截断）
    local nickname = entry.nickname or "玩家"
    if #nickname > 24 then
        nickname = string.sub(nickname, 1, 24) .. "…"
    end

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 10, paddingRight = 10,
        paddingTop = 8, paddingBottom = 8,
        backgroundColor = rowBg,
        borderBottomWidth = 1,
        borderColor = { 50, 40, 70, 60 },
        gap = 8,
        children = {
            -- 排名
            UI.Panel {
                width = 36,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = rankText,
                        fontSize = rank <= 3 and 18 or 14,
                        fontWeight = rank <= 3 and "bold" or "normal",
                        fontColor = rankColor,
                        pointerEvents = "none",
                    },
                },
            },
            -- 昵称
            UI.Panel {
                flex = 1,
                children = {
                    UI.Label {
                        text = nickname .. (isMe and " (我)" or ""),
                        fontSize = 13,
                        fontColor = isMe and C.gold or C.white,
                        fontWeight = isMe and "bold" or "normal",
                        pointerEvents = "none",
                    },
                },
            },
            -- 分数
            UI.Panel {
                alignItems = "flex-end",
                children = {
                    UI.Label {
                        text = LB.FormatStage(entry.score),
                        fontSize = 13,
                        fontWeight = "bold",
                        fontColor = C.green,
                        pointerEvents = "none",
                    },
                },
            },
        },
    }
end

return LeaderboardUI
