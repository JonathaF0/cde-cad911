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

-- Function to send 911 call to CAD
local function SendToCAD(callData)
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
        ['Accept'] = 'application/json'
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
            end
        end, 'POST', json.encode(testData), {
            ['Content-Type'] = 'application/json',
            ['Accept'] = 'application/json'
        })
    end, true)
end

-- Version check
Citizen.CreateThread(function()
    print("^2[CAD-911] 911 CAD Integration v1.0.0 loaded^0")
    print("^2[CAD-911] Command: /" .. Config.Command .. "^0")
    if Config.EnableAdminCommands then
        print("^2[CAD-911] Admin commands enabled. Use 'test911cad' in console to test.^0")
    end
end)
