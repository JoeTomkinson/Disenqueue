local _, ns = ...

-- ═══════════════════════════════════════════════════════════════════════════════
-- Settings.lua — Blizzard Settings API registration
-- ═══════════════════════════════════════════════════════════════════════════════

local DEFAULT_MIN_QUALITY = 2
local DEFAULT_MAX_QUALITY = 4

local PROCESS_KEY_OPTIONS = {
    { value = "SCROLLWHEEL", label = "Mouse Scroll Wheel" },
    { value = "ENTER",       label = "Enter" },
    { value = "SPACE",       label = "Space" },
    { value = "F",           label = "F" },
    { value = "E",           label = "E" },
    { value = "R",           label = "R" },
}

local function registerSettings()
    local category, layout = Settings.RegisterVerticalLayoutCategory("Disenqueue")
    _G.WDQ_SettingsCategory = category

    -- Section: General
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("|cff60ff60General|r"))

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
            if ns.isProcessing and not InCombatLockdown() then
                ns.BindProcessKey()
            end
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

    -- Soulbound Only toggle
    do
        local name = "Soulbound Only"
        local variable = "DisenqueueSoulboundOnly"
        local defaultValue = false

        local function GetValue()
            return DisenqueueDB.soulboundOnly
        end

        local function SetValue(value)
            DisenqueueDB.soulboundOnly = value
        end

        local setting = Settings.RegisterProxySetting(category, variable, type(defaultValue), name, defaultValue, GetValue, SetValue)
        Settings.CreateCheckbox(category, setting, "When enabled, only soulbound gear is queued for disenchanting. Non-bound items (tradeable/AH-sellable) are excluded.")
    end

    -- Section: Notifications
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("|cff60ff60Notifications|r"))

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
        titleStr:SetText("|cff60ff60Lesser Professions|r")

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
        prospectCb.Text:SetText("|cffffffffProspecting|r  |cff888888(Jewelcrafting \226\128\148 ore stacks of 5+)|r")
        prospectCb:SetChecked(DisenqueueDB.prospectingEnabled)

        -- Milling checkbox
        local millCb = CreateFrame("CheckButton", "WDQ_MillToggle", subFrame, "InterfaceOptionsCheckButtonTemplate")
        millCb:SetPoint("TOPLEFT", prospectCb, "BOTTOMLEFT", 0, -6)
        millCb.Text:SetText("|cffffffffMilling|r  |cff888888(Inscription \226\128\148 herb stacks of 5+)|r")
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

    -- Slash Commands subcategory
    do
        local cmdFrame = CreateFrame("Frame", nil, UIParent)
        cmdFrame:SetSize(400, 320)
        cmdFrame:Hide()

        local titleStr = cmdFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        titleStr:SetPoint("TOPLEFT", 20, -16)
        titleStr:SetText("|cff60ff60Slash Commands|r")

        local descStr = cmdFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        descStr:SetPoint("TOPLEFT", titleStr, "BOTTOMLEFT", 0, -6)
        descStr:SetPoint("RIGHT", cmdFrame, "RIGHT", -20, 0)
        descStr:SetJustifyH("LEFT")
        descStr:SetWordWrap(true)
        descStr:SetText("All commands use the |cffffffcc/wdq|r prefix.")

        local commands = {
            { cmd = "/wdq build",    desc = "Scan bags and populate the queue" },
            { cmd = "/wdq start",    desc = "Begin processing (enables key/scroll to disenchant)" },
            { cmd = "/wdq stop",     desc = "Pause processing" },
            { cmd = "/wdq next",     desc = "Process one queued item" },
            { cmd = "/wdq list",     desc = "Print queued items to chat" },
            { cmd = "/wdq clear",    desc = "Clear the current queue" },
            { cmd = "/wdq quality <min> <max>", desc = "Set item quality filter (0\226\128\1474)" },
            { cmd = "/wdq protect add <item>",  desc = "Lock an item from being queued" },
            { cmd = "/wdq protect remove <item>", desc = "Unlock a previously locked item" },
            { cmd = "/wdq protect list", desc = "List all locked items" },
            { cmd = "/wdq ui",       desc = "Toggle the queue window" },
            { cmd = "/wdq help",     desc = "Show command list in chat" },
        }

        local yOff = -8
        local prevAnchor = descStr
        for _, entry in ipairs(commands) do
            local line = cmdFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            line:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, yOff)
            line:SetPoint("RIGHT", cmdFrame, "RIGHT", -20, 0)
            line:SetJustifyH("LEFT")
            line:SetWordWrap(false)
            line:SetText("|cffffffcc" .. entry.cmd .. "|r  |cffaaaaaa\226\128\148|r  " .. entry.desc)
            prevAnchor = line
            yOff = -4
        end

        Settings.RegisterCanvasLayoutSubcategory(category, cmdFrame, "Slash Commands")
    end

    -- About subcategory
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
        titleStr:SetText("|cff60ff60Disenqueue|r")

        local versionStr = aboutFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        versionStr:SetPoint("TOPLEFT", titleStr, "BOTTOMLEFT", 0, -4)
        versionStr:SetText("|cffffffccv" .. ns.ADDON_VERSION .. "|r")

        local descStr = aboutFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        descStr:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -16)
        descStr:SetPoint("RIGHT", aboutFrame, "RIGHT", -20, 0)
        descStr:SetJustifyH("LEFT")
        descStr:SetWordWrap(true)
        descStr:SetText("Queue disenchantable items from your bags and process them one at a time with a configurable key or scroll wheel.\n\nAlso supports the Lesser Professions (Prospecting & Milling) for those who recognise that Enchanting is the one true craft.\n\nDisenqueue is designed to strictly adhere to Blizzard's Terms of Service. Every action requires a deliberate user input \226\128\148 one keypress or scroll tick produces exactly one in-game action. No automation, no queued inputs, no unattended play. Just a smarter workflow that respects the rules.")

        local authorStr = aboutFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        authorStr:SetPoint("TOPLEFT", descStr, "BOTTOMLEFT", 0, -12)
        authorStr:SetText("Author: Grimmv\195\182care - Bronzebeard")

        Settings.RegisterCanvasLayoutSubcategory(category, aboutFrame, "About")
    end

    Settings.RegisterAddOnCategory(category)
end

-- ─── Callback Wiring ─────────────────────────────────────────────────────────

ns.RegisterCallback("ADDON_LOADED", function()
    registerSettings()
end)
