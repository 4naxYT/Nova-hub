if getgenv().Aiming then return getgenv().Aiming end

-- // Dependencies
local SignalManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/Stefanuk12/Signal/main/Manager.lua"))()
local BeizerManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/Stefanuk12/ROBLOX/master/Universal/Aiming/BeizerManager.lua"))()
local NovaDraw = loadstring(game:HttpGet("https://raw.githubusercontent.com/4naxYT/Nova-hub/refs/heads/main/Redistributable%20%5B%20Code%20%5D/Custom%20Drawing%20Api%20%5B%20Universal%20%5D.lua"))()

-- // Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- // Vars
local Heartbeat = RunService.Heartbeat
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = Workspace.CurrentCamera

-- // Optimisation Vars
local Color3fromRGB = Color3.fromRGB
local GetGuiInset = GuiService.GetGuiInset
local Randomnew = Random.new
local mathfloor = math.floor
local CharacterAdded = LocalPlayer.CharacterAdded
local CharacterAddedWait = CharacterAdded.Wait
local WorldToViewportPoint = CurrentCamera.WorldToViewportPoint
local RaycastParamsnew = RaycastParams.new
local EnumRaycastFilterTypeBlacklist = Enum.RaycastFilterType.Blacklist
local Raycast = Workspace.Raycast
local GetPlayers = Players.GetPlayers
local Instancenew = Instance.new
local IsDescendantOf = Instancenew("Part").IsDescendantOf
local FindFirstChildWhichIsA = Instancenew("Part").FindFirstChildWhichIsA
local FindFirstChild = Instancenew("Part").FindFirstChild
local tableremove = table.remove
local tableinsert = table.insert
local GetMouseLocation = UserInputService.GetMouseLocation

-- // Silent Aim Vars
local Aiming = {
    Enabled = true,

    ShowFOV = true,
    FOV = 60,
    FOVSides = 12,
    FOVColour = Color3fromRGB(231, 84, 128),
    FOVLockedColour = Color3fromRGB(255, 150, 150),   -- colour when target is locked

    VisibleCheck = true,
    ShowCredits = true,

    HitChance = 100,

    Selected = nil,
    SelectedPart = nil,
    SelectedPosition = nil,
    SelectedPositionOnScreen = nil,

    TargetPart = {"Head", "HumanoidRootPart"},

    Ignored = {
        Teams = {
            {
                Team = LocalPlayer.Team,
                TeamColor = LocalPlayer.TeamColor,
            },
        },
        IgnoreOtherTeams = true,
        Players = {
            LocalPlayer,
            91318356
        }
    },

    RaycastIgnore = nil,
    Signals = SignalManager.new()
}
getgenv().Aiming = Aiming

-- // Create signals
do
    local SignalNames = {"TargetPlayerChanged", "TargetPartChanged", "TargetPartPositionChanged", "TargetPartPositionOnScreenChanged"}

    for _, SignalName in ipairs(SignalNames) do
        Aiming.Signals:Create(SignalName)
    end
end

-- // NovaDraw FOV circle
local fovCircle = nil
local heartbeatConnection = nil

-- // Update FOV function
function Aiming.UpdateFOV()
    if not Aiming.ShowFOV then
        if fovCircle then
            NovaDraw.hide(fovCircle)
        end
        return
    end

    local mousePos = GetMouseLocation(UserInputService)
    local radius = Aiming.FOV * 3   -- because original used *3

    if not fovCircle then
        fovCircle = NovaDraw.circle(
            mousePos.X,
            mousePos.Y,
            radius,
            2,                      -- thickness
            Aiming.FOVColour,
            false,                  -- filled = false
            1                       -- opacity
        )
        NovaDraw.setSides(fovCircle, Aiming.FOVSides)
    else
        NovaDraw.moveCircle(fovCircle, mousePos.X, mousePos.Y)
        NovaDraw.resizeCircle(fovCircle, radius)
        NovaDraw.setSides(fovCircle, Aiming.FOVSides)

        local colour = Aiming.Selected and Aiming.Selected ~= LocalPlayer and Aiming.FOVLockedColour or Aiming.FOVColour
        NovaDraw.recolor(fovCircle, colour)

        NovaDraw.show(fovCircle)
    end
end

-- // Proper cleanup
function Aiming.CleanupDrawings()
    -- Disconnect heartbeat first so no more drawing calls occur
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end

    -- Destroy the entire NovaDraw GUI and all tracked objects
    pcall(function()
        NovaDraw.destroy()
    end)

    fovCircle = nil
end

-- // Custom Functions
local CalcChance = function(percentage)
    percentage = mathfloor(percentage)
    local chance = mathfloor(Randomnew().NextNumber(Randomnew(), 0, 1) * 100) / 100
    return chance <= percentage / 100
end

-- // Customisable Checking Functions: Is a part visible
function Aiming.IsPartVisible(Part, PartDescendant)
    local Character = LocalPlayer.Character or CharacterAddedWait(CharacterAdded)
    local Origin = CurrentCamera.CFrame.Position
    local _, OnScreen = WorldToViewportPoint(CurrentCamera, Part.Position)

    if OnScreen then
        local raycastParams = RaycastParamsnew()
        raycastParams.FilterType = EnumRaycastFilterTypeBlacklist
        raycastParams.FilterDescendantsInstances = (typeof(Aiming.RaycastIgnore) == "function" and Aiming.RaycastIgnore() or Aiming.RaycastIgnore) or {Character, CurrentCamera}

        local Result = Raycast(Workspace, Origin, Part.Position - Origin, raycastParams)
        if Result then
            local PartHit = Result.Instance
            return (not PartHit or IsDescendantOf(PartHit, PartDescendant))
        end
    end
    return false
end

-- // Ignore player
function Aiming.IgnorePlayer(Player)
    local Ignored = Aiming.Ignored
    local IgnoredPlayers = Ignored.Players

    for _, IgnoredPlayer in ipairs(IgnoredPlayers) do
        if IgnoredPlayer == Player then
            return false
        end
    end

    tableinsert(IgnoredPlayers, Player)
    return true
end

-- // Unignore Player
function Aiming.UnIgnorePlayer(Player)
    local Ignored = Aiming.Ignored
    local IgnoredPlayers = Ignored.Players

    for i, IgnoredPlayer in ipairs(IgnoredPlayers) do
        if IgnoredPlayer == Player then
            tableremove(IgnoredPlayers, i)
            return true
        end
    end
    return false
end

-- // Ignore team
function Aiming.IgnoreTeam(Team, TeamColor)
    local Ignored = Aiming.Ignored
    local IgnoredTeams = Ignored.Teams

    for _, IgnoredTeam in ipairs(IgnoredTeams) do
        if IgnoredTeam.Team == Team and IgnoredTeam.TeamColor == TeamColor then
            return false
        end
    end

    tableinsert(IgnoredTeams, {Team = Team, TeamColor = TeamColor})
    return true
end

-- // Unignore team
function Aiming.UnIgnoreTeam(Team, TeamColor)
    local Ignored = Aiming.Ignored
    local IgnoredTeams = Ignored.Teams

    for i, IgnoredTeam in ipairs(IgnoredTeams) do
        if IgnoredTeam.Team == Team and IgnoredTeam.TeamColor == TeamColor then
            tableremove(IgnoredTeams, i)
            return true
        end
    end
    return false
end

-- //  Toggle team check
function Aiming.TeamCheck(Toggle)
    if Toggle then
        return Aiming.IgnoreTeam(LocalPlayer.Team, LocalPlayer.TeamColor)
    end
    return Aiming.UnIgnoreTeam(LocalPlayer.Team, LocalPlayer.TeamColor)
end

-- // Check teams
function Aiming.IsIgnoredTeam(Player)
    local Ignored = Aiming.Ignored
    local IgnoredTeams = Ignored.Teams

    if Ignored.IgnoreOtherTeams then
        return (LocalPlayer.Team == Player.Team and LocalPlayer.TeamColor == Player.TeamColor)
    end

    for _, IgnoredTeam in ipairs(IgnoredTeams) do
        if Player.Team == IgnoredTeam.Team and Player.TeamColor == IgnoredTeam.TeamColor then
            return true
        end
    end
    return false
end

-- // Check if player (and team) is ignored
function Aiming.IsIgnored(Player)
    local Ignored = Aiming.Ignored
    local IgnoredPlayers = Ignored.Players

    for _, IgnoredPlayer in ipairs(IgnoredPlayers) do
        if typeof(IgnoredPlayer) == "number" and Player.UserId == IgnoredPlayer then
            return true
        end
        if IgnoredPlayer == Player then
            return true
        end
    end

    return Aiming.IsIgnoredTeam(Player)
end

-- // Get the Direction, Normal and Material
function Aiming.Raycast(Origin, Destination, UnitMultiplier)
    if typeof(Origin) == "Vector3" and typeof(Destination) == "Vector3" then
        if not UnitMultiplier then UnitMultiplier = 1 end
        local Direction = (Destination - Origin).Unit * UnitMultiplier
        local Result = Raycast(Workspace, Origin, Direction)
        if Result then
            return Direction, Result.Normal, Result.Material
        end
    end
    return nil
end

-- // Get Character
function Aiming.Character(Player)
    return Player.Character
end

-- // Check Health
function Aiming.CheckHealth(Player)
    local Character = Aiming.Character(Player)
    local Humanoid = FindFirstChildWhichIsA(Character, "Humanoid")
    local Health = (Humanoid and Humanoid.Health or 0)
    return Health > 0
end

-- // Custom Check Function
function Aiming.CheckCustom(Player)
    return true
end

-- // Check if silent aim can used
function Aiming.Check()
    return (Aiming.Enabled == true and Aiming.Selected ~= LocalPlayer and Aiming.SelectedPart ~= nil)
end
Aiming.checkSilentAim = Aiming.Check

-- // Get Closest Target Part
function Aiming.GetClosestTargetPartToCursor(Character)
    local TargetParts = Aiming.TargetPart
    local ClosestPart = nil
    local ClosestPartPosition = nil
    local ClosestPartOnScreen = false
    local ClosestPartMagnitudeFromMouse = nil
    local ShortestDistance = 1/0

    local function CheckTargetPart(TargetPart)
        if typeof(TargetPart) == "string" then
            TargetPart = FindFirstChild(Character, TargetPart)
        end
        if not TargetPart then return end

        local PartPos, onScreen = WorldToViewportPoint(CurrentCamera, TargetPart.Position)
        PartPos = Vector2.new(PartPos.X, PartPos.Y)

        local MousePosition = GetMouseLocation(UserInputService)
        local GuiInset = GetGuiInset(GuiService)
        local AccountedPos = PartPos - GuiInset
        local Magnitude = (AccountedPos - MousePosition).Magnitude

        if Magnitude < ShortestDistance then
            ClosestPart = TargetPart
            ClosestPartPosition = PartPos
            ClosestPartOnScreen = onScreen
            ClosestPartMagnitudeFromMouse = Magnitude
            ShortestDistance = Magnitude
        end
    end

    if typeof(TargetParts) == "string" then
        if TargetParts == "All" then
            for _, v in ipairs(Character:GetChildren()) do
                if v:IsA("BasePart") then
                    CheckTargetPart(v)
                end
            end
        else
            CheckTargetPart(TargetParts)
        end
    elseif typeof(TargetParts) == "table" then
        for _, TargetPartName in ipairs(TargetParts) do
            CheckTargetPart(TargetPartName)
        end
    end

    return ClosestPart, ClosestPartPosition, ClosestPartOnScreen, ClosestPartMagnitudeFromMouse
end

-- // Silent Aim Function
function Aiming.GetClosestPlayerToCursor()
    local TargetPart = nil
    local ClosestPlayer = nil
    local PartPosition = nil
    local PartPositionOnScreen = nil
    local Chance = CalcChance(Aiming.HitChance)
    local ShortestDistance = 1/0

    if not Chance then
        Aiming.Selected = LocalPlayer
        Aiming.SelectedPart = nil
        Aiming.SelectedPosition = nil
        Aiming.SelectedPositionOnScreen = nil
        return LocalPlayer
    end

    for _, Player in ipairs(GetPlayers(Players)) do
        local Character = Aiming.Character(Player)

        if not Aiming.IsIgnored(Player) and Character then
            local TargetPartTemp, PartPositionTemp, PartPositionOnScreenTemp, Magnitude = Aiming.GetClosestTargetPartToCursor(Character)

            if TargetPartTemp and Aiming.CheckHealth(Player) and Aiming.CheckCustom(Player) then
                if fovCircle and NovaDraw.getRadius and (NovaDraw.getRadius(fovCircle) > Magnitude and Magnitude < ShortestDistance) then
                    if Aiming.VisibleCheck and not Aiming.IsPartVisible(TargetPartTemp, Character) then continue end

                    ClosestPlayer = Player
                    ShortestDistance = Magnitude
                    TargetPart = TargetPartTemp
                    PartPosition = PartPositionTemp
                    PartPositionOnScreen = PartPositionOnScreenTemp
                end
            end
        end
    end

    if Aiming.Selected ~= ClosestPlayer then
        Aiming.Signals:Fire("TargetPlayerChanged", ClosestPlayer)
    end
    if Aiming.SelectedPart ~= TargetPart then
        Aiming.Signals:Fire("TargetPartChanged", TargetPart)
    end
    if Aiming.SelectedPosition ~= PartPosition then
        Aiming.Signals:Fire("TargetPartPositionChanged", PartPosition)
    end
    if Aiming.SelectedPositionOnScreen ~= PartPositionOnScreen then
        Aiming.Signals:Fire("TargetPartPositionOnScreenChanged", PartPositionOnScreen)
    end

    Aiming.Selected = ClosestPlayer
    Aiming.SelectedPart = TargetPart
    Aiming.SelectedPosition = PartPosition
    Aiming.SelectedPositionOnScreen = PartPositionOnScreen
end

-- //
function Aiming.SetCameraCFrame(CFr)
    CurrentCamera.CFrame = CFr
end

-- //
function Aiming.CameraLookAt(Position)
    local LookAt = CFrame.lookAt(CurrentCamera.CFrame.Position, Position)
    Aiming.SetCameraCFrame(LookAt)
end

-- // Beizer Aim Curves
Aiming.BeizerCurve = {}
do
    local ManagerA = BeizerManager.new()
    local ManagerB = BeizerManager.new()

    Aiming.BeizerCurve.ManagerA = ManagerA
    Aiming.BeizerCurve.ManagerB = ManagerB

    Aiming.BeizerCurve.AimTo = function(...)
        ManagerA:ChangeData(...)
    end
    Aiming.BeizerCurve.AimToB = function(...)
        ManagerB:ChangeData(...)
    end

    ManagerB:CameraMode()
    ManagerB.Function = function(Pitch, Yaw)
        local RotationMatrix = CFrame.fromEulerAnglesYXZ(Pitch, Yaw, 0)
        Aiming.SetCameraCFrame(CFrame.new(CurrentCamera.CFrame.Position) * RotationMatrix)
    end

    ManagerA:Start()
    ManagerB:Start()
end

-- // Heartbeat loop (stored for cleanup)
heartbeatConnection = Heartbeat:Connect(function()
    Aiming.UpdateFOV()
    Aiming.GetClosestPlayerToCursor()
end)

-- // Cleanup when script is unloaded
local function fullCleanup()
    Aiming.CleanupDrawings()
end

-- Attach to teleport
LocalPlayer.OnTeleport:Connect(fullCleanup)

-- If your executor supports a global unload function, set it
getgenv().UnloadSilentAim = fullCleanup

-- // Credits
print([[
    Credits To:
    - Stefanuk12 ( main implimentation of silent aim )
    - NovaHub ( NovaDraw )
]])

return Aiming
