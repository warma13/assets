-- Game/RecruitData.lua
-- 招募系统逻辑（对齐咸鱼之王）
-- 招募令抽卡 → 碎片产出 → 自动解锁

local Config = require("Game.Config")
local HeroData = require("Game.HeroData")

local RecruitData = {}

--- 获取今日日期字符串 "YYYY-MM-DD"
---@return string
local function GetTodayStr()
    return os.date("%Y-%m-%d") or ""
end

--- 是否可以免费单抽（每天一次）
---@return boolean
function RecruitData.CanFreePull()
    local rd = HeroData.recruitData
    return rd.freeDaily ~= GetTodayStr()
end

--- 是否有足够招募令
---@param count number  需要的令数
---@return boolean
function RecruitData.CanAfford(count)
    return (HeroData.currencies.void_pact or 0) >= count
end

--- 随机一个稀有度
---@param forcePity boolean  是否强制SSR
---@return string rarity
local function RollRarity(forcePity)
    if forcePity then return "SSR" end
    local roll = math.random(1, 100)
    if roll <= Config.RECRUIT_RATES.SSR then
        return "SSR"
    elseif roll <= Config.RECRUIT_RATES.SSR + Config.RECRUIT_RATES.SR then
        return "SR"
    else
        return "R"
    end
end

--- 随机一个英雄并发放奖励
---@param rarity string
---@return table
local function ResolveHero(rarity)
    local pool = Config.RECRUIT_POOL[rarity]
    local heroId = pool[math.random(1, #pool)]

    local heroName = heroId
    for _, td in ipairs(Config.TOWER_TYPES) do
        if td.id == heroId then
            heroName = td.name
            break
        end
    end

    -- 咸鱼之王机制：首次获得 → 直接解锁，重复 → 碎片
    local isNew = not HeroData.IsUnlocked(heroId)
    local fragments = 0
    if isNew then
        HeroData.UnlockHero(heroId)
    else
        local fragRange = Config.RECRUIT_FRAGMENT_DROP[rarity]
        fragments = math.random(fragRange.min, fragRange.max)
        HeroData.AddFragments(heroId, fragments)
    end

    return {
        heroId = heroId,
        heroName = heroName,
        rarity = rarity,
        fragments = fragments,
        isNew = isNew,
    }
end

--- 执行招募（单抽或十连）
---@param pullCount number  1 或 10
---@param isFree boolean  是否使用免费次数（仅单抽）
---@return boolean success
---@return table|string  results数组 或 错误信息
function RecruitData.DoPull(pullCount, isFree)
    local rd = HeroData.recruitData
    local cost = pullCount == 10 and Config.RECRUIT_TEN_COST or Config.RECRUIT_SINGLE_COST

    -- 检查消耗
    if isFree and pullCount == 1 then
        if not RecruitData.CanFreePull() then
            return false, "今日免费次数已用"
        end
    else
        if not RecruitData.CanAfford(cost) then
            return false, "虚空契约不足(需要" .. cost .. "，当前" .. (HeroData.currencies.void_pact or 0) .. ")"
        end
    end

    -- 扣除消耗
    if isFree and pullCount == 1 then
        rd.freeDaily = GetTodayStr()
    else
        HeroData.currencies.void_pact = HeroData.currencies.void_pact - cost
    end

    -- 先决定每抽的稀有度
    local rarities = {}
    for i = 1, pullCount do
        rd.totalPulls = rd.totalPulls + 1
        rarities[i] = RollRarity(false)
    end

    -- 十连保底：如果10连中没有SSR及以上，随机一个位置强制SSR
    if pullCount >= 10 then
        local hasSSR = false
        for _, r in ipairs(rarities) do
            if r == "SSR" or r == "UR" or r == "LR" then
                hasSSR = true
                break
            end
        end
        if not hasSSR then
            local idx = math.random(1, #rarities)
            rarities[idx] = "SSR"
            print("[RecruitData] 10-pull pity triggered at index " .. idx)
        end
    end

    -- 按确定的稀有度发放奖励
    local results = {}
    for i = 1, pullCount do
        results[i] = ResolveHero(rarities[i])
    end

    -- 保存
    HeroData.Save()

    print("[RecruitData] Pulled " .. pullCount .. " times")
    return true, results
end

--- 获取历史总抽数
---@return number
function RecruitData.GetTotalPulls()
    return HeroData.recruitData.totalPulls
end

return RecruitData
