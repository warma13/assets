-- ============================================================================
-- StageConfig.lua - 章节关卡配置 (第一章: 灰烬荒原)
-- 数值基准: 1级玩家 DPS≈18, 大量低血怪割草体验
-- ============================================================================

local StageConfig = {}

--- 延迟获取 GameState (避免循环依赖, Boss回调运行时才调用)
---@return table GameState
local function GS()
    return require("GameState")
end

--- 延迟获取 MonsterFamilies / BossArchetypes (避免循环依赖)
---@return table MonsterFamilies
local function MF()
    return require("MonsterFamilies")
end
---@return table BossArchetypes
local function BA()
    return require("BossArchetypes")
end

-- ============================================================================
-- 怪物模板
-- 血量说明 (1级玩家 DPS≈18):
--   ash_rat   35HP → ~2s击杀, 群体填充怪(蜂群)
--   void_bat  20HP → ~1s击杀, 高速脆皮(大量涌入)
--   spore_shroom 60HP → ~3s, 静止型减速怪
--   swamp_frog   50HP → ~3s, 中速中血
--   rot_worm  80HP → ~4s, 慢速肉盾
--   bandit    70HP → ~4s, 中速高攻精英
--   water_spirit 30HP → ~2s, 水元素填充
--   tide_crab 100HP → ~6s, 水系肉盾
--   中BOSS  800HP → ~45s, 需要技能配合
--   终BOSS 2500HP → ~2min, 后期玩家更强实际更快
-- ============================================================================

StageConfig.MONSTERS = {
    ash_rat = {
        name = "灰烬鼠", hp = 35, atk = 3, speed = 55, def = 0,
        atkInterval = 1.2, element = "fire",
        expDrop = 8, dropTemplate = "common",
        image = "Textures/mobs/ash_rat.png", radius = 14,
        color = { 140, 120, 100 },
    },
    rot_worm = {
        name = "腐土蠕虫", hp = 80, atk = 5, speed = 20, def = 1,
        atkInterval = 1.5, element = "poison", antiHeal = true,
        expDrop = 15, dropTemplate = "common",
        image = "Textures/mobs/rot_worm.png", radius = 16,
        color = { 120, 80, 160 },
    },
    void_bat = {
        name = "虚隙蝠", hp = 20, atk = 4, speed = 70, def = 0,
        atkInterval = 0.8, element = "arcane",
        expDrop = 6, dropTemplate = "common",
        image = "Textures/mobs/void_bat.png", radius = 12,
        color = { 80, 50, 120 },
    },
    bandit = {
        name = "荒原劫匪", hp = 70, atk = 8, speed = 40, def = 2,
        atkInterval = 1.0, element = "physical",
        expDrop = 18, dropTemplate = "common",
        image = "Textures/mobs/bandit.png", radius = 16,
        color = { 180, 140, 100 },
    },
    spore_shroom = {
        name = "孢子菇", hp = 60, atk = 5, speed = 25, def = 1,
        atkInterval = 1.0, element = "poison", antiHeal = true,
        slowOnHit = 0.3, slowDuration = 2.0,
        expDrop = 12, dropTemplate = "common",
        image = "Textures/mobs/spore_shroom.png", radius = 14,
        color = { 100, 180, 80 },
    },
    swamp_frog = {
        name = "沼泽蛙", hp = 50, atk = 6, speed = 45, def = 1,
        atkInterval = 1.0, element = "ice",
        slowOnHit = 0.2, slowDuration = 1.5,
        expDrop = 12, dropTemplate = "common",
        image = "Textures/mobs/swamp_frog.png", radius = 15,
        color = { 60, 140, 80 },
    },
    -- 水元素怪物
    water_spirit = {
        name = "水灵", hp = 30, atk = 4, speed = 50, def = 1,
        atkInterval = 1.0, element = "water",
        expDrop = 8, dropTemplate = "common",
        image = "Textures/mobs/water_spirit.png", radius = 13,
        color = { 40, 100, 220 },
    },
    tide_crab = {
        name = "潮汐蟹", hp = 100, atk = 7, speed = 30, def = 3,
        atkInterval = 1.3, element = "water",
        slowOnHit = 0.25, slowDuration = 2.0,
        expDrop = 18, dropTemplate = "common",
        image = "Textures/mobs/tide_crab.png", radius = 17,
        color = { 30, 80, 180 },
    },
    -- ==================== 第二章: 冰封深渊 ====================
    frost_imp = {
        name = "霜魔小鬼", hp = 45, atk = 10, speed = 55, def = 1,
        atkInterval = 1.2, element = "ice",
        slowOnHit = 0.25, slowDuration = 1.5,
        expDrop = 12, dropTemplate = "common",
        image = "Textures/mobs/frost_imp.png", radius = 14,
        color = { 150, 200, 255 },
    },
    ice_wraith = {
        name = "寒魂幽灵", hp = 25, atk = 14, speed = 75, def = 0,
        atkInterval = 0.8, element = "ice",
        defPierce = 0.30, -- 无视30%DEF
        expDrop = 10, dropTemplate = "common",
        image = "Textures/mobs/ice_wraith.png", radius = 13,
        color = { 180, 220, 255 },
    },
    glacier_beetle = {
        name = "冰川甲虫", hp = 120, atk = 6, speed = 20, def = 8,
        atkInterval = 1.5, element = "ice", antiHeal = true,
        expDrop = 20, dropTemplate = "common",
        image = "Textures/mobs/glacier_beetle.png", radius = 17,
        color = { 100, 160, 200 },
    },
    snow_wolf = {
        name = "雪原狼", hp = 55, atk = 12, speed = 65, def = 2,
        atkInterval = 1.0, element = "physical",
        packBonus = 0.30, packThreshold = 3, -- >=3只同屏ATK+30%
        expDrop = 14, dropTemplate = "common",
        image = "Textures/mobs/snow_wolf.png", radius = 15,
        color = { 220, 230, 245 },
    },
    cryo_mage = {
        name = "冰霜术士", hp = 70, atk = 15, speed = 30, def = 3,
        atkInterval = 1.0, element = "ice",
        slowOnHit = 0.4, slowDuration = 2.5,
        isRanged = true,
        expDrop = 18, dropTemplate = "common",
        image = "Textures/mobs/cryo_mage.png", radius = 15,
        color = { 80, 130, 220 },
    },
    frozen_revenant = {
        name = "冰封亡灵", hp = 90, atk = 11, speed = 35, def = 4,
        atkInterval = 1.2, element = "ice", antiHeal = true,
        deathExplode = { element = "ice", dmgMul = 0.8, radius = 40 },
        expDrop = 16, dropTemplate = "common",
        image = "Textures/mobs/frozen_revenant.png", radius = 16,
        color = { 120, 150, 200 },
    },
    abyssal_jellyfish = {
        name = "深渊水母", hp = 40, atk = 8, speed = 40, def = 1,
        atkInterval = 1.0, element = "water",
        expDrop = 10, dropTemplate = "common",
        image = "Textures/mobs/abyssal_jellyfish.png", radius = 14,
        color = { 60, 80, 200 },
    },
    permafrost_golem = {
        name = "永冻傀儡", hp = 160, atk = 9, speed = 15, def = 11,
        atkInterval = 1.8, element = "ice", antiHeal = true,
        hpRegen = 0.03, -- 每5s回复3%HP
        hpRegenInterval = 5.0,
        expDrop = 25, dropTemplate = "common",
        image = "Textures/mobs/permafrost_golem.png", radius = 18,
        color = { 140, 180, 210 },
    },
    -- 第二章 BOSS
    boss_ice_witch = {
        name = "冰晶女巫", hp = 2240, atk = 20, speed = 25, def = 12,
        atkInterval = 1.5, element = "ice", antiHeal = true,
        slowOnHit = 0.5, slowDuration = 3.0,
        -- 冰棱弹幕: 每8s向周围发射冰棱
        barrage = { interval = 8.0, count = 6, dmgMul = 0.5, element = "ice" },
        -- 冰甲: HP<50%时受伤减半3s, CD15s
        iceArmor = { hpThreshold = 0.5, dmgReduce = 0.5, duration = 3.0, cd = 15.0 },
        expDrop = 600, dropTemplate = "miniboss",
        image = "Textures/mobs/boss_ice_witch.png", radius = 28,
        color = { 100, 160, 240 }, isBoss = true,
    },
    boss_frost_dragon = {
        name = "深渊冰龙·寒渊", hp = 5120, atk = 28, speed = 18, def = 18,
        atkInterval = 2.0, element = "ice", antiHeal = true,
        slowOnHit = 0.4, slowDuration = 2.5,
        -- 龙息: 每10s锥形冰息
        dragonBreath = { interval = 10.0, dmgMul = 2.0, element = "ice" },
        -- 冰封领域: HP<60%时减速区域
        frozenField = { hpThreshold = 0.6, slowRate = 0.6, duration = 8.0, cd = 20.0 },
        -- 冰晶再生: HP<30%时每秒回复0.5%HP
        iceRegen = { hpThreshold = 0.3, regenPct = 0.005 },
        expDrop = 1500, dropTemplate = "boss",
        image = "Textures/mobs/boss_frost_dragon.png", radius = 35,
        color = { 80, 140, 230 }, isBoss = true,
    },
    -- 第一章 BOSS
    boss_corrupt_guard = {
        name = "腐化巡逻兵", hp = 640, atk = 12, speed = 30, def = 8,
        atkInterval = 1.5, element = "physical", antiHeal = true,
        expDrop = 300, dropTemplate = "miniboss",
        image = "Textures/mobs/boss_corrupt_guard.png", radius = 28,
        color = { 160, 100, 60 }, isBoss = true,
    },
    boss_golem = {
        name = "荒原巨像", hp = 1600, atk = 18, speed = 20, def = 15,
        atkInterval = 2.0, element = "arcane", antiHeal = true,
        slowOnHit = 0.4, slowDuration = 3.0,
        expDrop = 800, dropTemplate = "boss",
        image = "Textures/mobs/boss_golem.png", radius = 32,
        color = { 130, 100, 160 }, isBoss = true,
    },
    -- ==================== 第三章: 熔岩炼狱 ====================
    lava_lizard = {
        name = "熔岩蜥蜴", hp = 60, atk = 16, speed = 55, def = 3,
        atkInterval = 1.2, element = "fire",
        expDrop = 18, dropTemplate = "common",
        image = "Textures/mobs/lava_lizard.png", radius = 14,
        color = { 220, 100, 40 },
    },
    volcano_moth = {
        name = "火山飞蛾", hp = 30, atk = 20, speed = 80, def = 0,
        atkInterval = 0.8, element = "fire",
        defPierce = 0.25,
        expDrop = 14, dropTemplate = "common",
        image = "Textures/mobs/volcano_moth.png", radius = 12,
        color = { 255, 150, 50 },
    },
    toxiflame_shroom = {
        name = "毒焰蘑菇", hp = 80, atk = 12, speed = 0, def = 4,
        atkInterval = 1.0, element = "poison", antiHeal = true,
        slowOnHit = 0.35, slowDuration = 2.0,
        expDrop = 16, dropTemplate = "common",
        image = "Textures/mobs/toxiflame_shroom.png", radius = 14,
        color = { 140, 200, 60 },
    },
    rock_scorpion = {
        name = "岩甲巨蝎", hp = 180, atk = 14, speed = 20, def = 12,
        atkInterval = 1.5, element = "physical",
        hpRegen = 0.02, hpRegenInterval = 6.0,
        expDrop = 28, dropTemplate = "common",
        image = "Textures/mobs/rock_scorpion.png", radius = 18,
        color = { 120, 100, 80 },
    },
    molten_sprite = {
        name = "熔核精灵", hp = 45, atk = 22, speed = 60, def = 1,
        atkInterval = 1.0, element = "fire",
        deathExplode = { element = "fire", dmgMul = 1.0, radius = 50 },
        expDrop = 16, dropTemplate = "common",
        image = "Textures/mobs/molten_sprite.png", radius = 13,
        color = { 255, 200, 50 },
    },
    miasma_weaver = {
        name = "瘴气编织者", hp = 90, atk = 18, speed = 35, def = 4,
        atkInterval = 1.0, element = "poison",
        isRanged = true,
        slowOnHit = 0.30, slowDuration = 2.0,
        expDrop = 22, dropTemplate = "common",
        image = "Textures/mobs/miasma_weaver.png", radius = 15,
        color = { 130, 80, 180 },
    },
    lava_hound = {
        name = "熔岩猎犬", hp = 70, atk = 20, speed = 70, def = 4,
        atkInterval = 1.0, element = "fire",
        packBonus = 0.35, packThreshold = 3,
        expDrop = 20, dropTemplate = "common",
        image = "Textures/mobs/lava_hound.png", radius = 15,
        color = { 200, 80, 30 },
    },
    obsidian_guard = {
        name = "黑曜石守卫", hp = 220, atk = 10, speed = 15, def = 16,
        atkInterval = 1.8, element = "physical", antiHeal = true,
        deathExplode = { element = "fire", dmgMul = 0.6, radius = 35 },
        expDrop = 30, dropTemplate = "common",
        image = "Textures/mobs/obsidian_guard.png", radius = 19,
        color = { 50, 40, 50 },
    },
    -- 第三章 BOSS
    boss_lava_lord = {
        name = "熔岩领主·烬牙", hp = 7680, atk = 35, speed = 25, def = 20,
        atkInterval = 1.5, element = "fire", antiHeal = true,
        slowOnHit = 0.3, slowDuration = 2.0,
        barrage = { interval = 7.0, count = 8, dmgMul = 0.6, element = "fire" },
        iceArmor = { hpThreshold = 0.5, dmgReduce = 0.6, duration = 4.0, cd = 12.0 },
        expDrop = 2000, dropTemplate = "miniboss",
        image = "Textures/mobs/boss_lava_lord.png", radius = 30,
        color = { 255, 120, 30 }, isBoss = true,
    },
    boss_inferno_king = {
        name = "炼狱之王·焚渊", hp = 14080, atk = 45, speed = 20, def = 25,
        atkInterval = 2.0, element = "fire", antiHeal = true,
        slowOnHit = 0.4, slowDuration = 2.5,
        dragonBreath = { interval = 9.0, dmgMul = 2.5, element = "fire" },
        frozenField = { hpThreshold = 0.6, slowRate = 0.5, duration = 6.0, cd = 18.0 },
        iceRegen = { hpThreshold = 0.3, regenPct = 0.008 },
        expDrop = 4000, dropTemplate = "boss",
        image = "Textures/mobs/boss_inferno_king.png", radius = 36,
        color = { 200, 50, 20 }, isBoss = true,
    },
    -- ==================== 第四章: 幽暗墓域 ====================
    grave_rat = {
        name = "墓穴鼠", hp = 40, atk = 22, speed = 70, def = 0,
        atkInterval = 1.2, element = "physical",
        packBonus = 0.40, packThreshold = 4,
        expDrop = 10, dropTemplate = "common",
        image = "Textures/mobs/grave_rat.png", radius = 13,
        color = { 100, 80, 70 },
        resist = { poison = 0.40 },
    },
    skeleton_warrior = {
        name = "骸骨武士", hp = 130, atk = 20, speed = 40, def = 14,
        atkInterval = 1.3, element = "physical",
        expDrop = 22, dropTemplate = "common",
        image = "Textures/mobs/skeleton_warrior.png", radius = 16,
        color = { 200, 190, 170 },
        resist = { fire = -0.25, ice = 0.10, poison = 0.50, physical = 0.20 },
    },
    wraith = {
        name = "怨灵", hp = 35, atk = 28, speed = 55, def = 0,
        atkInterval = 0.9, element = "arcane",
        defPierce = 0.45,
        expDrop = 12, dropTemplate = "common",
        image = "Textures/mobs/wraith.png", radius = 14,
        color = { 120, 80, 180 },
        resist = { ice = 0.20, poison = 0.50, arcane = 0.30, physical = 0.50 },
    },
    corpse_spider = {
        name = "尸蛛", hp = 90, atk = 18, speed = 50, def = 4,
        atkInterval = 1.0, element = "poison", antiHeal = true,
        slowOnHit = 0.35, slowDuration = 2.0,
        expDrop = 16, dropTemplate = "common",
        image = "Textures/mobs/corpse_spider.png", radius = 15,
        color = { 80, 100, 60 },
        resist = { fire = -0.20, poison = 0.50, water = 0.10 },
    },
    necro_acolyte = {
        name = "亡灵侍祭", hp = 75, atk = 24, speed = 45, def = 3,
        atkInterval = 1.0, element = "arcane",
        isRanged = true,
        healAura = { pct = 0.05, interval = 8.0, radius = 100 },
        expDrop = 20, dropTemplate = "common",
        image = "Textures/mobs/necro_acolyte.png", radius = 15,
        color = { 100, 60, 140 },
        resist = { poison = 0.40, arcane = 0.20 },
    },
    bone_golem = {
        name = "骨傀儡", hp = 280, atk = 15, speed = 30, def = 19,
        atkInterval = 1.8, element = "physical",
        deathExplode = { element = "arcane", dmgMul = 1.0, radius = 50 },
        expDrop = 30, dropTemplate = "common",
        image = "Textures/mobs/bone_golem.png", radius = 18,
        color = { 180, 170, 150 },
        resist = { fire = -0.30, poison = 0.50, water = 0.10, physical = 0.30 },
    },
    shadow_assassin = {
        name = "暗影刺客", hp = 50, atk = 35, speed = 65, def = 1,
        atkInterval = 0.8, element = "arcane",
        firstStrikeMul = 2.0,
        expDrop = 18, dropTemplate = "common",
        image = "Textures/mobs/shadow_assassin.png", radius = 14,
        color = { 60, 40, 80 },
        resist = { fire = 0.10, ice = 0.10, poison = 0.40, arcane = 0.30, physical = 0.40 },
    },
    cursed_knight = {
        name = "诅咒骑士", hp = 160, atk = 25, speed = 45, def = 9,
        atkInterval = 1.0, element = "arcane",
        lifesteal = 0.15,
        expDrop = 24, dropTemplate = "common",
        image = "Textures/mobs/cursed_knight.png", radius = 16,
        color = { 140, 50, 60 },
        resist = { ice = 0.10, poison = 0.50, arcane = 0.15, physical = 0.15 },
    },
    -- 第四章 BOSS
    boss_bone_lord = {
        name = "骨冠领主·厄亡", hp = 22400, atk = 55, speed = 25, def = 15,
        atkInterval = 1.5, element = "arcane", antiHeal = true,
        barrage = { interval = 12.0, count = 8, dmgMul = 0.6, element = "arcane" },
        iceArmor = { hpThreshold = 0.5, dmgReduce = 0.55, duration = 4.0, cd = 14.0 },
        summon = { interval = 12.0, monsterId = "skeleton_warrior", count = 2 },
        expDrop = 5000, dropTemplate = "miniboss",
        image = "Textures/mobs/boss_bone_lord.png", radius = 32,
        color = { 160, 130, 80 }, isBoss = true,
        resist = { fire = -0.20, ice = 0.15, poison = 0.50, arcane = 0.20, physical = 0.25 },
    },
    boss_tomb_king = {
        name = "墓域君王·永夜", hp = 41600, atk = 70, speed = 20, def = 20,
        atkInterval = 2.0, element = "arcane", antiHeal = true,
        slowOnHit = 0.35, slowDuration = 2.5,
        barrage = { interval = 8.0, count = 10, dmgMul = 0.5, element = "arcane" },
        frozenField = { hpThreshold = 0.6, slowRate = 0.5, duration = 8.0, cd = 18.0 },
        iceRegen = { hpThreshold = 0.25, regenPct = 0.02 },
        expDrop = 8000, dropTemplate = "boss",
        image = "Textures/mobs/boss_tomb_king.png", radius = 36,
        color = { 80, 50, 120 }, isBoss = true,
        resist = { fire = 0.10, ice = 0.10, poison = 0.50, arcane = 0.30, physical = 0.20 },
    },
    -- ==================== 第五章: 深海渊域 ====================
    abyss_angler = {
        name = "深海灯笼鱼", hp = 50, atk = 30, speed = 65, def = 0,
        atkInterval = 1.2, element = "water",
        packBonus = 0.35, packThreshold = 3,
        expDrop = 14, dropTemplate = "common",
        image = "Textures/mobs/abyss_angler.png", radius = 14,
        color = { 20, 60, 160 },
        resist = { ice = -0.20, water = 0.50 },
    },
    storm_seahorse = {
        name = "风暴海马", hp = 45, atk = 35, speed = 75, def = 1,
        atkInterval = 0.9, element = "water",
        defPierce = 0.30,
        expDrop = 12, dropTemplate = "common",
        image = "Textures/mobs/storm_seahorse.png", radius = 13,
        color = { 80, 50, 180 },
        resist = { ice = -0.25, water = 0.50 },
    },
    venom_jelly = {
        name = "毒刺水母", hp = 55, atk = 25, speed = 40, def = 0,
        atkInterval = 1.0, element = "poison", antiHeal = true,
        slowOnHit = 0.30, slowDuration = 2.0,
        expDrop = 12, dropTemplate = "common",
        image = "Textures/mobs/venom_jelly.png", radius = 14,
        color = { 140, 60, 200 },
        resist = { poison = 0.50, water = 0.30, physical = 0.20 },
    },
    coral_guardian = {
        name = "珊瑚甲卫", hp = 200, atk = 18, speed = 20, def = 17,
        atkInterval = 1.5, element = "water",
        splitOnDeath = { childId = "coral_shard", count = 2 },
        expDrop = 28, dropTemplate = "common",
        image = "Textures/mobs/coral_guardian.png", radius = 18,
        color = { 200, 80, 60 },
        resist = { fire = -0.20, poison = 0.10, water = 0.50, physical = 0.30 },
    },
    -- 珊瑚甲卫分裂产物 (不再分裂)
    coral_shard = {
        name = "珊瑚碎片", hp = 60, atk = 12, speed = 35, def = 6,
        atkInterval = 1.2, element = "water",
        expDrop = 6, dropTemplate = "summon",
        image = "Textures/mobs/coral_guardian.png", radius = 11,
        color = { 200, 100, 80 },
        resist = { fire = -0.20, water = 0.50 },
    },
    sea_anemone = {
        name = "海葵祭司", hp = 85, atk = 28, speed = 35, def = 3,
        atkInterval = 1.0, element = "water",
        isRanged = true,
        healAura = { pct = 0.06, interval = 8.0, radius = 100 },
        expDrop = 22, dropTemplate = "common",
        image = "Textures/mobs/sea_anemone.png", radius = 15,
        color = { 40, 140, 120 },
        resist = { fire = -0.25, poison = 0.40, water = 0.50, arcane = 0.10 },
    },
    abyssal_crab = {
        name = "深渊巨蟹", hp = 300, atk = 20, speed = 15, def = 22,
        atkInterval = 1.8, element = "water",
        corrosion = { defReducePct = 0.08, stackMax = 5, duration = 8.0 },
        expDrop = 35, dropTemplate = "common",
        image = "Textures/mobs/abyssal_crab.png", radius = 19,
        color = { 20, 40, 100 },
        resist = { fire = -0.15, ice = 0.10, poison = 0.10, water = 0.50, physical = 0.40 },
    },
    ink_octopus = {
        name = "墨渊章鱼", hp = 100, atk = 32, speed = 50, def = 4,
        atkInterval = 1.0, element = "water",
        inkBlind = { atkReducePct = 0.25, duration = 4.0 },
        expDrop = 20, dropTemplate = "common",
        image = "Textures/mobs/ink_octopus.png", radius = 15,
        color = { 60, 20, 80 },
        resist = { ice = -0.20, poison = 0.30, water = 0.50 },
    },
    tide_merfolk = {
        name = "潮汐鲛人", hp = 180, atk = 30, speed = 50, def = 11,
        atkInterval = 1.0, element = "water",
        lifesteal = 0.20,
        expDrop = 26, dropTemplate = "common",
        image = "Textures/mobs/tide_merfolk.png", radius = 16,
        color = { 40, 120, 100 },
        resist = { poison = 0.15, water = 0.40, arcane = -0.20, physical = 0.10 },
    },
    -- 第五章 BOSS
    boss_siren = {
        name = "深渊女妖·塞壬", hp = 64000, atk = 85, speed = 25, def = 20,
        atkInterval = 1.5, element = "water", antiHeal = true,
        slowOnHit = 0.40, slowDuration = 2.5,
        barrage = { interval = 8.0, count = 10, dmgMul = 0.6, element = "water" },
        iceArmor = { hpThreshold = 0.5, dmgReduce = 0.50, duration = 4.0, cd = 12.0 },
        summon = { interval = 12.0, monsterId = "venom_jelly", count = 2 },
        expDrop = 10000, dropTemplate = "miniboss",
        image = "Textures/mobs/boss_siren.png", radius = 32,
        color = { 60, 100, 200 }, isBoss = true,
        resist = { ice = -0.15, poison = 0.40, water = 0.50, physical = 0.20 },
    },
    boss_leviathan = {
        name = "海渊之主·利维坦", hp = 128000, atk = 110, speed = 18, def = 30,
        atkInterval = 2.0, element = "water", antiHeal = true,
        slowOnHit = 0.35, slowDuration = 2.5,
        dragonBreath = { interval = 9.0, dmgMul = 2.5, element = "water" },
        frozenField = { hpThreshold = 0.6, slowRate = 0.50, duration = 8.0, cd = 18.0 },
        iceRegen = { hpThreshold = 0.25, regenPct = 0.025 },
        expDrop = 15000, dropTemplate = "boss",
        image = "Textures/mobs/boss_leviathan.png", radius = 38,
        color = { 10, 30, 80 }, isBoss = true,
        resist = { fire = -0.10, poison = 0.30, water = 0.50, arcane = 0.15, physical = 0.30 },
    },
    -- ==================== 第六章: 雷鸣荒漠 ====================
    sand_scarab = {
        name = "沙漠甲虫", hp = 55, atk = 28, speed = 70, def = 1,
        atkInterval = 1.0, element = "physical",
        packBonus = 0.30, packThreshold = 4,
        expDrop = 18, dropTemplate = "common",
        image = "Textures/mobs/sand_scarab.png", radius = 13,
        color = { 200, 170, 80 },
        resist = { ice = -0.20, poison = 0.10, water = -0.25, physical = 0.30 },
    },
    thunder_scorpion = {
        name = "雷蝎", hp = 80, atk = 38, speed = 55, def = 3,
        atkInterval = 0.9, element = "arcane",
        chargeUp = { stackMax = 5, dmgMul = 2.5, resetOnTrigger = true },
        expDrop = 24, dropTemplate = "common",
        image = "Textures/mobs/thunder_scorpion.png", radius = 15,
        color = { 180, 130, 255 },
        resist = { fire = 0.10, ice = -0.15, poison = 0.30, water = -0.20, arcane = 0.40 },
    },
    dune_worm = {
        name = "沙丘蠕虫", hp = 250, atk = 22, speed = 18, def = 20,
        atkInterval = 1.8, element = "physical",
        firstStrikeMul = 2.0,
        expDrop = 32, dropTemplate = "common",
        image = "Textures/mobs/dune_worm.png", radius = 18,
        color = { 160, 140, 90 },
        resist = { fire = -0.15, poison = 0.20, water = -0.20, physical = 0.40 },
    },
    storm_hawk = {
        name = "风暴鹰", hp = 60, atk = 40, speed = 80, def = 0,
        atkInterval = 0.8, element = "arcane",
        defPierce = 0.30,
        expDrop = 20, dropTemplate = "common",
        image = "Textures/mobs/storm_hawk.png", radius = 14,
        color = { 140, 100, 220 },
        resist = { ice = -0.25, water = 0.10, arcane = 0.50 },
    },
    lightning_lizard = {
        name = "雷脊蜥", hp = 120, atk = 35, speed = 50, def = 8,
        atkInterval = 1.0, element = "fire",
        chainLightning = { bounces = 2, dmgMul = 0.50, element = "arcane", range = 80 },
        expDrop = 26, dropTemplate = "common",
        image = "Textures/mobs/lightning_lizard.png", radius = 16,
        color = { 220, 160, 50 },
        resist = { fire = 0.30, ice = -0.20, water = -0.15, arcane = 0.20, physical = 0.10 },
    },
    sand_wraith = {
        name = "荒漠蛛后", hp = 100, atk = 32, speed = 40, def = 4,
        atkInterval = 1.0, element = "poison",
        isRanged = true,
        sandStorm = { critReducePct = 0.20, duration = 5.0 },
        expDrop = 22, dropTemplate = "common",
        image = "Textures/mobs/sand_wraith.png", radius = 15,
        color = { 180, 160, 100 },
        resist = { fire = -0.20, poison = 0.50, physical = 0.10 },
    },
    desert_golem = {
        name = "沙漠傀儡", hp = 350, atk = 25, speed = 12, def = 25,
        atkInterval = 2.0, element = "physical",
        chargeUp = { stackMax = 8, dmgMul = 2.0, resetOnTrigger = true, isAOE = true, aoeRadius = 60 },
        hpRegen = 0.02, hpRegenInterval = 6.0,
        expDrop = 40, dropTemplate = "common",
        image = "Textures/mobs/desert_golem.png", radius = 19,
        color = { 170, 150, 100 },
        resist = { ice = 0.10, water = -0.25, arcane = -0.15, physical = 0.50 },
    },
    thunder_shaman = {
        name = "雷能巫师", hp = 200, atk = 35, speed = 45, def = 12,
        atkInterval = 1.2, element = "arcane",
        isRanged = true,
        lifesteal = 0.15,
        healAura = { pct = 0.05, interval = 8.0, radius = 100 },
        expDrop = 34, dropTemplate = "common",
        image = "Textures/mobs/thunder_shaman.png", radius = 16,
        color = { 200, 180, 255 },
        resist = { ice = -0.15, poison = 0.20, water = -0.20, arcane = 0.30 },
    },
    -- 第六章 BOSS
    boss_sandstorm_lord = {
        name = "沙暴君主·拉赫", hp = 192000, atk = 130, speed = 22, def = 24,
        atkInterval = 1.5, element = "arcane", antiHeal = true,
        slowOnHit = 0.35, slowDuration = 2.0,
        barrage = { interval = 7.0, count = 12, dmgMul = 0.5, element = "arcane" },
        frozenField = { hpThreshold = 0.6, slowRate = 0.40, duration = 6.0, cd = 16.0 },
        iceArmor = { hpThreshold = 0.4, dmgReduce = 0.45, duration = 5.0, cd = 14.0 },
        summon = { interval = 10.0, monsterId = "thunder_scorpion", count = 3 },
        expDrop = 15000, dropTemplate = "miniboss",
        image = "Textures/mobs/boss_sandstorm_lord.png", radius = 36,
        color = { 200, 170, 60 }, isBoss = true,
        resist = { fire = 0.20, ice = -0.20, poison = 0.10, water = -0.15, arcane = 0.50, physical = 0.25 },
    },
    boss_thunder_titan = {
        name = "雷霆泰坦·奥西曼", hp = 224000, atk = 150, speed = 16, def = 35,
        atkInterval = 2.0, element = "fire", antiHeal = true,
        slowOnHit = 0.30, slowDuration = 2.5,
        dragonBreath = { interval = 8.0, dmgMul = 3.0, element = "fire" },
        frozenField = { hpThreshold = 0.55, slowRate = 0.55, duration = 8.0, cd = 18.0 },
        iceArmor = { hpThreshold = 0.35, dmgReduce = 0.55, duration = 5.0, cd = 15.0 },
        iceRegen = { hpThreshold = 0.20, regenPct = 0.020 },
        expDrop = 22000, dropTemplate = "boss",
        image = "Textures/mobs/boss_thunder_titan.png", radius = 40,
        color = { 255, 200, 50 }, isBoss = true,
        resist = { fire = 0.40, ice = 0.10, poison = -0.15, water = -0.20, arcane = 0.30, physical = 0.20 },
    },

    -- ==================== 第七章: 瘴毒密林 ====================
    plague_beetle = {
        name = "瘟疫甲虫", hp = 55, atk = 28, def = 1, speed = 70,
        atkInterval = 1.0, element = "poison",
        packBonus = 0.30, packThreshold = 4,
        expDrop = 450, dropTemplate = "common",
        image = "Textures/mobs/plague_beetle.png", radius = 13,
        color = {80, 140, 50},
        resist = { fire = -0.15, ice = 0, poison = 0.30, water = 0, arcane = 0, physical = 0.10 },
    },
    thorn_viper = {
        name = "荆棘蝮蛇", hp = 70, atk = 42, def = 2, speed = 65,
        atkInterval = 0.8, element = "poison",
        venomStack = { dmgPctPerStack = 0.02, stackMax = 8, duration = 6.0 },
        expDrop = 650, dropTemplate = "common",
        image = "Textures/mobs/thorn_viper.png", radius = 15,
        color = {120, 180, 40},
        resist = { fire = -0.30, ice = 0, poison = 0.40, water = -0.15, arcane = 0, physical = 0 },
    },
    jungle_panther = {
        name = "丛林黑豹", hp = 65, atk = 45, def = 2, speed = 80,
        atkInterval = 0.7, element = "physical",
        defPierce = 0.35, firstStrikeMul = 2.0,
        expDrop = 600, dropTemplate = "common",
        image = "Textures/mobs/jungle_panther.png", radius = 15,
        color = {60, 60, 60},
        resist = { fire = -0.15, ice = 0, poison = 0.10, water = 0, arcane = 0, physical = 0.30 },
    },
    vine_strangler = {
        name = "绞杀藤蔓", hp = 150, atk = 30, def = 14, speed = 25,
        atkInterval = 1.5, element = "physical",
        slowOnHit = 0.40, slowDuration = 2.5, antiHeal = true,
        expDrop = 700, dropTemplate = "common",
        image = "Textures/mobs/vine_strangler.png", radius = 17,
        color = {80, 120, 50},
        resist = { fire = -0.20, ice = 0.10, poison = 0.20, water = 0, arcane = 0, physical = 0.40 },
    },
    spore_lurker = {
        name = "孢子潜伏者", hp = 120, atk = 28, def = 9, speed = 35,
        atkInterval = 1.2, element = "poison",
        sporeCloud = { atkSpeedReducePct = 0.15, duration = 4.0 },
        deathExplode = { element = "poison", dmgMul = 0.8, radius = 45 },
        expDrop = 650, dropTemplate = "common",
        image = "Textures/mobs/spore_lurker.png", radius = 14,
        color = {160, 130, 80},
        resist = { fire = -0.20, ice = -0.15, poison = 0.50, water = 0, arcane = 0, physical = 0.10 },
    },
    toxic_wasp = {
        name = "毒雾黄蜂", hp = 50, atk = 30, def = 1, speed = 75,
        atkInterval = 0.9, element = "poison",
        venomStack = { dmgPctPerStack = 0.015, stackMax = 6, duration = 5.0 },
        packBonus = 0.25, packThreshold = 5,
        expDrop = 500, dropTemplate = "common",
        image = "Textures/mobs/toxic_wasp.png", radius = 12,
        color = {180, 200, 30},
        resist = { fire = -0.25, ice = 0, poison = 0.35, water = -0.10, arcane = 0, physical = 0 },
    },
    ironbark_treant = {
        name = "铁木树人", hp = 500, atk = 20, def = 36, speed = 10,
        atkInterval = 2.2, element = "physical",
        sporeCloud = { atkSpeedReducePct = 0.20, duration = 5.0 },
        hpRegen = 0.02, hpRegenInterval = 6.0,
        expDrop = 1100, dropTemplate = "common",
        image = "Textures/mobs/ironbark_treant.png", radius = 20,
        color = {100, 80, 50},
        resist = { fire = -0.30, ice = 0, poison = 0.20, water = -0.15, arcane = -0.10, physical = 0.50 },
    },
    mire_shaman = {
        name = "沼地巫师", hp = 180, atk = 38, def = 11, speed = 40,
        atkInterval = 1.2, element = "poison",
        isRanged = true, lifesteal = 0.18,
        healAura = { pct = 0.05, interval = 8.0, radius = 100 },
        expDrop = 950, dropTemplate = "common",
        image = "Textures/mobs/mire_shaman.png", radius = 16,
        color = {60, 160, 80},
        resist = { fire = -0.15, ice = 0, poison = 0.40, water = 0, arcane = 0.20, physical = 0 },
    },
    -- 第七章 BOSS
    boss_venom_queen = {
        name = "毒液女王·阿拉克涅", hp = 320000, atk = 200, speed = 22, def = 28,
        atkInterval = 1.5, element = "poison", antiHeal = true,
        slowOnHit = 0.35, slowDuration = 2.0,
        barrage = { interval = 7.0, count = 14, dmgMul = 0.5, element = "poison" },
        iceArmor = { hpThreshold = 0.4, dmgReduce = 0.50, duration = 5.0, cd = 14.0 },
        summon = { interval = 10.0, monsterId = "thorn_viper", count = 3 },
        expDrop = 20000, dropTemplate = "miniboss",
        image = "Textures/mobs/boss_venom_queen.png", radius = 36,
        color = { 100, 200, 50 }, isBoss = true,
        resist = { fire = -0.20, ice = 0.10, poison = 0.50, water = -0.15, arcane = 0, physical = 0.20 },
    },
    boss_rotwood_mother = {
        name = "朽木之母·耶梦加得", hp = 640000, atk = 270, speed = 14, def = 42,
        atkInterval = 2.0, element = "physical", antiHeal = true,
        slowOnHit = 0.30, slowDuration = 2.5,
        dragonBreath = { interval = 8.0, dmgMul = 3.0, element = "physical" },
        frozenField = { hpThreshold = 0.55, slowRate = 0.50, duration = 7.0, cd = 18.0 },
        iceArmor = { hpThreshold = 0.35, dmgReduce = 0.55, duration = 5.0, cd = 15.0 },
        iceRegen = { hpThreshold = 0.20, regenPct = 0.022 },
        expDrop = 28000, dropTemplate = "boss",
        image = "Textures/mobs/boss_rotwood_mother.png", radius = 40,
        color = { 80, 60, 40 }, isBoss = true,
        resist = { fire = -0.15, ice = -0.10, poison = 0.30, water = 0, arcane = 0.10, physical = 0.40 },
    },
    -- ==================== 第八章: 虚空裂隙 ====================
    void_wisp = {
        name = "虚空游光", hp = 45, atk = 35, def = 1, speed = 75,
        atkInterval = 0.9, element = "arcane",
        packBonus = 0.35, packThreshold = 4,
        expDrop = 600, dropTemplate = "common",
        image = "Textures/mobs/void_wisp.png", radius = 12,
        color = {160, 80, 220},
        resist = { fire = 0, ice = 0, poison = -0.20, water = -0.15, arcane = 0.40, physical = -0.10 },
    },
    rift_stalker = {
        name = "裂隙潜行者", hp = 75, atk = 52, def = 3, speed = 70,
        atkInterval = 0.7, element = "arcane",
        defPierce = 0.40, firstStrikeMul = 2.2,
        expDrop = 800, dropTemplate = "common",
        image = "Textures/mobs/rift_stalker.png", radius = 15,
        color = {120, 50, 180},
        resist = { fire = -0.15, ice = 0, poison = -0.20, water = 0, arcane = 0.35, physical = 0.10 },
    },
    null_sentinel = {
        name = "虚无哨兵", hp = 200, atk = 35, def = 17, speed = 30,
        atkInterval = 1.4, element = "arcane",
        slowOnHit = 0.35, slowDuration = 2.0,
        hpRegen = 0.025, hpRegenInterval = 5.0,
        expDrop = 900, dropTemplate = "common",
        image = "Textures/mobs/null_sentinel.png", radius = 18,
        color = {100, 60, 160},
        resist = { fire = -0.15, ice = 0.10, poison = 0, water = -0.10, arcane = 0.45, physical = 0.30 },
    },
    phase_weaver = {
        name = "相位编织者", hp = 130, atk = 45, def = 8, speed = 45,
        atkInterval = 1.1, element = "arcane",
        isRanged = true, lifesteal = 0.15,
        healAura = { pct = 0.04, interval = 7.0, radius = 90 },
        expDrop = 850, dropTemplate = "common",
        image = "Textures/mobs/phase_weaver.png", radius = 15,
        color = {180, 100, 220},
        resist = { fire = 0, ice = -0.15, poison = 0, water = 0, arcane = 0.30, physical = -0.10 },
    },
    entropy_mote = {
        name = "熵灭微粒", hp = 60, atk = 38, def = 1, speed = 80,
        atkInterval = 0.8, element = "arcane",
        deathExplode = { element = "arcane", dmgMul = 1.0, radius = 50 },
        packBonus = 0.30, packThreshold = 5,
        expDrop = 650, dropTemplate = "common",
        image = "Textures/mobs/entropy_mote.png", radius = 11,
        color = {200, 120, 255},
        resist = { fire = -0.20, ice = -0.15, poison = 0, water = 0, arcane = 0.50, physical = -0.15 },
    },
    spatial_ripper = {
        name = "空间撕裂者", hp = 100, atk = 48, def = 4, speed = 55,
        atkInterval = 0.9, element = "arcane",
        venomStack = { dmgPctPerStack = 0.025, stackMax = 6, duration = 5.0 },
        expDrop = 750, dropTemplate = "common",
        image = "Textures/mobs/spatial_ripper.png", radius = 14,
        color = {140, 60, 200},
        resist = { fire = 0, ice = 0, poison = -0.15, water = -0.20, arcane = 0.35, physical = 0.10 },
    },
    void_colossus = {
        name = "虚空巨像", hp = 600, atk = 25, def = 40, speed = 10,
        atkInterval = 2.4, element = "arcane",
        sporeCloud = { atkSpeedReducePct = 0.25, duration = 5.0 },
        hpRegen = 0.025, hpRegenInterval = 5.0,
        expDrop = 1400, dropTemplate = "common",
        image = "Textures/mobs/void_colossus.png", radius = 22,
        color = {80, 40, 130},
        resist = { fire = -0.20, ice = -0.10, poison = 0.10, water = 0, arcane = 0.50, physical = 0.40 },
    },
    star_oracle = {
        name = "星辰神谕者", hp = 220, atk = 50, def = 12, speed = 40,
        atkInterval = 1.3, element = "arcane",
        isRanged = true, antiHeal = true,
        healAura = { pct = 0.06, interval = 7.0, radius = 110 },
        expDrop = 1200, dropTemplate = "common",
        image = "Textures/mobs/star_oracle.png", radius = 16,
        color = {220, 180, 255},
        resist = { fire = -0.10, ice = 0, poison = -0.15, water = 0, arcane = 0.40, physical = 0.10 },
    },
    -- 第八章 BOSS
    boss_void_prince = {
        name = "虚空亲王·艾瑟隆", hp = 384000, atk = 260, speed = 22, def = 35,
        atkInterval = 1.4, element = "arcane", antiHeal = true,
        slowOnHit = 0.30, slowDuration = 2.0,
        barrage = { interval = 6.0, count = 16, dmgMul = 0.5, element = "arcane" },
        iceArmor = { hpThreshold = 0.45, dmgReduce = 0.50, duration = 5.0, cd = 13.0 },
        summon = { interval = 10.0, monsterId = "rift_stalker", count = 3 },
        expDrop = 28000, dropTemplate = "miniboss",
        image = "Textures/mobs/boss_void_prince.png", radius = 38,
        color = { 160, 80, 220 }, isBoss = true,
        resist = { fire = -0.15, ice = 0, poison = -0.20, water = 0.10, arcane = 0.50, physical = 0.15 },
    },
    boss_rift_sovereign = {
        name = "裂隙君主·奥伯龙", hp = 832000, atk = 340, speed = 14, def = 50,
        atkInterval = 2.0, element = "arcane", antiHeal = true,
        slowOnHit = 0.35, slowDuration = 2.5,
        dragonBreath = { interval = 7.0, dmgMul = 3.5, element = "arcane" },
        frozenField = { hpThreshold = 0.55, slowRate = 0.55, duration = 7.0, cd = 16.0 },
        iceArmor = { hpThreshold = 0.35, dmgReduce = 0.60, duration = 5.0, cd = 14.0 },
        iceRegen = { hpThreshold = 0.20, regenPct = 0.025 },
        expDrop = 36000, dropTemplate = "boss",
        image = "Textures/mobs/boss_rift_sovereign.png", radius = 42,
        color = { 100, 40, 180 }, isBoss = true,
        resist = { fire = -0.10, ice = -0.15, poison = 0.10, water = 0, arcane = 0.40, physical = 0.30 },
    },
    -- ==================== 第九章: 天穹圣域 ====================
    radiant_sprite = {
        name = "辉光精灵", hp = 55, atk = 40, def = 2, speed = 72,
        atkInterval = 0.85, element = "holy",
        packBonus = 0.35, packThreshold = 4,
        expDrop = 750, dropTemplate = "common",
        image = "Textures/mobs/radiant_sprite.png", radius = 12,
        color = {255, 220, 140},
        resist = { fire = 0.10, ice = 0, poison = -0.25, water = 0, arcane = -0.15, physical = -0.10, holy = 0.45 },
    },
    zealot_knight = {
        name = "狂信骑士", hp = 90, atk = 58, def = 4, speed = 65,
        atkInterval = 0.75, element = "holy",
        defPierce = 0.35, firstStrikeMul = 2.0,
        expDrop = 950, dropTemplate = "common",
        image = "Textures/mobs/zealot_knight.png", radius = 16,
        color = {240, 200, 100},
        resist = { fire = 0, ice = -0.15, poison = -0.20, water = 0, arcane = 0, physical = 0.20, holy = 0.40 },
    },
    golden_guardian = {
        name = "金甲守卫", hp = 250, atk = 38, def = 22, speed = 25,
        atkInterval = 1.5, element = "holy",
        slowOnHit = 0.30, slowDuration = 2.0,
        hpRegen = 0.02, hpRegenInterval = 5.0,
        expDrop = 1100, dropTemplate = "common",
        image = "Textures/mobs/golden_guardian.png", radius = 19,
        color = {220, 190, 80},
        resist = { fire = -0.10, ice = 0.10, poison = -0.15, water = 0, arcane = 0, physical = 0.35, holy = 0.50 },
    },
    celestial_mender = {
        name = "天穹治愈师", hp = 160, atk = 48, def = 9, speed = 42,
        atkInterval = 1.1, element = "holy",
        isRanged = true, lifesteal = 0.12,
        healAura = { pct = 0.05, interval = 6.0, radius = 100 },
        expDrop = 1000, dropTemplate = "common",
        image = "Textures/mobs/celestial_mender.png", radius = 15,
        color = {255, 240, 180},
        resist = { fire = 0, ice = -0.10, poison = -0.15, water = 0.10, arcane = 0, physical = -0.10, holy = 0.35 },
    },
    sanctum_wisp = {
        name = "圣光游魂", hp = 70, atk = 42, def = 1, speed = 78,
        atkInterval = 0.8, element = "holy",
        deathExplode = { element = "holy", dmgMul = 1.1, radius = 55 },
        packBonus = 0.30, packThreshold = 5,
        expDrop = 800, dropTemplate = "common",
        image = "Textures/mobs/sanctum_wisp.png", radius = 11,
        color = {255, 250, 200},
        resist = { fire = -0.15, ice = -0.15, poison = -0.20, water = 0, arcane = -0.10, physical = -0.15, holy = 0.55 },
    },
    halo_lancer = {
        name = "光环枪兵", hp = 120, atk = 52, def = 6, speed = 52,
        atkInterval = 0.9, element = "holy",
        venomStack = { dmgPctPerStack = 0.03, stackMax = 5, duration = 5.0 },
        expDrop = 900, dropTemplate = "common",
        image = "Textures/mobs/halo_lancer.png", radius = 15,
        color = {250, 210, 120},
        resist = { fire = 0, ice = 0, poison = -0.20, water = -0.10, arcane = 0, physical = 0.15, holy = 0.40 },
    },
    divine_colossus = {
        name = "圣域巨灵", hp = 700, atk = 30, def = 44, speed = 8,
        atkInterval = 2.5, element = "holy",
        sporeCloud = { atkSpeedReducePct = 0.30, duration = 5.0 },
        hpRegen = 0.02, hpRegenInterval = 5.0,
        expDrop = 1700, dropTemplate = "common",
        image = "Textures/mobs/divine_colossus.png", radius = 23,
        color = {200, 170, 60},
        resist = { fire = -0.15, ice = -0.10, poison = -0.10, water = 0, arcane = 0.10, physical = 0.45, holy = 0.55 },
    },
    seraph_invoker = {
        name = "炽天使祈唤者", hp = 260, atk = 55, def = 14, speed = 38,
        atkInterval = 1.3, element = "holy",
        isRanged = true, antiHeal = true,
        healAura = { pct = 0.07, interval = 7.0, radius = 120 },
        expDrop = 1500, dropTemplate = "common",
        image = "Textures/mobs/seraph_invoker.png", radius = 17,
        color = {255, 230, 160},
        resist = { fire = -0.10, ice = 0, poison = -0.15, water = 0, arcane = 0, physical = 0.10, holy = 0.45 },
    },
    -- 第九章 BOSS
    boss_archon = {
        name = "圣裁者·米迦勒", hp = 480000, atk = 300, speed = 20, def = 40,
        atkInterval = 1.3, element = "holy", antiHeal = true,
        slowOnHit = 0.30, slowDuration = 2.0,
        barrage = { interval = 5.5, count = 18, dmgMul = 0.55, element = "holy" },
        iceArmor = { hpThreshold = 0.45, dmgReduce = 0.55, duration = 5.0, cd = 12.0 },
        summon = { interval = 9.0, monsterId = "zealot_knight", count = 4 },
        expDrop = 35000, dropTemplate = "miniboss",
        image = "Textures/mobs/boss_archon.png", radius = 40,
        color = { 255, 220, 100 }, isBoss = true,
        resist = { fire = -0.10, ice = 0, poison = -0.25, water = 0, arcane = -0.10, physical = 0.20, holy = 0.50 },
    },
    boss_celestial_emperor = {
        name = "天穹帝皇·乌列尔", hp = 1024000, atk = 400, speed = 12, def = 58,
        atkInterval = 2.0, element = "holy", antiHeal = true,
        slowOnHit = 0.40, slowDuration = 2.5,
        dragonBreath = { interval = 6.5, dmgMul = 3.8, element = "holy" },
        frozenField = { hpThreshold = 0.55, slowRate = 0.60, duration = 7.0, cd = 15.0 },
        iceArmor = { hpThreshold = 0.35, dmgReduce = 0.65, duration = 5.0, cd = 13.0 },
        iceRegen = { hpThreshold = 0.20, regenPct = 0.03 },
        expDrop = 45000, dropTemplate = "boss",
        image = "Textures/mobs/boss_celestial_emperor.png", radius = 45,
        color = { 255, 200, 60 }, isBoss = true,
        resist = { fire = -0.10, ice = -0.10, poison = -0.15, water = 0, arcane = 0.10, physical = 0.30, holy = 0.45 },
    },

    -- ==================== 第十章: 永夜深渊 ====================
    abyss_shade = {
        name = "深渊暗影", hp = 65, atk = 45, speed = 72, def = 2,
        atkInterval = 1.0, element = "arcane",
        packBonus = 0.35, packThreshold = 4,
        expDrop = 900, dropTemplate = "common",
        image = "Textures/mobs/mob_abyss_shade_20260310091659.png", radius = 14,
        color = { 100, 50, 160 },
        resist = { fire = -0.20, ice = 0, poison = 0, water = 0, arcane = 0.40, physical = -0.10 },
    },
    night_reaper = {
        name = "永夜收割者", hp = 100, atk = 62, speed = 68, def = 5,
        atkInterval = 0.9, element = "arcane",
        defPierce = 0.40, firstStrikeMul = 2.2,
        expDrop = 1100, dropTemplate = "common",
        image = "Textures/mobs/mob_night_reaper_20260310091728.png", radius = 15,
        color = { 130, 40, 180 },
        resist = { fire = -0.15, ice = 0, poison = -0.20, water = 0, arcane = 0.35, physical = 0 },
    },
    dark_sentinel = {
        name = "暗之哨卫", hp = 300, atk = 42, speed = 25, def = 24,
        atkInterval = 1.5, element = "physical",
        slowOnHit = 0.35, slowDuration = 2.0,
        hpRegen = 0.025, hpRegenInterval = 5.0,
        expDrop = 1400, dropTemplate = "common",
        image = "Textures/mobs/mob_dark_sentinel_20260310091701.png", radius = 18,
        color = { 80, 70, 100 },
        resist = { fire = 0, ice = 0.10, poison = 0, water = -0.20, arcane = 0.30, physical = 0.20 },
    },
    corrupt_mage = {
        name = "腐化法师", hp = 180, atk = 55, speed = 42, def = 11,
        atkInterval = 1.2, element = "arcane",
        isRanged = true, lifesteal = 0.15,
        healAura = { pct = 0.04, interval = 7.0, radius = 90 },
        expDrop = 1200, dropTemplate = "common",
        image = "Textures/mobs/mob_corrupt_mage_20260310091712.png", radius = 15,
        color = { 120, 60, 180 },
        resist = { fire = -0.25, ice = 0, poison = 0, water = 0, arcane = 0.45, physical = -0.10 },
    },
    doom_wisp = {
        name = "末日游魂", hp = 80, atk = 48, speed = 78, def = 1,
        atkInterval = 0.9, element = "fire",
        deathExplode = { element = "fire", dmgMul = 1.2, radius = 55 },
        packBonus = 0.30, packThreshold = 5,
        expDrop = 1000, dropTemplate = "common",
        image = "Textures/mobs/mob_doom_wisp_20260310091652.png", radius = 13,
        color = { 200, 80, 40 },
        resist = { fire = 0.30, ice = -0.25, poison = 0, water = -0.15, arcane = 0, physical = 0 },
    },
    void_lancer = {
        name = "虚空枪兵", hp = 140, atk = 58, speed = 52, def = 7,
        atkInterval = 1.1, element = "arcane",
        venomStack = { dmgPctPerStack = 0.025, stackMax = 6, duration = 5.0 },
        expDrop = 1100, dropTemplate = "common",
        image = "Textures/mobs/mob_void_lancer_20260310091651.png", radius = 16,
        color = { 110, 50, 170 },
        resist = { fire = -0.15, ice = 0, poison = -0.15, water = 0, arcane = 0.30, physical = 0 },
    },
    abyssal_titan = {
        name = "深渊巨人", hp = 800, atk = 35, speed = 8, def = 48,
        atkInterval = 2.0, element = "physical",
        sporeCloud = { atkSpeedReducePct = 0.25, duration = 5.0 },
        hpRegen = 0.025, hpRegenInterval = 5.0,
        expDrop = 2000, dropTemplate = "common",
        image = "Textures/mobs/mob_abyssal_titan_20260310091724.png", radius = 22,
        color = { 60, 40, 80 },
        resist = { fire = 0, ice = 0, poison = -0.25, water = 0, arcane = 0.20, physical = 0.30 },
    },
    shadow_oracle = {
        name = "暗影神谕", hp = 280, atk = 60, speed = 38, def = 16,
        atkInterval = 1.3, element = "arcane",
        isRanged = true, antiHeal = true,
        healAura = { pct = 0.06, interval = 7.0, radius = 110 },
        expDrop = 1500, dropTemplate = "common",
        image = "Textures/mobs/mob_shadow_oracle_20260310091708.png", radius = 16,
        color = { 140, 60, 200 },
        resist = { fire = -0.20, ice = 0, poison = 0, water = -0.15, arcane = 0.40, physical = 0 },
    },
    boss_abyss_general = {
        name = "深渊魔将·暗噬者", hp = 576000, atk = 340, speed = 20, def = 45,
        atkInterval = 2.0, element = "arcane", antiHeal = true,
        slowOnHit = 0.35, slowDuration = 2.0,
        barrage = { interval = 8.0, count = 10, dmgMul = 0.7, element = "arcane" },
        iceArmor = { hpThreshold = 0.50, dmgReduce = 0.55, duration = 5.0, cd = 14.0 },
        summon = { interval = 12.0, monsterId = "abyss_shade", count = 3 },
        expDrop = 55000, dropTemplate = "miniboss",
        image = "Textures/mobs/mob_boss_abyss_general_20260310091649.png", radius = 40,
        color = { 120, 50, 200 }, isBoss = true,
        resist = { fire = -0.25, ice = 0, poison = -0.15, water = 0, arcane = 0.50, physical = 0.10 },
    },
    boss_abyss_lord = {
        name = "深渊君王·虚无之主", hp = 1280000, atk = 450, speed = 12, def = 65,
        atkInterval = 2.0, element = "arcane", antiHeal = true,
        slowOnHit = 0.40, slowDuration = 2.5,
        dragonBreath = { interval = 10.0, dmgMul = 1.2, element = "arcane" },
        frozenField = { hpThreshold = 0.60, slowRate = 0.50, duration = 8.0, cd = 16.0 },
        iceArmor = { hpThreshold = 0.40, dmgReduce = 0.60, duration = 5.0, cd = 13.0 },
        iceRegen = { hpThreshold = 0.20, regenPct = 0.025 },
        expDrop = 70000, dropTemplate = "boss",
        image = "Textures/mobs/mob_boss_abyss_lord_20260310091656.png", radius = 45,
        color = { 140, 40, 220 }, isBoss = true,
        resist = { fire = -0.20, ice = 0.10, poison = -0.20, water = 0, arcane = 0.50, physical = 0.15 },
    },

    -- ==================== 第十一章: 焚天炼狱 ====================
    pyre_imp = {
        name = "焚炎小鬼", hp = 75, atk = 50, speed = 70, def = 3,
        atkInterval = 1.0, element = "fire",
        packBonus = 0.40, packThreshold = 4,
        expDrop = 1100, dropTemplate = "common",
        image = "Textures/mobs/mob_pyre_imp_20260310091844.png", radius = 14,
        color = { 255, 120, 30 },
        resist = { fire = 0.40, ice = -0.25, poison = 0, water = -0.15, arcane = 0, physical = -0.10 },
    },
    inferno_blade = {
        name = "炼狱刀客", hp = 110, atk = 68, speed = 66, def = 6,
        atkInterval = 0.9, element = "fire",
        defPierce = 0.45, firstStrikeMul = 2.5,
        expDrop = 1300, dropTemplate = "common",
        image = "Textures/mobs/mob_inferno_blade_20260310091854.png", radius = 15,
        color = { 220, 100, 20 },
        resist = { fire = 0.35, ice = -0.20, poison = 0, water = -0.15, arcane = 0, physical = 0 },
    },
    molten_golem = {
        name = "熔金傀儡", hp = 350, atk = 48, speed = 22, def = 28,
        atkInterval = 1.5, element = "physical",
        slowOnHit = 0.40, slowDuration = 2.0,
        hpRegen = 0.025, hpRegenInterval = 5.0,
        expDrop = 1600, dropTemplate = "common",
        image = "Textures/mobs/mob_molten_golem_20260310091840.png", radius = 19,
        color = { 200, 160, 40 },
        resist = { fire = 0.30, ice = -0.15, poison = 0, water = -0.25, arcane = 0, physical = 0.25 },
    },
    hellfire_caster = {
        name = "狱火法师", hp = 200, atk = 62, speed = 40, def = 12,
        atkInterval = 1.2, element = "fire",
        isRanged = true, lifesteal = 0.18,
        healAura = { pct = 0.05, interval = 6.0, radius = 100 },
        expDrop = 1400, dropTemplate = "common",
        image = "Textures/mobs/mob_hellfire_caster_20260310091830.png", radius = 15,
        color = { 255, 80, 30 },
        resist = { fire = 0.45, ice = -0.25, poison = -0.10, water = 0, arcane = 0, physical = -0.10 },
    },
    cinder_wraith = {
        name = "余烬亡魂", hp = 90, atk = 55, speed = 76, def = 1,
        atkInterval = 0.9, element = "fire",
        deathExplode = { element = "fire", dmgMul = 1.3, radius = 55 },
        packBonus = 0.30, packThreshold = 5,
        expDrop = 1200, dropTemplate = "common",
        image = "Textures/mobs/mob_cinder_wraith_20260310091839.png", radius = 13,
        color = { 180, 100, 40 },
        resist = { fire = 0.30, ice = -0.30, poison = 0, water = -0.15, arcane = 0, physical = 0 },
    },
    scorch_knight = {
        name = "灼焰骑士", hp = 160, atk = 65, speed = 50, def = 8,
        atkInterval = 1.1, element = "fire",
        venomStack = { dmgPctPerStack = 0.03, stackMax = 5, duration = 5.0 },
        expDrop = 1300, dropTemplate = "common",
        image = "Textures/mobs/mob_scorch_knight_20260310091857.png", radius = 16,
        color = { 240, 110, 20 },
        resist = { fire = 0.30, ice = -0.15, poison = -0.15, water = 0, arcane = 0, physical = 0 },
    },
    purgatory_giant = {
        name = "炼狱巨兽", hp = 900, atk = 40, speed = 6, def = 56,
        atkInterval = 2.0, element = "physical",
        sporeCloud = { atkSpeedReducePct = 0.30, duration = 5.0 },
        hpRegen = 0.025, hpRegenInterval = 5.0,
        expDrop = 2400, dropTemplate = "common",
        image = "Textures/mobs/mob_purgatory_giant_20260310091828.png", radius = 22,
        color = { 180, 130, 30 },
        resist = { fire = 0.20, ice = 0, poison = -0.25, water = -0.15, arcane = 0, physical = 0.30 },
    },
    flame_hierophant = {
        name = "烈焰祭司", hp = 320, atk = 68, speed = 36, def = 17,
        atkInterval = 1.3, element = "fire",
        isRanged = true, antiHeal = true,
        healAura = { pct = 0.07, interval = 7.0, radius = 120 },
        expDrop = 1800, dropTemplate = "common",
        image = "Textures/mobs/mob_flame_hierophant_20260310091853.png", radius = 16,
        color = { 255, 140, 40 },
        resist = { fire = 0.40, ice = -0.20, poison = 0, water = -0.20, arcane = 0, physical = 0 },
    },
    boss_inferno_general = {
        name = "炼狱将军·焚骨者", hp = 704000, atk = 400, speed = 18, def = 52,
        atkInterval = 2.0, element = "fire", antiHeal = true,
        slowOnHit = 0.35, slowDuration = 2.0,
        barrage = { interval = 7.0, count = 12, dmgMul = 0.75, element = "fire" },
        iceArmor = { hpThreshold = 0.50, dmgReduce = 0.60, duration = 5.0, cd = 13.0 },
        summon = { interval = 10.0, monsterId = "pyre_imp", count = 3 },
        expDrop = 65000, dropTemplate = "miniboss",
        image = "Textures/mobs/mob_boss_inferno_general_20260310091831.png", radius = 42,
        color = { 255, 100, 20 }, isBoss = true,
        resist = { fire = 0.50, ice = -0.25, poison = 0.10, water = -0.20, arcane = 0, physical = 0.10 },
    },
    boss_pyre_sovereign = {
        name = "焚天帝主·灭世之焰", hp = 1600000, atk = 520, speed = 10, def = 75,
        atkInterval = 2.0, element = "fire", antiHeal = true,
        slowOnHit = 0.45, slowDuration = 2.5,
        dragonBreath = { interval = 9.0, dmgMul = 1.3, element = "fire" },
        frozenField = { hpThreshold = 0.55, slowRate = 0.55, duration = 8.0, cd = 15.0 },
        iceArmor = { hpThreshold = 0.35, dmgReduce = 0.65, duration = 6.0, cd = 12.0 },
        iceRegen = { hpThreshold = 0.18, regenPct = 0.03 },
        expDrop = 85000, dropTemplate = "boss",
        image = "Textures/mobs/mob_boss_pyre_sovereign_20260310091909.png", radius = 48,
        color = { 255, 160, 30 }, isBoss = true,
        resist = { fire = 0.50, ice = -0.20, poison = 0.10, water = -0.15, arcane = 0, physical = 0.20 },
    },

    -- ==================== 第十二章: 时渊回廊 ====================
    -- 蜂群
    chrono_mite = {
        name = "时隙蜉蝣", hp = 95, atk = 62, speed = 72, def = 4,
        atkInterval = 1.0, element = "arcane",
        packBonus = 0.45, packThreshold = 4,
        expDrop = 1100, dropTemplate = "common",
        image = "Textures/mobs/mob_chrono_mite_20260311050719.png", radius = 10,
        color = { 140, 80, 200 },
        resist = { fire = -0.25, ice = 0, poison = 0, water = 0, arcane = 0.40, physical = -0.15 },
    },
    -- 高速刺客
    rewind_assassin = {
        name = "回溯刺客", hp = 130, atk = 82, speed = 70, def = 8,
        atkInterval = 0.9, element = "arcane",
        defPierce = 0.50, firstStrikeMul = 2.8,
        expDrop = 1400, dropTemplate = "common",
        image = "Textures/mobs/mob_rewind_assassin_20260311050743.png", radius = 14,
        color = { 120, 60, 180 },
        resist = { fire = -0.20, ice = 0, poison = 0, water = -0.10, arcane = 0.35, physical = -0.20 },
    },
    -- 肉盾
    eternal_sentinel = {
        name = "永恒哨卫", hp = 450, atk = 55, speed = 20, def = 33,
        atkInterval = 1.5, element = "physical",
        slowOnHit = 0.40, slowDuration = 2.0,
        hpRegen = 0.03, hpRegenInterval = 5.0,
        expDrop = 1600, dropTemplate = "common",
        image = "Textures/mobs/mob_eternal_sentinel_20260311050745.png", radius = 18,
        color = { 80, 100, 180 },
        resist = { fire = -0.15, ice = 0, poison = -0.20, water = 0, arcane = 0.30, physical = 0.30 },
    },
    -- 远程精英
    chrono_mage = {
        name = "时序术士", hp = 250, atk = 75, speed = 38, def = 14,
        atkInterval = 1.2, element = "arcane",
        isRanged = true, lifesteal = 0.20,
        expDrop = 1500, dropTemplate = "common",
        image = "Textures/mobs/mob_chrono_mage_20260311050720.png", radius = 15,
        color = { 160, 80, 220 },
        resist = { fire = -0.20, ice = 0.10, poison = -0.15, water = 0, arcane = 0.45, physical = -0.10 },
    },
    -- 自爆脆皮
    rift_phantom = {
        name = "时裂游魂", hp = 110, atk = 65, speed = 78, def = 2,
        atkInterval = 0.9, element = "arcane",
        deathExplode = { element = "arcane", dmgMul = 1.5, radius = 58 },
        packBonus = 0.35, packThreshold = 5,
        expDrop = 1200, dropTemplate = "common",
        image = "Textures/mobs/mob_rift_phantom_20260311050716.png", radius = 12,
        color = { 150, 90, 210 },
        resist = { fire = -0.25, ice = 0, poison = 0, water = 0, arcane = 0.35, physical = 0 },
    },
    -- 控制精英
    stasis_spider = {
        name = "迟滞蛛母", hp = 190, atk = 72, speed = 45, def = 11,
        atkInterval = 1.1, element = "arcane",
        venomStack = { dmgPctPerStack = 0.04, stackMax = 6, duration = 5.0 },
        slowOnHit = 0.35, slowDuration = 2.5,
        expDrop = 1300, dropTemplate = "common",
        image = "Textures/mobs/mob_stasis_spider_20260311050557.png", radius = 16,
        color = { 130, 70, 190 },
        resist = { fire = -0.20, ice = 0, poison = -0.15, water = 0, arcane = 0.35, physical = 0 },
    },
    -- 超级肉盾
    epoch_colossus = {
        name = "时渊巨像", hp = 1100, atk = 48, speed = 6, def = 68,
        atkInterval = 2.0, element = "physical",
        sporeCloud = { atkSpeedReducePct = 0.35, duration = 5.0 },
        hpRegen = 0.03, hpRegenInterval = 5.0,
        expDrop = 2800, dropTemplate = "common",
        image = "Textures/mobs/mob_epoch_colossus_20260311050558.png", radius = 24,
        color = { 100, 80, 160 },
        resist = { fire = -0.15, ice = 0, poison = -0.25, water = 0, arcane = 0.25, physical = 0.35 },
    },
    -- 远程祭司
    aeon_hierophant = {
        name = "永劫祭司", hp = 400, atk = 80, speed = 34, def = 20,
        atkInterval = 1.3, element = "arcane",
        isRanged = true, antiHeal = true,
        healAura = { pct = 0.08, interval = 7.0, radius = 120 },
        expDrop = 2000, dropTemplate = "common",
        image = "Textures/mobs/mob_aeon_hierophant_20260311050620.png", radius = 16,
        color = { 180, 100, 240 },
        resist = { fire = -0.20, ice = 0, poison = 0, water = -0.15, arcane = 0.45, physical = 0 },
    },
    -- 中章Boss
    boss_rift_lord = {
        name = "时空裂主·弗拉克图斯", hp = 896000, atk = 480, speed = 18, def = 62,
        atkInterval = 2.0, element = "arcane", antiHeal = true,
        slowOnHit = 0.40, slowDuration = 2.0,
        barrage = { interval = 7.0, count = 14, dmgMul = 0.80, element = "arcane" },
        iceArmor = { hpThreshold = 0.50, dmgReduce = 0.62, duration = 5.0, cd = 13.0 },
        summon = { interval = 10.0, monsterId = "chrono_mite", count = 4 },
        expDrop = 75000, dropTemplate = "miniboss",
        image = "Textures/mobs/mob_boss_rift_lord_20260311050623.png", radius = 44,
        color = { 160, 90, 220 }, isBoss = true,
        resist = { fire = -0.25, ice = 0.10, poison = 0.10, water = -0.15, arcane = 0.50, physical = -0.15 },
    },
    -- 章末Boss
    boss_chrono_sovereign = {
        name = "永恒钟主·克洛诺斯", hp = 2048000, atk = 620, speed = 10, def = 90,
        atkInterval = 2.0, element = "arcane", antiHeal = true,
        slowOnHit = 0.50, slowDuration = 2.5,
        dragonBreath = { interval = 9.0, dmgMul = 1.5, element = "arcane" },
        frozenField = { hpThreshold = 0.55, slowRate = 0.58, duration = 8.0, cd = 15.0 },
        chronoDecay = { hpThreshold = 0.55, atkSpdReducePerSec = 0.05, maxReduce = 0.50 },
        iceArmor = { hpThreshold = 0.35, dmgReduce = 0.68, duration = 6.0, cd = 12.0 },
        iceRegen = { hpThreshold = 0.18, regenPct = 0.035 },
        expDrop = 100000, dropTemplate = "boss",
        image = "Textures/mobs/mob_boss_chrono_sovereign_20260311050617.png", radius = 50,
        color = { 180, 110, 240 }, isBoss = true,
        resist = { fire = -0.20, ice = 0.10, poison = 0.10, water = -0.10, arcane = 0.55, physical = -0.10 },
    },

    -- ==================== 第十三章: 寒渊冰域 ====================
    -- 蜂群: 霜蚀虫群
    frost_mite = {
        name = "霜蚀虫群", hp = 115, atk = 75, speed = 74, def = 4,
        atkInterval = 1.0, element = "ice",
        slowOnHit = 0.15, slowDuration = 1.5,
        packBonus = 0.50, packThreshold = 4,
        expDrop = 10, dropTemplate = "common",
        image = "Textures/mobs/frost_mite.png", radius = 14,
        color = { 100, 200, 230 },
        resist = { fire = -0.30, ice = 0.40, poison = -0.10, water = 0.25, arcane = 0, physical = -0.15 },
    },
    -- 高速刺客: 冰棘猎手
    ice_stalker = {
        name = "冰棘猎手", hp = 155, atk = 98, speed = 72, def = 9,
        atkInterval = 1.2, element = "ice",
        defPierce = 0.55, firstStrikeMul = 3.0,
        expDrop = 14, dropTemplate = "common",
        image = "Textures/mobs/ice_stalker.png", radius = 13,
        color = { 120, 210, 240 },
        resist = { fire = -0.25, ice = 0.35, poison = -0.15, water = 0.20, arcane = 0, physical = -0.10 },
    },
    -- 肉盾: 永冻巨兽
    permafrost_beast = {
        name = "永冻巨兽", hp = 540, atk = 66, speed = 18, def = 40,
        atkInterval = 2.0, element = "physical", antiHeal = true,
        iceArmor = { hpThreshold = 0.60, dmgReduce = 0.25, duration = 5.0, cd = 10.0 },
        hpRegen = 0.03, hpRegenInterval = 5.0,
        expDrop = 22, dropTemplate = "elite",
        image = "Textures/mobs/permafrost_beast.png", radius = 20,
        color = { 140, 190, 210 },
        resist = { fire = -0.20, ice = 0.30, poison = -0.20, water = 0.15, arcane = 0, physical = 0.30 },
    },
    -- 远程精英: 冰川术士
    glacier_caster = {
        name = "冰川术士", hp = 300, atk = 90, speed = 36, def = 17,
        atkInterval = 1.5, element = "water", isRanged = true,
        lifesteal = 0.22,
        slowOnHit = 0.25, slowDuration = 2.0,
        expDrop = 20, dropTemplate = "elite",
        image = "Textures/mobs/glacier_caster.png", radius = 16,
        color = { 80, 170, 240 },
        resist = { fire = -0.25, ice = 0.35, poison = 0, water = 0.40, arcane = -0.15, physical = 0 },
    },
    -- 自爆脆皮: 冰晶爆破者
    cryo_wraith = {
        name = "冰晶爆破者", hp = 135, atk = 78, speed = 76, def = 3,
        atkInterval = 1.0, element = "ice",
        deathExplode = { element = "ice", dmgMul = 1.6, radius = 55 },
        expDrop = 12, dropTemplate = "common",
        image = "Textures/mobs/cryo_wraith.png", radius = 14,
        color = { 130, 220, 255 },
        resist = { fire = -0.30, ice = 0.35, poison = 0, water = 0.20, arcane = -0.10, physical = 0 },
    },
    -- 控制精英: 霜织蛛
    rime_weaver = {
        name = "霜织蛛", hp = 230, atk = 86, speed = 43, def = 13,
        atkInterval = 1.4, element = "water",
        slowOnHit = 0.40, slowDuration = 3.0,
        venomStack = { dmgPctPerStack = 0.025, stackMax = 6, duration = 5.0 },
        expDrop = 16, dropTemplate = "elite",
        image = "Textures/mobs/rime_weaver.png", radius = 15,
        color = { 90, 180, 220 },
        resist = { fire = -0.25, ice = 0.30, poison = -0.20, water = 0.30, arcane = 0, physical = 0 },
    },
    -- 超级肉盾: 冰渊泰坦
    glacial_titan = {
        name = "冰渊泰坦", hp = 1320, atk = 58, speed = 5, def = 80,
        atkInterval = 2.2, element = "physical", antiHeal = true,
        iceArmor = { hpThreshold = 0.50, dmgReduce = 0.30, duration = 6.0, cd = 12.0 },
        hpRegen = 0.03, hpRegenInterval = 4.0,
        expDrop = 28, dropTemplate = "elite",
        image = "Textures/mobs/glacial_titan.png", radius = 24,
        color = { 100, 180, 200 },
        resist = { fire = -0.20, ice = 0.25, poison = -0.25, water = 0.15, arcane = 0, physical = 0.35 },
    },
    -- 远程精英: 冰潮祭司
    frostfall_priest = {
        name = "冰潮祭司", hp = 480, atk = 96, speed = 32, def = 24,
        atkInterval = 1.6, element = "water", isRanged = true, antiHeal = true,
        healAura = { pct = 0.06, interval = 7.0, radius = 110 },
        expDrop = 24, dropTemplate = "elite",
        image = "Textures/mobs/frostfall_priest.png", radius = 16,
        color = { 70, 160, 230 },
        resist = { fire = -0.25, ice = 0.35, poison = 0, water = 0.45, arcane = -0.15, physical = 0 },
    },
    -- 中Boss: 霜暴领主·格拉西恩 (新模板系统, 2阶段)
    boss_frost_lord = {
        name = "霜暴领主·格拉西恩", hp = 1088000, atk = 576, speed = 16, def = 74,
        atkInterval = 2.0, element = "ice", isBoss = true,
        expDrop = 85000, dropTemplate = "miniboss",
        image = "Textures/mobs/boss_frost_lord.png", radius = 44,
        color = { 80, 190, 255 },
        resist = { fire = -0.30, ice = 0.50, poison = -0.20, water = 0.35, arcane = 0.10, physical = -0.10 },
        -- 新模板系统: phases 阶段技能配置
        phases = {
            -- 阶段一 (100%→55%): 弹幕风暴
            {
                hpThreshold = 1.0,
                skills = {
                    { template = "ATK_barrage",  params = { count = 16, spread = 120, dmgMul = 0.85, speed = 200, interval = 6.0, onHit = { slow = 0.10, slowDuration = 1.5 } } },
                    { template = "ATK_spikes",   params = { count = 3, radius = 35, delay = 1.2, dmgMul = 1.2, lingerTime = 4.0, interval = 8.0, lingerEffect = { slow = 0.30 } } },
                    { template = "SUM_minion",   params = { monsterId = "frost_mite", count = 5, interval = 9.0 } },
                },
                transition = { hpThreshold = 0.55, duration = 1.0, text = "霜暴领域！" },
            },
            -- 阶段二 (55%→0%): 冰原领域
            {
                hpThreshold = 0.55,
                skills = {
                    { template = "ATK_barrage",  params = { count = 20, spread = 90, dmgMul = 0.85, speed = 220, interval = 6.0, onHit = { slow = 0.10, slowDuration = 1.5 } } },
                    { template = "CTL_field",    params = { radius = 120, dmgMul = 0.30, tickRate = 0.5, duration = 8.0, cd = 14.0, effect = { slow = 0.40 } } },
                    { template = "DEF_armor",    params = { hpThreshold = 0.45, dmgReduce = 0.65, duration = 5.0, cd = 13.0 } },
                    { template = "DEF_crystal",  params = { count = 2, hpPct = 0.02, healPct = 0.015, spawnInterval = 12.0, spawnRadius = 80, onDestroy = { dmgMul = 0.5, radius = 40, element = "ice" } } },
                },
            },
        },
    },
    -- 章末Boss: 冰渊至尊·尼弗海姆 (新模板系统, 3阶段)
    boss_ice_sovereign = {
        name = "冰渊至尊·尼弗海姆", hp = 2496000, atk = 745, speed = 9, def = 108,
        atkInterval = 2.2, element = "ice", isBoss = true,
        expDrop = 120000, dropTemplate = "boss",
        image = "Textures/mobs/boss_ice_sovereign.png", radius = 50,
        color = { 60, 170, 240 },
        resist = { fire = -0.25, ice = 0.60, poison = -0.15, water = 0.40, arcane = -0.10, physical = 0.10 },
        -- 新模板系统: phases 阶段技能配置
        phases = {
            -- 阶段一 (100%→60%): 寒潮试探
            {
                hpThreshold = 1.0,
                skills = {
                    { template = "ATK_breath",   params = { angle = 60, range = 150, dmgMul = 0.50, tickRate = 0.3, duration = 1.5, interval = 8.0, onHit = { frostbite = 0.05 } } },
                    { template = "ATK_pulse",    params = { speed = 80, width = 20, maxRadius = 200, dmgMul = 0.8, hitEffect = "stun", hitDuration = 0.5, interval = 10.0 } },
                    { template = "SUM_guard",    params = { count = 2, hpPct = 0.01, atkMul = 0.4, tauntWeight = 0.6, interval = 15.0, aura = { slow = 0.20, radius = 40 } } },
                },
                transition = { hpThreshold = 0.60, duration = 1.5, text = "绝对零度！" },
            },
            -- 阶段二 (60%→30%): 空间压缩
            {
                hpThreshold = 0.60,
                skills = {
                    { template = "ATK_breath",   params = { angle = 90, range = 150, dmgMul = 0.65, tickRate = 0.3, duration = 1.5, interval = 8.0, onHit = { frostbite = 0.05 } } },
                    { template = "CTL_field",    params = { radius = 140, dmgMul = 0.35, tickRate = 0.5, duration = 10.0, cd = 16.0, effect = { slow = 0.55 } } },
                    { template = "CTL_barrier",  params = { count = 2, duration = 6.0, contactDmgMul = 0.3, interval = 14.0, onContact = { freeze = 1.0 } } },
                    { template = "CTL_decay",    params = { stat = "moveSpeed", reducePerSec = 0.02, maxReduce = 0.30, bonusOnHit = 0.05 } },
                    { template = "DEF_shield",   params = {
                        hpPct = 0.03, bossDmgReduce = 0.80, duration = 10.0, cd = 18.0, hpThreshold = 0.50, baseResist = 0.50,
                        shield_reaction = {
                            weakReaction = "melt", weakElement = "fire", weakMultiplier = 3.0,
                            wrongHitEffects = {
                                ice     = { shieldHeal = 0.05, bossHeal = 0.02 },
                                water   = { reflect = 0.30 },
                                physical = { atkSpeedReduce = 0.15, duration = 3.0 },
                                arcane  = { dmgFactor = 0.7 },
                                poison  = { dmgFactor = 0.5, dotOnSelf = 0.01 },
                            },
                            timeoutPenalty = { type = "bossHeal", healPct = 0.15 },
                        },
                    } },
                },
                transition = { hpThreshold = 0.30, duration = 2.0, text = "万物终将冰封！" },
            },
            -- 阶段三 (30%→0%): 永冻绞杀
            {
                hpThreshold = 0.30,
                skills = {
                    { template = "DEF_armor",    params = { hpThreshold = 0.30, dmgReduce = 0.72, duration = 7.0, cd = 14.0 } },
                    { template = "DEF_regen",    params = { hpThreshold = 0.30, regenPct = 0.03 } },
                    { template = "CTL_vortex",   params = { radius = 100, pullSpeed = 30, coreDmgMul = 0.6, coreRadius = 30, duration = 4.0, interval = 12.0, coreEffect = { freeze = 1.0 } } },
                    { template = "ATK_detonate", params = { count = 4, hpPct = 0.008, timer = 8.0, dmgMul = 2.0, bossHealPct = 0.10, interval = 0, onExplode = { freeze = 2.0 } } },
                },
            },
        },
    },

    -- ==================== 第十四章: 腐蚀魔域 ====================
    -- 蜂群: 瘟蚀虫群
    plague_mite = {
        name = "瘟蚀虫群", hp = 138, atk = 90, speed = 76, def = 5,
        atkInterval = 1.0, element = "poison",
        packBonus = 0.55, packThreshold = 4,
        deathExplode = { element = "poison", dmgMul = 0.4, radius = 25 },
        expDrop = 12, dropTemplate = "common",
        image = "Textures/mobs/plague_mite.png", radius = 14,
        color = { 80, 180, 60 },
        resist = { fire = -0.30, ice = -0.20, poison = 0.40, water = 0.25, arcane = 0, physical = -0.10 },
    },
    -- 高速刺客: 毒刺猎手
    venom_stalker = {
        name = "毒刺猎手", hp = 186, atk = 118, speed = 74, def = 11,
        atkInterval = 1.2, element = "poison",
        defPierce = 0.60, firstStrikeMul = 3.0,
        corrosion = { defReducePct = 0.03, stackMax = 3, duration = 6.0 },
        expDrop = 16, dropTemplate = "common",
        image = "Textures/mobs/venom_stalker.png", radius = 13,
        color = { 100, 200, 70 },
        resist = { fire = -0.25, ice = -0.15, poison = 0.35, water = 0.20, arcane = 0, physical = -0.10 },
    },
    -- 肉盾: 腐朽巨兽
    rot_beast = {
        name = "腐朽巨兽", hp = 650, atk = 79, speed = 18, def = 46,
        atkInterval = 2.0, element = "physical", antiHeal = true,
        hpRegen = 0.03, hpRegenInterval = 5.0,
        expDrop = 26, dropTemplate = "elite",
        image = "Textures/mobs/rot_beast.png", radius = 20,
        color = { 100, 160, 60 },
        resist = { fire = -0.20, ice = -0.15, poison = 0.30, water = 0.15, arcane = 0, physical = 0.30 },
    },
    -- 远程精英: 枯萎术士
    blight_caster = {
        name = "枯萎术士", hp = 360, atk = 108, speed = 36, def = 20,
        atkInterval = 1.5, element = "poison", isRanged = true,
        lifesteal = 0.24,
        venomStack = { dmgPctPerStack = 0.012, stackMax = 5, duration = 6.0 },
        expDrop = 22, dropTemplate = "elite",
        image = "Textures/mobs/blight_caster.png", radius = 16,
        color = { 90, 170, 50 },
        resist = { fire = -0.25, ice = -0.10, poison = 0.40, water = 0.30, arcane = -0.15, physical = 0 },
    },
    -- 自爆脆皮: 孢子爆破者
    spore_wraith = {
        name = "孢子爆破者", hp = 162, atk = 94, speed = 78, def = 4,
        atkInterval = 1.0, element = "poison",
        deathExplode = { element = "poison", dmgMul = 1.8, radius = 55 },
        expDrop = 14, dropTemplate = "common",
        image = "Textures/mobs/spore_wraith.png", radius = 14,
        color = { 110, 200, 80 },
        resist = { fire = -0.30, ice = -0.15, poison = 0.35, water = 0.20, arcane = -0.10, physical = 0 },
    },
    -- 控制精英: 瘴毒蛛母
    miasma_weaver = {
        name = "瘴毒蛛母", hp = 276, atk = 103, speed = 43, def = 16,
        atkInterval = 1.4, element = "poison",
        venomStack = { dmgPctPerStack = 0.015, stackMax = 6, duration = 6.0 },
        corrosion = { defReducePct = 0.03, stackMax = 4, duration = 6.0 },
        expDrop = 18, dropTemplate = "elite",
        image = "Textures/mobs/miasma_weaver.png", radius = 15,
        color = { 120, 160, 80 },
        resist = { fire = -0.25, ice = -0.15, poison = 0.30, water = 0.25, arcane = 0, physical = 0 },
    },
    -- 超级肉盾: 瘟疫泰坦
    plague_titan = {
        name = "瘟疫泰坦", hp = 1580, atk = 70, speed = 5, def = 94,
        atkInterval = 2.2, element = "physical", antiHeal = true,
        hpRegen = 0.03, hpRegenInterval = 4.0,
        expDrop = 32, dropTemplate = "elite",
        image = "Textures/mobs/plague_titan.png", radius = 24,
        color = { 80, 150, 50 },
        resist = { fire = -0.20, ice = -0.15, poison = 0.25, water = 0.15, arcane = 0, physical = 0.35 },
    },
    -- 远程祭司: 毒雾祭司
    toxin_priest = {
        name = "毒雾祭司", hp = 576, atk = 115, speed = 32, def = 28,
        atkInterval = 1.6, element = "poison", isRanged = true, antiHeal = true,
        healAura = { pct = 0.05, interval = 7.0, radius = 110 },
        expDrop = 28, dropTemplate = "elite",
        image = "Textures/mobs/toxin_priest.png", radius = 16,
        color = { 70, 180, 60 },
        resist = { fire = -0.25, ice = -0.10, poison = 0.40, water = 0.35, arcane = -0.15, physical = 0 },
    },
    -- 中Boss: 剧毒母巢·维诺莎 (新模板系统, 2阶段)
    boss_venom_mother = {
        name = "剧毒母巢·维诺莎", hp = 1312000, atk = 690, speed = 18, def = 89,
        atkInterval = 1.8, element = "poison", isBoss = true,
        expDrop = 102000, dropTemplate = "miniboss",
        image = "Textures/mobs/boss_venom_mother.png", radius = 44,
        color = { 80, 200, 60 },
        resist = { fire = -0.30, ice = -0.20, poison = 0.50, water = 0.30, arcane = 0.10, physical = -0.10 },
        phases = {
            -- 阶段一 (100%→55%): 毒潮侵袭
            {
                hpThreshold = 1.0,
                skills = {
                    { template = "ATK_barrage", params = {
                        count = 18, spread = 140, dmgMul = 0.70, speed = 190, interval = 5.5,
                        onHit = function(bs, source)
                            GS().ApplyVenomStackDebuff(0.015, 8, 6.0)
                        end,
                    }},
                    { template = "ATK_spikes", params = {
                        count = 4, radius = 30, delay = 1.0, dmgMul = 1.0, lingerTime = 5.0, interval = 7.0,
                        lingerEffect = { slow = 0.20 },
                        lingerOnTick = function(bs, source)
                            GS().ApplyVenomStackDebuff(0.015, 8, 6.0)
                        end,
                    }},
                    { template = "SUM_minion", params = { monsterId = "plague_mite", count = 6, interval = 8.0 } },
                },
                transition = { hpThreshold = 0.55, duration = 1.0, text = "毒巢觉醒！" },
            },
            -- 阶段二 (55%→0%): 毒巢领域
            {
                hpThreshold = 0.55,
                skills = {
                    { template = "ATK_barrage", params = {
                        count = 14, spread = 360, dmgMul = 0.70, speed = 160, interval = 6.0,
                        onHit = function(bs, source)
                            GS().ApplyVenomStackDebuff(0.015, 8, 6.0)
                        end,
                    }},
                    { template = "CTL_field", params = {
                        radius = 110, dmgMul = 0.25, tickRate = 0.5, duration = 7.0, cd = 13.0,
                        effect = function(bs, source)
                            GS().ApplyVenomStackDebuff(0.015, 8, 6.0)
                            GS().ApplyAntiHeal(0.50, 1.0)
                        end,
                    }},
                    { template = "DEF_armor", params = { hpThreshold = 0.40, dmgReduce = 0.60, duration = 5.0, cd = 12.0 } },
                    { template = "DEF_crystal", params = {
                        count = 2, hpPct = 0.018, healPct = 0.012, spawnInterval = 11.0, spawnRadius = 90,
                        onDestroy = function(bs, source)
                            -- 摧毁毒腺图腾: 清除玩家3层蚀毒
                            local gs = GS()
                            gs.venomStackCount = math.max(0, gs.venomStackCount - 3)
                            if gs.venomStackCount == 0 then
                                gs.venomStackTimer = 0
                                gs.venomStackDmgPct = 0
                                gs.venomStackMaxStacks = 0
                                gs.venomStackTickCD = 0
                            end
                        end,
                    }},
                },
            },
        },
    },
    -- 章末Boss: 腐蚀主宰·涅克洛斯 (新模板系统, 3阶段)
    boss_plague_sovereign = {
        name = "腐蚀主宰·涅克洛斯", hp = 3008000, atk = 895, speed = 10, def = 130,
        atkInterval = 2.2, element = "poison", isBoss = true,
        expDrop = 144000, dropTemplate = "boss",
        image = "Textures/mobs/boss_plague_sovereign.png", radius = 50,
        color = { 60, 180, 40 },
        resist = { fire = -0.25, ice = -0.15, poison = 0.60, water = 0.35, arcane = -0.10, physical = 0.10 },
        phases = {
            -- 阶段一 (100%→60%): 腐蚀试探
            {
                hpThreshold = 1.0,
                skills = {
                    { template = "ATK_breath", params = {
                        angle = 70, range = 160, dmgMul = 0.45, tickRate = 0.3, duration = 1.8, interval = 7.0,
                        onHit = function(bs, source)
                            GS().ApplyCorrosionDebuff(0.04, 10, 8.0)
                        end,
                    }},
                    { template = "ATK_spikes", params = {
                        count = 3, radius = 35, delay = 1.2, dmgMul = 1.1, lingerTime = 5.0, interval = 9.0,
                        lingerEffect = function(bs, source)
                            GS().ApplyAntiHeal(0.40, 1.0)
                        end,
                    }},
                    { template = "SUM_guard", params = { count = 2, hpPct = 0.012, atkMul = 0.35, tauntWeight = 0.55, interval = 14.0 } },
                },
                transition = { hpThreshold = 0.60, duration = 1.5, text = "万物腐朽！" },
            },
            -- 阶段二 (60%→30%): 腐朽侵蚀
            {
                hpThreshold = 0.60,
                skills = {
                    { template = "ATK_breath", params = {
                        angle = 100, range = 160, dmgMul = 0.55, tickRate = 0.3, duration = 1.8, interval = 7.0,
                        onHit = function(bs, source)
                            GS().ApplyCorrosionDebuff(0.04, 10, 8.0)
                        end,
                    }},
                    { template = "CTL_decay", params = { stat = "def", reducePerSec = 0.015, maxReduce = 0.40, bonusOnHit = 0.04 } },
                    { template = "CTL_barrier", params = {
                        count = 2, duration = 7.0, contactDmgMul = 0.35, interval = 13.0,
                        onContact = function(bs, source)
                            GS().ApplyCorrosionDebuff(0.04, 10, 8.0)
                            GS().ApplyCorrosionDebuff(0.04, 10, 8.0)
                            GS().ApplyCorrosionDebuff(0.04, 10, 8.0)
                        end,
                    }},
                    { template = "CTL_field", params = {
                        radius = 130, dmgMul = 0.30, tickRate = 0.5, duration = 9.0, cd = 15.0,
                        effect = function(bs, source)
                            GS().ApplyCorrosionDebuff(0.04, 10, 8.0)
                            GS().ApplyAntiHeal(0.60, 1.0)
                        end,
                    }},
                    { template = "DEF_shield", params = {
                        hpPct = 0.035, bossDmgReduce = 0.80, duration = 10.0, cd = 20.0, hpThreshold = 0.50, baseResist = 0.50,
                        shield_reaction = {
                            weakReaction = "purify", weakElement = "fire", weakMultiplier = 2.5,
                            wrongHitEffects = {
                                poison   = { shieldHeal = 0.08, bossHeal = 0.02 },
                                water    = { spreadPoison = true, aoeRadius = 60 },
                                ice      = { dmgFactor = 0.6, slowSelf = 0.20 },
                                physical = { corrosion = 0.05, maxStack = 5 },
                                arcane   = { dmgFactor = 0.65 },
                            },
                            timeoutPenalty = { type = "bossBuff", atkBonus = 0.30, duration = 8.0 },
                        },
                    }},
                },
                transition = { hpThreshold = 0.30, duration = 2.0, text = "一切终将腐朽！" },
            },
            -- 阶段三 (30%→0%): 腐朽终焉
            {
                hpThreshold = 0.30,
                skills = {
                    { template = "DEF_armor", params = { hpThreshold = 0.30, dmgReduce = 0.70, duration = 7.0, cd = 15.0 } },
                    { template = "DEF_regen", params = { hpThreshold = 0.30, regenPct = 0.025 } },
                    { template = "CTL_vortex", params = {
                        radius = 110, pullSpeed = 35, coreDmgMul = 0.55, coreRadius = 35, duration = 4.5, interval = 11.0,
                        coreEffect = function(bs, source)
                            GS().ApplyCorrosionDebuff(0.04, 10, 8.0)
                            GS().ApplyCorrosionDebuff(0.04, 10, 8.0)
                            GS().ApplyAntiHeal(0.80, 1.0)
                        end,
                    }},
                    { template = "ATK_detonate", params = {
                        count = 3, hpPct = 0.01, timer = 9.0, dmgMul = 2.2, bossHealPct = 0.08, interval = 0,
                        onExplode = function(bs, source)
                            GS().ApplyAntiHeal(1.0, 5.0)
                            -- 全场毒伤5s由antiHeal覆盖，DoT通过venomStack实现
                            GS().ApplyVenomStackDebuff(0.005, 1, 5.0) -- 0.5% maxHP/秒持续5s
                        end,
                    }},
                },
            },
        },
    },

    -- ==================== 第十五章: 天火之泉 ====================
    -- 蜂群: 烈焰小鬼
    flame_imp = {
        name = "烈焰小鬼", hp = 166, atk = 108, speed = 76, def = 6,
        atkInterval = 1.0, element = "fire",
        packBonus = 0.50, packThreshold = 4,
        deathExplode = { element = "fire", dmgMul = 0.4, radius = 20 },
        expDrop = 14, dropTemplate = "common",
        image = "Textures/mobs/flame_imp.png", radius = 14,
        color = { 240, 80, 30 },
        resist = { water = -0.30, ice = -0.20, fire = 0.40, poison = 0.25, arcane = 0, physical = -0.10 },
    },
    -- 高速刺客: 灼刃猎手
    ember_stalker = {
        name = "灼刃猎手", hp = 223, atk = 142, speed = 74, def = 13,
        atkInterval = 1.2, element = "fire",
        defPierce = 0.55, firstStrikeMul = 3.0,
        burnStack = { dmgPct = 0.018, atkSpdReduce = 0.03, maxStacks = 8, duration = 5.0 },
        expDrop = 19, dropTemplate = "common",
        image = "Textures/mobs/ember_stalker.png", radius = 13,
        color = { 255, 120, 40 },
        resist = { water = -0.25, ice = -0.15, fire = 0.35, poison = 0.20, arcane = 0, physical = -0.10 },
    },
    -- 肉盾: 熔岩巨兽
    magma_beast = {
        name = "熔岩巨兽", hp = 780, atk = 95, speed = 18, def = 62,
        atkInterval = 2.0, element = "fire",
        damageReflect = { element = "fire", pct = 0.15 },
        expDrop = 31, dropTemplate = "elite",
        image = "Textures/mobs/magma_beast.png", radius = 20,
        color = { 200, 60, 20 },
        resist = { water = -0.20, ice = -0.15, fire = 0.30, poison = 0.15, arcane = 0, physical = 0.30 },
    },
    -- 远程精英: 焚炎术士
    inferno_caster = {
        name = "焚炎术士", hp = 432, atk = 130, speed = 36, def = 24,
        atkInterval = 1.5, element = "fire", isRanged = true,
        lifesteal = 0.22,
        burnStack = { dmgPct = 0.018, atkSpdReduce = 0.03, maxStacks = 8, duration = 5.0 },
        expDrop = 26, dropTemplate = "elite",
        image = "Textures/mobs/inferno_caster.png", radius = 16,
        color = { 255, 100, 30 },
        resist = { water = -0.25, ice = -0.10, fire = 0.40, poison = 0.30, arcane = -0.15, physical = 0 },
    },
    -- 自爆脆皮: 余烬爆破者
    cinder_wraith = {
        name = "余烬爆破者", hp = 194, atk = 113, speed = 78, def = 5,
        atkInterval = 1.0, element = "fire",
        deathExplode = { element = "fire", dmgMul = 2.0, radius = 55 },
        burnStack = { dmgPct = 0.018, atkSpdReduce = 0.03, maxStacks = 8, duration = 5.0 },
        expDrop = 17, dropTemplate = "common",
        image = "Textures/mobs/cinder_wraith.png", radius = 14,
        color = { 255, 140, 50 },
        resist = { water = -0.30, ice = -0.15, fire = 0.35, poison = 0.20, arcane = -0.10, physical = 0 },
    },
    -- 控制精英: 狱火编织者
    hellfire_weaver = {
        name = "狱火编织者", hp = 331, atk = 124, speed = 43, def = 19,
        atkInterval = 1.4, element = "fire",
        burnStack = { dmgPct = 0.018, atkSpdReduce = 0.03, maxStacks = 8, duration = 5.0 },
        scorchOnHit = { dmgAmpPct = 0.03, maxStacks = 10, duration = 8.0 },
        expDrop = 22, dropTemplate = "elite",
        image = "Textures/mobs/hellfire_weaver.png", radius = 15,
        color = { 220, 70, 40 },
        resist = { water = -0.25, ice = -0.15, fire = 0.30, poison = 0.25, arcane = 0, physical = 0 },
    },
    -- 超级肉盾: 焰狱泰坦
    flame_titan = {
        name = "焰狱泰坦", hp = 1680, atk = 84, speed = 5, def = 125,
        atkInterval = 2.2, element = "fire",
        burnAura = { radius = 50, interval = 1.0 },
        expDrop = 38, dropTemplate = "elite",
        image = "Textures/mobs/flame_titan.png", radius = 24,
        color = { 180, 50, 20 },
        resist = { water = -0.20, ice = -0.15, fire = 0.25, poison = 0.15, arcane = 0, physical = 0.35 },
    },
    -- 远程祭司: 焚祭司
    pyre_priest = {
        name = "焚祭司", hp = 691, atk = 138, speed = 32, def = 34,
        atkInterval = 1.6, element = "fire", isRanged = true,
        healAura = { pct = 0.06, interval = 7.0, radius = 110 },
        scorchOnHit = { dmgAmpPct = 0.03, maxStacks = 10, duration = 8.0 },
        expDrop = 34, dropTemplate = "elite",
        image = "Textures/mobs/pyre_priest.png", radius = 16,
        color = { 200, 90, 30 },
        resist = { water = -0.25, ice = -0.10, fire = 0.40, poison = 0.35, arcane = -0.15, physical = 0 },
    },
    -- 中Boss: 灼翼领主·伊格尼斯 (新模板系统, 2阶段)
    boss_flame_lord = {
        name = "灼翼领主·伊格尼斯", hp = 1574400, atk = 828, speed = 20, def = 107,
        atkInterval = 1.6, element = "fire", isBoss = true,
        expDrop = 122000, dropTemplate = "miniboss",
        image = "Textures/mobs/boss_flame_lord.png", radius = 44,
        color = { 240, 80, 30 },
        resist = { water = -0.30, ice = -0.20, fire = 0.50, poison = 0.30, arcane = 0.10, physical = -0.10 },
        phases = {
            -- 阶段一 (100%→55%): 烈焰洗礼
            {
                hpThreshold = 1.0,
                skills = {
                    { template = "ATK_barrage", params = {
                        count = 20, spread = 150, dmgMul = 0.75, speed = 200, interval = 5.0,
                        onHit = function(bs, source)
                            GS().ApplyBlazeDebuff(0.018, 0.03, 8, 5.0, source.atk)
                        end,
                    }},
                    { template = "ATK_spikes", params = {
                        count = 5, radius = 32, delay = 1.0, dmgMul = 1.1, lingerTime = 6.0, interval = 7.0,
                        lingerOnTick = function(bs, source)
                            GS().ApplyBlazeDebuff(0.018, 0.03, 8, 5.0, source.atk)
                        end,
                    }},
                    { template = "SUM_minion", params = { monsterId = "flame_imp", count = 5, interval = 8.0 } },
                },
                transition = { hpThreshold = 0.55, duration = 1.0, text = "烈焰燃尽一切！" },
            },
            -- 阶段二 (55%→0%): 焰翼领域
            {
                hpThreshold = 0.55,
                skills = {
                    { template = "ATK_barrage", params = {
                        count = 16, spread = 360, dmgMul = 0.75, speed = 170, interval = 6.0,
                        onHit = function(bs, source)
                            GS().ApplyBlazeDebuff(0.018, 0.03, 8, 5.0, source.atk)
                        end,
                    }},
                    { template = "CTL_field", params = {
                        radius = 120, dmgMul = 0.30, tickRate = 0.5, duration = 8.0, cd = 13.0,
                        effect = function(bs, source)
                            GS().ApplyBlazeDebuff(0.018, 0.03, 8, 5.0, source.atk)
                            GS().ApplyAntiHeal(0.40, 1.0)
                        end,
                    }},
                    { template = "DEF_armor", params = { hpThreshold = 0.40, dmgReduce = 0.55, duration = 5.0, cd = 12.0 } },
                    { template = "DEF_crystal", params = {
                        count = 2, hpPct = 0.02, healPct = 0.015, spawnInterval = 11.0, spawnRadius = 85,
                        onDestroy = function(bs, source)
                            -- 摧毁焰核: 清除玩家3层灼烧
                            local gs = GS()
                            gs.blazeStacks = math.max(0, gs.blazeStacks - 3)
                            if gs.blazeStacks == 0 then
                                gs.blazeTimer = 0
                                gs.blazeDmgPct = 0
                                gs.blazeAtkSpdReduce = 0
                                gs.blazeMaxStacks = 0
                                gs.blazeTickCD = 0
                                gs.blazeBossAtk = 0
                            end
                        end,
                    }},
                },
            },
        },
    },
    -- 章末Boss: 焚天魔君·萨拉曼德 (新模板系统, 3阶段)
    boss_inferno_sovereign = {
        name = "焚天魔君·萨拉曼德", hp = 3609600, atk = 1074, speed = 12, def = 156,
        atkInterval = 2.0, element = "fire", isBoss = true,
        expDrop = 173000, dropTemplate = "boss",
        image = "Textures/mobs/boss_inferno_sovereign.png", radius = 50,
        color = { 255, 60, 20 },
        resist = { water = -0.25, ice = -0.15, fire = 0.60, poison = 0.35, arcane = -0.10, physical = 0.10 },
        phases = {
            -- 阶段一 (100%→60%): 灼热试探
            {
                hpThreshold = 1.0,
                skills = {
                    { template = "ATK_breath", params = {
                        angle = 75, range = 165, dmgMul = 0.50, tickRate = 0.3, duration = 2.0, interval = 7.0,
                        onHit = function(bs, source)
                            GS().ApplyScorchDebuff(0.03, 10, 8.0)
                        end,
                    }},
                    { template = "ATK_spikes", params = {
                        count = 4, radius = 35, delay = 1.0, dmgMul = 1.2, lingerTime = 6.0, interval = 8.0,
                        lingerEffect = function(bs, source)
                            GS().ApplyAntiHeal(0.40, 1.0)
                        end,
                    }},
                    { template = "SUM_guard", params = {
                        count = 2, hpPct = 0.014, atkMul = 0.40, tauntWeight = 0.55, interval = 13.0,
                        scorchOnHit = { dmgAmpPct = 0.03, maxStacks = 10, duration = 8.0 },
                    }},
                },
                transition = { hpThreshold = 0.60, duration = 1.5, text = "焦土焚天！" },
            },
            -- 阶段二 (60%→30%): 焦土碾压
            {
                hpThreshold = 0.60,
                skills = {
                    { template = "ATK_breath", params = {
                        angle = 105, range = 165, dmgMul = 0.60, tickRate = 0.3, duration = 2.0, interval = 7.0,
                        onHit = function(bs, source)
                            GS().ApplyScorchDebuff(0.03, 10, 8.0)
                        end,
                    }},
                    { template = "CTL_decay", params = { stat = "atkSpeed", reducePerSec = 0.018, maxReduce = 0.35, bonusOnHit = 0.04 } },
                    { template = "CTL_barrier", params = {
                        count = 2, duration = 7.0, contactDmgMul = 0.40, interval = 12.0,
                        onContact = function(bs, source)
                            GS().ApplyScorchDebuff(0.03, 10, 8.0)
                            GS().ApplyScorchDebuff(0.03, 10, 8.0)
                            GS().ApplyScorchDebuff(0.03, 10, 8.0)
                        end,
                    }},
                    { template = "CTL_field", params = {
                        radius = 135, dmgMul = 0.35, tickRate = 0.5, duration = 9.0, cd = 15.0,
                        effect = function(bs, source)
                            GS().ApplyScorchDebuff(0.03, 10, 8.0)
                            GS().ApplyAntiHeal(0.55, 1.0)
                        end,
                    }},
                    { template = "DEF_shield", params = {
                        hpPct = 0.04, bossDmgReduce = 0.80, duration = 10.0, cd = 20.0, hpThreshold = 0.50, baseResist = 0.50,
                        shield_reaction = {
                            weakReaction = "quench", weakElement = "water", weakMultiplier = 2.8,
                            wrongHitEffects = {
                                fire     = { shieldHeal = 0.10, bossHeal = 0.03 },
                                poison   = { dmgFactor = 0.5, dotOnSelf = 0.015 },
                                ice      = { dmgFactor = 0.7, scorchSelf = 2 },
                                physical = { reflect = 0.25, atkSpeedReduce = 0.10 },
                                arcane   = { dmgFactor = 0.60 },
                            },
                            timeoutPenalty = { type = "explode", dmgMul = 1.5, scorchStacks = 5 },
                        },
                    }},
                },
                transition = { hpThreshold = 0.30, duration = 2.0, text = "万物终将化为灰烬！" },
            },
            -- 阶段三 (30%→0%): 焚天终焉
            {
                hpThreshold = 0.30,
                skills = {
                    { template = "DEF_armor", params = { hpThreshold = 0.30, dmgReduce = 0.68, duration = 6.0, cd = 14.0 } },
                    { template = "DEF_regen", params = { hpThreshold = 0.30, regenPct = 0.028 } },
                    { template = "CTL_vortex", params = {
                        radius = 115, pullSpeed = 38, coreDmgMul = 0.60, coreRadius = 35, duration = 4.5, interval = 11.0,
                        coreEffect = function(bs, source)
                            GS().ApplyScorchDebuff(0.03, 10, 8.0)
                            GS().ApplyScorchDebuff(0.03, 10, 8.0)
                        end,
                    }},
                    { template = "ATK_detonate", params = {
                        count = 3, hpPct = 0.012, timer = 8.0, dmgMul = 2.4, bossHealPct = 0.09, interval = 0,
                        onExplode = function(bs, source)
                            -- 焚天风暴: 6s全场火伤 + 攻速-50% + 5层焚灼
                            for i = 1, 5 do
                                GS().ApplyScorchDebuff(0.03, 10, 8.0)
                            end
                        end,
                    }},
                },
            },
        },
    },

    -- ==================== 第16章: 深渊潮汐 (water) ====================
    -- 蜂群: 潮汐蟹群
    tidal_crab = {
        name = "潮汐蟹群", hp = 200, atk = 130, speed = 74, def = 8,
        atkInterval = 1.0, element = "water",
        packBonus = 0.48, packThreshold = 4,
        deathExplode = { element = "water", dmgMul = 0.4, radius = 18 },
        drenchStack = { perStack = 1, duration = 6.0, maxStacks = 8 },
        expDrop = 17, dropTemplate = "common",
        image = "Textures/mobs/tidal_crab.png", radius = 14,
        color = { 30, 90, 200 },
        resist = { fire = -0.20, ice = -0.25, poison = 0, water = 0.35, arcane = -0.15, physical = 0 },
    },
    -- 精锐打手: 深渊刺鳐
    abyssal_stingray = {
        name = "深渊刺鳐", hp = 268, atk = 170, speed = 72, def = 16,
        atkInterval = 0.9, element = "water",
        defPierce = 0.55, firstStrikeMul = 3.0,
        drenchStack = { perStack = 1, duration = 6.0, maxStacks = 8 },
        expDrop = 23, dropTemplate = "common",
        image = "Textures/mobs/abyssal_stingray.png", radius = 13,
        color = { 60, 40, 160 },
        resist = { fire = -0.15, ice = -0.25, poison = 0, water = 0.30, arcane = -0.20, physical = 0 },
    },
    -- 坦克肉盾: 珊瑚巨龟
    coral_tortoise = {
        name = "珊瑚巨龟", hp = 936, atk = 114, speed = 16, def = 75,
        atkInterval = 1.6, element = "water",
        hpRegen = 0.025, hpRegenInterval = 5.0,
        slowOnHit = 0.40, slowDuration = 2.0,
        expDrop = 37, dropTemplate = "elite",
        image = "Textures/mobs/coral_tortoise.png", radius = 20,
        color = { 40, 180, 160 },
        resist = { fire = -0.15, ice = -0.20, poison = -0.15, water = 0.40, arcane = 0, physical = 0.20 },
    },
    -- 远程法师: 深海巫师
    deepsea_warlock = {
        name = "深海巫师", hp = 518, atk = 156, speed = 34, def = 29,
        atkInterval = 1.2, element = "water", isRanged = true,
        lifesteal = 0.20,
        drenchStack = { perStack = 1, duration = 6.0, maxStacks = 8 },
        expDrop = 31, dropTemplate = "elite",
        image = "Textures/mobs/deepsea_warlock.png", radius = 16,
        color = { 20, 60, 140 },
        resist = { fire = -0.15, ice = -0.20, poison = -0.10, water = 0.45, arcane = -0.15, physical = 0 },
    },
    -- 自爆型: 膨胀水母
    bloat_jellyfish = {
        name = "膨胀水母", hp = 233, atk = 136, speed = 76, def = 6,
        atkInterval = 0.9, element = "water",
        deathExplode = { element = "water", dmgMul = 1.8, radius = 55 },
        packBonus = 0.35, packThreshold = 5,
        drenchStack = { perStack = 1, duration = 6.0, maxStacks = 8 },
        expDrop = 20, dropTemplate = "common",
        image = "Textures/mobs/bloat_jellyfish.png", radius = 14,
        color = { 80, 140, 220 },
        resist = { fire = -0.20, ice = -0.25, poison = 0, water = 0.30, arcane = -0.15, physical = 0 },
    },
    -- 控制型: 缠绕海蛇
    coil_serpent = {
        name = "缠绕海蛇", hp = 397, atk = 149, speed = 42, def = 23,
        atkInterval = 1.1, element = "water",
        venomStack = { dmgPctPerStack = 0.035, stackMax = 7, duration = 5.0 },
        slowOnHit = 0.35, slowDuration = 2.5,
        drenchStack = { perStack = 1, duration = 6.0, maxStacks = 8 },
        expDrop = 26, dropTemplate = "elite",
        image = "Textures/mobs/coil_serpent.png", radius = 15,
        color = { 30, 80, 170 },
        resist = { fire = -0.15, ice = -0.20, poison = 0.15, water = 0.35, arcane = -0.15, physical = 0 },
    },
    -- 超级坦克: 远古海魔
    ancient_kraken = {
        name = "远古海魔", hp = 2016, atk = 101, speed = 5, def = 150,
        atkInterval = 2.0, element = "water",
        sporeCloud = { atkSpeedReducePct = 0.30, duration = 5.0 },
        hpRegen = 0.025, hpRegenInterval = 5.0,
        expDrop = 46, dropTemplate = "elite",
        image = "Textures/mobs/ancient_kraken.png", radius = 24,
        color = { 40, 30, 120 },
        resist = { fire = -0.10, ice = -0.15, poison = -0.15, water = 0.40, arcane = 0, physical = 0.25 },
    },
    -- 精英祭司: 潮汐祭司
    tide_hierophant = {
        name = "潮汐祭司", hp = 830, atk = 166, speed = 30, def = 41,
        atkInterval = 1.3, element = "water", isRanged = true,
        antiHeal = true,
        healAura = { pct = 0.06, interval = 7.0, radius = 115 },
        drenchStack = { perStack = 1, duration = 6.0, maxStacks = 8 },
        expDrop = 41, dropTemplate = "elite",
        image = "Textures/mobs/tide_hierophant.png", radius = 16,
        color = { 50, 120, 200 },
        resist = { fire = -0.15, ice = -0.20, poison = 0, water = 0.45, arcane = -0.15, physical = 0 },
    },
    -- 中Boss: 潮涌将领·塞壬 (模板系统, 2阶段)
    boss_tide_commander = {
        name = "潮涌将领·塞壬", hp = 2952000, atk = 994, speed = 18, def = 128,
        atkInterval = 1.8, element = "water", isBoss = true,
        expDrop = 146000, dropTemplate = "miniboss",
        image = "Textures/mobs/boss_tide_commander.png", radius = 44,
        color = { 30, 90, 200 },
        resist = { fire = -0.15, ice = -0.25, poison = 0.15, water = 0.50, arcane = -0.15, physical = 0 },
        phases = {
            -- 阶段一 (100%→50%): 潮涌洗礼
            {
                hpThreshold = 1.0,
                skills = {
                    { template = "ATK_barrage", params = {
                        count = 18, spread = 140, dmgMul = 0.80, speed = 190, interval = 5.5,
                        onHit = function(bs, source)
                            GS().ApplyDrenchDebuff(1, 8, 6.0)
                        end,
                    }},
                    { template = "ATK_spikes", params = {
                        count = 5, radius = 30, delay = 1.0, dmgMul = 1.0, lingerTime = 7.0, interval = 7.0,
                        lingerOnTick = function(bs, source)
                            GS().ApplyDrenchDebuff(1, 8, 6.0)
                        end,
                    }},
                    { template = "SUM_minion", params = { monsterId = "tidal_crab", count = 5, interval = 9.0 } },
                },
                transition = { hpThreshold = 0.50, duration = 1.0, text = "潮汐将吞没一切！" },
            },
            -- 阶段二 (50%→0%): 涌潮领域
            {
                hpThreshold = 0.50,
                skills = {
                    { template = "ATK_barrage", params = {
                        count = 14, spread = 360, dmgMul = 0.80, speed = 165, interval = 6.5,
                        onHit = function(bs, source)
                            GS().ApplyDrenchDebuff(1, 8, 6.0)
                        end,
                    }},
                    { template = "CTL_field", params = {
                        radius = 115, dmgMul = 0.28, tickRate = 0.5, duration = 8.0, cd = 14.0, hpThreshold = 0.50,
                        onTick = function(bs, source)
                            GS().ApplyDrenchDebuff(1, 8, 6.0)
                        end,
                    }},
                    { template = "DEF_armor", params = {
                        hpThreshold = 0.35, dmgReduce = 0.58, duration = 5.0, cd = 12.0,
                    }},
                    { template = "DEF_crystal", params = {
                        count = 2, hpPct = 0.02, healPct = 0.015, spawnInterval = 12.0, spawnRadius = 85,
                    }},
                },
            },
        },
    },
    -- 终Boss: 万潮海主·勒维坦 (模板系统, 3阶段)
    boss_abyssal_leviathan = {
        name = "万潮海主·勒维坦", hp = 6768000, atk = 1289, speed = 10, def = 187,
        atkInterval = 2.0, element = "water", isBoss = true,
        expDrop = 208000, dropTemplate = "boss",
        image = "Textures/mobs/boss_abyssal_leviathan.png", radius = 50,
        color = { 20, 60, 180 },
        resist = { fire = -0.10, ice = -0.25, poison = 0.15, water = 0.60, arcane = -0.15, physical = 0.10 },
        phases = {
            -- 阶段一 (100%→60%): 深渊试探
            {
                hpThreshold = 1.0,
                skills = {
                    { template = "ATK_breath", params = {
                        angle = 70, range = 160, dmgMul = 0.50, tickRate = 0.3, duration = 2.0, interval = 7.0,
                        onHit = function(bs, source)
                            GS().ApplyTidalCorrosionDebuff(1, 10, 8.0)
                        end,
                    }},
                    { template = "ATK_spikes", params = {
                        count = 4, radius = 32, delay = 1.0, dmgMul = 1.1, lingerTime = 7.0, interval = 8.0,
                        lingerOnTick = function(bs, source)
                            GS().ApplyDrenchDebuff(1, 8, 6.0)
                        end,
                    }},
                    { template = "SUM_guard", params = {
                        count = 2, hpPct = 0.014, atkMul = 0.40, tauntWeight = 0.55, interval = 13.0,
                    }},
                },
                transition = { hpThreshold = 0.60, duration = 1.5, text = "深渊万潮吞噬万物！" },
            },
            -- 阶段二 (60%→30%): 深渊碾压
            {
                hpThreshold = 0.60,
                skills = {
                    { template = "ATK_breath", params = {
                        angle = 100, range = 160, dmgMul = 0.55, tickRate = 0.3, duration = 2.0, interval = 7.0,
                        onHit = function(bs, source)
                            GS().ApplyTidalCorrosionDebuff(1, 10, 8.0)
                        end,
                    }},
                    { template = "CTL_decay", params = {
                        hpThreshold = 0.60, stat = "crit", reducePerSec = 0.015, maxReduce = 0.35, bonusOnHit = 0.035,
                    }},
                    { template = "CTL_barrier", params = {
                        count = 2, duration = 7.0, contactDmgMul = 0.40, interval = 12.0,
                        onContact = function(bs, source)
                            for i = 1, 3 do
                                GS().ApplyTidalCorrosionDebuff(1, 10, 8.0)
                            end
                        end,
                    }},
                    { template = "CTL_field", params = {
                        radius = 130, dmgMul = 0.32, tickRate = 0.5, duration = 9.0, cd = 15.0, hpThreshold = 0.60,
                        onTick = function(bs, source)
                            GS().ApplyTidalCorrosionDebuff(1, 10, 8.0)
                        end,
                    }},
                    { template = "DEF_shield", params = {
                        hpPct = 0.04, bossDmgReduce = 0.80, duration = 10.0, cd = 20.0, hpThreshold = 0.50,
                        baseResist = 0.50,
                        shieldElement = "water",
                        weakReaction = "freeze", weakElement = "ice", weakMultiplier = 2.8,
                        wrongHitEffects = {
                            water    = { shieldHeal = 0.10, bossHeal = 0.03 },
                            fire     = { dmgFactor = 0.6, selfBurn = 0.012 },
                            poison   = { dmgFactor = 0.5, drenchSelf = 2 },
                            physical = { reflect = 0.20, critReduce = 0.08 },
                            arcane   = { dmgFactor = 0.65 },
                        },
                        timeoutPenalty = { type = "tsunami", dmgMul = 1.5, drenchStacks = 5 },
                    }},
                },
                transition = { hpThreshold = 0.30, duration = 2.0, text = "万潮归一，众生沉沦！" },
            },
            -- 阶段三 (30%→0%): 万潮终焉
            {
                hpThreshold = 0.30,
                skills = {
                    { template = "DEF_armor", params = {
                        hpThreshold = 0.30, dmgReduce = 0.65, duration = 6.0, cd = 14.0,
                    }},
                    { template = "DEF_regen", params = {
                        hpThreshold = 0.30, regenPct = 0.026,
                    }},
                    { template = "CTL_vortex", params = {
                        radius = 110, pullSpeed = 36, coreDmgMul = 0.55, coreRadius = 32, duration = 4.5, interval = 11.0,
                        onCoreTick = function(bs, source)
                            for i = 1, 2 do
                                GS().ApplyTidalCorrosionDebuff(1, 10, 8.0)
                            end
                        end,
                    }},
                    { template = "ATK_detonate", params = {
                        count = 3, hpPct = 0.012, timer = 8.0, dmgMul = 2.2, bossHealPct = 0.08, interval = 0,
                        onExplode = function(bs, source)
                            -- 万潮海啸: 6s全场水伤 + 5层潮蚀
                            for i = 1, 5 do
                                GS().ApplyTidalCorrosionDebuff(1, 10, 8.0)
                            end
                        end,
                    }},
                },
            },
        },
    },
    -- ==================== 第17章: 焰息回廊 (fire) ====================
    -- 复用第一章「灰烬荒原」怪物结构, 数值按章节17系数缩放
    -- 蜂群: 焰息蜂虫
    ember_swarm = {
        name = "焰息蜂虫", hp = 230, atk = 148, speed = 58, def = 9,
        atkInterval = 1.1, element = "fire",
        packBonus = 0.45, packThreshold = 4,
        deathExplode = { element = "fire", dmgMul = 0.35, radius = 16 },
        expDrop = 19, dropTemplate = "common",
        image = "Textures/mobs/ash_rat.png", radius = 14,
        color = { 200, 120, 40 },
        resist = { fire = 0.35, ice = -0.25, poison = -0.15, water = -0.20, arcane = -0.15, physical = 0 },
    },
    -- 肉盾: 熔壳蠕虫
    molten_worm = {
        name = "熔壳蠕虫", hp = 560, atk = 125, speed = 22, def = 45,
        atkInterval = 1.4, element = "fire", antiHeal = true,
        hpRegen = 0.02, hpRegenInterval = 5.0,
        expDrop = 28, dropTemplate = "common",
        image = "Textures/mobs/rot_worm.png", radius = 16,
        color = { 180, 80, 30 },
        resist = { fire = 0.40, ice = -0.25, poison = -0.15, water = -0.20, arcane = 0, physical = 0.15 },
    },
    -- 脆皮高速: 灰烬蝙蝠
    cinder_bat = {
        name = "灰烬蝙蝠", hp = 140, atk = 165, speed = 78, def = 4,
        atkInterval = 0.8, element = "fire",
        defPierce = 0.50,
        expDrop = 15, dropTemplate = "common",
        image = "Textures/mobs/void_bat.png", radius = 12,
        color = { 255, 100, 30 },
        resist = { fire = 0.30, ice = -0.30, poison = 0, water = -0.25, arcane = -0.20, physical = 0 },
    },
    -- 精英打手: 焰卫劫匪
    flame_bandit = {
        name = "焰卫劫匪", hp = 420, atk = 175, speed = 44, def = 30,
        atkInterval = 1.0, element = "fire",
        burnOnHit = { dmgPctPerTick = 0.02, tickInterval = 1.0, duration = 4.0 },
        expDrop = 32, dropTemplate = "elite",
        image = "Textures/mobs/bandit.png", radius = 16,
        color = { 220, 140, 50 },
        resist = { fire = 0.35, ice = -0.20, poison = -0.10, water = -0.15, arcane = -0.15, physical = 0.10 },
    },
    -- 减速毒菇: 焰孢菇
    ember_shroom = {
        name = "焰孢菇", hp = 380, atk = 140, speed = 26, def = 20,
        atkInterval = 1.0, element = "fire", antiHeal = true,
        slowOnHit = 0.35, slowDuration = 2.5,
        sporeCloud = { atkSpeedReducePct = 0.20, duration = 4.0 },
        expDrop = 24, dropTemplate = "common",
        image = "Textures/mobs/spore_shroom.png", radius = 14,
        color = { 200, 160, 40 },
        resist = { fire = 0.35, ice = -0.25, poison = 0.15, water = -0.20, arcane = -0.10, physical = 0 },
    },
    -- 中速跳跃: 焰蛙
    magma_frog = {
        name = "焰蛙", hp = 320, atk = 155, speed = 48, def = 18,
        atkInterval = 1.0, element = "fire",
        slowOnHit = 0.25, slowDuration = 1.5,
        burnOnHit = { dmgPctPerTick = 0.015, tickInterval = 1.0, duration = 3.0 },
        expDrop = 22, dropTemplate = "common",
        image = "Textures/mobs/swamp_frog.png", radius = 15,
        color = { 230, 100, 30 },
        resist = { fire = 0.35, ice = -0.25, poison = -0.10, water = -0.20, arcane = -0.15, physical = 0 },
    },
    -- 水元素对应: 焰灵
    fire_wisp = {
        name = "焰灵", hp = 180, atk = 138, speed = 54, def = 8,
        atkInterval = 1.0, element = "fire",
        burnOnHit = { dmgPctPerTick = 0.01, tickInterval = 1.0, duration = 3.0 },
        expDrop = 16, dropTemplate = "common",
        image = "Textures/mobs/water_spirit.png", radius = 13,
        color = { 255, 160, 40 },
        resist = { fire = 0.35, ice = -0.30, poison = 0, water = -0.25, arcane = -0.15, physical = 0 },
    },
    -- 水系肉盾对应: 熔岩甲蟹
    lava_crab = {
        name = "熔岩甲蟹", hp = 650, atk = 130, speed = 28, def = 55,
        atkInterval = 1.3, element = "fire",
        slowOnHit = 0.30, slowDuration = 2.0,
        hpRegen = 0.02, hpRegenInterval = 5.0,
        expDrop = 34, dropTemplate = "elite",
        image = "Textures/mobs/tide_crab.png", radius = 17,
        color = { 200, 80, 20 },
        resist = { fire = 0.40, ice = -0.20, poison = -0.15, water = -0.20, arcane = 0, physical = 0.20 },
    },
    -- 中Boss: 焰息守卫·炎魔
    boss_ember_guard = {
        name = "焰息守卫·炎魔", hp = 3400000, atk = 1080, speed = 20, def = 140,
        atkInterval = 1.8, element = "fire", isBoss = true,
        expDrop = 168000, dropTemplate = "miniboss",
        image = "Textures/mobs/boss_corrupt_guard.png", radius = 44,
        color = { 220, 100, 30 },
        resist = { fire = 0.50, ice = -0.25, poison = -0.15, water = -0.20, arcane = -0.15, physical = 0 },
        phases = {
            -- 阶段一 (100%→50%): 焰息风暴
            {
                hpThreshold = 1.0,
                skills = {
                    { template = "ATK_barrage", params = {
                        count = 16, spread = 130, dmgMul = 0.85, speed = 185, interval = 5.5,
                    }},
                    { template = "ATK_spikes", params = {
                        count = 5, radius = 28, delay = 1.0, dmgMul = 1.0, lingerTime = 6.0, interval = 7.0,
                    }},
                    { template = "SUM_minion", params = { monsterId = "ember_swarm", count = 5, interval = 9.0 } },
                },
                transition = { hpThreshold = 0.50, duration = 1.0, text = "烈焰将焚尽一切！" },
            },
            -- 阶段二 (50%→0%): 焚天领域
            {
                hpThreshold = 0.50,
                skills = {
                    { template = "ATK_barrage", params = {
                        count = 12, spread = 360, dmgMul = 0.85, speed = 160, interval = 6.5,
                    }},
                    { template = "CTL_field", params = {
                        radius = 110, dmgMul = 0.30, tickRate = 0.5, duration = 7.0, cd = 14.0, hpThreshold = 0.50,
                    }},
                    { template = "DEF_armor", params = {
                        hpThreshold = 0.35, dmgReduce = 0.55, duration = 5.0, cd = 12.0,
                    }},
                    { template = "DEF_crystal", params = {
                        count = 2, hpPct = 0.02, healPct = 0.015, spawnInterval = 12.0, spawnRadius = 80,
                    }},
                },
            },
        },
    },
    -- 终Boss: 灰烬巨像·炎狱
    boss_ember_golem = {
        name = "灰烬巨像·炎狱", hp = 7800000, atk = 1400, speed = 12, def = 200,
        atkInterval = 2.0, element = "fire", isBoss = true,
        expDrop = 240000, dropTemplate = "boss",
        image = "Textures/mobs/boss_golem.png", radius = 50,
        color = { 200, 80, 20 },
        resist = { fire = 0.60, ice = -0.25, poison = -0.15, water = -0.15, arcane = -0.15, physical = 0.10 },
        phases = {
            -- 阶段一 (100%→60%): 灰烬试探
            {
                hpThreshold = 1.0,
                skills = {
                    { template = "ATK_breath", params = {
                        angle = 70, range = 155, dmgMul = 0.55, tickRate = 0.3, duration = 2.0, interval = 7.0,
                    }},
                    { template = "ATK_spikes", params = {
                        count = 4, radius = 30, delay = 1.0, dmgMul = 1.1, lingerTime = 7.0, interval = 8.0,
                    }},
                    { template = "SUM_guard", params = {
                        count = 2, hpPct = 0.014, atkMul = 0.40, tauntWeight = 0.55, interval = 13.0,
                    }},
                },
                transition = { hpThreshold = 0.60, duration = 1.5, text = "灰烬燃尽天地！" },
            },
            -- 阶段二 (60%→30%): 焚天碾压
            {
                hpThreshold = 0.60,
                skills = {
                    { template = "ATK_breath", params = {
                        angle = 100, range = 155, dmgMul = 0.60, tickRate = 0.3, duration = 2.0, interval = 7.0,
                    }},
                    { template = "CTL_decay", params = {
                        hpThreshold = 0.60, stat = "crit", reducePerSec = 0.015, maxReduce = 0.35, bonusOnHit = 0.035,
                    }},
                    { template = "CTL_barrier", params = {
                        count = 2, duration = 7.0, contactDmgMul = 0.40, interval = 12.0,
                    }},
                    { template = "CTL_field", params = {
                        radius = 125, dmgMul = 0.35, tickRate = 0.5, duration = 9.0, cd = 15.0, hpThreshold = 0.60,
                    }},
                    { template = "DEF_shield", params = {
                        hpPct = 0.04, bossDmgReduce = 0.80, duration = 10.0, cd = 20.0, hpThreshold = 0.50,
                        baseResist = 0.50,
                        shieldElement = "fire",
                        weakReaction = "melt", weakElement = "water", weakMultiplier = 2.8,
                        wrongHitEffects = {
                            fire     = { shieldHeal = 0.10, bossHeal = 0.03 },
                            water    = { dmgFactor = 0.6, selfBurn = 0.012 },
                            ice      = { dmgFactor = 0.7 },
                            poison   = { dmgFactor = 0.5 },
                            physical = { reflect = 0.20, critReduce = 0.08 },
                            arcane   = { dmgFactor = 0.65 },
                        },
                        timeoutPenalty = { type = "eruption", dmgMul = 1.5 },
                    }},
                },
                transition = { hpThreshold = 0.30, duration = 2.0, text = "焰息回廊，万物成灰！" },
            },
            -- 阶段三 (30%→0%): 焰息终焉
            {
                hpThreshold = 0.30,
                skills = {
                    { template = "DEF_armor", params = {
                        hpThreshold = 0.30, dmgReduce = 0.65, duration = 6.0, cd = 14.0,
                    }},
                    { template = "DEF_regen", params = {
                        hpThreshold = 0.30, regenPct = 0.028,
                    }},
                    { template = "CTL_vortex", params = {
                        radius = 105, pullSpeed = 38, coreDmgMul = 0.60, coreRadius = 30, duration = 4.5, interval = 11.0,
                    }},
                    { template = "ATK_detonate", params = {
                        count = 3, hpPct = 0.012, timer = 8.0, dmgMul = 2.3, bossHealPct = 0.08, interval = 0,
                    }},
                },
            },
        },
    },
}

-- ============================================================================
-- 章节定义
-- 每关 2-3 波, 总血量池约 7000-12000 (1级基准, scaleMul 递增)
-- ============================================================================

-- ============================================================================
-- 关卡自动编排模板 (10关标准模式)
-- 有 families 字段的章节使用此模板自动生成 waves
-- 设计文档: docs/系统设计/怪物家族重构设计.md §6
-- ============================================================================

local STAGE_TEMPLATES = {
    -- 关1: 纯蜂群入门
    {
        pattern = "swarm_only",
        waves = {
            { roles = { { role = "swarm", count = 25, family = "primary" } } },
            { roles = { { role = "swarm", count = 30, family = "primary" } } },
        },
    },
    -- 关2: 引入肉盾
    {
        pattern = "intro_tank",
        waves = {
            { roles = { { role = "swarm", count = 20, family = "primary" }, { role = "tank", count = 6, family = "primary" } } },
            { roles = { { role = "swarm", count = 15, family = "primary" }, { role = "tank", count = 8, family = "primary" } } },
        },
    },
    -- 关3: 脆皮海
    {
        pattern = "glass_rush",
        waves = {
            { roles = { { role = "glass", count = 30, family = "primary" } } },
            { roles = { { role = "glass", count = 35, family = "primary" } } },
        },
    },
    -- 关4: 引入精英
    {
        pattern = "intro_bruiser",
        waves = {
            { roles = { { role = "swarm", count = 20, family = "primary" }, { role = "bruiser", count = 8, family = "primary" } } },
            { roles = { { role = "bruiser", count = 10, family = "primary" }, { role = "tank", count = 6, family = "primary" } } },
        },
    },
    -- 关5: 中Boss
    {
        pattern = "mid_boss",
        waves = {
            { roles = { { role = "bruiser", count = 12, family = "primary" }, { role = "tank", count = 6, family = "primary" } } },
            { roles = { { role = "boss_mid", count = 1 }, { role = "swarm", count = 20, family = "primary" } } },
        },
    },
    -- 关6: 混合（引入辅助家族）
    {
        pattern = "mixed_intro",
        waves = {
            { roles = { { role = "debuffer", count = 8, family = "primary" }, { role = "caster", count = 4, family = "secondary" }, { role = "swarm", count = 10, family = "secondary" } } },
            { roles = { { role = "swarm", count = 15, family = "secondary" }, { role = "debuffer", count = 8, family = "primary" } } },
        },
    },
    -- 关7: 减速地狱
    {
        pattern = "slow_hell",
        waves = {
            { roles = { { role = "debuffer", count = 10, family = "primary" }, { role = "tank", count = 6, family = "primary" }, { role = "swarm", count = 10, family = "secondary" } } },
            { roles = { { role = "tank", count = 8, family = "primary" }, { role = "debuffer", count = 8, family = "secondary" } } },
        },
    },
    -- 关8: 三波大混战
    {
        pattern = "triple_wave",
        waves = {
            { roles = { { role = "glass", count = 20, family = "primary" }, { role = "bruiser", count = 8, family = "secondary" } } },
            { roles = { { role = "bruiser", count = 10, family = "primary" }, { role = "tank", count = 6, family = "secondary" } } },
            { roles = { { role = "glass", count = 15, family = "secondary" }, { role = "exploder", count = 8, family = "primary" } } },
        },
    },
    -- 关9: 高密度三波
    {
        pattern = "high_density",
        waves = {
            { roles = { { role = "glass", count = 25, family = "primary" }, { role = "debuffer", count = 8, family = "secondary" } } },
            { roles = { { role = "debuffer", count = 12, family = "secondary" }, { role = "bruiser", count = 10, family = "primary" } } },
            { roles = { { role = "glass", count = 20, family = "primary" }, { role = "tank", count = 6, family = "secondary" } } },
        },
    },
    -- 关10: 终Boss
    {
        pattern = "final_boss",
        waves = {
            { roles = { { role = "swarm", count = 20, family = "primary" }, { role = "caster", count = 4, family = "primary" }, { role = "bruiser", count = 8, family = "secondary" } } },
            { roles = { { role = "boss_final", count = 1 }, { role = "swarm", count = 15, family = "secondary" }, { role = "exploder", count = 6, family = "primary" } } },
        },
    },
}

--- 自动编排：将章节配置 + 编排模板 → 10 关 waves
--- 仅对有 families 字段且无 stages 的章节调用
---@param chapterCfg table  章节配置（含 families, tagLevels, boss）
---@param chapter number    章节号
---@return table[] stages   10关配置（与手写 stages 格式完全一致）
local function generateStages(chapterCfg, chapter)
    local families = chapterCfg.families
    local primaryFamilyId  = families[1]
    local secondaryFamilyId = families[2] or families[1]
    local tagLevels = chapterCfg.tagLevels or {}

    local stages = {}
    for i, template in ipairs(STAGE_TEMPLATES) do
        local stage = { waves = {} }
        for _, waveDef in ipairs(template.waves) do
            local wave = { monsters = {} }
            for _, roleDef in ipairs(waveDef.roles) do
                if roleDef.role == "boss_mid" then
                    -- Boss 走原型解析，生成临时 ID 并注册到 MONSTERS
                    local bossConfig = chapterCfg.boss and chapterCfg.boss.mid
                    if bossConfig then
                        local bossId = BA().MakeBossId(bossConfig) .. "_ch" .. chapter
                        if not StageConfig.MONSTERS[bossId] then
                            StageConfig.MONSTERS[bossId] = BA().Resolve(bossConfig, chapter)
                        end
                        table.insert(wave.monsters, { id = bossId, count = 1 })
                    end
                elseif roleDef.role == "boss_final" then
                    local bossConfig = chapterCfg.boss and chapterCfg.boss.final
                    if bossConfig then
                        local bossId = BA().MakeBossId(bossConfig) .. "_ch" .. chapter
                        if not StageConfig.MONSTERS[bossId] then
                            StageConfig.MONSTERS[bossId] = BA().Resolve(bossConfig, chapter)
                        end
                        table.insert(wave.monsters, { id = bossId, count = 1 })
                    end
                else
                    -- 通过家族+行为模板组装怪物 ID
                    local familyId = roleDef.family == "secondary" and secondaryFamilyId or primaryFamilyId
                    local monsterId = familyId .. "_" .. roleDef.role
                    -- 惰性注册到 MONSTERS（首次访问时生成）
                    if not StageConfig.MONSTERS[monsterId] then
                        StageConfig.MONSTERS[monsterId] = MF().Resolve(familyId, roleDef.role, chapter, tagLevels)
                    end
                    table.insert(wave.monsters, { id = monsterId, count = roleDef.count })
                end
            end
            table.insert(stage.waves, wave)
        end
        table.insert(stages, stage)
    end
    return stages
end

--- 生成并缓存自动编排关卡（避免重复计算）
---@type table<number, table[]>
local generatedStagesCache_ = {}

--- 获取自动编排关卡（带缓存）
---@param chapterCfg table  章节配置
---@param chapter number    章节号
---@return table[] stages
local function getGeneratedStages(chapterCfg, chapter)
    if not generatedStagesCache_[chapter] then
        generatedStagesCache_[chapter] = generateStages(chapterCfg, chapter)
    end
    return generatedStagesCache_[chapter]
end

-- ============================================================================
-- 怪物解析接口 (供 Spawner 调用)
-- 支持三种来源: MONSTERS 表 / 家族组合ID / Boss 原型
-- ============================================================================

--- 解析怪物ID为 Spawner 兼容定义
--- 优先查 MONSTERS 表（含自动注册的家族怪和 Boss），
--- 若未命中则尝试家族解析
---@param monsterId string   怪物ID
---@param chapter? number    章节号 (家族解析时需要)
---@param tagLevels? table   章节标签等级
---@return table|nil monsterDef
function StageConfig.ResolveMonster(monsterId, chapter, tagLevels)
    -- 1. MONSTERS 表直接命中（含惰性注册的家族怪/原型Boss）
    if StageConfig.MONSTERS[monsterId] then
        return StageConfig.MONSTERS[monsterId]
    end

    -- 2. 尝试家族组合ID解析: "familyId_behaviorId"
    local def = MF().ResolveById(monsterId, chapter, tagLevels)
    if def then
        -- 惰性注册，后续访问直接命中
        StageConfig.MONSTERS[monsterId] = def
        return def
    end

    return nil
end

StageConfig.CHAPTERS = {
    -- ==================== 第一章: 灰烬荒原 ====================
    {
        id = 1,
        name = "灰烬荒原",
        desc = "焰息城外的第一步",
        lore = "焰息城的结界日渐衰弱，荒原上的裂隙不断涌出被黑暗扭曲的生物。城中长老将最后的希望寄托于一位年轻的术士——你必须穿越灰烬荒原，找到裂隙之源并将其封印。荒原曾是繁荣的农田，如今只剩枯骨与灰烬。腐化的巡逻兵在废墟中游荡，它们曾是守护这片土地的卫兵，如今却成了最危险的敌人。",
        stages = {
            -- 第1关: 荒原边缘 (纯蜂群入门)
            {
                name = "荒原边缘",
                waves = {
                    { monsters = { { id = "ash_rat", count = 25 } } },
                    { monsters = { { id = "ash_rat", count = 30 } } },
                },
                reward = { gold = 30 },
            },
            -- 第2关: 枯骨田野 (引入肉盾)
            {
                name = "枯骨田野",
                waves = {
                    { monsters = { { id = "ash_rat", count = 20 }, { id = "rot_worm", count = 6 } } },
                    { monsters = { { id = "ash_rat", count = 15 }, { id = "rot_worm", count = 8 } } },
                },
                reward = { gold = 40 },
            },
            -- 第3关: 裂隙石桥 (脆皮蝙蝠海)
            {
                name = "裂隙石桥",
                waves = {
                    { monsters = { { id = "void_bat", count = 30 } } },
                    { monsters = { { id = "void_bat", count = 35 } } },
                },
                reward = { gold = 50 },
            },
            -- 第4关: 废墟营地 (引入精英劫匪)
            {
                name = "废墟营地",
                waves = {
                    { monsters = { { id = "ash_rat", count = 20 }, { id = "bandit", count = 8 } } },
                    { monsters = { { id = "bandit", count = 10 }, { id = "rot_worm", count = 6 } } },
                },
                reward = { gold = 60 },
            },
            -- 第5关: BOSS - 腐化巡逻兵
            {
                name = "腐化巡逻兵",
                isBoss = true,
                waves = {
                    { monsters = { { id = "bandit", count = 12 }, { id = "rot_worm", count = 6 } } },
                    { monsters = { { id = "boss_corrupt_guard", count = 1 }, { id = "ash_rat", count = 20 } } },
                },
                reward = { gold = 150, guaranteeEquipQuality = 2 },
            },
            -- 第6关: 灰烬森林入口 (引入水元素, 混合蜂群)
            {
                name = "灰烬森林入口",
                waves = {
                    { monsters = { { id = "rot_worm", count = 8 }, { id = "spore_shroom", count = 8 }, { id = "water_spirit", count = 10 } } },
                    { monsters = { { id = "water_spirit", count = 15 }, { id = "rot_worm", count = 8 } } },
                },
                reward = { gold = 70 },
            },
            -- 第7关: 菌丝沼泽 (减速地狱)
            {
                name = "菌丝沼泽",
                waves = {
                    { monsters = { { id = "spore_shroom", count = 10 }, { id = "swamp_frog", count = 10 }, { id = "water_spirit", count = 8 } } },
                    { monsters = { { id = "tide_crab", count = 6 }, { id = "swamp_frog", count = 10 }, { id = "spore_shroom", count = 8 } } },
                },
                reward = { gold = 80 },
            },
            -- 第8关: 枯木深处 (三波大混战)
            {
                name = "枯木深处",
                waves = {
                    { monsters = { { id = "void_bat", count = 20 }, { id = "bandit", count = 8 } } },
                    { monsters = { { id = "bandit", count = 10 }, { id = "rot_worm", count = 8 } } },
                    { monsters = { { id = "void_bat", count = 15 }, { id = "swamp_frog", count = 10 } } },
                },
                reward = { gold = 100 },
            },
            -- 第9关: 裂隙之源 (三波高密度)
            {
                name = "裂隙之源",
                waves = {
                    { monsters = { { id = "void_bat", count = 25 }, { id = "spore_shroom", count = 8 } } },
                    { monsters = { { id = "swamp_frog", count = 12 }, { id = "bandit", count = 10 } } },
                    { monsters = { { id = "void_bat", count = 20 }, { id = "tide_crab", count = 6 } } },
                },
                reward = { gold = 120 },
            },
            -- 第10关: BOSS - 荒原巨像
            {
                name = "裂隙守卫·荒原巨像",
                isBoss = true,
                waves = {
                    { monsters = { { id = "void_bat", count = 20 }, { id = "swamp_frog", count = 10 }, { id = "bandit", count = 8 } } },
                    { monsters = { { id = "boss_golem", count = 1 }, { id = "ash_rat", count = 25 } } },
                },
                reward = { gold = 350, guaranteeEquipQuality = 3 },
            },
        },
    },
    -- ==================== 第二章: 冰封深渊 ====================
    {
        id = 2,
        name = "冰封深渊",
        desc = "永冻之地的严酷考验",
        lore = "封印灰烬荒原的裂隙后，术士追踪黑暗力量的源头来到了冰封深渊。这里曾是古代冰霜巨人的领地，千年前的一场大战将整片大陆冻结。如今沉睡的冰龙开始苏醒，它的龙息让深渊中的亡灵重新获得了力量。永冻的傀儡在冰晶洞窟中巡逻，冰霜术士在暗处编织着更大的阴谋——它们试图唤醒深渊最底层的远古冰龙·寒渊。",
        stages = {
            -- 2-1: 冰封隘口 (纯霜魔蜂群, 引入冰系减速)
            {
                name = "冰封隘口",
                waves = {
                    { monsters = { { id = "frost_imp", count = 30 } } },
                    { monsters = { { id = "frost_imp", count = 35 } } },
                },
                reward = { gold = 60 },
            },
            -- 2-2: 霜风谷地 (引入穿透DEF幽灵, HP/护盾检定)
            {
                name = "霜风谷地",
                waves = {
                    { monsters = { { id = "frost_imp", count = 20 }, { id = "ice_wraith", count = 8 } } },
                    { monsters = { { id = "ice_wraith", count = 12 }, { id = "frost_imp", count = 15 } } },
                },
                reward = { gold = 75 },
            },
            -- 2-3: 冻骨矿道 (引入高DEF甲虫, 攻击力检定)
            {
                name = "冻骨矿道",
                waves = {
                    { monsters = { { id = "glacier_beetle", count = 6 }, { id = "frost_imp", count = 20 } } },
                    { monsters = { { id = "glacier_beetle", count = 8 }, { id = "ice_wraith", count = 6 } } },
                },
                reward = { gold = 90, guaranteeEquipQuality = 1 },
            },
            -- 2-4: 雪狼巢穴 (⚠ 第一个装备墙: 狼群增伤+冰霜术士)
            {
                name = "雪狼巢穴",
                waves = {
                    { monsters = { { id = "snow_wolf", count = 15 }, { id = "frost_imp", count = 15 } } },
                    { monsters = { { id = "snow_wolf", count = 12 }, { id = "cryo_mage", count = 5 }, { id = "frost_imp", count = 10 } } },
                },
                reward = { gold = 110, guaranteeEquipQuality = 1 },
            },
            -- 2-5: BOSS - 冰晶女巫 (韧性+防御检定)
            {
                name = "冰晶女巫",
                isBoss = true,
                waves = {
                    { monsters = { { id = "cryo_mage", count = 8 }, { id = "frost_imp", count = 15 } } },
                    { monsters = { { id = "boss_ice_witch", count = 1 }, { id = "frozen_revenant", count = 6 }, { id = "frost_imp", count = 20 } } },
                },
                reward = { gold = 300, guaranteeEquipQuality = 3 },
            },
            -- 2-6: 深渊裂隙 (冰抗检定: 大量冰伤+死亡爆冰)
            {
                name = "深渊裂隙",
                waves = {
                    { monsters = { { id = "frozen_revenant", count = 10 }, { id = "cryo_mage", count = 6 } } },
                    { monsters = { { id = "cryo_mage", count = 8 }, { id = "frozen_revenant", count = 8 }, { id = "abyssal_jellyfish", count = 6 } } },
                },
                reward = { gold = 130, guaranteeEquipQuality = 2 },
            },
            -- 2-7: 水晶洞窟 (⚠ 第二个装备墙: 永冻傀儡高DEF+回血)
            {
                name = "水晶洞窟",
                waves = {
                    { monsters = { { id = "permafrost_golem", count = 4 }, { id = "abyssal_jellyfish", count = 10 } } },
                    { monsters = { { id = "permafrost_golem", count = 3 }, { id = "cryo_mage", count = 6 }, { id = "abyssal_jellyfish", count = 8 } } },
                    { monsters = { { id = "permafrost_golem", count = 5 }, { id = "frost_imp", count = 15 } } },
                },
                reward = { gold = 150, guaranteeEquipQuality = 2 },
            },
            -- 2-8: 冰封祭坛 (全种类综合考验)
            {
                name = "冰封祭坛",
                waves = {
                    { monsters = { { id = "snow_wolf", count = 12 }, { id = "glacier_beetle", count = 6 }, { id = "ice_wraith", count = 8 } } },
                    { monsters = { { id = "cryo_mage", count = 6 }, { id = "frozen_revenant", count = 8 }, { id = "abyssal_jellyfish", count = 8 } } },
                    { monsters = { { id = "permafrost_golem", count = 3 }, { id = "snow_wolf", count = 10 }, { id = "frost_imp", count = 15 } } },
                },
                reward = { gold = 180, guaranteeEquipQuality = 2 },
            },
            -- 2-9: 龙息走廊 (⚠ 第三个装备墙: 大量高DEF怪)
            {
                name = "龙息走廊",
                waves = {
                    { monsters = { { id = "permafrost_golem", count = 6 }, { id = "cryo_mage", count = 8 } } },
                    { monsters = { { id = "glacier_beetle", count = 8 }, { id = "frozen_revenant", count = 10 }, { id = "ice_wraith", count = 8 } } },
                    { monsters = { { id = "permafrost_golem", count = 4 }, { id = "cryo_mage", count = 6 }, { id = "snow_wolf", count = 12 } } },
                },
                reward = { gold = 220, guaranteeEquipQuality = 3 },
            },
            -- 2-10: BOSS - 深渊冰龙·寒渊 (全面装备检定)
            {
                name = "深渊冰龙·寒渊",
                isBoss = true,
                waves = {
                    { monsters = { { id = "cryo_mage", count = 8 }, { id = "frozen_revenant", count = 8 }, { id = "snow_wolf", count = 10 } } },
                    { monsters = { { id = "boss_frost_dragon", count = 1 }, { id = "frost_imp", count = 30 }, { id = "abyssal_jellyfish", count = 8 } } },
                },
                reward = { gold = 800, guaranteeEquipQuality = 4 },
            },
        },
    },
    -- ==================== 第三章: 熔岩炼狱 ====================
    {
        id = 3,
        name = "熔岩炼狱",
        desc = "岩浆与瘴气交织的地下深渊",
        lore = "击败冰龙后，术士发现黑暗力量的真正源头来自地底更深处——熔岩炼狱。这片被岩浆与毒瘴吞没的地下世界，曾是远古锻造之神的熔炉。炼狱之王·焚渊占据了神炉的核心，利用无尽的火焰锻造亡灵军团。熔岩蜥蜴在岩浆河畔游弋，黑曜石守卫封锁每一条通道。空气中弥漫着硫磺与死亡的气息，唯有穿越这片炼狱，才能阻止黑暗力量继续蔓延。",
        stages = {
            -- 3-1: 熔岩裂口 (纯数量压力)
            {
                name = "熔岩裂口",
                waves = {
                    { monsters = { { id = "lava_lizard", count = 35 } } },
                    { monsters = { { id = "lava_lizard", count = 35 } } },
                },
                reward = { gold = 140 },
            },
            -- 3-2: 火蛾巢穴 (穿防怪引入)
            {
                name = "火蛾巢穴",
                waves = {
                    { monsters = { { id = "volcano_moth", count = 20 }, { id = "lava_lizard", count = 15 } } },
                    { monsters = { { id = "volcano_moth", count = 20 }, { id = "lava_lizard", count = 10 } } },
                },
                reward = { gold = 170 },
            },
            -- 3-3: 毒菇矿道 (减疗+远程组合)
            {
                name = "毒菇矿道",
                waves = {
                    { monsters = { { id = "toxiflame_shroom", count = 6 }, { id = "miasma_weaver", count = 5 }, { id = "lava_lizard", count = 10 } } },
                    { monsters = { { id = "toxiflame_shroom", count = 6 }, { id = "miasma_weaver", count = 5 }, { id = "lava_lizard", count = 10 } } },
                },
                reward = { gold = 200, guaranteeEquipQuality = 1 },
            },
            -- 3-4: 蝎巢深处 ⚠️装备检定 (肉盾+狼群)
            {
                name = "蝎巢深处",
                waves = {
                    { monsters = { { id = "rock_scorpion", count = 4 }, { id = "lava_hound", count = 10 } } },
                    { monsters = { { id = "rock_scorpion", count = 4 }, { id = "lava_hound", count = 8 }, { id = "lava_lizard", count = 15 } } },
                },
                reward = { gold = 240, guaranteeEquipQuality = 1 },
            },
            -- 3-5: BOSS - 熔岩领主·烬牙
            {
                name = "熔岩领主·烬牙",
                isBoss = true,
                waves = {
                    { monsters = { { id = "molten_sprite", count = 15 }, { id = "miasma_weaver", count = 8 } } },
                    { monsters = { { id = "boss_lava_lord", count = 1 }, { id = "lava_lizard", count = 30 } } },
                },
                reward = { gold = 600, guaranteeEquipQuality = 3 },
            },
            -- 3-6: 黑曜石回廊 (高防怪+死亡爆炸)
            {
                name = "黑曜石回廊",
                waves = {
                    { monsters = { { id = "obsidian_guard", count = 5 }, { id = "volcano_moth", count = 15 } } },
                    { monsters = { { id = "obsidian_guard", count = 5 }, { id = "toxiflame_shroom", count = 8 }, { id = "volcano_moth", count = 10 } } },
                },
                reward = { gold = 280, guaranteeEquipQuality = 2 },
            },
            -- 3-7: 精灵祭坛 ⚠️装备检定 (连锁爆炸地狱)
            {
                name = "精灵祭坛",
                waves = {
                    { monsters = { { id = "molten_sprite", count = 15 }, { id = "miasma_weaver", count = 6 } } },
                    { monsters = { { id = "molten_sprite", count = 15 }, { id = "rock_scorpion", count = 4 }, { id = "miasma_weaver", count = 6 } } },
                },
                reward = { gold = 330, guaranteeEquipQuality = 2 },
            },
            -- 3-8: 炼狱熔炉 (全类型混合3波)
            {
                name = "炼狱熔炉",
                waves = {
                    { monsters = { { id = "lava_lizard", count = 20 }, { id = "volcano_moth", count = 15 }, { id = "toxiflame_shroom", count = 6 } } },
                    { monsters = { { id = "lava_hound", count = 12 }, { id = "rock_scorpion", count = 4 }, { id = "miasma_weaver", count = 8 } } },
                    { monsters = { { id = "obsidian_guard", count = 6 }, { id = "molten_sprite", count = 12 }, { id = "lava_lizard", count = 15 } } },
                },
                reward = { gold = 400, guaranteeEquipQuality = 2 },
            },
            -- 3-9: 毒火交汇 ⚠️终极难度墙
            {
                name = "毒火交汇",
                waves = {
                    { monsters = { { id = "obsidian_guard", count = 3 }, { id = "rock_scorpion", count = 3 }, { id = "lava_hound", count = 8 } } },
                    { monsters = { { id = "miasma_weaver", count = 10 }, { id = "molten_sprite", count = 12 } } },
                    { monsters = { { id = "obsidian_guard", count = 3 }, { id = "rock_scorpion", count = 3 }, { id = "lava_hound", count = 7 }, { id = "molten_sprite", count = 8 } } },
                },
                reward = { gold = 500, guaranteeEquipQuality = 3 },
            },
            -- 3-10: BOSS - 炼狱之王·焚渊 (终极Boss)
            {
                name = "炼狱之王·焚渊",
                isBoss = true,
                waves = {
                    { monsters = { { id = "obsidian_guard", count = 6 }, { id = "molten_sprite", count = 12 }, { id = "lava_hound", count = 12 } } },
                    { monsters = { { id = "boss_inferno_king", count = 1 }, { id = "miasma_weaver", count = 8 }, { id = "lava_lizard", count = 25 } } },
                },
                reward = { gold = 1500, guaranteeEquipQuality = 4 },
            },
        },
    },
    -- ==================== 第四章: 幽暗墓域 ====================
    {
        id = 4,
        name = "幽暗墓域",
        desc = "亡灵横行的地下墓穴，暗影笼罩一切",
        lore = "熔岩炼狱的尽头，一扇刻满古老符文的石门通向更深的黑暗——幽暗墓域。这里埋葬着远古王朝的君王与将军，千年来无人踏足。然而黑暗力量的侵蚀唤醒了沉眠的亡灵，墓域君王·永夜重新登上骨骸铸就的王座，统领着骸骨武士、怨灵、暗影刺客组成的不死军团。亡灵侍祭在祭坛上吟诵禁忌咒文，为死者注入永恒的诅咒之力。术士必须深入墓域核心，击败永夜，终结这片土地上的千年诅咒。",
        stages = {
            -- 4-1: 墓穴入口 (墓穴鼠蜂群)
            {
                name = "墓穴入口",
                waves = {
                    { monsters = { { id = "grave_rat", count = 35 } } },
                    { monsters = { { id = "grave_rat", count = 40 } } },
                },
                reward = { gold = 200 },
            },
            -- 4-2: 骸骨厅堂 (引入骸骨武士肉盾)
            {
                name = "骸骨厅堂",
                waves = {
                    { monsters = { { id = "grave_rat", count = 25 }, { id = "skeleton_warrior", count = 6 } } },
                    { monsters = { { id = "skeleton_warrior", count = 8 }, { id = "grave_rat", count = 20 } } },
                },
                reward = { gold = 250 },
            },
            -- 4-3: 怨灵走廊 (高穿透怨灵)
            {
                name = "怨灵走廊",
                waves = {
                    { monsters = { { id = "wraith", count = 20 }, { id = "corpse_spider", count = 8 } } },
                    { monsters = { { id = "wraith", count = 25 }, { id = "corpse_spider", count = 6 } } },
                },
                reward = { gold = 300, guaranteeEquipQuality = 1 },
            },
            -- 4-4: 侍祭祭坛 ⚠️装备检定 (治疗光环+远程)
            {
                name = "侍祭祭坛",
                waves = {
                    { monsters = { { id = "necro_acolyte", count = 5 }, { id = "skeleton_warrior", count = 8 }, { id = "grave_rat", count = 15 } } },
                    { monsters = { { id = "necro_acolyte", count = 4 }, { id = "cursed_knight", count = 4 }, { id = "wraith", count = 10 } } },
                },
                reward = { gold = 350, guaranteeEquipQuality = 1 },
            },
            -- 4-5: BOSS - 骨冠领主·厄亡
            {
                name = "骨冠领主·厄亡",
                isBoss = true,
                waves = {
                    { monsters = { { id = "skeleton_warrior", count = 10 }, { id = "necro_acolyte", count = 4 }, { id = "wraith", count = 10 } } },
                    { monsters = { { id = "boss_bone_lord", count = 1 }, { id = "grave_rat", count = 30 } } },
                },
                reward = { gold = 900, guaranteeEquipQuality = 3 },
            },
            -- 4-6: 暗影密道 (暗影刺客首击+吸血骑士)
            {
                name = "暗影密道",
                waves = {
                    { monsters = { { id = "shadow_assassin", count = 12 }, { id = "cursed_knight", count = 5 } } },
                    { monsters = { { id = "shadow_assassin", count = 10 }, { id = "bone_golem", count = 3 }, { id = "wraith", count = 8 } } },
                },
                reward = { gold = 400, guaranteeEquipQuality = 2 },
            },
            -- 4-7: 骨傀儡工坊 ⚠️装备检定 (高防+死亡爆炸)
            {
                name = "骨傀儡工坊",
                waves = {
                    { monsters = { { id = "bone_golem", count = 4 }, { id = "necro_acolyte", count = 4 }, { id = "corpse_spider", count = 8 } } },
                    { monsters = { { id = "bone_golem", count = 5 }, { id = "skeleton_warrior", count = 8 }, { id = "wraith", count = 8 } } },
                    { monsters = { { id = "bone_golem", count = 3 }, { id = "cursed_knight", count = 5 }, { id = "shadow_assassin", count = 8 } } },
                },
                reward = { gold = 500, guaranteeEquipQuality = 2 },
            },
            -- 4-8: 诅咒圣殿 (全类型综合)
            {
                name = "诅咒圣殿",
                waves = {
                    { monsters = { { id = "cursed_knight", count = 6 }, { id = "wraith", count = 10 }, { id = "corpse_spider", count = 8 } } },
                    { monsters = { { id = "necro_acolyte", count = 5 }, { id = "shadow_assassin", count = 10 }, { id = "skeleton_warrior", count = 8 } } },
                    { monsters = { { id = "bone_golem", count = 4 }, { id = "cursed_knight", count = 6 }, { id = "grave_rat", count = 20 } } },
                },
                reward = { gold = 600, guaranteeEquipQuality = 2 },
            },
            -- 4-9: 永夜深渊 ⚠️终极难度墙
            {
                name = "永夜深渊",
                waves = {
                    { monsters = { { id = "bone_golem", count = 4 }, { id = "cursed_knight", count = 6 }, { id = "shadow_assassin", count = 8 } } },
                    { monsters = { { id = "necro_acolyte", count = 5 }, { id = "wraith", count = 12 }, { id = "corpse_spider", count = 8 } } },
                    { monsters = { { id = "bone_golem", count = 3 }, { id = "cursed_knight", count = 5 }, { id = "shadow_assassin", count = 6 }, { id = "necro_acolyte", count = 3 } } },
                },
                reward = { gold = 800, guaranteeEquipQuality = 3 },
            },
            -- 4-10: BOSS - 墓域君王·永夜
            {
                name = "墓域君王·永夜",
                isBoss = true,
                waves = {
                    { monsters = { { id = "bone_golem", count = 4 }, { id = "cursed_knight", count = 6 }, { id = "shadow_assassin", count = 10 }, { id = "necro_acolyte", count = 4 } } },
                    { monsters = { { id = "boss_tomb_king", count = 1 }, { id = "wraith", count = 20 }, { id = "skeleton_warrior", count = 10 } } },
                },
                reward = { gold = 2500, guaranteeEquipQuality = 4 },
            },
        },
    },
    -- ==================== 第五章: 深海渊域 ====================
    {
        id = 5,
        name = "深海渊域",
        desc = "潮汐与深渊交织的海底世界",
        lore = "击败墓域君王后，术士追踪黑暗力量的最终源头来到了深海渊域。这片被潮汐与黑暗吞没的海底世界，曾是远古海神的领地。海渊之主·利维坦沉睡在最深处的海沟中，它的呼吸搅动着整片海域的潮汐。深海灯笼鱼在幽暗的水域中闪烁诡异的荧光，巨大的珊瑚甲卫守护着每一条通道。墨渊章鱼释放的墨汁遮蔽了一切光线，而美丽的塞壬用歌声引诱着每一个试图深入的冒险者走向毁灭。",
        stages = {
            -- 5-1: 沉船墓地 (纯蜂群适应新怪物)
            {
                name = "沉船墓地",
                waves = {
                    { monsters = { { id = "abyss_angler", count = 40 } } },
                    { monsters = { { id = "abyss_angler", count = 45 } } },
                },
                reward = { gold = 300 },
            },
            -- 5-2: 珊瑚迷宫 (引入分裂机制)
            {
                name = "珊瑚迷宫",
                waves = {
                    { monsters = { { id = "abyss_angler", count = 25 }, { id = "coral_guardian", count = 6 } } },
                    { monsters = { { id = "coral_guardian", count = 8 }, { id = "abyss_angler", count = 15 } } },
                },
                reward = { gold = 380 },
            },
            -- 5-3: 水母群落 (减速+穿透双压力)
            {
                name = "水母群落",
                waves = {
                    { monsters = { { id = "venom_jelly", count = 20 }, { id = "storm_seahorse", count = 10 } } },
                    { monsters = { { id = "storm_seahorse", count = 15 }, { id = "venom_jelly", count = 12 } } },
                },
                reward = { gold = 460, guaranteeEquipQuality = 1 },
            },
            -- 5-4: 海蛇暗礁 ⚠️装备墙1 (治疗+肉盾+吸血)
            {
                name = "海蛇暗礁",
                waves = {
                    { monsters = { { id = "sea_anemone", count = 4 }, { id = "storm_seahorse", count = 12 }, { id = "abyss_angler", count = 15 } } },
                    { monsters = { { id = "sea_anemone", count = 3 }, { id = "coral_guardian", count = 5 }, { id = "tide_merfolk", count = 5 } } },
                },
                reward = { gold = 550, guaranteeEquipQuality = 1 },
            },
            -- 5-5: BOSS - 深渊女妖·塞壬
            {
                name = "深渊女妖·塞壬",
                isBoss = true,
                waves = {
                    { monsters = { { id = "venom_jelly", count = 15 }, { id = "sea_anemone", count = 5 }, { id = "storm_seahorse", count = 10 } } },
                    { monsters = { { id = "boss_siren", count = 1 }, { id = "abyss_angler", count = 30 } } },
                },
                reward = { gold = 1400, guaranteeEquipQuality = 3 },
            },
            -- 5-6: 深渊裂谷 (腐蚀+墨汁双debuff)
            {
                name = "深渊裂谷",
                waves = {
                    { monsters = { { id = "abyssal_crab", count = 4 }, { id = "ink_octopus", count = 8 } } },
                    { monsters = { { id = "ink_octopus", count = 6 }, { id = "abyssal_crab", count = 3 }, { id = "tide_merfolk", count = 6 } } },
                },
                reward = { gold = 650, guaranteeEquipQuality = 2 },
            },
            -- 5-7: 墨渊深处 ⚠️装备墙2 (大量章鱼+巨蟹+祭司)
            {
                name = "墨渊深处",
                waves = {
                    { monsters = { { id = "ink_octopus", count = 8 }, { id = "abyssal_crab", count = 4 }, { id = "sea_anemone", count = 3 } } },
                    { monsters = { { id = "tide_merfolk", count = 8 }, { id = "coral_guardian", count = 5 }, { id = "venom_jelly", count = 8 } } },
                    { monsters = { { id = "abyssal_crab", count = 3 }, { id = "ink_octopus", count = 6 }, { id = "sea_anemone", count = 4 } } },
                },
                reward = { gold = 800, guaranteeEquipQuality = 2 },
            },
            -- 5-8: 潮汐祭坛 (全怪物混合三波)
            {
                name = "潮汐祭坛",
                waves = {
                    { monsters = { { id = "abyss_angler", count = 25 }, { id = "storm_seahorse", count = 12 }, { id = "venom_jelly", count = 8 } } },
                    { monsters = { { id = "tide_merfolk", count = 8 }, { id = "coral_guardian", count = 4 }, { id = "ink_octopus", count = 8 } } },
                    { monsters = { { id = "abyssal_crab", count = 4 }, { id = "sea_anemone", count = 4 }, { id = "tide_merfolk", count = 6 }, { id = "abyss_angler", count = 15 } } },
                },
                reward = { gold = 1000, guaranteeEquipQuality = 2 },
            },
            -- 5-9: 利维坦巢穴 ⚠️装备墙3 (终极难度)
            {
                name = "利维坦巢穴",
                waves = {
                    { monsters = { { id = "abyssal_crab", count = 5 }, { id = "tide_merfolk", count = 8 }, { id = "sea_anemone", count = 4 } } },
                    { monsters = { { id = "ink_octopus", count = 10 }, { id = "coral_guardian", count = 6 } } },
                    { monsters = { { id = "abyssal_crab", count = 4 }, { id = "tide_merfolk", count = 6 }, { id = "ink_octopus", count = 8 }, { id = "sea_anemone", count = 3 } } },
                },
                reward = { gold = 1200, guaranteeEquipQuality = 3 },
            },
            -- 5-10: BOSS - 海渊之主·利维坦
            {
                name = "海渊之主·利维坦",
                isBoss = true,
                waves = {
                    { monsters = { { id = "abyssal_crab", count = 4 }, { id = "tide_merfolk", count = 8 }, { id = "ink_octopus", count = 8 }, { id = "sea_anemone", count = 3 } } },
                    { monsters = { { id = "boss_leviathan", count = 1 }, { id = "abyss_angler", count = 35 }, { id = "venom_jelly", count = 10 } } },
                },
                reward = { gold = 4000, guaranteeEquipQuality = 4 },
            },
        },
    },
    -- ==================== 第六章: 雷鸣荒漠 ====================
    {
        id = 6,
        name = "雷鸣荒漠",
        desc = "雷暴与黄沙交织的远古废墟",
        lore = "穿越深海渊域后，你踏上了一片被永恒雷暴笼罩的沙漠。这里曾是辉煌的古代文明中心，如今只剩风蚀的遗迹和被雷电赋予生命的沙漠生物。传说沙漠深处沉睡着一尊远古战争兵器——雷霆泰坦·奥西曼，它的苏醒将引发毁灭一切的雷暴。你必须在它完全觉醒之前将其封印。",
        stages = {
            -- 6-1: 风蚀戈壁 (过渡关)
            {
                name = "风蚀戈壁",
                waves = {
                    { monsters = { { id = "sand_scarab", count = 35 } } },
                    { monsters = { { id = "sand_scarab", count = 40 } } },
                },
                reward = { gold = 500 },
            },
            -- 6-2: 蝎巢沙谷 (引入充能机制)
            {
                name = "蝎巢沙谷",
                waves = {
                    { monsters = { { id = "sand_scarab", count = 25 }, { id = "thunder_scorpion", count = 8 } } },
                    { monsters = { { id = "thunder_scorpion", count = 10 }, { id = "sand_scarab", count = 15 } } },
                },
                reward = { gold = 600 },
            },
            -- 6-3: 流沙陷阱 (沙虫+风暴鹰)
            {
                name = "流沙陷阱",
                waves = {
                    { monsters = { { id = "dune_worm", count = 4 }, { id = "storm_hawk", count = 12 } } },
                    { monsters = { { id = "storm_hawk", count = 15 }, { id = "sand_wraith", count = 8 } } },
                },
                reward = { gold = 750, guaranteeEquipQuality = 1 },
            },
            -- 6-4: 雷石峡湾 ⚠️装备墙1
            {
                name = "雷石峡湾",
                waves = {
                    { monsters = { { id = "lightning_lizard", count = 8 }, { id = "desert_golem", count = 4 }, { id = "sand_scarab", count = 15 } } },
                    { monsters = { { id = "desert_golem", count = 3 }, { id = "thunder_shaman", count = 4 }, { id = "thunder_scorpion", count = 6 } } },
                },
                reward = { gold = 900, guaranteeEquipQuality = 1 },
            },
            -- 6-5: BOSS - 沙暴君主·拉赫
            {
                name = "沙暴君主·拉赫",
                isBoss = true,
                waves = {
                    { monsters = { { id = "sand_scarab", count = 20 }, { id = "sand_wraith", count = 8 }, { id = "storm_hawk", count = 10 } } },
                    { monsters = { { id = "boss_sandstorm_lord", count = 1 }, { id = "thunder_scorpion", count = 15 } } },
                },
                reward = { gold = 2200, guaranteeEquipQuality = 3 },
            },
            -- 6-6: 电弧裂谷
            {
                name = "电弧裂谷",
                waves = {
                    { monsters = { { id = "thunder_shaman", count = 4 }, { id = "sand_wraith", count = 6 }, { id = "lightning_lizard", count = 8 } } },
                    { monsters = { { id = "desert_golem", count = 4 }, { id = "thunder_shaman", count = 3 }, { id = "thunder_scorpion", count = 8 } } },
                },
                reward = { gold = 1000, guaranteeEquipQuality = 2 },
            },
            -- 6-7: 傀儡工坊 ⚠️装备墙2
            {
                name = "傀儡工坊",
                waves = {
                    { monsters = { { id = "desert_golem", count = 5 }, { id = "thunder_shaman", count = 4 }, { id = "sand_wraith", count = 5 } } },
                    { monsters = { { id = "dune_worm", count = 6 }, { id = "lightning_lizard", count = 8 }, { id = "storm_hawk", count = 10 } } },
                    { monsters = { { id = "desert_golem", count = 4 }, { id = "thunder_shaman", count = 3 }, { id = "thunder_scorpion", count = 10 }, { id = "sand_scarab", count = 20 } } },
                },
                reward = { gold = 1300, guaranteeEquipQuality = 2 },
            },
            -- 6-8: 遗迹风暴 (全怪混合三波)
            {
                name = "遗迹风暴",
                waves = {
                    { monsters = { { id = "sand_scarab", count = 30 }, { id = "storm_hawk", count = 12 }, { id = "sand_wraith", count = 6 } } },
                    { monsters = { { id = "dune_worm", count = 5 }, { id = "lightning_lizard", count = 8 }, { id = "thunder_scorpion", count = 8 } } },
                    { monsters = { { id = "desert_golem", count = 4 }, { id = "thunder_shaman", count = 4 }, { id = "thunder_scorpion", count = 6 }, { id = "sand_scarab", count = 15 } } },
                },
                reward = { gold = 1600, guaranteeEquipQuality = 2 },
            },
            -- 6-9: 雷神祭坛 ⚠️装备墙3
            {
                name = "雷神祭坛",
                waves = {
                    { monsters = { { id = "desert_golem", count = 6 }, { id = "thunder_shaman", count = 5 }, { id = "sand_wraith", count = 5 } } },
                    { monsters = { { id = "dune_worm", count = 5 }, { id = "lightning_lizard", count = 10 }, { id = "thunder_scorpion", count = 8 } } },
                    { monsters = { { id = "desert_golem", count = 5 }, { id = "thunder_shaman", count = 4 }, { id = "dune_worm", count = 4 }, { id = "storm_hawk", count = 10 } } },
                },
                reward = { gold = 2000, guaranteeEquipQuality = 3 },
            },
            -- 6-10: BOSS - 雷霆泰坦·奥西曼
            {
                name = "雷霆泰坦·奥西曼",
                isBoss = true,
                waves = {
                    { monsters = { { id = "desert_golem", count = 4 }, { id = "thunder_shaman", count = 4 }, { id = "lightning_lizard", count = 8 }, { id = "sand_wraith", count = 5 } } },
                    { monsters = { { id = "boss_thunder_titan", count = 1 }, { id = "sand_scarab", count = 30 }, { id = "storm_hawk", count = 12 } } },
                },
                reward = { gold = 6000, guaranteeEquipQuality = 4 },
            },
        },
    },
    -- ==================== 第七章: 瘴毒密林 ====================
    {
        id = 7,
        name = "瘴毒密林",
        desc = "瘴气与毒雾弥漫的远古密林",
        lore = "穿越雷鸣荒漠后，你循着黑暗能量的踪迹进入了一片亘古密林。这里终年笼罩在浓重的瘴毒之中，巨型毒菌释放致命孢子，剧毒蛇虫潜伏在每一片阴影里。密林深处盘踞着一棵被黑暗腐蚀的远古巨树——朽木之母·耶梦加得，它的根系将毒素蔓延至整片大地。唯有以火焰净化这片密林，才能阻止毒素的永恒扩散。",
        stages = {
            -- 7-1: 瘴气入口 (过渡关)
            {
                name = "瘴气入口",
                waves = {
                    { monsters = { { id = "plague_beetle", count = 35 } } },
                    { monsters = { { id = "plague_beetle", count = 40 } } },
                },
                reward = { gold = 700 },
            },
            -- 7-2: 毒蛇谷地 (引入毒蛊叠加)
            {
                name = "毒蛇谷地",
                waves = {
                    { monsters = { { id = "plague_beetle", count = 25 }, { id = "thorn_viper", count = 8 } } },
                    { monsters = { { id = "thorn_viper", count = 10 }, { id = "plague_beetle", count = 15 } } },
                },
                reward = { gold = 850 },
            },
            -- 7-3: 黑豹疾径 (高速+孢子)
            {
                name = "黑豹疾径",
                waves = {
                    { monsters = { { id = "jungle_panther", count = 10 }, { id = "toxic_wasp", count = 15 } } },
                    { monsters = { { id = "toxic_wasp", count = 18 }, { id = "spore_lurker", count = 8 } } },
                },
                reward = { gold = 1000, guaranteeEquipQuality = 1 },
            },
            -- 7-4: 藤蔓沼泽 ⚠️装备墙1
            {
                name = "藤蔓沼泽",
                waves = {
                    { monsters = { { id = "vine_strangler", count = 6 }, { id = "spore_lurker", count = 8 }, { id = "plague_beetle", count = 15 } } },
                    { monsters = { { id = "ironbark_treant", count = 3 }, { id = "mire_shaman", count = 4 }, { id = "thorn_viper", count = 8 } } },
                },
                reward = { gold = 1200, guaranteeEquipQuality = 1 },
            },
            -- 7-5: BOSS - 毒液女王·阿拉克涅
            {
                name = "毒液女王·阿拉克涅",
                isBoss = true,
                waves = {
                    { monsters = { { id = "plague_beetle", count = 20 }, { id = "toxic_wasp", count = 10 }, { id = "spore_lurker", count = 8 } } },
                    { monsters = { { id = "boss_venom_queen", count = 1 }, { id = "thorn_viper", count = 15 } } },
                },
                reward = { gold = 3000, guaranteeEquipQuality = 3 },
            },
            -- 7-6: 孢子深林
            {
                name = "孢子深林",
                waves = {
                    { monsters = { { id = "mire_shaman", count = 4 }, { id = "spore_lurker", count = 8 }, { id = "vine_strangler", count = 5 } } },
                    { monsters = { { id = "ironbark_treant", count = 3 }, { id = "mire_shaman", count = 3 }, { id = "toxic_wasp", count = 12 } } },
                },
                reward = { gold = 1400, guaranteeEquipQuality = 2 },
            },
            -- 7-7: 腐木巢穴 ⚠️装备墙2
            {
                name = "腐木巢穴",
                waves = {
                    { monsters = { { id = "ironbark_treant", count = 5 }, { id = "mire_shaman", count = 4 }, { id = "spore_lurker", count = 6 } } },
                    { monsters = { { id = "vine_strangler", count = 5 }, { id = "thorn_viper", count = 10 }, { id = "jungle_panther", count = 8 } } },
                    { monsters = { { id = "ironbark_treant", count = 4 }, { id = "mire_shaman", count = 3 }, { id = "toxic_wasp", count = 15 }, { id = "plague_beetle", count = 20 } } },
                },
                reward = { gold = 1800, guaranteeEquipQuality = 2 },
            },
            -- 7-8: 毒雾深渊 (全怪混合三波)
            {
                name = "毒雾深渊",
                waves = {
                    { monsters = { { id = "plague_beetle", count = 30 }, { id = "jungle_panther", count = 10 }, { id = "spore_lurker", count = 8 } } },
                    { monsters = { { id = "vine_strangler", count = 5 }, { id = "thorn_viper", count = 8 }, { id = "toxic_wasp", count = 12 } } },
                    { monsters = { { id = "ironbark_treant", count = 4 }, { id = "mire_shaman", count = 4 }, { id = "thorn_viper", count = 6 }, { id = "plague_beetle", count = 15 } } },
                },
                reward = { gold = 2200, guaranteeEquipQuality = 2 },
            },
            -- 7-9: 朽木圣坛 ⚠️装备墙3
            {
                name = "朽木圣坛",
                waves = {
                    { monsters = { { id = "ironbark_treant", count = 6 }, { id = "mire_shaman", count = 5 }, { id = "spore_lurker", count = 6 } } },
                    { monsters = { { id = "vine_strangler", count = 5 }, { id = "thorn_viper", count = 10 }, { id = "jungle_panther", count = 8 } } },
                    { monsters = { { id = "ironbark_treant", count = 5 }, { id = "mire_shaman", count = 4 }, { id = "vine_strangler", count = 4 }, { id = "toxic_wasp", count = 12 } } },
                },
                reward = { gold = 2800, guaranteeEquipQuality = 3 },
            },
            -- 7-10: BOSS - 朽木之母·耶梦加得
            {
                name = "朽木之母·耶梦加得",
                isBoss = true,
                waves = {
                    { monsters = { { id = "ironbark_treant", count = 4 }, { id = "mire_shaman", count = 4 }, { id = "vine_strangler", count = 5 }, { id = "spore_lurker", count = 6 } } },
                    { monsters = { { id = "boss_rotwood_mother", count = 1 }, { id = "plague_beetle", count = 35 }, { id = "jungle_panther", count = 10 } } },
                },
                reward = { gold = 8000, guaranteeEquipQuality = 4 },
            },
        },
    },
    -- ==================== 第八章: 虚空裂隙 ====================
    {
        id = 8,
        name = "虚空裂隙",
        desc = "时空碎裂的虚空异界",
        lore = "密林深处的黑暗之源并非终点——一道通往虚空的裂隙在瘴毒净化后显露出来。裂隙彼端是一片破碎的时空异界，星辰在紫色的虚无中闪烁。虚空生物从裂隙中涌出，它们以奥术能量为食，能扭曲空间本身。裂隙君主·奥伯龙掌控着这片破碎领域，试图将裂隙扩大到足以吞噬整个世界。你必须深入虚空核心，将裂隙彻底封印。",
        stages = {
            -- 8-1: 裂隙边缘 (过渡关)
            {
                name = "裂隙边缘",
                waves = {
                    { monsters = { { id = "void_wisp", count = 40 } } },
                    { monsters = { { id = "void_wisp", count = 45 } } },
                },
                reward = { gold = 900 },
            },
            -- 8-2: 相位通道 (引入空间撕裂)
            {
                name = "相位通道",
                waves = {
                    { monsters = { { id = "void_wisp", count = 25 }, { id = "spatial_ripper", count = 8 } } },
                    { monsters = { { id = "spatial_ripper", count = 10 }, { id = "void_wisp", count = 20 } } },
                },
                reward = { gold = 1100 },
            },
            -- 8-3: 熵灭地带 (死亡爆炸+高速)
            {
                name = "熵灭地带",
                waves = {
                    { monsters = { { id = "rift_stalker", count = 10 }, { id = "entropy_mote", count = 15 } } },
                    { monsters = { { id = "entropy_mote", count = 20 }, { id = "spatial_ripper", count = 8 } } },
                },
                reward = { gold = 1300, guaranteeEquipQuality = 1 },
            },
            -- 8-4: 虚无要塞 ⚠️装备墙1
            {
                name = "虚无要塞",
                waves = {
                    { monsters = { { id = "null_sentinel", count = 6 }, { id = "phase_weaver", count = 6 }, { id = "void_wisp", count = 20 } } },
                    { monsters = { { id = "void_colossus", count = 3 }, { id = "star_oracle", count = 4 }, { id = "spatial_ripper", count = 8 } } },
                },
                reward = { gold = 1600, guaranteeEquipQuality = 1 },
            },
            -- 8-5: BOSS - 虚空亲王·艾瑟隆
            {
                name = "虚空亲王·艾瑟隆",
                isBoss = true,
                waves = {
                    { monsters = { { id = "void_wisp", count = 25 }, { id = "entropy_mote", count = 12 }, { id = "rift_stalker", count = 8 } } },
                    { monsters = { { id = "boss_void_prince", count = 1 }, { id = "spatial_ripper", count = 15 } } },
                },
                reward = { gold = 4000, guaranteeEquipQuality = 3 },
            },
            -- 8-6: 星辰回廊
            {
                name = "星辰回廊",
                waves = {
                    { monsters = { { id = "star_oracle", count = 5 }, { id = "phase_weaver", count = 6 }, { id = "null_sentinel", count = 5 } } },
                    { monsters = { { id = "void_colossus", count = 3 }, { id = "star_oracle", count = 4 }, { id = "entropy_mote", count = 15 } } },
                },
                reward = { gold = 1800, guaranteeEquipQuality = 2 },
            },
            -- 8-7: 奥术风暴核心 ⚠️装备墙2
            {
                name = "奥术风暴核心",
                waves = {
                    { monsters = { { id = "void_colossus", count = 5 }, { id = "star_oracle", count = 5 }, { id = "phase_weaver", count = 5 } } },
                    { monsters = { { id = "null_sentinel", count = 5 }, { id = "spatial_ripper", count = 10 }, { id = "rift_stalker", count = 8 } } },
                    { monsters = { { id = "void_colossus", count = 4 }, { id = "star_oracle", count = 4 }, { id = "entropy_mote", count = 18 }, { id = "void_wisp", count = 25 } } },
                },
                reward = { gold = 2400, guaranteeEquipQuality = 2 },
            },
            -- 8-8: 次元断层 (全怪混合三波)
            {
                name = "次元断层",
                waves = {
                    { monsters = { { id = "void_wisp", count = 35 }, { id = "rift_stalker", count = 10 }, { id = "entropy_mote", count = 10 } } },
                    { monsters = { { id = "null_sentinel", count = 5 }, { id = "spatial_ripper", count = 8 }, { id = "phase_weaver", count = 6 } } },
                    { monsters = { { id = "void_colossus", count = 4 }, { id = "star_oracle", count = 5 }, { id = "spatial_ripper", count = 8 }, { id = "void_wisp", count = 20 } } },
                },
                reward = { gold = 2800, guaranteeEquipQuality = 2 },
            },
            -- 8-9: 裂隙王座 ⚠️装备墙3
            {
                name = "裂隙王座",
                waves = {
                    { monsters = { { id = "void_colossus", count = 6 }, { id = "star_oracle", count = 5 }, { id = "phase_weaver", count = 5 } } },
                    { monsters = { { id = "null_sentinel", count = 5 }, { id = "spatial_ripper", count = 10 }, { id = "rift_stalker", count = 10 } } },
                    { monsters = { { id = "void_colossus", count = 5 }, { id = "star_oracle", count = 5 }, { id = "null_sentinel", count = 4 }, { id = "entropy_mote", count = 15 } } },
                },
                reward = { gold = 3500, guaranteeEquipQuality = 3 },
            },
            -- 8-10: BOSS - 裂隙君主·奥伯龙
            {
                name = "裂隙君主·奥伯龙",
                isBoss = true,
                waves = {
                    { monsters = { { id = "void_colossus", count = 4 }, { id = "star_oracle", count = 5 }, { id = "null_sentinel", count = 5 }, { id = "phase_weaver", count = 5 } } },
                    { monsters = { { id = "boss_rift_sovereign", count = 1 }, { id = "void_wisp", count = 40 }, { id = "rift_stalker", count = 10 } } },
                },
                reward = { gold = 10000, guaranteeEquipQuality = 4 },
            },
        },
    },
    -- ==================== 第九章: 天穹圣域 ====================
    {
        id = 9,
        name = "天穹圣域",
        desc = "众神栖居的金色天界",
        lore = "封印虚空裂隙后，一道金色的光柱从天而降，将你引向天穹圣域——古老传说中众神栖居的神圣领域。然而这片圣域已被堕落侵蚀，曾经守护世界的天使战士如今成为狂信的审判者，将一切外来者视为亵渎。圣裁者·米迦勒统领光明军团，天穹帝皇·乌列尔则端坐于金色王座之上，以绝对的圣光裁决万物。你必须穿越重重圣光审判，揭开天穹圣域堕落的真相。",
        stages = {
            -- 9-1: 金色阶梯 (过渡关)
            {
                name = "金色阶梯",
                waves = {
                    { monsters = { { id = "radiant_sprite", count = 45 } } },
                    { monsters = { { id = "radiant_sprite", count = 50 } } },
                },
                reward = { gold = 1200 },
            },
            -- 9-2: 光环甬道 (引入枪兵)
            {
                name = "光环甬道",
                waves = {
                    { monsters = { { id = "radiant_sprite", count = 28 }, { id = "halo_lancer", count = 10 } } },
                    { monsters = { { id = "halo_lancer", count = 12 }, { id = "radiant_sprite", count = 22 } } },
                },
                reward = { gold = 1400 },
            },
            -- 9-3: 净化试炼场 (死亡爆炸+高速)
            {
                name = "净化试炼场",
                waves = {
                    { monsters = { { id = "zealot_knight", count = 12 }, { id = "sanctum_wisp", count = 18 } } },
                    { monsters = { { id = "sanctum_wisp", count = 22 }, { id = "halo_lancer", count = 10 } } },
                },
                reward = { gold = 1600, guaranteeEquipQuality = 1 },
            },
            -- 9-4: 圣域前厅 ⚠️装备墙1
            {
                name = "圣域前厅",
                waves = {
                    { monsters = { { id = "golden_guardian", count = 6 }, { id = "celestial_mender", count = 6 }, { id = "radiant_sprite", count = 22 } } },
                    { monsters = { { id = "divine_colossus", count = 3 }, { id = "seraph_invoker", count = 4 }, { id = "halo_lancer", count = 10 } } },
                },
                reward = { gold = 2000, guaranteeEquipQuality = 1 },
            },
            -- 9-5: BOSS - 圣裁者·米迦勒
            {
                name = "圣裁者·米迦勒",
                isBoss = true,
                waves = {
                    { monsters = { { id = "radiant_sprite", count = 28 }, { id = "sanctum_wisp", count = 15 }, { id = "zealot_knight", count = 10 } } },
                    { monsters = { { id = "boss_archon", count = 1 }, { id = "halo_lancer", count = 18 } } },
                },
                reward = { gold = 5000, guaranteeEquipQuality = 3 },
            },
            -- 9-6: 炽天使回廊
            {
                name = "炽天使回廊",
                waves = {
                    { monsters = { { id = "seraph_invoker", count = 5 }, { id = "celestial_mender", count = 6 }, { id = "golden_guardian", count = 5 } } },
                    { monsters = { { id = "divine_colossus", count = 3 }, { id = "seraph_invoker", count = 4 }, { id = "sanctum_wisp", count = 18 } } },
                },
                reward = { gold = 2400, guaranteeEquipQuality = 2 },
            },
            -- 9-7: 审判圣殿 ⚠️装备墙2
            {
                name = "审判圣殿",
                waves = {
                    { monsters = { { id = "divine_colossus", count = 5 }, { id = "seraph_invoker", count = 5 }, { id = "celestial_mender", count = 5 } } },
                    { monsters = { { id = "golden_guardian", count = 6 }, { id = "halo_lancer", count = 12 }, { id = "zealot_knight", count = 10 } } },
                    { monsters = { { id = "divine_colossus", count = 4 }, { id = "seraph_invoker", count = 4 }, { id = "sanctum_wisp", count = 20 }, { id = "radiant_sprite", count = 28 } } },
                },
                reward = { gold = 3000, guaranteeEquipQuality = 2 },
            },
            -- 9-8: 神恩殿堂 (全怪混合三波)
            {
                name = "神恩殿堂",
                waves = {
                    { monsters = { { id = "radiant_sprite", count = 38 }, { id = "zealot_knight", count = 12 }, { id = "sanctum_wisp", count = 12 } } },
                    { monsters = { { id = "golden_guardian", count = 5 }, { id = "halo_lancer", count = 10 }, { id = "celestial_mender", count = 6 } } },
                    { monsters = { { id = "divine_colossus", count = 4 }, { id = "seraph_invoker", count = 5 }, { id = "halo_lancer", count = 10 }, { id = "radiant_sprite", count = 22 } } },
                },
                reward = { gold = 3500, guaranteeEquipQuality = 2 },
            },
            -- 9-9: 天穹王座 ⚠️装备墙3
            {
                name = "天穹王座",
                waves = {
                    { monsters = { { id = "divine_colossus", count = 6 }, { id = "seraph_invoker", count = 6 }, { id = "celestial_mender", count = 5 } } },
                    { monsters = { { id = "golden_guardian", count = 6 }, { id = "halo_lancer", count = 12 }, { id = "zealot_knight", count = 12 } } },
                    { monsters = { { id = "divine_colossus", count = 5 }, { id = "seraph_invoker", count = 5 }, { id = "golden_guardian", count = 5 }, { id = "sanctum_wisp", count = 18 } } },
                },
                reward = { gold = 4500, guaranteeEquipQuality = 3 },
            },
            -- 9-10: BOSS - 天穹帝皇·乌列尔
            {
                name = "天穹帝皇·乌列尔",
                isBoss = true,
                waves = {
                    { monsters = { { id = "divine_colossus", count = 4 }, { id = "seraph_invoker", count = 5 }, { id = "golden_guardian", count = 5 }, { id = "celestial_mender", count = 5 } } },
                    { monsters = { { id = "boss_celestial_emperor", count = 1 }, { id = "radiant_sprite", count = 45 }, { id = "zealot_knight", count = 12 } } },
                },
                reward = { gold = 12000, guaranteeEquipQuality = 4 },
            },
        },
    },
    -- ==================== 第十章: 永夜深渊 ====================
    {
        id = 10,
        name = "永夜深渊",
        desc = "堕落与毁灭的黑暗深渊",
        lore = "天穹圣域的光明背面隐藏着无尽的黑暗——永夜深渊。当圣域的堕落被揭露后，裂缝深处涌出了更加古老、更加恐怖的力量。深渊中弥漫着腐败的暗影能量，暗紫色的虚空裂隙中不断渗出暗红色的深渊之火。暗噬者统领着深渊军团，而虚无之主则端坐于深渊最底层的黑暗王座上，试图用永夜吞噬一切光明。你必须深入深渊核心，斩断黑暗之源。",
        stages = {
            -- 10-1: 深渊之门 (过渡关)
            {
                name = "深渊之门",
                waves = {
                    { monsters = { { id = "abyss_shade", count = 45 } } },
                    { monsters = { { id = "abyss_shade", count = 50 } } },
                },
                reward = { gold = 1500 },
            },
            -- 10-2: 暗影走廊 (引入刺客+法师)
            {
                name = "暗影走廊",
                waves = {
                    { monsters = { { id = "abyss_shade", count = 28 }, { id = "night_reaper", count = 10 } } },
                    { monsters = { { id = "night_reaper", count = 12 }, { id = "corrupt_mage", count = 5 } } },
                },
                reward = { gold = 1700 },
            },
            -- 10-3: 堕落祭坛 (自爆+枪兵)
            {
                name = "堕落祭坛",
                waves = {
                    { monsters = { { id = "doom_wisp", count = 15 }, { id = "void_lancer", count = 10 } } },
                    { monsters = { { id = "void_lancer", count = 12 }, { id = "night_reaper", count = 8 } } },
                },
                reward = { gold = 2000, guaranteeEquipQuality = 1 },
            },
            -- 10-4: 噩梦回廊 ⚠️装备墙1
            {
                name = "噩梦回廊",
                waves = {
                    { monsters = { { id = "dark_sentinel", count = 6 }, { id = "corrupt_mage", count = 6 }, { id = "abyss_shade", count = 22 } } },
                    { monsters = { { id = "abyssal_titan", count = 3 }, { id = "shadow_oracle", count = 4 }, { id = "void_lancer", count = 10 } } },
                },
                reward = { gold = 2400, guaranteeEquipQuality = 1 },
            },
            -- 10-5: BOSS - 深渊魔将·暗噬者
            {
                name = "深渊魔将·暗噬者",
                isBoss = true,
                waves = {
                    { monsters = { { id = "abyss_shade", count = 28 }, { id = "doom_wisp", count = 15 }, { id = "night_reaper", count = 10 } } },
                    { monsters = { { id = "boss_abyss_general", count = 1 }, { id = "void_lancer", count = 18 } } },
                },
                reward = { gold = 6000, guaranteeEquipQuality = 3 },
            },
            -- 10-6: 虚妄之境
            {
                name = "虚妄之境",
                waves = {
                    { monsters = { { id = "shadow_oracle", count = 5 }, { id = "corrupt_mage", count = 6 }, { id = "dark_sentinel", count = 5 } } },
                    { monsters = { { id = "abyssal_titan", count = 3 }, { id = "shadow_oracle", count = 4 }, { id = "doom_wisp", count = 18 } } },
                },
                reward = { gold = 2800, guaranteeEquipQuality = 2 },
            },
            -- 10-7: 永夜风暴 ⚠️装备墙2
            {
                name = "永夜风暴",
                waves = {
                    { monsters = { { id = "abyssal_titan", count = 5 }, { id = "shadow_oracle", count = 5 }, { id = "corrupt_mage", count = 5 } } },
                    { monsters = { { id = "dark_sentinel", count = 6 }, { id = "void_lancer", count = 12 }, { id = "night_reaper", count = 10 } } },
                    { monsters = { { id = "abyssal_titan", count = 4 }, { id = "shadow_oracle", count = 4 }, { id = "doom_wisp", count = 20 }, { id = "abyss_shade", count = 28 } } },
                },
                reward = { gold = 3500, guaranteeEquipQuality = 2 },
            },
            -- 10-8: 深渊王座前厅 (全怪混合三波)
            {
                name = "深渊王座前厅",
                waves = {
                    { monsters = { { id = "abyss_shade", count = 38 }, { id = "night_reaper", count = 12 }, { id = "doom_wisp", count = 12 } } },
                    { monsters = { { id = "dark_sentinel", count = 5 }, { id = "void_lancer", count = 10 }, { id = "corrupt_mage", count = 6 } } },
                    { monsters = { { id = "abyssal_titan", count = 4 }, { id = "shadow_oracle", count = 5 }, { id = "void_lancer", count = 10 }, { id = "abyss_shade", count = 22 } } },
                },
                reward = { gold = 4000, guaranteeEquipQuality = 2 },
            },
            -- 10-9: 毁灭走廊 ⚠️装备墙3
            {
                name = "毁灭走廊",
                waves = {
                    { monsters = { { id = "abyssal_titan", count = 6 }, { id = "shadow_oracle", count = 6 }, { id = "corrupt_mage", count = 5 } } },
                    { monsters = { { id = "dark_sentinel", count = 6 }, { id = "void_lancer", count = 12 }, { id = "night_reaper", count = 12 } } },
                    { monsters = { { id = "abyssal_titan", count = 5 }, { id = "shadow_oracle", count = 5 }, { id = "dark_sentinel", count = 5 }, { id = "doom_wisp", count = 18 } } },
                },
                reward = { gold = 5000, guaranteeEquipQuality = 3 },
            },
            -- 10-10: BOSS - 深渊君王·虚无之主
            {
                name = "深渊君王·虚无之主",
                isBoss = true,
                waves = {
                    { monsters = { { id = "abyssal_titan", count = 4 }, { id = "shadow_oracle", count = 5 }, { id = "dark_sentinel", count = 5 }, { id = "corrupt_mage", count = 5 } } },
                    { monsters = { { id = "boss_abyss_lord", count = 1 }, { id = "abyss_shade", count = 48 }, { id = "night_reaper", count = 12 } } },
                },
                reward = { gold = 15000, guaranteeEquipQuality = 4 },
            },
        },
    },
    -- ==================== 第十一章: 焚天炼狱 ====================
    {
        id = 11,
        name = "焚天炼狱",
        desc = "焚尽万物的炼狱烈焰",
        lore = "永夜深渊的最底层并非终点——当黑暗被斩断后，一道炽热的光芒从深渊裂缝中喷涌而出。那是比深渊更古老的存在——焚天炼狱，一片由永恒之火铸就的灼热领域。熔金般的岩浆在脚下流淌，灼热的烟尘遮蔽天穹。炼狱将军·焚骨者守护着通往核心的通道，而焚天帝主·灭世之焰则是这片烈焰领域的至高主宰，其力量足以焚尽天地万物。这是你迄今为止最危险的征途。",
        stages = {
            -- 11-1: 焚天之路 (过渡关)
            {
                name = "焚天之路",
                waves = {
                    { monsters = { { id = "pyre_imp", count = 48 } } },
                    { monsters = { { id = "pyre_imp", count = 55 } } },
                },
                reward = { gold = 1800 },
            },
            -- 11-2: 熔金走廊 (引入刀客+傀儡)
            {
                name = "熔金走廊",
                waves = {
                    { monsters = { { id = "pyre_imp", count = 30 }, { id = "inferno_blade", count = 12 } } },
                    { monsters = { { id = "inferno_blade", count = 14 }, { id = "molten_golem", count = 4 } } },
                },
                reward = { gold = 2000 },
            },
            -- 11-3: 灰烬祭坛 (自爆+骑士)
            {
                name = "灰烬祭坛",
                waves = {
                    { monsters = { { id = "cinder_wraith", count = 18 }, { id = "scorch_knight", count = 12 } } },
                    { monsters = { { id = "scorch_knight", count = 14 }, { id = "inferno_blade", count = 10 } } },
                },
                reward = { gold = 2400, guaranteeEquipQuality = 1 },
            },
            -- 11-4: 烈焰试炼场 ⚠️装备墙1
            {
                name = "烈焰试炼场",
                waves = {
                    { monsters = { { id = "molten_golem", count = 6 }, { id = "hellfire_caster", count = 6 }, { id = "pyre_imp", count = 25 } } },
                    { monsters = { { id = "purgatory_giant", count = 3 }, { id = "flame_hierophant", count = 4 }, { id = "scorch_knight", count = 12 } } },
                },
                reward = { gold = 2800, guaranteeEquipQuality = 1 },
            },
            -- 11-5: BOSS - 炼狱将军·焚骨者
            {
                name = "炼狱将军·焚骨者",
                isBoss = true,
                waves = {
                    { monsters = { { id = "pyre_imp", count = 32 }, { id = "cinder_wraith", count = 18 }, { id = "inferno_blade", count = 12 } } },
                    { monsters = { { id = "boss_inferno_general", count = 1 }, { id = "scorch_knight", count = 20 } } },
                },
                reward = { gold = 7000, guaranteeEquipQuality = 3 },
            },
            -- 11-6: 永焰殿堂
            {
                name = "永焰殿堂",
                waves = {
                    { monsters = { { id = "flame_hierophant", count = 5 }, { id = "hellfire_caster", count = 6 }, { id = "molten_golem", count = 5 } } },
                    { monsters = { { id = "purgatory_giant", count = 3 }, { id = "flame_hierophant", count = 4 }, { id = "cinder_wraith", count = 20 } } },
                },
                reward = { gold = 3200, guaranteeEquipQuality = 2 },
            },
            -- 11-7: 毁灭熔炉 ⚠️装备墙2
            {
                name = "毁灭熔炉",
                waves = {
                    { monsters = { { id = "purgatory_giant", count = 5 }, { id = "flame_hierophant", count = 5 }, { id = "hellfire_caster", count = 5 } } },
                    { monsters = { { id = "molten_golem", count = 6 }, { id = "scorch_knight", count = 14 }, { id = "inferno_blade", count = 12 } } },
                    { monsters = { { id = "purgatory_giant", count = 4 }, { id = "flame_hierophant", count = 4 }, { id = "cinder_wraith", count = 22 }, { id = "pyre_imp", count = 30 } } },
                },
                reward = { gold = 4000, guaranteeEquipQuality = 2 },
            },
            -- 11-8: 炼狱深层 (全怪混合三波)
            {
                name = "炼狱深层",
                waves = {
                    { monsters = { { id = "pyre_imp", count = 42 }, { id = "inferno_blade", count = 14 }, { id = "cinder_wraith", count = 14 } } },
                    { monsters = { { id = "molten_golem", count = 5 }, { id = "scorch_knight", count = 12 }, { id = "hellfire_caster", count = 6 } } },
                    { monsters = { { id = "purgatory_giant", count = 4 }, { id = "flame_hierophant", count = 5 }, { id = "scorch_knight", count = 12 }, { id = "pyre_imp", count = 25 } } },
                },
                reward = { gold = 4500, guaranteeEquipQuality = 2 },
            },
            -- 11-9: 焚天王座 ⚠️装备墙3
            {
                name = "焚天王座",
                waves = {
                    { monsters = { { id = "purgatory_giant", count = 6 }, { id = "flame_hierophant", count = 6 }, { id = "hellfire_caster", count = 5 } } },
                    { monsters = { { id = "molten_golem", count = 6 }, { id = "scorch_knight", count = 14 }, { id = "inferno_blade", count = 14 } } },
                    { monsters = { { id = "purgatory_giant", count = 5 }, { id = "flame_hierophant", count = 5 }, { id = "molten_golem", count = 5 }, { id = "cinder_wraith", count = 20 } } },
                },
                reward = { gold = 5500, guaranteeEquipQuality = 3 },
            },
            -- 11-10: BOSS - 焚天帝主·灭世之焰
            {
                name = "焚天帝主·灭世之焰",
                isBoss = true,
                waves = {
                    { monsters = { { id = "purgatory_giant", count = 4 }, { id = "flame_hierophant", count = 5 }, { id = "molten_golem", count = 5 }, { id = "hellfire_caster", count = 5 } } },
                    { monsters = { { id = "boss_pyre_sovereign", count = 1 }, { id = "pyre_imp", count = 50 }, { id = "inferno_blade", count = 14 } } },
                },
                reward = { gold = 18000, guaranteeEquipQuality = 4 },
            },
        },
    },

    -- ==================== 第十二章: 时渊回廊 ====================
    {
        id = 12,
        name = "时渊回廊",
        desc = "时间法则崩塌的混沌维度",
        lore = "穿越焚天炼狱的烈焰深渊后，你发现了隐藏在灼热之下的时空裂缝。当你踏入这片幽紫色的回廊，时间的法则在这里彻底崩塌——巨大的时钟齿轮碎片悬浮在虚空中，时空裂缝散发着冰冷的紫光。这里的生物已被扭曲的时间之力所侵蚀，它们不再服从因果律，能够回溯、停滞甚至加速时间。永恒钟主·克洛诺斯坐镇于回廊的尽头，掌控着这片维度的时间之流。唯有打碎他的时间权杖，才能阻止时空裂缝继续扩散。",
        stages = {
            -- 12-1: 时裂入口 (过渡关)
            {
                name = "时裂入口",
                waves = {
                    { monsters = { { id = "chrono_mite", count = 30 } } },
                    { monsters = { { id = "chrono_mite", count = 35 } } },
                },
                reward = { gold = 2200 },
            },
            -- 12-2: 回忆长廊 (引入刺客)
            {
                name = "回忆长廊",
                waves = {
                    { monsters = { { id = "chrono_mite", count = 22 }, { id = "rewind_assassin", count = 8 } } },
                    { monsters = { { id = "chrono_mite", count = 18 }, { id = "rewind_assassin", count = 10 } } },
                },
                reward = { gold = 2800 },
            },
            -- 12-3: 停滞之间 (引入坦克)
            {
                name = "停滞之间",
                waves = {
                    { monsters = { { id = "eternal_sentinel", count = 5 }, { id = "chrono_mite", count = 22 } } },
                    { monsters = { { id = "eternal_sentinel", count = 6 }, { id = "rewind_assassin", count = 8 } } },
                },
                reward = { gold = 3400 },
            },
            -- 12-4: 悖论花园 ⚠️装备墙1
            {
                name = "悖论花园",
                waves = {
                    { monsters = { { id = "stasis_spider", count = 8 }, { id = "chrono_mage", count = 6 }, { id = "chrono_mite", count = 12 } } },
                    { monsters = { { id = "stasis_spider", count = 6 }, { id = "chrono_mage", count = 8 }, { id = "rewind_assassin", count = 8 } } },
                },
                reward = { gold = 4200, guaranteeEquipQuality = 2 },
            },
            -- 12-5: BOSS - 时空裂主·弗拉克图斯
            {
                name = "时空裂主·弗拉克图斯",
                isBoss = true,
                waves = {
                    { monsters = { { id = "chrono_mage", count = 8 }, { id = "stasis_spider", count = 8 }, { id = "chrono_mite", count = 15 } } },
                    { monsters = { { id = "boss_rift_lord", count = 1 }, { id = "chrono_mite", count = 30 } } },
                },
                reward = { gold = 9500, guaranteeEquipQuality = 3 },
            },
            -- 12-6: 碎片回廊 (引入自爆+祭司)
            {
                name = "碎片回廊",
                waves = {
                    { monsters = { { id = "rift_phantom", count = 12 }, { id = "aeon_hierophant", count = 4 }, { id = "chrono_mite", count = 15 } } },
                    { monsters = { { id = "rift_phantom", count = 10 }, { id = "aeon_hierophant", count = 5 }, { id = "eternal_sentinel", count = 4 } } },
                },
                reward = { gold = 5000, guaranteeEquipQuality = 2 },
            },
            -- 12-7: 永劫祭坛 ⚠️装备墙2 (3波)
            {
                name = "永劫祭坛",
                waves = {
                    { monsters = { { id = "epoch_colossus", count = 3 }, { id = "chrono_mage", count = 6 }, { id = "chrono_mite", count = 15 } } },
                    { monsters = { { id = "epoch_colossus", count = 4 }, { id = "aeon_hierophant", count = 5 }, { id = "stasis_spider", count = 6 } } },
                    { monsters = { { id = "epoch_colossus", count = 3 }, { id = "rewind_assassin", count = 10 }, { id = "rift_phantom", count = 8 } } },
                },
                reward = { gold = 6200, guaranteeEquipQuality = 2 },
            },
            -- 12-8: 时序熔炉 (全怪种3波)
            {
                name = "时序熔炉",
                waves = {
                    { monsters = { { id = "chrono_mite", count = 20 }, { id = "rewind_assassin", count = 10 }, { id = "rift_phantom", count = 8 } } },
                    { monsters = { { id = "stasis_spider", count = 8 }, { id = "chrono_mage", count = 6 }, { id = "eternal_sentinel", count = 5 } } },
                    { monsters = { { id = "epoch_colossus", count = 3 }, { id = "aeon_hierophant", count = 5 }, { id = "rewind_assassin", count = 8 } } },
                },
                reward = { gold = 7800, guaranteeEquipQuality = 2 },
            },
            -- 12-9: 因果终端 ⚠️装备墙3 (3波)
            {
                name = "因果终端",
                waves = {
                    { monsters = { { id = "epoch_colossus", count = 4 }, { id = "chrono_mage", count = 8 }, { id = "stasis_spider", count = 6 } } },
                    { monsters = { { id = "aeon_hierophant", count = 6 }, { id = "rift_phantom", count = 12 }, { id = "rewind_assassin", count = 10 } } },
                    { monsters = { { id = "epoch_colossus", count = 3 }, { id = "aeon_hierophant", count = 4 }, { id = "eternal_sentinel", count = 6 }, { id = "chrono_mage", count = 6 } } },
                },
                reward = { gold = 10000, guaranteeEquipQuality = 3 },
            },
            -- 12-10: BOSS - 永恒钟主·克洛诺斯
            {
                name = "永恒钟主·克洛诺斯",
                isBoss = true,
                waves = {
                    { monsters = { { id = "aeon_hierophant", count = 6 }, { id = "stasis_spider", count = 8 }, { id = "rewind_assassin", count = 10 }, { id = "epoch_colossus", count = 3 } } },
                    { monsters = { { id = "boss_chrono_sovereign", count = 1 }, { id = "chrono_mite", count = 35 }, { id = "rift_phantom", count = 8 } } },
                },
                reward = { gold = 22000, guaranteeEquipQuality = 4 },
            },
        },
    },

    -- ==================== 第十三章: 寒渊冰域 ====================
    {
        id = 13,
        name = "寒渊冰域",
        desc = "远古冰封的极寒领域",
        lore = "穿越时渊回廊的时空裂缝后，你坠入了一片远古冰封的极寒领域。巨大冰川裂隙中透出幽绿极光，冰晶折射出冷艳光辉。这里的生物已被永冻之力所侵蚀，它们操控冰霜与严寒，将一切温暖化为乌有。冰渊至尊·尼弗海姆坐镇于永冻核心的深处，掌控着这片极寒之域。唯有以烈焰融化他的永冻铠甲，才能终结这片冰封的诅咒。",
        stages = {
            -- 13-1: 冰川裂口 (过渡关)
            {
                name = "冰川裂口",
                waves = {
                    { monsters = { { id = "frost_mite", count = 28 } } },
                    { monsters = { { id = "frost_mite", count = 32 } } },
                },
                reward = { gold = 2500 },
            },
            -- 13-2: 霜晶峡谷 (引入刺客)
            {
                name = "霜晶峡谷",
                waves = {
                    { monsters = { { id = "frost_mite", count = 20 }, { id = "ice_stalker", count = 7 } } },
                    { monsters = { { id = "frost_mite", count = 16 }, { id = "ice_stalker", count = 9 } } },
                },
                reward = { gold = 3000 },
            },
            -- 13-3: 冻骨荒原 (引入坦克)
            {
                name = "冻骨荒原",
                waves = {
                    { monsters = { { id = "permafrost_beast", count = 4 }, { id = "frost_mite", count = 20 } } },
                    { monsters = { { id = "permafrost_beast", count = 5 }, { id = "ice_stalker", count = 7 } } },
                },
                reward = { gold = 3600 },
            },
            -- 13-4: 极光裂隙 ⚠️装备墙1
            {
                name = "极光裂隙",
                waves = {
                    { monsters = { { id = "rime_weaver", count = 7 }, { id = "glacier_caster", count = 5 }, { id = "frost_mite", count = 10 } } },
                    { monsters = { { id = "rime_weaver", count = 5 }, { id = "glacier_caster", count = 7 }, { id = "ice_stalker", count = 7 } } },
                },
                reward = { gold = 4500, guaranteeEquipQuality = 2 },
            },
            -- 13-5: BOSS - 霜暴领主·格拉西恩
            {
                name = "霜暴领主·格拉西恩",
                isBoss = true,
                waves = {
                    { monsters = { { id = "glacier_caster", count = 7 }, { id = "rime_weaver", count = 7 }, { id = "frost_mite", count = 12 } } },
                    { monsters = { { id = "boss_frost_lord", count = 1 }, { id = "frost_mite", count = 28 } } },
                },
                reward = { gold = 10000, guaranteeEquipQuality = 3 },
            },
            -- 13-6: 碎冰深渊 (引入自爆+祭司)
            {
                name = "碎冰深渊",
                waves = {
                    { monsters = { { id = "cryo_wraith", count = 10 }, { id = "frostfall_priest", count = 3 }, { id = "frost_mite", count = 14 } } },
                    { monsters = { { id = "cryo_wraith", count = 8 }, { id = "frostfall_priest", count = 5 }, { id = "permafrost_beast", count = 4 } } },
                },
                reward = { gold = 5500, guaranteeEquipQuality = 2 },
            },
            -- 13-7: 寒渊祭坛 ⚠️装备墙2 (3波)
            {
                name = "寒渊祭坛",
                waves = {
                    { monsters = { { id = "glacial_titan", count = 3 }, { id = "glacier_caster", count = 5 }, { id = "frost_mite", count = 14 } } },
                    { monsters = { { id = "glacial_titan", count = 3 }, { id = "frostfall_priest", count = 4 }, { id = "rime_weaver", count = 5 } } },
                    { monsters = { { id = "glacial_titan", count = 2 }, { id = "ice_stalker", count = 9 }, { id = "cryo_wraith", count = 7 } } },
                },
                reward = { gold = 6800, guaranteeEquipQuality = 2 },
            },
            -- 13-8: 冰封熔炉 (全怪种3波)
            {
                name = "冰封熔炉",
                waves = {
                    { monsters = { { id = "frost_mite", count = 18 }, { id = "ice_stalker", count = 8 }, { id = "cryo_wraith", count = 7 } } },
                    { monsters = { { id = "rime_weaver", count = 7 }, { id = "glacier_caster", count = 5 }, { id = "permafrost_beast", count = 4 } } },
                    { monsters = { { id = "glacial_titan", count = 2 }, { id = "frostfall_priest", count = 4 }, { id = "ice_stalker", count = 7 } } },
                },
                reward = { gold = 8500, guaranteeEquipQuality = 2 },
            },
            -- 13-9: 永冻核心 ⚠️装备墙3 (3波)
            {
                name = "永冻核心",
                waves = {
                    { monsters = { { id = "glacial_titan", count = 3 }, { id = "glacier_caster", count = 7 }, { id = "rime_weaver", count = 5 } } },
                    { monsters = { { id = "frostfall_priest", count = 5 }, { id = "cryo_wraith", count = 10 }, { id = "ice_stalker", count = 9 } } },
                    { monsters = { { id = "glacial_titan", count = 2 }, { id = "frostfall_priest", count = 4 }, { id = "permafrost_beast", count = 5 }, { id = "glacier_caster", count = 5 } } },
                },
                reward = { gold = 11000, guaranteeEquipQuality = 3 },
            },
            -- 13-10: BOSS - 冰渊至尊·尼弗海姆
            {
                name = "冰渊至尊·尼弗海姆",
                isBoss = true,
                waves = {
                    { monsters = { { id = "frostfall_priest", count = 5 }, { id = "rime_weaver", count = 7 }, { id = "ice_stalker", count = 9 }, { id = "glacial_titan", count = 2 } } },
                    { monsters = { { id = "boss_ice_sovereign", count = 1 }, { id = "frost_mite", count = 32 }, { id = "cryo_wraith", count = 7 } } },
                },
                reward = { gold = 25000, guaranteeEquipQuality = 4 },
            },
        },
    },

    -- ==================== 第十四章: 腐蚀魔域 ====================
    {
        id = 14,
        name = "腐蚀魔域",
        desc = "瘴毒侵蚀的腐朽领域",
        lore = "穿越寒渊冰域的永冻裂隙后，你坠入了一片被剧毒侵蚀的远古领域。暗绿色的瘴毒从地底渗出，一切有机物都在缓慢腐朽。毒藤蔓延覆盖了远古神殿的残垣，腐蚀之力将万物化为尘土。腐蚀主宰·涅克洛斯端坐于腐朽深渊的核心，操控着防御衰减与毒蚀叠层，将入侵者的护甲一层层剥离。唯有以烈焰焚净他的腐蚀之体，才能终结这片瘴毒的诅咒。",
        stages = {
            -- 14-1: 毒沼入口 (过渡关)
            {
                name = "毒沼入口",
                waves = {
                    { monsters = { { id = "plague_mite", count = 30 } } },
                    { monsters = { { id = "plague_mite", count = 35 } } },
                },
                reward = { gold = 2800 },
            },
            -- 14-2: 孢子峡谷 (引入刺客)
            {
                name = "孢子峡谷",
                waves = {
                    { monsters = { { id = "plague_mite", count = 22 }, { id = "venom_stalker", count = 7 } } },
                    { monsters = { { id = "plague_mite", count = 18 }, { id = "venom_stalker", count = 10 } } },
                },
                reward = { gold = 3400 },
            },
            -- 14-3: 腐骨荒原 (引入坦克)
            {
                name = "腐骨荒原",
                waves = {
                    { monsters = { { id = "rot_beast", count = 4 }, { id = "plague_mite", count = 22 } } },
                    { monsters = { { id = "rot_beast", count = 5 }, { id = "venom_stalker", count = 8 } } },
                },
                reward = { gold = 4000 },
            },
            -- 14-4: 瘴毒裂隙 ⚠️装备墙1
            {
                name = "瘴毒裂隙",
                waves = {
                    { monsters = { { id = "miasma_weaver", count = 7 }, { id = "blight_caster", count = 5 }, { id = "plague_mite", count = 12 } } },
                    { monsters = { { id = "miasma_weaver", count = 5 }, { id = "blight_caster", count = 7 }, { id = "venom_stalker", count = 8 } } },
                },
                reward = { gold = 5000, guaranteeEquipQuality = 2 },
            },
            -- 14-5: BOSS - 剧毒母巢·维诺莎
            {
                name = "剧毒母巢·维诺莎",
                isBoss = true,
                waves = {
                    { monsters = { { id = "blight_caster", count = 7 }, { id = "miasma_weaver", count = 7 }, { id = "plague_mite", count = 14 } } },
                    { monsters = { { id = "boss_venom_mother", count = 1 }, { id = "plague_mite", count = 30 } } },
                },
                reward = { gold = 12000, guaranteeEquipQuality = 3 },
            },
            -- 14-6: 腐蚀深渊 (引入自爆+祭司)
            {
                name = "腐蚀深渊",
                waves = {
                    { monsters = { { id = "spore_wraith", count = 10 }, { id = "toxin_priest", count = 3 }, { id = "plague_mite", count = 16 } } },
                    { monsters = { { id = "spore_wraith", count = 8 }, { id = "toxin_priest", count = 5 }, { id = "rot_beast", count = 4 } } },
                },
                reward = { gold = 6200, guaranteeEquipQuality = 2 },
            },
            -- 14-7: 瘟疫祭坛 ⚠️装备墙2 (3波)
            {
                name = "瘟疫祭坛",
                waves = {
                    { monsters = { { id = "plague_titan", count = 3 }, { id = "blight_caster", count = 5 }, { id = "plague_mite", count = 16 } } },
                    { monsters = { { id = "plague_titan", count = 3 }, { id = "toxin_priest", count = 4 }, { id = "miasma_weaver", count = 5 } } },
                    { monsters = { { id = "plague_titan", count = 2 }, { id = "venom_stalker", count = 10 }, { id = "spore_wraith", count = 7 } } },
                },
                reward = { gold = 7500, guaranteeEquipQuality = 2 },
            },
            -- 14-8: 毒藤熔炉 (全怪种3波)
            {
                name = "毒藤熔炉",
                waves = {
                    { monsters = { { id = "plague_mite", count = 20 }, { id = "venom_stalker", count = 8 }, { id = "spore_wraith", count = 7 } } },
                    { monsters = { { id = "miasma_weaver", count = 7 }, { id = "blight_caster", count = 5 }, { id = "rot_beast", count = 5 } } },
                    { monsters = { { id = "plague_titan", count = 2 }, { id = "toxin_priest", count = 4 }, { id = "venom_stalker", count = 8 } } },
                },
                reward = { gold = 9500, guaranteeEquipQuality = 2 },
            },
            -- 14-9: 腐朽核心 ⚠️装备墙3 (3波)
            {
                name = "腐朽核心",
                waves = {
                    { monsters = { { id = "plague_titan", count = 3 }, { id = "blight_caster", count = 7 }, { id = "miasma_weaver", count = 5 } } },
                    { monsters = { { id = "toxin_priest", count = 5 }, { id = "spore_wraith", count = 10 }, { id = "venom_stalker", count = 10 } } },
                    { monsters = { { id = "plague_titan", count = 2 }, { id = "toxin_priest", count = 4 }, { id = "rot_beast", count = 5 }, { id = "blight_caster", count = 5 } } },
                },
                reward = { gold = 12500, guaranteeEquipQuality = 3 },
            },
            -- 14-10: BOSS - 腐蚀主宰·涅克洛斯
            {
                name = "腐蚀主宰·涅克洛斯",
                isBoss = true,
                waves = {
                    { monsters = { { id = "toxin_priest", count = 5 }, { id = "miasma_weaver", count = 7 }, { id = "venom_stalker", count = 10 }, { id = "plague_titan", count = 2 } } },
                    { monsters = { { id = "boss_plague_sovereign", count = 1 }, { id = "plague_mite", count = 35 }, { id = "spore_wraith", count = 7 } } },
                },
                reward = { gold = 28000, guaranteeEquipQuality = 4 },
            },
        },
    },
    -- ==================== 第十五章: 天火之泉 ====================
    {
        id = 15,
        name = "天火之泉",
        desc = "天火涌动的灼热泉源",
        lore = "封印腐蚀主宰之后，你踏入了一片天火与熔泉交织的灼热秘境。沸腾的火泉从大地深处喷涌而出，将整片区域笼罩在炽白的蒸汽与硫磺之中。火元素——曾经是你对抗冰霜与毒素的最强武器——如今成了最致命的敌人。焚天魔君·萨拉曼德统御着这片天火之源，以灼烧剥夺你的攻速，以焚灼放大你承受的一切伤害。唯有以水之力淬灭天火，才能在这场DPS竞速中生存。",
        stages = {
            -- 15-1: 灼泉入口 (过渡关)
            {
                name = "灼泉入口",
                waves = {
                    { monsters = { { id = "flame_imp", count = 30 } } },
                    { monsters = { { id = "flame_imp", count = 35 } } },
                },
                reward = { gold = 3400 },
            },
            -- 15-2: 沸泉峡谷 (引入刺客)
            {
                name = "沸泉峡谷",
                waves = {
                    { monsters = { { id = "flame_imp", count = 22 }, { id = "ember_stalker", count = 7 } } },
                    { monsters = { { id = "flame_imp", count = 18 }, { id = "ember_stalker", count = 10 } } },
                },
                reward = { gold = 4100 },
            },
            -- 15-3: 焰泉荒原 (引入坦克)
            {
                name = "焰泉荒原",
                waves = {
                    { monsters = { { id = "magma_beast", count = 4 }, { id = "flame_imp", count = 22 } } },
                    { monsters = { { id = "magma_beast", count = 5 }, { id = "ember_stalker", count = 8 } } },
                },
                reward = { gold = 4800 },
            },
            -- 15-4: 炽焰裂隙 ⚠️装备墙1
            {
                name = "天火裂隙",
                waves = {
                    { monsters = { { id = "hellfire_weaver", count = 7 }, { id = "inferno_caster", count = 5 }, { id = "flame_imp", count = 12 } } },
                    { monsters = { { id = "hellfire_weaver", count = 5 }, { id = "inferno_caster", count = 7 }, { id = "ember_stalker", count = 8 } } },
                },
                reward = { gold = 6000, guaranteeEquipQuality = 2 },
            },
            -- 15-5: BOSS - 灼翼领主·伊格尼斯
            {
                name = "灼翼领主·伊格尼斯",
                isBoss = true,
                waves = {
                    { monsters = { { id = "inferno_caster", count = 7 }, { id = "hellfire_weaver", count = 7 }, { id = "flame_imp", count = 14 } } },
                    { monsters = { { id = "boss_flame_lord", count = 1 }, { id = "flame_imp", count = 30 } } },
                },
                reward = { gold = 14400, guaranteeEquipQuality = 3 },
            },
            -- 15-6: 沉渊泉眼 (引入自爆+祭司)
            {
                name = "沉渊泉眼",
                waves = {
                    { monsters = { { id = "cinder_wraith", count = 10 }, { id = "pyre_priest", count = 3 }, { id = "flame_imp", count = 16 } } },
                    { monsters = { { id = "cinder_wraith", count = 8 }, { id = "pyre_priest", count = 5 }, { id = "magma_beast", count = 4 } } },
                },
                reward = { gold = 7400, guaranteeEquipQuality = 2 },
            },
            -- 15-7: 涌火祭坛 ⚠️装备墙2 (3波)
            {
                name = "涌火祭坛",
                waves = {
                    { monsters = { { id = "flame_titan", count = 3 }, { id = "inferno_caster", count = 5 }, { id = "flame_imp", count = 16 } } },
                    { monsters = { { id = "flame_titan", count = 3 }, { id = "pyre_priest", count = 4 }, { id = "hellfire_weaver", count = 5 } } },
                    { monsters = { { id = "flame_titan", count = 2 }, { id = "ember_stalker", count = 10 }, { id = "cinder_wraith", count = 7 } } },
                },
                reward = { gold = 9000, guaranteeEquipQuality = 2 },
            },
            -- 15-8: 熔泉熔炉 (全怪种3波)
            {
                name = "熔泉熔炉",
                waves = {
                    { monsters = { { id = "flame_imp", count = 20 }, { id = "ember_stalker", count = 8 }, { id = "cinder_wraith", count = 7 } } },
                    { monsters = { { id = "hellfire_weaver", count = 7 }, { id = "inferno_caster", count = 5 }, { id = "magma_beast", count = 5 } } },
                    { monsters = { { id = "flame_titan", count = 2 }, { id = "pyre_priest", count = 4 }, { id = "ember_stalker", count = 8 } } },
                },
                reward = { gold = 11400, guaranteeEquipQuality = 2 },
            },
            -- 15-9: 天火之心 ⚠️装备墙3 (3波)
            {
                name = "天火之心",
                waves = {
                    { monsters = { { id = "flame_titan", count = 3 }, { id = "inferno_caster", count = 7 }, { id = "hellfire_weaver", count = 5 } } },
                    { monsters = { { id = "pyre_priest", count = 5 }, { id = "cinder_wraith", count = 10 }, { id = "ember_stalker", count = 10 } } },
                    { monsters = { { id = "flame_titan", count = 2 }, { id = "pyre_priest", count = 4 }, { id = "magma_beast", count = 5 }, { id = "inferno_caster", count = 5 } } },
                },
                reward = { gold = 15000, guaranteeEquipQuality = 3 },
            },
            -- 15-10: BOSS - 焚天魔君·萨拉曼德
            {
                name = "焚天魔君·萨拉曼德",
                isBoss = true,
                waves = {
                    { monsters = { { id = "pyre_priest", count = 5 }, { id = "hellfire_weaver", count = 7 }, { id = "ember_stalker", count = 10 }, { id = "flame_titan", count = 2 } } },
                    { monsters = { { id = "boss_inferno_sovereign", count = 1 }, { id = "flame_imp", count = 35 }, { id = "cinder_wraith", count = 7 } } },
                },
                reward = { gold = 33600, guaranteeEquipQuality = 4 },
            },
        },
    },
    -- ========================================================================
    -- 第16章: 深渊潮汐
    -- ========================================================================
    {
        name = "深渊潮汐",
        element = "water",
        stages = {
            -- 16-1: 潮汐滩涂 (纯蜂群)
            {
                name = "潮汐滩涂",
                waves = {
                    { monsters = { { id = "tidal_crab", count = 30 } } },
                    { monsters = { { id = "tidal_crab", count = 35 } } },
                },
                reward = { gold = 4100 },
            },
            -- 16-2: 沉船墓场 (引入刺客)
            {
                name = "沉船墓场",
                waves = {
                    { monsters = { { id = "tidal_crab", count = 22 }, { id = "abyssal_stingray", count = 8 } } },
                    { monsters = { { id = "tidal_crab", count = 18 }, { id = "abyssal_stingray", count = 10 } } },
                },
                reward = { gold = 5000 },
            },
            -- 16-3: 珊瑚迷宫 (引入坦克)
            {
                name = "珊瑚迷宫",
                waves = {
                    { monsters = { { id = "coral_tortoise", count = 5 }, { id = "tidal_crab", count = 22 } } },
                    { monsters = { { id = "coral_tortoise", count = 6 }, { id = "abyssal_stingray", count = 8 } } },
                },
                reward = { gold = 5800, guaranteeEquipQuality = 1 },
            },
            -- 16-4: 深渊裂口 (装备墙：控制+远程)
            {
                name = "深渊裂口",
                waves = {
                    { monsters = { { id = "coil_serpent", count = 8 }, { id = "deepsea_warlock", count = 6 }, { id = "tidal_crab", count = 12 } } },
                    { monsters = { { id = "coil_serpent", count = 6 }, { id = "deepsea_warlock", count = 8 }, { id = "abyssal_stingray", count = 8 } } },
                },
                reward = { gold = 7200, guaranteeEquipQuality = 1 },
            },
            -- 16-5: BOSS - 潮涌将领·塞壬
            {
                name = "潮涌将领·塞壬",
                isBoss = true,
                waves = {
                    { monsters = { { id = "deepsea_warlock", count = 8 }, { id = "coil_serpent", count = 8 }, { id = "tidal_crab", count = 15 } } },
                    { monsters = { { id = "boss_tide_commander", count = 1 }, { id = "tidal_crab", count = 30 } } },
                },
                reward = { gold = 17300, guaranteeEquipQuality = 3 },
            },
            -- 16-6: 海蚀洞穴 (引入自爆+祭司)
            {
                name = "海蚀洞穴",
                waves = {
                    { monsters = { { id = "bloat_jellyfish", count = 12 }, { id = "tide_hierophant", count = 4 }, { id = "tidal_crab", count = 15 } } },
                    { monsters = { { id = "bloat_jellyfish", count = 10 }, { id = "tide_hierophant", count = 5 }, { id = "coral_tortoise", count = 4 } } },
                },
                reward = { gold = 8900, guaranteeEquipQuality = 2 },
            },
            -- 16-7: 深海祭坛 ⚠️装备墙2 (超级坦克登场)
            {
                name = "深海祭坛",
                waves = {
                    { monsters = { { id = "ancient_kraken", count = 3 }, { id = "deepsea_warlock", count = 6 }, { id = "tidal_crab", count = 15 } } },
                    { monsters = { { id = "ancient_kraken", count = 4 }, { id = "tide_hierophant", count = 5 }, { id = "coil_serpent", count = 6 } } },
                    { monsters = { { id = "ancient_kraken", count = 3 }, { id = "abyssal_stingray", count = 10 }, { id = "bloat_jellyfish", count = 8 } } },
                },
                reward = { gold = 10800, guaranteeEquipQuality = 2 },
            },
            -- 16-8: 万潮回廊 (全种类3波混战)
            {
                name = "万潮回廊",
                waves = {
                    { monsters = { { id = "tidal_crab", count = 20 }, { id = "abyssal_stingray", count = 10 }, { id = "bloat_jellyfish", count = 8 } } },
                    { monsters = { { id = "coil_serpent", count = 8 }, { id = "deepsea_warlock", count = 6 }, { id = "coral_tortoise", count = 5 } } },
                    { monsters = { { id = "ancient_kraken", count = 3 }, { id = "tide_hierophant", count = 5 }, { id = "abyssal_stingray", count = 8 } } },
                },
                reward = { gold = 13700, guaranteeEquipQuality = 2 },
            },
            -- 16-9: 勒维坦之眼 ⚠️装备墙3 (全精英)
            {
                name = "勒维坦之眼",
                waves = {
                    { monsters = { { id = "ancient_kraken", count = 4 }, { id = "deepsea_warlock", count = 8 }, { id = "coil_serpent", count = 6 } } },
                    { monsters = { { id = "tide_hierophant", count = 6 }, { id = "bloat_jellyfish", count = 12 }, { id = "abyssal_stingray", count = 10 } } },
                    { monsters = { { id = "ancient_kraken", count = 3 }, { id = "tide_hierophant", count = 4 }, { id = "coral_tortoise", count = 6 }, { id = "deepsea_warlock", count = 6 } } },
                },
                reward = { gold = 18000, guaranteeEquipQuality = 3 },
            },
            -- 16-10: BOSS - 万潮海主·勒维坦
            {
                name = "万潮海主·勒维坦",
                isBoss = true,
                waves = {
                    { monsters = { { id = "tide_hierophant", count = 6 }, { id = "coil_serpent", count = 8 }, { id = "abyssal_stingray", count = 10 }, { id = "ancient_kraken", count = 3 } } },
                    { monsters = { { id = "boss_abyssal_leviathan", count = 1 }, { id = "tidal_crab", count = 35 }, { id = "bloat_jellyfish", count = 8 } } },
                },
                reward = { gold = 40300, guaranteeEquipQuality = 4 },
            },
        },
    },
    -- ========================================================================
    -- 第17章: 焰息回廊 (复用第一章结构, 火系元素, 数值缩放)
    -- ========================================================================
    {
        id = 17,
        name = "焰息回廊",
        desc = "灰烬荒原的烈焰重生",
        lore = "封印深渊潮汐之后，术士感应到焰息城方向传来异常的灼热波动。曾经的灰烬荒原在一场神秘的焰爆中重生，大地裂开喷涌岩浆，灰烬中诞生了全新的火系生物。它们比荒原初代怪物强大百倍，以烈焰为食、以灰烬为巢。焰息城的结界已被高温灼穿，你必须重返这片浴火重生的战场，击败焰息回廊深处的灰烬巨像·炎狱。",
        element = "fire",
        stages = {
            -- 17-1: 焰息边缘 (纯蜂群入门)
            {
                name = "焰息边缘",
                waves = {
                    { monsters = { { id = "ember_swarm", count = 25 } } },
                    { monsters = { { id = "ember_swarm", count = 30 } } },
                },
                reward = { gold = 4800 },
            },
            -- 17-2: 熔壳田野 (引入肉盾)
            {
                name = "熔壳田野",
                waves = {
                    { monsters = { { id = "ember_swarm", count = 20 }, { id = "molten_worm", count = 6 } } },
                    { monsters = { { id = "ember_swarm", count = 15 }, { id = "molten_worm", count = 8 } } },
                },
                reward = { gold = 5800 },
            },
            -- 17-3: 灰烬石桥 (脆皮蝙蝠海)
            {
                name = "灰烬石桥",
                waves = {
                    { monsters = { { id = "cinder_bat", count = 30 } } },
                    { monsters = { { id = "cinder_bat", count = 35 } } },
                },
                reward = { gold = 6800 },
            },
            -- 17-4: 焰卫营地 (引入精英劫匪)
            {
                name = "焰卫营地",
                waves = {
                    { monsters = { { id = "ember_swarm", count = 20 }, { id = "flame_bandit", count = 8 } } },
                    { monsters = { { id = "flame_bandit", count = 10 }, { id = "molten_worm", count = 6 } } },
                },
                reward = { gold = 8200, guaranteeEquipQuality = 1 },
            },
            -- 17-5: BOSS - 焰息守卫·炎魔
            {
                name = "焰息守卫·炎魔",
                isBoss = true,
                waves = {
                    { monsters = { { id = "flame_bandit", count = 12 }, { id = "molten_worm", count = 6 } } },
                    { monsters = { { id = "boss_ember_guard", count = 1 }, { id = "ember_swarm", count = 20 } } },
                },
                reward = { gold = 20000, guaranteeEquipQuality = 3 },
            },
            -- 17-6: 焰孢森林 (引入减速+焰灵, 混合蜂群)
            {
                name = "焰孢森林",
                waves = {
                    { monsters = { { id = "molten_worm", count = 8 }, { id = "ember_shroom", count = 8 }, { id = "fire_wisp", count = 10 } } },
                    { monsters = { { id = "fire_wisp", count = 15 }, { id = "molten_worm", count = 8 } } },
                },
                reward = { gold = 10200 },
            },
            -- 17-7: 熔岩沼泽 (减速地狱)
            {
                name = "熔岩沼泽",
                waves = {
                    { monsters = { { id = "ember_shroom", count = 10 }, { id = "magma_frog", count = 10 }, { id = "fire_wisp", count = 8 } } },
                    { monsters = { { id = "lava_crab", count = 6 }, { id = "magma_frog", count = 10 }, { id = "ember_shroom", count = 8 } } },
                },
                reward = { gold = 12000 },
            },
            -- 17-8: 焰息深处 (三波大混战)
            {
                name = "焰息深处",
                waves = {
                    { monsters = { { id = "cinder_bat", count = 20 }, { id = "flame_bandit", count = 8 } } },
                    { monsters = { { id = "flame_bandit", count = 10 }, { id = "molten_worm", count = 8 } } },
                    { monsters = { { id = "cinder_bat", count = 15 }, { id = "magma_frog", count = 10 } } },
                },
                reward = { gold = 15000, guaranteeEquipQuality = 2 },
            },
            -- 17-9: 焰息之源 (三波高密度)
            {
                name = "焰息之源",
                waves = {
                    { monsters = { { id = "cinder_bat", count = 25 }, { id = "ember_shroom", count = 8 } } },
                    { monsters = { { id = "magma_frog", count = 12 }, { id = "flame_bandit", count = 10 } } },
                    { monsters = { { id = "cinder_bat", count = 20 }, { id = "lava_crab", count = 6 } } },
                },
                reward = { gold = 21000, guaranteeEquipQuality = 3 },
            },
            -- 17-10: BOSS - 灰烬巨像·炎狱
            {
                name = "灰烬巨像·炎狱",
                isBoss = true,
                waves = {
                    { monsters = { { id = "cinder_bat", count = 20 }, { id = "magma_frog", count = 10 }, { id = "flame_bandit", count = 8 } } },
                    { monsters = { { id = "boss_ember_golem", count = 1 }, { id = "ember_swarm", count = 25 } } },
                },
                reward = { gold = 46500, guaranteeEquipQuality = 4 },
            },
        },
    },
}

-- ============================================================================
-- 辅助函数
-- ============================================================================

--- 获取指定章节关卡配置（双轨：手写 stages 或自动编排 families）
---@param chapter number 章节编号 (从1开始)
---@param stage number 关卡编号 (从1开始)
---@return table|nil stageCfg, table|nil chapterCfg
function StageConfig.GetStage(chapter, stage)
    local ch = StageConfig.CHAPTERS[chapter]
    if not ch then return nil, nil end

    -- 双轨: 有 stages → 旧逻辑; 有 families 且无 stages → 自动编排
    if ch.stages then
        return ch.stages[stage], ch
    elseif ch.families then
        local generated = getGeneratedStages(ch, chapter)
        return generated[stage], ch
    end
    return nil, ch
end

--- 获取章节总关卡数（双轨兼容）
function StageConfig.GetStageCount(chapter)
    local ch = StageConfig.CHAPTERS[chapter]
    if not ch then return 0 end
    if ch.stages then
        return #ch.stages
    elseif ch.families then
        return #STAGE_TEMPLATES  -- 自动编排固定 10 关
    end
    return 0
end

--- 获取总章节数
function StageConfig.GetChapterCount()
    return #StageConfig.CHAPTERS
end

-- ============================================================================
-- 动态 scaleMul 计算 (v1.9.1: 替代硬编码值, 与 tierMul 对齐)
-- ============================================================================
-- 设计目标:
--   scaleMul = difficultyRatio × tierMul(chapter)
--   difficultyRatio 在章节内从 s1 到 s10 指数递增 (~5.57x)
--   difficultyRatio 随章节缓慢增长 (每章 +8%), 模拟玩家技能/套装的额外成长
--
-- 效果:
--   ch1 s1=1.4  s10=7.8   (与旧值完全相同)
--   ch6 s1=77.5 s10=431.6 (旧值: 40800~170000, 大幅下调)
--   ch12 s1=143 s10=798   (旧值: 1.04亿~5.2亿, 大幅下调)
-- ============================================================================

--- 章节内关卡难度插值系数 (指数插值, s1=1.0, s10=5.5714)
local STAGE_RAMP = 5.5714  -- = 7.8 / 1.4, 章节内 boss 是初始的 5.57 倍

-- ============================================================================
-- 玩家战力乘数表 (v2: 追踪分裂弹/攻速/暴击等 scaleMul 未覆盖的战力成长)
-- 锚定依据: 典型玩家DPS(极限×40%) 在各章末击杀 swarm(hp=35) 约2秒
-- 调节方式: 增大某章值 → 该章怪物更肉; 减小 → 更脆
-- 详见: docs/数值/数值锚定与战力曲线.md §2.4, §3.4
-- ============================================================================
local PLAYER_POWER_MUL = {
    --  Ch1: 教程阶段, 无分裂弹/暴击/装备, scaleMul 已吻合
    [1]  = 1,
    --  Ch2: 装备初步成型, 无分裂弹
    [2]  = 55,
    --  Ch3: 分裂弹部分成型(碎裂lv3≈7弹), 有一定暴击
    [3]  = 80,
    --  Ch4: 分裂弹+暴击进一步成长
    [4]  = 105,
    --  Ch5: 分裂弹接近满配(13弹), 攻速cap开始拉开
    [5]  = 200,
    --  Ch6: 分裂弹满配, 暴击率60%+
    [6]  = 350,
    --  Ch7: 攻速/暴击继续增长
    [7]  = 490,
    --  Ch8: 暴击率接近溢出
    [8]  = 640,
    --  Ch9: 暴击开始溢出转暴伤
    [9]  = 850,
    -- Ch10: 全面成长
    [10] = 1060,
    -- Ch11: 接近极限
    [11] = 1260,
    -- Ch12: 极限build满配
    [12] = 1440,
    -- Ch13: 冰系新元素体系
    [13] = 1630,
    -- Ch14: 毒系腐蚀体系, 防御衰减+DoT叠加
    [14] = 1820,
    -- Ch15: 火系焚天体系, 攻速衰减+受伤增幅
    [15] = 2020,
    -- Ch16: 水系深渊潮汐, 暴击衰减+浸蚀叠层
    [16] = 2230,
    -- Ch17: 火系焰息回廊, 复用灰烬荒原结构+焰灼体系
    [17] = 2450,
}

--- 获取玩家战力乘数 (对未定义章节线性插值)
---@param chapter number 章节编号
---@return number playerPowerMul
local function getPlayerPowerMul(chapter)
    if chapter <= 1 then return 1 end
    if chapter >= 17 then return PLAYER_POWER_MUL[17] end

    local lo = math.floor(chapter)
    local hi = lo + 1
    local loVal = PLAYER_POWER_MUL[lo] or 1
    local hiVal = PLAYER_POWER_MUL[hi] or loVal
    local frac = chapter - lo
    return loVal + (hiVal - loVal) * frac
end

--- 计算动态 scaleMul (替代硬编码值)
---@param chapter number 章节编号 (从1开始)
---@param stageIdx number 关卡编号 (从1开始)
---@return number scaleMul
function StageConfig.CalcScaleMul(chapter, stageIdx)
    local Config = require("Config")
    local tierMul = Config.GetChapterTier(chapter)

    -- 难度比率: 随章节缓慢增长 (每章 +6%)
    local chGrowth = 1 + 0.06 * (chapter - 1)
    local baseRatio_s1 = 1.15 * chGrowth
    -- 章节内指数插值
    local stageCount = StageConfig.GetStageCount(chapter)
    local t = (stageIdx - 1) / math.max(1, stageCount - 1)  -- 0.0 ~ 1.0
    local difficultyRatio = baseRatio_s1 * (STAGE_RAMP ^ t)

    -- 玩家战力乘数: 追踪分裂弹/攻速/暴击带来的DPS倍增
    local powerMul = getPlayerPowerMul(chapter)

    return difficultyRatio * tierMul * powerMul
end

--- 获取关卡的 scaleMul (优先动态计算)
---@param chapter number 章节编号
---@param stage number 关卡编号
---@return number scaleMul
function StageConfig.GetScaleMul(chapter, stage)
    if chapter and stage and chapter >= 1 and stage >= 1 then
        return StageConfig.CalcScaleMul(chapter, stage)
    end
    return 1.0
end

return StageConfig
