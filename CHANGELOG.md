# Changelog

## [1.1.0] — 2025-05-28

I know that AI is a bit of a loaded term when it comes to communities we care about, I want to be transparent that as a software engineer as my day job, I do fold the use of Github Copilot into my workflows typically. I used it for elements of this add-on. Mainly from a learning perspective, I've never quite had the time to really dig into WoW's API and Lua, so I leaned on it to help me understand how to do certain things in the WoW environment. I also used it to help generate some boilerplate code for the UI, and to help me refactor the original monolithic file into a more modular structure. That being said, I wrote the overall architecture and design of the add-on myself, and I did all of the testing and debugging. I also wrote all of the documentation and comments. So while I did use AI as a tool in my development process, I don't think it would be accurate to say that this add-on was "created by AI". It was created by me, with the help of AI as a tool.

### Architecture

- **Modular refactor**: Split monolithic `Disenqueue.lua` (~2900 lines) into 8 focused modules: `Core.lua`, `Theme.lua`, `SlotMap.lua`, `UI_Main.lua`, `UI_Locked.lua`, `UI_Export.lua`, `UI_Minimap.lua`, `Settings.lua`
- **Callback system**: Introduced `ns.RegisterCallback` / `ns.FireCallback` for loose coupling between modules (events: `ADDON_LOADED`, `QUEUE_UPDATED`, `LOCKED_UPDATED`, `STATE_CHANGED`, `CAST_START`, `CAST_STOP`)
- **Shared namespace**: All modules communicate via `local _, ns = ...` pattern

### Complete UI Overhaul

#### Theming System (`Theme.lua`)

- Custom dark-violet color palette with 17+ named tokens (surfaces, accents, status colors, item quality tints)
- Bundled fonts: **Inter** (Regular/Medium/SemiBold) and **JetBrains Mono** (Regular/Medium) with system fallbacks
- 10+ widget factory functions for consistent styling: `CreateIconButton`, `CreatePrimaryButton`, `CreateGhostButton`, `CreateDangerButton`, `CreateKbdPill`, `CreateChip`, `CreateIconTile`, `CreateDivider`, `CreateDragHandle`, `CreateResizeGrip`
- Animated window chrome: 3px violet crown (top) and green floor (bottom) with breathing glow animations and corner wraps

#### Main Queue Window (`UI_Main.lua`)

- **Title bar**: Logo tile, title, version badge, icon buttons (settings, lock panel, close)
- **Meta strip**: Queued/Locked chip counters, dust estimate with shard icon
- **Scrollable item list**: 9 visible rows (resizable 4–16), each with quality-bordered icon tiles, item name, slot label, lock/hide actions, violet hover gradient
- **Custom scrollbar**: 4px themed track + violet thumb (replaces Blizzard templates)
- **Resizable**: Vertical drag grip with snap-to-row and position persistence
- **Draggable**: Full window drag with saved position
- **Processing mode**: Progress strip with count + ETA, animated cast bar, per-row state (active shimmer/pulse, done fade, pending normal), stop button
- **Keyboard hint row**: `shift + scroll to browse` with styled Kbd pills
- **Footer**: Scan Bags (ghost button) + Start (violet primary button)

#### Locked Items Panel (`UI_Locked.lua`)

- Companion panel (360px) auto-anchored to main window
- Two-section layout: **♥ Favorites** (manual locks) and **⚡ Auto-Blocked** (failed disenchants)
- Click-to-unlock rows with quality-colored names and type icons
- Custom scrollbar, mouse-wheel scroll, row tooltips
- Footer with count and flavor text

#### Export/Import Modal (`UI_Export.lua`)

- Dialog-strata modal (460×360) with title bar and tab pill row
- Dark code block with mono font, custom scrollbar, full text selection
- **Export format**: `!WDQ:1!` + Base64(Deflate(CBOR)) — compact binary serialization preserving item IDs, names, and auto-protection flags
- Copy workflow with status feedback
- Import with validation, error messages, and duplicate detection
- Item count displayed accurately from source data

#### Minimap Button (`UI_Minimap.lua`)

- 32×32 draggable button with angle persistence
- Click to toggle main window, tooltip with keybind hints
- Optional hide via settings

#### Settings Panel (`Settings.lua`)

- Modern Blizzard Settings API integration (WoW 10.0+)
- Process key selector: Scroll Wheel, Enter, Space, F, E, R
- Quality range filter (min/max dropdowns)
- Soulbound-only toggle
- Lesser professions master toggle with Prospecting/Milling sub-toggles
- Notification category toggles (Scan, Process, Warnings, Queue)

### Core Features

- **Three processing modes**: Disenchant, Prospect (ore ≥5), Mill (herbs ≥5)
- **7-layer PreClick validation**: Combat check, casting check, cooldown gate, cursor check, loot window check, slot verification, item ID confirmation
- **Auto-protection**: Items that fail twice are automatically locked to prevent repeated attempts
- **Dust estimation**: Quality-based gold value estimates displayed in meta strip
- **Progress tracking**: Live count, ETA calculation, percentage bar
- **Bag integration**: Alt+Click on bag items to toggle queue membership
- **Secure macro system**: Dynamic `/cast` + `/use` macro generation with PostClick cleanup

### Slash Commands

```txt
/wdq build, start, stop, next, list, clear
/wdq quality <min> <max>
/wdq protect add|remove|list
/wdq ui, help
```

### Assets

- 17 custom TGA icons (arrow-right, bolt, close, cog, copy, download, eye, eye-off, heart, lock-closed, lock-open, qr, scroll, search, shard, stop, upload)
- Logo variants: 32×32 (main window) and 20×20 (minimap)
- 5 bundled font files

---

## [1.0.3] — Previous Release

- Single-file monolithic addon
- Basic Blizzard UI templates
