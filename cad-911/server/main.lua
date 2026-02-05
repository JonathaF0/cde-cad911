-- server/main.lua
-- CAD-911 Server Side Script with CDE Duty Integration
-- Version 2.2.0 - Complete Rewrite with Speed Camera Support & Improved LEO Bypass

-- ========================================
-- FRAMEWORK INITIALIZATION
-- ========================================
local Framework = nil
if Config.Framework.ESX then
    Framework = exports['es_extended']:getSharedObject()
elseif Config.Framework.QBCore then
    Framework = exports['qb-core']:GetCoreObject()
end

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

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
    
    return GetPlayerName(source)
end

-- Function to get nearest postal code (server-side)
local function GetNearestPostal(coords, source)
    local postal = nil
    
    local methods = {
        function() return exports['nearest-postal']:get_postal(coords.x, coords.y, coords.z) end,
        function() return exports['nearest-postal']:getPostalCode(coords.x, coords.y, coords.z) end,
        function() return exports['nearest-postal']:nearestPostal(coords.x, coords.y, coords.z) end,
        function() return exports['nearest-postal']:postal(coords.x, coords.y) end,
        function() return exports['nearest-postal']:get_nearest_postal(coords.x, coords.y, coords.z) end
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

-- ========================================
-- LEO STATUS INTEGRATION (v2.2.0)
-- ========================================

-- Handle client request for LEO status
RegisterNetEvent('cad:requestLEOStatus')
AddEventHandler('cad:requestLEOStatus', function()
    local source = source
    local isLEO = false
    
    -- Check if CDE_Duty is available
    if GetResourceState('CDE_Duty') == 'started' then
        -- Use export to check LEO status
        local success, result = pcall(function()
            return exports['CDE_Duty']:IsPlayerOnDutyLEO(source)
        end)
        
        if success then
            isLEO = result
        end
    end
    
    -- Send status to client
    TriggerClientEvent('CDE:SetLEOStatus', source, isLEO)
    
    if Config.EnableDebug then
        print(string.format("^3[CAD-911] Player %s LEO status: %s^0", GetPlayerName(source), tostring(isLEO)))
    end
end)

-- ========================================
-- CDE DUTY INTEGRATION (v2.2.0)
-- ========================================

-- Function to forward 911 calls to CDE Duty System
local function ForwardToOnDutyUnits(callData, isNPCReport, isAnonymous)
    -- Check if CDE_Duty resource is running
    if GetResourceState('CDE_Duty') ~= 'started' then
        if Config.EnableDebug then
            print("^3[CAD-911] CDE_Duty not running, skipping unit notification^0")
        end
        return
    end
    
    -- Prepare call data for duty system
    local dutyCallData = {
        description = callData.description,
        location = callData.location,
        coords = callData.coords,
        playerName = callData.playerName,
        caller = isAnonymous and "Anonymous" or callData.playerName,
        reportType = callData.reportType,
        message = callData.description,
        isNPC = isNPCReport,
        isAnonymous = isAnonymous
    }
    
    -- Trigger event for CDE_Duty
    TriggerEvent('cad:forward911ToUnits', dutyCallData)
    
    -- Get on-duty counts from CDE Duty
    local leoCount = 0
    local fireCount = 0
    
    if exports['CDE_Duty'] then
        local success, leoUnits = pcall(function() return exports['CDE_Duty']:GetOnDutyLEOUnits() end)
        if success and leoUnits then
            leoCount = #leoUnits
        end
        
        local success2, fireUnits = pcall(function() return exports['CDE_Duty']:GetOnDutyFireUnits() end)
        if success2 and fireUnits then
            fireCount = #fireUnits
        end
    end
    
    print(string.format("^2[CAD-911] Forwarded %s to %d LEO and %d Fire/EMS units^0", 
        isAnonymous and "anonymous tip" or (isNPCReport and "NPC report" or "911 call"),
        leoCount, fireCount))
end

-- ========================================
-- MAIN CAD COMMUNICATION FUNCTION
-- ========================================

local function SendToCAD(callData, isNPCReport, isAnonymous)
    if Config.EnableDebug then
        print("^3[CAD-911] === SENDING TO CAD ===^0")
        print("^3[CAD-911] Type: " .. (isAnonymous and "Anonymous" or (isNPCReport and "NPC Report" or "Player Call")) .. "^0")
        print("^3[CAD-911] Description: " .. (callData.description or "nil") .. "^0")
        print("^3[CAD-911] Location: " .. (callData.location or "nil") .. "^0")
        if callData.reportType then
            print("^3[CAD-911] Report Type: " .. callData.reportType .. "^0")
        end
    end
    
    -- Enhance location with postal if needed
    if callData.coords and Config.UsePostal and not string.find(callData.location, "Postal") then
        local postal = GetNearestPostal(callData.coords, callData.source)
        if postal then
            if callData.location and callData.location ~= "" then
                callData.location = string.format(Config.Messages.LocationFormat, callData.location, postal)
            else
                callData.location = "Postal " .. postal
            end
        end
    end
    
    -- Determine caller name
    local callerName = "Anonymous Caller"
    if not isAnonymous then
        if isNPCReport then
            callerName = "Anonymous Witness"
        else
            callerName = callData.playerName
        end
    end
    
    -- Prepare data for CAD API
    local postData = {
        callType = "911 - " .. callData.description,
        location = callData.location,
        callerName = callerName,
        communityId = Config.CommunityID,
        -- Add metadata
        metadata = {
            isNPCReport = isNPCReport,
            isAnonymous = isAnonymous,
            reportType = callData.reportType,
            timestamp = os.time()
        }
    }
    
    -- Add caller info for non-anonymous calls
    if not isAnonymous and not isNPCReport then
        postData.callerInfo = {
            playerId = callData.source,
            playerName = callData.playerName
        }
    end
    
    local jsonData = json.encode(postData)
    
    if Config.EnableDebug then
        print("^3[CAD-911] Endpoint: " .. Config.CADEndpoint .. "^0")
        print("^3[CAD-911] JSON Data: " .. jsonData .. "^0")
    end
    
    -- Make HTTP request to CAD
    PerformHttpRequest(Config.CADEndpoint, function(statusCode, response, headers)
        local success = statusCode == 200 or statusCode == 201
        
        if Config.EnableDebug then
            print("^3[CAD-911] Response Status: " .. tostring(statusCode) .. "^0")
            if response and response ~= "" then
                print("^3[CAD-911] Response: " .. tostring(response) .. "^0")
            end
        end
        
        if success then
            local reportTypeStr = isAnonymous and "Anonymous Call" or (isNPCReport and "NPC Report" or "Player Call")
            print(string.format("^2[CAD-911] %s sent successfully^0", reportTypeStr))
            
            -- Parse response for call ID
            if response then
                local responseData = json.decode(response)
                if responseData and responseData._id then
                    print(string.format("^2[CAD-911] Call ID: %s^0", responseData._id))
                end
            end
            
            -- Send to Discord if enabled
            if Config.LogToDiscord and Config.DiscordWebhook ~= "" then
                SendToDiscord(callData, isNPCReport, isAnonymous)
            end
        else
            print(string.format("^1[CAD-911] Failed to send call. Status: %d^0", statusCode or 0))
            
            -- Detailed error reporting
            if statusCode == 400 then
                print("^1[CAD-911] Error 400: Bad Request - Check data format^0")
            elseif statusCode == 401 then
                print("^1[CAD-911] Error 401: Unauthorized - Check API key^0")
            elseif statusCode == 404 then
                print("^1[CAD-911] Error 404: Endpoint not found^0")
            elseif statusCode == 500 then
                print("^1[CAD-911] Error 500: CAD server error^0")
            elseif statusCode == 0 or statusCode == nil then
                print("^1[CAD-911] Connection failed - CAD may be offline^0")
            end
        end
        
        -- Notify the player (v2.2.0 FIX: Send response back to client)
        if callData.source then
            TriggerClientEvent('cad:911CallResponse', callData.source, success, callData, isNPCReport, isAnonymous)
        end
        
        -- Forward to CDE Duty System (always, even if CAD is offline)
        ForwardToOnDutyUnits(callData, isNPCReport, isAnonymous)
        
        -- Also notify emergency services through framework (backup method)
        if success and Config.NotifyEmergencyServices then
            NotifyEmergencyServices(callData, isNPCReport, isAnonymous)
        end
    end, 'POST', jsonData, {
        ['Content-Type'] = 'application/json',
        ['Accept'] = 'application/json',
        ['X-API-Key'] = Config.APIKey
    })
end

-- ========================================
-- EVENT HANDLERS
-- ========================================

-- Handle regular 911 call from client (v2.2.0 FIX: Added source parameter)
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
    SendToCAD(data, false, false)
end)

-- Handle anonymous 911 call from client
RegisterNetEvent('cad:sendAnonymous911Call')
AddEventHandler('cad:sendAnonymous911Call', function(data)
    local source = source
    
    -- Add source for response
    data.source = source
    
    -- Log to console (don't log player name for anonymity)
    print(string.format("^3[CAD-911] Anonymous tip received: %s at %s^0", 
        data.description, 
        data.location
    ))
    
    -- Send to CAD as anonymous
    SendToCAD(data, false, true)
end)

-- Handle NPC 911 report from client (v2.2.0: IMPROVED LEO CHECK)
RegisterNetEvent('cad:sendNPC911Call')
AddEventHandler('cad:sendNPC911Call', function(data)
    local source = source
    
    -- Validate that NPCs are enabled
    if not Config.NPCReports.Enabled then
        return
    end
    
    -- DOUBLE-CHECK ON SERVER SIDE - Block if player is LEO (v2.2.0 IMPROVED)
    if GetResourceState('CDE_Duty') == 'started' then
        local success, isLEO = pcall(function()
            return exports['CDE_Duty']:IsPlayerOnDutyLEO(source)
        end)
        
        if success and isLEO then
            if Config.EnableDebug then
                print(string.format("^3[CAD-911] Blocked NPC report from on-duty LEO: %s^0", GetPlayerName(source)))
            end
            return
        end
    end
    
    -- Add source for response
    data.source = source
    
    -- Get character name
    data.playerName = "Anonymous Witness"
    
    -- Log to console
    print(string.format("^3[CAD-911] NPC Report - %s at %s^0", 
        data.description, 
        data.location
    ))
    
    -- Send to CAD as NPC report
    SendToCAD(data, true, false)
end)

-- ========================================
-- EMERGENCY SERVICES NOTIFICATION
-- ========================================

function NotifyEmergencyServices(callData, isNPCReport, isAnonymous)
    -- Only notify if we have a framework
    if not (Config.Framework.ESX or Config.Framework.QBCore) then
        return
    end
    
    local players = GetPlayers()
    
    -- Prepare prefix based on call type
    local prefix = ""
    local color = {255, 0, 0}
    
    if isAnonymous then
        prefix = "📞 ANONYMOUS TIP"
        color = {128, 128, 128} -- Gray
    elseif isNPCReport then
        if callData.reportType then
            if callData.reportType == "Gunshots" then
                prefix = "🔫 911 SHOTS FIRED"
                color = {255, 0, 0} -- Red
            elseif callData.reportType == "Speeding" or callData.reportType == "SpeedCamera" then
                prefix = "🚗 911 SPEEDING"
                color = {255, 255, 0} -- Yellow
            elseif callData.reportType == "Accident" then
                prefix = "💥 911 ACCIDENT"
                color = {255, 165, 0} -- Orange
            elseif callData.reportType == "Fighting" then
                prefix = "👊 911 FIGHT"
                color = {255, 100, 0} -- Orange-red
            elseif callData.reportType == "Explosion" then
                prefix = "💣 911 EXPLOSION"
                color = {255, 0, 0} -- Red
            elseif callData.reportType == "Brandishing" then
                prefix = "🔫 911 ARMED PERSON"
                color = {255, 165, 0} -- Orange
            elseif callData.reportType == "CCTV" then
                if callData.subType == "Brandishing" then
                    prefix = "📹🔫 CCTV ARMED PERSON"
                else
                    prefix = "📹 911 CCTV ALERT"
                end
                color = {0, 255, 0} -- Green
            else
                prefix = "👁️ 911 WITNESS"
                color = {255, 165, 0} -- Orange
            end
        else
            prefix = "👁️ 911 WITNESS"
            color = {255, 165, 0} -- Orange
        end
    else
        prefix = "🚨 911 DISPATCH"
        color = {255, 0, 0} -- Red
    end
    
    -- Framework-based notification (backup for non-duty players)
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
            
            -- Check EMS jobs if not police
            if not isEmergency then
                for _, job in ipairs(Config.EmergencyJobs.EMS) do
                    if playerJob == job then
                        isEmergency = true
                        break
                    end
                end
            end
            
            -- Send notification to emergency services
            if isEmergency then
                TriggerClientEvent('chat:addMessage', playerId, {
                    color = color,
                    multiline = true,
                    args = {prefix, callData.description .. " | 📍 " .. callData.location}
                })
            end
        end
    end
end

-- ========================================
-- DISCORD INTEGRATION
-- ========================================

function SendToDiscord(callData, isNPCReport, isAnonymous)
    if not Config.LogToDiscord or Config.DiscordWebhook == "" then return end
    
    local title = "🚨 911 Emergency Call"
    local color = Config.DiscordSettings.Colors.Player
    
    -- Set title and color based on type
    if isAnonymous then
        title = "📞 Anonymous 911 Tip"
        color = Config.DiscordSettings.Colors.Anonymous
    elseif isNPCReport then
        if callData.reportType then
            if callData.reportType == "Gunshots" then
                title = "🔫 911 Shots Fired Report"
                color = Config.DiscordSettings.Colors.Gunshots
            elseif callData.reportType == "Speeding" or callData.reportType == "SpeedCamera" then
                title = "🚗 911 Speeding Report" .. (callData.reportType == "SpeedCamera" and " (Speed Camera)" or "")
                color = Config.DiscordSettings.Colors.SpeedCamera or Config.DiscordSettings.Colors.Speeding
            elseif callData.reportType == "Accident" then
                title = "💥 911 Accident Report"
                color = Config.DiscordSettings.Colors.Accident
            elseif callData.reportType == "Fighting" then
                title = "👊 911 Fight Report"
                color = Config.DiscordSettings.Colors.Fighting
            elseif callData.reportType == "Explosion" then
                title = "💣 911 Explosion Report"
                color = Config.DiscordSettings.Colors.Explosion
            elseif callData.reportType == "Brandishing" then
                title = "🔫 911 Armed Person Report"
                color = Config.DiscordSettings.Colors.Brandishing
            elseif callData.reportType == "CCTV" then
                title = "📹 CCTV Alert"
                color = Config.DiscordSettings.Colors.CCTV
            end
        else
            title = "👁️ 911 Witness Report"
            color = Config.DiscordSettings.Colors.NPC
        end
    end
    
    local embed = {
        {
            title = title,
            description = "**Description:** " .. callData.description .. "\n**Location:** " .. callData.location,
            color = color,
            fields = {
                {
                    name = "Caller",
                    value = callData.playerName or "Anonymous",
                    inline = true
                },
                {
                    name = "Type",
                    value = isAnonymous and "Anonymous" or (isNPCReport and "NPC Report" or "Player Call"),
                    inline = true
                },
                {
                    name = "Report Type",
                    value = callData.reportType or "General",
                    inline = true
                }
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = {
                text = "CAD-911 System"
            }
        }
    }
    
    PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, 'POST', json.encode({
        username = Config.DiscordSettings.Username,
        avatar_url = Config.DiscordSettings.Avatar ~= "" and Config.DiscordSettings.Avatar or nil,
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

-- ========================================
-- ADMIN COMMANDS
-- ========================================

RegisterCommand('testcad', function(source, args)
    if source ~= 0 then return end
    
    print("^3[CAD-911] ========================================^0")
    print("^3[CAD-911] Testing CAD Connection^0")
    print("^3[CAD-911] ========================================^0")
    
    -- Check dependencies
    print("^2[CAD-911] Checking dependencies...^0")
    
    if not Config then
        print("^1[CAD-911] ✗ Config not loaded!^0")
        return
    end
    
    print("^2[CAD-911]   ✓ Config loaded^0")
    print("^2[CAD-911] Settings:^0")
    print("^2[CAD-911]   • CAD Endpoint: " .. Config.CADEndpoint .. "^0")
    print("^2[CAD-911]   • Community ID: " .. Config.CommunityID .. "^0")
    print("^2[CAD-911]   • API Key: " .. (Config.APIKey ~= "" and "SET" or "MISSING") .. "^0")
    
    -- Check CDE_Duty integration
    if GetResourceState('CDE_Duty') == 'started' then
        print("^2[CAD-911] ✓ CDE_Duty integration: Active^0")
        
        if exports['CDE_Duty'] then
            local success, leoUnits = pcall(function() return exports['CDE_Duty']:GetOnDutyLEOUnits() end)
            local success2, fireUnits = pcall(function() return exports['CDE_Duty']:GetOnDutyFireUnits() end)
            
            if success and success2 then
                print(string.format("^2[CAD-911]   On-duty units: %d LEO, %d Fire/EMS^0", 
                    leoUnits and #leoUnits or 0, 
                    fireUnits and #fireUnits or 0))
            end
        end
    else
        print("^3[CAD-911] ⚠ CDE_Duty integration: Not running^0")
    end
    
    local testData = {
        callType = "911 - System Test",
        location = "Server Console Test",
        callerName = "System Administrator",
        communityId = Config.CommunityID,
        metadata = {
            test = true,
            timestamp = os.time()
        }
    }
    
    local jsonData = json.encode(testData)
    print("^3[CAD-911] Test data: " .. jsonData .. "^0")
    
    PerformHttpRequest(Config.CADEndpoint, function(statusCode, response, headers)
        print("^3[CAD-911] ========================================^0")
        print("^3[CAD-911] TEST RESULTS^0")
        print("^3[CAD-911] ========================================^0")
        print("^3[CAD-911] Status Code: " .. tostring(statusCode) .. "^0")
        
        if statusCode == 200 or statusCode == 201 then
            print("^2[CAD-911] ✓ SUCCESS: CAD connection working!^0")
            if response then
                print("^2[CAD-911] Response: " .. response .. "^0")
            end
        else
            print("^1[CAD-911] ✗ FAILED: Connection error^0")
            
            if statusCode == 0 or statusCode == nil then
                print("^1[CAD-911] Cannot reach CAD backend^0")
                print("^1[CAD-911] Possible issues:^0")
                print("^1[CAD-911]   • CAD backend not running^0")
                print("^1[CAD-911]   • Incorrect URL^0")
                print("^1[CAD-911]   • Firewall blocking connection^0")
                print("^1[CAD-911]   • Network issues^0")
            elseif statusCode == 404 then
                print("^1[CAD-911] Endpoint not found^0")
                print("^1[CAD-911] Check if URL is correct: " .. Config.CADEndpoint .. "^0")
            elseif statusCode == 401 or statusCode == 403 then
                print("^1[CAD-911] Authentication failed^0")
                print("^1[CAD-911] Check your API key configuration^0")
            elseif statusCode == 400 then
                print("^1[CAD-911] Bad request - CAD rejected the data format^0")
            elseif statusCode == 500 then
                print("^1[CAD-911] CAD backend server error^0")
            end
            
            if response then
                print("^1[CAD-911] Error details: " .. response .. "^0")
            end
        end
        
        print("^3[CAD-911] ========================================^0")
    end, 'POST', jsonData, {
        ['Content-Type'] = 'application/json',
        ['Accept'] = 'application/json',
        ['X-API-Key'] = Config.APIKey
    })
end, true)

-- Test 911 to duty units
RegisterCommand('test911duty', function(source, args)
    if source ~= 0 then return end
    
    print("^3[CAD-911] Testing 911 to duty integration...^0")
    
    local testCallData = {
        description = "Test emergency call from console",
        location = "Test Location - Postal 123",
        coords = {x = 0, y = 0, z = 0},
        playerName = "Console Test",
        reportType = "TEST",
        isNPC = false,
        isAnonymous = false
    }
    
    ForwardToOnDutyUnits(testCallData, false, false)
    
    print("^2[CAD-911] Test call sent to on-duty units^0")
end, true)

-- Check LEO status command
RegisterCommand('checkleo', function(source, args)
    if source == 0 then
        print("^1[CAD-911] This command must be used in-game^0")
        return
    end
    
    if GetResourceState('CDE_Duty') == 'started' then
        local success, isLEO = pcall(function()
            return exports['CDE_Duty']:IsPlayerOnDutyLEO(source)
        end)
        
        if success then
            print(string.format("^2[CAD-911] %s is %s^0", 
                GetPlayerName(source), 
                isLEO and "ON DUTY LEO" or "NOT on duty LEO"))
            TriggerClientEvent('chat:addMessage', source, {
                args = {"System", "LEO Status: " .. (isLEO and "ON DUTY" or "OFF DUTY")}
            })
        end
    else
        print("^3[CAD-911] CDE_Duty not running^0")
    end
end, false)

-- ========================================
-- STARTUP & VERSION CHECK
-- ========================================

Citizen.CreateThread(function()
    -- Wait for config to load
    while not Config do
        Citizen.Wait(100)
    end
    
    print("^2[CAD-911] ========================================^0")
    print("^2[CAD-911] 911 CAD Integration System v2.2.0^0")
    print("^2[CAD-911] With CDE Duty System Integration^0")
    print("^2[CAD-911] Speed Camera Support & Improved LEO Bypass^0")
    print("^2[CAD-911] ========================================^0")
    print("^2[CAD-911] Initializing...^0")
    
    -- Display active features
    print("^2[CAD-911] Active Features:^0")
    print("^2[CAD-911]   • Player 911 Calls: /" .. Config.Command .. "^0")
    print("^2[CAD-911]   • Anonymous Tips: /" .. Config.AnonymousCommand .. "^0")
    
    if Config.NPCReports.Enabled then
        local activeReports = {}
        if Config.NPCReports.Speeding.Enabled then table.insert(activeReports, "Speeding") end
        if Config.NPCReports.Gunshots.Enabled then table.insert(activeReports, "Gunshots") end
        if Config.NPCReports.Accidents and Config.NPCReports.Accidents.Enabled then table.insert(activeReports, "Accidents") end
        if Config.NPCReports.Fighting and Config.NPCReports.Fighting.Enabled then table.insert(activeReports, "Fighting") end
        if Config.NPCReports.Explosions and Config.NPCReports.Explosions.Enabled then table.insert(activeReports, "Explosions") end
        if Config.NPCReports.Brandishing and Config.NPCReports.Brandishing.Enabled then table.insert(activeReports, "Brandishing") end
        if Config.NPCReports.CCTV and Config.NPCReports.CCTV.Enabled then table.insert(activeReports, "CCTV") end
        
        if #activeReports > 0 then
            print("^2[CAD-911]   • NPC Reports: " .. table.concat(activeReports, ", ") .. "^0")
            print("^2[CAD-911]   • LEO Bypass: Enabled (LEOs won't trigger NPC reports)^0")
        end
    end
    
    if Config.SpeedCameras and Config.SpeedCameras.Enabled then
        print("^2[CAD-911]   • Speed Cameras: Enabled (" .. #Config.SpeedCameras.Locations .. " cameras)^0")
    end
    
    if Config.LogToDiscord then
        print("^2[CAD-911]   • Discord Logging: Enabled^0")
    end
    
    if Config.NotifyEmergencyServices then
        print("^2[CAD-911]   • Emergency Service Notifications: Enabled^0")
    end
    
    -- Wait for other resources
    Citizen.Wait(3000)
    
    -- Check dependencies
    print("^2[CAD-911] Checking dependencies...^0")
    
    local postalState = GetResourceState('nearest-postal')
    if postalState == 'started' then
        print("^2[CAD-911]   ✓ nearest-postal: Ready^0")
    else
        print("^1[CAD-911]   ✗ nearest-postal: Not found (postal codes disabled)^0")
    end
    
    -- Check CDE_Duty integration
    local dutyState = GetResourceState('CDE_Duty')
    if dutyState == 'started' then
        print("^2[CAD-911]   ✓ CDE_Duty: Ready (duty system integrated)^0")
        print("^2[CAD-911]   ✓ LEO Detection: Active^0")
    else
        print("^3[CAD-911]   ⚠ CDE_Duty: Not running (framework fallback active)^0")
        print("^3[CAD-911]   ⚠ LEO Detection: Disabled^0")
    end
    
    -- Admin commands reminder
    if Config.EnableAdminCommands then
        print("^2[CAD-911] Admin Commands Available:^0")
        print("^2[CAD-911]   • testcad - Test CAD connection^0")
        print("^2[CAD-911]   • test911duty - Test duty integration^0")
        print("^2[CAD-911]   • checkleo - Check player LEO status^0")
    end
    
    print("^2[CAD-911] ========================================^0")
    print("^2[CAD-911] System Ready!^0")
    print("^2[CAD-911] ========================================^0")
    
    -- Auto-test on startup if debug enabled
    if Config.EnableDebug then
        Citizen.Wait(5000)
        print("^3[CAD-911] Running startup connection test...^0")
        ExecuteCommand('testcad')
    end
end)
