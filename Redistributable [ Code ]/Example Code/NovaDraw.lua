-- NovaHub | NovaDraw Rayfield UI v2.1

local NovaDraw = loadstring(game:HttpGet("https://raw.githubusercontent.com/4naxYT/Nova-hub/refs/heads/main/Redistributable%20%5B%20Code%20%5D/Custom%20Drawing%20Api%20%5B%20Universal%20%5D.lua"))()
local Rayfield  = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- ══════════════════════════════════════════
--  SERVICES
-- ══════════════════════════════════════════

local UIS     = game:GetService("UserInputService")
local RS      = game:GetService("RunService")
local Players = game:GetService("Players")
local LP      = Players.LocalPlayer
local Camera  = workspace.CurrentCamera

-- ══════════════════════════════════════════
--  STATE
-- ══════════════════════════════════════════

local loops      = {}   -- [name] = RBXScriptConnection
local taggedObjs = {}   -- [tag]  = { NovaDraw objects }
local espData    = {}   -- [Player] = { box, name, health, tracer, dist }

local CFG = {
    color          = Color3.fromRGB(255, 80,  80),
    thickness      = 2,
    opacity        = 1,
    filled         = false,
    radius         = 60,
    offsetX        = 0,
    offsetY        = 0,
    screenOffX     = 0,
    screenOffY     = 0,
    rounded        = true,
    orbitSpeed     = 3,
    sides          = 6,
    spokeCount     = 8,
    crossGap       = 4,
    crossLen       = 10,
    fovOn          = false,
    fovRadius      = 120,
    fovObj         = nil,
    espOn          = false,
    espBoxType     = "Corner",
    espShowNames   = true,
    espShowHealth  = true,
    espShowDist    = true,
    espShowTracer  = false,
    espMaxDist     = 500,
    espBoxColor    = Color3.fromRGB(255, 80,  80),
    espNameColor   = Color3.fromRGB(255, 255, 255),
    espTracerColor = Color3.fromRGB(255, 80,  80),
}

-- ══════════════════════════════════════════
--  LOOP HELPERS
-- ══════════════════════════════════════════

local function stopLoop(name)
    if loops[name] then
        loops[name]:Disconnect()
        loops[name] = nil
    end
end

local function stopAllLoops()
    for name in pairs(loops) do stopLoop(name) end
end

-- ══════════════════════════════════════════
--  OBJECT TRACKING
--  Every spawned NovaDraw object is stored
--  under a tag so toggling off only removes
--  that feature's objects cleanly via the
--  API's own NovaDraw.remove() path
-- ══════════════════════════════════════════

local function trackObj(tag, obj)
    if not taggedObjs[tag] then taggedObjs[tag] = {} end
    table.insert(taggedObjs[tag], obj)
end

local function clearTag(tag)
    if not taggedObjs[tag] then return end
    for _, obj in ipairs(taggedObjs[tag]) do
        NovaDraw.remove(obj)
    end
    taggedObjs[tag] = nil
end

local function clearAllTags()
    for tag in pairs(taggedObjs) do clearTag(tag) end
end

-- ══════════════════════════════════════════
--  ANCHOR HELPERS
-- ══════════════════════════════════════════

local function getAnchor()
    local mp = UIS:GetMouseLocation()
    return mp.X + CFG.offsetX + CFG.screenOffX,
           mp.Y + CFG.offsetY + CFG.screenOffY
end

local function getScreenPt(x, y)
    return x + CFG.screenOffX, y + CFG.screenOffY
end

-- ══════════════════════════════════════════
--  ESP HELPERS
-- ══════════════════════════════════════════

local function removeESP(player)
    if not espData[player] then return end
    local d = espData[player]
    for _, key in ipairs({"box","name","health","tracer","dist"}) do
        if d[key] then
            NovaDraw.remove(d[key])
            d[key] = nil
        end
    end
    espData[player] = nil
end

local function removeAllESP()
    for _, p in ipairs(Players:GetPlayers()) do removeESP(p) end
    espData = {}
end

local function hideESPPlayer(d)
    if d.box then
        if d.box._lines then
            for _, ln in ipairs(d.box._lines) do
                if ln._frame then ln._frame.Visible = false end
            end
        elseif d.box._frame  then d.box._frame.Visible  = false
        elseif d.box._frames then
            for _, f in ipairs(d.box._frames) do f.Visible = false end
        end
    end
    if d.name   then d.name._container.Visible          = false end
    if d.health then d.health._bg.Visible = false; d.health._fill.Visible = false end
    if d.tracer then d.tracer._frame.Visible             = false end
    if d.dist   then d.dist._container.Visible           = false end
end

local function updateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LP then continue end
        if not espData[player] then espData[player] = {} end
        local d   = espData[player]
        local chr = player.Character
        local hrp = chr and (chr:FindFirstChild("HumanoidRootPart") or chr:FindFirstChild("HoodieRootPart"))
        local hum = chr and chr:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then hideESPPlayer(d); continue end

        local pos3D, onScreen = Camera:WorldToViewportPoint(hrp.Position)
        if not onScreen then hideESPPlayer(d); continue end

        local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
        if dist > CFG.espMaxDist then hideESPPlayer(d); continue end

        local scale = 1600 / pos3D.Z
        local bw = math.max(math.floor(scale * 0.4), 20)
        local bh = math.max(math.floor(scale * 1.1), 40)
        local bx = math.floor(pos3D.X - bw/2)
        local by = math.floor(pos3D.Y - bh/2)
        local hp = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)

        -- box
        if CFG.espBoxType == "Corner" then
            local cl = math.max(math.floor(bw * 0.28), 6)
            if not d.box then
                d.box = NovaDraw.cornerBox(bx,by,bw,bh,cl,CFG.thickness,CFG.espBoxColor,CFG.opacity)
            else
                local pts = {{bx,by},{bx+bw,by},{bx+bw,by+bh},{bx,by+bh}}
                NovaDraw.moveLine(d.box._lines[1],pts[1][1],pts[1][2],pts[1][1]+cl,pts[1][2])
                NovaDraw.moveLine(d.box._lines[2],pts[1][1],pts[1][2],pts[1][1],pts[1][2]+cl)
                NovaDraw.moveLine(d.box._lines[3],pts[2][1],pts[2][2],pts[2][1]-cl,pts[2][2])
                NovaDraw.moveLine(d.box._lines[4],pts[2][1],pts[2][2],pts[2][1],pts[2][2]+cl)
                NovaDraw.moveLine(d.box._lines[5],pts[4][1],pts[4][2],pts[4][1]+cl,pts[4][2])
                NovaDraw.moveLine(d.box._lines[6],pts[4][1],pts[4][2],pts[4][1],pts[4][2]-cl)
                NovaDraw.moveLine(d.box._lines[7],pts[3][1],pts[3][2],pts[3][1]-cl,pts[3][2])
                NovaDraw.moveLine(d.box._lines[8],pts[3][1],pts[3][2],pts[3][1],pts[3][2]-cl)
                for _, ln in ipairs(d.box._lines) do
                    if ln._frame then ln._frame.Visible = true end
                    NovaDraw.recolor(ln, CFG.espBoxColor)
                end
            end
        else
            if not d.box then
                d.box = NovaDraw.box(bx,by,bw,bh,CFG.thickness,CFG.espBoxColor,CFG.opacity,4)
            else
                NovaDraw.moveSquare(d.box, bx, by)
                NovaDraw.setVisible(d.box, true)
                NovaDraw.recolor(d.box, CFG.espBoxColor)
            end
        end

        -- name
        if CFG.espShowNames then
            local ns = player.DisplayName.." ["..player.Name.."]"
            if not d.name then
                d.name = NovaDraw.text(bx, by-18, ns, 12, CFG.espNameColor, CFG.opacity, true)
            else
                NovaDraw.moveText(d.name, bx, by-18)
                NovaDraw.setText(d.name, ns)
                NovaDraw.recolor(d.name, CFG.espNameColor)
                d.name._container.Visible = true
            end
        else
            if d.name then d.name._container.Visible = false end
        end

        -- health
        if CFG.espShowHealth then
            if not d.health then
                d.health = NovaDraw.healthBar(bx-8, by, 5, bh, hp, Color3.fromRGB(80,255,80), CFG.opacity)
            else
                d.health._x = bx-8; d.health._y = by; d.health._h = bh
                d.health._bg.Position  = UDim2.fromOffset(bx-8, by)
                d.health._bg.Size      = UDim2.fromOffset(5, bh)
                d.health._bg.Visible   = true
                d.health._fill.Visible = true
                NovaDraw.updateHealthBar(d.health, hp)
            end
        else
            if d.health then
                d.health._bg.Visible   = false
                d.health._fill.Visible = false
            end
        end

        -- distance
        if CFG.espShowDist then
            local ds = math.floor(dist).."m"
            if not d.dist then
                d.dist = NovaDraw.text(bx+bw+4, by+bh/2-7, ds, 11, Color3.fromRGB(200,200,200), CFG.opacity, true)
            else
                NovaDraw.moveText(d.dist, bx+bw+4, by+bh/2-7)
                NovaDraw.setText(d.dist, ds)
                d.dist._container.Visible = true
            end
        else
            if d.dist then d.dist._container.Visible = false end
        end

        -- tracer
        if CFG.espShowTracer then
            local vp = Camera.ViewportSize
            local ox, oy = getScreenPt(vp.X/2, vp.Y)
            local tx, ty = math.floor(pos3D.X), math.floor(pos3D.Y)
            if not d.tracer then
                d.tracer = NovaDraw.tracer(ox,oy,tx,ty,1,CFG.espTracerColor,CFG.opacity*0.7)
            else
                NovaDraw.moveLine(d.tracer, ox,oy, tx,ty)
                d.tracer._frame.Visible = true
                NovaDraw.recolor(d.tracer, CFG.espTracerColor)
            end
        else
            if d.tracer then d.tracer._frame.Visible = false end
        end
    end
end

-- ══════════════════════════════════════════
--  MASTER CLEANUP
-- ══════════════════════════════════════════

local function fullCleanup()
    stopAllLoops()   -- 1. kill all RenderStepped loops first
    removeAllESP()   -- 2. remove ESP via NovaDraw.remove per object
    clearAllTags()   -- 3. remove all tagged shape objects via NovaDraw.remove
end

-- ══════════════════════════════════════════
--  WINDOW
-- ══════════════════════════════════════════

local Window = Rayfield:CreateWindow({
    Name                   = "NovaHub | NovaDraw",
    Icon                   = "pentagon",
    LoadingTitle           = "NovaHub",
    LoadingSubtitle        = "NovaDraw UI v2.1",
    ShowText               = "NovaHub",
    Theme                  = "Default",
    ToggleUIKeybind        = "K",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings   = false,
    ConfigurationSaving    = { Enabled=true, FolderName="NovaHub", FileName="NovaDraw" },
    Discord                = { Enabled=false, Invite="", RememberJoins=false },
    KeySystem              = false,
})

-- ══════════════════════════════════════════
--  TAB 1 — SHAPES
-- ══════════════════════════════════════════

local ShapeTab = Window:CreateTab("Shapes", "shapes")

ShapeTab:CreateParagraph({
    Title   = "Mouse Shapes",
    Content = "Shapes that follow your mouse. Toggle on, adjust settings in Config, toggle off to remove cleanly.",
})
ShapeTab:CreateDivider()

-- Circle
ShapeTab:CreateSection("Circle")
local circleOn = false
ShapeTab:CreateToggle({ Name="Mouse Circle", CurrentValue=false, Flag="SH_CIRC",
    Callback = function(v)
        circleOn = v
        stopLoop("circ"); clearTag("circ")
        if not v then return end
        local ax,ay = getAnchor()
        local obj = NovaDraw.circle(ax,ay,CFG.radius,CFG.thickness,CFG.color,CFG.filled,CFG.opacity)
        trackObj("circ", obj)
        loops["circ"] = RS.RenderStepped:Connect(function()
            if not circleOn then return end
            local x,y = getAnchor()
            NovaDraw.moveCircle(obj, x, y)
            NovaDraw.recolor(obj,    CFG.color)
            NovaDraw.setOpacity(obj, CFG.opacity)
        end)
    end,
})

-- Square
ShapeTab:CreateSection("Square")
local squareOn = false
ShapeTab:CreateToggle({ Name="Mouse Square", CurrentValue=false, Flag="SH_SQ",
    Callback = function(v)
        squareOn = v
        stopLoop("sq"); clearTag("sq")
        if not v then return end
        local ax,ay = getAnchor(); local s = CFG.radius
        local obj = NovaDraw.square(ax-s,ay-s,s*2,s*2,CFG.thickness,CFG.color,CFG.filled,CFG.opacity,CFG.rounded and 6 or 0)
        trackObj("sq", obj)
        loops["sq"] = RS.RenderStepped:Connect(function()
            if not squareOn then return end
            local x,y = getAnchor(); local sz = CFG.radius
            NovaDraw.moveSquare(obj, x-sz, y-sz)
            NovaDraw.recolor(obj,    CFG.color)
            NovaDraw.setOpacity(obj, CFG.opacity)
        end)
    end,
})

-- Triangle
ShapeTab:CreateSection("Triangle")
local triOn = false
ShapeTab:CreateToggle({ Name="Mouse Triangle", CurrentValue=false, Flag="SH_TRI",
    Callback = function(v)
        triOn = v
        stopLoop("tri"); clearTag("tri")
        if not v then return end
        local ax,ay = getAnchor(); local r = CFG.radius
        local obj = NovaDraw.triangle(ax,ay-r,ax-r,ay+r,ax+r,ay+r,CFG.thickness,CFG.color,CFG.opacity,CFG.rounded)
        trackObj("tri", obj)
        loops["tri"] = RS.RenderStepped:Connect(function()
            if not triOn then return end
            local x,y = getAnchor(); local r2 = CFG.radius
            NovaDraw.moveLine(obj._lines[1], x,y-r2,   x-r2,y+r2)
            NovaDraw.moveLine(obj._lines[2], x-r2,y+r2, x+r2,y+r2)
            NovaDraw.moveLine(obj._lines[3], x+r2,y+r2, x,y-r2)
            NovaDraw.recolor(obj,    CFG.color)
            NovaDraw.setOpacity(obj, CFG.opacity)
        end)
    end,
})

-- Diamond
ShapeTab:CreateSection("Diamond")
local diamondOn = false
ShapeTab:CreateToggle({ Name="Mouse Diamond", CurrentValue=false, Flag="SH_DM",
    Callback = function(v)
        diamondOn = v
        stopLoop("dm"); clearTag("dm")
        if not v then return end
        local ax,ay = getAnchor()
        local obj = NovaDraw.diamond(ax,ay,CFG.radius,CFG.thickness,CFG.color,CFG.opacity)
        trackObj("dm", obj)
        loops["dm"] = RS.RenderStepped:Connect(function()
            if not diamondOn then return end
            local x,y = getAnchor(); local r = CFG.radius
            NovaDraw.moveLine(obj._lines[1], x,y-r, x+r,y)
            NovaDraw.moveLine(obj._lines[2], x+r,y, x,y+r)
            NovaDraw.moveLine(obj._lines[3], x,y+r, x-r,y)
            NovaDraw.moveLine(obj._lines[4], x-r,y, x,y-r)
            NovaDraw.recolor(obj,    CFG.color)
            NovaDraw.setOpacity(obj, CFG.opacity)
        end)
    end,
})

-- Star
ShapeTab:CreateSection("Star")
local starOn = false
ShapeTab:CreateToggle({ Name="Mouse Star", CurrentValue=false, Flag="SH_ST",
    Callback = function(v)
        starOn = v
        stopLoop("st"); clearTag("st")
        if not v then return end
        local ax,ay = getAnchor()
        local obj = NovaDraw.star(ax,ay,CFG.radius,CFG.radius*0.45,5,CFG.thickness,CFG.color,CFG.opacity)
        trackObj("st", obj)
        loops["st"] = RS.RenderStepped:Connect(function()
            if not starOn then return end
            local x,y = getAnchor()
            local oR = CFG.radius; local iR = oR*0.45
            local pts = {}
            for i=0,9 do
                local a=(math.pi*i/5)-math.pi/2
                local r=(i%2==0) and oR or iR
                table.insert(pts,{x+math.cos(a)*r,y+math.sin(a)*r})
            end
            for i,ln in ipairs(obj._lines) do
                local n=(i%10)+1
                NovaDraw.moveLine(ln,pts[i][1],pts[i][2],pts[n][1],pts[n][2])
            end
            NovaDraw.recolor(obj,    CFG.color)
            NovaDraw.setOpacity(obj, CFG.opacity)
        end)
    end,
})

-- Polygon
ShapeTab:CreateSection("Polygon")
local polyOn = false
ShapeTab:CreateDropdown({ Name="Sides", Options={"3","4","5","6","7","8","10","12"},
    CurrentOption={"6"}, Flag="SH_PLYS", MultipleOptions=false,
    Callback=function(v) CFG.sides=tonumber(type(v)=="table" and v[1] or v) or 6 end })
ShapeTab:CreateToggle({ Name="Mouse Polygon", CurrentValue=false, Flag="SH_PLY",
    Callback = function(v)
        polyOn = v
        stopLoop("ply"); clearTag("ply")
        if not v then return end
        local ax,ay = getAnchor()
        local obj = NovaDraw.polygon(ax,ay,CFG.sides,CFG.radius,CFG.thickness,CFG.color,CFG.opacity)
        trackObj("ply", obj)
        loops["ply"] = RS.RenderStepped:Connect(function()
            if not polyOn then return end
            local x,y=getAnchor(); local r=CFG.radius; local s=CFG.sides
            local pts={}
            for i=0,s-1 do
                local a=(2*math.pi*i/s)-math.pi/2
                table.insert(pts,{x+math.cos(a)*r,y+math.sin(a)*r})
            end
            for i,ln in ipairs(obj._lines) do
                local n=(i%s)+1
                NovaDraw.moveLine(ln,pts[i][1],pts[i][2],pts[n][1],pts[n][2])
                NovaDraw.recolor(ln,    CFG.color)
                NovaDraw.setOpacity(ln, CFG.opacity)
            end
        end)
    end,
})

-- Spiral
ShapeTab:CreateSection("Spiral")
local spiralOn = false
ShapeTab:CreateToggle({ Name="Mouse Spiral", CurrentValue=false, Flag="SH_SPR",
    Callback = function(v)
        spiralOn = v
        stopLoop("spr"); clearTag("spr")
        if not v then return end
        local ax,ay = getAnchor()
        local obj = NovaDraw.spiral(ax,ay,5,CFG.radius,3,60,CFG.thickness,CFG.color,CFG.opacity)
        trackObj("spr", obj)
        loops["spr"] = RS.RenderStepped:Connect(function()
            if not spiralOn then return end
            local x,y=getAnchor(); local pts={}
            for i=0,60 do
                local t2=i/60
                local ang=t2*3*math.pi*2
                local r=5+(CFG.radius-5)*t2
                table.insert(pts,{x+math.cos(ang)*r,y+math.sin(ang)*r})
            end
            for i,ln in ipairs(obj._lines) do
                if pts[i] and pts[i+1] then
                    NovaDraw.moveLine(ln,pts[i][1],pts[i][2],pts[i+1][1],pts[i+1][2])
                end
                NovaDraw.recolor(ln,    CFG.color)
                NovaDraw.setOpacity(ln, CFG.opacity)
            end
        end)
    end,
})

-- ══════════════════════════════════════════
--  TAB 2 — LINES
-- ══════════════════════════════════════════

local LineTab = Window:CreateTab("Lines", "move-diagonal")

LineTab:CreateParagraph({
    Title   = "Line Tools",
    Content = "Crosshair, tracers, connectors, spokes and arrows anchored to mouse or screen.",
})
LineTab:CreateDivider()

-- Crosshair
LineTab:CreateSection("Crosshair")
local crossOn = false
LineTab:CreateToggle({ Name="Crosshair", CurrentValue=false, Flag="LN_CRH",
    Callback = function(v)
        crossOn = v
        stopLoop("crh"); clearTag("crh")
        if not v then return end
        local ax,ay = getAnchor()
        local obj = NovaDraw.crosshair(ax,ay,CFG.crossLen,CFG.crossGap,CFG.thickness,CFG.color,CFG.opacity)
        trackObj("crh", obj)
        loops["crh"] = RS.RenderStepped:Connect(function()
            if not crossOn then return end
            local x,y = getAnchor()
            NovaDraw.moveCrosshair(obj, x, y)
            NovaDraw.recolor(obj,    CFG.color)
            NovaDraw.setOpacity(obj, CFG.opacity)
        end)
    end,
})
LineTab:CreateSlider({ Name="Length", Range={5,80}, Increment=1, Suffix="px",
    CurrentValue=10, Flag="LN_CRHL", Callback=function(v) CFG.crossLen=v end })
LineTab:CreateSlider({ Name="Gap",    Range={0,20}, Increment=1, Suffix="px",
    CurrentValue=4,  Flag="LN_CRHG", Callback=function(v) CFG.crossGap=v end })

-- Center connector
LineTab:CreateSection("Center Connector")
local centerOn = false
LineTab:CreateToggle({ Name="Center → Mouse", CurrentValue=false, Flag="LN_CTR",
    Callback = function(v)
        centerOn = v
        stopLoop("ctr"); clearTag("ctr")
        if not v then return end
        local vp=Camera.ViewportSize
        local sx,sy=getScreenPt(vp.X/2,vp.Y/2)
        local ax,ay=getAnchor()
        local obj=NovaDraw.line(sx,sy,ax,ay,CFG.thickness,CFG.color,CFG.opacity,true)
        trackObj("ctr",obj)
        loops["ctr"]=RS.RenderStepped:Connect(function()
            if not centerOn then return end
            local vp2=Camera.ViewportSize
            local ox,oy=getScreenPt(vp2.X/2,vp2.Y/2)
            local tx,ty=getAnchor()
            NovaDraw.moveLine(obj,ox,oy,tx,ty)
            NovaDraw.recolor(obj,    CFG.color)
            NovaDraw.setOpacity(obj, CFG.opacity)
        end)
    end,
})

-- Bottom tracer
LineTab:CreateSection("Bottom Tracer")
local tracerOn = false
LineTab:CreateToggle({ Name="Bottom Tracer", CurrentValue=false, Flag="LN_BTR",
    Callback = function(v)
        tracerOn = v
        stopLoop("btr"); clearTag("btr")
        if not v then return end
        local vp=Camera.ViewportSize
        local sx,sy=getScreenPt(vp.X/2,vp.Y)
        local ax,ay=getAnchor()
        local obj=NovaDraw.tracer(sx,sy,ax,ay,CFG.thickness,CFG.color,CFG.opacity)
        trackObj("btr",obj)
        loops["btr"]=RS.RenderStepped:Connect(function()
            if not tracerOn then return end
            local vp2=Camera.ViewportSize
            local ox,oy=getScreenPt(vp2.X/2,vp2.Y)
            local tx,ty=getAnchor()
            NovaDraw.moveLine(obj,ox,oy,tx,ty)
            NovaDraw.recolor(obj,    CFG.color)
            NovaDraw.setOpacity(obj, CFG.opacity)
        end)
    end,
})

-- Arrow
LineTab:CreateSection("Arrow")
local arrowOn = false
LineTab:CreateToggle({ Name="Mouse Arrow", CurrentValue=false, Flag="LN_ARR",
    Callback = function(v)
        arrowOn = v
        stopLoop("arr"); clearTag("arr")
        if not v then return end
        local ax,ay=getAnchor()
        local obj=NovaDraw.arrow(ax,ay+CFG.radius,ax,ay,CFG.thickness,CFG.color,CFG.opacity,14)
        trackObj("arr",obj)
        loops["arr"]=RS.RenderStepped:Connect(function()
            if not arrowOn then return end
            local x,y=getAnchor(); local r=CFG.radius; local hs=14
            NovaDraw.moveLine(obj._body,x,y+r,x,y)
            local a1=math.rad(-90)+math.rad(150)
            local a2=math.rad(-90)-math.rad(150)
            NovaDraw.moveLine(obj._h1,x,y,x+math.cos(a1)*hs,y+math.sin(a1)*hs)
            NovaDraw.moveLine(obj._h2,x,y,x+math.cos(a2)*hs,y+math.sin(a2)*hs)
            NovaDraw.recolor(obj,    CFG.color)
            NovaDraw.setOpacity(obj, CFG.opacity)
        end)
    end,
})

-- Spokes
LineTab:CreateSection("Spokes")
local spokesOn = false
LineTab:CreateSlider({ Name="Spoke Count", Range={3,16}, Increment=1, Suffix=" spokes",
    CurrentValue=8, Flag="LN_SPKC", Callback=function(v) CFG.spokeCount=v end })
LineTab:CreateToggle({ Name="Mouse Spokes", CurrentValue=false, Flag="LN_SPK",
    Callback = function(v)
        spokesOn = v
        stopLoop("spk"); clearTag("spk")
        if not v then return end
        local ax,ay=getAnchor()
        local lines={}
        for i=1,CFG.spokeCount do
            local a=(2*math.pi*(i-1)/CFG.spokeCount)
            local ln=NovaDraw.line(ax,ay,ax+math.cos(a)*CFG.radius,ay+math.sin(a)*CFG.radius,CFG.thickness,CFG.color,CFG.opacity,true)
            table.insert(lines,ln)
            trackObj("spk",ln)
        end
        loops["spk"]=RS.RenderStepped:Connect(function()
            if not spokesOn then return end
            local x,y=getAnchor()
            for i,ln in ipairs(lines) do
                local a=(2*math.pi*(i-1)/CFG.spokeCount)
                NovaDraw.moveLine(ln,x,y,x+math.cos(a)*CFG.radius,y+math.sin(a)*CFG.radius)
                NovaDraw.recolor(ln,    CFG.color)
                NovaDraw.setOpacity(ln, CFG.opacity)
            end
        end)
    end,
})

-- ══════════════════════════════════════════
--  TAB 3 — ANIMATED
-- ══════════════════════════════════════════

local AnimTab = Window:CreateTab("Animated", "zap")

AnimTab:CreateParagraph({
    Title   = "Animated Shapes",
    Content = "Orbiting dot, pulsing ring, rotating polygon, animated progress bar.",
})
AnimTab:CreateDivider()

-- Orbiting dot
AnimTab:CreateSection("Orbiting Dot")
local orbitOn = false; local orbitAngle = 0
AnimTab:CreateToggle({ Name="Orbiting Circle", CurrentValue=false, Flag="AN_ORB",
    Callback = function(v)
        orbitOn = v
        stopLoop("orb"); clearTag("orb")
        if not v then return end
        local ax,ay=getAnchor()
        local obj=NovaDraw.circle(ax,ay,8,2,CFG.color,true,CFG.opacity)
        trackObj("orb",obj)
        loops["orb"]=RS.RenderStepped:Connect(function(dt)
            if not orbitOn then return end
            orbitAngle=orbitAngle+dt*CFG.orbitSpeed
            local x,y=getAnchor()
            NovaDraw.moveCircle(obj,
                x+math.cos(orbitAngle)*CFG.radius,
                y+math.sin(orbitAngle)*CFG.radius)
            NovaDraw.recolor(obj,    CFG.color)
            NovaDraw.setOpacity(obj, CFG.opacity)
        end)
    end,
})
AnimTab:CreateSlider({ Name="Orbit Speed", Range={1,20}, Increment=1, Suffix="x",
    CurrentValue=3, Flag="AN_ORBS", Callback=function(v) CFG.orbitSpeed=v end })

-- Pulsing circle
AnimTab:CreateSection("Pulsing Circle")
local pulseOn = false
AnimTab:CreateToggle({ Name="Pulsing Circle", CurrentValue=false, Flag="AN_PLS",
    Callback = function(v)
        pulseOn = v
        stopLoop("pls"); clearTag("pls")
        if not v then return end
        local ax,ay=getAnchor()
        local obj=NovaDraw.circle(ax,ay,CFG.radius,CFG.thickness,CFG.color,false,CFG.opacity)
        trackObj("pls",obj)
        local t=0
        loops["pls"]=RS.RenderStepped:Connect(function(dt)
            if not pulseOn then return end
            t=t+dt*3
            local x,y=getAnchor()
            local pr=CFG.radius+math.sin(t)*(CFG.radius*0.3)
            NovaDraw.moveCircle(obj,x,y)
            if obj._frame then obj._frame.Size=UDim2.fromOffset(pr*2,pr*2) end
            NovaDraw.recolor(obj,    CFG.color)
            NovaDraw.setOpacity(obj, math.abs(math.sin(t))*CFG.opacity)
        end)
    end,
})

-- Rotating polygon
AnimTab:CreateSection("Rotating Polygon")
local rotPolyOn = false; local rotAngle = 0
AnimTab:CreateToggle({ Name="Rotating Polygon", CurrentValue=false, Flag="AN_RPOLY",
    Callback = function(v)
        rotPolyOn = v
        stopLoop("rpoly"); clearTag("rpoly")
        if not v then return end
        local ax,ay=getAnchor()
        local obj=NovaDraw.polygon(ax,ay,CFG.sides,CFG.radius,CFG.thickness,CFG.color,CFG.opacity)
        trackObj("rpoly",obj)
        loops["rpoly"]=RS.RenderStepped:Connect(function(dt)
            if not rotPolyOn then return end
            rotAngle=rotAngle+dt*CFG.orbitSpeed*0.5
            local x,y=getAnchor(); local r=CFG.radius; local s=CFG.sides
            local pts={}
            for i=0,s-1 do
                local a=(2*math.pi*i/s)-math.pi/2+rotAngle
                table.insert(pts,{x+math.cos(a)*r,y+math.sin(a)*r})
            end
            for i,ln in ipairs(obj._lines) do
                local n=(i%s)+1
                NovaDraw.moveLine(ln,pts[i][1],pts[i][2],pts[n][1],pts[n][2])
                NovaDraw.recolor(ln,    CFG.color)
                NovaDraw.setOpacity(ln, CFG.opacity)
            end
        end)
    end,
})

-- Progress bar
AnimTab:CreateSection("Progress Bar")
local progOn = false
AnimTab:CreateToggle({ Name="Animated Progress Bar", CurrentValue=false, Flag="AN_PRG",
    Callback = function(v)
        progOn = v
        stopLoop("prg"); clearTag("prg")
        if not v then return end
        local ax,ay=getAnchor()
        local obj=NovaDraw.progressBar(ax-50,ay+CFG.radius+10,100,10,0,CFG.color,Color3.fromRGB(30,30,30),CFG.opacity)
        trackObj("prg",obj)
        local t=0
        loops["prg"]=RS.RenderStepped:Connect(function(dt)
            if not progOn then return end
            t=(t+dt*0.5)%1
            local x,y=getAnchor()
            obj._bg.Position           = UDim2.fromOffset(x-50,y+CFG.radius+10)
            obj._fill.Position         = UDim2.fromOffset(x-50,y+CFG.radius+10)
            obj._bg.BackgroundColor3   = Color3.fromRGB(30,30,30)
            obj._fill.BackgroundColor3 = CFG.color
            NovaDraw.updateProgressBar(obj,t)
        end)
    end,
})

-- ══════════════════════════════════════════
--  TAB 4 — ESP
-- ══════════════════════════════════════════

local ESPTab = Window:CreateTab("ESP", "eye")

ESPTab:CreateParagraph({
    Title   = "Player ESP",
    Content = "Boxes, names, health bars, distance and tracers — all built with NovaDraw, no executor Drawing API.",
})
ESPTab:CreateDivider()

ESPTab:CreateSection("Master Toggle")
ESPTab:CreateToggle({ Name="Enable ESP", CurrentValue=false, Flag="ESP_ON",
    Callback = function(v)
        CFG.espOn = v
        stopLoop("esp")
        if v then
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LP and not espData[p] then espData[p]={} end
            end
            loops["esp"]=RS.RenderStepped:Connect(function()
                if CFG.espOn then updateESP() end
            end)
        else
            removeAllESP()
        end
    end,
})

ESPTab:CreateSection("Box Style")
ESPTab:CreateDropdown({ Name="Box Type", Options={"Corner","Full"},
    CurrentOption={"Corner"}, Flag="ESP_BT", MultipleOptions=false,
    Callback = function(v)
        CFG.espBoxType = type(v)=="table" and v[1] or v
        for _,p in ipairs(Players:GetPlayers()) do
            if espData[p] and espData[p].box then
                NovaDraw.remove(espData[p].box)
                espData[p].box = nil
            end
        end
    end,
})

ESPTab:CreateSection("Visibility")
ESPTab:CreateToggle({ Name="Show Names",    CurrentValue=true,  Flag="ESP_N",  Callback=function(v) CFG.espShowNames=v   end })
ESPTab:CreateToggle({ Name="Show Health",   CurrentValue=true,  Flag="ESP_H",  Callback=function(v) CFG.espShowHealth=v  end })
ESPTab:CreateToggle({ Name="Show Distance", CurrentValue=true,  Flag="ESP_D",  Callback=function(v) CFG.espShowDist=v    end })
ESPTab:CreateToggle({ Name="Show Tracers",  CurrentValue=false, Flag="ESP_TR", Callback=function(v) CFG.espShowTracer=v  end })

ESPTab:CreateSection("Range")
ESPTab:CreateSlider({ Name="Max Distance", Range={50,2000}, Increment=50, Suffix="m",
    CurrentValue=500, Flag="ESP_MD", Callback=function(v) CFG.espMaxDist=v end })

ESPTab:CreateSection("Colors")
ESPTab:CreateColorPicker({ Name="Box Color",    Color=Color3.fromRGB(255,80,80),   Flag="ESP_BC",
    Callback=function(v) CFG.espBoxColor=v    end })
ESPTab:CreateColorPicker({ Name="Name Color",   Color=Color3.fromRGB(255,255,255), Flag="ESP_NC",
    Callback=function(v) CFG.espNameColor=v   end })
ESPTab:CreateColorPicker({ Name="Tracer Color", Color=Color3.fromRGB(255,80,80),   Flag="ESP_TRC",
    Callback=function(v) CFG.espTracerColor=v end })

-- ══════════════════════════════════════════
--  TAB 5 — FOV
-- ══════════════════════════════════════════

local FOVTab = Window:CreateTab("FOV", "circle-dashed")

FOVTab:CreateParagraph({
    Title   = "FOV Circle",
    Content = "Static ring at screen center. Resize live with the slider. Toggling off calls NovaDraw.remove cleanly.",
})
FOVTab:CreateDivider()

FOVTab:CreateSection("Toggle")
FOVTab:CreateToggle({ Name="Show FOV Circle", CurrentValue=false, Flag="FOV_ON",
    Callback = function(v)
        CFG.fovOn = v
        stopLoop("fov"); clearTag("fov")
        CFG.fovObj = nil
        if not v then return end
        local vp=Camera.ViewportSize
        CFG.fovObj = NovaDraw.circle(vp.X/2,vp.Y/2,CFG.fovRadius,CFG.thickness,CFG.color,false,CFG.opacity)
        trackObj("fov", CFG.fovObj)
        loops["fov"]=RS.RenderStepped:Connect(function()
            if not CFG.fovOn or not CFG.fovObj then return end
            local vp2=Camera.ViewportSize
            NovaDraw.moveCircle(CFG.fovObj, vp2.X/2, vp2.Y/2)
            NovaDraw.recolor(CFG.fovObj,    CFG.color)
            NovaDraw.setOpacity(CFG.fovObj, CFG.opacity)
        end)
    end,
})

FOVTab:CreateSection("Settings")
FOVTab:CreateSlider({ Name="FOV Radius", Range={20,600}, Increment=5, Suffix="px",
    CurrentValue=120, Flag="FOV_R",
    Callback = function(v)
        CFG.fovRadius = v
        if CFG.fovObj and CFG.fovObj._frame then
            CFG.fovObj._frame.Size = UDim2.fromOffset(v*2, v*2)
        end
    end,
})
FOVTab:CreateColorPicker({ Name="FOV Color", Color=Color3.fromRGB(255,80,80), Flag="FOV_C",
    Callback=function(v) CFG.color=v end })

-- ══════════════════════════════════════════
--  TAB 6 — CONFIG
-- ══════════════════════════════════════════

local CfgTab = Window:CreateTab("Config", "settings")

CfgTab:CreateParagraph({
    Title   = "Global Settings",
    Content = "All settings apply to active shapes in real time. No need to retoggle.",
})
CfgTab:CreateDivider()

CfgTab:CreateSection("Color")
CfgTab:CreateColorPicker({ Name="Shape Color", Color=Color3.fromRGB(255,80,80), Flag="CF_COL",
    Callback=function(v) CFG.color=v end })

CfgTab:CreateSection("Shape")
CfgTab:CreateSlider({ Name="Radius / Size", Range={10,250}, Increment=1, Suffix="px",
    CurrentValue=60, Flag="CF_RAD", Callback=function(v) CFG.radius=v end })
CfgTab:CreateSlider({ Name="Thickness", Range={1,12}, Increment=1, Suffix="px",
    CurrentValue=2,  Flag="CF_THK", Callback=function(v) CFG.thickness=v end })
CfgTab:CreateSlider({ Name="Opacity", Range={0,100}, Increment=5, Suffix="%",
    CurrentValue=100, Flag="CF_OPC", Callback=function(v) CFG.opacity=v/100 end })
CfgTab:CreateToggle({ Name="Filled Shapes",   CurrentValue=false, Flag="CF_FIL", Callback=function(v) CFG.filled=v  end })
CfgTab:CreateToggle({ Name="Rounded Corners", CurrentValue=true,  Flag="CF_RND", Callback=function(v) CFG.rounded=v end })

CfgTab:CreateSection("Mouse Offset")
CfgTab:CreateLabel("Shifts the mouse anchor only — fixed screen points unaffected.", "mouse-pointer", Color3.fromRGB(180,180,180), true)
CfgTab:CreateSlider({ Name="Mouse Offset X", Range={-300,300}, Increment=1, Suffix="px",
    CurrentValue=0, Flag="CF_MOX", Callback=function(v) CFG.offsetX=v end })
CfgTab:CreateSlider({ Name="Mouse Offset Y", Range={-300,300}, Increment=1, Suffix="px",
    CurrentValue=0, Flag="CF_MOY", Callback=function(v) CFG.offsetY=v end })
CfgTab:CreateButton({ Name="Reset Mouse Offset", Callback=function()
    CFG.offsetX=0; CFG.offsetY=0
    Rayfield:Notify({ Title="Offset", Content="Mouse offset reset.", Duration=2, Image="mouse-pointer" })
end })

CfgTab:CreateSection("Screen Offset")
CfgTab:CreateLabel("Shifts everything including tracer/connector origins.", "monitor", Color3.fromRGB(180,180,180), true)
CfgTab:CreateSlider({ Name="Screen Offset X", Range={-500,500}, Increment=1, Suffix="px",
    CurrentValue=0, Flag="CF_SOX", Callback=function(v) CFG.screenOffX=v end })
CfgTab:CreateSlider({ Name="Screen Offset Y", Range={-500,500}, Increment=1, Suffix="px",
    CurrentValue=0, Flag="CF_SOY", Callback=function(v) CFG.screenOffY=v end })
CfgTab:CreateButton({ Name="Reset Screen Offset", Callback=function()
    CFG.screenOffX=0; CFG.screenOffY=0
    Rayfield:Notify({ Title="Offset", Content="Screen offset reset.", Duration=2, Image="monitor" })
end })
CfgTab:CreateButton({ Name="Reset All Offsets", Callback=function()
    CFG.offsetX=0; CFG.offsetY=0; CFG.screenOffX=0; CFG.screenOffY=0
    Rayfield:Notify({ Title="Offset", Content="All offsets reset.", Duration=2, Image="refresh-cw" })
end })

CfgTab:CreateSection("Cleanup")
CfgTab:CreateLabel("Stops all loops and calls NovaDraw.remove() on every active object.", "trash-2", Color3.fromRGB(255,100,100), true)
CfgTab:CreateButton({ Name="Clear All Drawings", Callback=function()
    fullCleanup()
    Rayfield:Notify({ Title="NovaHub", Content="All drawings cleared.", Duration=3, Image="trash-2" })
end })
CfgTab:CreateDivider()
CfgTab:CreateButton({ Name="🔴 Unload NovaHub", Callback=function()
    fullCleanup()
    NovaDraw.destroy()  -- wipes the entire ScreenGui
    Rayfield:Destroy()
end })

-- ══════════════════════════════════════════
--  PLAYER HOOKS
-- ══════════════════════════════════════════

Players.PlayerAdded:Connect(function(p)
    if CFG.espOn and p~=LP then espData[p]={} end
end)

Players.PlayerRemoving:Connect(function(p)
    removeESP(p)
end)

-- ══════════════════════════════════════════
--  DONE
-- ══════════════════════════════════════════

Rayfield:Notify({
    Title   = "NovaHub",
    Content = "NovaDraw UI v2.1 loaded. Press K to toggle.",
    Duration = 5,
    Image    = "pentagon",
})
