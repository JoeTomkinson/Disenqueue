local ADDON_NAME, ns = ...

-- ═══════════════════════════════════════════════════════════════════════════════
-- Core.lua — Data model, queue logic, secure action, event handling, slash commands
-- ═══════════════════════════════════════════════════════════════════════════════

ns.ADDON_VERSION = "1.1.0"

-- Spell constants
local DISENCHANT_SPELL_ID = 13262
local PROSPECTING_SPELL_ID = 31252
local MILLING_SPELL_ID = 51005
local DEFAULT_MIN_QUALITY = 2
local DEFAULT_MAX_QUALITY = 4
local MIN_STACK_SIZE = 5
local POST_CAST_COOLDOWN = 0.4

-- Processing modes
ns.MODE_DISENCHANT = "disenchant"
ns.MODE_PROSPECT = "prospect"
ns.MODE_MILL = "mill"

local MODE_DISENCHANT = ns.MODE_DISENCHANT
local MODE_PROSPECT = ns.MODE_PROSPECT
local MODE_MILL = ns.MODE_MILL

-- Spell names used in macros
local SPELL_NAMES = {
    [MODE_DISENCHANT] = "Disenchant",
    [MODE_PROSPECT] = "Prospecting",
    [MODE_MILL] = "Milling",
}

-- Spell IDs for modern API calls
local SPELL_IDS = {
    [MODE_DISENCHANT] = DISENCHANT_SPELL_ID,
    [MODE_PROSPECT] = PROSPECTING_SPELL_ID,
    [MODE_MILL] = MILLING_SPELL_ID,
}

-- Notification categories
local NOTIFY_SCAN = "notifyScan"
local NOTIFY_PROCESS = "notifyProcess"
local NOTIFY_WARNINGS = "notifyWarnings"
local NOTIFY_QUEUE = "notifyQueue"

-- ─── State ───────────────────────────────────────────────────────────────────
ns.queue = {}
ns.isProcessing = false
ns.isCasting = false
ns.castStartTime = 0
ns.castEndTime = 0

local queue = ns.queue
local lastCastSucceeded = 0
local equippedSnapshot = {}
local failStrikes = {}
local MAX_FAIL_STRIKES = 2

-- ─── Callback System ─────────────────────────────────────────────────────────
local callbacks = {}

function ns.RegisterCallback(event, fn)
    if not callbacks[event] then callbacks[event] = {} end
    table.insert(callbacks[event], fn)
end

function ns.FireCallback(event, ...)
    if callbacks[event] then
        for _, fn in ipairs(callbacks[event]) do
            local ok, err = xpcall(fn, function(e) return e .. "\n" .. debugstack(2, 6, 0) end, ...)
            if not ok then
                -- Print error prominently so it's hard to miss
                print("|cffff3333[Disenqueue] ERROR in " .. event .. ":|r " .. tostring(err))
            end
        end
    end
end

-- ─── Utility Functions ───────────────────────────────────────────────────────

function ns.Chat(message, category)
    if category and DisenqueueDB then
        if DisenqueueDB[category] == false then return end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0WDQ|r: " .. message)
end

local chat = ns.Chat

function ns.AnchorTooltip(owner)
    local centerX = owner:GetCenter()
    local screenWidth = GetScreenWidth()
    if centerX and centerX > screenWidth / 2 then
        GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    else
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    end
end

local function getContainerNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag)
    end
    if GetContainerNumSlots then
        return GetContainerNumSlots(bag)
    end
    return 0
end

local function getContainerItemLink(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bag, slot)
    end
    if GetContainerItemLink then
        return GetContainerItemLink(bag, slot)
    end
end
ns.GetContainerItemLink = getContainerItemLink

local function getContainerItemCount(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        return info and info.stackCount or 0
    end
    if GetContainerItemInfo then
        local _, count = GetContainerItemInfo(bag, slot)
        return count or 0
    end
    return 0
end

local function parseItemID(itemLink)
    if not itemLink then return nil end
    local id = itemLink:match("item:(%d+)")
    if not id then return nil end
    return tonumber(id)
end
ns.ParseItemID = parseItemID

local function isProtected(itemID)
    return itemID and DisenqueueDB.protectedItemIDs[itemID] ~= nil
end
ns.IsProtected = isProtected

-- ─── DB Normalization ────────────────────────────────────────────────────────

function ns.NormalizeDB()
    if type(DisenqueueDB) ~= "table" then
        DisenqueueDB = {}
    end
    if type(DisenqueueDB.minQuality) ~= "number" then
        DisenqueueDB.minQuality = DEFAULT_MIN_QUALITY
    end
    if type(DisenqueueDB.maxQuality) ~= "number" then
        DisenqueueDB.maxQuality = DEFAULT_MAX_QUALITY
    end
    if type(DisenqueueDB.protectedItemIDs) ~= "table" then
        DisenqueueDB.protectedItemIDs = {}
    end
    if type(DisenqueueDB.processKey) ~= "string" then
        DisenqueueDB.processKey = "SCROLLWHEEL"
    end
    if type(DisenqueueDB.notifyScan) ~= "boolean" then
        DisenqueueDB.notifyScan = true
    end
    if type(DisenqueueDB.notifyProcess) ~= "boolean" then
        DisenqueueDB.notifyProcess = true
    end
    if type(DisenqueueDB.notifyWarnings) ~= "boolean" then
        DisenqueueDB.notifyWarnings = true
    end
    if type(DisenqueueDB.notifyQueue) ~= "boolean" then
        DisenqueueDB.notifyQueue = true
    end
    if type(DisenqueueDB.soulboundOnly) ~= "boolean" then
        DisenqueueDB.soulboundOnly = false
    end
    if type(DisenqueueDB.lesserProfsEnabled) ~= "boolean" then
        DisenqueueDB.lesserProfsEnabled = false
    end
    if type(DisenqueueDB.prospectingEnabled) ~= "boolean" then
        DisenqueueDB.prospectingEnabled = false
    end
    if type(DisenqueueDB.millingEnabled) ~= "boolean" then
        DisenqueueDB.millingEnabled = false
    end
    -- Migrate old boolean-only entries
    for itemID, val in pairs(DisenqueueDB.protectedItemIDs) do
        if val == true then
            DisenqueueDB.protectedItemIDs[itemID] = { name = tostring(itemID) }
        end
    end
end

-- ─── Item Eligibility ────────────────────────────────────────────────────────

local function isItemBound(bag, slot)
    if C_Item and C_Item.IsBound then
        local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
        if itemLocation and itemLocation:IsValid() then
            return C_Item.IsBound(itemLocation)
        end
    end
    if not _G.WDQ_ScanTip then
        CreateFrame("GameTooltip", "WDQ_ScanTip", nil, "GameTooltipTemplate")
    end
    local tip = _G.WDQ_ScanTip
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tip:ClearLines()
    tip:SetBagItem(bag, slot)
    for i = 2, tip:NumLines() do
        local text = _G["WDQ_ScanTipTextLeft" .. i]
        if text then
            local line = text:GetText()
            if line == ITEM_SOULBOUND or line == ITEM_BNETACCOUNTBOUND or line == ITEM_ACCOUNTBOUND then
                return true
            end
        end
    end
    return false
end

local function isItemRefundable(bag, slot)
    if not bag or not slot then return false end
    if C_Item and C_Item.CanBeRefunded then
        local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
        if itemLocation and itemLocation:IsValid() then
            return C_Item.CanBeRefunded(itemLocation)
        end
    end
    return false
end

local function hasCannotDisenchantLine(bag, slot)
    if not bag or not slot then return false end
    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local data = C_TooltipInfo.GetBagItem(bag, slot)
        if data and data.lines then
            for _, line in ipairs(data.lines) do
                if line.type and line.type == 41 and line.leftText
                    and line.leftText:find("[Dd]isenchant") then
                    return true
                end
                if line.leftText then
                    local text = line.leftText
                    if text == (_G.ITEM_DISENCHANT_NOT_DISENCHANTABLE or "")
                        or text == (_G.ERR_CANT_BE_DISENCHANTED or "")
                        or text == "Cannot be disenchanted"
                        or text == "Item cannot be disenchanted" then
                        return true
                    end
                    if line.leftColor and line.leftColor.r and line.leftColor.r > 0.9
                        and line.leftColor.g < 0.2 and line.leftColor.b < 0.2 then
                        if text:find("[Dd]isenchant") then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end
    if not _G.WDQ_ScanTip then
        CreateFrame("GameTooltip", "WDQ_ScanTip", nil, "GameTooltipTemplate")
    end
    local tip = _G.WDQ_ScanTip
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tip:ClearLines()
    tip:SetBagItem(bag, slot)
    for i = 2, tip:NumLines() do
        local textObj = _G["WDQ_ScanTipTextLeft" .. i]
        if textObj then
            local line = textObj:GetText()
            if not line then break end
            if line == (_G.ITEM_DISENCHANT_NOT_DISENCHANTABLE or "")
                or line == (_G.ERR_CANT_BE_DISENCHANTED or "")
                or line == "Cannot be disenchanted"
                or line == "Item cannot be disenchanted" then
                return true
            end
            local r, g, b = textObj:GetTextColor()
            if r and r > 0.9 and g < 0.2 and b < 0.2 and line:find("[Dd]isenchant") then
                return true
            end
        end
    end
    return false
end

local function isDisenchantCandidate(itemLink, bag, slot)
    local itemName, _, itemQuality, _, _, _, _, _, _, _, _, classID, subClassID, bindType = GetItemInfo(itemLink)
    if not itemName or not itemQuality or not classID then
        return false
    end
    if itemQuality < DisenqueueDB.minQuality or itemQuality > DisenqueueDB.maxQuality then
        return false
    end
    if bindType and bindType == 4 then
        return false
    end
    local isValidClass = (classID == 2) or (classID == 4) or (classID == 3 and subClassID == 11)
    if not isValidClass then
        return false
    end
    local itemID = parseItemID(itemLink)
    if isProtected(itemID) then
        return false
    end
    if DisenqueueDB.soulboundOnly and bag and slot then
        if not isItemBound(bag, slot) then
            return false
        end
    end
    if isItemRefundable(bag, slot) then
        return false
    end
    if hasCannotDisenchantLine(bag, slot) then
        return false
    end
    return true
end
ns.IsDisenchantCandidate = isDisenchantCandidate

local function isProspectCandidate(itemLink, bag, slot)
    if not DisenqueueDB.lesserProfsEnabled or not DisenqueueDB.prospectingEnabled then
        return false
    end
    local itemName, _, _, _, _, _, _, _, _, _, _, classID, subClassID = GetItemInfo(itemLink)
    if not itemName or not classID then return false end
    if classID ~= 7 or subClassID ~= 7 then return false end
    if getContainerItemCount(bag, slot) < MIN_STACK_SIZE then return false end
    local itemID = parseItemID(itemLink)
    if isProtected(itemID) then return false end
    return true
end

local function isMillingCandidate(itemLink, bag, slot)
    if not DisenqueueDB.lesserProfsEnabled or not DisenqueueDB.millingEnabled then
        return false
    end
    local itemName, _, _, _, _, _, _, _, _, _, _, classID, subClassID = GetItemInfo(itemLink)
    if not itemName or not classID then return false end
    if classID ~= 7 or subClassID ~= 9 then return false end
    if getContainerItemCount(bag, slot) < MIN_STACK_SIZE then return false end
    local itemID = parseItemID(itemLink)
    if isProtected(itemID) then return false end
    return true
end

-- ─── Dust Estimation ─────────────────────────────────────────────────────────
-- Simple quality-based average dust value (approximate market estimates)
local DUST_VALUE_BY_QUALITY = {
    [0] = 0,       -- Poor
    [1] = 0,       -- Common
    [2] = 1200,    -- Uncommon: ~12g in dust/essences
    [3] = 3500,    -- Rare: ~35g in shards/crystals
    [4] = 8000,    -- Epic: ~80g in crystals
}

function ns.GetDustEstimate()
    local total = 0
    for _, entry in ipairs(queue) do
        if entry.mode == MODE_DISENCHANT then
            local _, _, itemQuality = GetItemInfo(entry.itemID or 0)
            if itemQuality then
                total = total + (DUST_VALUE_BY_QUALITY[itemQuality] or 0)
            end
        end
    end
    return total
end

function ns.FormatGold(copperAmount)
    if copperAmount >= 10000 then
        return ("%.1fk"):format(copperAmount / 10000)
    elseif copperAmount >= 100 then
        return ("%dg"):format(math.floor(copperAmount / 100))
    else
        return ("%dc"):format(copperAmount)
    end
end

-- ─── Queue Operations ────────────────────────────────────────────────────────

local function queueItem(bag, slot, itemLink, mode)
    local itemID = parseItemID(itemLink)
    local itemName = GetItemInfo(itemLink)
    table.insert(queue, {
        bag = bag,
        slot = slot,
        itemID = itemID,
        itemName = itemName or itemLink,
        mode = mode or MODE_DISENCHANT,
    })
end

local function clearQueue()
    wipe(queue)
    ns.isProcessing = false
    ns.FireCallback("QUEUE_UPDATED")
end

function ns.RebuildQueue()
    clearQueue()
    wipe(failStrikes)

    local backpackStart = _G.BACKPACK_CONTAINER or 0
    local backpackEnd = _G.NUM_BAG_SLOTS or 4

    for bag = backpackStart, backpackEnd do
        local slots = getContainerNumSlots(bag)
        for slot = 1, slots do
            local itemLink = getContainerItemLink(bag, slot)
            if itemLink and isDisenchantCandidate(itemLink, bag, slot) then
                queueItem(bag, slot, itemLink, MODE_DISENCHANT)
            end
        end
    end

    if DisenqueueDB.lesserProfsEnabled and DisenqueueDB.prospectingEnabled then
        for bag = backpackStart, backpackEnd do
            local slots = getContainerNumSlots(bag)
            for slot = 1, slots do
                local itemLink = getContainerItemLink(bag, slot)
                if itemLink and isProspectCandidate(itemLink, bag, slot) then
                    queueItem(bag, slot, itemLink, MODE_PROSPECT)
                end
            end
        end
    end

    if DisenqueueDB.lesserProfsEnabled and DisenqueueDB.millingEnabled then
        for bag = backpackStart, backpackEnd do
            local slots = getContainerNumSlots(bag)
            for slot = 1, slots do
                local itemLink = getContainerItemLink(bag, slot)
                if itemLink and isMillingCandidate(itemLink, bag, slot) then
                    queueItem(bag, slot, itemLink, MODE_MILL)
                end
            end
        end
    end

    ns.FireCallback("QUEUE_UPDATED")
    chat(("Scanned bags: %d item(s) found. Review and click 'Start' when ready."):format(#queue), NOTIFY_SCAN)
end

function ns.ClearQueue()
    clearQueue()
    chat("Queue cleared.")
end

function ns.RemoveFromQueue(index)
    if index and index <= #queue then
        local removed = table.remove(queue, index)
        chat(("Removed: %s"):format(removed.itemName or "Unknown"), NOTIFY_QUEUE)
        ns.FireCallback("QUEUE_UPDATED")
    end
end

function ns.HideFromQueue(index)
    if index and index <= #queue then
        local removed = table.remove(queue, index)
        chat(("Hidden: %s"):format(removed.itemName or "Unknown"), NOTIFY_QUEUE)
        ns.FireCallback("QUEUE_UPDATED")
    end
end

function ns.ToggleLock(itemID, itemName)
    if not itemID then return end
    if DisenqueueDB.protectedItemIDs[itemID] then
        DisenqueueDB.protectedItemIDs[itemID] = nil
        chat(("|cffff6060Unlocked:|r %s"):format(itemName or tostring(itemID)), NOTIFY_QUEUE)
    else
        DisenqueueDB.protectedItemIDs[itemID] = { name = itemName or tostring(itemID) }
        chat(("|cff60ff60Locked:|r %s (will never be queued)"):format(itemName or tostring(itemID)), NOTIFY_QUEUE)
        for i = #queue, 1, -1 do
            if queue[i].itemID == itemID then
                table.remove(queue, i)
            end
        end
    end
    ns.FireCallback("QUEUE_UPDATED")
    ns.FireCallback("LOCKED_UPDATED")
end

function ns.LockFromQueue(index)
    if not index or index > #queue then return end
    local entry = queue[index]
    if entry and entry.itemID then
        DisenqueueDB.protectedItemIDs[entry.itemID] = { name = entry.itemName or "Unknown" }
        table.remove(queue, index)
        chat(("|cff60ff60Locked:|r %s"):format(entry.itemName or "Unknown"), NOTIFY_QUEUE)
        ns.FireCallback("QUEUE_UPDATED")
        ns.FireCallback("LOCKED_UPDATED")
    end
end

-- ─── Secure Action Button ────────────────────────────────────────────────────

local secureBtn = CreateFrame("Button", "WDQ_SecureProcessButton", UIParent, "SecureActionButtonTemplate")
secureBtn:SetSize(1, 1)
secureBtn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100)
secureBtn:SetAttribute("type", "macro")
secureBtn:SetAttribute("macrotext", "")
secureBtn:RegisterForClicks("AnyDown")

local function clearSecureBtn()
    secureBtn:SetAttribute("macrotext", "")
end

local function isSpellReady(spellName, mode)
    if UnitCastingInfo("player") or UnitChannelInfo("player") then
        return false
    end
    local spellID = mode and SPELL_IDS[mode] or DISENCHANT_SPELL_ID
    if C_Spell and C_Spell.IsSpellUsable then
        local isUsable = C_Spell.IsSpellUsable(spellID)
        if not isUsable then return false end
    end
    if C_Spell and C_Spell.GetSpellCooldown then
        local cdInfo = C_Spell.GetSpellCooldown(spellID)
        if cdInfo and cdInfo.startTime and cdInfo.startTime > 0 and cdInfo.duration > 0 then
            return false
        end
    else
        local start, duration = GetSpellCooldown(spellName)
        if start and start > 0 and duration > 0 then
            return false
        end
    end
    return true
end

secureBtn:SetScript("PreClick", function(self)
    if InCombatLockdown() then
        clearSecureBtn()
        return
    end
    if not ns.isProcessing or #queue == 0 then
        clearSecureBtn()
        return
    end
    if ns.isCasting then
        clearSecureBtn()
        return
    end
    if GetTime() - lastCastSucceeded < POST_CAST_COOLDOWN then
        clearSecureBtn()
        return
    end
    ClearCursor()
    if GetCursorInfo() then
        clearSecureBtn()
        return
    end
    if GetNumLootItems and GetNumLootItems() > 0 then
        clearSecureBtn()
        return
    end
    if LootFrame and LootFrame:IsShown() then
        clearSecureBtn()
        return
    end
    if SpellIsTargeting and SpellIsTargeting() then
        SpellStopTargeting()
        clearSecureBtn()
        return
    end
    local nextItem = queue[1]
    if not nextItem then
        clearSecureBtn()
        return
    end
    local spellName = SPELL_NAMES[nextItem.mode] or SPELL_NAMES[MODE_DISENCHANT]
    if not isSpellReady(spellName, nextItem.mode) then
        clearSecureBtn()
        return
    end
    local currentLink = getContainerItemLink(nextItem.bag, nextItem.slot)
    if not currentLink then
        clearSecureBtn()
        chat("Slot empty - skipping. Press again to continue.", NOTIFY_WARNINGS)
        table.remove(queue, 1)
        C_Timer.After(0.1, function() ns.UpdateSecureButton(); ns.FireCallback("QUEUE_UPDATED") end)
        return
    end
    local currentID = parseItemID(currentLink)
    if currentID ~= nextItem.itemID then
        clearSecureBtn()
        chat("Item changed in slot - skipping to prevent accidental disenchant.", NOTIFY_WARNINGS)
        table.remove(queue, 1)
        C_Timer.After(0.1, function() ns.UpdateSecureButton(); ns.FireCallback("QUEUE_UPDATED") end)
        return
    end
    if nextItem.mode == MODE_DISENCHANT then
        if not isDisenchantCandidate(currentLink, nextItem.bag, nextItem.slot) then
            clearSecureBtn()
            chat("Item no longer valid for disenchanting - skipping.", NOTIFY_WARNINGS)
            table.remove(queue, 1)
            C_Timer.After(0.1, function() ns.UpdateSecureButton(); ns.FireCallback("QUEUE_UPDATED") end)
            return
        end
    end
    local macro = ("/cast %s\n/use %d %d"):format(spellName, nextItem.bag, nextItem.slot)
    self:SetAttribute("macrotext", macro)
end)

secureBtn:SetScript("PostClick", function(self)
    if not InCombatLockdown() then
        clearSecureBtn()
    end
end)

function ns.UpdateSecureButton()
    if InCombatLockdown() then return end
    if not ns.isProcessing or #queue == 0 then
        clearSecureBtn()
        return
    end
    local nextItem = queue[1]
    if not nextItem then
        clearSecureBtn()
        return
    end
    local currentLink = getContainerItemLink(nextItem.bag, nextItem.slot)
    if not currentLink then
        table.remove(queue, 1)
        chat("Queued slot is empty. Skipping.", NOTIFY_WARNINGS)
        ns.FireCallback("QUEUE_UPDATED")
        ns.UpdateSecureButton()
        return
    end
    local currentID = parseItemID(currentLink)
    if currentID ~= nextItem.itemID then
        table.remove(queue, 1)
        chat("Queued item changed. Skipping mismatched slot.", NOTIFY_WARNINGS)
        ns.FireCallback("QUEUE_UPDATED")
        ns.UpdateSecureButton()
        return
    end
    local spellName = SPELL_NAMES[nextItem.mode] or SPELL_NAMES[MODE_DISENCHANT]
    local macro = ("/cast %s\n/use %d %d"):format(spellName, nextItem.bag, nextItem.slot)
    secureBtn:SetAttribute("macrotext", macro)
end

-- ─── Key Binding ─────────────────────────────────────────────────────────────

local function bindProcessKey()
    if InCombatLockdown() then return end
    local owner = _G.WDQ_QueueFrame or secureBtn
    local key = DisenqueueDB.processKey or "SCROLLWHEEL"
    ClearOverrideBindings(owner)
    if key == "SCROLLWHEEL" then
        SetOverrideBindingClick(owner, true, "MOUSEWHEELUP", "WDQ_SecureProcessButton")
        SetOverrideBindingClick(owner, true, "MOUSEWHEELDOWN", "WDQ_SecureProcessButton")
    else
        SetOverrideBindingClick(owner, true, key, "WDQ_SecureProcessButton")
    end
end
ns.BindProcessKey = bindProcessKey

local function unbindProcessKey()
    if InCombatLockdown() then return end
    local owner = _G.WDQ_QueueFrame or secureBtn
    ClearOverrideBindings(owner)
end
ns.UnbindProcessKey = unbindProcessKey

-- ─── Processing Control ──────────────────────────────────────────────────────

function ns.StartProcessing()
    if #queue == 0 then
        chat("Nothing in queue. Scan bags first.", NOTIFY_PROCESS)
        return
    end
    if InCombatLockdown() then
        chat("Cannot start while in combat.", NOTIFY_WARNINGS)
        return
    end
    ns.isProcessing = true
    lastCastSucceeded = 0
    wipe(equippedSnapshot)
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link then
            equippedSnapshot[slot] = parseItemID(link)
        end
    end
    chat(("Processing started! Use your bound key to process %d item(s)."):format(#queue), NOTIFY_PROCESS)
    ns.UpdateSecureButton()
    bindProcessKey()
    ns.FireCallback("STATE_CHANGED")
end

function ns.StopProcessing()
    ns.isProcessing = false
    unbindProcessKey()
    clearSecureBtn()
    chat("Processing stopped. You can review/edit the queue.", NOTIFY_PROCESS)
    ns.FireCallback("STATE_CHANGED")
end

local function advanceQueue()
    if not ns.isProcessing then return end
    if #queue == 0 then return end

    local entry = queue[1]
    local mode = entry and entry.mode or MODE_DISENCHANT

    if entry and entry.itemID then
        failStrikes[tostring(entry.itemID)] = nil
    end

    if mode == MODE_PROSPECT or mode == MODE_MILL then
        local remaining = getContainerItemCount(entry.bag, entry.slot)
        if remaining >= MIN_STACK_SIZE then
            local modeLabel = (mode == MODE_PROSPECT) and "Prospected" or "Milled"
            chat(("%s: %s (%d remaining)"):format(modeLabel, entry.itemName or "Unknown", remaining), NOTIFY_PROCESS)
            if not InCombatLockdown() then
                ns.UpdateSecureButton()
                ns.FireCallback("QUEUE_UPDATED")
            end
            return
        end
        local modeLabel = (mode == MODE_PROSPECT) and "Prospected" or "Milled"
        table.remove(queue, 1)
        chat(("%s: %s (stack depleted)"):format(modeLabel, entry.itemName or "Unknown"), NOTIFY_PROCESS)
    else
        table.remove(queue, 1)
        chat(("Disenchanted: %s"):format(entry.itemName or "Unknown"), NOTIFY_PROCESS)
    end

    if #queue == 0 then
        ns.isProcessing = false
        unbindProcessKey()
        clearSecureBtn()
        chat("Queue complete!", NOTIFY_PROCESS)
        ns.FireCallback("STATE_CHANGED")
        return
    end

    if not InCombatLockdown() then
        ns.UpdateSecureButton()
        ns.FireCallback("QUEUE_UPDATED")
    end
end

-- ─── Progress Tracking ───────────────────────────────────────────────────────

local processStartCount = 0
local processStartTime = 0

function ns.GetProgress()
    local total = processStartCount
    local done = total - #queue
    if done < 0 then done = 0 end
    local eta = 0
    if done > 0 and #queue > 0 then
        local elapsed = GetTime() - processStartTime
        local avgTime = elapsed / done
        eta = avgTime * #queue
    end
    return { done = done, total = total, etaSeconds = eta }
end

-- ─── Export / Import ─────────────────────────────────────────────────────────

local EXPORT_PREFIX = "!WDQ:1!"

function ns.ExportLockedList()
    local items = {}
    for itemID, entry in pairs(DisenqueueDB.protectedItemIDs) do
        local name = (type(entry) == "table" and entry.name) or tostring(itemID)
        local isAuto = (type(entry) == "table" and entry.autoProtected) or false
        table.insert(items, { id = itemID, name = name, auto = isAuto })
    end
    if #items == 0 then
        chat("No locked items to export.", NOTIFY_QUEUE)
        return nil
    end
    local exportTable = { version = 1, items = items }
    local ok, serialized = pcall(C_EncodingUtil.SerializeCBOR, exportTable)
    if not ok then
        chat("Export failed: serialization error.", NOTIFY_WARNINGS)
        return nil
    end
    local compressed = C_EncodingUtil.CompressString(serialized, Enum.CompressionMethod.Deflate, Enum.CompressionLevel.OptimizeForSize)
    local encoded = C_EncodingUtil.EncodeBase64(compressed)
    return EXPORT_PREFIX .. encoded
end

function ns.ImportLockedList(inputStr)
    local version, payload = inputStr:match("^!WDQ:(%d+)!(.+)$")
    if not version or not payload then
        return false, "Invalid format (missing !WDQ: prefix)"
    end
    version = tonumber(version)
    if version ~= 1 then
        return false, "Unsupported version: " .. tostring(version)
    end
    local decoded = C_EncodingUtil.DecodeBase64(payload)
    if not decoded or decoded == "" then
        return false, "Failed to decode Base64 data"
    end
    local ok, decompressed = pcall(C_EncodingUtil.DecompressString, decoded, Enum.CompressionMethod.Deflate)
    if not ok or not decompressed then
        return false, "Failed to decompress data"
    end
    local ok2, data = pcall(C_EncodingUtil.DeserializeCBOR, decompressed)
    if not ok2 or type(data) ~= "table" then
        return false, "Failed to deserialize data"
    end
    if type(data.items) ~= "table" then
        return false, "Invalid data structure (no items)"
    end
    local added = 0
    for _, item in ipairs(data.items) do
        if type(item.id) == "number" and type(item.name) == "string" then
            local entry = { name = item.name }
            if item.auto then entry.autoProtected = true end
            if not DisenqueueDB.protectedItemIDs[item.id] then
                added = added + 1
            end
            DisenqueueDB.protectedItemIDs[item.id] = entry
        end
    end
    ns.FireCallback("LOCKED_UPDATED")
    local total = #data.items
    return true, ("Imported %d item(s) (%d new)"):format(total, added)
end

function ns.GetExportByteCount(exportStr)
    return exportStr and #exportStr or 0
end

-- ─── Bag Click Hooks ─────────────────────────────────────────────────────────

local function isItemInQueue(bag, slot)
    for i, entry in ipairs(queue) do
        if entry.bag == bag and entry.slot == slot then
            return i
        end
    end
    return nil
end

local function toggleQueueItem(bag, slot)
    local itemLink = getContainerItemLink(bag, slot)
    if not itemLink then return end

    local index = isItemInQueue(bag, slot)
    if index then
        local removed = table.remove(queue, index)
        chat(("Removed from queue: %s"):format(removed.itemName or "Unknown"), NOTIFY_QUEUE)
    else
        local itemName, _, itemQuality, _, _, _, _, _, _, _, _, classID = GetItemInfo(itemLink)
        if not itemName then
            chat("Item info not available. Try again.")
            return
        end
        local itemID = parseItemID(itemLink)
        if isProtected(itemID) then
            chat(("Item %s is protected."):format(itemName), NOTIFY_WARNINGS)
            return
        end
        table.insert(queue, {
            bag = bag,
            slot = slot,
            itemID = itemID,
            itemName = itemName,
            mode = MODE_DISENCHANT,
        })
        local qualityColor = ITEM_QUALITY_COLORS[itemQuality]
        local colorStr = qualityColor and ("|cff%02x%02x%02x"):format(qualityColor.r * 255, qualityColor.g * 255, qualityColor.b * 255) or "|cffffffff"
        chat(("Added to queue: %s%s|r"):format(colorStr, itemName), NOTIFY_QUEUE)
    end
    ns.FireCallback("QUEUE_UPDATED")

    if _G.WDQ_QueueFrame and not _G.WDQ_QueueFrame:IsShown() then
        _G.WDQ_QueueFrame:Show()
        DisenqueueDB.showUI = true
    end
end

local function toggleLockItem(bag, slot)
    local itemLink = getContainerItemLink(bag, slot)
    if not itemLink then return end
    local itemID = parseItemID(itemLink)
    if not itemID then return end
    local itemName = GetItemInfo(itemLink) or "Unknown"
    ns.ToggleLock(itemID, itemName)
end

function ns.HookBagClicks()
    local function hookModernBagButton(button)
        if button and not button.wdqHooked then
            button:HookScript("OnClick", function(self, mouseButton)
                if IsAltKeyDown() and mouseButton == "LeftButton" then
                    local bag = self.GetBagID and self:GetBagID() or (self:GetParent() and self:GetParent():GetID())
                    local slot = self.GetID and self:GetID()
                    if bag and slot then
                        toggleQueueItem(bag, slot)
                    end
                end
            end)
            button.wdqHooked = true
        end
    end

    for i = 1, 13 do
        local containerFrame = _G["ContainerFrame" .. i]
        if containerFrame then
            for j = 1, 36 do
                local itemButton = _G["ContainerFrame" .. i .. "Item" .. j]
                if itemButton then
                    hookModernBagButton(itemButton)
                end
            end
        end
    end

    if ContainerFrameCombinedBags and ContainerFrameCombinedBags.Items then
        for _, itemButton in pairs(ContainerFrameCombinedBags.Items) do
            hookModernBagButton(itemButton)
        end
    end

    if EventRegistry then
        EventRegistry:RegisterCallback("ContainerFrame.OpenBag", function()
            C_Timer.After(0.1, function()
                for i = 1, 13 do
                    local containerFrame = _G["ContainerFrame" .. i]
                    if containerFrame then
                        for j = 1, 36 do
                            local itemButton = _G["ContainerFrame" .. i .. "Item" .. j]
                            if itemButton then
                                hookModernBagButton(itemButton)
                            end
                        end
                    end
                end
                if ContainerFrameCombinedBags and ContainerFrameCombinedBags.Items then
                    for _, itemButton in pairs(ContainerFrameCombinedBags.Items) do
                        hookModernBagButton(itemButton)
                    end
                end
            end)
        end)
    end
end

-- ─── Event Handler ───────────────────────────────────────────────────────────

local eventFrame = CreateFrame("Frame", "WDQ_EventFrame")

local function isTrackedSpell(spellID)
    if spellID == DISENCHANT_SPELL_ID then return true end
    if spellID == PROSPECTING_SPELL_ID then return true end
    if spellID == MILLING_SPELL_ID then return true end
    if not ns.isProcessing then return false end
    local name
    if C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(spellID)
    elseif GetSpellInfo then
        name = GetSpellInfo(spellID)
    end
    if not name then return false end
    for _, tracked in pairs(SPELL_NAMES) do
        if name == tracked then return true end
    end
    return false
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
eventFrame:RegisterEvent("UI_ERROR_MESSAGE")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

eventFrame:SetScript("OnEvent", function(_, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        ns.NormalizeDB()
        ns.HookBagClicks()
        ns.FireCallback("ADDON_LOADED")
        chat(("v%s loaded. Alt+Left-Click to queue."):format(ns.ADDON_VERSION))
        return
    end

    if event == "BAG_UPDATE_DELAYED" then
        if ns.isProcessing and not InCombatLockdown() then
            ns.UpdateSecureButton()
        end
        ns.FireCallback("QUEUE_UPDATED")
        return
    end

    if event == "PLAYER_EQUIPMENT_CHANGED" then
        if ns.isProcessing then
            local slot = arg1
            local expectedID = equippedSnapshot[slot]
            local currentLink = GetInventoryItemLink("player", slot)
            local currentID = currentLink and parseItemID(currentLink)
            if currentID ~= expectedID then
                local slotName = (GetInventorySlotInfo and select(1, GetInventorySlotInfo(slot))) or ("Slot " .. slot)
                local itemName = currentLink and (GetItemInfo(currentLink) or currentLink) or "empty"
                chat(("|cffff3333EQUIPMENT CHANGE DETECTED!|r %s is now: %s"):format(
                    tostring(slotName), tostring(itemName)), NOTIFY_WARNINGS)
                chat("|cffff3333Processing halted as a safety precaution.|r Check your gear!", NOTIFY_WARNINGS)
                ns.StopProcessing()
            end
        end
        return
    end

    if event == "UI_ERROR_MESSAGE" then
        if ns.isProcessing and #queue > 0 then
            local message = select(1, ...)
            local errText = _G.ERR_CANT_BE_DISENCHANTED or "Item cannot be disenchanted"
            if message and (message == errText or message:find("[Dd]isenchant")) then
                local entry = queue[1]
                if entry then
                    chat(("|cffff3333%s|r cannot be disenchanted (server rejected). Skipping."):format(
                        entry.itemName or "Unknown"), NOTIFY_WARNINGS)
                    local strikeKey = tostring(entry.itemID or 0)
                    failStrikes[strikeKey] = nil
                    table.remove(queue, 1)
                    if entry.itemID and not isProtected(entry.itemID) then
                        DisenqueueDB.protectedItemIDs[entry.itemID] = { name = entry.itemName or tostring(entry.itemID), autoProtected = true }
                        chat(("|cff888888Auto-protected item %d (%s) to prevent future queueing.|r"):format(
                            entry.itemID, entry.itemName or "Unknown"), NOTIFY_WARNINGS)
                    end
                    C_Timer.After(0.1, function() ns.UpdateSecureButton(); ns.FireCallback("QUEUE_UPDATED") end)
                end
            end
        end
        return
    end

    -- Spellcast tracking
    if arg1 ~= "player" then return end

    if event == "UNIT_SPELLCAST_START" then
        local spellID = select(2, ...)
        if isTrackedSpell(spellID) then
            local _, _, _, startMS, endMS = UnitCastingInfo("player")
            if startMS and endMS then
                ns.castStartTime = startMS / 1000
                ns.castEndTime = endMS / 1000
                ns.isCasting = true
                ns.FireCallback("CAST_START")
            end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local spellID = select(2, ...)
        if isTrackedSpell(spellID) then
            ns.isCasting = false
            lastCastSucceeded = GetTime()
            ns.FireCallback("CAST_STOP")
            advanceQueue()
        end
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET"
        or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local spellID = select(2, ...)
        if isTrackedSpell(spellID) then
            ns.isCasting = false
            ns.FireCallback("CAST_STOP")
            if ns.isProcessing and #queue > 0 then
                local entry = queue[1]
                if entry then
                    local strikeKey = tostring(entry.itemID or 0)
                    failStrikes[strikeKey] = (failStrikes[strikeKey] or 0) + 1
                    if failStrikes[strikeKey] >= MAX_FAIL_STRIKES then
                        chat(("|cffff8800Auto-skipping|r %s — failed %d times (likely non-disenchantable)."):format(
                            entry.itemName or "Unknown", failStrikes[strikeKey]), NOTIFY_WARNINGS)
                        failStrikes[strikeKey] = nil
                        table.remove(queue, 1)
                        if entry.itemID and not isProtected(entry.itemID) then
                            DisenqueueDB.protectedItemIDs[entry.itemID] = { name = entry.itemName or tostring(entry.itemID), autoProtected = true }
                            chat(("|cff888888Auto-protected item %d (%s) to prevent future queueing.|r"):format(
                                entry.itemID, entry.itemName or "Unknown"), NOTIFY_WARNINGS)
                        end
                        C_Timer.After(0.1, function() ns.UpdateSecureButton(); ns.FireCallback("QUEUE_UPDATED") end)
                    else
                        chat(("Cast failed — scroll again to retry (%d/%d before auto-skip)."):format(
                            failStrikes[strikeKey], MAX_FAIL_STRIKES), NOTIFY_WARNINGS)
                    end
                end
            end
        end
    elseif event == "UNIT_SPELLCAST_STOP" then
        local spellID = select(2, ...)
        if isTrackedSpell(spellID) then
            ns.isCasting = false
            ns.FireCallback("CAST_STOP")
        end
    end
end)

-- Track process start for progress calculation
ns.RegisterCallback("STATE_CHANGED", function()
    if ns.isProcessing then
        processStartCount = #queue
        processStartTime = GetTime()
    end
end)

-- ─── Slash Commands ──────────────────────────────────────────────────────────

local function listQueue()
    if #queue == 0 then
        chat("Queue is empty.")
        return
    end
    chat(("Queued item(s): %d"):format(#queue))
    for index, entry in ipairs(queue) do
        chat(("%d. %s"):format(index, entry.itemName or "Unknown item"))
    end
end

local function parseProtectArgument(raw)
    if not raw or raw == "" then return nil end
    local itemID = tonumber(raw)
    if itemID then return itemID end
    return parseItemID(raw)
end

local function handleProtectCommand(action, arg)
    if action == "list" then
        local count = 0
        for _ in pairs(DisenqueueDB.protectedItemIDs) do count = count + 1 end
        if count == 0 then
            chat("No protected item IDs configured.")
            return
        end
        chat(("Protected item IDs (%d):"):format(count))
        for itemID in pairs(DisenqueueDB.protectedItemIDs) do
            chat(tostring(itemID))
        end
        return
    end
    local itemID = parseProtectArgument(arg)
    if not itemID then
        chat("Usage: /wdq protect add|remove <itemID or itemLink>")
        return
    end
    if action == "add" then
        DisenqueueDB.protectedItemIDs[itemID] = { name = tostring(itemID) }
        chat(("Added %d to protected list."):format(itemID))
        ns.FireCallback("LOCKED_UPDATED")
        return
    end
    if action == "remove" then
        DisenqueueDB.protectedItemIDs[itemID] = nil
        chat(("Removed %d from protected list."):format(itemID))
        ns.FireCallback("LOCKED_UPDATED")
        return
    end
    chat("Usage: /wdq protect add|remove|list")
end

local function setQualityRange(minQ, maxQ)
    local minQuality = tonumber(minQ)
    local maxQuality = tonumber(maxQ)
    if not minQuality or not maxQuality then
        chat("Usage: /wdq quality <min> <max> (0-6)")
        return
    end
    if minQuality < 0 or maxQuality > 6 or minQuality > maxQuality then
        chat("Invalid quality range. Expected values between 0 and 6.")
        return
    end
    DisenqueueDB.minQuality = minQuality
    DisenqueueDB.maxQuality = maxQuality
    chat(("Queue quality filter set to %d-%d."):format(minQuality, maxQuality))
end

SLASH_DISENQUEUE1 = "/wdq"
SlashCmdList.DISENQUEUE = function(input)
    local command, rest = input:match("^(%S*)%s*(.-)$")
    command = (command or ""):lower()

    if command == "" or command == "help" then
        chat("/wdq build - scan bags and populate queue")
        chat("/wdq start - begin processing (enables scroll to disenchant)")
        chat("/wdq stop - pause processing")
        chat("/wdq next - process one queued item")
        chat("/wdq list - print queued items")
        chat("/wdq clear - clear current queue")
        chat("/wdq quality <min> <max> - set item quality filter")
        chat("/wdq protect add|remove|list <itemID|itemLink>")
        chat("/wdq ui - toggle queue window")
        return
    end

    if command == "build" then ns.RebuildQueue(); return end
    if command == "start" then ns.StartProcessing(); return end
    if command == "stop" then ns.StopProcessing(); return end

    if command == "next" then
        if not ns.isProcessing then ns.isProcessing = true end
        -- Click the secure button (requires hardware event in practice)
        return
    end

    if command == "list" then listQueue(); return end
    if command == "clear" then ns.ClearQueue(); return end

    if command == "quality" then
        local minQ, maxQ = rest:match("^(%S+)%s+(%S+)$")
        setQualityRange(minQ, maxQ)
        return
    end

    if command == "protect" then
        local action, arg = rest:match("^(%S+)%s*(.-)$")
        handleProtectCommand((action or ""):lower(), arg)
        return
    end

    if command == "ui" or command == "show" or command == "hide" then
        local queueFrame = _G.WDQ_QueueFrame
        if queueFrame then
            if command == "hide" then
                queueFrame:Hide()
                DisenqueueDB.showUI = false
                chat("UI hidden.")
            elseif command == "show" or not queueFrame:IsShown() then
                queueFrame:Show()
                DisenqueueDB.showUI = true
                ns.RebuildQueue()
                chat("UI shown.")
            else
                queueFrame:Hide()
                DisenqueueDB.showUI = false
                chat("UI hidden.")
            end
        end
        return
    end

    chat("Unknown command. Use /wdq help")
end

-- Legacy binding support
function WDQ_ProcessNextFromBinding()
    if ns.isProcessing and not InCombatLockdown() then
        secureBtn:Click()
    end
end
