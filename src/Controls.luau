local Import = ...
local Core = Import("src/Core")
local Theme, Animator, New, UIS = Core.Theme, Core.Animator, Core.New, Core.UIS
local Elements = Core.Elements
local Fire = Core.Fire

local function Row(self, o, height)
	height = height or 38
	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = Core.NextOrder(),
		Theme = { BackgroundColor3 = "Surface" },
		Parent = self.Container,
	})
	Core.Corner(row, 6)
	local stroke = Core.Stroke(row)
	local title = Core.Text({
		Text = o.Name or "",
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 0, height),
		Parent = row,
	})
	return row, title, stroke
end

local function Element(self, row, title, o, api)
	api = api or {}
	api.Instance, api.Flag = row, o.Flag
	local maid = Core.Maid.new()
	api.Maid = maid
	function api:SetTitle(text)
		if title then
			title.Text = tostring(text)
		end
	end
	function api:SetVisible(state)
		row.Visible = state
	end
	function api:Destroy()
		maid:Clean()
		row:Destroy()
		if self.Flag and Core.Library.Flags[self.Flag] == self then
			Core.Library.Flags[self.Flag] = nil
		end
	end
	Core.RegisterFlag(o.Flag, api)
	self.Window.Maid:Give(api)
	return api, maid
end

local function Hit(row, height)
	return New("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = if height then UDim2.new(1, 0, 0, height) else UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = row,
	})
end

local function Hover(maid, target, row)
	maid:Give(target.MouseEnter:Connect(function()
		Animator:Tween(row, { BackgroundColor3 = Theme:Get("Elevated") }, "Fast")
	end))
	maid:Give(target.MouseLeave:Connect(function()
		Animator:Tween(row, { BackgroundColor3 = Theme:Get("Surface") }, "Fast")
	end))
end

local function SmallBox(class, props)
	local base = {
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Theme = { BackgroundColor3 = "Elevated", TextColor3 = "Text" },
	}
	if class == "TextButton" then
		base.AutoButtonColor = false
	else
		base.ClearTextOnFocus = false
		base.Theme.PlaceholderColor3 = "SubText"
	end
	for k, v in props do
		base[k] = v
	end
	local inst = New(class, base)
	Core.Corner(inst, 5)
	return inst
end

function Elements:CreateButton(o)
	o = o or {}
	local row, title, stroke = Row(self, o)
	local api, maid = Element(self, row, title, o)
	local hit = Hit(row)
	Core.Text({
		Text = "›",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0, 20, 1, 0),
		Theme = { TextColor3 = "SubText" },
		Parent = row,
	})
	Hover(maid, hit, row)
	maid:Give(hit.MouseButton1Click:Connect(function()
		Animator:Tween(stroke, { Color = Theme:Get("Accent") }, "Fast")
		task.delay(Theme.Motion.Duration, function()
			if row.Parent then
				Theme:Refresh(stroke, true)
			end
		end)
		Fire(o.Callback)
	end))
	return api
end

function Elements:CreateToggle(o)
	o = o or {}
	local row, title = Row(self, o)
	title.Size = UDim2.new(1, -70, 1, 0)
	local initial = o.CurrentValue
	if initial == nil then
		initial = o.Default
	end
	local api, maid = Element(self, row, title, o, { Value = initial == true })
	local hit = Hit(row)
	local track = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(38, 20),
		Theme = {
			BackgroundColor3 = function(p)
				return if api.Value then p.Accent else p.Elevated
			end,
		},
		Parent = row,
	})
	Core.Corner(track, 10)
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		Theme = {
			BackgroundColor3 = function(p)
				return if api.Value then p.AccentText else p.SubText
			end,
		},
		Parent = track,
	})
	Core.Corner(knob, 7)

	function api:Set(value, silent)
		self.Value = value == true
		Theme:Refresh(track, true)
		Theme:Refresh(knob, true)
		Animator:Tween(knob, { Position = UDim2.new(0, self.Value and 21 or 3, 0.5, 0) })
		if not silent then
			Fire(o.Callback, self.Value)
		end
	end
	function api:Get()
		return self.Value
	end

	Hover(maid, hit, row)
	maid:Give(hit.MouseButton1Click:Connect(function()
		api:Set(not api.Value)
	end))
	api:Set(api.Value, true)
	return api
end

function Elements:CreateChecklist(o)
	o = o or {}
	local options = o.Options or {}
	local row, title = Row(self, o)
	row.Size = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	title.Size = UDim2.new(1, -170, 0, 38)
	local api, maid = Element(self, row, title, o, { Selected = {}, Value = {} })

	local allButton = SmallBox("TextButton", {
		Text = "Select All",
		TextSize = 11,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -74, 0, 9),
		Size = UDim2.fromOffset(64, 20),
		Parent = row,
	})
	local clearButton = SmallBox("TextButton", {
		Text = "Clear",
		TextSize = 11,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 9),
		Size = UDim2.fromOffset(56, 20),
		Parent = row,
	})

	local body = New("Frame", {
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = row,
	})
	Core.List(body, 2)
	Core.Padding(body, 0, 8, 8, 8)

	local boxes = {}
	local function Paint(name)
		local item = boxes[name]
		Theme:Refresh(item.Box, true)
		item.Check.Visible = api.Selected[name] == true
	end

	function api:GetSelected()
		local out = {}
		for _, name in options do
			if self.Selected[name] then
				table.insert(out, name)
			end
		end
		return out
	end
	api.Get = api.GetSelected

	for i, name in options do
		local item = New("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = i,
			Parent = body,
		})
		local box = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 4, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			Theme = {
				BackgroundColor3 = function(p)
					return if api.Selected[name] then p.Accent else p.Elevated
				end,
			},
			Parent = item,
		})
		Core.Corner(box, 4)
		local check = Core.Text({
			Text = "✓",
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			Theme = { TextColor3 = "AccentText" },
			Parent = box,
		})
		Core.Text({
			Text = tostring(name),
			TextSize = 13,
			Position = UDim2.fromOffset(28, 0),
			Size = UDim2.new(1, -32, 1, 0),
			Theme = { TextColor3 = "SubText" },
			Parent = item,
		})
		boxes[name] = { Box = box, Check = check }
		maid:Give(item.MouseButton1Click:Connect(function()
			api.Selected[name] = not api.Selected[name] or nil
			Paint(name)
			api.Value = api:GetSelected()
			Fire(o.Callback, api.Value)
		end))
	end

	function api:Set(list, silent)
		table.clear(self.Selected)
		for _, name in (type(list) == "table" and list or {}) do
			if boxes[name] then
				self.Selected[name] = true
			end
		end
		for name in boxes do
			Paint(name)
		end
		self.Value = self:GetSelected()
		if not silent then
			Fire(o.Callback, self.Value)
		end
	end

	maid:Give(allButton.MouseButton1Click:Connect(function()
		api:Set(options)
	end))
	maid:Give(clearButton.MouseButton1Click:Connect(function()
		api:Set({})
	end))
	api:Set(o.CurrentValue or o.Default or {}, true)
	return api
end

function Elements:CreateSlider(o)
	o = o or {}
	local range = o.Range or { 0, 100 }
	local min, max = range[1], range[2]
	local increment = o.Increment or 1
	local row, title = Row(self, o, 54)
	title.Size = UDim2.new(1, -110, 0, 32)
	local api, maid = Element(self, row, title, o, { Value = min })

	local box = SmallBox("TextBox", {
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 6),
		Size = UDim2.fromOffset(80, 20),
		Parent = row,
	})
	local bar = New("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 0, 6),
		Theme = { BackgroundColor3 = "Elevated" },
		Parent = row,
	})
	Core.Corner(bar, 3)
	local fill = New("Frame", { Size = UDim2.fromScale(0, 1), Theme = { BackgroundColor3 = "Accent" }, Parent = bar })
	Core.Corner(fill, 3)
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(12, 12),
		Theme = { BackgroundColor3 = "Text" },
		Parent = bar,
	})
	Core.Corner(knob, 6)

	local function Display(v)
		return tostring(v) .. (o.Suffix and (" " .. o.Suffix) or "")
	end
	local function Snap(v)
		v = math.clamp(v, min, max)
		v = min + math.floor((v - min) / increment + 0.5) * increment
		return tonumber(string.format("%.4f", math.clamp(v, min, max)))
	end

	function api:Set(value, silent, instant)
		value = tonumber(value)
		if not value then
			box.Text = Display(self.Value)
			return
		end
		value = Snap(value)
		local changed = value ~= self.Value
		self.Value = value
		local alpha = if max > min then (value - min) / (max - min) else 0
		local fillSize, knobPos = UDim2.fromScale(alpha, 1), UDim2.fromScale(alpha, 0.5)
		if instant then
			fill.Size, knob.Position = fillSize, knobPos
		else
			Animator:Tween(fill, { Size = fillSize }, "Fast")
			Animator:Tween(knob, { Position = knobPos }, "Fast")
		end
		box.Text = Display(value)
		if changed and not silent then
			Fire(o.Callback, value)
		end
	end
	function api:Get()
		return self.Value
	end

	local dragging = false
	local function FromX(x)
		local width = math.max(bar.AbsoluteSize.X, 1)
		api:Set(min + (max - min) * math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1), false, true)
	end
	maid:Give(bar.InputBegan:Connect(function(input)
		if Core.IsPointer(input) then
			dragging = true
			FromX(input.Position.X)
		end
	end))
	maid:Give(UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			FromX(input.Position.X)
		end
	end))
	maid:Give(UIS.InputEnded:Connect(function(input)
		if Core.IsPointer(input) then
			dragging = false
		end
	end))
	maid:Give(box.FocusLost:Connect(function()
		api:Set(box.Text:match("%-?[%d%.]+"))
	end))

	api:Set(o.CurrentValue or o.Default or min, true, true)
	box.Text = Display(api.Value)
	return api
end

function Elements:CreateDropdown(o)
	o = o or {}
	local multi = o.MultipleOptions or o.Multi or false
	local options = table.clone(o.Options or {})
	local row, title = Row(self, o)
	row.ClipsDescendants = true
	title.Size = UDim2.new(0.5, -12, 0, 38)
	local api, maid = Element(self, row, title, o, { Open = false })
	local selected, items = {}, {}

	local header = Hit(row, 38)
	local valueLabel = Core.Text({
		Text = "",
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -32, 0, 0),
		Size = UDim2.new(0.5, -32, 0, 38),
		Theme = { TextColor3 = "SubText" },
		Parent = row,
	})
	local chevron = Core.Text({
		Text = "▾",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.fromOffset(20, 38),
		Theme = { TextColor3 = "SubText" },
		Parent = row,
	})

	local searchHeight = o.Search and 30 or 0
	local search
	if o.Search then
		search = SmallBox("TextBox", {
			Text = "",
			PlaceholderText = "Search...",
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(8, 40),
			Size = UDim2.new(1, -16, 0, 24),
			Parent = row,
		})
		Core.Padding(search, 0, 8, 0, 8)
	end

	local list = New("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 40 + searchHeight),
		Size = UDim2.new(1, -16, 0, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 2,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Theme = { ScrollBarImageColor3 = "Accent" },
		Parent = row,
	})
	Core.List(list, 2)

	function api:Get()
		if multi then
			local out = {}
			for _, name in options do
				if selected[name] then
					table.insert(out, name)
				end
			end
			return out
		end
		for _, name in options do
			if selected[name] then
				return name
			end
		end
		return nil
	end

	local function Layout()
		local count = 0
		for _, item in items do
			if item.Visible then
				count += 1
			end
		end
		local listHeight = math.min(count * 28, 168)
		list.Size = UDim2.new(1, -16, 0, listHeight)
		local height = if api.Open then 40 + searchHeight + listHeight + 8 else 38
		Animator:Tween(row, { Size = UDim2.new(1, 0, 0, height) })
		Animator:Tween(chevron, { Rotation = api.Open and 180 or 0 }, "Fast")
	end

	local function Paint()
		for _, item in items do
			Theme:Refresh(item, true)
		end
		local value = api:Get()
		api.Value = value
		if multi then
			valueLabel.Text = if #value == 0 then "None" else table.concat(value, ", ")
		else
			valueLabel.Text = if value == nil then "None" else tostring(value)
		end
	end

	local function Build()
		for _, item in items do
			item:Destroy()
		end
		table.clear(items)
		for i, name in options do
			local item = New("TextButton", {
				Text = tostring(name),
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				Size = UDim2.new(1, -4, 0, 26),
				LayoutOrder = i,
				Theme = {
					BackgroundColor3 = function(p)
						return if selected[name] then p.Elevated else p.Surface
					end,
					TextColor3 = function(p)
						return if selected[name] then p.Accent else p.Text
					end,
				},
				Parent = list,
			})
			Core.Corner(item, 5)
			Core.Padding(item, 0, 8, 0, 8)
			item.MouseButton1Click:Connect(function()
				if multi then
					selected[name] = not selected[name] or nil
				else
					table.clear(selected)
					selected[name] = true
					api.Open = false
					Layout()
				end
				Paint()
				Fire(o.Callback, api:Get())
			end)
			items[name] = item
		end
	end

	local function Filter()
		local query = search and search.Text:lower() or ""
		for name, item in items do
			item.Visible = query == "" or tostring(name):lower():find(query, 1, true) ~= nil
		end
		Layout()
	end

	function api:Set(value, silent)
		table.clear(selected)
		if type(value) == "table" then
			for _, name in value do
				if table.find(options, name) then
					selected[name] = true
					if not multi then
						break
					end
				end
			end
		elseif value ~= nil and table.find(options, value) then
			selected[value] = true
		end
		Paint()
		if not silent then
			Fire(o.Callback, self:Get())
		end
	end

	function api:Refresh(newOptions, keepSelection)
		local previous = self:Get()
		options = table.clone(newOptions or {})
		Build()
		self:Set(if keepSelection then previous else nil, true)
		Filter()
	end

	function api:SetOpen(state)
		self.Open = state == true
		Layout()
	end

	if search then
		maid:Give(search:GetPropertyChangedSignal("Text"):Connect(Filter))
	end
	maid:Give(header.MouseButton1Click:Connect(function()
		api:SetOpen(not api.Open)
	end))
	Hover(maid, header, row)

	Build()
	api:Set(o.CurrentOption or o.Default, true)
	Filter()
	return api
end

function Elements:CreateKeybind(o)
	o = o or {}
	local row, title = Row(self, o)
	title.Size = UDim2.new(1, -120, 1, 0)
	local api, maid = Element(self, row, title, o, { Listening = false, Value = "None" })
	local button = SmallBox("TextButton", {
		Text = "None",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = row,
	})
	Core.Padding(button, 0, 10, 0, 10)

	function api:Set(key, silent)
		self.Key = Core.ToKey(key)
		self.Value = if self.Key then self.Key.Name else "None"
		button.Text = self.Value
		if not silent then
			Fire(o.ChangedCallback, self.Key)
		end
	end
	function api:Get()
		return self.Value
	end

	maid:Give(button.MouseButton1Click:Connect(function()
		api.Listening = true
		button.Text = "..."
		Animator:Tween(button, { TextColor3 = Theme:Get("Accent") }, "Fast")
	end))
	maid:Give(UIS.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if api.Listening then
			api.Listening = false
			Theme:Refresh(button, true)
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
				api:Set(nil)
			else
				api:Set(input.KeyCode)
			end
		elseif not processed and api.Key and input.KeyCode == api.Key then
			Fire(o.Callback, api.Key)
		end
	end))

	api:Set(o.CurrentKeybind or o.Default, true)
	return api
end

function Elements:CreateInput(o)
	o = o or {}
	local row, title = Row(self, o)
	title.Size = UDim2.new(0.45, -12, 1, 0)
	local api, maid = Element(self, row, title, o, { Value = tostring(o.CurrentValue or o.Default or "") })
	local box = SmallBox("TextBox", {
		Text = api.Value,
		PlaceholderText = o.PlaceholderText or "Type here...",
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClipsDescendants = true,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0.55, -10, 0, 24),
		Parent = row,
	})
	Core.Padding(box, 0, 8, 0, 8)
	local stroke = Core.Stroke(box)

	maid:Give(box.Focused:Connect(function()
		Animator:Tween(stroke, { Color = Theme:Get("Accent") }, "Fast")
	end))
	maid:Give(box.FocusLost:Connect(function(enterPressed)
		Theme:Refresh(stroke, true)
		api.Value = box.Text
		Fire(o.Callback, api.Value, enterPressed)
		if o.RemoveTextAfterFocusLost then
			box.Text = ""
		end
	end))

	function api:Set(text, silent)
		self.Value = tostring(text or "")
		box.Text = self.Value
		if not silent then
			Fire(o.Callback, self.Value, false)
		end
	end
	function api:Get()
		return self.Value
	end
	return api
end

function Elements:CreateLabel(o)
	if type(o) ~= "table" then
		o = { Text = tostring(o or "") }
	end
	local row, title = Row(self, { Name = o.Text or o.Name or "" }, 32)
	title.Font = Enum.Font.Gotham
	local api = Element(self, row, title, o)
	function api:Set(text)
		title.Text = tostring(text)
	end
	return api
end

function Elements:CreateParagraph(o)
	o = o or {}
	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = Core.NextOrder(),
		Theme = { BackgroundColor3 = "Surface" },
		Parent = self.Container,
	})
	Core.Corner(row, 6)
	Core.Stroke(row)
	Core.Padding(row, 10, 12, 10, 12)
	Core.List(row, 4)
	local title = Core.Text({
		Text = o.Title or "",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 1,
		Parent = row,
	})
	local body = Core.Text({
		Text = o.Content or "",
		TextSize = 12,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Theme = { TextColor3 = "SubText" },
		Parent = row,
	})
	local api = Element(self, row, title, o)
	function api:Set(data)
		if type(data) == "string" then
			body.Text = data
			return
		end
		if data.Title then
			title.Text = data.Title
		end
		if data.Content then
			body.Text = data.Content
		end
	end
	return api
end

function Elements:CreateDivider()
	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, 9),
		BackgroundTransparency = 1,
		LayoutOrder = Core.NextOrder(),
		Parent = self.Container,
	})
	New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		Theme = { BackgroundColor3 = "Stroke" },
		Parent = row,
	})
	return (Element(self, row, nil, {}))
end

return Elements