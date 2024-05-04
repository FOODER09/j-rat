local isPromptShown = false
local isCameraActive = false
local playerCamera = nil
local playerPed = nil

-- Function to display a text input prompt
function ShowTextInput(title, defaultText, maxInputLength, callback)
    if not isPromptShown then
        DisplayOnscreenKeyboard(1, title, "", defaultText, "", "", "", maxInputLength)
        isPromptShown = true
    end

    -- Function to handle the result of the text input
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)

            -- Check for keyboard input
            if UpdateOnscreenKeyboard() == 1 then -- if the keyboard was closed
                local input = GetOnscreenKeyboardResult()

                if input then
                    isPromptShown = false
                    callback(input)
                    break -- Exit the loop after processing the input
                end
            end

            -- Check for Enter key press to close the prompt
            if isPromptShown and IsControlJustPressed(0, 191) then -- Enter key code: 191
                -- Close the keyboard
                UpdateOnscreenKeyboard(0)
                isPromptShown = false
                break -- Exit the loop
            end
        end
    end)
end

-- Function to get the server ID of a player by their name
function GetPlayerServerIdByName(playerName)
    local playerServerId = nil
    for i = 0, 255 do
        if NetworkIsPlayerActive(i) then
            local playerId = GetPlayerServerId(i)
            local playerNameServer = GetPlayerName(i)
            if playerNameServer == playerName then
                playerServerId = playerId
                break
            end
        end
    end
    return playerServerId
end

-- Function to set up camera following a player
function SetPlayerCamera(serverId)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(serverId))
    if targetPed then
        isCameraActive = true
        playerPed = targetPed
        local playerCoords = GetEntityCoords(targetPed)
        playerCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamActive(playerCamera, true)
        AttachCamToPedBone(playerCamera, playerPed, 31086, 0.0, -3.0, 1.0, true) -- Attach to head bone with an offset
        SetCamFov(playerCamera, 100.0) -- Adjust field of view if needed
        RenderScriptCams(true, false, 0, true, true)
    else
        print("Failed to find player with Server ID: " .. serverId)
    end
end

-- Function to release player camera
function ReleasePlayerCamera()
    isCameraActive = false
    if playerCamera ~= nil then
        DestroyCam(playerCamera, true)
        RenderScriptCams(false, false, 0, true, true)
        playerCamera = nil
        playerPed = nil
    end
end

-- Function to update the list of players and their server IDs
function UpdatePlayersList()
    local playersList = {}
    for i = 0, 255 do
        if NetworkIsPlayerActive(i) then
            local playerName = GetPlayerName(i)
            local playerServerId = GetPlayerServerId(i)
            table.insert(playersList, { name = playerName, serverId = playerServerId })
        end
    end
    return playersList
end

-- Main thread to handle the camera following process
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        -- Update the list of players and their server IDs
        local playersList = UpdatePlayersList()

        -- Display the help text for camera control along with the list of players
        local helpText = isCameraActive and "Press 'E' to exit camera mode." or "Press 'E' to spectate nearest players.\n\nPlayers in vicinity:\n"
        for _, player in ipairs(playersList) do
            helpText = helpText .. string.format("%s - ID: %d\n", player.name, player.serverId)
        end

        SetFloatingHelpTextScreenPosition(0.5, 0.5) -- Set help text position to left-middle
        SetTextComponentFormat("STRING")
        AddTextComponentString(helpText)
        DisplayHelpTextFromStringLabel(0, 0, 1, -1)

        -- Check for control press to initiate or exit camera mode
        if IsControlJustPressed(0, 38) then -- 'E' key code
            if isCameraActive then
                ReleasePlayerCamera() -- Exit camera mode
            else
                -- Display the text input prompt
                ShowTextInput("FMMC_KEY_TIP8", "", 20, function(input)
                    local targetId = tonumber(input) or GetPlayerServerIdByName(input)
                    if targetId then
                        ReleasePlayerCamera() -- Release previous camera
                        SetPlayerCamera(targetId) -- Set up camera for new player
                    else
                        print("Invalid input. Please enter a valid Server ID or player name.")
                    end
                end)
            end
        end

        -- Update camera position and rotation when active
        if isCameraActive then
            local playerCoords = GetEntityCoords(playerPed)
            local camCoords = GetGameplayCamCoord()
            local lookAtCoords = vector3(playerCoords.x, playerCoords.y, playerCoords.z + 1.0) -- Point camera slightly above the player
            SetCamCoord(playerCamera, camCoords.x, camCoords.y, camCoords.z)
            PointCamAtCoord(playerCamera, lookAtCoords.x, lookAtCoords.y, lookAtCoords.z)
        end
    end
end)
