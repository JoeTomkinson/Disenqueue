# WoW Lua Addon Development Reference

> **Interface Version:** `120005` (Patch 12.0.0 — Midnight)
> **Last Updated:** May 2026

This document is mainly so I can keep track of relevant resources and things I've stumbled upon along the way, relevant to this add-on.

---

## Interface Version History & Release Notes

| Expansion             | Interface | TOC Value | API Changes                                            |
| --------------------- | --------- | --------- | ------------------------------------------------------ |
| Midnight (12.0)       | 12.0.0    | `120005`  | https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes |
| The War Within (11.1) | 11.1.0    | `110100`  | https://warcraft.wiki.gg/wiki/Patch_11.1.0/API_changes |
| The War Within (11.0) | 11.0.2    | `110002`  | https://warcraft.wiki.gg/wiki/Patch_11.0.2/API_changes |
| Dragonflight (10.0)   | 10.0.0    | `100000`  | https://warcraft.wiki.gg/wiki/Patch_10.0.0/API_changes |

**Official patch notes:** https://worldofwarcraft.blizzard.com/en-us/news

**Full API reference:** https://warcraft.wiki.gg/wiki/World_of_Warcraft_API

**FrameXML source (live):** https://github.com/Gethe/wow-ui-source/tree/live

---

## TOC File Format

```toc
## Interface: 120005
## Title: MyAddon
## Notes: Short description shown in addon list.
## Author: Your Name
## Version: 1.0.0
## SavedVariables: MyAddonDB
## IconTexture: Interface\AddOns\MyAddon\icon
## Category: Professions

MyAddon.lua
```

### Key TOC Directives (as of 11.1+)

| Directive                    | Purpose                                               |
| ---------------------------- | ----------------------------------------------------- |
| `Interface`                  | Required. Interface version number.                   |
| `Title`                      | Display name. Supports `Title-deDE:` locale variants. |
| `Notes`                      | Tooltip description. Supports locale variants.        |
| `SavedVariables`             | Per-account saved data tables.                        |
| `SavedVariablesPerCharacter` | Per-character saved data tables.                      |
| `IconTexture`                | Addon icon (shown in list & settings).                |
| `Category`                   | Addon list grouping header (added 11.1).              |
| `Group`                      | Sub-grouping under a parent addon (added 11.1).       |
| `Dependencies`               | Required addons (comma-separated).                    |
| `OptionalDeps`               | Optional dependencies.                                |

---

## Settings API (Patch 10.0+ / Current)

The Settings API was rewritten in 10.0.0 with breaking changes in 11.0.2. **Do not use the legacy `InterfaceOptions` panel.**

### Basic Vertical Layout Category

```lua
local category, layout = Settings.RegisterVerticalLayoutCategory("MyAddon")

-- Section headers
layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("General"))

-- Proxy setting (reads/writes your own table)
local setting = Settings.RegisterProxySetting(category, "MyVar", type(defaultValue), "Display Name", defaultValue, GetValue, SetValue)

-- Controls
Settings.CreateCheckbox(category, setting, "Tooltip text")
Settings.CreateDropdown(category, setting, GetOptionsFunc, "Tooltip text")
Settings.CreateSlider(category, setting, optionsTable, "Tooltip text")

-- Register with the addon panel
Settings.RegisterAddOnCategory(category)
```

### Section Headers

```lua
-- Returns two values: category AND layout
local category, layout = Settings.RegisterVerticalLayoutCategory("MyAddon")

-- Add a styled section header (same look as Blizzard panels)
layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Section Name", "Optional tooltip"))
```

### Canvas Subcategories (custom frames)

```lua
-- For About panels, custom layouts, etc.
local frame = CreateFrame("Frame", nil, UIParent)
frame:SetSize(400, 300)
frame:Hide()
-- ... populate frame ...

Settings.RegisterCanvasLayoutSubcategory(category, frame, "Tab Name")
```

### Dropdown Options

```lua
local function GetOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add("value1", "Label 1")
    container:Add("value2", "Label 2")
    return container:GetData()
end
```

---

## Secure Action Buttons

For performing protected actions (casting spells, using items) in response to hardware events:

### Cast Spell on Bag Item (macro with PreClick guards)

The `/cast Spell\n/use BAG SLOT` macro pattern works because `/use` targets the
item for the active spell cursor. The key is ensuring `/cast` **will succeed**
before the macro fires — otherwise `/use` acts independently and can equip gear.

```lua
local btn = CreateFrame("Button", "MySecureBtn", UIParent, "SecureActionButtonTemplate")
btn:SetAttribute("type", "macro")
btn:SetAttribute("macrotext", "")  -- Always start empty
btn:RegisterForClicks("AnyDown")

-- Override a key to click this button
SetOverrideBindingClick(btn, true, "MOUSEWHEELUP", "MySecureBtn")
SetOverrideBindingClick(btn, true, "MOUSEWHEELDOWN", "MySecureBtn")

-- Clear when done
ClearOverrideBindings(btn)
```

### CRITICAL: PreClick + PostClick Safety Pattern

The macro is **only set for a single click** and cleared immediately after.
PreClick validates that the spell will succeed before allowing the macro:

```lua
-- Check that the spell will actually fire (not on GCD, not casting, not channeling)
local function isSpellReady(spellName)
    if UnitCastingInfo("player") or UnitChannelInfo("player") then
        return false
    end
    local start, duration = GetSpellCooldown(spellName)
    if start and start > 0 and duration > 0 then
        return false  -- On GCD
    end
    return true
end

btn:SetScript("PreClick", function(self)
    if InCombatLockdown() then
        self:SetAttribute("macrotext", "")
        return
    end
    if not isSpellReady("Disenchant") then
        self:SetAttribute("macrotext", "")
        return
    end
    -- Validate bag/slot item hasn't changed...
    self:SetAttribute("macrotext", "/cast Disenchant\n/use " .. bag .. " " .. slot)
end)

-- PostClick: ALWAYS clear the macro immediately after each click
btn:SetScript("PostClick", function(self)
    if not InCombatLockdown() then
        self:SetAttribute("macrotext", "")
    end
end)
```

### Why NOT type=spell + target-item?

The wiki documents `type=spell` + `target-item` as an atomic alternative:

```lua
btn:SetAttribute("type", "spell")
btn:SetAttribute("spell", "Disenchant")
btn:SetAttribute("target-item", "0 1")  -- "bagID slotIndex"
```

In practice (retail 12.0+), `target-item` does **not reliably auto-target** the
bag item. The spell enters targeting mode (cursor glows) but the item click never
resolves. Use the guarded macro approach instead.

**Rules:**

- Cannot modify secure attributes during combat (`InCombatLockdown()`)
- One hardware event = one action (Blizzard ToS)
- Use `SecureActionButtonTemplate` for macro/spell/item types
- Macro text must be empty between clicks (PostClick clears it)
- PreClick must verify spell will succeed: check casting, channeling, AND GCD
- `UnitCastingInfo` detects casts; `UnitChannelInfo` detects channels; `GetSpellCooldown` detects GCD

---

## Container (Bag) API

Modern retail uses `C_Container` namespace:

```lua
-- Get number of slots in a bag
C_Container.GetContainerNumSlots(bagID)

-- Get item link
C_Container.GetContainerItemLink(bagID, slotIndex)

-- Get item info (stack count, etc.)
local info = C_Container.GetContainerItemInfo(bagID, slotIndex)
-- info.stackCount, info.itemID, info.hyperlink, info.quality, etc.

-- Bag constants
BACKPACK_CONTAINER  -- 0
NUM_BAG_SLOTS       -- 4 (standard bags)
```

---

## Frame Templates & Backdrop

```lua
-- Modern backdrop (BackdropTemplate mixin, 9.0+)
local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
frame:SetBackdropColor(0, 0, 0, 0.8)
frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
```

---

## Item Classification

```lua
local _, _, _, _, _, _, _, _, _, _, _, classID, subClassID = GetItemInfo(itemLink)
```

| classID | Type       |
| ------- | ---------- |
| 2       | Weapon     |
| 4       | Armor      |
| 7       | Tradeskill |

| classID | subClassID | Meaning               |
| ------- | ---------- | --------------------- |
| 7       | 7          | Ore (for Prospecting) |
| 7       | 9          | Herb (for Milling)    |
| 3       | 11         | Artifact Relic        |

---

## Event Handling

```lua
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("BAG_UPDATE")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- init
    elseif event == "BAG_UPDATE" then
        local bagID = ...
    end
end)
```

### EventRegistry (modern pattern, 10.0+)

```lua
EventRegistry:RegisterCallback("ContainerFrame.OpenBag", function(_, bag)
    -- bag opened
end)
```

---

## Timers

```lua
C_Timer.After(seconds, function()
    -- runs once after delay
end)

local ticker = C_Timer.NewTicker(interval, function()
    -- repeats
end, optionalCount)
ticker:Cancel()
```

---

## Slash Commands

```lua
SLASH_MYADDON1 = "/myaddon"
SLASH_MYADDON2 = "/ma"
SlashCmdList["MYADDON"] = function(msg)
    local args = { strsplit(" ", msg) }
    -- handle args
end
```

---

## Chat Output

```lua
-- Basic print (white, DEFAULT_CHAT_FRAME)
print("Hello")

-- Colored addon message
DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[MyAddon]|r Message here")
```

---

## SavedVariables Pattern

```lua
-- In TOC: ## SavedVariables: MyAddonDB

-- In Lua:
local defaults = { enabled = true, scale = 1.0 }

local function normalizeDB()
    if not MyAddonDB then MyAddonDB = {} end
    for k, v in pairs(defaults) do
        if MyAddonDB[k] == nil then MyAddonDB[k] = v end
    end
end

-- Call in ADDON_LOADED or PLAYER_LOGIN
```

---

## Animation Groups

```lua
local ag = frame:CreateAnimationGroup()
ag:SetLooping("BOUNCE")  -- NONE, REPEAT, BOUNCE

local anim = ag:CreateAnimation("Alpha")
anim:SetFromAlpha(0)
anim:SetToAlpha(1)
anim:SetDuration(0.5)

ag:Play()
ag:Stop()
```

---

## Common Gotchas

1. **`Settings.CreateCanvas` doesn't exist** — Use `Settings.RegisterCanvasLayoutSubcategory()` for custom frames.
2. **`category:GetLayout()` doesn't exist** — `Settings.RegisterVerticalLayoutCategory()` returns TWO values: `category, layout`.
3. **`ContainerFrameItemButton_OnModifiedClick` removed** — Use `HookScript` on bag item buttons directly, or `EventRegistry`.
4. **Bindings.xml** — Can be empty/omitted; keybinding can be done entirely in Lua with `SetOverrideBindingClick`.
5. **`InCombatLockdown()`** — Always check before modifying secure frame attributes.
6. **Item info caching** — `GetItemInfo()` may return nil on first call for uncached items. Use `Item:CreateFromItemLink()` callback or scan twice.
7. **`/cast + /use` macro can equip gear** — If `/cast` fails (GCD, casting, channeling), `/use BAG SLOT` fires independently and equips items. Fix: use `isSpellReady()` check in PreClick (validates casting, channeling, AND GCD via `GetSpellCooldown`) so the macro only fires when the spell WILL succeed.
8. **`type=spell` + `target-item` broken in retail** — The wiki documents this as atomic cast-on-item, but in retail 12.0+ it does not reliably auto-target the bag item. The spell enters targeting mode but `target-item` never resolves. Use guarded macro approach instead.
9. **`UnitCastingInfo` vs `UnitChannelInfo`** — `UnitCastingInfo("player")` only detects casts, NOT channels. If the player is channeling, `/cast` fails. Always check BOTH in PreClick guards.
10. **GCD check** — After a cast completes, there may be a brief GCD. `GetSpellCooldown(spellName)` returns `(start, duration)` where `start > 0` means on cooldown/GCD. Check this to prevent scrolling during GCD from firing `/use`.
11. **PostClick for safety** — Always clear `macrotext` in PostClick. The macro should only exist for the single frame of click processing. Between hardware events, the button must be empty.
12. **Spell ID changes per expansion** — Profession spells like Prospecting have expansion-specific variants (e.g. "Midnight Prospecting"). Match by `GetSpellInfo(spellID)` name against known spell names instead of hardcoding IDs.

---

## Useful Resources

- **WoW API Wiki:** https://warcraft.wiki.gg/wiki/World_of_Warcraft_API
- **Settings API:** https://warcraft.wiki.gg/wiki/Settings_API
- **TOC Format:** https://warcraft.wiki.gg/wiki/TOC_format
- **Menu Implementation Guide:** https://warcraft.wiki.gg/wiki/Blizzard_Menu_implementation_guide
- **FrameXML Source:** https://github.com/Gethe/wow-ui-source
- **Townlong Yak (live FrameXML):** https://www.townlong-yak.com/framexml/live
- **Addon Categories (11.1+):** https://warcraft.wiki.gg/wiki/Addon_Categories
- **WoW Dev Discord:** https://discord.gg/wowuidev
- **Live AddOns Source:** https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns