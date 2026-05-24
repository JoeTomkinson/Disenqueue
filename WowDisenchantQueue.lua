local ADDON_NAME = ...
local DISENCHANT_SPELL_ID = 13262
local DEFAULT_MIN_QUALITY = 2
local DEFAULT_MAX_QUALITY = 4

BINDING_HEADER_WOW_DISENCHANT_QUEUE = "WoW Disenchant Queue"
BINDING_NAME_WDQ_PROCESS_NEXT = "Destroy/Disenchant next queued item"

local addon = CreateFrame("Frame", "WDQ_MainFrame")
local queue = {}

local function chat(message)
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
    if type(WowDisenchantQueueDB) ~= "table" then
        WowDisenchantQueueDB = {}
    end

    if type(WowDisenchantQueueDB.minQuality) ~= "number" then
        WowDisenchantQueueDB.minQuality = DEFAULT_MIN_QUALITY
    end

    if type(WowDisenchantQueueDB.maxQuality) ~= "number" then
        WowDisenchantQueueDB.maxQuality = DEFAULT_MAX_QUALITY
    end

    if type(WowDisenchantQueueDB.protectedItemIDs) ~= "table" then
        WowDisenchantQueueDB.protectedItemIDs = {}
    end
end

local function isProtected(itemID)
    return itemID and WowDisenchantQueueDB.protectedItemIDs[itemID]
end

local function isDisenchantCandidate(itemLink)
    local itemName, _, itemQuality, _, _, _, _, _, _, _, _, classID = GetItemInfo(itemLink)
    if not itemName or not itemQuality or not classID then
        return false
    end

    if itemQuality < WowDisenchantQueueDB.minQuality or itemQuality > WowDisenchantQueueDB.maxQuality then
        return false
    end

    if classID ~= 2 and classID ~= 4 then
        return false
    end

    local itemID = parseItemID(itemLink)
    if isProtected(itemID) then
        return false
    end

    return true
end

local function updateStatusText()
    if _G.WDQ_StatusText then
        _G.WDQ_StatusText:SetText(("Queued: %d"):format(#queue))
    end
end

local function queueItem(bag, slot, itemLink)
    local itemID = parseItemID(itemLink)
    local itemName = GetItemInfo(itemLink)

    table.insert(queue, {
        bag = bag,
        slot = slot,
        itemID = itemID,
        itemName = itemName or itemLink,
    })
end

local function clearQueue()
    wipe(queue)
    updateStatusText()
end

local function rebuildQueue()
    clearQueue()

    local backpackStart = _G.BACKPACK_CONTAINER or 0
    local backpackEnd = _G.NUM_BAG_SLOTS or 4

    for bag = backpackStart, backpackEnd do
        local slots = getContainerNumSlots(bag)
        for slot = 1, slots do
            local itemLink = getContainerItemLink(bag, slot)
            if itemLink and isDisenchantCandidate(itemLink) then
                queueItem(bag, slot, itemLink)
            end
        end
    end

    updateStatusText()
    chat(("Queue rebuilt with %d item(s). Use your wheel bind to process."):format(#queue))
end

local function processNext()
    if InCombatLockdown() then
        chat("Cannot process while in combat.")
        return
    end

    if #queue == 0 then
        chat("Queue empty. Use /wdq build to refresh.")
        return
    end

    local nextItem = table.remove(queue, 1)
    local currentLink = getContainerItemLink(nextItem.bag, nextItem.slot)
    if not currentLink then
        chat("Queued slot is empty. Skipping.")
        updateStatusText()
        return
    end

    local currentID = parseItemID(currentLink)
    if currentID ~= nextItem.itemID then
        chat("Queued item changed. Skipping mismatched slot.")
        updateStatusText()
        return
    end

    local disenchantSpell = GetSpellInfo(DISENCHANT_SPELL_ID)
    if not disenchantSpell or not IsPlayerSpell(DISENCHANT_SPELL_ID) then
        chat("Disenchant spell not known on this character.")
        table.insert(queue, 1, nextItem)
        updateStatusText()
        return
    end

    CastSpellByName(disenchantSpell)
    useContainerItem(nextItem.bag, nextItem.slot)

    chat(("Disenchant started: %s"):format(nextItem.itemName or "Unknown item"))
    updateStatusText()
end

function WDQ_ProcessNextFromBinding()
    processNext()
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
        for _ in pairs(WowDisenchantQueueDB.protectedItemIDs) do
            count = count + 1
        end

        if count == 0 then
            chat("No protected item IDs configured.")
            return
        end

        chat(("Protected item IDs (%d):"):format(count))
        for itemID in pairs(WowDisenchantQueueDB.protectedItemIDs) do
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
        WowDisenchantQueueDB.protectedItemIDs[itemID] = true
        chat(("Added %d to protected list."):format(itemID))
        return
    end

    if action == "remove" then
        WowDisenchantQueueDB.protectedItemIDs[itemID] = nil
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

    WowDisenchantQueueDB.minQuality = minQuality
    WowDisenchantQueueDB.maxQuality = maxQuality
    chat(("Queue quality filter set to %d-%d."):format(minQuality, maxQuality))
end

SLASH_WOWDISENCHANTQUEUE1 = "/wdq"
SlashCmdList.WOWDISENCHANTQUEUE = function(input)
    local command, rest = input:match("^(%S*)%s*(.-)$")
    command = (command or ""):lower()

    if command == "" or command == "help" then
        chat("/wdq build - scan bags and rebuild queue")
        chat("/wdq next - process one queued item")
        chat("/wdq list - print queued items")
        chat("/wdq clear - clear current queue")
        chat("/wdq quality <min> <max> - set item quality filter")
        chat("/wdq protect add|remove|list <itemID|itemLink>")
        return
    end

    if command == "build" then
        rebuildQueue()
        return
    end

    if command == "next" then
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

    chat("Unknown command. Use /wdq help")
end

local function createUI()
    local frame = CreateFrame("Frame", "WDQ_QueueFrame", UIParent, "BackdropTemplate")
    frame:SetSize(230, 90)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -10)
    title:SetText("WoW Disenchant Queue")

    local status = frame:CreateFontString("WDQ_StatusText", "OVERLAY", "GameFontNormal")
    status:SetPoint("TOP", title, "BOTTOM", 0, -8)
    status:SetText("Queued: 0")

    local destroyButton = CreateFrame("Button", "WDQ_DestroyButton", frame, "UIPanelButtonTemplate")
    destroyButton:SetSize(160, 22)
    destroyButton:SetPoint("BOTTOM", 0, 14)
    destroyButton:SetText("Destroy/Disenchant Next")
    destroyButton:SetScript("OnClick", processNext)

    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        if delta ~= 0 then
            processNext()
        end
    end)

    frame:Show()
end

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("BAG_UPDATE_DELAYED")
addon:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        normalizeDB()
        createUI()
        chat("Loaded. Use /wdq build then bind 'Destroy/Disenchant next queued item' to wheel up/down.")
        return
    end

    if event == "BAG_UPDATE_DELAYED" then
        updateStatusText()
    end
end)
