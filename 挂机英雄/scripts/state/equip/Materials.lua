-- ============================================================================
-- state/equip/Materials.lua — 材料管理 & 背包容量
-- ============================================================================

local M = {}

---@param GS table GameState
---@param ctx table { Config }
function M.Install(GS, ctx)
    local Config = ctx.Config

    function GS.AddStone(amount)
        GS.materials.stone = GS.materials.stone + amount
    end

    function GS.GetStone()
        return GS.materials.stone
    end

    function GS.AddSoulCrystal(amount)
        GS.materials.soulCrystal = GS.materials.soulCrystal + (amount or 1)
    end

    function GS.GetSoulCrystal()
        return GS.materials.soulCrystal or 0
    end

    function GS.GetInventorySize()
        return Config.INVENTORY_SIZE + (GS.expandCount or 0) * Config.INVENTORY_EXPAND_SLOTS
    end

    function GS.GetExpandCost()
        local n = (GS.expandCount or 0) + 1
        return Config.EXPAND_BASE_COST + (n - 1) * Config.EXPAND_COST_INCREMENT
    end

    function GS.ExpandInventory()
        local curSize = GS.GetInventorySize()
        if curSize >= Config.INVENTORY_MAX_SIZE then
            return false, "背包已达上限 " .. Config.INVENTORY_MAX_SIZE .. " 格"
        end
        local cost = GS.GetExpandCost()
        local cur = GS.GetSoulCrystal()
        if cur < cost then
            return false, "魂晶不足 (" .. cur .. "/" .. cost .. ")"
        end
        GS.materials.soulCrystal = GS.materials.soulCrystal - cost
        GS.expandCount = (GS.expandCount or 0) + 1
        print("[GameState] Inventory expanded to " .. GS.GetInventorySize() .. " slots (cost " .. cost .. " soul crystals)")
        return true, nil
    end
end

return M
