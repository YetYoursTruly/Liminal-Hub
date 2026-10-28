--[[
	Liminal Hub | Loader.lua (single file: loader + hub)
	Run:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/YetYoursTruly/Liminal-Hub/main/Loader.lua"))()

	Adding a tab later:
		local tab = CreateTab("Name", "icon-file-name-without-png")
		local sec = tab:Section("Title", "icon")
		sec:Label(text) / sec:Button(text, fn) / sec:Toggle(text, default, fn)
		sec:Slider(text, min, max, default, fn, "%") / sec:Keybind(text, "RightShift", fn)
		local box = sec:Container(height) -- raw Frame for custom layouts

	Custom Monochrome background:
		Put Background.png (or .jpg) in Workspace/LiminalHub/
]]

if not game:IsLoaded() then
	game.Loaded:Wait()
end

--// Executor check
for _, fnName in ipairs({ "getcustomasset", "writefile", "readfile", "isfile", "isfolder", "makefolder" }) do
	if not (getgenv and getgenv()[fnName]) and not getfenv()[fnName] then
		warn("[Liminal Hub] Your executor is missing: " .. fnName)
		return
	end
end

--// Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

--// Single instance
if getgenv().LiminalHub and getgenv().LiminalHub.Destroy then
	pcall(getgenv().LiminalHub.Destroy)
end

--// Constants
local VERSION = "1.2.0"
local REPO_URL = "https://github.com/YetYoursTruly/Liminal-Hub"
local RAW = "https://raw.githubusercontent.com/YetYoursTruly/Liminal-Hub/main/"
local ROOT = "LiminalHub"
local PATHS = {
	Root = ROOT,
	Assets = ROOT .. "/Assets",
	Music = ROOT .. "/MusicPlayer",
	Track = ROOT .. "/MusicPlayer/Music.mp3",
	Config = ROOT .. "/Config.json",
}
local BG_FILES = { "Background.png", "Background.jpg", "Background.jpeg" }
local ICONS = {
	"settings", "palette", "music", "play", "pause", "repeat", "volume-2",
	"volume-x", "sliders-horizontal", "house", "x", "minus", "maximize", "info",
}
local SIZE_NORMAL = Vector2.new(640, 420)
local SIZE_MAX = Vector2.new(880, 560)
local SHADOW_T = 0.5

--// Folders + icon download
for _, folder in ipairs({ PATHS.Root, PATHS.Assets, PATHS.Music }) do
	if not isfolder(folder) then
		pcall(makefolder, folder)
	end
end

local pending = #ICONS
for _, name in ipairs(ICONS) do
	task.spawn(function()
		local path = PATHS.Assets .. "/" .. name .. ".png"
		local valid = false
		if isfile(path) then
			local ok, data = pcall(readfile, path)
			valid = ok and type(data) == "string" and data:sub(2, 4) == "PNG"
		end
		if not valid then
			local ok, data = pcall(game.HttpGet, game, RAW .. "Assets/" .. name .. ".png")
			if ok and type(data) == "string" and data:sub(2, 4) == "PNG" then
				pcall(writefile, path, data)
			else
				warn("[Liminal Hub] Could not download icon: " .. name .. ".png")
			end
		end
		pending -= 1
	end)
end
local waited = 0
while pending > 0 and waited < 20 do
	waited += task.wait()
end

local iconCache = {}
local function Icon(name)
	if iconCache[name] then
		return iconCache[name]
	end
	local path = PATHS.Assets .. "/" .. name .. ".png"
	if isfile(path) then
		local ok, id = pcall(getcustomasset, path)
		if ok and id then
			iconCache[name] = id
			return id
		end
	end
	return ""
end

--// Config (theme is intentionally not saved: the hub always starts on Monochrome)
local Config = {
	Volume = 50,
	Muted = false,
	Autoplay = false,
	Scale = 100,
	ToggleKey = "RightShift",
	BgDim = 40,
	Theme = "Monochrome",
}
if isfile(PATHS.Config) then
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(PATHS.Config))
	end)
	if ok and type(data) == "table" then
		for k, v in pairs(data) do
			if k ~= "Theme" and Config[k] ~= nil and type(v) == type(Config[k]) then
				Config[k] = v
			end
		end
	end
end

local saveQueued = false
local function Save()
	if saveQueued then
		return
	end
	saveQueued = true
	task.delay(1, function()
		saveQueued = false
		pcall(writefile, PATHS.Config, HttpService:JSONEncode(Config))
	end)
end

--// Themes
local ThemeOrder = { "Monochrome", "Matrix", "Late Night Tokyo", "Halloween" }
local Themes = {
	["Monochrome"] = {
		Background = Color3.fromRGB(6, 6, 6), Surface = Color3.fromRGB(13, 13, 13), Surface2 = Color3.fromRGB(24, 24, 24),
		Accent = Color3.fromRGB(255, 255, 255), Accent2 = Color3.fromRGB(120, 120, 120),
		Text = Color3.fromRGB(242, 242, 242), SubText = Color3.fromRGB(168, 168, 168), Stroke = Color3.fromRGB(62, 62, 62),
		OnAccent = Color3.fromRGB(0, 0, 0), Font = Enum.Font.GothamMedium, FontBold = Enum.Font.GothamBold,
		UseImage = true,
	},
	["Matrix"] = {
		Background = Color3.fromRGB(0, 5, 0), Surface = Color3.fromRGB(2, 14, 4), Surface2 = Color3.fromRGB(5, 28, 9),
		Accent = Color3.fromRGB(0, 255, 65), Accent2 = Color3.fromRGB(0, 150, 25),
		Text = Color3.fromRGB(185, 255, 200), SubText = Color3.fromRGB(80, 190, 105), Stroke = Color3.fromRGB(0, 80, 24),
		OnAccent = Color3.fromRGB(0, 12, 2), Font = Enum.Font.Code, FontBold = Enum.Font.Code,
	},
	["Late Night Tokyo"] = {
		Background = Color3.fromRGB(6, 9, 24), Surface = Color3.fromRGB(12, 17, 40), Surface2 = Color3.fromRGB(21, 28, 62),
		Accent = Color3.fromRGB(88, 140, 255), Accent2 = Color3.fromRGB(255, 92, 170),
		Text = Color3.fromRGB(224, 230, 255), SubText = Color3.fromRGB(150, 164, 214), Stroke = Color3.fromRGB(40, 52, 106),
		OnAccent = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamMedium, FontBold = Enum.Font.GothamBold,
	},
	["Halloween"] = {
		Background = Color3.fromRGB(9, 5, 13), Surface = Color3.fromRGB(19, 11, 28), Surface2 = Color3.fromRGB(32, 19, 46),
		Accent = Color3.fromRGB(255, 117, 0), Accent2 = Color3.fromRGB(150, 70, 235),
		Text = Color3.fromRGB(247, 232, 216), SubText = Color3.fromRGB(190, 160, 180), Stroke = Color3.fromRGB(78, 44, 102),
		OnAccent = Color3.fromRGB(16, 8, 4), Font = Enum.Font.GothamMedium, FontBold = Enum.Font.GothamBold,
	},
}
local Theme = Themes[Config.Theme]

--// Helpers
local Conns = {}
local function Connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(Conns, c)
	return c
end

local function New(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function Tween(inst, goal, t, style, dir)
	TweenService:Create(inst, TweenInfo.new(t or 0.25, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal):Play()
end

local function Set(inst, goal, instant)
	if instant then
		for k, v in pairs(goal) do
			inst[k] = v
		end
	else
		Tween(inst, goal)
	end
end

--// Theme binding
local Bound, Refreshers = {}, {}

local function Bind(inst, map)
	table.insert(Bound, { inst, map })
	for prop, key in pairs(map) do
		inst[prop] = Theme[key]
	end
	return inst
end

local function AddRefresher(fn)
	table.insert(Refreshers, fn)
	fn(true)
end

local function RefreshAll(instant)
	for _, fn in ipairs(Refreshers) do
		fn(instant)
	end
end

local function Corner(parent, r)
	return New("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function Stroke(parent, key, transparency)
	local s = New("UIStroke", {
		Thickness = 1, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
	return Bind(s, { Color = key or "Stroke" })
end

local function Pad(parent, p)
	return New("UIPadding", {
		PaddingTop = UDim.new(0, p), PaddingBottom = UDim.new(0, p),
		PaddingLeft = UDim.new(0, p), PaddingRight = UDim.new(0, p),
	}, parent)
end

local function List(parent, padding)
	return New("UIListLayout", { Padding = UDim.new(0, padding or 0), SortOrder = Enum.SortOrder.LayoutOrder }, parent)
end

local function Text(parent, props, color, bold)
	props.BackgroundTransparency = 1
	props.TextSize = props.TextSize or 13
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	local l = New("TextLabel", props, parent)
	return Bind(l, { TextColor3 = color or "Text", Font = bold and "FontBold" or "Font" })
end

local function Img(parent, name, size, pos, color)
	local i = New("ImageLabel", {
		BackgroundTransparency = 1, Image = Icon(name),
		ResampleMode = Enum.ResamplerMode.Default,
		Size = UDim2.fromOffset(size, size), Position = pos or UDim2.new(),
	}, parent)
	return Bind(i, { ImageColor3 = color or "Accent" })
end

--// Background state + panel opacity (panels get more see-through only when a custom image is showing)
local BgState = { Found = false }
local Panels = {}
local BgDim, BgImage, BgStatus

local function PanelTransparency()
	return (Theme.UseImage and BgState.Found) and 0.3 or 0.04
end

local function Panel(inst)
	inst.BackgroundTransparency = PanelTransparency()
	table.insert(Panels, inst)
	return inst
end

local function UpdateBackground(instant)
	local show = (Theme.UseImage and BgState.Found) and true or false
	if BgImage then
		BgImage.Visible = show
		BgDim.Visible = show
		BgDim.BackgroundTransparency = 1 - (Config.BgDim / 100)
	end
	for i = #Panels, 1, -1 do
		local p = Panels[i]
		if p.Parent == nil then
			table.remove(Panels, i)
		else
			Set(p, { BackgroundTransparency = PanelTransparency() }, instant)
		end
	end
	if BgStatus then
		if not Theme.UseImage then
			BgStatus.Text = "Background images only show on the Monochrome theme."
		elseif BgState.Found then
			BgStatus.Text = "Background loaded. Higher darkness = darker image, 0% = raw image."
		else
			BgStatus.Text = "No background found. Put Background.png or Background.jpg in Workspace/LiminalHub/ then press Reload."
		end
	end
end

--// ScreenGui + window
local Gui = New("ScreenGui", {
	Name = "LiminalHub", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999, Enabled = false,
}, (gethui and gethui()) or CoreGui)

local Window = New("Frame", {
	Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(SIZE_NORMAL.X, SIZE_NORMAL.Y), BackgroundTransparency = 1,
}, Gui)
local UIScaleObj = New("UIScale", { Scale = Config.Scale / 100 }, Window)

-- Anim holds everything so open/close can slide it without touching the draggable Window
local Anim = New("Frame", { Name = "Anim", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, Window)

local State = { Listening = false, Open = false, Maximized = false, Unloading = false, Token = 0 }

-- Shadow (Roblox UIShadow) sits on a solid backing box behind the window
local ShadowBox = New("Frame", {
	Name = "ShadowBox", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 0,
}, Anim)
Corner(ShadowBox, 8)

local Shadow
do
	local ok, s = pcall(Instance.new, "UIShadow")
	if ok and s then
		pcall(function() s.BlurRadius = UDim.new(0, 32) end)
		pcall(function() s.Spread = UDim2.fromOffset(2, 2) end)
		pcall(function() s.Offset = UDim2.new() end)
		pcall(function() s.Transparency = SHADOW_T end)
		s.Parent = ShadowBox
		Bind(s, { Color = "Accent" })
		Shadow = s
	else
		warn("[Liminal Hub] UIShadow is not supported here, skipping the glow shadow.")
	end
end

local Main = New("CanvasGroup", {
	Name = "Main", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 1, GroupTransparency = 1,
}, Anim)
Bind(Main, { BackgroundColor3 = "Background" })
Corner(Main, 8)
Stroke(Main, "Accent", 0.65)

--// Background image
BgImage = New("ImageLabel", {
	Name = "BgImage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
	ScaleType = Enum.ScaleType.Crop, ZIndex = 1, Visible = false,
}, Main)
BgDim = New("Frame", {
	Name = "BgDim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0, ZIndex = 2, Visible = false,
}, Main)

local function LoadBackground()
	BgState.Found = false
	for _, file in ipairs(BG_FILES) do
		local path = PATHS.Root .. "/" .. file
		if isfile(path) then
			local ok, id = pcall(getcustomasset, path)
			if ok and id then
				BgImage.Image = id
				BgState.Found = true
				break
			end
		end
	end
	UpdateBackground()
end
LoadBackground()

--// Matrix rain layer
local Rain = { Enabled = false, Cols = {} }
local RainLayer = New("Frame", {
	Name = "Rain", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
	ClipsDescendants = true, ZIndex = 3, Visible = false,
}, Main)

local function RandBits()
	local t = {}
	for i = 1, 18 do
		t[i] = tostring(math.random(0, 1))
	end
	return table.concat(t, "\n")
end

do
	local COLS = 36
	for i = 1, COLS do
		local xs = (i - 1) / COLS
		local y = -math.random(0, 420)
		local l = New("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1 / COLS, 0, 0, 252),
			Position = UDim2.new(xs, 0, 0, y),
			Text = RandBits(), TextSize = 14, Font = Enum.Font.Code, LineHeight = 1,
			TextYAlignment = Enum.TextYAlignment.Top,
		}, RainLayer)
		Bind(l, { TextColor3 = "Accent" })
		New("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.6) }),
		}, l)
		table.insert(Rain.Cols, { l = l, xs = xs, y = y, speed = math.random(50, 130) })
	end
end

Connect(RunService.RenderStepped, function(dt)
	if not RainLayer.Visible then
		return
	end
	local h = Window.Size.Y.Offset
	for _, c in ipairs(Rain.Cols) do
		c.y += c.speed * dt
		if c.y > h then
			c.y = -252
			c.speed = math.random(50, 130)
			c.l.Text = RandBits()
		end
		c.l.Position = UDim2.new(c.xs, 0, 0, c.y)
	end
end)

--// Top bar
local TopBar = New("Frame", { Name = "TopBar", Size = UDim2.new(1, 0, 0, 44), BorderSizePixel = 0, ZIndex = 5 }, Main)
Bind(TopBar, { BackgroundColor3 = "Surface" })
Panel(TopBar)
Text(TopBar, { Text = "LIMINAL HUB", Size = UDim2.new(0, 220, 1, 0), Position = UDim2.fromOffset(16, 0), TextSize = 19 }, "Accent", true)

local AccentLine = New("Frame", {
	Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1),
}, TopBar)
local AccentGrad = New("UIGradient", {}, AccentLine)
AddRefresher(function()
	AccentGrad.Color = ColorSequence.new(Theme.Accent, Theme.Accent2)
end)

local function TopButton(iconName, xOffset, size, hoverColor)
	local b = New("ImageButton", {
		BackgroundTransparency = 1, Image = Icon(iconName), Size = UDim2.fromOffset(size, size),
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOffset, 0.5, 0),
	}, TopBar)
	Bind(b, { ImageColor3 = "Text" })
	Connect(b.MouseEnter, function() Tween(b, { ImageColor3 = hoverColor or Theme.Accent }, 0.15) end)
	Connect(b.MouseLeave, function() Tween(b, { ImageColor3 = Theme.Text }, 0.15) end)
	return b
end
local CloseBtn = TopButton("x", -14, 24, Color3.fromRGB(255, 85, 85))
local MaxBtn = TopButton("maximize", -52, 20)
local MinBtn = TopButton("minus", -86, 20)

--// Smooth (tweened) dragging
do
	local dragging, dragStart, startPos
	Connect(TopBar.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, input.Position, Window.Position
		end
	end)
	Connect(UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			local target = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			Tween(Window, { Position = target }, 0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		end
	end)
	Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

--// Body: sidebar + content
local Body = New("Frame", {
	Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), ZIndex = 4,
}, Main)

local Sidebar = New("Frame", { Name = "Sidebar", Size = UDim2.new(0, 150, 1, 0), BorderSizePixel = 0 }, Body)
Bind(Sidebar, { BackgroundColor3 = "Surface" })
Panel(Sidebar)
local Divider = New("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BorderSizePixel = 0 }, Sidebar)
Bind(Divider, { BackgroundColor3 = "Stroke" })
local TabList = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, Sidebar)
Pad(TabList, 8)
List(TabList, 4)

local Content = New("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(150, 0), Size = UDim2.new(1, -150, 1, 0) }, Body)

--// Open / close animations
local function PlayOpen()
	local s = Config.Scale / 100
	Gui.Enabled = true
	UIScaleObj.Scale = s * 0.86
	Anim.Position = UDim2.fromOffset(0, 28)
	Main.GroupTransparency = 1
	ShadowBox.BackgroundTransparency = 1
	if Shadow then
		Shadow.Transparency = 1
	end
	Tween(UIScaleObj, { Scale = s }, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	Tween(Anim, { Position = UDim2.new() }, 0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	Tween(Main, { GroupTransparency = 0 }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Tween(ShadowBox, { BackgroundTransparency = 0 }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if Shadow then
		Tween(Shadow, { Transparency = SHADOW_T }, 0.6)
	end
end

local function PlayClose()
	local s = Config.Scale / 100
	Tween(UIScaleObj, { Scale = s * 0.9 }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	Tween(Anim, { Position = UDim2.fromOffset(0, 30) }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	Tween(Main, { GroupTransparency = 1 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Tween(ShadowBox, { BackgroundTransparency = 1 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if Shadow then
		Tween(Shadow, { Transparency = 1 }, 0.25)
	end
	return 0.32
end

local function SetOpen(open)
	if State.Unloading or State.Open == open then
		return
	end
	State.Open = open
	State.Token += 1
	local token = State.Token
	if open then
		PlayOpen()
	else
		local d = PlayClose()
		task.delay(d, function()
			if State.Token == token and not State.Open then
				Gui.Enabled = false
			end
		end)
	end
end

--// Window buttons
local Destroy
local Sound -- forward declared, created in the music engine below

local function Unload()
	if State.Unloading then
		return
	end
	State.Unloading = true
	State.Open = false
	local d = PlayClose()
	if Sound then
		Tween(Sound, { Volume = 0 }, d + 0.15)
	end
	task.delay(d + 0.2, function()
		Destroy()
	end)
end

Connect(MinBtn.MouseButton1Click, function()
	SetOpen(false) -- same as the toggle key
end)
Connect(MaxBtn.MouseButton1Click, function()
	State.Maximized = not State.Maximized
	local sz = State.Maximized and SIZE_MAX or SIZE_NORMAL
	Tween(Window, { Size = UDim2.fromOffset(sz.X, sz.Y) }, 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
end)
Connect(CloseBtn.MouseButton1Click, Unload)

--// Tabs
local Tabs, CurrentTab = {}, nil
local Tab = {}
Tab.__index = Tab

local function SelectTab(tab)
	CurrentTab = tab
	for _, t in ipairs(Tabs) do
		t.Page.Visible = (t == tab)
	end
	RefreshAll()
end

local function CreateTab(name, iconName)
	local tab = setmetatable({ Name = name, _order = 0 }, Tab)

	local btn = New("TextButton", {
		Name = name, Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Text = "",
		AutoButtonColor = false, LayoutOrder = #Tabs + 1, BorderSizePixel = 0,
	}, TabList)
	Corner(btn, 6)
	local tstroke = New("UIStroke", { Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, btn)
	local bar = New("Frame", { Size = UDim2.new(0, 3, 0.6, 0), Position = UDim2.new(0, 0, 0.2, 0), BorderSizePixel = 0, BackgroundTransparency = 1 }, btn)
	Corner(bar, 2)
	local ico = New("ImageLabel", { BackgroundTransparency = 1, Image = Icon(iconName), Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 14, 0.5, -9) }, btn)
	local lbl = New("TextLabel", {
		BackgroundTransparency = 1, Text = name, Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(40, 0),
		TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
	}, btn)
	Bind(lbl, { Font = "FontBold" })

	local page = New("ScrollingFrame", {
		Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, Content)
	Bind(page, { ScrollBarImageColor3 = "Accent" })
	Pad(page, 12)
	List(page, 10)
	tab.Page = page

	AddRefresher(function(instant)
		local active = CurrentTab == tab
		Set(btn, { BackgroundTransparency = active and 0.1 or 1, BackgroundColor3 = Theme.Surface2 }, instant)
		Set(bar, { BackgroundTransparency = active and 0 or 1, BackgroundColor3 = Theme.Accent }, instant)
		Set(tstroke, { Transparency = active and 0.65 or 1, Color = Theme.Accent }, instant)
		Set(ico, { ImageColor3 = active and Theme.Accent or Theme.Text }, instant)
		Set(lbl, { TextColor3 = active and Theme.Accent or Theme.Text }, instant)
	end)

	Connect(btn.MouseButton1Click, function()
		SelectTab(tab)
	end)
	table.insert(Tabs, tab)
	return tab
end

local function Row(sec, height)
	sec._n += 1
	return New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height), LayoutOrder = sec._n }, sec.Frame)
end

function Tab:Section(title, iconName)
	self._order += 1
	local frame = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0, LayoutOrder = self._order,
	}, self.Page)
	Bind(frame, { BackgroundColor3 = "Surface" })
	Panel(frame)
	Corner(frame, 6)
	Stroke(frame, "Stroke", 0.2)
	Pad(frame, 10)
	List(frame, 8)

	local header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0 }, frame)
	local textX = 0
	if iconName then
		Img(header, iconName, 20, UDim2.new(0, 0, 0.5, -10), "Accent")
		textX = 22
	end
	Text(header, { Text = string.upper(title), Size = UDim2.new(1, -textX, 1, 0), Position = UDim2.fromOffset(textX, 0), TextSize = 11 }, "Accent", true)

	local sec = { Frame = frame, _n = 0 }

	function sec:Container(height)
		self._n += 1
		return New("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height or 0),
			AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y, LayoutOrder = self._n,
		}, self.Frame)
	end

	function sec:Label(str)
		self._n += 1
		return Text(self.Frame, {
			Text = str, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true, LayoutOrder = self._n, TextSize = 12,
		}, "SubText")
	end

	function sec:Button(str, callback)
		local row = Row(self, 30)
		local b = New("TextButton", {
			Size = UDim2.fromScale(1, 1), Text = str, TextSize = 13, AutoButtonColor = false, BorderSizePixel = 0,
		}, row)
		Bind(b, { BackgroundColor3 = "Surface2", TextColor3 = "Text", Font = "FontBold" })
		Corner(b, 5)
		local s = Stroke(b, "Stroke")
		Connect(b.MouseEnter, function() Tween(s, { Color = Theme.Accent }, 0.15) end)
		Connect(b.MouseLeave, function() Tween(s, { Color = Theme.Stroke }, 0.15) end)
		Connect(b.MouseButton1Click, function()
			if callback then
				task.spawn(callback)
			end
		end)
		return b
	end

	function sec:Toggle(str, default, callback)
		local row = Row(self, 28)
		Text(row, { Text = str, Size = UDim2.new(1, -50, 1, 0) }, "Text")
		local sw = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(38, 20),
			Text = "", AutoButtonColor = false, BorderSizePixel = 0,
		}, row)
		Corner(sw, 10)
		local swStroke = New("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, sw)
		local knob = New("Frame", { Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0 }, sw)
		Corner(knob, 7)
		local state = default and true or false
		AddRefresher(function(instant)
			Set(sw, { BackgroundColor3 = state and Theme.Accent or Theme.Surface2 }, instant)
			Set(swStroke, { Color = state and Theme.Accent or Theme.Stroke }, instant)
			Set(knob, {
				Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
				BackgroundColor3 = state and Theme.OnAccent or Theme.SubText,
			}, instant)
		end)
		local obj = {}
		function obj.Set(v)
			state = v and true or false
			RefreshAll()
		end
		Connect(sw.MouseButton1Click, function()
			state = not state
			RefreshAll()
			if callback then
				task.spawn(callback, state)
			end
		end)
		return obj
	end

	function sec:Slider(str, min, max, default, callback, suffix)
		suffix = suffix or ""
		local row = Row(self, 42)
		Text(row, { Text = str, Size = UDim2.new(0.6, 0, 0, 18) }, "Text")
		local valueLbl = Text(row, { Size = UDim2.new(0.4, 0, 0, 18), Position = UDim2.fromScale(0.6, 0), TextXAlignment = Enum.TextXAlignment.Right }, "SubText")
		local hit = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 16) }, row)
		local track = New("Frame", { Position = UDim2.new(0, 0, 0.5, -2), Size = UDim2.new(1, 0, 0, 4), BorderSizePixel = 0 }, hit)
		Bind(track, { BackgroundColor3 = "Surface2" })
		Corner(track, 2)
		Stroke(track, "Stroke", 0.4)
		local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, track)
		Bind(fill, { BackgroundColor3 = "Accent" })
		Corner(fill, 2)
		local knob = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(8, 14), BorderSizePixel = 0 }, track)
		Bind(knob, { BackgroundColor3 = "Text" })
		Corner(knob, 3)
		Stroke(knob, "Accent", 0.4)

		local value = math.clamp(default, min, max)
		local function render()
			local a = (value - min) / (max - min)
			fill.Size = UDim2.fromScale(a, 1)
			knob.Position = UDim2.fromScale(a, 0.5)
			valueLbl.Text = tostring(value) .. suffix
		end
		render()

		local function fromInput(input)
			local a = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
			local v = math.floor(min + (max - min) * a + 0.5)
			if v ~= value then
				value = v
				render()
				if callback then
					task.spawn(callback, value)
				end
			end
		end

		local dragging = false
		Connect(hit.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				fromInput(input)
			end
		end)
		Connect(UserInputService.InputChanged, function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				fromInput(input)
			end
		end)
		Connect(UserInputService.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		return { Get = function() return value end }
	end

	function sec:Keybind(str, default, callback)
		local row = Row(self, 28)
		Text(row, { Text = str, Size = UDim2.new(1, -110, 1, 0) }, "Text")
		local b = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(100, 24),
			Text = default, TextSize = 12, AutoButtonColor = false, BorderSizePixel = 0,
		}, row)
		Bind(b, { BackgroundColor3 = "Surface2", TextColor3 = "Accent", Font = "FontBold" })
		Corner(b, 5)
		Stroke(b, "Stroke")
		Connect(b.MouseButton1Click, function()
			if State.Listening then
				return
			end
			State.Listening = true
			b.Text = "Press a key..."
			local conn
			conn = UserInputService.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.Keyboard then
					return
				end
				conn:Disconnect()
				if input.KeyCode ~= Enum.KeyCode.Escape then
					default = input.KeyCode.Name
					if callback then
						task.spawn(callback, default)
					end
				end
				b.Text = default
				task.defer(function()
					State.Listening = false
				end)
			end)
		end)
		return b
	end

	return sec
end

--// Music engine
Sound = New("Sound", { Name = "LiminalHub_Music", Looped = true, Volume = 0.5 }, SoundService)
local Music = { Playing = false, Ready = false, Downloading = false }

local function ApplyVolume()
	Sound.Volume = Config.Muted and 0 or (Config.Volume / 100)
end
ApplyVolume()

function Music.Load()
	Music.Ready = false
	if not isfile(PATHS.Track) then
		return false
	end
	local ok, id = pcall(getcustomasset, PATHS.Track)
	if not ok or not id then
		return false
	end
	Sound.SoundId = id
	Music.Ready = true
	return true
end

function Music.SetPlaying(play)
	if play and not Music.Ready and not Music.Load() then
		Music.Playing = false
		return
	end
	Music.Playing = play
	if play then
		Sound:Play()
	else
		Sound:Pause()
	end
end

-- Default track: downloaded from the repo's MusicPlayer folder only if you don't already have a Music.mp3
function Music.DownloadDefault()
	if Music.Downloading or isfile(PATHS.Track) then
		return
	end
	Music.Downloading = true
	task.spawn(function()
		local ok, data = pcall(game.HttpGet, game, RAW .. "MusicPlayer/Music.mp3")
		if ok and type(data) == "string" and #data > 2048 and data:sub(1, 3) ~= "404" then
			pcall(writefile, PATHS.Track, data)
		else
			warn("[Liminal Hub] Could not download the default Music.mp3")
		end
		Music.Downloading = false
		if Gui.Parent and Music.Load() and Config.Autoplay then
			Music.SetPlaying(true)
		end
	end)
end

if not Music.Load() then
	Music.DownloadDefault()
end

--// Pages (Settings sits right under Home)
local Home = CreateTab("Home", "house")
local ScriptHub = CreateTab("Home", "scroll")
local Settings = CreateTab("Settings", "settings")

-- Home
do
	local welcome = Home:Section("Welcome", "house")
	welcome:Label("Welcome back, " .. LocalPlayer.DisplayName .. ".")
	local exec = "Unknown"
	if identifyexecutor then
		local ok, name, ver = pcall(identifyexecutor)
		if ok and name then
			exec = tostring(name) .. (ver and (" " .. tostring(ver)) or "")
		end
	end
	welcome:Label("Executor: " .. exec .. "\nPlace ID: " .. game.PlaceId .. "\nPress " .. Config.ToggleKey .. " (or the minus button) to hide the UI, and again to bring it back.")

	local quick = Home:Section("Quick Actions", "sliders-horizontal")
	quick:Button("Open Settings", function()
		SelectTab(Settings)
	end)
	quick:Button("Rejoin Server", function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end)
end

local queue_on_teleport =
    queue_on_teleport
    or (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)

if queue_on_teleport then
    queue_on_teleport([[
        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/YetYoursTruly/Liminal-Hub/main/Loader.lua"
        ))()
    ]])
end

-- Script Hub
do
	local Scriptz = ScriptHub:Section("My Scripts", "scroll")
	Scriptz:Button("Load SundownV5", function()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/YetYoursTruly/Sundown-UI/main/SundownV5"))()
	end)

	Scriptz:Button("Load Syn-Guard", function()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/YetYoursTruly/Syn-Guard/main/Loader.lua"))()
	end)

	Scriptz:Label("More coming soon!")
end

-- Settings > General
do
	local general = Settings:Section("General", "sliders-horizontal")
	general:Keybind("Toggle UI Key", Config.ToggleKey, function(key)
		Config.ToggleKey = key
		Save()
	end)
	general:Slider("UI Scale", 70, 130, Config.Scale, function(v)
		Config.Scale = v
		UIScaleObj.Scale = v / 100
		Save()
	end, "%")
	general:Toggle("Autoplay Music On Load", Config.Autoplay, function(v)
		Config.Autoplay = v
		Save()
	end)
	general:Button("Unload Liminal Hub", Unload)
end

-- Settings > Themes
local ThemeCards = {}
local function ApplyTheme(name, instant)
	Theme = Themes[name]
	Config.Theme = name
	for i = #Bound, 1, -1 do
		local e = Bound[i]
		local inst = e[1]
		if inst.Parent == nil then
			table.remove(Bound, i)
		else
			local goal = {}
			for prop, key in pairs(e[2]) do
				if prop == "Font" then
					inst.Font = Theme[key]
				else
					goal[prop] = Theme[key]
				end
			end
			Set(inst, goal, instant)
		end
	end
	Rain.Enabled = (name == "Matrix")
	RainLayer.Visible = Rain.Enabled
	UpdateBackground(instant)
	RefreshAll(instant)
end

do
	local themes = Settings:Section("Themes", "palette")
	local grid = themes:Container()
	New("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, 58), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)

	for i, name in ipairs(ThemeOrder) do
		local t = Themes[name]
		local card = New("TextButton", {
			LayoutOrder = i, Text = "", AutoButtonColor = false, BackgroundColor3 = t.Background, BorderSizePixel = 0,
		}, grid)
		Corner(card, 6)
		local stroke = New("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = t.Stroke }, card)
		New("TextLabel", {
			BackgroundTransparency = 1, Text = string.upper(name), Font = t.FontBold, TextSize = 11, TextColor3 = t.Text,
			TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 16),
		}, card)
		for s, col in ipairs({ t.Accent, t.Accent2, t.Surface2 }) do
			local sw = New("Frame", { Size = UDim2.fromOffset(14, 6), Position = UDim2.new(0, 10 + (s - 1) * 20, 1, -18), BackgroundColor3 = col, BorderSizePixel = 0 }, card)
			Corner(sw, 2)
		end
		ThemeCards[name] = stroke
		Connect(card.MouseButton1Click, function()
			ApplyTheme(name)
		end)
	end

	AddRefresher(function()
		for name, stroke in pairs(ThemeCards) do
			local selected = (name == Config.Theme)
			stroke.Thickness = selected and 2 or 1
			stroke.Color = selected and Theme.Accent or Themes[name].Stroke
		end
	end)

	BgStatus = themes:Label("")
	themes:Slider("Background Darkness", 0, 95, Config.BgDim, function(v)
		Config.BgDim = v
		UpdateBackground()
		Save()
	end, "%")
	themes:Button("Reload Background", LoadBackground)
	UpdateBackground(true)
end

-- Settings > Music Player
do
	local ms = Settings:Section("Music Player", "music")
	local pc = ms:Container(106)

	Text(pc, { Text = "Music.mp3", Size = UDim2.new(1, 0, 0, 18), TextSize = 14 }, "Text", true)
	local status = Text(pc, { Text = "", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 18), TextSize = 12 }, "SubText")

	local barHit = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 14) }, pc)
	local track = New("Frame", { Position = UDim2.new(0, 0, 0.5, -2), Size = UDim2.new(1, 0, 0, 4), BorderSizePixel = 0 }, barHit)
	Bind(track, { BackgroundColor3 = "Surface2" })
	Corner(track, 2)
	Stroke(track, "Stroke", 0.4)
	local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, track)
	Bind(fill, { BackgroundColor3 = "Accent" })
	Corner(fill, 2)

	local tCur = Text(pc, { Text = "0:00", Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 58), TextSize = 11 }, "SubText")
	local tEnd = Text(pc, { Text = "0:00", Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 58), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right }, "SubText")

	Connect(barHit.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if Sound.TimeLength > 0 then
				local a = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
				Sound.TimePosition = a * Sound.TimeLength
			end
		end
	end)

	-- Play / pause
	local playBtn = New("TextButton", { Position = UDim2.fromOffset(0, 76), Size = UDim2.fromOffset(28, 28), Text = "", AutoButtonColor = false, BorderSizePixel = 0 }, pc)
	Bind(playBtn, { BackgroundColor3 = "Accent" })
	Corner(playBtn, 6)
	local playIcon = New("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(7, 7) }, playBtn)
	Bind(playIcon, { ImageColor3 = "OnAccent" })

	-- Loop indicator (always on)
	Img(pc, "repeat", 20, UDim2.fromOffset(42, 80), "Accent")
	Text(pc, { Text = "Looping", Size = UDim2.fromOffset(60, 28), Position = UDim2.fromOffset(62, 76), TextSize = 12 }, "SubText")

	-- Mute
	local muteBtn = New("TextButton", { Position = UDim2.fromOffset(128, 76), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, pc)
	local muteIcon = New("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(5, 5) }, muteBtn)

	local function fmt(s)
		s = math.max(0, math.floor(s))
		return string.format("%d:%02d", s // 60, s % 60)
	end

	local function RenderControls(instant)
		playIcon.Image = Icon(Music.Playing and "pause" or "play")
		muteIcon.Image = Icon(Config.Muted and "volume-x" or "volume-2")
		Set(muteIcon, { ImageColor3 = Config.Muted and Theme.SubText or Theme.Text }, instant)
	end
	AddRefresher(RenderControls)

	Connect(playBtn.MouseButton1Click, function()
		Music.SetPlaying(not Music.Playing)
		RenderControls(true)
	end)
	Connect(muteBtn.MouseButton1Click, function()
		Config.Muted = not Config.Muted
		ApplyVolume()
		RenderControls(true)
		Save()
	end)

	ms:Slider("Volume", 0, 100, Config.Volume, function(v)
		Config.Volume = v
		if v > 0 and Config.Muted then
			Config.Muted = false
			RenderControls(true)
		end
		ApplyVolume()
		Save()
	end, "%")

	ms:Button("Reload Music.mp3", function()
		local was = Music.Playing
		Sound:Stop()
		Music.Playing = false
		if Music.Load() then
			if was then
				Music.SetPlaying(true)
			end
		else
			Music.DownloadDefault()
		end
		RenderControls(true)
	end)

	local acc = 0
	Connect(RunService.Heartbeat, function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		if not isfile(PATHS.Track) then
			status.Text = Music.Downloading and "Downloading default track..." or ("Put a file at Workspace/" .. PATHS.Track)
			Music.Ready = false
			fill.Size = UDim2.fromScale(0, 1)
			return
		end
		status.Text = (Music.Playing and "Playing" or "Paused") .. "  |  Loops forever"
		local len = Sound.TimeLength
		if len > 0 then
			fill.Size = UDim2.fromScale(math.clamp(Sound.TimePosition / len, 0, 1), 1)
			tCur.Text = fmt(Sound.TimePosition)
			tEnd.Text = fmt(len)
		end
	end)
end

-- Settings > About
do
	local about = Settings:Section("About", "info")
	about:Label("Liminal Hub v" .. VERSION)
	about:Button("Copy Repo Link", function()
		if setclipboard then
			setclipboard(REPO_URL)
		end
	end)
end

--// Toggle key
Connect(UserInputService.InputBegan, function(input)
	if State.Listening or UserInputService:GetFocusedTextBox() then
		return
	end
	local ok, key = pcall(function()
		return Enum.KeyCode[Config.ToggleKey]
	end)
	if ok and input.KeyCode == key then
		SetOpen(not State.Open)
	end
end)

--// Cleanup
Destroy = function()
	for _, c in ipairs(Conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	pcall(function()
		Sound:Stop()
		Sound:Destroy()
	end)
	pcall(function()
		Gui:Destroy()
	end)
	pcall(writefile, PATHS.Config, HttpService:JSONEncode(Config))
	getgenv().LiminalHub = nil
end
getgenv().LiminalHub = { Destroy = Destroy, Version = VERSION }

--// Start
ApplyTheme(Config.Theme, true)
SelectTab(Home)
State.Open = true
PlayOpen()
if Config.Autoplay then
	Music.SetPlaying(true)
	RefreshAll(true)
end