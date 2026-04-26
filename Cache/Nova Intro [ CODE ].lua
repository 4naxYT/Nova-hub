--[[

// gives a debug msg for verifying Steps

getgenv().Nova_LS_Debug = true

]]

local function initiate_loading_screen()

    -- =============================================
    --           NOVA HUB - INTRO V2
    --        by 4nax | Upgraded Loading Screen
    -- =============================================

    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")
    local Lighting = game:GetService("Lighting")

    local localPlayer = Players.LocalPlayer
    local BLUR_START = 60
    local FADE_DURATION = 0.1
    local TOTAL_STEPS = BLUR_START
    local LETTERBOX_HEIGHT = 0.06

    -- ──────────────────────────────────────────
    --  DEBUGGING
    -- ──────────────────────────────────────────
    local logEntries = {}
    local function log(component, success, details)
        local icon = success and "✅" or "❌"
        local msg = string.format("[Nova - Loading Screen] %s - [%s]", component, icon)
        if details then
            msg = msg .. " (" .. tostring(details) .. ")"
        end
        table.insert(logEntries, msg)
        print(msg)
    end

    -- ──────────────────────────────────────────
    --  VIDEO CACHE
    -- ──────────────────────────────────────────
    local VIDEO_PATH = "Nova_Intro_v2.mov"
    local VIDEO_URL  = "https://raw.githubusercontent.com/4naxYT/Nova-hub/refs/heads/main/Cache/Nova's%20Intro%20v2.mov"

    local videoLoaded = false
    local resolvedVideo = nil

    local function loadVideo()
        local success, err = pcall(function()
            if not isfile(VIDEO_PATH) then
                writefile(VIDEO_PATH, game:HttpGet(VIDEO_URL))
            end
            resolvedVideo = getcustomasset(VIDEO_PATH)
            if not resolvedVideo then error("getcustomasset returned nil") end
        end)
        if success then
            videoLoaded = true
            log("Video download & cache", true)
        else
            log("Video download & cache", false, err)
        end
    end
    loadVideo()

    -- ──────────────────────────────────────────
    --  BLUR SETUP
    -- ──────────────────────────────────────────
    local blur_
    local blurSuccess, blurErr = pcall(function()
        blur_ = Instance.new("BlurEffect", Lighting)
        blur_.Size = BLUR_START
    end)
    if blurSuccess then
        log("Blur effect", true, "Size " .. BLUR_START)
    else
        log("Blur effect", false, blurErr)
    end

    -- ──────────────────────────────────────────
    --  ROOT GUI
    -- ──────────────────────────────────────────
    local screenGui
    local guiSuccess, guiErr = pcall(function()
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "NovaHubIntro"
        screenGui.ResetOnSpawn = false
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
    end)
    if guiSuccess then log("ScreenGui", true) else log("ScreenGui", false, guiErr) return end

    -- ──────────────────────────────────────────
    --  VIEWPORT – spinning REAL avatar
    -- ──────────────────────────────────────────
    local viewportFrame
    local viewportCam
    local viewportLight
    local spinConnection
    local avatarModel = nil
    local characterSpinRunning = false

    local function setupViewport()
        viewportFrame = Instance.new("ViewportFrame")
        viewportFrame.Name = "SpinningCharacter"
        viewportFrame.Size = UDim2.new(1, 0, 1, 0)
        viewportFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        viewportFrame.BackgroundTransparency = 0.5
        viewportFrame.BorderSizePixel = 0
        viewportFrame.ZIndex = 0
        viewportFrame.Parent = screenGui

        viewportCam = Instance.new("Camera")
        viewportCam.CameraType = Enum.CameraType.Scriptable
        viewportCam.Parent = viewportFrame
        viewportFrame.CurrentCamera = viewportCam

        viewportLight = Instance.new("PointLight")
        viewportLight.Brightness = 2
        viewportLight.Color = Color3.fromRGB(180, 80, 255)
        viewportLight.Range = 20
        viewportLight.Parent = viewportCam
    end

    local function cleanModel(model)
        for _, v in ipairs(model:GetDescendants()) do
            if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("AnimationController") then
                v:Destroy()
            end
        end
    end

    -- Spawn a real avatar model using Players APIs + ApplyDescription
    local function createRealAvatar()
        local userId = localPlayer.UserId
        local model = nil
        local avatarType = "Unknown"

        -- Step 1: Get appearance info to know the rig type
        local infoSuccess, info = pcall(function()
            return Players:GetCharacterAppearanceInfoAsync(userId)
        end)
        if infoSuccess and info then
            avatarType = info.playerAvatarType
            log("Avatar type detected", true, avatarType)
        else
            log("Avatar type detection", false, info)
            avatarType = "R6"
        end

        -- Step 2: Build base model (force R6)
        local buildSuccess, buildErr = pcall(function()
            if avatarType == "R15" then
                local description = Players:GetHumanoidDescriptionFromUserIdAsync(userId)
                model = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6, Enum.AssetTypeVerification.Default)
            else
                model = Players:CreateHumanoidModelFromUserIdAsync(userId)
            end
        end)

        if not buildSuccess or not model then
            error("Avatar creation failed: " .. tostring(buildErr))
        end

        -- Step 3: Apply the full humanoid description (loads ALL accessories, hair, clothes etc.)
        local descSuccess, desc = pcall(function()
            return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
        end)
        if descSuccess and desc then
            local applySuccess, applyErr = pcall(function()
                model.Humanoid:BuildRigFromAttachments()
            end)
            if applySuccess then
                log("Accessories & clothes applied", true)
            else
                log("ApplyDescription failed", false, applyErr)
            end
        else
            log("Fetch HumanoidDescription", false, desc)
        end

        return model, avatarType
    end

    -- Start spinning the avatar (or dummy if avatar failed)
    local function startAvatarSpin()
        local model, avatarType = nil, nil

        -- Try to create the real avatar (base body only)
        local avatarSuccess, avatarErr = pcall(function()
            model, avatarType = createRealAvatar()
        end)

        if avatarSuccess and model then
            log("Real avatar created", true, avatarType)

            -- === APPLY FULL OUTFIT (requires DataModel) ===
            local descSuccess, desc = pcall(function()
                return Players:GetHumanoidDescriptionFromUserIdAsync(localPlayer.UserId)
            end)
            if descSuccess and desc then
                -- Store the original parent (likely nil)
                local originalParent = model.Parent
                -- Move to workspace in a hidden location
                model.Parent = workspace
                model:MoveTo(Vector3.new(0, 99999, 0))   -- far away, invisible
                local applySuccess, applyErr = pcall(function()
                    model.Humanoid:ApplyDescription(desc)
                    model.Humanoid:BuildRigFromAttachments()
                end)
                -- Move back to original parent (or to viewport later)
                model.Parent = originalParent
                if applySuccess then
                    log("Accessories & clothes applied", true)
                else
                    log("ApplyDescription failed (will use body only)", false, applyErr)
                end
            else
                log("Fetch HumanoidDescription", false, desc)
            end

            cleanModel(model)
        else
            log("Real avatar creation", false, avatarErr or "unknown")
            -- Fallback dummy (same as before)
            model = Instance.new("Model")
            model.Name = "DummyCharacter"
            local function createPart(name, size, color, offset)
                local p = Instance.new("Part")
                p.Name = name
                p.Size = size
                p.Position = Vector3.new(0, offset, 0)
                p.Anchored = true
                p.CanCollide = false
                p.BrickColor = BrickColor.new(color)
                p.Parent = model
                return p
            end
            createPart("Head", Vector3.new(1.2, 1.2, 1.2), "Deep purple", 2.4)
            createPart("UpperTorso", Vector3.new(1.8, 1.8, 1.2), "Bright violet", 0.9)
            createPart("LowerTorso", Vector3.new(1.6, 1.2, 1.2), "Eggplant", -0.3)
            createPart("LeftArm", Vector3.new(0.4, 1.8, 0.4), "Lavender", 1.2).Position = Vector3.new(-1.3, 1.2, 0)
            createPart("RightArm", Vector3.new(0.4, 1.8, 0.4), "Lavender", 1.2).Position = Vector3.new(1.3, 1.2, 0)
            createPart("LeftLeg", Vector3.new(0.5, 1.8, 0.5), "Plum", -1.8).Position = Vector3.new(-0.5, -1.8, 0)
            createPart("RightLeg", Vector3.new(0.5, 1.8, 0.5), "Plum", -1.8).Position = Vector3.new(0.5, -1.8, 0)

            local root = Instance.new("Part")
            root.Name = "HumanoidRootPart"
            root.Size = Vector3.zero
            root.Anchored = true
            root.CanCollide = false
            root.Transparency = 1
            root.Parent = model
            model.PrimaryPart = root
            log("Using dummy fallback", true)
        end

        avatarModel = model
        avatarModel.Parent = viewportFrame

        local rootPart = avatarModel.PrimaryPart or avatarModel:WaitForChild("HumanoidRootPart", 10)
        if not rootPart then error("No root part found for camera orbit") end

        local angle = 0
        local rotationSpeed = 1.5
        local cameraDistance = 10
        local cameraHeight = 3

        spinConnection = RunService.Heartbeat:Connect(function(deltaTime)
            angle = angle + rotationSpeed * deltaTime
            local pos = rootPart.Position
            local offset = Vector3.new(
                math.sin(angle) * cameraDistance,
                cameraHeight,
                math.cos(angle) * cameraDistance
            )
            viewportCam.CFrame = CFrame.new(pos + offset, pos + Vector3.new(0, -2, 0))
        end)

        characterSpinRunning = true
    end

    pcall(setupViewport)
    if viewportFrame then
        log("ViewportFrame", true)
        task.spawn(function()
            local spinSuccess, spinErr = pcall(startAvatarSpin)
            if spinSuccess then
                log("Viewport spin animation", true)
            else
                log("Viewport spin animation", false, spinErr)
            end
        end)
    else
        log("ViewportFrame", false, "setup failed")
    end

    -- ──────────────────────────────────────────
    --  LETTERBOX BARS
    -- ──────────────────────────────────────────
    local letterTop, letterBot
    local letterboxSuccess, letterboxErr = pcall(function()
        letterTop = Instance.new("Frame")
        letterTop.Name = "LetterboxTop"
        letterTop.Size = UDim2.new(1, 0, LETTERBOX_HEIGHT, 0)
        letterTop.Position = UDim2.new(0, 0, -LETTERBOX_HEIGHT, 0)
        letterTop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        letterTop.BackgroundTransparency = 0
        letterTop.BorderSizePixel = 0
        letterTop.ZIndex = 10
        letterTop.Parent = screenGui

        local topEdge = Instance.new("Frame")
        topEdge.Size = UDim2.new(1, 0, 0, 1)
        topEdge.Position = UDim2.new(0, 0, 1, -1)
        topEdge.BackgroundColor3 = Color3.fromRGB(180, 80, 255)
        topEdge.BackgroundTransparency = 0.3
        topEdge.BorderSizePixel = 0
        topEdge.ZIndex = 11
        topEdge.Parent = letterTop
        Instance.new("UIGradient", topEdge).Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(80, 180, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 80, 255)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 80, 160)),
        })

        letterBot = Instance.new("Frame")
        letterBot.Name = "LetterboxBottom"
        letterBot.Size = UDim2.new(1, 0, LETTERBOX_HEIGHT, 0)
        letterBot.Position = UDim2.new(0, 0, 1, 0)
        letterBot.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        letterBot.BackgroundTransparency = 0
        letterBot.BorderSizePixel = 0
        letterBot.ZIndex = 10
        letterBot.Parent = screenGui

        local botEdge = Instance.new("Frame")
        botEdge.Size = UDim2.new(1, 0, 0, 1)
        botEdge.Position = UDim2.new(0, 0, 0, 0)
        botEdge.BackgroundColor3 = Color3.fromRGB(180, 80, 255)
        botEdge.BackgroundTransparency = 0.3
        botEdge.BorderSizePixel = 0
        botEdge.ZIndex = 11
        botEdge.Parent = letterBot
        Instance.new("UIGradient", botEdge).Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(80, 180, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 80, 255)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 80, 160)),
        })
    end)
    if letterboxSuccess then log("Letterbox bars", true) else log("Letterbox bars", false, letterboxErr) end

    local function safeTween(obj, info, props, componentName)
        if not obj then log(componentName or "Tween", false, "object is nil") return end
        local s, e = pcall(function() TweenService:Create(obj, info, props):Play() end)
        if s then log(componentName or "Tween", true) else log(componentName or "Tween", false, e) end
    end

    safeTween(letterTop, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0),
    }, "Letterbox Top Slide In")
    safeTween(letterBot, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 1 - LETTERBOX_HEIGHT, 0),
    }, "Letterbox Bottom Slide In")

    -- ──────────────────────────────────────────
    --  DARK OVERLAY
    -- ──────────────────────────────────────────
    local overlay
    local overlaySuccess, overlayErr = pcall(function()
        overlay = Instance.new("Frame")
        overlay.Name = "Overlay"
        overlay.Size = UDim2.new(1, 0, 1, 0)
        overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        overlay.BackgroundTransparency = 0.35
        overlay.BorderSizePixel = 0
        overlay.ZIndex = 1
        overlay.Parent = screenGui
    end)
    log("Dark overlay", overlaySuccess, overlayErr)

    -- ──────────────────────────────────────────
    --  SCAN-LINE TEXTURE OVERLAY
    -- ──────────────────────────────────────────
    local scanSuccess, scanErr = pcall(function()
        local scanlines = Instance.new("Frame")
        scanlines.Name = "Scanlines"
        scanlines.Size = UDim2.new(1, 0, 1, 0)
        scanlines.BackgroundTransparency = 1
        scanlines.BorderSizePixel = 0
        scanlines.ZIndex = 2
        scanlines.Parent = screenGui

        local scanGrid = Instance.new("UIGridLayout")
        scanGrid.CellSize = UDim2.new(1, 0, 0, 4)
        scanGrid.CellPadding = UDim2.new(0, 0, 0, 0)
        scanGrid.Parent = scanlines

        for i = 1, 300 do
            local line = Instance.new("Frame")
            line.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            line.BackgroundTransparency = 0.88
            line.BorderSizePixel = 0
            line.Size = UDim2.new(1, 0, 0, 2)
            line.Parent = scanlines
        end
    end)
    log("Scanlines overlay", scanSuccess, scanErr)

    -- ──────────────────────────────────────────
    --  VIDEO / ANIMATION CONTAINER
    -- ──────────────────────────────────────────
    local animContainer
    local videoFrame
    local animGlow

    local animSuccess, animErr = pcall(function()
        animContainer = Instance.new("Frame")
        animContainer.Name = "AnimContainer"
        animContainer.Size = UDim2.new(0.52, 0, 0.62, 0)
        animContainer.AnchorPoint = Vector2.new(0.5, 0.5)
        animContainer.Position = UDim2.new(0.5, 0, 0.47, 0)
        animContainer.BackgroundTransparency = 1
        animContainer.ZIndex = 3
        animContainer.Parent = screenGui

        if videoLoaded then
            videoFrame = Instance.new("VideoFrame")
            videoFrame.Name = "IntroVideo"
            videoFrame.Size = UDim2.new(1, 0, 1, 0)
            videoFrame.BackgroundTransparency = 1
            videoFrame.Video = resolvedVideo
            videoFrame.Looped = false
            videoFrame.ZIndex = 3
            videoFrame.Parent = animContainer

            animGlow = Instance.new("ImageLabel")
            animGlow.Name = "AnimGlow"
            animGlow.Size = UDim2.new(1.4, 0, 1.4, 0)
            animGlow.AnchorPoint = Vector2.new(0.5, 0.5)
            animGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
            animGlow.BackgroundTransparency = 1
            animGlow.Image = "rbxassetid://1316045217"
            animGlow.ImageColor3 = Color3.fromRGB(140, 60, 255)
            animGlow.ImageTransparency = 0.75
            animGlow.ScaleType = Enum.ScaleType.Slice
            animGlow.SliceCenter = Rect.new(10, 10, 118, 118)
            animGlow.ZIndex = 2
            animGlow.Parent = animContainer

            pcall(function() videoFrame:Play() end)
        end
    end)
    if animSuccess then
        log("Animation container", true)
        if videoLoaded then log("VideoFrame", true) else log("VideoFrame", false, "video not loaded") end
    else
        log("Animation container", false, animErr)
    end

    -- ──────────────────────────────────────────
    --  TITLE BLOCK
    -- ──────────────────────────────────────────
    local titleFrame, titleLabel, subLabel, accentBar
    local titleSuccess, titleErr = pcall(function()
        titleFrame = Instance.new("Frame")
        titleFrame.Name = "TitleBlock"
        titleFrame.Size = UDim2.new(0, 340, 0, 72)
        titleFrame.AnchorPoint = Vector2.new(0.5, 1)
        titleFrame.Position = UDim2.new(0.5, 0, 0.88, 0)
        titleFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 18)
        titleFrame.BackgroundTransparency = 0.15
        titleFrame.BorderSizePixel = 0
        titleFrame.ZIndex = 5
        titleFrame.Parent = screenGui

        local titleCorner = Instance.new("UICorner")
        titleCorner.CornerRadius = UDim.new(0, 6)
        titleCorner.Parent = titleFrame

        accentBar = Instance.new("Frame")
        accentBar.Size = UDim2.new(1, 0, 0, 2)
        accentBar.Position = UDim2.new(0, 0, 0, 0)
        accentBar.BackgroundColor3 = Color3.fromRGB(180, 80, 255)
        accentBar.BorderSizePixel = 0
        accentBar.ZIndex = 6
        accentBar.Parent = titleFrame
        Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 6)
        Instance.new("UIGradient", accentBar).Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 180, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 80, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 160)),
        })

        titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TitleText"
        titleLabel.Size = UDim2.new(1, 0, 0.62, 0)
        titleLabel.Position = UDim2.new(0, 0, 0.05, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = "NOVA HUB"
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.Font = Enum.Font.GothamBlack
        titleLabel.TextScaled = true
        titleLabel.TextStrokeTransparency = 0.4
        titleLabel.TextStrokeColor3 = Color3.fromRGB(160, 80, 255)
        titleLabel.ZIndex = 6
        titleLabel.Parent = titleFrame
        local titleGrad = Instance.new("UIGradient")
        titleGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 130, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 200, 255)),
        })
        titleGrad.Rotation = 45
        titleGrad.Parent = titleLabel

        subLabel = Instance.new("TextLabel")
        subLabel.Name = "SubText"
        subLabel.Size = UDim2.new(1, 0, 0.28, 0)
        subLabel.Position = UDim2.new(0, 0, 0.68, 0)
        subLabel.BackgroundTransparency = 1
        subLabel.Text = "by 4nax  ·  loading . . ."
        subLabel.TextColor3 = Color3.fromRGB(160, 160, 200)
        subLabel.Font = Enum.Font.Gotham
        subLabel.TextScaled = true
        subLabel.TextTransparency = 0.25
        subLabel.ZIndex = 6
        subLabel.Parent = titleFrame
    end)
    log("Title block", titleSuccess, titleErr)

    -- ──────────────────────────────────────────
    --  PROGRESS BAR
    -- ──────────────────────────────────────────
    local progressBG, progressFill
    local progSuccess, progErr = pcall(function()
        progressBG = Instance.new("Frame")
        progressBG.Name = "ProgressBG"
        progressBG.Size = UDim2.new(0, 340, 0, 4)
        progressBG.AnchorPoint = Vector2.new(0.5, 0)
        progressBG.Position = UDim2.new(0.5, 0, 0.89, 0)
        progressBG.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
        progressBG.BorderSizePixel = 0
        progressBG.ZIndex = 5
        progressBG.Parent = screenGui
        Instance.new("UICorner", progressBG).CornerRadius = UDim.new(1, 0)

        progressFill = Instance.new("Frame")
        progressFill.Name = "ProgressFill"
        progressFill.Size = UDim2.new(0, 0, 1, 0)
        progressFill.BackgroundColor3 = Color3.fromRGB(180, 80, 255)
        progressFill.BorderSizePixel = 0
        progressFill.ZIndex = 6
        progressFill.Parent = progressBG
        Instance.new("UICorner", progressFill).CornerRadius = UDim.new(1, 0)
        Instance.new("UIGradient", progressFill).Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 180, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 80, 255)),
        })
    end)
    log("Progress bar", progSuccess, progErr)

    -- ──────────────────────────────────────────
    --  CORNER DECORATIONS
    -- ──────────────────────────────────────────
    local cornerSuccess, cornerErr = pcall(function()
        local function makeCornerDeco(xAnchor, yAnchor, xPos, yPos, rotated)
            local deco = Instance.new("Frame")
            deco.Size = UDim2.new(0, 60, 0, 60)
            deco.AnchorPoint = Vector2.new(xAnchor, yAnchor)
            deco.Position = UDim2.new(xPos, 0, yPos, 0)
            deco.BackgroundTransparency = 1
            deco.ZIndex = 4
            deco.Parent = screenGui
            local borderL = Instance.new("Frame")
            borderL.Size = UDim2.new(0, 2, 0, 40)
            borderL.Position = rotated and UDim2.new(1, -2, 0, 0) or UDim2.new(0, 0, 0, 0)
            borderL.BackgroundColor3 = Color3.fromRGB(180, 80, 255)
            borderL.BackgroundTransparency = 0.3
            borderL.BorderSizePixel = 0
            borderL.ZIndex = 4
            borderL.Parent = deco
            local borderT = Instance.new("Frame")
            borderT.Size = UDim2.new(0, 40, 0, 2)
            borderT.Position = rotated and UDim2.new(1, -40, 1, -2) or UDim2.new(0, 0, 0, 0)
            borderT.BackgroundColor3 = Color3.fromRGB(180, 80, 255)
            borderT.BackgroundTransparency = 0.3
            borderT.BorderSizePixel = 0
            borderT.ZIndex = 4
            borderT.Parent = deco
        end
        makeCornerDeco(0, 0, 0.02, 0.03, false)
        makeCornerDeco(1, 0, 0.98, 0.03, true)
        makeCornerDeco(0, 1, 0.02, 0.97, false)
        makeCornerDeco(1, 1, 0.98, 0.97, true)
    end)
    log("Corner decorations", cornerSuccess, cornerErr)

    -- ──────────────────────────────────────────
    --  PLAYER HIGHLIGHT EFFECT
    -- ──────────────────────────────────────────
    local highlight
    local highSuccess, highErr = pcall(function()
        highlight = Instance.new("Highlight")
        highlight.FillColor = Color3.fromRGB(100, 80, 255)
        highlight.FillTransparency = 0.7
        highlight.OutlineColor = Color3.fromRGB(200, 80, 255)
        highlight.OutlineTransparency = 0.1
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    end)
    if highSuccess then
        local function applyHighlight(character)
            if not character then return end
            pcall(function()
                highlight.Adornee = character
                highlight.Parent = character
            end)
        end
        localPlayer.CharacterAdded:Connect(applyHighlight)
        if localPlayer.Character then applyHighlight(localPlayer.Character) end
        log("Player highlight", true)
    else
        log("Player highlight", false, highErr)
    end

    -- ──────────────────────────────────────────
    --  TITLE ENTRANCE TWEEN
    -- ──────────────────────────────────────────
    if titleFrame then
        titleFrame.Position = UDim2.new(0.5, 0, 1.05, 0)
        titleFrame.BackgroundTransparency = 1
        titleLabel.TextTransparency = 1
        subLabel.TextTransparency = 1

        task.delay(0.4, function()
            safeTween(titleFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, 0, 0.88, 0),
                BackgroundTransparency = 0.15,
            }, "Title Frame Slide In")
            task.delay(0.2, function()
                safeTween(titleLabel, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { TextTransparency = 0 }, "Title Label Fade")
                safeTween(subLabel,   TweenInfo.new(0.45, Enum.EasingStyle.Quad), { TextTransparency = 0.25 }, "Subtitle Label Fade")
            end)
        end)
    end

    -- ──────────────────────────────────────────
    --  GLOW PULSE
    -- ──────────────────────────────────────────
    local animRunning = videoLoaded
    if animGlow then
        task.spawn(function()
            while animRunning do
                safeTween(animGlow, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = 0.55 }, "Glow Pulse Up")
                task.wait(1.2)
                safeTween(animGlow, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = 0.82 }, "Glow Pulse Down")
                task.wait(1.2)
            end
        end)
        task.delay(5.0, function()
            if animRunning then pcall(function() videoFrame:Play() end) end
        end)
    end

    -- ──────────────────────────────────────────
    --  MAIN LOOP
    -- ──────────────────────────────────────────
    local step = 0
    local fillTrans = 0.7
    local outlineTrans = 0.1

    local loopSuccess, loopErr = pcall(function()
        while step < TOTAL_STEPS do
            step = step + 1
            if blur_ then blur_.Size = BLUR_START - step end
            safeTween(progressFill, TweenInfo.new(FADE_DURATION * 1.2, Enum.EasingStyle.Linear), {
                Size = UDim2.new(step / TOTAL_STEPS, 0, 1, 0),
            })

            local t = tick()
            local r = math.floor(math.sin(t)     * 127 + 128)
            local g = math.floor(math.sin(t + 2) * 127 + 128)
            local b = math.floor(math.sin(t + 4) * 127 + 128)
            fillTrans    = math.min(fillTrans    + 0.009, 1)
            outlineTrans = math.min(outlineTrans + 0.009, 1)

            if highlight then
                pcall(function()
                    highlight.FillColor = Color3.fromRGB(r, g, b)
                    highlight.FillTransparency = fillTrans
                    highlight.OutlineColor = Color3.fromRGB(255 - r, 255 - g, 255 - b)
                    highlight.OutlineTransparency = outlineTrans
                end)
            end

            if accentBar then
                pcall(function() accentBar.BackgroundColor3 = Color3.fromRGB(r, g, b) end)
            end

            task.wait(FADE_DURATION)
        end
    end)
    if loopSuccess then log("Loading progression loop", true) else log("Loading progression loop", false, loopErr) end

    -- ──────────────────────────────────────────
    --  OUTRO
    -- ──────────────────────────────────────────
    animRunning = false

    if spinConnection then
        spinConnection:Disconnect()
        spinConnection = nil
        log("Viewport spin stopped", true)
    end
    characterSpinRunning = false

    safeTween(progressFill, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
        Size = UDim2.new(1, 0, 1, 0),
    }, "Progress Bar Complete")

    task.wait(0.2)

    safeTween(titleFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
        Position = UDim2.new(0.5, 0, 1.05, 0),
        BackgroundTransparency = 1,
    }, "Title Frame Slide Out")
    safeTween(titleLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { TextTransparency = 1 }, "Title Label Fade Out")
    safeTween(subLabel,   TweenInfo.new(0.3, Enum.EasingStyle.Quad), { TextTransparency = 1 }, "Subtitle Label Fade Out")

    safeTween(overlay, TweenInfo.new(0.55, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }, "Overlay Fade Out")
    safeTween(viewportFrame, TweenInfo.new(0.55, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }, "Viewport Fade Out")

    if videoFrame then
        pcall(function()
            videoFrame.Visible = false
            log("Video hidden (no fade support)", true)
        end)
    end

    if animGlow then
        safeTween(animGlow, TweenInfo.new(0.55, Enum.EasingStyle.Quad), { ImageTransparency = 1 }, "Glow Fade Out")
    end

    safeTween(progressBG, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }, "Progress Bar Fade Out")

    safeTween(letterTop, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        Position = UDim2.new(0, 0, -LETTERBOX_HEIGHT, 0),
    }, "Letterbox Top Slide Out")
    safeTween(letterBot, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        Position = UDim2.new(0, 0, 1, 0),
    }, "Letterbox Bottom Slide Out")

    task.wait(0.6)

    -- ──────────────────────────────────────────
    --  FINAL CLEANUP
    -- ──────────────────────────────────────────
    pcall(function() blur_.Enabled = false; blur_:Destroy(); log("Blur destroyed", true) end)
    pcall(function() highlight:Destroy(); log("Highlight destroyed", true) end)
    if avatarModel then
        pcall(function() avatarModel:Destroy(); log("Avatar model destroyed", true) end)
    end
    pcall(function() screenGui:Destroy(); log("ScreenGui destroyed", true) end)

    if getgenv().Nova_LS_Debug then
        print("\n[ Nova - Loading Screen ] Report:")
        for _, entry in ipairs(logEntries) do print(entry) end
    end
    print("[Nova - Loading Screen] Finished.")
end

initiate_loading_screen()
