local Import = ...
local Theme = Import("src/ThemeEngine")
local Animator = Theme.Animator

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local Core = { Theme = Theme, Animator = Animator, UIS = UserInputService }
local Library = { Flags = {}, Windows = {}, Modals = {}, Theme = Theme, Version = "1.1.0" }
Core.Library = Library

local Maid = {}
Maid.__index = Maid
Core.Maid = Maid

function Maid.new()
	return setmetatable({ Tasks = {} }, Maid)
end

function Maid:Give(item)
	table.insert(self.Tasks, item)
	return item
end

function Maid:Remove(item)
	local index = table.find(self.Tasks, item)
	if index then
		table.remove(self.Tasks, index)
	end
end

function Maid:Clean()
	local tasks = self.Tasks
	self.Tasks = {}
	for i = #tasks, 1, -1 do
		local t = tasks[i]
		local kind = typeof(t)
		if kind == "RBXScriptConnection" then
			t:Disconnect()
		elseif kind == "Instance" then
			if t:IsA("Tween") then
				t:Cancel()
			else
				t:Destroy()
			end
		elseif kind == "function" then
			pcall(t)
		elseif kind == "thread" then
			pcall(task.cancel, t)
		elseif kind == "table" then
			if t.Destroy then
				pcall(t.Destroy, t)
			elseif t.Disconnect then
				pcall(t.Disconnect, t)
			end
		end
	end
end

Library.Maid = Maid.new()

local order = 0
function Core.NextOrder()
	order += 1
	return order
end

function Core.New(class, props, children)
	local inst = Instance.new(class)
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end
	local parent, theme
	for k, v in props or {} do
		if k == "Parent" then
			parent = v
		elseif k == "Theme" then
			theme = v
		else
			inst[k] = v
		end
	end
	if theme then
		Theme:Bind(inst, theme)
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

function Core.Text(props)
	local base = {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Theme = { TextColor3 = "Text" },
	}
	for k, v in props do
		base[k] = v
	end
	return Core.New("TextLabel", base)
end

function Core.Corner(parent, radius)
	return Core.New("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = parent })
end

function Core.Stroke(parent, key, thickness)
	return Core.New("UIStroke", {
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Theme = { Color = key or "Stroke" },
		Parent = parent,
	})
end

function Core.Padding(parent, t, r, b, l)
	r = r or t
	b = b or t
	l = l or r
	return Core.New("UIPadding", {
		PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, b),
		PaddingLeft = UDim.new(0, l),
		Parent = parent,
	})
end

function Core.List(parent, padding, direction)
	return Core.New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding or 6),
		FillDirection = direction or Enum.FillDirection.Vertical,
		Parent = parent,
	})
end

function Core.Tween(inst, props, speed, style)
	return Animator:Tween(inst, props, speed, style)
end

function Core.Fire(callback, ...)
	if type(callback) ~= "function" then
		return
	end
	task.spawn(function(...)
		local ok, err = pcall(callback, ...)
		if not ok then
			warn("[CrystallUI] Callback error: " .. tostring(err))
		end
	end, ...)
end

function Core.ToKey(key)
	if typeof(key) == "EnumItem" then
		return key
	end
	if type(key) == "string" and key ~= "None" then
		local ok, result = pcall(function()
			return Enum.KeyCode[key]
		end)
		if ok then
			return result
		end
	end
	return nil
end

function Core.GetGuiParent()
	local ok, hui = pcall(function()
		return gethui and gethui()
	end)
	if ok and typeof(hui) == "Instance" then
		return hui
	end
	local coreOk = pcall(function()
		local probe = Instance.new("Folder")
		probe.Parent = CoreGui
		probe:Destroy()
	end)
	if coreOk then
		return CoreGui
	end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

function Core.CreateGui(name, displayOrder)
	local gui = Core.New("ScreenGui", {
		Name = name .. "_" .. HttpService:GenerateGUID(false):sub(1, 8),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 100,
	})
	pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(gui)
		end
	end)
	gui.Parent = Core.GetGuiParent()
	return gui
end

function Core.RegisterFlag(flag, element)
	if flag then
		if Library.Flags[flag] and Library.Flags[flag] ~= element then
			warn("[CrystallUI] Flag '" .. tostring(flag) .. "' is already registered, the old element is replaced")
		end
		Library.Flags[flag] = element
	end
end

function Library:GetFlag(flag)
	local element = self.Flags[flag]
	return element and element.Get and element:Get()
end

function Library:ExportConfig(asTable)
	local data = {}
	for flag, element in self.Flags do
		local getter = element.Export or element.Get
		if getter then
			local ok, value = pcall(getter, element)
			if ok then
				data[flag] = value
			end
		end
	end
	data.__theme = { Palette = Theme.PaletteName, Motion = Theme.MotionName }
	return if asTable then data else HttpService:JSONEncode(data)
end

function Library:ImportConfig(data)
	if type(data) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, data)
		if not ok then
			return false, "Invalid JSON"
		end
		data = decoded
	end
	if type(data) ~= "table" then
		return false, "Invalid config"
	end
	-- the theme goes first so elements that are recoloured by Set pick up the right palette
	if type(data.__theme) == "table" then
		pcall(Theme.SetTheme, Theme, { Palette = data.__theme.Palette, Motion = data.__theme.Motion })
	end
	for flag, value in data do
		local element = self.Flags[flag]
		if flag ~= "__theme" and element and element.Set then
			pcall(element.Set, element, value)
		end
	end
	return true
end

----------------------------------------------------------------------------------------------------
-- Helpers shared by dialogs, the key system and controls
----------------------------------------------------------------------------------------------------

-- Yields the calling thread until `resolve(...)` is called, returns what it was called with.
-- Works even if resolve fires before the yield (synchronously).
function Core.Await(start)
	local thread = coroutine.running()
	local done, result, waiting = false, nil, false
	start(function(...)
		if done then
			return
		end
		done, result = true, table.pack(...)
		if waiting then
			task.spawn(thread, ...)
		end
	end)
	if done then
		return table.unpack(result, 1, result.n)
	end
	waiting = true
	return coroutine.yield()
end

function Core.Button(parent, text, style, props)
	local bg, fg = "Elevated", "Text"
	if style == "Primary" then
		bg, fg = "Accent", "AccentText"
	elseif style == "Danger" then
		bg, fg = "Error", "AccentText"
	end
	local button = Core.New("TextButton", {
		Text = text,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 36),
		Theme = { BackgroundColor3 = bg, TextColor3 = fg },
		Parent = parent,
	})
	Core.Corner(button, 8)
	button.MouseEnter:Connect(function()
		Animator:Tween(button, { BackgroundTransparency = 0.15 }, "Fast")
	end)
	button.MouseLeave:Connect(function()
		Animator:Tween(button, { BackgroundTransparency = 0 }, "Fast")
	end)
	for k, v in props or {} do
		button[k] = v
	end
	return button
end

-- Centered card over a dimmed screen. Content goes into modal.Body.
function Core.CreateModal(o)
	o = o or {}
	local New = Core.New
	local maid = Maid.new()
	local modal = { Maid = maid, Closed = false, OnClose = o.OnClose }

	local gui = maid:Give(Core.CreateGui("CrystallUI_Modal", 150))
	local dim = New("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Theme = { BackgroundColor3 = "Background" },
		Parent = gui,
	})
	local card = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(o.Width or 340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Theme = { BackgroundColor3 = "Surface" },
		Parent = dim,
	})
	Core.Corner(card, 12)
	Core.Stroke(card)
	local scale = New("UIScale", { Parent = card })

	local inner = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card,
	})
	Core.Padding(inner, 24, 22, 22, 22)
	local list = Core.List(inner, 12)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local badge = New("Frame", {
		Size = UDim2.fromOffset(48, 48),
		LayoutOrder = 1,
		Theme = { BackgroundColor3 = "Elevated" },
		Parent = inner,
	})
	Core.Corner(badge, 24)
	Core.Stroke(badge, "Accent", 2)
	Core.Text({
		Text = o.Icon or "◆",
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Theme = { TextColor3 = "Accent" },
		Parent = badge,
	})
	Core.Text({
		Text = o.Title or "",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = inner,
	})
	if o.Subtitle and o.Subtitle ~= "" then
		Core.Text({
			Text = o.Subtitle,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 3,
			Theme = { TextColor3 = "SubText" },
			Parent = inner,
		})
	end
	local body = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = inner,
	})
	Core.List(body, 10)

	if o.Closable ~= false then
		local close = New("TextButton", {
			Text = "×",
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.fromOffset(24, 24),
			ZIndex = 3,
			Theme = { TextColor3 = "SubText" },
			Parent = card,
		})
		maid:Give(close.MouseButton1Click:Connect(function()
			modal:Close()
		end))
	end

	modal.Gui, modal.Card, modal.Body, modal.Dim = gui, card, body, dim
	Library.Modals[modal] = true

	scale.Scale = Theme.Motion.Scale
	Animator:Tween(scale, { Scale = 1 })
	Animator:Tween(dim, { BackgroundTransparency = 0.4 })

	function modal:Close()
		if self.Closed then
			return
		end
		self.Closed = true
		Library.Modals[self] = nil
		Animator:Tween(dim, { BackgroundTransparency = 1 }, "Fast")
		local out = Animator:Tween(scale, { Scale = Theme.Motion.Scale }, "Fast", Enum.EasingStyle.Quad)
		out.Completed:Once(function()
			maid:Clean()
		end)
		Core.Fire(self.OnClose)
	end

	function modal:Shake()
		task.spawn(function()
			for _, dx in { 10, -10, 6, -6, 0 } do
				if self.Closed then
					return
				end
				Animator:Tween(card, { Position = UDim2.new(0.5, dx, 0.5, 0) }, 0.05, Enum.EasingStyle.Quad)
				task.wait(0.05)
			end
		end)
	end

	return modal
end

-- Library:Dialog({ Title, Content, Icon, Width, Closable, OnClose, Buttons = { { Name, Callback, Style, Keep } } })
function Library:Dialog(o)
	o = o or {}
	local modal = Core.CreateModal({
		Title = o.Title or "Notice",
		Subtitle = o.Content,
		Icon = o.Icon,
		Width = o.Width,
		Closable = o.Closable,
		OnClose = o.OnClose,
	})
	local buttons = o.Buttons
	if type(buttons) ~= "table" or #buttons == 0 then
		buttons = { { Name = "OK" } }
	end
	local count = #buttons
	local row = Core.New("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = 100, Parent = modal.Body })
	Core.List(row, 8, Enum.FillDirection.Horizontal)
	for i, spec in buttons do
		local style = spec.Style or (if i == count then "Primary" else "Default")
		local button = Core.Button(row, spec.Name or "OK", style, {
			Size = UDim2.new(1 / count, -8 * (count - 1) / count, 1, 0),
			LayoutOrder = i,
		})
		button.MouseButton1Click:Connect(function()
			Core.Fire(spec.Callback)
			if not spec.Keep then
				modal:Close()
			end
		end)
	end
	return modal
end

-- Blocking yes/no prompt, returns true or false. Must be called from a thread that may yield.
function Library:Confirm(o)
	o = o or {}
	return Core.Await(function(resolve)
		self:Dialog({
			Title = o.Title or "Are you sure?",
			Content = o.Content,
			Icon = o.Icon,
			OnClose = function()
				resolve(false)
			end,
			Buttons = {
				{ Name = o.No or "Cancel", Callback = function() resolve(false) end },
				{ Name = o.Yes or "Confirm", Style = if o.Danger then "Danger" else "Primary", Callback = function() resolve(true) end },
			},
		})
	end)
end

local CONFIG_DIR = "CrystallUI/configs"

local function ConfigPath(name)
	name = tostring(name or "default"):gsub("[^%w_%-]", "_")
	return CONFIG_DIR .. "/" .. name .. ".json"
end

function Library:SaveConfig(name)
	if not (writefile and makefolder and isfolder) then
		return false, "File API is not available in this environment"
	end
	local ok, err = pcall(function()
		if not isfolder("CrystallUI") then
			makefolder("CrystallUI")
		end
		if not isfolder(CONFIG_DIR) then
			makefolder(CONFIG_DIR)
		end
		writefile(ConfigPath(name), self:ExportConfig())
	end)
	return ok, if ok then nil else tostring(err)
end

function Library:LoadConfig(name)
	if not (readfile and isfile) then
		return false, "File API is not available in this environment"
	end
	local path = ConfigPath(name)
	if not isfile(path) then
		return false, "Config not found: " .. path
	end
	local ok, data = pcall(readfile, path)
	if not ok then
		return false, tostring(data)
	end
	return self:ImportConfig(data)
end

function Library:ListConfigs()
	local out = {}
	if listfiles and isfolder and isfolder(CONFIG_DIR) then
		for _, path in listfiles(CONFIG_DIR) do
			local name = tostring(path):match("([^/\\]+)%.json$")
			if name then
				table.insert(out, name)
			end
		end
	end
	table.sort(out)
	return out
end

local Elements = {}
Core.Elements = Elements

local Window = {}
Window.__index = Window
local Tab = setmetatable({}, { __index = Elements })
Tab.__index = Tab
local Section = setmetatable({}, { __index = Elements })
Section.__index = Section
Core.Window, Core.Tab, Core.Section = Window, Tab, Section

local function IsPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end
Core.IsPointer = IsPointer

-- Floating round button that shows/hides the window. Built for touch devices where there is no
-- toggle key: tap toggles, drag moves it, on release it snaps to the nearest screen edge.
local DRAG_THRESHOLD = 8

local function BuildToggleButton(win, o)
	local setting = o.MobileButton
	if setting == nil then
		setting = UserInputService.TouchEnabled
	end
	if not setting then
		return
	end

	local gui, maid = win.Gui, win.Maid
	local size, margin = 46, 12
	local side, curY, snap = "left", nil, nil

	local button = Core.New("TextButton", {
		Name = "ToggleButton",
		Text = o.ToggleIcon or "◆",
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		AutoButtonColor = false,
		Position = UDim2.new(0, margin, 0.4, 0),
		Size = UDim2.fromOffset(size, size),
		ZIndex = 20,
		Theme = { BackgroundColor3 = "Surface", TextColor3 = "Accent" },
		Parent = gui,
	})
	Core.Corner(button, size / 2)
	Core.Stroke(button, "Accent", 2)
	local scale = Core.New("UIScale", { Parent = button })
	win.ToggleButton = button

	local function EdgeX()
		return if side == "left" then margin else math.max(margin, gui.AbsoluteSize.X - size - margin)
	end
	local function ClampY(y)
		return math.clamp(y, margin, math.max(margin, gui.AbsoluteSize.Y - size - margin))
	end

	local dragging, moved, startInput, startX, startY, curX = false, false, nil, 0, 0, 0
	maid:Give(button.InputBegan:Connect(function(input)
		if not IsPointer(input) or dragging then
			return
		end
		if snap then
			snap:Cancel()
			snap = nil
		end
		local abs = button.AbsolutePosition
		dragging, moved, startInput, startX, startY = true, false, input.Position, abs.X, abs.Y
		curX, curY = abs.X, abs.Y
		Animator:Tween(scale, { Scale = 0.9 }, "Fast")
	end))
	maid:Give(UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - startInput
		if not moved then
			if math.sqrt(delta.X ^ 2 + delta.Y ^ 2) < DRAG_THRESHOLD then
				return
			end
			moved = true
			Animator:Tween(scale, { Scale = 1.1 }, "Fast")
		end
		local view = gui.AbsoluteSize
		curX = math.clamp(startX + delta.X, margin, math.max(margin, view.X - size - margin))
		curY = ClampY(startY + delta.Y)
		button.Position = UDim2.fromOffset(curX, curY)
	end))
	maid:Give(UserInputService.InputEnded:Connect(function(input)
		if not dragging or not IsPointer(input) then
			return
		end
		dragging = false
		Animator:Tween(scale, { Scale = 1 }, "Fast")
		if not moved then
			win:Toggle()
			return
		end
		side = if curX + size / 2 < gui.AbsoluteSize.X / 2 then "left" else "right"
		snap = Animator:Tween(button, { Position = UDim2.fromOffset(EdgeX(), curY) })
	end))
	-- keep it reachable when the viewport changes (rotation, window resize)
	maid:Give(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if curY then
			if snap then
				snap:Cancel()
				snap = nil
			end
			curY = ClampY(curY)
			button.Position = UDim2.fromOffset(EdgeX(), curY)
		end
	end))

	win:_UpdateToggleButton()
end

function Library:CreateWindow(o)
	o = o or {}
	if o.Theme then
		Theme:SetTheme(o.Theme)
	end
	local New = Core.New
	local size = o.Size or UDim2.fromOffset(560, 380)
	local win = setmetatable({
		Tabs = {},
		Popups = {},
		Maid = Maid.new(),
		Visible = true,
		Minimized = false,
		ToggleKey = if o.ToggleKey == false then nil else (Core.ToKey(o.ToggleKey) or Enum.KeyCode.RightShift),
		Size = size,
	}, Window)
	local maid = win.Maid

	local gui = maid:Give(Core.CreateGui("CrystallUI"))
	local main = New("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		ClipsDescendants = true,
		Theme = { BackgroundColor3 = "Background" },
		Parent = gui,
	})
	Core.Corner(main, 10)
	Core.Stroke(main)
	local scale = New("UIScale", { Parent = main })

	local top = New("Frame", { Name = "TopBar", Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Parent = main })
	local hasSub = o.Subtitle ~= nil
	local icon = if o.Icon == false then nil else (o.Icon or "◆")
	local textX = if icon then 38 else 16
	if icon then
		Core.Text({
			Text = icon,
			Font = Enum.Font.GothamBold,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.fromOffset(22, 42),
			Theme = { TextColor3 = "Accent" },
			Parent = top,
		})
	end
	Core.Text({
		Text = o.Name or "Crystall UI",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Position = UDim2.fromOffset(textX, hasSub and 6 or 0),
		Size = UDim2.new(1, -(textX + 94), 0, hasSub and 18 or 42),
		Parent = top,
	})
	if hasSub then
		Core.Text({
			Text = o.Subtitle,
			TextSize = 12,
			Position = UDim2.fromOffset(textX, 23),
			Size = UDim2.new(1, -(textX + 94), 0, 14),
			Theme = { TextColor3 = "SubText" },
			Parent = top,
		})
	end

	local function TopButton(text, x)
		local button = New("TextButton", {
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, x, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			Theme = { BackgroundColor3 = "Elevated", TextColor3 = "SubText" },
			Parent = top,
		})
		Core.Corner(button, 6)
		return button
	end
	local closeButton = TopButton("×", -10)
	local minButton = TopButton("–", -42)
	New("Frame", { Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 1), Theme = { BackgroundColor3 = "Stroke" }, Parent = main })
	-- accent line that fades into the divider
	local glow = New("Frame", {
		Position = UDim2.fromOffset(0, 41),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 2,
		Parent = main,
	})
	New("UIGradient", {
		Theme = {
			Color = function(p)
				return ColorSequence.new(p.Accent, p.Stroke)
			end,
		},
		Parent = glow,
	})

	local body = New("Frame", { Name = "Body", Position = UDim2.fromOffset(0, 43), Size = UDim2.new(1, 0, 1, -43), BackgroundTransparency = 1, Parent = main })
	local sidebar = New("Frame", { Size = UDim2.new(0, 160, 1, 0), Theme = { BackgroundColor3 = "Surface" }, Parent = body })

	local searchHeight = if o.Search == false then 0 else 38
	local search
	if searchHeight > 0 then
		search = New("TextBox", {
			Text = "",
			PlaceholderText = "Search tabs...",
			ClearTextOnFocus = false,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 0, 26),
			Theme = { BackgroundColor3 = "Elevated", TextColor3 = "Text", PlaceholderColor3 = "SubText" },
			Parent = sidebar,
		})
		Core.Corner(search, 6)
		Core.Padding(search, 0, 8, 0, 8)
	end

	local tabList = New("ScrollingFrame", {
		Position = UDim2.fromOffset(0, searchHeight + 4),
		Size = UDim2.new(1, 0, 1, -(searchHeight + 8)),
		BackgroundTransparency = 1,
		ScrollBarThickness = 2,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Theme = { ScrollBarImageColor3 = "Accent" },
		Parent = sidebar,
	})
	Core.List(tabList, 4)
	Core.Padding(tabList, 4, 8, 4, 8)

	local indicator = New("Frame", {
		Size = UDim2.fromOffset(3, 18),
		Position = UDim2.fromOffset(4, 0),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Theme = { BackgroundColor3 = "Accent" },
		Parent = sidebar,
	})
	Core.Corner(indicator, 2)

	local content = New("Frame", {
		Position = UDim2.fromOffset(160, 0),
		Size = UDim2.new(1, -160, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = body,
	})

	win.Gui, win.Main, win.Scale, win.Body = gui, main, scale, body
	win.Sidebar, win.TabList, win.Indicator, win.Content = sidebar, tabList, indicator, content
	win.MinButton = minButton
	BuildToggleButton(win, o)

	maid:Give(tabList:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		win:_UpdateIndicator(false)
	end))

	if search then
		maid:Give(search:GetPropertyChangedSignal("Text"):Connect(function()
			local query = search.Text:lower()
			for _, tab in win.Tabs do
				tab.Button.Visible = query == "" or tab.Name:lower():find(query, 1, true) ~= nil
			end
			task.defer(win._UpdateIndicator, win, true)
		end))
	end

	local dragging, dragStart, startPos = false, nil, nil
	maid:Give(top.InputBegan:Connect(function(input)
		if IsPointer(input) then
			dragging, dragStart, startPos = true, input.Position, main.Position
		end
	end))
	maid:Give(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			local viewport = gui.AbsoluteSize
			local half = main.AbsoluteSize / 2
			local cx = viewport.X * startPos.X.Scale + startPos.X.Offset + delta.X
			local cy = viewport.Y * startPos.Y.Scale + startPos.Y.Offset + delta.Y
			-- keep the title bar reachable: it can't leave the screen
			cx = math.clamp(cx, 40, math.max(40, viewport.X - 40))
			cy = math.clamp(cy, half.Y, math.max(half.Y, viewport.Y - 42 + half.Y))
			local x = cx - viewport.X * startPos.X.Scale
			local y = cy - viewport.Y * startPos.Y.Scale
			main.Position = UDim2.new(startPos.X.Scale, x, startPos.Y.Scale, y)
		end
	end))
	maid:Give(UserInputService.InputEnded:Connect(function(input)
		if IsPointer(input) then
			dragging = false
		end
	end))
	maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and win.ToggleKey and input.KeyCode == win.ToggleKey then
			win:Toggle()
		end
	end))
	maid:Give(minButton.MouseButton1Click:Connect(function()
		win:Minimize()
	end))
	maid:Give(closeButton.MouseButton1Click:Connect(function()
		win:Toggle(false)
	end))

	scale.Scale = Theme.Motion.Scale
	Animator:Tween(scale, { Scale = 1 })

	table.insert(Library.Windows, win)
	return win
end

function Window:_UpdateIndicator(animate)
	local tab, indicator = self.Selected, self.Indicator
	if not tab or not tab.Button.Visible then
		Animator:Tween(indicator, { BackgroundTransparency = 1 }, "Fast")
		return
	end
	local button = tab.Button
	local list = self.TabList
	local top = button.AbsolutePosition.Y
	local bottom = top + button.AbsoluteSize.Y
	if bottom < list.AbsolutePosition.Y or top > list.AbsolutePosition.Y + list.AbsoluteSize.Y then
		Animator:Tween(indicator, { BackgroundTransparency = 1 }, "Fast")
		return
	end
	local y = top - self.Sidebar.AbsolutePosition.Y + (button.AbsoluteSize.Y - 18) / 2
	local position = UDim2.fromOffset(4, y)
	if animate then
		Animator:Tween(indicator, { Position = position })
	else
		indicator.Position = position
	end
	Animator:Tween(indicator, { BackgroundTransparency = 0 }, "Fast")
end

function Window:_UpdateToggleButton()
	local button = self.ToggleButton
	if button then
		-- slightly see-through while the window is open, solid when it is hidden
		Animator:Tween(button, { BackgroundTransparency = if self.Visible then 0.35 else 0 }, "Fast")
	end
end

-- dropdowns and pickers register themselves here so they can be closed together
function Window:_ClosePopups(except)
	for api, close in table.clone(self.Popups) do
		if api ~= except then
			close()
		end
	end
end

function Window:SetMobileButton(state)
	if self.ToggleButton then
		self.ToggleButton.Visible = state == true
	elseif state then
		BuildToggleButton(self, { MobileButton = true })
	end
end

function Window:Toggle(state)
	if state == nil then
		state = not self.Visible
	end
	if state == self.Visible then
		return
	end
	self.Visible = state
	self:_UpdateToggleButton()
	if not state then
		self:_ClosePopups()
	end
	local motion = Theme.Motion
	if state then
		self.Main.Visible = true
		self.Scale.Scale = motion.Scale
		Animator:Tween(self.Scale, { Scale = 1 })
	else
		local tween = Animator:Tween(self.Scale, { Scale = motion.Scale }, "Fast", Enum.EasingStyle.Quad)
		tween.Completed:Once(function(playbackState)
			if not self.Visible and playbackState == Enum.PlaybackState.Completed then
				self.Main.Visible = false
			end
		end)
	end
end

function Window:Minimize(state)
	if state == nil then
		state = not self.Minimized
	end
	self.Minimized = state
	if state then
		self:_ClosePopups()
	end
	self.MinButton.Text = state and "+" or "–"
	local size = self.Size
	Animator:Tween(self.Main, { Size = if state then UDim2.new(size.X.Scale, size.X.Offset, 0, 42) else size })
end

function Window:SetToggleKey(key)
	self.ToggleKey = Core.ToKey(key)
end

function Window:Destroy()
	self.Maid:Clean()
	local index = table.find(Library.Windows, self)
	if index then
		table.remove(Library.Windows, index)
	end
end

function Window:SelectTab(target)
	if type(target) == "number" then
		target = self.Tabs[target]
	elseif type(target) == "string" then
		local found
		for _, tab in self.Tabs do
			if tab.Name == target then
				found = tab
				break
			end
		end
		target = found
	end
	if target and getmetatable(target) == Tab then
		target:Select()
		return target
	end
	return nil
end

function Window:CreateTab(name, icon)
	local New = Core.New
	name = tostring(name or "Tab")
	local tab = setmetatable({ Name = name, Window = self, Sections = {} }, Tab)
	local button = New("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = #self.Tabs + 1,
		BackgroundTransparency = 1,
		Theme = { BackgroundColor3 = "Elevated" },
		Parent = self.TabList,
	})
	Core.Corner(button, 6)
	local label = Core.Text({
		Text = (icon and (icon .. "  ") or "") .. name,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -16, 1, 0),
		Theme = {
			TextColor3 = function(p)
				return if self.Selected == tab then p.Text else p.SubText
			end,
		},
		Parent = button,
	})
	local page = New("ScrollingFrame", {
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Theme = { ScrollBarImageColor3 = "Accent" },
		Parent = self.Content,
	})
	Core.List(page, 8)
	Core.Padding(page, 12, 14, 12, 12)
	tab.Button, tab.Label, tab.Page, tab.Container = button, label, page, page
	self.Maid:Give(button.MouseButton1Click:Connect(function()
		tab:Select()
	end))
	self.Maid:Give(button.MouseEnter:Connect(function()
		if self.Selected ~= tab then
			Animator:Tween(button, { BackgroundTransparency = 0.6 }, "Fast")
		end
	end))
	self.Maid:Give(button.MouseLeave:Connect(function()
		if self.Selected ~= tab then
			Animator:Tween(button, { BackgroundTransparency = 1 }, "Fast")
		end
	end))
	table.insert(self.Tabs, tab)
	if not self.Selected then
		tab:Select()
	end
	return tab
end

function Tab:Select()
	local win = self.Window
	local previous = win.Selected
	if previous == self then
		return
	end
	win.Selected = self
	win:_ClosePopups()
	if previous then
		previous.Page.Visible = false
		Animator:Tween(previous.Button, { BackgroundTransparency = 1 }, "Fast")
		Theme:Refresh(previous.Label, true)
	end
	Animator:Tween(self.Button, { BackgroundTransparency = 0 }, "Fast")
	Theme:Refresh(self.Label, true)
	self.Page.Visible = true
	self.Page.Position = UDim2.fromOffset(0, Theme.Motion.Offset)
	Animator:Tween(self.Page, { Position = UDim2.new() })
	task.defer(win._UpdateIndicator, win, previous ~= nil)
end

function Tab:CreateSection(name, o)
	o = o or {}
	name = tostring(name or "")
	local New = Core.New
	local section = setmetatable({ Name = name, Tab = self, Window = self.Window, Collapsed = false }, Section)
	local frame = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = Core.NextOrder(),
		Parent = self.Page,
	})
	Core.List(frame, 6)
	local header = New("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Parent = frame,
	})
	New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(3, 11),
		Theme = { BackgroundColor3 = "Accent" },
		Parent = header,
	})
	section.Title = Core.Text({
		Text = string.upper(name),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -34, 1, 0),
		Theme = { TextColor3 = "SubText" },
		Parent = header,
	})
	local container = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = frame,
	})
	Core.List(container, 6)
	section.Frame, section.Header, section.Container = frame, header, container

	if o.Collapsible then
		local chevron = Core.Text({
			Text = "▾",
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -2, 0, 0),
			Size = UDim2.new(0, 20, 1, 0),
			Theme = { TextColor3 = "SubText" },
			Parent = header,
		})
		section._apply = function()
			container.Visible = not section.Collapsed
			Animator:Tween(chevron, { Rotation = section.Collapsed and -90 or 0 }, "Fast")
		end
		self.Window.Maid:Give(header.MouseButton1Click:Connect(function()
			section:SetCollapsed(not section.Collapsed)
		end))
		if o.Collapsed then
			section:SetCollapsed(true)
		end
	end

	table.insert(self.Sections, section)
	return section
end

function Section:SetTitle(text)
	self.Title.Text = string.upper(tostring(text))
end

function Section:SetCollapsed(state)
	self.Collapsed = state == true
	if self._apply then
		self._apply()
	end
end

function Section:Destroy()
	local index = table.find(self.Tab.Sections, self)
	if index then
		table.remove(self.Tab.Sections, index)
	end
	self.Frame:Destroy()
end

function Library:Destroy()
	for i = #self.Windows, 1, -1 do
		self.Windows[i]:Destroy()
	end
	for modal in table.clone(self.Modals) do
		modal.OnClose = nil
		modal:Close()
		modal.Maid:Clean()
	end
	self.Maid:Clean()
	Theme:Clear()
	table.clear(self.Flags)
end

return Core