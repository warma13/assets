-- ============================================================================
-- battle/DropManager.lua - 掉落管理器 (数据驱动)
-- ============================================================================
-- 将 StageManager.OnEnemyKilled 中 ~60 行硬编码掉落判断提取为声明式掉落表
-- 调整掉率/增删掉落物只需修改 DROP_RULES，无需改动战斗逻辑
-- ============================================================================

local Config      = require("Config")
local GameState   = require("GameState")
local Loot        = require("battle.Loot")
local CombatUtils = require("battle.CombatUtils")
local AffixHelper = require("state.AffixHelper")

local DropManager = {}

-- ========================================================================
-- 掉落规则表 (声明式)
-- 每条规则:
--   id        : 掉落物ID (日志/调试用)
--   condition : function(ctx) → boolean  是否执行此掉落
--   execute   : function(ctx)            生成掉落物
-- ctx 结构:
--   { bs, enemy, luck, chapter, stageIdx, mode }
-- ========================================================================

---@alias DropCtx { bs: table, enemy: table, luck: number, chapter: number, stageIdx: number, mode: table|nil }

local DROP_RULES = {
    -- 1) 经验 (特殊模式可跳过)
    {
        id = "exp",
        condition = function(ctx)
            local skip = ctx.mode and ctx.mode.SkipNormalExpDrop and ctx.mode:SkipNormalExpDrop()
            return not skip
        end,
        execute = function(ctx)
            local expAmount = ctx.enemy.expDrop
            -- 词缀: 博学 (经验获取+N%)
            local scholarVal = AffixHelper.GetAffixValue("scholar")
            if scholarVal > 0 then
                expAmount = math.floor(expAmount * (1 + scholarVal))
            end
            Loot.Spawn(ctx.bs.loots, ctx.enemy.x, ctx.enemy.y, "exp", expAmount)
        end,
    },

    -- 2) 金币 (概率来自敌人模板)
    {
        id = "gold",
        condition = function(ctx)
            local chance = ctx.enemy.goldChance or 0.30
            return math.random() < chance
        end,
        execute = function(ctx)
            local baseGold = math.random(
                math.max(1, ctx.enemy.goldMin),
                math.max(1, ctx.enemy.goldMax)
            )
            -- 词缀: 贪婪 (金币掉落+N%)
            local greedVal = AffixHelper.GetAffixValue("greed")
            if greedVal > 0 then
                baseGold = math.floor(baseGold * (1 + greedVal))
            end
            if baseGold >= 1 then
                Loot.Spawn(ctx.bs.loots,
                    ctx.enemy.x + math.random(-15, 15),
                    ctx.enemy.y + math.random(-15, 15),
                    "gold", baseGold)
            end
        end,
    },

    -- 3) 装备 (概率来自模板 + luck加成)
    {
        id = "equip",
        condition = function(ctx)
            local base = ctx.enemy.equipChance or 0.12
            return math.random() < (base + ctx.luck * 0.5)
        end,
        execute = function(ctx)
            local equip = GameState.GenerateEquip(ctx.bs.currentWave, ctx.enemy.isBoss)
            Loot.Spawn(ctx.bs.loots, ctx.enemy.x, ctx.enemy.y,
                "equip", equip, equip.qualityColor,
                { slotId = equip.slot, name = equip.name, setId = equip.setId })
        end,
    },

    -- 4) 魂晶 (仅Boss, 每4章+1)
    {
        id = "soulCrystal",
        condition = function(ctx) return ctx.enemy.isBoss end,
        execute = function(ctx)
            local amount = Config.SOUL_CRYSTAL.dropPerBoss + math.floor((ctx.chapter - 1) / 4)
            Loot.Spawn(ctx.bs.loots,
                ctx.enemy.x + math.random(-10, 10),
                ctx.enemy.y + math.random(-10, 10),
                "soulCrystal", amount, Config.SOUL_CRYSTAL.color)
        end,
    },

    -- 5) 属性重置券 (仅Boss, 万分之一)
    {
        id = "attr_reset_ticket",
        condition = function(ctx)
            return ctx.enemy.isBoss and math.random(1, 10000) == 1
        end,
        execute = function(ctx)
            Loot.Spawn(ctx.bs.loots,
                ctx.enemy.x + math.random(-12, 12),
                ctx.enemy.y + math.random(-12, 12),
                "bagItem", 1, { 255, 200, 80 }, { itemId = "attr_reset" })
        end,
    },

    -- 6) 技能重置券 (仅Boss, 万分之一)
    {
        id = "skill_reset_ticket",
        condition = function(ctx)
            return ctx.enemy.isBoss and math.random(1, 10000) == 1
        end,
        execute = function(ctx)
            Loot.Spawn(ctx.bs.loots,
                ctx.enemy.x + math.random(-12, 12),
                ctx.enemy.y + math.random(-12, 12),
                "bagItem", 1, { 180, 100, 255 }, { itemId = "skill_reset" })
        end,
    },

    -- 7) 散光棱镜 (仅Boss, 按章节缩放 1%~4%)
    {
        id = "prism",
        condition = function(ctx)
            if not ctx.enemy.isBoss then return false end
            -- 章节1→1%, 章节16→4%, 线性插值
            local chance = 0.01 + (ctx.chapter - 1) * (0.03 / 15)
            return math.random() < chance
        end,
        execute = function(ctx)
            Loot.Spawn(ctx.bs.loots,
                ctx.enemy.x + math.random(-12, 12),
                ctx.enemy.y + math.random(-12, 12),
                "bagItem", 1, { 200, 180, 255 }, { itemId = "prism" })
        end,
    },

    -- 8) 魔法石 (仅Boss, S10=1%, S5≈0.7%)
    {
        id = "magic_stone",
        condition = function(ctx)
            if not ctx.enemy.isBoss then return false end
            local dropN = (ctx.stageIdx == 10) and Config.MAGIC_STONE_DROP.s10 or Config.MAGIC_STONE_DROP.s5
            return math.random(1, dropN) == 1
        end,
        execute = function(ctx)
            local stoneId = "magic_stone:" .. ctx.chapter
            local stoneCfg = Config.ITEM_MAP[stoneId]
            if stoneCfg then
                Loot.Spawn(ctx.bs.loots,
                    ctx.enemy.x + math.random(-12, 12),
                    ctx.enemy.y + math.random(-12, 12),
                    "bagItem", 1, stoneCfg.color, { itemId = stoneId })
            end
        end,
    },
}

-- ========================================================================
-- 公共 API
-- ========================================================================

--- 处理击杀后的所有掉落 (替代 StageManager.OnEnemyKilled 中的掉落部分)
---@param bs table BattleSystem 引用
---@param enemy table 被击杀的敌人
---@param mode table|nil GameMode 适配器
function DropManager.ProcessDrops(bs, enemy, mode)
    local ctx = {
        bs       = bs,
        enemy    = enemy,
        luck     = GameState.GetLuck(),
        chapter  = GameState.stage and GameState.stage.chapter or 1,
        stageIdx = GameState.stage and GameState.stage.stage or 1,
        mode     = mode,
    }

    for _, rule in ipairs(DROP_RULES) do
        if rule.condition(ctx) then
            rule.execute(ctx)
        end
    end
end

--- 注册自定义掉落规则 (供 GameMode 或扩展使用)
---@param rule table { id, condition, execute }
function DropManager.AddRule(rule)
    DROP_RULES[#DROP_RULES + 1] = rule
end

--- 移除指定ID的掉落规则
---@param ruleId string
function DropManager.RemoveRule(ruleId)
    for i = #DROP_RULES, 1, -1 do
        if DROP_RULES[i].id == ruleId then
            table.remove(DROP_RULES, i)
            return true
        end
    end
    return false
end

return DropManager
