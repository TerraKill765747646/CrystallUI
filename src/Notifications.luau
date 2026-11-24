local Import = ...
local Core = Import("src/Core")
local Animator, New = Core.Animator, Core.New

local Notifications = { Active = 0, Queue = {}, Max = 4 }
local TypeKeys = { Info = "Info", Success = "Success", Warning = "Warning", Error = "Error" }
local holder

local function GetHolder()
	if holder and holder:IsDescendantOf(game) then
		return holder
	end
	local gui = Core.Library.Maid:Give(Core.CreateGui("CrystallUI_Notify", 200))
	holder = New("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 300, 1, -32),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Core.List(holder, 8).VerticalAlignment = Enum.VerticalAlignment.Bottom
	Core.Library.Maid:Give(function()
		Notifications.Active = 0
		table.clear(Notifications.Queue)
		holder = nil
	end)
	return holder
end

local function Release()
	Notifications.Active = math.max(0, Notifications.Active - 1)
	Notifications:_Next()
end

local function Show(o, handle)
	Notifications.Active += 1
	local parent = GetHolder()
	local key = TypeKeys[o.Type] or "Accent"

	local wrap = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		LayoutOrder = Core.NextOrder(),
		Parent = parent,
	})
	local card = New("Frame", {
		Position = UDim2.fromOffset(340, 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Theme = { BackgroundColor3 = "Surface" },
		Parent = wrap,
	})
	Core.Corner(card, 8)
	Core.Stroke(card)

	-- The coloured edge: an accent shape under a surface-coloured face that starts 3px further in.
	-- Both have the card's corner radius, so the accent shows as a crescent that follows the rounded
	-- corners exactly instead of a straight bar sticking out of them.
	local accent = New("Frame", { Size = UDim2.new(0, 24, 1, 0), Theme = { BackgroundColor3 = key }, Parent = card })
	Core.Corner(accent, 8)
	local face = New("Frame", {
		Position = UDim2.fromOffset(3, 0),
		Size = UDim2.new(1, -3, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 2,
		Theme = { BackgroundColor3 = "Surface" },
		Parent = card,
	})
	Core.Corner(face, 8)

	local inner = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = face,
	})
	Core.Padding(inner, 10, 12, 12, 16)
	Core.List(inner, 4)
	Core.Text({
		Text = o.Title or "Notification",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Size = UDim2.new(1, -20, 0, 18),
		LayoutOrder = 1,
		Parent = inner,
	})
	Core.Text({
		Text = o.Content or "",
		TextSize = 13,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Theme = { TextColor3 = "SubText" },
		Parent = inner,
	})

	if type(o.Actions) == "table" and #o.Actions > 0 then
		local row = New("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 3, Parent = inner })
		Core.List(row, 6, Enum.FillDirection.Horizontal)
		for i, action in o.Actions do
			local button = New("TextButton", {
				Text = action.Name or "OK",
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				AutoButtonColor = false,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 26),
				LayoutOrder = i,
				Theme = {
					BackgroundColor3 = i == 1 and "Accent" or "Elevated",
					TextColor3 = i == 1 and "AccentText" or "Text",
				},
				Parent = row,
			})
			Core.Corner(button, 6)
			Core.Padding(button, 0, 10, 0, 10)
			button.MouseButton1Click:Connect(function()
				Core.Fire(action.Callback)
				handle:Close()
			end)
		end
	end

	local closeButton = New("TextButton", {
		Name = "Close",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(18, 18),
		ZIndex = 3,
		Parent = card,
	})
	Core.Cross(closeButton, 8, "SubText")
	closeButton.MouseButton1Click:Connect(function()
		handle:Close()
	end)

	local duration = tonumber(o.Duration)
	if o.Duration == false or duration == 0 or duration == math.huge then
		duration = nil -- sticky: stays until closed by the user or by code
	else
		duration = if duration and duration > 0 then duration else 5
	end

	-- the timer line floats inside the face with a margin: away from the accent edge and the rounded corners
	local progress = New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -6),
		Size = UDim2.new(1, -32, 0, 2),
		Visible = duration ~= nil,
		Theme = { BackgroundColor3 = key },
		Parent = face,
	})
	Core.Corner(progress, 1)

	task.wait()
	if handle.Closed then
		wrap:Destroy()
		Release()
		return
	end

	Animator:Tween(wrap, { Size = UDim2.new(1, 0, 0, card.AbsoluteSize.Y) })
	Animator:Tween(card, { Position = UDim2.new() })
	local progressTween = if duration
		then Animator:Tween(progress, { Size = UDim2.new(0, 0, 0, 2) }, duration, Enum.EasingStyle.Linear)
		else nil

	local timer
	handle._close = function()
		if progressTween then
			progressTween:Cancel()
		end
		if timer then
			task.cancel(timer)
		end
		Animator:Tween(card, { Position = UDim2.fromOffset(340, 0) }, "Fast", Enum.EasingStyle.Quad)
		local collapse = Animator:Tween(wrap, { Size = UDim2.new(1, 0, 0, 0) }, nil, Enum.EasingStyle.Quad)
		collapse.Completed:Once(function()
			wrap:Destroy()
		end)
		Release()
	end

	if duration then
		timer = task.delay(duration, function()
			timer = nil
			handle:Close()
		end)
	end
end

function Notifications:_Next()
	while self.Active < self.Max and #self.Queue > 0 do
		local entry = table.remove(self.Queue, 1)
		if not entry.Handle.Closed then
			task.spawn(Show, entry.Options, entry.Handle)
		end
	end
end

function Notifications:Notify(o)
	if type(o) == "string" then
		o = { Content = o }
	end
	o = if type(o) == "table" then o else {}
	local handle = { Closed = false }
	function handle:Close()
		if self.Closed then
			return
		end
		self.Closed = true
		if self._close then
			self._close()
		end
	end
	table.insert(self.Queue, { Options = o, Handle = handle })
	self:_Next()
	return handle
end

return Notifications