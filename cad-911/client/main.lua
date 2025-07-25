-- client/main.lua
-- CAD-911 Client Side Script

local lastCallTime = 0

-- Function to get street names at position
local function GetStreetNames(coords)
    local s1, s2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street1 = GetStreetNameFromHashKey(s1)
    local street2 = GetStreetNameFromHashKey(s2)
    
    if street2 and street2 ~= "" then
        return street1 .. " & " .. street2
    else
        return street1
    end
end

-- Function to get complete location string
local function GetLocationString(coords)
    local location = ""
    
    -- Get street names if enabled
    if Config.UseStreetNames then
        location = GetStreetNames(coords)
    end
    
    -- Get postal code if enabled
    if Config.UsePostal then
        -- Check if nearest-postal exists
        local success, postal = pcall(function()
            return exports['nearest-postal']:getPostal()
        end)
        
        if success and postal then
            if location ~= "" then
                location = string.format(Config.Messages.LocationFormat, location, postal.code)
            else
                location = "Postal " .. postal.code
            end
        elseif not success then
            print("^1[CAD-911] Warning: nearest-postal not found. Install it for postal codes.^0")
        end
    end
    
    -- Add coordinates if enabled
    if Config.UseCoordinates then
        local coordStr = string.format("(%.1f, %.1f)", coords.x, coords.y)
        if location ~= "" then
            location = location .. " " .. coordStr
        else
            location = coordStr
        end
    end
    
    -- Fallback to coordinates if no location found
    if location == "" then
        location = string.format("%.2f, %.2f", coords.x, coords.y)
    end
    
    return location
end

-- Function to show notification
local function ShowNotification(message)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(message)
    DrawNotification(false, false)
end

-- Main 911 command
RegisterCommand(Config.Command, function(source, args, rawCommand)
    -- Check if player provided a description
    if #args == 0 then
        ShowNotification(Config.Messages.NoArgs)
        return
    end
    
    -- Check cooldown
    local currentTime = GetGameTimer()
    local timeSinceLastCall = (currentTime - lastCallTime) / 1000
    
    if timeSinceLastCall < Config.CooldownSeconds then
        local remainingTime = math.ceil(Config.CooldownSeconds - timeSinceLastCall)
        ShowNotification(string.format(Config.Messages.Cooldown, remainingTime))
        return
    end
    
    -- Get player data
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local location = GetLocationString(coords)
    local description = table.concat(args, " ")
    
    -- Get player name
    local playerName = GetPlayerName(PlayerId())
    
    -- Show sending notification
    ShowNotification(Config.Messages.Sending)
    
    -- Send to server
    TriggerServerEvent('cad:send911Call', {
        description = description,
        location = location,
        coords = {x = coords.x, y = coords.y, z = coords.z},
        playerName = playerName
    })
    
    -- Update last call time
    lastCallTime = currentTime
end, false)

-- Handle 911 call response from server
RegisterNetEvent('cad:911CallResponse')
AddEventHandler('cad:911CallResponse', function(success, callData)
    if success then
        ShowNotification(Config.Messages.Success)
        
        -- Create blip if enabled
        if Config.BlipSettings.Enabled and callData.coords then
            local blip = AddBlipForCoord(callData.coords.x, callData.coords.y, callData.coords.z)
            SetBlipSprite(blip, Config.BlipSettings.Sprite)
            SetBlipColour(blip, Config.BlipSettings.Color)
            SetBlipScale(blip, Config.BlipSettings.Scale)
            SetBlipAsShortRange(blip, true)
            
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Config.BlipSettings.Text)
            EndTextCommandSetBlipName(blip)
            
            -- Remove blip after duration
            Citizen.SetTimeout(Config.BlipSettings.Duration * 1000, function()
                RemoveBlip(blip)
            end)
        end
    else
        ShowNotification(Config.Messages.Failed)
    end
end)

-- Add chat suggestion for the command
Citizen.CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Call 911 for emergency services', {
        { name = "description", help = "Describe your emergency" }
    })
end)

-- Test location command (admin/debug)
if Config.EnableAdminCommands then
    RegisterCommand('testlocation', function()
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local location = GetLocationString(coords)
        
        print("^2[CAD-911] Current location: " .. location .. "^0")
        ShowNotification("~g~Location:~w~ " .. location)
    end, false)
    
    TriggerEvent('chat:addSuggestion', '/testlocation', 'Test location detection for 911 calls')
end
