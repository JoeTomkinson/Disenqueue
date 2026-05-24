local ADDON_NAME = ...
local ADDON_VERSION = "1.0.0"
local DISENCHANT_SPELL_ID = 13262
local DEFAULT_MIN_QUALITY = 2
local DEFAULT_MAX_QUALITY = 4
local MIN_STACK_SIZE = 5  -- Minimum stack for Prospecting/Milling

-- Processing modes
local MODE_DISENCHANT = "disenchant"
local MODE_PROSPECT = "prospect"
local MODE_MILL = "mill"

-- Spell names used in macros (names are locale-independent for /cast)
local SPELL_NAMES = {
    [MODE_DISENCHANT] = "Disenchant",
    [MODE_PROSPECT] = "Prospecting",
    [MODE_MILL] = "Milling",
}

local addon = CreateFrame("Frame", "WDQ_MainFrame")
local queue = {}
local isProcessing = false  -- true when actively running through the queue

-- Notification categories
local NOTIFY_SCAN = "notifyScan"         -- Bag scan results
local NOTIFY_PROCESS = "notifyProcess"   -- Start/stop/complete/disenchanted
local NOTIFY_WARNINGS = "notifyWarnings" -- Slot empty, item changed, skipping
local NOTIFY_QUEUE = "notifyQueue"       -- Added/removed/locked/unlocked items

local function chat(message, category)
    -- Commands (no category) always show; categorized messages check user prefs
    if category and DisenqueueDB then
        if DisenqueueDB[category] == false then return end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0WDQ|r: " .. message)
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

local function useContainerItem(bag, slot)
    if C_Container and C_Container.UseContainerItem then
        C_Container.UseContainerItem(bag, slot)
        return
    end

    if UseContainerItem then
        UseContainerItem(bag, slot)
    end
end

local function parseItemID(itemLink)
    if not itemLink then
        return nil
    end

    local id = itemLink:match("item:(%d+)")
    if not id then
        return nil
    end

    return tonumber(id)
end

local function normalizeDB()
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

    -- Lesser Professions defaults
    if type(DisenqueueDB.lesserProfsEnabled) ~= "boolean" then
        DisenqueueDB.lesserProfsEnabled = false
    end
    if type(DisenqueueDB.prospectingEnabled) ~= "boolean" then
        DisenqueueDB.prospectingEnabled = false
    end
    if type(DisenqueueDB.millingEnabled) ~= "boolean" then
        DisenqueueDB.millingEnabled = false
    end

    -- Migrate old boolean-only entries to include item names
    for itemID, val in pairs(DisenqueueDB.protectedItemIDs) do
        if val == true then
            DisenqueueDB.protectedItemIDs[itemID] = { name = tostring(itemID) }
        end
    end
end

local function isProtected(itemID)
    return itemID and DisenqueueDB.protectedItemIDs[itemID] ~= nil
end

local function isDisenchantCandidate(itemLink)
    local itemName, _, itemQuality, _, _, _, _, _, _, _, _, classID, subClassID = GetItemInfo(itemLink)
    if not itemName or not itemQuality or not classID then
        return false
    end

    if itemQuality < DisenqueueDB.minQuality or itemQuality > DisenqueueDB.maxQuality then
        return false
    end

    -- Weapon (2), Armor (4), or Artifact Relic (Gem=3, subclass=11)
    local isValidClass = (classID == 2) or (classID == 4) or (classID == 3 and subClassID == 11)
    if not isValidClass then
        return false
    end

    local itemID = parseItemID(itemLink)
    if isProtected(itemID) then
        return false
    end

    return true
end

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

local function isProspectCandidate(itemLink, bag, slot)
    if not DisenqueueDB.lesserProfsEnabled or not DisenqueueDB.prospectingEnabled then
        return false
    end
    local itemName, _, _, _, _, _, _, _, _, _, _, classID, subClassID = GetItemInfo(itemLink)
    if not itemName or not classID then return false end

    -- Tradeskill (7), Metal & Stone (7)
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

    -- Tradeskill (7), Herb (9)
    if classID ~= 7 or subClassID ~= 9 then return false end

    if getContainerItemCount(bag, slot) < MIN_STACK_SIZE then return false end

    local itemID = parseItemID(itemLink)
    if isProtected(itemID) then return false end

    return true
end

local MAX_VISIBLE_ROWS = 10
local ROW_HEIGHT = 28
local FRAME_WIDTH = 350
local HEADER_HEIGHT = 56
local FOOTER_HEIGHT = 70
local LIST_PADDING_BOTTOM = 16
local LIST_HEIGHT = MAX_VISIBLE_ROWS * ROW_HEIGHT
local FRAME_HEIGHT = HEADER_HEIGHT + LIST_HEIGHT + LIST_PADDING_BOTTOM + FOOTER_HEIGHT

local rows = {}
local scrollOffset = 0
local glowAnim = nil
local castStartTime = 0
local castEndTime = 0
local isCasting = false

local function updateStatusText()
    if _G.WDQ_StatusText then
        if isProcessing then
            _G.WDQ_StatusText:SetText(("|cffaaddaaProcessing:|r |cffcccccc%d remaining|r"):format(#queue))
        elseif #queue > 0 then
            -- Count by mode for richer status
            local counts = {}
            for _, entry in ipairs(queue) do
                local m = entry.mode or MODE_DISENCHANT
                counts[m] = (counts[m] or 0) + 1
            end
            local parts = {}
            if counts[MODE_DISENCHANT] then table.insert(parts, counts[MODE_DISENCHANT] .. " DE") end
            if counts[MODE_PROSPECT] then table.insert(parts, counts[MODE_PROSPECT] .. " Prospect") end
            if counts[MODE_MILL] then table.insert(parts, counts[MODE_MILL] .. " Mill") end
            _G.WDQ_StatusText:SetText(("|cffffd100Queued: %s|r"):format(table.concat(parts, " / ")))
        else
            _G.WDQ_StatusText:SetText("|cffffd100Queued: 0|r")
        end
    end

    -- Pulse only when processing and waiting for user input
    if glowAnim then
        if isProcessing and #queue > 0 then
            if not glowAnim:IsPlaying() then
                if glowAnim.glowFrame then
                    glowAnim.glowFrame:SetBackdropBorderColor(0.4, 1, 0.4, 0.8)
                end
                glowAnim:Play()
            end
        else
            glowAnim:Stop()
            if glowAnim.glowFrame then
                glowAnim.glowFrame:SetBackdropBorderColor(0.4, 1, 0.4, 0)
            end
        end
    end

    -- Update button states
    local startBtn = _G.WDQ_StartButton
    local scanBtn = _G.WDQ_ScanButton
    local stopBtn = _G.WDQ_StopButton
    if startBtn then
        startBtn:SetShown(not isProcessing and #queue > 0)
    end
    if scanBtn then
        scanBtn:SetShown(not isProcessing)
    end
    if stopBtn then
        stopBtn:SetShown(isProcessing)
    end

    -- Update prompt text
    local prompt = _G.WDQ_PromptText
    if prompt then
        if isProcessing and #queue > 0 then
            local keyLabel = DisenqueueDB.processKey or "SCROLLWHEEL"
            if keyLabel == "SCROLLWHEEL" then
                keyLabel = "SCROLL"
            end
            local nextMode = queue[1] and queue[1].mode or MODE_DISENCHANT
            local verb = "disenchant"
            if nextMode == MODE_PROSPECT then verb = "prospect"
            elseif nextMode == MODE_MILL then verb = "mill" end
            prompt:SetText(("Press %s to %s next"):format(keyLabel, verb))
            prompt:SetTextColor(0.2, 1, 0.2)
        elseif isProcessing and #queue == 0 then
            prompt:SetText("Done! All items processed.")
            prompt:SetTextColor(1, 0.82, 0)
        else
            prompt:SetText("Shift+Scroll to browse")
            prompt:SetTextColor(0.5, 0.5, 0.5)
        end
    end
end

local function getItemQualityColor(itemLink)
    if not itemLink then
        return 1, 1, 1
    end
    local _, _, itemQuality = GetItemInfo(itemLink)
    if itemQuality and ITEM_QUALITY_COLORS[itemQuality] then
        local c = ITEM_QUALITY_COLORS[itemQuality]
        return c.r, c.g, c.b
    end
    return 1, 1, 1
end

local function refreshQueueList()
    updateStatusText()

    local emptyText = _G.WDQ_EmptyText
    if emptyText then
        if #queue == 0 and not isProcessing then
            emptyText:SetText("Queue empty\nClick 'Scan Bags' to find processable items")
            emptyText:Show()
        elseif #queue == 0 and isProcessing then
            emptyText:SetText("All done!")
            emptyText:Show()
            isProcessing = false
            updateStatusText()
        else
            emptyText:Hide()
        end
    end

    for i = 1, MAX_VISIBLE_ROWS do
        local row = rows[i]
        if not row then break end

        local dataIndex = i + scrollOffset
        if dataIndex <= #queue then
            local entry = queue[dataIndex]
            local itemLink = getContainerItemLink(entry.bag, entry.slot)
            local icon = entry.itemID and GetItemIcon(entry.itemID)
            row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            -- Show mode prefix for non-disenchant entries
            local prefix = ""
            if entry.mode == MODE_PROSPECT then
                prefix = "|cff00ccff[P]|r "
            elseif entry.mode == MODE_MILL then
                prefix = "|cff33cc33[M]|r "
            end
            row.nameText:SetText(prefix .. (entry.itemName or "Unknown"))
            local r, g, b = getItemQualityColor(itemLink)
            row.nameText:SetTextColor(r, g, b)
            row.dataIndex = dataIndex
            -- Hide action buttons during processing
            if row.lockBtn then row.lockBtn:SetShown(not isProcessing) end
            if row.removeBtn then row.removeBtn:SetShown(not isProcessing) end
            row:Show()
        else
            row.dataIndex = nil
            row:Hide()
        end
    end

    local scrollFrame = _G.WDQ_ScrollFrame
    if scrollFrame then
        local maxScroll = math.max(0, #queue - MAX_VISIBLE_ROWS)
        scrollOffset = math.min(scrollOffset, maxScroll)
    end
end

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
    scrollOffset = 0
    isProcessing = false
    updateStatusText()
    refreshQueueList()
end

local function rebuildQueue()
    clearQueue()
    isProcessing = false

    local backpackStart = _G.BACKPACK_CONTAINER or 0
    local backpackEnd = _G.NUM_BAG_SLOTS or 4

    -- Pass 1: Disenchant candidates
    for bag = backpackStart, backpackEnd do
        local slots = getContainerNumSlots(bag)
        for slot = 1, slots do
            local itemLink = getContainerItemLink(bag, slot)
            if itemLink and isDisenchantCandidate(itemLink) then
                queueItem(bag, slot, itemLink, MODE_DISENCHANT)
            end
        end
    end

    -- Pass 2: Prospecting candidates (grouped after disenchants)
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

    -- Pass 3: Milling candidates (grouped after prospect)
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

    updateStatusText()
    refreshQueueList()
    chat(("Scanned bags: %d item(s) found. Review and click 'Start' when ready."):format(#queue), NOTIFY_SCAN)

    -- Auto-show the frame on build
    if _G.WDQ_QueueFrame then
        _G.WDQ_QueueFrame:Show()
        DisenqueueDB.showUI = true
    end
end

local lastNotProcessingMsg = 0

-- Secure action button for disenchanting (requires hardware event)
local secureBtn = CreateFrame("Button", "WDQ_SecureProcessButton", UIParent, "SecureActionButtonTemplate")
secureBtn:SetSize(1, 1)
secureBtn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100)
secureBtn:SetAttribute("type", "macro")
secureBtn:SetAttribute("macrotext", "")
secureBtn:RegisterForClicks("AnyDown")

-- PreClick safeguard: verify the item hasn't changed before the macro fires
secureBtn:SetScript("PreClick", function(self)
    if InCombatLockdown() then
        self:SetAttribute("macrotext", "")
        return
    end
    if not isProcessing or #queue == 0 then
        self:SetAttribute("macrotext", "")
        return
    end
    local nextItem = queue[1]
    if not nextItem then
        self:SetAttribute("macrotext", "")
        return
    end
    -- Re-validate: check the item is still the same
    local currentLink = getContainerItemLink(nextItem.bag, nextItem.slot)
    if not currentLink then
        self:SetAttribute("macrotext", "")
        chat("Slot empty - skipping. Press again to continue.", NOTIFY_WARNINGS)
        table.remove(queue, 1)
        C_Timer.After(0.1, function() updateSecureButton(); updateStatusText(); refreshQueueList() end)
        return
    end
    local currentID = parseItemID(currentLink)
    if currentID ~= nextItem.itemID then
        self:SetAttribute("macrotext", "")
        chat("Item changed in slot - skipping to prevent accidental disenchant.", NOTIFY_WARNINGS)
        table.remove(queue, 1)
        C_Timer.After(0.1, function() updateSecureButton(); updateStatusText(); refreshQueueList() end)
        return
    end
    -- Item confirmed, macro is already set correctly
end)

-- Updates the secure button's macro to target the next queue item
local function updateSecureButton()
    if InCombatLockdown() then return end

    if not isProcessing or #queue == 0 then
        secureBtn:SetAttribute("macrotext", "")
        return
    end

    -- Validate the next item
    local nextItem = queue[1]
    if not nextItem then
        secureBtn:SetAttribute("macrotext", "")
        return
    end

    local currentLink = getContainerItemLink(nextItem.bag, nextItem.slot)
    if not currentLink then
        -- Slot is empty, remove and advance
        table.remove(queue, 1)
        chat("Queued slot is empty. Skipping.", NOTIFY_WARNINGS)
        updateStatusText()
        refreshQueueList()
        updateSecureButton()
        return
    end

    local currentID = parseItemID(currentLink)
    if currentID ~= nextItem.itemID then
        -- Item changed, remove and advance
        table.remove(queue, 1)
        chat("Queued item changed. Skipping mismatched slot.", NOTIFY_WARNINGS)
        updateStatusText()
        refreshQueueList()
        updateSecureButton()
        return
    end

    -- Set macro: cast the appropriate spell then use the bag slot
    local spellName = SPELL_NAMES[nextItem.mode] or SPELL_NAMES[MODE_DISENCHANT]
    local macro = ("/cast %s\n/use %d %d"):format(spellName, nextItem.bag, nextItem.slot)
    secureBtn:SetAttribute("macrotext", macro)
end

-- Binds the configured process key to the secure button
local function bindProcessKey()
    if InCombatLockdown() then return end
    local owner = _G.WDQ_QueueFrame or secureBtn
    local key = DisenqueueDB.processKey or "SCROLLWHEEL"
    -- Clear previous bindings
    ClearOverrideBindings(owner)
    if key == "SCROLLWHEEL" then
        SetOverrideBindingClick(owner, true, "MOUSEWHEELUP", "WDQ_SecureProcessButton")
        SetOverrideBindingClick(owner, true, "MOUSEWHEELDOWN", "WDQ_SecureProcessButton")
    else
        SetOverrideBindingClick(owner, true, key, "WDQ_SecureProcessButton")
    end
end

-- Clears the override bindings
local function unbindProcessKey()
    if InCombatLockdown() then return end
    local owner = _G.WDQ_QueueFrame or secureBtn
    ClearOverrideBindings(owner)
end

local function startProcessing()
    if #queue == 0 then
        chat("Nothing in queue. Scan bags first.", NOTIFY_PROCESS)
        return
    end
    if InCombatLockdown() then
        chat("Cannot start while in combat.", NOTIFY_WARNINGS)
        return
    end
    isProcessing = true
    -- Disable frame mouse wheel so override binding can capture scroll
    local qf = _G.WDQ_QueueFrame
    if qf then qf:EnableMouseWheel(false) end
    chat(("Processing started! Use your bound key to process %d item(s)."):format(#queue), NOTIFY_PROCESS)
    updateSecureButton()
    bindProcessKey()
    updateStatusText()
    refreshQueueList()
end

local function stopProcessing()
    isProcessing = false
    -- Re-enable frame mouse wheel for list scrolling
    local qf = _G.WDQ_QueueFrame
    if qf then qf:EnableMouseWheel(true) end
    unbindProcessKey()
    secureBtn:SetAttribute("macrotext", "")
    chat("Processing stopped. You can review/edit the queue.", NOTIFY_PROCESS)
    updateStatusText()
    refreshQueueList()
end

-- Called after a successful cast to advance the queue
local function advanceQueue()
    if not isProcessing then return end
    if #queue == 0 then return end

    local entry = queue[1]
    local mode = entry and entry.mode or MODE_DISENCHANT

    -- For stack-based modes (prospect/mill), check if stack still has enough
    if mode == MODE_PROSPECT or mode == MODE_MILL then
        local remaining = getContainerItemCount(entry.bag, entry.slot)
        if remaining >= MIN_STACK_SIZE then
            -- Stack still has enough, keep entry and re-fire
            local modeLabel = (mode == MODE_PROSPECT) and "Prospected" or "Milled"
            chat(("%s: %s (%d remaining)"):format(modeLabel, entry.itemName or "Unknown", remaining), NOTIFY_PROCESS)
            C_Timer.After(0.3, function()
                if isProcessing and not InCombatLockdown() then
                    updateSecureButton()
                    updateStatusText()
                    refreshQueueList()
                end
            end)
            return
        end
        -- Stack depleted below minimum, remove entry
        local modeLabel = (mode == MODE_PROSPECT) and "Prospected" or "Milled"
        table.remove(queue, 1)
        chat(("%s: %s (stack depleted)"):format(modeLabel, entry.itemName or "Unknown"), NOTIFY_PROCESS)
    else
        -- Disenchant: always remove the item
        table.remove(queue, 1)
        chat(("Disenchanted: %s"):format(entry.itemName or "Unknown"), NOTIFY_PROCESS)
    end

    if #queue == 0 then
        isProcessing = false
        local qf = _G.WDQ_QueueFrame
        if qf then qf:EnableMouseWheel(true) end
        unbindProcessKey()
        secureBtn:SetAttribute("macrotext", "")
        chat("Queue complete!", NOTIFY_PROCESS)
        updateStatusText()
        refreshQueueList()
        return
    end
    -- Prepare next item (delayed slightly to avoid combat lockdown from loot)
    C_Timer.After(0.3, function()
        if isProcessing and not InCombatLockdown() then
            updateSecureButton()
            updateStatusText()
            refreshQueueList()
        end
    end)
end

function WDQ_ProcessNextFromBinding()
    -- Legacy binding support: just click the secure button
    if isProcessing and not InCombatLockdown() then
        secureBtn:Click()
    end
end

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
    if not raw or raw == "" then
        return nil
    end

    local itemID = tonumber(raw)
    if itemID then
        return itemID
    end

    return parseItemID(raw)
end

local function handleProtectCommand(action, arg)
    if action == "list" then
        local count = 0
        for _ in pairs(DisenqueueDB.protectedItemIDs) do
            count = count + 1
        end

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
        DisenqueueDB.protectedItemIDs[itemID] = true
        chat(("Added %d to protected list."):format(itemID))
        return
    end

    if action == "remove" then
        DisenqueueDB.protectedItemIDs[itemID] = nil
        chat(("Removed %d from protected list."):format(itemID))
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

    if command == "build" then
        rebuildQueue()
        return
    end

    if command == "start" then
        if #queue == 0 then
            chat("Nothing in queue. Use /wdq build first.")
        else
            isProcessing = true
            chat(("Processing started! Scroll to disenchant %d item(s)."):format(#queue))
            updateStatusText()
            refreshQueueList()
        end
        return
    end

    if command == "stop" then
        isProcessing = false
        chat("Processing stopped.")
        updateStatusText()
        refreshQueueList()
        return
    end

    if command == "next" then
        if not isProcessing then
            isProcessing = true
        end
        processNext()
        return
    end

    if command == "list" then
        listQueue()
        return
    end

    if command == "clear" then
        clearQueue()
        chat("Queue cleared.")
        return
    end

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
                rebuildQueue()
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

local function createUI()
    local frame = CreateFrame("Frame", "WDQ_QueueFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -80)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        DisenqueueDB.framePos = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.85)

    -- Pulsing glow border (edge-only, not filling the frame)
    local borderGlow = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    borderGlow:SetPoint("TOPLEFT", -2, 2)
    borderGlow:SetPoint("BOTTOMRIGHT", 2, -2)
    borderGlow:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
    })
    borderGlow:SetBackdropBorderColor(0.4, 1, 0.4, 0)
    borderGlow:SetFrameLevel(frame:GetFrameLevel() + 5)

    local animGroup = borderGlow:CreateAnimationGroup()
    animGroup:SetLooping("BOUNCE")
    local fadeIn = animGroup:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(0.9)
    fadeIn:SetDuration(0.8)
    fadeIn:SetSmoothing("IN_OUT")
    glowAnim = animGroup
    glowAnim.glowFrame = borderGlow

    -- Header bar background
    local headerBar = CreateFrame("Frame", nil, frame)
    headerBar:SetPoint("TOPLEFT", 4, -4)
    headerBar:SetPoint("TOPRIGHT", -4, -4)
    headerBar:SetHeight(HEADER_HEIGHT - 8)
    local headerBg = headerBar:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0.08, 0.08, 0.08, 0.9)

    -- Separator line below header
    local headerSep = frame:CreateTexture(nil, "ARTWORK")
    headerSep:SetPoint("TOPLEFT", 6, -HEADER_HEIGHT + 2)
    headerSep:SetPoint("TOPRIGHT", -6, -HEADER_HEIGHT + 2)
    headerSep:SetHeight(1)
    headerSep:SetColorTexture(0.3, 0.3, 0.3, 0.6)

    -- Logo (left-aligned in header)
    local logo = headerBar:CreateTexture(nil, "ARTWORK")
    logo:SetSize(22, 22)
    logo:SetPoint("LEFT", 8, 6)
    logo:SetTexture("Interface\\AddOns\\Disenqueue\\logos\\logo-small")

    -- Title (left-aligned next to logo)
    local title = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", logo, "RIGHT", 7, 0)
    title:SetText("|cffccccccDisenqueue|r")
    title:SetJustifyH("LEFT")

    -- Version badge (small, dimmed, after title)
    local verText = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    verText:SetPoint("LEFT", title, "RIGHT", 5, 0)
    verText:SetText("|cff666666v" .. ADDON_VERSION .. "|r")

    -- Helper: create a header icon button (uniform rounded-style)
    local function createHeaderIconBtn(parent, texturePath, size)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(size, size)
        -- Circular background
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("TOPLEFT", 2, -2)
        bg:SetPoint("BOTTOMRIGHT", -2, 2)
        bg:SetColorTexture(0.18, 0.18, 0.18, 0.9)
        btn.bg = bg
        -- Icon
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 4, -4)
        icon:SetPoint("BOTTOMRIGHT", -4, 4)
        icon:SetTexture(texturePath)
        btn.icon = icon
        -- Highlight
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetPoint("TOPLEFT", 2, -2)
        hl:SetPoint("BOTTOMRIGHT", -2, 2)
        hl:SetColorTexture(1, 1, 1, 0.1)
        return btn
    end

    -- Close button
    local closeBtn = createHeaderIconBtn(headerBar, "Interface\\AddOns\\Disenqueue\\icons\\close", 24)
    closeBtn:SetPoint("RIGHT", headerBar, "RIGHT", -6, 6)
    closeBtn:SetScript("OnClick", function()
        if isProcessing then stopProcessing() end
        frame:Hide()
        DisenqueueDB.showUI = false
        if _G.WDQ_LockedPanel then _G.WDQ_LockedPanel:Hide() end
    end)

    -- Lock button (opens Locked Items panel)
    local lockBtn = createHeaderIconBtn(headerBar, "Interface\\AddOns\\Disenqueue\\icons\\lock-open", 24)
    lockBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    lockBtn:SetScript("OnClick", function()
        local panel = _G.WDQ_LockedPanel
        if panel then
            if panel:IsShown() then
                panel:Hide()
            else
                _G.WDQ_RefreshLockedList()
                panel:Show()
            end
        end
    end)
    lockBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Locked Items", 1, 0.82, 0)
        GameTooltip:AddLine("View/unlock permanently hidden items", 1, 1, 1)
        GameTooltip:Show()
    end)
    lockBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Status text (subtitle row in header)
    local status = headerBar:CreateFontString("WDQ_StatusText", "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("BOTTOMLEFT", headerBar, "BOTTOMLEFT", 10, 6)
    status:SetText("|cffffd100Queued: 0|r")
    status:SetJustifyH("LEFT")

    -- Item list area
    local listArea = CreateFrame("Frame", "WDQ_ScrollFrame", frame)
    listArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -HEADER_HEIGHT)
    listArea:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -HEADER_HEIGHT)
    listArea:SetHeight(LIST_HEIGHT)
    listArea:SetClipsChildren(true)

    -- Create row frames with remove and lock action buttons
    for i = 1, MAX_VISIBLE_ROWS do
        local row = CreateFrame("Frame", nil, listArea)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", listArea, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", listArea, "TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)
        row:EnableMouse(true)

        -- Cast progress bar (background layer, behind everything)
        local castBar = row:CreateTexture(nil, "BORDER")
        castBar:SetPoint("LEFT")
        castBar:SetPoint("TOP")
        castBar:SetPoint("BOTTOM")
        castBar:SetWidth(0)
        castBar:SetColorTexture(0.2, 0.6, 1, 0.25)
        castBar:Hide()
        row.castBar = castBar

        local highlight = row:CreateTexture(nil, "BACKGROUND")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.03)

        local iconTex = row:CreateTexture(nil, "ARTWORK")
        iconTex:SetSize(24, 24)
        iconTex:SetPoint("LEFT", 4, 0)
        row.icon = iconTex

        local nameStr = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameStr:SetPoint("LEFT", iconTex, "RIGHT", 6, 0)
        nameStr:SetPoint("RIGHT", row, "RIGHT", -56, 0)
        nameStr:SetJustifyH("LEFT")
        nameStr:SetWordWrap(false)
        row.nameText = nameStr

        -- Lock button (per row)
        local lockRowBtn = CreateFrame("Button", nil, row)
        lockRowBtn:SetSize(20, 20)
        lockRowBtn:SetPoint("RIGHT", row, "RIGHT", -26, 0)
        local lockRowIcon = lockRowBtn:CreateTexture(nil, "ARTWORK")
        lockRowIcon:SetAllPoints()
        lockRowIcon:SetTexture("Interface\\AddOns\\Disenqueue\\icons\\lock-closed")
        local lockRowHL = lockRowBtn:CreateTexture(nil, "HIGHLIGHT")
        lockRowHL:SetAllPoints()
        lockRowHL:SetColorTexture(1, 0.82, 0, 0.2)
        lockRowBtn:SetScript("OnClick", function()
            if isProcessing then return end
            local dataIndex = row.dataIndex
            if dataIndex and dataIndex <= #queue then
                local entry = queue[dataIndex]
                if entry.itemID then
                    DisenqueueDB.protectedItemIDs[entry.itemID] = { name = entry.itemName or "Unknown" }
                    table.remove(queue, dataIndex)
                    chat(("|cff60ff60Locked:|r %s"):format(entry.itemName or "Unknown"), NOTIFY_QUEUE)
                    refreshQueueList()
                    if _G.WDQ_LockedPanel and _G.WDQ_LockedPanel:IsShown() then
                        _G.WDQ_RefreshLockedList()
                    end
                end
            end
        end)
        lockRowBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Lock Item", 1, 0.82, 0)
            GameTooltip:AddLine("Never show this item again", 1, 1, 1)
            GameTooltip:Show()
        end)
        lockRowBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.lockBtn = lockRowBtn

        -- Remove button (per row)
        local removeRowBtn = CreateFrame("Button", nil, row)
        removeRowBtn:SetSize(20, 20)
        removeRowBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        local removeRowIcon = removeRowBtn:CreateTexture(nil, "ARTWORK")
        removeRowIcon:SetAllPoints()
        removeRowIcon:SetTexture("Interface\\AddOns\\Disenqueue\\icons\\remove-ok")
        local removeRowHL = removeRowBtn:CreateTexture(nil, "HIGHLIGHT")
        removeRowHL:SetAllPoints()
        removeRowHL:SetColorTexture(1, 1, 1, 0.1)
        removeRowBtn:SetScript("OnClick", function()
            if isProcessing then return end
            local dataIndex = row.dataIndex
            if dataIndex and dataIndex <= #queue then
                local removed = table.remove(queue, dataIndex)
                chat(("Removed: %s"):format(removed.itemName or "Unknown"), NOTIFY_QUEUE)
                refreshQueueList()
            end
        end)
        removeRowBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Remove", 1, 0.4, 0.4)
            GameTooltip:AddLine("Remove from this queue only", 1, 1, 1)
            GameTooltip:Show()
        end)
        removeRowBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.removeBtn = removeRowBtn

        -- Row tooltip on hover
        row:SetScript("OnEnter", function(self)
            local dataIndex = self.dataIndex
            if dataIndex and dataIndex <= #queue then
                local entry = queue[dataIndex]
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetBagItem(entry.bag, entry.slot)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row.dataIndex = nil
        row:Hide()
        rows[i] = row
    end

    -- Empty queue placeholder
    local emptyText = frame:CreateFontString("WDQ_EmptyText", "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("CENTER", listArea, "CENTER", 0, 0)
    emptyText:SetText("Queue empty\nClick 'Scan Bags' to find disenchantable items")
    emptyText:Show()

    -- Helper: create a modern flat button
    local function createModernButton(name, parent, width, height)
        local btn = CreateFrame("Button", name, parent)
        btn:SetSize(width, height)

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
        btn.bg = bg

        local border = btn:CreateTexture(nil, "BORDER")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetColorTexture(0.4, 0.4, 0.4, 0.6)
        btn.border = border

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)

        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER", 0, 0)
        btn.text = text
        btn.SetLabel = function(self, label)
            self.text:SetText(label)
        end
        btn.SetLabelColor = function(self, r, g, b)
            self.text:SetTextColor(r, g, b)
        end
        btn.SetBgColor = function(self, r, g, b, a)
            self.bg:SetColorTexture(r, g, b, a or 0.9)
        end

        return btn
    end

    -- Footer area with buttons
    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
    footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    footer:SetHeight(FOOTER_HEIGHT)

    -- Scan Bags button (modern)
    local scanBtn = createModernButton("WDQ_ScanButton", footer, 144, 26)
    scanBtn:SetPoint("TOPLEFT", footer, "TOPLEFT", 4, 0)
    scanBtn:SetLabel("Scan Bags")
    scanBtn:SetLabelColor(0.8, 0.8, 0.8)
    scanBtn:SetScript("OnClick", function()
        rebuildQueue()
    end)

    -- Start button (modern, green tint)
    local startBtn = createModernButton("WDQ_StartButton", footer, 144, 26)
    startBtn:SetPoint("TOPRIGHT", footer, "TOPRIGHT", -4, 0)
    startBtn:SetLabel("Start")
    startBtn:SetLabelColor(0.3, 1, 0.3)
    startBtn:SetBgColor(0.05, 0.2, 0.05)
    startBtn:SetScript("OnClick", function()
        startProcessing()
    end)
    startBtn:Hide()

    -- Stop button (modern, red tint)
    local stopBtn = createModernButton("WDQ_StopButton", footer, 144, 26)
    stopBtn:SetPoint("TOPRIGHT", footer, "TOPRIGHT", -4, 0)
    stopBtn:SetLabel("Stop")
    stopBtn:SetLabelColor(1, 0.4, 0.4)
    stopBtn:SetBgColor(0.25, 0.05, 0.05)
    stopBtn:SetScript("OnClick", function()
        stopProcessing()
    end)
    stopBtn:Hide()

    -- Prompt text at very bottom
    local prompt = frame:CreateFontString("WDQ_PromptText", "OVERLAY", "GameFontNormal")
    prompt:SetPoint("BOTTOM", footer, "BOTTOM", 0, 2)
    prompt:SetText("")
    prompt:SetTextColor(0.5, 0.5, 0.5)

    -- Mouse wheel: scroll list when shift held (processing scroll handled by override binding)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        if IsShiftKeyDown() then
            local maxScroll = math.max(0, #queue - MAX_VISIBLE_ROWS)
            scrollOffset = scrollOffset - delta
            scrollOffset = math.max(0, math.min(scrollOffset, maxScroll))
            refreshQueueList()
        end
    end)

    -- Restore saved position
    if DisenqueueDB.framePos then
        local pos = DisenqueueDB.framePos
        frame:ClearAllPoints()
        frame:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or 0, pos.y or -80)
    end

    -- Restore visibility state
    if DisenqueueDB.showUI == false then
        frame:Hide()
    else
        frame:Show()
        rebuildQueue()
    end
end

-- Alt+Click on bag items to add/remove from queue
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
        })
        local qualityColor = ITEM_QUALITY_COLORS[itemQuality]
        local colorStr = qualityColor and ("|cff%02x%02x%02x"):format(qualityColor.r * 255, qualityColor.g * 255, qualityColor.b * 255) or "|cffffffff"
        chat(("Added to queue: %s%s|r"):format(colorStr, itemName), NOTIFY_QUEUE)
    end
    updateStatusText()
    refreshQueueList()

    -- Auto-show the frame
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

    if DisenqueueDB.protectedItemIDs[itemID] then
        DisenqueueDB.protectedItemIDs[itemID] = nil
        chat(("|cffff6060Unlocked:|r %s"):format(itemName), NOTIFY_QUEUE)
    else
        DisenqueueDB.protectedItemIDs[itemID] = { name = itemName }
        chat(("|cff60ff60Locked:|r %s (will never be queued)"):format(itemName), NOTIFY_QUEUE)
        -- Remove from current queue if present
        for i = #queue, 1, -1 do
            if queue[i].itemID == itemID then
                table.remove(queue, i)
            end
        end
        refreshQueueList()
    end

    -- Refresh locked panel if open
    if _G.WDQ_LockedPanel and _G.WDQ_LockedPanel:IsShown() then
        _G.WDQ_RefreshLockedList()
    end
end

local function hookBagClicks()
    -- Hook for modern bag frames (Retail/Midnight combined bags)
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

    -- Hook ContainerFrame items for classic-style bags
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

    -- Hook combined bag (ContainerFrameCombinedBags) items
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags.Items then
        for _, itemButton in pairs(ContainerFrameCombinedBags.Items) do
            hookModernBagButton(itemButton)
        end
    end

    -- EventRegistry hook for dynamically created bag item buttons
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

-- Minimap button (no library dependency)
local function createMinimapButton()
    local minimapBtn = CreateFrame("Button", "WDQ_MinimapButton", Minimap)
    minimapBtn:SetSize(32, 32)
    minimapBtn:SetFrameStrata("MEDIUM")
    minimapBtn:SetFrameLevel(8)
    minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = minimapBtn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    local icon = minimapBtn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\AddOns\\Disenqueue\\logos\\logo-small")
    icon:SetPoint("CENTER", 0, 1)

    local background = minimapBtn:CreateTexture(nil, "BACKGROUND", nil, -1)
    background:SetSize(24, 24)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("CENTER", 0, 1)

    -- Position around minimap edge
    local angle = DisenqueueDB.minimapAngle or 220
    local function updatePosition()
        local radian = math.rad(angle)
        local x = math.cos(radian) * 80
        local y = math.sin(radian) * 80
        minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    updatePosition()

    -- Dragging to reposition around minimap
    minimapBtn:RegisterForDrag("LeftButton")
    minimapBtn:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            angle = math.deg(math.atan2(cy - my, cx - mx))
            DisenqueueDB.minimapAngle = angle
            updatePosition()
        end)
    end)
    minimapBtn:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
    end)

    -- Click to toggle UI
    minimapBtn:SetScript("OnClick", function(_, button)
        local queueFrame = _G.WDQ_QueueFrame
        if queueFrame then
            if queueFrame:IsShown() then
                queueFrame:Hide()
                DisenqueueDB.showUI = false
            else
                queueFrame:Show()
                DisenqueueDB.showUI = true
                rebuildQueue()
            end
        end
    end)

    -- Tooltip
    minimapBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Disenqueue")
        GameTooltip:AddLine("Click: Toggle queue window", 1, 1, 1)
        GameTooltip:AddLine("Alt+Click bag items to add to queue", 1, 1, 1)
        GameTooltip:AddLine("Drag to reposition", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    minimapBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- Locked Items panel
local MAX_LOCKED_ROWS = 8
local lockedRows = {}

local function createLockedPanel()
    local panel = CreateFrame("Frame", "WDQ_LockedPanel", UIParent, "BackdropTemplate")
    panel:SetSize(240, 50 + MAX_LOCKED_ROWS * 22)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0, 0, 0, 0.9)

    -- Anchor to right side of main frame
    local mainFrame = _G.WDQ_QueueFrame
    if mainFrame then
        panel:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 4, 0)
    else
        panel:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    end

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Locked Items")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    -- Count text
    local countText = panel:CreateFontString("WDQ_LockedCount", "OVERLAY", "GameFontNormal")
    countText:SetPoint("TOP", title, "BOTTOM", 0, -4)
    countText:SetTextColor(0.7, 0.7, 0.7)

    -- List area
    local listArea = CreateFrame("Frame", nil, panel)
    listArea:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -44)
    listArea:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -44)
    listArea:SetHeight(MAX_LOCKED_ROWS * 22)

    -- Empty text
    local emptyText = panel:CreateFontString("WDQ_LockedEmpty", "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("CENTER", listArea, "CENTER", 0, 0)
    emptyText:SetText("No locked items")

    -- Create locked item rows
    for i = 1, MAX_LOCKED_ROWS do
        local row = CreateFrame("Button", nil, listArea)
        row:SetHeight(22)
        row:SetPoint("TOPLEFT", listArea, "TOPLEFT", 0, -(i - 1) * 22)
        row:SetPoint("TOPRIGHT", listArea, "TOPRIGHT", 0, -(i - 1) * 22)

        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.3, 0.8, 0.3, 0.15)

        local iconTex = row:CreateTexture(nil, "ARTWORK")
        iconTex:SetSize(18, 18)
        iconTex:SetPoint("LEFT", 4, 0)
        row.icon = iconTex

        local nameStr = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameStr:SetPoint("LEFT", iconTex, "RIGHT", 6, 0)
        nameStr:SetPoint("RIGHT", row, "RIGHT", -24, 0)
        nameStr:SetJustifyH("LEFT")
        nameStr:SetWordWrap(false)
        row.nameText = nameStr

        -- Unlock icon
        local unlockIcon = row:CreateTexture(nil, "ARTWORK")
        unlockIcon:SetSize(16, 16)
        unlockIcon:SetPoint("RIGHT", -4, 0)
        unlockIcon:SetTexture("Interface\\AddOns\\Disenqueue\\icons\\lock-open")
        unlockIcon:SetAlpha(0)
        row.unlockLabel = unlockIcon

        row.itemID = nil

        -- Click to unlock
        row:SetScript("OnClick", function(self)
            if self.itemID then
                local entry = DisenqueueDB.protectedItemIDs[self.itemID]
                local name = (entry and entry.name) or tostring(self.itemID)
                DisenqueueDB.protectedItemIDs[self.itemID] = nil
                chat(("|cffff6060Unlocked:|r %s"):format(name), NOTIFY_QUEUE)
                _G.WDQ_RefreshLockedList()
            end
        end)

        row:SetScript("OnEnter", function(self)
            self.unlockLabel:SetAlpha(1)
            if self.itemID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(self.itemID)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Click to unlock", 0.2, 1, 0.2)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(self)
            self.unlockLabel:SetAlpha(0)
            GameTooltip:Hide()
        end)

        row:Hide()
        lockedRows[i] = row
    end

    panel:Hide()
end

function _G.WDQ_RefreshLockedList()
    local panel = _G.WDQ_LockedPanel
    if not panel then return end

    local items = {}
    for itemID, entry in pairs(DisenqueueDB.protectedItemIDs) do
        local name = (type(entry) == "table" and entry.name) or tostring(itemID)
        table.insert(items, { itemID = itemID, name = name })
    end
    table.sort(items, function(a, b) return a.name < b.name end)

    local countText = _G.WDQ_LockedCount
    if countText then
        countText:SetText(("%d item(s) locked"):format(#items))
    end

    local emptyText = _G.WDQ_LockedEmpty
    if emptyText then
        emptyText:SetShown(#items == 0)
    end

    for i = 1, MAX_LOCKED_ROWS do
        local row = lockedRows[i]
        if not row then break end

        if i <= #items then
            local entry = items[i]
            row.itemID = entry.itemID
            local icon = GetItemIcon(entry.itemID)
            row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.nameText:SetText(entry.name)
            row.nameText:SetTextColor(0.6, 0.6, 0.6)
            row:Show()
        else
            row.itemID = nil
            row:Hide()
        end
    end
end

-- Settings panel (AddOns tab in Blizzard Options)
local PROCESS_KEY_OPTIONS = {
    { value = "SCROLLWHEEL", label = "Mouse Scroll Wheel" },
    { value = "ENTER",       label = "Enter" },
    { value = "SPACE",       label = "Space" },
    { value = "F",           label = "F" },
    { value = "E",           label = "E" },
    { value = "R",           label = "R" },
}

function WDQ_RegisterSettings()
    local category = Settings.RegisterVerticalLayoutCategory("Disenqueue")

    -- Process Key dropdown
    do
        local name = "Process Key"
        local variable = "DisenqueueProcessKey"
        local defaultValue = "SCROLLWHEEL"

        local function GetValue()
            return DisenqueueDB.processKey or defaultValue
        end

        local function SetValue(value)
            DisenqueueDB.processKey = value
            if isProcessing and not InCombatLockdown() then
                bindProcessKey()
            end
            updateStatusText()
        end

        local setting = Settings.RegisterProxySetting(category, variable, type(defaultValue), name, defaultValue, GetValue, SetValue)

        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            for _, opt in ipairs(PROCESS_KEY_OPTIONS) do
                container:Add(opt.value, opt.label)
            end
            return container:GetData()
        end

        Settings.CreateDropdown(category, setting, GetOptions, "The key used to disenchant the next item while processing.")
    end

    -- Min Quality dropdown
    do
        local name = "Minimum Quality"
        local variable = "DisenqueueMinQuality"
        local defaultValue = DEFAULT_MIN_QUALITY

        local function GetValue()
            return DisenqueueDB.minQuality or defaultValue
        end

        local function SetValue(value)
            DisenqueueDB.minQuality = value
        end

        local setting = Settings.RegisterProxySetting(category, variable, type(defaultValue), name, defaultValue, GetValue, SetValue)

        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            container:Add(0, "Poor")
            container:Add(1, "Common")
            container:Add(2, "Uncommon")
            container:Add(3, "Rare")
            container:Add(4, "Epic")
            return container:GetData()
        end

        Settings.CreateDropdown(category, setting, GetOptions, "Minimum item quality to include when scanning bags.")
    end

    -- Max Quality dropdown
    do
        local name = "Maximum Quality"
        local variable = "DisenqueueMaxQuality"
        local defaultValue = DEFAULT_MAX_QUALITY

        local function GetValue()
            return DisenqueueDB.maxQuality or defaultValue
        end

        local function SetValue(value)
            DisenqueueDB.maxQuality = value
        end

        local setting = Settings.RegisterProxySetting(category, variable, type(defaultValue), name, defaultValue, GetValue, SetValue)

        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            container:Add(0, "Poor")
            container:Add(1, "Common")
            container:Add(2, "Uncommon")
            container:Add(3, "Rare")
            container:Add(4, "Epic")
            return container:GetData()
        end

        Settings.CreateDropdown(category, setting, GetOptions, "Maximum item quality to include when scanning bags.")
    end

    -- Chat notification toggles
    do
        local notifications = {
            { key = "notifyScan", var = "DisenqueueNotifyScan", name = "Scan Notifications", tooltip = "Show a chat message after scanning bags." },
            { key = "notifyProcess", var = "DisenqueueNotifyProcess", name = "Processing Notifications", tooltip = "Show chat messages when starting, stopping, or completing disenchants." },
            { key = "notifyWarnings", var = "DisenqueueNotifyWarnings", name = "Warning Notifications", tooltip = "Show chat warnings when items change or slots are empty." },
            { key = "notifyQueue", var = "DisenqueueNotifyQueue", name = "Queue Change Notifications", tooltip = "Show chat messages when items are added, removed, locked, or unlocked." },
        }
        for _, notif in ipairs(notifications) do
            local function GetValue()
                return DisenqueueDB[notif.key] ~= false
            end
            local function SetValue(value)
                DisenqueueDB[notif.key] = value
            end
            local setting = Settings.RegisterProxySetting(category, notif.var, type(true), notif.name, true, GetValue, SetValue)
            Settings.CreateCheckbox(category, setting, notif.tooltip)
        end
    end

    -- Lesser Professions subcategory
    do
        local lpFrame = CreateFrame("Frame", nil, UIParent)
        lpFrame:SetSize(400, 300)
        lpFrame:Hide()

        local titleStr = lpFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        titleStr:SetPoint("TOPLEFT", 20, -16)
        titleStr:SetText("Lesser Professions")

        local descStr = lpFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        descStr:SetPoint("TOPLEFT", titleStr, "BOTTOMLEFT", 0, -6)
        descStr:SetPoint("RIGHT", lpFrame, "RIGHT", -20, 0)
        descStr:SetJustifyH("LEFT")
        descStr:SetWordWrap(true)
        descStr:SetText("Enable support for other professions that use the same cast-on-bag-item pattern. When enabled, Scan Bags will also find items for these professions.")

        -- Master toggle
        local masterCb = CreateFrame("CheckButton", "WDQ_LesserProfsToggle", lpFrame, "InterfaceOptionsCheckButtonTemplate")
        masterCb:SetPoint("TOPLEFT", descStr, "BOTTOMLEFT", -2, -14)
        masterCb.Text:SetText("|cffffffffEnable Lesser Professions|r")
        masterCb:SetChecked(DisenqueueDB.lesserProfsEnabled)

        -- Sub-options container
        local subFrame = CreateFrame("Frame", nil, lpFrame)
        subFrame:SetPoint("TOPLEFT", masterCb, "BOTTOMLEFT", 20, -8)
        subFrame:SetPoint("RIGHT", lpFrame, "RIGHT", -20, 0)
        subFrame:SetHeight(120)

        -- Prospecting checkbox
        local prospectCb = CreateFrame("CheckButton", "WDQ_ProspectToggle", subFrame, "InterfaceOptionsCheckButtonTemplate")
        prospectCb:SetPoint("TOPLEFT", 0, 0)
        prospectCb.Text:SetText("|cffffffffProspecting|r  |cff888888(Jewelcrafting — ore stacks of 5+)|r")
        prospectCb:SetChecked(DisenqueueDB.prospectingEnabled)

        -- Milling checkbox
        local millCb = CreateFrame("CheckButton", "WDQ_MillToggle", subFrame, "InterfaceOptionsCheckButtonTemplate")
        millCb:SetPoint("TOPLEFT", prospectCb, "BOTTOMLEFT", 0, -6)
        millCb.Text:SetText("|cffffffffMilling|r  |cff888888(Inscription — herb stacks of 5+)|r")
        millCb:SetChecked(DisenqueueDB.millingEnabled)

        -- Update sub-options visibility
        local function updateSubVis()
            local enabled = masterCb:GetChecked()
            local alpha = enabled and 1 or 0.4
            subFrame:SetAlpha(alpha)
            prospectCb:SetEnabled(enabled)
            millCb:SetEnabled(enabled)
        end
        updateSubVis()

        masterCb:SetScript("OnClick", function(self)
            DisenqueueDB.lesserProfsEnabled = self:GetChecked()
            updateSubVis()
        end)
        prospectCb:SetScript("OnClick", function(self)
            DisenqueueDB.prospectingEnabled = self:GetChecked()
        end)
        millCb:SetScript("OnClick", function(self)
            DisenqueueDB.millingEnabled = self:GetChecked()
        end)

        Settings.RegisterCanvasLayoutSubcategory(category, lpFrame, "Lesser Professions")
    end

    -- About subcategory with logo and addon info
    do
        local aboutFrame = CreateFrame("Frame", nil, UIParent)
        aboutFrame:SetSize(300, 200)
        aboutFrame:Hide()

        local logo = aboutFrame:CreateTexture(nil, "ARTWORK")
        logo:SetSize(64, 64)
        logo:SetPoint("TOPLEFT", 20, -20)
        logo:SetTexture("Interface\\AddOns\\Disenqueue\\logos\\logo")

        local titleStr = aboutFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        titleStr:SetPoint("TOPLEFT", logo, "TOPRIGHT", 14, -4)
        titleStr:SetText("Disenqueue")

        local versionStr = aboutFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        versionStr:SetPoint("TOPLEFT", titleStr, "BOTTOMLEFT", 0, -4)
        versionStr:SetText("v" .. ADDON_VERSION)

        local descStr = aboutFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        descStr:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -16)
        descStr:SetPoint("RIGHT", aboutFrame, "RIGHT", -20, 0)
        descStr:SetJustifyH("LEFT")
        descStr:SetText("Queue disenchantable items from your bags and process them one at a time with a configurable key or scroll wheel.")

        local authorStr = aboutFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        authorStr:SetPoint("TOPLEFT", descStr, "BOTTOMLEFT", 0, -12)
        authorStr:SetText("Author: Grimmvöcare - Bronzebeard")

        Settings.RegisterCanvasLayoutSubcategory(category, aboutFrame, "About")
    end

    Settings.RegisterAddOnCategory(category)
end

-- Cast bar progress update (OnUpdate driven)
local castBarTicker = CreateFrame("Frame")
castBarTicker:Hide()

function WDQ_StartCastBarUpdate()
    -- Show cast bar on first visible row (the item being processed)
    local row = rows[1]
    if row and row.castBar then
        row.castBar:Show()
    end
    castBarTicker:Show()
end

function WDQ_StopCastBarUpdate()
    castBarTicker:Hide()
    -- Hide all cast bars
    for _, row in ipairs(rows) do
        if row.castBar then
            row.castBar:SetWidth(0)
            row.castBar:Hide()
        end
    end
end

castBarTicker:SetScript("OnUpdate", function()
    if not isCasting then
        WDQ_StopCastBarUpdate()
        return
    end

    local now = GetTime()
    local duration = castEndTime - castStartTime
    if duration <= 0 then return end

    local elapsed = now - castStartTime
    local progress = math.min(elapsed / duration, 1.0)

    -- Update first row's cast bar width
    local row = rows[1]
    if row and row.castBar and row:IsShown() then
        local rowWidth = row:GetWidth()
        row.castBar:SetWidth(rowWidth * progress)
        row.castBar:Show()
    end
end)

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("BAG_UPDATE_DELAYED")
addon:RegisterEvent("UNIT_SPELLCAST_START")
addon:RegisterEvent("UNIT_SPELLCAST_STOP")
addon:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
addon:RegisterEvent("UNIT_SPELLCAST_FAILED")
addon:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
addon:SetScript("OnEvent", function(_, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        normalizeDB()
        createUI()
        createLockedPanel()
        createMinimapButton()
        hookBagClicks()
        WDQ_RegisterSettings()
        chat(("v%s loaded. Alt+Left-Click to queue."):format(ADDON_VERSION))
        return
    end

    if event == "BAG_UPDATE_DELAYED" then
        -- Re-validate secure button when bags change during processing
        if isProcessing and not InCombatLockdown() then
            updateSecureButton()
        end
        updateStatusText()
        refreshQueueList()
        return
    end

    -- Spellcast tracking for disenchant progress bar
    if arg1 ~= "player" then return end

    if event == "UNIT_SPELLCAST_START" then
        local spellID = select(2, ...)
        if spellID == DISENCHANT_SPELL_ID then
            local _, _, _, startMS, endMS = UnitCastingInfo("player")
            if startMS and endMS then
                castStartTime = startMS / 1000
                castEndTime = endMS / 1000
                isCasting = true
                WDQ_StartCastBarUpdate()
            end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local spellID = select(2, ...)
        if spellID == DISENCHANT_SPELL_ID then
            isCasting = false
            WDQ_StopCastBarUpdate()
            -- Advance the queue after successful disenchant
            advanceQueue()
        end
    elseif event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local spellID = select(2, ...)
        if spellID == DISENCHANT_SPELL_ID then
            isCasting = false
            WDQ_StopCastBarUpdate()
        end
    end
end)
