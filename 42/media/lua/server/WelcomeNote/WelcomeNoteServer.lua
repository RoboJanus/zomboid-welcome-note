--***********************************************************
--** Welcome Note - Server Component
--** Reads welcome-note.txt on server start, caches pages,
--** and delivers the note server-side on client request.
--***********************************************************

if isClient() then return end

local WelcomeNoteServer = {}
WelcomeNoteServer.pages = nil
WelcomeNoteServer.title = "Welcome to the Server!"

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

    -- Read version from sandbox options
    WelcomeNoteServer.version = "1"
    if SandboxVars and SandboxVars.WelcomeNote and SandboxVars.WelcomeNote.NoteVersion then
        local v = SandboxVars.WelcomeNote.NoteVersion
        if v ~= "" then
            WelcomeNoteServer.version = v
        end
    end

    WelcomeNoteServer.pages = pages
    logInfo("Cached " .. #pages .. " page(s), version '" .. WelcomeNoteServer.version .. "'. Welcome notes will be given to new characters.")
end

--- Handle client request for welcome note.
function WelcomeNoteServer.onClientCommand(module, command, player, args)
    if module ~= "WelcomeNote" then return end
    if command ~= "requestNote" then return end

    if not WelcomeNoteServer.pages then
        logWarn("Client " .. tostring(player:getUsername()) .. " requested note but no content cached.")
        return
    end

    -- Check if this player already received the current version (via player modData)
    local modData = player:getModData()
    if modData and modData.WelcomeNoteVersion == WelcomeNoteServer.version then
        return
    end

    -- Add the note server-side (authoritative)
    local inv = player:getInventory()
    if not inv then
        logError("Could not get inventory for " .. tostring(player:getUsername()))
        return
    end

    local note = inv:AddItem("Base.Notebook")
    if not note then
        logError("Failed to create Notebook for " .. tostring(player:getUsername()))
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

    -- Sync to client
    sendAddItemToContainer(inv, note)

    -- Mark player as having received this version
    modData.WelcomeNoteVersion = WelcomeNoteServer.version

    -- Tell client to refresh inventory
    sendServerCommand(player, "WelcomeNote", "noteDelivered", {})

    logInfo("Gave welcome note ('" .. WelcomeNoteServer.title .. "', " .. #WelcomeNoteServer.pages .. " pages) to " ..
        tostring(player:getUsername()))
end

Events.OnServerStarted.Add(WelcomeNoteServer.loadFromFile)
Events.OnClientCommand.Add(WelcomeNoteServer.onClientCommand)

-- Optional JSON API integration (only if JSON API mod is installed)
Events.OnServerStarted.Add(function()
    if JsonAPI then
        JsonAPI.addHandler("welcomenote/reload", function(args)
            -- Optionally bump the version at runtime
            if args and args.version then
                local newVersion = args.version
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
