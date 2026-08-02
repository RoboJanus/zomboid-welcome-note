# Welcome Note - Project Zomboid Server Mod

A simple server-side mod that spawns a customizable welcome note in every new character's inventory. Perfect for communicating server rules, tips, or lore to new players.

## Features

- Automatically adds a note to new characters on creation
- Fully configurable title and text via Sandbox Options
- Multi-page support using `<PAGE>` delimiter
- Works in multiplayer and singleplayer
- No client-side mod required for players

## Installation

1. Subscribe on Steam Workshop (or install manually)
2. Add `\welcomenote` to your server's `Mods=` line
3. Add the Workshop ID to `WorkshopItems=`
4. Configure the note text in Sandbox Options or `KLICKALACK_SandboxVars.lua`

## Configuration

**Sandbox Options > Welcome Note:**

| Option | Description |
|--------|-------------|
| Note Title | The display name of the note item (default: "Server Welcome Note") |
| Note Text | The content of the note. Use `<PAGE>` to create multiple pages. |

### Example SandboxVars.lua

```lua
WelcomeNote = {
    NoteTitle = "Welcome to Klickalack!",
    NoteText = "Welcome, survivor! Here are the rules:<PAGE>1. Be polite - DBAA<PAGE>2. PvP is disabled<PAGE>3. Join our Discord at discord.gg/mYUWSnFK4g",
},
```

## Compatibility

- Project Zomboid Build 42.20+
- Multiplayer dedicated servers and singleplayer
- No dependencies

## License

MIT

## Source Code

[GitHub](https://github.com/RoboJanus/zomboid-welcome-note)
