--***********************************************************
--** Welcome Note - Server Component
--** Reads welcome-note.txt on server start, caches pages,
--** and delivers the note server-side on client request.
--**
--** Delivery rules:
--**   - New characters receive the current welcome note once
--**   - Existing characters receive it again only when NoteVersion changes
--**   - Relogs of the same character do not receive another copy
--***********************************************************

-- Run on dedicated server, listen-server host, and singleplayer.
-- Skip on multiplayer clients (they request via client command).
if isClient() and not isServer() then return end

local WelcomeNoteServer = {}
WelcomeNoteServer.pages = nil
WelcomeNoteServer.title = "Welcome to the Server!"
WelcomeNoteServer.version = "1"
WelcomeNoteServer.received = nil
-- username -> { version = "1", player = IsoPlayer } for this server session only
WelcomeNoteServer.deliveredThisSession = {}

local RECEIVED_MODDATA_KEY = "WelcomeNote_Received"
local LOG_PREFIX = "[WelcomeNote] "

local function logInfo(msg)
    print(LOG_PREFIX .. msg)
end

local function logError(msg)
    print(LOG_PREFIX .. "ERROR: " .. msg)
end

local function logWarn(msg)
    print(LOG_PREFIX .. "WARNING: " .. msg)
end

--- Normalize sandbox / persisted version values to a comparable Lua string.
-- Kahlua `==` is unreliable between Java strings and Lua strings, which made
-- the previous per-connect gate fail and re-deliver the note every login.
local function normalizeVersion(value)
    if value == nil then return "" end
    local asString = tostring(value)
    if asString == "" or asString == "nil" or asString == "null" then return "" end
    return asString
end

local function playerKey(player)
    if not player then return "" end
    return tostring(player:getUsername() or "")
end

function WelcomeNoteServer.getReceivedTable()
    if not WelcomeNoteServer.received then
        WelcomeNoteServer.received = ModData.getOrCreate(RECEIVED_MODDATA_KEY)
    end
    return WelcomeNoteServer.received
end

function WelcomeNoteServer.refreshVersion()
    local version = "1"
    if SandboxVars and SandboxVars.WelcomeNote and SandboxVars.WelcomeNote.NoteVersion ~= nil then
        local sandboxVersion = normalizeVersion(SandboxVars.WelcomeNote.NoteVersion)
        if sandboxVersion ~= "" then
            version = sandboxVersion
        end
    elseif WelcomeNoteServer.version then
        local cached = normalizeVersion(WelcomeNoteServer.version)
        if cached ~= "" then
            version = cached
        end
    end
    WelcomeNoteServer.version = version
    return version
end

function WelcomeNoteServer.hasReceivedCurrentVersion(player)
    local version = WelcomeNoteServer.refreshVersion()
    local key = playerKey(player)
    if key ~= "" then
        local received = WelcomeNoteServer.getReceivedTable()
        if normalizeVersion(received[key]) == version then
            return true
        end
    end

    -- Fallback for characters that were marked on player modData only
    local modData = player and player:getModData()
    if modData and normalizeVersion(modData.WelcomeNoteVersion) == version then
        return true
    end

    return false
end

function WelcomeNoteServer.markReceived(player)
    local version = WelcomeNoteServer.refreshVersion()
    local key = playerKey(player)
    if key ~= "" then
        WelcomeNoteServer.getReceivedTable()[key] = version
    end

    local modData = player and player:getModData()
    if modData then
        modData.WelcomeNoteVersion = version
        if player.transmitModData then
            player:transmitModData()
        end
    end
end

function WelcomeNoteServer.clearReceived(player)
    local key = playerKey(player)
    if key ~= "" then
        WelcomeNoteServer.getReceivedTable()[key] = nil
    end

    local modData = player and player:getModData()
    if modData then
        modData.WelcomeNoteVersion = nil
    end
end

--- Read the welcome note text file and cache the pages.
function WelcomeNoteServer.loadFromFile()
    logInfo("Loading welcome note content...")

    local reader = getFileReader("welcome-note.txt", false)
    if not reader then
        logError("Could not read 'welcome-note.txt'. " ..
            "Ensure the file exists in your server's Lua/ directory (<cachedir>/Lua/welcome-note.txt). " ..
            "Welcome notes will NOT be spawned until this is resolved.")
        return
    end

    local content = ""
    local lineCount = 0
    local status, err = pcall(function()
        local line = reader:readLine()
        while line ~= nil do
            if content ~= "" then
                content = content .. "\n"
            end
            content = content .. line
            lineCount = lineCount + 1
            line = reader:readLine()
        end
        reader:close()
    end)

    if not status then
        logError("Failed to read welcome-note.txt: " .. tostring(err))
        return
    end

    if content == "" then
        logWarn("welcome-note.txt exists but is empty. Welcome notes will NOT be spawned.")
        return
    end

    logInfo("Read " .. lineCount .. " lines from welcome-note.txt")

    -- Split on <PAGE> delimiter
    local pages = {}
    for page in (content .. "<PAGE>"):gmatch("(.-)<PAGE>") do
        local trimmed = page:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            pages[#pages + 1] = trimmed
        end
    end

    if #pages == 0 then
        pages[1] = content
    end

    if #pages > 20 then
        logWarn("welcome-note.txt has " .. #pages .. " pages but Notebooks support a maximum of 20. " ..
            "Content beyond page 20 will be truncated.")
        local truncated = {}
        for i = 1, 20 do
            truncated[i] = pages[i]
        end
        pages = truncated
    end

    -- Read title from sandbox options
    if SandboxVars and SandboxVars.WelcomeNote and SandboxVars.WelcomeNote.NoteTitle then
        local customTitle = SandboxVars.WelcomeNote.NoteTitle
        if customTitle ~= "" then
            WelcomeNoteServer.title = customTitle
        end
    end

    WelcomeNoteServer.refreshVersion()
    WelcomeNoteServer.pages = pages
    logInfo("Cached " .. #pages .. " page(s), version '" .. WelcomeNoteServer.version .. "'. Welcome notes will be given to new characters and when the version changes.")
end

--- True if this specific player object already received the current version this session.
-- Username-only checks cannot distinguish a relog from a new character after death.
local function alreadyDeliveredToThisPlayer(player, version)
    local key = playerKey(player)
    if key == "" then return false end
    local entry = WelcomeNoteServer.deliveredThisSession[key]
    if not entry then return false end
    if normalizeVersion(entry.version) ~= version then return false end
    return entry.player == player
end

local function rememberSessionDelivery(player, version)
    local key = playerKey(player)
    if key == "" then return end
    WelcomeNoteServer.deliveredThisSession[key] = { version = version, player = player }
end

--- Deliver the cached welcome note if this character has not already received the current version.
-- forceNewCharacter: true for OnNewGame so a replacement character still gets the note.
function WelcomeNoteServer.tryDeliver(player, forceNewCharacter)
    if not player then return end
    if player:isDead() then return end

    local username = tostring(player:getUsername() or "unknown")

    if not WelcomeNoteServer.pages then
        logWarn("Client " .. username .. " requested note but no content cached.")
        return
    end

    local version = WelcomeNoteServer.refreshVersion()
    if alreadyDeliveredToThisPlayer(player, version) then
        WelcomeNoteServer.markReceived(player)
        logInfo("Skipping welcome note for " .. username .. " (already delivered this session)")
        return
    end

    if not forceNewCharacter and WelcomeNoteServer.hasReceivedCurrentVersion(player) then
        rememberSessionDelivery(player, version)
        logInfo("Skipping welcome note for " .. username .. " (already received version '" .. version .. "')")
        return
    end

    local inv = player:getInventory()
    if not inv then
        logError("Could not get inventory for " .. username)
        return
    end

    local note = inv:AddItem("Base.Notebook")
    if not note then
        logError("Failed to create Notebook for " .. username)
        return
    end

    note:setName(WelcomeNoteServer.title)
    note:setCustomName(true)

    local status, err = pcall(function()
        for i, pageText in ipairs(WelcomeNoteServer.pages) do
            note:addPage(i, pageText)
        end
    end)

    if not status then
        logError("Failed to write pages: " .. tostring(err))
        return
    end

    sendAddItemToContainer(inv, note)
    WelcomeNoteServer.markReceived(player)
    rememberSessionDelivery(player, version)

    if isServer() then
        sendServerCommand(player, "WelcomeNote", "noteDelivered", {})
    end

    logInfo("Gave welcome note ('" .. WelcomeNoteServer.title .. "', " .. #WelcomeNoteServer.pages .. " pages, version '" .. version .. "') to " .. username)
end

function WelcomeNoteServer.onClientCommand(module, command, player, args)
    if module ~= "WelcomeNote" then return end
    if command ~= "requestNote" then return end
    WelcomeNoteServer.tryDeliver(player)
end

function WelcomeNoteServer.onPlayerDeath(player)
    if not player then return end
    local username = tostring(player:getUsername() or "unknown")
    local key = playerKey(player)
    if key ~= "" then
        WelcomeNoteServer.deliveredThisSession[key] = nil
    end
    WelcomeNoteServer.clearReceived(player)
    logInfo("Cleared welcome note receipt for " .. username .. " (character died; a new character will receive the current note)")
end

--- Brand-new characters (including after death) always receive the current note.
function WelcomeNoteServer.onNewGame(player, square)
    if not player then return end
    WelcomeNoteServer.tryDeliver(player, true)
end

function WelcomeNoteServer.onInitGlobalModData()
    WelcomeNoteServer.received = ModData.getOrCreate(RECEIVED_MODDATA_KEY)
end

Events.OnInitGlobalModData.Add(WelcomeNoteServer.onInitGlobalModData)
Events.OnServerStarted.Add(WelcomeNoteServer.loadFromFile)
Events.OnClientCommand.Add(WelcomeNoteServer.onClientCommand)
Events.OnPlayerDeath.Add(WelcomeNoteServer.onPlayerDeath)
Events.OnNewGame.Add(WelcomeNoteServer.onNewGame)

-- Singleplayer has no client-command round trip; deliver on player load directly.
if not isServer() then
    Events.OnCreatePlayer.Add(function(playerIndex, player)
        WelcomeNoteServer.tryDeliver(player)
    end)
end

-- Optional JSON API integration (only if JSON API mod is installed)
Events.OnServerStarted.Add(function()
    if JsonAPI then
        JsonAPI.addHandler("welcomenote/reload", function(args)
            -- Optionally bump the version at runtime
            if args and args.version then
                local newVersion = normalizeVersion(args.version)
                getSandboxOptions():set("WelcomeNote.NoteVersion", newVersion)
                getSandboxOptions():applySettings()
                getSandboxOptions():saveServerLuaFile(getServerName())
                WelcomeNoteServer.version = newVersion
                if SandboxVars and SandboxVars.WelcomeNote then
                    SandboxVars.WelcomeNote.NoteVersion = newVersion
                end
                logInfo("Version bumped to '" .. newVersion .. "' via JSON API")
            end

            WelcomeNoteServer.loadFromFile()
            if WelcomeNoteServer.pages then
                return '{"reloaded":true,"pages":' .. #WelcomeNoteServer.pages .. ',"version":"' .. WelcomeNoteServer.version .. '"}'
            else
                return '{"reloaded":false,"error":"No content loaded"}'
            end
        end)
        logInfo("Registered JSON API endpoint: welcomenote/reload")
    end
end)
