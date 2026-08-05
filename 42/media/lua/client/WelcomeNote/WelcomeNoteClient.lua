--***********************************************************
--** Welcome Note - Client Component
--** On character creation, requests note content from server.
--** On receiving content, creates the note in player inventory.
--***********************************************************

if not isClient() then return end

local WelcomeNoteClient = {}

local LOG_PREFIX = "[WelcomeNote] "

local function logInfo(msg)
    print(LOG_PREFIX .. msg)
end

local function logError(msg)
    print(LOG_PREFIX .. "ERROR: " .. msg)
end

--- Called when a new character is created. Requests note content from the server.
function WelcomeNoteClient.onCreatePlayer(playerIndex, player)
    if not player then return end
    logInfo("New character created, will request welcome note from server...")
    -- Store the player reference and request on next tick (connection may not be ready yet)
    WelcomeNoteClient.pendingPlayer = player
end

--- Check each tick if we have a pending request to send
function WelcomeNoteClient.onTick()
    if not WelcomeNoteClient.pendingPlayer then return end
    local player = WelcomeNoteClient.pendingPlayer
    WelcomeNoteClient.pendingPlayer = nil
    logInfo("Requesting welcome note from server...")
    sendClientCommand(player, "WelcomeNote", "requestNote", {})
end

--- Called when the server sends the welcome note content.
function WelcomeNoteClient.onServerCommand(module, command, args)
    if module ~= "WelcomeNote" then return end
    if command ~= "deliverNote" then return end

    local player = getPlayer()
    if not player then
        logError("Received note content but no local player found.")
        return
    end

    local title = args.title or "Welcome to the Server!"
    local pageCount = args.pageCount or 0

    if pageCount == 0 then
        logError("Server sent empty note content.")
        return
    end

    local inv = player:getInventory()
    if not inv then
        logError("Could not get player inventory.")
        return
    end

    local note = inv:AddItem("WelcomeNote.WelcomeNote")
    if not note then
        logError("Failed to create WelcomeNote item.")
        return
    end

    note:setName(title)
    note:setCustomName(true)

    -- Populate pages (1-indexed)
    local status, err = pcall(function()
        for i = 1, pageCount do
            local pageText = args["page" .. i]
            if pageText then
                note:addPage(i, pageText)
            end
        end
    end)

    if not status then
        logError("Failed to write pages to notebook: " .. tostring(err))
        return
    end

    logInfo("Welcome note created: '" .. title .. "' (" .. pageCount .. " pages)")
end

Events.OnCreatePlayer.Add(WelcomeNoteClient.onCreatePlayer)
Events.OnServerCommand.Add(WelcomeNoteClient.onServerCommand)
Events.OnTick.Add(WelcomeNoteClient.onTick)
