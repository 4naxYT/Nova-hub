---------------------------------------------------------------------
-- WALK TO SYSTEM : Custom
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
local DEFAULT_WAYPOINT_SPACING = 3 -- Can be adjusted globally
local CurrentlyPathing = false
local CurrentPath = nil
local CurrentWaypoint = nil
local VisualFolder = nil

-- Tween info for visual effects
local TweenI = TweenInfo.new(1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

---------------------------------------------------------------------
-- PREDEFINED LOCATIONS
---------------------------------------------------------------------

local Locations = {
    Cafe       = CFrame.new(-4599.47, 3.89,  -296.98),
    Subway     = CFrame.new(-4590.86, 3.65,  -694.64),
    Motel      = CFrame.new(-4619.04, 5.33,  -897.38),
    Tower      = CFrame.new(-4490.34, 3.29,  -759.60),
    Factory    = CFrame.new(-4305.15, 3.93,  -609.54),
    Pizza      = CFrame.new(-4373.28, 4,     -174.13),
    Junk_Yard  = CFrame.new(-3852.35, 3.89,  -361.91),
    Basket_Ball= CFrame.new(-4830.70, 3.60,  -241.91),
}

---------------------------------------------------------------------
-- VISUAL WAYPOINTS - FIXED
---------------------------------------------------------------------

-- Store all active visual markers
local ActiveVisualMarkers = {}

local function CreateVisualPoint(Position)
    if not VisualFolder then
        VisualFolder = Instance.new("Folder", Workspace)
        VisualFolder.Name = "Pathfinding API - Waypoint Visuals"
    end
    
    local A = Instance.new("Part")
    local B = Instance.new("SelectionSphere")
    A.Anchored = true
    A.CanCollide = false
    A.Size = Vector3.new(0.8, 0.8, 0.8) -- Larger size
    A.Position = Position + Vector3.new(0, 3, 0)
    A.Transparency = 1
    A.BrickColor = BrickColor.new("Bright red")
    A.Material = Enum.Material.Neon
    A.Parent = VisualFolder
    A.Name = tostring(Position) .. "_" .. tostring(tick())
    
    B.Transparency = 0
    B.Parent = A
    B.Adornee = A
    B.Color3 = Color3.new(1, 0, 0)
    
    -- Add a beam for visibility
    local beam = Instance.new("Part")
    beam.Anchored = true
    beam.CanCollide = false
    beam.Size = Vector3.new(0.3, 6, 0.3)
    beam.Position = Position + Vector3.new(0, 1.5, 0)
    beam.Transparency = 0.8
    beam.BrickColor = BrickColor.new("Bright red")
    beam.Material = Enum.Material.Neon
    beam.Parent = A
    
    -- Store marker info
    local markerInfo = {
        Part = A,
        Sphere = B,
        Beam = beam,
        Position = Position,
        Created = tick()
    }
    table.insert(ActiveVisualMarkers, markerInfo)
    
    return A
end

local function UpdateVisualPoint(markerPart, IsComplete, Color)
    if not markerPart or not markerPart.Parent then return end
    
    local sphere = markerPart:FindFirstChild("SelectionSphere")
    local beam = markerPart:FindFirstChildWhichIsA("Part")
    
    task.spawn(function()
        if IsComplete then
            -- Change to green when completed
            if sphere then
                TweenService:Create(sphere, TweenInfo.new(0.5), {Color3 = Color3.new(0, 1, 0)}):Play()
            end
            if beam then
                TweenService:Create(beam, TweenInfo.new(0.5), {BrickColor = BrickColor.new("Bright green")}):Play()
            end
            
            -- Fade out after 2 seconds
            task.wait(2)
            if sphere then
                TweenService:Create(sphere, TweenInfo.new(0.5), {Transparency = 1}):Play()
            end
            if beam then
                TweenService:Create(beam, TweenInfo.new(0.5), {Transparency = 1}):Play()
            end
            TweenService:Create(markerPart, TweenInfo.new(0.5), {Transparency = 1}):Play()
            task.wait(0.5)
            markerPart:Destroy()

            
            -- Remove from active markers
            for i, marker in pairs(ActiveVisualMarkers) do
                if marker.Part == markerPart then
                    table.remove(ActiveVisualMarkers, i)
                    break
                end
            end
        else
            -- Highlight current waypoint
            if sphere then
                TweenService:Create(sphere, TweenInfo.new(0.3), {Color3 = Color or Color3.new(0, 1, 0)}):Play()
            end
            if beam then
                TweenService:Create(beam, TweenInfo.new(0.3), {BrickColor = BrickColor.new("Bright green")}):Play()
            end
            TweenService:Create(markerPart, TweenInfo.new(0.3), {Transparency = 0}):Play()
        end
    end)
end

local function ClearVisualPoints()
    for _, marker in pairs(ActiveVisualMarkers) do
        if marker.Part and marker.Part.Parent then
            local sphere = marker.Part:FindFirstChild("SelectionSphere")
            local beam = marker.Part:FindFirstChildWhichIsA("Part")
            task.spawn(function()  -- spawn so no yielding in the main loop
                if sphere then
                    TweenService:Create(sphere, TweenInfo.new(0.5), {Transparency = 1}):Play()
                end
                if beam then
                    TweenService:Create(beam, TweenInfo.new(0.5), {Transparency = 1}):Play()
                end
                TweenService:Create(marker.Part, TweenInfo.new(0.5), {Transparency = 1}):Play()
                task.wait(0.5)
                if marker.Part and marker.Part.Parent then
                    marker.Part:Destroy()
                end
            end)
        end
    end
    ActiveVisualMarkers = {}
end

-- New function to only clear completed visuals (for fallback)
local function ClearCompletedVisuals()
    for i = #ActiveVisualMarkers, 1, -1 do
        local marker = ActiveVisualMarkers[i]
        if marker and marker.Part and marker.Part.Parent then
            -- Check if this marker is old (more than 30 seconds)
            if tick() - marker.Created > 30 then
                if marker.Part:FindFirstChild("SelectionSphere") then
                    UpdateVisualPoint(marker.Part, true)
                end
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
    return point.X > position.X - size.X/2 and point.X < position.X + size.X/2
       and point.Y > position.Y - size.Y/2 and point.Y < position.Y + size.Y/2
       and point.Z > position.Z - size.Z/2 and point.Z < position.Z + size.Z/2
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
-- Based on Roblox's updated 2017 ClickToMove (Garnold revision).
-- Uses FindPathAsync + MoveToFinished event-driven traversal,
-- with surface normal ground-snap retry and short-range direct walk.
-- Only activates when the primary custom path fails entirely.
-- Now includes visual waypoints support!
---------------------------------------------------------------------

local function NativeFallbackWalkTo(DestinationPosition, Options)
    Options = Options or {}
    local ShowVisuals = Options.ShowVisuals ~= false
    local VisualMarkers = {} -- Track visual markers for this fallback path
    
    print("[WalkToSystem] Primary path failed — engaging native fallback")

    -- Helper to clear fallback visuals
    local function ClearFallbackVisuals()
        for _, marker in pairs(VisualMarkers) do
            if marker and marker.Parent then
                -- Don't destroy immediately, fade out
                local sphere = marker:FindFirstChild("SelectionSphere")
                if sphere then
                    UpdateVisualPoint(sphere, true)
                end
            end
        end
        VisualMarkers = {}
    end

    -- Helper to create fallback visuals
    local function CreateFallbackVisuals(waypoints)
        if not ShowVisuals then return end
        ClearFallbackVisuals()
        for _, v in pairs(waypoints) do
            if v.Position then
                local marker = CreateVisualPoint(v.Position)
                -- Store the marker for later updates
                if VisualFolder and VisualFolder:FindFirstChild(tostring(v.Position)) then
                    table.insert(VisualMarkers, VisualFolder[tostring(v.Position)])
                end
            end
        end
    end

    -- Helper to update visual marker for current waypoint
    local function UpdateFallbackVisualCurrent(position)
        if not ShowVisuals or not VisualFolder then return end
        local marker = VisualFolder:FindFirstChild(tostring(position))
        if marker and marker:FindFirstChild("SelectionSphere") then
            UpdateVisualPoint(marker.SelectionSphere, false, Color3.new(0.098, 1, 0))
        end
    end

    -- Helper to mark a waypoint as completed
    local function MarkFallbackVisualComplete(position)
        if not ShowVisuals or not VisualFolder then return end
        local marker = VisualFolder:FindFirstChild(tostring(position))
        if marker and marker:FindFirstChild("SelectionSphere") then
            UpdateVisualPoint(marker.SelectionSphere, true)
        end
        -- Remove from tracking
        for i, m in pairs(VisualMarkers) do
            if m == marker then
                table.remove(VisualMarkers, i)
                break
            end
        end
    end

    -- Try to ground-snap the destination using a surface normal offset,
    -- same as ClickToMove does when PathComputed fails on first attempt.
    local function TryGroundSnap(targetPoint, surfaceNormal)
        surfaceNormal = surfaceNormal or Vector3.new(0, 1, 0)
        local offsetPoint = targetPoint + surfaceNormal * 1.5
        local ray = Ray.new(offsetPoint, Vector3.new(0, -1, 0) * 50)
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = {Character}
        params.FilterType = Enum.RaycastFilterType.Blacklist
        local result = workspace:Raycast(offsetPoint, Vector3.new(0, -50, 0), params)
        if result then
            return result.Position
        end
        return targetPoint
    end

    -- FindPathAsync-based path compute, mirroring the 2017 Pather:ComputePath().
    -- Returns a waypoint list or nil. Retries once with a ground-snapped point.
    local function ComputeNativePath(targetPoint)
        local function tryCompute(dest)
            local pathResult = nil
            local ok = pcall(function()
                pathResult = PathfindingService:FindPathAsync(
                    HumanoidRootPart.CFrame.Position, dest
                )
            end)
            if ok and pathResult and pathResult.Status == Enum.PathStatus.Success then
                local wps = pathResult:GetWaypoints()
                if #wps > 0 then return wps end
            end
            return nil
        end

        -- First attempt
        local waypoints = tryCompute(targetPoint)
        if waypoints then 
            if ShowVisuals then
                CreateFallbackVisuals(waypoints)
            end
            return waypoints 
        end

        -- Retry with ground-snapped destination (ClickToMove fallback behavior)
        local snapped = TryGroundSnap(targetPoint)
        if snapped ~= targetPoint then
            waypoints = tryCompute(snapped)
            if waypoints then 
                if ShowVisuals then
                    CreateFallbackVisuals(waypoints)
                end
                return waypoints 
            end
        end

        return nil
    end

    -- Short range direct walk (ClickToMove: <25 studs, not too far down).
    -- Issues a single MoveTo and waits for MoveToFinished.
    local function TryDirectWalk(targetPoint)
        local diff = targetPoint - HumanoidRootPart.Position
        if diff.Magnitude < 25 and (HumanoidRootPart.Position.Y - targetPoint.Y) > -3 then
            print("[WalkToSystem] Fallback: direct short-range walk")
            CurrentlyPathing = true
            CurrentWaypoint = {Position = targetPoint}
            
            -- Create a single visual marker for direct walk
            if ShowVisuals then
                local marker = CreateVisualPoint(targetPoint)
                if marker and marker:FindFirstChild("SelectionSphere") then
                    UpdateVisualPoint(marker.SelectionSphere, false, Color3.new(0.098, 1, 0))
                end
            end

            if Humanoid.Sit then
                Humanoid.Jump = true
                task.wait(0.1)
            end

            local reached = false
            local conn
            conn = Humanoid.MoveToFinished:Connect(function(r)
                reached = r
                conn:Disconnect()
            end)

            Humanoid:MoveTo(targetPoint)

            -- Yield with timeout
            local t = 0
            repeat
                task.wait(0.1)
                t += 0.1
            until reached or not CurrentlyPathing or t >= 15

            -- Clean up direct walk visual
            if ShowVisuals and VisualFolder then
                local marker = VisualFolder:FindFirstChild(tostring(targetPoint))
                if marker and marker:FindFirstChild("SelectionSphere") then
                    UpdateVisualPoint(marker.SelectionSphere, true)
                end
            end

            CurrentlyPathing = false
            if Options.OnPathComplete then Options.OnPathComplete() end
            return true
        end
        return false
    end

    -- Event-driven waypoint traversal using MoveToFinished,
    -- matching the 2017 Pather:OnPointReached() logic exactly.
    -- Includes jump-action handling and freefall wait before jump waypoints.
    -- Event-driven waypoint traversal with 20-second timeout
    local function WalkWaypoints(waypointList)
        if #waypointList == 0 then return false end

        CurrentlyPathing = true
        local currentIndex = 1  -- skip index 0; first waypoint is always start
        local finished = false
        local failed = false
        local moveConn = nil
        local WaypointStartTime = tick()
        local WaypointTimerThread = nil

        local TimesFailed = 0

        -- Update initial waypoint visual
        if ShowVisuals and waypointList[currentIndex] then
            UpdateFallbackVisualCurrent(waypointList[currentIndex].Position)
        end
        
        -- Timer thread to check for 20-second timeout
        WaypointTimerThread = task.spawn(function()
            while CurrentlyPathing and not finished do
                task.wait(1)
                if WaypointStartTime and (tick() - WaypointStartTime) > 20 then
                    print("[WalkToSystem] Fallback: Waypoint timeout (20s) - teleporting")
                    if CurrentWaypoint then
                        Character:PivotTo(CFrame.new(CurrentWaypoint.Position + Vector3.new(0, 4, 0)))
                        Humanoid:MoveTo(CurrentWaypoint.Position)
                        WaypointStartTime = tick() -- Reset timer
                        TimesFailed = 0
                    end
                end
            end
        end)

        -- Anti-stuck: same logic as primary path
        local antiStuckThread = task.spawn(function()
            while task.wait(0.5) and CurrentlyPathing do
                if TimesFailed >= 2 then
                    repeat task.wait() until not checkVisibility()
                    print("[WalkToSystem] Fallback anti-stuck: teleporting")
                    if CurrentWaypoint then
                        Character:PivotTo(CFrame.new(CurrentWaypoint.Position + Vector3.new(0, 4, 0)))
                        Humanoid:MoveTo(CurrentWaypoint.Position)
                        WaypointStartTime = tick()
                        TimesFailed = 0
                    end
                    continue
                end
                if HumanoidRootPart and HumanoidRootPart.Velocity.Magnitude < 0.07 then
                    if CurrentWaypoint then Humanoid:MoveTo(CurrentWaypoint.Position) end
                    task.wait(0.2)
                    if HumanoidRootPart.Velocity.Magnitude < 0.07 and CurrentWaypoint then
                        local xzDist = Vector3.new(
                            CurrentWaypoint.Position.X - HumanoidRootPart.Position.X, 0,
                            CurrentWaypoint.Position.Z - HumanoidRootPart.Position.Z
                        ).Magnitude
                        if xzDist < 3 and not checkVisibility() then
                            Character:PivotTo(CFrame.new(CurrentWaypoint.Position + Vector3.new(0, 4, 0)))
                            Humanoid:MoveTo(CurrentWaypoint.Position)
                            WaypointStartTime = tick()
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

        -- MoveToFinished-driven traversal (2017 Pather pattern)
        local function moveToNext()
            -- Mark current waypoint as complete before moving to next
            if currentIndex <= #waypointList and ShowVisuals then
                MarkFallbackVisualComplete(waypointList[currentIndex].Position)
            end
            
            currentIndex += 1

            if currentIndex > #waypointList then
                finished = true
                return
            end

            local waypoint = waypointList[currentIndex]
            CurrentWaypoint = waypoint
            WaypointStartTime = tick() -- Reset timer for new waypoint
            
            -- Update visual for the new waypoint
            if ShowVisuals then
                UpdateFallbackVisualCurrent(waypoint.Position)
            end

            -- If next-next action is Jump, wait until grounded first
            -- (prevents jump flag being reset by state change)
            if currentIndex + 1 <= #waypointList then
                local nextAction = waypointList[currentIndex + 1].Action
                if nextAction == Enum.PathWaypointAction.Jump then
                    local state = Humanoid:GetState()
                    if state == Enum.HumanoidStateType.Freefall
                    or state == Enum.HumanoidStateType.Jumping
                    or state == Enum.HumanoidStateType.FallingDown then
                        Humanoid.FreeFalling:Wait()
                        task.wait(0.1)
                    end
                end
            end

            if waypoint.Action == Enum.PathWaypointAction.Jump then
                Humanoid.Jump = true
            end

            Humanoid:MoveTo(waypoint.Position)
        end

        -- Wire up MoveToFinished
        moveConn = Humanoid.MoveToFinished:Connect(function(reached)
            if not CurrentlyPathing then
                moveConn:Disconnect()
                return
            end
            if reached then
                TimesFailed = 0
                moveToNext()
            else
                -- MoveToFinished fired false = timed out (8s Roblox default)
                -- Increment stuck counter and retry current waypoint
                TimesFailed += 1
                if CurrentWaypoint then
                    Humanoid:MoveTo(CurrentWaypoint.Position)
                end
            end
        end)

        -- Start traversal from waypoint index 1 (index 0 is spawn, skip it)
        moveToNext()

        -- Yield until done, cancelled, or global timeout
        local totalTimer = 0
        local maxTime = #waypointList * 25  -- generous total budget
        repeat
            task.wait(0.1)
            totalTimer += 0.1
        until finished or not CurrentlyPathing or totalTimer >= maxTime

        -- Cleanup
        if moveConn then moveConn:Disconnect() end
        if WaypointTimerThread then task.cancel(WaypointTimerThread) end
        if antiStuckThread then task.cancel(antiStuckThread) end
        CurrentlyPathing = false
        
        -- Clear all remaining visuals
        if ShowVisuals then
            ClearFallbackVisuals()
        end

        if Options.OnPathComplete and finished then
            Options.OnPathComplete()
        end

        return finished
    end

    -- Fallback priority order:
    -- 1. Native FindPathAsync path (event-driven)
    -- 2. Short-range direct MoveTo (<25 studs)
    -- 3. Give up

    local waypoints = ComputeNativePath(DestinationPosition)
    if waypoints then
        print("[WalkToSystem] Fallback: using FindPathAsync event-driven path (" .. #waypoints .. " waypoints)")
        return WalkWaypoints(waypoints)
    end

    if TryDirectWalk(DestinationPosition) then
        return true
    end

    warn("[WalkToSystem] Fallback exhausted — no path available to destination")
    return false
end

---------------------------------------------------------------------
-- ADD INTERMEDIATE WAYPOINTS FOR SMOOTHER NAVIGATION
---------------------------------------------------------------------

local function AddIntermediateWaypoints(waypoints, spacing)
    if #waypoints < 2 then return waypoints end
    
    local newWaypoints = {}
    
    for i = 1, #waypoints - 1 do
        local current = waypoints[i]
        local nextWP = waypoints[i + 1]
        
        -- Always add the current waypoint
        table.insert(newWaypoints, current)
        
        -- Calculate distance between waypoints
        local distance = (nextWP.Position - current.Position).Magnitude
        
        -- If distance is greater than spacing, add intermediate points
        if distance > spacing then
            local steps = math.floor(distance / spacing)
            local stepVector = (nextWP.Position - current.Position) / steps
            
            for step = 1, steps - 1 do
                local intermediatePos = current.Position + (stepVector * step)
                -- Create a new waypoint with same action as the current
                local intermediateWP = {
                    Position = intermediatePos,
                    Action = current.Action
                }
                table.insert(newWaypoints, intermediateWP)
            end
        end
    end
    
    -- Add the final waypoint
    table.insert(newWaypoints, waypoints[#waypoints])
    
    print(string.format("[WalkToSystem] Added intermediate waypoints: %d -> %d", #waypoints, #newWaypoints))
    return newWaypoints
end

---------------------------------------------------------------------
-- MAIN WALK FUNCTION - ENHANCED WITH FREQUENT WAYPOINTS
---------------------------------------------------------------------

function WalkToSystem.WalkTo(Destination, Options)
    Options = Options or {}
    local ShowVisuals = Options.ShowVisuals ~= false
    local AutoJump = Options.AutoJump ~= false
    local SkipInvalidWaypoints = Options.SkipInvalidWaypoints ~= false
    local AntiStuck = Options.AntiStuck ~= false
    local WaypointFrequency = Options.WaypointFrequency or 3

    if not UpdateCharacterReferences() then
        warn("[WalkToSystem] Character not found")
        return false
    end

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

    -- Only clear if we're starting a new path (not if already pathing)
    ClearVisualPoints()

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 4,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = WaypointFrequency, -- Control waypoint density
    })

    local success = pcall(function()
        path:ComputeAsync(HumanoidRootPart.Position, DestinationPosition)
    end)

    -- Primary path failed: hand off to native fallback
    if not success or path.Status ~= Enum.PathStatus.Success then
        warn("[WalkToSystem] Primary path failed — handing off to native fallback")
        -- Pass WaypointFrequency to fallback as well
        Options.WaypointFrequency = WaypointFrequency
        return NativeFallbackWalkTo(DestinationPosition, Options)
    end

    CurrentPath = path
    CurrentlyPathing = true

    local waypoints = CurrentPath:GetWaypoints()
    
    -- OPTIONAL: Add intermediate waypoints for smoother navigation
    if WaypointFrequency < 10 then
        waypoints = AddIntermediateWaypoints(waypoints, WaypointFrequency)
    end

    if ShowVisuals then
        print(string.format("[WalkToSystem] Creating %d visual waypoints", #waypoints))
        for _, v in pairs(waypoints) do
            CreateVisualPoint(v.Position)
        end
    end

    local TimesFailed = 0
    local SkipNext = false
    local WaypointStartTime = nil -- Track when we started trying to reach current waypoint
    local AntiStuckThread = nil

    -- Enhanced anti-stuck with 20-second timeout per waypoint
    if AntiStuck then
        AntiStuckThread = task.spawn(function()
            while task.wait(0.5) and CurrentlyPathing do
                -- Check if we've been trying to reach the current waypoint for >20 seconds
                if WaypointStartTime and (tick() - WaypointStartTime) > 20 then
                    print("[WalkToSystem] Waypoint timeout (20s) - teleporting to next waypoint")
                    -- Teleport directly to current waypoint
                    if CurrentWaypoint then
                        Character:PivotTo(CFrame.new(CurrentWaypoint.Position + Vector3.new(0, 4, 0)))
                        Humanoid:MoveTo(CurrentWaypoint.Position)
                        WaypointStartTime = tick() -- Reset timer after teleport
                        TimesFailed = 0
                    end
                    continue
                end
                
                if TimesFailed >= 2 then
                    repeat task.wait() until not checkVisibility()
                    print("[WalkToSystem] Anti-stuck: teleporting to waypoint")
                    if CurrentWaypoint then
                        Character:PivotTo(CFrame.new(CurrentWaypoint.Position + Vector3.new(0, 4, 0)))
                        Humanoid:MoveTo(CurrentWaypoint.Position)
                        WaypointStartTime = tick() -- Reset timer after teleport
                        TimesFailed = 0
                    end
                    continue
                end
                
                if HumanoidRootPart and HumanoidRootPart.Velocity.Magnitude < 0.07 then
                    if CurrentWaypoint then 
                        Humanoid:MoveTo(CurrentWaypoint.Position) 
                    end
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
                            WaypointStartTime = tick() -- Reset timer after teleport
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

        -- Find the visual marker for this waypoint
        local visualMarker = nil
        for _, marker in pairs(ActiveVisualMarkers) do
            if (marker.Position - v.Position).Magnitude < 5 then
                visualMarker = marker.Part
                break
            end
        end

        if not SkipNext then
            CurrentWaypoint = v
            Humanoid:MoveTo(v.Position)
            WaypointStartTime = tick()

            -- Highlight current waypoint

            local waypointTimer = 0
            local reachedWaypoint = false
            
            repeat
                task.wait(0.1)
                waypointTimer += 0.1
                
                if (HumanoidRootPart.Position - v.Position).Magnitude < 3.8 then
                    reachedWaypoint = true
                    break
                end
                
                if waypointTimer >= 20 then
                    print("[WalkToSystem] Waypoint timeout (20s), triggering teleport")
                    break
                end
                
            until not CurrentlyPathing
            
            -- Mark waypoint as complete when reached
            if reachedWaypoint and visualMarker then
                UpdateVisualPoint(visualMarker, true) -- This will fade it out after 2 seconds
            end
            
            if not reachedWaypoint and CurrentlyPathing then
                print("[WalkToSystem] Teleporting to waypoint due to timeout")
                Character:PivotTo(CFrame.new(v.Position + Vector3.new(0, 4, 0)))
                Humanoid:MoveTo(v.Position)
                WaypointStartTime = tick()
            end

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

        if ShowVisuals and visualMarker then
            UpdateVisualPoint(visualMarker, true)
        end
    end

    CurrentlyPathing = false
    
    if AntiStuckThread then
        task.cancel(AntiStuckThread)
    end

    -- Optionally, clear old visuals (older than 30 seconds) but keep new ones
    ClearCompletedVisuals()

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
        for name in pairs(Locations) do table.insert(available, name) end
        warn("[WalkToSystem] Location not found: " .. locationName .. ". Available: " .. table.concat(available, ", "))
        return false
    end
    return WalkToSystem.WalkTo(targetCFrame, Options)
end

---------------------------------------------------------------------
-- PUBLIC API
---------------------------------------------------------------------

---------------------------------------------------------------------
-- CHECK IF DESTINATION IS REACHABLE WITH DETAILED STATUS
---------------------------------------------------------------------

function WalkToSystem.CanReachWithDetails(Destination, Options)
    Options = Options or {}
    
    if not UpdateCharacterReferences() then
        return false, "Character not ready"
    end
    
    local DestPos
    if typeof(Destination) == "CFrame" then
        DestPos = Destination.Position
    elseif typeof(Destination) == "Vector3" then
        DestPos = Destination
    elseif typeof(Destination) == "Instance" and Destination:IsA("BasePart") then
        DestPos = Destination.Position
    elseif type(Destination) == "string" then
        local lc = Locations[Destination]
        if lc then 
            DestPos = lc.Position 
        else 
            return false, "Location not found"
        end
    else
        return false, "Invalid destination type"
    end
    
    local path = PathfindingService:CreatePath({
        AgentRadius = Options.AgentRadius or 2,
        AgentHeight = Options.AgentHeight or 4,
        AgentCanJump = Options.AgentCanJump ~= false,
        AgentCanClimb = Options.AgentCanClimb ~= false,
    })
    
    local ok = pcall(function() 
        path:ComputeAsync(HumanoidRootPart.Position, DestPos) 
    end)
    
    if not ok then
        return false, "Path computation error"
    end
    
    if path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        return true, "Path found", waypoints
    elseif path.Status == Enum.PathStatus.NoPath then
        return false, "No path found"
    elseif path.Status == Enum.PathStatus.ClimbingNotSupported then
        return false, "Climbing not supported"
    elseif path.Status == Enum.PathStatus.JumpNotSupported then
        return false, "Jump not supported"
    else
        return false, "Unknown error"
    end
end

-- Enhanced WalkTo that returns success/failure
function WalkToSystem.WalkToWithResult(Destination, Options)
    local success = WalkToSystem.WalkTo(Destination, Options)
    return success
end

function WalkToSystem.Cancel()
    CurrentlyPathing = false
    if Humanoid then
        Humanoid:MoveTo(HumanoidRootPart and HumanoidRootPart.Position or Vector3.zero)
    end
    ClearVisualPoints()
    return true
end

function WalkToSystem.IsMoving()   return CurrentlyPathing end
function WalkToSystem.GetCurrentWaypoint() return CurrentWaypoint end

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
        local lc = Locations[Destination]
        if lc then DestPos = lc.Position else return false end
    else
        return false
    end
    local path = PathfindingService:CreatePath({AgentRadius=2,AgentHeight=4,AgentCanJump=true,AgentCanClimb=true})
    local ok = pcall(function() path:ComputeAsync(HumanoidRootPart.Position, DestPos) end)
    return ok and path.Status == Enum.PathStatus.Success
end

function WalkToSystem.GetLocations()
    local t = {}
    for name in pairs(Locations) do table.insert(t, name) end
    return t
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
    _G.WalkTo           = WalkToSystem.WalkTo
    _G.WalkToLocation   = WalkToSystem.WalkToLocation
    _G.CancelWalk       = WalkToSystem.Cancel
    _G.IsWalking        = WalkToSystem.IsMoving
    _G.WalkToSystem     = WalkToSystem
end

return WalkToSystem
