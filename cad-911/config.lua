Config = {}

-- ========================================
-- CAD SYSTEM CONFIGURATION (REQUIRED)
-- ========================================
-- You MUST update these values with your CAD system details
Config.CADEndpoint = "https://cad.tnsrp.com/api/civilian/fivem-911-call" -- Your CAD backend URL
Config.CommunityID = "" -- Your community ID from CAD system

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
Config.EnableAdminCommands = false -- Enable admin commands for testing
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
