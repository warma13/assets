-- Game/DungeonUI.lua
-- 副本页面 - 两级导航：副本列表 → 具体副本详情页
-- 参考咸鱼之王：滚动卡片列表，点击进入对应副本

local Config = require("Game.Config")
local HeroData = require("Game.HeroData")
local Currency = require("Game.Currency")
local TrialTowerData = require("Game.TrialTowerData")
local RD = require("Game.ResourceDungeonData")
local InventoryData = require("Game.InventoryData")
local Toast = require("Game.Toast")
local RewardDisplay = require("Game.RewardDisplay")

local LB = require("Game.LeaderboardData")

local DungeonUI = {}

---@type any
local UI = nil
---@type any
local pageRoot = nil

-- 当前视图状态
local currentView = "list"  -- "list" | "tower" | "resource_list" | "resource_detail"
local currentResourceKey = nil  -- 当前选中的资源副本 key

-- 排名缓存（异步加载后更新 UI）
local rankCache = {
    tower = nil,    -- number|nil 我的试练塔排名
    dungeon = nil,  -- number|nil 我的资源副本排名
}

-- ============================================================================
-- 配色
-- ============================================================================
local S = {
    pageBg       = { 15, 12, 25, 255 },
    headerBg     = { 28, 20, 45, 255 },
    cardBg       = { 30, 24, 48, 240 },
    cardBorder   = { 70, 55, 100, 120 },
    cardHover    = { 45, 36, 68, 255 },
    -- 各副本卡片主题色
    towerAccent  = { 140, 100, 220, 255 },
    dailyAccent  = { 220, 160, 40, 255 },
    arenaAccent  = { 60, 180, 220, 255 },
    dreamAccent  = { 200, 80, 160, 255 },
    -- 层格子
    clearedBg    = { 45, 70, 45, 220 },
    clearedBorder= { 80, 140, 80, 180 },
    currentBg    = { 70, 45, 120, 255 },
    currentBorder= { 140, 100, 220, 255 },
    lockedBg     = { 35, 30, 50, 180 },
    lockedBorder = { 55, 45, 70, 100 },
    -- 文字
    white        = { 245, 238, 225, 255 },
    dim          = { 150, 140, 160, 200 },
    gold         = { 255, 215, 80, 255 },
    green        = { 120, 220, 100, 255 },
    purple       = { 160, 120, 240, 255 },
    red          = { 220, 80, 80, 255 },
    -- 按钮
    btnPrimary   = { 100, 60, 200, 255 },
    btnDisabled  = { 50, 40, 70, 200 },
    -- 即将开放
    comingSoon   = { 80, 70, 95, 200 },
}

-- ============================================================================
-- 副本定义
-- ============================================================================
local DUNGEON_DEFS = {
    {
        key = "tower",
        name = "试练塔",
        desc = "逐层挑战，获取噬魂石与冥晶",
        accentColor = S.towerAccent,
        available = true,
        cover = "image/dungeon_trial_tower_20260407191307.png",
    },
    {
        key = "resource",
        name = "资源副本",
        desc = "挑战Boss，获取冥晶、噬魂石、锻魂铁和宝箱",
        accentColor = S.dailyAccent,
        available = true,
        cover = "image/dungeon_resource_cover_20260408201730.png",
    },
}

-- ============================================================================
-- 辅助
-- ============================================================================

local function FormatNum(n)
    if n >= 10000 then return string.format("%.1f万", n / 10000) end
    return tostring(math.floor(n))
end

-- ============================================================================
-- 页面创建 & 刷新
-- ============================================================================

function DungeonUI.CreatePage(uiModule)
    UI = uiModule

    pageRoot = UI.Panel {
        id = "dungeonPage",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        flexDirection = "column",
        backgroundColor = S.pageBg,
        children = {},
    }

    DungeonUI.Refresh()
    return pageRoot
end

function DungeonUI.Refresh()
    if not pageRoot or not UI then return end
    pageRoot:ClearChildren()

    if currentView == "list" then
        DungeonUI.BuildListView()
        -- 异步加载排名
        DungeonUI.FetchRanks()
    elseif currentView == "tower" then
        DungeonUI.BuildTowerDetailView()
    elseif currentView == "resource_list" then
        DungeonUI.BuildResourceListView()
    elseif currentView == "resource_detail" then
        DungeonUI.BuildResourceDetailView()
    end
end

--- 异步加载试练塔和资源副本排名
function DungeonUI.FetchRanks()
    if not clientCloud then return end

    LB.FetchMyRank(LB.KEY_TOWER, function(rank, score)
        rankCache.tower = rank
        -- 更新 UI
        if pageRoot and currentView == "list" then
            local label = pageRoot:FindById("towerRankLabel")
            if label then
                label:SetText(rank and ("排名 第" .. rank .. "名") or "未上榜")
            end
        end
    end)

    LB.FetchMyRank(LB.KEY_DUNGEON, function(rank, score)
        rankCache.dungeon = rank
        if pageRoot and currentView == "list" then
            local label = pageRoot:FindById("dungeonRankLabel")
            if label then
                label:SetText(rank and ("排名 第" .. rank .. "名") or "未上榜")
            end
        end
    end)
end

-- ============================================================================
-- 一级页面：副本列表（滚动卡片）
-- ============================================================================

function DungeonUI.BuildListView()
    -- 顶部标题
    pageRoot:AddChild(UI.Panel {
        width = "100%",
        height = 50,
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = S.headerBg,
        flexShrink = 0,
        children = {
            UI.Label {
                text = "副本",
                fontSize = 20,
                fontWeight = "bold",
                fontColor = S.white,
                pointerEvents = "none",
            },
        },
    })

    -- 四张卡片等分剩余高度
    local cards = {}
    for _, def in ipairs(DUNGEON_DEFS) do
        cards[#cards + 1] = DungeonUI.BuildDungeonCard(def)
    end

    pageRoot:AddChild(UI.ScrollView {
        width = "100%",
        flex = 1,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "column",
                paddingTop = 6, paddingBottom = 6,
                paddingLeft = 12, paddingRight = 12,
                gap = 10,
                children = cards,
            },
        },
    })
end

--- 构建单个副本卡片
function DungeonUI.BuildDungeonCard(def)
    local isAvailable = def.available

    -- 副本特有的进度信息
    local progressText = ""
    local progressColor = S.dim
    if def.key == "tower" and isAvailable then
        local data = TrialTowerData.GetData()
        local towerNum = TrialTowerData.GetTowerNum(data.currentFloor)
        local floorInTower = TrialTowerData.GetFloorInTower(data.currentFloor)
        progressText = "第" .. towerNum .. "塔 · " .. (floorInTower - 1) .. "/10"
        progressColor = S.gold
    elseif def.key == "resource" and isAvailable then
        -- 显示今日剩余次数（取所有副本中最少的剩余）
        local minRemain = RD.DAILY_ATTEMPTS
        for _, rd in ipairs(RD.DUNGEON_DEFS) do
            local r = RD.GetRemainingAttempts(rd.key)
            if r < minRemain then minRemain = r end
        end
        progressText = "今日 " .. minRemain .. "/" .. RD.DAILY_ATTEMPTS
        progressColor = minRemain > 0 and S.green or S.red
    elseif not isAvailable then
        progressText = "即将开放"
        progressColor = S.comingSoon
    end

    -- 左侧竖条颜色
    local accentColor = isAvailable and def.accentColor or S.comingSoon

    -- 奖励预览
    local rewardChildren = {}
    if def.key == "tower" and isAvailable then
        local data = TrialTowerData.GetData()
        local towerNum = TrialTowerData.GetTowerNum(data.currentFloor)
        local stones, gold = TrialTowerData.GetFloorReward(towerNum)
        rewardChildren = {
            Currency.IconWidget(UI, "devour_stone", 13),
            UI.Label { text = FormatNum(stones), fontSize = 11, fontColor = { 60, 160, 80 }, pointerEvents = "none" },
            UI.Label { text = " + ", fontSize = 10, fontColor = S.dim, pointerEvents = "none" },
            Currency.IconWidget(UI, "nether_crystal", 13),
            UI.Label { text = FormatNum(gold), fontSize = 11, fontColor = { 140, 80, 200 }, pointerEvents = "none" },
        }
    elseif def.key == "resource" and isAvailable then
        rewardChildren = {
            Currency.IconWidget(UI, "nether_crystal", 13),
            Currency.IconWidget(UI, "devour_stone", 13),
            Currency.IconWidget(UI, "forge_iron", 13),
            UI.Panel {
                width = 13, height = 13,
                backgroundImage = "image/tab_chest_20260408235703.png",
                backgroundFit = "contain",
                pointerEvents = "none",
                flexShrink = 0,
            },
        }
    end

    -- 背景图片
    local bgImage = def.cover

    return UI.Panel {
        width = "100%",
        aspectRatio = 16 / 9,
        flexDirection = "row",
        backgroundColor = isAvailable and S.cardBg or { 25, 20, 38, 180 },
        backgroundImage = bgImage,
        backgroundScaleMode = bgImage and "aspectFill" or nil,
        borderRadius = 10,
        borderWidth = 1,
        borderColor = isAvailable and S.cardBorder or { 50, 42, 65, 80 },
        overflow = "hidden",
        onClick = isAvailable and function()
            if def.key == "tower" then
                currentView = "tower"
                DungeonUI.Refresh()
            elseif def.key == "resource" then
                currentView = "resource_list"
                DungeonUI.Refresh()
            end
        end or nil,
        children = {
            -- 左侧色条
            UI.Panel {
                width = 5,
                height = "100%",
                backgroundColor = accentColor,
            },
            -- 右侧内容区（半透明遮罩保证文字可读）
            UI.Panel {
                flex = 1,
                flexDirection = "column",
                paddingLeft = 12, paddingRight = 14,
                paddingTop = 14, paddingBottom = 14,
                gap = 6,
                backgroundColor = bgImage and { 15, 12, 25, 160 } or nil,
                children = {
                    -- 第一行：名称 + 进度标签
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        justifyContent = "space-between",
                        children = {
                            UI.Label {
                                text = def.name,
                                fontSize = 17,
                                fontWeight = "bold",
                                fontColor = isAvailable and S.white or S.dim,
                                pointerEvents = "none",
                            },
                            -- 右：进度/状态
                            UI.Panel {
                                paddingLeft = 8, paddingRight = 8,
                                paddingTop = 3, paddingBottom = 3,
                                borderRadius = 10,
                                backgroundColor = { progressColor[1], progressColor[2], progressColor[3], 40 },
                                children = {
                                    UI.Label {
                                        text = progressText,
                                        fontSize = 11,
                                        fontColor = progressColor,
                                        pointerEvents = "none",
                                    },
                                },
                            },
                        },
                    },
                    -- 第二行：描述
                    UI.Label {
                        text = def.desc,
                        fontSize = 12,
                        fontColor = S.dim,
                        pointerEvents = "none",
                    },
                    -- 第三行：奖励预览（仅可用副本）
                    #rewardChildren > 0 and UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 3,
                        marginTop = 2,
                        children = rewardChildren,
                    } or nil,
                    -- 第四行：排名（左下角）
                    (def.key == "tower" and isAvailable) and UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 4,
                        marginTop = 2,
                        children = {
                            UI.Label {
                                text = "🏆",
                                fontSize = 11,
                                pointerEvents = "none",
                            },
                            UI.Label {
                                id = "towerRankLabel",
                                text = rankCache.tower and ("排名 第" .. rankCache.tower .. "名") or "加载中...",
                                fontSize = 11,
                                fontColor = S.gold,
                                pointerEvents = "none",
                            },
                        },
                    } or nil,
                    (def.key == "resource" and isAvailable) and UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 4,
                        marginTop = 2,
                        children = {
                            UI.Label {
                                text = "🏆",
                                fontSize = 11,
                                pointerEvents = "none",
                            },
                            UI.Label {
                                id = "dungeonRankLabel",
                                text = rankCache.dungeon and ("排名 第" .. rankCache.dungeon .. "名") or "加载中...",
                                fontSize = 11,
                                fontColor = S.gold,
                                pointerEvents = "none",
                            },
                        },
                    } or nil,
                },
            },
            -- 右侧箭头指示
            isAvailable and UI.Panel {
                width = 30,
                justifyContent = "center",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "›",
                        fontSize = 24,
                        fontColor = S.dim,
                        pointerEvents = "none",
                    },
                },
            } or nil,
        },
    }
end

-- ============================================================================
-- 二级页面：试练塔详情
-- ============================================================================

function DungeonUI.BuildTowerDetailView()
    local data = TrialTowerData.GetData()
    local currentFloor = data.currentFloor
    local towerNum = TrialTowerData.GetTowerNum(currentFloor)
    local floorInTower = TrialTowerData.GetFloorInTower(currentFloor)

    -- 顶部标题栏（含返回按钮）
    pageRoot:AddChild(DungeonUI.BuildDetailHeader(towerNum))

    -- 内容区域用 ScrollView 包裹
    local contentChildren = {}

    -- 当前塔信息卡
    contentChildren[#contentChildren + 1] = DungeonUI.BuildTowerInfoCard(towerNum, floorInTower, currentFloor)

    -- 层数网格
    contentChildren[#contentChildren + 1] = DungeonUI.BuildFloorGrid(towerNum, currentFloor)

    -- 奖励预览
    contentChildren[#contentChildren + 1] = DungeonUI.BuildRewardPreview(towerNum)

    pageRoot:AddChild(UI.ScrollView {
        width = "100%",
        flex = 1,
        children = contentChildren,
    })

    -- 底部挑战按钮（固定在底部）
    pageRoot:AddChild(DungeonUI.BuildChallengeButton(currentFloor))
end

--- 详情页标题栏
function DungeonUI.BuildDetailHeader(towerNum)
    local diffLabel, diffColor = TrialTowerData.GetDifficultyLabel(towerNum)
    return UI.Panel {
        width = "100%",
        height = 50,
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = S.headerBg,
        flexShrink = 0,
        gap = 8,
        children = {
            UI.Label {
                text = "试练塔",
                fontSize = 20,
                fontWeight = "bold",
                fontColor = S.white,
                pointerEvents = "none",
            },
            UI.Panel {
                paddingLeft = 8, paddingRight = 8,
                paddingTop = 2, paddingBottom = 2,
                borderRadius = 4,
                backgroundColor = { diffColor[1], diffColor[2], diffColor[3], 60 },
                children = {
                    UI.Label {
                        text = diffLabel,
                        fontSize = 12,
                        fontColor = diffColor,
                        pointerEvents = "none",
                    },
                },
            },
        },
    }
end

--- 当前塔信息卡片
function DungeonUI.BuildTowerInfoCard(towerNum, floorInTower, currentFloor)
    local themeDef = TrialTowerData.GetTheme(currentFloor)
    local themeName = themeDef and themeDef.name or "未知"
    local themeColor = (themeDef and themeDef.color) or S.purple

    return UI.Panel {
        width = "100%",
        paddingLeft = 12, paddingRight = 12,
        paddingTop = 8,
        flexShrink = 0,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                backgroundColor = S.cardBg,
                borderRadius = 8,
                borderWidth = 1,
                borderColor = S.cardBorder,
                paddingLeft = 14, paddingRight = 14,
                paddingTop = 12, paddingBottom = 12,
                children = {
                    -- 左：塔号 + 主题
                    UI.Panel {
                        flexDirection = "column",
                        gap = 4,
                        children = {
                            UI.Label {
                                text = "第 " .. towerNum .. " 塔",
                                fontSize = 18,
                                fontWeight = "bold",
                                fontColor = S.gold,
                                pointerEvents = "none",
                            },
                            UI.Panel {
                                flexDirection = "row",
                                alignItems = "center",
                                gap = 4,
                                children = {
                                    UI.Label {
                                        text = "主题:",
                                        fontSize = 12,
                                        fontColor = S.dim,
                                        pointerEvents = "none",
                                    },
                                    UI.Label {
                                        text = themeName,
                                        fontSize = 12,
                                        fontColor = themeColor,
                                        pointerEvents = "none",
                                    },
                                },
                            },
                        },
                    },
                    -- 右：进度
                    UI.Panel {
                        flexDirection = "column",
                        alignItems = "flex-end",
                        gap = 4,
                        children = {
                            UI.Label {
                                text = "进度",
                                fontSize = 11,
                                fontColor = S.dim,
                                pointerEvents = "none",
                            },
                            UI.Label {
                                text = (floorInTower - 1) .. " / 10",
                                fontSize = 16,
                                fontWeight = "bold",
                                fontColor = S.white,
                                pointerEvents = "none",
                            },
                        },
                    },
                },
            },
        },
    }
end

--- 层数网格（当前塔 10 层）
function DungeonUI.BuildFloorGrid(towerNum, currentFloor)
    local towerStartFloor = (towerNum - 1) * 10 + 1

    local rows = {}
    for row = 1, 2 do
        local cells = {}
        for col = 1, 5 do
            local floorInTower = (row - 1) * 5 + col
            local globalFloor = towerStartFloor + floorInTower - 1
            cells[#cells + 1] = DungeonUI.BuildFloorCell(floorInTower, globalFloor, currentFloor)
        end
        rows[#rows + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            justifyContent = "center",
            gap = 6,
            children = cells,
        }
    end

    return UI.Panel {
        width = "100%",
        paddingLeft = 12, paddingRight = 12,
        paddingTop = 6,
        flexDirection = "column",
        gap = 6,
        flexShrink = 0,
        children = rows,
    }
end

--- 单个层格子
function DungeonUI.BuildFloorCell(floorInTower, globalFloor, currentFloor)
    local isCleared = TrialTowerData.IsFloorCleared(globalFloor)
    local isCurrent = TrialTowerData.IsCurrentFloor(globalFloor)
    local isBoss = (floorInTower == 10)

    local bg, border, textColor
    if isCleared then
        bg = S.clearedBg
        border = S.clearedBorder
        textColor = S.green
    elseif isCurrent then
        bg = S.currentBg
        border = S.currentBorder
        textColor = S.white
    else
        bg = S.lockedBg
        border = S.lockedBorder
        textColor = S.dim
    end

    local label = tostring(floorInTower)
    if isBoss then label = "BOSS" end

    local statusText = ""
    if isCleared then statusText = "✓"
    elseif isCurrent then statusText = "→"
    else statusText = "🔒"
    end

    return UI.Panel {
        flex = 1,
        height = 56,
        maxWidth = 60,
        flexDirection = "column",
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = bg,
        borderRadius = 6,
        borderWidth = isCurrent and 2 or 1,
        borderColor = border,
        gap = 2,
        children = {
            UI.Label {
                text = label,
                fontSize = isBoss and 11 or 14,
                fontWeight = (isCurrent or isBoss) and "bold" or "normal",
                fontColor = textColor,
                pointerEvents = "none",
            },
            UI.Label {
                text = statusText,
                fontSize = 10,
                fontColor = textColor,
                pointerEvents = "none",
            },
        },
    }
end

--- 奖励预览
function DungeonUI.BuildRewardPreview(towerNum)
    local stones, gold = TrialTowerData.GetFloorReward(towerNum)

    local rewardItems = {
        UI.Panel {
            flexDirection = "row", alignItems = "center", gap = 4,
            children = {
                UI.Label { text = "每层:", fontSize = 11, fontColor = S.dim, pointerEvents = "none" },
                Currency.IconWidget(UI, "devour_stone", 14),
                UI.Label { text = FormatNum(stones), fontSize = 12, fontColor = { 60, 160, 80 }, pointerEvents = "none" },
                UI.Label { text = "+", fontSize = 10, fontColor = S.dim, pointerEvents = "none" },
                Currency.IconWidget(UI, "nether_crystal", 14),
                UI.Label { text = FormatNum(gold), fontSize = 12, fontColor = { 140, 80, 200 }, pointerEvents = "none" },
            },
        },
        UI.Panel {
            flexDirection = "row", alignItems = "center", gap = 4,
            children = {
                UI.Label { text = "通塔:", fontSize = 11, fontColor = S.dim, pointerEvents = "none" },
                Currency.IconWidget(UI, "void_pact", 14),
                UI.Label { text = "×10", fontSize = 12, fontColor = { 200, 40, 40 }, pointerEvents = "none" },
            },
        },
    }

    return UI.Panel {
        width = "100%",
        paddingLeft = 12, paddingRight = 12,
        paddingTop = 6,
        flexShrink = 0,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-around",
                backgroundColor = S.cardBg,
                borderRadius = 6,
                paddingTop = 8, paddingBottom = 8,
                paddingLeft = 8, paddingRight = 8,
                children = rewardItems,
            },
        },
    }
end

--- 底部按钮栏（返回 + 挑战）
function DungeonUI.BuildChallengeButton(currentFloor)
    local towerNum = TrialTowerData.GetTowerNum(currentFloor)
    local floorInTower = TrialTowerData.GetFloorInTower(currentFloor)
    local isBoss = (floorInTower == 10)
    local btnText = isBoss and ("挑战 BOSS · 第" .. towerNum .. "塔") or ("挑战第 " .. floorInTower .. " 层")

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 12, paddingRight = 12,
        paddingTop = 10, paddingBottom = 10,
        flexShrink = 0,
        gap = 10,
        children = {
            -- 返回按钮（左侧）
            UI.Button {
                text = "返回",
                fontSize = 14,
                width = 70,
                height = 46,
                borderRadius = 8,
                variant = "outline",
                onClick = function()
                    currentView = "list"
                    DungeonUI.Refresh()
                end,
            },
            -- 挑战按钮（右侧，撑满剩余空间）
            UI.Button {
                id = "towerChallengeBtn",
                text = btnText,
                fontSize = 16,
                flex = 1,
                height = 46,
                borderRadius = 8,
                variant = "primary",
                onClick = function(self)
                    DungeonUI.OnChallenge()
                end,
            },
        },
    }
end

-- ============================================================================
-- 交互逻辑
-- ============================================================================

function DungeonUI.OnChallenge()
    local currentFloor = TrialTowerData.GetCurrentFloor()
    local towerNum = TrialTowerData.GetTowerNum(currentFloor)
    local floorInTower = TrialTowerData.GetFloorInTower(currentFloor)
    local isBoss = (floorInTower == 10)

    local BM = require("Game.BattleManager")
    local GameUI = require("Game.GameUI")

    -- 5 波 × 20 只，按波生成
    local totalWaves = TrialTowerData.WAVE_COUNT
    local waves = {}
    for w = 1, totalWaves do
        local enemyDefs = TrialTowerData.GenerateWaveEnemies(currentFloor, w)
        waves[w] = BM.BuildSpawnQueue(enemyDefs, 0.5)
    end

    local label = "试练塔 " .. towerNum .. "-" .. floorInTower

    GameUI.EnterDungeonBattle({
        mode = "trial_tower",
        waves = waves,
        totalWaves = totalWaves,
        stageNum = towerNum,
        label = label,
        waveInterval = 25,
        autoAdvanceWave = true,
        bossTimerEnabled = isBoss,
        overloadEnabled = true,
        overloadLimit = TrialTowerData.OVERLOAD_LIMIT,
        initialDarkSoul = Config.INITIAL_DARK_SOUL,
        onWin = function(result)
            local rewards = TrialTowerData.ClearFloor(currentFloor)
            if rewards then
                local rewardItems = {}
                -- 噬魂石
                if rewards.devour_stone and rewards.devour_stone > 0 then
                    local def = Config.CURRENCY["devour_stone"]
                    rewardItems[#rewardItems + 1] = {
                        icon = def and def.image or "?",
                        name = def and def.name or "噬魂石",
                        amount = rewards.devour_stone,
                    }
                end
                -- 冥晶
                if rewards.nether_crystal and rewards.nether_crystal > 0 then
                    local def = Config.CURRENCY["nether_crystal"]
                    rewardItems[#rewardItems + 1] = {
                        icon = def and def.image or "?",
                        name = def and def.name or "冥晶",
                        amount = rewards.nether_crystal,
                    }
                end
                -- 通塔奖励：虚空契约
                if rewards.isTowerClear and rewards.void_pact and rewards.void_pact > 0 then
                    local def = Config.CURRENCY["void_pact"]
                    rewardItems[#rewardItems + 1] = {
                        icon = def and def.image or "?",
                        name = def and def.name or "虚空契约",
                        amount = rewards.void_pact,
                        borderColor = { 255, 200, 50, 200 },
                    }
                end
                if #rewardItems > 0 then
                    local root = GameUI.GetUIRoot()
                    if root then
                        RewardDisplay.Show(UI, root, {
                            title = label .. " 通关",
                            rewards = rewardItems,
                            onClose = function()
                                GameUI.ExitDungeonBattle()
                            end,
                        })
                        return
                    end
                end
            end
            GameUI.ExitDungeonBattle()
        end,
        onLose = function(result)
            Toast.Show(label .. " 挑战失败 (第" .. result.wave .. "/" .. totalWaves .. "波)", S.red)
            GameUI.ExitDungeonBattle()
        end,
    })
end

-- ============================================================================
-- 资源副本：二级页面 - 4 种副本列表
-- ============================================================================

function DungeonUI.BuildResourceListView()
    -- 标题栏（无返回按钮）
    pageRoot:AddChild(UI.Panel {
        width = "100%",
        height = 50,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = S.headerBg,
        flexShrink = 0,
        children = {
            UI.Label {
                text = "资源副本",
                fontSize = 20,
                fontWeight = "bold",
                fontColor = S.white,
                textAlign = "center",
                pointerEvents = "none",
            },
        },
    })

    -- 4 种资源副本卡片
    local cards = {}
    for _, def in ipairs(RD.DUNGEON_DEFS) do
        cards[#cards + 1] = DungeonUI.BuildResourceCard(def)
    end

    pageRoot:AddChild(UI.ScrollView {
        width = "100%",
        flex = 1,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "column",
                paddingTop = 6, paddingBottom = 6,
                paddingLeft = 12, paddingRight = 12,
                gap = 10,
                children = cards,
            },
        },
    })

    -- 底部返回按钮
    pageRoot:AddChild(UI.Panel {
        width = "100%",
        flexShrink = 0,
        paddingLeft = 12, paddingRight = 12,
        paddingTop = 6, paddingBottom = 10,
        children = {
            UI.Button {
                text = "返回",
                fontSize = 14,
                width = 70, height = 46,
                borderRadius = 8,
                variant = "outline",
                onClick = function()
                    currentView = "list"
                    DungeonUI.Refresh()
                end,
            },
        },
    })
end

--- 构建资源副本卡片（大图卡片风格，与副本主页一致）
function DungeonUI.BuildResourceCard(def)
    local remaining = RD.GetRemainingAttempts(def.key)
    local bestWave = RD.GetBestWave(def.key)
    local canChallenge = remaining > 0

    local currDef = Config.CURRENCY[def.rewardCurrency]

    -- 次数 badge 颜色
    local badgeBg = canChallenge and { 80, 180, 80, 40 } or { 200, 60, 60, 40 }
    local badgeColor = canChallenge and S.green or S.red

    -- 奖励预览
    local rewardChildren = {}
    if def.rewardCurrency ~= "chest" and currDef then
        rewardChildren = {
            Currency.IconWidget(UI, def.rewardCurrency, 13),
            UI.Label {
                text = currDef.name, fontSize = 11,
                fontColor = currDef.color or S.dim, pointerEvents = "none",
            },
        }
    else
        rewardChildren = {
            UI.Panel {
                width = 13, height = 13,
                backgroundImage = "image/tab_chest_20260408235703.png",
                backgroundFit = "contain",
                pointerEvents = "none",
                flexShrink = 0,
            },
            UI.Label {
                text = "宝箱", fontSize = 11,
                fontColor = S.gold, pointerEvents = "none",
            },
        }
    end

    return UI.Panel {
        width = "100%",
        aspectRatio = 16 / 9,
        flexDirection = "column",
        backgroundColor = canChallenge and S.cardBg or { 25, 20, 38, 180 },
        backgroundImage = def.cover,
        backgroundScaleMode = def.cover and "aspectFill" or nil,
        borderRadius = 10,
        borderWidth = 1,
        borderColor = { def.accentColor[1], def.accentColor[2], def.accentColor[3], canChallenge and 120 or 60 },
        overflow = "hidden",
        onClick = function()
            currentResourceKey = def.key
            currentView = "resource_detail"
            DungeonUI.Refresh()
        end,
        children = {
            -- 内容区（半透明遮罩保证文字可读）
            UI.Panel {
                width = "100%",
                flex = 1,
                flexDirection = "column",
                justifyContent = "flex-start",
                paddingLeft = 14, paddingRight = 14,
                paddingTop = 14, paddingBottom = 14,
                backgroundColor = def.cover and { 15, 12, 25, 140 } or nil,
                gap = 6,
                children = {
                    -- 第一行：emoji + 名称 + 次数 badge
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        justifyContent = "space-between",
                        children = {
                            UI.Label {
                                text = def.name, fontSize = 17, fontWeight = "bold",
                                fontColor = canChallenge and S.white or S.dim,
                                pointerEvents = "none",
                            },
                            UI.Panel {
                                paddingLeft = 8, paddingRight = 8,
                                paddingTop = 3, paddingBottom = 3,
                                borderRadius = 10,
                                backgroundColor = badgeBg,
                                children = {
                                    UI.Label {
                                        text = remaining .. "/" .. RD.DAILY_ATTEMPTS,
                                        fontSize = 11, fontColor = badgeColor,
                                        pointerEvents = "none",
                                    },
                                },
                            },
                        },
                    },
                    -- 第二行：描述
                    UI.Label {
                        text = def.desc, fontSize = 12, fontColor = S.dim, pointerEvents = "none",
                    },
                    -- 第三行：奖励图标
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = 3,
                        children = rewardChildren,
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- 资源副本：三级页面 - 具体副本详情（20 波进度）
-- ============================================================================

function DungeonUI.BuildResourceDetailView()
    local def = RD.DUNGEON_MAP[currentResourceKey]
    if not def then
        currentView = "resource_list"
        DungeonUI.Refresh()
        return
    end

    local bestWave = RD.GetBestWave(def.key)
    local remaining = RD.GetRemainingAttempts(def.key)
    local ticketCount = InventoryData.GetCount("dungeon_ticket")

    -- 标题栏
    pageRoot:AddChild(UI.Panel {
        width = "100%",
        height = 50,
        flexDirection = "row",
        alignItems = "center",
        backgroundColor = S.headerBg,
        flexShrink = 0,
        children = {
            UI.Panel {
                width = 50, height = 50,
                justifyContent = "center", alignItems = "center",
                onClick = function()
                    currentView = "resource_list"
                    DungeonUI.Refresh()
                end,
                children = {
                    UI.Label { text = "‹", fontSize = 22, fontColor = S.dim, pointerEvents = "none" },
                },
            },
            UI.Label {
                text = def.name, fontSize = 20, fontWeight = "bold",
                fontColor = S.white, pointerEvents = "none",
            },
            UI.Panel { flex = 1 },
            -- 门票数量（仅有门票时显示）
            ticketCount > 0 and UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                paddingRight = 4,
                gap = 3,
                children = {
                    UI.Panel {
                        width = 14, height = 14,
                        backgroundImage = "image/item_dungeon_ticket_20260410115546.png",
                        backgroundFit = "contain",
                        pointerEvents = "none",
                    },
                    UI.Label {
                        text = "×" .. ticketCount,
                        fontSize = 11,
                        fontColor = S.gold,
                        pointerEvents = "none",
                    },
                },
            } or nil,
            UI.Panel {
                paddingLeft = 8, paddingRight = 12,
                paddingTop = 3, paddingBottom = 3,
                children = {
                    UI.Label {
                        text = "剩余 " .. remaining .. " 次",
                        fontSize = 12,
                        fontColor = remaining > 0 and S.green or S.red,
                        pointerEvents = "none",
                    },
                },
            },
        },
    })

    -- 滚动内容
    local contentChildren = {}

    -- 信息卡
    contentChildren[#contentChildren + 1] = DungeonUI.BuildResourceInfoCard(def, bestWave)

    -- 波次网格 (4 行 × 5 列 = 20 波)
    contentChildren[#contentChildren + 1] = DungeonUI.BuildWaveGrid(def, bestWave)

    -- 奖励预览表
    contentChildren[#contentChildren + 1] = DungeonUI.BuildResourceRewardPreview(def)

    pageRoot:AddChild(UI.ScrollView {
        width = "100%",
        flex = 1,
        children = contentChildren,
    })

    -- 底部挑战按钮
    pageRoot:AddChild(DungeonUI.BuildResourceChallengeButton(def, remaining))
end

--- 资源副本信息卡
function DungeonUI.BuildResourceInfoCard(def, bestWave)
    local diffLabel, diffColor
    if bestWave == 0 then
        diffLabel, diffColor = "未挑战", S.dim
    else
        diffLabel, diffColor = RD.GetWaveDifficulty(bestWave)
    end

    return UI.Panel {
        width = "100%",
        paddingLeft = 12, paddingRight = 12,
        paddingTop = 8,
        flexShrink = 0,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                backgroundColor = S.cardBg,
                borderRadius = 8,
                borderWidth = 1,
                borderColor = { def.accentColor[1], def.accentColor[2], def.accentColor[3], 80 },
                paddingLeft = 14, paddingRight = 14,
                paddingTop = 12, paddingBottom = 12,
                children = {
                    -- 左：副本名 + 规则
                    UI.Panel {
                        flexDirection = "column", gap = 4,
                        children = {
                            UI.Label {
                                text = def.name, fontSize = 18, fontWeight = "bold",
                                fontColor = def.accentColor, pointerEvents = "none",
                            },
                            UI.Label {
                                text = RD.TOTAL_WAVES .. "波 × " .. RD.ENEMIES_PER_WAVE .. "怪 · 每波末尾Boss",
                                fontSize = 11, fontColor = S.dim, pointerEvents = "none",
                            },
                        },
                    },
                    -- 右：最高纪录
                    UI.Panel {
                        flexDirection = "column", alignItems = "flex-end", gap = 4,
                        children = {
                            UI.Label { text = "最高纪录", fontSize = 11, fontColor = S.dim, pointerEvents = "none" },
                            UI.Label {
                                text = bestWave > 0 and ("第 " .. bestWave .. " 波") or "—",
                                fontSize = 16, fontWeight = "bold",
                                fontColor = bestWave > 0 and S.gold or S.dim,
                                pointerEvents = "none",
                            },
                        },
                    },
                },
            },
        },
    }
end

--- 波次网格（4 行 × 5 列 = 20 波）
function DungeonUI.BuildWaveGrid(def, bestWave)
    local rows = {}
    for row = 1, 4 do
        local cells = {}
        for col = 1, 5 do
            local wave = (row - 1) * 5 + col
            cells[#cells + 1] = DungeonUI.BuildWaveCell(def, wave, bestWave)
        end
        rows[#rows + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            justifyContent = "center",
            gap = 5,
            children = cells,
        }
    end

    return UI.Panel {
        width = "100%",
        paddingLeft = 12, paddingRight = 12,
        paddingTop = 6,
        flexDirection = "column",
        gap = 5,
        flexShrink = 0,
        children = rows,
    }
end

--- 单个波次格子
function DungeonUI.BuildWaveCell(def, wave, bestWave)
    local isCleared = wave <= bestWave
    local isNext = wave == bestWave + 1
    local isBossWave = (wave % 5 == 0)  -- 5/10/15/20 波标记

    local bg, border, textColor
    if isCleared then
        bg = S.clearedBg
        border = S.clearedBorder
        textColor = S.green
    elseif isNext then
        bg = { def.accentColor[1], def.accentColor[2], def.accentColor[3], 80 }
        border = def.accentColor
        textColor = S.white
    else
        bg = S.lockedBg
        border = S.lockedBorder
        textColor = S.dim
    end

    -- 奖励显示
    local reward = RD.GetWaveReward(def.key, wave)
    local rewardText = ""
    ---@type table|nil
    local chestReward = nil
    ---@type string|nil
    local chestImage = nil
    if def.rewardCurrency == "chest" then
        chestReward = RD.GetChestWaveReward(wave)
        if chestReward then
            local ct = Config.CHEST_TYPES_MAP[chestReward.id]
            chestImage = ct and ct.image
        end
    elseif reward > 0 then
        rewardText = "+" .. FormatNum(reward)
    end

    -- 宝箱波次底部：图标 + 数量
    local bottomChild
    if isCleared then
        bottomChild = UI.Label {
            text = "✓", fontSize = 9,
            fontColor = S.green, pointerEvents = "none",
        }
    elseif chestReward and chestImage then
        local countLabel = chestReward.count > 1 and ("×" .. chestReward.count) or nil
        bottomChild = UI.Panel {
            flexDirection = "row", alignItems = "center", gap = 1,
            children = {
                UI.Panel {
                    width = 16, height = 16,
                    backgroundImage = chestImage,
                    backgroundScaleMode = "aspectFit",
                },
                countLabel and UI.Label {
                    text = countLabel, fontSize = 8,
                    fontColor = S.gold, pointerEvents = "none",
                } or nil,
            },
        }
    else
        bottomChild = UI.Label {
            text = rewardText, fontSize = 9,
            fontColor = def.rewardCurrency == "chest" and S.gold or def.accentColor,
            pointerEvents = "none",
        }
    end

    return UI.Panel {
        flex = 1,
        height = 52,
        maxWidth = 62,
        flexDirection = "column",
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = bg,
        borderRadius = 6,
        borderWidth = isNext and 2 or 1,
        borderColor = border,
        gap = 1,
        children = {
            UI.Label {
                text = isBossWave and ("W" .. wave .. "★") or ("W" .. wave),
                fontSize = isBossWave and 10 or 11,
                fontWeight = (isNext or isBossWave) and "bold" or "normal",
                fontColor = textColor,
                pointerEvents = "none",
            },
            bottomChild,
        },
    }
end

--- 资源副本奖励预览
function DungeonUI.BuildResourceRewardPreview(def)
    -- 选几个关键波次展示奖励
    local milestones = { 5, 10, 15, 20 }
    local items = {}

    for _, w in ipairs(milestones) do
        local reward = RD.GetWaveReward(def.key, w)
        local diffLabel, diffColor = RD.GetWaveDifficulty(w)
        local rewardText = ""
        local rewardImage = nil
        if def.rewardCurrency == "chest" then
            local cr = RD.GetChestWaveReward(w)
            if cr then
                local ct = Config.CHEST_TYPES_MAP[cr.id]
                rewardText = (ct and ct.name or cr.id) .. " ×" .. cr.count
                rewardImage = ct and ct.image
            end
        else
            local currDef = Config.CURRENCY[def.rewardCurrency]
            local name = currDef and currDef.name or def.rewardCurrency
            rewardText = name .. " +" .. FormatNum(reward)
        end

        items[#items + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            justifyContent = "space-between",
            paddingTop = 4, paddingBottom = 4,
            children = {
                -- 左：波次 + 难度
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = 6,
                    children = {
                        UI.Label {
                            text = "第" .. w .. "波", fontSize = 12,
                            fontWeight = "bold", fontColor = S.white, pointerEvents = "none",
                        },
                        UI.Panel {
                            paddingLeft = 4, paddingRight = 4,
                            paddingTop = 1, paddingBottom = 1,
                            borderRadius = 3,
                            backgroundColor = { diffColor[1], diffColor[2], diffColor[3], 50 },
                            children = {
                                UI.Label {
                                    text = diffLabel, fontSize = 9,
                                    fontColor = diffColor, pointerEvents = "none",
                                },
                            },
                        },
                    },
                },
                -- 右：奖励
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = 4,
                    children = {
                        rewardImage and UI.Panel {
                            width = 18, height = 18,
                            backgroundImage = rewardImage,
                            backgroundScaleMode = "aspectFit",
                        } or nil,
                        UI.Label {
                            text = rewardText, fontSize = 11,
                            fontColor = def.accentColor, pointerEvents = "none",
                        },
                    },
                },
            },
        }
    end

    -- 总计
    local totalRewards = RD.CalcTotalRewards(def.key, RD.TOTAL_WAVES)
    local totalText
    if def.rewardCurrency == "chest" then
        local c = totalRewards.chests or {}
        local parts = {}
        for _, ctDef in ipairs(Config.CHEST_TYPES) do
            if c[ctDef.id] and c[ctDef.id] > 0 then
                parts[#parts + 1] = ctDef.name .. "×" .. c[ctDef.id]
            end
        end
        totalText = table.concat(parts, " ")
    else
        local total = totalRewards[def.rewardCurrency] or 0
        local currDef = Config.CURRENCY[def.rewardCurrency]
        totalText = (currDef and currDef.name or "") .. " " .. FormatNum(total)
    end

    items[#items + 1] = UI.Panel {
        width = "100%", height = 1,
        backgroundColor = { 100, 70, 160, 60 },
        marginTop = 2,
    }
    items[#items + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "space-between",
        paddingTop = 4,
        children = {
            UI.Label {
                text = "全通关总计", fontSize = 12,
                fontWeight = "bold", fontColor = S.gold, pointerEvents = "none",
            },
            UI.Label {
                text = totalText, fontSize = 12,
                fontWeight = "bold", fontColor = S.gold, pointerEvents = "none",
            },
        },
    }

    return UI.Panel {
        width = "100%",
        paddingLeft = 12, paddingRight = 12,
        paddingTop = 8,
        flexShrink = 0,
        children = {
            UI.Panel {
                width = "100%",
                backgroundColor = S.cardBg,
                borderRadius = 8,
                paddingLeft = 12, paddingRight = 12,
                paddingTop = 8, paddingBottom = 8,
                flexDirection = "column",
                children = items,
            },
        },
    }
end

--- 资源副本底部按钮
function DungeonUI.BuildResourceChallengeButton(def, remaining)
    local canChallenge = remaining > 0
    local ticketCount = InventoryData.GetCount("dungeon_ticket")
    local canUseTicket = (not canChallenge) and ticketCount > 0

    local actionChildren = {
        UI.Button {
            text = "返回",
            fontSize = 14,
            width = 70, height = 46,
            borderRadius = 8,
            variant = "outline",
            onClick = function()
                currentView = "resource_list"
                DungeonUI.Refresh()
            end,
        },
    }

    if canChallenge then
        -- 有免费次数
        actionChildren[#actionChildren + 1] = UI.Button {
            text = "挑战 " .. def.name .. " (" .. remaining .. "次)",
            fontSize = 15,
            flex = 1, height = 46,
            borderRadius = 8,
            variant = "primary",
            onClick = function()
                DungeonUI.OnResourceChallenge(def.key, false)
            end,
        }
    elseif canUseTicket then
        -- 免费次数用完，但有门票
        actionChildren[#actionChildren + 1] = UI.Button {
            text = "使用门票挑战 (余" .. ticketCount .. "张)",
            fontSize = 14,
            flex = 1, height = 46,
            borderRadius = 8,
            variant = "primary",
            onClick = function()
                DungeonUI.OnResourceChallenge(def.key, true)
            end,
        }
    else
        -- 既没有免费次数也没有门票
        actionChildren[#actionChildren + 1] = UI.Button {
            text = "今日次数已用完",
            fontSize = 13,
            flex = 1, height = 46,
            borderRadius = 8,
            variant = "outline",
        }
    end

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 12, paddingRight = 12,
        paddingTop = 10, paddingBottom = 10,
        flexShrink = 0,
        gap = 10,
        children = actionChildren,
    }
end

-- ============================================================================
-- 资源副本挑战逻辑
-- ============================================================================

function DungeonUI.OnResourceChallenge(dungeonKey, useTicket)
    local def = RD.DUNGEON_MAP[dungeonKey]
    if not def then return end

    -- 入场时立即消耗次数/门票
    if useTicket then
        if not RD.ConsumeTicket() then return end
    else
        if not RD.ConsumeAttempt(dungeonKey) then return end
    end

    -- 预生成全部 20 波的 spawn queue
    local BM = require("Game.BattleManager")
    local GameUI = require("Game.GameUI")

    local waves = {}
    local totalWaves = RD.TOTAL_WAVES

    for w = 1, totalWaves do
        local enemyDefs = RD.GenerateWaveEnemies(dungeonKey, w)
        -- 每波 19 个普通怪 + 1 个 Boss，间隔较短（大量敌人）
        waves[w] = BM.BuildSpawnQueue(enemyDefs, 0.5)
    end

    local label = (def.name or dungeonKey) .. "副本"

    GameUI.EnterDungeonBattle({
        mode = "resource_dungeon",
        waves = waves,
        totalWaves = totalWaves,
        stageNum = 1,
        label = label,
        waveInterval = 30,
        autoAdvanceWave = true,
        bossTimerEnabled = true,
        overloadEnabled = true,
        overloadLimit = 10,
        initialDarkSoul = Config.INITIAL_DARK_SOUL,

        onWin = function(result)
            -- 全部通关，发放全额奖励（次数/门票已在入场时扣除）
            local rewards = RD.ClaimReward(dungeonKey, totalWaves)
            if rewards then
                local rewardItems = {}
                if def.rewardCurrency == "chest" then
                    local c = rewards.chests or {}
                    for chestId, count in pairs(c) do
                        if count > 0 then
                            local ct = Config.CHEST_TYPES_MAP[chestId]
                            rewardItems[#rewardItems + 1] = {
                                icon = ct and ct.image or "?",
                                name = ct and ct.name or chestId,
                                amount = count,
                                borderColor = ct and ct.borderColor or nil,
                            }
                        end
                    end
                else
                    local currDef = Config.CURRENCY[def.rewardCurrency]
                    local amount = rewards[def.rewardCurrency] or 0
                    if amount > 0 then
                        rewardItems[#rewardItems + 1] = {
                            icon = currDef and currDef.image or "?",
                            name = currDef and currDef.name or def.rewardCurrency,
                            amount = amount,
                        }
                    end
                end
                if #rewardItems > 0 then
                    local root = GameUI.GetUIRoot()
                    if root then
                        RewardDisplay.Show(UI, root, {
                            title = label .. " 全部通关!",
                            rewards = rewardItems,
                            onClose = function()
                                GameUI.ExitDungeonBattle()
                            end,
                        })
                        return
                    end
                end
            end
            GameUI.ExitDungeonBattle()
        end,

        onExit = function(result)
            -- 玩家主动退出：按已通关波数结算奖励（次数/门票已在入场时扣除）
            local clearedWave = math.max(0, result.wave - 1)
            if clearedWave > 0 then
                local rewards = RD.ClaimReward(dungeonKey, clearedWave)
                if rewards then
                    local rewardItems = {}
                    if def.rewardCurrency == "chest" then
                        local c = rewards.chests or {}
                        for chestId, count in pairs(c) do
                            if count > 0 then
                                local ct = Config.CHEST_TYPES_MAP[chestId]
                                rewardItems[#rewardItems + 1] = {
                                    icon = ct and ct.image or "?",
                                    name = ct and ct.name or chestId,
                                    amount = count,
                                    borderColor = ct and ct.borderColor or nil,
                                }
                            end
                        end
                    else
                        local currDef = Config.CURRENCY[def.rewardCurrency]
                        local amount = rewards[def.rewardCurrency] or 0
                        if amount > 0 then
                            rewardItems[#rewardItems + 1] = {
                                icon = currDef and currDef.image or "?",
                                name = currDef and currDef.name or def.rewardCurrency,
                                amount = amount,
                            }
                        end
                    end
                    if #rewardItems > 0 then
                        local root = GameUI.GetUIRoot()
                        if root then
                            RewardDisplay.Show(UI, root, {
                                title = label .. " 提前退出 (第" .. clearedWave .. "波)",
                                rewards = rewardItems,
                                onClose = function()
                                    GameUI.ExitDungeonBattle()
                                end,
                            })
                            return
                        end
                    end
                end
            else
                Toast.Show(label .. " 提前退出，无奖励", S.red)
            end
            GameUI.ExitDungeonBattle()
        end,

        onLose = function(result)
            -- 失败：按打到的波数发放部分奖励（次数/门票已在入场时扣除）
            local clearedWave = math.max(0, result.wave - 1)
            if clearedWave > 0 then
                local rewards = RD.ClaimReward(dungeonKey, clearedWave)
                if rewards then
                    local rewardItems = {}
                    if def.rewardCurrency == "chest" then
                        local c = rewards.chests or {}
                        for chestId, count in pairs(c) do
                            if count > 0 then
                                local ct = Config.CHEST_TYPES_MAP[chestId]
                                rewardItems[#rewardItems + 1] = {
                                    icon = ct and ct.image or "?",
                                    name = ct and ct.name or chestId,
                                    amount = count,
                                    borderColor = ct and ct.borderColor or nil,
                                }
                            end
                        end
                    else
                        local currDef = Config.CURRENCY[def.rewardCurrency]
                        local amount = rewards[def.rewardCurrency] or 0
                        if amount > 0 then
                            rewardItems[#rewardItems + 1] = {
                                icon = currDef and currDef.image or "?",
                                name = currDef and currDef.name or def.rewardCurrency,
                                amount = amount,
                            }
                        end
                    end
                    if #rewardItems > 0 then
                        local root = GameUI.GetUIRoot()
                        if root then
                            RewardDisplay.Show(UI, root, {
                                title = label .. " 第" .. clearedWave .. "波失败",
                                rewards = rewardItems,
                                onClose = function()
                                    GameUI.ExitDungeonBattle()
                                end,
                            })
                            return
                        end
                    end
                end
            else
                -- 第一波就失败了，无奖励（次数/门票已在入场时扣除）
                Toast.Show(label .. " 挑战失败", S.red)
            end
            GameUI.ExitDungeonBattle()
        end,
    })
end

return DungeonUI
