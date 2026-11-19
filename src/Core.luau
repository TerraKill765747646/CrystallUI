local Import = ...
local Theme = Import("src/ThemeEngine")
local Animator = Theme.Animator

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local Core = { Theme = Theme, Animator = Animator, UIS = UserInputService }
local Library = { Flags = {}, Windows = {}, Theme = Theme, Version = "1.0.0" }
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
		if element.Get then
			local ok, value = pcall(element.Get, element)
			if ok then
				data[flag] = value
			end
		end
	end
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
	for flag, value in data do
		local element = self.Flags[flag]
		if element and element.Set then
			pcall(element.Set, element, value)
		end
	end
	return true
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

function Library:CreateWindow(o)
	o = o or {}
	if o.Theme then
		Theme:SetTheme(o.Theme)
	end
	local New = Core.New
	local size = o.Size or UDim2.fromOffset(560, 380)
	local win = setmetatable({
		Tabs = {},
		Maid = Maid.new(),
		Visible = true,
		Minimized = false,
		ToggleKey = Core.ToKey(o.ToggleKey) or Enum.KeyCode.RightShift,
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
	Core.Text({
		Text = o.Name or "Crystall UI",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Position = UDim2.fromOffset(16, hasSub and 6 or 0),
		Size = UDim2.new(1, -110, 0, hasSub and 18 or 42),
		Parent = top,
	})
	if hasSub then
		Core.Text({
			Text = o.Subtitle,
			TextSize = 12,
			Position = UDim2.fromOffset(16, 23),
			Size = UDim2.new(1, -110, 0, 14),
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
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
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
	local y = button.AbsolutePosition.Y - self.Sidebar.AbsolutePosition.Y + (button.AbsoluteSize.Y - 18) / 2
	local position = UDim2.fromOffset(4, y)
	if animate then
		Animator:Tween(indicator, { Position = position })
	else
		indicator.Position = position
	end
	Animator:Tween(indicator, { BackgroundTransparency = 0 }, "Fast")
end

function Window:Toggle(state)
	if state == nil then
		state = not self.Visible
	end
	if state == self.Visible then
		return
	end
	self.Visible = state
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

function Window:CreateTab(name, icon)
	local New = Core.New
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
	Core.Text({
		Text = string.upper(name),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		Size = UDim2.new(1, -24, 1, 0),
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

function Section:SetCollapsed(state)
	self.Collapsed = state == true
	if self._apply then
		self._apply()
	end
end

function Section:Destroy()
	self.Frame:Destroy()
end

function Library:Destroy()
	for i = #self.Windows, 1, -1 do
		self.Windows[i]:Destroy()
	end
	self.Maid:Clean()
	Theme:Clear()
	table.clear(self.Flags)
end

return Core