-- Game/InventoryUI.lua
-- 仓库弹窗 UI：3列网格，可滚动，底部固定选中物品详情+使用按钮

local InventoryData  = require("Game.InventoryData")
local Currency       = require("Game.Currency")
local RewardIcon     = require("Game.RewardIcon")
local RewardDisplay  = require("Game.RewardDisplay")

local InventoryUI = {}

-- ============================================================================
-- 配色（与 HeroUI 暗色系一致）
-- ============================================================================
local S = {
    overlayBg   = { 0, 0, 0, 180 },
    popupBg     = { 42, 30, 22, 250 },
    popupBorder = { 90, 70, 50, 200 },
    white       = { 245, 238, 225, 255 },
    dim         = { 170, 155, 135, 200 },
    gold        = { 255, 215, 80, 255 },
    cardBg      = { 55, 42, 32, 240 },
    cardBorder  = { 80, 62, 44, 120 },
    selectedBorder = { 255, 200, 80, 255 },
    emptyText   = { 130, 120, 110, 160 },
    btnUse      = { 75, 165, 55, 255 },
    btnUseBorder = { 100, 200, 75, 200 },
    btnDisabled = { 65, 58, 48, 220 },
    detailBg    = { 35, 26, 18, 240 },
    detailBorder = { 75, 55, 38, 120 },
}

--- 稀有度边框颜色
local RARITY_COLORS = {
    UR  = { 200, 150, 30, 255 },
    SSR = { 150, 55, 190, 255 },
    SR  = { 45, 115, 195, 255 },
    R   = { 80, 160, 60, 255 },
    N   = { 140, 130, 120, 200 },
}

-- ============================================================================
-- 状态
-- ============================================================================

---@type any
local UI = nil
---@type any
local overlay = nil
---@type any
local contentContainer = nil
---@type string|nil
local selectedItemId = nil
---@type any
local detailContainer = nil
---@type fun()|nil
local onCloseCallback = nil

-- ============================================================================
-- 内部：创建单个物品格子
-- ============================================================================

---@param item table {id, count, def}
---@param isSelected boolean
local function CreateItemCell(item, isSelected)
    local def = item.def
    local rarityCol = RARITY_COLORS[def.rarity] or RARITY_COLORS.N
    local borderCol = isSelected and S.selectedBorder or rarityCol

    return UI.Panel {
        flexGrow = 1,
        flexBasis = 0,
        aspectRatio = 1.0,
        backgroundColor = S.cardBg,
        borderRadius = 6,
        borderWidth = isSelected and 2.5 or 1.5,
        borderColor = borderCol,
        justifyContent = "center",
        alignItems = "center",
        children = {
            -- 物品图标（铺满 + 右下角数量）
            RewardIcon.Create(UI, "100%", def.icon, item.count, {
                label = def.name,
                desc = def.desc or "",
            }),
            -- 稀有度标签（左上）
            UI.Panel {
                position = "absolute",
                top = 2, left = 2,
                paddingLeft = 3, paddingRight = 3,
                paddingTop = 1, paddingBottom = 1,
                borderRadius = 3,
                backgroundColor = { rarityCol[1], rarityCol[2], rarityCol[3], 160 },
                children = {
                    UI.Label {
                        text = def.rarity,
                        fontSize = 7,
                        fontColor = { 255, 255, 255, 240 },
                        fontWeight = "bold",
                    },
                },
            },
            -- 点击遮罩（覆盖在 RewardIcon 上方，拦截点击用于选中）
            UI.Panel {
                position = "absolute",
                top = 0, left = 0, right = 0, bottom = 0,
                borderRadius = 6,
                onClick = function(self)
                    selectedItemId = item.id
                    RefreshInventoryContent()
                end,
            },
        },
    }
end

--- 创建空白占位格（保持3列对齐）
local function CreateEmptyCell()
    return UI.Panel {
        flexGrow = 1,
        flexBasis = 0,
        aspectRatio = 1.0,
    }
end

-- ============================================================================
-- 底部详情栏
-- ============================================================================

---@param item table|nil {id, count, def}
local function CreateDetailBar(item)
    if not item then
        return UI.Panel {
            width = "100%",
            height = 56,
            justifyContent = "center",
            alignItems = "center",
            backgroundColor = S.detailBg,
            borderTopWidth = 1,
            borderTopColor = S.detailBorder,
            children = {
                UI.Label {
                    text = "点击物品查看详情",
                    fontSize = 12,
                    fontColor = S.emptyText,
                },
            },
        }
    end

    local def = item.def
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        paddingTop = 8, paddingBottom = 8,
        paddingLeft = 10, paddingRight = 10,
        backgroundColor = S.detailBg,
        borderTopWidth = 1,
        borderTopColor = S.detailBorder,
        gap = 8,
        flexShrink = 0,
        children = {
            -- 图标
            Currency.IconWidget(UI, def.icon, 32),
            -- 名称 + 描述
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                gap = 2,
                children = {
                    UI.Label {
                        text = def.name .. " ×" .. item.count,
                        fontSize = 12,
                        fontColor = S.white,
                        fontWeight = "bold",
                    },
                    UI.Label {
                        text = def.desc,
                        fontSize = 10,
                        fontColor = S.dim,
                    },
                },
            },
            -- 使用按钮（仅礼包类有 use 函数时显示）
            def.use and UI.Panel {
                paddingLeft = 14, paddingRight = 14,
                paddingTop = 7, paddingBottom = 7,
                borderRadius = 8,
                backgroundColor = S.btnUse,
                borderWidth = 1,
                borderColor = S.btnUseBorder,
                flexShrink = 0,
                onClick = function(self)
                    local ok, msg, rewards = InventoryData.Use(item.id, 1)
                    if not ok then
                        print("[InventoryUI] Use failed: " .. (msg or ""))
                        return
                    end
                    -- 使用后如果数量归零，取消选中
                    if InventoryData.GetCount(item.id) <= 0 then
                        selectedItemId = nil
                    end
                    if rewards and #rewards > 0 then
                        RewardDisplay.Show(UI, overlay, {
                            title = "使用 " .. def.name,
                            rewards = rewards,
                            onClose = function()
                                RefreshInventoryContent()
                            end,
                        })
                    else
                        RefreshInventoryContent()
                    end
                end,
                children = {
                    UI.Label {
                        text = "使用",
                        fontSize = 13,
                        fontColor = { 255, 255, 255, 255 },
                        fontWeight = "bold",
                    },
                },
            } or nil,
        },
    }
end

-- ============================================================================
-- 刷新仓库内容
-- ============================================================================

function RefreshInventoryContent()
    if not contentContainer then return end
    contentContainer:ClearChildren()

    -- 确保数据已加载
    if not InventoryData.items then
        InventoryData.Load()
    end

    local allItems = InventoryData.GetAll()

    -- 标题栏
    contentContainer:AddChild(UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        paddingTop = 6, paddingBottom = 6,
        flexShrink = 0,
        children = {
            UI.Label {
                text = "仓库",
                fontSize = 16,
                fontColor = S.white,
                fontWeight = "bold",
            },
        },
    })

    if #allItems == 0 then
        -- 空仓库
        contentContainer:AddChild(UI.Panel {
            flexGrow = 1,
            width = "100%",
            justifyContent = "center",
            alignItems = "center",
            children = {
                UI.Label {
                    text = "仓库空空如也",
                    fontSize = 14,
                    fontColor = S.emptyText,
                },
                UI.Label {
                    text = "通过每日特惠获取物品",
                    fontSize = 11,
                    fontColor = S.emptyText,
                    marginTop = 4,
                },
            },
        })
    else
        -- 分类：可使用的礼包 vs 不可使用的材料
        local usableItems = {}
        local materialItems = {}
        for _, item in ipairs(allItems) do
            if item.def.use then
                usableItems[#usableItems + 1] = item
            else
                materialItems[#materialItems + 1] = item
            end
        end

        --- 构建一个分类的3列网格行列表
        ---@param items table[]
        ---@return table[] rows, table|nil selectedItem
        local function BuildGrid(items)
            local rows = {}
            local selItem = nil
            for i = 1, #items, 3 do
                local rowChildren = {}
                for j = 0, 2 do
                    local item = items[i + j]
                    if item then
                        local isSelected = (item.id == selectedItemId)
                        if isSelected then selItem = item end
                        rowChildren[#rowChildren + 1] = CreateItemCell(item, isSelected)
                    else
                        rowChildren[#rowChildren + 1] = CreateEmptyCell()
                    end
                end
                rows[#rows + 1] = UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    gap = 6,
                    children = rowChildren,
                }
            end
            return rows, selItem
        end

        --- 创建分区标题
        ---@param text string
        ---@param icon string|nil
        ---@return any
        local function SectionHeader(text, icon)
            local headerChildren = {}
            if icon then
                headerChildren[#headerChildren + 1] = UI.Label {
                    text = icon,
                    fontSize = 13,
                }
            end
            headerChildren[#headerChildren + 1] = UI.Label {
                text = text,
                fontSize = 13,
                fontColor = S.gold,
                fontWeight = "bold",
            }
            headerChildren[#headerChildren + 1] = UI.Panel {
                flex = 1, height = 1,
                backgroundColor = { 80, 60, 45, 80 },
                marginLeft = 4,
            }
            return UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                gap = 6,
                paddingTop = 8, paddingBottom = 4,
                children = headerChildren,
            }
        end

        local scrollChildren = {}
        local selectedItem = nil

        -- 礼包区
        if #usableItems > 0 then
            scrollChildren[#scrollChildren + 1] = SectionHeader("道具")
            local rows, selItem = BuildGrid(usableItems)
            if selItem then selectedItem = selItem end
            for _, row in ipairs(rows) do
                scrollChildren[#scrollChildren + 1] = row
            end
        end

        -- 材料区
        if #materialItems > 0 then
            scrollChildren[#scrollChildren + 1] = SectionHeader("材料", "🔮")
            local rows, selItem = BuildGrid(materialItems)
            if selItem then selectedItem = selItem end
            for _, row in ipairs(rows) do
                scrollChildren[#scrollChildren + 1] = row
            end
        end

        -- 如果 selectedItemId 有值但物品已用完，清除选中
        if selectedItemId and not selectedItem then
            selectedItemId = nil
        end

        contentContainer:AddChild(UI.ScrollView {
            flexGrow = 1, flexBasis = 0,
            scrollY = true,
            width = "100%",
            children = {
                UI.Panel {
                    width = "100%",
                    paddingTop = 4, paddingBottom = 10,
                    paddingLeft = 10, paddingRight = 10,
                    gap = 6,
                    children = scrollChildren,
                },
            },
        })

        -- 底部详情栏
        contentContainer:AddChild(CreateDetailBar(selectedItem))
    end
end

-- ============================================================================
-- 公开接口
-- ============================================================================

--- 显示仓库弹窗
---@param uiModule any  UI 模块引用
---@param parentNode any  父节点（通常是 pageRoot）
---@param onClose? fun()  关闭回调
function InventoryUI.Show(uiModule, parentNode, onClose)
    UI = uiModule
    onCloseCallback = onClose

    if overlay then
        RefreshInventoryContent()
        return
    end

    -- 确保数据已加载
    InventoryData.Load()
    selectedItemId = nil

    -- 内容容器
    contentContainer = UI.Panel {
        flexGrow = 1, flexShrink = 1,
        width = "100%",
        flexDirection = "column",
    }

    -- 弹窗面板
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
            contentContainer,
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
                            InventoryUI.Hide(parentNode)
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

    -- 遮罩
    overlay = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 100,
        backgroundColor = S.overlayBg,
        children = { popup },
    }

    RefreshInventoryContent()
    parentNode:AddChild(overlay)
end

--- 隐藏仓库弹窗
---@param parentNode any
function InventoryUI.Hide(parentNode)
    if overlay then
        parentNode:RemoveChild(overlay)
        overlay = nil
        contentContainer = nil
        selectedItemId = nil
        if onCloseCallback then
            onCloseCallback()
        end
    end
end

--- 仓库是否正在显示
---@return boolean
function InventoryUI.IsVisible()
    return overlay ~= nil
end

return InventoryUI
