--***********************************************************
--** Welcome Note
--** Spawns a customizable note in new characters' inventories.
--** Configure the note text via Sandbox Options.
--***********************************************************

if isClient() then return end

local function onCreatePlayer(playerIndex, player)
    if not player then return end

    -- Get the note text from sandbox options
    local noteText = ""
    if SandboxVars and SandboxVars.WelcomeNote then
        noteText = SandboxVars.WelcomeNote.NoteText or ""
    end

    if noteText == "" then
        -- Default text if nothing configured
        noteText = "Welcome to the server! Check the server description for rules and information."
    end

    -- Create a note item and add it to the player's inventory
    local inv = player:getInventory()
    if inv then
        local note = inv:AddItem("Base.Notebook")
        if note then
            -- Set custom name and page content
            local customName = "Server Welcome Note"
            if SandboxVars and SandboxVars.WelcomeNote and SandboxVars.WelcomeNote.NoteTitle then
                local title = SandboxVars.WelcomeNote.NoteTitle
                if title ~= "" then
                    customName = title
                end
            end
            note:setName(customName)
            note:setCustomName(true)

            -- Add pages with the note text
            -- Split on <PAGE> delimiter for multi-page notes
            local pages = {}
            for page in (noteText .. "<PAGE>"):gmatch("(.-)<PAGE>") do
                local trimmed = page:match("^%s*(.-)%s*$")
                if trimmed and trimmed ~= "" then
                    pages[#pages + 1] = trimmed
                end
            end

            if #pages == 0 then
                pages[1] = noteText
            end

            -- Write pages to the notebook
            for i, pageText in ipairs(pages) do
                note:addPage(i - 1, pageText)
            end

            print("[WelcomeNote] Gave welcome note to " .. player:getUsername())
        end
    end
end

Events.OnCreatePlayer.Add(onCreatePlayer)
