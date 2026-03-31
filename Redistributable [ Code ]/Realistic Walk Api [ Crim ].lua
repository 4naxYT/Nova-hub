---------------------------------------------------------------------
-- WALK TO SYSTEM (Based on Auto-Farm Script)
-- Uses Roblox PathfindingService with Humanoid:MoveTo
-- Includes anti-stuck teleport fallback and visual waypoints
-- Can Reach is currently bugged, so ignore it
---------------------------------------------------------------------

local WalkToSystem = {}

-- Services
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Local references
local LocalPlayer = Players.LocalPlayer
local Character = nil
local Humanoid = nil
local HumanoidRootPart = nil

-- State variables
local CurrentlyPathing = false
local CurrentPath = nil
local CurrentWaypoint = nil
local VisualFolder = nil
local Pass = false

-- Tween info for visual effects
local TweenI = TweenInfo.new(1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

---------------------------------------------------------------------
-- PREDEFINED LOCATIONS (from auto-farm map)
---------------------------------------------------------------------

local Locations = { -- criminality
    Cafe = CFrame.new(-4599.47, 3.89, -296.98),
    Subway = CFrame.new(-4590.86, 3.65, -694.64),
    Motel = CFrame.new(-4619.04, 5.33, -897.38),
    Tower = CFrame.new(-4490.34, 3.29, -759.60),
    Factory = CFrame.new(-4305.15, 3.93, -609.54),
    Pizza = CFrame.new(-4373.28, 4, -174.13),
    Junk_Yard = CFrame.new(-3852.35, 3.89, -361.91),
    Basket_Ball = CFrame.new(-4830.70, 3.60, -241.91),
}

---------------------------------------------------------------------
-- VISUAL WAYPOINTS
---------------------------------------------------------------------

local function CreateVisualPoint(Position)
    if not VisualFolder then
        VisualFolder = Instance.new("Folder", Workspace)
        VisualFolder.Name = "PathVisuals_WalkToSystem"
    end
    
    local A = Instance.new("Part")
    local B = Instance.new("SelectionSphere")
    A.Anchored = true
    A.CanCollide = false
    A.Size = Vector3.new(0.001, 0.001, 0.001)
    A.Position = Position + Vector3.new(0, 2, 0)
    A.Transparency = 1
    A.Parent = VisualFolder
    A.Name = tostring(Position)
    B.Transparency = 1
    B.Parent = A
    B.Adornee = A
    B.Color3 = Color3.new(1, 0, 0.0156863)
    TweenService:Create(B, TweenI, {Transparency = 0}):Play()
end

local function UpdateVisualPoint(Point, Remove, Color)
    task.spawn(function()
        if Remove == true then
            TweenService:Create(Point, TweenI, {Color3 = Color3.new(0.454902, 0.454902, 0.454902)}):Play()
            TweenService:Create(Point, TweenI, {Transparency = 1}):Play()
            wait(1)
            Point.Parent:Destroy()
        else
            TweenService:Create(Point, TweenI, {Color3 = Color}):Play()
        end
    end)
end

local function ClearVisualPoints()
    if VisualFolder then
        for i, v in pairs(VisualFolder:GetChildren()) do
            if v:FindFirstChild("SelectionSphere") then
                UpdateVisualPoint(v.SelectionSphere, true)
            else
                v:Destroy()
            end
        end
    end
end

---------------------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------------------

local function isPointInsidePart(part, point)
    local size = part.Size
    local position = part.Position
    
    local minX = position.X - size.X / 2
    local maxX = position.X + size.X / 2
    local minY = position.Y - size.Y / 2
    local maxY = position.Y + size.Y / 2
    local minZ = position.Z - size.Z / 2
    local maxZ = position.Z + size.Z / 2
    
    if point.X > minX and point.X < maxX and 
       point.Y > minY and point.Y < maxY and 
       point.Z > minZ and point.Z < maxZ then
        return true
    end
    return false
end

local function isPositionInsidePart(position)
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Whitelist
    params.FilterDescendantsInstances = { Workspace.Map }
    
    local parts = workspace:GetPartBoundsInRadius(position, 20, params)
    
    for i = 1, #parts do
        local part = parts[i]
        if part:IsA("Part") and part.CanCollide == true and isPointInsidePart(part, position) then
            return true
        end
    end
    return false
end

local function checkVisibility()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {player.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            raycastParams.IgnoreWater = true
            local result = workspace:Raycast(player.Character.Head.Position, 
                (Character.PrimaryPart.Position - player.Character.Head.Position).Unit * 70)
            if result and result.Instance:IsDescendantOf(Character) then
                return true
            end
        end
    end
    return false
end

---------------------------------------------------------------------
-- UPDATE CHARACTER REFERENCE
---------------------------------------------------------------------

local function UpdateCharacterReferences()
    Character = LocalPlayer.Character
    if Character then
        Humanoid = Character:FindFirstChild("Humanoid")
        HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    end
    return Character and Humanoid and HumanoidRootPart
end

---------------------------------------------------------------------
-- MAIN WALK FUNCTION
---------------------------------------------------------------------

-- Walk to a destination (CFrame, Vector3, or BasePart)
function WalkToSystem.WalkTo(Destination, Options)
    Options = Options or {}
    local ShowVisuals = Options.ShowVisuals ~= false
    local AutoJump = Options.AutoJump ~= false
    local SkipInvalidWaypoints = Options.SkipInvalidWaypoints ~= false
    local AntiStuck = Options.AntiStuck ~= false
    
    -- Update character references
    if not UpdateCharacterReferences() then
        warn("[WalkToSystem] Character not found")
        return false
    end
    
    -- Get destination position
    local DestinationPosition
    if typeof(Destination) == "CFrame" then
        DestinationPosition = Destination.Position
    elseif typeof(Destination) == "Vector3" then
        DestinationPosition = Destination
    elseif Destination:IsA("BasePart") then
        DestinationPosition = Destination.Position
    else
        warn("[WalkToSystem] Invalid destination type")
        return false
    end
    
    -- Clear previous path visuals
    ClearVisualPoints()
    
    -- Create path
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 4,
        AgentCanJump = true,
        AgentCanClimb = true
    })
    
    local success, errorMessage = pcall(function()
        path:ComputeAsync(HumanoidRootPart.Position, DestinationPosition)
    end)
    
    if not success or path.Status ~= Enum.PathStatus.Success then
        warn("[WalkToSystem] No path found to destination")
        return false
    end
    
    CurrentPath = path
    CurrentlyPathing = true
    
    -- Create visual waypoints
    if ShowVisuals then
        for i, v in pairs(CurrentPath:GetWaypoints()) do
            CreateVisualPoint(v.Position)
        end
    end
    
    local waypoints = CurrentPath:GetWaypoints()
    local TimesFailed = 0
    local SkipNext = false
    
    -- Anti-stuck loop
    if AntiStuck then
        task.spawn(function()
            while task.wait(0.5) and CurrentlyPathing == true do
                if TimesFailed >= 2 then
                    repeat task.wait() until not checkVisibility()
                    print("[WalkToSystem] Stuck, teleporting to next waypoint")
                    Character:PivotTo(CFrame.new(CurrentWaypoint.Position + Vector3.new(0, 4, 0)))
                    Humanoid:MoveTo(CurrentWaypoint.Position)
                    TimesFailed = 0
                end
                
                if HumanoidRootPart and (HumanoidRootPart.Velocity).Magnitude < 0.07 then
                    Humanoid:MoveTo(CurrentWaypoint.Position)
                    task.wait(0.2)
                    if (HumanoidRootPart.Velocity).Magnitude < 0.07 then
                        local targetPosition = CurrentWaypoint.Position
                        local charPosition = HumanoidRootPart.Position
                        local dx = targetPosition.X - charPosition.X
                        local dz = targetPosition.Z - charPosition.Z
                        local distance = math.sqrt(dx * dx + dz * dz)
                        if distance < 3 and not checkVisibility() then
                            print("[WalkToSystem] Stuck, teleporting to waypoint")
                            Character:PivotTo(CFrame.new(CurrentWaypoint.Position + Vector3.new(0, 4, 0)))
                            Humanoid:MoveTo(CurrentWaypoint.Position)
                            TimesFailed = 0
                        else
                            TimesFailed = TimesFailed + 1
                            Humanoid.Jump = true
                            task.wait()
                            Humanoid:MoveTo(CurrentWaypoint.Position)
                        end
                    end
                else
                    TimesFailed = 0
                end
            end
        end)
    end
    
    -- Walk through waypoints
    for i, v in pairs(waypoints) do
        if not CurrentlyPathing then
            break
        end
        
        if ShowVisuals and VisualFolder and VisualFolder[tostring(v.Position)] then
            UpdateVisualPoint(VisualFolder[tostring(v.Position)].SelectionSphere, false, Color3.new(0.0980392, 1, 0))
        end
        
        if not SkipNext then
            CurrentWaypoint = v
            Humanoid:MoveTo(v.Position)
            
            -- Wait to reach waypoint
            repeat 
                task.wait() 
            until not CurrentlyPathing or (HumanoidRootPart.Position - v.Position).Magnitude < 3.8
            
            -- Handle jump waypoints
            if AutoJump and waypoints[i + 1] and waypoints[i + 1].Action == Enum.PathWaypointAction.Jump then
                task.spawn(function()
                    task.wait(0.1)
                    Humanoid.Jump = true
                end)
            end
            
            -- Check if next waypoint is inside a part (skip it)
            if SkipInvalidWaypoints and waypoints[i + 1] and isPositionInsidePart(waypoints[i + 1].Position + Vector3.new(0, 2, 0)) then
                SkipNext = true
            end
            
            -- Callback
            if Options.OnWaypointReached then
                Options.OnWaypointReached(v, i)
            end
        elseif SkipNext then
            SkipNext = false
        end
        
        if ShowVisuals and VisualFolder and VisualFolder[tostring(v.Position)] then
            UpdateVisualPoint(VisualFolder[tostring(v.Position)].SelectionSphere, true)
        end
    end
    
    CurrentlyPathing = false
    
    if Options.OnPathComplete then
        Options.OnPathComplete()
    end
    
    return true
end

---------------------------------------------------------------------
-- WALK TO PREDEFINED LOCATION
---------------------------------------------------------------------

-- Walk to a named location
function WalkToSystem.WalkToLocation(locationName, Options)
    local targetCFrame = Locations[locationName]
    
    if not targetCFrame then
        -- Try case-insensitive match
        for name, cframe in pairs(Locations) do
            if string.lower(name) == string.lower(locationName) then
                targetCFrame = cframe
                break
            end
        end
    end
    
    if not targetCFrame then
        local available = {}
        for name, _ in pairs(Locations) do
            table.insert(available, name)
        end
        warn("[WalkToSystem] Location not found: " .. locationName .. ". Available: " .. table.concat(available, ", "))
        return false
    end
    
    return WalkToSystem.WalkTo(targetCFrame, Options)
end

---------------------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------------------

-- Cancel current movement
function WalkToSystem.Cancel()
    CurrentlyPathing = false
    if Humanoid then
        Humanoid:MoveTo(HumanoidRootPart and HumanoidRootPart.Position or Vector3.zero)
    end
    ClearVisualPoints()
    return true
end

-- Check if currently moving
function WalkToSystem.IsMoving()
    return CurrentlyPathing
end

-- Get current waypoint (for UI)
function WalkToSystem.GetCurrentWaypoint()
    return CurrentWaypoint
end

-- Check if path exists to a destination
function WalkToSystem.CanReach(Destination)
    if not UpdateCharacterReferences() then
        return false
    end
    
    local DestPos
    if typeof(Destination) == "CFrame" then
        DestPos = Destination.Position
    elseif typeof(Destination) == "Vector3" then
        DestPos = Destination
    elseif Destination:IsA("BasePart") then
        DestPos = Destination.Position
    elseif type(Destination) == "string" then
        local locCFrame = Locations[Destination]
        if locCFrame then
            DestPos = locCFrame.Position
        else
            return false
        end
    else
        return false
    end
    
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 4,
        AgentCanJump = true,
        AgentCanClimb = true
    })
    
    local success = pcall(function()
        path:ComputeAsync(HumanoidRootPart.Position, DestPos)
    end)
    
    return success and path.Status == Enum.PathStatus.Success
end

-- Get all available location names
function WalkToSystem.GetLocations()
    local locations = {}
    for name, _ in pairs(Locations) do
        table.insert(locations, name)
    end
    return locations
end

-- Add a custom location
function WalkToSystem.AddLocation(name, cframe)
    Locations[name] = cframe
    return true
end

---------------------------------------------------------------------
-- CLEANUP
---------------------------------------------------------------------

function WalkToSystem.Destroy()
    WalkToSystem.Cancel()
    if VisualFolder then
        VisualFolder:Destroy()
        VisualFolder = nil
    end
end

---------------------------------------------------------------------
-- GLOBAL EXPORTS
---------------------------------------------------------------------

if _G then
    _G.WalkTo = WalkToSystem.WalkTo
    _G.WalkToLocation = WalkToSystem.WalkToLocation
    _G.CancelWalk = WalkToSystem.Cancel
    _G.IsWalking = WalkToSystem.IsMoving
    _G.WalkToSystem = WalkToSystem
end

return WalkToSystem
