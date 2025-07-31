-- client/main.lua
-- CAD-911 Client Side Script with NPC Reports

local lastCallTime = 0
local lastAnonymousCallTime = 0
local npcReportCooldowns = {
    speeding = {},
    gunshots = {}
}

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

-- Function to get nearest postal code from client-side
local function GetNearestPostal(coords)
    local postal = nil
    
    -- Try multiple export methods for nearest-postal
    local methods = {
        -- Most common method
        function() return exports['nearest-postal']:get_postal(coords.x, coords.y, coords.z) end,
        -- Alternative methods
        function() return exports['nearest-postal']:getPostalCode(coords.x, coords.y, coords.z) end,
        function() return exports['nearest-postal']:nearestPostal(coords.x, coords.y, coords.z) end,
        function() return exports['nearest-postal']:postal(coords.x, coords.y) end,
        function() return exports['nearest-postal']:get_nearest_postal(coords.x, coords.y, coords.z) end,
        -- No coordinates method
        function() return exports['nearest-postal']:getPostal() end,
    }
    
    for i, method in ipairs(methods) do
        local success, result = pcall(method)
        
        if success and result then
            if type(result) == "table" then
                if result.code then
                    postal = tostring(result.code)
                    break
                elseif result.postal then
                    postal = tostring(result.postal)
                    break
                end
            elseif type(result) == "string" and result ~= "" then
                postal = result
                break
            elseif type(result) == "number" then
                postal = tostring(result)
                break
            end
        end
    end
    
    return postal
end

-- Function to get complete location string
local function GetLocationString(coords)
    local location = ""
    
    -- Get street names if enabled
    if Config.UseStreetNames then
        local streetName = GetStreetNames(coords)
        if streetName and streetName ~= "" then
            location = streetName
        end
    end
    
    -- Get postal code if enabled
    if Config.UsePostal then
        local postal = GetNearestPostal(coords)
        if postal then
            if location ~= "" then
                location = string.format(Config.Messages.LocationFormat, location, postal)
            else
                location = "Postal " .. postal
            end
        elseif location == "" then
            -- Fallback message if postal lookup fails
            location = "Location Unknown"
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

-- Function to check if position is in safe zone
local function IsInSafeZone(coords)
    if not Config.NPCReports.DisableInSafeZones then
        return false
    end
    
    for _, zone in ipairs(Config.NPCReports.SafeZones) do
        local distance = #(coords - zone.coords)
        if distance <= zone.radius then
            return true
        end
    end
    
    return false
end

-- Function to check if area is on cooldown
local function IsAreaOnCooldown(coords, reportType)
    local currentTime = GetGameTimer()
    local cooldownList = npcReportCooldowns[reportType]
    
    -- Check each cooldown entry
    for i = #cooldownList, 1, -1 do
        local entry = cooldownList[i]
        local timePassed = (currentTime - entry.time) / 1000
        
        -- Remove expired cooldowns
        if timePassed > (reportType == "speeding" and Config.NPCReports.Speeding.Cooldown or Config.NPCReports.Gunshots.Cooldown) then
            table.remove(cooldownList, i)
        else
            -- Check if we're in cooldown radius (50m from report location)
            local distance = #(coords - entry.coords)
            if distance < 50.0 then
                return true
            end
        end
    end
    
    return false
end

-- Function to add area cooldown
local function AddAreaCooldown(coords, reportType)
    table.insert(npcReportCooldowns[reportType], {
        coords = coords,
        time = GetGameTimer()
    })
end

-- Function to count nearby NPCs
local function CountNearbyNPCs(coords, radius)
    local count = 0
    local handle, ped = FindFirstPed()
    local success
    
    repeat
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped, true) then
            local pedCoords = GetEntityCoords(ped)
            local distance = #(coords - pedCoords)
            
            if distance <= radius then
                -- Check if ped is a valid "witness" (not in vehicle, not animal, etc)
                if GetPedType(ped) == 4 or GetPedType(ped) == 5 then -- Civilian NPCs
                    if not IsPedInAnyVehicle(ped, false) then
                        count = count + 1
                    end
                end
            end
        end
        
        success, ped = FindNextPed(handle)
    until not success
    
    EndFindPed(handle)
    return count
end

-- Function to get random NPC report message
local function GetRandomNPCMessage(reportType)
    local messages = Config.Messages.NPCReports[reportType]
    return messages[math.random(#messages)]
end

-- Function to send NPC report
local function SendNPCReport(coords, reportType, additionalInfo)
    local location = GetLocationString(coords)
    local description = GetRandomNPCMessage(reportType)
    
    if additionalInfo then
        description = description .. " - " .. additionalInfo
    end
    
    -- Send to server as NPC report
    TriggerServerEvent('cad:sendNPC911Call', {
        description = description,
        location = location,
        coords = {x = coords.x, y = coords.y, z = coords.z},
        reportType = reportType
    })
    
    -- Add cooldown for this area
    AddAreaCooldown(coords, reportType)
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

-- Anonymous 911 command
RegisterCommand(Config.AnonymousCommand, function(source, args, rawCommand)
    -- Check if player provided a description
    if #args == 0 then
        ShowNotification(Config.Messages.NoArgsAnonymous)
        return
    end
    
    -- Check cooldown
    local currentTime = GetGameTimer()
    local timeSinceLastCall = (currentTime - lastAnonymousCallTime) / 1000
    
    if timeSinceLastCall < Config.AnonymousCooldownSeconds then
        local remainingTime = math.ceil(Config.AnonymousCooldownSeconds - timeSinceLastCall)
        ShowNotification(string.format(Config.Messages.AnonymousCooldown, remainingTime))
        return
    end
    
    -- Get only basic location data (no exact coords for anonymity)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local location = ""
    
    -- For anonymous calls, only provide general area
    if Config.UsePostal then
        local postal = GetNearestPostal(coords)
        if postal then
            location = "Near Postal " .. postal
        else
            location = "Unknown Location"
        end
    else
        -- Just give a very general area description
        location = "Somewhere in the city"
    end
    
    local description = table.concat(args, " ")
    
    -- Show sending notification
    ShowNotification(Config.Messages.SendingAnonymous)
    
    -- Send to server as anonymous
    TriggerServerEvent('cad:sendAnonymous911Call', {
        description = description,
        location = location,
        -- Don't send exact coords for anonymous calls
        coords = nil
    })
    
    -- Update last anonymous call time
    lastAnonymousCallTime = currentTime
end, false)

-- Handle 911 call response from server
RegisterNetEvent('cad:911CallResponse')
AddEventHandler('cad:911CallResponse', function(success, callData, isNPCReport, isAnonymous)
    if success then
        if not isNPCReport then
            if isAnonymous then
                ShowNotification(Config.Messages.SuccessAnonymous)
            else
                ShowNotification(Config.Messages.Success)
            end
        end
        
        -- Create blip if enabled (but not for anonymous calls)
        if Config.BlipSettings.Enabled and callData.coords and not isAnonymous then
            local blipConfig = isNPCReport and Config.BlipSettings.NPCReport or Config.BlipSettings
            
            local blip = AddBlipForCoord(callData.coords.x, callData.coords.y, callData.coords.z)
            SetBlipSprite(blip, blipConfig.Sprite or Config.BlipSettings.Sprite)
            SetBlipColour(blip, blipConfig.Color or Config.BlipSettings.Color)
            SetBlipScale(blip, Config.BlipSettings.Scale)
            SetBlipAsShortRange(blip, true)
            
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(blipConfig.Text or Config.BlipSettings.Text)
            EndTextCommandSetBlipName(blip)
            
            -- Remove blip after duration
            Citizen.SetTimeout(Config.BlipSettings.Duration * 1000, function()
                RemoveBlip(blip)
            end)
        end
    else
        if not isNPCReport then
            ShowNotification(Config.Messages.Failed)
        end
    end
end)

-- Speeding Detection Thread
Citizen.CreateThread(function()
    if not Config.NPCReports.Enabled or not Config.NPCReports.Speeding.Enabled then
        return
    end
    
    while true do
        Citizen.Wait(2000) -- Check every 2 seconds for performance
        
        local playerPed = PlayerPedId()
        
        if IsPedInAnyVehicle(playerPed, false) then
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            
            if GetPedInVehicleSeat(vehicle, -1) == playerPed then -- Only if player is driver
                local speed = GetEntitySpeed(vehicle) * 3.6 -- Convert to KM/H
                
                if speed > Config.NPCReports.Speeding.SpeedThreshold then
                    local coords = GetEntityCoords(vehicle)
                    
                    -- Check if in safe zone or on cooldown
                    if not IsInSafeZone(coords) and not IsAreaOnCooldown(coords, "speeding") then
                        -- Check for nearby NPCs
                        local nearbyNPCs = CountNearbyNPCs(coords, Config.NPCReports.Speeding.CheckRadius)
                        
                        if nearbyNPCs >= Config.NPCReports.Speeding.MinNPCsNearby then
                            -- Roll chance to report
                            if math.random() < Config.NPCReports.Speeding.ChanceToReport then
                                -- Get vehicle info
                                local vehicleModel = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
                                local plateText = GetVehicleNumberPlateText(vehicle)
                                local vehicleColor = GetVehicleColor(vehicle)
                                
                                local additionalInfo = string.format("%s - Plate: %s", vehicleModel, plateText)
                                
                                SendNPCReport(coords, "Speeding", additionalInfo)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Gunshot Detection Thread
Citizen.CreateThread(function()
    if not Config.NPCReports.Enabled or not Config.NPCReports.Gunshots.Enabled then
        return
    end
    
    while true do
        Citizen.Wait(0) -- Needs to be more responsive for gunshots
        
        local playerPed = PlayerPedId()
        
        -- Check if player is shooting
        if IsPedShooting(playerPed) then
            local weapon = GetSelectedPedWeapon(playerPed)
            
            -- Check if weapon is not blacklisted
            if not Config.NPCReports.Gunshots.BlacklistedWeapons[weapon] then
                local coords = GetEntityCoords(playerPed)
                
                -- Check if in safe zone or on cooldown
                if not IsInSafeZone(coords) and not IsAreaOnCooldown(coords, "gunshots") then
                    -- Check for nearby NPCs
                    local nearbyNPCs = CountNearbyNPCs(coords, Config.NPCReports.Gunshots.DetectionRadius)
                    
                    if nearbyNPCs >= Config.NPCReports.Gunshots.MinNPCsNearby then
                        -- Roll chance to report
                        if math.random() < Config.NPCReports.Gunshots.ChanceToReport then
                            -- Wait a bit before reporting (realistic delay)
                            Citizen.SetTimeout(math.random(5000, 15000), function()
                                SendNPCReport(coords, "Gunshots")
                            end)
                        end
                    end
                end
                
                -- Wait to avoid multiple reports for automatic weapons
                Citizen.Wait(3000)
            end
        end
    end
end)

-- Add chat suggestion for the command
Citizen.CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Call 911 for emergency services', {
        { name = "description", help = "Describe your emergency" }
    })
    
    TriggerEvent('chat:addSuggestion', '/' .. Config.AnonymousCommand, 'Send anonymous tip to 911', {
        { name = "description", help = "Describe what you witnessed (your identity will be hidden)" }
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
        
        -- Test postal specifically
        local postal = GetNearestPostal(coords)
        if postal then
            print("^2[CAD-911] Postal code: " .. postal .. "^0")
        else
            print("^1[CAD-911] Postal code: FAILED^0")
        end
    end, false)
    
    RegisterCommand('testnpcreport', function(source, args)
        local reportType = args[1] or "Gunshots"
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        
        SendNPCReport(coords, reportType, "TEST REPORT")
        print("^2[CAD-911] Sent test NPC report^0")
    end, false)
    
    TriggerEvent('chat:addSuggestion', '/testlocation', 'Test location detection for 911 calls')
    TriggerEvent('chat:addSuggestion', '/testnpcreport', 'Test NPC report system', {
        { name = "type", help = "Speeding or Gunshots" }
    })
end

-- Helper function to get vehicle color name
function GetVehicleColor(vehicle)
    local colors = {
        [0] = "Black", [1] = "Black", [2] = "Black", [3] = "Silver",
        [4] = "Silver", [5] = "Silver", [6] = "Silver", [7] = "Silver",
        [8] = "Silver", [9] = "Silver", [10] = "Silver", [11] = "Black",
        [27] = "Red", [28] = "Red", [29] = "Red", [30] = "Red",
        [31] = "Red", [32] = "Red", [33] = "Red", [34] = "Red",
        [35] = "Red", [36] = "Red", [37] = "Red", [38] = "Orange",
        [41] = "Orange", [42] = "Yellow", [88] = "Yellow", [89] = "Yellow",
        [55] = "Green", [125] = "Green", [49] = "Green", [50] = "Green",
        [64] = "Blue", [65] = "Blue", [66] = "Blue", [67] = "Blue",
        [68] = "Blue", [69] = "Blue", [70] = "Blue", [71] = "Blue",
        [72] = "Blue", [73] = "Blue", [74] = "Blue", [75] = "Blue",
        [76] = "Blue", [77] = "Blue", [78] = "Blue", [79] = "Blue",
        [80] = "Blue", [81] = "Blue", [82] = "Blue", [83] = "Blue",
        [111] = "White", [112] = "White", [113] = "White", [121] = "White",
        [122] = "White", [131] = "White", [132] = "White", [134] = "White"
    }
    
    local primaryColor, secondaryColor = GetVehicleColours(vehicle)
    return colors[primaryColor] or "Unknown Color"
end
