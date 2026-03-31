---------------------------------------------------------------------
-- WALK TO SYSTEM (Based on Auto-Farm Script)
-- Uses Roblox PathfindingService with Humanoid:MoveTo
-- Includes anti-stuck teleport fallback and visual waypoints
-- Falls back to native ClickToMove pathfinding if no path found
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

-- Tween info for visual effects
local TweenI = TweenInfo.new(1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

---------------------------------------------------------------------
-- PREDEFINED LOCATIONS (from auto-farm map)
---------------------------------------------------------------------

local Locations = {
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
            task.wait(1)
            Point.Parent:Destroy()
        else
            TweenService:Create(Point, TweenI, {Color3 = Color}):Play()
        end
    end)
end

local function ClearVisualPoints()
    if VisualFolder then
        for _, v in pairs(VisualFolder:GetChildren()) do
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

    return point.X > minX and point.X < maxX
        and point.Y > minY and point.Y < maxY
        and point.Z > minZ and point.Z < maxZ
end

local function isPositionInsidePart(position)
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Whitelist

    local mapChildren = {}
    for _, child in pairs(Workspace.Map:GetChildren()) do
        if child.Name ~= "Doors" and child.Name ~= "BredMakurz" then
            table.insert(mapChildren, child)
        end
    end
    params.FilterDescendantsInstances = mapChildren

    local parts = workspace:GetPartBoundsInRadius(position, 20, params)

    for _, part in pairs(parts) do
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
            local result = workspace:Raycast(
                player.Character.Head.Position,
                (Character.PrimaryPart.Position - player.Character.Head.Position).Unit * 70
            )
            if result and result.Instance:IsDescendantOf(Character) then
                return true
            end
        end
    end
    return false
end

---------------------------------------------------------------------
-- UPDATE CHARACTER REFERENCES
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
-- NATIVE CLICKTOMOVE FALLBACK
-- Extracted from Roblox's ClickToMove implementation.
-- Only activates when custom PathfindingService fails to find a path.
-- Automatically moves to destination without requiring user input.
---------------------------------------------------------------------

local function NativeFallbackWalkTo(DestinationPosition, Options)
    Options = Options or {}
    print("[WalkToSystem] Custom path failed, using native ClickToMove fallback")

    local XZ_VECTOR3 = Vector3.new(1, 0, 1)

    -- Occlusion check: is there a clear line between two points?
    local function CheckOcclusion(point1, point2)
        local diffVector = point2 - point1
        local directionVector = diffVector.Unit
        local torsoRadius = Vector3.new(
            HumanoidRootPart.Size.X / 2, 0, HumanoidRootPart.Size.Z / 2
        )
        local rightVector = Vector3.new(0, 1, 0):Cross(directionVector) * torsoRadius

        local function doRay(origin, direction)
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = {Character}
            params.FilterType = Enum.RaycastFilterType.Blacklist
            return workspace:Raycast(origin, direction, params)
        end

        if doRay(point1 + rightVector, diffVector + rightVector) then return false end
        if doRay(point1, diffVector) then return false end
        if doRay(point1 - rightVector, diffVector - rightVector) then return false end

        -- Make sure there's ground to walk on between the two points
        local studsBetweenSamples = 2
        for i = 1, math.floor(diffVector.Magnitude / studsBetweenSamples) do
            local samplePoint = point1 + directionVector * i * studsBetweenSamples
            local downParams = RaycastParams.new()
            downParams.FilterDescendantsInstances = {Character}
            downParams.FilterType = Enum.RaycastFilterType.Blacklist
            if not workspace:Raycast(samplePoint, Vector3.new(0, -7, 0), downParams) then
                return false
            end
        end

        return true
    end

    -- Try a direct straight-line path first (ClickToMove DirectPath logic)
    local function TryDirectPath()
        local startPt = HumanoidRootPart.Position
        local finishPt = DestinationPosition
        local diff = finishPt - startPt

        if diff.Magnitude < 150 then
            -- Step back 2 studs so we don't collide with the target object
            finishPt = finishPt - diff.Unit * 2
            if CheckOcclusion(startPt, finishPt) then
                return {finishPt}
            end
        end
        return nil
    end

    -- Compute path using native PathfindingService with ClosestNoPath fallback
    local function ComputeNativePath()
        local path = PathfindingService:CreatePath({
            AgentRadius = 2,
            AgentHeight = 4,
            AgentCanJump = true,
            AgentCanClimb = true,
        })

        local startPos = HumanoidRootPart.Position - Vector3.new(0, 3, 0)

        local success = pcall(function()
            path:ComputeAsync(startPos, DestinationPosition)
        end)

        if not success then return nil end

        -- Accept ClosestNoPath if waypoints got us reasonably close
        if path.Status == Enum.PathStatus.Success or path.Status == Enum.PathStatus.ClosestNoPath then
            local waypoints = path:GetWaypoints()
            if #waypoints > 0 then
                return waypoints
            end
        end

        -- FailStartNotEmpty: try neighboring cells as alternate start points
        if path.Status == Enum.PathStatus.FailStartNotEmpty then
            local roundedPos = Vector3.new(
                math.floor((HumanoidRootPart.Position.X - 2) / 4 + 0.5) * 4 + 2,
                math.floor((HumanoidRootPart.Position.Y - 2) / 4 + 0.5) * 4 + 2,
                math.floor((HumanoidRootPart.Position.Z - 2) / 4 + 0.5) * 4 + 2
            )
            local offsets = {
                Vector3.new(-4, 0, -4), Vector3.new(-4, 0, 4),
                Vector3.new(4, 0, -4),  Vector3.new(4, 0, 4),
            }
            for _, offset in pairs(offsets) do
                local altStart = roundedPos + offset
                local altPath = PathfindingService:CreatePath({
                    AgentRadius = 2, AgentHeight = 4,
                    AgentCanJump = true, AgentCanClimb = true,
                })
                local altSuccess = pcall(function()
                    altPath:ComputeAsync(altStart, DestinationPosition)
                end)
                if altSuccess and altPath.Status == Enum.PathStatus.Success then
                    local waypoints = altPath:GetWaypoints()
                    if #waypoints > 0 then
                        return waypoints
                    end
                end
            end
        end

        return nil
    end

    -- Smooth path by removing unnecessary intermediate waypoints
    local function SmoothWaypoints(waypointList)
        local positions = {}
        for _, wp in pairs(waypointList) do
            table.insert(positions, wp.Position)
        end

        local i = #positions - 1
        while i >= 2 do
            local prev = positions[i - 1]
            local curr = positions[i]
            local next = positions[i + 1]
            -- If prev, curr, next are all at the same Y and line of sight is clear, remove curr
            if math.abs(curr.Y - prev.Y) < 0.1 and math.abs(curr.Y - next.Y) < 0.1 then
                if CheckOcclusion(prev, next) then
                    table.remove(positions, i)
                end
            end
            i -= 1
        end

        return positions
    end

    -- Walk through a flat list of Vector3 positions (native fallback movement)
    local function WalkPositions(positions)
        CurrentlyPathing = true

        local TimesFailed = 0

        -- Reuse same anti-stuck logic
        task.spawn(function()
            while task.wait(0.5) and CurrentlyPathing do
                if TimesFailed >= 2 then
                    repeat task.wait() until not checkVisibility()
                    print("[WalkToSystem] Fallback anti-stuck: teleporting")
                    Character:PivotTo(CFrame.new(CurrentWaypoint.Position + Vector3.new(0, 4, 0)))
                    Humanoid:MoveTo(CurrentWaypoint.Position)
                    TimesFailed = 0
                    continue
                end

                if HumanoidRootPart and HumanoidRootPart.Velocity.Magnitude < 0.07 then
                    Humanoid:MoveTo(CurrentWaypoint.Position)
                    task.wait(0.2)
                    if HumanoidRootPart.Velocity.Magnitude < 0.07 then
                        local dist = (CurrentWaypoint.Position - HumanoidRootPart.Position)
                        local xzDist = Vector3.new(dist.X, 0, dist.Z).Magnitude
                        if xzDist < 3 and not checkVisibility() then
                            Character:PivotTo(CFrame.new(CurrentWaypoint.Position + Vector3.new(0, 4, 0)))
                            Humanoid:MoveTo(CurrentWaypoint.Position)
                            TimesFailed = 0
                        else
                            TimesFailed += 1
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

        for _, pos in pairs(positions) do
            if not CurrentlyPathing then break end

            -- Wrap position into a fake waypoint table so anti-stuck can read .Position
            CurrentWaypoint = {Position = pos}
            Humanoid:MoveTo(pos)

            local waypointTimer = 0
            repeat
                task.wait(0.1)
                waypointTimer += 0.1

                -- Auto-jump if we need to go upward (from ClickToMove YieldUntilPointReached)
                local diff = pos - HumanoidRootPart.Position
                local xzMag = Vector3.new(diff.X, 0, diff.Z).Magnitude
                if xzMag < 6 and diff.Y >= 2.2 then
                    Humanoid.Jump = true
                end

                if waypointTimer >= 20 then
                    TimesFailed += 2
                    print("[WalkToSystem] Fallback waypoint timeout, triggering anti-stuck")
                    break
                end
            until not CurrentlyPathing or (HumanoidRootPart.Position - pos).Magnitude < 3.8
        end

        CurrentlyPathing = false

        if Options.OnPathComplete then
            Options.OnPathComplete()
        end

        return true
    end

    -- Try direct path first, then full native compute
    local directPositions = TryDirectPath()
    if directPositions then
        print("[WalkToSystem] Fallback: using direct line path")
        return WalkPositions(directPositions)
    end

    local nativeWaypoints = ComputeNativePath()
    if nativeWaypoints then
        print("[WalkToSystem] Fallback: using native computed path")
        local smoothed = SmoothWaypoints(nativeWaypoints)
        return WalkPositions(smoothed)
    end

    warn("[WalkToSystem] Fallback also failed, no path available")
    return false
end

---------------------------------------------------------------------
-- MAIN WALK FUNCTION
---------------------------------------------------------------------

function WalkToSystem.WalkTo(Destination, Options)
    Options = Options or {}
    local ShowVisuals = Options.ShowVisuals ~= false
    local AutoJump = Options.AutoJump ~= false
    local SkipInvalidWaypoints = Options.SkipInvalidWaypoints ~= false
    local AntiStuck = Options.AntiStuck ~= false

    if not UpdateCharacterReferences() then
        warn("[WalkToSystem] Character not found")
        return false
    end

    -- Resolve destination to Vector3
    local DestinationPosition
    if typeof(Destination) == "CFrame" then
        DestinationPosition = Destination.Position
    elseif typeof(Destination) == "Vector3" then
        DestinationPosition = Destination
    elseif typeof(Destination) == "Instance" and Destination:IsA("BasePart") then
        DestinationPosition = Destination.Position
    else
        warn("[WalkToSystem] Invalid destination type")
        return false
    end

    ClearVisualPoints()

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 4,
        AgentCanJump = true,
        AgentCanClimb = true,
    })

    local success = pcall(function()
        path:ComputeAsync(HumanoidRootPart.Position, DestinationPosition)
    end)

    -- Primary path failed: hand off to native fallback
    if not success or path.Status ~= Enum.PathStatus.Success then
        warn("[WalkToSystem] Primary path failed, attempting native fallback")
        return NativeFallbackWalkTo(DestinationPosition, Options)
    end

    CurrentPath = path
    CurrentlyPathing = true

    local waypoints = CurrentPath:GetWaypoints()

    if ShowVisuals then
        for _, v in pairs(waypoints) do
            CreateVisualPoint(v.Position)
        end
    end

    local TimesFailed = 0
    local SkipNext = false

    if AntiStuck then
        task.spawn(function()
            while task.wait(0.5) and CurrentlyPathing do

                if TimesFailed >= 2 then
                    repeat task.wait() until not checkVisibility()
                    print("[WalkToSystem] Anti-stuck: teleporting to waypoint")
                    Character:PivotTo(CFrame.new(CurrentWaypoint.Position + Vector3.new(0, 4, 0)))
                    Humanoid:MoveTo(CurrentWaypoint.Position)
                    TimesFailed = 0
                    continue
                end

                if HumanoidRootPart and HumanoidRootPart.Velocity.Magnitude < 0.07 then
                    Humanoid:MoveTo(CurrentWaypoint.Position)
                    task.wait(0.2)
                    if HumanoidRootPart.Velocity.Magnitude < 0.07 then
                        local targetPosition = CurrentWaypoint.Position
                        local charPosition = HumanoidRootPart.Position
                        local dx = targetPosition.X - charPosition.X
                        local dz = targetPosition.Z - charPosition.Z
                        local distance = math.sqrt(dx * dx + dz * dz)
                        if distance < 3 and not checkVisibility() then
                            print("[WalkToSystem] Anti-stuck: close but stuck, teleporting")
                            Character:PivotTo(CFrame.new(CurrentWaypoint.Position + Vector3.new(0, 4, 0)))
                            Humanoid:MoveTo(CurrentWaypoint.Position)
                            TimesFailed = 0
                        else
                            TimesFailed += 1
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

    for i, v in pairs(waypoints) do
        if not CurrentlyPathing then break end

        if ShowVisuals and VisualFolder and VisualFolder:FindFirstChild(tostring(v.Position)) then
            UpdateVisualPoint(VisualFolder[tostring(v.Position)].SelectionSphere, false, Color3.new(0.098, 1, 0))
        end

        if not SkipNext then
            CurrentWaypoint = v
            Humanoid:MoveTo(v.Position)

            local waypointTimer = 0
            repeat
                task.wait(0.1)
                waypointTimer += 0.1
                if waypointTimer >= 20 then
                    TimesFailed += 2
                    print("[WalkToSystem] Waypoint timeout (20s), triggering anti-stuck")
                    break
                end
            until not CurrentlyPathing or (HumanoidRootPart.Position - v.Position).Magnitude < 3.8

            if AutoJump and waypoints[i + 1] and waypoints[i + 1].Action == Enum.PathWaypointAction.Jump then
                task.spawn(function()
                    task.wait(0.1)
                    Humanoid.Jump = true
                end)
            end

            if SkipInvalidWaypoints and waypoints[i + 1] and isPositionInsidePart(waypoints[i + 1].Position + Vector3.new(0, 2, 0)) then
                SkipNext = true
            end

            if Options.OnWaypointReached then
                Options.OnWaypointReached(v, i)
            end
        else
            SkipNext = false
        end

        if ShowVisuals and VisualFolder and VisualFolder:FindFirstChild(tostring(v.Position)) then
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

function WalkToSystem.WalkToLocation(locationName, Options)
    local targetCFrame = Locations[locationName]

    if not targetCFrame then
        for name, cframe in pairs(Locations) do
            if string.lower(name) == string.lower(locationName) then
                targetCFrame = cframe
                break
            end
        end
    end

    if not targetCFrame then
        local available = {}
        for name in pairs(Locations) do
            table.insert(available, name)
        end
        warn("[WalkToSystem] Location not found: " .. locationName .. ". Available: " .. table.concat(available, ", "))
        return false
    end

    return WalkToSystem.WalkTo(targetCFrame, Options)
end

---------------------------------------------------------------------
-- PUBLIC API
---------------------------------------------------------------------

function WalkToSystem.Cancel()
    CurrentlyPathing = false
    if Humanoid then
        Humanoid:MoveTo(HumanoidRootPart and HumanoidRootPart.Position or Vector3.zero)
    end
    ClearVisualPoints()
    return true
end

function WalkToSystem.IsMoving()
    return CurrentlyPathing
end

function WalkToSystem.GetCurrentWaypoint()
    return CurrentWaypoint
end

function WalkToSystem.CanReach(Destination)
    if not UpdateCharacterReferences() then return false end

    local DestPos
    if typeof(Destination) == "CFrame" then
        DestPos = Destination.Position
    elseif typeof(Destination) == "Vector3" then
        DestPos = Destination
    elseif typeof(Destination) == "Instance" and Destination:IsA("BasePart") then
        DestPos = Destination.Position
    elseif type(Destination) == "string" then
        local locCFrame = Locations[Destination]
        if locCFrame then DestPos = locCFrame.Position else return false end
    else
        return false
    end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 4,
        AgentCanJump = true,
        AgentCanClimb = true,
    })

    local success = pcall(function()
        path:ComputeAsync(HumanoidRootPart.Position, DestPos)
    end)

    return success and path.Status == Enum.PathStatus.Success
end

function WalkToSystem.GetLocations()
    local locations = {}
    for name in pairs(Locations) do
        table.insert(locations, name)
    end
    return locations
end

function WalkToSystem.AddLocation(name, cframe)
    Locations[name] = cframe
    return true
end

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
