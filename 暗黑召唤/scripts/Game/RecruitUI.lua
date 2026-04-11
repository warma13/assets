-- Game/RecruitUI.lua
-- 招募页面 UI（对齐咸鱼之王招募系统）

local Config = require("Game.Config")
local HeroData = require("Game.HeroData")
local RecruitData = require("Game.RecruitData")
local Currency = require("Game.Currency")

local RecruitUI = {}

---@type any
local UI = nil
---@type any
local pageRoot = nil

-- 稀有度颜色
local RARITY_COLORS = {
    N   = { 180, 180, 180 },
    R   = { 120, 200, 120 },
    SR  = { 140, 120, 220 },
    SSR = { 255, 200, 50 },
    UR  = { 255, 215, 60 },
    LR  = { 255, 80, 80 },
}

-- 稀有度背景颜色（暗色调）
local RARITY_BG = {
    N   = { 35, 35, 30, 200 },
    R   = { 30, 50, 30, 200 },
    SR  = { 35, 25, 55, 200 },
    SSR = { 50, 40, 15, 200 },
    UR  = { 50, 45, 10, 200 },
    LR  = { 50, 15, 15, 200 },
}

--- 创建招募页面
---@param uiModule any
---@return any
function RecruitUI.CreatePage(uiModule)
    UI = uiModule

    pageRoot = UI.Panel {
        id = "recruitPage",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        flexDirection = "column",
        backgroundColor = { 15, 12, 25, 255 },
        children = {},
    }

    RecruitUI.Refresh()
    return pageRoot
end

--- 刷新页面内容
function RecruitUI.Refresh()
    if not pageRoot or not UI then return end
    pageRoot:ClearChildren()

    -- 顶部招募令显示
    pageRoot:AddChild(RecruitUI.CreateTokenBar())
    -- 池子横幅（大幅视觉区域）
    pageRoot:AddChild(RecruitUI.CreatePoolBanner())
    -- 底部按钮区
    pageRoot:AddChild(RecruitUI.CreateButtonArea())
end

--- 顶部招募令货币栏
function RecruitUI.CreateTokenBar()
    local tokens = HeroData.currencies.void_pact or 0
    local totalPulls = RecruitData.GetTotalPulls()

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingTop = 10, paddingBottom = 10,
        paddingLeft = 12, paddingRight = 12,
        backgroundColor = { 20, 16, 32, 200 },
        borderWidth = 1,
        borderColor = { 70, 55, 100, 120 },
        flexShrink = 0,
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = {
                    Currency.IconWidget(UI, "void_pact", 18),
                    UI.Label {
                        text = "虚空契约: " .. tokens,
                        fontSize = 15,
                        fontColor = { 255, 200, 50, 255 },
                    },
                },
            },
            UI.Label {
                text = "十连保底SSR",
                fontSize = 12,
                fontColor = { 200, 160, 255, 160 },
            },
            UI.Label {
                text = "累计: " .. totalPulls .. "抽",
                fontSize = 12,
                fontColor = { 150, 140, 170, 180 },
            },
        },
    }
end

--- 池子横幅（大幅视觉区域，填满中间空间）
function RecruitUI.CreatePoolBanner()
    return UI.Panel {
        width = "100%",
        flex = 1,
        backgroundImage = "image/recruit_pool_bg_20260407001701.png",
        backgroundFit = "cover",
        justifyContent = "flex-start",
        alignItems = "center",
        overflow = "hidden",
        children = {
            -- 标题
            UI.Label {
                text = "深渊祭坛",
                fontSize = 36,
                fontColor = { 220, 180, 255, 255 },
                fontWeight = "bold",
                marginTop = 16,
                zIndex = 1,
            },
            -- 详情入口按钮
            UI.Panel {
                position = "absolute",
                bottom = 10, right = 12,
                flexDirection = "row",
                alignItems = "center",
                gap = 3,
                paddingLeft = 10, paddingRight = 10,
                paddingTop = 5, paddingBottom = 5,
                backgroundColor = { 0, 0, 0, 120 },
                borderRadius = 12,
                borderWidth = 1,
                borderColor = { 160, 130, 220, 150 },
                onClick = function(self)
                    RecruitUI.ShowDetailPopup()
                end,
                children = {
                    UI.Label {
                        text = "详情",
                        fontSize = 12,
                        fontColor = { 200, 180, 255, 230 },
                    },
                    UI.Label {
                        text = ">",
                        fontSize = 12,
                        fontColor = { 160, 140, 200, 180 },
                    },
                },
            },
        },
    }
end

--- 显示详情弹窗（英雄列表 + 概率说明）
function RecruitUI.ShowDetailPopup()
    if not pageRoot or not UI then return end

    -- 移除旧弹窗
    local old = pageRoot:FindById("detailPopup")
    if old then pageRoot:RemoveChild(old) end

    -- 构建英雄列表
    local listChildren = {}

    -- 概率说明
    local rates = Config.RECRUIT_RATES
    local rateOrder = { "LR", "UR", "SSR", "SR", "R", "N" }
    local rateLabels = {}
    for _, r in ipairs(rateOrder) do
        if rates[r] then
            rateLabels[#rateLabels + 1] = UI.Panel {
                paddingLeft = 6, paddingRight = 6,
                paddingTop = 2, paddingBottom = 2,
                backgroundColor = { RARITY_COLORS[r][1], RARITY_COLORS[r][2], RARITY_COLORS[r][3], 40 },
                borderRadius = 4,
                children = {
                    UI.Label {
                        text = r .. " " .. rates[r] .. "%",
                        fontSize = 12,
                        fontColor = RARITY_COLORS[r],
                    },
                },
            }
        end
    end

    listChildren[#listChildren + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        justifyContent = "center",
        gap = 6,
        paddingBottom = 8,
        children = rateLabels,
    }

    listChildren[#listChildren + 1] = UI.Label {
        text = "十连召唤保底至少1个SSR",
        fontSize = 11,
        fontColor = { 180, 160, 120, 200 },
        alignSelf = "center",
        marginBottom = 10,
    }

    -- 分割线
    listChildren[#listChildren + 1] = UI.Panel {
        width = "90%",
        height = 1,
        backgroundColor = { 80, 60, 120, 100 },
        alignSelf = "center",
        marginBottom = 10,
    }

    -- 英雄列表（按稀有度倒序）
    local rarityOrder = { "LR", "UR", "SSR", "SR", "R", "N" }
    for _, rarity in ipairs(rarityOrder) do
        local heroIds = Config.RECRUIT_POOL[rarity]
        if heroIds then
            local fragRange = Config.RECRUIT_FRAGMENT_DROP[rarity]
            for _, heroId in ipairs(heroIds) do
                local heroName = heroId
                local heroColor = { 200, 200, 200 }
                for _, td in ipairs(Config.TOWER_TYPES) do
                    if td.id == heroId then
                        heroName = td.name
                        heroColor = td.color
                        break
                    end
                end

                local h = HeroData.Get(heroId)
                local frags = h and h.fragments or 0
                local unlocked = h and h.unlocked or false

                listChildren[#listChildren + 1] = UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    alignItems = "center",
                    paddingTop = 6, paddingBottom = 6,
                    paddingLeft = 10, paddingRight = 10,
                    marginBottom = 2,
                    backgroundColor = RARITY_BG[rarity],
                    borderRadius = 6,
                    children = {
                        UI.Panel {
                            width = 36,
                            height = 18,
                            justifyContent = "center",
                            alignItems = "center",
                            backgroundColor = RARITY_COLORS[rarity],
                            borderRadius = 4,
                            marginRight = 8,
                            children = {
                                UI.Label {
                                    text = rarity,
                                    fontSize = 10,
                                    fontColor = { 20, 16, 32, 255 },
                                },
                            },
                        },
                        UI.Label {
                            text = heroName,
                            fontSize = 13,
                            fontColor = heroColor,
                            flex = 1,
                        },
                        UI.Label {
                            text = fragRange.min .. "~" .. fragRange.max .. "碎片",
                            fontSize = 11,
                            fontColor = { 150, 140, 170, 180 },
                            marginRight = 8,
                        },
                        UI.Label {
                            text = (unlocked and "✓ " or "") .. frags .. "碎片",
                            fontSize = 11,
                            fontColor = unlocked and { 100, 220, 100, 255 } or { 180, 160, 140, 200 },
                        },
                    },
                }
            end
        end
    end

    local popup = UI.Panel {
        id = "detailPopup",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        flexDirection = "column",
        backgroundColor = { 0, 0, 0, 210 },
        pointerEvents = "auto",
        children = {
            -- 标题栏
            UI.Panel {
                width = "100%",
                alignItems = "center",
                paddingTop = 14, paddingBottom = 10,
                flexShrink = 0,
                backgroundColor = { 25, 20, 40, 255 },
                borderWidth = 1,
                borderColor = { 100, 70, 160, 120 },
                children = {
                    UI.Label {
                        text = "深渊祭坛 · 详情",
                        fontSize = 18,
                        fontColor = { 220, 180, 255, 255 },
                        fontWeight = "bold",
                    },
                },
            },
            -- 可滚动英雄列表
            UI.ScrollView {
                width = "100%",
                flex = 1,
                paddingTop = 10, paddingBottom = 10,
                paddingLeft = 10, paddingRight = 10,
                children = listChildren,
            },
            -- 底部返回按钮
            UI.Panel {
                width = "100%",
                paddingTop = 8, paddingBottom = 10,
                paddingLeft = 12, paddingRight = 12,
                flexShrink = 0,
                backgroundColor = { 25, 20, 40, 255 },
                borderWidth = 1,
                borderColor = { 100, 70, 160, 120 },
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 4,
                        paddingLeft = 14, paddingRight = 18,
                        paddingTop = 6, paddingBottom = 6,
                        backgroundColor = { 60, 40, 80, 255 },
                        borderRadius = 8,
                        borderWidth = 1,
                        borderColor = { 140, 100, 200, 150 },
                        onClick = function(self)
                            local p = pageRoot:FindById("detailPopup")
                            if p then pageRoot:RemoveChild(p) end
                        end,
                        children = {
                            UI.Label {
                                text = "<",
                                fontSize = 14,
                                fontColor = { 180, 160, 220, 200 },
                            },
                            UI.Label {
                                text = "返回",
                                fontSize = 14,
                                fontColor = { 200, 180, 240, 255 },
                            },
                        },
                    },
                },
            },
        },
    }

    pageRoot:AddChild(popup)
end

--- 概率说明
function RecruitUI.CreateRateInfo()
    local rates = Config.RECRUIT_RATES
    local rateOrder = { "LR", "UR", "SSR", "SR", "R", "N" }
    local rateLabels = {}
    for _, r in ipairs(rateOrder) do
        if rates[r] then
            rateLabels[#rateLabels + 1] = UI.Label {
                text = r .. " " .. rates[r] .. "%",
                fontSize = 12,
                fontColor = RARITY_COLORS[r],
            }
        end
    end
    rateLabels[#rateLabels + 1] = UI.Label {
        text = "(每" .. Config.RECRUIT_PITY .. "抽保底SSR)",
        fontSize = 11,
        fontColor = { 180, 160, 120, 180 },
    }

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = 10,
        paddingTop = 6, paddingBottom = 6,
        flexShrink = 0,
        children = rateLabels,
    }
end

--- 招募池展示（显示所有可招募英雄）
function RecruitUI.CreatePoolDisplay()
    local poolChildren = {}

    -- 标题
    poolChildren[#poolChildren + 1] = UI.Label {
        text = "— 深渊祭坛 —",
        fontSize = 18,
        fontColor = { 200, 160, 255, 255 },
        fontWeight = "bold",
        marginBottom = 8,
        alignSelf = "center",
    }

    -- 按稀有度倒序展示
    local rarityOrder = { "LR", "UR", "SSR", "SR", "R", "N" }
    for _, rarity in ipairs(rarityOrder) do
        local heroIds = Config.RECRUIT_POOL[rarity]
        if heroIds then
            local fragRange = Config.RECRUIT_FRAGMENT_DROP[rarity]
            for _, heroId in ipairs(heroIds) do
                local heroName = heroId
                local heroColor = { 200, 200, 200 }
                for _, td in ipairs(Config.TOWER_TYPES) do
                    if td.id == heroId then
                        heroName = td.name
                        heroColor = td.color
                        break
                    end
                end

                -- 当前碎片数
                local h = HeroData.Get(heroId)
                local frags = h and h.fragments or 0
                local unlocked = h and h.unlocked or false

                poolChildren[#poolChildren + 1] = UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    alignItems = "center",
                    paddingTop = 6, paddingBottom = 6,
                    paddingLeft = 10, paddingRight = 10,
                    marginBottom = 2,
                    backgroundColor = RARITY_BG[rarity],
                    borderRadius = 6,
                    children = {
                        -- 稀有度标签
                        UI.Panel {
                            width = 40,
                            height = 20,
                            justifyContent = "center",
                            alignItems = "center",
                            backgroundColor = RARITY_COLORS[rarity],
                            borderRadius = 4,
                            marginRight = 8,
                            children = {
                                UI.Label {
                                    text = rarity,
                                    fontSize = 11,
                                    fontColor = { 20, 16, 32, 255 },
                                },
                            },
                        },
                        -- 英雄名
                        UI.Label {
                            text = heroName,
                            fontSize = 14,
                            fontColor = heroColor,
                            flex = 1,
                        },
                        -- 碎片掉落区间
                        UI.Label {
                            text = fragRange.min .. "~" .. fragRange.max .. "碎片",
                            fontSize = 11,
                            fontColor = { 150, 140, 170, 180 },
                            marginRight = 8,
                        },
                        -- 当前碎片
                        UI.Label {
                            text = (unlocked and "✓ " or "") .. frags .. "碎片",
                            fontSize = 12,
                            fontColor = unlocked and { 100, 220, 100, 255 } or { 180, 160, 140, 200 },
                        },
                    },
                }
            end
        end
    end

    return UI.ScrollView {
        width = "100%",
        flex = 1,
        paddingTop = 8, paddingBottom = 8,
        paddingLeft = 8, paddingRight = 8,
        children = poolChildren,
    }
end

--- 通过 heroId 获取头像图片路径
---@param heroId string|nil
---@return string|nil
local function GetAvatarImage(heroId)
    if not heroId then return nil end
    -- 查找 icon
    local icon = heroId
    if heroId == "leader" then
        icon = Config.LEADER_HERO.icon or "leader"
    else
        for _, td in ipairs(Config.TOWER_TYPES) do
            if td.id == heroId then
                icon = td.icon or heroId
                break
            end
        end
    end
    return "image/avatars/avatar_" .. icon .. ".png"
end

--- 创建单个奖励卡片（与宝箱弹窗同风格）
---@param emoji string
---@param name string
---@param amount number
---@param borderColor table
---@param avatarImage string|nil
---@param isNew boolean|nil  是否为首次获得（NEW标记）
---@return any
local function CreateRewardCard(emoji, name, amount, borderColor, avatarImage, isNew)
    -- 图标区域：优先使用头像图片（占卡片 80%），否则显示 emoji
    local iconChild
    if avatarImage then
        iconChild = UI.Panel {
            width = "80%", aspectRatio = 1.0,
            borderRadius = 8,
            overflow = "hidden",
            backgroundImage = avatarImage,
            backgroundFit = "cover",
        }
    else
        iconChild = UI.Label {
            text = emoji,
            fontSize = 32,
        }
    end

    -- 底部信息：NEW 显示 "NEW!" 标签，重复显示碎片数量
    local bottomChild
    if isNew then
        bottomChild = UI.Label {
            text = "NEW!",
            fontSize = 14,
            fontColor = { 255, 255, 100, 255 },
            fontWeight = "bold",
        }
    else
        bottomChild = UI.Label {
            text = "x" .. amount,
            fontSize = 14,
            fontColor = { 255, 220, 80, 255 },
            fontWeight = "bold",
        }
    end

    -- 构建 children
    local cardChildren = {
        iconChild,
        UI.Panel {
            position = "absolute",
            bottom = -2, left = 0,
            paddingLeft = 4, paddingRight = 4,
            paddingTop = 1, paddingBottom = 1,
            backgroundColor = { borderColor[1], borderColor[2], borderColor[3], 230 },
            borderRadius = 3,
            children = {
                UI.Label {
                    text = name,
                    fontSize = 8,
                    fontColor = { 20, 16, 32, 255 },
                },
            },
        },
        bottomChild,
    }

    return UI.Panel {
        width = "30%",
        aspectRatio = 1.0,
        marginBottom = 10,
        backgroundColor = isNew and { 50, 45, 30, 240 } or { 40, 35, 30, 230 },
        borderRadius = 8,
        borderWidth = isNew and 3 or 2,
        borderColor = isNew and { 255, 220, 60, 255 } or borderColor,
        justifyContent = "center",
        alignItems = "center",
        gap = 2,
        children = cardChildren,
    }
end

--- 显示招募结果弹窗（与宝箱弹窗同风格：3x3 网格，溢出滚动）
---@param results table
local function ShowResultPopup(results)
    if not pageRoot or not UI then return end

    -- 移除旧弹窗
    local old = pageRoot:FindById("recruitResultPopup")
    if old then pageRoot:RemoveChild(old) end

    -- 构建卡片
    local rewardCards = {}
    for _, r in ipairs(results) do
        local rc = RARITY_COLORS[r.rarity] or { 200, 200, 200 }
        rewardCards[#rewardCards + 1] = CreateRewardCard(
            "👤",
            r.rarity .. " " .. r.heroName,
            r.fragments,
            { rc[1], rc[2], rc[3], 200 },
            GetAvatarImage(r.heroId),
            r.isNew
        )
    end

    local popup = UI.Panel {
        id = "recruitResultPopup",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        flexDirection = "column",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 200 },
        pointerEvents = "auto",
        children = {
            -- 顶部标题
            UI.Panel {
                width = "100%",
                alignItems = "center",
                paddingTop = 40,
                flexShrink = 0,
                children = {
                    UI.Panel {
                        paddingLeft = 14, paddingRight = 14,
                        paddingTop = 3, paddingBottom = 3,
                        backgroundColor = { 140, 100, 220, 255 },
                        borderRadius = 4,
                        marginBottom = 6,
                        children = {
                            UI.Label {
                                text = "深渊祭坛",
                                fontSize = 12,
                                fontColor = { 255, 255, 255, 255 },
                                fontWeight = "bold",
                            },
                        },
                    },
                    UI.Label {
                        text = "恭喜获得",
                        fontSize = 28,
                        fontColor = { 255, 255, 255, 255 },
                        fontWeight = "bold",
                        marginBottom = 12,
                    },
                },
            },
            -- 中间可滚动网格
            UI.ScrollView {
                width = "100%",
                flex = 1,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        flexWrap = "wrap",
                        justifyContent = "center",
                        gap = 8,
                        paddingLeft = 16, paddingRight = 16,
                        paddingTop = 4, paddingBottom = 12,
                        children = rewardCards,
                    },
                },
            },
            -- 底部按钮
            UI.Panel {
                width = "100%",
                paddingLeft = 24, paddingRight = 24,
                paddingTop = 10, paddingBottom = 6,
                flexShrink = 0,
                children = {
                    UI.Button {
                        text = "确定",
                        fontSize = 16,
                        variant = "primary",
                        width = "100%",
                        height = 46,
                        onClick = function(self)
                            local p = pageRoot:FindById("recruitResultPopup")
                            if p then pageRoot:RemoveChild(p) end
                            RecruitUI.Refresh()
                        end,
                    },
                },
            },
            UI.Label {
                text = "点击确定返回招募界面",
                fontSize = 11,
                fontColor = { 180, 140, 100, 150 },
                marginTop = 2,
                marginBottom = 8,
                flexShrink = 0,
            },
        },
    }

    pageRoot:AddChild(popup)
end

--- 执行招募并展示结果
---@param pullCount number
---@param isFree boolean
local function DoRecruitAndShow(pullCount, isFree)
    local ok, result = RecruitData.DoPull(pullCount, isFree)
    if ok then
        local AudioManager = require("Game.AudioManager")
        AudioManager.PlayRecruit()
        ShowResultPopup(result)
    else
        -- 失败提示（简单刷新页面，提示在日志）
        print("[RecruitUI] Pull failed: " .. tostring(result))
        RecruitUI.Refresh()
    end
end

--- 显示购买契约弹窗（数量选择器）
function RecruitUI.ShowBuyPopup(defaultQty)
    if not pageRoot or not UI then return end

    local old = pageRoot:FindById("buyVoidPactPopup")
    if old then pageRoot:RemoveChild(old) end

    local UNIT_PRICE = 300
    local MIN_QTY = 1
    local MAX_QTY = 99
    local qty = defaultQty or 1

    -- 动态更新的标签引用
    local qtyLabel, priceLabel, buyBtnLabel, buyBtn

    local function updateDisplay()
        local totalCost = qty * UNIT_PRICE
        local canAfford = Currency.Get("shadow_essence") >= totalCost
        if qtyLabel then qtyLabel:SetValue(tostring(qty)) end
        if priceLabel then priceLabel:SetText(tostring(totalCost)) end
        if buyBtnLabel then buyBtnLabel:SetText("购买 ×" .. qty) end
        if buyBtn then
            buyBtn:SetStyle({
                backgroundColor = canAfford
                    and { 100, 70, 180, 255 }
                    or { 60, 55, 65, 200 },
                borderColor = canAfford
                    and { 180, 140, 255, 200 }
                    or { 80, 75, 85, 120 },
            })
        end
        if priceLabel then
            priceLabel:SetStyle({
                fontColor = canAfford
                    and { 255, 220, 100, 255 }
                    or { 140, 130, 130, 180 },
            })
        end
        if buyBtnLabel then
            buyBtnLabel:SetStyle({
                fontColor = canAfford
                    and { 255, 255, 255, 255 }
                    or { 140, 130, 130, 180 },
            })
        end
    end

    local function changeQty(delta)
        qty = math.max(MIN_QTY, math.min(MAX_QTY, qty + delta))
        updateDisplay()
    end

    local function doBuy()
        local totalCost = qty * UNIT_PRICE
        if not Currency.Has("shadow_essence", totalCost) then
            local Toast = require("Game.Toast")
            Toast.Show("暗影精粹不足", { 255, 100, 80 })
            return
        end
        Currency.Spend("shadow_essence", totalCost)
        Currency.Add("void_pact", qty)
        local Toast = require("Game.Toast")
        Toast.Show("获得虚空契约 ×" .. qty, { 180, 140, 255 })
        -- closePopup 在此时还未定义，直接内联关闭
        local p = pageRoot:FindById("buyVoidPactPopup")
        if p then pageRoot:RemoveChild(p) end
        RecruitUI.Refresh()
    end

    -- 数量按钮样式
    local function qtyBtn(text, delta)
        return UI.Panel {
            width = 40, height = 40,
            borderRadius = 8,
            backgroundColor = { 70, 55, 110, 255 },
            borderWidth = 1,
            borderColor = { 140, 110, 200, 180 },
            justifyContent = "center",
            alignItems = "center",
            pointerEvents = "auto",
            onClick = function() changeQty(delta) end,
            children = {
                UI.Label {
                    text = text,
                    fontSize = 22,
                    fontColor = { 255, 255, 255, 255 },
                    fontWeight = "bold",
                },
            },
        }
    end

    qtyLabel = UI.TextField {
        id = "buyQtyLabel",
        value = tostring(qty),
        fontSize = 18,
        fontColor = { 255, 255, 255, 255 },
        textAlign = "center",
        maxLength = 2,
        width = 60, height = 40,
        backgroundColor = { 35, 28, 55, 255 },
        borderRadius = 6,
        borderWidth = 1,
        borderColor = { 80, 65, 120, 150 },
        onChange = function(self, value)
            local n = tonumber(value)
            if n then
                qty = math.max(MIN_QTY, math.min(MAX_QTY, math.floor(n)))
            end
            updateDisplay()
        end,
        onSubmit = function(self, value)
            local n = tonumber(value)
            if n then
                qty = math.max(MIN_QTY, math.min(MAX_QTY, math.floor(n)))
            end
            updateDisplay()
        end,
    }

    priceLabel = UI.Label {
        id = "buyPriceLabel",
        text = tostring(qty * UNIT_PRICE),
        fontSize = 16,
        fontColor = { 255, 220, 100, 255 },
        fontWeight = "bold",
    }

    buyBtnLabel = UI.Label {
        id = "buyBtnLabel",
        text = "购买 ×" .. qty,
        fontSize = 15,
        fontColor = { 255, 255, 255, 255 },
        fontWeight = "bold",
    }

    buyBtn = UI.Panel {
        width = "100%",
        borderRadius = 10,
        backgroundColor = { 100, 70, 180, 255 },
        borderWidth = 1,
        borderColor = { 180, 140, 255, 200 },
        justifyContent = "center",
        alignItems = "center",
        flexDirection = "column",
        gap = 1,
        paddingTop = 8, paddingBottom = 8,
        pointerEvents = "auto",
        onClick = function() doBuy() end,
        children = {
            -- 价格行
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = 4,
                children = {
                    Currency.IconWidget(UI, "shadow_essence", 16),
                    priceLabel,
                },
            },
            buyBtnLabel,
        },
    }

    local function closePopup()
        local p = pageRoot:FindById("buyVoidPactPopup")
        if p then pageRoot:RemoveChild(p) end
    end

    local popup = UI.Panel {
        id = "buyVoidPactPopup",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 180 },
        pointerEvents = "auto",
        onClick = function() closePopup() end,
        children = {
            -- 弹窗主体
            UI.Panel {
                width = "80%",
                backgroundColor = { 25, 20, 40, 250 },
                borderRadius = 14,
                borderWidth = 2,
                borderColor = { 120, 90, 180, 200 },
                paddingTop = 18, paddingBottom = 18,
                paddingLeft = 20, paddingRight = 20,
                flexDirection = "column",
                alignItems = "center",
                gap = 14,
                pointerEvents = "auto",
                onClick = function() end,
                children = {
                    -- 标题
                    UI.Label {
                        text = "购买",
                        fontSize = 20,
                        fontColor = { 220, 180, 255, 255 },
                        fontWeight = "bold",
                    },
                    -- 副标题
                    UI.Label {
                        text = "购买虚空契约",
                        fontSize = 13,
                        fontColor = { 180, 160, 220, 200 },
                    },
                    -- 商品图标
                    UI.Panel {
                        width = 72, height = 72,
                        borderRadius = 12,
                        backgroundColor = { 50, 35, 70, 255 },
                        borderWidth = 2,
                        borderColor = { 200, 40, 40, 200 },
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            Currency.IconWidget(UI, "void_pact", 40),
                        },
                    },
                    -- 数量选择器
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 12,
                        children = {
                            qtyBtn("−", -1),
                            qtyLabel,
                            qtyBtn("+", 1),
                        },
                    },
                    -- 购买按钮（含价格）
                    buyBtn,
                },
            },

        },
    }

    pageRoot:AddChild(popup)
    updateDisplay()
end

--- 底部按钮区
function RecruitUI.CreateButtonArea()
    local tokens = HeroData.currencies.void_pact or 0
    local canFree = RecruitData.CanFreePull()
    local canSingle = RecruitData.CanAfford(Config.RECRUIT_SINGLE_COST)
    local canTen = RecruitData.CanAfford(Config.RECRUIT_TEN_COST)

    local buttons = {}

    -- 单抽按钮
    buttons[#buttons + 1] = UI.Panel {
        flex = 1,
        height = 56,
        borderRadius = 10,
        backgroundColor = canSingle and { 60, 50, 90, 255 } or { 40, 35, 55, 200 },
        borderWidth = 1,
        borderColor = canSingle and { 140, 100, 220, 200 } or { 60, 50, 80, 100 },
        justifyContent = "center",
        alignItems = "center",
        gap = 2,
        onClick = function(self)
            if canSingle then
                DoRecruitAndShow(1, false)
            else
                RecruitUI.ShowBuyPopup(1)
            end
        end,
        children = {
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = 3,
                children = {
                    Currency.IconWidget(UI, "void_pact", 16),
                    UI.Label {
                        text = tostring(Config.RECRUIT_SINGLE_COST),
                        fontSize = 14,
                        fontColor = { 255, 220, 80, 255 },
                        fontWeight = "bold",
                    },
                },
            },
            UI.Label {
                text = "招募一次",
                fontSize = 14,
                fontColor = canSingle and { 255, 255, 255, 255 } or { 120, 110, 140, 180 },
                fontWeight = "bold",
            },
        },
    }

    -- 十连按钮
    buttons[#buttons + 1] = UI.Panel {
        flex = 1,
        height = 56,
        borderRadius = 10,
        backgroundColor = canTen and { 140, 100, 40, 255 } or { 50, 42, 30, 200 },
        borderWidth = 1,
        borderColor = canTen and { 255, 200, 60, 200 } or { 80, 65, 40, 100 },
        justifyContent = "center",
        alignItems = "center",
        gap = 2,
        onClick = function(self)
            if canTen then
                DoRecruitAndShow(10, false)
            else
                RecruitUI.ShowBuyPopup(10)
            end
        end,
        children = {
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = 3,
                children = {
                    Currency.IconWidget(UI, "void_pact", 16),
                    UI.Label {
                        text = tostring(Config.RECRUIT_TEN_COST),
                        fontSize = 14,
                        fontColor = { 255, 220, 80, 255 },
                        fontWeight = "bold",
                    },
                },
            },
            UI.Label {
                text = "招募十次",
                fontSize = 14,
                fontColor = canTen and { 255, 255, 255, 255 } or { 120, 110, 140, 180 },
                fontWeight = "bold",
            },
        },
    }

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        gap = 8,
        paddingTop = 10, paddingBottom = 10,
        paddingLeft = 12, paddingRight = 12,
        backgroundColor = { 20, 16, 32, 230 },
        borderWidth = 1,
        borderColor = { 100, 70, 180, 120 },
        flexShrink = 0,
        children = buttons,
    }
end

return RecruitUI
