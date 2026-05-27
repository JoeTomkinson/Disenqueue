# Disenqueue

A lightweight disenchant queue that processes **one item per hardware input** — fully compliant with Blizzard's one-action-per-keypress rules. Scan your bags, bind a key (or your scroll wheel), and shred through items safely and efficiently.

Also supports the **Lesser Professions**™ — Prospecting and Milling — for those of us who recognise that Enchanting is the one true craft and everything else is just breaking rocks and grinding weeds.

---

## Features

- **One action per input** — processes exactly one queued item per key/wheel press, staying within Blizzard's hardware input rules at all times
- **Smart bag scanning** — automatically detects disenchantable gear in your bags based on configurable quality filters
- **Scroll wheel workflow** — bind Mouse Wheel Up/Down and scroll through your disenchant pile in seconds
- **Item locking** — permanently protect valuable items so they never enter the queue, with manual lock and auto-lock support
- **Import/Export locked lists** — share your protected item lists between characters or with friends
- **Lesser Professions** — optionally queue Prospecting (ore stacks of 5+) and Milling (herb stacks of 5+) alongside disenchants
- **Soulbound filter** — optionally restrict scanning to soulbound items only, keeping tradeable/AH-sellable gear safe
- **Customisable notifications** — toggle chat messages for scanning, processing, warnings, and queue changes independently
- **Draggable UI** — clean, minimal queue window you can position anywhere
- **Zero combat footprint** — does nothing during combat; fully unloads keybinds when not processing

---

## Getting Started

1. Install the addon into your `Interface/AddOns/` folder and `/reload`
2. Type `/wdq build` to scan your bags and build the queue
3. Open **Key Bindings → AddOns → Disenqueue**
4. Bind **Destroy/Disenchant next queued item** to your preferred key (Mouse Wheel Up/Down recommended)
5. Click **Start** in the Disenqueue UI and scroll to process items one at a time

---

## Slash Commands

| Command | Description |
|---------|-------------|
| `/wdq build` | Scan bags and rebuild the queue |
| `/wdq start` | Begin processing (activates keybind) |
| `/wdq stop` | Stop processing |
| `/wdq next` | Process the next queued item |
| `/wdq list` | Print queued items to chat |
| `/wdq clear` | Clear the entire queue |
| `/wdq quality <min> <max>` | Set quality filter (0–4, default: 2 4) |
| `/wdq protect add <id\|link>` | Permanently protect an item from queueing |
| `/wdq protect remove <id\|link>` | Remove item protection |
| `/wdq protect list` | List all protected item IDs |

---

## Settings

Access via **Settings → AddOns → Disenqueue** or the gear icon in the UI header.

**General**

- Process Key — choose between scroll wheel, keyboard key, or button input
- Minimum/Maximum Quality — filter which item rarities get queued (Poor through Epic)
- Soulbound Only — only queue soulbound gear

**Notifications**

- Scan, Processing, Warning, and Queue Change notifications can each be toggled on/off

**Lesser Professions** *(subcategory)*

- Master toggle to enable/disable
- Prospecting — queue ore stacks (requires Jewelcrafting)
- Milling — queue herb stacks (requires Inscription)

---

## Lesser Professions

When enabled, Scan Bags also queues:

- **Prospecting** — ore stacks of 5+ (Jewelcrafting)
- **Milling** — herb stacks of 5+ (Inscription)

Items are grouped by mode in the queue (disenchants first, then prospect, then mill) and the correct spell is cast automatically. Stack-based items keep processing until the stack drops below 5.

---

## FAQ / Troubleshooting

**Item not appearing in queue?**
Run `/wdq build` again after opening your bags. Uncached items may appear on a second scan.

**Nothing happens when I scroll?**
Make sure the keybind is set in Key Bindings → AddOns → Disenqueue, and that you've clicked Start in the UI.

**"Disenchant spell not known"?**
The current character doesn't have the Enchanting profession or hasn't learned Disenchant.

**Will this get me banned?**
No. Disenqueue processes exactly one item per hardware input event, which is the same rule Blizzard applies to all actions. It does not automate, queue multiple actions, or bypass any restrictions.

---

## Compatibility

- **WoW Retail** — The War Within (Interface 120005)
- **Dependencies** — None. Fully standalone, no libraries required.
- **Conflicts** — None known. Works alongside TSM, Enchantrix, and other inventory addons.

---

## License

Licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0). Attribution and license notices must be preserved when redistributing or modifying.
