-- Game/Config_Core.lua
-- 游戏基础设置、网格、塔类型、星级倍率

local function apply(Config)

-- ============================================================================
-- 游戏基础设置
-- ============================================================================
Config.TITLE = "Dark Merge TD"
Config.INITIAL_DARK_SOUL = 50      -- 开局初始暗魂（默认值，可被 BattleManager 配置覆盖）
Config.SUMMON_BASE_COST = 50       -- 召唤初始消耗（暗魂）
Config.SUMMON_COST_INCREMENT = 10  -- 每次召唤后消耗增加（球球英雄机制）
Config.WAVE_DARK_SOUL_BONUS = 30   -- 每波奖励暗魂
Config.MAX_STAR = 5
Config.MAX_ENEMIES = 7            -- 场上怪物上限阈值
Config.OVERLOAD_COUNTDOWN = 10    -- 超限后倒计时秒数，归零则输
Config.WAVE_INTERVAL = 30         -- 每波间隔(秒)，自动出下一波

-- ============================================================================
-- 网格设置
-- 布局: 8x7 总网格，外圈为路径，内部 6x5 为塔放置区
-- ============================================================================
Config.GRID_COLS = 8
Config.GRID_ROWS = 7
Config.CELL_SIZE = 42        -- 每格像素大小（缩小以适配更大网格）
Config.GRID_PADDING = 12     -- 网格边距

-- ============================================================================
-- 塔类型定义（全部 21 个英雄，按品质排列）
-- ============================================================================
Config.TOWER_TYPES = {
    -- ========== N 级 (3个) ==========
    {
        id = "skeleton_grunt",
        name = "骷髅小兵",
        rarity = "N",
        color = { 180, 170, 140 },
        glowColor = { 0.7, 0.65, 0.55 },
        attackType = "single",
        baseRange = 100,
        baseSpeed = 0.8,
        special = "none",
        faction = "undead",
        icon = "grunt",
    },
    {
        id = "bat_minion",
        name = "蝙蝠仆从",
        rarity = "N",
        color = { 140, 120, 160 },
        glowColor = { 0.55, 0.47, 0.63 },
        attackType = "single",
        baseRange = 120,
        baseSpeed = 0.4,
        special = "fast_attack",
        faction = "demon",
        icon = "bat_m",
    },
    {
        id = "hell_hound",
        name = "地狱犬",
        rarity = "N",
        color = { 200, 100, 50 },
        glowColor = { 0.8, 0.4, 0.2 },
        attackType = "aoe",
        baseRange = 70,
        baseSpeed = 1.2,
        special = "dot",
        dotDamage = 2,
        dotDuration = 1.5,
        faction = "demon",
        icon = "hound",
    },
    -- ========== R 级 (4个) ==========
    {
        id = "skeleton_archer",
        name = "骷髅弓手",
        rarity = "R",
        color = { 80, 200, 80 },
        glowColor = { 0.3, 0.8, 0.3 },
        attackType = "single",
        baseRange = 140,
        baseSpeed = 0.5,
        special = "fast_attack",
        faction = "undead",
        icon = "archer",
    },
    {
        id = "demon_warrior",
        name = "恶魔战士",
        rarity = "R",
        color = { 220, 60, 60 },
        glowColor = { 0.9, 0.2, 0.2 },
        attackType = "aoe",
        baseRange = 80,
        baseSpeed = 1.2,
        special = "aoe_damage",
        faction = "demon",
        icon = "demon",
    },
    {
        id = "ghost_assassin",
        name = "幽魂刺客",
        rarity = "R",
        color = { 100, 180, 200 },
        glowColor = { 0.4, 0.7, 0.8 },
        attackType = "single",
        baseRange = 90,
        baseSpeed = 0.7,
        special = "amp_damage",
        ampRate = 0.08,
        ampDuration = 3.0,
        faction = "undead",
        icon = "assassin",
    },
    {
        id = "stone_golem",
        name = "石像兵",
        rarity = "R",
        color = { 160, 150, 130 },
        glowColor = { 0.6, 0.55, 0.5 },
        attackType = "single",
        baseRange = 80,
        baseSpeed = 1.5,
        special = "slow",
        slowRate = 0.20,
        faction = "elemental",
        icon = "golem",
    },
    -- ========== SR 级 (5个) ==========
    {
        id = "necromancer",
        name = "死灵术士",
        rarity = "SR",
        color = { 60, 200, 200 },
        glowColor = { 0.2, 0.8, 0.8 },
        attackType = "single",
        baseRange = 110,
        baseSpeed = 1.0,
        special = "slow",
        slowRate = 0.30,
        faction = "undead",
        icon = "necro",
    },
    {
        id = "inferno_flame",
        name = "炼狱火焰",
        rarity = "SR",
        color = { 240, 150, 30 },
        glowColor = { 1.0, 0.6, 0.1 },
        attackType = "aoe",
        baseRange = 90,
        baseSpeed = 0.8,
        special = "dot",
        dotDamage = 5,
        dotDuration = 2.0,
        faction = "elemental",
        icon = "flame",
    },
    {
        id = "armor_breaker",
        name = "破甲骑士",
        rarity = "SR",
        color = { 200, 180, 100 },
        glowColor = { 0.8, 0.7, 0.4 },
        attackType = "single",
        baseRange = 90,
        baseSpeed = 1.1,
        special = "armor_break",
        armorBreak = 0.08,
        armorBreakDuration = 5.0,
        faction = "human",
        icon = "knight",
    },
    {
        id = "frost_witch",
        name = "冰霜女巫",
        rarity = "SR",
        color = { 120, 180, 255 },
        glowColor = { 0.47, 0.7, 1.0 },
        attackType = "chain",
        baseRange = 120,
        baseSpeed = 1.0,
        special = "slow",
        slowRate = 0.25,
        chainCount = 3,
        chainDecay = 0.7,
        faction = "elemental",
        icon = "witch",
    },
    {
        id = "war_drummer",
        name = "战鼓祭司",
        rarity = "SR",
        color = { 220, 180, 80 },
        glowColor = { 0.85, 0.7, 0.3 },
        attackType = "single",
        baseRange = 100,
        baseSpeed = 1.2,
        special = "support",
        auraRange = 80,
        atkBuff = 0.10,
        faction = "human",
        icon = "drummer",
    },
    -- ========== SSR 级 (4个) ==========
    {
        id = "shadow_mage",
        name = "暗影法师",
        rarity = "SSR",
        color = { 160, 80, 220 },
        glowColor = { 0.6, 0.3, 0.9 },
        attackType = "single",
        baseRange = 120,
        baseSpeed = 1.0,
        special = "high_damage",
        faction = "undead",
        icon = "mage",
    },
    {
        id = "abyss_hunter",
        name = "深渊猎手",
        rarity = "SSR",
        color = { 180, 50, 90 },
        glowColor = { 0.7, 0.2, 0.35 },
        attackType = "single",
        baseRange = 130,
        baseSpeed = 0.9,
        special = "boss_killer",
        bossExtraDmg = 0.30,
        faction = "demon",
        icon = "hunter",
    },
    {
        id = "plague_doctor",
        name = "瘟疫博士",
        rarity = "SSR",
        color = { 100, 180, 60 },
        glowColor = { 0.4, 0.7, 0.25 },
        attackType = "aoe",
        baseRange = 100,
        baseSpeed = 1.0,
        special = "dot",
        dotDamage = 12,
        dotDuration = 4.0,
        faction = "human",
        icon = "plague",
    },
    {
        id = "storm_lord",
        name = "暴风领主",
        rarity = "SSR",
        color = { 80, 140, 255 },
        glowColor = { 0.3, 0.55, 1.0 },
        attackType = "aoe",
        baseRange = 110,
        baseSpeed = 1.3,
        special = "aoe_control",
        slowRate = 0.35,
        stunChance = 0.08,
        stunDuration = 1.0,
        faction = "elemental",
        icon = "storm",
    },
    -- ========== UR 级 (2个) ==========
    {
        id = "fallen_archangel",
        name = "堕天使长",
        rarity = "UR",
        color = { 255, 215, 60 },
        glowColor = { 1.0, 0.85, 0.25 },
        attackType = "aoe",
        baseRange = 130,
        baseSpeed = 1.0,
        special = "amp_damage",
        ampRate = 0.15,
        ampDuration = 5.0,
        faction = "human",
        icon = "archangel",
    },
    {
        id = "void_dragon",
        name = "虚空龙王",
        rarity = "UR",
        color = { 255, 200, 50 },
        glowColor = { 1.0, 0.8, 0.2 },
        attackType = "chain",
        baseRange = 120,
        baseSpeed = 0.8,
        special = "boss_killer",
        bossExtraDmg = 0.25,
        chainCount = 4,
        chainDecay = 0.8,
        faction = "demon",
        icon = "dragon",
    },
    -- ========== LR 级 (2个) ==========
    {
        id = "fate_weaver",
        name = "命运织者",
        rarity = "LR",
        color = { 220, 40, 40 },
        glowColor = { 0.9, 0.15, 0.15 },
        attackType = "aoe",
        baseRange = 140,
        baseSpeed = 1.0,
        special = "support",
        auraRange = 999,
        atkBuff = 0.12,
        spdBuff = 0.10,
        faction = "elemental",
        icon = "weaver",
    },
    {
        id = "eternal_archfiend",
        name = "永恒魔君",
        rarity = "LR",
        color = { 200, 20, 20 },
        glowColor = { 0.85, 0.1, 0.1 },
        attackType = "single",
        baseRange = 120,
        baseSpeed = 0.7,
        special = "high_damage",
        faction = "demon",
        icon = "archfiend",
    },
}

-- 星级倍率（平滑指数增长: 每级约 ×2.0~2.25）
Config.STAR_MULTIPLIER = {
    [1] = 1.0,     -- 基础
    [2] = 2.0,     -- ×2.0
    [3] = 4.5,     -- ×2.25
    [4] = 10.0,    -- ×2.22
    [5] = 22.0,    -- ×2.20
}

-- 星级合成所需数量: 拖拽合成，固定2个
Config.STAR_MERGE_COST = {
    [1] = 2,   -- 2个★1 → ★2
    [2] = 2,   -- 2个★2 → ★3
    [3] = 2,   -- 2个★3 → ★4
    [4] = 2,   -- 2个★4 → ★5
}

-- 星级射程加成
Config.STAR_RANGE_BONUS = {
    [1] = 0,
    [2] = 10,
    [3] = 20,
    [4] = 35,
    [5] = 50,
}

-- 星级攻速倍率（除以该值加速）
Config.STAR_SPEED_MULT = {
    [1] = 1.0,
    [2] = 1.15,
    [3] = 1.30,
    [4] = 1.50,
    [5] = 1.75,
}

end

return apply
