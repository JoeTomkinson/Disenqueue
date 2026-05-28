local _, ns = ...

-- ═══════════════════════════════════════════════════════════════════════════════
-- UI_Main.lua — Main queue window (idle + processing states)
-- ═══════════════════════════════════════════════════════════════════════════════

local C = ns.C
local Theme = ns.Theme

-- Layout constants
local FRAME_WIDTH = 420
local TITLE_BAR_HEIGHT = 56
local META_STRIP_HEIGHT = 44
local ROW_HEIGHT = 54
local DEFAULT_VISIBLE_ROWS = 9
local MAX_VISIBLE_ROWS = 16  -- max rows when fully expanded
local MIN_VISIBLE_ROWS = 4   -- min rows when collapsed
local FOOTER_HEIGHT = 88
local LIST_HEIGHT = DEFAULT_VISIBLE_ROWS * ROW_HEIGHT

local rows = {}
local scrollOffset = 0
local visibleRows = DEFAULT_VISIBLE_ROWS
local mainFrame

-- ─── Row Widget ──────────────────────────────────────────────────────────────

local function createRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    -- Hover highlight (violet horizontal gradient from left)
    local hoverBg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    hoverBg:SetAllPoints()
    hoverBg:SetColorTexture(1, 1, 1, 1)
    hoverBg:SetGradient("HORIZONTAL",
        CreateColor(C.violet.r, C.violet.g, C.violet.b, 0.12),
        CreateColor(C.violet.r, C.violet.g, C.violet.b, 0)
    )
    hoverBg:Hide()
    row._hoverBg = hoverBg

    -- Active left border (2px violet)
    local leftBorder = row:CreateTexture(nil, "OVERLAY")
    leftBorder:SetWidth(2)
    leftBorder:SetPoint("TOPLEFT")
    leftBorder:SetPoint("BOTTOMLEFT")
    leftBorder:SetColorTexture(C.violet.r, C.violet.g, C.violet.b, 1)
    leftBorder:Hide()
    row._leftBorder = leftBorder

    -- Icon tile (38x38)
    local iconTile = Theme.CreateIconTile(row, 38)
    iconTile:SetPoint("LEFT", 14, 0)
    row._iconTile = iconTile

    -- Text block
    local nameStr = row:CreateFontString(nil, "OVERLAY")
    nameStr:SetFontObject(ns.Font.Body)
    nameStr:SetPoint("TOPLEFT", iconTile, "TOPRIGHT", 12, -6)
    nameStr:SetPoint("RIGHT", row, "RIGHT", -80, 0)
    nameStr:SetJustifyH("LEFT")
    nameStr:SetWordWrap(false)
    row._name = nameStr

    local slotStr = row:CreateFontString(nil, "OVERLAY")
    slotStr:SetFontObject(ns.Font.SlotLabel)
    slotStr:SetPoint("TOPLEFT", nameStr, "BOTTOMLEFT", 0, -3)
    slotStr:SetJustifyH("LEFT")
    row._slot = slotStr

    -- Lock toggle button (24x24)
    local lockBtn = Theme.CreateIconButton(row, 24,
        "Interface\\AddOns\\Disenqueue\\icons\\lock-open", C.textDim, "Lock Item")
    lockBtn:SetPoint("RIGHT", row, "RIGHT", -38, 0)
    lockBtn:SetScript("OnClick", function()
        if ns.isProcessing then return end
        local idx = row._dataIndex
        if idx then ns.LockFromQueue(idx) end
    end)
    row._lockBtn = lockBtn

    -- Hide/eye toggle button (24x24)
    local hideBtn = Theme.CreateIconButton(row, 24,
        "Interface\\AddOns\\Disenqueue\\icons\\eye-off", C.textDim, "Hide from Queue")
    hideBtn:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    hideBtn:SetScript("OnClick", function()
        if ns.isProcessing then return end
        local idx = row._dataIndex
        if idx then ns.HideFromQueue(idx) end
    end)
    row._hideBtn = hideBtn

    -- Processing state elements
    -- "CHANNELING..." label (shown during active)
    local channelLabel = row:CreateFontString(nil, "OVERLAY")
    channelLabel:SetFontObject(ns.Font.SlotLabel)
    channelLabel:SetPoint("TOPLEFT", nameStr, "BOTTOMLEFT", 0, -3)
    channelLabel:SetText("CHANNELING\226\128\166")
    channelLabel:SetTextColor(C.violetHi.r, C.violetHi.g, C.violetHi.b)
    channelLabel:Hide()
    row._channelLabel = channelLabel

    -- "DUSTED" label (shown for done items)
    local dustedLabel = row:CreateFontString(nil, "OVERLAY")
    dustedLabel:SetFontObject(ns.Font.SlotLabel)
    dustedLabel:SetPoint("TOPLEFT", nameStr, "BOTTOMLEFT", 0, -3)
    dustedLabel:SetText("DUSTED")
    dustedLabel:SetTextColor(C.textMute.r, C.textMute.g, C.textMute.b)
    dustedLabel:Hide()
    row._dustedLabel = dustedLabel

    -- Pulsing dot (6px, violet)
    local dot = row:CreateTexture(nil, "OVERLAY")
    dot:SetSize(6, 6)
    dot:SetPoint("RIGHT", row, "RIGHT", -16, 0)
    dot:SetColorTexture(C.violet.r, C.violet.g, C.violet.b, 1)
    dot:Hide()
    row._dot = dot

    -- Dot pulse animation
    local dotAG = dot:CreateAnimationGroup()
    dotAG:SetLooping("BOUNCE")
    local dotAlpha = dotAG:CreateAnimation("Alpha")
    dotAlpha:SetFromAlpha(0.4)
    dotAlpha:SetToAlpha(1.0)
    dotAlpha:SetDuration(0.6)
    dotAlpha:SetSmoothing("IN_OUT")
    local dotScale = dotAG:CreateAnimation("Scale")
    dotScale:SetScaleFrom(0.85, 0.85)
    dotScale:SetScaleTo(1.10, 1.10)
    dotScale:SetDuration(0.6)
    dotScale:SetSmoothing("IN_OUT")
    row._dotAG = dotAG

    -- Shimmer sweep texture (for active row processing animation)
    local shimmer = row:CreateTexture(nil, "OVERLAY", nil, 2)
    shimmer:SetHeight(ROW_HEIGHT)
    shimmer:SetWidth(80)
    shimmer:SetColorTexture(1, 1, 1, 0.15)
    shimmer:SetGradient("HORIZONTAL",
        CreateColor(C.violet.r, C.violet.g, C.violet.b, 0),
        CreateColor(C.violet.r, C.violet.g, C.violet.b, 0.3)
    )
    shimmer:SetBlendMode("ADD")
    shimmer:SetPoint("LEFT", row, "LEFT", -80, 0)
    shimmer:Hide()
    row._shimmer = shimmer

    -- Shimmer animation
    local shimmerAG = shimmer:CreateAnimationGroup()
    shimmerAG:SetLooping("REPEAT")
    local shimmerTrans = shimmerAG:CreateAnimation("Translation")
    shimmerTrans:SetOffset(FRAME_WIDTH + 160, 0)
    shimmerTrans:SetDuration(1.8)
    shimmerTrans:SetSmoothing("IN_OUT")
    row._shimmerAG = shimmerAG

    -- Row hover interaction
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if not ns.isProcessing then
            self._hoverBg:Show()
            self._leftBorder:Show()
        end
        -- Tooltip
        local idx = self._dataIndex
        if idx and idx <= #ns.queue then
            local entry = ns.queue[idx]
            ns.AnchorTooltip(self)
            GameTooltip:SetBagItem(entry.bag, entry.slot)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        if not ns.isProcessing then
            self._hoverBg:Hide()
            self._leftBorder:Hide()
        end
        GameTooltip:Hide()
    end)

    row._dataIndex = nil
    row._state = "normal" -- "normal", "active", "done"
    row:Hide()
    return row
end

-- ─── Row State Management ────────────────────────────────────────────────────

local function setRowState(row, state)
    row._state = state

    if state == "done" then
        row:SetAlpha(0.35)
        row._name:SetAlpha(1) -- alpha is inherited
        row._slot:Hide()
        row._channelLabel:Hide()
        row._dustedLabel:Show()
        row._lockBtn:Hide()
        row._hideBtn:Hide()
        row._hoverBg:Hide()
        row._leftBorder:Hide()
        row._dot:Hide()
        row._dotAG:Stop()
        row._shimmer:Hide()
        row._shimmerAG:Stop()
    elseif state == "active" then
        row:SetAlpha(1)
        row._slot:Hide()
        row._channelLabel:Show()
        row._dustedLabel:Hide()
        row._lockBtn:Hide()
        row._hideBtn:Hide()
        row._hoverBg:Show()
        row._leftBorder:Show()
        row._dot:Show()
        row._dotAG:Play()
        row._shimmer:Show()
        row._shimmer:SetPoint("LEFT", row, "LEFT", -80, 0)
        row._shimmerAG:Play()
    else -- "normal"
        row:SetAlpha(1)
        row._slot:Show()
        row._channelLabel:Hide()
        row._dustedLabel:Hide()
        row._lockBtn:SetShown(not ns.isProcessing)
        row._hideBtn:SetShown(not ns.isProcessing)
        row._hoverBg:Hide()
        row._leftBorder:Hide()
        row._dot:Hide()
        row._dotAG:Stop()
        row._shimmer:Hide()
        row._shimmerAG:Stop()
    end
end

-- ─── List Refresh ────────────────────────────────────────────────────────────

local doneCount = 0 -- tracks how many items have been processed in this session

local function refreshList()
    local queue = ns.queue

    -- Update meta strip
    if mainFrame._queuedChip then
        mainFrame._queuedChip:Update(#queue, "QUEUED")
    end
    if mainFrame._lockedChip then
        local lockCount = 0
        for _ in pairs(DisenqueueDB.protectedItemIDs) do lockCount = lockCount + 1 end
        mainFrame._lockedChip:Update(lockCount, "LOCKED")
    end
    if mainFrame._dustEst then
        local est = ns.GetDustEstimate()
        if est > 0 then
            mainFrame._dustEst:SetText("~ " .. ns.FormatGold(est) .. " dust est.")
            mainFrame._dustEst:Show()
            mainFrame._dustIcon:Show()
        else
            mainFrame._dustEst:Hide()
            mainFrame._dustIcon:Hide()
        end
    end

    -- Update progress strip (processing mode)
    if ns.isProcessing and mainFrame._progressStrip then
        mainFrame._progressStrip:Show()
        mainFrame._metaStrip:Hide()
        local progress = ns.GetProgress()
        if mainFrame._progressCount then
            mainFrame._progressCount:SetText(("%d / %d"):format(progress.done, progress.total))
        end
        if mainFrame._progressEta then
            if progress.etaSeconds > 0 then
                mainFrame._progressEta:SetText(("~ %ds"):format(math.ceil(progress.etaSeconds)))
            else
                mainFrame._progressEta:SetText("")
            end
        end
        if mainFrame._progressBar and progress.total > 0 then
            local pct = progress.done / progress.total
            local barWidth = mainFrame._progressTrack:GetWidth() * pct
            mainFrame._progressBar:SetWidth(math.max(barWidth, 1))
        end
    elseif mainFrame._progressStrip then
        mainFrame._progressStrip:Hide()
        mainFrame._metaStrip:Show()
    end

    -- Update footer state
    if mainFrame._idleFooter and mainFrame._procFooter then
        mainFrame._idleFooter:SetShown(not ns.isProcessing)
        mainFrame._procFooter:SetShown(ns.isProcessing)
    end

    -- Start button visibility
    if mainFrame._startBtn then
        mainFrame._startBtn:SetShown(not ns.isProcessing and #queue > 0)
    end
    if mainFrame._scanBtn then
        mainFrame._scanBtn:SetShown(not ns.isProcessing)
    end

    -- Empty state
    if mainFrame._emptyText then
        mainFrame._emptyText:SetShown(#queue == 0 and not ns.isProcessing)
    end

    -- Show scroll hint when there are items to browse
    if mainFrame._hintRow then
        mainFrame._hintRow:SetShown(not ns.isProcessing and #queue > 0)
    end

    -- Debug: confirm row rendering attempt
    if #queue > 0 and #rows == 0 then
        print("|cffff9900[Disenqueue] WARNING: Queue has " .. #queue .. " items but rows[] is empty (createMainFrame likely errored)|r")
    end

    -- Render rows
    for i = 1, visibleRows do
        local row = rows[i]
        if not row then break end

        local dataIndex = i + scrollOffset
        if dataIndex <= #queue then
            local entry = queue[dataIndex]
            local itemIcon = entry.itemID and GetItemIcon(entry.itemID)
            row._iconTile:SetIcon(itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")

            -- Quality color
            local r, g, b = 1, 1, 1
            if entry.itemID then
                local _, _, itemQuality = GetItemInfo(entry.itemID)
                if itemQuality and ITEM_QUALITY_COLORS[itemQuality] then
                    local qc = ITEM_QUALITY_COLORS[itemQuality]
                    if qc.color then
                        r, g, b = qc.color:GetRGB()
                    elseif qc.r then
                        r, g, b = qc.r, qc.g, qc.b
                    end
                end
                row._iconTile:SetQualityColor(r, g, b)
            end

            -- Mode prefix
            local prefix = ""
            if entry.mode == ns.MODE_PROSPECT then prefix = "|cff00ccff[P]|r "
            elseif entry.mode == ns.MODE_MILL then prefix = "|cff33cc33[M]|r " end

            row._name:SetText(prefix .. (entry.itemName or "Unknown"))
            row._name:SetTextColor(r, g, b)

            -- Slot label
            local slotLabel = ns.GetSlotLabelByID(entry.itemID)
            row._slot:SetText(slotLabel or "")

            row._dataIndex = dataIndex

            -- Determine row state during processing
            if ns.isProcessing then
                if dataIndex == 1 then
                    setRowState(row, "active")
                else
                    setRowState(row, "normal")
                end
            else
                setRowState(row, "normal")
            end

            row:Show()
        else
            row._dataIndex = nil
            row:Hide()
        end
    end

    -- Hide rows beyond current visible count (pre-created for resize)
    for i = visibleRows + 1, MAX_VISIBLE_ROWS do
        if rows[i] then rows[i]:Hide() end
    end
end

-- ─── Cast Bar ────────────────────────────────────────────────────────────────

local castBarFrame

local function updateCastBar()
    if not castBarFrame or not ns.isCasting then
        if castBarFrame then
            castBarFrame._fill:SetWidth(1)
            castBarFrame._label:SetText("")
        end
        return
    end

    local now = GetTime()
    local duration = ns.castEndTime - ns.castStartTime
    if duration <= 0 then return end

    local elapsed = now - ns.castStartTime
    local progress = math.min(elapsed / duration, 1.0)
    local trackWidth = castBarFrame._track:GetWidth()
    castBarFrame._fill:SetWidth(math.max(trackWidth * progress, 1))

    local remaining = math.max(duration - elapsed, 0)
    local spellLabel = "DISENCHANT"
    if #ns.queue > 0 then
        local mode = ns.queue[1].mode
        if mode == ns.MODE_PROSPECT then spellLabel = "PROSPECT"
        elseif mode == ns.MODE_MILL then spellLabel = "MILL" end
    end
    castBarFrame._label:SetText(("%s \194\183 %.1fs"):format(spellLabel, remaining))
end

-- ─── Main Frame Construction ─────────────────────────────────────────────────

local function createMainFrame()
    local frame = CreateFrame("Frame", "WDQ_QueueFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, TITLE_BAR_HEIGHT + META_STRIP_HEIGHT + LIST_HEIGHT + FOOTER_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        DisenqueueDB.framePos = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM")

    -- Apply themed backdrop
    Theme.ApplyWindowBackdrop(frame)
    Theme.ApplyVioletCrown(frame)
    Theme.ApplyGreenFloor(frame)
    Theme.CreateDragHandle(frame)

    mainFrame = frame

    -- ═══ Title Bar (56h) ═══
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetHeight(TITLE_BAR_HEIGHT)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)

    -- Logo icon (no background)
    local logoIcon = titleBar:CreateTexture(nil, "ARTWORK")
    logoIcon:SetSize(26, 26)
    logoIcon:SetPoint("LEFT", 14, 0)
    logoIcon:SetTexture("Interface\\AddOns\\Disenqueue\\logos\\logo")
    logoIcon:SetVertexColor(C.violetHi.r, C.violetHi.g, C.violetHi.b)

    -- Title text
    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFontObject(ns.Font.Title)
    titleText:SetText("Disenqueue")
    titleText:SetPoint("LEFT", logoIcon, "RIGHT", 10, 0)

    -- Version
    local versionText = titleBar:CreateFontString(nil, "OVERLAY")
    versionText:SetFontObject(ns.Font.Mono)
    versionText:SetText("v" .. ns.ADDON_VERSION)
    versionText:SetPoint("LEFT", titleText, "RIGHT", 8, 0)

    -- Close button
    local closeBtn = Theme.CreateIconButton(titleBar, 26,
        "Interface\\AddOns\\Disenqueue\\icons\\close", C.danger)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -14, 0)
    closeBtn:SetScript("OnClick", function()
        if ns.isProcessing then ns.StopProcessing() end
        frame:Hide()
        DisenqueueDB.showUI = false
        if _G.WDQ_LockedPanel then _G.WDQ_LockedPanel:Hide() end
        if _G.WDQ_ExportModal then _G.WDQ_ExportModal:Hide() end
    end)

    -- Lock panel toggle button
    local lockPanelBtn = Theme.CreateIconButton(titleBar, 26,
        "Interface\\AddOns\\Disenqueue\\icons\\lock-closed", C.warning)
    lockPanelBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    lockPanelBtn:SetScript("OnClick", function()
        local panel = _G.WDQ_LockedPanel
        if panel then
            if panel:IsShown() then
                panel:Hide()
            else
                panel:Show()
                ns.FireCallback("LOCKED_UPDATED")
            end
        end
    end)

    -- Settings button
    local settingsBtn = Theme.CreateIconButton(titleBar, 26,
        "Interface\\AddOns\\Disenqueue\\icons\\cog", C.textDim)
    settingsBtn:SetPoint("RIGHT", lockPanelBtn, "LEFT", -4, 0)
    settingsBtn:SetScript("OnClick", function()
        if _G.WDQ_SettingsCategory then
            Settings.OpenToCategory(_G.WDQ_SettingsCategory:GetID())
        end
    end)

    -- ═══ Meta Strip (44h) — shown in idle ═══
    local metaStrip = CreateFrame("Frame", nil, frame)
    metaStrip:SetHeight(META_STRIP_HEIGHT)
    metaStrip:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    metaStrip:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    frame._metaStrip = metaStrip

    -- Queued chip
    local queuedChip = Theme.CreateChip(metaStrip, 0, "QUEUED", C.violet)
    queuedChip:SetPoint("LEFT", 14, 0)
    frame._queuedChip = queuedChip

    -- Locked chip
    local lockedChip = Theme.CreateChip(metaStrip, 0, "LOCKED", C.warning)
    lockedChip:SetPoint("LEFT", queuedChip, "RIGHT", 8, 0)
    frame._lockedChip = lockedChip

    -- Dust estimate (right-aligned) with shard icon
    local dustEst = metaStrip:CreateFontString(nil, "OVERLAY")
    dustEst:SetFontObject(ns.Font.Mono)
    dustEst:SetPoint("RIGHT", metaStrip, "RIGHT", -32, 0)
    dustEst:SetTextColor(C.textDim.r, C.textDim.g, C.textDim.b)
    dustEst:Hide()
    frame._dustEst = dustEst

    local dustIcon = metaStrip:CreateTexture(nil, "OVERLAY")
    dustIcon:SetSize(14, 14)
    dustIcon:SetTexture("Interface\\AddOns\\Disenqueue\\icons\\shard")
    dustIcon:SetVertexColor(C.violetHi.r, C.violetHi.g, C.violetHi.b)
    dustIcon:SetPoint("LEFT", dustEst, "RIGHT", 4, 0)
    dustIcon:Hide()
    frame._dustIcon = dustIcon

    -- Divider below meta strip
    local metaDiv = metaStrip:CreateTexture(nil, "ARTWORK")
    metaDiv:SetHeight(1)
    metaDiv:SetPoint("BOTTOMLEFT", metaStrip, "BOTTOMLEFT", 14, 0)
    metaDiv:SetPoint("BOTTOMRIGHT", metaStrip, "BOTTOMRIGHT", -14, 0)
    metaDiv:SetColorTexture(C.divider.r, C.divider.g, C.divider.b, C.divider.a)

    -- ═══ Progress Strip (44h) — shown during processing ═══
    local progressStrip = CreateFrame("Frame", nil, frame)
    progressStrip:SetHeight(META_STRIP_HEIGHT)
    progressStrip:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    progressStrip:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    progressStrip:Hide()
    frame._progressStrip = progressStrip

    -- "PROCESSING" label
    local procLabel = progressStrip:CreateFontString(nil, "OVERLAY")
    procLabel:SetFontObject(ns.Font.SlotLabel)
    procLabel:SetText("PROCESSING")
    procLabel:SetTextColor(C.textMute.r, C.textMute.g, C.textMute.b)
    procLabel:SetPoint("TOPLEFT", 14, -8)

    -- Count "3 / 9"
    local procCount = progressStrip:CreateFontString(nil, "OVERLAY")
    procCount:SetFontObject(ns.Font.MonoMedium)
    procCount:SetText("0 / 0")
    procCount:SetPoint("LEFT", procLabel, "RIGHT", 8, 0)
    frame._progressCount = procCount

    -- ETA right-aligned
    local procEta = progressStrip:CreateFontString(nil, "OVERLAY")
    procEta:SetFontObject(ns.Font.Mono)
    procEta:SetTextColor(C.violetHi.r, C.violetHi.g, C.violetHi.b)
    procEta:SetPoint("RIGHT", progressStrip, "RIGHT", -14, -8)
    frame._progressEta = procEta

    -- Progress bar track (5px tall pill)
    local progressTrack = CreateFrame("Frame", nil, progressStrip, "BackdropTemplate")
    progressTrack:SetHeight(5)
    progressTrack:SetPoint("BOTTOMLEFT", progressStrip, "BOTTOMLEFT", 14, 10)
    progressTrack:SetPoint("BOTTOMRIGHT", progressStrip, "BOTTOMRIGHT", -14, 10)
    progressTrack:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 0,
    })
    progressTrack:SetBackdropColor(C.surface1.r, C.surface1.g, C.surface1.b, 1)
    frame._progressTrack = progressTrack

    -- Progress bar fill
    local progressFill = progressTrack:CreateTexture(nil, "ARTWORK")
    progressFill:SetPoint("TOPLEFT", 0, 0)
    progressFill:SetPoint("BOTTOMLEFT", 0, 0)
    progressFill:SetWidth(1)
    progressFill:SetColorTexture(1, 1, 1, 1)
    progressFill:SetGradient("HORIZONTAL",
        CreateColor(C.violet.r, C.violet.g, C.violet.b, 1),
        CreateColor(C.violetHi.r, C.violetHi.g, C.violetHi.b, 1)
    )
    frame._progressBar = progressFill

    -- Progress glow
    local progressGlow = progressTrack:CreateTexture(nil, "ARTWORK", nil, 1)
    progressGlow:SetPoint("TOPLEFT", progressFill, "TOPLEFT", 0, 2)
    progressGlow:SetPoint("BOTTOMRIGHT", progressFill, "BOTTOMRIGHT", 0, -2)
    progressGlow:SetColorTexture(C.violet.r, C.violet.g, C.violet.b, 0.3)
    progressGlow:SetBlendMode("ADD")

    -- ═══ List Area ═══
    local listArea = CreateFrame("Frame", nil, frame)
    listArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(TITLE_BAR_HEIGHT + META_STRIP_HEIGHT))
    listArea:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -(TITLE_BAR_HEIGHT + META_STRIP_HEIGHT))
    listArea:SetHeight(visibleRows * ROW_HEIGHT)
    listArea:SetClipsChildren(true)
    frame._listArea = listArea

    -- Create row widgets (pre-create max for resize expansion)
    for i = 1, MAX_VISIBLE_ROWS do
        local row = createRow(listArea, i)
        row:SetPoint("TOPLEFT", listArea, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", listArea, "TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)
        rows[i] = row
    end

    -- Empty state text
    local emptyText = listArea:CreateFontString(nil, "OVERLAY")
    emptyText:SetFontObject(ns.Font.BodyRegular)
    emptyText:SetPoint("CENTER", listArea, "CENTER", 0, 0)
    emptyText:SetText("Queue empty\nClick 'Scan Bags' to find disenchantable items")
    emptyText:SetTextColor(C.textMute.r, C.textMute.g, C.textMute.b)
    emptyText:SetJustifyH("CENTER")
    frame._emptyText = emptyText

    -- Scrollbar track (4px wide, right side)
    local scrollTrack = listArea:CreateTexture(nil, "OVERLAY")
    scrollTrack:SetWidth(4)
    scrollTrack:SetPoint("TOPRIGHT", listArea, "TOPRIGHT", -4, -4)
    scrollTrack:SetPoint("BOTTOMRIGHT", listArea, "BOTTOMRIGHT", -4, 4)
    scrollTrack:SetColorTexture(C.surface1.r, C.surface1.g, C.surface1.b, 0.5)
    frame._scrollTrack = scrollTrack

    local scrollThumb = listArea:CreateTexture(nil, "OVERLAY", nil, 1)
    scrollThumb:SetWidth(4)
    scrollThumb:SetColorTexture(C.violetSoft.r, C.violetSoft.g, C.violetSoft.b, 0.9)
    scrollThumb:SetPoint("TOPRIGHT", scrollTrack, "TOPRIGHT", 0, 0)
    scrollThumb:SetHeight(40)
    scrollThumb:Hide()
    frame._scrollThumb = scrollThumb

    -- ═══ Idle Footer (88h) ═══
    local idleFooter = CreateFrame("Frame", nil, frame)
    idleFooter:SetHeight(FOOTER_HEIGHT)
    idleFooter:SetPoint("BOTTOMLEFT", 0, 0)
    idleFooter:SetPoint("BOTTOMRIGHT", 0, 0)
    frame._idleFooter = idleFooter

    -- Divider at top of footer
    local footerDiv = idleFooter:CreateTexture(nil, "ARTWORK")
    footerDiv:SetHeight(1)
    footerDiv:SetPoint("TOPLEFT", 14, 0)
    footerDiv:SetPoint("TOPRIGHT", -14, 0)
    footerDiv:SetColorTexture(C.divider.r, C.divider.g, C.divider.b, C.divider.a)

    -- Kbd hint row: shift + scroll to browse (centered between divider and buttons)
    local hintRow = CreateFrame("Frame", nil, idleFooter)
    hintRow:SetHeight(16)
    hintRow:SetPoint("TOPLEFT", idleFooter, "TOPLEFT", 0, -12)
    hintRow:SetPoint("TOPRIGHT", idleFooter, "TOPRIGHT", 0, -12)
    hintRow:Hide()
    frame._hintRow = hintRow

    local shiftPill = Theme.CreateKbdPill(hintRow, "shift")
    shiftPill:SetPoint("RIGHT", hintRow, "CENTER", -30, 0)

    local plusText = hintRow:CreateFontString(nil, "OVERLAY")
    plusText:SetFontObject(ns.Font.Kbd)
    plusText:SetText("+")
    plusText:SetTextColor(C.violetHi.r, C.violetHi.g, C.violetHi.b)
    plusText:SetPoint("LEFT", shiftPill, "RIGHT", 4, 0)

    local scrollPill = Theme.CreateKbdPill(hintRow, "scroll")
    scrollPill:SetPoint("LEFT", plusText, "RIGHT", 4, 0)

    local browseText = hintRow:CreateFontString(nil, "OVERLAY")
    browseText:SetFontObject(ns.Font.Kbd)
    browseText:SetText("to browse")
    browseText:SetTextColor(C.violetHi.r, C.violetHi.g, C.violetHi.b)
    browseText:SetPoint("LEFT", scrollPill, "RIGHT", 6, 0)

    -- Button row: Scan Bags (ghost) + Start (primary)
    local btnWidth = (FRAME_WIDTH - 14 * 2 - 8) / 2

    local scanBtn = Theme.CreateGhostButton(idleFooter, btnWidth, 36, "Scan Bags",
        "Interface\\AddOns\\Disenqueue\\icons\\search")
    scanBtn:SetPoint("BOTTOMLEFT", idleFooter, "BOTTOMLEFT", 14, 14)
    scanBtn:SetScript("OnClick", function()
        ns.RebuildQueue()
    end)
    frame._scanBtn = scanBtn

    local startBtn = Theme.CreatePrimaryButton(idleFooter, btnWidth, 36, "Start",
        "Interface\\AddOns\\Disenqueue\\icons\\arrow-right")
    startBtn:SetPoint("BOTTOMRIGHT", idleFooter, "BOTTOMRIGHT", -14, 14)
    startBtn:SetScript("OnClick", function()
        ns.StartProcessing()
    end)
    startBtn:Hide()
    frame._startBtn = startBtn

    -- ═══ Processing Footer (88h) ═══
    local procFooter = CreateFrame("Frame", nil, frame)
    procFooter:SetHeight(FOOTER_HEIGHT)
    procFooter:SetPoint("BOTTOMLEFT", 0, 0)
    procFooter:SetPoint("BOTTOMRIGHT", 0, 0)
    procFooter:Hide()
    frame._procFooter = procFooter

    -- Divider
    local procFooterDiv = procFooter:CreateTexture(nil, "ARTWORK")
    procFooterDiv:SetHeight(1)
    procFooterDiv:SetPoint("TOPLEFT", 14, 0)
    procFooterDiv:SetPoint("TOPRIGHT", -14, 0)
    procFooterDiv:SetColorTexture(C.divider.r, C.divider.g, C.divider.b, C.divider.a)

    -- Cast bar (22h)
    local castBarContainer = CreateFrame("Frame", nil, procFooter)
    castBarContainer:SetHeight(22)
    castBarContainer:SetPoint("TOPLEFT", 14, -10)
    castBarContainer:SetPoint("TOPRIGHT", -14, -10)
    castBarFrame = castBarContainer

    -- Cast bar track
    local castTrack = CreateFrame("Frame", nil, castBarContainer, "BackdropTemplate")
    castTrack:SetAllPoints()
    castTrack:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 0,
    })
    castTrack:SetBackdropColor(C.surface1.r, C.surface1.g, C.surface1.b, 1)
    castBarFrame._track = castTrack

    -- Cast bar fill
    local castFill = castTrack:CreateTexture(nil, "ARTWORK")
    castFill:SetPoint("TOPLEFT", 0, 0)
    castFill:SetPoint("BOTTOMLEFT", 0, 0)
    castFill:SetWidth(1)
    castFill:SetColorTexture(1, 1, 1, 1)
    castFill:SetGradient("HORIZONTAL",
        CreateColor(C.violet.r, C.violet.g, C.violet.b, 1),
        CreateColor(C.violetHi.r, C.violetHi.g, C.violetHi.b, 1)
    )
    castBarFrame._fill = castFill

    -- Cast bar label (centered)
    local castLabel = castTrack:CreateFontString(nil, "OVERLAY")
    castLabel:SetFontObject(ns.Font.CastBar)
    castLabel:SetPoint("CENTER")
    castLabel:SetText("")
    castBarFrame._label = castLabel

    -- Cast bar OnUpdate
    local castTicker = CreateFrame("Frame", nil, castBarContainer)
    castTicker:SetScript("OnUpdate", updateCastBar)
    castTicker:Hide()
    castBarFrame._ticker = castTicker

    -- Bottom row: hint + Stop button
    local procHint = procFooter:CreateFontString(nil, "OVERLAY")
    procHint:SetFontObject(ns.Font.Kbd)
    procHint:SetText("Scroll for next")
    procHint:SetTextColor(C.textGhost.r, C.textGhost.g, C.textGhost.b)
    procHint:SetPoint("BOTTOMLEFT", procFooter, "BOTTOMLEFT", 14, 14)

    local stopBtn = Theme.CreateDangerButton(procFooter, 80, 30, "Stop",
        "Interface\\AddOns\\Disenqueue\\icons\\stop")
    stopBtn:SetPoint("BOTTOMRIGHT", procFooter, "BOTTOMRIGHT", -14, 10)
    stopBtn:SetScript("OnClick", function()
        ns.StopProcessing()
    end)

    -- ═══ Mouse Wheel Scrolling ═══
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        if IsShiftKeyDown() and not ns.isProcessing then
            local maxScroll = math.max(0, #ns.queue - visibleRows)
            scrollOffset = scrollOffset - delta
            scrollOffset = math.max(0, math.min(scrollOffset, maxScroll))
            refreshList()
            -- Update scrollbar thumb position
            if maxScroll > 0 then
                local thumbHeight = math.max(20, (visibleRows / #ns.queue) * frame._scrollTrack:GetHeight())
                frame._scrollThumb:SetHeight(thumbHeight)
                local trackSpace = frame._scrollTrack:GetHeight() - thumbHeight
                local offset = (scrollOffset / maxScroll) * trackSpace
                frame._scrollThumb:SetPoint("TOPRIGHT", frame._scrollTrack, "TOPRIGHT", 0, -offset)
                frame._scrollThumb:Show()
            else
                frame._scrollThumb:Hide()
            end
        end
    end)

    -- ═══ Vertical Resize ═══
    local minH = TITLE_BAR_HEIGHT + META_STRIP_HEIGHT + MIN_VISIBLE_ROWS * ROW_HEIGHT + FOOTER_HEIGHT
    local maxH = TITLE_BAR_HEIGHT + META_STRIP_HEIGHT + MAX_VISIBLE_ROWS * ROW_HEIGHT + FOOTER_HEIGHT

    Theme.CreateResizeGrip(frame, minH, maxH,
        -- Live: update layout without snapping (keeps drag smooth)
        function(newHeight)
            local listSpace = newHeight - TITLE_BAR_HEIGHT - META_STRIP_HEIGHT - FOOTER_HEIGHT
            local newRows = math.floor(listSpace / ROW_HEIGHT)
            newRows = math.max(MIN_VISIBLE_ROWS, math.min(newRows, MAX_VISIBLE_ROWS))
            if newRows ~= visibleRows then
                visibleRows = newRows
                frame._listArea:SetHeight(visibleRows * ROW_HEIGHT)
                scrollOffset = math.min(scrollOffset, math.max(0, #ns.queue - visibleRows))
                refreshList()
            end
        end,
        -- Final: snap to row boundary + persist
        function(newHeight)
            local listSpace = newHeight - TITLE_BAR_HEIGHT - META_STRIP_HEIGHT - FOOTER_HEIGHT
            local newRows = math.floor(listSpace / ROW_HEIGHT)
            newRows = math.max(MIN_VISIBLE_ROWS, math.min(newRows, MAX_VISIBLE_ROWS))
            visibleRows = newRows
            local snapHeight = TITLE_BAR_HEIGHT + META_STRIP_HEIGHT + visibleRows * ROW_HEIGHT + FOOTER_HEIGHT
            frame:SetHeight(snapHeight)
            frame._listArea:SetHeight(visibleRows * ROW_HEIGHT)
            scrollOffset = math.min(scrollOffset, math.max(0, #ns.queue - visibleRows))
            refreshList()
            DisenqueueDB.mainFrameHeight = snapHeight
        end
    )

    -- ═══ Restore Position & Height ═══
    if DisenqueueDB.mainFrameHeight then
        local savedH = DisenqueueDB.mainFrameHeight
        local listSpace = savedH - TITLE_BAR_HEIGHT - META_STRIP_HEIGHT - FOOTER_HEIGHT
        local newRows = math.floor(listSpace / ROW_HEIGHT)
        newRows = math.max(MIN_VISIBLE_ROWS, math.min(newRows, MAX_VISIBLE_ROWS))
        visibleRows = newRows
        frame:SetHeight(savedH)
        frame._listArea:SetHeight(visibleRows * ROW_HEIGHT)
    end

    if DisenqueueDB.framePos then
        local pos = DisenqueueDB.framePos
        frame:ClearAllPoints()
        frame:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or 0, pos.y or 0)
    end

    -- Auto-scan when frame becomes visible
    frame:SetScript("OnShow", function()
        C_Timer.After(0.1, function()
            ns.RebuildQueue()
        end)
    end)

    -- Initial visibility
    if DisenqueueDB.showUI == false then
        frame:Hide()
    else
        frame:Show()
    end

    return frame
end

-- ─── Callback Wiring ─────────────────────────────────────────────────────────

ns.RegisterCallback("ADDON_LOADED", function()
    local ok, err = pcall(createMainFrame)
    if not ok then
        print("|cffff3333[Disenqueue] CRITICAL: createMainFrame failed:|r " .. tostring(err))
    else
        print("|cff00ff00[Disenqueue] UI created successfully.|r")
    end
end)

ns.RegisterCallback("QUEUE_UPDATED", function()
    if mainFrame then
        scrollOffset = math.min(scrollOffset, math.max(0, #ns.queue - visibleRows))
        refreshList()
    end
end)

ns.RegisterCallback("STATE_CHANGED", function()
    if not mainFrame then return end
    if ns.isProcessing then
        -- Disable mouse wheel on frame so override binding captures scroll
        mainFrame:EnableMouseWheel(false)
        doneCount = 0
    else
        mainFrame:EnableMouseWheel(true)
    end
    refreshList()
end)

ns.RegisterCallback("CAST_START", function()
    if castBarFrame and castBarFrame._ticker then
        castBarFrame._ticker:Show()
    end
end)

ns.RegisterCallback("CAST_STOP", function()
    if castBarFrame and castBarFrame._ticker then
        castBarFrame._ticker:Hide()
        if castBarFrame._fill then
            castBarFrame._fill:SetWidth(1)
        end
        if castBarFrame._label then
            castBarFrame._label:SetText("")
        end
    end
end)
