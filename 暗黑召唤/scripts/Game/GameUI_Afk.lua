-- Game/GameUI_Afk.lua
-- 挂机系统：挂机按钮、挂机收益、离线奖励面板

return function(GameUI, ctx)

local Config         = require("Game.Config")
local Currency       = require("Game.Currency")
local HeroData       = require("Game.HeroData")
local ChestData      = require("Game.ChestData")
local Toast          = require("Game.Toast")
local LaunchGiftData = require("Game.LaunchGiftData")
local DailyTaskData  = require("Game.DailyTaskData")

local FormatNum = ctx.FormatNum

-- ============================================================================
-- 左侧挂机奖励入口（实时计时 + 点击领取）
-- ============================================================================

-- 挂机计时起点（使用引擎单调时钟，防止玩家改系统时间）
GameUI._afkStartTime = time.elapsedTime
-- 上次更新显示的秒数（避免每帧刷新文本）
GameUI._afkLastDisplaySec = -1

--- 格式化挂机时长
---@param secs number
---@return string
local function FormatAfkTime(secs)
    secs = math.floor(secs)
    if secs >= 3600 then
        local h = math.floor(secs / 3600)
        local m = math.floor((secs % 3600) / 60)
        return string.format("%dh%02dm", h, m)
    elseif secs >= 60 then
        local m = math.floor(secs / 60)
        local s = secs % 60
        return string.format("%dm%02ds", m, s)
    else
        return string.format("%ds", secs)
    end
end

--- 计算当前挂机收益（基于实时累计时间）
---@return table rewards { seconds, nether_crystal, devour_stone, forge_iron, chestDrops }
local function CalcAfkRewardsNow()
    local elapsed = time.elapsedTime - GameUI._afkStartTime
    local capped = math.min(elapsed, Config.IDLE_MAX_SECONDS)
    local hours = capped / 3600

    local stage = HeroData.stats and HeroData.stats.bestStage or 0
    local crystalPerH = Config.IDLE_CRYSTAL_BASE + stage * Config.IDLE_CRYSTAL_PER_STAGE
    local stonePerH = Config.IDLE_STONE_PER_HOUR + math.floor(stage / 5)
    local ironPerH = Config.IDLE_IRON_PER_HOUR + math.floor(stage / 8)

    -- 宝箱掉落
    local chestDrops = {}
    if Config.IDLE_CHEST_DROPS then
        for _, rule in ipairs(Config.IDLE_CHEST_DROPS) do
            if hours >= rule.minHours then
                for id, count in pairs(rule.chests) do
                    chestDrops[id] = (chestDrops[id] or 0) + count
                end
            end
        end
    end
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
    }
end

--- 创建左侧功能按钮组（招募 + 挂机）
function GameUI.CreateAfkButton()
    local btnSize = 56
    local sk = { 0, 0, 0, 255 }  -- 描边色

    --- 创建带黑边描边的文字（4方向偏移黑色 + 白色正文）
    local function outlineLabel(txt, fontSize, fc, panelId)
        local offsets = { {-1,0}, {1,0}, {0,-1}, {0,1} }
        local children = {}
        for _, o in ipairs(offsets) do
            children[#children + 1] = ctx.UI.Label {
                text = txt, fontSize = fontSize, fontColor = sk, fontWeight = "bold",
                position = "absolute", left = o[1], top = o[2],
                width = "100%", textAlign = "center",
            }
        end
        children[#children + 1] = ctx.UI.Label {
            text = txt, fontSize = fontSize, fontColor = fc, fontWeight = "bold",
            width = "100%", textAlign = "center",
        }
        return ctx.UI.Panel {
            id = panelId,
            position = "relative", width = "100%", alignItems = "center",
            children = children,
        }
    end

    return ctx.UI.Panel {
        id = "leftSideButtons",
        position = "absolute",
        left = 6, top = "30%",
        width = btnSize,
        flexDirection = "column",
        alignItems = "center",
        gap = 8,
        pointerEvents = "box-none",
        children = {
            -- 排行榜入口按钮
            ctx.UI.Panel {
                id = "leaderboardBtn",
                width = btnSize, height = btnSize,
                borderRadius = 10,
                borderWidth = 1,
                borderColor = { 220, 200, 60, 180 },
                overflow = "hidden",
                pointerEvents = "auto",
                onClick = function(self)
                    local LeaderboardUI = require("Game.LeaderboardUI")
                    LeaderboardUI.Show()
                end,
                children = {
                    ctx.UI.Panel {
                        width = btnSize, height = btnSize,
                        backgroundColor = { 40, 35, 20, 220 },
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            ctx.UI.Panel {
                                width = 32, height = 32,
                                backgroundImage = "image/icon_leaderboard_20260410202832.png",
                                backgroundFit = "contain",
                            },
                        },
                    },
                    ctx.UI.Panel {
                        position = "absolute",
                        bottom = 2, left = 0, right = 0,
                        alignItems = "center",
                        children = { outlineLabel("排行", 11, { 255, 220, 80 }) },
                    },
                },
            },
            -- 每日任务入口按钮
            ctx.UI.Panel {
                id = "dailyTaskBtn",
                width = btnSize, height = btnSize,
                borderRadius = 10,
                borderWidth = 1,
                borderColor = { 180, 120, 255, 180 },
                overflow = "hidden",
                pointerEvents = "auto",
                onClick = function(self)
                    GameUI.ShowDailyTaskOverlay(true)
                end,
                children = {
                    ctx.UI.Panel {
                        width = btnSize, height = btnSize,
                        backgroundColor = { 40, 25, 60, 220 },
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            ctx.UI.Panel {
                                width = 32, height = 32,
                                backgroundImage = "image/icon_dailytask_20260410092630.png",
                                backgroundFit = "contain",
                            },
                        },
                    },
                    ctx.UI.Panel {
                        position = "absolute",
                        bottom = 2, left = 0, right = 0,
                        alignItems = "center",
                        children = { outlineLabel("任务", 11, { 200, 160, 255 }) },
                    },
                    -- 红点
                    ctx.UI.Panel {
                        id = "dailyTaskRedDot",
                        position = "absolute",
                        top = 2, right = 2,
                        width = 10, height = 10,
                        borderRadius = 5,
                        backgroundColor = { 255, 60, 60, 255 },
                        visible = DailyTaskData.HasClaimable(),
                    },
                },
            },
            -- 开服好礼入口按钮
            ctx.UI.Panel {
                id = "launchGiftBtn",
                width = btnSize, height = btnSize,
                borderRadius = 10,
                borderWidth = 1,
                borderColor = { 220, 180, 60, 180 },
                overflow = "hidden",
                pointerEvents = "auto",
                visible = LaunchGiftData.IsActive(),
                onClick = function(self)
                    GameUI.ShowLaunchGiftOverlay(true)
                end,
                children = {
                    ctx.UI.Panel {
                        width = btnSize, height = btnSize,
                        backgroundColor = { 60, 30, 20, 220 },
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            ctx.UI.Panel {
                                width = 32, height = 32,
                                backgroundImage = "image/开服好礼图标_20260410084937.png",
                                backgroundFit = "contain",
                            },
                        },
                    },
                    ctx.UI.Panel {
                        position = "absolute",
                        bottom = 2, left = 0, right = 0,
                        alignItems = "center",
                        children = { outlineLabel("好礼", 11, { 255, 220, 100 }) },
                    },
                    -- 红点
                    ctx.UI.Panel {
                        id = "launchGiftRedDot",
                        position = "absolute",
                        top = 2, right = 2,
                        width = 10, height = 10,
                        borderRadius = 5,
                        backgroundColor = { 255, 60, 60, 255 },
                        visible = LaunchGiftData.HasClaimable(),
                    },
                },
            },
            -- 招募入口按钮
            ctx.UI.Panel {
                width = btnSize, height = btnSize,
                borderRadius = 10,
                borderWidth = 1,
                borderColor = { 200, 80, 80, 180 },
                overflow = "hidden",
                pointerEvents = "auto",
                onClick = function(self)
                    GameUI.ShowRecruitOverlay(true)
                end,
                children = {
                    ctx.UI.Panel {
                        width = btnSize, height = btnSize,
                        backgroundImage = "image/icon_recruit_20260408182722.png",
                        backgroundSize = "cover",
                    },
                    ctx.UI.Panel {
                        position = "absolute",
                        bottom = 2, left = 0, right = 0,
                        alignItems = "center",
                        children = { outlineLabel("招募", 11, { 255, 255, 255 }) },
                    },
                },
            },
            -- 挂机奖励按钮
            ctx.UI.Panel {
                id = "afkButton",
                width = btnSize, height = btnSize,
                borderRadius = 10,
                borderWidth = 1,
                borderColor = { 120, 80, 200, 180 },
                overflow = "hidden",
                pointerEvents = "auto",
                onClick = function(self)
                    GameUI.ClaimAfkReward()
                end,
                children = {
                    ctx.UI.Panel {
                        width = btnSize, height = btnSize,
                        backgroundImage = "image/icon_idle_20260408182706.png",
                        backgroundSize = "cover",
                    },
                    ctx.UI.Panel {
                        position = "absolute",
                        bottom = 2, left = 0, right = 0,
                        alignItems = "center",
                        children = {
                            outlineLabel("0s", 11, { 140, 220, 140 }, "afkTimeLabel"),
                        },
                    },
                },
            },
            -- 活动入口按钮
            ctx.UI.Panel {
                width = btnSize, height = btnSize,
                borderRadius = 10,
                borderWidth = 1,
                borderColor = { 220, 160, 40, 180 },
                overflow = "hidden",
                pointerEvents = "auto",
                onClick = function(self)
                    GameUI.ShowActivityOverlay(true)
                end,
                children = {
                    ctx.UI.Panel {
                        width = btnSize, height = btnSize,
                        backgroundImage = "image/icon_activity_20260408182703.png",
                        backgroundSize = "cover",
                    },
                    ctx.UI.Panel {
                        position = "absolute",
                        bottom = 2, left = 0, right = 0,
                        alignItems = "center",
                        children = { outlineLabel("活动", 11, { 255, 255, 255 }) },
                    },
                },
            },
        },
    }
end

--- 更新挂机计时显示（由 GameUI.Update 调用）
function GameUI.UpdateAfkTimer()
    if not ctx.uiRoot then return end
    local elapsed = time.elapsedTime - GameUI._afkStartTime
    local capped = math.floor(math.min(elapsed, Config.IDLE_MAX_SECONDS))
    -- 仅秒数变化时才更新
    if capped == GameUI._afkLastDisplaySec then return end
    GameUI._afkLastDisplaySec = capped

    local panel = ctx.uiRoot:FindById("afkTimeLabel")
    if panel then
        local txt = FormatAfkTime(capped)
        local kids = panel:GetChildren()
        if kids then
            for i = 1, #kids do
                kids[i]:SetText(txt)
            end
            -- 可领取时前景 Label（最后一个）变金色，描边保持黑色
            if capped >= Config.IDLE_MIN_SECONDS then
                kids[#kids]:SetFontColor({ 255, 220, 80, 255 })
            end
        end
    end
end

--- 计算满时长挂机收益（广告立即领取用）
---@return table rewards
local function CalcAfkRewardsMax()
    local maxSecs = Config.IDLE_MAX_SECONDS
    local hours = maxSecs / 3600

    local stage = HeroData.stats and HeroData.stats.bestStage or 0
    local crystalPerH = Config.IDLE_CRYSTAL_BASE + stage * Config.IDLE_CRYSTAL_PER_STAGE
    local stonePerH = Config.IDLE_STONE_PER_HOUR + math.floor(stage / 5)
    local ironPerH = Config.IDLE_IRON_PER_HOUR + math.floor(stage / 8)

    local chestDrops = {}
    if Config.IDLE_CHEST_DROPS then
        for _, rule in ipairs(Config.IDLE_CHEST_DROPS) do
            if hours >= rule.minHours then
                for id, count in pairs(rule.chests) do
                    chestDrops[id] = (chestDrops[id] or 0) + count
                end
            end
        end
    end
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
        seconds = maxSecs,
        nether_crystal = math.floor(crystalPerH * hours),
        devour_stone = math.floor(stonePerH * hours),
        forge_iron = math.floor(ironPerH * hours),
        chestDrops = chestDrops,
    }
end

--- 实际发放挂机奖励（货币+宝箱）
---@param rewards table
local function GrantAfkRewards(rewards)
    Currency.Add("nether_crystal", rewards.nether_crystal)
    Currency.Add("devour_stone", rewards.devour_stone)
    Currency.Add("forge_iron", rewards.forge_iron)

    if rewards.chestDrops then
        for id, count in pairs(rewards.chestDrops) do
            if count > 0 then
                ChestData.Add(id, count)
            end
        end
        ChestData.Save()
    end

    HeroData.lastSaveTime = os.time()
    HeroData.Save()

    print("[GameUI] AFK rewards granted: crystal+" .. rewards.nether_crystal
        .. " stone+" .. rewards.devour_stone
        .. " iron+" .. rewards.forge_iron
        .. " (" .. math.floor(rewards.seconds / 60) .. " min)")
end

--- 点击挂机按钮：打开预览弹窗（不自动发放）
function GameUI.ClaimAfkReward()
    local rewards = CalcAfkRewardsNow()
    -- 显示预览弹窗（不发放奖励）
    GameUI.ShowIdleRewards(rewards)
end

-- ============================================================================
-- 挂机离线收益弹窗
-- ============================================================================

--- 创建挂机收益面板（全屏遮罩 + 居中卡片）
function GameUI.CreateIdleRewardPanel()
    local function closePanel()
        GameUI.ShowPanel("idleRewardPanel", false)
    end

    return ctx.UI.Panel {
        id = "idleRewardPanel",
        visible = false,
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 180 },
        pointerEvents = "auto",
        onClick = function(self)
            -- 点击外部遮罩关闭
            closePanel()
        end,
        children = {
            ctx.UI.Panel {
                width = 280,
                paddingTop = 24, paddingBottom = 24,
                paddingLeft = 20, paddingRight = 20,
                gap = 8,
                backgroundColor = { 20, 25, 50, 245 },
                borderRadius = 16,
                borderWidth = 2,
                borderColor = { 140, 80, 200, 200 },
                alignItems = "center",
                pointerEvents = "auto",
                children = {
                    -- 右上角 X 关闭按钮
                    ctx.UI.Panel {
                        position = "absolute",
                        top = 4, right = 4,
                        width = 32, height = 32,
                        justifyContent = "center",
                        alignItems = "center",
                        pointerEvents = "auto",
                        onClick = function(self)
                            closePanel()
                        end,
                        children = {
                            ctx.UI.Label {
                                text = "✕",
                                fontSize = 18,
                                fontColor = { 180, 160, 200, 200 },
                            },
                        },
                    },
                    ctx.UI.Label {
                        id = "idleTitleLabel",
                        text = "挂机收益",
                        fontSize = 24,
                        fontColor = { 200, 170, 255, 255 },
                    },
                    ctx.UI.Label {
                        id = "idleTimeLabel",
                        text = "",
                        fontSize = 13,
                        fontColor = { 160, 150, 180, 200 },
                    },
                    -- 分隔线
                    ctx.UI.Panel {
                        width = "90%", height = 1,
                        marginTop = 4, marginBottom = 4,
                        backgroundColor = { 100, 70, 160, 100 },
                    },
                    -- 奖励行：冥晶
                    ctx.UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 8,
                        children = {
                            Currency.IconWidget(ctx.UI, "nether_crystal", 20),
                            ctx.UI.Label {
                                id = "idleCrystalLabel",
                                text = "冥晶: +0",
                                fontSize = 15,
                                fontColor = { 140, 80, 200, 255 },
                            },
                        },
                    },
                    -- 奖励行：噬魂石
                    ctx.UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 8,
                        children = {
                            Currency.IconWidget(ctx.UI, "devour_stone", 20),
                            ctx.UI.Label {
                                id = "idleStoneLabel",
                                text = "噬魂石: +0",
                                fontSize = 15,
                                fontColor = { 60, 160, 80, 255 },
                            },
                        },
                    },
                    -- 奖励行：锻魂铁
                    ctx.UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 8,
                        children = {
                            Currency.IconWidget(ctx.UI, "forge_iron", 20),
                            ctx.UI.Label {
                                id = "idleIronLabel",
                                text = "锻魂铁: +0",
                                fontSize = 15,
                                fontColor = { 130, 160, 200, 255 },
                            },
                        },
                    },
                    -- 宝箱掉落区域（动态填充）
                    ctx.UI.Panel {
                        id = "idleChestDropArea",
                        width = "100%",
                        alignItems = "center",
                        gap = 4,
                    },
                    -- 分隔线
                    ctx.UI.Panel {
                        width = "90%", height = 1,
                        marginTop = 4, marginBottom = 4,
                        backgroundColor = { 100, 70, 160, 100 },
                    },
                    -- 按钮行：领取 + 立即领取
                    ctx.UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "center",
                        alignItems = "center",
                        gap = 10,
                        children = {
                            -- 领取按钮
                            ctx.UI.Panel {
                                id = "idleClaimBtn",
                                paddingLeft = 24, paddingRight = 24,
                                paddingTop = 10, paddingBottom = 10,
                                backgroundColor = { 120, 80, 200, 255 },
                                borderRadius = 8,
                                borderWidth = 1,
                                borderColor = { 180, 140, 255, 180 },
                                alignItems = "center",
                                justifyContent = "center",
                                onClick = function(self)
                                    local pendingRewards = GameUI._pendingIdleRewards
                                    if pendingRewards then
                                        if pendingRewards.isOffline then
                                            HeroData.ClaimIdleRewards(pendingRewards)
                                        else
                                            GrantAfkRewards(pendingRewards)
                                            -- 重置挂机计时
                                            GameUI._afkStartTime = time.elapsedTime
                                            GameUI._afkLastDisplaySec = -1
                                        end
                                        GameUI._pendingIdleRewards = nil
                                        Toast.Show("收益已领取", { 100, 220, 100 })
                                    end
                                    GameUI.ShowPanel("idleRewardPanel", false)
                                    GameUI.UpdateHUD()
                                end,
                                children = {
                                    ctx.UI.Label {
                                        text = "领取",
                                        fontSize = 16,
                                        fontColor = { 255, 255, 255 },
                                        fontWeight = "bold",
                                    },
                                },
                            },
                            -- 立即领取按钮（看广告领满时长收益）
                            ctx.UI.Panel {
                                id = "idleAdClaimBtn",
                                paddingLeft = 16, paddingRight = 16,
                                paddingTop = 10, paddingBottom = 10,
                                backgroundColor = { 200, 160, 50 },
                                borderRadius = 8,
                                borderWidth = 1,
                                borderColor = { 255, 220, 100, 180 },
                                flexDirection = "row",
                                alignItems = "center",
                                justifyContent = "center",
                                gap = 4,
                                onClick = function(self)
                                    local function onAdSuccess()
                                        local AdTracker = require("Game.AdTracker")
                                        AdTracker.Record()
                                        -- 发放满时长收益
                                        local maxRewards = CalcAfkRewardsMax()
                                        GrantAfkRewards(maxRewards)
                                        -- 重置挂机计时
                                        GameUI._afkStartTime = time.elapsedTime
                                        GameUI._afkLastDisplaySec = -1
                                        GameUI._pendingIdleRewards = nil
                                        Toast.Show("满时长收益已领取", { 255, 220, 80 })
                                        GameUI.ShowPanel("idleRewardPanel", false)
                                        GameUI.UpdateHUD()
                                    end
                                    ---@diagnostic disable-next-line: undefined-global
                                    if sdk and sdk.ShowRewardVideoAd then
                                        ---@diagnostic disable-next-line: undefined-global
                                        sdk:ShowRewardVideoAd(function(success)
                                            if success then onAdSuccess() end
                                        end)
                                    else
                                        onAdSuccess()
                                    end
                                end,
                                children = {
                                    ctx.UI.Panel {
                                        width = 16, height = 16,
                                        backgroundImage = "image/icon_watch_ad_20260408182809.png",
                                        backgroundFit = "contain",
                                    },
                                    ctx.UI.Label {
                                        text = "立即领取",
                                        fontSize = 14,
                                        fontColor = { 30, 20, 10 },
                                        fontWeight = "bold",
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }
end

--- 显示挂机收益弹窗
---@param rewards table  HeroData.CalcIdleRewards() 的返回值
function GameUI.ShowIdleRewards(rewards)
    if not rewards or not ctx.uiRoot then return end

    -- 暂存待领取奖励
    GameUI._pendingIdleRewards = rewards

    -- 格式化时长
    local secs = rewards.seconds
    local prefix = rewards.isOffline and "离线" or "挂机"
    local timeStr
    if secs >= 3600 then
        local h = math.floor(secs / 3600)
        local m = math.floor((secs % 3600) / 60)
        timeStr = string.format("%s %d小时%d分钟", prefix, h, m)
    else
        timeStr = string.format("%s %d分钟", prefix, math.floor(secs / 60))
    end

    -- 更新文本
    local titleLabel = ctx.uiRoot:FindById("idleTitleLabel")
    if titleLabel then titleLabel:SetText(rewards.isOffline and "离线收益" or "挂机收益") end

    local timeLabel = ctx.uiRoot:FindById("idleTimeLabel")
    if timeLabel then timeLabel:SetText(timeStr) end

    local crystalLabel = ctx.uiRoot:FindById("idleCrystalLabel")
    if crystalLabel then crystalLabel:SetText("冥晶: +" .. rewards.nether_crystal) end

    local stoneLabel = ctx.uiRoot:FindById("idleStoneLabel")
    if stoneLabel then stoneLabel:SetText("噬魂石: +" .. rewards.devour_stone) end

    local ironLabel = ctx.uiRoot:FindById("idleIronLabel")
    if ironLabel then ironLabel:SetText("锻魂铁: +" .. rewards.forge_iron) end

    -- 填充宝箱掉落
    local chestArea = ctx.uiRoot:FindById("idleChestDropArea")
    if chestArea then
        chestArea:ClearChildren()
        if rewards.chestDrops then
            local hasChest = false
            for id, count in pairs(rewards.chestDrops) do
                if count > 0 then
                    hasChest = true
                    local cdef = ChestData.GetChestDef(id)
                    local chestName = cdef and cdef.name or id
                    local chestColor = cdef and cdef.color or { 200, 200, 200, 255 }
                    chestArea:AddChild(ctx.UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 8,
                        children = {
                            (cdef and cdef.image) and ctx.UI.Panel {
                                width = 20, height = 20,
                                backgroundImage = cdef.image,
                                backgroundFit = "contain",
                            } or ctx.UI.Label {
                                text = (cdef and cdef.emoji) or "📦",
                                fontSize = 16,
                            },
                            ctx.UI.Label {
                                text = chestName .. ": +" .. count,
                                fontSize = 15,
                                fontColor = chestColor,
                            },
                        },
                    })
                end
            end
            if hasChest then
                -- 加一条分隔线在宝箱区域前
                chestArea:AddChild(ctx.UI.Panel {
                    width = "90%", height = 1,
                    marginTop = 2, marginBottom = 2,
                    backgroundColor = { 100, 70, 160, 80 },
                })
            end
        end
    end

    -- 立即领取按钮：离线收益时隐藏（离线收益无需广告立即领取）
    local adClaimBtn = ctx.uiRoot:FindById("idleAdClaimBtn")
    if adClaimBtn then
        adClaimBtn:SetVisible(not rewards.isOffline)
    end

    GameUI.ShowPanel("idleRewardPanel", true)
end

--- 每帧更新 UI 状态

end
