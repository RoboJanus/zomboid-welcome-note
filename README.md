# Welcome Note - Project Zomboid Server Mod

A server-side mod that spawns a customizable welcome note in every new character's inventory. Perfect for communicating server rules, tips, or lore to new players.

## Features

- Automatically delivers a readable note to every new character
- Note content loaded from a text file on the server (`Lua/welcome-note.txt`)
- Multi-page support using `<PAGE>` delimiter
- Configurable note title and version via Sandbox Options
- Version tracking: players only receive the note once per version (bump the version to re-deliver)
- Optional JSON API integration for hot-reloading content without server restart
- Works in multiplayer and singleplayer
- Safe to uninstall (uses vanilla Notebook item)

## Local testing (before Workshop publish)

Run the dedicated-server test loop in [`test/tests.md`](test/tests.md). Minimum before publish: Session 1 (new character, relog, death) and Session 2 (version bump).

```bash
cp secrets.env.example secrets.env   # set ADMIN_PASSWORD and RCON_PASSWORD
docker compose -f docker-compose.dev.yml up -d
docker compose -f docker-compose.dev.yml logs -f pz-dev
# Connect the PZ client (with this repo enabled as a local mod) to localhost:16261
```

## Installation

1. Subscribe on [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3777821988)
2. Add `\welcomenote` to your server's `Mods=` line
3. Add the Workshop ID `3777821988` to `WorkshopItems=`
4. Create `Lua/welcome-note.txt` in your Zomboid data folder (the same folder containing `Server/` and `Saves/`)
5. Restart the server

## Configuration

### Note Content

Place your note content in `Lua/welcome-note.txt` inside your server's Zomboid data directory. Use `<PAGE>` to separate pages:

```
Welcome to our server!

Rules:
- Be polite
- No griefing
<PAGE>
Tips:
- Generators need fuel
- Join our Discord at discord.gg/example
<PAGE>
Have fun surviving!
```

### Sandbox Options

| Option | Default | Description |
|--------|---------|-------------|
| Note Title | Welcome to the Server! | The display name of the note in the player's inventory |
| Note Version | 1 | Bump this to re-deliver the note to all players who received an older version |

### Example SandboxVars.lua

```lua
WelcomeNote = {
    NoteTitle = "Welcome to Klickalack! READ ME!",
    NoteVersion = "1",
},
```

## JSON API Integration (Optional)

If you also have the [JSON API](https://steamcommunity.com/sharedfiles/filedetails/?id=3727256572) mod installed, a `welcomenote/reload` endpoint is automatically registered. This lets you reload the welcome note content and bump the version without restarting the server.

**Reload content only:**
```json
[{"id":"reload","path":"welcomenote/reload"}]
```

**Reload content and bump version (re-delivers to all players):**
```json
[{"id":"reload","path":"welcomenote/reload","version":"2"}]
```

Response: `{"reloaded":true,"pages":3,"version":"2"}`

## Recommended: Auto-Cleanup

Players may drop the welcome note on the ground. To auto-remove dropped notes, add `WelcomeNote.WelcomeNote` to your `WorldItemRemovalList` in SandboxVars:

```lua
WorldItemRemovalList = "Base.Hat,Base.Glasses,WelcomeNote.WelcomeNote",
```

## Limits

- Maximum 20 pages per note
- Maximum 16,384 characters per page
- Content is cached on server start (use JSON API reload endpoint or restart to pick up changes)

## Compatibility

- Project Zomboid Build 42.20+
- Multiplayer dedicated servers and singleplayer
- No dependencies (JSON API integration is optional)
- Does not conflict with other mods

## License

See LICENSE file.

## Source Code

[GitHub](https://github.com/RoboJanus/zomboid-welcome-note)
