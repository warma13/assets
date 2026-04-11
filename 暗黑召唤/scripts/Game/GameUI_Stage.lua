-- Game/GameUI_Stage.lua
-- 关卡流程：自动合并、波次就绪、游戏结束、通关结算、菜单

return function(GameUI, ctx)

local Config   = require("Game.Config")
local State    = require("Game.State")
local Tower    = require("Game.Tower")
local Wave     = require("Game.Wave")
local Currency = require("Game.Currency")
local HeroData = require("Game.HeroData")
local ChestData = require("Game.ChestData")

local FormatNum = ctx.FormatNum

function GameUI.AutoMerge()
    local merged = false
    -- 从低星开始找第一个可合成的配对
    for star = 1, Config.MAX_STAR - 1 do
        for i = 1, #State.towers do
            local t1 = State.towers[i]
            if t1 and t1.star == star and t1.star < Config.MAX_STAR then
                for j = i + 1, #State.towers do
                    local t2 = State.towers[j]
                    if t2 and t2.typeIndex == t1.typeIndex and t2.star == t1.star then
                        if Tower.CanMerge(t1, t2) then
                            local result = Tower.Merge(t1, t2)
                            if result then
                                merged = true
                                break
                            end
                        end
                    end
                end
            end
            if merged then break end
        end
        if merged then break end
    end
    if not merged then
        print("[UI] No mergeable pair found")
    end
    GameUI.UpdateHUD()
end

--- 波次准备面板
function GameUI.CreateWaveReadyPanel()
    return ctx.UI.Panel {
        id = "waveReadyPanel",
        visible = false,
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        pointerEvents = "box-none",
        children = {
            ctx.UI.Panel {
                padding = 24,
                gap = 12,
                backgroundColor = { 20, 16, 32, 230 },
                borderRadius = 12,
                borderWidth = 1,
                borderColor = { 100, 70, 160, 150 },
                alignItems = "center",
                pointerEvents = "auto",
                children = {
                    ctx.UI.Label {
                        id = "nextWaveLabel",
                        text = "准备下一波",
                        fontSize = 18,
                        fontColor = Config.COLORS.textPrimary,
                    },
                    ctx.UI.Button {
                        text = "开始波次",
                        variant = "primary",
                        fontSize = 16,
                        onClick = function(self)
                            Wave.StartNext()
                            State.phase = State.PHASE_PLAYING
                            GameUI.ShowPanel("waveReadyPanel", false)
                            GameUI.UpdateHUD()
                        end,
                    },
                }
            }
        }
    }
end

--- 失败面板（无奖励）
function GameUI.CreateGameOverPanel()
    return ctx.UI.Panel {
        id = "gameOverPanel",
        visible = false,
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 180 },
        pointerEvents = "auto",
        children = {
            ctx.UI.Panel {
                width = 260,
                paddingTop = 24, paddingBottom = 24,
                paddingLeft = 20, paddingRight = 20,
                gap = 12,
                backgroundColor = { 30, 20, 45, 245 },
                borderRadius = 16,
                borderWidth = 2,
                borderColor = { 200, 50, 50, 200 },
                alignItems = "center",
                children = {
                    ctx.UI.Label {
                        text = "挑战失败",
                        fontSize = 26,
                        fontColor = { 220, 50, 50, 255 },
                    },
                    ctx.UI.Label {
                        id = "failStageLabel",
                        text = "第1关",
                        fontSize = 16,
                        fontColor = Config.COLORS.textSecondary,
                    },
                    ctx.UI.Label {
                        id = "failWaveLabel",
                        text = "进度: 0/20",
                        fontSize = 14,
                        fontColor = Config.COLORS.textSecondary,
                    },
                    -- 提示
                    ctx.UI.Label {
                        text = "通关才有奖励，提升英雄再来!",
                        fontSize = 12,
                        fontColor = { 180, 140, 100, 200 },
                    },
                    -- 分隔线
                    ctx.UI.Panel {
                        width = "90%", height = 1,
                        marginTop = 2, marginBottom = 2,
                        backgroundColor = { 100, 70, 160, 100 },
                    },
                    ctx.UI.Button {
                        text = "重新挑战",
                        variant = "primary",
                        fontSize = 16,
                        onClick = function(self)
                            GameUI.RetryStage()
                        end,
                    },
                }
            }
        }
    }
end

--- 通关结算面板（有奖励）
function GameUI.CreateStageClearPanel()
    return ctx.UI.Panel {
        id = "stageClearPanel",
        visible = false,
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 180 },
        pointerEvents = "auto",
        children = {
            ctx.UI.Panel {
                width = 280,
                paddingTop = 24, paddingBottom = 24,
                paddingLeft = 20, paddingRight = 20,
                gap = 10,
                backgroundColor = { 20, 25, 50, 245 },
                borderRadius = 16,
                borderWidth = 2,
                borderColor = { 255, 200, 50, 200 },
                alignItems = "center",
                children = {
                    ctx.UI.Label {
                        id = "clearTitleLabel",
                        text = "通关!",
                        fontSize = 28,
                        fontColor = Config.COLORS.textGold,
                    },
                    ctx.UI.Label {
                        id = "clearStageLabel",
                        text = "第1关",
                        fontSize = 16,
                        fontColor = Config.COLORS.textPrimary,
                    },
                    -- 分隔线
                    ctx.UI.Panel {
                        width = "90%", height = 1,
                        marginTop = 4, marginBottom = 4,
                        backgroundColor = { 100, 70, 160, 100 },
                    },
                    ctx.UI.Label {
                        text = "通关奖励",
                        fontSize = 16,
                        fontColor = { 180, 160, 220, 255 },
                    },
                    ctx.UI.Label {
                        id = "clearGoldLabel",
                        text = "冥晶: +0",
                        fontSize = 14,
                        fontColor = { 255, 215, 0, 255 },
                    },
                    ctx.UI.Label {
                        id = "clearDiamondLabel",
                        text = "暗影精华: +0",
                        fontSize = 14,
                        fontColor = { 100, 200, 255, 255 },
                    },
                    ctx.UI.Label {
                        id = "clearTokenLabel",
                        text = "虚空契约: +0",
                        fontSize = 14,
                        fontColor = { 200, 180, 100, 255 },
                    },
                    ctx.UI.Label {
                        id = "clearFragLabel",
                        text = "碎片: +0",
                        fontSize = 14,
                        fontColor = { 180, 120, 255, 255 },
                    },
                    -- 分隔线
                    ctx.UI.Panel {
                        width = "90%", height = 1,
                        marginTop = 4, marginBottom = 4,
                        backgroundColor = { 100, 70, 160, 100 },
                    },
                    ctx.UI.Button {
                        text = "下一关",
                        variant = "primary",
                        fontSize = 16,
                        onClick = function(self)
                            GameUI.NextStage()
                        end,
                    },
                }
            }
        }
    }
end

--- 设置按钮 + 弹出面板（手动保存、返回区服选择）
function GameUI.CreateMenuPanel()
    local SlotSave = require("Game.SlotSaveSystem")
    local Toast    = require("Game.Toast")

    local btnSize = 36

    return ctx.UI.Panel {
        id = "menuPanel",
        position = "absolute",
        top = 8, left = 8,
        pointerEvents = "box-none",
        children = {
            -- 设置齿轮按钮
            ctx.UI.Panel {
                width = btnSize, height = btnSize,
                borderRadius = 8,
                backgroundColor = { 30, 24, 50, 200 },
                borderWidth = 1,
                borderColor = { 100, 80, 140, 150 },
                justifyContent = "center",
                alignItems = "center",
                pointerEvents = "auto",
                onClick = function(self)
                    local panel = ctx.uiRoot and ctx.uiRoot:FindById("settingsPopup")
                    if panel then panel:SetVisible(not panel:IsVisible()) end
                end,
                children = {
                    ctx.UI.Label {
                        text = "\u{2699}",   -- ⚙ 齿轮 emoji
                        fontSize = 20,
                        fontColor = { 200, 190, 220, 255 },
                    },
                },
            },
            -- 弹出面板
            ctx.UI.Panel {
                id = "settingsPopup",
                visible = false,
                marginTop = 4,
                width = 150,
                padding = 10,
                gap = 8,
                backgroundColor = { 25, 20, 40, 240 },
                borderRadius = 10,
                borderWidth = 1,
                borderColor = { 100, 80, 160, 180 },
                pointerEvents = "auto",
                children = {
                    ctx.UI.Label {
                        text = "设置",
                        fontSize = 14,
                        fontColor = { 180, 170, 210, 255 },
                        textAlign = "center",
                        width = "100%",
                    },
                    -- 分隔线
                    ctx.UI.Panel {
                        width = "100%", height = 1,
                        backgroundColor = { 100, 70, 160, 80 },
                    },
                    -- 手动保存
                    ctx.UI.Button {
                        id = "manualSaveBtn",
                        text = "手动保存",
                        fontSize = 14,
                        width = "100%",
                        height = 36,
                        borderRadius = 6,
                        variant = "outline",
                        onClick = function(self)
                            if SlotSave.GetActiveSlot() > 0 then
                                SlotSave.SaveNow()
                                Toast.Show("存档已保存")
                            else
                                Toast.Show("当前无活跃存档")
                            end
                            local panel = ctx.uiRoot and ctx.uiRoot:FindById("settingsPopup")
                            if panel then panel:SetVisible(false) end
                        end,
                    },
                    -- 返回区服选择
                    ctx.UI.Button {
                        id = "returnServerBtn",
                        text = "返回区服选择",
                        fontSize = 14,
                        width = "100%",
                        height = 36,
                        borderRadius = 6,
                        variant = "outline",
                        onClick = function(self)
                            local panel = ctx.uiRoot and ctx.uiRoot:FindById("settingsPopup")
                            if panel then panel:SetVisible(false) end
                            GameUI.ReturnToServerSelect()
                        end,
                    },
                },
            },
        },
    }
end

--- 显示/隐藏面板
function GameUI.ShowPanel(panelId, visible)
    if not ctx.uiRoot then return end
    local panel = ctx.uiRoot:FindById(panelId)
    if panel then
        panel:SetVisible(visible)
    end
end

--- 隐藏所有弹出面板
local function HideAllPanels()
    GameUI.ShowPanel("gameOverPanel", false)
    GameUI.ShowPanel("stageClearPanel", false)
    GameUI.ShowPanel("idleRewardPanel", false)
    GameUI.ShowPanel("menuPanel", false)
    GameUI.ShowPanel("waveReadyPanel", false)
end

--- 开始一个关卡（重置局内状态，保留关卡号）
local function StartStage(stageNum)
    local savedStage = stageNum
    require("Game.LootDrop").CollectAll()  -- 结算残留掉落物，防止丢失奖励
    State.Reset()
    require("Game.Combat").Reset()  -- 重置音效节流计时器
    State.currentStage = savedStage
    State.phase = State.PHASE_PLAYING

    -- 自动放置暗影君主到内部网格中心 (col=5, row=4)
    local leaderCol, leaderRow = 5, 4
    local leader = Tower.CreateLeader(leaderCol, leaderRow)
    if leader then
        leader.spawnTime = 0.6  -- 出生动画
    end

    Wave.StartNext()

    -- 设置开局初始暗魂（必须在 Wave.StartNext 之后，因为 StartNext 会加波次奖励）
    HeroData.currencies.dark_soul = Config.INITIAL_DARK_SOUL

    HideAllPanels()
    GameUI.UpdateHUD()
    print("[GameUI] Starting stage " .. savedStage)
end

--- 重新挑战当前关（失败后调用）
function GameUI.RetryStage()
    StartStage(State.currentStage)
end

--- 重新开始游戏（从第1关开始，兼容旧调用）
function GameUI.RestartGame()
    StartStage(1)
end

--- 进入下一关（通关后调用）
function GameUI.NextStage()
    StartStage(State.currentStage + 1)
end

--- 通关结算：计算奖励并显示通关面板
function GameUI.DoStageClear()
    local stageNum = State.currentStage
    local rewards = HeroData.SettleRewards(stageNum, State.score)
    State.settleRewards = rewards

    -- 通关产出宝箱
    ChestData.GrantStageDrop(stageNum)

    -- 开服好礼任务追踪
    local ok, LGD = pcall(require, "Game.LaunchGiftData")
    if ok and LGD then LGD.AddProgress("stage", 1) end
    -- 每日任务追踪（通关 + 战斗）
    local ok2, DTD = pcall(require, "Game.DailyTaskData")
    if ok2 and DTD then
        DTD.AddProgress("stage", 1)
        DTD.AddProgress("battle", 1)
    end

    if ctx.uiRoot then
        local tl = ctx.uiRoot:FindById("clearStageLabel")
        if tl then tl:SetText("第" .. stageNum .. "关") end

        local gl = ctx.uiRoot:FindById("clearGoldLabel")
        if gl then gl:SetText("冥晶: +" .. rewards.nether_crystal) end

        local dl = ctx.uiRoot:FindById("clearDiamondLabel")
        if dl then
            if rewards.shadow_essence > 0 then
                dl:SetText("暗影精华: +" .. rewards.shadow_essence)
                dl:SetVisible(true)
            else
                dl:SetVisible(false)
            end
        end

        local tl2 = ctx.uiRoot:FindById("clearTokenLabel")
        if tl2 then
            if rewards.void_pact and rewards.void_pact > 0 then
                tl2:SetText("虚空契约: +" .. rewards.void_pact)
                tl2:SetVisible(true)
            else
                tl2:SetVisible(false)
            end
        end

        local fl = ctx.uiRoot:FindById("clearFragLabel")
        if fl then
            if rewards.totalFragments > 0 then
                local fragParts = {}
                for heroId, count in pairs(rewards.fragments) do
                    local heroName = heroId
                    for _, td in ipairs(Config.TOWER_TYPES) do
                        if td.id == heroId then heroName = td.name; break end
                    end
                    fragParts[#fragParts + 1] = heroName .. "x" .. count
                end
                fl:SetText("碎片: +" .. rewards.totalFragments .. " (" .. table.concat(fragParts, ", ") .. ")")
                fl:SetVisible(true)
            else
                fl:SetVisible(false)
            end
        end
    end

    -- 不显示通关弹窗，直接进入下一关
    print("[GameUI] Stage " .. stageNum .. " clear! nether_crystal+" .. rewards.nether_crystal .. " shadow_essence+" .. rewards.shadow_essence .. " frags+" .. rewards.totalFragments)
    GameUI.NextStage()
end

--- 自动召唤：用光所有金币填满格子
local function AutoSummonAll()
    local count = 0
    while true do
        local canSummon = Tower.CanSummon()
        if not canSummon then break end
        local t = Tower.Summon()
        if not t then break end
        count = count + 1
    end
    print("[GameUI] Auto-summoned " .. count .. " towers")
    return count
end

--- 自动合成：循环合成直到无法继续（从低星开始）
local function AutoMergeAll()
    local totalMerged = 0
    local merged = true
    while merged do
        merged = false
        for star = 1, Config.MAX_STAR - 1 do
            for i = 1, #State.towers do
                local t1 = State.towers[i]
                if t1 and t1.star == star and t1.star < Config.MAX_STAR then
                    for j = i + 1, #State.towers do
                        local t2 = State.towers[j]
                        if t2 and t2.typeIndex == t1.typeIndex and t2.star == t1.star then
                            if Tower.CanMerge(t1, t2) then
                                local result = Tower.Merge(t1, t2)
                                if result then
                                    totalMerged = totalMerged + 1
                                    merged = true
                                    break
                                end
                            end
                        end
                    end
                end
                if merged then break end
            end
            if merged then break end
        end
    end
    print("[GameUI] Auto-merged " .. totalMerged .. " pairs")
    return totalMerged
end

--- 失败后自动回退到上一关，自动召唤+合成，直接开始
function GameUI.DoGameOver()
    -- 每日任务追踪（战斗失败也计为一次战斗）
    local ok2, DTD = pcall(require, "Game.DailyTaskData")
    if ok2 and DTD then DTD.AddProgress("battle", 1) end

    local failedStage = State.currentStage
    local failedWave = State.currentWave
    -- 回退到上一关（最低第1关）
    local retreatStage = math.max(1, failedStage - 1)

    print("[GameUI] Stage " .. failedStage .. " failed at wave " .. failedWave
        .. ", retreating to stage " .. retreatStage)

    -- 重置局内状态，设定回退关卡
    require("Game.LootDrop").CollectAll()  -- 结算残留掉落物，防止丢失奖励
    State.Reset()
    State.currentStage = retreatStage
    State.phase = State.PHASE_PLAYING

    -- 放置暗影君主 (内部中心 col=5, row=4)
    local leader = Tower.CreateLeader(5, 4)
    if leader then leader.spawnTime = 0.6 end

    -- 自动召唤填满格子
    AutoSummonAll()
    -- 自动合成所有可合成对
    AutoMergeAll()

    -- 开始第一波
    Wave.StartNext()
    HideAllPanels()
    GameUI.UpdateHUD()

    print("[GameUI] Auto-started stage " .. retreatStage .. " with "
        .. #State.towers .. " towers")
end


end
