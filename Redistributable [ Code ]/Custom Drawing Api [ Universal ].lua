--[[
    ══════════════════════════════════════════
    NOVADRAW v2 — API REFERENCE
    ══════════════════════════════════════════

    All functions are called on the NovaDraw table
    Every constructor returns an object you store and pass into helpers later
    e.g.
        local myCircle = NovaDraw.circle(500, 300, 60, 2, Color3.fromRGB(255,80,80), false, 1)
        NovaDraw.moveCircle(myCircle, 600, 400)
        NovaDraw.recolor(myCircle, Color3.fromRGB(80,255,80))
        NovaDraw.remove(myCircle)

    ══════════════════════════════════════════
    CONSTRUCTORS
    ══════════════════════════════════════════

    NovaDraw.circle(x, y, radius, thickness, color, filled, opacity)
        x, y         center position in pixels
        radius       circle radius in px
        thickness    stroke width in px, only used when filled = false
        color        Color3
        filled       true = solid disc | false = hollow ring via UIStroke
        opacity      0 to 1

    NovaDraw.square(x, y, sizeX, sizeY, thickness, color, filled, opacity, cornerRadius)
        x, y         top-left corner position
        sizeX,sizeY  width and height in px
        thickness    border width, only used when filled = false
        color        Color3
        filled       true = solid | false = outline only
        opacity      0 to 1
        cornerRadius corner rounding in px, 0 = sharp, any value = rounded via UICorner

    NovaDraw.line(x1, y1, x2, y2, thickness, color, opacity, rounded)
        x1,y1        start point
        x2,y2        end point
        thickness    line height in px
        color        Color3
        opacity      0 to 1
        rounded      true = pill-shaped ends via UICorner | false = flat square ends

    NovaDraw.triangle(ax,ay, bx,by, cx,cy, thickness, color, opacity, rounded)
        ax,ay        point A
        bx,by        point B
        cx,cy        point C
        thickness    line width in px
        rounded      rounds line ends at each corner
        internals    obj._lines = { line, line, line }

    NovaDraw.quad(ax,ay, bx,by, cx,cy, dx,dy, thickness, color, opacity, rounded)
        four points A B C D connected in order to form a quadrilateral
        internals    obj._lines = { line, line, line, line }

    NovaDraw.text(x, y, content, size, color, opacity, outline)
        x, y         top-left of the text container frame
        content      string, supports RichText tags
        size         font size in px
        color        Color3 for the main label
        opacity      0 to 1
        outline      true = 4-direction black shadow for outline effect
        internals    obj._label = the main TextLabel
                     obj._container = the parent Frame

    NovaDraw.polygon(x, y, sides, radius, thickness, color, opacity)
        x, y         center of the polygon
        sides        number of sides e.g. 3 = triangle, 6 = hexagon, 8 = octagon
        radius       distance from center to each vertex in px
        internals    obj._lines = table of N line objects

    NovaDraw.crosshair(x, y, length, gap, thickness, color, opacity)
        x, y         center point
        length       arm length in px measured from the gap edge outward
        gap          empty space at center in px, 0 = lines meet in the middle
        internals    obj._h  = left arm line
                     obj._h2 = right arm line
                     obj._v  = top arm line
                     obj._v2 = bottom arm line

    NovaDraw.box(x, y, w, h, thickness, color, opacity, cornerRadius)
        shorthand alias for a hollow square
        x, y         top-left corner
        w, h         width and height
        cornerRadius optional rounding in px

    NovaDraw.cornerBox(x, y, w, h, cornerLen, thickness, color, opacity)
        ESP-style box where only the corners are drawn, not full edges
        x, y         top-left
        w, h         total box dimensions
        cornerLen    length of each corner tick in px
        internals    obj._lines = { 8 line objects, 2 per corner }

    NovaDraw.roundedBox(x, y, w, h, thickness, color, filled, opacity, radius)
        shorthand alias for square() with a cornerRadius pre-applied
        radius       corner rounding in px, defaults to 8

    NovaDraw.healthBar(x, y, w, h, percent, fillColor, opacity)
        vertical fill bar, designed for ESP health display
        x, y         top-left
        w, h         dimensions in px
        percent      0 to 1, how full the bar is
        fillColor    Color3 for the fill, auto shifts red to green via updateHealthBar()
        internals    obj._bg   = background frame
                     obj._fill = fill frame
                     obj._x, obj._y, obj._w, obj._h, obj._percent stored for updates

    NovaDraw.progressBar(x, y, w, h, percent, fillColor, bgColor, opacity)
        horizontal fill bar
        x, y         top-left
        w, h         dimensions
        percent      0 to 1
        fillColor    Color3 for the filled portion
        bgColor      Color3 for the unfilled background
        internals    obj._bg = background | obj._fill = fill

    NovaDraw.diamond(x, y, radius, thickness, color, opacity)
        x, y         center point
        radius       distance from center to each of the 4 tips in px
        internals    obj._lines = { 4 line objects }

    NovaDraw.star(x, y, outerR, innerR, points, thickness, color, opacity)
        x, y         center point
        outerR       outer spike tip radius in px
        innerR       inner indent radius in px, defaults to outerR * 0.45
        points       number of star points, defaults to 5
        internals    obj._lines = table of points*2 line objects

    NovaDraw.spiral(x, y, startR, endR, turns, steps, thickness, color, opacity)
        x, y         center point
        startR       radius at the beginning of the spiral
        endR         radius at the end of the spiral
        turns        number of full rotations around the center
        steps        segment count, higher = smoother curve, defaults to 60
        internals    obj._lines = table of step-1 line objects

    NovaDraw.dashedLine(x1,y1, x2,y2, thickness, color, opacity, dashLen, gapLen)
        x1,y1        start point
        x2,y2        end point
        dashLen      length of each visible dash in px, defaults to 10
        gapLen       length of each invisible gap between dashes in px, defaults to 6
        internals    obj._lines = table of dash line objects

    NovaDraw.arrow(x1,y1, x2,y2, thickness, color, opacity, headSize)
        draws a line from x1,y1 to x2,y2 with an arrowhead at x2,y2
        headSize     arrowhead arm length in px, defaults to 12
        internals    obj._body = shaft line
                     obj._h1  = left head arm
                     obj._h2  = right head arm

    NovaDraw.grid(x, y, w, h, cols, rows, thickness, color, opacity)
        x, y         top-left of the entire grid
        w, h         total grid width and height in px
        cols,rows    number of columns and rows to divide into
        internals    obj._lines = table of all vertical + horizontal line objects

    NovaDraw.tracer(ox, oy, tx, ty, thickness, color, opacity)
        shorthand for a rounded line between two points, typically used for ESP tracers
        ox,oy        origin point e.g. screen bottom center
        tx,ty        target point e.g. enemy screen position
        returns a plain line object, use moveLine() to update it

    ══════════════════════════════════════════
    MOVE HELPERS
    ══════════════════════════════════════════

    NovaDraw.moveCircle(obj, x, y)
        moves the circle center to x, y

    NovaDraw.moveLine(obj, x1, y1, x2, y2)
        repositions the line and recomputes its length and rotation angle

    NovaDraw.moveSquare(obj, x, y)
        moves the top-left corner to x, y
        if the square is hollow it updates all 4 border frames

    NovaDraw.moveText(obj, x, y)
        moves the text container top-left to x, y

    NovaDraw.moveCrosshair(obj, x, y)
        recenters all 4 arms around a new x, y
        preserves the original arm length and gap value

    ══════════════════════════════════════════
    STYLE HELPERS
    ══════════════════════════════════════════

    NovaDraw.recolor(obj, Color3)
        changes color on any object type
        handles circle frame + UIStroke, square frames, lines,
        text labels, and all compound shapes recursively

    NovaDraw.setOpacity(obj, opacity)
        opacity is 0 to 1
        updates BackgroundTransparency and UIStroke.Transparency
        across all object types including nested compound shapes

    NovaDraw.setThickness(obj, px)
        updates UIStroke thickness on circles
        updates frame height on lines
        recurses into compound shapes

    NovaDraw.show(obj)
        makes the object visible

    NovaDraw.hide(obj)
        hides the object without destroying it, can be shown again with show()

    NovaDraw.setVisible(obj, bool)
        explicit visibility control, true or false

    ══════════════════════════════════════════
    CONTENT HELPERS
    ══════════════════════════════════════════

    NovaDraw.setText(obj, string)
        updates the displayed string on a text object
        also syncs all 4 shadow labels so the outline stays correct

    NovaDraw.updateHealthBar(obj, percent)
        percent is 0 to 1
        resizes the fill frame vertically
        automatically shifts fill color from red at 0 to green at 1

    NovaDraw.updateProgressBar(obj, percent)
        percent is 0 to 1
        resizes the fill frame horizontally

    ══════════════════════════════════════════
    CLEANUP
    ══════════════════════════════════════════

    NovaDraw.remove(obj)
        destroys all Roblox instances belonging to the object
        removes it from the internal _objects tracking table

    NovaDraw.clearAll()
        destroys every currently tracked object
        does not destroy the ScreenGui itself, NovaDraw stays usable

    NovaDraw.destroy()
        runs clearAll() and then destroys the ScreenGui entirely
        call this on script unload to leave no instances behind

]]

local NovaDraw = {}
NovaDraw._objects = {}
 
-- ══════════════════════════════════════════
--  SETUP
-- ══════════════════════════════════════════
 
local gui = Instance.new("ScreenGui")
gui.Name              = "NovaDrawGui"
gui.ResetOnSpawn      = false
gui.IgnoreGuiInset    = true
gui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
gui.Parent            = game:GetService("CoreGui")
 
NovaDraw._gui = gui
 
-- ══════════════════════════════════════════
--  INTERNAL HELPERS
-- ══════════════════════════════════════════
 
local function register(obj)
    table.insert(NovaDraw._objects, obj)
    return obj
end
 
local function newFrame(parent)
    local f = Instance.new("Frame")
    f.BorderSizePixel  = 0
    f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    f.Parent           = parent or gui
    return f
end
 
print([[
    Drawing API Courtesy of:
    The NovaHub Team - ( @xx4naxx on YouTube )
]])
 
local function setAbsolute(f, x, y, w, h)
    f.Position = UDim2.fromOffset(x, y)
    f.Size     = UDim2.fromOffset(w, h)
end
 
-- safe destroy: guards against already-destroyed instances
local function safeDestroy(instance)
    if instance and instance.Parent ~= nil then
        pcall(function() instance:Destroy() end)
    end
end
 
-- ══════════════════════════════════════════
--  CIRCLE
-- ══════════════════════════════════════════
 
function NovaDraw.circle(x, y, radius, thickness, color, filled, opacity)
    thickness = thickness or 2
    color     = color     or Color3.fromRGB(255, 255, 255)
    opacity   = opacity   ~= nil and opacity or 1
    filled    = filled    or false
    local size = radius * 2
 
    local f = newFrame()
    f.AnchorPoint            = Vector2.new(0.5, 0.5)
    f.Position               = UDim2.fromOffset(x, y)
    f.Size                   = UDim2.fromOffset(size, size)
    f.BackgroundColor3       = color
    f.BackgroundTransparency = filled and (1 - opacity) or 1
 
    local corner = Instance.new("UICorner", f)
    corner.CornerRadius = UDim.new(1, 0)
 
    local stroke = nil
    if not filled then
        stroke = Instance.new("UIStroke", f)
        stroke.Color           = color
        stroke.Thickness       = thickness
        stroke.Transparency    = 1 - opacity
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    end
 
    return register({
        _type   = "circle",
        _frame  = f,
        _filled = filled,
        _radius = radius,
        _stroke = stroke,
    })
end
 
-- ══════════════════════════════════════════
--  SQUARE / RECTANGLE
-- ══════════════════════════════════════════
 
function NovaDraw.square(x, y, sizeX, sizeY, thickness, color, filled, opacity, cornerRadius)
    thickness    = thickness    or 2
    color        = color        or Color3.fromRGB(255, 255, 255)
    opacity      = opacity      ~= nil and opacity or 1
    filled       = filled       or false
    sizeX        = sizeX        or 100
    sizeY        = sizeY        or 100
    cornerRadius = cornerRadius or 0
 
    if cornerRadius > 0 then
        local f = newFrame()
        setAbsolute(f, x, y, sizeX, sizeY)
        f.BackgroundColor3       = color
        f.BackgroundTransparency = filled and (1 - opacity) or 1
 
        local corner = Instance.new("UICorner", f)
        corner.CornerRadius = UDim.new(0, cornerRadius)
 
        local stroke = nil
        if not filled then
            stroke = Instance.new("UIStroke", f)
            stroke.Color           = color
            stroke.Thickness       = thickness
            stroke.Transparency    = 1 - opacity
            stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        end
 
        return register({
            _type    = "square",
            _frame   = f,
            _filled  = filled,
            _rounded = true,
            _stroke  = stroke,
            _x=x, _y=y, _sizeX=sizeX, _sizeY=sizeY,
        })
    end
 
    if filled then
        local f = newFrame()
        setAbsolute(f, x, y, sizeX, sizeY)
        f.BackgroundColor3       = color
        f.BackgroundTransparency = 1 - opacity
        return register({
            _type="square", _frame=f, _filled=true,
            _x=x, _y=y, _sizeX=sizeX, _sizeY=sizeY,
        })
    else
        local t      = thickness
        local top    = newFrame(); setAbsolute(top,    x,          y,          sizeX, t)
        local bottom = newFrame(); setAbsolute(bottom, x,          y+sizeY-t,  sizeX, t)
        local left   = newFrame(); setAbsolute(left,   x,          y,          t,     sizeY)
        local right  = newFrame(); setAbsolute(right,  x+sizeX-t,  y,          t,     sizeY)
        for _, f in ipairs({top, bottom, left, right}) do
            f.BackgroundColor3       = color
            f.BackgroundTransparency = 1 - opacity
        end
        return register({
            _type="square", _frames={top,bottom,left,right}, _filled=false,
            _x=x, _y=y, _sizeX=sizeX, _sizeY=sizeY, _thickness=t,
        })
    end
end
 
-- ══════════════════════════════════════════
--  LINE
-- ══════════════════════════════════════════
 
function NovaDraw.line(x1, y1, x2, y2, thickness, color, opacity, rounded)
    thickness = thickness or 2
    color     = color     or Color3.fromRGB(255, 255, 255)
    opacity   = opacity   ~= nil and opacity or 1
 
    local dx  = x2 - x1
    local dy  = y2 - y1
    local len = math.sqrt(dx*dx + dy*dy)
    local ang = math.deg(math.atan2(dy, dx))
 
    local f = newFrame()
    f.AnchorPoint            = Vector2.new(0.5, 0.5)
    f.Position               = UDim2.fromOffset((x1+x2)/2, (y1+y2)/2)
    f.Size                   = UDim2.fromOffset(len, thickness)
    f.BackgroundColor3       = color
    f.BackgroundTransparency = 1 - opacity
    f.Rotation               = ang
 
    if rounded then
        local corner = Instance.new("UICorner", f)
        corner.CornerRadius = UDim.new(0, math.floor(thickness / 2))
    end
 
    return register({
        _type="line", _frame=f,
        _x1=x1, _y1=y1, _x2=x2, _y2=y2,
        _thickness=thickness,
    })
end
 
-- ══════════════════════════════════════════
--  TRIANGLE
-- ══════════════════════════════════════════
 
function NovaDraw.triangle(ax,ay, bx,by, cx,cy, thickness, color, opacity, rounded)
    local l1 = NovaDraw.line(ax,ay, bx,by, thickness,color,opacity,rounded)
    local l2 = NovaDraw.line(bx,by, cx,cy, thickness,color,opacity,rounded)
    local l3 = NovaDraw.line(cx,cy, ax,ay, thickness,color,opacity,rounded)
    -- pop child lines out of top-level registry; parent obj owns them
    for i=1,3 do table.remove(NovaDraw._objects,#NovaDraw._objects) end
    return register({ _type="triangle", _lines={l1,l2,l3} })
end
 
-- ══════════════════════════════════════════
--  QUAD
-- ══════════════════════════════════════════
 
function NovaDraw.quad(ax,ay, bx,by, cx,cy, dx,dy, thickness, color, opacity, rounded)
    local lines = {
        NovaDraw.line(ax,ay, bx,by, thickness,color,opacity,rounded),
        NovaDraw.line(bx,by, cx,cy, thickness,color,opacity,rounded),
        NovaDraw.line(cx,cy, dx,dy, thickness,color,opacity,rounded),
        NovaDraw.line(dx,dy, ax,ay, thickness,color,opacity,rounded),
    }
    for i=1,4 do table.remove(NovaDraw._objects,#NovaDraw._objects) end
    return register({ _type="quad", _lines=lines })
end
 
-- ══════════════════════════════════════════
--  TEXT
-- ══════════════════════════════════════════
 
function NovaDraw.text(x, y, content, size, color, opacity, outline)
    color   = color   or Color3.fromRGB(255, 255, 255)
    opacity = opacity ~= nil and opacity or 1
    size    = size    or 14
 
    local container = Instance.new("Frame")
    container.BackgroundTransparency = 1
    container.BorderSizePixel        = 0
    container.Position               = UDim2.fromOffset(x, y)
    container.Size                   = UDim2.fromOffset(400, size + 8)
    container.Parent                 = gui
 
    if outline then
        for _, off in ipairs({{1,1},{-1,1},{1,-1},{-1,-1}}) do
            local s = Instance.new("TextLabel", container)
            s.BackgroundTransparency = 1
            s.BorderSizePixel        = 0
            s.Position               = UDim2.fromOffset(off[1], off[2])
            s.Size                   = UDim2.new(1,0,1,0)
            s.Text                   = content
            s.TextColor3             = Color3.fromRGB(0,0,0)
            s.TextTransparency       = 1 - opacity
            s.TextSize               = size
            s.Font                   = Enum.Font.GothamBold
            s.TextXAlignment         = Enum.TextXAlignment.Left
            s.RichText               = true
        end
    end
 
    local label = Instance.new("TextLabel", container)
    label.BackgroundTransparency = 1
    label.BorderSizePixel        = 0
    label.Position               = UDim2.fromOffset(0, 0)
    label.Size                   = UDim2.new(1,0,1,0)
    label.Text                   = content
    label.TextColor3             = color
    label.TextTransparency       = 1 - opacity
    label.TextSize               = size
    label.Font                   = Enum.Font.GothamBold
    label.TextXAlignment         = Enum.TextXAlignment.Left
    label.RichText               = true
 
    return register({
        _type      = "text",
        _container = container,
        _label     = label,
        _content   = content,
    })
end
 
-- ══════════════════════════════════════════
--  POLYGON
-- ══════════════════════════════════════════
 
function NovaDraw.polygon(x, y, sides, radius, thickness, color, opacity)
    sides = sides or 6
    local pts = {}
    for i = 0, sides-1 do
        local a = (2*math.pi*i/sides) - math.pi/2
        table.insert(pts, { x+math.cos(a)*radius, y+math.sin(a)*radius })
    end
    local lines = {}
    for i = 1, sides do
        local n  = (i%sides)+1
        local ln = NovaDraw.line(pts[i][1],pts[i][2], pts[n][1],pts[n][2], thickness,color,opacity, true)
        table.remove(NovaDraw._objects,#NovaDraw._objects)
        table.insert(lines, ln)
    end
    return register({ _type="polygon", _lines=lines })
end
 
-- ══════════════════════════════════════════
--  CROSSHAIR
-- ══════════════════════════════════════════
 
function NovaDraw.crosshair(x, y, length, gap, thickness, color, opacity)
    gap = gap or 0
    local h  = NovaDraw.line(x-length-gap, y,          x-gap,        y,          thickness,color,opacity,true)
    local h2 = NovaDraw.line(x+gap,        y,          x+length+gap, y,          thickness,color,opacity,true)
    local v  = NovaDraw.line(x,            y-length-gap, x,          y-gap,      thickness,color,opacity,true)
    local v2 = NovaDraw.line(x,            y+gap,        x,          y+length+gap, thickness,color,opacity,true)
    for i=1,4 do table.remove(NovaDraw._objects,#NovaDraw._objects) end
    return register({ _type="crosshair", _h=h, _h2=h2, _v=v, _v2=v2, _gap=gap, _length=length })
end
 
-- ══════════════════════════════════════════
--  BOX
-- ══════════════════════════════════════════
 
function NovaDraw.box(x, y, w, h, thickness, color, opacity, cornerRadius)
    return NovaDraw.square(x, y, w, h, thickness, color, false, opacity, cornerRadius or 0)
end
 
-- ══════════════════════════════════════════
--  CORNER BOX
-- ══════════════════════════════════════════
 
function NovaDraw.cornerBox(x, y, w, h, cornerLen, thickness, color, opacity)
    local cl = cornerLen or math.floor(w * 0.25)
    local lines = {
        NovaDraw.line(x,    y,    x+cl,   y,      thickness,color,opacity,true),
        NovaDraw.line(x,    y,    x,      y+cl,   thickness,color,opacity,true),
        NovaDraw.line(x+w,  y,    x+w-cl, y,      thickness,color,opacity,true),
        NovaDraw.line(x+w,  y,    x+w,    y+cl,   thickness,color,opacity,true),
        NovaDraw.line(x,    y+h,  x+cl,   y+h,    thickness,color,opacity,true),
        NovaDraw.line(x,    y+h,  x,      y+h-cl, thickness,color,opacity,true),
        NovaDraw.line(x+w,  y+h,  x+w-cl, y+h,    thickness,color,opacity,true),
        NovaDraw.line(x+w,  y+h,  x+w,    y+h-cl, thickness,color,opacity,true),
    }
    for i=1,8 do table.remove(NovaDraw._objects,#NovaDraw._objects) end
    return register({ _type="cornerBox", _lines=lines })
end
 
-- ══════════════════════════════════════════
--  ROUNDED BOX
-- ══════════════════════════════════════════
 
function NovaDraw.roundedBox(x, y, w, h, thickness, color, filled, opacity, radius)
    return NovaDraw.square(x, y, w, h, thickness, color, filled, opacity, radius or 8)
end
 
-- ══════════════════════════════════════════
--  HEALTH BAR
-- ══════════════════════════════════════════
 
function NovaDraw.healthBar(x, y, w, h, percent, fillColor, opacity)
    percent   = math.clamp(percent or 1, 0, 1)
    fillColor = fillColor or Color3.fromRGB(80, 255, 80)
    opacity   = opacity   ~= nil and opacity or 1
 
    local bg = newFrame()
    setAbsolute(bg, x, y, w, h)
    bg.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    bg.BackgroundTransparency = 1 - (opacity * 0.7)
    local bgCorner = Instance.new("UICorner", bg)
    bgCorner.CornerRadius = UDim.new(0, 3)
 
    local fillH = math.floor(h * percent)
    local fill  = newFrame()
    setAbsolute(fill, x, y + (h - fillH), w, math.max(fillH, 1))
    fill.BackgroundColor3       = fillColor
    fill.BackgroundTransparency = 1 - opacity
    local fillCorner = Instance.new("UICorner", fill)
    fillCorner.CornerRadius = UDim.new(0, 3)
 
    local stroke = Instance.new("UIStroke", bg)
    stroke.Color           = Color3.fromRGB(0, 0, 0)
    stroke.Thickness       = 1
    stroke.Transparency    = 1 - opacity
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
 
    return register({
        _type    = "healthBar",
        _bg      = bg,
        _fill    = fill,
        _stroke  = stroke,
        _x=x, _y=y, _w=w, _h=h,
        _percent = percent,
    })
end
 
-- ══════════════════════════════════════════
--  PROGRESS BAR
-- ══════════════════════════════════════════
 
function NovaDraw.progressBar(x, y, w, h, percent, fillColor, bgColor, opacity)
    percent   = math.clamp(percent or 1, 0, 1)
    fillColor = fillColor or Color3.fromRGB(80, 180, 255)
    bgColor   = bgColor   or Color3.fromRGB(30, 30, 30)
    opacity   = opacity   ~= nil and opacity or 1
 
    local bg = newFrame()
    setAbsolute(bg, x, y, w, h)
    bg.BackgroundColor3       = bgColor
    bg.BackgroundTransparency = 1 - (opacity * 0.7)
    local bgC = Instance.new("UICorner", bg)
    bgC.CornerRadius = UDim.new(0, math.floor(h/2))
 
    local fillW = math.floor(w * percent)
    local fill  = newFrame()
    setAbsolute(fill, x, y, math.max(fillW, 1), h)
    fill.BackgroundColor3       = fillColor
    fill.BackgroundTransparency = 1 - opacity
    local fillC = Instance.new("UICorner", fill)
    fillC.CornerRadius = UDim.new(0, math.floor(h/2))
 
    local stroke = Instance.new("UIStroke", bg)
    stroke.Color           = Color3.fromRGB(0,0,0)
    stroke.Thickness       = 1
    stroke.Transparency    = 1 - opacity
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
 
    return register({
        _type    = "progressBar",
        _bg      = bg,
        _fill    = fill,
        _x=x, _y=y, _w=w, _h=h,
        _percent = percent,
    })
end
 
-- ══════════════════════════════════════════
--  DIAMOND
-- ══════════════════════════════════════════
 
function NovaDraw.diamond(x, y, radius, thickness, color, opacity)
    local r  = radius or 40
    local l1 = NovaDraw.line(x,   y-r, x+r, y,   thickness,color,opacity,true)
    local l2 = NovaDraw.line(x+r, y,   x,   y+r, thickness,color,opacity,true)
    local l3 = NovaDraw.line(x,   y+r, x-r, y,   thickness,color,opacity,true)
    local l4 = NovaDraw.line(x-r, y,   x,   y-r, thickness,color,opacity,true)
    for i=1,4 do table.remove(NovaDraw._objects,#NovaDraw._objects) end
    return register({ _type="diamond", _lines={l1,l2,l3,l4} })
end
 
-- ══════════════════════════════════════════
--  STAR
-- ══════════════════════════════════════════
 
function NovaDraw.star(x, y, outerR, innerR, points, thickness, color, opacity)
    points = points or 5
    innerR = innerR or outerR * 0.45
    local pts = {}
    for i = 0, points*2-1 do
        local a = (math.pi*i/points) - math.pi/2
        local r = (i%2==0) and outerR or innerR
        table.insert(pts, { x+math.cos(a)*r, y+math.sin(a)*r })
    end
    local lines = {}
    for i = 1, #pts do
        local n  = (i%#pts)+1
        local ln = NovaDraw.line(pts[i][1],pts[i][2], pts[n][1],pts[n][2], thickness,color,opacity,true)
        table.remove(NovaDraw._objects,#NovaDraw._objects)
        table.insert(lines, ln)
    end
    return register({ _type="star", _lines=lines })
end
 
-- ══════════════════════════════════════════
--  SPIRAL
-- ══════════════════════════════════════════
 
function NovaDraw.spiral(x, y, startR, endR, turns, steps, thickness, color, opacity)
    steps = steps or 60
    turns = turns or 3
    local pts = {}
    for i = 0, steps do
        local t   = i/steps
        local ang = t * turns * math.pi * 2
        local r   = startR + (endR - startR) * t
        table.insert(pts, { x+math.cos(ang)*r, y+math.sin(ang)*r })
    end
    local lines = {}
    for i = 1, #pts-1 do
        local ln = NovaDraw.line(pts[i][1],pts[i][2], pts[i+1][1],pts[i+1][2], thickness,color,opacity,true)
        table.remove(NovaDraw._objects,#NovaDraw._objects)
        table.insert(lines, ln)
    end
    return register({ _type="spiral", _lines=lines })
end
 
-- ══════════════════════════════════════════
--  DASHED LINE
-- ══════════════════════════════════════════
 
function NovaDraw.dashedLine(x1, y1, x2, y2, thickness, color, opacity, dashLen, gapLen)
    dashLen = dashLen or 10
    gapLen  = gapLen  or 6
    local dx    = x2-x1; local dy = y2-y1
    local total = math.sqrt(dx*dx+dy*dy)
    local nx    = dx/total; local ny = dy/total
    local segs  = {}
    local pos   = 0
    while pos < total do
        local dEnd = math.min(pos+dashLen, total)
        local ln = NovaDraw.line(
            x1+nx*pos,  y1+ny*pos,
            x1+nx*dEnd, y1+ny*dEnd,
            thickness, color, opacity, true
        )
        table.remove(NovaDraw._objects,#NovaDraw._objects)
        table.insert(segs, ln)
        pos = pos + dashLen + gapLen
    end
    return register({ _type="dashedLine", _lines=segs })
end
 
-- ══════════════════════════════════════════
--  ARROW
-- ══════════════════════════════════════════
 
function NovaDraw.arrow(x1, y1, x2, y2, thickness, color, opacity, headSize)
    headSize = headSize or 12
    local dx  = x2-x1; local dy = y2-y1
    local ang = math.atan2(dy, dx)
    local a1  = ang + math.rad(150)
    local a2  = ang - math.rad(150)
    local body = NovaDraw.line(x1,y1, x2,y2, thickness,color,opacity,true)
    local h1   = NovaDraw.line(x2,y2, x2+math.cos(a1)*headSize, y2+math.sin(a1)*headSize, thickness,color,opacity,true)
    local h2   = NovaDraw.line(x2,y2, x2+math.cos(a2)*headSize, y2+math.sin(a2)*headSize, thickness,color,opacity,true)
    for i=1,3 do table.remove(NovaDraw._objects,#NovaDraw._objects) end
    return register({ _type="arrow", _body=body, _h1=h1, _h2=h2 })
end
 
-- ══════════════════════════════════════════
--  GRID
-- ══════════════════════════════════════════
 
function NovaDraw.grid(x, y, w, h, cols, rows, thickness, color, opacity)
    cols = cols or 4; rows = rows or 4
    local cw = w/cols; local rh = h/rows
    local lines = {}
    for i = 0, cols do
        local lx = x + i*cw
        local ln = NovaDraw.line(lx,y, lx,y+h, thickness,color,opacity,false)
        table.remove(NovaDraw._objects,#NovaDraw._objects)
        table.insert(lines, ln)
    end
    for i = 0, rows do
        local ly = y + i*rh
        local ln = NovaDraw.line(x,ly, x+w,ly, thickness,color,opacity,false)
        table.remove(NovaDraw._objects,#NovaDraw._objects)
        table.insert(lines, ln)
    end
    return register({ _type="grid", _lines=lines })
end
 
-- ══════════════════════════════════════════
--  TRACER
-- ══════════════════════════════════════════
 
function NovaDraw.tracer(ox, oy, tx, ty, thickness, color, opacity)
    return NovaDraw.line(ox, oy, tx, ty, thickness, color, opacity, true)
end
 
-- ══════════════════════════════════════════
--  MOVE HELPERS
-- ══════════════════════════════════════════
 
function NovaDraw.moveCircle(obj, x, y)
    obj._frame.Position = UDim2.fromOffset(x, y)
end
 
function NovaDraw.moveLine(obj, x1, y1, x2, y2)
    local dx  = x2-x1; local dy = y2-y1
    local len = math.sqrt(dx*dx+dy*dy)
    obj._frame.Position = UDim2.fromOffset((x1+x2)/2, (y1+y2)/2)
    obj._frame.Size     = UDim2.fromOffset(len, obj._frame.Size.Y.Offset)
    obj._frame.Rotation = math.deg(math.atan2(dy, dx))
    obj._x1=x1; obj._y1=y1; obj._x2=x2; obj._y2=y2
end
 
function NovaDraw.moveSquare(obj, x, y)
    if obj._frame then
        obj._frame.Position = UDim2.fromOffset(x, y)
    elseif obj._frames then
        local f=obj._frames; local t=obj._thickness
        local w=obj._sizeX;  local h=obj._sizeY
        f[1].Position = UDim2.fromOffset(x,       y)
        f[2].Position = UDim2.fromOffset(x,       y+h-t)
        f[3].Position = UDim2.fromOffset(x,       y)
        f[4].Position = UDim2.fromOffset(x+w-t,   y)
    end
    obj._x=x; obj._y=y
end
 
function NovaDraw.moveText(obj, x, y)
    obj._container.Position = UDim2.fromOffset(x, y)
end
 
function NovaDraw.moveCrosshair(obj, x, y)
    local len = obj._length or 10
    local gap = obj._gap    or 0
    NovaDraw.moveLine(obj._h,  x-len-gap, y,          x-gap,     y)
    NovaDraw.moveLine(obj._h2, x+gap,     y,          x+len+gap, y)
    NovaDraw.moveLine(obj._v,  x,         y-len-gap,  x,         y-gap)
    NovaDraw.moveLine(obj._v2, x,         y+gap,      x,         y+len+gap)
end
 
-- ══════════════════════════════════════════
--  STYLE HELPERS
-- ══════════════════════════════════════════
 
function NovaDraw.recolor(obj, color)
    local t = obj._type
    if t == "circle" then
        obj._frame.BackgroundColor3 = color
        if obj._stroke then obj._stroke.Color = color end
    elseif t == "square" then
        if obj._frame then
            obj._frame.BackgroundColor3 = color
            if obj._stroke then obj._stroke.Color = color end
        elseif obj._frames then
            for _,f in ipairs(obj._frames) do f.BackgroundColor3=color end
        end
    elseif t == "line" then
        obj._frame.BackgroundColor3 = color
    elseif t == "text" then
        obj._label.TextColor3 = color
    elseif t == "crosshair" then
        NovaDraw.recolor(obj._h,  color); NovaDraw.recolor(obj._h2, color)
        NovaDraw.recolor(obj._v,  color); NovaDraw.recolor(obj._v2, color)
    elseif t == "arrow" then
        NovaDraw.recolor(obj._body, color)
        NovaDraw.recolor(obj._h1,  color)
        NovaDraw.recolor(obj._h2,  color)
    elseif t == "healthBar" then
        obj._fill.BackgroundColor3 = color
    elseif t == "progressBar" then
        obj._fill.BackgroundColor3 = color
    elseif obj._lines then
        -- triangle, quad, polygon, cornerBox, diamond, star, spiral, dashedLine, grid
        for _,l in ipairs(obj._lines) do NovaDraw.recolor(l, color) end
    end
end
 
function NovaDraw.setOpacity(obj, opacity)
    local t  = 1 - opacity
    local tp = obj._type
    if tp == "circle" then
        obj._frame.BackgroundTransparency = obj._filled and t or 1
        if obj._stroke then obj._stroke.Transparency = t end
    elseif tp == "square" then
        if obj._frame then
            obj._frame.BackgroundTransparency = obj._filled and t or 1
            if obj._stroke then obj._stroke.Transparency = t end
        elseif obj._frames then
            for _,f in ipairs(obj._frames) do f.BackgroundTransparency=t end
        end
    elseif tp == "line" then
        obj._frame.BackgroundTransparency = t
    elseif tp == "text" then
        obj._label.TextTransparency = t
    elseif tp == "crosshair" then
        NovaDraw.setOpacity(obj._h,  opacity); NovaDraw.setOpacity(obj._h2, opacity)
        NovaDraw.setOpacity(obj._v,  opacity); NovaDraw.setOpacity(obj._v2, opacity)
    elseif tp == "arrow" then
        NovaDraw.setOpacity(obj._body, opacity)
        NovaDraw.setOpacity(obj._h1,   opacity)
        NovaDraw.setOpacity(obj._h2,   opacity)
    elseif tp == "healthBar" then
        obj._bg.BackgroundTransparency   = 1 - (opacity * 0.7)
        obj._fill.BackgroundTransparency = t
        if obj._stroke then obj._stroke.Transparency = t end
    elseif tp == "progressBar" then
        obj._bg.BackgroundTransparency   = 1 - (opacity * 0.7)
        obj._fill.BackgroundTransparency = t
    elseif obj._lines then
        for _,l in ipairs(obj._lines) do NovaDraw.setOpacity(l, opacity) end
    end
end
 
function NovaDraw.setThickness(obj, thickness)
    local t = obj._type
    if t == "circle" and obj._stroke then
        obj._stroke.Thickness = thickness
    elseif t == "line" then
        obj._frame.Size = UDim2.fromOffset(obj._frame.Size.X.Offset, thickness)
        obj._thickness  = thickness
    elseif obj._lines then
        for _,l in ipairs(obj._lines) do NovaDraw.setThickness(l, thickness) end
    elseif t == "crosshair" then
        NovaDraw.setThickness(obj._h,  thickness); NovaDraw.setThickness(obj._h2, thickness)
        NovaDraw.setThickness(obj._v,  thickness); NovaDraw.setThickness(obj._v2, thickness)
    elseif t == "arrow" then
        NovaDraw.setThickness(obj._body, thickness)
        NovaDraw.setThickness(obj._h1,   thickness)
        NovaDraw.setThickness(obj._h2,   thickness)
    end
end
 
-- ══════════════════════════════════════════
--  VISIBILITY
--  FIX: explicit dispatch per type — no silent
--  fallthrough between if/elseif chains
-- ══════════════════════════════════════════
 
function NovaDraw.show(obj) NovaDraw.setVisible(obj, true)  end
function NovaDraw.hide(obj) NovaDraw.setVisible(obj, false) end
 
function NovaDraw.setVisible(obj, v)
    local t = obj._type
    if t == "circle" or t == "square" and obj._frame or t == "line" then
        if obj._frame then obj._frame.Visible = v end
        if obj._frames then for _,f in ipairs(obj._frames) do f.Visible=v end end
    elseif t == "text" then
        obj._container.Visible = v
    elseif t == "crosshair" then
        NovaDraw.setVisible(obj._h,  v); NovaDraw.setVisible(obj._h2, v)
        NovaDraw.setVisible(obj._v,  v); NovaDraw.setVisible(obj._v2, v)
    elseif t == "arrow" then
        NovaDraw.setVisible(obj._body, v)
        NovaDraw.setVisible(obj._h1,   v)
        NovaDraw.setVisible(obj._h2,   v)
    elseif t == "healthBar" then
        obj._bg.Visible   = v
        obj._fill.Visible = v
    elseif t == "progressBar" then
        obj._bg.Visible   = v
        obj._fill.Visible = v
    elseif obj._lines then
        -- triangle, quad, polygon, cornerBox, diamond, star, spiral, dashedLine, grid
        for _,l in ipairs(obj._lines) do NovaDraw.setVisible(l, v) end
    else
        -- fallback: try frame/frames/container
        if obj._frame     then obj._frame.Visible = v end
        if obj._frames    then for _,f in ipairs(obj._frames) do f.Visible=v end end
        if obj._container then obj._container.Visible = v end
    end
end
 
-- ══════════════════════════════════════════
--  CONTENT HELPERS
-- ══════════════════════════════════════════
 
function NovaDraw.setText(obj, content)
    obj._label.Text = content
    obj._content    = content
    for _, child in ipairs(obj._container:GetChildren()) do
        if child:IsA("TextLabel") and child ~= obj._label then
            child.Text = content
        end
    end
end
 
function NovaDraw.updateHealthBar(obj, percent)
    percent      = math.clamp(percent, 0, 1)
    obj._percent = percent
    local fillH  = math.floor(obj._h * percent)
    obj._fill.Size     = UDim2.fromOffset(obj._w, math.max(fillH, 1))
    obj._fill.Position = UDim2.fromOffset(obj._x, obj._y + (obj._h - fillH))
    local red   = math.floor((1 - percent) * 255)
    local green = math.floor(percent * 255)
    obj._fill.BackgroundColor3 = Color3.fromRGB(red, green, 0)
end
 
function NovaDraw.updateProgressBar(obj, percent)
    percent      = math.clamp(percent, 0, 1)
    obj._percent = percent
    local fillW  = math.floor(obj._w * percent)
    obj._fill.Size = UDim2.fromOffset(math.max(fillW, 1), obj._h)
end
 
-- ══════════════════════════════════════════
--  REMOVE / CLEANUP
--  FIX: destroyObj is now exhaustive and type-
--  explicit. Every field that holds a Roblox
--  instance is destroyed and then set to nil
--  so double-remove calls are completely safe.
-- ══════════════════════════════════════════
 
local function destroyObj(obj)
    if not obj then return end
    local t = obj._type
 
    -- ── single frame types ────────────────
    if t == "circle" or t == "line" or
       (t == "square" and obj._frame) then
        safeDestroy(obj._frame)
        obj._frame  = nil
        obj._stroke = nil  -- child of frame, already destroyed with it
 
    -- ── 4-frame hollow square ─────────────
    elseif t == "square" and obj._frames then
        for _, f in ipairs(obj._frames) do safeDestroy(f) end
        obj._frames = nil
 
    -- ── text ─────────────────────────────
    elseif t == "text" then
        safeDestroy(obj._container)  -- destroys all child TextLabels too
        obj._container = nil
        obj._label     = nil
 
    -- ── healthBar ────────────────────────
    elseif t == "healthBar" then
        safeDestroy(obj._bg)    -- UIStroke and UICorner are children, go with it
        safeDestroy(obj._fill)
        obj._bg     = nil
        obj._fill   = nil
        obj._stroke = nil
 
    -- ── progressBar ──────────────────────
    elseif t == "progressBar" then
        safeDestroy(obj._bg)
        safeDestroy(obj._fill)
        obj._bg   = nil
        obj._fill = nil
 
    -- ── crosshair ────────────────────────
    elseif t == "crosshair" then
        destroyObj(obj._h);  obj._h  = nil
        destroyObj(obj._h2); obj._h2 = nil
        destroyObj(obj._v);  obj._v  = nil
        destroyObj(obj._v2); obj._v2 = nil
 
    -- ── arrow ─────────────────────────────
    elseif t == "arrow" then
        destroyObj(obj._body); obj._body = nil
        destroyObj(obj._h1);   obj._h1   = nil
        destroyObj(obj._h2);   obj._h2   = nil
 
    -- ── all _lines compound types ─────────
    -- triangle, quad, polygon, cornerBox,
    -- diamond, star, spiral, dashedLine, grid
    elseif obj._lines then
        for _, l in ipairs(obj._lines) do destroyObj(l) end
        obj._lines = nil
    end
end
 
function NovaDraw.remove(obj)
    if not obj then return end
    pcall(destroyObj, obj)
    -- remove from registry
    for i, entry in ipairs(NovaDraw._objects) do
        if entry == obj then
            table.remove(NovaDraw._objects, i)
            break
        end
    end
end
 
function NovaDraw.clearAll()
    -- snapshot the list first so any re-entrant calls don't corrupt iteration
    local snapshot = {}
    for _, obj in ipairs(NovaDraw._objects) do
        table.insert(snapshot, obj)
    end
    NovaDraw._objects = {}
    for _, obj in ipairs(snapshot) do
        pcall(destroyObj, obj)
    end
end
 
function NovaDraw.destroy()
    NovaDraw.clearAll()
    safeDestroy(gui)
end
 
return NovaDraw
