-- Game/HeroUI.lua
-- 英雄养成页面（咸鱼之王风格 - 简约暖色调）
-- 主页：主角 + 上阵英雄列表 + 升级/进阶
-- 弹出层：英雄收藏网格（上阵/下阵管理）

local Config = require("Game.Config")
local HeroData = require("Game.HeroData")
local Currency = require("Game.Currency")
local InventoryUI = require("Game.InventoryUI")

local HeroUI = {}

--- 格式化大数字 (对齐咸鱼之王显示风格)
---@param n number
---@return string
local function FormatBigNum(n)
    if n >= 100000000 then
        return string.format("%.1f亿", n / 100000000)
    elseif n >= 10000 then
        return string.format("%.1f万", n / 10000)
    else
        return tostring(math.floor(n))
    end
end

-- ============================================================================
-- 咸鱼之王简约风配色
-- ============================================================================
local S = {
    -- 页面
    pageBg        = { 42, 30, 22, 255 },
    -- 货币栏
    currBg        = { 50, 36, 26, 240 },
    currBorder    = { 75, 55, 38, 100 },
    -- 卡片
    cardBg        = { 55, 42, 32, 240 },
    cardBorder    = { 80, 62, 44, 120 },
    cardLocked    = { 45, 38, 32, 200 },
    -- 文字
    white         = { 245, 238, 225, 255 },
    dim           = { 170, 155, 135, 200 },
    dimLocked     = { 130, 120, 110, 160 },
    gold          = { 255, 215, 80, 255 },
    powerYellow   = { 255, 220, 100, 255 },
    -- 进度条
    progBg        = { 30, 22, 16, 220 },
    progFill      = { 90, 180, 65, 255 },
    progFillMax   = { 210, 165, 45, 255 },
    -- 升级按钮
    btnGreen      = { 75, 165, 55, 255 },
    btnGreenDark  = { 60, 135, 45, 255 },
    btnDisabled   = { 65, 58, 48, 220 },
    btnAdvance    = { 200, 140, 40, 255 },
    btnText       = { 255, 255, 255, 255 },
    -- 头像等级徽章
    lvBadgeBg     = { 0, 0, 0, 180 },
    -- 收藏弹出层
    overlayBg     = { 0, 0, 0, 180 },
    popupBg       = { 42, 30, 22, 250 },
    popupBorder   = { 90, 70, 50, 200 },
    checkGreen    = { 60, 200, 80, 255 },
    checkBg       = { 40, 160, 60, 240 },
    lockOverlay   = { 0, 0, 0, 120 },
    deployedCount = { 255, 200, 80, 255 },
    deployFull    = { 255, 100, 80, 255 },
    -- 收藏按钮
    collectBtn    = { 180, 120, 50, 255 },
    collectBtnBorder = { 220, 160, 70, 255 },
}

-- 稀有度排序值（高品质在前）
local RARITY_ORDER = { LR = 6, UR = 5, SSR = 4, SR = 3, R = 2, N = 1 }

---@type any
local UI = nil
---@type any
local pageRoot = nil
---@type any
local collectionOverlay = nil  -- 上阵弹出层引用
---@type any
local collectionDetailOverlay = nil  -- 英雄收藏弹出层引用
---@type any
local heroDetailOverlay = nil  -- 英雄详情面板引用


-- ============================================================================
-- 多级升级计算
-- ============================================================================

--- 计算批量升级的总金币消耗
---@param heroId string
---@param count number  期望升的级数
---@return number totalCost, number actualLevels
local function CalcBatchUpgradeCost(heroId, count)
    local h = HeroData.Get(heroId)
    if not h then return 0, 0 end
    local cap = HeroData.GetCurrentLevelCap(heroId)
    local curLevel = h.level
    local total = 0
    local actual = 0
    for i = 0, count - 1 do
        local lv = curLevel + i
        if lv >= cap then break end
        if lv >= Config.MAX_LEVEL then break end
        total = total + HeroData.GetLevelUpCost(lv)
        actual = actual + 1
    end
    return total, actual
end

--- 计算最佳多级升级方案
---@param heroId string
---@return table|nil
local function GetBestUpgradeTier(heroId)
    local gold = HeroData.currencies.nether_crystal or 0
    local tiers = { 100, 50, 10, 1 }
    for _, tier in ipairs(tiers) do
        local cost, actual = CalcBatchUpgradeCost(heroId, tier)
        if actual >= tier and gold >= cost then
            return { tier = tier, cost = cost, actual = actual }
        end
    end
    local cost1, actual1 = CalcBatchUpgradeCost(heroId, 1)
    if actual1 >= 1 and gold >= cost1 then
        return { tier = 1, cost = cost1, actual = 1 }
    end
    return nil
end

--- 执行批量升级
---@param heroId string
---@param count number
local function DoBatchLevelUp(heroId, count)
    for _ = 1, count do
        local ok, _ = HeroData.LevelUp(heroId)
        if not ok then break end
    end
end

-- ============================================================================
-- 进阶门槛计算
-- ============================================================================

--- 获取下一个进阶门槛等级
---@param heroId string
---@return number
local function GetNextGateLevel(heroId)
    local advLv = HeroData.GetAdvanceLevel(heroId)
    local nextIdx = advLv + 1
    local gate = Config.ADVANCE_GATES[nextIdx]
    if gate then return gate.level end
    return Config.MAX_LEVEL
end

--- 获取上一个已通过的门槛等级
---@param heroId string
---@return number
local function GetPrevGateLevel(heroId)
    local advLv = HeroData.GetAdvanceLevel(heroId)
    if advLv <= 0 then return 0 end
    local gate = Config.ADVANCE_GATES[advLv]
    if gate then return gate.level end
    return 0
end

-- ============================================================================
-- 通用：Toast 提示（使用全局 Toast 模块，支持上浮淡出自动消失）
-- ============================================================================
local Toast = require("Game.Toast")

local function ShowToast(msg)
    Toast.Show(msg)
end

-- ============================================================================
-- 通用：稀有度颜色
-- ============================================================================

--- 稀有度背景色
---@param rarity string
---@return table
local function GetRarityColor(rarity)
    if rarity == "LR" then return { 180, 30, 30, 220 } end
    if rarity == "UR" then return { 200, 150, 30, 220 } end
    if rarity == "SSR" then return { 150, 55, 190, 200 } end
    if rarity == "SR" then return { 45, 115, 195, 200 } end
    if rarity == "N" then return { 130, 120, 110, 200 } end
    if rarity == "none" then return { 140, 90, 200, 220 } end
    return { 75, 125, 55, 200 } -- R
end

--- 稀有度边框色（更亮的版本）
---@param rarity string
---@return table
local function GetRarityBorderColor(rarity)
    if rarity == "LR" then return { 255, 60, 60, 255 } end
    if rarity == "UR" then return { 255, 215, 60, 255 } end
    if rarity == "SSR" then return { 200, 100, 255, 255 } end
    if rarity == "SR" then return { 80, 160, 255, 255 } end
    if rarity == "N" then return { 170, 160, 150, 180 } end
    return { 100, 200, 80, 220 } -- R
end

-- ============================================================================
-- 主页：英雄列表（主角 + 上阵英雄 + 空阵位）
-- ============================================================================

--- 创建空阵位占位卡片
local function CreateEmptySlot(slotIndex)
    return UI.Panel {
        width = "100%",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = { 40, 32, 26, 150 },
        borderRadius = 8,
        borderWidth = 1,
        borderColor = { 60, 50, 40, 100 },
        borderStyle = "dashed",
        children = {
            UI.Label {
                text = "空阵位",
                fontSize = 13,
                fontColor = S.dim,
            },
        },
    }
end

--- 生成星级图标行（多行排列，每行最多5颗）
---@param starCount number  总星数
---@param tierColor table   星星颜色
---@return table[]  UI children
local function CreateStarRows(starCount, tierColor)
    if starCount <= 0 then return {} end
    local rows = {}
    local remaining = starCount
    while remaining > 0 do
        local thisRow = math.min(remaining, 5)
        local stars = {}
        for i = 1, thisRow do
            stars[#stars + 1] = UI.Label {
                text = "★",
                fontSize = 7,
                fontColor = tierColor,
            }
        end
        rows[#rows + 1] = UI.Panel {
            flexDirection = "row",
            gap = 0,
            justifyContent = "center",
            children = stars,
        }
        remaining = remaining - thisRow
    end
    return rows
end

--- 创建单个英雄行（咸鱼之王横条风格 5:1）
local function CreateHeroRow(heroDef, isLeader)
    local heroId = heroDef.id
    local h = HeroData.Get(heroId)
    local isUnlocked = h and h.unlocked or false
    local level = (h and h.level) or 1
    local fragments = (h and h.fragments) or 0

    -- 等级/门槛
    local nextGate = GetNextGateLevel(heroId)
    local prevGate = GetPrevGateLevel(heroId)
    local levelCap = HeroData.GetCurrentLevelCap(heroId)
    local atCap = (level >= levelCap)

    -- 进度条
    local gateSpan = math.max(1, nextGate - prevGate)
    local progressRatio = math.min(1.0, (level - prevGate) / gateSpan)

    -- 战力
    local stats = HeroData.GetHeroStats(heroId)
    -- 叠加装备加成到显示属性
    local EquipData = require("Game.EquipData")
    local eqBonus = EquipData.GetTotalBonus(heroId)
    stats.atk = stats.atk + (eqBonus.atk or 0)
    stats.critDmg = (stats.critDmg or 0) + (eqBonus.critDmg or 0)
    stats.dmgBonus = (stats.dmgBonus or 0) + (eqBonus.dmgBonus or 0)
    -- 元素伤害加成：加到英雄对应元素
    local heroElem = Config.HERO_ELEMENT[heroId]
    if heroElem and eqBonus.elemDmg and eqBonus.elemDmg > 0 then
        if not stats.elemDmgBonus then stats.elemDmgBonus = {} end
        stats.elemDmgBonus[heroElem] = (stats.elemDmgBonus[heroElem] or 0) + eqBonus.elemDmg
    end
    local power = stats.atk + stats.spd

    -- 头像图片
    local avatarIcon = heroDef.icon or heroId
    local avatarImage = "image/avatars/avatar_" .. avatarIcon .. ".png"

    -- 品质
    local rarity = heroDef.rarity or "R"
    local rarityColor = GetRarityColor(rarity)
    local rarityBorder = GetRarityBorderColor(rarity)

    -- 星级信息
    local tierInfo = HeroData.GetStarTierInfo(heroId)

    -- 头像边框颜色
    local frameColor = { 100, 75, 50, 200 }
    if isUnlocked then
        if isLeader then
            frameColor = { 210, 170, 50, 255 }
        else
            frameColor = { rarityBorder[1], rarityBorder[2], rarityBorder[3], 220 }
        end
    end

    -- ==================== 左侧：头像区 ====================
    -- 星级叠加在头像左上角
    local starOverlay = nil
    if isUnlocked and tierInfo.starInTier > 0 then
        local starRows = CreateStarRows(tierInfo.starInTier, tierInfo.color)
        starOverlay = UI.Panel {
            position = "absolute",
            top = 1, left = 1,
            gap = 0,
            children = starRows,
        }
    end

    local avatarSection = UI.Panel {
        height = "80%",
        aspectRatio = 1.0,
        flexShrink = 0,
        borderRadius = 6,
        borderWidth = 2,
        borderColor = frameColor,
        backgroundColor = {
            rarityColor[1], rarityColor[2], rarityColor[3],
            isUnlocked and 200 or 50,
        },
        backgroundImage = avatarImage,
        backgroundFit = "cover",
        opacity = isUnlocked and 1.0 or 0.3,
        overflow = "hidden",
        onClick = function(self)
            ShowHeroDetail(heroId)
        end,
        children = {
            -- 星级（左上）
            starOverlay,
            -- 等级徽章（左下）
            isUnlocked and UI.Panel {
                position = "absolute",
                bottom = 0, left = 0,
                paddingLeft = 4, paddingRight = 4,
                paddingTop = 1, paddingBottom = 1,
                borderTopRightRadius = 4,
                backgroundColor = S.lvBadgeBg,
                children = {
                    UI.Label {
                        text = "Lv." .. level,
                        fontSize = 9,
                        fontColor = { 255, 255, 255, 230 },
                    },
                },
            } or nil,
            -- 元素图标（右下角）
            (function()
                local elemId = Config.HERO_ELEMENT[heroId]
                local elemDef = elemId and Config.ELEMENTS[elemId]
                if not elemDef then return nil end
                return UI.Panel {
                    position = "absolute",
                    bottom = 1, right = 1,
                    width = 18, height = 18,
                    backgroundImage = elemDef.icon,
                    backgroundFit = "contain",
                }
            end)(),
        },
    }

    -- ==================== 右侧：操作按钮 ====================
    local rightSection = nil
    local pendingGate = HeroData.GetPendingAdvanceGate(heroId)

    if not isUnlocked then
        local unlockCost = Config.RARITY_SHARD_COST[rarity] or 10
        rightSection = UI.Panel {
            width = "28%", flexShrink = 0,
            justifyContent = "center", alignItems = "center",
            children = {
                UI.Label { text = fragments .. "/" .. unlockCost, fontSize = 12, fontColor = S.dim },
                UI.Label { text = "未解锁", fontSize = 10, fontColor = S.dimLocked, marginTop = 2 },
            },
        }
    elseif atCap and pendingGate then
        local advDisabled = (HeroData.currencies.devour_stone or 0) < pendingGate.stones
        rightSection = UI.Panel {
            width = "28%", flexShrink = 0,
            justifyContent = "center", alignItems = "center",
            gap = 3,
            children = {
                -- 费用标签（绿底）
                UI.Panel {
                    width = "100%",
                    paddingTop = 3, paddingBottom = 3,
                    borderRadius = 4,
                    backgroundColor = advDisabled and S.btnDisabled or { 75, 140, 55, 255 },
                    flexDirection = "row",
                    justifyContent = "center", alignItems = "center",
                    gap = 2,
                    children = {
                        Currency.IconWidget(UI, "devour_stone", 11),
                        UI.Label { text = FormatBigNum(pendingGate.stones), fontSize = 11, fontColor = S.btnText, fontWeight = "bold" },
                    },
                },
                -- 进阶按钮
                UI.Panel {
                    width = "100%",
                    paddingTop = 5, paddingBottom = 5,
                    borderRadius = 6,
                    backgroundColor = advDisabled and S.btnDisabled or S.btnAdvance,
                    justifyContent = "center", alignItems = "center",
                    onClick = function(self)
                        if advDisabled then return end
                        local ok, msg = HeroData.Advance(heroId)
                        print("[HeroUI] Advance " .. heroId .. ": " .. msg)
                        HeroUI.Refresh()
                    end,
                    children = {
                        UI.Label { text = "进阶", fontSize = 14, fontColor = S.btnText, fontWeight = "bold" },
                    },
                },
            },
        }
    elseif atCap then
        rightSection = UI.Panel {
            width = "28%", flexShrink = 0,
            justifyContent = "center", alignItems = "center",
            gap = 3,
            children = {
                UI.Panel {
                    width = "100%",
                    paddingTop = 5, paddingBottom = 5,
                    borderRadius = 6,
                    backgroundColor = S.btnDisabled,
                    justifyContent = "center", alignItems = "center",
                    onClick = function(self)
                        ShowToast("已达等级上限，不能超过角色等级")
                    end,
                    children = {
                        UI.Label { text = "升级", fontSize = 14, fontColor = { 120, 110, 100, 180 }, fontWeight = "bold" },
                    },
                },
            },
        }
    else
        local best = GetBestUpgradeTier(heroId)
        local canUpgrade = (best ~= nil)
        local btnLabel = "升级"
        local costNum = ""
        if best then
            costNum = FormatBigNum(best.cost)
            if best.tier > 1 then
                btnLabel = "升级" .. best.tier .. "次"
            end
        else
            local cost1, _ = CalcBatchUpgradeCost(heroId, 1)
            costNum = FormatBigNum(cost1)
        end

        rightSection = UI.Panel {
            width = "28%", flexShrink = 0,
            justifyContent = "center", alignItems = "center",
            gap = 3,
            children = {
                -- 费用标签（绿底圆角）
                UI.Panel {
                    width = "100%",
                    paddingTop = 3, paddingBottom = 3,
                    borderRadius = 4,
                    backgroundColor = canUpgrade and { 75, 140, 55, 255 } or S.btnDisabled,
                    flexDirection = "row",
                    justifyContent = "center", alignItems = "center",
                    gap = 2,
                    children = {
                        Currency.IconWidget(UI, "nether_crystal", 11),
                        UI.Label { text = costNum, fontSize = 11, fontColor = S.btnText, fontWeight = "bold" },
                    },
                },
                -- 升级按钮（深色底）
                UI.Panel {
                    width = "100%",
                    paddingTop = 5, paddingBottom = 5,
                    borderRadius = 6,
                    backgroundColor = canUpgrade and S.btnGreen or S.btnDisabled,
                    justifyContent = "center", alignItems = "center",
                    onClick = function(self)
                        if not canUpgrade then return end
                        local b = GetBestUpgradeTier(heroId)
                        if b then
                            DoBatchLevelUp(heroId, b.tier)
                            local AudioManager = require("Game.AudioManager")
                            AudioManager.PlayUpgrade()
                            print("[HeroUI] BatchLevelUp " .. heroId .. " x" .. b.tier)
                        end
                        HeroUI.Refresh()
                    end,
                    children = {
                        UI.Label { text = btnLabel, fontSize = 14, fontColor = S.btnText, fontWeight = "bold" },
                    },
                },
            },
        }
    end

    -- ==================== 中间：信息区 ====================
    local nameColor = isUnlocked and S.white or S.dimLocked

    local middleSection = UI.Panel {
        flexGrow = 1, flexShrink = 1,
        gap = 3,
        children = {
            -- 名字行：名字 + 品质标签
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                gap = 5,
                children = {
                    UI.Label {
                        text = heroDef.name,
                        fontSize = 15,
                        fontColor = nameColor,
                        fontWeight = "bold",
                    },
                    heroDef.rarity ~= "none" and UI.Panel {
                        paddingLeft = 5, paddingRight = 5,
                        paddingTop = 1, paddingBottom = 1,
                        borderRadius = 3,
                        backgroundColor = GetRarityColor(heroDef.rarity),
                        children = {
                            UI.Label {
                                text = heroDef.rarity or "R",
                                fontSize = 9,
                                fontColor = { 255, 255, 255, 230 },
                                fontWeight = "bold",
                            },
                        },
                    } or nil,
                },
            },

            -- 进度条（圆角，内嵌文字）
            isUnlocked and UI.Panel {
                width = "100%",
                height = 18,
                borderRadius = 9,
                backgroundColor = S.progBg,
                overflow = "hidden",
                children = {
                    -- 填充条
                    UI.Panel {
                        width = math.max(3, math.floor(progressRatio * 100)) .. "%",
                        height = "100%",
                        borderRadius = 9,
                        backgroundColor = atCap and S.progFillMax or S.progFill,
                    },
                    -- 进度文字（居中叠加）
                    UI.Label {
                        text = level .. "/" .. nextGate,
                        fontSize = 10,
                        fontColor = { 255, 255, 255, 230 },
                        position = "absolute",
                        left = 0, right = 0, top = 0, bottom = 0,
                        textAlign = "center",
                        verticalAlign = "middle",
                    },
                },
            } or UI.Panel {
                width = "100%", height = 18,
                justifyContent = "center",
                children = {
                    UI.Label {
                        text = "收集碎片解锁",
                        fontSize = 10,
                        fontColor = S.dimLocked,
                    },
                },
            },

            -- 战力值
            isUnlocked and UI.Label {
                text = "战力 " .. FormatBigNum(power),
                fontSize = 11,
                fontColor = S.powerYellow,
            } or nil,
        },
    }

    -- ==================== 组装卡片（5:1 横条） ====================
    local bg = isUnlocked and S.cardBg or S.cardLocked

    return UI.Panel {
        width = "100%",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        flexDirection = "row",
        alignItems = "center",
        backgroundColor = bg,
        borderRadius = 8,
        borderWidth = 1,
        borderColor = S.cardBorder,
        paddingLeft = 6, paddingRight = 8,
        gap = 8,
        children = {
            avatarSection,
            middleSection,
            rightSection,
        },
    }
end

--- 创建英雄列表（主角 + 上阵英雄 + 空阵位）
local function CreateHeroList()
    local cards = {}
    -- 主角置顶
    cards[#cards + 1] = CreateHeroRow(Config.LEADER_HERO, true)

    -- 只显示已上阵的随从英雄
    local deployedList = HeroData.GetDeployedList()
    for _, heroId in ipairs(deployedList) do
        local heroDef = nil
        for _, td in ipairs(Config.TOWER_TYPES) do
            if td.id == heroId then
                heroDef = td
                break
            end
        end
        if heroDef then
            cards[#cards + 1] = CreateHeroRow(heroDef, false)
        end
    end

    -- 空阵位占位
    local emptySlots = Config.MAX_DEPLOYED - #deployedList
    for i = 1, emptySlots do
        cards[#cards + 1] = CreateEmptySlot(#deployedList + i)
    end

    return UI.Panel {
        flexGrow = 1, flexShrink = 1,
        flexBasis = 0,
        width = "100%",
        flexDirection = "column",
        gap = 5,
        paddingTop = 5, paddingBottom = 5,
        paddingLeft = 8, paddingRight = 8,
        children = cards,
    }
end

-- ============================================================================
-- 收藏按钮（绝对定位，浮于列表上方）
-- ============================================================================

local function CreateBottomBar()
    local GameUI = require("Game.GameUI")
    local count = HeroData.GetDeployedCount()
    local maxDeploy = Config.MAX_DEPLOYED
    return UI.Panel {
        width = "100%",
        flexShrink = 0,
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingTop = 6, paddingBottom = 8,
        paddingLeft = 8, paddingRight = 8,
        backgroundColor = { 30, 22, 16, 240 },
        borderTopWidth = 1,
        borderTopColor = { 75, 55, 38, 100 },
        children = {
            -- 左侧：操作按钮
            UI.Panel {
                flexDirection = "row",
                gap = 5,
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 3,
                        paddingLeft = 8, paddingRight = 8,
                        paddingTop = 5, paddingBottom = 5,
                        borderRadius = 14,
                        backgroundColor = S.collectBtn,
                        borderWidth = 1,
                        borderColor = S.collectBtnBorder,
                        onClick = function(self)
                            ShowCollectionPopup()
                        end,
                        children = {
                            UI.Label { text = "上阵", fontSize = 11, fontColor = S.white, fontWeight = "bold" },
                            UI.Label { text = count .. "/" .. maxDeploy, fontSize = 10, fontColor = S.gold },
                        },
                    },
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        paddingLeft = 8, paddingRight = 8,
                        paddingTop = 5, paddingBottom = 5,
                        borderRadius = 14,
                        backgroundColor = { 100, 70, 140, 255 },
                        borderWidth = 1,
                        borderColor = { 150, 115, 190, 255 },
                        onClick = function(self)
                            ShowCollectionDetailPopup()
                        end,
                        children = {
                            UI.Label { text = "英雄收藏", fontSize = 11, fontColor = S.white, fontWeight = "bold" },
                        },
                    },
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        paddingLeft = 8, paddingRight = 8,
                        paddingTop = 5, paddingBottom = 5,
                        borderRadius = 14,
                        backgroundColor = { 140, 100, 50, 255 },
                        borderWidth = 1,
                        borderColor = { 190, 145, 70, 255 },
                        onClick = function(self)
                            InventoryUI.Show(UI, pageRoot)
                        end,
                        children = {
                            UI.Label { text = "仓库", fontSize = 11, fontColor = S.white, fontWeight = "bold" },
                        },
                    },
                },
            },
            -- 右侧：货币药丸（内联版，避免 Button 默认 minWidth/padding 撑大）
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = {
                    GameUI.CreateCurrencyChip(UI, "nether_crystal", "heroCrystalLabel", { 160, 100, 230 }),
                    GameUI.CreateCurrencyChip(UI, "devour_stone", "heroStoneLabel", { 100, 180, 80 }),
                },
            },
        },
    }
end

-- ============================================================================
-- 收藏弹出层：英雄网格（上阵/下阵管理）
-- ============================================================================

--- 获取排序后的英雄列表（排除主角）
--- 排序优先级：已上阵 → 已解锁（按品质高→低） → 未解锁（按品质高→低）
---@return table[]
local function GetSortedHeroes()
    local heroes = {}
    for _, td in ipairs(Config.TOWER_TYPES) do
        heroes[#heroes + 1] = td
    end
    table.sort(heroes, function(a, b)
        local aDeployed = HeroData.IsDeployed(a.id) and 1 or 0
        local bDeployed = HeroData.IsDeployed(b.id) and 1 or 0
        if aDeployed ~= bDeployed then return aDeployed > bDeployed end

        local aUnlocked = HeroData.IsUnlocked(a.id) and 1 or 0
        local bUnlocked = HeroData.IsUnlocked(b.id) and 1 or 0
        if aUnlocked ~= bUnlocked then return aUnlocked > bUnlocked end

        local ra = RARITY_ORDER[a.rarity] or 0
        local rb = RARITY_ORDER[b.rarity] or 0
        if ra ~= rb then return ra > rb end
        return a.name < b.name
    end)
    return heroes
end

--- 创建单个英雄卡片（收藏网格用）
--- @param heroDef table
--- @param mode string|nil  "deploy"(默认) 或 "detail"
local function CreateHeroCard(heroDef, mode)
    mode = mode or "deploy"
    local heroId = heroDef.id
    local h = HeroData.Get(heroId)
    local isUnlocked = h and h.unlocked or false
    local isDeployed = HeroData.IsDeployed(heroId)
    local heroColor = heroDef.color
    local rarity = heroDef.rarity or "R"
    local fragments = (h and h.fragments) or 0
    local unlockCost = Config.RARITY_SHARD_COST[rarity] or 10

    local power = 0
    if isUnlocked then
        local stats = HeroData.GetHeroStats(heroId)
        power = stats.atk + stats.spd
    end

    local level = (h and h.level) or 1
    local cardWidth = "31%"
    local cardBg = isUnlocked and S.cardBg or S.cardLocked
    local borderColor = isUnlocked and GetRarityBorderColor(rarity) or { 60, 50, 40, 100 }
    local rarityColor = GetRarityColor(rarity)
    local avatarIcon = heroDef.icon or heroId
    local avatarImage = "image/avatars/avatar_" .. avatarIcon .. ".png"
    local avatarAlpha = isUnlocked and 220 or 40

    local cardChildren = {
        -- 头像区域
        UI.Panel {
            width = "100%",
            aspectRatio = 1.0,
            backgroundColor = {
                rarityColor[1], rarityColor[2], rarityColor[3], avatarAlpha,
            },
            backgroundImage = avatarImage,
            backgroundFit = "cover",
            opacity = isUnlocked and 1.0 or 0.3,
            borderTopLeftRadius = 6,
            borderTopRightRadius = 6,
            justifyContent = "center",
            alignItems = "center",
            overflow = "hidden",
            children = {
                -- 稀有度角标（左上）
                rarity ~= "none" and UI.Panel {
                    position = "absolute",
                    top = 2, left = 2,
                    paddingLeft = 4, paddingRight = 4,
                    paddingTop = 1, paddingBottom = 1,
                    borderRadius = 3,
                    backgroundColor = rarityColor,
                    children = {
                        UI.Label {
                            text = rarity,
                            fontSize = 8,
                            fontColor = { 255, 255, 255, 240 },
                            fontWeight = "bold",
                        },
                    },
                } or nil,
                -- 等级角标（右上）
                isUnlocked and UI.Panel {
                    position = "absolute",
                    top = 2, right = 2,
                    paddingLeft = 3, paddingRight = 3,
                    paddingTop = 1, paddingBottom = 1,
                    borderRadius = 3,
                    backgroundColor = { 0, 0, 0, 160 },
                    children = {
                        UI.Label {
                            text = "Lv." .. level,
                            fontSize = 8,
                            fontColor = { 255, 255, 255, 220 },
                        },
                    },
                } or nil,
                -- 元素图标（右下角）
                (function()
                    local elemId = Config.HERO_ELEMENT[heroId]
                    local elemDef = elemId and Config.ELEMENTS[elemId]
                    if not elemDef then return nil end
                    return UI.Panel {
                        position = "absolute",
                        bottom = 1, right = 1,
                        width = 16, height = 16,
                        backgroundImage = elemDef.icon,
                        backgroundFit = "contain",
                    }
                end)(),
                -- 未解锁遮罩
                (not isUnlocked) and UI.Panel {
                    position = "absolute",
                    top = 0, left = 0, right = 0, bottom = 0,
                    backgroundColor = S.lockOverlay,
                    justifyContent = "center",
                    alignItems = "center",
                    children = {
                        UI.Label { text = "🔒", fontSize = 18 },
                    },
                } or nil,

            },
        },

        -- 底部信息区域
        UI.Panel {
            width = "100%",
            paddingTop = 3, paddingBottom = 4,
            paddingLeft = 4, paddingRight = 4,
            gap = 1,
            alignItems = "center",
            children = {
                UI.Label {
                    text = heroDef.name,
                    fontSize = 10,
                    fontColor = isUnlocked and S.white or S.dimLocked,
                    fontWeight = "bold",
                    textAlign = "center",
                },
                isUnlocked and UI.Label {
                    text = "⚔ " .. FormatBigNum(power),
                    fontSize = 9,
                    fontColor = S.powerYellow,
                } or UI.Label {
                    text = fragments .. "/" .. unlockCost,
                    fontSize = 9,
                    fontColor = S.dimLocked,
                },
            },
        },
    }

    -- 上阵标记：暗色遮罩 + 大对勾覆盖整张卡（仅 deploy 模式）
    if isDeployed and mode == "deploy" then
        cardChildren[#cardChildren + 1] = UI.Panel {
            position = "absolute",
            top = 0, left = 0, right = 0, bottom = 0,
            backgroundColor = { 0, 0, 0, 140 },
            justifyContent = "center",
            alignItems = "center",
            zIndex = 10,
            children = {
                UI.Panel {
                    width = "60%",
                    aspectRatio = 1.0,
                    backgroundImage = "image/check_mark_20260407003705.png",
                    backgroundFit = "contain",
                },
            },
        }
    end

    return UI.Panel {
        width = cardWidth,
        backgroundColor = cardBg,
        borderRadius = 6,
        borderWidth = 1.5,
        borderColor = borderColor,
        onClick = function(self)
            if mode == "detail" then
                ShowHeroDetail(heroId)
            else
                HandleCardClick(heroId, isUnlocked, isDeployed)
            end
        end,
        children = cardChildren,
    }
end

--- 卡片点击处理：上阵/下阵切换
function HandleCardClick(heroId, isUnlocked, isDeployed)
    if not isUnlocked then
        print("[HeroUI] " .. heroId .. " is locked")
        return
    end

    local ok, msg
    if isDeployed then
        ok, msg = HeroData.Undeploy(heroId)
    else
        ok, msg = HeroData.Deploy(heroId)
    end
    print("[HeroUI] " .. (isDeployed and "Undeploy" or "Deploy") .. " " .. heroId .. ": " .. msg)

    local success, AudioManager = pcall(require, "Game.AudioManager")
    if success and AudioManager then
        if ok then
            AudioManager.PlayUpgrade()
        end
    end

    -- 刷新弹出层内容
    RefreshCollectionContent()
end

--- 创建英雄网格
--- @param mode string|nil  "deploy"(默认) 或 "detail"
local function CreateHeroGrid(mode)
    mode = mode or "deploy"
    local sortedHeroes = GetSortedHeroes()
    local cards = {}
    for _, heroDef in ipairs(sortedHeroes) do
        cards[#cards + 1] = CreateHeroCard(heroDef, mode)
    end

    return UI.ScrollView {
        flexGrow = 1, flexBasis = 0,
        scrollY = true, width = "100%",
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                flexWrap = "wrap",
                justifyContent = "flex-start",
                paddingTop = 4, paddingBottom = 10,
                paddingLeft = 8, paddingRight = 8,
                gap = 6,
                children = cards,
            },
        },
    }
end

--- 收藏弹出层内容容器（用于局部刷新）
---@type any
local popupContentContainer = nil

--- 刷新收藏弹出层网格内容（不重建整个弹出层）
function RefreshCollectionContent()
    if not popupContentContainer then return end
    popupContentContainer:ClearChildren()

    -- 上阵信息栏
    local count = HeroData.GetDeployedCount()
    local maxDeploy = Config.MAX_DEPLOYED
    local isFull = count >= maxDeploy
    local countColor = isFull and S.deployFull or S.deployedCount

    popupContentContainer:AddChild(UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingTop = 4, paddingBottom = 6,
        paddingLeft = 12, paddingRight = 12,
        flexShrink = 0,
        children = {
            UI.Label {
                text = "英雄收藏",
                fontSize = 15,
                fontColor = S.white,
                fontWeight = "bold",
            },
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = {
                    UI.Label { text = "上阵", fontSize = 11, fontColor = S.dim },
                    UI.Label {
                        text = count .. "/" .. maxDeploy,
                        fontSize = 13,
                        fontColor = countColor,
                        fontWeight = "bold",
                    },
                },
            },
        },
    })

    -- 英雄网格
    popupContentContainer:AddChild(CreateHeroGrid())
end

--- 显示英雄收藏弹出层
function ShowCollectionPopup()
    if collectionOverlay then
        -- 已经打开则刷新
        RefreshCollectionContent()
        return
    end

    -- 创建内容容器
    popupContentContainer = UI.Panel {
        flexGrow = 1, flexShrink = 1,
        width = "100%",
        flexDirection = "column",
    }

    -- 弹出面板
    local popup = UI.Panel {
        position = "absolute",
        top = 10, left = 8, right = 8, bottom = 10,
        backgroundColor = S.popupBg,
        borderRadius = 12,
        borderWidth = 1,
        borderColor = S.popupBorder,
        flexDirection = "column",
        overflow = "hidden",
        children = {
            -- 内容容器
            popupContentContainer,
            -- 底部返回按钮
            UI.Panel {
                width = "100%",
                paddingTop = 8, paddingBottom = 10,
                paddingLeft = 12, paddingRight = 12,
                flexShrink = 0,
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 4,
                        paddingLeft = 14, paddingRight = 18,
                        paddingTop = 6, paddingBottom = 6,
                        backgroundColor = { 80, 60, 45, 230 },
                        borderRadius = 8,
                        borderWidth = 1,
                        borderColor = { 140, 110, 70, 150 },
                        onClick = function(self)
                            HideCollectionPopup()
                        end,
                        children = {
                            UI.Label {
                                text = "<",
                                fontSize = 14,
                                fontColor = { 180, 160, 130, 200 },
                            },
                            UI.Label {
                                text = "返回",
                                fontSize = 14,
                                fontColor = S.white,
                            },
                        },
                    },
                },
            },
        },
    }

    -- 半透明遮罩（点击关闭）
    collectionOverlay = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 100,
        backgroundColor = S.overlayBg,
        children = { popup },
    }

    -- 填充内容
    RefreshCollectionContent()

    -- 添加到页面
    pageRoot:AddChild(collectionOverlay)
end

--- 隐藏英雄收藏弹出层
function HideCollectionPopup()
    if collectionOverlay then
        pageRoot:RemoveChild(collectionOverlay)
        collectionOverlay = nil
        popupContentContainer = nil
        -- 关闭后刷新主页（上阵列表可能变化）
        HeroUI.Refresh()
    end
end

-- ============================================================================
-- 英雄收藏弹出层（点击查看详情）
-- ============================================================================

---@type any
local detailPopupContentContainer = nil

--- 刷新英雄收藏弹出层内容
function RefreshCollectionDetailContent()
    if not detailPopupContentContainer then return end
    detailPopupContentContainer:ClearChildren()

    -- 标题栏
    detailPopupContentContainer:AddChild(UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        paddingTop = 4, paddingBottom = 6,
        paddingLeft = 12, paddingRight = 12,
        flexShrink = 0,
        children = {
            UI.Label { text = "英雄收藏", fontSize = 15, fontColor = S.white, fontWeight = "bold" },
        },
    })

    -- 英雄网格（detail 模式）
    detailPopupContentContainer:AddChild(CreateHeroGrid("detail"))
end

--- 显示英雄收藏弹出层
function ShowCollectionDetailPopup()
    if collectionDetailOverlay then
        RefreshCollectionDetailContent()
        return
    end

    detailPopupContentContainer = UI.Panel {
        flexGrow = 1, flexShrink = 1,
        width = "100%",
        flexDirection = "column",
    }

    local popup = UI.Panel {
        position = "absolute",
        top = 10, left = 8, right = 8, bottom = 10,
        backgroundColor = S.popupBg,
        borderRadius = 12,
        borderWidth = 1,
        borderColor = { 150, 115, 190, 200 },
        flexDirection = "column",
        overflow = "hidden",
        children = {
            detailPopupContentContainer,
            -- 底部返回按钮
            UI.Panel {
                width = "100%",
                paddingTop = 8, paddingBottom = 10,
                paddingLeft = 12, paddingRight = 12,
                flexShrink = 0,
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 4,
                        paddingLeft = 14, paddingRight = 18,
                        paddingTop = 6, paddingBottom = 6,
                        backgroundColor = { 80, 60, 45, 230 },
                        borderRadius = 8,
                        borderWidth = 1,
                        borderColor = { 140, 110, 70, 150 },
                        onClick = function(self)
                            HideCollectionDetailPopup()
                        end,
                        children = {
                            UI.Label { text = "<", fontSize = 14, fontColor = { 180, 160, 130, 200 } },
                            UI.Label { text = "返回", fontSize = 14, fontColor = S.white },
                        },
                    },
                },
            },
        },
    }

    collectionDetailOverlay = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 100,
        backgroundColor = S.overlayBg,
        children = { popup },
    }

    RefreshCollectionDetailContent()
    pageRoot:AddChild(collectionDetailOverlay)
end

--- 隐藏英雄收藏弹出层
function HideCollectionDetailPopup()
    if collectionDetailOverlay then
        pageRoot:RemoveChild(collectionDetailOverlay)
        collectionDetailOverlay = nil
        detailPopupContentContainer = nil
    end
end

-- ============================================================================
-- 英雄详情面板
-- ============================================================================

--- 创建属性行
---@param label string
---@param value number|string
---@param color table|nil
---@param fmt string|nil  "pct"=百分比, nil=整数
local function CreateStatRow(label, value, color, fmt)
    local display
    if fmt == "pct" then
        display = string.format("%.1f%%", (value or 0) * 100)
    elseif type(value) == "number" then
        display = FormatBigNum(value)
    else
        display = tostring(value)
    end
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingLeft = 12, paddingRight = 12,
        paddingTop = 4, paddingBottom = 4,
        children = {
            UI.Label { text = label, fontSize = 13, fontColor = S.dim },
            UI.Label { text = display, fontSize = 13, fontColor = color or S.white, fontWeight = "bold" },
        },
    }
end

--- 创建技能图标
--- @param skillDef table
--- @param unlocked boolean
--- @param selected boolean
--- @param onClick function|nil
local function CreateSkillIcon(skillDef, unlocked, selected, onClick)
    local typeTag = skillDef.type == "active" and "主" or "被"
    local tagColor = skillDef.type == "active" and { 220, 70, 50, 255 } or { 80, 160, 60, 255 }
    local bgColor = unlocked and { 60, 48, 36, 255 } or { 40, 35, 30, 200 }
    local borderCol = (selected and unlocked) and { 255, 200, 80, 255 }
        or (unlocked and { 120, 95, 65, 200 } or { 60, 50, 40, 150 })
    local textAlpha = unlocked and 255 or 100
    local borderW = selected and 3 or 2

    return UI.Panel {
        alignItems = "center",
        gap = 3,
        width = 56,
        onClick = onClick,
        children = {
            -- 圆形技能图标
            UI.Panel {
                width = 42, height = 42,
                borderRadius = 21,
                backgroundColor = bgColor,
                borderWidth = borderW,
                borderColor = borderCol,
                justifyContent = "center", alignItems = "center",
                opacity = unlocked and 1.0 or 0.5,
                children = {
                    UI.Label {
                        text = string.sub(skillDef.name, 1, 6),
                        fontSize = 10,
                        fontColor = { 255, 255, 255, textAlpha },
                        textAlign = "center",
                    },
                    -- 主/被 角标
                    UI.Panel {
                        position = "absolute",
                        top = -2, right = -2,
                        width = 16, height = 16,
                        borderRadius = 8,
                        backgroundColor = tagColor,
                        justifyContent = "center", alignItems = "center",
                        children = {
                            UI.Label { text = typeTag, fontSize = 8, fontColor = { 255, 255, 255, 240 }, fontWeight = "bold" },
                        },
                    },
                },
            },
            -- 技能名
            UI.Label {
                text = skillDef.name,
                fontSize = 9,
                fontColor = { 255, 255, 255, textAlpha },
                textAlign = "center",
            },
        },
    }
end

-- ============================================================================
-- 英雄详情面板（标签页版：信息 / 装备 / 升星 / 皮肤）
-- ============================================================================

--- 当前详情面板打开的英雄ID和选中标签
---@type string|nil
local detailHeroId = nil
---@type string
local detailTab = "info"

--- 详情面板内容容器（用于标签切换时局部刷新）
---@type any
local detailContentContainer = nil

--- 标签页定义
local DETAIL_TABS = {
    { key = "info",    label = "信息" },
    { key = "equip",   label = "装备" },
    { key = "starup",  label = "升星" },
    { key = "skin",    label = "皮肤" },
}

-- ==================== 标签页：信息（属性 + 技能） ====================

--- 构建信息标签页内容
---@param heroId string
---@param heroDef table
local function BuildInfoTab(heroId, heroDef)
    local h = HeroData.Get(heroId)
    local level = (h and h.level) or 1
    local isUnlocked = h and h.unlocked or false
    local fragments = (h and h.fragments) or 0
    local rarity = heroDef.rarity or "R"
    local unlockCost = Config.RARITY_SHARD_COST[rarity] or 10

    if not isUnlocked then
        return UI.Panel {
            width = "100%",
            alignItems = "center", justifyContent = "center",
            paddingTop = 20, paddingBottom = 20,
            children = {
                UI.Label { text = "碎片 " .. fragments .. "/" .. unlockCost, fontSize = 14, fontColor = S.dim },
                UI.Label { text = "收集碎片解锁英雄", fontSize = 12, fontColor = S.dimLocked, marginTop = 6 },
            },
        }
    end

    local stats = HeroData.GetHeroStats(heroId)
    local EquipData = require("Game.EquipData")
    local eqBonus = EquipData.GetTotalBonus(heroId)
    stats.atk = stats.atk + (eqBonus.atk or 0)
    stats.critDmg = (stats.critDmg or 0) + (eqBonus.critDmg or 0)
    stats.dmgBonus = (stats.dmgBonus or 0) + (eqBonus.dmgBonus or 0)
    local heroElem = Config.HERO_ELEMENT[heroId]
    if heroElem and eqBonus.elemDmg and eqBonus.elemDmg > 0 then
        if not stats.elemDmgBonus then stats.elemDmgBonus = {} end
        stats.elemDmgBonus[heroElem] = (stats.elemDmgBonus[heroElem] or 0) + eqBonus.elemDmg
    end

    local children = {}

    -- 属性区
    children[#children + 1] = UI.Panel {
        width = "100%",
        backgroundColor = { 35, 25, 18, 200 },
        borderRadius = 8,
        borderWidth = 1,
        borderColor = { 70, 55, 40, 150 },
        paddingTop = 6, paddingBottom = 6,
        gap = 2,
        children = {
            CreateStatRow("攻击", stats.atk, { 255, 120, 80, 255 }),
            CreateStatRow("速度", stats.spd, { 100, 180, 255, 255 }),
            CreateStatRow("暴击率", stats.critRate, { 255, 220, 80, 255 }, "pct"),
            CreateStatRow("暴击伤害", stats.critDmg, { 255, 160, 60, 255 }, "pct"),
            CreateStatRow("穿甲", stats.armorPen, { 200, 140, 255, 255 }, "pct"),
            CreateStatRow("伤害加成", stats.dmgBonus or 0, { 255, 100, 100, 255 }, "pct"),
            (function()
                local elemId = Config.HERO_ELEMENT[heroId]
                local elemDef = elemId and Config.ELEMENTS[elemId]
                if not elemId or not elemDef then return nil end
                local elemBonus = stats.elemDmgBonus and stats.elemDmgBonus[elemId] or 0
                return CreateStatRow(elemDef.name .. "伤害", elemBonus, elemDef.color, "pct")
            end)(),
        },
    }

    -- 技能区
    local skillDefs = Config.HERO_SKILLS and Config.HERO_SKILLS[heroId] or {}
    if #skillDefs > 0 then
        local skillDescContainer = UI.Panel { width = "100%" }
        local selectedIdx = 1
        local skillIconsContainer = UI.Panel {
            width = "100%",
            flexDirection = "row",
            justifyContent = "center",
            gap = 6,
            flexWrap = "wrap",
        }

        local function UpdateSkillDesc(idx)
            selectedIdx = idx
            local sd = skillDefs[idx]
            if not sd then return end
            local unlockLv = Config.SKILL_UNLOCK_LEVELS[idx] or 999
            local isLocked = level < unlockLv

            skillDescContainer:ClearChildren()
            skillDescContainer:AddChild(UI.Panel {
                width = "100%",
                marginTop = 4,
                backgroundColor = { 45, 35, 28, 220 },
                borderRadius = 6,
                borderWidth = 1,
                borderColor = { 80, 65, 48, 150 },
                paddingTop = 6, paddingBottom = 6,
                paddingLeft = 10, paddingRight = 10,
                gap = 3,
                children = {
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = 6,
                        children = {
                            UI.Label {
                                text = sd.name, fontSize = 13,
                                fontColor = isLocked and S.dimLocked or S.gold,
                                fontWeight = "bold",
                            },
                            UI.Label {
                                text = sd.type == "active" and "[主动]" or "[被动]",
                                fontSize = 10,
                                fontColor = sd.type == "active"
                                    and { 220, 100, 80, 200 } or { 100, 180, 80, 200 },
                            },
                        },
                    },
                    UI.Label {
                        text = sd.desc, fontSize = 11,
                        fontColor = isLocked and { 180, 170, 155, 180 } or { 210, 200, 180, 220 },
                    },
                    isLocked and UI.Label {
                        text = "Lv." .. unlockLv .. " 解锁",
                        fontSize = 10, fontColor = { 255, 140, 60, 200 }, marginTop = 2,
                    } or nil,
                },
            })

            skillIconsContainer:ClearChildren()
            for i, skillDef in ipairs(skillDefs) do
                local ulv = Config.SKILL_UNLOCK_LEVELS[i] or 999
                local su = level >= ulv
                skillIconsContainer:AddChild(CreateSkillIcon(skillDef, su, i == selectedIdx, function(self)
                    UpdateSkillDesc(i)
                end))
            end
        end

        UpdateSkillDesc(1)

        children[#children + 1] = UI.Panel {
            width = "100%",
            marginTop = 6,
            backgroundColor = { 35, 25, 18, 200 },
            borderRadius = 8,
            borderWidth = 1,
            borderColor = { 70, 55, 40, 150 },
            paddingTop = 8, paddingBottom = 8,
            paddingLeft = 6, paddingRight = 6,
            gap = 4,
            children = {
                UI.Label { text = "技能", fontSize = 12, fontColor = S.dim, marginLeft = 6 },
                skillIconsContainer,
                skillDescContainer,
            },
        }
    end

    return UI.Panel {
        width = "100%",
        gap = 4,
        children = children,
    }
end

-- ==================== 标签页：装备 ====================

--- 构建装备标签页内容
---@param heroId string
---@param heroDef table
local function BuildEquipTab(heroId, heroDef)
    local h = HeroData.Get(heroId)
    local isUnlocked = h and h.unlocked or false

    if not isUnlocked then
        return UI.Panel {
            width = "100%",
            alignItems = "center", justifyContent = "center",
            paddingTop = 30, paddingBottom = 30,
            children = {
                UI.Label { text = "解锁英雄后可装备", fontSize = 14, fontColor = S.dimLocked },
            },
        }
    end

    -- 主角不参与装备系统
    if heroId == Config.LEADER_HERO.id then
        return UI.Panel {
            width = "100%",
            alignItems = "center", justifyContent = "center",
            paddingTop = 30, paddingBottom = 30,
            children = {
                UI.Label { text = "主角无装备", fontSize = 14, fontColor = S.dimLocked },
            },
        }
    end

    -- 未上阵英雄无装备
    if not HeroData.IsDeployed(heroId) then
        return UI.Panel {
            width = "100%",
            alignItems = "center", justifyContent = "center",
            paddingTop = 30, paddingBottom = 30,
            children = {
                UI.Label { text = "上阵后可查看装备", fontSize = 14, fontColor = S.dimLocked },
            },
        }
    end

    local EquipData = require("Game.EquipData")
    local heroLevel = (h and h.level) or 1
    local cards = {}

    for _, slotDef in ipairs(Config.EQUIP_SLOTS) do
        local info = EquipData.GetSlotInfo(heroId, slotDef.id)
        if info then
            local tier = info.tierDef
            local needBreak, breakInfo = EquipData.CheckBreakthrough(heroId, slotDef.id)
            local upgradeCost = EquipData.GetUpgradeCost(info.level)
            local isMaxLevel = (info.level >= Config.EQUIP_MAX_LEVEL)
            local isAtHeroCap = (info.level >= heroLevel)
            local isAtTierMax = needBreak

            -- 按钮逻辑
            local btnText, btnColor, btnClick
            if isMaxLevel then
                btnText = "满级"
                btnColor = S.btnDisabled
                btnClick = function() end
            elseif isAtTierMax then
                btnText = "突破"
                btnColor = S.btnAdvance
                btnClick = function()
                    EquipData.Breakthrough(heroId, slotDef.id)
                    local AudioManager = require("Game.AudioManager")
                    AudioManager.PlayUpgrade()
                    ShowHeroDetail(heroId)  -- 刷新
                end
            elseif isAtHeroCap then
                btnText = "升级"
                btnColor = S.btnDisabled
                btnClick = function() end
            else
                local canUpgrade = (HeroData.currencies.forge_iron or 0) >= upgradeCost
                btnText = "升级"
                btnColor = canUpgrade and S.btnGreen or S.btnDisabled
                btnClick = function()
                    EquipData.Upgrade(heroId, slotDef.id)
                    local AudioManager = require("Game.AudioManager")
                    AudioManager.PlayUpgrade()
                    ShowHeroDetail(heroId)
                end
            end

            cards[#cards + 1] = UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                backgroundColor = { 35, 25, 18, 200 },
                borderRadius = 8,
                borderWidth = 1,
                borderColor = tier.borderColor,
                paddingTop = 5, paddingBottom = 5,
                paddingLeft = 6, paddingRight = 6,
                gap = 6,
                children = {
                    -- 装备图标
                    UI.Panel {
                        width = 40, height = 40,
                        flexShrink = 0,
                        borderRadius = 6,
                        backgroundColor = tier.bgColor,
                        borderWidth = 1,
                        borderColor = tier.color,
                        backgroundImage = "image/equip_" .. tier.id .. "_" .. slotDef.id .. ".png",
                        backgroundFit = "cover",
                        overflow = "hidden",
                        children = {
                            UI.Panel {
                                position = "absolute",
                                bottom = 0, left = 0,
                                paddingLeft = 3, paddingRight = 3,
                                backgroundColor = { 0, 0, 0, 180 },
                                borderTopRightRadius = 4,
                                children = {
                                    UI.Label { text = tostring(info.level), fontSize = 8, fontColor = tier.color, fontWeight = "bold" },
                                },
                            },
                        },
                    },
                    -- 装备名 + 属性
                    UI.Panel {
                        flexGrow = 1, flexShrink = 1,
                        gap = 1,
                        children = {
                            UI.Label { text = info.fullName, fontSize = 12, fontColor = tier.color, fontWeight = "bold" },
                            UI.Label {
                                text = slotDef.statName .. " +" .. (slotDef.fmt == "pct"
                                    and string.format("%.1f%%", info.statBonus * 100)
                                    or FormatBigNum(info.statBonus)),
                                fontSize = 10, fontColor = S.gold,
                            },
                        },
                    },
                    -- 操作按钮
                    UI.Panel {
                        width = 50, flexShrink = 0,
                        justifyContent = "center", alignItems = "center",
                        paddingTop = 5, paddingBottom = 5,
                        borderRadius = 6,
                        backgroundColor = btnColor,
                        onClick = btnClick,
                        children = {
                            UI.Label { text = btnText, fontSize = 11, fontColor = S.btnText, fontWeight = "bold" },
                        },
                    },
                },
            }
        end
    end

    -- 锻魂铁货币
    cards[#cards + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = 4,
        marginTop = 4,
        children = {
            Currency.IconWidget(UI, "forge_iron", 14),
            UI.Label {
                text = FormatBigNum(HeroData.currencies.forge_iron or 0),
                fontSize = 12, fontColor = S.gold,
            },
        },
    }

    return UI.Panel {
        width = "100%",
        gap = 5,
        children = cards,
    }
end

-- ==================== 标签页：升星 ====================

--- 构建升星标签页内容
---@param heroId string
---@param heroDef table
local function BuildStarUpTab(heroId, heroDef)
    local h = HeroData.Get(heroId)
    local isUnlocked = h and h.unlocked or false

    if not isUnlocked then
        return UI.Panel {
            width = "100%",
            alignItems = "center", justifyContent = "center",
            paddingTop = 30, paddingBottom = 30,
            children = {
                UI.Label { text = "解锁英雄后可升星", fontSize = 14, fontColor = S.dimLocked },
            },
        }
    end

    local star = h.star or 0
    local fragments = h.fragments or 0
    local tierInfo = HeroData.GetStarTierInfo(heroId)
    local isMaxStar = (star >= Config.MAX_HERO_STAR)

    -- 升星费用
    local starCost = 0
    local canStarUp = false
    if not isMaxStar then
        starCost = HeroData.GetStarUpCost(star)
        canStarUp = fragments >= starCost
    end

    -- 当前星段和下一星段信息
    local currentTierIdx = (star > 0) and HeroData.GetTierFromStar(star) or 0
    local nextTierIdx = (not isMaxStar) and HeroData.GetTierFromStar(star + 1) or currentTierIdx
    local nextTier = Config.STAR_TIERS[nextTierIdx]
    local isTierAdvance = (nextTierIdx > currentTierIdx)

    -- 当前星级显示行
    local currentStarRows = {}
    if star > 0 then
        currentStarRows = CreateStarRows(tierInfo.starInTier, tierInfo.color)
    end

    -- 下一星级预览
    local nextStarInTier = tierInfo.starInTier + 1
    local nextTierColor = tierInfo.color
    if isTierAdvance and nextTier then
        nextStarInTier = 1
        nextTierColor = nextTier.color
    end
    local nextStarRows = {}
    if not isMaxStar then
        nextStarRows = CreateStarRows(nextStarInTier, nextTierColor)
    end

    -- 碎片进度
    local progRatio = isMaxStar and 1.0 or math.min(1.0, fragments / math.max(1, starCost))

    local children = {}

    -- 星级变化区域：当前 → 下一级
    if not isMaxStar then
        children[#children + 1] = UI.Panel {
            width = "100%",
            backgroundColor = { 35, 25, 18, 200 },
            borderRadius = 8,
            borderWidth = 1,
            borderColor = { 70, 55, 40, 150 },
            paddingTop = 12, paddingBottom = 12,
            paddingLeft = 10, paddingRight = 10,
            gap = 8,
            children = {
                -- 标题
                UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    justifyContent = "center",
                    alignItems = "center",
                    children = {
                        UI.Label {
                            text = tierInfo.name .. " " .. tierInfo.starInTier .. "星",
                            fontSize = 14, fontColor = tierInfo.color, fontWeight = "bold",
                        },
                        UI.Label {
                            text = "  →  ",
                            fontSize = 14, fontColor = S.dim,
                        },
                        UI.Label {
                            text = (isTierAdvance and nextTier) and (nextTier.name .. " 1星") or (tierInfo.name .. " " .. (tierInfo.starInTier + 1) .. "星"),
                            fontSize = 14,
                            fontColor = isTierAdvance and nextTierColor or tierInfo.color,
                            fontWeight = "bold",
                        },
                    },
                },

                -- 星级图形对比（当前 → 下一）
                UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    justifyContent = "center",
                    alignItems = "center",
                    gap = 12,
                    children = {
                        -- 当前星级
                        UI.Panel {
                            alignItems = "center",
                            gap = 2,
                            children = {
                                #currentStarRows > 0 and UI.Panel {
                                    alignItems = "center", gap = 0,
                                    children = currentStarRows,
                                } or UI.Label { text = "无星", fontSize = 12, fontColor = S.dim },
                            },
                        },
                        UI.Label { text = "→", fontSize = 18, fontColor = S.gold },
                        -- 下一星级
                        UI.Panel {
                            alignItems = "center",
                            gap = 2,
                            children = {
                                UI.Panel {
                                    alignItems = "center", gap = 0,
                                    children = nextStarRows,
                                },
                            },
                        },
                    },
                },

                -- 属性加成预览
                (function()
                    local baseStat = HeroData.GetHeroStats(heroId)
                    -- 模拟升一星后的属性
                    local nextAtk = baseStat.atk * (1 + 0.02)  -- 每星约+2%
                    local atkDiff = nextAtk - baseStat.atk
                    return UI.Panel {
                        width = "100%",
                        alignItems = "center",
                        gap = 2,
                        children = {
                            UI.Label {
                                text = "升星加成",
                                fontSize = 11, fontColor = S.dim,
                            },
                            UI.Label {
                                text = "攻击 +" .. string.format("%.0f", atkDiff) .. "  速度 +2%",
                                fontSize = 12, fontColor = { 100, 255, 100, 255 },
                            },
                        },
                    }
                end)(),
            },
        }
    else
        children[#children + 1] = UI.Panel {
            width = "100%",
            backgroundColor = { 35, 25, 18, 200 },
            borderRadius = 8,
            paddingTop = 16, paddingBottom = 16,
            alignItems = "center",
            children = {
                UI.Panel { alignItems = "center", gap = 0, children = currentStarRows },
                UI.Label {
                    text = "已达最高星级",
                    fontSize = 14, fontColor = S.gold, fontWeight = "bold", marginTop = 8,
                },
            },
        }
    end

    -- 碎片进度条
    children[#children + 1] = UI.Panel {
        width = "100%",
        backgroundColor = { 35, 25, 18, 200 },
        borderRadius = 8,
        borderWidth = 1,
        borderColor = { 70, 55, 40, 150 },
        paddingTop = 8, paddingBottom = 8,
        paddingLeft = 12, paddingRight = 12,
        gap = 6,
        children = {
            -- 碎片标签
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    UI.Label { text = "英雄碎片", fontSize = 12, fontColor = S.dim },
                    UI.Label {
                        text = isMaxStar and tostring(fragments) or (fragments .. "/" .. starCost),
                        fontSize = 12,
                        fontColor = canStarUp and { 100, 255, 100, 255 } or S.white,
                        fontWeight = "bold",
                    },
                },
            },
            -- 进度条
            UI.Panel {
                width = "100%",
                height = 16,
                borderRadius = 8,
                backgroundColor = S.progBg,
                overflow = "hidden",
                children = {
                    UI.Panel {
                        width = math.max(3, math.floor(progRatio * 100)) .. "%",
                        height = "100%",
                        borderRadius = 8,
                        backgroundColor = canStarUp and { 100, 255, 100, 255 } or { 200, 160, 60, 255 },
                    },
                },
            },
        },
    }

    -- 升星按钮
    if not isMaxStar then
        children[#children + 1] = UI.Panel {
            width = "100%",
            alignItems = "center",
            marginTop = 4,
            children = {
                UI.Panel {
                    width = "70%",
                    paddingTop = 10, paddingBottom = 10,
                    borderRadius = 10,
                    backgroundColor = canStarUp and S.btnGreen or S.btnDisabled,
                    justifyContent = "center", alignItems = "center",
                    onClick = function(self)
                        if not canStarUp then
                            ShowToast("碎片不足")
                            return
                        end
                        local ok, msg = HeroData.StarUp(heroId)
                        if ok then
                            local AudioManager = require("Game.AudioManager")
                            AudioManager.PlayUpgrade()
                            ShowToast("升星成功! " .. msg)
                        else
                            ShowToast(msg)
                        end
                        -- 刷新详情面板
                        ShowHeroDetail(heroId)
                    end,
                    children = {
                        UI.Label {
                            text = isTierAdvance and "突破升星" or "升星",
                            fontSize = 16, fontColor = S.btnText, fontWeight = "bold",
                        },
                    },
                },
            },
        }
    end

    return UI.Panel {
        width = "100%",
        gap = 6,
        children = children,
    }
end

-- ==================== 标签页：皮肤 ====================

--- 构建皮肤标签页内容
---@param heroId string
---@param heroDef table
local function BuildSkinTab(heroId, heroDef)
    return UI.Panel {
        width = "100%",
        alignItems = "center", justifyContent = "center",
        paddingTop = 40, paddingBottom = 40,
        children = {
            UI.Label { text = "皮肤系统", fontSize = 16, fontColor = S.dim },
            UI.Label { text = "敬请期待", fontSize = 13, fontColor = S.dimLocked, marginTop = 6 },
        },
    }
end

-- ==================== 详情面板刷新 ====================

--- 刷新详情面板内容区域（切换标签时调用）
---@param heroId string
---@param heroDef table
local function RefreshDetailContent(heroId, heroDef)
    if not detailContentContainer then return end
    detailContentContainer:ClearChildren()

    local content
    if detailTab == "info" then
        content = BuildInfoTab(heroId, heroDef)
    elseif detailTab == "equip" then
        content = BuildEquipTab(heroId, heroDef)
    elseif detailTab == "starup" then
        content = BuildStarUpTab(heroId, heroDef)
    elseif detailTab == "skin" then
        content = BuildSkinTab(heroId, heroDef)
    end

    if content then
        detailContentContainer:AddChild(content)
    end
end

--- 显示英雄详情面板
function ShowHeroDetail(heroId)
    -- 查找英雄定义
    local heroDef = nil
    if Config.LEADER_HERO.id == heroId then
        heroDef = Config.LEADER_HERO
    else
        for _, td in ipairs(Config.TOWER_TYPES) do
            if td.id == heroId then heroDef = td; break end
        end
    end
    if not heroDef then return end

    -- 保持标签状态（如果是同一个英雄则保持标签，否则重置为信息页）
    if detailHeroId ~= heroId then
        detailTab = "info"
    end
    detailHeroId = heroId

    local h = HeroData.Get(heroId)
    local isUnlocked = h and h.unlocked or false
    local level = (h and h.level) or 1
    local rarity = heroDef.rarity or "R"
    local rarityColor = GetRarityColor(rarity)
    local rarityBorder = GetRarityBorderColor(rarity)
    local tierInfo = HeroData.GetStarTierInfo(heroId)
    local stats = HeroData.GetHeroStats(heroId)
    local EquipData = require("Game.EquipData")
    local eqBonus = EquipData.GetTotalBonus(heroId)
    stats.atk = stats.atk + (eqBonus.atk or 0)
    local power = stats.atk + stats.spd
    local avatarIcon = heroDef.icon or heroId
    local avatarImage = "image/avatars/avatar_" .. avatarIcon .. ".png"

    -- 星级显示
    local starChildren = {}
    if isUnlocked and tierInfo.starInTier > 0 then
        local starRows = CreateStarRows(tierInfo.starInTier, tierInfo.color)
        for _, row in ipairs(starRows) do
            starChildren[#starChildren + 1] = row
        end
    end

    -- ========== 构建英雄切换列表（不含主角，品质高→低排序） ==========
    local isLeader = (heroDef.isLeader == true)
    local allHeroList = GetSortedHeroes()  -- 已按 上阵→解锁→品质高→低→名字 排序
    local currentHeroIdx = 1
    for i, hd in ipairs(allHeroList) do
        if hd.id == heroId then currentHeroIdx = i; break end
    end

    -- ========== 顶部：大头像展示 + 品质/名字 + 左右切换 ==========
    local elemId = Config.HERO_ELEMENT[heroId]
    local elemDef = elemId and Config.ELEMENTS[elemId]

    -- 构建 topSection children（过滤 nil 避免数组空洞导致 ipairs 提前终止）
    local topChildren = {}

    -- 品质标签（主角 rarity=="none" 时不显示）
    if rarity ~= "none" then
        topChildren[#topChildren + 1] = UI.Panel {
            flexDirection = "row", alignItems = "center", gap = 4,
            children = {
                UI.Label { text = "《", fontSize = 14, fontColor = rarityBorder },
                UI.Label { text = rarity, fontSize = 16, fontColor = rarityBorder, fontWeight = "bold" },
                UI.Label { text = "》", fontSize = 14, fontColor = rarityBorder },
            },
        }
    end

    -- 英雄名字
    topChildren[#topChildren + 1] = UI.Label { text = heroDef.name, fontSize = 18, fontColor = S.white, fontWeight = "bold" }

    -- 元素图标 + 星级（同一行）
    local elemStarChildren = {}
    if elemDef then
        elemStarChildren[#elemStarChildren + 1] = UI.Panel {
            width = 16, height = 16,
            backgroundImage = elemDef.icon,
            backgroundFit = "contain",
        }
    end
    if #starChildren > 0 then
        elemStarChildren[#elemStarChildren + 1] = UI.Panel {
            flexDirection = "row", gap = 1, alignItems = "center",
            children = starChildren,
        }
    end
    topChildren[#topChildren + 1] = UI.Panel {
        flexDirection = "row", alignItems = "center", gap = 6,
        height = 18,
        children = elemStarChildren,
    }

    -- 大头像
    topChildren[#topChildren + 1] = UI.Panel {
        width = 100, height = 100,
        borderRadius = 12,
        borderWidth = 2,
        borderColor = rarityBorder,
        backgroundColor = rarityColor,
        backgroundImage = avatarImage,
        backgroundFit = "cover",
        opacity = isUnlocked and 1.0 or 0.5,
        overflow = "hidden",
    }

    -- 等级 + 战力
    if isUnlocked then
        topChildren[#topChildren + 1] = UI.Panel {
            flexDirection = "row", gap = 10, alignItems = "center",
            children = {
                UI.Label { text = "Lv." .. level, fontSize = 14, fontColor = S.gold, fontWeight = "bold" },
                UI.Label { text = "战力:" .. FormatBigNum(power), fontSize = 12, fontColor = S.powerYellow },
            },
        }
    else
        topChildren[#topChildren + 1] = UI.Label { text = "未解锁", fontSize = 13, fontColor = S.dimLocked }
    end

    -- 左箭头（居左，主角不显示）
    if not isLeader then
        topChildren[#topChildren + 1] = UI.Panel {
            position = "absolute",
            left = 6, top = "50%",
            marginTop = -18,
            width = 36, height = 36,
            borderRadius = 18,
            backgroundColor = { 60, 45, 35, 200 },
            justifyContent = "center", alignItems = "center",
            onClick = function(self)
                local prevIdx = currentHeroIdx - 1
                if prevIdx < 1 then prevIdx = #allHeroList end
                detailTab = detailTab
                detailHeroId = allHeroList[prevIdx].id
                ShowHeroDetail(allHeroList[prevIdx].id)
            end,
            children = {
                UI.Label { text = "<", fontSize = 20, fontColor = { 200, 180, 160, 220 }, fontWeight = "bold" },
            },
        }

        -- 右箭头（居右）
        topChildren[#topChildren + 1] = UI.Panel {
            position = "absolute",
            right = 6, top = "50%",
            marginTop = -18,
            width = 36, height = 36,
            borderRadius = 18,
            backgroundColor = { 60, 45, 35, 200 },
            justifyContent = "center", alignItems = "center",
            onClick = function(self)
                local nextIdx = currentHeroIdx + 1
                if nextIdx > #allHeroList then nextIdx = 1 end
                detailTab = detailTab
                detailHeroId = allHeroList[nextIdx].id
                ShowHeroDetail(allHeroList[nextIdx].id)
            end,
            children = {
                UI.Label { text = ">", fontSize = 20, fontColor = { 200, 180, 160, 220 }, fontWeight = "bold" },
            },
        }
    end

    local topSection = UI.Panel {
        width = "100%",
        flex = 4,
        alignItems = "center",
        justifyContent = "center",
        gap = 4,
        children = topChildren,
    }

    -- ========== 标签栏（主角只有信息页） ==========
    local visibleTabs = isLeader and { DETAIL_TABS[1] } or DETAIL_TABS
    if isLeader then detailTab = "info" end
    local tabItems = {}
    for _, tabDef in ipairs(visibleTabs) do
        local isActive = (tabDef.key == detailTab)
        tabItems[#tabItems + 1] = UI.Panel {
            flex = 1,
            paddingTop = 8, paddingBottom = 8,
            alignItems = "center", justifyContent = "center",
            backgroundColor = isActive and { 80, 60, 45, 255 } or { 0, 0, 0, 0 },
            borderBottomWidth = isActive and 2 or 0,
            borderBottomColor = S.gold,
            onClick = function(self)
                detailTab = tabDef.key
                ShowHeroDetail(heroId)
            end,
            children = {
                UI.Label {
                    text = tabDef.label,
                    fontSize = 13,
                    fontColor = isActive and S.gold or S.dim,
                    fontWeight = isActive and "bold" or "normal",
                },
            },
        }
    end

    local tabBar = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexShrink = 0,
        backgroundColor = { 50, 36, 26, 240 },
        borderBottomWidth = 1,
        borderBottomColor = { 75, 55, 38, 100 },
    }
    for _, item in ipairs(tabItems) do
        tabBar:AddChild(item)
    end

    -- ========== 内容区域（可滚动） ==========
    detailContentContainer = UI.Panel {
        width = "100%",
        paddingLeft = 10, paddingRight = 10,
        paddingTop = 6, paddingBottom = 10,
    }

    local contentScroll = UI.ScrollView {
        flexGrow = 1, flexBasis = 0,
        scrollY = true,
        width = "100%",
        children = { detailContentContainer },
    }

    -- 下半部分容器（标签栏 + 内容）
    local bottomSection = UI.Panel {
        width = "100%",
        flex = 6,
        flexDirection = "column",
        children = {
            tabBar,
            contentScroll,
        },
    }

    -- ========== 关闭按钮（左下角） ==========
    local closeBtn = UI.Panel {
        position = "absolute",
        bottom = 8, left = 8,
        flexDirection = "row",
        alignItems = "center",
        gap = 2,
        paddingLeft = 10, paddingRight = 14,
        paddingTop = 6, paddingBottom = 6,
        borderRadius = 16,
        backgroundColor = { 80, 60, 45, 220 },
        zIndex = 10,
        onClick = function(self)
            HideHeroDetail()
        end,
        children = {
            UI.Label { text = "<", fontSize = 14, fontColor = { 200, 180, 160, 220 }, fontWeight = "bold" },
            UI.Label { text = "返回", fontSize = 13, fontColor = { 200, 180, 160, 220 } },
        },
    }

    -- ========== 组装面板 ==========
    local detailPanel = UI.Panel {
        position = "absolute",
        top = 5, left = 5, right = 5, bottom = 5,
        backgroundColor = S.popupBg,
        borderRadius = 12,
        borderWidth = 2,
        borderColor = rarityBorder,
        flexDirection = "column",
        overflow = "hidden",
        children = {
            topSection,
            bottomSection,
            closeBtn,
        },
    }

    -- 填充内容
    RefreshDetailContent(heroId, heroDef)

    -- 半透明遮罩
    if heroDetailOverlay then
        pageRoot:RemoveChild(heroDetailOverlay)
    end
    heroDetailOverlay = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 200,
        backgroundColor = { 0, 0, 0, 180 },
        children = { detailPanel },
    }
    pageRoot:AddChild(heroDetailOverlay)
end

--- 隐藏英雄详情面板
function HideHeroDetail()
    if heroDetailOverlay then
        pageRoot:RemoveChild(heroDetailOverlay)
        heroDetailOverlay = nil
        detailContentContainer = nil
        detailHeroId = nil
    end
end

-- ============================================================================
-- 公开接口
-- ============================================================================

--- 标题栏："英雄" 标题
local function CreateTitleBar()
    return UI.Panel {
        id = "heroTitleBar",
        width = "100%",
        paddingTop = 4, paddingBottom = 6,
        paddingLeft = 14,
        borderBottomWidth = 1,
        borderBottomColor = { 75, 55, 38, 100 },
        flexShrink = 0,
        children = {
            UI.Label {
                text = "英雄",
                fontSize = 17,
                fontColor = S.gold,
                fontWeight = "bold",
            },
        },
    }
end

--- 创建英雄养成页面
---@param uiModule any
---@return any
function HeroUI.CreatePage(uiModule)
    UI = uiModule
    pageRoot = UI.Panel {
        id = "heroPage",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        flexDirection = "column",
        backgroundColor = S.pageBg,
        children = {},
    }
    HeroUI.Refresh()
    return pageRoot
end

--- 刷新页面（重建主页内容，不含弹出层）
function HeroUI.Refresh()
    if not pageRoot or not UI then return end
    -- 保存弹出层状态
    local wasPopupOpen = (collectionOverlay ~= nil)
    local wasDetailPopupOpen = (collectionDetailOverlay ~= nil)
    local wasInventoryOpen = InventoryUI.IsVisible()

    pageRoot:ClearChildren()
    collectionOverlay = nil
    popupContentContainer = nil
    collectionDetailOverlay = nil
    detailPopupContentContainer = nil
    heroDetailOverlay = nil
    -- 仓库弹窗由 InventoryUI 模块管理，ClearChildren 已清除其 overlay
    if wasInventoryOpen then
        InventoryUI.Hide(pageRoot)
    end

    pageRoot:AddChild(CreateTitleBar())
    pageRoot:AddChild(CreateHeroList())
    pageRoot:AddChild(CreateBottomBar())

    -- 如果弹出层之前打开着，重新打开
    if wasPopupOpen then
        ShowCollectionPopup()
    elseif wasDetailPopupOpen then
        ShowCollectionDetailPopup()
    elseif wasInventoryOpen then
        InventoryUI.Show(UI, pageRoot)
    end
end

return HeroUI
