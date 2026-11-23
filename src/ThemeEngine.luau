local TweenService = game:GetService("TweenService")

local Theme = {
	Palettes = {},
	Motions = {},
	PaletteName = "Amethyst",
	MotionName = "Minimal",
}

local Bindings = setmetatable({}, { __mode = "k" })
local Listeners = {}

Theme.Palettes.Amethyst = {
	Background = Color3.fromRGB(17, 15, 26),
	Surface = Color3.fromRGB(26, 23, 38),
	Elevated = Color3.fromRGB(38, 34, 56),
	Stroke = Color3.fromRGB(58, 50, 86),
	Accent = Color3.fromRGB(157, 110, 255),
	AccentText = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(236, 232, 248),
	SubText = Color3.fromRGB(150, 142, 178),
	Success = Color3.fromRGB(94, 214, 150),
	Warning = Color3.fromRGB(255, 196, 92),
	Error = Color3.fromRGB(255, 99, 120),
	Info = Color3.fromRGB(120, 170, 255),
	DefaultMotion = "Minimal",
}

Theme.Palettes.RoyalTopaz = {
	Background = Color3.fromRGB(11, 17, 31),
	Surface = Color3.fromRGB(19, 27, 47),
	Elevated = Color3.fromRGB(29, 40, 67),
	Stroke = Color3.fromRGB(47, 63, 101),
	Accent = Color3.fromRGB(255, 170, 51),
	AccentText = Color3.fromRGB(24, 16, 6),
	Text = Color3.fromRGB(242, 237, 226),
	SubText = Color3.fromRGB(150, 160, 188),
	Success = Color3.fromRGB(88, 210, 140),
	Warning = Color3.fromRGB(255, 205, 80),
	Error = Color3.fromRGB(255, 92, 92),
	Info = Color3.fromRGB(96, 165, 250),
	DefaultMotion = "Brutal",
}

Theme.Palettes.Emerald = {
	Background = Color3.fromRGB(10, 20, 18),
	Surface = Color3.fromRGB(16, 31, 28),
	Elevated = Color3.fromRGB(25, 46, 41),
	Stroke = Color3.fromRGB(40, 72, 64),
	Accent = Color3.fromRGB(52, 211, 153),
	AccentText = Color3.fromRGB(6, 28, 20),
	Text = Color3.fromRGB(226, 245, 238),
	SubText = Color3.fromRGB(130, 168, 156),
	Success = Color3.fromRGB(94, 214, 150),
	Warning = Color3.fromRGB(255, 196, 92),
	Error = Color3.fromRGB(255, 99, 120),
	Info = Color3.fromRGB(120, 170, 255),
	DefaultMotion = "Minimal",
}

Theme.Palettes.Quartz = {
	Background = Color3.fromRGB(244, 242, 248),
	Surface = Color3.fromRGB(255, 255, 255),
	Elevated = Color3.fromRGB(233, 229, 242),
	Stroke = Color3.fromRGB(207, 200, 224),
	Accent = Color3.fromRGB(124, 77, 255),
	AccentText = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(32, 28, 48),
	SubText = Color3.fromRGB(104, 96, 130),
	Success = Color3.fromRGB(22, 163, 98),
	Warning = Color3.fromRGB(217, 140, 10),
	Error = Color3.fromRGB(220, 53, 80),
	Info = Color3.fromRGB(37, 99, 235),
	DefaultMotion = "Minimal",
}

Theme.Motions.Minimal = {
	Duration = 0.28,
	Fast = 0.15,
	Style = Enum.EasingStyle.Quint,
	Direction = Enum.EasingDirection.Out,
	ColorStyle = Enum.EasingStyle.Quad,
	Scale = 0.94,
	Offset = 14,
}

Theme.Motions.Brutal = {
	Duration = 0.18,
	Fast = 0.08,
	Style = Enum.EasingStyle.Back,
	Direction = Enum.EasingDirection.Out,
	ColorStyle = Enum.EasingStyle.Linear,
	Scale = 0.7,
	Offset = 48,
}

Theme.Motions.Instant = {
	Duration = 0,
	Fast = 0,
	Style = Enum.EasingStyle.Linear,
	Direction = Enum.EasingDirection.Out,
	ColorStyle = Enum.EasingStyle.Linear,
	Scale = 1,
	Offset = 0,
}

Theme.Current = Theme.Palettes.Amethyst
Theme.Motion = Theme.Motions.Minimal

local Animator = { Active = setmetatable({}, { __mode = "k" }) }
Theme.Animator = Animator

function Animator:Info(speed, style)
	local m = Theme.Motion
	local duration = if type(speed) == "number" then speed elseif speed == "Fast" then m.Fast else m.Duration
	return TweenInfo.new(duration, style or m.Style, m.Direction)
end

function Animator:Tween(inst, props, speed, style)
	local names = {}
	for k in props do
		table.insert(names, k)
	end
	table.sort(names)
	local id = table.concat(names, ",")
	local map = self.Active[inst]
	if not map then
		map = {}
		self.Active[inst] = map
	end
	if map[id] then
		map[id]:Cancel()
	end
	local tween = TweenService:Create(inst, self:Info(speed, style), props)
	map[id] = tween
	tween.Completed:Once(function()
		if map[id] == tween then
			map[id] = nil
		end
	end)
	tween:Play()
	return tween
end

function Animator:CancelAll()
	for _, map in self.Active do
		for _, tween in map do
			tween:Cancel()
		end
	end
	table.clear(self.Active)
end

local function Resolve(v)
	if type(v) == "function" then
		return v(Theme.Current)
	elseif type(v) == "string" then
		return Theme.Current[v]
	end
	return v
end

local function Emit(kind, name)
	for fn in Listeners do
		task.spawn(fn, kind, name)
	end
end

function Theme:Bind(inst, props)
	local binding = Bindings[inst]
	if not binding then
		binding = {}
		-- Binding closures usually reference the element that owns the instance, which keeps the
		-- weak key alive. Dropping the entry on Destroying is what actually frees it.
		inst.Destroying:Once(function()
			Bindings[inst] = nil
		end)
	end
	for k, v in props do
		binding[k] = v
		local value = Resolve(v)
		if value ~= nil then
			inst[k] = value
		end
	end
	Bindings[inst] = binding
	return inst
end

function Theme:Unbind(inst)
	Bindings[inst] = nil
end

local TWEENABLE = { Color3 = true, number = true, UDim2 = true, UDim = true, Vector2 = true }

function Theme:Refresh(inst, animate)
	local binding = Bindings[inst]
	if not binding then
		return
	end
	local goal, direct = {}, {}
	for k, v in binding do
		local value = Resolve(v)
		if value ~= nil then
			-- ColorSequence, strings, enums and the like can't be tweened, they are assigned directly
			if animate and TWEENABLE[typeof(value)] then
				goal[k] = value
			else
				direct[k] = value
			end
		end
	end
	for k, v in direct do
		inst[k] = v
	end
	if next(goal) ~= nil then
		Animator:Tween(inst, goal, "Fast", self.Motion.ColorStyle)
	end
end

function Theme:_BindingCount()
	local count = 0
	for _ in Bindings do
		count += 1
	end
	return count
end

function Theme:Get(key)
	return self.Current[key]
end

function Theme:SetMotion(name)
	local motion = self.Motions[name]
	assert(motion, "[CrystallUI] Unknown motion profile: " .. tostring(name))
	self.Motion, self.MotionName = motion, name
	Emit("Motion", name)
end

function Theme:SetPalette(name, keepMotion)
	local palette = self.Palettes[name]
	assert(palette, "[CrystallUI] Unknown palette: " .. tostring(name))
	self.Current, self.PaletteName = palette, name
	if not keepMotion and palette.DefaultMotion and self.Motions[palette.DefaultMotion] then
		self:SetMotion(palette.DefaultMotion)
	end
	for inst in Bindings do
		self:Refresh(inst, inst.Parent ~= nil)
	end
	Emit("Palette", name)
end

function Theme:SetTheme(cfg)
	cfg = cfg or {}
	if cfg.Palette then
		self:SetPalette(cfg.Palette, cfg.Motion ~= nil)
	end
	if cfg.Motion then
		self:SetMotion(cfg.Motion)
	end
end

function Theme:RegisterPalette(name, palette)
	assert(type(name) == "string" and name ~= "", "[CrystallUI] Palette name must be a non-empty string")
	assert(type(palette) == "table", "[CrystallUI] Palette must be a table")
	local new = table.clone(self.Palettes.Amethyst)
	new.DefaultMotion = nil
	for k, v in palette do
		if k == "DefaultMotion" then
			assert(type(v) == "string", "[CrystallUI] DefaultMotion must be a string")
		else
			assert(typeof(v) == "Color3", "[CrystallUI] Palette key '" .. tostring(k) .. "' must be a Color3")
		end
		new[k] = v
	end
	self.Palettes[name] = new
	return new
end

function Theme:RegisterMotion(name, motion)
	assert(type(name) == "string" and name ~= "", "[CrystallUI] Motion name must be a non-empty string")
	assert(type(motion) == "table", "[CrystallUI] Motion must be a table")
	local new = table.clone(self.Motions.Minimal)
	for k, v in motion do
		new[k] = v
	end
	self.Motions[name] = new
	return new
end

function Theme:ListPalettes()
	local names = {}
	for name in self.Palettes do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function Theme:ListMotions()
	local names = {}
	for name in self.Motions do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function Theme:OnChanged(fn)
	assert(type(fn) == "function", "[CrystallUI] OnChanged expects a function")
	Listeners[fn] = true
	return {
		Disconnect = function()
			Listeners[fn] = nil
		end,
	}
end

function Theme:Clear()
	Animator:CancelAll()
	table.clear(Bindings)
	table.clear(Listeners)
end

return Theme