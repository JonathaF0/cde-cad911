#!/bin/bash
# FiveM CAD-911 Resource Generator
# This script creates all the files for the CAD-911 integration

echo "========================================="
echo "FiveM CAD-911 Resource Generator"
echo "========================================="
echo ""

# Create main directory
RESOURCE_NAME="cad-911"
echo "Creating $RESOURCE_NAME resource..."
mkdir -p "$RESOURCE_NAME/client"
mkdir -p "$RESOURCE_NAME/server"

cd "$RESOURCE_NAME"

# Create fxmanifest.lua
cat > fxmanifest.lua << 'EOF'
fx_version 'cerulean'
game 'gta5'

author 'CAD System Integration'
description '911 Emergency Call Integration with CAD System'
version '1.0.0'
repository 'https://github.com/yourusername/cad-911'

-- Requires nearest-postal for location services
dependency 'nearest-postal'

client_scripts {
    'config.lua',
    'client/main.lua'
}

server_scripts {
    'config.lua',
    'server/main.lua'
}

shared_script 'config.lua'
EOF

# Create config.lua
cat > config.lua << 'EOF'
Config = {}

-- ========================================
-- CAD SYSTEM CONFIGURATION (REQUIRED)
-- ========================================
-- You MUST update these values with your CAD system details
Config.CADEndpoint = "http://localhost:3000/api/civilian/911-call" -- Your CAD backend URL
Config.CommunityID = "YOUR_COMMUNITY_ID_HERE" -- Your community ID from CAD system

-- ========================================
-- COMMAND CONFIGURATION
-- ========================================
Config.Command = "911" -- Command players use (without the /)
Config.CooldownSeconds = 30 -- Cooldown between 911 calls per player

-- ========================================
-- MESSAGES
-- ========================================
Config.Messages = {
    NoArgs = "~r~Please describe your emergency. Usage: /911 [description]",
    Cooldown = "~r~You must wait %d seconds before making another 911 call.",
    Sending = "~y~Sending your 911 call...",
    Success = "~g~911 call sent successfully. Help is on the way!",
    Failed = "~r~Failed to send 911 call. Please try again.",
    LocationFormat = "%s, Postal %s", -- Format: Street Name, Postal 123
}

-- ========================================
-- LOCATION SETTINGS
-- ========================================
Config.UsePostal = true -- Use postal codes (requires nearest-postal)
Config.UseStreetNames = true -- Include street names in location
Config.UseCoordinates = false -- Include exact coordinates (for admin purposes)

-- ========================================
-- VISUAL SETTINGS
-- ========================================
Config.BlipSettings = {
    Enabled = true, -- Show blip where 911 call was made
    Sprite = 280, -- Blip icon (280 = handcuffs)
    Color = 1, -- Blip color (1 = red)
    Scale = 1.0, -- Blip size
    Duration = 60, -- Seconds to show blip
    Text = "911 Call" -- Blip label
}

-- ========================================
-- ADVANCED FEATURES
-- ========================================
Config.NotifyEmergencyServices = false -- Notify online police/ems (requires job system)
Config.EnableAdminCommands = true -- Enable admin commands for testing
Config.LogToDiscord = false -- Enable Discord webhook logging
Config.DiscordWebhook = "" -- Discord webhook URL (if LogToDiscord is true)

-- ========================================
-- FRAMEWORK CONFIGURATION
-- ========================================
-- Set your framework (only one should be true)
Config.Framework = {
    Standalone = true, -- No framework, just FiveM
    ESX = false, -- ESX Framework
    QBCore = false, -- QB-Core Framework
}

-- ========================================
-- EMERGENCY JOBS (if NotifyEmergencyServices is true)
-- ========================================
Config.EmergencyJobs = {
    Police = {"police", "sheriff", "trooper"},
    EMS = {"ambulance", "ems", "fire"},
}
EOF

# Create client/main.lua
cat > client/main.lua << 'EOF'
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
EOF

# Create server/main.lua
cat > server/main.lua << 'EOF'
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
EOF

# Create README.md
cat > README.md << 'EOF'
# 🚨 FiveM 911 CAD Integration

A FiveM resource that integrates 911 emergency calls with your CAD (Computer Aided Dispatch) system.

## Features

- ✅ **Simple Command** - Players use `/911 [emergency description]`
- ✅ **Automatic Location** - Detects street names and postal codes
- ✅ **CAD Integration** - Sends calls directly to your dispatch system
- ✅ **Anti-Spam** - Configurable cooldown between calls
- ✅ **Visual Feedback** - Notifications and optional map blips
- ✅ **Framework Support** - Works with ESX, QBCore, or standalone
- ✅ **Admin Tools** - Test commands and debugging features

## Prerequisites

1. **[nearest-postal](https://github.com/DevBlocky/nearest-postal)** - Required for postal code detection
2. A working CAD system with the 911 API endpoint

## Installation

1. **Download** this resource
2. **Extract** to your server's `resources` folder
3. **Install nearest-postal** if you haven't already:
   ```bash
   cd resources
   git clone https://github.com/DevBlocky/nearest-postal.git
   ```
4. **Configure** the resource (see Configuration section)
5. **Add to server.cfg**:
   ```cfg
   ensure nearest-postal
   ensure cad-911
   ```
6. **Restart** your server

## Configuration

Edit `config.lua` and update these required settings:

```lua
-- Your CAD system's API endpoint
Config.CADEndpoint = "http://your-cad-server:3000/api/civilian/911-call"

-- Your community ID from the CAD system
Config.CommunityID = "your_community_id_here"
```

### Optional Settings

- `Config.Command` - Change the command (default: "911")
- `Config.CooldownSeconds` - Time between calls (default: 30)
- `Config.UsePostal` - Enable/disable postal codes
- `Config.UseStreetNames` - Enable/disable street names
- `Config.BlipSettings` - Configure map blips

## Usage

### For Players

```
/911 [description of emergency]
```

Examples:
- `/911 There's a car accident at Legion Square!`
- `/911 Someone is robbing the 24/7 store!`
- `/911 I need medical help, I'm injured!`

### For Admins

**Test CAD Connection** (server console only):
```
test911cad
```

**Test Location Detection** (in-game):
```
/testlocation
```

## API Integration

The resource sends POST requests to your CAD endpoint with this format:

```json
{
    "callType": "911 - [player's description]",
    "location": "Street Name, Postal 123",
    "callerName": "Player Name",
    "communityId": "your_community_id"
}
```

## Framework Support

### ESX
```lua
Config.Framework = {
    Standalone = false,
    ESX = true,
    QBCore = false
}
```

### QBCore
```lua
Config.Framework = {
    Standalone = false,
    ESX = false,
    QBCore = true
}
```

## Troubleshooting

### Calls not appearing in CAD?
1. Check your CAD backend is running
2. Verify the endpoint URL in `config.lua`
3. Use `test911cad` in server console to test connection
4. Check server console for error messages

### Location showing as coordinates?
- Ensure `nearest-postal` is installed and started
- Make sure it's listed before `cad-911` in server.cfg

### "Unknown command" error?
- Verify the resource is started: `ensure cad-911`
- Check server console for startup errors

## Discord Logging

To enable Discord webhook logging:

1. Set `Config.LogToDiscord = true`
2. Add your webhook URL: `Config.DiscordWebhook = "your_webhook_url"`

## Support

For issues or questions:
1. Check the server console for error messages
2. Verify your configuration settings
3. Test the CAD connection with `test911cad`
4. Ensure all dependencies are installed

## License

This resource is provided as-is under the MIT License.

## Credits

- Uses [nearest-postal](https://github.com/DevBlocky/nearest-postal) for postal codes
- Designed for integration with CAD systems

---

Made with ❤️ for the FiveM roleplay community
EOF

# Create LICENSE
cat > LICENSE << 'EOF'
MIT License

Copyright (c) 2024 CAD-911 Integration

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

# Create .gitignore
cat > .gitignore << 'EOF'
# Dependencies
node_modules/

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Logs
*.log

# Config backups
config.lua.backup
config.lua.bak
EOF

# Create version.json for version tracking
cat > version.json << 'EOF'
{
    "version": "1.0.0",
    "name": "CAD-911 Integration",
    "description": "FiveM 911 Emergency Call Integration with CAD Systems",
    "author": "CAD System",
    "repository": "https://github.com/yourusername/cad-911",
    "changelog": {
        "1.0.0": [
            "Initial release",
            "Basic 911 command functionality",
            "Location detection with nearest-postal",
            "CAD system integration",
            "Framework support (ESX, QBCore, Standalone)",
            "Admin commands for testing",
            "Discord webhook support"
        ]
    }
}
EOF

# Return to parent directory
cd ..

echo ""
echo "========================================="
echo "✅ CAD-911 Resource Generated!"
echo "========================================="
echo ""
echo "📁 Created: $RESOURCE_NAME/"
echo ""
echo "📝 Next Steps:"
echo "1. Edit $RESOURCE_NAME/config.lua with your CAD settings"
echo "2. Install nearest-postal if not already installed"
echo "3. Add to server.cfg:"
echo "   ensure nearest-postal"
echo "   ensure $RESOURCE_NAME"
echo "4. Restart your server"
echo ""
echo "📦 To create a ZIP file:"
echo "   zip -r $RESOURCE_NAME.zip $RESOURCE_NAME/"
echo ""
echo "🚀 To upload to GitHub:"
echo "   cd $RESOURCE_NAME"
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Initial release'"
echo "   git remote add origin https://github.com/yourusername/$RESOURCE_NAME.git"
echo "   git push -u origin main"
echo ""
echo "========================================="
