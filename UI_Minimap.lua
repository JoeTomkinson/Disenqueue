local _, ns = ...

-- ═══════════════════════════════════════════════════════════════════════════════
-- UI_Minimap.lua — Minimap button (no library dependency)
-- ═══════════════════════════════════════════════════════════════════════════════

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
        minimapBtn:ClearAllPoints()
        minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    updatePosition()

    -- Dragging to reposition around minimap
    minimapBtn:RegisterForDrag("LeftButton")
    minimapBtn:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:SetScript("OnUpdate", function()
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
                if _G.WDQ_LockedPanel then _G.WDQ_LockedPanel:Hide() end
            else
                queueFrame:Show()
                DisenqueueDB.showUI = true
                ns.RebuildQueue()
            end
        end
    end)

    -- Tooltip
    minimapBtn:SetScript("OnEnter", function(self)
        ns.AnchorTooltip(self)
        GameTooltip:AddLine("Disenqueue")
        GameTooltip:AddLine("Click: Toggle queue window", 1, 1, 1)
        GameTooltip:AddLine("Alt+Click bag items to add to queue", 1, 1, 1)
        GameTooltip:AddLine("Drag to reposition", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    minimapBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Hide if setting is off
    if DisenqueueDB.hideMinimap then
        minimapBtn:Hide()
    end
end

-- ─── Callback Wiring ─────────────────────────────────────────────────────────

ns.RegisterCallback("ADDON_LOADED", function()
    createMinimapButton()
end)
