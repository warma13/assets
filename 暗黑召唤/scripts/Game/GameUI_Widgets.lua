-- Game/GameUI_Widgets.lua
-- UI 组件：StageBar、HUD、货币展示、资源商店

return function(GameUI, ctx)

local Config   = require("Game.Config")
local State    = require("Game.State")
local Currency = require("Game.Currency")
local Toast    = require("Game.Toast")

local FormatNum = ctx.FormatNum

function GameUI.CreateStageBar()
    local typeTag = ""
    if State.waveType == "boss" then typeTag = " BOSS"
    elseif State.waveType == "elite" then typeTag = " 精英" end
    local waveText = State.currentStage .. "-" .. State.currentWave .. typeTag

    return ctx.UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "center",
        paddingTop = 8, paddingBottom = 4,
        flexShrink = 0,
        children = {
            ctx.UI.Panel {
                paddingLeft = 16, paddingRight = 16,
                paddingTop = 6, paddingBottom = 6,
                backgroundColor = { 20, 16, 32, 200 },
                borderRadius = 12,
                borderWidth = 1,
                borderColor = { 70, 55, 100, 120 },
                children = {
                    ctx.UI.Label {
                        id = "stageBarLabel",
                        text = waveText,
                        fontSize = 13,
                        fontColor = Config.COLORS.textSecondary,
                    },
                },
            },
        },
    }
end

--- 顶部 HUD（战斗页专用，绝对定位）
function GameUI.CreateHUD()
    return ctx.UI.Panel {
        id = "hud",
        position = "absolute",
        top = 8, left = 8, right = 8,
        height = 40,
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        paddingLeft = 12, paddingRight = 12,
        backgroundColor = { 20, 16, 32, 200 },
        borderRadius = 8,
        borderWidth = 1,
        borderColor = { 70, 55, 100, 120 },
        pointerEvents = "none",
        children = {
            ctx.UI.Label {
                id = "waveLabel",
                text = "波次: 0",
                fontSize = 13,
                fontColor = Config.COLORS.textSecondary,
            },
        }
    }
end

--- 紧凑货币药丸（用 Panel 代替 Button 做"+"，避免 Button 默认 minWidth=64 撑大）
--- @param uiRef any UI 模块引用
--- @param currencyId string
--- @param labelId string
--- @param labelColor table
function GameUI.CreateCurrencyChip(uiRef, currencyId, labelId, labelColor)
    return uiRef.Panel {
        flexDirection = "row",
        alignItems = "center",
        height = 24,
        paddingLeft = 4, paddingRight = 2,
        backgroundColor = { 15, 12, 28, 210 },
        borderRadius = 12,
        borderWidth = 1,
        borderColor = { labelColor[1], labelColor[2], labelColor[3], 60 },
        gap = 4,
        children = {
            Currency.IconWidget(uiRef, currencyId, 16),
            uiRef.Label {
                id = labelId,
                text = "0",
                fontSize = 12,
                fontColor = { labelColor[1], labelColor[2], labelColor[3], 255 },
            },
            uiRef.Panel {
                width = 20, height = 20,
                borderRadius = 10,
                backgroundColor = { labelColor[1], labelColor[2], labelColor[3], 80 },
                justifyContent = "center",
                alignItems = "center",
                onClick = function()
                    GameUI.ShowResourceShop(currencyId)
                end,
                children = {
                    uiRef.Label {
                        text = "+",
                        fontSize = 14,
                        fontColor = { 255, 255, 255, 200 },
                    },
                },
            },
        },
    }
end

--- 货币模块行：图标 + 数字 + "+" 按钮（公开组件，供其他页面复用）
function GameUI.CurrencyPill(currencyId, labelId, labelColor)
    local def = Config.CURRENCY[currencyId]
    return ctx.UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        height = 24,
        paddingLeft = 4, paddingRight = 2,
        backgroundColor = { 15, 12, 28, 210 },
        borderRadius = 12,
        borderWidth = 1,
        borderColor = { labelColor[1], labelColor[2], labelColor[3], 60 },
        gap = 4,
        children = {
            -- 图标
            Currency.IconWidget(ctx.UI, currencyId, 16),
            -- 数字
            ctx.UI.Label {
                id = labelId,
                text = "0",
                fontSize = 12,
                fontColor = { labelColor[1], labelColor[2], labelColor[3], 255 },
                minWidth = 36,
            },
            -- "+" 按钮
            ctx.UI.Button {
                text = "+",
                width = 20, height = 20,
                fontSize = 14,
                fontColor = { 255, 255, 255, 200 },
                backgroundColor = { labelColor[1], labelColor[2], labelColor[3], 80 },
                borderRadius = 10,
                paddingLeft = 0, paddingRight = 0,
                paddingTop = 0, paddingBottom = 0,
                justifyContent = "center",
                alignItems = "center",
                onClick = function()
                    GameUI.ShowResourceShop(currencyId)
                end,
            },
        },
    }
end

--- 右上货币显示面板
function GameUI.CreateCurrencyDisplay()
    return ctx.UI.Panel {
        id = "currencyDisplay",
        position = "absolute",
        right = 8, top = "30%",
        flexDirection = "column",
        alignItems = "flex-end",
        gap = 4,
        children = {
            -- 退出副本按钮（仅副本模式显示）
            ctx.UI.Button {
                id = "exitDungeonBtn",
                text = "退出",
                fontSize = 11,
                variant = "outline",
                height = 26,
                paddingLeft = 10, paddingRight = 10,
                visible = false,
                onClick = function(self)
                    GameUI.ExitDungeonBattle()
                end,
            },
            GameUI.CurrencyPill("nether_crystal", "hudCrystalLabel", { 160, 100, 230 }),
            GameUI.CurrencyPill("shadow_essence", "hudEssenceLabel", { 180, 140, 255 }),
        },
    }
end

--- 资源商店弹窗
function GameUI.ShowResourceShop(focusCurrency)
    -- 如果已显示则关闭
    local existing = ctx.uiRoot and ctx.uiRoot:FindById("resourceShopOverlay")
    if existing then
        existing:Remove()
        return
    end
    if not ctx.uiRoot then return end

    local shopItems = {
        { id = "nether_crystal", name = "冥晶",   color = { 160, 100, 230 }, desc = "升级英雄等级",
          sources = { "击杀怪物掉落", "挂机离线收益", "开启朽木宝箱", "活动奖励" } },
        { id = "shadow_essence", name = "暗影精粹", color = { 180, 140, 255 }, desc = "兑换高级道具",
          sources = { "开启钻石宝箱", "积分里程碑奖励", "活动奖励" } },
        { id = "devour_stone",   name = "噬魂石",  color = { 60, 160, 80 },   desc = "英雄进阶",
          sources = { "击杀精英/BOSS", "挂机离线收益", "开启青铜/黄金/铂金宝箱" } },
        { id = "forge_iron",     name = "锻魂铁",  color = { 130, 160, 200 }, desc = "打造装备",
          sources = { "击杀BOSS掉落", "挂机离线收益" } },
        { id = "void_pact",      name = "虚空契约", color = { 200, 40, 40 },   desc = "招募英雄",
          sources = { "通关结算奖励", "积分里程碑奖励" } },
    }

    local itemChildren = {}
    for _, item in ipairs(shopItems) do
        local amount = Currency.Get(item.id)
        -- 来源文字
        local srcTexts = {}
        for i, s in ipairs(item.sources) do
            srcTexts[#srcTexts + 1] = ctx.UI.Label {
                text = "· " .. s,
                fontSize = 10,
                fontColor = { 180, 170, 200, 180 },
            }
        end

        itemChildren[#itemChildren + 1] = ctx.UI.Panel {
            flexDirection = "row",
            alignItems = "center",
            gap = 8,
            paddingLeft = 12, paddingRight = 12,
            paddingTop = 8, paddingBottom = 8,
            backgroundColor = (focusCurrency == item.id)
                and { item.color[1], item.color[2], item.color[3], 30 }
                or { 30, 24, 50, 180 },
            borderRadius = 8,
            borderWidth = (focusCurrency == item.id) and 1 or 0,
            borderColor = { item.color[1], item.color[2], item.color[3], 100 },
            children = {
                -- 图标
                Currency.IconWidget(ctx.UI, item.id, 28),
                -- 信息列
                ctx.UI.Panel {
                    flexDirection = "column",
                    flexGrow = 1,
                    flexShrink = 1,
                    gap = 2,
                    children = {
                        -- 名称 + 数量
                        ctx.UI.Panel {
                            flexDirection = "row",
                            alignItems = "center",
                            gap = 6,
                            children = {
                                ctx.UI.Label {
                                    text = item.name,
                                    fontSize = 13,
                                    fontColor = { item.color[1], item.color[2], item.color[3], 255 },
                                    fontWeight = "bold",
                                },
                                ctx.UI.Label {
                                    text = FormatNum(amount),
                                    fontSize = 12,
                                    fontColor = { 220, 210, 240, 255 },
                                },
                            },
                        },
                        -- 用途
                        ctx.UI.Label {
                            text = item.desc,
                            fontSize = 10,
                            fontColor = { 140, 130, 170, 200 },
                        },
                        -- 获取途径
                        ctx.UI.Panel {
                            flexDirection = "column",
                            gap = 1,
                            marginTop = 2,
                            children = srcTexts,
                        },
                    },
                },
            },
        }
    end

    local overlay = ctx.UI.Panel {
        id = "resourceShopOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 160 },
        onClick = function(self)
            self:Remove()
        end,
        children = {
            ctx.UI.Panel {
                width = 280,
                maxHeight = "80%",
                backgroundColor = { 25, 20, 45, 245 },
                borderRadius = 12,
                borderWidth = 1,
                borderColor = { 100, 70, 180, 120 },
                paddingTop = 12, paddingBottom = 12,
                onClick = function() end,  -- 阻止冒泡关闭
                children = {
                    -- 标题
                    ctx.UI.Label {
                        text = "资源总览",
                        fontSize = 16,
                        fontColor = { 220, 200, 255, 255 },
                        fontWeight = "bold",
                        textAlign = "center",
                        marginBottom = 10,
                        alignSelf = "center",
                    },
                    -- 资源列表
                    ctx.UI.Panel {
                        flexDirection = "column",
                        gap = 6,
                        paddingLeft = 8, paddingRight = 8,
                        children = itemChildren,
                    },
                    -- 关闭提示
                    ctx.UI.Label {
                        text = "点击空白处关闭",
                        fontSize = 10,
                        fontColor = { 120, 110, 150, 150 },
                        textAlign = "center",
                        marginTop = 10,
                        alignSelf = "center",
                    },
                },
            },
        },
    }

    ctx.uiRoot:AddChild(overlay)
end

--- 品质颜色（挂到 ctx 供其他子模块共享）
local RARITY_COLORS = {
    LR  = { 255, 80, 80, 200 },
    UR  = { 255, 200, 50, 200 },
    SSR = { 180, 100, 255, 200 },
    SR  = { 80, 150, 255, 200 },
    R   = { 100, 200, 100, 200 },
    N   = { 160, 150, 140, 200 },
}
ctx.RARITY_COLORS = RARITY_COLORS

--- 格式化数字

end
