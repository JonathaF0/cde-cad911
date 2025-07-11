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
