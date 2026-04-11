-- Game/State.lua
-- 暗黑塔防游戏 - 全局状态管理

local Config = require("Game.Config")

local State = {}

-- 游戏阶段
State.PHASE_MENU = "menu"
State.PHASE_PLAYING = "playing"
State.PHASE_WAVE_READY = "wave_ready"
State.PHASE_GAME_OVER = "game_over"      -- 失败（无奖励）
State.PHASE_STAGE_CLEAR = "stage_clear"   -- 通关（有奖励）

function State.Reset()
    State.phase = State.PHASE_MENU
    State.score = 0
    State.currentStage = 1       -- 当前关卡号（局外持久化）
    State.currentWave = 0        -- 关内波次号 (1~20)
    State.time = 0
    State.waveType = "normal"    -- "normal" / "elite" / "boss"

    -- 网格: grid[col][row] = tower 或 nil
    State.grid = {}
    for c = 1, Config.GRID_COLS do
        State.grid[c] = {}
    end

    -- 塔列表
    State.towers = {}
    -- 敌人列表
    State.enemies = {}
    -- 子弹/弹道列表
    State.projectiles = {}
    -- 粒子特效列表
    State.particles = {}
    -- 飘字列表（伤害数字等）
    State.floatingTexts = {}
    -- 掉落物列表
    State.lootDrops = {}

    -- 波次状态
    State.waveSpawnQueue = {}
    State.waveSpawnTimer = 0
    State.waveActive = false

    -- 选中的塔（用于合成）
    State.selectedTower = nil

    -- 拖拽状态
    State.dragging = false       -- 是否正在拖拽
    State.dragTower = nil        -- 被拖拽的塔
    State.dragOriginCol = 0      -- 拖拽起始列
    State.dragOriginRow = 0      -- 拖拽起始行
    State.dragX = 0              -- 当前拖拽位置 X（屏幕坐标）
    State.dragY = 0              -- 当前拖拽位置 Y（屏幕坐标）
    State.dragTargetCol = 0      -- 鼠标指向的目标列
    State.dragTargetRow = 0      -- 鼠标指向的目标行
    State.dragValid = false      -- 目标位置是否有效

    -- 超限倒计时（怪物超过上限后10秒未清理则输）
    State.overloadTimer = 0     -- 0=未超限, >0=正在倒计时
    State.overloading = false   -- 是否处于超限状态

    -- BOSS 战斗倒计时
    State.bossTimer = 0         -- >0 表示 BOSS 战斗中，倒计时剩余秒数
    State.bossActive = false    -- 是否正在 BOSS 战斗

    -- 波次定时器（30秒自动出下一波）
    State.waveTimer = 0

    -- 召唤次数（用于递增消耗，每局重置）
    State.summonCount = 0

    -- 自动召唤/合成/布阵（仅重置计时器，开关保留用户选择）
    State.autoSummonTimer = 0
    State.autoMergeTimer = 0
    State.autoDeployTimer = 0

    -- UI 状态
    State.summonFlash = 0       -- 召唤闪光计时
    State.mergeFlash = 0        -- 合成闪光计时
    State.mergeFlashPos = nil   -- 合成闪光位置
    State.skillFlash = nil      -- 技能释放闪光 { timer, r, g, b }

    -- 结算状态
    State.settleRewards = nil   -- 结算奖励数据（非nil时显示结算面板）

    print("[State] Game state reset")
end

-- 标签页状态（不在 Reset 中重置，保持用户当前页签）
State.activeTab = "battle"   -- "hero" / "battle" / "recruit" / "activity"

-- 自动召唤/合成/布阵开关（不在 Reset 中重置，保持用户选择）
State.autoSummon = false
State.autoMerge = false
State.autoDeploy = false

--- 检查今日是否已通过广告解锁自动功能
---@param key string "autoSummon" | "autoMerge" | "autoDeploy"
---@return boolean
function State.IsAutoUnlockedToday(key)
    local HeroData = require("Game.HeroData")
    local dateKey = key .. "AdDate"
    local today = os.date("%Y-%m-%d")
    return HeroData.stats[dateKey] == today
end

--- 记录今日已通过广告解锁
---@param key string "autoSummon" | "autoMerge" | "autoDeploy"
function State.RecordAutoAdUnlock(key)
    local HeroData = require("Game.HeroData")
    local dateKey = key .. "AdDate"
    HeroData.stats[dateKey] = os.date("%Y-%m-%d")
    HeroData.Save()
end

-- 初始化
State.Reset()

return State
