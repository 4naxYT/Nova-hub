# NovaHub Redistributable Code

This repository contains redistributable modules for Roblox "Code Development".  
You are free to use them in your projects, provided that proper credit is given.

## 📌 Crediting

Credit must be given in a visible way, such as:
- A Roblox notification
- A label in your UI
- A button
- Any other method that clearly shows **NovaHub**'s redistributable code has been used

## 💡 Suggestions

All suggestions for improvements should be submitted through the NovaHub Discord server:  
_**[ [https://discord.gg/8HDEWZVUem](https://discord.gg/8HDEWZVUem) ]**_

---

## 📦 Current Contents

As of **20/03/2026**, the redistributable includes:

- **Aimbot API** – modified version of [Exunys Aimbot API](https://github.com/Exunys/AirHub-V2)
- **Drawing API** – fully custom, reliable drawing library

---

## 🎯 Aimbot API

This aimbot module is a fork of Exunys' work, with the following modifications:

- Added compatibility for the **Velocity** executor  
- Removed whitelist / blacklist for debloating  
- Improved wall check using raycast + caching  
- Fixed FOV circle transparency and filled mode  
- Fixed FOV centering with Y-offset (pixel‑accurate conversion from studs)

### Basic Usage

```lua
local aimbot = loadstring(game:HttpGet("https://raw.githubusercontent.com/4naxYT/Nova-hub/refs/heads/main/Redistributable%20%5B%20Code%20%5D/Exunys-fork%20aimbot%20%5BVelocity%20ver%5D.lua"))()

-- Configure settings
aimbot.Settings.Enabled = true
aimbot.Settings.LockPart = "Head"
aimbot.Settings.WallCheck = true
aimbot.Settings.TriggerKey = Enum.UserInputType.MouseButton2

-- Enable FOV circle
aimbot.FOVSettings.Enabled = true
aimbot.FOVSettings.Radius = 120
aimbot.FOVSettings.Color = Color3.fromRGB(255, 255, 255)

-- Start the aimbot
aimbot:Load()
```

**Settings table**  
| Property | Description |
|----------|-------------|
| `Enabled` | Master toggle |
| `TeamCheck` | Avoid targeting same team |
| `AliveCheck` | Only target alive players |
| `WallCheck` | Use raycast to check obstacles |
| `LockPart` | Part to aim at (e.g., "Head", "HumanoidRootPart") |
| `TriggerKey` | Key or mouse button to activate |
| `Toggle` | Hold or toggle mode |

---

## ✏️ Drawing API (NovaDraw v2)

A complete, reliable drawing library that works in most Roblox executors.  
All drawing is done via `ScreenGui` objects, ensuring cross‑executor compatibility.

### Supported Shapes

| Constructor | Description |
|-------------|-------------|
| `NovaDraw.circle` | Circle (filled or hollow) |
| `NovaDraw.square` | Rectangle / square |
| `NovaDraw.line` | Single line |
| `NovaDraw.triangle` | Triangle |
| `NovaDraw.quad` | Quadrilateral |
| `NovaDraw.text` | Text with optional outline |
| `NovaDraw.polygon` | Regular polygon (any number of sides) |
| `NovaDraw.crosshair` | 4‑arm crosshair |
| `NovaDraw.box` | Hollow rectangle |
| `NovaDraw.cornerBox` | ESP‑style box with only corners |
| `NovaDraw.roundedBox` | Box with rounded corners |
| `NovaDraw.healthBar` | Vertical health bar (auto color) |
| `NovaDraw.progressBar` | Horizontal progress bar |
| `NovaDraw.diamond` | Diamond shape |
| `NovaDraw.star` | Star polygon |
| `NovaDraw.spiral` | Spiral curve |
| `NovaDraw.dashedLine` | Dashed line |
| `NovaDraw.arrow` | Line with arrowhead |
| `NovaDraw.grid` | Grid of lines |
| `NovaDraw.tracer` | Line between two points (alias for rounded line) |

### Usage Example

```lua
local NovaDraw = loadstring(game:HttpGet("your_drawing_api_url"))()

-- Create a red circle
local circle = NovaDraw.circle(500, 300, 50, 2, Color3.fromRGB(255, 0, 0), false, 1)

-- Move it to a new position
NovaDraw.moveCircle(circle, 600, 400)

-- Change its color
NovaDraw.recolor(circle, Color3.fromRGB(0, 255, 0))

-- Hide it
NovaDraw.hide(circle)

-- Show it again
NovaDraw.show(circle)

-- Remove it completely
NovaDraw.remove(circle)

-- Clean up all drawings
NovaDraw.clearAll()
```

### Text with Outline

```lua
local myText = NovaDraw.text(100, 100, "Hello World", 24, Color3.fromRGB(255,255,255), 1, true)
NovaDraw.setText(myText, "New text")
```

### Health Bar

```lua
local health = NovaDraw.healthBar(50, 50, 30, 100, 0.75, Color3.fromRGB(0,255,0), 1)
-- Later, update the percentage
NovaDraw.updateHealthBar(health, 0.45)
```

### Complete API Reference

For a full list of all constructors and helper methods, please refer to the **top‑of‑file documentation** inside `Custom Drawing Api [ Universal ].lua`.

---

## 🔁 License & Credits

- The **Aimbot API** is a modified version of [Exunys Aimbot API](https://github.com/Exunys/AirHub-V2). Original work by Exunys.  
- The **Drawing API** (NovaDraw) is a custom creation by NovaHub.

Both modules are **redistributable** and can be used freely, provided you include appropriate credits as described above.

---

> *For any questions or support, join our [Discord](https://discord.gg/8HDEWZVUem).*

---
