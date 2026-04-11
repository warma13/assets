-- Game/GameUI.lua
-- 暗黑塔防游戏 - UI 面板（门面模块）
-- 子模块: GameUI_Widgets, GameUI_Panels, GameUI_Stage, GameUI_Afk

local Config = require("Game.Config")
local State = require("Game.State")
local Tower = require("Game.Tower")
local Wave = require("Game.Wave")
local HeroData = require("Game.HeroData")
local Currency = require("Game.Currency")
local TabNav = require("Game.TabNav")
local HeroUI = require("Game.HeroUI")
local RecruitUI = require("Game.RecruitUI")
local ChestUI = require("Game.ChestUI")
local ChestData = require("Game.ChestData")
local EquipUI = require("Game.EquipUI")
local EquipData = require("Game.EquipData")
local DungeonUI = require("Game.DungeonUI")
local ActivityUI = require("Game.ActivityUI")
local ActivityData = require("Game.ActivityData")
local LaunchGiftUI = require("Game.LaunchGiftUI")
local DailyTaskUI = require("Game.DailyTaskUI")
local LeaderboardUI = require("Game.LeaderboardUI")
local SpeedBoost = require("Game.SpeedBoostData")
local Toast = require("Game.Toast")
local ServerSelectUI = require("Game.ServerSelectUI")

local GameUI = {}

---@type any
local UI = nil
---@type any
local uiRoot = nil

-- 共享上下文
local ctx = {
    UI = nil,       -- 延迟设置
    uiRoot = nil,   -- 延迟设置
    lastInfoTowerId = nil,
    lastInfoTowerStar = nil,
}

--- 格式化大数字（万/亿）
local function FormatNum(n)
    if n >= 100000000 then return string.format("%.1f亿", n / 100000000) end
    if n >= 10000 then return string.format("%.1f万", n / 10000) end
    return tostring(math.floor(n))
end
ctx.FormatNum = FormatNum

function GameUI.Init(uiModule)
    UI = uiModule
    ctx.UI = uiModule
end

-- 加载子模块
require("Game.GameUI_Widgets")(GameUI, ctx)
require("Game.GameUI_Panels")(GameUI, ctx)
require("Game.GameUI_Stage")(GameUI, ctx)
require("Game.GameUI_Afk")(GameUI, ctx)

--- 更新 HUD 上的文本
function GameUI.UpdateHUD()
    if not uiRoot then return end

    local darkSouls = Currency.GetDarkSouls()

    local bottomGoldLabel = uiRoot:FindById("bottomGoldLabel")
    if bottomGoldLabel then bottomGoldLabel:SetText(tostring(darkSouls)) end

    local hudCrystalLabel = uiRoot:FindById("hudCrystalLabel")
    if hudCrystalLabel then hudCrystalLabel:SetText(FormatNum(Currency.Get("nether_crystal"))) end
    local hudEssenceLabel = uiRoot:FindById("hudEssenceLabel")
    if hudEssenceLabel then hudEssenceLabel:SetText(FormatNum(Currency.Get("shadow_essence"))) end

    local waveLabel = uiRoot:FindById("waveLabel")
    if waveLabel then
        local BM = require("Game.BattleManager")
        if BM.IsActive() then
            waveLabel:SetText(BM.GetLabel())
        else
            local typeTag = ""
            if State.waveType == "boss" then typeTag = " BOSS"
            elseif State.waveType == "elite" then typeTag = " 精英"
            end
            waveLabel:SetText(State.currentStage .. "-" .. State.currentWave .. typeTag)
        end
    end

    local summonBtn = uiRoot:FindById("summonBtn")
    if summonBtn then
        local canSummon = Tower.CanSummon()
        if canSummon then
            summonBtn:SetStyle({ backgroundColor = { 100, 60, 200, 255 } })
        else
            summonBtn:SetStyle({ backgroundColor = { 60, 40, 80, 200 } })
        end
    end

    local summonCostLabel = uiRoot:FindById("summonCostLabel")
    if summonCostLabel then
        summonCostLabel:SetText(tostring(Tower.GetSummonCost()))
    end

    local heroInfoPanel = uiRoot:FindById("heroInfoPanel")
    if heroInfoPanel then
        local sel = State.selectedTower
        if sel then
            local needUpdate = (sel.id ~= ctx.lastInfoTowerId) or (sel.star ~= ctx.lastInfoTowerStar)
            if needUpdate then
                ctx.lastInfoTowerId = sel.id
                ctx.lastInfoTowerStar = sel.star
                heroInfoPanel:ClearChildren()
                local content = GameUI.BuildHeroInfoContent(sel)
                for _, child in ipairs(content) do
                    if child then
                        heroInfoPanel:AddChild(child)
                    end
                end
            end
            heroInfoPanel:SetVisible(true)
        else
            if ctx.lastInfoTowerId then
                ctx.lastInfoTowerId = nil
                ctx.lastInfoTowerStar = nil
                heroInfoPanel:ClearChildren()
            end
            heroInfoPanel:SetVisible(false)
        end
    end

    -- 退出副本按钮（仅副本模式显示）
    local exitDungeonBtn = uiRoot:FindById("exitDungeonBtn")
    if exitDungeonBtn then
        local BM = require("Game.BattleManager")
        exitDungeonBtn:SetVisible(BM.IsActive())
    end

    -- 自动召唤按钮状态
    local autoSummonBtn = uiRoot:FindById("autoSummonBtn")
    if autoSummonBtn then
        local unlocked = State.IsAutoUnlockedToday("autoSummon")
        if not unlocked then
            autoSummonBtn:SetText("自动召唤 ▶")
            autoSummonBtn:SetStyle({ backgroundColor = { 80, 60, 40, 200 }, fontColor = { 255, 200, 100, 255 } })
        elseif State.autoSummon then
            autoSummonBtn:SetText("自动召唤:开")
            autoSummonBtn:SetStyle({ backgroundColor = { 100, 60, 200, 255 }, fontColor = { 255, 255, 255, 255 } })
        else
            autoSummonBtn:SetText("自动召唤:关")
            autoSummonBtn:SetStyle({ backgroundColor = { 60, 50, 80, 200 }, fontColor = { 180, 160, 220, 255 } })
        end
    end

    -- 自动合成按钮状态
    local autoMergeBtn = uiRoot:FindById("autoMergeBtn")
    if autoMergeBtn then
        local unlocked = State.IsAutoUnlockedToday("autoMerge")
        if not unlocked then
            autoMergeBtn:SetText("自动合成 ▶")
            autoMergeBtn:SetStyle({ backgroundColor = { 80, 60, 40, 200 }, fontColor = { 255, 200, 100, 255 } })
        elseif State.autoMerge then
            autoMergeBtn:SetText("自动合成:开")
            autoMergeBtn:SetStyle({ backgroundColor = { 100, 60, 200, 255 }, fontColor = { 255, 255, 255, 255 } })
        else
            autoMergeBtn:SetText("自动合成:关")
            autoMergeBtn:SetStyle({ backgroundColor = { 60, 50, 80, 200 }, fontColor = { 180, 160, 220, 255 } })
        end
    end

    -- 自动布阵按钮状态
    local autoDeployBtn = uiRoot:FindById("autoDeployBtn")
    if autoDeployBtn then
        local unlocked = State.IsAutoUnlockedToday("autoDeploy")
        if not unlocked then
            autoDeployBtn:SetText("自动布阵 ▶")
            autoDeployBtn:SetStyle({ backgroundColor = { 80, 60, 40, 200 }, fontColor = { 255, 200, 100, 255 } })
        elseif State.autoDeploy then
            autoDeployBtn:SetText("自动布阵:开")
            autoDeployBtn:SetStyle({ backgroundColor = { 60, 160, 100, 255 }, fontColor = { 255, 255, 255, 255 } })
        else
            autoDeployBtn:SetText("自动布阵:关")
            autoDeployBtn:SetStyle({ backgroundColor = { 60, 50, 80, 200 }, fontColor = { 180, 160, 220, 255 } })
        end
    end

    -- x3 加速按钮状态
    local speedBtn = uiRoot:FindById("speedBoostBtn")
    local speedLabel = uiRoot:FindById("speedBoostLabel")
    if speedBtn then
        if SpeedBoost.enabled and SpeedBoost.remaining > 0 then
            speedBtn:SetStyle({ backgroundColor = { 200, 120, 40, 255 }, borderColor = { 255, 200, 60, 220 } })
            if speedLabel then speedLabel:SetText("x2 " .. SpeedBoost.FormatRemaining()) end
        else
            speedBtn:SetStyle({ backgroundColor = { 60, 50, 80, 200 }, borderColor = { 200, 160, 60, 180 } })
            if speedLabel then speedLabel:SetText("x2") end
        end
    end
end

-- 获取空位（代理函数）
function Tower.GetEmptyCells()
    local Grid = require("Game.Grid")
    return Grid.GetEmptyCells()
end

--- 创建战斗页内容
function GameUI.CreateBattlePage()
    return UI.Panel {
        id = "battlePage",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        pointerEvents = "box-none",
        children = {
            GameUI.CreateHUD(),
            GameUI.CreateCurrencyDisplay(),
            GameUI.CreateHeroInfoPanel(),
            GameUI.CreateBottomBar(),
            GameUI.CreateWaveReadyPanel(),
            GameUI.CreateGameOverPanel(),
            GameUI.CreateStageClearPanel(),
            GameUI.CreateAfkButton(),
            GameUI.CreateIdleRewardPanel(),
            GameUI.CreateMenuPanel(),
            -- x3 加速按钮（独立定位，在自动召唤上方）
            UI.Panel {
                id = "speedBoostBtn",
                position = "absolute",
                right = 12, bottom = 108,
                paddingLeft = 10, paddingRight = 10,
                paddingTop = 5, paddingBottom = 5,
                borderRadius = 6,
                borderWidth = 1,
                borderColor = { 200, 160, 60, 180 },
                backgroundColor = { 60, 50, 80, 200 },
                pointerEvents = "auto",
                alignItems = "center",
                onClick = function(self)
                    GameUI.ShowSpeedBoostDialog(true)
                end,
                children = {
                    UI.Label {
                        id = "speedBoostLabel",
                        text = "x2",
                        fontSize = 11,
                        fontColor = { 200, 160, 80, 255 },
                        fontWeight = "bold",
                    },
                },
            },
        }
    }
end

--- 标签切换回调
local function OnTabSwitch(fromKey, toKey)
    if toKey == "battle" then Tower.RefreshAllStats() end
    if toKey == "hero" then HeroUI.Refresh() end
    if toKey == "equip" then EquipUI.Refresh() end
    if toKey == "chest" then ChestUI.Refresh() end
    if toKey == "dungeon" then DungeonUI.Refresh() end
end

--- 创建游戏 UI（多页架构）
function GameUI.CreateUI()
    ChestData.Load()

    local battlePage = GameUI.CreateBattlePage()
    local heroPage = HeroUI.CreatePage(UI)
    local equipPage = EquipUI.CreatePage(UI)
    local chestPage = ChestUI.CreatePage(UI)
    local dungeonPage = DungeonUI.CreatePage(UI)

    uiRoot = TabNav.Create(UI, {
        hero = heroPage,
        equip = equipPage,
        battle = battlePage,
        dungeon = dungeonPage,
        chest = chestPage,
    }, OnTabSwitch)

    ctx.uiRoot = uiRoot

    GameUI._recruitPage = GameUI.CreateRecruitOverlay()
    uiRoot:AddChild(GameUI._recruitPage)

    GameUI._activityPage = GameUI.CreateActivityOverlay()
    uiRoot:AddChild(GameUI._activityPage)

    GameUI._launchGiftPage = GameUI.CreateLaunchGiftOverlay()
    uiRoot:AddChild(GameUI._launchGiftPage)

    GameUI._dailyTaskPage = GameUI.CreateDailyTaskOverlay()
    uiRoot:AddChild(GameUI._dailyTaskPage)

    GameUI._leaderboardPage = LeaderboardUI.CreateOverlay(UI)
    uiRoot:AddChild(GameUI._leaderboardPage)

    GameUI._speedBoostDialog = GameUI.CreateSpeedBoostDialog()
    uiRoot:AddChild(GameUI._speedBoostDialog)

    UI.SetRoot(uiRoot)
    return uiRoot
end

--- 创建区服选择浮层（由 main.lua 调用）
---@param onStart function  选服后开始游戏回调 function(serverId)
---@param slotMeta table|nil  存档元数据（来自 SlotSaveSystem）
function GameUI.CreateServerSelect(onStart, slotMeta)
    GameUI._serverSelectPage = ServerSelectUI.CreatePage(UI, function(serverId)
        GameUI.ShowServerSelect(false)
        if onStart then onStart(serverId) end
    end, slotMeta)
    uiRoot:AddChild(GameUI._serverSelectPage)
end

--- 显示/隐藏区服选择界面
function GameUI.ShowServerSelect(show)
    if GameUI._serverSelectPage then
        GameUI._serverSelectPage:SetVisible(show)
    end
    -- 区服选择期间隐藏底部标签栏
    TabNav.SetBarVisible(not show)
end

--- 返回区服选择：保存并卸载当前槽位，重置游戏状态，显示区服选择
function GameUI.ReturnToServerSelect()
    local SlotSave = require("Game.SlotSaveSystem")
    local LootDrop = require("Game.LootDrop")
    local Combat   = require("Game.Combat")

    -- 先收集残留掉落物，防止丢失奖励
    LootDrop.CollectAll()

    -- 保存并卸载当前槽位（异步）
    SlotSave.SaveAndUnload(function(success)
        -- 重置游戏状态
        State.Reset()
        Combat.Reset()

        -- 销毁旧的区服选择浮层
        if GameUI._serverSelectPage then
            GameUI._serverSelectPage:SetVisible(false)
            GameUI._serverSelectPage = nil
        end

        -- 重新获取最新元数据并创建区服选择
        local freshMeta = SlotSave.GetMeta()
        GameUI.CreateServerSelect(function(serverId)
            StartGame(serverId)  -- 全局函数，定义在 main.lua
        end, freshMeta)
        GameUI.ShowServerSelect(true)

        -- 切到战斗标签页（确保返回后看到的是战斗页）
        TabNav.SwitchTo("battle")
    end)
end

--- 获取 UI 根节点（供外部模块挂载弹窗）
function GameUI.GetUIRoot()
    return uiRoot
end

--- 创建招募页浮层
function GameUI.CreateRecruitOverlay()
    local recruitContent = RecruitUI.CreatePage(UI)
    local overlay = UI.Panel {
        id = "recruitOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        visible = false,
        children = {
            recruitContent,
            UI.Panel {
                position = "absolute",
                left = 8, bottom = 120,
                pointerEvents = "auto",
                children = {
                    UI.Button {
                        text = "返回",
                        fontSize = 20,
                        width = 90,
                        height = 54,
                        borderRadius = 8,
                        variant = "outline",
                        onClick = function()
                            GameUI.ShowRecruitOverlay(false)
                        end,
                    },
                },
            },
        },
    }
    return overlay
end

function GameUI.ShowRecruitOverlay(show)
    if GameUI._recruitPage then
        GameUI._recruitPage:SetVisible(show)
        if show then RecruitUI.Refresh() end
    end
end

function GameUI.CreateActivityOverlay()
    ActivityUI.SetOnBack(function()
        GameUI.ShowActivityOverlay(false)
    end)

    local activityContent = ActivityUI.CreatePage(UI)
    local overlay = UI.Panel {
        id = "activityOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        visible = false,
        children = { activityContent },
    }
    return overlay
end

function GameUI.ShowActivityOverlay(show)
    if GameUI._activityPage then
        GameUI._activityPage:SetVisible(show)
        if show then ActivityUI.Refresh() end
    end
end

function GameUI.CreateLaunchGiftOverlay()
    local content = LaunchGiftUI.CreatePage(UI)
    local overlay = UI.Panel {
        id = "launchGiftOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        visible = false,
        children = {
            content,
            -- 左下角返回键（与 RecruitOverlay 一致）
            UI.Panel {
                position = "absolute",
                left = 8, bottom = 120,
                pointerEvents = "auto",
                children = {
                    UI.Button {
                        text = "返回",
                        fontSize = 20,
                        width = 90,
                        height = 54,
                        borderRadius = 8,
                        variant = "outline",
                        onClick = function()
                            GameUI.ShowLaunchGiftOverlay(false)
                        end,
                    },
                },
            },
        },
    }
    return overlay
end

function GameUI.ShowLaunchGiftOverlay(show)
    if GameUI._launchGiftPage then
        GameUI._launchGiftPage:SetVisible(show)
        if show then LaunchGiftUI.Refresh() end
    end
    -- 关闭时刷新红点
    if not show and uiRoot then
        local LaunchGiftData = require("Game.LaunchGiftData")
        local redDot = uiRoot:FindById("launchGiftRedDot")
        if redDot then redDot:SetVisible(LaunchGiftData.HasClaimable()) end
    end
end

--- 刷新好礼按钮红点（存档加载后调用）
function GameUI.RefreshLaunchGiftRedDot()
    if not uiRoot then return end
    local LaunchGiftData = require("Game.LaunchGiftData")
    local redDot = uiRoot:FindById("launchGiftRedDot")
    if redDot then redDot:SetVisible(LaunchGiftData.HasClaimable()) end
    -- 同时刷新按钮可见性（活动可能已过期）
    local btn = uiRoot:FindById("launchGiftBtn")
    if btn then btn:SetVisible(LaunchGiftData.IsActive()) end
end

-- ============================================================================
-- 每日任务 Overlay
-- ============================================================================

function GameUI.CreateDailyTaskOverlay()
    local content = DailyTaskUI.CreatePage(UI)
    local overlay = UI.Panel {
        id = "dailyTaskOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        visible = false,
        children = {
            content,
            -- 左下角返回键
            UI.Panel {
                position = "absolute",
                left = 8, bottom = 120,
                pointerEvents = "auto",
                children = {
                    UI.Button {
                        text = "返回",
                        fontSize = 20,
                        width = 90,
                        height = 54,
                        borderRadius = 8,
                        variant = "outline",
                        onClick = function()
                            GameUI.ShowDailyTaskOverlay(false)
                        end,
                    },
                },
            },
        },
    }
    return overlay
end

function GameUI.ShowDailyTaskOverlay(show)
    if GameUI._dailyTaskPage then
        GameUI._dailyTaskPage:SetVisible(show)
        if show then DailyTaskUI.Refresh() end
    end
    -- 关闭时刷新红点
    if not show and uiRoot then
        local DTD = require("Game.DailyTaskData")
        local redDot = uiRoot:FindById("dailyTaskRedDot")
        if redDot then redDot:SetVisible(DTD.HasClaimable()) end
    end
end

--- 刷新每日任务按钮红点（存档加载后调用）
function GameUI.RefreshDailyTaskRedDot()
    if not uiRoot then return end
    local DTD = require("Game.DailyTaskData")
    local redDot = uiRoot:FindById("dailyTaskRedDot")
    if redDot then redDot:SetVisible(DTD.HasClaimable()) end
end

-- ============================================================================
-- 加速弹窗
-- ============================================================================

--- 创建加速弹窗浮层
function GameUI.CreateSpeedBoostDialog()
    local overlay = UI.Panel {
        id = "speedBoostOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = { 0, 0, 0, 160 },
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        pointerEvents = "auto",
        onClick = function(self)
            GameUI.ShowSpeedBoostDialog(false)
        end,
        children = {
            -- 弹窗卡片
            UI.Panel {
                width = 300,
                backgroundColor = { 30, 24, 50, 245 },
                borderRadius = 14,
                borderWidth = 1,
                borderColor = { 200, 150, 60, 180 },
                paddingTop = 16, paddingBottom = 16,
                paddingLeft = 20, paddingRight = 20,
                gap = 14,
                alignItems = "center",
                pointerEvents = "auto",
                onClick = function(self) end,  -- 阻止穿透关闭
                children = {
                    -- 标题
                    UI.Label {
                        text = "⚡ 战斗加速 x2",
                        fontSize = 18,
                        fontColor = { 255, 200, 60, 255 },
                        fontWeight = "bold",
                    },
                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = { 200, 150, 60, 60 } },
                    -- 当前状态
                    UI.Panel {
                        width = "100%",
                        gap = 6,
                        alignItems = "center",
                        children = {
                            UI.Label {
                                id = "sbDialogStatus",
                                text = "当前：未加速",
                                fontSize = 13,
                                fontColor = { 180, 170, 200, 220 },
                            },
                            UI.Label {
                                id = "sbDialogRemaining",
                                text = "",
                                fontSize = 15,
                                fontColor = { 255, 200, 60, 255 },
                                fontWeight = "bold",
                            },
                        },
                    },
                    -- 说明
                    UI.Panel {
                        width = "100%",
                        backgroundColor = { 50, 40, 70, 150 },
                        borderRadius = 8,
                        paddingTop = 8, paddingBottom = 8,
                        paddingLeft = 10, paddingRight = 10,
                        children = {
                            UI.Label {
                                text = "看广告获得加速时间",
                                fontSize = 12,
                                fontColor = { 200, 190, 220, 200 },
                            },
                        },
                    },
                    -- 开关加速按钮
                    UI.Button {
                        id = "sbToggleBtn",
                        text = "关闭加速",
                        fontSize = 13,
                        variant = "outline",
                        width = "100%",
                        height = 34,
                        borderRadius = 8,
                        visible = false,
                        onClick = function(self)
                            SpeedBoost.enabled = not SpeedBoost.enabled
                            GameUI.RefreshSpeedBoostDialog()
                            GameUI.UpdateHUD()
                        end,
                    },
                    -- 看广告按钮
                    UI.Button {
                        id = "sbWatchAdBtn",
                        text = "▶ 看广告加速",
                        fontSize = 14,
                        fontWeight = "bold",
                        variant = "primary",
                        width = "100%",
                        height = 42,
                        borderRadius = 8,
                        onClick = function(self)
                            if not SpeedBoost.CanWatchAd() then
                                Toast.Show("今日次数已用完", { 255, 100, 100 })
                                return
                            end
                            ---@diagnostic disable-next-line: undefined-global
                            if sdk and sdk.ShowRewardVideoAd then
                                ---@diagnostic disable-next-line: undefined-global
                                sdk:ShowRewardVideoAd(function(success)
                                    if success then
                                        local AdTracker = require("Game.AdTracker")
                                        AdTracker.Record()
                                        SpeedBoost.OnAdWatched()
                                        GameUI.RefreshSpeedBoostDialog()
                                        GameUI.UpdateHUD()
                                        Toast.Show("+1小时加速！", { 255, 200, 60 })
                                    else
                                        Toast.Show("广告未完成", { 200, 100, 100 })
                                    end
                                end)
                            else
                                Toast.Show("广告不可用", { 200, 100, 100 })
                            end
                        end,
                    },
                    -- 关闭按钮
                    UI.Button {
                        text = "关闭",
                        fontSize = 13,
                        variant = "outline",
                        width = "100%",
                        height = 34,
                        borderRadius = 8,
                        onClick = function(self)
                            GameUI.ShowSpeedBoostDialog(false)
                        end,
                    },
                },
            },
        },
    }
    return overlay
end

--- 刷新弹窗内容
function GameUI.RefreshSpeedBoostDialog()
    if not uiRoot then return end
    local statusLabel = uiRoot:FindById("sbDialogStatus")
    local remainLabel = uiRoot:FindById("sbDialogRemaining")
    local watchBtn = uiRoot:FindById("sbWatchAdBtn")

    if statusLabel then
        if SpeedBoost.enabled and SpeedBoost.remaining > 0 then
            statusLabel:SetText("当前：x2 加速中")
        else
            statusLabel:SetText("当前：未加速")
        end
    end
    if remainLabel then
        if SpeedBoost.remaining > 0 then
            remainLabel:SetText("剩余时间：" .. SpeedBoost.FormatRemaining())
        else
            remainLabel:SetText("")
        end
    end
    if watchBtn then
        if SpeedBoost.CanWatchAd() then
            watchBtn:SetText("▶ 看广告加速")
            watchBtn:SetStyle({ backgroundColor = { 200, 120, 40, 255 } })
        else
            watchBtn:SetText("今日次数已用完")
            watchBtn:SetStyle({ backgroundColor = { 80, 60, 60, 200 } })
        end
    end
    local toggleBtn = uiRoot:FindById("sbToggleBtn")
    if toggleBtn then
        if SpeedBoost.remaining > 0 then
            toggleBtn:SetVisible(true)
            if SpeedBoost.enabled then
                toggleBtn:SetText("关闭加速")
            else
                toggleBtn:SetText("开启加速")
            end
        else
            toggleBtn:SetVisible(false)
        end
    end
end

--- 显示/隐藏加速弹窗
function GameUI.ShowSpeedBoostDialog(show)
    if GameUI._speedBoostDialog then
        GameUI._speedBoostDialog:SetVisible(show)
        if show then GameUI.RefreshSpeedBoostDialog() end
    end
end

--- 主更新循环
function GameUI.Update(dt)
    local Enemy = require("Game.Enemy")
    local BM = require("Game.BattleManager")
    local isBMActive = BM.IsActive()

    if State.phase == State.PHASE_PLAYING then
        -- 超限判定（BattleManager 模式下根据配置决定是否启用）
        local overloadEnabled = true
        if isBMActive and not BM.config.overloadEnabled then
            overloadEnabled = false
        end

        if overloadEnabled then
            local aliveCount = Enemy.GetAliveCount()
            local maxEnemies = (isBMActive and BM.config.overloadLimit) or Config.MAX_ENEMIES
            if aliveCount > maxEnemies then
                if not State.overloading then
                    State.overloading = true
                    State.overloadTimer = 0
                    print("[GameUI] Overload started! enemies=" .. aliveCount)
                end
                State.overloadTimer = State.overloadTimer + dt
                if State.overloadTimer >= Config.OVERLOAD_COUNTDOWN then
                    State.phase = State.PHASE_GAME_OVER
                    State.overloading = false
                    local AudioManager = require("Game.AudioManager")
                    AudioManager.PlayDefeat()
                    print("[GameUI] Overload timeout! Game over.")
                    if isBMActive then
                        BM.OnLose()
                    else
                        GameUI.DoGameOver()
                    end
                    return
                end
            else
                if State.overloading then
                    print("[GameUI] Overload cleared, enemies=" .. aliveCount)
                end
                State.overloading = false
                State.overloadTimer = 0
            end
        end
    end

    if State.phase == State.PHASE_PLAYING then
        -- BOSS 倒计时
        local bossTimerEnabled = true
        if isBMActive and not BM.config.bossTimerEnabled then
            bossTimerEnabled = false
        end

        if bossTimerEnabled then
            if State.waveType == "boss" and not State.bossActive then
                for _, e in ipairs(State.enemies) do
                    if e.alive and e.isBoss then
                        State.bossActive = true
                        State.bossTimer = Config.BOSS_TIMER_MAX
                        print("[GameUI] BOSS fight started! Timer=" .. Config.BOSS_TIMER_MAX .. "s")
                        break
                    end
                end
            end

            if State.bossActive then
                local bossAlive = false
                for _, e in ipairs(State.enemies) do
                    if e.alive and e.isBoss then
                        bossAlive = true
                        break
                    end
                end

                if not bossAlive then
                    State.bossActive = false
                    State.bossTimer = 0
                    print("[GameUI] BOSS defeated! Timer stopped.")
                else
                    State.bossTimer = State.bossTimer - dt
                    if State.bossTimer <= 0 then
                        State.bossTimer = 0
                        State.bossActive = false
                        State.phase = State.PHASE_GAME_OVER
                        local AudioManager = require("Game.AudioManager")
                        AudioManager.PlayDefeat()
                        print("[GameUI] BOSS timer expired! Game over.")
                        if isBMActive then
                            BM.OnLose()
                        else
                            GameUI.DoGameOver()
                        end
                        return
                    end
                end
            end
        end
    else
        if State.bossActive then
            State.bossActive = false
            State.bossTimer = 0
        end
    end

    -- 自动召唤/合成定时触发
    if State.phase == State.PHASE_PLAYING or State.phase == State.PHASE_WAVE_READY then
        local AUTO_INTERVAL = 0.4  -- 每 0.4 秒触发一次

        -- 跨天自动关闭（昨天解锁的今天失效）
        if State.autoSummon and not State.IsAutoUnlockedToday("autoSummon") then
            State.autoSummon = false
            GameUI.UpdateHUD()
        end
        if State.autoMerge and not State.IsAutoUnlockedToday("autoMerge") then
            State.autoMerge = false
            GameUI.UpdateHUD()
        end
        if State.autoDeploy and not State.IsAutoUnlockedToday("autoDeploy") then
            State.autoDeploy = false
            GameUI.UpdateHUD()
        end

        if State.autoSummon then
            State.autoSummonTimer = State.autoSummonTimer + dt
            if State.autoSummonTimer >= AUTO_INTERVAL then
                State.autoSummonTimer = 0
                local t = Tower.Summon()
                if t then
                    GameUI.UpdateHUD()
                end
            end
        end

        if State.autoMerge then
            State.autoMergeTimer = State.autoMergeTimer + dt
            if State.autoMergeTimer >= AUTO_INTERVAL then
                State.autoMergeTimer = 0
                GameUI.AutoMerge()
            end
        end

        -- 自动布阵（每3秒重排一次，间隔较长因为移动位置比较明显）
        local DEPLOY_INTERVAL = 3.0
        if State.autoDeploy then
            State.autoDeployTimer = State.autoDeployTimer + dt
            if State.autoDeployTimer >= DEPLOY_INTERVAL then
                State.autoDeployTimer = 0
                local Renderer = require("Game.Renderer")
                local moved = Tower.AutoDeploy(Renderer.gridOffsetX, Renderer.gridOffsetY)
                if moved then
                    print("[GameUI] Auto-deploy repositioned towers")
                end
            end
        end
    end

    -- 通关判定
    if State.phase == State.PHASE_STAGE_CLEAR and not State.settleRewards then
        if isBMActive then
            BM.OnWin()
            return
        else
            GameUI.DoStageClear()
        end
    end

    GameUI.UpdateHUD()
    GameUI.UpdateAfkTimer()
    EquipUI.Update(dt)
end

-- ============================================================================
-- 副本战斗入口/出口
-- ============================================================================

--- 保存主线战斗状态（进副本前备份，出来后恢复）
local savedCampaignStage = nil

--- 进入副本战斗：切换到战斗页面，启动 BattleManager
---@param config table BattleManager.Start 所需的配置
function GameUI.EnterDungeonBattle(config)
    local BM = require("Game.BattleManager")

    -- 备份主线当前关卡
    savedCampaignStage = (HeroData.stats.bestStage or 0) + 1
    if savedCampaignStage < 1 then savedCampaignStage = 1 end

    -- 切到战斗页
    TabNav.SwitchTo("battle")

    -- 启动战斗
    BM.Start(config)

    GameUI.UpdateHUD()
    print("[GameUI] Entered dungeon battle: " .. (config.label or config.mode))
end

--- 退出副本战斗：清理 BattleManager，恢复主线并切回副本页
--- 如果有 onExit 回调（资源副本），先触发结算再退出
function GameUI.ExitDungeonBattle()
    local BM = require("Game.BattleManager")

    -- 如果有 onExit 回调，先触发提前结算（回调内部会再次调用本函数完成真正退出）
    if BM.config and BM.config.onExit then
        local onExit = BM.config.onExit
        BM.config.onExit = nil  -- 清除防止递归
        local LootDrop = require("Game.LootDrop")
        LootDrop.CollectAll()
        local result = {
            mode = BM.config.mode,
            wave = State.currentWave,
            totalWaves = BM.config.totalWaves,
            score = State.score,
        }
        onExit(result)
        return
    end

    BM.End()

    -- 恢复主线状态
    local LootDrop = require("Game.LootDrop")
    local Combat = require("Game.Combat")
    LootDrop.CollectAll()
    State.Reset()
    Combat.Reset()

    local restoreStage = savedCampaignStage or ((HeroData.stats.bestStage or 0) + 1)
    if restoreStage < 1 then restoreStage = 1 end
    State.currentStage = restoreStage
    State.phase = State.PHASE_PLAYING
    savedCampaignStage = nil

    -- 放置暗影君主 + 自动开始
    Tower.CreateLeader(5, 4)
    Wave.StartNext()

    -- 设置开局初始暗魂（必须在 Wave.StartNext 之后，因为 StartNext 会加波次奖励）
    HeroData.currencies.dark_soul = Config.INITIAL_DARK_SOUL

    -- 切回副本页
    TabNav.SwitchTo("dungeon")
    DungeonUI.Refresh()

    GameUI.UpdateHUD()
    print("[GameUI] Exited dungeon battle, restored campaign stage " .. restoreStage)
end

return GameUI
