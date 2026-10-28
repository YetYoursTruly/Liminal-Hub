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

	Custom Watch Dogs background:
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
local VERSION = "1.1.0"
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
	"volume-x", "sliders-horizontal", "house", "x", "minus", "info",
}

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

--// Config (theme is intentionally not saved: the hub always starts on Watch Dogs)
local Config = {
	Volume = 50,
	Muted = false,
	Autoplay = false,
	Scale = 100,
	ToggleKey = "RightShift",
	BgDim = 55,
	Theme = "Watch Dogs",
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
local ThemeOrder = { "Watch Dogs", "Matrix", "Late Night Tokyo", "Halloween" }
local Themes = {
	["Watch Dogs"] = {
		Background = Color3.fromRGB(6, 6, 6), Surface = Color3.fromRGB(12, 12, 12), Surface2 = Color3.fromRGB(22, 22, 22),
		Accent = Color3.fromRGB(255, 255, 255), Accent2 = Color3.fromRGB(120, 120, 120),
		Text = Color3.fromRGB(240, 240, 240), SubText = Color3.fromRGB(128, 128, 128), Stroke = Color3.fromRGB(52, 52, 52),
		OnAccent = Color3.fromRGB(0, 0, 0), Font = Enum.Font.GothamMedium, FontBold = Enum.Font.GothamBold,
		UseImage = true,
	},
	["Matrix"] = {
		Background = Color3.fromRGB(0, 5, 0), Surface = Color3.fromRGB(2, 14, 4), Surface2 = Color3.fromRGB(5, 28, 9),
		Accent = Color3.fromRGB(0, 255, 65), Accent2 = Color3.fromRGB(0, 150, 25),
		Text = Color3.fromRGB(185, 255, 200), SubText = Color3.fromRGB(55, 160, 80), Stroke = Color3.fromRGB(0, 75, 22),
		OnAccent = Color3.fromRGB(0, 12, 2), Font = Enum.Font.Code, FontBold = Enum.Font.Code,
	},
	["Late Night Tokyo"] = {
		Background = Color3.fromRGB(6, 9, 24), Surface = Color3.fromRGB(12, 17, 40), Surface2 = Color3.fromRGB(21, 28, 62),
		Accent = Color3.fromRGB(88, 140, 255), Accent2 = Color3.fromRGB(255, 92, 170),
		Text = Color3.fromRGB(220, 227, 255), SubText = Color3.fromRGB(118, 132, 184), Stroke = Color3.fromRGB(36, 46, 96),
		OnAccent = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamMedium, FontBold = Enum.Font.GothamBold,
	},
	["Halloween"] = {
		Background = Color3.fromRGB(9, 5, 13), Surface = Color3.fromRGB(19, 11, 28), Surface2 = Color3.fromRGB(32, 19, 46),
		Accent = Color3.fromRGB(255, 117, 0), Accent2 = Color3.fromRGB(150, 70, 235),
		Text = Color3.fromRGB(247, 232, 216), SubText = Color3.fromRGB(165, 132, 155), Stroke = Color3.fromRGB(72, 40, 94),
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
		Size = UDim2.fromOffset(size, size), Position = pos or UDim2.new(),
	}, parent)
	return Bind(i, { ImageColor3 = color or "Accent" })
end

--// ScreenGui + window
local Gui = New("ScreenGui", {
	Name = "LiminalHub", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
}, (gethui and gethui()) or CoreGui)

local Window = New("Frame", {
	Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(640, 420), BackgroundTransparency = 1,
}, Gui)
local UIScaleObj = New("UIScale", { Scale = Config.Scale / 100 }, Window)

local State = { Minimized = false, Listening = false, Open = true }

-- Glow halos: stacked outer strokes that fade out, drawn behind the window
local Halos = {}
do
	local bases = { 0.55, 0.74, 0.87, 0.95 }
	for i, base in ipairs(bases) do
		local h = New("Frame", {
			Name = "Halo" .. i, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0,
			Position = UDim2.fromOffset(-i * 2, -i * 2), Size = UDim2.new(1, i * 4, 1, i * 4),
		}, Window)
		local s = New("UIStroke", { Thickness = 2, Transparency = base, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, h)
		Bind(s, { Color = "Accent" })
		Halos[i] = { s = s, base = base }
	end
end

Connect(RunService.Heartbeat, function()
	if not Gui.Enabled then
		return
	end
	local pulse = math.sin(os.clock() * 1.6) * 0.05
	for _, h in ipairs(Halos) do
		h.s.Transparency = math.clamp(h.base + pulse, 0, 1)
	end
end)

local Main = New("Frame", {
	Name = "Main", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 1,
}, Window)
Bind(Main, { BackgroundColor3 = "Background" })
Stroke(Main, "Accent", 0.35)

--// Background image (Watch Dogs theme)
local BgImage = New("ImageLabel", {
	Name = "BgImage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
	ScaleType = Enum.ScaleType.Crop, ZIndex = 1, Visible = false,
}, Main)
local BgDim = New("Frame", {
	Name = "BgDim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0, ZIndex = 2, Visible = false,
}, Main)
local BgState = { Found = false }

local function UpdateBackground()
	local show = Theme.UseImage and BgState.Found
	BgImage.Visible = show and true or false
	BgDim.Visible = show and true or false
	BgDim.BackgroundTransparency = 1 - (Config.BgDim / 100)
end

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
	local COLS = 30
	local CW = 640 / COLS
	for i = 1, COLS do
		local l = New("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromOffset(CW, 252),
			Position = UDim2.fromOffset((i - 1) * CW, -math.random(0, 420)),
			Text = RandBits(), TextSize = 14, Font = Enum.Font.Code, LineHeight = 1,
			TextYAlignment = Enum.TextYAlignment.Top,
		}, RainLayer)
		Bind(l, { TextColor3 = "Accent" })
		New("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.6) }),
		}, l)
		table.insert(Rain.Cols, { l = l, x = (i - 1) * CW, y = -math.random(0, 420), speed = math.random(50, 130) })
	end
end

Connect(RunService.RenderStepped, function(dt)
	if not RainLayer.Visible then
		return
	end
	for _, c in ipairs(Rain.Cols) do
		c.y += c.speed * dt
		if c.y > 420 then
			c.y = -252
			c.speed = math.random(50, 130)
			c.l.Text = RandBits()
		end
		c.l.Position = UDim2.fromOffset(c.x, c.y)
	end
end)

local function UpdateRain()
	RainLayer.Visible = Rain.Enabled and not State.Minimized
end

--// Top bar
local TopBar = New("Frame", {
	Name = "TopBar", Size = UDim2.new(1, 0, 0, 40), BorderSizePixel = 0, BackgroundTransparency = 0.15, ZIndex = 5,
}, Main)
Bind(TopBar, { BackgroundColor3 = "Surface" })
Text(TopBar, { Text = "LIMINAL HUB", Size = UDim2.new(0, 160, 1, 0), Position = UDim2.fromOffset(14, 0), TextSize = 14 }, "Accent", true)
Text(TopBar, { Text = "v" .. VERSION, Size = UDim2.new(0, 60, 1, 0), Position = UDim2.fromOffset(112, 1), TextSize = 10 }, "SubText")

local AccentLine = New("Frame", {
	Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1),
}, TopBar)
local AccentGrad = New("UIGradient", {}, AccentLine)
AddRefresher(function()
	AccentGrad.Color = ColorSequence.new(Theme.Accent, Theme.Accent2)
end)

local function TopButton(iconName, xOffset)
	local b = New("ImageButton", {
		BackgroundTransparency = 1, Image = Icon(iconName), Size = UDim2.fromOffset(16, 16),
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOffset, 0.5, 0),
	}, TopBar)
	Bind(b, { ImageColor3 = "SubText" })
	Connect(b.MouseEnter, function() Tween(b, { ImageColor3 = Theme.Accent }, 0.15) end)
	Connect(b.MouseLeave, function() Tween(b, { ImageColor3 = Theme.SubText }, 0.15) end)
	return b
end
local CloseBtn = TopButton("x", -14)
local MinBtn = TopButton("minus", -42)

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
	Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), ZIndex = 4,
}, Main)

local Sidebar = New("Frame", { Name = "Sidebar", Size = UDim2.new(0, 150, 1, 0), BackgroundTransparency = 0.2, BorderSizePixel = 0 }, Body)
Bind(Sidebar, { BackgroundColor3 = "Surface" })
local Divider = New("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BorderSizePixel = 0 }, Sidebar)
Bind(Divider, { BackgroundColor3 = "Stroke" })
local SidebarInner = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, Sidebar)
Pad(SidebarInner, 8)
local TabList = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -44) }, SidebarInner)
List(TabList, 4)
local Footer = New("Frame", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
}, SidebarInner)
List(Footer, 4)

local Content = New("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(150, 0), Size = UDim2.new(1, -150, 1, 0) }, Body)

--// Open / close (X button and toggle key hide the UI, they do not unload it)
local function SetOpen(open)
	if State.Open == open then
		return
	end
	State.Open = open
	local s = Config.Scale / 100
	if open then
		Gui.Enabled = true
		UIScaleObj.Scale = s * 0.93
		Tween(UIScaleObj, { Scale = s }, 0.22, Enum.EasingStyle.Quint)
	else
		Tween(UIScaleObj, { Scale = s * 0.93 }, 0.14, Enum.EasingStyle.Quint)
		task.delay(0.15, function()
			if not State.Open then
				Gui.Enabled = false
			end
		end)
	end
end

local Destroy
Connect(MinBtn.MouseButton1Click, function()
	State.Minimized = not State.Minimized
	if State.Minimized then
		Body.Visible = false
		Tween(Window, { Size = UDim2.fromOffset(640, 40) }, 0.2)
	else
		Tween(Window, { Size = UDim2.fromOffset(640, 420) }, 0.2)
		task.delay(0.15, function()
			if not State.Minimized then
				Body.Visible = true
			end
		end)
	end
	UpdateRain()
end)
Connect(CloseBtn.MouseButton1Click, function()
	SetOpen(false)
end)

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

local function CreateTab(name, iconName, bottom)
	local tab = setmetatable({ Name = name, _order = 0 }, Tab)

	local btn = New("TextButton", {
		Name = name, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "",
		AutoButtonColor = false, LayoutOrder = #Tabs + 1, BorderSizePixel = 0,
	}, bottom and Footer or TabList)
	local tstroke = New("UIStroke", { Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, btn)
	local bar = New("Frame", { Size = UDim2.new(0, 2, 1, 0), BorderSizePixel = 0, BackgroundTransparency = 1 }, btn)
	local ico = New("ImageLabel", { BackgroundTransparency = 1, Image = Icon(iconName), Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 12, 0.5, -9) }, btn)
	local lbl = New("TextLabel", {
		BackgroundTransparency = 1, Text = name, Size = UDim2.new(1, -42, 1, 0), Position = UDim2.fromOffset(38, 0),
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
	}, btn)
	Bind(lbl, { Font = "FontBold" })

	local page = New("ScrollingFrame", {
		Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, Content)
	Bind(page, { ScrollBarImageColor3 = "Accent" })
	Pad(page, 12)
	List(page, 10)
	tab.Page = page

	AddRefresher(function(instant)
		local active = CurrentTab == tab
		Set(btn, { BackgroundTransparency = active and 0.2 or 1, BackgroundColor3 = Theme.Surface2 }, instant)
		Set(bar, { BackgroundTransparency = active and 0 or 1, BackgroundColor3 = Theme.Accent }, instant)
		Set(tstroke, { Transparency = active and 0.6 or 1, Color = Theme.Accent }, instant)
		Set(ico, { ImageColor3 = active and Theme.Accent or Theme.SubText }, instant)
		Set(lbl, { TextColor3 = active and Theme.Text or Theme.SubText }, instant)
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
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 0.2,
		BorderSizePixel = 0, LayoutOrder = self._order,
	}, self.Page)
	Bind(frame, { BackgroundColor3 = "Surface" })
	Stroke(frame, "Accent", 0.72) -- soft glow stroke
	Pad(frame, 10)
	List(frame, 8)

	local header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0 }, frame)
	local textX = 0
	if iconName then
		Img(header, iconName, 14, UDim2.new(0, 0, 0.5, -7), "Accent")
		textX = 22
	end
	Text(header, { Text = string.upper(title), Size = UDim2.new(1, -textX, 1, 0), Position = UDim2.fromOffset(textX, 0), TextSize = 12 }, "Accent", true)

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
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(38, 18),
			Text = "", AutoButtonColor = false, BorderSizePixel = 0,
		}, row)
		local swStroke = New("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, sw)
		local knob = New("Frame", { Size = UDim2.fromOffset(12, 12), BorderSizePixel = 0 }, sw)
		local state = default and true or false
		AddRefresher(function(instant)
			Set(sw, { BackgroundColor3 = state and Theme.Accent or Theme.Surface2 }, instant)
			Set(swStroke, { Color = state and Theme.Accent or Theme.Stroke }, instant)
			Set(knob, {
				Position = state and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6),
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
		Stroke(track, "Stroke", 0.4)
		local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, track)
		Bind(fill, { BackgroundColor3 = "Accent" })
		local knob = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(6, 14), BorderSizePixel = 0 }, track)
		Bind(knob, { BackgroundColor3 = "Text" })
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
local Sound = New("Sound", { Name = "LiminalHub_Music", Looped = true, Volume = 0.5 }, SoundService)
local Music = { Playing = false, Ready = false }

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

Music.Load()

--// Pages
local Home = CreateTab("Home", "house")
local Settings = CreateTab("Settings", "settings", true)

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
	welcome:Label("Executor: " .. exec .. "\nPlace ID: " .. game.PlaceId .. "\nPress " .. Config.ToggleKey .. " to show or hide the UI.")

	local quick = Home:Section("Quick Actions", "sliders-horizontal")
	quick:Button("Open Settings", function()
		SelectTab(Settings)
	end)
	quick:Button("Rejoin Server", function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end)
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
	general:Button("Unload Liminal Hub", function()
		Destroy()
	end)
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
	UpdateRain()
	UpdateBackground()
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
		local stroke = New("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = t.Stroke }, card)
		New("TextLabel", {
			BackgroundTransparency = 1, Text = string.upper(name), Font = t.FontBold, TextSize = 11, TextColor3 = t.Text,
			TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 16),
		}, card)
		for s, col in ipairs({ t.Accent, t.Accent2, t.Surface2 }) do
			New("Frame", { Size = UDim2.fromOffset(14, 6), Position = UDim2.new(0, 10 + (s - 1) * 20, 1, -18), BackgroundColor3 = col, BorderSizePixel = 0 }, card)
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

	themes:Label("Watch Dogs supports a custom background. Put Background.png (or .jpg) in Workspace/LiminalHub/ and press reload.")
	themes:Slider("Background Dim", 0, 95, Config.BgDim, function(v)
		Config.BgDim = v
		UpdateBackground()
		Save()
	end, "%")
	themes:Button("Reload Background", LoadBackground)
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
	Stroke(track, "Stroke", 0.4)
	local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, track)
	Bind(fill, { BackgroundColor3 = "Accent" })

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
	Stroke(playBtn, "Accent", 0.4)
	local playIcon = New("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(7, 7) }, playBtn)
	Bind(playIcon, { ImageColor3 = "OnAccent" })

	-- Loop indicator (always on)
	Img(pc, "repeat", 16, UDim2.fromOffset(42, 82), "Accent")
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
		if Music.Load() and was then
			Music.SetPlaying(true)
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
			status.Text = "Put a file at Workspace/" .. PATHS.Track
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
if Config.Autoplay then
	Music.SetPlaying(true)
	RefreshAll(true)
end