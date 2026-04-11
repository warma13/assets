-- Game/Tooltip.lua
-- 通用浮窗组件，可在任意页面复用
--
-- 用法:
--   local Tooltip = require("Game.Tooltip")
--   Tooltip.Init(UI, pageRoot)
--   Tooltip.Show({ title = "物品名", desc = "描述文字", anchor = widget })
--   Tooltip.Hide()

local Tooltip = {}

---@type any UI 模块引用
local UI = nil
---@type any 浮窗容器（absolute 全屏遮罩）
local panel = nil

-- 样式
local STYLE = {
    bg        = { 20, 16, 38, 230 },
    border    = { 120, 90, 180, 180 },
    titleColor = { 255, 220, 100, 255 },
    descColor  = { 190, 180, 210, 220 },
    dismissBg  = { 0, 0, 0, 1 },
    radius     = 10,
    padding    = 10,
    gap        = 4,
    width      = 160,
    height     = 64,
    margin     = 8,   -- 距屏幕边缘最小间距
    spacing    = 6,    -- 距 anchor 间距
}

--- 初始化：创建浮窗层并挂到父容器上
--- 每次页面重建时调用一次
---@param uiModule any  UI 模块引用
---@param parent any    父容器（通常是 pageRoot，需 position=absolute 或 relative）
---@return any panel    浮窗层引用（方便外部管理生命周期）
function Tooltip.Init(uiModule, parent)
    UI = uiModule
    panel = UI.Panel {
        id = "tooltipLayer",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        visible = false,
    }
    parent:AddChild(panel)
    return panel
end

--- 显示浮窗
---@param opts table { title: string, desc: string, anchor: Widget, titleColor?: table, descColor?: table }
function Tooltip.Show(opts)
    if not panel or not UI then return end
    if not opts or not opts.anchor then return end

    local anchor = opts.anchor
    local title = opts.title or ""
    local desc = opts.desc or ""

    -- 获取 anchor 的绝对布局位置
    local layout = anchor:GetAbsoluteLayoutForHitTest()
    local ax, ay = layout.x, layout.y
    local aw, ah = layout.w, layout.h

    -- 浮窗尺寸
    local tw = STYLE.width
    local th = STYLE.height
    local margin = STYLE.margin
    local spacing = STYLE.spacing

    -- 默认居中于 anchor 上方
    local tx = ax + aw / 2 - tw / 2
    local ty = ay - th - spacing

    -- 边界修正（用 panel 自身布局宽度，与 anchor 坐标系一致）
    local parentLayout = panel:GetAbsoluteLayoutForHitTest()
    local parentW = parentLayout.w
    if tx + tw > parentW - margin then tx = parentW - margin - tw end
    if tx < margin then tx = margin end
    if ty < margin then ty = ay + ah + spacing end  -- 放到下方

    -- 重建内容
    panel:ClearChildren()

    -- 点击遮罩（点任意位置关闭）
    panel:AddChild(UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = STYLE.dismissBg,
        pointerEvents = "auto",
        onClick = function() Tooltip.Hide() end,
    })

    -- 气泡
    panel:AddChild(UI.Panel {
        position = "absolute",
        left = tx,
        top = ty,
        width = tw,
        backgroundColor = STYLE.bg,
        borderRadius = STYLE.radius,
        borderWidth = 1,
        borderColor = STYLE.border,
        paddingLeft = STYLE.padding, paddingRight = STYLE.padding,
        paddingTop = STYLE.padding - 2, paddingBottom = STYLE.padding - 2,
        flexDirection = "column",
        gap = STYLE.gap,
        pointerEvents = "auto",
        children = {
            UI.Label {
                text = title,
                fontSize = 13,
                fontColor = opts.titleColor or STYLE.titleColor,
                fontWeight = "bold",
            },
            desc ~= "" and UI.Label {
                text = desc,
                fontSize = 11,
                fontColor = opts.descColor or STYLE.descColor,
            } or nil,
        },
    })

    panel:SetVisible(true)
end

--- 隐藏浮窗
function Tooltip.Hide()
    if panel then
        panel:SetVisible(false)
    end
end

--- 是否正在显示
---@return boolean
function Tooltip.IsVisible()
    return panel ~= nil and panel:IsVisible()
end

return Tooltip
