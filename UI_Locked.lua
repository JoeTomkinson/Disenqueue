local _, ns = ...

-- ═══════════════════════════════════════════════════════════════════════════════
-- UI_Locked.lua — Locked Items companion panel
-- ═══════════════════════════════════════════════════════════════════════════════

local C = ns.C
local Theme = ns.Theme

local PANEL_WIDTH = 360
local TITLE_BAR_HEIGHT = 48
local SECTION_HEADER_HEIGHT = 28
local ROW_HEIGHT = 38
local DEFAULT_VISIBLE_ROWS = 10
local MAX_VISIBLE_ROWS = 18  -- max rows when fully expanded
local MIN_VISIBLE_ROWS = 4   -- min rows when collapsed
local FOOTER_HEIGHT = 36

local lockedRows = {}
local scrollOffset = 0
local visibleRows = DEFAULT_VISIBLE_ROWS
local panel

-- ─── Row Widget ──────────────────────────────────────────────────────────────

local function createLockedRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    -- Icon tile (30x30)
    local iconTile = Theme.CreateIconTile(row, 30)
    iconTile:SetPoint("LEFT", 14, 0)
    row._iconTile = iconTile

    -- Tag icon (14px, heart or bolt)
    local tagIcon = row:CreateTexture(nil, "OVERLAY")
    tagIcon:SetSize(14, 14)
    tagIcon:SetPoint("LEFT", iconTile, "RIGHT", 8, 0)
    row._tagIcon = tagIcon

    -- Item name
    local nameStr = row:CreateFontString(nil, "OVERLAY")
    nameStr:SetFontObject(ns.Font.Body)
    nameStr:SetPoint("LEFT", tagIcon, "RIGHT", 6, 0)
    nameStr:SetPoint("RIGHT", row, "RIGHT", -14, 0)
    nameStr:SetJustifyH("LEFT")
    nameStr:SetWordWrap(false)
    row._name = nameStr

    -- Hover highlight
    local highlight = row:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints()
    highlight:SetColorTexture(C.surface1.r, C.surface1.g, C.surface1.b, 0)

    row:SetScript("OnEnter", function(self)
        highlight:SetColorTexture(C.surface1.r, C.surface1.g, C.surface1.b, 0.5)
        if self._itemID then
            ns.AnchorTooltip(self)
            GameTooltip:SetItemByID(self._itemID)
            GameTooltip:AddLine(" ")
            if self._isAuto then
                GameTooltip:AddLine("Auto-blocked (failed to disenchant)", C.warning.r, C.warning.g, C.warning.b)
            end
            GameTooltip:AddLine("Click to unlock", C.success.r, C.success.g, C.success.b)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        highlight:SetColorTexture(C.surface1.r, C.surface1.g, C.surface1.b, 0)
        GameTooltip:Hide()
    end)

    -- Click to unlock
    row:SetScript("OnClick", function(self)
        if self._itemID then
            local entry = DisenqueueDB.protectedItemIDs[self._itemID]
            local name = (type(entry) == "table" and entry.name) or tostring(self._itemID)
            ns.ToggleLock(self._itemID, name)
        end
    end)

    row._itemID = nil
    row._isAuto = false
    row:Hide()
    return row
end

-- ─── Refresh ─────────────────────────────────────────────────────────────────

local favHeader, autoHeader
local favCountStr, autoCountStr

local function refreshLockedList()
    if not panel or not panel:IsShown() then return end

    -- Collect and sort items
    local manualItems = {}
    local autoItems = {}
    for itemID, entry in pairs(DisenqueueDB.protectedItemIDs) do
        local name = (type(entry) == "table" and entry.name) or tostring(itemID)
        local isAuto = (type(entry) == "table" and entry.autoProtected) or false
        if isAuto then
            table.insert(autoItems, { itemID = itemID, name = name, isAuto = true })
        else
            table.insert(manualItems, { itemID = itemID, name = name, isAuto = false })
        end
    end
    table.sort(manualItems, function(a, b) return a.name < b.name end)
    table.sort(autoItems, function(a, b) return a.name < b.name end)

    -- Update section headers
    if favCountStr then
        favCountStr:SetText(tostring(#manualItems))
    end
    if autoCountStr then
        autoCountStr:SetText(tostring(#autoItems))
    end

    -- Combine for display
    local items = {}
    for _, v in ipairs(manualItems) do table.insert(items, v) end
    for _, v in ipairs(autoItems) do table.insert(items, v) end

    -- Clamp scroll
    local maxScroll = math.max(0, #items - visibleRows)
    if scrollOffset > maxScroll then scrollOffset = maxScroll end

    -- Render rows
    for i = 1, visibleRows do
        local row = lockedRows[i]
        if not row then break end

        local dataIndex = i + scrollOffset
        if dataIndex <= #items then
            local entry = items[dataIndex]
            row._itemID = entry.itemID
            row._isAuto = entry.isAuto

            -- Icon
            local icon = GetItemIcon(entry.itemID)
            row._iconTile:SetIcon(icon or "Interface\\Icons\\INV_Misc_QuestionMark")

            -- Quality color for border
            local _, _, itemQuality = GetItemInfo(entry.itemID)
            if itemQuality and ITEM_QUALITY_COLORS[itemQuality] then
                local qc = ITEM_QUALITY_COLORS[itemQuality]
                row._iconTile:SetQualityColor(qc.r, qc.g, qc.b)
                row._name:SetTextColor(qc.r, qc.g, qc.b)
            else
                row._iconTile:SetQualityColor(C.text.r, C.text.g, C.text.b)
                row._name:SetTextColor(C.text.r, C.text.g, C.text.b)
            end

            -- Tag icon
            if entry.isAuto then
                row._tagIcon:SetTexture("Interface\\AddOns\\Disenqueue\\icons\\bolt")
                row._tagIcon:SetVertexColor(C.warning.r, C.warning.g, C.warning.b)
                row._name:SetText("|cff" .. string.format("%02x%02x%02x",
                    C.textMute.r * 255, C.textMute.g * 255, C.textMute.b * 255)
                    .. "[A]|r " .. entry.name)
            else
                row._tagIcon:SetTexture("Interface\\AddOns\\Disenqueue\\icons\\heart")
                row._tagIcon:SetVertexColor(C.danger.r, C.danger.g, C.danger.b)
                row._name:SetText(entry.name)
            end

            row:Show()
        else
            row._itemID = nil
            row:Hide()
        end
    end

    -- Hide rows beyond current visible count
    for i = visibleRows + 1, MAX_VISIBLE_ROWS do
        if lockedRows[i] then lockedRows[i]:Hide() end
    end

    -- Footer count
    if panel._footerCount then
        panel._footerCount:SetText(("%d locked \194\183 %d auto-blocked"):format(#manualItems, #autoItems))
    end

    -- Show/hide empty state
    if panel._emptyText then
        panel._emptyText:SetShown(#items == 0)
    end

    -- Update scrollbar
    if panel._scrollThumb and panel._scrollTrack then
        if maxScroll > 0 and #items > visibleRows then
            local trackH = panel._scrollTrack:GetHeight()
            local thumbHeight = math.max(20, (visibleRows / #items) * trackH)
            panel._scrollThumb:SetHeight(thumbHeight)
            local trackSpace = trackH - thumbHeight
            local offset = (scrollOffset / maxScroll) * trackSpace
            panel._scrollThumb:ClearAllPoints()
            panel._scrollThumb:SetPoint("TOPRIGHT", panel._scrollTrack, "TOPRIGHT", 0, -offset)
            panel._scrollThumb:Show()
            panel._scrollTrack:Show()
        else
            panel._scrollThumb:Hide()
            panel._scrollTrack:Hide()
        end
    end
end

-- ─── Panel Construction ──────────────────────────────────────────────────────

local function createLockedPanel()
    panel = CreateFrame("Frame", "WDQ_LockedPanel", UIParent, "BackdropTemplate")
    local totalHeight = TITLE_BAR_HEIGHT + SECTION_HEADER_HEIGHT * 2 + DEFAULT_VISIBLE_ROWS * ROW_HEIGHT + FOOTER_HEIGHT
    panel:SetSize(PANEL_WIDTH, totalHeight)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        DisenqueueDB.lockedPos = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    panel:SetClampedToScreen(true)
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel(10)

    -- Backdrop
    Theme.ApplyWindowBackdrop(panel)

    -- Anchor to right of main frame
    local mainFrame = _G.WDQ_QueueFrame
    if mainFrame then
        panel:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 8, 0)
    else
        panel:SetPoint("CENTER", UIParent, "CENTER", 250, 0)
    end

    -- Restore saved position
    if DisenqueueDB.lockedPos then
        local pos = DisenqueueDB.lockedPos
        panel:ClearAllPoints()
        panel:SetPoint(pos.point or "TOPLEFT", UIParent, pos.relPoint or "TOPLEFT", pos.x or 0, pos.y or 0)
    end

    -- ═══ Title Bar ═══
    local titleBar = CreateFrame("Frame", nil, panel)
    titleBar:SetHeight(TITLE_BAR_HEIGHT)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)

    -- Lock icon
    local lockIcon = titleBar:CreateTexture(nil, "ARTWORK")
    lockIcon:SetSize(20, 20)
    lockIcon:SetPoint("LEFT", 14, 0)
    lockIcon:SetTexture("Interface\\AddOns\\Disenqueue\\icons\\lock-closed")
    lockIcon:SetVertexColor(C.warning.r, C.warning.g, C.warning.b)

    -- Title
    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFontObject(ns.Font.Title)
    titleText:SetText("Locked Items")
    titleText:SetPoint("LEFT", lockIcon, "RIGHT", 8, 0)

    -- Close button
    local closeBtn = Theme.CreateIconButton(titleBar, 26,
        "Interface\\AddOns\\Disenqueue\\icons\\close", C.danger)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -14, 0)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    -- Import button (download icon, success color)
    local importBtn = Theme.CreateIconButton(titleBar, 26,
        "Interface\\AddOns\\Disenqueue\\icons\\download", C.success)
    importBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    importBtn:SetScript("OnClick", function()
        ns.FireCallback("SHOW_IMPORT")
    end)
    importBtn:SetScript("OnEnter", function(self)
        ns.AnchorTooltip(self)
        GameTooltip:AddLine("Import Locked List")
        GameTooltip:AddLine("Paste an exported string to add items", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    importBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Export button (upload icon, violet)
    local exportBtn = Theme.CreateIconButton(titleBar, 26,
        "Interface\\AddOns\\Disenqueue\\icons\\upload", C.violet)
    exportBtn:SetPoint("RIGHT", importBtn, "LEFT", -4, 0)
    exportBtn:SetScript("OnClick", function()
        local exportStr = ns.ExportLockedList()
        if exportStr then
            ns.FireCallback("SHOW_EXPORT", exportStr)
        end
    end)
    exportBtn:SetScript("OnEnter", function(self)
        ns.AnchorTooltip(self)
        GameTooltip:AddLine("Export Locked List")
        GameTooltip:AddLine("Copy a shareable string of your locked items", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    exportBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ═══ Section Headers ═══
    local contentTop = -(TITLE_BAR_HEIGHT)

    -- Favorites section header
    favHeader = CreateFrame("Frame", nil, panel)
    favHeader:SetHeight(SECTION_HEADER_HEIGHT)
    favHeader:SetPoint("TOPLEFT", 0, contentTop)
    favHeader:SetPoint("TOPRIGHT", 0, contentTop)

    local favIcon = favHeader:CreateTexture(nil, "ARTWORK")
    favIcon:SetSize(12, 12)
    favIcon:SetPoint("LEFT", 14, 0)
    favIcon:SetTexture("Interface\\AddOns\\Disenqueue\\icons\\heart")
    favIcon:SetVertexColor(C.danger.r, C.danger.g, C.danger.b)

    local favLabel = favHeader:CreateFontString(nil, "OVERLAY")
    favLabel:SetFontObject(ns.Font.SectionHeader)
    favLabel:SetText("FAVORITES")
    favLabel:SetPoint("LEFT", favIcon, "RIGHT", 6, 0)

    favCountStr = favHeader:CreateFontString(nil, "OVERLAY")
    favCountStr:SetFontObject(ns.Font.Chip)
    favCountStr:SetText("0")
    favCountStr:SetTextColor(C.textDim.r, C.textDim.g, C.textDim.b)
    favCountStr:SetPoint("LEFT", favLabel, "RIGHT", 6, 0)

    local favHint = favHeader:CreateFontString(nil, "OVERLAY")
    favHint:SetFontObject(ns.Font.SlotLabel)
    favHint:SetText("Never disenchant")
    favHint:SetTextColor(C.textGhost.r, C.textGhost.g, C.textGhost.b)
    favHint:SetPoint("RIGHT", favHeader, "RIGHT", -14, 0)

    -- Auto-blocked section header
    autoHeader = CreateFrame("Frame", nil, panel)
    autoHeader:SetHeight(SECTION_HEADER_HEIGHT)
    autoHeader:SetPoint("TOPLEFT", favHeader, "BOTTOMLEFT", 0, 0)
    autoHeader:SetPoint("TOPRIGHT", favHeader, "BOTTOMRIGHT", 0, 0)

    local autoIcon = autoHeader:CreateTexture(nil, "ARTWORK")
    autoIcon:SetSize(12, 12)
    autoIcon:SetPoint("LEFT", 14, 0)
    autoIcon:SetTexture("Interface\\AddOns\\Disenqueue\\icons\\bolt")
    autoIcon:SetVertexColor(C.warning.r, C.warning.g, C.warning.b)

    local autoLabel = autoHeader:CreateFontString(nil, "OVERLAY")
    autoLabel:SetFontObject(ns.Font.SectionHeader)
    autoLabel:SetText("AUTO-BLOCKED")
    autoLabel:SetPoint("LEFT", autoIcon, "RIGHT", 6, 0)

    autoCountStr = autoHeader:CreateFontString(nil, "OVERLAY")
    autoCountStr:SetFontObject(ns.Font.Chip)
    autoCountStr:SetText("0")
    autoCountStr:SetTextColor(C.textDim.r, C.textDim.g, C.textDim.b)
    autoCountStr:SetPoint("LEFT", autoLabel, "RIGHT", 6, 0)

    local autoHint = autoHeader:CreateFontString(nil, "OVERLAY")
    autoHint:SetFontObject(ns.Font.SlotLabel)
    autoHint:SetText("Bind-on-equip rule")
    autoHint:SetTextColor(C.textGhost.r, C.textGhost.g, C.textGhost.b)
    autoHint:SetPoint("RIGHT", autoHeader, "RIGHT", -14, 0)

    -- ═══ List Area ═══
    local listArea = CreateFrame("Frame", nil, panel)
    listArea:SetPoint("TOPLEFT", autoHeader, "BOTTOMLEFT", 0, 0)
    listArea:SetPoint("TOPRIGHT", autoHeader, "BOTTOMRIGHT", 0, 0)
    listArea:SetHeight(visibleRows * ROW_HEIGHT)
    listArea:SetClipsChildren(true)
    panel._listArea = listArea

    -- Pre-create max rows for resize expansion
    for i = 1, MAX_VISIBLE_ROWS do
        local row = createLockedRow(listArea, i)
        row:SetPoint("TOPLEFT", listArea, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", listArea, "TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)
        lockedRows[i] = row
    end

    -- Empty text
    local emptyText = listArea:CreateFontString(nil, "OVERLAY")
    emptyText:SetFontObject(ns.Font.BodyRegular)
    emptyText:SetPoint("CENTER")
    emptyText:SetText("No locked items")
    emptyText:SetTextColor(C.textMute.r, C.textMute.g, C.textMute.b)
    panel._emptyText = emptyText

    -- Scrollbar track (4px wide, right side)
    local scrollTrack = listArea:CreateTexture(nil, "OVERLAY")
    scrollTrack:SetWidth(4)
    scrollTrack:SetPoint("TOPRIGHT", listArea, "TOPRIGHT", -4, -4)
    scrollTrack:SetPoint("BOTTOMRIGHT", listArea, "BOTTOMRIGHT", -4, 4)
    scrollTrack:SetColorTexture(C.surface1.r, C.surface1.g, C.surface1.b, 0.5)
    panel._scrollTrack = scrollTrack

    local scrollThumb = listArea:CreateTexture(nil, "OVERLAY", nil, 1)
    scrollThumb:SetWidth(4)
    scrollThumb:SetColorTexture(C.violetSoft.r, C.violetSoft.g, C.violetSoft.b, 0.9)
    scrollThumb:SetPoint("TOPRIGHT", scrollTrack, "TOPRIGHT", 0, 0)
    scrollThumb:SetHeight(40)
    scrollThumb:Hide()
    panel._scrollThumb = scrollThumb

    -- Mouse wheel scroll
    listArea:EnableMouseWheel(true)
    listArea:SetScript("OnMouseWheel", function(_, delta)
        local totalItems = 0
        for _ in pairs(DisenqueueDB.protectedItemIDs) do totalItems = totalItems + 1 end
        local maxScroll = math.max(0, totalItems - visibleRows)
        scrollOffset = scrollOffset - delta
        scrollOffset = math.max(0, math.min(scrollOffset, maxScroll))
        refreshLockedList()
    end)

    -- ═══ Footer ═══
    local footer = CreateFrame("Frame", nil, panel)
    footer:SetHeight(FOOTER_HEIGHT)
    footer:SetPoint("BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", 0, 0)

    -- Divider
    local footerDiv = footer:CreateTexture(nil, "ARTWORK")
    footerDiv:SetHeight(1)
    footerDiv:SetPoint("TOPLEFT", 14, 0)
    footerDiv:SetPoint("TOPRIGHT", -14, 0)
    footerDiv:SetColorTexture(C.divider.r, C.divider.g, C.divider.b, C.divider.a)

    -- Count text
    local footerCount = footer:CreateFontString(nil, "OVERLAY")
    footerCount:SetFontObject(ns.Font.Mono)
    footerCount:SetPoint("LEFT", 14, 0)
    footerCount:SetTextColor(C.textDim.r, C.textDim.g, C.textDim.b)
    panel._footerCount = footerCount

    -- Personality line (italic feel via lowercase + ellipsis)
    local personality = footer:CreateFontString(nil, "OVERLAY")
    personality:SetFontObject(ns.Font.SlotLabel)
    personality:SetText("your sentimental side, organised")
    personality:SetTextColor(1, 0.82, 0)
    personality:SetPoint("RIGHT", -14, 0)

    -- ═══ Vertical Resize ═══
    local minH = TITLE_BAR_HEIGHT + SECTION_HEADER_HEIGHT * 2 + MIN_VISIBLE_ROWS * ROW_HEIGHT + FOOTER_HEIGHT
    local maxH = TITLE_BAR_HEIGHT + SECTION_HEADER_HEIGHT * 2 + MAX_VISIBLE_ROWS * ROW_HEIGHT + FOOTER_HEIGHT

    Theme.CreateResizeGrip(panel, minH, maxH,
        -- Live: update layout without snapping
        function(newHeight)
            local listSpace = newHeight - TITLE_BAR_HEIGHT - SECTION_HEADER_HEIGHT * 2 - FOOTER_HEIGHT
            local newRows = math.floor(listSpace / ROW_HEIGHT)
            newRows = math.max(MIN_VISIBLE_ROWS, math.min(newRows, MAX_VISIBLE_ROWS))
            if newRows ~= visibleRows then
                visibleRows = newRows
                panel._listArea:SetHeight(visibleRows * ROW_HEIGHT)
                refreshLockedList()
            end
        end,
        -- Final: snap to row boundary + persist
        function(newHeight)
            local listSpace = newHeight - TITLE_BAR_HEIGHT - SECTION_HEADER_HEIGHT * 2 - FOOTER_HEIGHT
            local newRows = math.floor(listSpace / ROW_HEIGHT)
            newRows = math.max(MIN_VISIBLE_ROWS, math.min(newRows, MAX_VISIBLE_ROWS))
            visibleRows = newRows
            local snapHeight = TITLE_BAR_HEIGHT + SECTION_HEADER_HEIGHT * 2 + visibleRows * ROW_HEIGHT + FOOTER_HEIGHT
            panel:SetHeight(snapHeight)
            panel._listArea:SetHeight(visibleRows * ROW_HEIGHT)
            refreshLockedList()
            DisenqueueDB.lockedPanelHeight = snapHeight
        end
    )

    -- Restore saved height
    if DisenqueueDB.lockedPanelHeight then
        local savedH = DisenqueueDB.lockedPanelHeight
        local listSpace = savedH - TITLE_BAR_HEIGHT - SECTION_HEADER_HEIGHT * 2 - FOOTER_HEIGHT
        local newRows = math.floor(listSpace / ROW_HEIGHT)
        newRows = math.max(MIN_VISIBLE_ROWS, math.min(newRows, MAX_VISIBLE_ROWS))
        visibleRows = newRows
        panel:SetHeight(savedH)
        panel._listArea:SetHeight(visibleRows * ROW_HEIGHT)
    end

    panel:SetScript("OnShow", function()
        refreshLockedList()
    end)

    panel:Hide()
    return panel
end

-- ─── Callback Wiring ─────────────────────────────────────────────────────────

ns.RegisterCallback("ADDON_LOADED", function()
    createLockedPanel()
end)

ns.RegisterCallback("LOCKED_UPDATED", function()
    refreshLockedList()
end)
