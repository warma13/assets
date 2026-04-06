local Equipment = {}

function Equipment.Install(GameState)
    local Config = require("Config")
    local StatDefs = require("state.StatDefs")
    local AffixHelper = require("state.AffixHelper")

    -- ========================================================================
    -- 内部工具
    -- ========================================================================

    --- Fisher-Yates 打乱 array (原地)
    local function shuffle(arr)
        for i = #arr, 2, -1 do
            local j = math.random(1, i)
            arr[i], arr[j] = arr[j], arr[i]
        end
    end

    --- 从 pool 中无重复选取 n 条 (返回新 array)
    local function shuffleSelect(pool, n)
        local copy = {}
        for i, v in ipairs(pool) do copy[i] = v end
        shuffle(copy)
        local result = {}
        for i = 1, math.min(n, #copy) do
            result[i] = copy[i]
        end
        return result
    end

    -- ========================================================================
    -- 孔位生成 (仅橙装)
    -- ========================================================================

    --- 根据 SOCKET_WEIGHTS 加权随机初始孔数
    --- @return number 孔数 (0~3)
    local function rollInitialSockets()
        local weights = Config.SOCKET_WEIGHTS
        local roll = math.random()
        local acc = 0
        for i, w in ipairs(weights) do
            acc = acc + w
            if roll <= acc then return i - 1 end
        end
        return 0
    end

    --- 为橙装添加孔位字段
    local function addSocketsIfOrange(item)
        if item.qualityIdx == 5 then
            item.sockets = rollInitialSockets()
            item.gems = {}
        end
    end

    -- ========================================================================
    -- P2: IP 驱动词缀 Roll
    -- ========================================================================

    --- Roll N 条词缀 (统一词缀系统)
    --- @param slotId string 槽位 ID
    --- @param qualityIdx number 品质索引
    --- @param itemPower number 装备 IP
    --- @return table[] affixes { {id, value, greater}, ... }
    local function rollNewAffixes(slotId, qualityIdx, itemPower)
        local pool = Config.AFFIX_SLOT_POOLS[slotId]
        if not pool then return {} end

        local affixCount = Config.AFFIX_COUNT_BY_QUALITY[qualityIdx] or 1
        local selected = shuffleSelect(pool, affixCount)

        local minRoll, maxRoll = Config.GetIPBracket(itemPower)
        local isOrange = (qualityIdx == 5)

        local affixes = {}
        for _, affId in ipairs(selected) do
            local def = Config.AFFIX_POOL_MAP[affId]
            if def then
                local roll = minRoll + math.random() * (maxRoll - minRoll)
                local value = Config.CalcAffixValue(def, itemPower, roll)
                local isGreater = false
                if isOrange and math.random() < Config.AFFIX_GREATER_CHANCE then
                    value = value * 1.5
                    isGreater = true
                end
                table.insert(affixes, {
                    id = affId,
                    value = value,
                    greater = isGreater or nil,  -- nil 不占存档空间
                })
            end
        end
        return affixes
    end

    --- 计算装备 IP
    --- @param chapter number 章节
    --- @param qualityIdx number 品质索引
    --- @param upgradeLv number|nil 升级等级
    --- @return number itemPower
    local function calcItemPower(chapter, qualityIdx, upgradeLv)
        local baseIP = Config.CalcBaseIP(chapter)
        local qMul = Config.IP_QUALITY_MUL[qualityIdx] or 0.5
        return math.floor(baseIP * qMul) + (upgradeLv or 0) * Config.IP_PER_UPGRADE
    end

    -- ========================================================================
    -- 武器元素 & 套装 & 名称 (共用逻辑)
    -- ========================================================================

    --- 随机武器元素
    local function rollWeaponElement(slotCfg, qualityIdx)
        if not slotCfg.hasElement then return nil end
        local elemWeights = Config.WEAPON_ELEMENT_WEIGHTS[qualityIdx]
        if not elemWeights then return "physical" end
        local elemTotal = 0
        for _, w in pairs(elemWeights) do elemTotal = elemTotal + w end
        local elemRoll = math.random() * elemTotal
        local elemAcc = 0
        for elem, w in pairs(elemWeights) do
            elemAcc = elemAcc + w
            if elemRoll <= elemAcc then return elem end
        end
        return "physical"
    end

    --- 构建装备名称
    local function buildItemName(slotCfg, setId, element)
        local nameParts = { slotCfg.name }
        if setId then
            local setCfg = Config.EQUIP_SET_MAP[setId]
            if setCfg then table.insert(nameParts, 1, setCfg.name) end
        end
        local name = table.concat(nameParts)
        if element and element ~= "physical" then
            local elemName = Config.WEAPON_ELEMENTS.names[element] or ""
            name = name .. "(" .. elemName .. ")"
        end
        return name
    end

    --- 随机套装 (掉落批次限制)
    local function rollSetId(chapter, quality)
        if not quality.canHaveSet then return nil end
        if math.random() >= Config.SET_DROP_CHANCE then return nil end
        local batchStart, batchEnd = Config.GetDropBatch(chapter)
        local available = {}
        for _, s in ipairs(Config.EQUIP_SETS) do
            if not s.retired and Config.IsSetInBatch(s, batchStart, batchEnd) then
                table.insert(available, s.id)
            end
        end
        if #available == 0 then return nil end
        return available[math.random(1, #available)]
    end

    -- ========================================================================
    -- 材料系统
    -- ========================================================================

    function GameState.AddStone(amount)
        GameState.materials.stone = GameState.materials.stone + amount
    end

    function GameState.GetStone()
        return GameState.materials.stone
    end

    function GameState.AddSoulCrystal(amount)
        GameState.materials.soulCrystal = GameState.materials.soulCrystal + (amount or 1)
    end

    function GameState.GetSoulCrystal()
        return GameState.materials.soulCrystal or 0
    end

    -- 背包容量

    function GameState.GetInventorySize()
        return Config.INVENTORY_SIZE + (GameState.expandCount or 0) * Config.INVENTORY_EXPAND_SLOTS
    end

    function GameState.GetExpandCost()
        local n = (GameState.expandCount or 0) + 1
        return Config.EXPAND_BASE_COST + (n - 1) * Config.EXPAND_COST_INCREMENT
    end

    function GameState.ExpandInventory()
        local curSize = GameState.GetInventorySize()
        if curSize >= Config.INVENTORY_MAX_SIZE then
            return false, "背包已达上限 " .. Config.INVENTORY_MAX_SIZE .. " 格"
        end
        local cost = GameState.GetExpandCost()
        local cur = GameState.GetSoulCrystal()
        if cur < cost then
            return false, "魂晶不足 (" .. cur .. "/" .. cost .. ")"
        end
        GameState.materials.soulCrystal = GameState.materials.soulCrystal - cost
        GameState.expandCount = (GameState.expandCount or 0) + 1
        print("[GameState] Inventory expanded to " .. GameState.GetInventorySize() .. " slots (cost " .. cost .. " soul crystals)")
        return true, nil
    end

    -- ========================================================================
    -- 装备升级 (P2: 均匀成长)
    -- ========================================================================

    --- 检查装备能否升级
    function GameState.CanUpgradeEquip(item)
        if not item then return false, "无装备" end
        local q = Config.EQUIP_QUALITY[item.qualityIdx]
        if not q then return false, "品质异常" end
        local maxLv = q.maxUpgrade or 0
        if maxLv <= 0 then return false, "白色装备无法升级" end
        local curLv = item.upgradeLv or 0
        if curLv >= maxLv then return false, "已满级" end
        -- 费用: 根据当前等级和 IP 推算章节
        local cost = Config.UpgradeCost(curLv, 1)
        if GameState.materials.stone < cost then
            return false, "强化石不足 (" .. GameState.materials.stone .. "/" .. cost .. ")"
        end
        return true, nil
    end

    --- 升级装备 (P2: 所有词缀均匀 +3%/级, IP +5)
    function GameState.UpgradeEquip(slotId)
        local item = GameState.equipment[slotId]
        local ok, reason = GameState.CanUpgradeEquip(item)
        if not ok then return false, reason end

        local curLv = item.upgradeLv or 0
        local cost = Config.UpgradeCost(curLv, 1)

        -- 扣材料
        GameState.materials.stone = GameState.materials.stone - cost
        item.upgradeStonesSpent = (item.upgradeStonesSpent or 0) + cost

        -- 升级
        curLv = curLv + 1
        item.upgradeLv = curLv

        -- IP +5
        item.itemPower = (item.itemPower or 100) + Config.IP_PER_UPGRADE

        -- 所有词缀均匀成长: value = baseValue × (1 + lv × growth)
        local growth = Config.UPGRADE_AFFIX_GROWTH
        if item.affixes then
            for _, aff in ipairs(item.affixes) do
                if not aff.baseValue then aff.baseValue = aff.value end
                aff.value = aff.baseValue * (1 + curLv * growth)
            end
        end

        print("[Upgrade] " .. (item.name or "?") .. " → Lv." .. curLv .. " (消耗 " .. cost .. " 强化石)")
        local ok2, DR = pcall(require, "DailyRewards")
        if ok2 and DR and DR.TrackProgress then DR.TrackProgress("enhance", 1) end
        return true, "升级到 Lv." .. curLv
    end

    -- ========================================================================
    -- 装备生成 (P2: IP 驱动, 统一词缀)
    -- ========================================================================

    --- 生成随机装备
    --- @param waveLevel number 当前波次等级(仅用于品质权重)
    --- @param isBoss boolean|nil 是否Boss掉落
    --- @param overrideChapter number|nil 覆盖章节
    --- @return table 装备对象
    function GameState.GenerateEquip(waveLevel, isBoss, overrideChapter)
        -- 品质权重抽取
        local luck = GameState.GetLuck()
        local luckyStarVal = AffixHelper.GetAffixValue("lucky_star")
        local totalWeight = 0
        local weights = {}
        local mobMul = { 1, 1, 0.054, 0.02, 0.008 }
        for i, q in ipairs(Config.EQUIP_QUALITY) do
            local w = q.dropWeight
            if i <= 2 then
                w = w * math.max(0.3, 1 - luck)
            else
                w = w * (1 + luck * (i - 2))
                if luckyStarVal > 0 then
                    w = w * (1 + luckyStarVal)
                end
            end
            if not isBoss and mobMul[i] then
                w = w * mobMul[i]
            end
            weights[i] = w
            totalWeight = totalWeight + w
        end
        local roll = math.random() * totalWeight
        local qualityIdx = 1
        local acc = 0
        for i, w in ipairs(weights) do
            acc = acc + w
            if roll <= acc then qualityIdx = i; break end
        end

        -- 随机槽位
        local slotIdx = math.random(1, #Config.EQUIP_SLOTS)
        local slotCfg = Config.EQUIP_SLOTS[slotIdx]
        local quality = Config.EQUIP_QUALITY[qualityIdx]

        -- 章节 → IP
        local chapter = overrideChapter or (GameState.stage and GameState.stage.chapter or 1)
        local itemPower = calcItemPower(chapter, qualityIdx, 0)

        -- 套装
        local setId = rollSetId(chapter, quality)

        -- 武器元素
        local element = rollWeaponElement(slotCfg, qualityIdx)

        -- 词缀
        local affixes = rollNewAffixes(slotCfg.id, qualityIdx, itemPower)

        -- 构造装备
        local item = {
            slot = slotCfg.id,
            slotName = slotCfg.name,
            qualityIdx = qualityIdx,
            qualityName = quality.name,
            qualityColor = quality.color,
            itemPower = itemPower,
            affixes = affixes,
            setId = setId,
            element = element,
            upgradeLv = 0,
        }
        item.name = buildItemName(slotCfg, setId, element)

        addSocketsIfOrange(item)

        return item
    end

    -- ========================================================================
    -- 指定参数直接构造装备
    -- ========================================================================

    --- @param qualityIdx number
    --- @param chapter number
    --- @param slotId string|nil
    --- @param forceSetId string|nil
    --- @return table item
    function GameState.CreateEquip(qualityIdx, chapter, slotId, forceSetId)
        local quality = Config.EQUIP_QUALITY[qualityIdx]
        if not quality then quality = Config.EQUIP_QUALITY[1]; qualityIdx = 1 end

        -- 槽位
        local slotCfg
        if slotId then
            for _, sc in ipairs(Config.EQUIP_SLOTS) do
                if sc.id == slotId then slotCfg = sc; break end
            end
        end
        if not slotCfg then
            slotCfg = Config.EQUIP_SLOTS[math.random(1, #Config.EQUIP_SLOTS)]
        end

        local itemPower = calcItemPower(chapter, qualityIdx, 0)

        -- 套装
        local setId = forceSetId
        if not setId then
            setId = rollSetId(chapter, quality)
        end

        -- 武器元素
        local element = rollWeaponElement(slotCfg, qualityIdx)

        -- 词缀
        local affixes = rollNewAffixes(slotCfg.id, qualityIdx, itemPower)

        local item = {
            slot = slotCfg.id,
            slotName = slotCfg.name,
            qualityIdx = qualityIdx,
            qualityName = quality.name,
            qualityColor = quality.color,
            itemPower = itemPower,
            affixes = affixes,
            setId = setId,
            element = element,
            upgradeLv = 0,
        }
        item.name = buildItemName(slotCfg, setId, element)

        addSocketsIfOrange(item)

        return item
    end

    -- ========================================================================
    -- 锻造系统 (装备商店, P2: IP 驱动)
    -- ========================================================================

    function GameState.ForgeEquip(segmentId, lockSlotId)
        -- 日期重置
        local today = os.date("%Y-%m-%d")
        if GameState.forge.lastDate ~= today then
            GameState.forge.usedFree = 0
            GameState.forge.usedPaid = 0
            GameState.forge.lastDate = today
        end

        local isFree = GameState.forge.usedFree < Config.FORGE_FREE_PER_DAY
        local totalUsed = GameState.forge.usedFree + GameState.forge.usedPaid

        if totalUsed >= Config.FORGE_TOTAL_PER_DAY then
            return nil, "今日锻造次数已用完"
        end

        if isFree and lockSlotId then
            return nil, "免费锻造不能锁定部位"
        end

        -- 获取分段 scaleMul & bossChapter
        local maxCh = GameState.records and GameState.records.maxChapter or 1
        local maxSt = GameState.records and GameState.records.maxStage or 1
        local scaleMul, bossChapter = Config.GetForgeSegmentScaleMul(segmentId, maxCh, maxSt)
        if not scaleMul then
            return nil, "未解锁该分段（需通关Boss）"
        end

        -- 消耗
        local lockSlot = lockSlotId ~= nil
        local goldCost = isFree and 0 or Config.GetForgeGoldCost(scaleMul, lockSlot)
        local stoneCost = isFree and 0 or Config.GetForgeStoneCost(lockSlot)

        if not isFree then
            if GameState.player.gold < goldCost then
                return nil, "金币不足 (" .. math.floor(GameState.player.gold) .. "/" .. goldCost .. ")"
            end
            if GameState.materials.stone < stoneCost then
                return nil, "强化石不足 (" .. GameState.materials.stone .. "/" .. stoneCost .. ")"
            end
        end

        if not isFree then
            GameState.player.gold = GameState.player.gold - goldCost
            GameState.materials.stone = GameState.materials.stone - stoneCost
        end

        -- 生成橙色装备
        local qualityIdx = Config.FORGE_QUALITY_IDX
        local quality = Config.EQUIP_QUALITY[qualityIdx]

        -- 槽位
        local slotCfg
        if lockSlotId then
            for _, sc in ipairs(Config.EQUIP_SLOTS) do
                if sc.id == lockSlotId then slotCfg = sc; break end
            end
        end
        if not slotCfg then
            slotCfg = Config.EQUIP_SLOTS[math.random(1, #Config.EQUIP_SLOTS)]
        end

        -- IP
        local itemPower = calcItemPower(bossChapter, qualityIdx, 0)

        -- 套装: 100% 从该段通用套装池中随机
        local setId = nil
        local seg = Config.FORGE_SEGMENTS[segmentId]
        if seg then
            local available = {}
            for _, s in ipairs(Config.EQUIP_SETS) do
                if s.chapterRange
                    and s.chapterRange[1] == seg.chapterRange[1]
                    and s.chapterRange[2] == seg.chapterRange[2] then
                    table.insert(available, s.id)
                end
            end
            if #available > 0 then
                setId = available[math.random(1, #available)]
            end
        end

        -- 武器元素
        local element = rollWeaponElement(slotCfg, qualityIdx)

        -- 词缀
        local affixes = rollNewAffixes(slotCfg.id, qualityIdx, itemPower)

        local item = {
            slot = slotCfg.id,
            slotName = slotCfg.name,
            qualityIdx = qualityIdx,
            qualityName = quality.name,
            qualityColor = quality.color,
            itemPower = itemPower,
            affixes = affixes,
            setId = setId,
            element = element,
            forged = true,
            upgradeLv = 0,
        }
        item.name = buildItemName(slotCfg, setId, element)

        addSocketsIfOrange(item)

        -- 更新每日计数
        if isFree then
            GameState.forge.usedFree = GameState.forge.usedFree + 1
        else
            GameState.forge.usedPaid = GameState.forge.usedPaid + 1
        end

        local SaveSys = require("SaveSystem")
        SaveSys.MarkDirty()

        print("[Forge] " .. item.name .. " (IP " .. itemPower .. ", "
            .. (isFree and "免费" or ("消耗 " .. goldCost .. "金 " .. stoneCost .. "石")) .. ")")
        return item, nil
    end

    function GameState.GetForgeInfo()
        local today = os.date("%Y-%m-%d")
        if GameState.forge.lastDate ~= today then
            GameState.forge.usedFree = 0
            GameState.forge.usedPaid = 0
            GameState.forge.lastDate = today
        end
        local isFree = GameState.forge.usedFree < Config.FORGE_FREE_PER_DAY
        local totalUsed = GameState.forge.usedFree + GameState.forge.usedPaid
        return {
            isFree = isFree,
            remaining = Config.FORGE_TOTAL_PER_DAY - totalUsed,
            usedFree = GameState.forge.usedFree,
            usedPaid = GameState.forge.usedPaid,
        }
    end

    -- ========================================================================
    -- P2: IP 注入 (取代旧 TierUpgrade)
    -- ========================================================================

    --- 检查装备能否 IP 注入
    function GameState.CanInfuseEquip(item)
        if not item then return false, "无装备" end
        if item.qualityIdx < 3 then return false, "蓝色品质以上才能注入" end
        local maxCh = GameState.records and GameState.records.maxChapter or 1
        local curIP = item.itemPower or 100
        local newIP = calcItemPower(maxCh, item.qualityIdx, item.upgradeLv or 0)
        if newIP <= curIP then return false, "IP 已是当前章节最高" end
        return true, nil
    end

    --- 执行 IP 注入: 将装备 IP 提升到当前最高章节水平, 重算所有词缀
    --- @param slotId string 装备槽位
    --- @param stoneItemId string 使用的魔法石道具 ID
    --- @return boolean success, string message
    function GameState.InfuseEquip(slotId, stoneItemId)
        local item = GameState.equipment[slotId]
        if not item then return false, "槽位无装备" end

        local cfg = Config.ITEM_MAP[stoneItemId]
        if not cfg or not cfg.isMagicStone then return false, "无效的魔法石" end

        local maxCh = GameState.records and GameState.records.maxChapter or 1
        -- 顶级魔法石 → 当前最高章节; 普通魔法石 → 指定 targetTier
        local targetChapter = cfg.isTopMagicStone and maxCh or cfg.targetTier

        local canInf, reason = GameState.CanInfuseEquip(item)
        if not canInf then return false, reason end

        -- 检查背包中有这个魔法石
        local count = GameState.GetBagItemCount(stoneItemId)
        if count <= 0 then return false, "魔法石不足" end

        local oldIP = item.itemPower or 100
        local newIP = calcItemPower(targetChapter, item.qualityIdx, item.upgradeLv or 0)
        if newIP <= oldIP then return false, "IP 已达到或超过目标" end

        -- 重算所有词缀值 (基于新 IP 的 ipFactor)
        if item.affixes then
            for _, aff in ipairs(item.affixes) do
                local def = Config.AFFIX_POOL_MAP[aff.id]
                if def then
                    local baseVal = aff.baseValue or aff.value
                    -- 还原 roll 成分: baseVal = base × oldIpFactor × roll × greaterMul × upgradeMul
                    -- 直接按 ipFactor 比例缩放更安全
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

        -- 消耗魔法石
        GameState.DiscardBagItem(stoneItemId, 1)

        local SaveSystem = require("SaveSystem")
        SaveSystem.MarkDirty()

        print("[InfuseEquip] " .. (item.name or "?") .. " IP " .. oldIP .. " → " .. newIP)
        return true, "IP " .. oldIP .. " → " .. newIP .. " 注入成功!"
    end

    --- 预览 IP 注入后的效果 (不修改装备)
    function GameState.PreviewInfuse(item, targetChapter)
        if not item then return nil end
        local oldIP = item.itemPower or 100
        local newIP = calcItemPower(targetChapter or 1, item.qualityIdx, item.upgradeLv or 0)
        if newIP <= oldIP then return nil end

        local preview = { itemPower = newIP, affixes = {} }
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

    -- 兼容: 旧 API 别名 (UI 层可能还引用 TierUpgrade)
    GameState.TierUpgradeEquip = GameState.InfuseEquip
    GameState.CanTierUpgrade = function(item, _targetTier)
        return GameState.CanInfuseEquip(item)
    end
    GameState.PreviewTierUpgrade = function(item, targetTier)
        return GameState.PreviewInfuse(item, targetTier)
    end

    --- 获取指定装备可用的魔法石列表 (兼容旧 UI)
    function GameState.GetAvailableMagicStones(item)
        local result = {}
        local maxCh = GameState.records and GameState.records.maxChapter or 1
        local curIP = item and item.itemPower or 100
        local qualityOk = item and item.qualityIdx >= 3
        local bag = GameState.bag or {}

        for itemId, bagCount in pairs(bag) do
            if bagCount > 0 then
                local itemCfg = Config.ITEM_MAP[itemId]
                if itemCfg and itemCfg.isMagicStone then
                    local tCh = itemCfg.isTopMagicStone and maxCh or itemCfg.targetTier
                    local targetIP = calcItemPower(tCh, item and item.qualityIdx or 1, item and item.upgradeLv or 0)
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
                        count = bagCount,
                        targetTier = tCh,
                        canUse = canUse,
                        reason = reasonStr,
                        color = itemCfg.color,
                    })
                end
            end
        end
        table.sort(result, function(a, b) return a.targetTier > b.targetTier end)
        return result
    end

    -- ========================================================================
    -- P2: 附魔 (洗词缀)
    -- ========================================================================

    --- 附魔: 重 roll 指定索引的词缀
    --- @param slotId string 装备槽位
    --- @param affixIndex number 要洗的词缀索引 (1-based)
    --- @return boolean success, string message
    function GameState.EnchantAffix(slotId, affixIndex)
        local item = GameState.equipment[slotId]
        if not item then return false, "槽位无装备" end
        if item.qualityIdx < 4 then return false, "紫色品质以上才能附魔" end
        if not item.affixes or affixIndex < 1 or affixIndex > #item.affixes then
            return false, "无效的词缀索引"
        end

        -- 费用
        local ip = item.itemPower or 100
        local qMul = Config.ENCHANT_COST.qualityMul[item.qualityIdx] or 1
        local cost = math.floor((Config.ENCHANT_COST.baseCost + ip * Config.ENCHANT_COST.ipMul) * qMul)
        local curSC = GameState.GetSoulCrystal()
        if curSC < cost then
            return false, "魂晶不足 (" .. curSC .. "/" .. cost .. ")"
        end

        -- 扣魂晶
        GameState.materials.soulCrystal = GameState.materials.soulCrystal - cost

        -- 收集其他已有词缀 ID (排除被洗的那条)
        local existingIds = {}
        for i, aff in ipairs(item.affixes) do
            if i ~= affixIndex then existingIds[aff.id] = true end
        end

        -- 从槽位池中排除已有词缀, 随机选一条新的
        local pool = Config.AFFIX_SLOT_POOLS[item.slot] or {}
        local candidates = {}
        for _, affId in ipairs(pool) do
            if not existingIds[affId] then
                table.insert(candidates, affId)
            end
        end

        if #candidates == 0 then
            -- 极端情况: 无可选词缀, 退款
            GameState.materials.soulCrystal = GameState.materials.soulCrystal + cost
            return false, "该槽位无其他可选词缀"
        end

        local newAffId = candidates[math.random(1, #candidates)]
        local def = Config.AFFIX_POOL_MAP[newAffId]

        -- Roll
        local minRoll, maxRoll = Config.GetIPBracket(ip)
        local roll = minRoll + math.random() * (maxRoll - minRoll)
        local value = Config.CalcAffixValue(def, ip, roll)

        -- Greater 状态保留
        local oldAff = item.affixes[affixIndex]
        local isGreater = oldAff.greater
        if isGreater then
            value = value * 1.5
        end

        -- 写入新词缀
        item.affixes[affixIndex] = {
            id = newAffId,
            value = value,
            greater = isGreater or nil,
        }

        -- 如果已升级, 记录 baseValue 方便后续升级成长计算
        if (item.upgradeLv or 0) > 0 then
            local baseVal = value / (1 + (item.upgradeLv or 0) * Config.UPGRADE_AFFIX_GROWTH)
            item.affixes[affixIndex].baseValue = baseVal
        end

        local SaveSystem = require("SaveSystem")
        SaveSystem.MarkDirty()

        print("[Enchant] " .. (item.name or "?") .. " 词缀 #" .. affixIndex
            .. " → " .. (def.name or newAffId) .. " (消耗 " .. cost .. " 魂晶)")
        return true, "附魔成功: " .. (def.name or newAffId)
    end

    -- ========================================================================
    -- 背包管理
    -- ========================================================================

    function GameState.AddToInventory(item)
        -- 自动分解
        local activeLevel, activeMode = 0, 0
        for k = #GameState.autoDecompConfig, 1, -1 do
            if GameState.autoDecompConfig[k] > 0 then
                activeLevel = k
                activeMode = GameState.autoDecompConfig[k]
                break
            end
        end
        if activeLevel > 0 and item.qualityIdx and item.qualityIdx <= activeLevel
            and not item.locked and (activeMode == 1 or not (item.setId and item.qualityIdx == activeLevel)) then
            if item.qualityIdx == 1 then
                GameState.AddGold(1)
            end
            local stones = Config.DECOMPOSE_STONES[item.qualityIdx] or 1
            GameState.AddStone(stones)
            return true
        end
        if #GameState.inventory >= GameState.GetInventorySize() then
            return false
        end
        table.insert(GameState.inventory, item)
        return true
    end

    function GameState.EquipItem(invIndex)
        local item = GameState.inventory[invIndex]
        if not item then return false end
        local old = GameState.equipment[item.slot]
        GameState.equipment[item.slot] = item
        table.remove(GameState.inventory, invIndex)
        if old then
            table.insert(GameState.inventory, old)
        end
        return true
    end

    function GameState.SortInventoryBySet()
        local slotOrder = {}
        for i, slot in ipairs(Config.EQUIP_SLOTS) do
            slotOrder[slot.id] = i
        end
        local powerCache = {}
        for _, item in ipairs(GameState.inventory) do
            powerCache[item] = GameState.ItemPower(item)
        end
        table.sort(GameState.inventory, function(a, b)
            local sA = a.setId or ""
            local sB = b.setId or ""
            if sA ~= sB then return sA < sB end
            local sa = slotOrder[a.slot] or 99
            local sb = slotOrder[b.slot] or 99
            if sa ~= sb then return sa < sb end
            if a.qualityIdx ~= b.qualityIdx then return a.qualityIdx > b.qualityIdx end
            local pa, pb = powerCache[a], powerCache[b]
            if pa ~= pb then return pa > pb end
            return (a.itemPower or 0) > (b.itemPower or 0)
        end)
    end

    function GameState.SortInventory()
        local slotOrder = {}
        for i, slot in ipairs(Config.EQUIP_SLOTS) do
            slotOrder[slot.id] = i
        end
        local powerCache = {}
        for _, item in ipairs(GameState.inventory) do
            powerCache[item] = GameState.ItemPower(item)
        end
        table.sort(GameState.inventory, function(a, b)
            local sa = slotOrder[a.slot] or 99
            local sb = slotOrder[b.slot] or 99
            if sa ~= sb then return sa < sb end
            if a.qualityIdx ~= b.qualityIdx then return a.qualityIdx > b.qualityIdx end
            local pa, pb = powerCache[a], powerCache[b]
            if pa ~= pb then return pa > pb end
            local sA = a.setId or ""
            local sB = b.setId or ""
            if sA ~= sB then return sA < sB end
            return (a.itemPower or 0) > (b.itemPower or 0)
        end)
    end

    function GameState.AutoEquipBest()
        local changed = false
        for _, slotCfg in ipairs(Config.EQUIP_SLOTS) do
            local bestIdx = nil
            local bestPower = GameState.ItemPower(GameState.equipment[slotCfg.id])
            for i, item in ipairs(GameState.inventory) do
                if item.slot == slotCfg.id then
                    local power = GameState.ItemPower(item)
                    if power > bestPower then
                        bestPower = power
                        bestIdx = i
                    end
                end
            end
            if bestIdx then
                GameState.EquipItem(bestIdx)
                changed = true
            end
        end
        return changed
    end

    function GameState.ToggleLock(invIndex)
        local item = GameState.inventory[invIndex]
        if not item then return end
        item.locked = not item.locked
    end

    function GameState.ToggleEquipLock(slotId)
        local item = GameState.equipment[slotId]
        if not item then return end
        item.locked = not item.locked
    end

    function GameState.DecomposeItem(invIndex)
        local item = GameState.inventory[invIndex]
        if not item then return 0, 0 end
        if item.locked then return 0, 0 end
        local gold = 0
        if item.qualityIdx == 1 then gold = 1 end
        local stones = Config.DECOMPOSE_STONES[item.qualityIdx] or 1
        local spent = item.upgradeStonesSpent or 0
        if spent > 0 then
            stones = stones + math.floor(spent * Config.UPGRADE_REFUND_RATIO)
        end
        table.remove(GameState.inventory, invIndex)
        if gold > 0 then GameState.AddGold(gold) end
        GameState.AddStone(stones)
        return gold, stones
    end

    function GameState.DecomposeAllWhite()
        local totalGold, totalStones = 0, 0
        for i = #GameState.inventory, 1, -1 do
            if GameState.inventory[i].qualityIdx == 1 then
                local g, s = GameState.DecomposeItem(i)
                totalGold = totalGold + g
                totalStones = totalStones + s
            end
        end
        return totalGold, totalStones
    end

    function GameState.DecomposeByFilter(maxQuality, keepSets)
        local totalGold = 0
        local totalStones = 0
        local count = 0
        for i = #GameState.inventory, 1, -1 do
            local item = GameState.inventory[i]
            if item.qualityIdx <= maxQuality then
                if not item.locked and not (keepSets and item.setId) then
                    local g, s = GameState.DecomposeItem(i)
                    totalGold = totalGold + g
                    totalStones = totalStones + s
                    count = count + 1
                end
            end
        end
        return totalGold, count, totalStones
    end

    -- ========================================================================
    -- 运行时迁移: 旧格式装备 → 统一词缀 + IP
    -- 捕获内存中尚未经过 v7→v8 存档迁移的装备
    -- ========================================================================

    --- 就地迁移单个装备 (旧 mainStat/subStats → 统一 affixes[] + itemPower)
    local function runtimeMigrateItem(item)
        if not item or type(item) ~= "table" then return false end
        -- 必须同时有 itemPower 和非空 affixes 才认为已迁移
        if item.itemPower and item.affixes and #item.affixes > 0 then return false end

        local newAffixes = {}

        -- mainStat → 第一条词缀
        if item.mainStat then
            table.insert(newAffixes, {
                id = item.mainStat,
                value = item.mainValue or 0,
                greater = false,
            })
        end

        -- subStats → 后续词缀
        if item.subStats then
            for _, sub in ipairs(item.subStats) do
                table.insert(newAffixes, {
                    id = sub.key,
                    value = sub.value or 0,
                    greater = false,
                })
            end
        end

        -- 旧 proc 词缀 → 合并
        if item.affixes then
            for _, aff in ipairs(item.affixes) do
                local def = Config.AFFIX_MAP and Config.AFFIX_MAP[aff.id]
                local base = def and def.baseValue or 0.2
                local isGreater = aff.enhanced or false
                table.insert(newAffixes, {
                    id = aff.id,
                    value = isGreater and (base * 1.5) or base,
                    greater = isGreater,
                })
            end
        end

        -- 计算 IP (从旧 tier 推导 chapter)
        local tier = item.tier or 1
        local chapter = 1
        if tier > 1 then
            chapter = math.max(1, math.floor(100 ^ ((tier - 1) / 99) + 0.5))
        end
        local baseIP = Config.CalcBaseIP(chapter)
        local qi = item.qualityIdx or 1
        local ipQMul = Config.IP_QUALITY_MUL[qi] or 0.5
        item.itemPower = math.floor(baseIP * ipQMul + (item.upgradeLv or 0) * Config.IP_PER_UPGRADE)

        -- 写入新结构, 删除旧字段
        item.affixes = newAffixes
        item.mainStat = nil
        item.mainValue = nil
        item.baseMainValue = nil
        item.subStats = nil
        item.tier = nil
        item.tierMul = nil
        return true
    end

    -- 启动时迁移所有内存中的装备
    local migratedCount = 0
    if GameState.equipment then
        for _, item in pairs(GameState.equipment) do
            if runtimeMigrateItem(item) then migratedCount = migratedCount + 1 end
        end
    end
    if GameState.inventory then
        for _, item in ipairs(GameState.inventory) do
            if runtimeMigrateItem(item) then migratedCount = migratedCount + 1 end
        end
    end
    if migratedCount > 0 then
        print(string.format("[Equipment] Runtime migrated %d items to unified affix system", migratedCount))
    end
end

return Equipment
