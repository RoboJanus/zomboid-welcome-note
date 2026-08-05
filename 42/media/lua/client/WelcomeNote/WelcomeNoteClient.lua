--***********************************************************
--** Welcome Note - Client Component
--** On character creation, requests note from server.
--** On delivery confirmation, refreshes inventory UI.
--***********************************************************

if not isClient() then return end

local WelcomeNoteClient = {}
WelcomeNoteClient.pendingPlayer = nil

local LOG_PREFIX = "[WelcomeNote] "

local function logInfo(msg)
    print(LOG_PREFIX .. msg)
end

--- Called when a new character is created. Requests note from the server.
function WelcomeNoteClient.onCreatePlayer(playerIndex, player)
    if not player then return end
    logInfo("Character loaded, requesting welcome note from server...")
    WelcomeNoteClient.pendingPlayer = player
end

--- Check each tick if we have a pending request to send
function WelcomeNoteClient.onTick()
    if not WelcomeNoteClient.pendingPlayer then return end
    local player = WelcomeNoteClient.pendingPlayer
    WelcomeNoteClient.pendingPlayer = nil
    logInfo("Sending welcome note request to server...")
    sendClientCommand(player, "WelcomeNote", "requestNote", {})
end

--- Called when the server confirms the note was delivered.
function WelcomeNoteClient.onServerCommand(module, command, args)
    if module ~= "WelcomeNote" then return end
    if command ~= "noteDelivered" then return end

    -- Refresh inventory UI so the item appears immediately
    local playerInv = getPlayerInventory(0)
    if playerInv and playerInv.inventoryPane then
        playerInv.inventoryPane:refreshContainer()
    end

    logInfo("Welcome note delivered and inventory refreshed.")
end

Events.OnCreatePlayer.Add(WelcomeNoteClient.onCreatePlayer)
Events.OnServerCommand.Add(WelcomeNoteClient.onServerCommand)
Events.OnTick.Add(WelcomeNoteClient.onTick)
