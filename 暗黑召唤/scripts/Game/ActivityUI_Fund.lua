-- Game/ActivityUI_Fund.lua
-- 基金商城页 + 占位页内容构建

return function(ctx, Shared)

local Config    = require("Game.Config")
local FundData  = require("Game.FundData")
local Currency  = require("Game.Currency")
local Toast     = require("Game.Toast")
local AdTracker = require("Game.AdTracker")

local S              = Shared.S
local FormatNum      = Shared.FormatNum
local REWARD_COLORS  = Shared.REWARD_COLORS

local Mod = {}

-- ============================================================================
-- 基金商城内容页
-- ============================================================================

local function BuildFundContent()
    FundData.Load()

    local fund
    for _, f in ipairs(FundData.FUNDS) do
        if f.id == ctx.currentFundTab then fund = f; break end
    end
    if not fund then fund = FundData.FUNDS[1] end

    -- ---- 子标签栏：噬魂石基金 | 锻魂铁基金 ----
    local subTabs = {}
    for _, f in ipairs(FundData.FUNDS) do
        local isActive = f.id == ctx.currentFundTab
        subTabs[#subTabs + 1] = ctx.UI.Panel {
            flex = 1,
            paddingTop = 8, paddingBottom = 8,
            alignItems = "center",
            backgroundColor = isActive and { 50, 35, 70, 240 } or { 25, 20, 40, 180 },
            borderBottomWidth = isActive and 2 or 0,
            borderColor = S.goldAccent,
            onClick = function()
                ctx.currentFundTab = f.id
                ctx.RefreshContent()
            end,
            children = {
                ctx.UI.Label {
                    text = f.name,
                    fontSize = 13,
                    fontColor = isActive and S.goldAccent or S.textSecondary,
                    fontWeight = isActive and "bold" or "normal",
                },
            },
        }
    end

    local subTabBar = ctx.UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexShrink = 0,
        children = subTabs,
    }

    -- ---- 基金卡片头 ----
    local totalReward = FundData.GetTotalReward(fund)
    local claimedCount = FundData.GetClaimedCount(fund.id)
    local currDef = Config.CURRENCY[fund.currency]
    local currName = currDef and currDef.name or fund.currency

    local headerCard = ctx.UI.Panel {
        width = "100%",
        paddingTop = 14, paddingBottom = 14,
        paddingLeft = 14, paddingRight = 14,
        backgroundColor = { 35, 28, 55, 240 },
        borderBottomWidth = 1,
        borderColor = { 60, 50, 80, 100 },
        flexShrink = 0,
        gap = 6,
        children = {
            ctx.UI.Label {
                text = fund.name,
                fontSize = 16,
                fontColor = S.textPrimary,
                fontWeight = "bold",
            },
            ctx.UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = {
                    ctx.UI.Label { text = "累计可获得", fontSize = 11, fontColor = S.textSecondary },
                    Currency.IconWidget(ctx.UI, fund.currency, 16),
                    ctx.UI.Label {
                        text = FormatNum(totalReward),
                        fontSize = 16,
                        fontColor = S.goldAccent,
                        fontWeight = "bold",
                    },
                },
            },
            ctx.UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = {
                    ctx.UI.Label { text = "ℹ", fontSize = 10, fontColor = S.textMuted },
                    ctx.UI.Label {
                        text = "观看广告解锁基金任务权限",
                        fontSize = 10,
                        fontColor = S.textMuted,
                    },
                },
            },
        },
    }

    -- ---- 里程碑列表（按组） ----
    local maxStage = FundData.GetMaxStage()
    local listItems = {}

    for g = 1, FundData.TOTAL_GROUPS do
        local startIdx = (g - 1) * FundData.GROUP_SIZE + 1
        local endIdx = math.min(g * FundData.GROUP_SIZE, FundData.TOTAL_MILESTONES)

        local groupUnlocked = FundData.IsGroupUnlocked(ctx.currentFundTab, g)
        local canWatch = FundData.CanWatchAd(ctx.currentFundTab, g)
        local adsWatched = FundData.GetGroupAds(ctx.currentFundTab, g)

        -- 组头
        local groupRight
        if groupUnlocked then
            groupRight = ctx.UI.Label { text = "已解锁 ✓", fontSize = 10, fontColor = S.checkColor }
        elseif canWatch then
            groupRight = ctx.UI.Panel {
                flexDirection = "row", alignItems = "center", gap = 6,
                children = {
                    ctx.UI.Label { text = adsWatched .. "/" .. FundData.ADS_PER_GROUP, fontSize = 10, fontColor = S.goldAccent },
                    ctx.UI.Panel {
                        paddingLeft = 8, paddingRight = 8,
                        paddingTop = 3, paddingBottom = 3,
                        backgroundColor = { 100, 70, 180, 255 },
                        borderRadius = 8,
                        flexDirection = "row",
                        alignItems = "center",
                        onClick = function()
                            ---@diagnostic disable-next-line: undefined-global
                            if sdk then
                                ---@diagnostic disable-next-line: undefined-global
                                sdk:ShowRewardVideoAd(function(success)
                                    if success then
                                        AdTracker.Record()
                                        FundData.RecordAdWatch(ctx.currentFundTab, g)
                                        ctx.RefreshContent()
                                    end
                                end)
                            else
                                AdTracker.Record()
                                FundData.RecordAdWatch(ctx.currentFundTab, g)
                                ctx.RefreshContent()
                            end
                        end,
                        children = {
                            ctx.UI.Panel { width = 14, height = 14, backgroundImage = "image/icon_watch_ad_20260408182809.png", backgroundFit = "contain", marginRight = 3 },
                            ctx.UI.Label { text = "观看", fontSize = 10, fontColor = { 255, 255, 255 }, fontWeight = "bold" },
                        },
                    },
                },
            }
        else
            groupRight = ctx.UI.Panel {
                flexDirection = "row", alignItems = "center", gap = 4,
                children = {
                    ctx.UI.Panel { width = 14, height = 14, backgroundImage = "image/icon_lock_20260408182729.png", backgroundFit = "contain" },
                    ctx.UI.Label { text = "需先解锁上一组", fontSize = 10, fontColor = S.textMuted },
                },
            }
        end

        listItems[#listItems + 1] = ctx.UI.Panel {
            width = "100%",
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "center",
            paddingLeft = 12, paddingRight = 12,
            paddingTop = 8, paddingBottom = 6,
            backgroundColor = { 30, 25, 48, 200 },
            borderTopWidth = 1,
            borderColor = { 70, 55, 100, 80 },
            children = {
                ctx.UI.Label {
                    text = "— 第" .. g .. "组 —",
                    fontSize = 11,
                    fontColor = groupUnlocked and S.checkColor or S.textMuted,
                    fontWeight = "bold",
                },
                groupRight,
            },
        }

        -- 组内里程碑行
        for idx = startIdx, endIdx do
            local stage = FundData.STAGES[idx]
            local claimed = FundData.IsClaimed(ctx.currentFundTab, idx)
            local canClaim = FundData.CanClaim(ctx.currentFundTab, idx)
            local reached = maxStage >= stage
            local progress = math.min(maxStage / stage, 1.0)

            -- 按钮
            local btnChild
            if claimed then
                btnChild = ctx.UI.Panel {
                    paddingLeft = 10, paddingRight = 10,
                    paddingTop = 4, paddingBottom = 4,
                    backgroundColor = { 50, 45, 55, 200 },
                    borderRadius = 8,
                    children = {
                        ctx.UI.Label { text = "已领取", fontSize = 10, fontColor = S.textMuted },
                    },
                }
            elseif canClaim then
                btnChild = ctx.UI.Panel {
                    paddingLeft = 10, paddingRight = 10,
                    paddingTop = 4, paddingBottom = 4,
                    backgroundColor = { 40, 120, 60, 255 },
                    borderRadius = 8,
                    borderWidth = 1,
                    borderColor = { 80, 200, 100, 200 },
                    onClick = function()
                        local ok, msg = FundData.Claim(ctx.currentFundTab, idx)
                        if ok then
                            Toast.Show("领取成功: " .. msg, { 120, 200, 80 })
                            local success, AudioManager = pcall(require, "Game.AudioManager")
                            if success and AudioManager then AudioManager.PlayChestOpen() end
                        else
                            Toast.Show(msg, { 255, 100, 80 })
                        end
                        ctx.RefreshContent()
                    end,
                    children = {
                        ctx.UI.Label { text = "领取", fontSize = 10, fontColor = { 255, 255, 255 }, fontWeight = "bold" },
                    },
                }
            else
                btnChild = ctx.UI.Panel {
                    paddingLeft = 10, paddingRight = 10,
                    paddingTop = 4, paddingBottom = 4,
                    backgroundColor = { 45, 40, 55, 200 },
                    borderRadius = 8,
                    children = {
                        ctx.UI.Panel { width = 18, height = 18, backgroundImage = "image/icon_lock_20260408182729.png", backgroundFit = "contain" },
                    },
                }
            end

            -- 进度百分比
            local progressPct = math.floor(progress * 100)

            listItems[#listItems + 1] = ctx.UI.Panel {
                width = "100%",
                paddingLeft = 12, paddingRight = 12,
                paddingTop = 8, paddingBottom = 8,
                backgroundColor = (idx % 2 == 0) and { 22, 18, 36, 200 } or { 26, 22, 42, 200 },
                borderBottomWidth = 1,
                borderColor = { 40, 35, 60, 50 },
                gap = 4,
                children = {
                    -- 上：关卡标签 + 提示 + 按钮
                    ctx.UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            ctx.UI.Panel {
                                flexDirection = "row", alignItems = "center", gap = 4,
                                children = {
                                    ctx.UI.Label {
                                        text = "通关第" .. stage .. "关",
                                        fontSize = 11,
                                        fontColor = reached and S.textPrimary or S.textMuted,
                                        fontWeight = reached and "bold" or "normal",
                                    },
                                    ctx.UI.Label {
                                        text = "ℹ 任务已完成即可领取奖励",
                                        fontSize = 8,
                                        fontColor = S.textMuted,
                                    },
                                },
                            },
                            btnChild,
                        },
                    },
                    -- 下：进度条 + 奖励
                    ctx.UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 6,
                        children = {
                            -- 进度条
                            ctx.UI.Panel {
                                flex = 1,
                                height = 16,
                                backgroundColor = { 15, 12, 25, 200 },
                                borderRadius = 8,
                                overflow = "hidden",
                                children = {
                                    ctx.UI.Panel {
                                        width = progressPct .. "%",
                                        height = "100%",
                                        backgroundColor = reached and { 80, 180, 80, 255 } or { 100, 70, 180, 255 },
                                        borderRadius = 8,
                                    },
                                    ctx.UI.Panel {
                                        position = "absolute",
                                        top = 0, left = 0, right = 0, bottom = 0,
                                        justifyContent = "center",
                                        alignItems = "center",
                                        children = {
                                            ctx.UI.Label {
                                                text = math.min(maxStage, stage) .. "/" .. stage,
                                                fontSize = 9,
                                                fontColor = { 255, 255, 255, 200 },
                                            },
                                        },
                                    },
                                },
                            },
                            -- 奖励
                            ctx.UI.Panel {
                                flexDirection = "row",
                                alignItems = "center",
                                gap = 2,
                                flexShrink = 0,
                                children = {
                                    Currency.IconWidget(ctx.UI, fund.currency, 16),
                                    ctx.UI.Label {
                                        text = "×" .. FundData.GetMilestoneReward(fund, idx),
                                        fontSize = 11,
                                        fontColor = claimed and S.textMuted or S.goldAccent,
                                        fontWeight = "bold",
                                    },
                                },
                            },
                        },
                    },
                },
            }
        end
    end

    local listPanel = ctx.UI.Panel {
        width = "100%",
        paddingBottom = 10,
        children = listItems,
    }

    return { subTabBar, headerCard, listPanel }
end

-- ============================================================================
-- 占位内容页（其他标签暂未实现）
-- ============================================================================

local function BuildPlaceholderContent(tabDef)
    return {
        ctx.UI.Panel {
            width = "100%",
            flex = 1,
            justifyContent = "center",
            alignItems = "center",
            gap = 12,
            children = {
                ctx.UI.Label {
                    text = tabDef.emoji,
                    fontSize = 48,
                },
                ctx.UI.Label {
                    text = tabDef.label,
                    fontSize = 20,
                    fontColor = S.textPrimary,
                    fontWeight = "bold",
                },
                ctx.UI.Label {
                    text = "即将开放，敬请期待",
                    fontSize = 13,
                    fontColor = S.textMuted,
                },
            },
        },
    }
end


Mod.BuildContent = BuildFundContent
Mod.BuildPlaceholderContent = BuildPlaceholderContent

return Mod
end
