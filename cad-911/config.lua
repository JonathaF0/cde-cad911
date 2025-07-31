Config = {}

-- ========================================
-- CAD SYSTEM CONFIGURATION (REQUIRED)
-- ========================================
-- You MUST update these values with your CAD system details
Config.CADEndpoint = "https://cad.yourdomain.com/api/civilian/fivem-911-call" -- Your CAD backend URL
Config.CommunityID = "" -- Your community ID from CAD system

-- ========================================
-- COMMAND CONFIGURATION
-- ========================================
Config.Command = "911" -- Command players use (without the /)
Config.CooldownSeconds = 30 -- Cooldown between 911 calls per player

-- ========================================
-- NPC/LOCAL REPORTS CONFIGURATION
-- ========================================
Config.NPCReports = {
    Enabled = true, -- Master switch for NPC reports
    
    -- Speeding Detection
    Speeding = {
        Enabled = true,
        SpeedThreshold = 150.0, -- Speed in KM/H to trigger report (150 km/h = ~93 mph)
        CheckRadius = 50.0, -- Radius to check for NPCs who might "see" the speeding
        Cooldown = 120, -- Seconds before same area can report speeding again
        ChanceToReport = 0.4, -- 30% chance an NPC will actually call it in
        MinNPCsNearby = 1, -- Minimum NPCs needed to witness for a report
    },
    
    -- Gunshot Detection
    Gunshots = {
        Enabled = true,
        DetectionRadius = 100.0, -- Radius NPCs can "hear" gunshots
        Cooldown = 90, -- Seconds before same area can report gunshots again
        ChanceToReport = 0.8, -- 50% chance of report (gunshots are more serious)
        MinNPCsNearby = 1, -- Minimum NPCs needed to witness
        BlacklistedWeapons = { -- Weapons that won't trigger reports
            [`WEAPON_STUNGUN`] = true,
            [`WEAPON_PETROLCAN`] = true,
            [`WEAPON_FIREEXTINGUISHER`] = true,
            [`WEAPON_SNOWBALL`] = true,
            [`WEAPON_FLARE`] = true,
        }
    },
    
    -- General Settings
    OnlyInCity = false, -- Only report in city areas (more realistic)
    DisableInSafeZones = true, -- Don't report in designated safe zones
    SafeZones = { -- Define safe zones where NPCs won't report
        {coords = vector3(440.2, -983.1, 30.7), radius = 50.0}, -- Mission Row PD
        {coords = vector3(299.2, -584.3, 43.3), radius = 75.0}, -- Pillbox Hospital
        -- Add more safe zones as needed
    }
}

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
    
    -- NPC Report Messages
    NPCReports = {
        Speeding = {
            "Reckless driver going extremely fast",
            "Someone driving like a maniac",
            "Speeding vehicle nearly hit pedestrians",
            "Dangerous driver speeding through traffic"
        },
        Gunshots = {
            "I heard gunshots",
            "Someone is shooting",
            "Multiple gunshots heard",
            "Shots fired in the area"
        }
    }
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
    Text = "911 Call", -- Blip label
    
    -- NPC Report Blip Settings
    NPCReport = {
        Sprite = 161, -- Different sprite for NPC reports
        Color = 3, -- Blue color
        Text = "911 Report (Witness)"
    }
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
