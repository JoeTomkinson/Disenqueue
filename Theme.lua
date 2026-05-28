local _, ns = ...

-- ═══════════════════════════════════════════════════════════════════════════════
-- Theme.lua — Color tokens, font objects, backdrop helpers, widget factories
-- ═══════════════════════════════════════════════════════════════════════════════

ns.C = {}
ns.Font = {}
ns.Theme = {}

local C = ns.C
local Theme = ns.Theme

-- ─── Color Tokens ────────────────────────────────────────────────────────────

-- Surfaces / chrome
C.canvas        = { r = 0.086, g = 0.082, b = 0.114, a = 1 }
C.windowBgTop   = { r = 0.157, g = 0.145, b = 0.184, a = 1 }
C.windowBgBot   = { r = 0.118, g = 0.110, b = 0.145, a = 1 }
C.surface1      = { r = 0.176, g = 0.165, b = 0.212, a = 1 }
C.surface2      = { r = 0.212, g = 0.196, b = 0.247, a = 1 }
C.divider       = { r = 0.231, g = 0.212, b = 0.271, a = 0.5 }

-- Text
C.textHi        = { r = 0.953, g = 0.945, b = 0.961, a = 1 }
C.text          = { r = 0.851, g = 0.835, b = 0.863, a = 1 }
C.textDim       = { r = 0.612, g = 0.588, b = 0.631, a = 1 }
C.textMute      = { r = 0.420, g = 0.396, b = 0.443, a = 1 }
C.textGhost     = { r = 0.290, g = 0.271, b = 0.318, a = 1 }

-- Accent — violet
C.violet        = { r = 0.604, g = 0.420, b = 0.878, a = 1 }
C.violetHi      = { r = 0.749, g = 0.631, b = 0.933, a = 1 }
C.violetSoft    = { r = 0.416, g = 0.278, b = 0.600, a = 1 }
C.violetGlow    = { r = 0.604, g = 0.420, b = 0.878, a = 0.35 }

-- Status
C.danger        = { r = 0.902, g = 0.420, b = 0.365, a = 1 }
C.success       = { r = 0.357, g = 0.776, b = 0.561, a = 1 }
C.warning       = { r = 0.851, g = 0.690, b = 0.353, a = 1 }

-- Item quality (toned-down versions for dark bg)
C.qualityPoor      = { r = 0.541, g = 0.533, b = 0.533 }
C.qualityCommon    = { r = 0.918, g = 0.910, b = 0.914 }
C.qualityUncommon  = { r = 0.357, g = 0.820, b = 0.486 }
C.qualityRare      = { r = 0.373, g = 0.643, b = 0.871 }
C.qualityEpic      = { r = 0.753, g = 0.475, b = 0.863 }
C.qualityLegendary = { r = 0.902, g = 0.659, b = 0.369 }

-- Inner surfaces
C.codeBlockBg   = { r = 0.086, g = 0.075, b = 0.114, a = 1 }

-- ─── Font Objects ────────────────────────────────────────────────────────────

local FONT_PATH = "Interface\\AddOns\\Disenqueue\\Fonts\\"
local FONT_UI = FONT_PATH .. "Inter-Regular.ttf"
local FONT_UI_MEDIUM = FONT_PATH .. "Inter-Medium.ttf"
local FONT_UI_SEMIBOLD = FONT_PATH .. "Inter-SemiBold.ttf"
local FONT_MONO = FONT_PATH .. "JetBrainsMono-Regular.ttf"
local FONT_MONO_MEDIUM = FONT_PATH .. "JetBrainsMono-Medium.ttf"

-- Fallback to system fonts if custom fonts aren't available
local FALLBACK_UI = "Fonts\\FRIZQT__.TTF"
local FALLBACK_MONO = "Fonts\\ARIALN.TTF"

local function createFontObject(name, fontFile, size, flags, fallback)
    local obj = CreateFont("WDQ_Font_" .. name)
    -- SetFont returns false/nil if the font file doesn't exist
    if not obj:SetFont(fontFile, size, flags or "") then
        obj:SetFont(fallback or FALLBACK_UI, size, flags or "")
    end
    return obj
end

-- Window title: 14, semibold
ns.Font.Title = createFontObject("Title", FONT_UI_SEMIBOLD, 14, "", FALLBACK_UI)
ns.Font.Title:SetTextColor(C.textHi.r, C.textHi.g, C.textHi.b)
ns.Font.Title:SetSpacing(0)

-- Body text: 13, medium
ns.Font.Body = createFontObject("Body", FONT_UI_MEDIUM, 13, "", FALLBACK_UI)
ns.Font.Body:SetTextColor(C.text.r, C.text.g, C.text.b)

-- Body regular: 13, regular
ns.Font.BodyRegular = createFontObject("BodyRegular", FONT_UI, 13, "", FALLBACK_UI)
ns.Font.BodyRegular:SetTextColor(C.text.r, C.text.g, C.text.b)

-- Button label: 13, semibold
ns.Font.Button = createFontObject("Button", FONT_UI_SEMIBOLD, 13, "", FALLBACK_UI)
ns.Font.Button:SetTextColor(C.textHi.r, C.textHi.g, C.textHi.b)

-- Version / mono small: 10.5
ns.Font.Mono = createFontObject("Mono", FONT_MONO, 11, "", FALLBACK_MONO)
ns.Font.Mono:SetTextColor(C.textMute.r, C.textMute.g, C.textMute.b)

-- Mono medium: 11
ns.Font.MonoMedium = createFontObject("MonoMedium", FONT_MONO_MEDIUM, 11, "", FALLBACK_MONO)
ns.Font.MonoMedium:SetTextColor(C.textHi.r, C.textHi.g, C.textHi.b)

-- Slot label: 10.5, mono uppercase
ns.Font.SlotLabel = createFontObject("SlotLabel", FONT_MONO, 10, "", FALLBACK_MONO)
ns.Font.SlotLabel:SetTextColor(C.textMute.r, C.textMute.g, C.textMute.b)

-- Chip value: 11, mono
ns.Font.Chip = createFontObject("Chip", FONT_MONO_MEDIUM, 11, "", FALLBACK_MONO)
ns.Font.Chip:SetTextColor(C.textHi.r, C.textHi.g, C.textHi.b)

-- Kbd pill: 10, mono
ns.Font.Kbd = createFontObject("Kbd", FONT_MONO, 10, "", FALLBACK_MONO)
ns.Font.Kbd:SetTextColor(C.text.r, C.text.g, C.text.b)

-- Section header: 10.5, semibold uppercase
ns.Font.SectionHeader = createFontObject("SectionHeader", FONT_UI_SEMIBOLD, 10, "", FALLBACK_UI)
ns.Font.SectionHeader:SetTextColor(C.textMute.r, C.textMute.g, C.textMute.b)

-- Cast bar label: 10.5, mono uppercase
ns.Font.CastBar = createFontObject("CastBar", FONT_MONO_MEDIUM, 10, "", FALLBACK_MONO)
ns.Font.CastBar:SetTextColor(C.textHi.r, C.textHi.g, C.textHi.b)
ns.Font.CastBar:SetShadowColor(0, 0, 0, 0.8)
ns.Font.CastBar:SetShadowOffset(1, -1)

-- ─── Backdrop Helpers ────────────────────────────────────────────────────────

local FLAT_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 0, right = 0, top = 0, bottom = 0 },
}

function Theme.ApplyWindowBackdrop(frame)
    frame:SetBackdrop(FLAT_BACKDROP)
    frame:SetBackdropColor(C.windowBgTop.r, C.windowBgTop.g, C.windowBgTop.b, 0.98)
    frame:SetBackdropBorderColor(C.divider.r, C.divider.g, C.divider.b, 0.6)

    -- Vertical gradient overlay
    local gradient = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    gradient:SetAllPoints()
    gradient:SetColorTexture(1, 1, 1, 1)
    gradient:SetGradient("VERTICAL",
        CreateColor(C.windowBgBot.r, C.windowBgBot.g, C.windowBgBot.b, 0.98),
        CreateColor(C.windowBgTop.r, C.windowBgTop.g, C.windowBgTop.b, 0.98)
    )
    frame._bgGradient = gradient
end

function Theme.ApplyVioletCrown(frame)
    local CORNER_LEN = 8
    local r, g, b = C.violetGlow.r, C.violetGlow.g, C.violetGlow.b

    -- Full-width top edge
    local crown = frame:CreateTexture(nil, "ARTWORK", nil, 7)
    crown:SetHeight(3)
    crown:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    crown:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    crown:SetColorTexture(r, g, b, 1)
    crown:SetBlendMode("ADD")
    crown:SetAlpha(0.5)

    -- Left corner (wraps down)
    local cornerL = frame:CreateTexture(nil, "ARTWORK", nil, 7)
    cornerL:SetWidth(1)
    cornerL:SetHeight(CORNER_LEN)
    cornerL:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    cornerL:SetColorTexture(r, g, b, 1)
    cornerL:SetBlendMode("ADD")
    cornerL:SetAlpha(0.35)

    -- Right corner (wraps down)
    local cornerR = frame:CreateTexture(nil, "ARTWORK", nil, 7)
    cornerR:SetWidth(1)
    cornerR:SetHeight(CORNER_LEN)
    cornerR:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    cornerR:SetColorTexture(r, g, b, 1)
    cornerR:SetBlendMode("ADD")
    cornerR:SetAlpha(0.35)

    -- Breathe animation on all three
    local ag = crown:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local alpha = ag:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0.4)
    alpha:SetToAlpha(0.6)
    alpha:SetDuration(6)
    alpha:SetSmoothing("IN_OUT")
    ag:Play()

    local agL = cornerL:CreateAnimationGroup()
    agL:SetLooping("BOUNCE")
    local alphaL = agL:CreateAnimation("Alpha")
    alphaL:SetFromAlpha(0.25)
    alphaL:SetToAlpha(0.45)
    alphaL:SetDuration(6)
    alphaL:SetSmoothing("IN_OUT")
    agL:Play()

    local agR = cornerR:CreateAnimationGroup()
    agR:SetLooping("BOUNCE")
    local alphaR = agR:CreateAnimation("Alpha")
    alphaR:SetFromAlpha(0.25)
    alphaR:SetToAlpha(0.45)
    alphaR:SetDuration(6)
    alphaR:SetSmoothing("IN_OUT")
    agR:Play()

    frame._crownGlow = crown
    frame._crownAnim = ag
    return crown
end

function Theme.ApplyGreenFloor(frame)
    local CORNER_LEN = 8
    local r, g, b = 0.2, 1.0, 0.5

    -- Full-width bottom edge
    local floor = frame:CreateTexture(nil, "ARTWORK", nil, 7)
    floor:SetHeight(3)
    floor:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    floor:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    floor:SetColorTexture(r, g, b, 1)
    floor:SetBlendMode("ADD")
    floor:SetAlpha(0.5)

    -- Left corner (wraps up)
    local cornerL = frame:CreateTexture(nil, "ARTWORK", nil, 7)
    cornerL:SetWidth(1)
    cornerL:SetHeight(CORNER_LEN)
    cornerL:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    cornerL:SetColorTexture(r, g, b, 1)
    cornerL:SetBlendMode("ADD")
    cornerL:SetAlpha(0.35)

    -- Right corner (wraps up)
    local cornerR = frame:CreateTexture(nil, "ARTWORK", nil, 7)
    cornerR:SetWidth(1)
    cornerR:SetHeight(CORNER_LEN)
    cornerR:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    cornerR:SetColorTexture(r, g, b, 1)
    cornerR:SetBlendMode("ADD")
    cornerR:SetAlpha(0.35)

    -- Breathe animation on all three
    local ag = floor:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local alpha = ag:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0.4)
    alpha:SetToAlpha(0.6)
    alpha:SetDuration(6)
    alpha:SetSmoothing("IN_OUT")
    ag:Play()

    local agL = cornerL:CreateAnimationGroup()
    agL:SetLooping("BOUNCE")
    local alphaL = agL:CreateAnimation("Alpha")
    alphaL:SetFromAlpha(0.25)
    alphaL:SetToAlpha(0.45)
    alphaL:SetDuration(6)
    alphaL:SetSmoothing("IN_OUT")
    agL:Play()

    local agR = cornerR:CreateAnimationGroup()
    agR:SetLooping("BOUNCE")
    local alphaR = agR:CreateAnimation("Alpha")
    alphaR:SetFromAlpha(0.25)
    alphaR:SetToAlpha(0.45)
    alphaR:SetDuration(6)
    alphaR:SetSmoothing("IN_OUT")
    agR:Play()

    frame._floorGlow = floor
    frame._floorAnim = ag
    return floor
end

function Theme.CreateDragHandle(frame)
    local handle = frame:CreateTexture(nil, "OVERLAY")
    handle:SetSize(3, 28)
    handle:SetPoint("TOP", frame, "TOP", 0, -5)
    handle:SetColorTexture(C.divider.r, C.divider.g, C.divider.b, 0.8)
    return handle
end

--- Creates a bottom-edge resize grip that constrains to vertical-only resizing.
--- @param frame Frame The frame to make resizable
--- @param minHeight number Minimum height
--- @param maxHeight number Maximum height
--- @param onResizing function? Callback(newHeight) fired live during drag (layout only, no SetHeight!)
--- @param onResized function? Callback(newHeight) fired once on drag stop (snap + persist here)
function Theme.CreateResizeGrip(frame, minHeight, maxHeight, onResizing, onResized)
    local width = frame:GetWidth()
    frame:SetResizable(true)
    frame:SetResizeBounds(width, minHeight, width, maxHeight)

    -- Grip zone at bottom edge (full width, 8px tall)
    local grip = CreateFrame("Frame", nil, frame)
    grip:SetHeight(8)
    grip:SetPoint("BOTTOMLEFT", 0, 0)
    grip:SetPoint("BOTTOMRIGHT", 0, 0)
    grip:EnableMouse(true)
    grip:SetFrameLevel(frame:GetFrameLevel() + 10)

    -- Visual indicator: horizontal bar with rounded feel (40px wide, 3px tall)
    local bar = grip:CreateTexture(nil, "OVERLAY")
    bar:SetSize(40, 3)
    bar:SetPoint("CENTER", 0, 0)
    bar:SetColorTexture(C.textMute.r, C.textMute.g, C.textMute.b, 0.5)

    -- Hover highlight
    grip:SetScript("OnEnter", function()
        bar:SetColorTexture(C.violetHi.r, C.violetHi.g, C.violetHi.b, 0.9)
    end)
    grip:SetScript("OnLeave", function()
        bar:SetColorTexture(C.textMute.r, C.textMute.g, C.textMute.b, 0.5)
    end)

    -- Drag to resize (bottom edge only)
    local isResizing = false
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function()
        -- Ensure TOPLEFT anchor so StartSizing("BOTTOM") only moves the bottom edge.
        local point, _, relPoint, xOfs, yOfs = frame:GetPoint(1)
        if point ~= "TOPLEFT" or relPoint ~= "BOTTOMLEFT" then
            local top = frame:GetTop()
            local left = frame:GetLeft()
            if top and left then
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            end
        end
        isResizing = true
        frame:StartSizing("BOTTOM")
    end)
    grip:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        isResizing = false
        if onResized then onResized(frame:GetHeight()) end
    end)

    -- Live layout updates during drag (no SetHeight here!)
    if onResizing then
        frame:SetScript("OnSizeChanged", function(_, w, h)
            if isResizing then onResizing(h) end
        end)
    end

    return grip
end

-- ─── Widget Factories ────────────────────────────────────────────────────────

function Theme.CreateIconButton(parent, size, texturePath, color, tooltip)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)

    -- Background (hidden by default, shown on hover)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(C.surface1.r, C.surface1.g, C.surface1.b, 0)
    btn._bg = bg

    -- Border (hidden by default, shown on hover)
    local border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(C.divider.r, C.divider.g, C.divider.b, 0)
    border:SetFrameLevel(btn:GetFrameLevel())
    btn._border = border

    -- Icon
    local icon = btn:CreateTexture(nil, "ARTWORK")
    local inset = math.floor(size * 0.2)
    icon:SetPoint("TOPLEFT", inset, -inset)
    icon:SetPoint("BOTTOMRIGHT", -inset, inset)
    icon:SetTexture(texturePath)
    if color then
        icon:SetVertexColor(color.r, color.g, color.b, color.a or 1)
    end
    btn._icon = icon

    -- Hover behavior
    btn:SetScript("OnEnter", function(self)
        self._bg:SetColorTexture(C.surface1.r, C.surface1.g, C.surface1.b, 1)
        self._border:SetBackdropBorderColor(C.divider.r, C.divider.g, C.divider.b, 0.6)
        if color then
            local r, g, b = color.r, color.g, color.b
            self._icon:SetVertexColor(r + (1 - r) * 0.2, g + (1 - g) * 0.2, b + (1 - b) * 0.2, 1)
        end
        if tooltip then
            ns.AnchorTooltip(self)
            GameTooltip:AddLine(tooltip)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self._bg:SetColorTexture(C.surface1.r, C.surface1.g, C.surface1.b, 0)
        self._border:SetBackdropBorderColor(C.divider.r, C.divider.g, C.divider.b, 0)
        if color then
            self._icon:SetVertexColor(color.r, color.g, color.b, color.a or 1)
        end
        GameTooltip:Hide()
    end)

    return btn
end

function Theme.CreatePrimaryButton(parent, width, height, label, iconPath)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)

    -- Violet gradient background
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 1)
    bg:SetGradient("VERTICAL",
        CreateColor(C.violetSoft.r, C.violetSoft.g, C.violetSoft.b, 1),
        CreateColor(C.violet.r, C.violet.g, C.violet.b, 1)
    )
    btn._bg = bg

    -- Border
    local border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(C.violet.r, C.violet.g, C.violet.b, 0.6)
    border:SetFrameLevel(btn:GetFrameLevel())
    btn._border = border

    -- Glow (outer)
    local glow = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
    glow:SetPoint("TOPLEFT", -3, 3)
    glow:SetPoint("BOTTOMRIGHT", 3, -3)
    glow:SetColorTexture(C.violet.r, C.violet.g, C.violet.b, 0.15)
    btn._glow = glow

    -- Label
    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFontObject(ns.Font.Button)
    text:SetTextColor(C.textHi.r, C.textHi.g, C.textHi.b)
    btn._text = text

    -- Icon (optional, right side)
    if iconPath then
        local icon = btn:CreateTexture(nil, "OVERLAY")
        icon:SetSize(14, 14)
        icon:SetTexture(iconPath)
        icon:SetVertexColor(C.textHi.r, C.textHi.g, C.textHi.b)
        icon:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
        text:SetPoint("CENTER", btn, "CENTER", -8, 0)
        btn._icon = icon
    else
        text:SetPoint("CENTER")
    end
    text:SetText(label)

    -- Hover state
    btn:SetScript("OnEnter", function(self)
        self._bg:SetGradient("VERTICAL",
            CreateColor(C.violet.r, C.violet.g, C.violet.b, 1),
            CreateColor(C.violetHi.r, C.violetHi.g, C.violetHi.b, 1)
        )
        self._glow:SetAlpha(0.25)
    end)
    btn:SetScript("OnLeave", function(self)
        self._bg:SetGradient("VERTICAL",
            CreateColor(C.violetSoft.r, C.violetSoft.g, C.violetSoft.b, 1),
            CreateColor(C.violet.r, C.violet.g, C.violet.b, 1)
        )
        self._glow:SetAlpha(0.15)
    end)
    btn:SetScript("OnMouseDown", function(self)
        self._bg:SetGradient("VERTICAL",
            CreateColor(C.violetSoft.r * 0.8, C.violetSoft.g * 0.8, C.violetSoft.b * 0.8, 1),
            CreateColor(C.violetSoft.r, C.violetSoft.g, C.violetSoft.b, 1)
        )
    end)
    btn:SetScript("OnMouseUp", function(self)
        self._bg:SetGradient("VERTICAL",
            CreateColor(C.violetSoft.r, C.violetSoft.g, C.violetSoft.b, 1),
            CreateColor(C.violet.r, C.violet.g, C.violet.b, 1)
        )
    end)

    function btn:SetLabel(newLabel)
        self._text:SetText(newLabel)
    end

    return btn
end

function Theme.CreateGhostButton(parent, width, height, label, iconPath)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)

    -- Background
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(C.surface1.r, C.surface1.g, C.surface1.b, 1)
    btn._bg = bg

    -- Border
    local border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(C.divider.r, C.divider.g, C.divider.b, 0.6)
    border:SetFrameLevel(btn:GetFrameLevel())
    btn._border = border

    -- Label
    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFontObject(ns.Font.Button)
    text:SetTextColor(C.text.r, C.text.g, C.text.b)
    btn._text = text

    -- Icon (optional, left side)
    if iconPath then
        local icon = btn:CreateTexture(nil, "OVERLAY")
        icon:SetSize(14, 14)
        icon:SetTexture(iconPath)
        icon:SetVertexColor(C.text.r, C.text.g, C.text.b)
        icon:SetPoint("LEFT", btn, "LEFT", 10, 0)
        text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        btn._icon = icon
    else
        text:SetPoint("CENTER")
    end
    text:SetText(label)

    -- Hover
    btn:SetScript("OnEnter", function(self)
        self._bg:SetColorTexture(C.surface2.r, C.surface2.g, C.surface2.b, 1)
        self._text:SetTextColor(C.textHi.r, C.textHi.g, C.textHi.b)
        if self._icon then
            self._icon:SetVertexColor(C.textHi.r, C.textHi.g, C.textHi.b)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self._bg:SetColorTexture(C.surface1.r, C.surface1.g, C.surface1.b, 1)
        self._text:SetTextColor(C.text.r, C.text.g, C.text.b)
        if self._icon then
            self._icon:SetVertexColor(C.text.r, C.text.g, C.text.b)
        end
    end)

    function btn:SetLabel(newLabel)
        self._text:SetText(newLabel)
    end

    return btn
end

function Theme.CreateDangerButton(parent, width, height, label, iconPath)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)

    -- Red gradient background
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 1)
    bg:SetGradient("VERTICAL",
        CreateColor(C.danger.r * 0.5, C.danger.g * 0.3, C.danger.b * 0.3, 1),
        CreateColor(C.danger.r * 0.7, C.danger.g * 0.4, C.danger.b * 0.35, 1)
    )
    btn._bg = bg

    -- Border
    local border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(C.danger.r, C.danger.g, C.danger.b, 0.6)
    border:SetFrameLevel(btn:GetFrameLevel())
    btn._border = border

    -- Label
    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFontObject(ns.Font.Button)
    text:SetTextColor(C.textHi.r, C.textHi.g, C.textHi.b)
    btn._text = text

    if iconPath then
        local icon = btn:CreateTexture(nil, "OVERLAY")
        icon:SetSize(14, 14)
        icon:SetTexture(iconPath)
        icon:SetVertexColor(C.textHi.r, C.textHi.g, C.textHi.b)
        icon:SetPoint("LEFT", btn, "LEFT", 10, 0)
        text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        btn._icon = icon
    else
        text:SetPoint("CENTER")
    end
    text:SetText(label)

    btn:SetScript("OnEnter", function(self)
        self._bg:SetGradient("VERTICAL",
            CreateColor(C.danger.r * 0.6, C.danger.g * 0.35, C.danger.b * 0.35, 1),
            CreateColor(C.danger.r * 0.85, C.danger.g * 0.5, C.danger.b * 0.4, 1)
        )
    end)
    btn:SetScript("OnLeave", function(self)
        self._bg:SetGradient("VERTICAL",
            CreateColor(C.danger.r * 0.5, C.danger.g * 0.3, C.danger.b * 0.3, 1),
            CreateColor(C.danger.r * 0.7, C.danger.g * 0.4, C.danger.b * 0.35, 1)
        )
    end)

    function btn:SetLabel(newLabel)
        self._text:SetText(newLabel)
    end

    return btn
end

function Theme.CreateKbdPill(parent, text)
    local pill = CreateFrame("Frame", nil, parent)
    pill:SetHeight(18)

    local bg = pill:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(C.surface2.r, C.surface2.g, C.surface2.b, 1)

    local border = CreateFrame("Frame", nil, pill, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(C.divider.r, C.divider.g, C.divider.b, 0.6)
    border:SetFrameLevel(pill:GetFrameLevel())

    -- Bottom shadow (1px)
    local shadow = pill:CreateTexture(nil, "BORDER")
    shadow:SetHeight(1)
    shadow:SetPoint("BOTTOMLEFT", 0, -1)
    shadow:SetPoint("BOTTOMRIGHT", 0, -1)
    shadow:SetColorTexture(0, 0, 0, 0.3)

    local label = pill:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(ns.Font.Kbd)
    label:SetText(text)
    label:SetPoint("CENTER", 0, 0)
    pill._label = label

    -- Size to fit
    local textWidth = label:GetStringWidth() or 0
    pill:SetWidth(math.max(textWidth + 12, 22))

    function pill:SetText(newText)
        self._label:SetText(newText)
        local w = self._label:GetStringWidth() or 0
        self:SetWidth(math.max(w + 12, 22))
    end

    return pill
end

function Theme.CreateChip(parent, count, label, countColor)
    local chip = CreateFrame("Frame", nil, parent)
    chip:SetHeight(24)

    local bg = chip:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(C.surface1.r, C.surface1.g, C.surface1.b, 1)

    local border = CreateFrame("Frame", nil, chip, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(C.divider.r, C.divider.g, C.divider.b, 0.4)
    border:SetFrameLevel(chip:GetFrameLevel())

    local countStr = chip:CreateFontString(nil, "OVERLAY")
    countStr:SetFontObject(ns.Font.Chip)
    countStr:SetText(tostring(count))
    countStr:SetPoint("LEFT", 8, 0)
    if countColor then
        countStr:SetTextColor(countColor.r, countColor.g, countColor.b)
    end
    chip._count = countStr

    local labelStr = chip:CreateFontString(nil, "OVERLAY")
    labelStr:SetFontObject(ns.Font.SlotLabel)
    labelStr:SetText(label)
    labelStr:SetPoint("LEFT", countStr, "RIGHT", 5, 0)
    labelStr:SetTextColor(C.textDim.r, C.textDim.g, C.textDim.b)
    chip._label = labelStr

    -- Size to fit
    local totalWidth = 8 + (countStr:GetStringWidth() or 0) + 5 + (labelStr:GetStringWidth() or 0) + 8
    chip:SetWidth(math.max(totalWidth, 50))

    function chip:Update(newCount, newLabel)
        self._count:SetText(tostring(newCount))
        if newLabel then self._label:SetText(newLabel) end
        local w = 8 + (self._count:GetStringWidth() or 0) + 5 + (self._label:GetStringWidth() or 0) + 8
        self:SetWidth(math.max(w, 50))
    end

    return chip
end

-- Divider line helper
function Theme.CreateDivider(parent, anchor, offsetY)
    local div = parent:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("LEFT", parent, "LEFT", 0, 0)
    div:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    if anchor then
        div:SetPoint("TOP", anchor, "BOTTOM", 0, offsetY or 0)
    end
    div:SetColorTexture(C.divider.r, C.divider.g, C.divider.b, C.divider.a)
    return div
end

-- Icon tile (38x38 with quality border and item icon)
function Theme.CreateIconTile(parent, size)
    size = size or 38
    local tile = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    tile:SetSize(size, size)
    tile:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    tile:SetBackdropColor(C.surface2.r, C.surface2.g, C.surface2.b, 1)
    tile:SetBackdropBorderColor(C.divider.r, C.divider.g, C.divider.b, 0.6)

    -- Item icon texture
    local icon = tile:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Trim default icon borders
    tile._icon = icon

    -- Inner glow (additive, faint)
    local glow = tile:CreateTexture(nil, "ARTWORK", nil, 1)
    glow:SetAllPoints(icon)
    glow:SetColorTexture(1, 1, 1, 0.05)
    glow:SetBlendMode("ADD")
    tile._glow = glow

    -- Top highlight (1px white at 15%)
    local highlight = tile:CreateTexture(nil, "OVERLAY")
    highlight:SetHeight(1)
    highlight:SetPoint("TOPLEFT", 1, -1)
    highlight:SetPoint("TOPRIGHT", -1, -1)
    highlight:SetColorTexture(1, 1, 1, 0.15)
    tile._highlight = highlight

    function tile:SetQualityColor(r, g, b)
        self:SetBackdropBorderColor(r, g, b, 0.8)
        self._glow:SetColorTexture(r, g, b, 0.15)
        self._glow:SetBlendMode("ADD")
    end

    function tile:SetIcon(texturePath)
        self._icon:SetTexture(texturePath)
    end

    return tile
end
