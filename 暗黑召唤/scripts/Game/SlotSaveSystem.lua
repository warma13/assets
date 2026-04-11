-- Game/SlotSaveSystem.lua
-- 多槽位云端存档系统（云端优先、本地缓存、分片存储）
-- 设计文档: docs/多槽位云端存档系统设计.md

---@diagnostic disable: undefined-global

local SaveManager = require("Game.SaveManager")

local SlotSaveSystem = {}

-- ============================================================================
-- 常量
-- ============================================================================

local SAVE_VERSION = 1         -- 存档数据版本号
local SHARD_FORMAT = 2         -- 分片格式版本号
local MAX_SLOTS = 10           -- 最大槽位数
local CHUNK_SIZE = 8192        -- 单片最大字节数 (8KB，留余量给JSON开销)
local SAVE_INTERVAL = 60       -- 自动保存间隔（秒）
local DIRTY_DELAY = 5          -- 脏标记延迟保存（秒）
local MAX_RETRY = 3            -- 最大重试次数
local RETRY_INTERVALS = { 3, 9, 27 }  -- 指数退避间隔

-- 数据组名列表（决定分组顺序和 key 名）
local GROUP_NAMES = { "core", "currency", "equip", "meta_game" }

-- ============================================================================
-- 内部状态
-- ============================================================================

local meta = nil               -- save_meta 数据
local activeSlot = 0           -- 当前活跃槽位 (0=未选择)
local headCache = {}           -- slotId -> head 数据缓存
local saveConfirmed = false    -- 存档已加载确认（开始自动保存循环）
local playTime = 0             -- 本次累计游戏时长（秒）
local healthy = true           -- 存档健康状态

-- 定时器
local autoSaveTimer = 0        -- 自动保存计时器
local dirtyTimer = -1          -- 脏标记计时器 (-1=未激活)
local savingInProgress = false -- 是否正在保存中（防止重入）

-- 重试队列
local retryQueue = {}          -- { { fn, retryCount, nextRetryTime } }

-- 初始化状态
local initState = "none"       -- "none" | "loading" | "ready" | "error"
local initRetryCount = 0
local initRetryTimer = -1
local initCallback = nil

-- ============================================================================
-- DJB2 校验
-- ============================================================================

--- 计算字符串的 DJB2 哈希
---@param str string
---@return number
local function CalcChecksum(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash << 5) + hash + string.byte(str, i)) & 0xFFFFFFFF
    end
    return hash
end

-- ============================================================================
-- 数据分组（业务层定义）
-- ============================================================================

--- 将完整 saveData 拆分为功能组
---@param saveData table
---@return table groups  { core={...}, currency={...}, equip={...}, meta_game={...} }
local function SplitIntoGroups(saveData)
    return {
        core = {
            heroes = saveData.heroes,
            deployed = saveData.deployed,
            stats = saveData.stats,
            recruitData = saveData.recruitData,
            lastSaveTime = saveData.lastSaveTime,
        },
        currency = {
            currencies = saveData.currencies,
        },
        equip = {
            equipData = saveData.equipData,
            chestData = saveData.chestData,
        },
        meta_game = {
            towerData = saveData.towerData,
            activityData = saveData.activityData,
            launchGiftData = saveData.launchGiftData,
        },
    }
end

--- 将各组合并还原为完整 saveData
---@param groups table
---@return table saveData
local function MergeGroups(groups)
    local data = {}
    -- core
    if groups.core then
        data.heroes = groups.core.heroes
        data.deployed = groups.core.deployed
        data.stats = groups.core.stats
        data.recruitData = groups.core.recruitData
        data.lastSaveTime = groups.core.lastSaveTime
    end
    -- currency
    if groups.currency then
        data.currencies = groups.currency.currencies
    end
    -- equip
    if groups.equip then
        data.equipData = groups.equip.equipData
        data.chestData = groups.equip.chestData
    end
    -- meta_game
    if groups.meta_game then
        data.towerData = groups.meta_game.towerData
        data.activityData = groups.meta_game.activityData
        data.launchGiftData = groups.meta_game.launchGiftData
    end
    return data
end

-- ============================================================================
-- 分片编码/解码
-- ============================================================================

--- 将分组数据编码为云端 key-value 对 + head 数据
---@param slotId number
---@param groups table
---@return table kvPairs  { key = jsonStr }
---@return table headData  分片索引+校验
local function EncodeChunkedGroups(slotId, groups)
    local kvPairs = {}
    local headKeys = {}
    local prefix = "s_" .. slotId .. "_"

    for _, groupName in ipairs(GROUP_NAMES) do
        local groupData = groups[groupName]
        if groupData then
            local ok, jsonStr = pcall(cjson.encode, groupData)
            if not ok then
                print("[SlotSave] Encode failed for group " .. groupName .. ": " .. tostring(jsonStr))
                jsonStr = "{}"
            end

            local len = #jsonStr
            if len <= CHUNK_SIZE then
                -- 单片
                local key = prefix .. groupName
                kvPairs[key] = jsonStr
                headKeys[groupName] = {
                    cs = CalcChecksum(jsonStr),
                    len = len,
                }
            else
                -- 多片
                local chunks = {}
                local csArr = {}
                local lenArr = {}
                local pos = 1
                local chunkIdx = 0
                while pos <= len do
                    local endPos = math.min(pos + CHUNK_SIZE - 1, len)
                    local chunk = string.sub(jsonStr, pos, endPos)
                    local key = prefix .. groupName .. "_" .. chunkIdx
                    kvPairs[key] = chunk
                    csArr[#csArr + 1] = CalcChecksum(chunk)
                    lenArr[#lenArr + 1] = #chunk
                    chunkIdx = chunkIdx + 1
                    pos = endPos + 1
                end
                headKeys[groupName] = {
                    chunks = chunkIdx,
                    cs = csArr,
                    len = lenArr,
                }
            end
        end
    end

    local headData = {
        format = SHARD_FORMAT,
        version = SAVE_VERSION,
        timestamp = os.time(),
        slotId = slotId,
        keys = headKeys,
    }

    return kvPairs, headData
end

--- 收集加载时需要读取的所有 key
---@param slotId number
---@param head table  head 数据
---@return table keys  key 列表
local function CollectGroupKeys(slotId, head)
    local keys = {}
    local prefix = "s_" .. slotId .. "_"
    if head and head.keys then
        for groupName, info in pairs(head.keys) do
            if info.chunks then
                for i = 0, info.chunks - 1 do
                    keys[#keys + 1] = prefix .. groupName .. "_" .. i
                end
            else
                keys[#keys + 1] = prefix .. groupName
            end
        end
    end
    return keys
end

--- 从云端返回的 values 解码分组数据
---@param slotId number
---@param head table
---@param values table  云端 values
---@return table|nil groups  解码后的分组数据
---@return boolean checksumOk  校验是否通过
local function DecodeChunkedGroups(slotId, head, values)
    local groups = {}
    local prefix = "s_" .. slotId .. "_"
    local allOk = true

    for groupName, info in pairs(head.keys) do
        local jsonStr
        if info.chunks then
            -- 多片拼接
            local parts = {}
            for i = 0, info.chunks - 1 do
                local key = prefix .. groupName .. "_" .. i
                local chunk = values[key]
                if not chunk then
                    print("[SlotSave] Missing chunk " .. key)
                    allOk = false
                    break
                end
                -- 校验每片
                if type(info.cs) == "table" and info.cs[i + 1] then
                    local actual = CalcChecksum(chunk)
                    if actual ~= info.cs[i + 1] then
                        print("[SlotSave] Checksum mismatch for " .. key)
                        allOk = false
                    end
                end
                parts[#parts + 1] = chunk
            end
            jsonStr = table.concat(parts)
        else
            -- 单片
            local key = prefix .. groupName
            jsonStr = values[key]
            if jsonStr then
                local actual = CalcChecksum(jsonStr)
                if actual ~= info.cs then
                    print("[SlotSave] Checksum mismatch for " .. key)
                    allOk = false
                end
            end
        end

        if jsonStr and jsonStr ~= "" then
            local ok, decoded = pcall(cjson.decode, jsonStr)
            if ok then
                groups[groupName] = decoded
            else
                print("[SlotSave] Decode failed for group " .. groupName .. ": " .. tostring(decoded))
                allOk = false
            end
        end
    end

    return groups, allOk
end

-- ============================================================================
-- 本地缓存
-- ============================================================================

--- 保存到本地缓存文件
---@param slotId number
---@param saveData table
local function SaveLocal(slotId, saveData)
    local fileName = "slot_" .. slotId .. "_cache.json"
    local ok, jsonStr = pcall(cjson.encode, saveData)
    if not ok then
        print("[SlotSave] Local encode failed: " .. tostring(jsonStr))
        return
    end
    local file = File(fileName, FILE_WRITE)
    if file and file:IsOpen() then
        file:WriteString(jsonStr)
        file:Close()
    else
        print("[SlotSave] Local write failed for " .. fileName)
    end
end

--- 从本地缓存读取
---@param slotId number
---@return table|nil
local function LoadLocal(slotId)
    local fileName = "slot_" .. slotId .. "_cache.json"
    if not fileSystem:FileExists(fileName) then return nil end
    local file = File(fileName, FILE_READ)
    if not file or not file:IsOpen() then return nil end
    local jsonStr = file:ReadString()
    file:Close()
    if not jsonStr or jsonStr == "" then return nil end
    local ok, data = pcall(cjson.decode, jsonStr)
    if ok then return data end
    return nil
end

-- ============================================================================
-- Meta 摘要
-- ============================================================================

--- 构建当前槽位的摘要信息（由业务层数据填充）
---@return table
local function BuildMetaSlot()
    local HeroData = require("Game.HeroData")
    local Config = require("Game.Config")

    -- 统计已解锁英雄数
    local heroCount = 0
    if HeroData.heroes then
        for _, h in pairs(HeroData.heroes) do
            if h and h.unlocked then
                heroCount = heroCount + 1
            end
        end
    end

    -- 主角等级
    local leaderLevel = 1
    if HeroData.heroes and HeroData.heroes[Config.LEADER_HERO.id] then
        leaderLevel = HeroData.heroes[Config.LEADER_HERO.id].level or 1
    end

    return {
        leaderLevel = leaderLevel,
        bestStage = (HeroData.stats and HeroData.stats.bestStage) or 0,
        heroCount = heroCount,
        playTime = playTime,
        timestamp = os.time(),
    }
end

--- 保存 meta 到云端
---@param onComplete function|nil
local function SaveMeta(onComplete)
    if not meta then return end
    local ok, metaJson = pcall(cjson.encode, meta)
    if not ok then
        print("[SlotSave] Meta encode failed")
        if onComplete then onComplete(false) end
        return
    end
    clientCloud:Set("save_meta", meta, {
        ok = function()
            print("[SlotSave] Meta saved to cloud")
            if onComplete then onComplete(true) end
        end,
        error = function(code, reason)
            print("[SlotSave] Meta save failed: " .. tostring(reason))
            if onComplete then onComplete(false) end
        end,
    })
end

-- ============================================================================
-- 版本迁移框架
-- ============================================================================

local MIGRATIONS = {
    -- [1] = function(data) ... end,  -- v1 → v2（预留）
}

--- 执行版本迁移
---@param data table
local function RunVersionMigrations(data)
    local ver = data.version or 0
    while ver < SAVE_VERSION do
        local fn = MIGRATIONS[ver]
        if fn then
            fn(data)
            ver = ver + 1
            data.version = ver
        else
            break
        end
    end
end

-- ============================================================================
-- 核心保存逻辑
-- ============================================================================

--- 执行完整保存流程（本地+云端）
local function DoSave()
    if activeSlot <= 0 or not saveConfirmed then return end
    if savingInProgress then return end
    savingInProgress = true

    local HeroData = require("Game.HeroData")
    local saveData = HeroData.GetSaveSnapshot()
    saveData.version = SAVE_VERSION

    -- 1. 先保存本地
    SaveLocal(activeSlot, saveData)

    -- 2. 分组+分片编码
    local groups = SplitIntoGroups(saveData)
    local kvPairs, headData = EncodeChunkedGroups(activeSlot, groups)

    -- 3. 构建 BatchSet
    local batch = clientCloud:BatchSet()
    -- head
    local headKey = "s_" .. activeSlot .. "_head"
    batch:Set(headKey, headData)
    -- 所有分组 key
    for key, value in pairs(kvPairs) do
        batch:Set(key, value)
    end

    -- 4. 更新 meta 摘要
    local slotMeta = BuildMetaSlot()
    if not meta then
        meta = { version = 1, activeSlot = activeSlot, slots = {} }
    end
    meta.slots[tostring(activeSlot)] = slotMeta
    meta.activeSlot = activeSlot
    batch:Set("save_meta", meta)

    -- 5. 提交
    batch:Save("slot_" .. activeSlot .. "_save", {
        ok = function()
            savingInProgress = false
            headCache[activeSlot] = headData
            print("[SlotSave] Cloud save OK (slot " .. activeSlot .. ")")
        end,
        error = function(code, reason)
            savingInProgress = false
            print("[SlotSave] Cloud save failed: " .. tostring(reason) .. " (code=" .. tostring(code) .. ")")
            -- 加入重试队列
            retryQueue[#retryQueue + 1] = {
                fn = DoSave,
                retryCount = 0,
                nextRetryTime = os.time() + RETRY_INTERVALS[1],
            }
        end,
    })
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 初始化存档系统（启动时调用一次）
---@param onMetaReady function  回调 (meta, isNewPlayer, err)
function SlotSaveSystem.Init(onMetaReady)
    initCallback = onMetaReady
    initState = "loading"
    initRetryCount = 0

    print("[SlotSave] Init: loading save_meta from cloud...")

    clientCloud:Get("save_meta", {
        ok = function(values, iscores)
            local cloudMeta = values.save_meta
            if cloudMeta and type(cloudMeta) == "table" and cloudMeta.slots then
                -- 有 meta，老玩家
                meta = cloudMeta
                initState = "ready"
                print("[SlotSave] Init: meta loaded, " .. SlotSaveSystem.GetSlotCount() .. " slots")
                if onMetaReady then
                    onMetaReady(meta, false, nil)
                end
            else
                -- 无 meta，检查旧格式迁移
                print("[SlotSave] Init: no meta, checking old format...")
                SlotSaveSystem._TryMigrateOldFormat(onMetaReady)
            end
        end,
        error = function(code, reason)
            print("[SlotSave] Init: cloud read failed: " .. tostring(reason))
            initRetryCount = initRetryCount + 1
            if initRetryCount <= MAX_RETRY then
                local delay = RETRY_INTERVALS[initRetryCount] or 27
                print("[SlotSave] Init: retry #" .. initRetryCount .. " in " .. delay .. "s")
                initRetryTimer = delay
                initState = "loading"
            else
                initState = "error"
                healthy = false
                -- 尝试从本地缓存恢复 meta
                meta = { version = 1, activeSlot = 0, slots = {} }
                if onMetaReady then
                    onMetaReady(meta, true, "cloud_error")
                end
            end
        end,
    })
end

--- 尝试旧格式迁移（内部方法）
---@param onMetaReady function
function SlotSaveSystem._TryMigrateOldFormat(onMetaReady)
    -- 尝试读取旧 key "hero_save" 或本地 SaveManager
    clientCloud:Get("hero_save", {
        ok = function(values, iscores)
            local oldData = values.hero_save
            if oldData and type(oldData) == "table" and oldData.heroes then
                -- 有旧云端存档，迁移到槽位 1
                print("[SlotSave] Found old cloud save, migrating to slot 1...")
                SlotSaveSystem._MigrateOldData(oldData, 1, onMetaReady)
            else
                -- 尝试本地旧存档
                local localData = SaveManager.Load()
                if localData and localData.heroes then
                    print("[SlotSave] Found old local save, migrating to slot 1...")
                    SlotSaveSystem._MigrateOldData(localData, 1, onMetaReady)
                else
                    -- 纯新玩家
                    print("[SlotSave] New player, creating empty meta")
                    meta = { version = 1, activeSlot = 0, slots = {} }
                    initState = "ready"
                    if onMetaReady then
                        onMetaReady(meta, true, nil)
                    end
                end
            end
        end,
        error = function(code, reason)
            -- 旧 key 读取失败，尝试本地
            local localData = SaveManager.Load()
            if localData and localData.heroes then
                print("[SlotSave] Cloud old key failed, using local save for migration")
                SlotSaveSystem._MigrateOldData(localData, 1, onMetaReady)
            else
                -- 当做新玩家
                meta = { version = 1, activeSlot = 0, slots = {} }
                initState = "ready"
                if onMetaReady then
                    onMetaReady(meta, true, nil)
                end
            end
        end,
    })
end

--- 执行旧数据迁移（内部方法）
---@param oldData table
---@param slotId number
---@param onMetaReady function
function SlotSaveSystem._MigrateOldData(oldData, slotId, onMetaReady)
    -- 先反序列化到运行时（执行字段迁移）
    local HeroData = require("Game.HeroData")
    HeroData.RestoreFromSnapshot(oldData)

    -- 再序列化为新格式
    local saveData = HeroData.GetSaveSnapshot()
    saveData.version = SAVE_VERSION

    -- 保存本地
    SaveLocal(slotId, saveData)

    -- 分组+分片编码
    local groups = SplitIntoGroups(saveData)
    local kvPairs, headData = EncodeChunkedGroups(slotId, groups)

    -- 构建 meta
    activeSlot = slotId
    saveConfirmed = true

    local slotMeta = BuildMetaSlot()
    slotMeta.migratedFrom = "old_format"
    meta = {
        version = 1,
        activeSlot = slotId,
        slots = {
            [tostring(slotId)] = slotMeta,
        },
    }

    -- 云端写入
    local batch = clientCloud:BatchSet()
    batch:Set("s_" .. slotId .. "_head", headData)
    for key, value in pairs(kvPairs) do
        batch:Set(key, value)
    end
    batch:Set("save_meta", meta)
    batch:Save("migrate_old_to_slot_" .. slotId, {
        ok = function()
            headCache[slotId] = headData
            initState = "ready"
            print("[SlotSave] Migration complete: old -> slot " .. slotId)
            if onMetaReady then
                onMetaReady(meta, false, nil)
            end
        end,
        error = function(code, reason)
            -- 本地已保存，不阻塞
            initState = "ready"
            print("[SlotSave] Migration cloud write failed (local ok): " .. tostring(reason))
            if onMetaReady then
                onMetaReady(meta, false, nil)
            end
        end,
    })
end

--- 加载存档槽位
---@param slotId number
---@param onComplete function  回调 (success, isNewSlot)
function SlotSaveSystem.LoadSlot(slotId, onComplete)
    print("[SlotSave] LoadSlot(" .. slotId .. ")...")

    -- 检查是否为空槽位（新建存档）
    if meta and not meta.slots[tostring(slotId)] then
        print("[SlotSave] Slot " .. slotId .. " is empty, creating new...")
        SlotSaveSystem.CreateNewSlot(slotId, function(success)
            if onComplete then onComplete(success, true) end
        end)
        return
    end

    -- 读取 head
    local headKey = "s_" .. slotId .. "_head"
    clientCloud:Get(headKey, {
        ok = function(values, iscores)
            local head = values[headKey]
            if head and type(head) == "table" and head.keys then
                -- 分片格式：批量读取所有分组
                SlotSaveSystem._LoadShardedSlot(slotId, head, onComplete)
            else
                -- 无 head 或格式不对，尝试旧格式回退
                print("[SlotSave] No valid head for slot " .. slotId .. ", trying fallback...")
                SlotSaveSystem._LoadFallback(slotId, onComplete)
            end
        end,
        error = function(code, reason)
            print("[SlotSave] Head read failed: " .. tostring(reason))
            -- 尝试本地缓存
            local localData = LoadLocal(slotId)
            if localData then
                print("[SlotSave] Using local cache for slot " .. slotId)
                SlotSaveSystem._FinalizeLoad(slotId, localData, onComplete)
            else
                if onComplete then onComplete(false, false) end
            end
        end,
    })
end

--- 加载分片格式的存档（内部方法）
---@param slotId number
---@param head table
---@param onComplete function
function SlotSaveSystem._LoadShardedSlot(slotId, head, onComplete)
    local groupKeys = CollectGroupKeys(slotId, head)

    if #groupKeys == 0 then
        print("[SlotSave] No group keys to load")
        SlotSaveSystem._LoadFallback(slotId, onComplete)
        return
    end

    -- BatchGet 所有分组 key
    local batchGet = clientCloud:BatchGet()
    for _, key in ipairs(groupKeys) do
        batchGet:Key(key)
    end

    batchGet:Fetch({
        ok = function(values, iscores)
            local groups, checksumOk = DecodeChunkedGroups(slotId, head, values)
            if not checksumOk then
                print("[SlotSave] Checksum failed, trying fallback...")
                -- 校验失败但有数据，仍尝试使用
                if next(groups) then
                    local saveData = MergeGroups(groups)
                    SlotSaveSystem._FinalizeLoad(slotId, saveData, onComplete)
                else
                    SlotSaveSystem._LoadFallback(slotId, onComplete)
                end
                return
            end

            local saveData = MergeGroups(groups)
            headCache[slotId] = head
            print("[SlotSave] Sharded load OK for slot " .. slotId)
            SlotSaveSystem._FinalizeLoad(slotId, saveData, onComplete)
        end,
        error = function(code, reason)
            print("[SlotSave] BatchGet failed: " .. tostring(reason))
            -- 尝试本地缓存
            local localData = LoadLocal(slotId)
            if localData then
                print("[SlotSave] Using local cache for slot " .. slotId)
                SlotSaveSystem._FinalizeLoad(slotId, localData, onComplete)
            else
                if onComplete then onComplete(false, false) end
            end
        end,
    })
end

--- 旧格式回退加载（内部方法）
---@param slotId number
---@param onComplete function
function SlotSaveSystem._LoadFallback(slotId, onComplete)
    -- 尝试本地缓存
    local localData = LoadLocal(slotId)
    if localData then
        print("[SlotSave] Fallback: using local cache")
        SlotSaveSystem._FinalizeLoad(slotId, localData, onComplete)
        return
    end

    -- 尝试旧格式 hero_save key
    clientCloud:Get("hero_save", {
        ok = function(values, iscores)
            local oldData = values.hero_save
            if oldData and type(oldData) == "table" then
                print("[SlotSave] Fallback: using old cloud save")
                SlotSaveSystem._FinalizeLoad(slotId, oldData, onComplete)
            else
                -- 真正没有任何数据
                print("[SlotSave] Fallback: no data found, creating new slot")
                SlotSaveSystem.CreateNewSlot(slotId, function(success)
                    if onComplete then onComplete(success, true) end
                end)
            end
        end,
        error = function()
            print("[SlotSave] Fallback: all attempts failed")
            if onComplete then onComplete(false, false) end
        end,
    })
end

--- 完成加载：版本迁移 + 反序列化 + 设置活跃槽位（内部方法）
---@param slotId number
---@param saveData table
---@param onComplete function
function SlotSaveSystem._FinalizeLoad(slotId, saveData, onComplete)
    -- 版本迁移
    RunVersionMigrations(saveData)

    -- 反序列化到运行时
    local HeroData = require("Game.HeroData")
    HeroData.RestoreFromSnapshot(saveData)

    -- 计算离线时长
    local lastTime = saveData.lastSaveTime or 0
    local offlineSecs = 0
    if lastTime > 0 then
        offlineSecs = os.time() - lastTime
    end

    -- 设置活跃状态
    activeSlot = slotId
    saveConfirmed = true
    autoSaveTimer = 0
    dirtyTimer = -1
    playTime = 0
    healthy = true

    -- 保存本地缓存
    SaveLocal(slotId, saveData)

    print("[SlotSave] Slot " .. slotId .. " loaded (offline " .. math.floor(offlineSecs / 60) .. " min)")

    if onComplete then onComplete(true, false) end
end

--- 新建存档
---@param slotId number
---@param onComplete function|nil  回调 (success)
function SlotSaveSystem.CreateNewSlot(slotId, onComplete)
    print("[SlotSave] Creating new slot " .. slotId)

    local HeroData = require("Game.HeroData")
    HeroData.InitDefault()

    activeSlot = slotId
    saveConfirmed = true
    autoSaveTimer = 0
    dirtyTimer = -1
    playTime = 0
    healthy = true

    local saveData = HeroData.GetSaveSnapshot()
    saveData.version = SAVE_VERSION

    -- 本地保存
    SaveLocal(slotId, saveData)

    -- 分组+分片编码
    local groups = SplitIntoGroups(saveData)
    local kvPairs, headData = EncodeChunkedGroups(slotId, groups)

    -- 更新 meta
    local slotMeta = BuildMetaSlot()
    slotMeta.createdAt = os.time()
    if not meta then
        meta = { version = 1, activeSlot = slotId, slots = {} }
    end
    meta.slots[tostring(slotId)] = slotMeta
    meta.activeSlot = slotId

    -- 云端写入
    local batch = clientCloud:BatchSet()
    batch:Set("s_" .. slotId .. "_head", headData)
    for key, value in pairs(kvPairs) do
        batch:Set(key, value)
    end
    batch:Set("save_meta", meta)
    batch:Save("create_slot_" .. slotId, {
        ok = function()
            headCache[slotId] = headData
            print("[SlotSave] New slot " .. slotId .. " created and saved")
            if onComplete then onComplete(true) end
        end,
        error = function(code, reason)
            -- 本地已保存，不阻塞
            print("[SlotSave] New slot cloud save failed (local ok): " .. tostring(reason))
            if onComplete then onComplete(true) end
        end,
    })
end

--- 删除存档
---@param slotId number
---@param onComplete function|nil  回调 (success)
function SlotSaveSystem.DeleteSlot(slotId, onComplete)
    if slotId == activeSlot then
        print("[SlotSave] Cannot delete active slot")
        if onComplete then onComplete(false) end
        return
    end

    print("[SlotSave] Deleting slot " .. slotId)

    -- 从 meta 移除
    if meta and meta.slots then
        meta.slots[tostring(slotId)] = nil
    end

    -- 构建删除列表
    local batch = clientCloud:BatchSet()
    batch:Delete("s_" .. slotId .. "_head")
    for _, groupName in ipairs(GROUP_NAMES) do
        batch:Delete("s_" .. slotId .. "_" .. groupName)
        -- 保守删除可能的分片后缀
        for i = 0, 9 do
            batch:Delete("s_" .. slotId .. "_" .. groupName .. "_" .. i)
        end
    end
    batch:Set("save_meta", meta)
    batch:Save("delete_slot_" .. slotId, {
        ok = function()
            headCache[slotId] = nil
            print("[SlotSave] Slot " .. slotId .. " deleted")
            if onComplete then onComplete(true) end
        end,
        error = function(code, reason)
            print("[SlotSave] Delete cloud failed: " .. tostring(reason))
            if onComplete then onComplete(false) end
        end,
    })
end

--- 保存并卸载当前存档（切换存档前调用）
---@param onComplete function|nil
function SlotSaveSystem.SaveAndUnload(onComplete)
    if activeSlot <= 0 then
        if onComplete then onComplete(true) end
        return
    end

    -- 立即保存
    SlotSaveSystem.SaveNow()

    -- 重置状态
    local oldSlot = activeSlot
    activeSlot = 0
    saveConfirmed = false
    dirtyTimer = -1
    autoSaveTimer = 0
    playTime = 0

    -- 重新拉取 meta
    clientCloud:Get("save_meta", {
        ok = function(values)
            if values.save_meta and type(values.save_meta) == "table" then
                meta = values.save_meta
            end
            print("[SlotSave] Unloaded slot " .. oldSlot .. ", meta refreshed")
            if onComplete then onComplete(true) end
        end,
        error = function()
            print("[SlotSave] Unload: meta refresh failed (using cached)")
            if onComplete then onComplete(true) end
        end,
    })
end

--- 常规保存（由定时器触发）
function SlotSaveSystem.Save()
    if activeSlot <= 0 or not saveConfirmed then return end
    dirtyTimer = -1
    autoSaveTimer = 0
    DoSave()
end

--- 立即保存（关键事件后调用）
function SlotSaveSystem.SaveNow()
    if activeSlot <= 0 or not saveConfirmed then return end
    dirtyTimer = -1
    autoSaveTimer = 0
    DoSave()
end

--- 标记数据为脏（延迟合并保存）
function SlotSaveSystem.MarkDirty()
    if activeSlot <= 0 or not saveConfirmed then return end
    if dirtyTimer < 0 then
        dirtyTimer = DIRTY_DELAY
    end
end

--- 每帧更新
---@param dt number
function SlotSaveSystem.Update(dt)
    -- Init 重试计时
    if initState == "loading" and initRetryTimer > 0 then
        initRetryTimer = initRetryTimer - dt
        if initRetryTimer <= 0 then
            initRetryTimer = -1
            SlotSaveSystem.Init(initCallback)
        end
        return
    end

    if not saveConfirmed then return end

    -- 累计游戏时长
    playTime = playTime + dt

    -- 脏标记定时器
    if dirtyTimer > 0 then
        dirtyTimer = dirtyTimer - dt
        if dirtyTimer <= 0 then
            dirtyTimer = -1
            DoSave()
            autoSaveTimer = 0  -- 脏保存后重置自动保存计时
        end
    end

    -- 自动保存定时器
    autoSaveTimer = autoSaveTimer + dt
    if autoSaveTimer >= SAVE_INTERVAL then
        autoSaveTimer = 0
        DoSave()
    end

    -- 重试队列
    local now = os.time()
    local i = 1
    while i <= #retryQueue do
        local item = retryQueue[i]
        if now >= item.nextRetryTime then
            item.retryCount = item.retryCount + 1
            if item.retryCount > MAX_RETRY then
                -- 超过最大重试，放弃
                table.remove(retryQueue, i)
                print("[SlotSave] Retry exhausted, giving up")
            else
                -- 执行重试
                table.remove(retryQueue, i)
                item.fn()
            end
        else
            i = i + 1
        end
    end
end

-- ============================================================================
-- 查询 API
-- ============================================================================

--- 获取 meta 数据
---@return table|nil
function SlotSaveSystem.GetMeta()
    return meta
end

--- 获取当前活跃槽位
---@return number  0=未选择
function SlotSaveSystem.GetActiveSlot()
    return activeSlot
end

--- 获取已用槽位数
---@return number
function SlotSaveSystem.GetSlotCount()
    if not meta or not meta.slots then return 0 end
    local count = 0
    for _ in pairs(meta.slots) do
        count = count + 1
    end
    return count
end

--- 获取最大槽位数
---@return number
function SlotSaveSystem.GetMaxSlots()
    return MAX_SLOTS
end

--- 获取累计游戏时长（秒）
---@return number
function SlotSaveSystem.GetPlayTime()
    return playTime
end

--- 存档是否健康
---@return boolean
function SlotSaveSystem.IsSaveHealthy()
    return healthy
end

return SlotSaveSystem
