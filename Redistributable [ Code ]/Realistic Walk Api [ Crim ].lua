---------------------------------------------------------------------
-- WALK TELEPORT SYSTEM (AC BYPASS)
-- Complete standalone module with all dependencies
-- Uses Roblox's native PathfindingService for obstacle navigation
---------------------------------------------------------------------

-- Create a local environment for dependencies
local WalkTeleportSystem = {}

-- Get required services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

-- Store the local player reference
local LocalPlayer = Players.LocalPlayer

-- Track active movement
local activeConnection = nil
local activePath = nil
local isMoving = false

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

-- Create path to destination using PathfindingService
local function createPathToDestination(startPos, endPos)
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentMaxSlope = 45,
        WaypointSpacing = 3,
        Costs = {
            Water = 10,
            -- Default costs for other materials
        }
    })
    
    local success, errorMessage = pcall(function()
        path:ComputeAsync(startPos, endPos)
    end)
    
    if not success or path.Status == Enum.PathStatus.NoPath then
        return nil, nil
    end
    
    local waypoints = path:GetWaypoints()
    return path, waypoints
end

-- Move along path using click-to-move (Humanoid:MoveTo)
local function moveAlongPath(hum, waypoints)
    if not hum or not waypoints or #waypoints == 0 then
        return false
    end
    
    isMoving = true
    
    -- Set up MoveToFinished connection
    local moveCompleted = false
    local moveFinishedConnection = nil
    local reachedEnd = false
    
    -- Function to move to next waypoint
    local function moveToWaypoint(index)
        if not hum or not hum.Parent or index > #waypoints then
            reachedEnd = index > #waypoints
            if moveFinishedConnection then
                moveFinishedConnection:Disconnect()
            end
            isMoving = false
            return false
        end
        
        local waypoint = waypoints[index]
        local targetPosition = waypoint.Position
        
        -- Move to the waypoint
        hum:MoveTo(targetPosition)
        
        -- Wait for movement to complete or be blocked
        local completed = false
        local blocked = false
        
        moveFinishedConnection = hum.MoveToFinished:Connect(function(reached)
            if reached then
                completed = true
            else
                blocked = true
            end
        end)
        
        -- Wait for either completion or timeout
        local timeout = 30
        local startTime = tick()
        
        while not completed and not blocked and tick() - startTime < timeout do
            task.wait(0.1)
            -- Check if we're stuck
            if hum and hum.MoveDirection.Magnitude < 0.1 and (hum.Position - targetPosition).Magnitude > 3 then
                blocked = true
                break
            end
        end
        
        if moveFinishedConnection then
            moveFinishedConnection:Disconnect()
        end
        
        if blocked then
            -- Try to recalculate path from current position
            return false
        end
        
        return true
    end
    
    -- Move through all waypoints
    local currentWaypoint = 1
    while currentWaypoint <= #waypoints and hum and hum.Parent do
        local success = moveToWaypoint(currentWaypoint)
        if not success then
            -- Recalculate path from current position
            local newPath, newWaypoints = createPathToDestination(hum.Position, waypoints[#waypoints].Position)
            if newPath and newWaypoints and #newWaypoints > 0 then
                waypoints = newWaypoints
                currentWaypoint = 1
            else
                break
            end
        else
            currentWaypoint = currentWaypoint + 1
        end
        task.wait(0.05)
    end
    
    isMoving = false
    
    -- Final arrival
    if reachedEnd or (currentWaypoint > #waypoints) then
        return true
    end
    
    return false
end

-- Send notification (supports multiple notification systems)
local function sendNotification(title, content, duration)
    duration = duration or 3
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

-- Cancel current movement
local function cancelCurrentMovement(hum)
    if isMoving and hum then
        hum:MoveTo(hum.Position) -- Cancel movement by moving to current position
        hum:MoveTo(Vector3.zero) -- Alternative method to stop
        hum.AutoRotate = true
        if activeConnection then
            activeConnection:Disconnect()
            activeConnection = nil
        end
        isMoving = false
        return true
    end
    return false
end

---------------------------------------------------------------------
-- MAIN EXPORTED FUNCTIONS
---------------------------------------------------------------------

-- Primary walk teleport function using click-to-move
-- @param targetCFrame: CFrame - Destination CFrame
-- @param options: table - Optional parameters
--   - silent: boolean - Suppress notifications (default: false)
--   - requireShift: boolean - Require shift to be held (default: true)
--   - maxDistance: number - Max distance to walk (default: nil = no limit)
--   - waitForCompletion: boolean - Wait for movement to finish (default: true)
-- @returns: boolean - Success status
function WalkTeleportSystem.walkto(targetCFrame, options)
    options = options or {}
    local silent = options.silent or false
    local requireShift = options.requireShift ~= false
    local maxDistance = options.maxDistance
    local waitForCompletion = options.waitForCompletion ~= false
    
    -- Validate input
    if not targetCFrame then
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
    
    -- Cancel any existing movement
    cancelCurrentMovement(hum)
    
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
    
    -- Create path to destination
    local startPos = hrp.Position
    local endPos = targetCFrame.Position
    
    if not silent then
        sendNotification("🚶 Calculating Path...", "Finding optimal route", 2)
    end
    
    local path, waypoints = createPathToDestination(startPos, endPos)
    
    if not path or not waypoints or #waypoints == 0 then
        if not silent then
            sendNotification("Error", "No path found to destination", 3)
        end
        return false
    end
    
    if not silent then
        sendNotification("🚶 Walking Safely...", 
               "Using Roblox pathfinding (" .. #waypoints .. " waypoints)", 3)
    end
    
    -- Move along the path
    local moveSuccess = false
    
    if waitForCompletion then
        moveSuccess = moveAlongPath(hum, waypoints)
    else
        -- Start movement but don't wait for completion
        isMoving = true
        moveSuccess = true
        
        -- Start coroutine to handle movement
        task.spawn(function()
            moveAlongPath(hum, waypoints)
        end)
    end
    
    if not moveSuccess and waitForCompletion then
        if not silent then
            sendNotification("Error", "Path blocked or movement interrupted", 2)
        end
        return false
    end
    
    if waitForCompletion and not silent then
        sendNotification("✅ Arrived Safely", "Destination reached - AC bypassed", 2)
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
        Bank = CFrame.new(-4625.00, 5.00, -350.00),
        Police = CFrame.new(-4720.00, 5.00, -450.00),
        Hospital = CFrame.new(-4580.00, 5.00, -550.00)
    }
    
    local targetCFrame = locations[locationName]
    if not targetCFrame then
        if not (options and options.silent) then
            local available = {}
            for k, _ in pairs(locations) do
                table.insert(available, k)
            end
            sendNotification("Location Not Found", "Available: " .. table.concat(available, ", "), 5)
        end
        return false
    end
    
    return WalkTeleportSystem.walkto(targetCFrame, options)
end

-- Cancel current movement
-- @returns: boolean - Whether movement was cancelled
function WalkTeleportSystem.cancelMovement()
    local _, hrp, hum = getCharacterParts()
    return cancelCurrentMovement(hum)
end

-- Check if currently moving
-- @returns: boolean - Whether a walk operation is in progress
function WalkTeleportSystem.isMoving()
    return isMoving
end

-- Check if a walk operation is possible to a destination
-- @param destination: CFrame/Vector3 - Destination to check
-- @returns: table with status information
function WalkTeleportSystem.checkPathExists(destination)
    local _, hrp = getCharacterParts()
    if not hrp then
        return {
            pathExists = false,
            error = "No character found"
        }
    end
    
    local destPos = destination
    if typeof(destination) == "CFrame" then
        destPos = destination.Position
    end
    
    local path, waypoints = createPathToDestination(hrp.Position, destPos)
    
    return {
        pathExists = path ~= nil and waypoints ~= nil and #waypoints > 0,
        waypointCount = waypoints and #waypoints or 0,
        error = path and waypoints and #waypoints > 0 and nil or "No path found"
    }
end

-- Check if a walk operation is possible (general status)
-- @returns: table with status information
function WalkTeleportSystem.checkStatus()
    local char, hrp, hum = getCharacterParts()
    
    return {
        characterExists = char ~= nil,
        hasHumanoidRootPart = hrp ~= nil,
        hasHumanoid = hum ~= nil,
        isAlive = hum and hum.Health > 0 or false,
        shiftHeld = isShiftHeld(),
        isMoving = isMoving
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
    _G.CancelWalk = WalkTeleportSystem.cancelMovement
    _G.IsWalking = WalkTeleportSystem.isMoving
    _G.WalkTeleportSystem = WalkTeleportSystem
end

-- Return the module
return WalkTeleportSystem
