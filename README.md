# LootG

![LootG Icon](icon.png)

**LootG** is a World of Warcraft addon that displays looted items with a beautiful scrolling animation in the center of your screen.

## Features

- **Scrolling Loot Display** - Looted items scroll upward with smooth animation
- **Item Quality Colors** - Items are displayed with their quality colors (Common, Uncommon, Rare, Epic, Legendary)
- **Item Icons** - Shows item icons alongside the item name
- **Bag Count** - Displays the total count of the item in your bags (only when > 0)
- **Currency & Gold Support** - Also displays looted currency and gold
- **Customizable Position** - Drag the anchor to position the display anywhere on screen
- **Font Customization** - Choose from multiple fonts, adjust size, outline, and shadow
- **Clean Interface** - Only shows YOUR loot, not party/raid members

## Installation

1. Download and extract the `LootG` folder
2. Place it in your `World of Warcraft\_retail_\Interface\AddOns\` directory
3. Restart WoW or reload your UI (`/reload`)

## Usage

### Commands

- `/lootg` - Open settings panel
- `/lootg test` - Display a test loot message

### Settings

Access settings through:
- Type `/lootg` in chat
- Click the LootG icon in the Addon Compartment (minimap button)
- Go to Game Menu → Options → AddOns → LootG

### Configuration Options

| Setting | Description |
|---------|-------------|
| **Lock Position** | Lock/unlock the anchor for positioning |
| **Show Icon** | Toggle item icon display |
| **X/Y Offset** | Fine-tune the display position |
| **Display Time** | How long messages stay visible (0.5-10s) |
| **Scroll Time** | Animation speed (0.1-5s) |
| **Fade Speed** | Fade out duration (0.1-2s) |
| **Font Size** | Text size (8-48) |
| **Font** | Choose from Standard, Chat, Damage, or Quest fonts |
| **Font Outline** | None, Thin, Thick, or Monochrome |
| **Font Shadow** | Enable/disable text shadow |

## Display Format

```
[Icon] Loot ItemName x1 (BagCount)
```

- **Icon** - Item texture (optional)
- **Loot** - Prefix text
- **ItemName** - Colored by item quality
- **x1** - Quantity looted
- **(BagCount)** - Total in bags (only shown if > 0)

## Screenshots

*Coming soon*

## Changelog

### v1.0.0
- Initial release
- Scrolling loot display with animation
- Item quality colors
- Customizable fonts and positioning
- Settings panel integration

## License

This addon is free to use and modify.

## Author

**Claude** (AI Assistant by Anthropic)

---

*Made with ❤️ for the WoW community*
