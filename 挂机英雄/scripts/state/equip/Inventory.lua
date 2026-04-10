-- ============================================================================
-- state/equip/Inventory.lua — 背包操作: 穿戴, 排序, 锁定, 分解
-- ============================================================================

local M = {}

---@param GS table GameState
---@param ctx table { Config }
function M.Install(GS, ctx)
    local Config = ctx.Config

    function GS.AddToInventory(item)
        -- 自动分解
        local activeLevel, activeMode = 0, 0
        for k = #GS.autoDecompConfig, 1, -1 do
            if GS.autoDecompConfig[k] > 0 then
                activeLevel = k
                activeMode = GS.autoDecompConfig[k]
                break
            end
        end
        if activeLevel > 0 and item.qualityIdx and item.qualityIdx <= activeLevel
            and not item.locked and (activeMode == 1 or not (item.setId and item.qualityIdx == activeLevel)) then
            if item.qualityIdx == 1 then
                GS.AddGold(1)
            end
            local stones = Config.DECOMPOSE_STONES[item.qualityIdx] or 1
            GS.AddStone(stones)
            return true
        end
        if #GS.inventory >= GS.GetInventorySize() then
            return false
        end
        table.insert(GS.inventory, item)
        return true
    end

    function GS.EquipItem(invIndex)
        local item = GS.inventory[invIndex]
        if not item then return false end
        local old = GS.equipment[item.slot]
        GS.equipment[item.slot] = item
        table.remove(GS.inventory, invIndex)
        if old then
            table.insert(GS.inventory, old)
        end
        return true
    end

    function GS.SortInventoryBySet()
        local slotOrder = {}
        for i, slot in ipairs(Config.EQUIP_SLOTS) do
            slotOrder[slot.id] = i
        end
        table.sort(GS.inventory, function(a, b)
            local sA = a.setId or ""
            local sB = b.setId or ""
            if sA ~= sB then return sA < sB end
            local sa = slotOrder[a.slot] or 99
            local sb = slotOrder[b.slot] or 99
            if sa ~= sb then return sa < sb end
            if a.qualityIdx ~= b.qualityIdx then return a.qualityIdx > b.qualityIdx end
            return (a.itemPower or 0) > (b.itemPower or 0)
        end)
    end

    function GS.SortInventory()
        local slotOrder = {}
        for i, slot in ipairs(Config.EQUIP_SLOTS) do
            slotOrder[slot.id] = i
        end
        table.sort(GS.inventory, function(a, b)
            local sa = slotOrder[a.slot] or 99
            local sb = slotOrder[b.slot] or 99
            if sa ~= sb then return sa < sb end
            if a.qualityIdx ~= b.qualityIdx then return a.qualityIdx > b.qualityIdx end
            local ipA = a.itemPower or 0
            local ipB = b.itemPower or 0
            if ipA ~= ipB then return ipA > ipB end
            local sA = a.setId or ""
            local sB = b.setId or ""
            return sA < sB
        end)
    end

    function GS.AutoEquipBest()
        local changed = false
        for _, slotCfg in ipairs(Config.EQUIP_SLOTS) do
            local bestIdx = nil
            local cur = GS.equipment[slotCfg.id]
            local bestIP = cur and (cur.itemPower or 0) or 0
            for i, item in ipairs(GS.inventory) do
                if item.slot == slotCfg.id then
                    local ip = item.itemPower or 0
                    if ip > bestIP then
                        bestIP = ip
                        bestIdx = i
                    end
                end
            end
            if bestIdx then
                GS.EquipItem(bestIdx)
                changed = true
            end
        end
        return changed
    end

    function GS.ToggleLock(invIndex)
        local item = GS.inventory[invIndex]
        if not item then return end
        item.locked = not item.locked
    end

    function GS.ToggleEquipLock(slotId)
        local item = GS.equipment[slotId]
        if not item then return end
        item.locked = not item.locked
    end

    function GS.DecomposeItem(invIndex)
        local item = GS.inventory[invIndex]
        if not item then return 0, 0 end
        if item.locked then return 0, 0 end
        local gold = 0
        if item.qualityIdx == 1 then gold = 1 end
        local stones = Config.DECOMPOSE_STONES[item.qualityIdx] or 1
        local spent = item.upgradeStonesSpent or 0
        if spent > 0 then
            stones = stones + math.floor(spent * Config.UPGRADE_REFUND_RATIO)
        end
        table.remove(GS.inventory, invIndex)
        if gold > 0 then GS.AddGold(gold) end
        GS.AddStone(stones)
        return gold, stones
    end

    function GS.DecomposeAllWhite()
        local totalGold, totalStones = 0, 0
        for i = #GS.inventory, 1, -1 do
            if GS.inventory[i].qualityIdx == 1 then
                local g, s = GS.DecomposeItem(i)
                totalGold = totalGold + g
                totalStones = totalStones + s
            end
        end
        return totalGold, totalStones
    end

    function GS.DecomposeByFilter(maxQuality, keepSets)
        local totalGold = 0
        local totalStones = 0
        local count = 0
        for i = #GS.inventory, 1, -1 do
            local item = GS.inventory[i]
            if item.qualityIdx <= maxQuality then
                if not item.locked and not (keepSets and item.setId) then
                    local g, s = GS.DecomposeItem(i)
                    totalGold = totalGold + g
                    totalStones = totalStones + s
                    count = count + 1
                end
            end
        end
        return totalGold, count, totalStones
    end
end

return M
