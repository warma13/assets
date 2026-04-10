-- ============================================================================
-- state/equip/Upgrade.lua — 装备改造: 升级, IP注入, 附魔
-- v4.1: 升级仅提升主属性, 每5级随机一条词缀+2%, IP不变
-- ============================================================================

local M = {}

---@param GS table GameState
---@param ctx table { Config, calcItemPower }
function M.Install(GS, ctx)
    local Config        = ctx.Config
    local calcItemPower = ctx.calcItemPower

    -- ====================================================================
    -- 升级 (v4.1: 仅提升主属性, 每5级随机一条词缀+2%)
    -- ====================================================================

    function GS.CanUpgradeEquip(item)
        if not item then return false, "无装备" end
        local q = Config.EQUIP_QUALITY[item.qualityIdx]
        if not q then return false, "品质异常" end
        local maxLv = q.maxUpgrade or 0
        if maxLv <= 0 then return false, "白色装备无法升级" end
        local curLv = item.upgradeLv or 0
        if curLv >= maxLv then return false, "已满级" end
        local cost = Config.UpgradeCost(curLv, 1)
        if GS.materials.stone < cost then
            return false, "强化石不足 (" .. GS.materials.stone .. "/" .. cost .. ")"
        end
        return true, nil
    end

    function GS.UpgradeEquip(slotId)
        local item = GS.equipment[slotId]
        local ok, reason = GS.CanUpgradeEquip(item)
        if not ok then return false, reason end

        local curLv = item.upgradeLv or 0
        local cost = Config.UpgradeCost(curLv, 1)

        GS.materials.stone = GS.materials.stone - cost
        item.upgradeStonesSpent = (item.upgradeStonesSpent or 0) + cost

        curLv = curLv + 1
        item.upgradeLv = curLv
        -- v4.0: IP 不再改变

        -- 主属性用 CalcMainStatValueFull (含升级加成)
        if item.mainStatBase then
            item.mainStatValue = Config.CalcMainStatValueFull(item.mainStatBase, item.itemPower or 100, curLv)
        end

        -- 词缀里程碑: 每5级随机选一条词缀 +2%
        if curLv % Config.UPGRADE_AFFIX_MILESTONE_INTERVAL == 0 and item.affixes and #item.affixes > 0 then
            local idx = math.random(1, #item.affixes)
            local aff = item.affixes[idx]
            if not aff.baseValue then aff.baseValue = aff.value end
            aff.milestoneCount = (aff.milestoneCount or 0) + 1
            aff.value = aff.baseValue * Config.CalcAffixMilestoneMul(aff.milestoneCount)
            print("[Upgrade] 里程碑 Lv." .. curLv .. " → 词缀 #" .. idx .. " (" .. (aff.id or "?") .. ") +2%, 累计 " .. aff.milestoneCount .. " 次")
        end

        print("[Upgrade] " .. (item.name or "?") .. " → Lv." .. curLv .. " (消耗 " .. cost .. " 强化石)")
        local ok2, DR = pcall(require, "DailyRewards")
        if ok2 and DR and DR.TrackProgress then DR.TrackProgress("enhance", 1) end
        return true, "升级到 Lv." .. curLv
    end

    -- ====================================================================
    -- IP 注入 (取代旧 TierUpgrade)
    -- ====================================================================

    function GS.CanInfuseEquip(item)
        if not item then return false, "无装备" end
        if item.qualityIdx < 3 then return false, "蓝色品质以上才能注入" end
        local maxCh = GS.records and GS.records.maxChapter or 1
        local curIP = item.itemPower or 100
        local newIP = calcItemPower(maxCh, item.qualityIdx)
        if newIP <= curIP then return false, "IP 已是当前章节最高" end
        return true, nil
    end

    function GS.InfuseEquip(slotId, stoneItemId)
        local item = GS.equipment[slotId]
        if not item then return false, "槽位无装备" end

        local cfg = Config.ITEM_MAP[stoneItemId]
        if not cfg or not cfg.isMagicStone then return false, "无效的魔法石" end

        local maxCh = GS.records and GS.records.maxChapter or 1
        local targetChapter = cfg.isTopMagicStone and maxCh or cfg.targetTier

        local canInf, reason = GS.CanInfuseEquip(item)
        if not canInf then return false, reason end

        local count = GS.GetBagItemCount(stoneItemId)
        if count <= 0 then return false, "魔法石不足" end

        local oldIP = item.itemPower or 100
        local newIP = calcItemPower(targetChapter, item.qualityIdx)
        if newIP <= oldIP then return false, "IP 已达到或超过目标" end

        if item.affixes then
            for _, aff in ipairs(item.affixes) do
                local def = Config.AFFIX_POOL_MAP[aff.id]
                if def then
                    local oldFactor = 1 + (oldIP / 100 - 1) * def.ipScale
                    local newFactor = 1 + (newIP / 100 - 1) * def.ipScale
                    if oldFactor > 0 then
                        local ratio = newFactor / oldFactor
                        aff.value = aff.value * ratio
                        if aff.baseValue then aff.baseValue = aff.baseValue * ratio end
                    end
                end
            end
        end

        item.itemPower = newIP

        -- 主属性用 CalcMainStatValueFull (含升级加成)
        if item.mainStatBase then
            item.mainStatValue = Config.CalcMainStatValueFull(item.mainStatBase, newIP, item.upgradeLv or 0)
        end

        GS.DiscardBagItem(stoneItemId, 1)

        local SaveSystem = require("SaveSystem")
        SaveSystem.MarkDirty()

        print("[InfuseEquip] " .. (item.name or "?") .. " IP " .. oldIP .. " → " .. newIP)
        return true, "IP " .. oldIP .. " → " .. newIP .. " 注入成功!"
    end

    function GS.PreviewInfuse(item, targetChapter)
        if not item then return nil end
        local oldIP = item.itemPower or 100
        local newIP = calcItemPower(targetChapter or 1, item.qualityIdx)
        if newIP <= oldIP then return nil end

        local preview = { itemPower = newIP, affixes = {} }
        -- 主属性预览 (含升级加成)
        if item.mainStatBase then
            preview.mainStatValue = Config.CalcMainStatValueFull(item.mainStatBase, newIP, item.upgradeLv or 0)
        end
        if item.affixes then
            for i, aff in ipairs(item.affixes) do
                local def = Config.AFFIX_POOL_MAP[aff.id]
                if def then
                    local oldFactor = 1 + (oldIP / 100 - 1) * def.ipScale
                    local newFactor = 1 + (newIP / 100 - 1) * def.ipScale
                    local ratio = (oldFactor > 0) and (newFactor / oldFactor) or 1
                    preview.affixes[i] = { id = aff.id, value = aff.value * ratio, greater = aff.greater }
                else
                    preview.affixes[i] = { id = aff.id, value = aff.value, greater = aff.greater }
                end
            end
        end
        return preview
    end

    -- 兼容别名
    GS.TierUpgradeEquip = GS.InfuseEquip
    GS.CanTierUpgrade = function(item, _targetTier) return GS.CanInfuseEquip(item) end
    GS.PreviewTierUpgrade = function(item, targetTier) return GS.PreviewInfuse(item, targetTier) end

    function GS.GetAvailableMagicStones(item)
        local result = {}
        local maxCh = GS.records and GS.records.maxChapter or 1
        local curIP = item and item.itemPower or 100
        local qualityOk = item and item.qualityIdx >= 3
        local bag = GS.bag or {}

        for itemId, bagCount in pairs(bag) do
            if bagCount > 0 then
                local itemCfg = Config.ITEM_MAP[itemId]
                if itemCfg and itemCfg.isMagicStone then
                    local tCh = itemCfg.isTopMagicStone and maxCh or itemCfg.targetTier
                    local targetIP = calcItemPower(tCh, item and item.qualityIdx or 1)
                    local canUse = qualityOk and targetIP > curIP
                    local reasonStr = nil
                    if not qualityOk then
                        reasonStr = "蓝色品质以上才能使用"
                    elseif targetIP <= curIP then
                        reasonStr = "IP 已达到或超过目标"
                    end
                    table.insert(result, {
                        itemId = itemCfg.id,
                        name = itemCfg.isTopMagicStone and ("顶级魔法石→IP" .. targetIP) or itemCfg.name,
                        count = bagCount, targetTier = tCh,
                        canUse = canUse, reason = reasonStr, color = itemCfg.color,
                    })
                end
            end
        end
        table.sort(result, function(a, b) return a.targetTier > b.targetTier end)
        return result
    end

    -- ====================================================================
    -- 附魔 (洗词缀)
    -- ====================================================================

    function GS.EnchantAffix(slotId, affixIndex)
        local item = GS.equipment[slotId]
        if not item then return false, "槽位无装备" end
        if item.qualityIdx < 4 then return false, "紫色品质以上才能附魔" end
        if not item.affixes or affixIndex < 1 or affixIndex > #item.affixes then
            return false, "无效的词缀索引"
        end

        local ip = item.itemPower or 100
        local qMul = Config.ENCHANT_COST.qualityMul[item.qualityIdx] or 1
        local cost = math.floor((Config.ENCHANT_COST.baseCost + ip * Config.ENCHANT_COST.ipMul) * qMul)
        local curSC = GS.GetSoulCrystal()
        if curSC < cost then
            return false, "魂晶不足 (" .. curSC .. "/" .. cost .. ")"
        end

        GS.materials.soulCrystal = GS.materials.soulCrystal - cost

        local existingIds = {}
        for i, aff in ipairs(item.affixes) do
            if i ~= affixIndex then existingIds[aff.id] = true end
        end

        local pool = Config.AFFIX_SLOT_POOLS[item.slot] or {}
        local candidates = {}
        for _, affId in ipairs(pool) do
            if not existingIds[affId] then table.insert(candidates, affId) end
        end

        if #candidates == 0 then
            GS.materials.soulCrystal = GS.materials.soulCrystal + cost
            return false, "该槽位无其他可选词缀"
        end

        local newAffId = candidates[math.random(1, #candidates)]
        local def = Config.AFFIX_POOL_MAP[newAffId]

        local minRoll, maxRoll = Config.GetIPBracket(ip)
        local roll = minRoll + math.random() * (maxRoll - minRoll)
        local value = Config.CalcAffixValue(def, ip, roll)

        local oldAff = item.affixes[affixIndex]
        local isGreater = oldAff.greater
        if isGreater then value = value * 1.5 end

        -- v4.1: 附魔替换词缀, 里程碑计数归零 (新词缀无积累)
        item.affixes[affixIndex] = {
            id = newAffId, value = value, greater = isGreater or nil,
            baseValue = value,       -- 基础值 (不含里程碑)
            milestoneCount = 0,      -- 新词缀无里程碑
        }

        local SaveSystem = require("SaveSystem")
        SaveSystem.MarkDirty()

        print("[Enchant] " .. (item.name or "?") .. " 词缀 #" .. affixIndex
            .. " → " .. (def.name or newAffId) .. " (消耗 " .. cost .. " 魂晶)")
        return true, "附魔成功: " .. (def.name or newAffId)
    end
end

return M
