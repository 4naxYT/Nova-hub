--[[
	Universal Aimbot Module by Exunys © CC0 1.0 Universal (2023 - 2024)
	https://github.com/Exunys
	Forked By - @xx4naxx on Youtube
	feature added- Compatability for the Velocity executor and most executors
--]]

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

-- Convert stud offset to pixels based on screen resolution
local function getPixelOffset(yOffset, camera)
	if not camera then
		camera = Camera or workspace.CurrentCamera
	end
	if not camera then
		return yOffset * 50 -- Fallback
	end
	
	local viewportSize = camera.ViewportSize
	if not viewportSize then
		return yOffset * 50
	end
	
	local cameraHeight = viewportSize.Y
	local fov = camera.FieldOfView
	
	-- Calculate pixels per stud at 1 stud distance
	local fovRad = math.rad(fov)
	local visibleHeightAtOneStud = 2 * math.tan(fovRad / 2)
	local pixelsPerStud = cameraHeight / visibleHeightAtOneStud
	
	return yOffset * pixelsPerStud
end

--// Environment Table
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
		Thickness = 2,
		Transparency = 1,        -- 0 = opaque, 1 = fully transparent
		Filled = false,
		RainbowColor = false,
		RainbowOutlineColor = false,
		Color = Color3fromRGB(255, 255, 255),
		OutlineColor = Color3fromRGB(0, 0, 0),
		LockedColor = Color3fromRGB(255, 150, 150),
		YOffset = -0.007
	},
	FOVCircle = nil,
	FOVStroke = nil,            -- Main colored stroke (on top)
	FOVOutlineStroke = nil,     -- Outline stroke (behind)
	FOVGui = nil,
}

getgenv().ExunysDeveloperAimbot = Environment

--// GUI-based FOV Circle
local function CreateFOVCircle()
	local success, gui = pcall(function()
		local FOVGui = Instance.new("ScreenGui")
		FOVGui.Name = "ExunysAimbotFOV"
		FOVGui.ResetOnSpawn = false
		FOVGui.IgnoreGuiInset = true
		FOVGui.DisplayOrder = 999
		FOVGui.Parent = __index(LocalPlayer, "PlayerGui")
		
		Environment.FOVGui = FOVGui

		-- Main circle frame
		local FOVFrame = Instance.new("Frame")
		FOVFrame.Name = "FOVCircle"
		FOVFrame.Size = UDim2.fromOffset(Environment.FOVSettings.Radius * 2, Environment.FOVSettings.Radius * 2)
		FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		FOVFrame.BackgroundTransparency = 1
		FOVFrame.BorderSizePixel = 0
		FOVFrame.Active = false
		FOVFrame.Selectable = false
		FOVFrame.Visible = false
		FOVFrame.ZIndex = 999
		FOVFrame.Parent = FOVGui
		
		Environment.FOVCircle = FOVFrame

		-- Make it a circle
		local FOVCorner = Instance.new("UICorner")
		FOVCorner.CornerRadius = UDim.new(1, 0)
		FOVCorner.Parent = FOVFrame

		-- OUTLINE STROKE (behind)
		local FOVOutlineStroke = Instance.new("UIStroke")
		FOVOutlineStroke.Thickness = Environment.FOVSettings.Thickness + 1
		FOVOutlineStroke.Color = Environment.FOVSettings.OutlineColor
		FOVOutlineStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		FOVOutlineStroke.LineJoinMode = Enum.LineJoinMode.Round
		FOVOutlineStroke.Transparency = Environment.FOVSettings.Transparency  -- Apply transparency
		FOVOutlineStroke.Parent = FOVFrame
		FOVOutlineStroke.ZIndex = 998
		
		Environment.FOVOutlineStroke = FOVOutlineStroke

		-- MAIN STROKE (on top)
		local FOVStroke = Instance.new("UIStroke")
		FOVStroke.Thickness = Environment.FOVSettings.Thickness
		FOVStroke.Color = Environment.FOVSettings.Color
		FOVStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		FOVStroke.LineJoinMode = Enum.LineJoinMode.Round
		FOVStroke.Transparency = Environment.FOVSettings.Transparency  -- Apply transparency
		FOVStroke.Parent = FOVFrame
		FOVStroke.ZIndex = 999
		
		Environment.FOVStroke = FOVStroke
		
		return FOVGui
	end)
	
	if not success then
		warn("FOV GUI creation failed, FOV circle will be disabled. Error: " .. tostring(success))
		Environment.FOVSettings.Enabled = false
		Environment.FOVSettings.Visible = false
	end
end

-- Only create GUI if LocalPlayer is available
if LocalPlayer and __index(LocalPlayer, "PlayerGui") then
	CreateFOVCircle()
else
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
    if Environment.FOVStroke then
        Environment.FOVStroke.Color = Environment.FOVSettings.Color
    end
    if Environment.FOVOutlineStroke then
        Environment.FOVOutlineStroke.Color = Environment.FOVSettings.OutlineColor
    end
    __newindex(UserInputService, "MouseDeltaSensitivity", OriginalSensitivity)
    if Animation then
        Animation:Cancel()
    end
end

local GetClosestPlayer = function()
	local Settings = Environment.Settings
	local LockPart = Settings.LockPart

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
					-- Wall check
					if Settings.WallCheck then
						local now = tick()
						local cached = WallCheckCache[Value]
						local obstructed

						if cached and now - cached.timestamp < 0.2 then
							obstructed = cached.result
						else
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

print([[
	Aimbot Module Courtosy of:
	Exunys,
	Modified For Compatability By:
	The NovaHub Team- ( @xx4naxx on YouTube )
]])

local Load = function()
	OriginalSensitivity = __index(UserInputService, "MouseDeltaSensitivity")

	local Settings, FOVCircle, FOVSettings, Offset = Environment.Settings, Environment.FOVCircle, Environment.FOVSettings

	ServiceConnections.RenderSteppedConnection = Connect(__index(RunService, Environment.DeveloperSettings.UpdateMode), function()
		if not Camera or not LocalPlayer then return end

		local OffsetToMoveDirection, LockPart = Settings.OffsetToMoveDirection, Settings.LockPart

		-- FOV Circle update
		if FOVSettings.Enabled and Settings.Enabled and FOVCircle and Environment.FOVGui then
			local mousePos = GetMouseLocation(UserInputService)
			local radius = FOVSettings.Radius
			
			-- Calculate colors
			local color
			local outlineColor
			
			if Environment.Locked then
				color = FOVSettings.LockedColor
				outlineColor = FOVSettings.OutlineColor
			else
				if FOVSettings.RainbowColor then
					color = GetRainbowColor()
				else
					color = FOVSettings.Color
				end
				
				if FOVSettings.RainbowOutlineColor then
					outlineColor = GetRainbowColor()
				else
					outlineColor = FOVSettings.OutlineColor
				end
			end

			-- Calculate Y-offset in pixels
			local pixelOffset = getPixelOffset(FOVSettings.YOffset, Camera)
			local adjustedY = mousePos.Y + pixelOffset

			-- Update frame
			local size = radius * 2
			FOVCircle.Size = UDim2.fromOffset(size, size)
			FOVCircle.Position = UDim2.new(0, mousePos.X, 0, adjustedY)
			FOVCircle.Visible = FOVSettings.Visible

			-- Update strokes (transparency applied here as well)
			local strokeTransparency = FOVSettings.Transparency

			if Environment.FOVOutlineStroke then
				Environment.FOVOutlineStroke.Color = outlineColor
				Environment.FOVOutlineStroke.Thickness = FOVSettings.Thickness + 1
				Environment.FOVOutlineStroke.Transparency = strokeTransparency
			end
			
			if Environment.FOVStroke then
				Environment.FOVStroke.Color = color
				Environment.FOVStroke.Thickness = FOVSettings.Thickness
				Environment.FOVStroke.Transparency = strokeTransparency
			end

			-- Fill and transparency
			if FOVSettings.Filled then
				FOVCircle.BackgroundTransparency = strokeTransparency
				FOVCircle.BackgroundColor3 = color
			else
				FOVCircle.BackgroundTransparency = 1
			end
			
			Environment.FOVGui.Enabled = true
		elseif Environment.FOVGui then
			Environment.FOVGui.Enabled = false
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
	
	-- Auto-cleanup on player removal
	if LocalPlayer then
		LocalPlayer.AncestryChanged:Connect(function()
			if not LocalPlayer.Parent then
				if Environment.FOVGui then
					Environment.FOVGui:Destroy()
				end
			end
		end)
	end
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
	if Environment.FOVGui then
		Environment.FOVGui:Destroy()
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
