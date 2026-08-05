# Welcome Note - Manual Test Procedures

## Prerequisites

- Local dev server running with the mod loaded
- PZ client with the mod installed locally
- `test/welcome-note.txt` contains multi-page content with `<PAGE>` delimiters
- `test/KLICKALACK_SandboxVars.lua` has `NoteTitle` and `NoteVersion` configured

---

## Session 1: Fresh Server (clean volumes)

Start the server with a fresh data volume and valid welcome-note.txt (3 pages), NoteVersion = "1".

### Test 1: New Character - Note Delivery

1. Connect with a fresh username, create a character
2. **Verify:** Note appears in inventory with correct title
3. **Verify:** Note has all pages and they are readable
4. **Verify:** Note can be dropped on the ground
5. **Verify:** Note can be moved to a container
6. **Verify:** Server logs show `[WelcomeNote] Gave welcome note ... to <username>`

### Test 2: Relog - No Duplicate

1. Disconnect and reconnect with the same account
2. **Verify:** No second note is added to inventory
3. **Verify:** Server logs do NOT show a second delivery message

### Test 3: Death - New Character Gets Note

1. Die and create a new character on the same account
2. **Verify:** The new character receives a fresh welcome note
3. **Verify:** Pages and title are correct

---

## Session 2: Version Bump (restart server)

Change `NoteVersion` from "1" to "2" in SandboxVars. Restart the server.

### Test 4: Version Bump Re-delivers

1. Reconnect with the same account from Session 1
2. **Verify:** A new welcome note is delivered (version changed)
3. **Verify:** Server logs show delivery

### Test 5: Second Relog - No Duplicate After Version Delivery

1. Disconnect and reconnect again
2. **Verify:** No additional note is added (already received version "2")

---

## Session 3: Title & Content Change (restart server)

Change the title in SandboxVars and update welcome-note.txt content. Keep NoteVersion at "2".

### Test 6: Content Change Without Version Bump

1. Reconnect
2. **Verify:** No new note is delivered (version hasn't changed)
3. Note: Content changes only take effect for players who haven't received the current version

---

## Session 4: Missing File (restart server)

Remove or rename welcome-note.txt so it doesn't exist. Restart the server.

### Test 7: Missing File - No Note

1. **Verify:** Server logs show `[WelcomeNote] ERROR: Could not read 'welcome-note.txt'...`
2. Connect and create a new character
3. **Verify:** No note is spawned, no crash

---

## Session 5: Empty File (restart server)

Create an empty welcome-note.txt (0 bytes). Restart the server.

### Test 8: Empty File - No Note

1. **Verify:** Server logs show `[WelcomeNote] WARNING: welcome-note.txt exists but is empty...`
2. Connect and create a new character
3. **Verify:** No note is spawned

---

## Session 6: Edge Cases (restart server)

Restore welcome-note.txt with valid content.

### Test 9: Single Page (No Delimiters)

1. Use content with no `<PAGE>` delimiters
2. Restart the server
3. **Verify:** Server logs show `Cached 1 page(s)`
4. Connect (use a fresh account or bump version)
5. **Verify:** Note has a single page with all content

### Test 10: Maximum Pages (20+)

1. Create welcome-note.txt with 22+ `<PAGE>` sections
2. Restart the server
3. **Verify:** Server logs show truncation warning
4. **Verify:** Server logs show `Cached 20 page(s)`
5. Connect (fresh account or bump version)
6. **Verify:** Note has exactly 20 pages

---

## Session 7: Default Title (restart server)

Remove the `WelcomeNote` section from SandboxVars entirely. Bump version if needed.

### Test 11: Default Title Fallback

1. Restart the server
2. Connect and create a new character
3. **Verify:** Note title is "Welcome to the Server!" (the default)

---

## Known Limitations

- Maximum 20 pages per note
- Maximum 16,384 characters per page
- Content is cached on server start; file changes require a server restart
- Players who have received the current NoteVersion will not get another until the version is bumped
- Admins should add `WelcomeNote.WelcomeNote` to `WorldItemRemovalList` in SandboxVars to auto-cleanup dropped notes
