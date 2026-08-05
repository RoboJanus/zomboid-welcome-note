# Welcome Note - Manual Test Procedures

## Prerequisites

- Local dev server running (`docker-compose -f docker-compose.dev.yml up`)
- PZ client with the mod installed locally
- `test/welcome-note.txt` contains multi-page content with `<PAGE>` delimiters
- `test/KLICKALACK_SandboxVars.lua` has a custom `NoteTitle`

## Tests

### 1. New Account - First Character

1. Connect to the server with a brand new username/password
2. Create a character
3. **Verify:** A note appears in inventory with the title from SandboxVars
4. **Verify:** Opening the note shows all pages from welcome-note.txt
5. **Verify:** Pages display correct content and can be navigated

### 2. Death - New Character (Same Account)

1. Using an existing account, die (kill yourself or use admin commands)
2. Create a new character on the same account
3. **Verify:** The welcome note appears in the new character's inventory
4. **Verify:** Content and title match the current configuration

### 3. Configuration Change (Title & Content)

1. Log out of the server
2. Edit `test/welcome-note.txt` with different content
3. Edit `test/KLICKALACK_SandboxVars.lua` with a different `NoteTitle`
4. Restart the server (`docker-compose -f docker-compose.dev.yml restart pz-dev`)
5. Connect and create a new character
6. **Verify:** The note has the NEW title
7. **Verify:** The note has the NEW content

### 4. Missing File

1. Rename or delete `test/welcome-note.txt`
2. Restart the server
3. **Verify:** Server logs show: `[WelcomeNote] ERROR: Could not read 'welcome-note.txt'...`
4. Connect and create a new character
5. **Verify:** No note is spawned (no crash, no error on client)
6. Restore the file for subsequent tests

### 5. Empty File

1. Replace `test/welcome-note.txt` contents with an empty file (0 bytes)
2. Restart the server
3. **Verify:** Server logs show: `[WelcomeNote] WARNING: welcome-note.txt exists but is empty...`
4. Connect and create a new character
5. **Verify:** No note is spawned

### 6. Single Page (No Delimiters)

1. Replace `test/welcome-note.txt` with content that has no `<PAGE>` delimiters
2. Restart the server
3. **Verify:** Server logs show: `Cached 1 page(s)`
4. Connect and create a new character
5. **Verify:** Note spawns with a single page containing all the content

### 7. Maximum Pages (20+)

1. Create a `welcome-note.txt` with more than 20 `<PAGE>` delimiters (21+ sections)
2. Restart the server
3. **Verify:** Server logs show truncation warning: `welcome-note.txt has X pages but Notebooks support a maximum of 20`
4. **Verify:** Server logs show: `Cached 20 page(s)`
5. Connect and create a new character
6. **Verify:** Note has exactly 20 pages, content beyond page 20 is not present

### 8. Default Title (No SandboxVars)

1. Remove or comment out the `WelcomeNote` section from `KLICKALACK_SandboxVars.lua`
2. Restart the server
3. Connect and create a new character
4. **Verify:** Note title defaults to "Welcome to the Server!"

### 9. Server Logs

1. After any successful character creation with the note
2. **Verify:** Server logs show: `[WelcomeNote] Sent welcome note (X pages) to <username>`
3. **Verify:** Client console shows: `[WelcomeNote] Welcome note created: '<title>' (X pages)`

## Known Limitations

- Maximum 20 pages per note
- Maximum 16,384 characters per page
- Note content is cached on server start; changes require a server restart
- Players can edit the note content (PZ does not support truly read-only notebooks)
- Admins should add `WelcomeNote.WelcomeNote` to `WorldItemRemovalList` in SandboxVars to auto-cleanup dropped notes
