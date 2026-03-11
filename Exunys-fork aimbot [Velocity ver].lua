--[[

	Universal Aimbot Module by Exunys © CC0 1.0 Universal (2023 - 2024)
	https://github.com/Exunys
	Forked By - @xx4naxx on Youtube
	feature added- Compatability for the Velocity executor

	Modified: Removed blacklist/whitelist, improved wall check (raycast + cache), fixed FOV transparency/filled.
	Added defensive nil checks to prevent "attempt to index nil" errors.

]]

--// Cache

local game, workspace = game, workspace
local getrawmetatable, getmetatable, setmetatable, pcall, getgenv, next, tick = getrawmetatable, getmetatable, setmetatable, pcall, getgenv, next, tick
local Vector2new, Vector3zero, CFramenew, Color3fromRGB, Color3fromHSV, Drawingnew, TweenInfonew = Vector2.new, Vector3.zero, CFrame.new, Color3.fromRGB, Color3.fromHSV, Drawing.new, TweenInfo.new
local getupvalue, mousemoverel, tablefind, tableremove, stringlower, stringsub, mathclamp = debug.getupvalue, mousemoverel or (Input and Input.MouseMove), table.find, table.remove, string.lower, string.sub, math.clamp

local GameMetatable = getrawmetatable and getrawmetatable(game) or {
	__index = function(self, Index) return self[Index] end,
	__newindex = function(self, Index, Value) self[Index] = Value end
}

local __index = GameMetatable.__index
local __newindex = GameMetatable.__newindex
local GetService = __index(game, "GetService")

--// Services

local RunService = GetService(game, "RunService")
local UserInputService = GetService(game, "UserInputService")
local TweenService = GetService(game, "TweenService")
local Players = GetService(game, "Players")

--// Service Methods

local LocalPlayer = __index(Players, "LocalPlayer")
local Camera = __index(workspace, "CurrentCamera")
local FindFirstChild, FindFirstChildOfClass = __index(game, "FindFirstChild"), __index(game, "FindFirstChildOfClass")
local GetDescendants = __index(game, "GetDescendants")
local WorldToViewportPoint = __index(Camera, "WorldToViewportPoint")
local GetPartsObscuringTarget = __index(Camera, "GetPartsObscuringTarget")
local GetMouseLocation = __index(UserInputService, "GetMouseLocation")
local GetPlayers = __index(Players, "GetPlayers")

--// Variables

local RequiredDistance, Typing, Running, ServiceConnections, Animation, OriginalSensitivity = 2000, false, false, {}
local Connect, Disconnect = __index(game, "DescendantAdded").Connect

-- Wall check cache: player -> {result = bool, timestamp = number}
local WallCheckCache = {}

--// Environment Table (will be returned and assigned to getgenv)

local Environment = {
	DeveloperSettings = {
		UpdateMode = "RenderStepped",
		TeamCheckOption = "TeamColor",
		RainbowSpeed = 1
	},
	Settings = {
		Enabled = true,
		TeamCheck = false,
		AliveCheck = true,
		WallCheck = false,
		OffsetToMoveDirection = false,
		OffsetIncrement = 15,
		Sensitivity = 0,
		Sensitivity2 = 3.5,
		LockMode = 1,
		LockPart = "Head",
		TriggerKey = Enum.UserInputType.MouseButton2,
		Toggle = false
	},
	FOVSettings = {
		Enabled = true,
		Visible = true,
		Radius = 90,
		NumSides = 60,
		Thickness = 1,
		Transparency = 1,
		Filled = false,
		RainbowColor = false,
		RainbowOutlineColor = false,
		Color = Color3fromRGB(255, 255, 255),
		OutlineColor = Color3fromRGB(0, 0, 0),
		LockedColor = Color3fromRGB(255, 150, 150)
	},
	FOVCircle = nil,
	FOVCircleOutline = nil,
}

getgenv().ExunysDeveloperAimbot = Environment

--// GUI-based FOV Circle (with nil protection)

local function CreateFOVCircle()
	local success, gui = pcall(function()
		local FOVGui = Instance.new("ScreenGui")
		FOVGui.Name = "ExunysAimbotFOV"
		FOVGui.ResetOnSpawn = false
		FOVGui.Parent = __index(LocalPlayer, "PlayerGui")

		local FOVFrame = Instance.new("Frame")
		FOVFrame.Size = UDim2.fromOffset(Environment.FOVSettings.Radius * 2, Environment.FOVSettings.Radius * 2)
		FOVFrame.AnchorPoint = Vector2.new(0.5, 1)
		FOVFrame.BackgroundTransparency = 1
		FOVFrame.Visible = false
		FOVFrame.ZIndex = 999
		FOVFrame.Parent = FOVGui

		local FOVFrameCorner = Instance.new("UICorner")
		FOVFrameCorner.CornerRadius = UDim.new(1, 0)
		FOVFrameCorner.Parent = FOVFrame

		local FOVStroke = Instance.new("UIStroke")
		FOVStroke.Thickness = Environment.FOVSettings.Thickness
		FOVStroke.Color = Environment.FOVSettings.Color
		FOVStroke.Parent = FOVFrame

		local FOVOuterFrame = Instance.new("Frame")
		FOVOuterFrame.Size = UDim2.fromOffset((Environment.FOVSettings.Radius + 1) * 2, (Environment.FOVSettings.Radius + 1) * 2)
		FOVOuterFrame.AnchorPoint = Vector2.new(0.5, 1)
		FOVOuterFrame.BackgroundTransparency = 1
		FOVOuterFrame.Visible = false
		FOVOuterFrame.ZIndex = 998
		FOVOuterFrame.Parent = FOVGui

		local FOVOuterCorner = Instance.new("UICorner")
		FOVOuterCorner.CornerRadius = UDim.new(1, 0)
		FOVOuterCorner.Parent = FOVOuterFrame

		local FOVOuterStroke = Instance.new("UIStroke")
		FOVOuterStroke.Thickness = Environment.FOVSettings.Thickness + 1
		FOVOuterStroke.Color = Environment.FOVSettings.OutlineColor
		FOVOuterStroke.Parent = FOVOuterFrame

		Environment.FOVCircle = FOVFrame
		Environment.FOVCircleOutline = FOVOuterFrame
		return FOVGui
	end)
	if not success then
		warn("FOV GUI creation failed, FOV circle will be disabled.")
		Environment.FOVSettings.Enabled = false
		Environment.FOVSettings.Visible = false
	end
end

-- Only create GUI if LocalPlayer is available
if LocalPlayer and __index(LocalPlayer, "PlayerGui") then
	CreateFOVCircle()
else
	-- Retry when LocalPlayer is added
	local playerAddedConn
	playerAddedConn = Connect(__index(Players, "PlayerAdded"), function(player)
		if player == LocalPlayer then
			CreateFOVCircle()
			Disconnect(playerAddedConn)
		end
	end)
end

--// Core Functions

local GetRainbowColor = function()
	local RainbowSpeed = Environment.DeveloperSettings.RainbowSpeed
	return Color3fromHSV(tick() % RainbowSpeed / RainbowSpeed, 1, 1)
end

local ConvertVector = function(Vector)
	return Vector2new(Vector.X, Vector.Y)
end

local CancelLock = function()
    Environment.Locked = nil
    if Environment.FOVCircle and Environment.FOVCircle:FindFirstChildOfClass("UIStroke") then
        Environment.FOVCircle:FindFirstChildOfClass("UIStroke").Color = Environment.FOVSettings.Color
    end
    __newindex(UserInputService, "MouseDeltaSensitivity", OriginalSensitivity)
    if Animation then
        Animation:Cancel()
    end
end

local GetClosestPlayer = function()
	local Settings = Environment.Settings
	local LockPart = Settings.LockPart

	-- Safety checks
	if not Camera or not LocalPlayer then return end

	if not Environment.Locked then
		RequiredDistance = Environment.FOVSettings.Enabled and Environment.FOVSettings.Radius or 2000

		for _, Value in next, GetPlayers(Players) do
			local Character = __index(Value, "Character")
			local Humanoid = Character and FindFirstChildOfClass(Character, "Humanoid")

			if Value ~= LocalPlayer and Character and FindFirstChild(Character, LockPart) and Humanoid then
				local Part = Character[LockPart]
				local PartPosition = __index(Part, "Position")
				local TeamCheckOption = Environment.DeveloperSettings.TeamCheckOption

				if Settings.TeamCheck and __index(Value, TeamCheckOption) == __index(LocalPlayer, TeamCheckOption) then
					continue
				end

				if Settings.AliveCheck and __index(Humanoid, "Health") <= 0 then
					continue
				end

				local Vector, OnScreen, Distance = WorldToViewportPoint(Camera, PartPosition)
				Vector = ConvertVector(Vector)
				Distance = (GetMouseLocation(UserInputService) - Vector).Magnitude

				if Distance < RequiredDistance and OnScreen then
					-- Wall check (cached + raycast)
					if Settings.WallCheck then
						local now = tick()
						local cached = WallCheckCache[Value]
						local obstructed

						if cached and now - cached.timestamp < 0.2 then
							obstructed = cached.result
						else
							-- Perform raycast from camera to target part
							local origin = Camera.CFrame.Position
							local direction = PartPosition - origin
							local raycastParams = RaycastParams.new()
							raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
							local filter = {LocalPlayer.Character, Character}
							raycastParams.FilterDescendantsInstances = filter
							local rayResult = workspace:Raycast(origin, direction, raycastParams)
							obstructed = rayResult ~= nil

							WallCheckCache[Value] = {result = obstructed, timestamp = now}
						end

						if obstructed then
							continue
						end
					end

					RequiredDistance, Environment.Locked = Distance, Value
				end
			end
		end
	else
		-- Check if locked target is still valid
		local lockedChar = __index(Environment.Locked, "Character")
		if lockedChar and lockedChar[LockPart] then
			local pos = __index(lockedChar[LockPart], "Position")
			local screenPos = WorldToViewportPoint(Camera, pos)
			local dist = (GetMouseLocation(UserInputService) - ConvertVector(screenPos)).Magnitude
			if dist > RequiredDistance then
				CancelLock()
			end
		else
			CancelLock()
		end
	end
end

local Load = function()
	OriginalSensitivity = __index(UserInputService, "MouseDeltaSensitivity")

	local Settings, FOVCircle, FOVCircleOutline, FOVSettings, Offset = Environment.Settings, Environment.FOVCircle, Environment.FOVCircleOutline, Environment.FOVSettings

	ServiceConnections.RenderSteppedConnection = Connect(__index(RunService, Environment.DeveloperSettings.UpdateMode), function()
		-- Safety checks
		if not Camera or not LocalPlayer then return end

		local OffsetToMoveDirection, LockPart = Settings.OffsetToMoveDirection, Settings.LockPart

		-- FOV Circle update (GUI-based)
		if FOVSettings.Enabled and Settings.Enabled and FOVCircle and FOVCircleOutline then
			local mousePos = GetMouseLocation(UserInputService)
			local radius = FOVSettings.Radius
			local color = (Environment.Locked and FOVSettings.LockedColor)
				or (FOVSettings.RainbowColor and GetRainbowColor())
				or FOVSettings.Color
			local outlineColor = (FOVSettings.RainbowOutlineColor and GetRainbowColor()) or FOVSettings.OutlineColor

			-- Position and size
			FOVCircle.Visible = FOVSettings.Visible
			FOVCircleOutline.Visible = FOVSettings.Visible
			FOVCircle.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
			FOVCircleOutline.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
			FOVCircle.Size = UDim2.fromOffset(radius * 2, radius * 2)
			FOVCircleOutline.Size = UDim2.fromOffset((radius + 1) * 2, (radius + 1) * 2)

			-- Strokes
			local stroke = FOVCircle:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = color
				stroke.Thickness = FOVSettings.Thickness
			end
			local outlineStroke = FOVCircleOutline:FindFirstChildOfClass("UIStroke")
			if outlineStroke then
				outlineStroke.Color = outlineColor
				outlineStroke.Thickness = FOVSettings.Thickness + 1
			end

			-- Fill and transparency
			if FOVSettings.Filled then
				FOVCircle.BackgroundTransparency = FOVSettings.Transparency
				FOVCircle.BackgroundColor3 = color
			else
				FOVCircle.BackgroundTransparency = 1
			end
			FOVCircleOutline.BackgroundTransparency = 1
		elseif FOVCircle and FOVCircleOutline then
			FOVCircle.Visible = false
			FOVCircleOutline.Visible = false
		end

		if Running and Settings.Enabled then
			GetClosestPlayer()

			if Environment.Locked then
				local lockedChar = __index(Environment.Locked, "Character")
				if lockedChar and lockedChar[LockPart] then
					Offset = OffsetToMoveDirection and __index(FindFirstChildOfClass(lockedChar, "Humanoid"), "MoveDirection") * (mathclamp(Settings.OffsetIncrement, 1, 30) / 10) or Vector3zero

					local LockedPosition_Vector3 = __index(lockedChar[LockPart], "Position")
					local LockedPosition = WorldToViewportPoint(Camera, LockedPosition_Vector3 + Offset)

					if Environment.Settings.LockMode == 2 then
						mousemoverel((LockedPosition.X - GetMouseLocation(UserInputService).X) / Settings.Sensitivity2, (LockedPosition.Y - GetMouseLocation(UserInputService).Y) / Settings.Sensitivity2)
					else
						if Settings.Sensitivity > 0 then
							Animation = TweenService:Create(Camera, TweenInfonew(Environment.Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFramenew(Camera.CFrame.Position, LockedPosition_Vector3)})
							Animation:Play()
						else
							__newindex(Camera, "CFrame", CFramenew(Camera.CFrame.Position, LockedPosition_Vector3 + Offset))
						end

						__newindex(UserInputService, "MouseDeltaSensitivity", 0)
					end

					if FOVCircle and FOVCircle:FindFirstChildOfClass("UIStroke") then
						FOVCircle:FindFirstChildOfClass("UIStroke").Color = FOVSettings.LockedColor
					end
				else
					CancelLock()
				end
			end
		end
	end)

	ServiceConnections.InputBeganConnection = Connect(__index(UserInputService, "InputBegan"), function(Input)
		local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle

		if Typing then
			return
		end

		if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
			if Toggle then
				Running = not Running

				if not Running then
					CancelLock()
				end
			else
				Running = true
			end
		end
	end)

	ServiceConnections.InputEndedConnection = Connect(__index(UserInputService, "InputEnded"), function(Input)
		local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle

		if Toggle or Typing then
			return
		end

		if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
			Running = false
			CancelLock()
		end
	end)
end

--// Typing Check

ServiceConnections.TypingStartedConnection = Connect(__index(UserInputService, "TextBoxFocused"), function()
	Typing = true
end)

ServiceConnections.TypingEndedConnection = Connect(__index(UserInputService, "TextBoxFocusReleased"), function()
	Typing = false
end)

--// Public Methods

function Environment.Exit(self)
	assert(self, "EXUNYS_AIMBOT-V3.Exit: Missing parameter #1 \"self\" <table>.")
	for Index, _ in next, ServiceConnections do
		Disconnect(ServiceConnections[Index])
	end
	if Environment.FOVCircle and Environment.FOVCircle.Parent then
		Environment.FOVCircle.Parent:Destroy()
	end
	getgenv().ExunysDeveloperAimbot = nil
end

function Environment.Restart()
	for Index, _ in next, ServiceConnections do
		Disconnect(ServiceConnections[Index])
	end
	Load()
end

function Environment.GetClosestPlayer()
	GetClosestPlayer()
	local Value = Environment.Locked
	CancelLock()
	return Value
end

Environment.Load = Load
setmetatable(Environment, {__call = Load})

return Environment
