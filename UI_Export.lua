local _, ns = ...

-- ═══════════════════════════════════════════════════════════════════════════════
-- UI_Export.lua — Export/Import modal with tabbed code block
-- ═══════════════════════════════════════════════════════════════════════════════

local C = ns.C
local Theme = ns.Theme

local MODAL_WIDTH = 460
local MODAL_HEIGHT = 360
local TITLE_BAR_HEIGHT = 48
local TAB_HEIGHT = 32
local CODE_MARGIN = 14
local CODE_TOP = TITLE_BAR_HEIGHT + TAB_HEIGHT + 8
local FOOTER_HEIGHT = 52

local modal
local activeTab = 1
local currentContent = ""
local isImportMode = false

-- ─── Tab System ──────────────────────────────────────────────────────────────

local tabButtons = {}
local TAB_LABELS = { "String" }

local function updateTabs()
    for i, btn in ipairs(tabButtons) do
        if i == activeTab then
            btn._bg:SetColorTexture(C.violet.r, C.violet.g, C.violet.b, 0.2)
            btn._label:SetTextColor(C.violetHi.r, C.violetHi.g, C.violetHi.b)
        else
            btn._bg:SetColorTexture(C.surface1.r, C.surface1.g, C.surface1.b, 0.6)
            btn._label:SetTextColor(C.textDim.r, C.textDim.g, C.textDim.b)
        end
    end
end

-- ─── Modal Construction ──────────────────────────────────────────────────────

local function createExportModal()
    modal = CreateFrame("Frame", "WDQ_ExportModal", UIParent, "BackdropTemplate")
    modal:SetSize(MODAL_WIDTH, MODAL_HEIGHT)
    modal:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    modal:SetMovable(true)
    modal:EnableMouse(true)
    modal:RegisterForDrag("LeftButton")
    modal:SetScript("OnDragStart", modal.StartMoving)
    modal:SetScript("OnDragStop", modal.StopMovingOrSizing)
    modal:SetClampedToScreen(true)
    modal:SetFrameStrata("DIALOG")

    Theme.ApplyWindowBackdrop(modal)

    -- ═══ Title Bar ═══
    local titleBar = CreateFrame("Frame", nil, modal)
    titleBar:SetHeight(TITLE_BAR_HEIGHT)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFontObject(ns.Font.Title)
    titleText:SetPoint("LEFT", 14, 0)
    modal._titleText = titleText

    -- Close button
    local closeBtn = Theme.CreateIconButton(titleBar, 26,
        "Interface\\AddOns\\Disenqueue\\icons\\close", C.danger)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -14, 0)
    closeBtn:SetScript("OnClick", function() modal:Hide() end)

    -- ═══ Tab Pill Row ═══
    local tabRow = CreateFrame("Frame", nil, modal)
    tabRow:SetHeight(TAB_HEIGHT)
    tabRow:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", CODE_MARGIN, -4)
    tabRow:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -CODE_MARGIN, -4)
    modal._tabRow = tabRow

    -- Tab background (rounded pill track)
    local tabTrack = tabRow:CreateTexture(nil, "BACKGROUND")
    tabTrack:SetAllPoints()
    tabTrack:SetColorTexture(C.surface1.r, C.surface1.g, C.surface1.b, 0.4)

    local tabWidth = (MODAL_WIDTH - CODE_MARGIN * 2) / #TAB_LABELS
    for i, label in ipairs(TAB_LABELS) do
        local btn = CreateFrame("Button", nil, tabRow)
        btn:SetSize(tabWidth, TAB_HEIGHT)
        btn:SetPoint("LEFT", tabRow, "LEFT", (i - 1) * tabWidth, 0)

        local bg = btn:CreateTexture(nil, "ARTWORK")
        bg:SetAllPoints()
        bg:SetColorTexture(C.surface1.r, C.surface1.g, C.surface1.b, 0.6)
        btn._bg = bg

        local labelStr = btn:CreateFontString(nil, "OVERLAY")
        labelStr:SetFontObject(ns.Font.Button)
        labelStr:SetText(label)
        labelStr:SetPoint("CENTER")
        btn._label = labelStr

        btn:SetScript("OnClick", function()
            activeTab = i
            updateTabs()
            -- Only String tab is functional
            if i ~= 1 and not isImportMode then
                modal._codeBlock:SetText("-- Coming soon: " .. label .. " export")
            elseif not isImportMode then
                modal._codeBlock:SetText(currentContent)
            end
        end)

        tabButtons[i] = btn
    end

    -- ═══ Code Block ═══
    local codeBlockHeight = MODAL_HEIGHT - CODE_TOP - FOOTER_HEIGHT - 8
    local codeOuter = CreateFrame("Frame", nil, modal, "BackdropTemplate")
    codeOuter:SetPoint("TOPLEFT", CODE_MARGIN, -CODE_TOP)
    codeOuter:SetPoint("TOPRIGHT", -CODE_MARGIN, -CODE_TOP)
    codeOuter:SetHeight(codeBlockHeight)
    codeOuter:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    codeOuter:SetBackdropColor(C.codeBlockBg.r, C.codeBlockBg.g, C.codeBlockBg.b, 1)
    codeOuter:SetBackdropBorderColor(C.divider.r, C.divider.g, C.divider.b, 0.5)

    -- Violet header tint on top 8px
    local headerTint = codeOuter:CreateTexture(nil, "ARTWORK")
    headerTint:SetHeight(8)
    headerTint:SetPoint("TOPLEFT", 1, -1)
    headerTint:SetPoint("TOPRIGHT", -1, -1)
    headerTint:SetGradient("VERTICAL",
        CreateColor(C.violet.r, C.violet.g, C.violet.b, 0),
        CreateColor(C.violet.r, C.violet.g, C.violet.b, 0.15)
    )

    -- ScrollFrame for EditBox (custom, no Blizzard template)
    local scrollFrame = CreateFrame("ScrollFrame", nil, codeOuter)
    scrollFrame:SetPoint("TOPLEFT", 8, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -14, 8)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ns.Font.Mono)
    editBox:SetWidth(MODAL_WIDTH - CODE_MARGIN * 2 - 30)
    editBox:SetHeight(codeBlockHeight - 18)
    editBox:SetTextColor(C.text.r, C.text.g, C.text.b)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollFrame:SetScrollChild(editBox)
    modal._codeBlock = editBox

    -- Custom scrollbar track (4px wide, right side of codeOuter)
    local scrollTrack = codeOuter:CreateTexture(nil, "OVERLAY")
    scrollTrack:SetWidth(4)
    scrollTrack:SetPoint("TOPRIGHT", codeOuter, "TOPRIGHT", -4, -10)
    scrollTrack:SetPoint("BOTTOMRIGHT", codeOuter, "BOTTOMRIGHT", -4, 8)
    scrollTrack:SetColorTexture(C.surface1.r, C.surface1.g, C.surface1.b, 0.5)

    local scrollThumb = codeOuter:CreateTexture(nil, "OVERLAY", nil, 1)
    scrollThumb:SetWidth(4)
    scrollThumb:SetColorTexture(C.violetSoft.r, C.violetSoft.g, C.violetSoft.b, 0.9)
    scrollThumb:SetPoint("TOPRIGHT", scrollTrack, "TOPRIGHT", 0, 0)
    scrollThumb:SetHeight(30)
    scrollThumb:Hide()

    -- Update scrollbar thumb position
    local function updateScrollThumb()
        local maxScroll = scrollFrame:GetVerticalScrollRange()
        if maxScroll > 0 then
            local trackH = scrollTrack:GetHeight()
            local thumbH = math.max(20, (scrollFrame:GetHeight() / (scrollFrame:GetHeight() + maxScroll)) * trackH)
            scrollThumb:SetHeight(thumbH)
            local offset = (scrollFrame:GetVerticalScroll() / maxScroll) * (trackH - thumbH)
            scrollThumb:ClearAllPoints()
            scrollThumb:SetPoint("TOPRIGHT", scrollTrack, "TOPRIGHT", 0, -offset)
            scrollThumb:Show()
            scrollTrack:Show()
        else
            scrollThumb:Hide()
            scrollTrack:Hide()
        end
    end

    scrollFrame:SetScript("OnScrollRangeChanged", function() updateScrollThumb() end)
    scrollFrame:SetScript("OnVerticalScroll", function() updateScrollThumb() end)

    -- Mouse wheel scrolling
    codeOuter:EnableMouseWheel(true)
    codeOuter:SetScript("OnMouseWheel", function(_, delta)
        local current = scrollFrame:GetVerticalScroll()
        local maxScroll = scrollFrame:GetVerticalScrollRange()
        local step = 40
        local newScroll = math.max(0, math.min(current - delta * step, maxScroll))
        scrollFrame:SetVerticalScroll(newScroll)
    end)

    -- Also handle wheel on the editbox itself
    editBox:EnableMouseWheel(true)
    editBox:SetScript("OnMouseWheel", function(_, delta)
        local current = scrollFrame:GetVerticalScroll()
        local maxScroll = scrollFrame:GetVerticalScrollRange()
        local step = 40
        local newScroll = math.max(0, math.min(current - delta * step, maxScroll))
        scrollFrame:SetVerticalScroll(newScroll)
    end)

    -- Auto-scroll when cursor moves (replaces Blizzard template behavior)
    editBox:SetScript("OnCursorChanged", function(_, _, y, _, cursorH)
        y = -y
        local offset = scrollFrame:GetVerticalScroll()
        local frameH = scrollFrame:GetHeight()
        if y < offset then
            scrollFrame:SetVerticalScroll(y)
        elseif y + cursorH > offset + frameH then
            scrollFrame:SetVerticalScroll(y + cursorH - frameH)
        end
    end)

    -- Click anywhere in the code area to focus the editbox
    codeOuter:EnableMouse(true)
    codeOuter:SetScript("OnMouseDown", function()
        editBox:SetFocus()
    end)

    -- ═══ Footer ═══
    local footer = CreateFrame("Frame", nil, modal)
    footer:SetHeight(FOOTER_HEIGHT)
    footer:SetPoint("BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", 0, 0)

    -- Copy/Import action button
    local actionBtn = Theme.CreatePrimaryButton(footer, 100, 34, "Copy",
        "Interface\\AddOns\\Disenqueue\\icons\\copy")
    actionBtn:SetPoint("RIGHT", footer, "RIGHT", -14, 0)
    modal._actionBtn = actionBtn

    -- Status label (shows "Copied!" or "Imported!")
    local statusLabel = footer:CreateFontString(nil, "OVERLAY")
    statusLabel:SetFontObject(ns.Font.SlotLabel)
    statusLabel:SetPoint("RIGHT", actionBtn, "LEFT", -10, 0)
    statusLabel:SetTextColor(C.success.r, C.success.g, C.success.b)
    statusLabel:SetText("")
    modal._statusLabel = statusLabel

    -- Item count hint (left aligned)
    local countHint = footer:CreateFontString(nil, "OVERLAY")
    countHint:SetFontObject(ns.Font.Mono)
    countHint:SetPoint("LEFT", 14, 0)
    countHint:SetTextColor(C.textDim.r, C.textDim.g, C.textDim.b)
    modal._countHint = countHint

    modal:Hide()
    return modal
end

-- ─── Show Export ─────────────────────────────────────────────────────────────

local function showExport(content, itemCount)
    if not modal then createExportModal() end

    isImportMode = false
    currentContent = content or ""
    activeTab = 1
    updateTabs()
    modal._tabRow:Hide()

    modal._titleText:SetText("Export Locked List")
    modal._codeBlock:SetText(currentContent)
    modal._codeBlock:SetCursorPosition(0)
    modal._codeBlock:EnableKeyboard(true)

    if itemCount and itemCount > 0 then
        modal._countHint:SetText(itemCount .. " items")
    else
        modal._countHint:SetText("")
    end

    modal._actionBtn:SetLabel("Copy")
    modal._actionBtn:SetScript("OnClick", function()
        modal._codeBlock:SetFocus()
        modal._codeBlock:HighlightText()
        modal._statusLabel:SetText("Ctrl+C to copy")
        C_Timer.After(3, function()
            if modal and modal._statusLabel then
                modal._statusLabel:SetText("")
            end
        end)
    end)

    modal._statusLabel:SetText("")
    modal:Show()
end

-- ─── Show Import ─────────────────────────────────────────────────────────────

local function showImport()
    if not modal then createExportModal() end

    isImportMode = true
    currentContent = ""
    activeTab = 1
    updateTabs()
    modal._tabRow:Hide()

    modal._titleText:SetText("Import Locked List")
    modal._codeBlock:SetText("")
    modal._codeBlock:EnableKeyboard(true) -- editable in import mode
    modal._codeBlock:SetFocus()
    modal._countHint:SetText("Paste your exported string below")

    modal._actionBtn:SetLabel("Import")
    modal._actionBtn:SetScript("OnClick", function()
        local text = modal._codeBlock:GetText()
        if text and text ~= "" then
            local count = ns.ImportLockedList(text)
            if count and count > 0 then
                modal._statusLabel:SetText(count .. " items imported!")
                modal._codeBlock:SetText("")
                C_Timer.After(2, function()
                    if modal then modal:Hide() end
                end)
            else
                modal._statusLabel:SetText("Invalid format")
                modal._statusLabel:SetTextColor(C.danger.r, C.danger.g, C.danger.b)
                C_Timer.After(2, function()
                    if modal and modal._statusLabel then
                        modal._statusLabel:SetText("")
                        modal._statusLabel:SetTextColor(C.success.r, C.success.g, C.success.b)
                    end
                end)
            end
        end
    end)

    modal._statusLabel:SetText("")
    modal:Show()
end

-- ─── Callback Wiring ─────────────────────────────────────────────────────────

ns.RegisterCallback("ADDON_LOADED", function()
    -- Pre-create modal on load (lazy pattern still works, but faster open)
end)

ns.RegisterCallback("SHOW_EXPORT", function(content, itemCount)
    showExport(content, itemCount)
end)

ns.RegisterCallback("SHOW_IMPORT", function()
    showImport()
end)
