# Welcome Note - Local Testing

Use this process to exercise the mod on a local dedicated server **before publishing to the Steam Workshop**.

**Minimum for a workshop publish:** Session 1 (Tests 1–3) and Session 2 (Tests 4–5). Those cover new-character delivery, relog (no duplicate), death, and version-bump re-delivery. Run Sessions 3–7 when changing file loading, page splitting, or sandbox options.

---

## 1. One-time setup

### Server

From `zomboid-welcome-note/`:

```bash
cp secrets.env.example secrets.env
# Set ADMIN_PASSWORD and RCON_PASSWORD (the client uses ADMIN_PASSWORD to log in as admin)

# Rebuild the local dedicated-server image from Klickalack (entrypoint + update logic):
( cd ../klickalack && docker build -f zomboid/Dockerfile -t zomboid:dev . )
```

### Client mod

The dedicated server loads the repo via `DEPLOY_DEV_MODS`. The PZ **client** needs the same files as a local mod.

**Linux:**

```bash
mkdir -p ~/Zomboid/mods
ln -sfn "$(pwd)" ~/Zomboid/mods/welcomenote
```

**Windows** (Command Prompt, adjust the repo path):

```bat
mkdir "%USERPROFILE%\Zomboid\mods"
mklink /J "%USERPROFILE%\Zomboid\mods\welcomenote" "C:\path\to\zomboid-welcome-note"
```

Then in the PZ client: **Main Menu → Mods → enable "Welcome Note"** and restart the client.

---

## 2. Start the local server

```bash
cp test/fixtures/three-pages.txt test/Lua/welcome-note.txt
# Confirm test/KLICKALACK_SandboxVars.lua has NoteVersion = "1"

docker compose -f docker-compose.dev.yml up -d
docker compose -f docker-compose.dev.yml logs -f pz-dev
```

First start downloads the dedicated server (~7GB, 5–10 minutes). Later starts reuse the `welcomenote-dev_pz-dev-data` volume.

Wait until logs show both of:

```
SERVER STARTED
[WelcomeNote] Cached 3 page(s), version '1'. Welcome notes will be given to new characters and when the version changes.
```

If `Cached` never appears, the mod did not load — check `Mods=\welcomenote` in `test/KLICKALACK.ini` and that the container is using `DEPLOY_DEV_MODS=true`.

### Connect

- Host: `localhost:16261`
- Account: create a dedicated **tester** username (not required to be admin)
- Admin login uses `ADMIN_USERNAME=admin` and `ADMIN_PASSWORD` from `secrets.env`

### Watch Welcome Note logs

```bash
docker compose -f docker-compose.dev.yml logs -f pz-dev 2>&1 | grep --line-buffered WelcomeNote
```

### After Lua edits

Restart so the entrypoint recopies the mod into the workshop tree:

```bash
docker compose -f docker-compose.dev.yml restart pz-dev
```

Restart the **client** as well if you changed files under `42/media/lua/client/`.

### Fresh world (Session 1, or after a dirty test)

This wipes player saves and world `ModData` (receipt tracking) but **keeps** the dedicated-server install:

```bash
docker compose -f docker-compose.dev.yml down
docker volume rm welcomenote-dev_pz-dev-config
docker compose -f docker-compose.dev.yml up -d
```

---

## 3. Restore fixtures when you are done

Sandbox and note-file edits are bind-mounted from this repo. Restore them before committing:

```bash
cp test/fixtures/three-pages.txt test/Lua/welcome-note.txt
git checkout -- test/KLICKALACK_SandboxVars.lua
```

---

## Session 1: Fresh server (clean config volume)

Default `test/Lua/welcome-note.txt` (3 pages), `NoteVersion = "1"`. Wipe `welcomenote-dev_pz-dev-config` as above, then start.

### Test 1: New Character - Note Delivery

1. Connect with a fresh username, create a character
2. **Verify:** Note appears in inventory with title `Welcome to the Server!`
3. **Verify:** Note has all 3 pages and they are readable
4. **Verify:** Note can be dropped on the ground
5. **Verify:** Note can be moved to a container
6. **Verify:** Server logs show `[WelcomeNote] Gave welcome note ... to <username>`

### Test 2: Relog - No Duplicate

1. Disconnect and reconnect with the same account
2. **Verify:** No second note is added to inventory
3. **Verify:** Server logs do NOT show a second `Gave welcome note` line
4. **Verify:** Server logs show `[WelcomeNote] Skipping welcome note for <username> (already received version '1')`

### Test 3: Death - New Character Gets Note

1. Die and create a new character on the same account
2. **Verify:** Server logs show `[WelcomeNote] Cleared welcome note receipt for <username> (character died; a new character will receive the current note)`
3. **Verify:** The new character receives a fresh welcome note
4. **Verify:** Pages and title are correct

---

## Session 2: Version bump (restart server)

Keep the same world (do **not** wipe `pz-dev-config`).

```bash
# In test/KLICKALACK_SandboxVars.lua, set NoteVersion = "2"
docker compose -f docker-compose.dev.yml restart pz-dev
```

Wait for `version '2'` in the startup log.

### Test 4: Version Bump Re-delivers

1. Reconnect with the same account from Session 1
2. **Verify:** A new welcome note is delivered (version changed)
3. **Verify:** Server logs show `Gave welcome note` with `version '2'`

### Test 5: Second Relog - No Duplicate After Version Delivery

1. Disconnect and reconnect again
2. **Verify:** No additional note is added (already received version "2")
3. **Verify:** Server logs show `[WelcomeNote] Skipping welcome note for <username> (already received version '2')`

---

## Session 3: Title & content change (restart server)

Change `NoteTitle` in `test/KLICKALACK_SandboxVars.lua` and:

```bash
# Edit test/Lua/welcome-note.txt (or copy a fixture)
# Keep NoteVersion at "2"
docker compose -f docker-compose.dev.yml restart pz-dev
```

### Test 6: Content Change Without Version Bump

1. Reconnect
2. **Verify:** No new note is delivered (version hasn't changed)
3. **Verify:** Server logs show a skip for version '2', not a delivery
4. Note: Content changes only take effect for players who haven't received the current version

---

## Session 4: Missing file (restart server)

```bash
mv test/Lua/welcome-note.txt test/Lua/welcome-note.txt.bak
docker compose -f docker-compose.dev.yml restart pz-dev
```

### Test 7: Missing File - No Note

1. **Verify:** Server logs show `[WelcomeNote] ERROR: Could not read 'welcome-note.txt'...`
2. Connect and create a new character (fresh username, or die first)
3. **Verify:** No note is spawned, no crash

Restore:

```bash
mv test/Lua/welcome-note.txt.bak test/Lua/welcome-note.txt
```

---

## Session 5: Empty file (restart server)

```bash
cp test/fixtures/empty.txt test/Lua/welcome-note.txt
docker compose -f docker-compose.dev.yml restart pz-dev
```

### Test 8: Empty File - No Note

1. **Verify:** Server logs show `[WelcomeNote] WARNING: welcome-note.txt exists but is empty...`
2. Connect and create a new character
3. **Verify:** No note is spawned

---

## Session 6: Edge cases (restart server)

Restore valid content first:

```bash
cp test/fixtures/three-pages.txt test/Lua/welcome-note.txt
```

### Test 9: Single Page (No Delimiters)

```bash
cp test/fixtures/single-page.txt test/Lua/welcome-note.txt
# Bump NoteVersion (or use a fresh username) so this character is eligible
docker compose -f docker-compose.dev.yml restart pz-dev
```

1. **Verify:** Server logs show `Cached 1 page(s)`
2. Connect (fresh account or bumped version)
3. **Verify:** Note has a single page with all content

### Test 10: Maximum Pages (20+)

```bash
cp test/fixtures/too-many-pages.txt test/Lua/welcome-note.txt
# Bump NoteVersion (or use a fresh username)
docker compose -f docker-compose.dev.yml restart pz-dev
```

1. **Verify:** Server logs show truncation warning
2. **Verify:** Server logs show `Cached 20 page(s)`
3. Connect (fresh account or bumped version)
4. **Verify:** Note has exactly 20 pages

---

## Session 7: Default title (restart server)

Remove the `WelcomeNote` block from `test/KLICKALACK_SandboxVars.lua`. Bump `NoteVersion` if the block is still needed for eligibility, or use a fresh username.

### Test 11: Default Title Fallback

1. Restart the server
2. Connect and create a new character
3. **Verify:** Note title is "Welcome to the Server!" (the default)

Restore the `WelcomeNote` block when finished (see section 3).

---

## Workshop publish checklist

- [ ] Session 1 Tests 1–3 pass (new character, relog, death)
- [ ] Session 2 Tests 4–5 pass (version bump re-delivers, second relog does not)
- [ ] `mod.info` `modversion` bumped if behavior changed
- [ ] Test fixtures restored (`test/Lua/welcome-note.txt`, `NoteVersion = "1"`)
- [ ] Client and server Lua both restarted from the same repo tree you will stage with `build.sh`

---

## Troubleshooting

| Symptom | What to check |
|---|---|
| No `[WelcomeNote]` lines at all | `Mods=\welcomenote` in `test/KLICKALACK.ini`; container env `DEPLOY_DEV_MODS=true`; wait for `SERVER STARTED` |
| `Could not read 'welcome-note.txt'` | File must be `test/Lua/welcome-note.txt` (mounted at `/project-zomboid-config/Lua/welcome-note.txt`) |
| Client refused for checksum | Test ini has `DoLuaChecksum=false`; still restart the client after client Lua edits |
| Note every relog | Fail Test 2 — receipt is not persisting; confirm skip log after reconnect |
| No note after death | Fail Test 3 — look for the `Cleared welcome note receipt` line |
| Volume reset re-downloads 7GB | You removed `welcomenote-dev_pz-dev-data`. Only remove `welcomenote-dev_pz-dev-config` for a fresh world |

Confirm the note file inside the container:

```bash
docker exec pz-welcome-note-dev ls -la /project-zomboid-config/Lua/welcome-note.txt
```

---

## Known Limitations

- Maximum 20 pages per note
- Maximum 16,384 characters per page
- Content is cached on server start; file changes require a server restart
- Players who have received the current NoteVersion will not get another until the version is bumped
- Admins should add `WelcomeNote.WelcomeNote` to `WorldItemRemovalList` in SandboxVars to auto-cleanup dropped notes
