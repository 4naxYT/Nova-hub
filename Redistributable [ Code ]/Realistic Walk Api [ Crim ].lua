---------------------------------------------------------------------
-- WALK TELEPORT SYSTEM (AC BYPASS)
-- Complete standalone module with all dependencies
---------------------------------------------------------------------

-- Create a local environment for dependencies
local WalkTeleportSystem = {}

-- Get required services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Store the local player reference
local LocalPlayer = Players.LocalPlayer

-- Optional: Get Fluent if available for notifications
local Fluent = _G.Fluent or nil

---------------------------------------------------------------------
-- INTERNAL HELPER FUNCTIONS
---------------------------------------------------------------------

-- Check if shift key is being held
local function isShiftHeld()
    return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or 
           UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

-- Get character and required parts with validation
local function getCharacterParts()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    
    if not hrp or not hum then
        return nil, nil, nil
    end
    
    return char, hrp, hum
end

-- Temporarily disable conflicting features and return old settings
local function temporarilyDisableFeatures()
    local oldSettings = {}
    
    -- Store current states if _G exists
    if _G then
        oldSettings.CustomWalkspeed = _G.CustomWalkspeed
        oldSettings.Noclip = _G.Noclip
        
        -- Disable features
        _G.CustomWalkspeed = false
        _G.Noclip = false
    end
    
    return oldSettings
end

-- Restore previously disabled features
local function restoreFeatures(oldSettings)
    task.wait(0.5)
    
    if _G then
        _G.CustomWalkspeed = oldSettings.CustomWalkspeed or false
        _G.Noclip = oldSettings.Noclip or false
    end
end

-- Generate waypoints between start and end positions
local function generateWaypoints(startPos, endPos, waypointDistance)
    waypointDistance = waypointDistance or 20
    
    local distance = (endPos - startPos).Magnitude
    local waypointCount = math.max(math.floor(distance / waypointDistance), 5)
    local waypoints = {}
    
    for i = 1, waypointCount do
        local alpha = i / waypointCount
        local waypointPos = startPos:Lerp(endPos, alpha)
        
        -- Add natural movement variations
        local randomOffset = Vector3.new(
            math.random(-2, 2) * 0.5,
            math.sin(i) * 1.5 + math.random(-1, 1) * 0.3,
            math.random(-2, 2) * 0.5
        )
        waypointPos = waypointPos + randomOffset
        table.insert(waypoints, waypointPos)
    end
    
    return waypoints
end

-- Move through waypoints with realistic timing
local function moveThroughWaypoints(hrp, waypoints)
    for i, waypointPos in ipairs(waypoints) do
        -- Check if character still exists
        if not hrp or not hrp.Parent then
            return false
        end
        
        -- Calculate segment distance
        local segmentDistance = i == 1 and (waypointPos - hrp.Position).Magnitude
                                 or (waypointPos - waypoints[i-1]).Magnitude
        
        -- Speed variation for realism (22-26 studs/sec)
        local speedVariation = math.random(22, 26)
        local duration = segmentDistance / speedVariation
        
        -- Use Sine easing for smooth movement
        local tweenInfo = TweenInfo.new(
            duration,
            Enum.EasingStyle.Sine,
            Enum.EasingDirection.InOut
        )
        
        -- Preserve rotation while moving
        local currentRotation = hrp.CFrame - hrp.CFrame.Position
        local targetCFrameAtWaypoint = CFrame.new(waypointPos) * currentRotation
        
        local tween = TweenService:Create(hrp, tweenInfo, {
            CFrame = targetCFrameAtWaypoint
        })
        
        tween:Play()
        tween.Completed:Wait()
        
        -- Random micro-pauses for human-like behavior
        local pauseChance = math.random(1, 100)
        if pauseChance <= 30 then
            task.wait(math.random(5, 15) / 100) -- 0.05 to 0.15 sec pause
        else
            task.wait(0.03) -- Minimum frame delay
        end
        
        -- Occasionally look around
        if i % 5 == 0 then
            local lookOffset = CFrame.Angles(0, math.rad(math.random(-20, 20)), 0)
            hrp.CFrame = hrp.CFrame * lookOffset
            task.wait(0.05)
        end
    end
    
    return true
end

-- Final landing and cleanup
local function finalizeMovement(hrp, hum, targetCFrame)
    -- Smooth landing
    local finalTween = TweenService:Create(hrp, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        CFrame = targetCFrame * CFrame.new(0, 3, 0)
    })
    finalTween:Play()
    finalTween.Completed:Wait()
    
    task.wait(0.2)
    
    -- Reset velocity
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    
    -- Ensure proper landing state
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Landed)
    end
end

-- Send notification (supports multiple notification systems)
local function sendNotification(title, content, duration)
    duration = duration or 3
    
    -- Try Fluent first
    if Fluent and Fluent.Notify then
        Fluent:Notify({
            Title = title,
            Content = content,
            Duration = duration
        })
        return true
    end
    
    -- Try game:GetService("StarterGui"):SetCore for Roblox notifications
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = content,
            Duration = duration
        })
    end)
    
    -- Fallback to print
    print(string.format("[WalkTeleport] %s: %s", title, content))
    
    return true
end

---------------------------------------------------------------------
-- MAIN EXPORTED FUNCTIONS
---------------------------------------------------------------------

-- Primary walk teleport function
-- @param targetCFrame: CFrame - Destination CFrame
-- @param options: table - Optional parameters
--   - waypointDistance: number - Distance between waypoints (default: 20)
--   - silent: boolean - Suppress notifications (default: false)
--   - requireShift: boolean - Require shift to be held (default: true)
--   - maxDistance: number - Max distance to walk (default: nil = no limit)
-- @returns: boolean - Success status
function WalkTeleportSystem.walkto(targetCFrame, options)
    options = options or {}
    local waypointDistance = options.waypointDistance or 20
    local silent = options.silent or false
    local requireShift = options.requireShift ~= false
    local maxDistance = options.maxDistance
    
    -- Validate input
    if not targetCFrame or not targetCFrame then
        if not silent then
            sendNotification("Error", "Invalid destination", 3)
        end
        return false
    end
    
    -- Check shift requirement
    if requireShift and not isShiftHeld() then
        if not silent then
            sendNotification("⚠️ Hold SHIFT!", "Hold SHIFT while clicking to bypass anticheat", 5)
        end
        return false
    end
    
    -- Get character parts
    local char, hrp, hum = getCharacterParts()
    if not hrp or not hum then
        if not silent then
            sendNotification("Error", "Could not find character parts", 3)
        end
        return false
    end
    
    -- Check distance limit
    if maxDistance then
        local distance = (hrp.Position - targetCFrame.Position).Magnitude
        if distance > maxDistance then
            if not silent then
                sendNotification("Distance Limit", string.format("Target too far (%.0f > %.0f)", distance, maxDistance), 3)
            end
            return false
        end
    end
    
    -- Temporarily disable conflicting features
    local oldSettings = temporarilyDisableFeatures()
    
    -- Generate waypoints
    local startPos = hrp.Position
    local endPos = targetCFrame.Position
    local waypoints = generateWaypoints(startPos, endPos, waypointDistance)
    
    if not silent then
        sendNotification("🚶 Walking Safely...", 
               "Ultra-stealth mode (" .. #waypoints .. " waypoints)", 3)
    end
    
    -- Move through waypoints
    local moveSuccess = moveThroughWaypoints(hrp, waypoints)
    
    if not moveSuccess then
        if not silent then
            sendNotification("Error", "Movement interrupted", 2)
        end
        restoreFeatures(oldSettings)
        return false
    end
    
    -- Final landing and cleanup
    finalizeMovement(hrp, hum, targetCFrame)
    
    -- Restore previous settings
    restoreFeatures(oldSettings)
    
    if not silent then
        sendNotification("✅ Arrived Safely", "Teleport complete - AC bypassed", 2)
    end
    
    return true
end

-- Walk to a Vector3 position
-- @param position: Vector3 - Destination position
-- @param options: table - Same options as walkto()
function WalkTeleportSystem.walktoPosition(position, options)
    return WalkTeleportSystem.walkto(CFrame.new(position), options)
end

-- Walk to a BasePart
-- @param part: BasePart - Destination part
-- @param options: table - Same options as walkto()
function WalkTeleportSystem.walktoPart(part, options)
    if not part or not part:IsA("BasePart") then
        if not (options and options.silent) then
            sendNotification("Error", "Invalid part", 2)
        end
        return false
    end
    return WalkTeleportSystem.walkto(part.CFrame, options)
end

-- Walk to a player's character
-- @param player: Player - Target player
-- @param options: table - Same options as walkto()
function WalkTeleportSystem.walktoPlayer(player, options)
    if not player or not player.Character then
        if not (options and options.silent) then
            sendNotification("Error", "Player not found", 2)
        end
        return false
    end
    
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        if not (options and options.silent) then
            sendNotification("Error", "Player has no HumanoidRootPart", 2)
        end
        return false
    end
    
    return WalkTeleportSystem.walkto(hrp.CFrame, options)
end

-- Walk to a model (uses PrimaryPart or first BasePart)
-- @param model: Model - Target model
-- @param options: table - Same options as walkto()
function WalkTeleportSystem.walktoModel(model, options)
    if not model or not model:IsA("Model") then
        if not (options and options.silent) then
            sendNotification("Error", "Invalid model", 2)
        end
        return false
    end
    
    local targetPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if not targetPart then
        if not (options and options.silent) then
            sendNotification("Error", "Model has no reachable part", 2)
        end
        return false
    end
    
    return WalkTeleportSystem.walkto(targetPart.CFrame, options)
end

-- Walk to a named location (predefined waypoints)
-- @param locationName: string - Name of location
-- @param options: table - Same options as walkto()
function WalkTeleportSystem.walktoLocation(locationName, options)
    local locations = {
        Cafe = CFrame.new(-4616.97, 6.00, -281.97),
        Subway = CFrame.new(-4600.73, 2.39, -684.50),
        Motel = CFrame.new(-4619.04, 5.33, -897.38),
        Tower = CFrame.new(-4483.96, 5.33, -787.30),
        Dealer = CFrame.new(-4526.13, 5.33, -842.42),
        Bank = CFrame.new(-4625.00, 5.00, -350.00), -- idk
        Police = CFrame.new(-4720.00, 5.00, -450.00), -- idk
        Hospital = CFrame.new(-4580.00, 5.00, -550.00) -- idk
    }
    
    local targetCFrame = locations[locationName]
    if not targetCFrame then
        if not (options and options.silent) then
            local available = table.concat(table.keys(locations), ", ")
            sendNotification("Location Not Found", "Available: " .. available, 5)
        end
        return false
    end
    
    return WalkTeleportSystem.walkto(targetCFrame, options)
end

-- Cancel current movement (if any)
-- Note: This function requires storing tween references which would need modification
-- For now, returns false as full implementation requires more complex state management
function WalkTeleportSystem.cancelMovement()
    -- This would require storing the current tween reference
    -- For simplicity, we'll return false
    return false
end

-- Check if a walk operation is possible
-- @returns: table with status information
function WalkTeleportSystem.checkStatus()
    local char, hrp, hum = getCharacterParts()
    
    return {
        characterExists = char ~= nil,
        hasHumanoidRootPart = hrp ~= nil,
        hasHumanoid = hum ~= nil,
        isAlive = hum and hum.Health > 0 or false,
        shiftHeld = isShiftHeld()
    }
end

---------------------------------------------------------------------
-- GLOBAL EXPORTS 
---------------------------------------------------------------------

if _G then
    _G.WalkTo = WalkTeleportSystem.walkto
    _G.WalkToPosition = WalkTeleportSystem.walktoPosition
    _G.WalkToPart = WalkTeleportSystem.walktoPart
    _G.WalkToPlayer = WalkTeleportSystem.walktoPlayer
    _G.WalkToModel = WalkTeleportSystem.walktoModel
    _G.WalkToLocation = WalkTeleportSystem.walktoLocation
    _G.WalkTeleportSystem = WalkTeleportSystem
end

-- Return the module
return WalkTeleportSystem
