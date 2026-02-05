Config = {}

-- ========================================
-- CAD SYSTEM CONFIGURATION (REQUIRED)
-- ========================================
-- You MUST update these values with your CAD system details
Config.CADEndpoint = "https://cdecad.com/api/civilian/fivem-911-call" -- Your CAD backend URL
Config.CommunityID = "" -- Your community ID from CAD system
Config.APIKey = "get_key_from_CDE_support" -- API key if required by your CAD

-- ========================================
-- COMMAND CONFIGURATION
-- ========================================
Config.Command = "911" -- Command players use (without the /)
Config.CooldownSeconds = 20 -- Cooldown between 911 calls per player
Config.AnonymousCommand = "a911" -- Command for anonymous tips
Config.AnonymousCooldownSeconds = 20 -- Cooldown for anonymous tips

-- ========================================
-- DEBUG & ADMIN SETTINGS
-- ========================================
Config.EnableAdminCommands = true -- Enable admin commands for testing
Config.EnableDebug = false -- Enable debug mode for troubleshooting (set to false for production)

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
    Duration = 100, -- Seconds to show blip
    Text = "911 Call", -- Blip label
    
    -- Blip visibility radius (only show to players within this distance)
    BlipRadius = {
        Enabled = true, -- Enable radius restriction
        Distance = 500.0, -- Only show blips to players within 500 meters
        EmergencyBypass = false, -- Emergency services see all blips regardless of distance
    },
    
    -- Different blip settings for each report type
    BlipTypes = {
        NPCReport = {
            Sprite = 161, -- Information icon
            Color = 3, -- Blue
            Text = "911 Witness Report"
        },
        Speeding = {
            Sprite = 523, -- Racing flag
            Color = 5, -- Yellow
            Text = "Speeding Report"
        },
        SpeedCamera = {
            Sprite = 227, -- Camera icon
            Color = 3, -- Blue
            Text = "Speed Camera Violation"
        },
        Gunshots = {
            Sprite = 156, -- Gun icon
            Color = 1, -- Red
            Text = "Shots Fired"
        },
        Accident = {
            Sprite = 488, -- Vehicle icon
            Color = 47, -- Orange
            Text = "Vehicle Accident"
        },
        Fighting = {
            Sprite = 685, -- Fist icon
            Color = 49, -- Orange-red
            Text = "Fight in Progress"
        },
        Explosion = {
            Sprite = 436, -- Explosion icon
            Color = 1, -- Red
            Text = "Explosion Reported"
        },
        Brandishing = {
            Sprite = 119, -- Weapon icon
            Color = 48, -- Orange
            Text = "Armed Person"
        },
        CCTV = {
            Sprite = 459, -- Camera icon
            Color = 2, -- Green
            Text = "CCTV Alert"
        }
    }
}

-- ========================================
-- SPEED CAMERA SYSTEM (NEW)
-- ========================================
Config.SpeedCameras = {
    Enabled = true, -- Master switch for speed camera system
    ReportDelay = {min = 5000, max = 12000}, -- Delay before camera report sent (ms)
    
    -- Speed Camera Locations on Highways
    Locations = {
        -- Interstate 1 (North-South Highway)
        {
            name = "I-1 North Checkpoint",
            coords = vector3(425.5, -980.2, 29.4),
            speedLimit = 200, -- km/h
            radius = 50.0,
            reportCooldown = 200, -- Seconds between reports
            chanceToReport = 0.85
        },
        {
            name = "I-1 South Checkpoint",
            coords = vector3(200.3, -1240.5, 28.9),
            speedLimit = 200,
            radius = 50.0,
            reportCooldown = 200,
            chanceToReport = 0.85
        },
        
        -- I-9 (East-West Highway)
        {
            name = "I-9 East Checkpoint",
            coords = vector3(1100.4, -560.2, 66.1),
            speedLimit = 200,
            radius = 50.0,
            reportCooldown = 200,
            chanceToReport = 0.85
        },
        {
            name = "I-9 West Checkpoint",
            coords = vector3(800.6, -300.8, 61.5),
            speedLimit = 200,
            radius = 50.0,
            reportCooldown = 200,
            chanceToReport = 0.85
        },
        
        -- Route 68 (Northern Highway)
        {
            name = "Route 68 North Checkpoint",
            coords = vector3(-320.5, 300.2, 86.3),
            speedLimit = 100,
            radius = 45.0,
            reportCooldown = 200,
            chanceToReport = 0.8
        },
        {
            name = "Route 68 South Checkpoint",
            coords = vector3(-150.3, 150.5, 80.7),
            speedLimit = 100,
            radius = 45.0,
            reportCooldown = 200,
            chanceToReport = 0.8
        },
        
        -- Great Ocean Highway (Coastal)
        {
            name = "Ocean Highway East Checkpoint",
            coords = vector3(1200.5, -1450.3, 35.2),
            speedLimit = 100,
            radius = 45.0,
            reportCooldown = 200,
            chanceToReport = 0.8
        },
        {
            name = "Ocean Highway West Checkpoint",
            coords = vector3(800.2, -1600.8, 32.1),
            speedLimit = 100,
            radius = 45.0,
            reportCooldown = 200,
            chanceToReport = 0.8
        },
        
        -- Paleto Freeway
        {
            name = "Paleto Freeway North Checkpoint",
            coords = vector3(-80.4, 1240.5, 175.2),
            speedLimit = 110,
            radius = 48.0,
            reportCooldown = 200,
            chanceToReport = 0.82
        },
        {
            name = "Paleto Freeway South Checkpoint",
            coords = vector3(150.3, 950.2, 165.8),
            speedLimit = 110,
            radius = 48.0,
            reportCooldown = 200,
            chanceToReport = 0.82
        },
        
        -- Senora Freeway (Desert Highway)
        {
            name = "Senora Freeway East Checkpoint",
            coords = vector3(850.5, 450.2, 123.4),
            speedLimit = 130,
            radius = 50.0,
            reportCooldown = 200,
            chanceToReport = 0.85
        },
        {
            name = "Senora Freeway West Checkpoint",
            coords = vector3(600.2, 300.8, 115.6),
            speedLimit = 130,
            radius = 50.0,
            reportCooldown = 200,
            chanceToReport = 0.85
        }
    }
}

-- ========================================
-- NPC/LOCAL REPORTS MASTER CONFIGURATION
-- ========================================
Config.NPCReports = {
    Enabled = false, -- Master switch for ALL NPC reports
    WhitelistEmergencyVehicles = true, -- Whitelist emergency vehicles from NPC reports
    
    -- IMPORTANT: LEO Bypass
    -- LEOs on duty (via CDE_Duty) are ALWAYS excluded from NPC reports
    -- This is the primary bypass mechanism
    
    -- ===== SPEEDING DETECTION =====
    Speeding = {
        Enabled = true,
        SpeedThreshold = 200.0, -- Speed in KM/H to trigger report (100 km/h = ~62 mph)
        CheckRadius = 55.0, -- Radius to check for NPCs who might "see" the speeding
        Cooldown = 180, -- Seconds before same area can report speeding again
        ChanceToReport = 0.45, -- 70% chance an NPC will actually call it in
        MinNPCsNearby = 1, -- Minimum NPCs needed to witness for a report
        
        -- Speed-based chance modifiers
        SpeedModifiers = {
            {speed = 250, chanceModifier = 1.2}, -- +20% chance if over 150 km/h
            {speed = 300, chanceModifier = 1.5}, -- +50% chance if over 200 km/h
        }
    },
    
    -- ===== GUNSHOT DETECTION =====
    Gunshots = {
        Enabled = true,
        DetectionRadius = 150.0, -- Radius NPCs can "hear" gunshots
        Cooldown = 45, -- Seconds before same area can report gunshots again
        ChanceToReport = 0.9, -- 90% chance of report (gunshots are serious)
        MinNPCsNearby = 1, -- Minimum NPCs needed to witness
        ReportDelay = {min = 5000, max = 15000}, -- Delay before reporting (ms)
        
        -- Weapons that won't trigger reports
        BlacklistedWeapons = {
            [`WEAPON_STUNGUN`] = true,
            [`WEAPON_PETROLCAN`] = true,
            [`WEAPON_FIREEXTINGUISHER`] = true,
            [`WEAPON_SNOWBALL`] = true,
            [`WEAPON_FLARE`] = true,
        },
        
        -- Weapon type specific report chances
        WeaponTypeModifiers = {
            Pistol = 0.8,
            SMG = 0.9,
            Shotgun = 0.95,
            AssaultRifle = 1.0,
            Sniper = 0.7,
            Heavy = 1.0
        }
    },
    
    -- ===== VEHICLE ACCIDENT DETECTION =====
    Accidents = {
        Enabled = true,
        MinDamage = 100, -- Minimum health loss to trigger report
        DetectionRadius = 75.0,
        Cooldown = 200,
        ChanceToReport = 0.8,
            MinNPCsNearby = 2,
        ReportDelay = {min = 3000, max = 8000},
        
        -- Damage severity thresholds
        SeverityThresholds = {
            Minor = 100,
            Moderate = 200,
            Major = 300
        }
    },
    
    -- ===== FIGHTING/MELEE DETECTION =====
    Fighting = {
        Enabled = true,
        DetectionRadius = 50.0,
        Cooldown = 90,
        ChanceToReport = 0.4,
        MinNPCsNearby = 1,
        ReportDelay = {min = 5000, max = 10000},
        CombatDuration = 10000 -- Minimum time between reports (ms)
    },
    
    -- ===== EXPLOSION DETECTION =====
    Explosions = {
        Enabled = true,
        DetectionRadius = 200.0,
        Cooldown = 180,
        ChanceToReport = 0.85, -- Almost always reported
        MinNPCsNearby = 1,
        ReportDelay = {min = 1000, max = 3000} -- Quick response to explosions
    },
    
    -- ===== CCTV CAMERA DETECTION =====
    CCTV = {
        Enabled = true,
        CheckInterval = 5000, -- Check every 5 seconds (ms)
        DetectionRadius = 30.0, -- How far cameras can "see"
        ChanceToReport = 0.65, -- 65% chance camera footage leads to report
        ReportDelay = {min = 8000, max = 15000}, -- Delay before "operator" reports
        
        -- Types of crimes CCTV will report
        DetectSpeeding = true,
        DetectGunshots = true,
        DetectFighting = true,
        DetectVehicleTheft = true,
        DetectBrandishing = true, -- Detect weapons drawn
        
        -- CCTV Camera Locations (add your own)
        Cameras = {
            -- Banks
            {coords = vector3(149.9, -1040.46, 29.37), name = "Fleeca Bank - Legion Square", radius = 35.0},
            {coords = vector3(-1212.27, -330.91, 37.78), name = "Fleeca Bank - Rockford Hills", radius = 35.0},
            {coords = vector3(-2962.35, 481.39, 15.7), name = "Fleeca Bank - Pillbox", radius = 35.0},
            {coords = vector3(1175.85, 2711.11, 38.09), name = "Fleeca Bank - Paleto", radius = 35.0},
            
            -- Stores
            {coords = vector3(24.95, -1347.09, 29.47), name = "24/7 Supermarket - Legion Square", radius = 35.0},
            {coords = vector3(-3242.21, 1001.52, 12.83), name = "24/7 Supermarket - Pillbox", radius = 35.0},
            {coords = vector3(547.27, 2671.97, 42.16), name = "24/7 Supermarket - Paleto Bay", radius = 35.0},
            
            -- Police Station
            {coords = vector3(425.51, -983.23, 29.44), name = "MRPD Entrance", radius = 40.0},
            --{coords = vector3(450.2, -1000.5, 29.4), name = "MRPD Parking", radius = 50.0},
            
            -- Highways
            {coords = vector3(850.5, 450.2, 123.4), name = "Senora Freeway Camera 1", radius = 40.0},
            {coords = vector3(600.2, 300.8, 115.6), name = "Senora Freeway Camera 2", radius = 40.0},
            {coords = vector3(1100.4, -560.2, 66.1), name = "I-9 Highway Camera", radius = 40.0},
        }
    },
    
    -- Emergency Vehicle Models (won't trigger NPC reports)
    EmergencyVehicleModels = {
        [`police`] = true,
        [`police2`] = true,
        [`police3`] = true,
        [`police4`] = true,
        [`policeb`] = true,
        [`policet`] = true,
        [`ambulance`] = true,
        [`fire`] = true,
    }
}

-- ========================================
-- MESSAGE CONFIGURATION
-- ========================================
Config.Messages = {
    -- Command messages
    NoArgs = "~r~Please describe your emergency. Usage: /911 [description]",
    NoArgsAnonymous = "~r~Please describe what you witnessed. Usage: /a911 [description]",
    Cooldown = "~y~Please wait %d seconds before calling 911 again.",
    AnonymousCooldown = "~y~Please wait %d seconds before submitting another anonymous tip.",
    Sending = "~g~Sending emergency dispatch...",
    SendingAnonymous = "~g~Submitting anonymous tip...",
    Success = "~g~Your 911 call has been received.",
    SuccessAnonymous = "~g~Your anonymous tip has been received.",
    LocationFormat = "%s (Postal %s)",
    
    NPCReports = {
        -- SPEEDING REPORTS
        Speeding = {
            "Crazy driver going way too fast!",
            "There's someone speeding past me!",
            "Vehicle just flew past at dangerous speed!",
            "Reckless driver - way over the limit!",
            "Someone's going way too fast on this road!",
            "I just saw a car speeding - really dangerous!",
            "Driver flying down the road at insane speed!",
            "Vehicle speeding dangerously through traffic!",
            "Just saw the craziest speedster come by!",
            "Someone's driving extremely fast - not safe!",
            "Racing down the street at high speed!",
            "That car is going way too fast through here!"
        },
        
        -- GUNSHOT REPORTS
        Gunshots = {
            "GUNSHOTS! OH MY GOD!",
            "I heard shots fired!",
            "Someone's shooting! Get police here NOW!",
            "There are shots being fired!",
            "I hear gunfire!",
            "Active shooter in the area!",
            "SOMEBODY'S SHOOTING! SEND HELP!",
            "Gunfire, multiple shots!",
            "I can hear gunshots nearby!",
            "Someone's firing a weapon!",
            "Shots fired! This is serious!",
            "I'm hearing gunshots in my area!"
        },
        
        -- ACCIDENT REPORTS
        Accident = {
            "There's been an accident!",
            "Car accident happening right now!",
            "Two vehicles just crashed!",
            "Major collision at the intersection",
            "Car flipped over, driver might be trapped",
            "Hit and run, someone's hurt",
            "Multi-vehicle pile-up on the highway",
            "Car crashed into a building",
            "Head-on collision just happened",
            "T-bone accident at the light",
            "Vehicle rolled over, need ambulance",
            "Bad wreck, airbags deployed, people injured",
            "Car accident with injuries, send EMS",
            "Crash with possible fatalities",
            "Vehicle off the road and in the ditch"
        },
        
        -- EXPLOSION REPORTS
        Explosion = {
            "HUGE EXPLOSION! OH MY GOD!",
            "Something just blew up! Send everyone!",
            "Massive explosion! There might be casualties!",
            "EXPLOSION! Fire and smoke everywhere!",
            "Big blast! Building might be damaged!",
            "Bomb or something went off! Need help NOW!",
            "Explosion heard! Sounds really bad!",
            "Something exploded! I can see flames!",
            "Major explosion, windows shattered!",
            "Blast went off, people are running!",
            "Explosive device detonated, need bomb squad!",
            "Car exploded! Fire spreading!",
            "Gas explosion or something, huge fireball!",
            "Multiple explosions! This is serious!"
        },
        
        -- WEAPON BRANDISHING REPORTS
        Brandishing = {
            -- Panicked reports
            "Someone has a gun out!",
            "There's a person waving a gun around!",
            "Armed person threatening people!",
            "Someone's walking around with a weapon drawn!",
            "Person brandishing a firearm in public!",
            
            -- Concerned citizen reports
            "I see someone with a gun, they're not police",
            "There's an armed individual here",
            "Someone is displaying a weapon",
            "Person with gun visible, looks threatening",
            "Armed suspect in the area",
            
            -- Detailed reports
            "Someone pulled out a gun, hasn't fired yet",
            "Person threatening others with a weapon",
            "Individual brandishing firearm, no shots fired",
            "Someone's pointing a gun at people",
            "Armed person acting aggressively",
            
            -- Location specific
            "Gun drawn inside the building",
            "Someone with a weapon in the parking lot",
            "Armed person near the entrance",
            "Weapon visible, person looks dangerous",
            "Someone showing off a gun"
        },
        
        -- CCTV CAMERA REPORTS
        CCTV = {
            -- General CCTV observations
            "Security camera footage shows criminal activity",
            "CCTV operator reporting incident in progress",
            "Security system has detected a crime",
            "Camera surveillance picked up illegal activity",
            "Security footage confirms violation",
            
            -- Specific camera reports
            "Security camera has recorded the incident",
            "CCTV system triggered - immediate response needed",
            "Surveillance footage available of suspect",
            "Security monitoring detected suspicious activity",
            "Camera operator witnessed crime in progress"
        },
        
        CCTVSpeeding = {
            "Traffic camera recorded vehicle speeding",
            "CCTV shows reckless driving in monitored area",
            "Security camera captured dangerous driver",
            "Surveillance shows vehicle violation",
            "Traffic monitoring system detected speeding vehicle"
        },
        
        CCTVGunshots = {
            "Security camera detected gunfire",
            "CCTV operator reporting shots fired on camera",
            "Surveillance system picked up muzzle flashes",
            "Security footage shows armed individual",
            "Camera detected weapons discharge"
        },
        
        CCTVFighting = {
            "Security camera shows fight in progress",
            "CCTV operator reporting physical altercation",
            "Surveillance detected violent incident",
            "Security footage shows assault taking place",
            "Camera picked up brawl in monitored area"
        },
        
        CCTVBrandishing = {
            "Security camera shows armed individual",
            "CCTV detected person with weapon drawn",
            "Surveillance shows someone brandishing a firearm",
            "Camera operator reporting armed person on premises",
            "Security footage shows individual displaying weapon",
            "CCTV alert: Armed person in monitored area",
            "Camera detected weapon - person is armed",
            "Security system shows threatening individual with gun"
        },
        
        CCTVTheft = {
            "Security camera shows vehicle theft in progress",
            "CCTV operator reporting car being stolen",
            "Surveillance detected unauthorized vehicle access",
            "Security footage shows suspect breaking into vehicle",
            "Camera captured carjacking incident"
        },
        
        -- CARJACKING REPORTS (if enabled)
        Carjacking = {
            "Someone just stole a car at gunpoint!",
            "Carjacking in progress!",
            "Person pulled from vehicle, car stolen!",
            "Armed carjacking just happened!",
            "Someone hijacked a vehicle!",
            "Driver forced out of car at weapon point!",
            "Vehicle theft with victim present!",
            "Violent car theft occurring now!"
        },
        
        -- SUSPICIOUS ACTIVITY
        Suspicious = {
            "Someone's acting really suspicious around parked cars",
            "I think someone's casing houses on my street",
            "There's a person looking into car windows",
            "Group of people doing something shady in the alley",
            "Someone's been sitting in their car watching the bank for an hour",
            "Suspicious person following people from the ATM",
            "Someone trying door handles on cars",
            "Person with tools messing with a car",
            "Suspicious van circling the neighborhood",
            "Someone hiding something in the bushes"
        },
        
        -- GENERAL DISTURBANCE
        Disturbance = {
            "Loud party that's getting out of control",
            "People causing a scene and won't leave",
            "Someone's disturbing the peace, yelling and threatening people",
            "Drunk person harassing customers",
            "Group causing problems at the store",
            "Someone's having a mental breakdown in public",
            "Person screaming and throwing things",
            "Aggressive panhandler won't leave people alone",
            "Someone vandalizing property",
            "Person exposing themselves in public"
        }
    }
}

-- ========================================
-- FRAMEWORK & INTEGRATION SETTINGS
-- ========================================
Config.Framework = {
    Standalone = true, -- No framework, just FiveM
    ESX = false, -- ESX Framework
    QBCore = false, -- QB-Core Framework
}

-- ========================================
-- EMERGENCY SERVICES NOTIFICATION
-- ========================================
Config.NotifyEmergencyServices = false -- Notify online police/ems (requires job system)
Config.EmergencyJobs = {
    Police = {"police", "sheriff", "trooper", "highway", "ranger", "fib", "swat"},
    EMS = {"ambulance", "ems", "fire", "doctor", "paramedic", "firefighter"},
}

-- ========================================
-- DISCORD INTEGRATION
-- ========================================
Config.LogToDiscord = true -- Enable Discord webhook logging
Config.DiscordWebhook = "" -- Discord webhook URL
Config.DiscordSettings = {
    Username = "CDE 911 Dispatch",
    Avatar = "", -- Avatar URL (optional)
    Colors = {
        Player = 15158332, -- Red
        Anonymous = 8421504, -- Gray
        NPC = 16753920, -- Orange
        Speeding = 16776960, -- Yellow
        SpeedCamera = 3447003, -- Blue
        Gunshots = 16711680, -- Bright Red
        Accident = 16744448, -- Orange-Red
        Fighting = 16737792, -- Light Red
        Explosion = 13632027, -- Dark Red
        Brandishing = 16744192, -- Orange
        CCTV = 32768 -- Green
    }
}
