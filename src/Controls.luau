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
	-- translucent cover that swallows input while the element is locked
	local shield = New("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.45,
		Visible = false,
		ZIndex = 30,
		Theme = { BackgroundColor3 = "Background" },
		Parent = row,
	})
	Core.Corner(shield, 6)
	api.Locked = false
	function api:SetLocked(state)
		self.Locked = state == true
		shield.Visible = self.Locked
		if self.Locked and self.SetOpen then
			self:SetOpen(false)
		end
	end
	if o.Locked then
		api:SetLocked(true)
	end

	local windowMaid = self.Window.Maid
	function api:Destroy()
		windowMaid:Remove(self)
		maid:Clean()
		row:Destroy()
		if self.Flag and Core.Library.Flags[self.Flag] == self then
			Core.Library.Flags[self.Flag] = nil
		end
	end
	Core.RegisterFlag(o.Flag, api)
	windowMaid:Give(api)
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

-- A panel that floats above the window (so it is never clipped by the scrolling page) and sits
-- under its row. Closes on outside click, on tab switch and when the window hides.
local function Popup(self, row, api, maid)
	local win = self.Window
	local gui = win.Gui
	local frame = New("Frame", {
		Visible = false,
		ClipsDescendants = true,
		ZIndex = 50,
		Size = UDim2.fromOffset(0, 0),
		Theme = { BackgroundColor3 = "Surface" },
		Parent = gui,
	})
	Core.Corner(frame, 8)
	Core.Stroke(frame, "Accent")
	maid:Give(frame)

	local pop = { Frame = frame, Height = 0 }

	local function Geometry()
		local abs, size, view = row.AbsolutePosition, row.AbsoluteSize, gui.AbsoluteSize
		local y = abs.Y + size.Y + 4
		if y + pop.Height > view.Y - 8 and abs.Y - pop.Height - 4 > 8 then
			y = abs.Y - pop.Height - 4 -- not enough room below, flip above
		end
		return UDim2.fromOffset(abs.X, y), size.X
	end

	function pop:Update(open)
		if open then
			local position, width = Geometry()
			local target = UDim2.fromOffset(width, self.Height)
			frame.Position = position
			if not frame.Visible then
				frame.Size = UDim2.fromOffset(width, 0)
				frame.Visible = true
			end
			Animator:Tween(frame, { Size = target })
		else
			local width = row.AbsoluteSize.X
			local tween = Animator:Tween(frame, { Size = UDim2.fromOffset(width, 0) }, "Fast", Enum.EasingStyle.Quad)
			tween.Completed:Once(function(state)
				if not api.Open and state == Enum.PlaybackState.Completed then
					frame.Visible = false
				end
			end)
		end
	end

	win.Popups[api] = function()
		api:SetOpen(false)
	end
	maid:Give(function()
		win.Popups[api] = nil
	end)

	local function Follow()
		if api.Open then
			local position, width = Geometry()
			frame.Position = position
			frame.Size = UDim2.fromOffset(width, pop.Height)
		end
	end
	maid:Give(row:GetPropertyChangedSignal("AbsolutePosition"):Connect(Follow))
	maid:Give(row:GetPropertyChangedSignal("AbsoluteSize"):Connect(Follow))

	local function Inside(inst, p)
		local a, s = inst.AbsolutePosition, inst.AbsoluteSize
		return p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
	end
	maid:Give(UIS.InputBegan:Connect(function(input)
		if api.Open and Core.IsPointer(input) and not Inside(frame, input.Position) and not Inside(row, input.Position) then
			api:SetOpen(false)
		end
	end))

	return pop
end

-- Runs a user-initiated change through the element's `Warning` option (see src/Warnings.luau).
-- `apply` only runs when nothing blocked the action. Programmatic Set() calls and config imports
-- never go through here, so they never pop a dialog. A second click while a dialog is already open
-- for the same element is ignored.
local function Guarded(api, o, ctx, apply)
	if not o.Warning then
		apply()
		return
	end
	if api._guarding then
		return
	end
	api._guarding = true
	ctx.Name = ctx.Name or o.Name
	ctx.Element = api
	task.spawn(function()
		local ok, err = pcall(Core.Warnings.Guard, Core.Warnings, o.Warning, ctx, apply, o.Flag or o.Name)
		api._guarding = false
		if not ok then
			warn("[CrystallUI] Warning failed: " .. tostring(err))
		end
	end)
end

function Elements:CreateButton(o)
	o = o or {}
	local row, title, stroke = Row(self, o)
	local api, maid = Element(self, row, title, o)
	local hit = Hit(row)
	Core.Chevron(row, 8, "SubText", 0, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
	})
	Hover(maid, hit, row)
	maid:Give(hit.MouseButton1Click:Connect(function()
		Animator:Tween(stroke, { Color = Theme:Get("Accent") }, "Fast")
		task.delay(Theme.Motion.Duration, function()
			if row.Parent then
				Theme:Refresh(stroke, true)
			end
		end)
		Guarded(api, o, { Action = "Click" }, function()
			Fire(o.Callback)
		end)
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
		local nextValue = not api.Value
		Guarded(api, o, { Action = if nextValue then "Enable" else "Disable", Value = nextValue, Old = api.Value }, function()
			api:Set(nextValue)
		end)
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
		local check = Core.Check(box, 16, "AccentText", { Visible = false })
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
			local picking = not api.Selected[name]
			Guarded(api, o, { Action = if picking then "Select" else "Deselect", Value = name, Old = api:GetSelected() }, function()
				api.Selected[name] = picking or nil
				Paint(name)
				api.Value = api:GetSelected()
				Fire(o.Callback, api.Value)
			end)
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
	if type(increment) ~= "number" or increment <= 0 then
		increment = 1
	end
	if min > max then
		min, max = max, min
	end
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
	local scroller
	local function SetDragging(state)
		dragging = state
		-- on touch the page would scroll under the finger while the slider is dragged
		if state then
			scroller = bar:FindFirstAncestorWhichIsA("ScrollingFrame")
			if scroller then
				scroller.ScrollingEnabled = false
			end
		elseif scroller then
			scroller.ScrollingEnabled = true
			scroller = nil
		end
	end
	maid:Give(function()
		SetDragging(false)
	end)
	local function FromX(x)
		local width = math.max(bar.AbsoluteSize.X, 1)
		api:Set(min + (max - min) * math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1), false, true)
	end
	maid:Give(bar.InputBegan:Connect(function(input)
		if Core.IsPointer(input) then
			SetDragging(true)
			FromX(input.Position.X)
		end
	end))
	maid:Give(UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			FromX(input.Position.X)
		end
	end))
	maid:Give(UIS.InputEnded:Connect(function(input)
		if Core.IsPointer(input) and dragging then
			SetDragging(false)
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
	title.Size = UDim2.new(0.5, -12, 0, 38)
	local api, maid = Element(self, row, title, o, { Open = false })
	local win = self.Window
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
	local chevron = Core.Chevron(row, 10, "SubText", 90, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0, 19),
	})

	local pop = Popup(self, row, api, maid)
	api.Popup = pop.Frame

	local searchHeight = o.Search and 30 or 0
	local search
	if o.Search then
		search = SmallBox("TextBox", {
			Text = "",
			PlaceholderText = "Search...",
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 0, 24),
			ZIndex = 51,
			Parent = pop.Frame,
		})
		Core.Padding(search, 0, 8, 0, 8)
	end

	local listTop = 8 + searchHeight
	local list = New("ScrollingFrame", {
		Position = UDim2.fromOffset(8, listTop),
		Size = UDim2.new(1, -16, 0, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 2,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 51,
		Theme = { ScrollBarImageColor3 = "Accent" },
		Parent = pop.Frame,
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
		pop.Height = listTop + listHeight + 8
		pop:Update(api.Open)
		Animator:Tween(chevron, { Rotation = if api.Open then 270 else 90 }, "Fast")
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
				ZIndex = 52,
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
				local picking = if multi then not selected[name] else true
				if not multi then
					api.Open = false -- a single pick closes the list right away, even if a warning is still pending
					Layout()
				end
				Guarded(api, o, { Action = if picking then "Select" else "Deselect", Value = name, Old = api:Get() }, function()
					if multi then
						selected[name] = picking or nil
					else
						table.clear(selected)
						selected[name] = true
					end
					Paint()
					Fire(o.Callback, api:Get())
				end)
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
		state = state == true
		if state and self.Locked then
			return
		end
		if state then
			win:_ClosePopups(self)
		end
		self.Open = state
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

local function ToHSV(c)
	local r, g, b = c.R, c.G, c.B
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local delta = max - min
	local h = 0
	if delta > 0 then
		if max == r then
			h = ((g - b) / delta) % 6
		elseif max == g then
			h = (b - r) / delta + 2
		else
			h = (r - g) / delta + 4
		end
		h /= 6
	end
	return h, if max == 0 then 0 else delta / max, max
end

local function FromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local m = i % 6
	local r, g, b
	if m == 0 then
		r, g, b = v, t, p
	elseif m == 1 then
		r, g, b = q, v, p
	elseif m == 2 then
		r, g, b = p, v, t
	elseif m == 3 then
		r, g, b = p, q, v
	elseif m == 4 then
		r, g, b = t, p, v
	else
		r, g, b = v, p, q
	end
	return Color3.fromRGB(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function ToHex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function ParseColor(value)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "string" then
		local hex = value:match("^%s*#?(%x+)%s*$")
		if hex and #hex == 3 then
			hex = hex:gsub(".", "%0%0")
		end
		if hex and #hex == 6 then
			return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
		end
	end
	return nil
end

function Elements:CreateColorPicker(o)
	o = o or {}
	local row, title = Row(self, o)
	title.Size = UDim2.new(1, -90, 1, 0)
	local api, maid = Element(self, row, title, o, { Open = false })
	local win = self.Window

	local start = ParseColor(o.CurrentValue or o.Default) or Color3.fromRGB(255, 255, 255)
	local h, s, v = ToHSV(start)
	api.Value = start

	local header = Hit(row, 38)
	local swatch = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(40, 20),
		BackgroundColor3 = start,
		Parent = row,
	})
	Core.Corner(swatch, 5)
	Core.Stroke(swatch)

	local pop = Popup(self, row, api, maid)
	api.Popup = pop.Frame
	pop.Height = 176

	-- saturation / value square: hue colour, white fading right, black fading down
	local sv = New("TextButton", {
		Name = "SV",
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -44, 0, 120),
		BackgroundColor3 = FromHSV(h, 1, 1),
		ZIndex = 51,
		Parent = pop.Frame,
	})
	Core.Corner(sv, 6)
	local white = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 52, Parent = sv })
	Core.Corner(white, 6)
	New("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
	local black = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(0, 0, 0), ZIndex = 53, Parent = sv })
	Core.Corner(black, 6)
	New("UIGradient", { Transparency = NumberSequence.new(1, 0), Rotation = 90, Parent = black })
	local svCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		ZIndex = 55,
		Parent = sv,
	})
	Core.Corner(svCursor, 6)
	Core.Stroke(svCursor, "Text", 2)

	local hue = New("TextButton", {
		Name = "Hue",
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.new(1, -28, 0, 8),
		Size = UDim2.fromOffset(20, 120),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 51,
		Parent = pop.Frame,
	})
	Core.Corner(hue, 6)
	local function Key(t, r, g, b)
		return ColorSequenceKeypoint.new(t, Color3.fromRGB(r, g, b))
	end
	New("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			Key(0, 255, 0, 0), Key(1 / 6, 255, 255, 0), Key(2 / 6, 0, 255, 0), Key(3 / 6, 0, 255, 255),
			Key(4 / 6, 0, 0, 255), Key(5 / 6, 255, 0, 255), Key(1, 255, 0, 0),
		}),
		Parent = hue,
	})
	local hueCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 6, 0, 4),
		BackgroundTransparency = 1,
		ZIndex = 55,
		Parent = hue,
	})
	Core.Corner(hueCursor, 2)
	Core.Stroke(hueCursor, "Text", 2)

	local hexBox = SmallBox("TextBox", {
		Text = "",
		PlaceholderText = "#RRGGBB",
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(8, 136),
		Size = UDim2.new(1, -16, 0, 28),
		ZIndex = 51,
		Parent = pop.Frame,
	})
	Core.Padding(hexBox, 0, 8, 0, 8)

	local function Paint()
		local color = FromHSV(h, s, v)
		api.Value = color
		swatch.BackgroundColor3 = color
		sv.BackgroundColor3 = FromHSV(h, 1, 1)
		svCursor.Position = UDim2.fromScale(s, 1 - v)
		hueCursor.Position = UDim2.fromScale(0.5, h)
		hexBox.Text = ToHex(color)
	end

	function api:Get()
		return self.Value
	end
	function api:GetHex()
		return ToHex(self.Value)
	end
	-- config files are JSON, so a colour is stored as hex
	api.Export = api.GetHex

	function api:Set(value, silent)
		local color = ParseColor(value)
		if not color then
			hexBox.Text = ToHex(self.Value)
			return
		end
		local nh, ns, nv = ToHSV(color)
		-- a grey or black pick has no meaningful hue/saturation: keep what the user had
		if ns > 0 and nv > 0 then
			h = nh
		end
		if nv > 0 then
			s = ns
		end
		v = nv
		Paint()
		if not silent then
			Fire(o.Callback, self.Value)
		end
	end

	local function Drag(frame, apply)
		local dragging = false
		local function Move(pos)
			local size, abs = frame.AbsoluteSize, frame.AbsolutePosition
			apply(math.clamp((pos.X - abs.X) / math.max(size.X, 1), 0, 1), math.clamp((pos.Y - abs.Y) / math.max(size.Y, 1), 0, 1))
			Paint()
			Fire(o.Callback, api.Value)
		end
		maid:Give(frame.InputBegan:Connect(function(input)
			if Core.IsPointer(input) then
				dragging = true
				Move(input.Position)
			end
		end))
		maid:Give(UIS.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				Move(input.Position)
			end
		end))
		maid:Give(UIS.InputEnded:Connect(function(input)
			if Core.IsPointer(input) then
				dragging = false
			end
		end))
	end
	Drag(sv, function(x, y)
		s, v = x, 1 - y
	end)
	Drag(hue, function(_, y)
		h = math.min(y, 0.9999)
	end)

	maid:Give(hexBox.FocusLost:Connect(function()
		api:Set(hexBox.Text)
	end))

	function api:SetOpen(state)
		state = state == true
		if state and self.Locked then
			return
		end
		if state then
			win:_ClosePopups(self)
		end
		self.Open = state
		pop:Update(state)
	end
	maid:Give(header.MouseButton1Click:Connect(function()
		api:SetOpen(not api.Open)
	end))
	Hover(maid, header, row)

	Paint()
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
		elseif not processed and not api.Locked and api.Key and input.KeyCode == api.Key then
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
	title.TextWrapped = true
	title.Size = UDim2.new(1, -24, 0, 32)
	title.AutomaticSize = Enum.AutomaticSize.Y
	row.AutomaticSize = Enum.AutomaticSize.Y
	Core.Padding(title, 6, 0, 6, 0)
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