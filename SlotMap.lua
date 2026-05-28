local _, ns = ...

-- ═══════════════════════════════════════════════════════════════════════════════
-- SlotMap.lua — Maps INVTYPE constants to readable slot names for display
-- ═══════════════════════════════════════════════════════════════════════════════

-- Maps WoW INVTYPE strings to display-friendly slot labels
local INVTYPE_TO_SLOT = {
    INVTYPE_HEAD           = "HELM",
    INVTYPE_SHOULDER       = "SHOULDERS",
    INVTYPE_CHEST          = "CHEST",
    INVTYPE_ROBE           = "CHEST",
    INVTYPE_WAIST          = "BELT",
    INVTYPE_LEGS           = "LEGS",
    INVTYPE_FEET           = "BOOTS",
    INVTYPE_WRIST          = "BRACERS",
    INVTYPE_HAND           = "GLOVES",
    INVTYPE_CLOAK          = "CLOAK",
    INVTYPE_FINGER         = "RING",
    INVTYPE_TRINKET        = "TRINKET",
    INVTYPE_WEAPON         = "WEAPON",
    INVTYPE_2HWEAPON       = "WEAPON",
    INVTYPE_WEAPONMAINHAND = "WEAPON",
    INVTYPE_WEAPONOFFHAND  = "OFF-HAND",
    INVTYPE_HOLDABLE       = "OFF-HAND",
    INVTYPE_SHIELD         = "SHIELD",
    INVTYPE_RANGED         = "RANGED",
    INVTYPE_RANGEDRIGHT    = "RANGED",
    INVTYPE_NECK           = "NECK",
    INVTYPE_BODY           = "SHIRT",
    INVTYPE_TABARD         = "TABARD",
}

-- Gets the slot label for an item link (uppercase display string)
function ns.GetSlotLabel(itemLink)
    if not itemLink then return nil end
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemLink)
    if not equipLoc or equipLoc == "" then return nil end
    return INVTYPE_TO_SLOT[equipLoc] or equipLoc:gsub("INVTYPE_", "")
end

-- Gets the slot label for an item by ID
function ns.GetSlotLabelByID(itemID)
    if not itemID then return nil end
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemID)
    if not equipLoc or equipLoc == "" then return nil end
    return INVTYPE_TO_SLOT[equipLoc] or equipLoc:gsub("INVTYPE_", "")
end
