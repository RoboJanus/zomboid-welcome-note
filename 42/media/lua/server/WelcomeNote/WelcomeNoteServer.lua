--***********************************************************
--** Welcome Note - Server Component
--** Reads welcome-note.txt on server start, caches pages,
--** and sends them to clients on request.
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

    WelcomeNoteServer.pages = pages
    logInfo("Cached " .. #pages .. " page(s). Welcome notes will be given to new characters.")
end

--- Handle client request for welcome note content.
function WelcomeNoteServer.onClientCommand(module, command, player, args)
    if module ~= "WelcomeNote" then return end
    if command ~= "requestNote" then return end

    if not WelcomeNoteServer.pages then
        logWarn("Client " .. tostring(player:getUsername()) .. " requested note but no content cached.")
        return
    end

    -- Send pages to the requesting client
    local responseArgs = {}
    responseArgs.title = WelcomeNoteServer.title
    responseArgs.pageCount = #WelcomeNoteServer.pages
    for i, pageText in ipairs(WelcomeNoteServer.pages) do
        responseArgs["page" .. i] = pageText
    end

    sendServerCommand(player, "WelcomeNote", "deliverNote", responseArgs)
    logInfo("Sent welcome note (" .. #WelcomeNoteServer.pages .. " pages) to " .. tostring(player:getUsername()))
end

Events.OnServerStarted.Add(WelcomeNoteServer.loadFromFile)
Events.OnClientCommand.Add(WelcomeNoteServer.onClientCommand)
