-- server/main.lua
-- CAD-911 Server Side Script

-- Initialize framework if needed
local Framework = nil
if Config.Framework.ESX then
    Framework = exports['es_extended']:getSharedObject()
elseif Config.Framework.QBCore then
    Framework = exports['qb-core']:GetCoreObject()
end

-- Function to get player name based on framework
local function GetPlayerCharacterName(source)
    if Config.Framework.ESX and Framework then
        local xPlayer = Framework.GetPlayerFromId(source)
        if xPlayer then
            return xPlayer.getName()
        end
    elseif Config.Framework.QBCore and Framework then
        local Player = Framework.Functions.GetPlayer(source)
        if Player then
            return Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
        end
    end
    
    -- Fallback to FiveM name
    return GetPlayerName(source)
end

-- Function to get nearest postal code
local function GetNearestPostal(coords, source)
    local postal = nil
    
    -- Try common export methods for nearest-postal
    local methods = {
        -- Most common method
        function() return exports['nearest-postal']:get_postal(coords.x, coords.y, coords.z) end,
        -- Alternative method
        function() return exports['nearest-postal']:getPostalCode(coords.x, coords.y, coords.z) end,
        -- Another common method
        function() return exports['nearest-postal']:nearestPostal(coords.x, coords.y, coords.z) end,
        -- Simplified method
        function() return exports['nearest-postal']:postal(coords.x, coords.y) end,
        -- Table method
        function() return exports['nearest-postal']:get_nearest_postal(coords.x, coords.y, coords.z) end
    }
    
    for i, method in ipairs(methods) do
        local success, result = pcall(method)
        
        if success and result then
            if type(result) == "table" then
                if result.code then
                    postal = tostring(result.code)
                    print("^2[CAD-911] Postal found using method " .. i .. ": " .. postal .. "^0")
                    break
                elseif result.postal then
                    postal = tostring(result.postal)
                    print("^2[CAD-911] Postal found using method " .. i .. ": " .. postal .. "^0")
                    break
                end
            elseif type(result) == "string" and result ~= "" then
                postal = result
                print("^2[CAD-911] Postal found using method " .. i .. ": " .. postal .. "^0")
                break
            elseif type(result) == "number" then
                postal = tostring(result)
                print("^2[CAD-911] Postal found using method " .. i .. ": " .. postal .. "^0")
                break
            end
        elseif success then
            print("^3[CAD-911] Method " .. i .. " returned: " .. tostring(result) .. "^0")
        else
            print("^1[CAD-911] Method " .. i .. " failed: " .. tostring(result) .. "^0")
        end
    end
    
    if not postal then
        print("^1[CAD-911] Warning: Could not get postal code from nearest-postal (all methods failed)^0")
    end
    
    return postal
end

-- Function to get street names at position (CLIENT-SIDE ONLY)
-- This function is removed from server - street names will be handled client-side

-- Function to format location with postal (street names handled client-side)
local function FormatLocation(coords, source, clientLocation)
    local location = clientLocation or ""
    
    -- Get postal code if enabled and not already included
    if Config.UsePostal then
        local postal = GetNearestPostal(coords, source)
        if postal then
            if location ~= "" and not string.find(location, "Postal") then
                location = string.format(Config.Messages.LocationFormat, location, postal)
            elseif location == "" then
                location = "Postal " .. postal
            end
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

-- Function to send 911 call to CAD
local function SendToCAD(callData)
    -- Only enhance location if coords are provided and postal is missing
    if callData.coords and Config.UsePostal and not string.find(callData.location, "Postal") then
        local postal = GetNearestPostal(callData.coords, callData.source)
        if postal then
            -- Add postal to existing location if not already there
            if callData.location and callData.location ~= "" then
                callData.location = string.format(Config.Messages.LocationFormat, callData.location, postal)
            else
                callData.location = "Postal " .. postal
            end
        end
    end
    
    -- Prepare the data for CAD API
    local postData = {
        callType = "911 - " .. callData.description,
        location = callData.location,
        callerName = callData.playerName,
        communityId = Config.CommunityID
    }
    
    -- Convert to JSON
    local jsonData = json.encode(postData)
    
    -- Make HTTP request to CAD
    PerformHttpRequest(Config.CADEndpoint, function(statusCode, response, headers)
        local success = statusCode == 200 or statusCode == 201
        
        if success then
            print(string.format("^2[CAD-911] Call sent successfully from %s^0", callData.playerName))
            
            -- Log the call ID if provided
            if response then
                local responseData = json.decode(response)
                if responseData and responseData._id then
                    print(string.format("^2[CAD-911] Call ID: %s^0", responseData._id))
                end
            end
            
            -- Send to Discord if enabled
            if Config.LogToDiscord and Config.DiscordWebhook ~= "" then
                SendToDiscord(callData)
            end
        else
            print(string.format("^1[CAD-911] Failed to send call. Status: %d^0", statusCode))
            if response then
                print("^1[CAD-911] Response: " .. response .. "^0")
            end
        end
        
        -- Notify the player
        TriggerClientEvent('cad:911CallResponse', callData.source, success, callData)
        
        -- Notify emergency services if enabled
        if success and Config.NotifyEmergencyServices then
            NotifyEmergencyServices(callData)
        end
    end, 'POST', jsonData, {
        ['Content-Type'] = 'application/json',
        ['Accept'] = 'application/json',
        ['X-API-Key'] = 'fivem-cad-911-key-2024'
    })
end

-- Handle 911 call from client
RegisterNetEvent('cad:send911Call')
AddEventHandler('cad:send911Call', function(data)
    local source = source
    
    -- Add source to data
    data.source = source
    
    -- Get character name if using framework
    data.playerName = GetPlayerCharacterName(source)
    
    -- Log to console
    print(string.format("^3[CAD-911] %s called 911: %s at %s^0", 
        data.playerName, 
        data.description, 
        data.location
    ))
    
    -- Send to CAD
    SendToCAD(data)
end)

-- Function to notify emergency services
function NotifyEmergencyServices(callData)
    if not Config.NotifyEmergencyServices then return end
    
    local players = GetPlayers()
    
    for _, playerId in ipairs(players) do
        playerId = tonumber(playerId)
        local playerJob = nil
        
        -- Get player job based on framework
        if Config.Framework.ESX and Framework then
            local xPlayer = Framework.GetPlayerFromId(playerId)
            if xPlayer then
                playerJob = xPlayer.job.name
            end
        elseif Config.Framework.QBCore and Framework then
            local Player = Framework.Functions.GetPlayer(playerId)
            if Player then
                playerJob = Player.PlayerData.job.name
            end
        end
        
        -- Check if player is emergency services
        if playerJob then
            local isEmergency = false
            
            -- Check police jobs
            for _, job in ipairs(Config.EmergencyJobs.Police) do
                if playerJob == job then
                    isEmergency = true
                    break
                end
            end
            
            -- Check EMS jobs
            if not isEmergency then
                for _, job in ipairs(Config.EmergencyJobs.EMS) do
                    if playerJob == job then
                        isEmergency = true
                        break
                    end
                end
            end
            
            -- Send notification
            if isEmergency then
                TriggerClientEvent('chat:addMessage', playerId, {
                    color = {255, 0, 0},
                    multiline = true,
                    args = {"911 DISPATCH", callData.description .. " | Location: " .. callData.location}
                })
            end
        end
    end
end

-- Function to send to Discord
function SendToDiscord(callData)
    if not Config.LogToDiscord or Config.DiscordWebhook == "" then return end
    
    local embed = {
        {
            title = "🚨 911 Emergency Call",
            description = callData.description,
            color = 15158332, -- Red
            fields = {
                {
                    name = "Caller",
                    value = callData.playerName,
                    inline = true
                },
                {
                    name = "Location",
                    value = callData.location,
                    inline = true
                },
                {
                    name = "Coordinates",
                    value = string.format("X: %.2f, Y: %.2f", callData.coords.x, callData.coords.y),
                    inline = false
                }
            },
            footer = {
                text = "CAD 911 System • " .. os.date("%Y-%m-%d %H:%M:%S")
            }
        }
    }
    
    PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, 
        'POST', 
        json.encode({embeds = embed}), 
        {['Content-Type'] = 'application/json'}
    )
end

-- Admin command to test CAD connection
if Config.EnableAdminCommands then
    RegisterCommand('test911cad', function(source, args, rawCommand)
        -- Only allow from server console
        if source ~= 0 then 
            print("^1[CAD-911] This command can only be used from the server console^0")
            return 
        end
        
        print("^3[CAD-911] Testing CAD connection...^0")
        print("^3[CAD-911] Endpoint: " .. Config.CADEndpoint .. "^0")
        print("^3[CAD-911] Community ID: " .. Config.CommunityID .. "^0")
        
        local testData = {
            callType = "911 - Connection Test",
            location = "Server Test Location",
            callerName = "System Test",
            communityId = Config.CommunityID
        }
        
        print("^3[CAD-911] Sending test data: " .. json.encode(testData) .. "^0")
        
        PerformHttpRequest(Config.CADEndpoint, function(statusCode, response, headers)
            if statusCode == 200 or statusCode == 201 then
                print("^2[CAD-911] SUCCESS: CAD connection working!^0")
                if response then
                    print("^2[CAD-911] Response: " .. response .. "^0")
                end
            else
                print("^1[CAD-911] FAILED: Status Code: " .. statusCode .. "^0")
                if response then
                    print("^1[CAD-911] Response: " .. response .. "^0")
                end
                print("^1[CAD-911] Make sure your CAD backend is running and accessible^0")
                
                -- Debug the request data
                print("^1[CAD-911] Request data sent: " .. json.encode(testData) .. "^0")
                print("^1[CAD-911] Headers sent: Content-Type: application/json, X-API-Key: fivem-cad-911-key-2024^0")
            end
        end, 'POST', json.encode(testData), {
            ['Content-Type'] = 'application/json',
            ['Accept'] = 'application/json',
            ['X-API-Key'] = 'fivem-cad-911-key-2024'
        })
    end, true)
end

-- Server command to test postal lookup
if Config.EnableAdminCommands then
    RegisterCommand('testpostal', function(source, args, rawCommand)
        if source ~= 0 then 
            print("^1[CAD-911] This command can only be used from the server console^0")
            return 
        end
        
        print("^3[CAD-911] === POSTAL TEST RESULTS ===^0")
        
        -- Test multiple locations
        local testLocations = {
            {name = "Los Santos Airport", x = -1037.0, y = -2737.0, z = 20.0},
            {name = "Legion Square", x = 195.0, y = -933.0, z = 30.0},
            {name = "Sandy Shores", x = 1961.0, y = 3740.0, z = 32.0}
        }
        
        for _, location in ipairs(testLocations) do
            local testCoords = {x = location.x, y = location.y, z = location.z}
            local postal = GetNearestPostal(testCoords, nil)
            
            print("^3[CAD-911] Location: " .. location.name .. "^0")
            print("^3[CAD-911]   Coordinates: " .. testCoords.x .. ", " .. testCoords.y .. "^0")
            print("^3[CAD-911]   Postal Code: " .. (postal or "FAILED") .. "^0")
            print("^3[CAD-911] ---^0")
        end
        
        -- Test if nearest-postal resource exists
        local resourceState = GetResourceState('nearest-postal')
        print("^3[CAD-911] Nearest-postal resource state: " .. resourceState .. "^0")
        
        if resourceState ~= 'started' then
            print("^1[CAD-911] ERROR: nearest-postal resource is not started!^0")
            print("^1[CAD-911] Make sure to 'ensure nearest-postal' in your server.cfg^0")
        end
        
        -- Try to list available exports
        print("^3[CAD-911] Checking available exports...^0")
        local success, exports_list = pcall(function()
            return GetResourceMetadata('nearest-postal', 'export', 0)
        end)
        if success and exports_list then
            print("^3[CAD-911] Available exports: " .. tostring(exports_list) .. "^0")
        end
    end, true)
end

-- Version check and startup tests
Citizen.CreateThread(function()
    print("^2[CAD-911] 911 CAD Integration v1.0.0 loaded^0")
    print("^2[CAD-911] Command: /" .. Config.Command .. "^0")
    if Config.EnableAdminCommands then
        print("^2[CAD-911] Admin commands enabled. Use 'test911cad' and 'testpostal' in console to test.^0")
    end
    
    -- Wait for other resources to load
    Citizen.Wait(3000)
    
    -- Check nearest-postal resource state
    local resourceState = GetResourceState('nearest-postal')
    print("^3[CAD-911] Checking nearest-postal resource: " .. resourceState .. "^0")
    
    if resourceState == 'started' then
        -- Test nearest-postal integration
        local testCoords = {x = 0.0, y = 0.0, z = 0.0}
        local postal = GetNearestPostal(testCoords, nil)
        if postal then
            print("^2[CAD-911] Nearest-postal integration: SUCCESS^0")
        else
            print("^1[CAD-911] Nearest-postal integration: PARTIAL - Resource running but export calls failing^0")
            print("^1[CAD-911] Try 'testpostal' command for detailed debugging^0")
        end
    else
        print("^1[CAD-911] Nearest-postal integration: FAILED - Resource not started^0")
        print("^1[CAD-911] Add 'ensure nearest-postal' to your server.cfg before 'ensure " .. GetCurrentResourceName() .. "'^0")
    end
end)
