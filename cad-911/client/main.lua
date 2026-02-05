-- client/main.lua
-- CAD-911 Client Side Script with Advanced NPC Reports
-- Version 2.1.0 - Fixed LEO NPC Report Bypass

local lastCallTime = 0
local lastAnonymousCallTime = 0

-- LEO Status tracking
local isLEO = false
-- Report Modifiers
Config = Config or {}
Config.NPCReports = Config.NPCReports or {}
Config.NPCReports.ReportModifiers = Config.NPCReports.ReportModifiers or {
    TimeBasedChance = { Enabled = false, HighActivityHours = {}, LowActivityHours = {} },
    LocationBasedChance = { Enabled = false, HighReportAreas = {} },
    WeatherBasedChance = { Enabled = false, WeatherModifiers = {} }
}
Config.Messages = Config.Messages or { NPCReports = {} }
-- Initialize cooldown tables for all report types
local npcReportCooldowns = {}
local reportTypes = {'speeding', 'gunshots', 'accident', 'fighting', 'explosion', 'carjacking', 'suspicious', 'disturbance', 'brandishing'}
for _, reportType in ipairs(reportTypes) do
    npcReportCooldowns[reportType] = {}
    npcReportCooldowns[reportType:sub(1,1):upper()..reportType:sub(2)] = {} -- Capitalized version
end

-- Speed Camera System (v2.2.0 - NEW)
local speedCameras = {}
local lastSpeedCameraReport = {}

-- ========================================
-- LEO STATUS TRACKING
-- ========================================

RegisterNetEvent('CDE:SetLEOStatus')
AddEventHandler('CDE:SetLEOStatus', function(status)
    isLEO = status
    if Config.EnableDebug then
        print("^2[CAD-911] LEO status updated: " .. tostring(isLEO) .. "^0")
    end
end)

-- Request LEO status on spawn
AddEventHandler('playerSpawned', function()
    TriggerServerEvent('cad:requestLEOStatus')
end)

-- Request status on resource start and refresh periodically
Citizen.CreateThread(function()
    Wait(1000)
    TriggerServerEvent('cad:requestLEOStatus')
    
    -- Refresh LEO status periodically
    while true do
        Wait(30000) -- Check every 30 seconds
        TriggerServerEvent('cad:requestLEOStatus')
    end
end)

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

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

-- Function to get nearest postal code
local function GetNearestPostal(coords)
    local postal = nil
    
    -- Try multiple export methods for nearest-postal
    local methods = {
        function() return exports['nearest-postal']:get_postal(coords.x, coords.y, coords.z) end,
        function() return exports['nearest-postal']:getPostalCode(coords.x, coords.y, coords.z) end,
        function() return exports['nearest-postal']:nearestPostal(coords.x, coords.y, coords.z) end,
        function() return exports['nearest-postal']:postal(coords.x, coords.y) end,
        function() return exports['nearest-postal']:get_nearest_postal(coords.x, coords.y, coords.z) end,
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
    
    if Config.UseStreetNames then
        local streetName = GetStreetNames(coords)
        if streetName and streetName ~= "" then
            location = streetName
        end
    end
    
    if Config.UsePostal then
        local postal = GetNearestPostal(coords)
        if postal then
            if location ~= "" then
                location = string.format(Config.Messages.LocationFormat, location, postal)
            else
                location = "Postal " .. postal
            end
        elseif location == "" then
            location = "Location Unknown"
        end
    end
    
    if Config.UseCoordinates then
        local coordStr = string.format("(%.1f, %.1f)", coords.x, coords.y)
        if location ~= "" then
            location = location .. " " .. coordStr
        else
            location = coordStr
        end
    end
    
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

-- ========================================
-- NPC REPORT FUNCTIONS
-- ========================================

-- Function to check if player is emergency services - IMPROVED LEO CHECK (v2.2.0)
local function IsPlayerEmergencyServices(playerId)
    -- PRIORITY: Check CDE Duty LEO status first (MOST RELIABLE)
    if isLEO then
        if Config.EnableDebug then
            print("^2[CAD-911] LEO bypass triggered (CDE Duty status)^0")
        end
        return true
    end
    
    if not Config.BlipSettings.BlipRadius.EmergencyBypass then
        return false
    end
    
    -- Fallback to vehicle check
    local ped = GetPlayerPed(playerId)
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        if IsEmergencyVehicle(vehicle) then
            if Config.EnableDebug then
                print("^2[CAD-911] LEO bypass triggered (emergency vehicle)^0")
            end
            return true
        end
    end
    
    return false
end

-- IMPROVED: Check if player should be excluded from NPC reports (v2.2.0)
local function ShouldExcludeFromNPCReports(playerId)
    -- PRIMARY CHECK: CDE Duty LEO status (most reliable method)
    if isLEO then
        if Config.EnableDebug then
            print("^2[CAD-911] NPC report blocked: LEO bypass active (CDE Duty status)^0")
        end
        return true
    end
    
    -- SECONDARY CHECK: Emergency vehicle
    local ped = GetPlayerPed(playerId)
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        if IsEmergencyVehicle(vehicle) then
            if Config.EnableDebug then
                print("^2[CAD-911] NPC report blocked: LEO bypass active (emergency vehicle)^0")
            end
            return true
        end
    end
    
    return false
end

-- ========================================
-- NPC REPORT FUNCTIONS
-- ========================================

-- Function to check if vehicle is emergency vehicle
local function IsEmergencyVehicle(vehicle)
    if not Config.NPCReports.WhitelistEmergencyVehicles then
        return false
    end
    
    local model = GetEntityModel(vehicle)
    if Config.NPCReports.EmergencyVehicleModels[model] then
        return true
    end
    
    -- Also check vehicle class 18 (emergency)
    local vehicleClass = GetVehicleClass(vehicle)
    if vehicleClass == 18 then
        return true
    end
    
    -- Check for sirens
    if IsVehicleSirenOn(vehicle) then
        return true
    end
    
    return false
end



-- Function to check if position is in safe zone
local function IsInSafeZone(coords)
    if not Config.NPCReports.DisableInSafeZones then
        return false
    end
    
    for _, zone in ipairs(Config.NPCReports.SafeZones) do
        local distance = #(coords - zone.coords)
        if distance <= zone.radius then
            if Config.EnableDebug then
                print("^3[NPC] In safe zone: " .. zone.name .. "^0")
            end
            return true
        end
    end
    
    return false
end

-- Function to check if area is on cooldown
local function IsAreaOnCooldown(coords, reportType)
    local currentTime = GetGameTimer()
    reportType = reportType:lower()
    
    if not npcReportCooldowns[reportType] then
        npcReportCooldowns[reportType] = {}
    end
    
    local cooldownList = npcReportCooldowns[reportType]
    local cooldownTime = 60 -- Default cooldown
    
    -- Get specific cooldown time for report type
    if Config.NPCReports[reportType:sub(1,1):upper()..reportType:sub(2)] then
        cooldownTime = Config.NPCReports[reportType:sub(1,1):upper()..reportType:sub(2)].Cooldown or 60
    end
    
    for i = #cooldownList, 1, -1 do
        local entry = cooldownList[i]
        local timePassed = (currentTime - entry.time) / 1000
        
        if timePassed > cooldownTime then
            table.remove(cooldownList, i)
        else
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
    reportType = reportType:lower()
    
    if not npcReportCooldowns[reportType] then
        npcReportCooldowns[reportType] = {}
    end
    
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
                if GetPedType(ped) == 4 or GetPedType(ped) == 5 then
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

-- Function to get time-based chance modifier
local function GetTimeModifier()
    if not Config.NPCReports.ReportModifiers.TimeBasedChance.Enabled then
        return 1.0
    end
    
    local hour = GetClockHours()
    
    -- Check high activity hours
    for _, timeRange in ipairs(Config.NPCReports.ReportModifiers.TimeBasedChance.HighActivityHours) do
        if hour >= timeRange.start and hour < timeRange.stop then
            return timeRange.multiplier
        end
    end
    
    -- Check low activity hours
    for _, timeRange in ipairs(Config.NPCReports.ReportModifiers.TimeBasedChance.LowActivityHours or {}) do
        if hour >= timeRange.start and hour < timeRange.stop then
            return timeRange.multiplier
        end
    end
    
    return 1.0
end

-- Function to get location-based chance modifier
local function GetLocationModifier(coords)
    if not Config.NPCReports.ReportModifiers.LocationBasedChance.Enabled then
        return 1.0
    end
    
    for _, area in ipairs(Config.NPCReports.ReportModifiers.LocationBasedChance.HighReportAreas) do
        local distance = #(coords - area.coords)
        if distance <= area.radius then
            return area.multiplier
        end
    end
    
    return 1.0
end

-- Function to get weather modifier (if enabled)
local function GetWeatherModifier()
    if not Config.NPCReports.ReportModifiers.WeatherBasedChance.Enabled then
        return 1.0
    end
    
    local weather = GetPrevWeatherTypeHashName()
    return Config.NPCReports.ReportModifiers.WeatherBasedChance.WeatherModifiers[weather] or 1.0
end

-- Function to calculate final report chance
local function CalculateReportChance(baseChance, coords)
    local timeModifier = GetTimeModifier()
    local locationModifier = GetLocationModifier(coords)
    local weatherModifier = GetWeatherModifier()
    
    local finalChance = baseChance * timeModifier * locationModifier * weatherModifier
    return math.min(finalChance, 1.0) -- Cap at 100%
end

-- Function to get random NPC message
local function GetRandomNPCMessage(reportType)
    reportType = reportType:sub(1,1):upper() .. reportType:sub(2):lower()
    
    local messages = Config.Messages.NPCReports[reportType]
    if not messages or #messages == 0 then
        return "Emergency situation reported"
    end
    return messages[math.random(#messages)]
end

-- Function to get vehicle description
local function GetVehicleDescription(vehicle)
    local vehicleModel = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    local plateText = GetVehicleNumberPlateText(vehicle)
    local vehicleColor = GetVehicleColor(vehicle)
    
    if vehicleModel == "CARNOTFOUND" then
        vehicleModel = "Unknown Vehicle"
    end
    
    local vehicleClass = GetVehicleClass(vehicle)
    local classNames = {
        [0] = "compact car", [1] = "sedan", [2] = "SUV", [3] = "coupe",
        [4] = "muscle car", [5] = "sports car", [6] = "high-end sports car",
        [7] = "supercar", [8] = "motorcycle", [9] = "off-road vehicle",
        [10] = "industrial vehicle", [11] = "utility vehicle", [12] = "van",
        [13] = "bicycle", [18] = "emergency vehicle", [20] = "commercial truck"
    }
    
    local vehicleType = classNames[vehicleClass] or "vehicle"
    
    local descriptions = {
        string.format("%s %s, plate: %s", vehicleColor, vehicleType, plateText),
        string.format("%s colored %s with plate %s", vehicleColor, vehicleModel, plateText),
        string.format("%s - License: %s", vehicleModel, plateText),
    }
    
    return descriptions[math.random(#descriptions)]
end

-- Helper function to get vehicle color name
function GetVehicleColor(vehicle)
    local colors = {
        [0] = "Black", [1] = "Black", [2] = "Black", [3] = "Silver",
        [4] = "Silver", [5] = "Silver", [27] = "Red", [28] = "Red",
        [38] = "Orange", [42] = "Yellow", [55] = "Green", [64] = "Blue",
        [111] = "White", [112] = "White", [134] = "White"
    }
    
    local primaryColor, secondaryColor = GetVehicleColours(vehicle)
    return colors[primaryColor] or "Unknown Color"
end

-- Main function to send NPC report (UPDATED WITH LEO CHECK)
local function SendNPCReport(coords, reportType, additionalInfo)
    -- CRITICAL: CHECK IF PLAYER IS LEO - DO NOT SEND IF TRUE
    if isLEO then
        if Config.EnableDebug then
            print("^3[NPC] Player is on-duty LEO - skipping NPC report^0")
        end
        return
    end
    
    reportType = reportType:sub(1,1):upper() .. reportType:sub(2):lower()
    
    local location = GetLocationString(coords)
    local description = GetRandomNPCMessage(reportType)
    
    if additionalInfo then
        description = description .. " - " .. additionalInfo
    end
    
    if Config.EnableDebug then
        print("^3[NPC] Sending " .. reportType .. " report: " .. description .. "^0")
    end
    
    TriggerServerEvent('cad:sendNPC911Call', {
        description = description,
        location = location,
        coords = {x = coords.x, y = coords.y, z = coords.z},
        reportType = reportType
    })
    
    AddAreaCooldown(coords, reportType)
end

-- ========================================
-- PLAYER COMMANDS
-- ========================================

-- Main 911 command
RegisterCommand(Config.Command, function(source, args, rawCommand)
    if #args == 0 then
        ShowNotification(Config.Messages.NoArgs)
        return
    end
    
    local currentTime = GetGameTimer()
    local timeSinceLastCall = (currentTime - lastCallTime) / 1000
    
    if timeSinceLastCall < Config.CooldownSeconds then
        local remainingTime = math.ceil(Config.CooldownSeconds - timeSinceLastCall)
        ShowNotification(string.format(Config.Messages.Cooldown, remainingTime))
        return
    end
    
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local location = GetLocationString(coords)
    local description = table.concat(args, " ")
    local playerName = GetPlayerName(PlayerId())
    
    ShowNotification(Config.Messages.Sending)
    
    TriggerServerEvent('cad:send911Call', {
        description = description,
        location = location,
        coords = {x = coords.x, y = coords.y, z = coords.z},
        playerName = playerName
    })
    
    lastCallTime = currentTime
end, false)

-- Anonymous 911 command
RegisterCommand(Config.AnonymousCommand, function(source, args, rawCommand)
    if #args == 0 then
        ShowNotification(Config.Messages.NoArgsAnonymous)
        return
    end
    
    local currentTime = GetGameTimer()
    local timeSinceLastCall = (currentTime - lastAnonymousCallTime) / 1000
    
    if timeSinceLastCall < Config.AnonymousCooldownSeconds then
        local remainingTime = math.ceil(Config.AnonymousCooldownSeconds - timeSinceLastCall)
        ShowNotification(string.format(Config.Messages.AnonymousCooldown, remainingTime))
        return
    end
    
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local location = ""
    
    if Config.UsePostal then
        local postal = GetNearestPostal(coords)
        if postal then
            location = "Near Postal " .. postal
        else
            location = "Unknown Location"
        end
    else
        location = "Somewhere in the city"
    end
    
    local description = table.concat(args, " ")
    
    ShowNotification(Config.Messages.SendingAnonymous)
    
    TriggerServerEvent('cad:sendAnonymous911Call', {
        description = description,
        location = location,
        coords = nil -- No coords for anonymous
    })
    
    lastAnonymousCallTime = currentTime
end, false)

-- ========================================
-- EVENT HANDLERS
-- ========================================

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
        
        -- Create blip if enabled
        if Config.BlipSettings.Enabled and callData.coords and not isAnonymous then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - vector3(callData.coords.x, callData.coords.y, callData.coords.z))
            
            -- Check if player is within radius or is emergency services
            local shouldShowBlip = false
            
            if Config.BlipSettings.BlipRadius.Enabled then
                if distance <= Config.BlipSettings.BlipRadius.Distance then
                    shouldShowBlip = true
                elseif Config.BlipSettings.BlipRadius.EmergencyBypass then
                    -- Check if player is emergency services
                    shouldShowBlip = IsPlayerEmergencyServices(PlayerId())
                end
            else
                shouldShowBlip = true
            end
            
            if shouldShowBlip then
                local blipConfig = Config.BlipSettings
                
                -- Get specific blip config for report type
                if isNPCReport and callData.reportType and Config.BlipSettings.BlipTypes[callData.reportType] then
                    blipConfig = Config.BlipSettings.BlipTypes[callData.reportType]
                elseif isNPCReport and Config.BlipSettings.BlipTypes.NPCReport then
                    blipConfig = Config.BlipSettings.BlipTypes.NPCReport
                end
                
                local blip = AddBlipForCoord(callData.coords.x, callData.coords.y, callData.coords.z)
                SetBlipSprite(blip, blipConfig.Sprite or Config.BlipSettings.Sprite)
                SetBlipColour(blip, blipConfig.Color or Config.BlipSettings.Color)
                SetBlipScale(blip, Config.BlipSettings.Scale)
                SetBlipAsShortRange(blip, true)
                
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(blipConfig.Text or Config.BlipSettings.Text)
                EndTextCommandSetBlipName(blip)
                
                Citizen.SetTimeout(Config.BlipSettings.Duration * 1000, function()
                    RemoveBlip(blip)
                end)
            end
        end
    else
        if not isNPCReport then
            ShowNotification(Config.Messages.Failed)
        end
    end
end)

-- ========================================
-- NPC DETECTION THREADS (ALL UPDATED WITH LEO CHECK)
-- ========================================

-- Speeding Detection Thread
Citizen.CreateThread(function()
    if not Config.NPCReports.Enabled or not Config.NPCReports.Speeding.Enabled then
        return
    end
    
    while true do
        Citizen.Wait(2000)
        
        -- SKIP IF PLAYER IS LEO
        if isLEO then
            Citizen.Wait(3000)
        else
            local playerPed = PlayerPedId()
            
            if IsPedInAnyVehicle(playerPed, false) then
                local vehicle = GetVehiclePedIsIn(playerPed, false)
                
                -- Skip emergency vehicles
                if not IsEmergencyVehicle(vehicle) then
                    if GetPedInVehicleSeat(vehicle, -1) == playerPed then
                        local speed = GetEntitySpeed(vehicle) * 3.6
                        
                        if speed > Config.NPCReports.Speeding.SpeedThreshold then
                            local coords = GetEntityCoords(vehicle)
                            
                            if not IsInSafeZone(coords) and not IsAreaOnCooldown(coords, "speeding") then
                                local nearbyNPCs = CountNearbyNPCs(coords, Config.NPCReports.Speeding.CheckRadius)
                                
                                if nearbyNPCs >= Config.NPCReports.Speeding.MinNPCsNearby then
                                    local baseChance = Config.NPCReports.Speeding.ChanceToReport
                                    
                                    -- Apply speed modifiers
                                    for _, modifier in ipairs(Config.NPCReports.Speeding.SpeedModifiers or {}) do
                                        if speed > modifier.speed then
                                            baseChance = baseChance * modifier.chanceModifier
                                        end
                                    end
                                    
                                    local finalChance = CalculateReportChance(baseChance, coords)
                                    
                                    if math.random() < finalChance then
                                        local vehicleDesc = GetVehicleDescription(vehicle)
                                        local speedContext = ""
                                        
                                        if speed > 200 then
                                            speedContext = "Going insanely fast! "
                                        elseif speed > 150 then
                                            speedContext = "Racing at extreme speeds! "
                                        else
                                            speedContext = "Driving recklessly! "
                                        end
                                        
                                        SendNPCReport(coords, "Speeding", speedContext .. vehicleDesc)
                                    end
                                end
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
        Citizen.Wait(100)
        
        -- SKIP IF PLAYER IS LEO
        if isLEO then
            Citizen.Wait(5000)
        else
            local playerPed = PlayerPedId()
            
            if IsPedShooting(playerPed) then
                local weapon = GetSelectedPedWeapon(playerPed)
                
                if not Config.NPCReports.Gunshots.BlacklistedWeapons[weapon] then
                    local coords = GetEntityCoords(playerPed)
                    
                    if not IsInSafeZone(coords) and not IsAreaOnCooldown(coords, "gunshots") then
                        local nearbyNPCs = CountNearbyNPCs(coords, Config.NPCReports.Gunshots.DetectionRadius)
                        
                        if nearbyNPCs >= Config.NPCReports.Gunshots.MinNPCsNearby then
                            local baseChance = Config.NPCReports.Gunshots.ChanceToReport
                            local finalChance = CalculateReportChance(baseChance, coords)
                            
                            if math.random() < finalChance then
                                local weaponGroup = GetWeapontypeGroup(weapon)
                                local weaponDesc = ""
                                
                                if weaponGroup == 416676503 then
                                    weaponDesc = "Sounds like a pistol"
                                elseif weaponGroup == 860033945 then
                                    weaponDesc = "Sounds like a shotgun"
                                elseif weaponGroup == 970310034 then
                                    weaponDesc = "Sounds like an assault rifle"
                                else
                                    weaponDesc = "Can't tell what kind of gun"
                                end
                                
                                local delay = math.random(
                                    Config.NPCReports.Gunshots.ReportDelay.min,
                                    Config.NPCReports.Gunshots.ReportDelay.max
                                )
                                
                                Citizen.SetTimeout(delay, function()
                                    SendNPCReport(coords, "Gunshots", weaponDesc)
                                end)
                            end
                        end
                    end
                    
                    Citizen.Wait(3000)
                end
            end
        end
    end
end)

-- Vehicle Accident Detection Thread
Citizen.CreateThread(function()
    if not Config.NPCReports.Enabled or not Config.NPCReports.Accidents or not Config.NPCReports.Accidents.Enabled then
        return
    end
    
    local lastVehicleHealth = {}
    
    while true do
        Citizen.Wait(500)
        
        -- SKIP IF PLAYER IS LEO
        if isLEO then
            Citizen.Wait(2000)
        else
            local playerPed = PlayerPedId()
            
            if IsPedInAnyVehicle(playerPed, false) then
                local vehicle = GetVehiclePedIsIn(playerPed, false)
                local vehicleHealth = GetEntityHealth(vehicle)
                local vehicleId = VehToNet(vehicle)
                
                if lastVehicleHealth[vehicleId] then
                    local healthDiff = lastVehicleHealth[vehicleId] - vehicleHealth
                    
                    if healthDiff > Config.NPCReports.Accidents.MinDamage then
                        local coords = GetEntityCoords(vehicle)
                        
                        if not IsInSafeZone(coords) and not IsAreaOnCooldown(coords, "accident") then
                            local nearbyNPCs = CountNearbyNPCs(coords, Config.NPCReports.Accidents.DetectionRadius)
                            
                            if nearbyNPCs >= Config.NPCReports.Accidents.MinNPCsNearby then
                                local baseChance = Config.NPCReports.Accidents.ChanceToReport
                                local finalChance = CalculateReportChance(baseChance, coords)
                                
                                if math.random() < finalChance then
                                    local severity = ""
                                    local thresholds = Config.NPCReports.Accidents.SeverityThresholds
                                    
                                    if healthDiff > thresholds.Major then
                                        severity = "Major collision! "
                                    elseif healthDiff > thresholds.Moderate then
                                        severity = "Bad accident! "
                                    else
                                        severity = "Minor accident. "
                                    end
                                    
                                    local vehicleDesc = GetVehicleDescription(vehicle)
                                    local roll = GetEntityRoll(vehicle)
                                    if math.abs(roll) > 75 then
                                        severity = severity .. "Vehicle overturned! "
                                    end
                                    
                                    local delay = math.random(
                                        Config.NPCReports.Accidents.ReportDelay.min,
                                        Config.NPCReports.Accidents.ReportDelay.max
                                    )
                                    
                                    Citizen.SetTimeout(delay, function()
                                        SendNPCReport(coords, "Accident", severity .. vehicleDesc)
                                    end)
                                end
                            end
                        end
                    end
                end
                
                lastVehicleHealth[vehicleId] = vehicleHealth
            end
        end
    end
end)

-- Fighting Detection Thread
Citizen.CreateThread(function()
    if not Config.NPCReports.Enabled or not Config.NPCReports.Fighting or not Config.NPCReports.Fighting.Enabled then
        return
    end
    
    local lastMeleeTime = 0
    
    while true do
        Citizen.Wait(250)
        
        -- SKIP IF PLAYER IS LEO
        if isLEO then
            Citizen.Wait(2000)
        else
            local playerPed = PlayerPedId()
            
            if IsPedInMeleeCombat(playerPed) then
                local currentTime = GetGameTimer()
                
                if currentTime - lastMeleeTime > Config.NPCReports.Fighting.CombatDuration then
                    local coords = GetEntityCoords(playerPed)
                    
                    if not IsInSafeZone(coords) and not IsAreaOnCooldown(coords, "fighting") then
                        local nearbyNPCs = CountNearbyNPCs(coords, Config.NPCReports.Fighting.DetectionRadius)
                        
                        if nearbyNPCs >= Config.NPCReports.Fighting.MinNPCsNearby then
                            local baseChance = Config.NPCReports.Fighting.ChanceToReport
                            local finalChance = CalculateReportChance(baseChance, coords)
                            
                            if math.random() < finalChance then
                                local delay = math.random(
                                    Config.NPCReports.Fighting.ReportDelay.min,
                                    Config.NPCReports.Fighting.ReportDelay.max
                                )
                                
                                Citizen.SetTimeout(delay, function()
                                    SendNPCReport(coords, "Fighting")
                                end)
                                
                                lastMeleeTime = currentTime
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Explosion Detection Thread
Citizen.CreateThread(function()
    if not Config.NPCReports.Enabled or not Config.NPCReports.Explosions or not Config.NPCReports.Explosions.Enabled then
        return
    end
    
    while true do
        Citizen.Wait(0)
        
        -- SKIP IF PLAYER IS LEO
        if isLEO then
            Citizen.Wait(5000)
        else
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            local explosionDetected = false
            
            for i = 0, 40 do
                local isExplosion, expCoords = IsExplosionInSphere(i, coords.x, coords.y, coords.z, 100.0)
                if isExplosion then
                    explosionDetected = true
                    coords = expCoords
                    break
                end
            end
            
            if explosionDetected then
                if not IsInSafeZone(coords) and not IsAreaOnCooldown(coords, "explosion") then
                    local nearbyNPCs = CountNearbyNPCs(coords, Config.NPCReports.Explosions.DetectionRadius)
                    
                    if nearbyNPCs >= Config.NPCReports.Explosions.MinNPCsNearby then
                        local baseChance = Config.NPCReports.Explosions.ChanceToReport
                        local finalChance = CalculateReportChance(baseChance, coords)
                        
                        if math.random() < finalChance then
                            local delay = math.random(
                                Config.NPCReports.Explosions.ReportDelay.min,
                                Config.NPCReports.Explosions.ReportDelay.max
                            )
                            
                            Citizen.SetTimeout(delay, function()
                                SendNPCReport(coords, "Explosion")
                            end)
                        end
                    end
                end
                
                Citizen.Wait(5000)
            end
        end
    end
end)

-- Brandishing Detection Thread
Citizen.CreateThread(function()
    if not Config.NPCReports.Enabled or not Config.NPCReports.Brandishing or not Config.NPCReports.Brandishing.Enabled then
        return
    end
    
    local brandishStartTime = nil
    local lastBrandishReport = 0
    
    while true do
        Citizen.Wait(500)
        
        -- SKIP IF PLAYER IS LEO
        if isLEO then
            Citizen.Wait(2000)
            brandishStartTime = nil
        else
            local playerPed = PlayerPedId()
            local weapon = GetSelectedPedWeapon(playerPed)
            
            if weapon ~= `WEAPON_UNARMED` and not Config.NPCReports.Brandishing.IgnoredWeapons[weapon] then
                if not IsPedInAnyVehicle(playerPed, false) then
                    if not brandishStartTime then
                        brandishStartTime = GetGameTimer()
                    end
                    
                    if GetGameTimer() - brandishStartTime >= Config.NPCReports.Brandishing.MinBrandishTime then
                        if not IsPedShooting(playerPed) then
                            local coords = GetEntityCoords(playerPed)
                            
                            if GetGameTimer() - lastBrandishReport > (Config.NPCReports.Brandishing.Cooldown * 1000) then
                                if not IsInSafeZone(coords) and not IsAreaOnCooldown(coords, "brandishing") then
                                    local nearbyNPCs = CountNearbyNPCs(coords, Config.NPCReports.Brandishing.DetectionRadius)
                                    
                                    if nearbyNPCs >= Config.NPCReports.Brandishing.MinNPCsNearby then
                                        local baseChance = Config.NPCReports.Brandishing.ChanceToReport
                                        local finalChance = CalculateReportChance(baseChance, coords)
                                        
                                        if math.random() < finalChance then
                                            local weaponGroup = GetWeapontypeGroup(weapon)
                                            local weaponDesc = ""
                                            
                                            if weaponGroup == 416676503 then
                                                weaponDesc = "Suspect has a handgun"
                                            elseif weaponGroup == 860033945 then
                                                weaponDesc = "Suspect has a shotgun"
                                            elseif weaponGroup == 970310034 then
                                                weaponDesc = "Suspect has an assault rifle"
                                            elseif weaponGroup == 1159398588 then
                                                weaponDesc = "Suspect has an SMG"
                                            elseif weaponGroup == 3082541095 then
                                                weaponDesc = "Suspect has a sniper rifle"
                                            elseif weaponGroup == 2725924767 then
                                                weaponDesc = "Suspect has a heavy weapon"
                                            elseif weaponGroup == 3566412244 then
                                                weaponDesc = "Suspect has a melee weapon"
                                            else
                                                weaponDesc = "Suspect is armed"
                                            end
                                            
                                            local delay = math.random(
                                                Config.NPCReports.Brandishing.ReportDelay.min,
                                                Config.NPCReports.Brandishing.ReportDelay.max
                                            )
                                            
                                            if Config.EnableDebug then
                                                print("^3[NPC] Brandishing detected: " .. weaponDesc .. "^0")
                                            end
                                            
                                            Citizen.SetTimeout(delay, function()
                                                SendNPCReport(coords, "Brandishing", weaponDesc)
                                            end)
                                            
                                            lastBrandishReport = GetGameTimer()
                                            AddAreaCooldown(coords, "brandishing")
                                        end
                                    end
                                end
                            end
                        end
                    end
                else
                    brandishStartTime = nil
                end
            else
                brandishStartTime = nil
            end
        end
    end
end)

-- ========================================
-- CCTV CAMERA DETECTION SYSTEM
-- ========================================

local function GetNearestCCTV(coords)
    if not Config.NPCReports.CCTV or not Config.NPCReports.CCTV.Enabled then
        return nil
    end
    
    for _, camera in ipairs(Config.NPCReports.CCTV.Cameras) do
        local distance = #(coords - camera.coords)
        if distance <= (camera.radius or Config.NPCReports.CCTV.DetectionRadius) then
            return camera
        end
    end
    
    return nil
end

local function SendCCTVReport(camera, crimeType, additionalInfo)
    -- LEO CHECK FOR CCTV
    if isLEO then
        if Config.EnableDebug then
            print("^3[CCTV] Player is on-duty LEO - skipping CCTV report^0")
        end
        return
    end
    
    local messages = Config.Messages.NPCReports.CCTV
    
    if crimeType == "Speeding" and Config.Messages.NPCReports.CCTVSpeeding then
        messages = Config.Messages.NPCReports.CCTVSpeeding
    elseif crimeType == "Gunshots" and Config.Messages.NPCReports.CCTVGunshots then
        messages = Config.Messages.NPCReports.CCTVGunshots
    elseif crimeType == "Fighting" and Config.Messages.NPCReports.CCTVFighting then
        messages = Config.Messages.NPCReports.CCTVFighting
    elseif crimeType == "Theft" and Config.Messages.NPCReports.CCTVTheft then
        messages = Config.Messages.NPCReports.CCTVTheft
    end
    
    local description = messages[math.random(#messages)]
    description = description .. " at " .. camera.name
    
    if additionalInfo then
        description = description .. ". " .. additionalInfo
    end
    
    if Config.EnableDebug then
        print("^3[CCTV] Camera report from " .. camera.name .. ": " .. crimeType .. "^0")
    end
    
    TriggerServerEvent('cad:sendNPC911Call', {
        description = description,
        location = camera.name,
        coords = {x = camera.coords.x, y = camera.coords.y, z = camera.coords.z},
        reportType = "CCTV",
        subType = crimeType
    })
end

-- CCTV Monitoring Thread
Citizen.CreateThread(function()
    if not Config.NPCReports.CCTV or not Config.NPCReports.CCTV.Enabled then
        return
    end
    
    local lastCCTVReport = {}
    
    while true do
        Citizen.Wait(Config.NPCReports.CCTV.CheckInterval or 5000)
        
        -- SKIP IF PLAYER IS LEO
        if isLEO then
            Citizen.Wait(5000)
        else
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            local camera = GetNearestCCTV(coords)
            
            if camera then
                local currentTime = GetGameTimer()
                local cameraKey = camera.name
                
                if not lastCCTVReport[cameraKey] or (currentTime - lastCCTVReport[cameraKey]) > 60000 then
                    
                    if Config.NPCReports.CCTV.DetectSpeeding and IsPedInAnyVehicle(playerPed, false) then
                        local vehicle = GetVehiclePedIsIn(playerPed, false)
                        
                        if not IsEmergencyVehicle(vehicle) and GetPedInVehicleSeat(vehicle, -1) == playerPed then
                            local speed = GetEntitySpeed(vehicle) * 3.6
                            
                            if speed > Config.NPCReports.Speeding.SpeedThreshold then
                                if math.random() < Config.NPCReports.CCTV.ChanceToReport then
                                    local vehicleDesc = GetVehicleDescription(vehicle)
                                    local delay = math.random(
                                        Config.NPCReports.CCTV.ReportDelay.min,
                                        Config.NPCReports.CCTV.ReportDelay.max
                                    )
                                    
                                    Citizen.SetTimeout(delay, function()
                                        SendCCTVReport(camera, "Speeding", vehicleDesc)
                                    end)
                                    
                                    lastCCTVReport[cameraKey] = currentTime
                                end
                            end
                        end
                    end
                    
                    if Config.NPCReports.CCTV.DetectGunshots and IsPedShooting(playerPed) then
                        local weapon = GetSelectedPedWeapon(playerPed)
                        
                        if not Config.NPCReports.Gunshots.BlacklistedWeapons[weapon] then
                            if math.random() < Config.NPCReports.CCTV.ChanceToReport then
                                local delay = math.random(
                                    Config.NPCReports.CCTV.ReportDelay.min,
                                    Config.NPCReports.CCTV.ReportDelay.max
                                )
                                
                                Citizen.SetTimeout(delay, function()
                                    SendCCTVReport(camera, "Gunshots", "Suspect armed and dangerous")
                                end)
                                
                                lastCCTVReport[cameraKey] = currentTime
                            end
                        end
                    end
                    
                    if Config.NPCReports.CCTV.DetectFighting and IsPedInMeleeCombat(playerPed) then
                        if math.random() < Config.NPCReports.CCTV.ChanceToReport then
                            local delay = math.random(
                                Config.NPCReports.CCTV.ReportDelay.min,
                                Config.NPCReports.CCTV.ReportDelay.max
                            )
                            
                            Citizen.SetTimeout(delay, function()
                                SendCCTVReport(camera, "Fighting", "Multiple individuals involved")
                            end)
                            
                            lastCCTVReport[cameraKey] = currentTime
                        end
                    end
                    
                    if Config.NPCReports.CCTV.DetectBrandishing then
                        local weapon = GetSelectedPedWeapon(playerPed)
                        
                        if weapon ~= `WEAPON_UNARMED` and not Config.NPCReports.Brandishing.IgnoredWeapons[weapon] then
                            if not IsPedShooting(playerPed) and not IsPedInAnyVehicle(playerPed, false) then
                                if math.random() < Config.NPCReports.CCTV.ChanceToReport then
                                    local weaponGroup = GetWeapontypeGroup(weapon)
                                    local weaponDesc = ""
                                    
                                    if weaponGroup == 416676503 then
                                        weaponDesc = "Individual has handgun visible"
                                    elseif weaponGroup == 860033945 then
                                        weaponDesc = "Individual carrying shotgun"
                                    elseif weaponGroup == 970310034 then
                                        weaponDesc = "Individual with assault rifle"
                                    elseif weaponGroup == 3566412244 then
                                        weaponDesc = "Individual with melee weapon"
                                    else
                                        weaponDesc = "Individual is visibly armed"
                                    end
                                    
                                    local delay = math.random(
                                        Config.NPCReports.CCTV.ReportDelay.min,
                                        Config.NPCReports.CCTV.ReportDelay.max
                                    )
                                    
                                    Citizen.SetTimeout(delay, function()
                                        local messages = Config.Messages.NPCReports.CCTVBrandishing or Config.Messages.NPCReports.CCTV
                                        local description = messages[math.random(#messages)]
                                        description = description .. " at " .. camera.name .. ". " .. weaponDesc
                                        
                                        TriggerServerEvent('cad:sendNPC911Call', {
                                            description = description,
                                            location = camera.name,
                                            coords = {x = camera.coords.x, y = camera.coords.y, z = camera.coords.z},
                                            reportType = "CCTV",
                                            subType = "Brandishing"
                                        })
                                    end)
                                    
                                    lastCCTVReport[cameraKey] = currentTime
                                end
                            end
                        end
                    end
                    
                    if Config.NPCReports.CCTV.DetectVehicleTheft then
                        local vehicle = GetVehiclePedIsTryingToEnter(playerPed)
                        
                        if vehicle ~= 0 and not IsEmergencyVehicle(vehicle) then
                            local lockStatus = GetVehicleDoorLockStatus(vehicle)
                            
                            if lockStatus >= 2 then
                                if math.random() < Config.NPCReports.CCTV.ChanceToReport then
                                    local vehicleDesc = GetVehicleDescription(vehicle)
                                    local delay = math.random(
                                        Config.NPCReports.CCTV.ReportDelay.min,
                                        Config.NPCReports.CCTV.ReportDelay.max
                                    )
                                    
                                    Citizen.SetTimeout(delay, function()
                                        SendCCTVReport(camera, "Theft", vehicleDesc)
                                    end)
                                    
                                    lastCCTVReport[cameraKey] = currentTime
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ========================================
-- SPEED CAMERA SYSTEM (v2.2.0 - NEW)
-- ========================================

local function InitializeSpeedCameras()
    if Config.SpeedCameras and Config.SpeedCameras.Enabled then
        if Config.SpeedCameras.Locations then
            for i, camera in ipairs(Config.SpeedCameras.Locations) do
                speedCameras[i] = camera
                if Config.EnableDebug then
                    print("^2[CAD-911] Speed camera " .. i .. " initialized at " .. camera.name .. "^0")
                end
            end
        end
        
        -- Start speed camera monitoring thread
        Citizen.CreateThread(function()
            while true do
                Citizen.Wait(500) -- Check every 500ms
                
                if Config.SpeedCameras.Enabled then
                    local playerPed = PlayerPedId()
                    local playerCoords = GetEntityCoords(playerPed)
                    
                    -- Skip if player is LEO (IMPROVED BYPASS - v2.2.0)
                    if not ShouldExcludeFromNPCReports(PlayerId()) then
                        -- Check each camera
                        for camIdx, camera in ipairs(speedCameras) do
                            local distance = #(playerCoords - camera.coords)
                            
                            if distance < camera.radius then
                                -- Player is in camera detection range
                                if IsPedInAnyVehicle(playerPed, false) then
                                    local vehicle = GetVehiclePedIsIn(playerPed, false)
                                    local speed = GetEntitySpeed(vehicle) * 3.6 -- Convert to km/h
                                    
                                    if speed > camera.speedLimit then
                                        local cameraKey = "speedcam_" .. camIdx
                                        local currentTime = os.time()
                                        local lastReport = lastSpeedCameraReport[cameraKey] or 0
                                        
                                        -- Check cooldown
                                        if (currentTime - lastReport) > camera.reportCooldown then
                                            if math.random() < camera.chanceToReport then
                                                local speedOverLimit = speed - camera.speedLimit
                                                local delay = math.random(
                                                    Config.SpeedCameras.ReportDelay.min,
                                                    Config.SpeedCameras.ReportDelay.max
                                                )
                                                
                                                Citizen.SetTimeout(delay, function()
                                                    local vehicleDesc = GetVehicleDescription(vehicle)
                                                    local description = string.format(
                                                        "Automated speed camera recorded vehicle traveling at %.1f km/h in %s zone (%.1f km/h over limit). Vehicle: %s",
                                                        speed,
                                                        camera.name,
                                                        speedOverLimit,
                                                        vehicleDesc
                                                    )
                                                    
                                                    TriggerServerEvent('cad:sendNPC911Call', {
                                                        description = description,
                                                        location = camera.name,
                                                        coords = {x = camera.coords.x, y = camera.coords.y, z = camera.coords.z},
                                                        reportType = "SpeedCamera",
                                                        subType = "Speeding"
                                                    })
                                                    
                                                    if Config.EnableDebug then
                                                        print("^3[CAD-911] Speed camera report: " .. string.format("%.1f", speed) .. " km/h at " .. camera.name .. "^0")
                                                    end
                                                end)
                                                
                                                lastSpeedCameraReport[cameraKey] = currentTime
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end

-- Initialize speed cameras on startup
Citizen.CreateThread(function()
    Wait(2000)
    InitializeSpeedCameras()
end)

-- ========================================
-- CHAT SUGGESTIONS & DEBUG
-- ========================================

Citizen.CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Call 911 for emergency services', {
        { name = "description", help = "Describe your emergency" }
    })
    
    TriggerEvent('chat:addSuggestion', '/' .. Config.AnonymousCommand, 'Send anonymous tip to 911', {
        { name = "description", help = "Describe what you witnessed (your identity will be hidden)" }
    })
end)

-- Debug commands
if Config.EnableDebug then
    RegisterCommand('debugnpc', function()
        print("^2=== NPC REPORTS DEBUG ===^0")
        print("Master Enabled: " .. tostring(Config.NPCReports.Enabled))
        print("LEO Status: " .. tostring(isLEO))
        print("Speeding: " .. tostring(Config.NPCReports.Speeding.Enabled))
        print("Gunshots: " .. tostring(Config.NPCReports.Gunshots.Enabled))
        print("Accidents: " .. tostring(Config.NPCReports.Accidents and Config.NPCReports.Accidents.Enabled))
        print("Fighting: " .. tostring(Config.NPCReports.Fighting and Config.NPCReports.Fighting.Enabled))
        print("Explosions: " .. tostring(Config.NPCReports.Explosions and Config.NPCReports.Explosions.Enabled))
        print("Speed Cameras: " .. tostring(Config.SpeedCameras and Config.SpeedCameras.Enabled))
        
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        
        print("In safe zone: " .. tostring(IsInSafeZone(coords)))
        print("NPCs within 50m: " .. CountNearbyNPCs(coords, 50.0))
        print("Time modifier: " .. GetTimeModifier())
        print("Location modifier: " .. GetLocationModifier(coords))
        
        if IsPedInAnyVehicle(playerPed, false) then
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            local speed = GetEntitySpeed(vehicle) * 3.6
            print("Current speed: " .. string.format("%.1f km/h", speed))
        end
        
        -- Speed camera info (v2.2.0)
        if speedCameras and #speedCameras > 0 then
            print("Speed Cameras Loaded: " .. #speedCameras)
            for i, cam in ipairs(speedCameras) do
                local dist = #(coords - cam.coords)
                print("  Camera " .. i .. ": " .. cam.name .. " (" .. string.format("%.1f", dist) .. "m away)")
            end
        end
    end, false)
    
    TriggerEvent('chat:addSuggestion', '/debugnpc', 'Debug NPC report system')
    
    -- New command for speed cameras (v2.2.0)
    RegisterCommand('testspeedcam', function()
        if speedCameras and #speedCameras > 0 then
            print("^2[CAD-911] Speed Cameras (v2.2.0):^0")
            for i, cam in ipairs(speedCameras) do
                print("  " .. i .. ". " .. cam.name .. " - Limit: " .. cam.speedLimit .. " km/h, Cooldown: " .. cam.reportCooldown .. "s, Chance: " .. (cam.chanceToReport * 100) .. "%")
            end
        else
            print("^1[CAD-911] No speed cameras configured^0")
        end
    end, false)
    
    TriggerEvent('chat:addSuggestion', '/testspeedcam', 'Test speed camera system')
end

-- Admin test commands
if Config.EnableAdminCommands then
    RegisterCommand('testlocation', function()
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local location = GetLocationString(coords)
        
        print("^2[CAD-911] Current location: " .. location .. "^0")
        ShowNotification("~g~Location:~w~ " .. location)
    end, false)
    
    RegisterCommand('testnpcreport', function(source, args)
        local reportType = args[1] or "Gunshots"
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        
        SendNPCReport(coords, reportType, "TEST REPORT")
        print("^2[CAD-911] Sent test " .. reportType .. " report^0")
    end, false)
    
    RegisterCommand('toggleleo', function()
        isLEO = not isLEO
        print("^2[CAD-911] LEO status manually toggled to: " .. tostring(isLEO) .. "^0")
        ShowNotification("~g~LEO Status:~w~ " .. tostring(isLEO))
    end, false)
    
    TriggerEvent('chat:addSuggestion', '/testlocation', 'Test location detection')
    TriggerEvent('chat:addSuggestion', '/testnpcreport', 'Test NPC report', {
        { name = "type", help = "Speeding/Gunshots/Accident/Fighting/Explosion" }
    })
    TriggerEvent('chat:addSuggestion', '/toggleleo', 'Toggle LEO status for testing')
end
