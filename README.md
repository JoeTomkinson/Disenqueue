# Disenqueue

A lightweight World of Warcraft addon that builds a disenchant queue from your bags and processes exactly one queued item per hardware input (button press / wheel bind), which keeps usage within Blizzard's one-action-per-input rules.

Also supports the **Lesser Professions**™ — Prospecting and Milling — for those of us who recognise that Enchanting is the one true craft and everything else is just breaking rocks and grinding weeds.

<img width="1024" height="1024" alt="Disenqueue" src="https://github.com/user-attachments/assets/dbcaf466-e64d-4364-9ad5-a6140991d7bc" />

## Install

1. Copy this addon folder into `World of Warcraft/_retail_/Interface/AddOns/`.
2. Reload the game UI with `/reload`.

## Setup (legal wheel workflow)

1. Open TSM if you use it: `/tsm destroy` (optional companion workflow).
2. Build this addon's queue: `/wdq build`.
3. Open **Key Bindings → AddOns → Disenqueue**.
4. Bind **Destroy/Disenchant next queued item** to **Mouse Wheel Up** and **Mouse Wheel Down**.
5. Scroll to process one queued item at a time.

## Slash commands

- `/wdq build` - Scan bags and rebuild queue
- `/wdq next` - Process one queued item
- `/wdq list` - Print queued items in chat
- `/wdq clear` - Clear queue
- `/wdq quality <min> <max>` - Set quality filter (0-6, default `2 4`)
- `/wdq protect add <itemID|itemLink>` - Protect item from queueing
- `/wdq protect remove <itemID|itemLink>` - Remove protection
- `/wdq protect list` - List protected item IDs

## Troubleshooting

- **Item not in queue**: run `/wdq build` again after opening bags; uncached items can appear on a second scan.
- **Nothing happens when scrolling**: confirm the wheel is bound in Key Bindings to this addon's action.
- **"Disenchant spell not known"**: this character does not have Enchanting/Disenchant available.

## Lesser Professions

Enable in **Settings → AddOns → Disenqueue → Lesser Professions**.

When enabled, Scan Bags will also queue:

- **Prospecting** — ore stacks of 5+ (Jewelcrafting)
- **Milling** — herb stacks of 5+ (Inscription)

Items are grouped by mode in the queue (disenchants first, then prospect, then mill) and the correct spell is cast automatically. Stack-based items keep processing until the stack drops below 5.

## Recommended safety filters

- Keep default quality filter at uncommon-to-epic: `/wdq quality 2 4`
- Protect important gear by item ID or item link using `/wdq protect add ...`

## License

Licensed under the Apache License 2.0. This requires keeping license and attribution notices when redistributing or modifying the addon.
