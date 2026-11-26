-- Minimal Roblox API emulation, just enough to run CrystallUI headless in plain Luau.
-- It is NOT a faithful engine: tweens apply their goal on completion, layout sizes are fixed,
-- and unknown properties are accepted silently. It exists to catch logic and runtime errors.

local Mock = {}

---------------------------------------------------------------- types
local function typed(tbl, name, mt)
	mt = mt or {}
	mt.__type = name
	return setmetatable(tbl, mt)
end

local realTypeof = typeof
local function mockTypeof(v)
	if type(v) == "table" then
		local mt = getmetatable(v)
		if mt and mt.__type then
			return mt.__type
		end
	end
	return realTypeof(v)
end
typeof = mockTypeof

-- Chunks compiled by loadstring would otherwise see the builtin typeof, so run them in an env that
-- carries the override. Everything else falls through to the real globals.
local realLoadstring = loadstring
local chunkEnv = setmetatable({ typeof = mockTypeof }, {
	__index = function(_, key) return getfenv(0)[key] end,
	__newindex = function(_, key, value) getfenv(0)[key] = value end,
})
loadstring = function(source, chunkname)
	local fn, err = realLoadstring(source, chunkname)
	if fn then
		setfenv(fn, chunkEnv)
	end
	return fn, err
end

local function makeV2(x, y)
	local mt = {
		__type = "Vector2",
		__add = function(a, b) return makeV2(a.X + b.X, a.Y + b.Y) end,
		__sub = function(a, b) return makeV2(a.X - b.X, a.Y - b.Y) end,
		__mul = function(a, b) return if type(b) == "number" then makeV2(a.X * b, a.Y * b) else makeV2(a.X * b.X, a.Y * b.Y) end,
		__div = function(a, b) return if type(b) == "number" then makeV2(a.X / b, a.Y / b) else makeV2(a.X / b.X, a.Y / b.Y) end,
	}
	return setmetatable({ X = x, Y = y }, mt)
end
Vector2 = { new = function(x, y) return makeV2(x or 0, y or 0) end }
local V2 = function(x, y) return makeV2(x, y) end

Vector3 = {
	new = function(x, y, z)
		local function v3(a, b, c)
			return setmetatable({ X = a, Y = b, Z = c }, {
				__type = "Vector3",
				__sub = function(l, r) return v3(l.X - r.X, l.Y - r.Y, l.Z - r.Z) end,
			})
		end
		return v3(x or 0, y or 0, z or 0)
	end,
}

UDim = {
	new = function(s, o) return typed({ Scale = s or 0, Offset = o or 0 }, "UDim") end,
}
UDim2 = {
	new = function(xs, xo, ys, yo)
		return typed({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, "UDim2")
	end,
	fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end,
	fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end,
}
Color3 = {
	fromRGB = function(r, g, b) return typed({ R = r / 255, G = g / 255, B = b / 255 }, "Color3") end,
}
Color3.new = function(r, g, b) return typed({ R = r, G = g, B = b }, "Color3") end
ColorSequence = { new = function(...) return typed({ args = { ... } }, "ColorSequence") end }
ColorSequenceKeypoint = { new = function(t, c) return typed({ Time = t, Value = c }, "ColorSequenceKeypoint") end }
NumberSequence = { new = function(...) return typed({ args = { ... } }, "NumberSequence") end }
TweenInfo = {
	new = function(t, style, dir) return typed({ Time = t, EasingStyle = style, EasingDirection = dir }, "TweenInfo") end,
}

---------------------------------------------------------------- enums
local KEYCODES = { RightShift = true, LeftShift = true, K = true, F = true, G = true, H = true, Escape = true, Backspace = true, Insert = true }
local enumCache = {}
local function EnumType(typeName)
	return setmetatable({}, {
		__index = function(self, name)
			if typeName == "KeyCode" and not KEYCODES[name] then
				error(name .. " is not a valid member of Enum.KeyCode", 2)
			end
			local key = typeName .. "." .. name
			if not enumCache[key] then
				enumCache[key] = typed({ Name = name, EnumType = typeName }, "EnumItem")
			end
			return enumCache[key]
		end,
	})
end
Enum = setmetatable({}, {
	__index = function(self, typeName)
		local t = EnumType(typeName)
		rawset(self, typeName, t)
		return t
	end,
})

---------------------------------------------------------------- scheduler (virtual clock)
local clock, seq, queue = 0, 0, {}
local function schedule(delay, fn, ...)
	seq += 1
	local entry = { at = clock + delay, seq = seq, fn = fn, args = table.pack(...), live = true }
	table.insert(queue, entry)
	return entry
end
local function runDue(limit)
	while true do
		local best
		for _, e in queue do
			if e.live and e.at <= limit and (not best or e.at < best.at or (e.at == best.at and e.seq < best.seq)) then
				best = e
			end
		end
		if not best then
			break
		end
		best.live = false
		clock = math.max(clock, best.at)
		best.fn(table.unpack(best.args, 1, best.args.n))
	end
	for i = #queue, 1, -1 do
		if not queue[i].live then
			table.remove(queue, i)
		end
	end
	clock = math.max(clock, limit)
end

-- threads started through task.spawn: only those may really yield in task.wait
local spawned = setmetatable({}, { __mode = "k" })

task = {
	spawn = function(fn, ...)
		if type(fn) == "thread" then
			coroutine.resume(fn, ...)
			return fn
		end
		local co = coroutine.create(fn)
		spawned[co] = true
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			print("[mock] error in spawned task: " .. tostring(err))
		end
		return co
	end,
	defer = function(fn, ...)
		return schedule(0, fn, ...)
	end,
	delay = function(t, fn, ...)
		return schedule(t, fn, ...)
	end,
	cancel = function(handle)
		if type(handle) == "table" then
			handle.live = false
		end
	end,
	-- Inside a spawned task, wait really suspends the task until the virtual clock gets there (as in
	-- the engine). On the main thread (the test runner) it advances the clock and runs what is due.
	wait = function(t)
		t = t or 0.03
		local co = coroutine.running()
		if spawned[co] then
			schedule(t, function()
				local ok, err = coroutine.resume(co)
				if not ok then
					print("[mock] error in resumed task: " .. tostring(err))
				end
			end)
			coroutine.yield()
			return t
		end
		runDue(clock + t)
		return t
	end,
}
function Mock.Time() return clock end

warn = function(...)
	Mock.Warnings = Mock.Warnings or {}
	table.insert(Mock.Warnings, table.concat({ ... }, " "))
end

---------------------------------------------------------------- signals
local function Signal()
	local handlers = {}
	local sig = {}
	local function connect(fn, once)
		local entry = { fn = fn, once = once }
		table.insert(handlers, entry)
		local conn = typed({ Connected = true }, "RBXScriptConnection")
		function conn:Disconnect()
			self.Connected = false
			local i = table.find(handlers, entry)
			if i then
				table.remove(handlers, i)
			end
		end
		return conn
	end
	function sig:Connect(fn) return connect(fn, false) end
	function sig:Once(fn) return connect(fn, true) end
	function sig:Fire(...)
		for _, entry in table.clone(handlers) do
			if entry.once then
				local i = table.find(handlers, entry)
				if i then
					table.remove(handlers, i)
				end
			end
			entry.fn(...)
		end
	end
	function sig:Count() return #handlers end
	return typed(sig, "RBXScriptSignal")
end
Mock.Signal = Signal

---------------------------------------------------------------- instances
local GUI_OBJECTS = { Frame = true, TextLabel = true, TextButton = true, TextBox = true, ScrollingFrame = true }
local EVENT_NAMES = {
	MouseButton1Click = true, MouseEnter = true, MouseLeave = true, InputBegan = true, InputChanged = true,
	InputEnded = true, FocusLost = true, Focused = true, Destroying = true, ChildAdded = true,
}

local Instance_mt = {}
local methods = {}

local function new(class)
	local self = { _class = class, _props = {}, _children = {}, _signals = {}, _propSignals = {}, _destroyed = false }
	return setmetatable(self, Instance_mt)
end

Instance = { new = new }

local defaults = {
	Visible = true, Text = "", Parent = nil, ScrollingEnabled = true,
	AbsoluteSize = V2(200, 30), AbsolutePosition = V2(0, 0), CanvasPosition = V2(0, 0),
	Rotation = 0, BackgroundTransparency = 0,
}

Instance_mt.__index = function(self, key)
	local props = rawget(self, "_props")
	local v = props[key]
	if v ~= nil then
		return v
	end
	if methods[key] then
		return methods[key]
	end
	if key == "ClassName" then
		return rawget(self, "_class")
	end
	if EVENT_NAMES[key] then
		local sigs = rawget(self, "_signals")
		sigs[key] = sigs[key] or Signal()
		return sigs[key]
	end
	return defaults[key]
end

Instance_mt.__newindex = function(self, key, value)
	local props = rawget(self, "_props")
	if key == "Parent" then
		if rawget(self, "_destroyed") then
			error("The Parent property of " .. rawget(self, "_class") .. " is locked", 2)
		end
		local old = props.Parent
		if old == value then
			return
		end
		if old then
			local siblings = rawget(old, "_children")
			local i = table.find(siblings, self)
			if i then
				table.remove(siblings, i)
			end
		end
		props.Parent = value
		if value then
			table.insert(rawget(value, "_children"), self)
		end
		return
	end
	local old = props[key]
	props[key] = value
	if old ~= value then
		local sig = rawget(self, "_propSignals")[key]
		if sig then
			sig:Fire()
		end
	end
end

function methods:IsA(class)
	local own = rawget(self, "_class")
	if own == class then
		return true
	end
	if class == "GuiObject" then
		return GUI_OBJECTS[own] == true
	end
	if class == "Instance" then
		return true
	end
	return false
end
function methods:GetPropertyChangedSignal(name)
	local sigs = rawget(self, "_propSignals")
	sigs[name] = sigs[name] or Signal()
	return sigs[name]
end
function methods:GetChildren()
	return table.clone(rawget(self, "_children"))
end
function methods:GetDescendants()
	local out = {}
	local function walk(inst)
		for _, child in rawget(inst, "_children") do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end
function methods:IsDescendantOf(ancestor)
	local cur = rawget(self, "_props").Parent
	while cur do
		if cur == ancestor then
			return true
		end
		cur = rawget(cur, "_props").Parent
	end
	return false
end
function methods:FindFirstAncestorWhichIsA(class)
	local cur = rawget(self, "_props").Parent
	while cur do
		if cur:IsA(class) then
			return cur
		end
		cur = rawget(cur, "_props").Parent
	end
	return nil
end
function methods:Destroy()
	if rawget(self, "_destroyed") then
		return
	end
	local sigs = rawget(self, "_signals")
	if sigs.Destroying then
		sigs.Destroying:Fire()
	end
	for _, child in self:GetChildren() do
		child:Destroy()
	end
	self.Parent = nil
	rawset(self, "_destroyed", true)
end
function methods:Clone() return new(rawget(self, "_class")) end

-- let typeof see instances
local instMT = Instance_mt
instMT.__type = "Instance"

---------------------------------------------------------------- services
local game_ = new("DataModel")
game = game_

local services = {}
local function service(name)
	local inst = new(name)
	inst.Parent = game_
	services[name] = inst
	return inst
end

local TweenService = service("TweenService")
function TweenService:Create(inst, info, props)
	local tween = typed({ Instance = inst, Info = info, Props = props }, "Tween")
	tween.Completed = Signal()
	tween.PlaybackState = Enum.PlaybackState.Begin
	local entry
	function tween:Play()
		self.PlaybackState = Enum.PlaybackState.Playing
		entry = schedule(info.Time or 0, function()
			for k, v in props do
				inst[k] = v
			end
			self.PlaybackState = Enum.PlaybackState.Completed
			self.Completed:Fire(Enum.PlaybackState.Completed)
		end)
	end
	function tween:Cancel()
		if entry then
			entry.live = false
		end
		if self.PlaybackState == Enum.PlaybackState.Playing then
			self.PlaybackState = Enum.PlaybackState.Cancelled
			self.Completed:Fire(Enum.PlaybackState.Cancelled)
		end
	end
	return tween
end
-- instances stay typeof "Instance" for the Maid, tweens are plain tables here, so give them IsA too
Mock.Services = services

local Players = service("Players")
Players.LocalPlayer = new("Player")
local UIS = service("UserInputService")
UIS.InputBegan, UIS.InputChanged, UIS.InputEnded = Signal(), Signal(), Signal()
rawget(UIS, "_props").InputBegan, rawget(UIS, "_props").InputChanged, rawget(UIS, "_props").InputEnded = UIS.InputBegan, UIS.InputChanged, UIS.InputEnded
local CoreGui = service("CoreGui")
local HttpService = service("HttpService")

local function encode(v)
	local t = type(v)
	if t == "nil" then return "null" end
	if t == "boolean" or t == "number" then return tostring(v) end
	if t == "string" then return '"' .. v:gsub('[\\"]', "\\%0") .. '"' end
	if t == "table" then
		if #v > 0 or next(v) == nil then
			local parts = {}
			for _, x in v do table.insert(parts, encode(x)) end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local keys = {}
		for k in v do table.insert(keys, k) end
		table.sort(keys)
		local parts = {}
		for _, k in keys do table.insert(parts, encode(tostring(k)) .. ":" .. encode(v[k])) end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("cannot encode " .. t)
end
local function decode(s)
	local i = 1
	local function ws() i = s:find("%S", i) or #s + 1 end
	local value
	local function str()
		local out, j = {}, i + 1
		while true do
			local c = s:sub(j, j)
			if c == "" then error("unterminated string") end
			if c == '"' then break end
			if c == "\\" then j += 1 c = s:sub(j, j) end
			table.insert(out, c)
			j += 1
		end
		i = j + 1
		return table.concat(out)
	end
	function value()
		ws()
		local c = s:sub(i, i)
		if c == "{" then
			i += 1
			local obj = {}
			ws()
			if s:sub(i, i) == "}" then i += 1 return obj end
			while true do
				ws()
				local k = str()
				ws()
				assert(s:sub(i, i) == ":", "expected ':'")
				i += 1
				obj[k] = value()
				ws()
				local d = s:sub(i, i)
				i += 1
				if d == "}" then break end
				assert(d == ",", "expected ','")
			end
			return obj
		elseif c == "[" then
			i += 1
			local arr = {}
			ws()
			if s:sub(i, i) == "]" then i += 1 return arr end
			while true do
				table.insert(arr, value())
				ws()
				local d = s:sub(i, i)
				i += 1
				if d == "]" then break end
				assert(d == ",", "expected ','")
			end
			return arr
		elseif c == '"' then
			return str()
		elseif s:sub(i, i + 3) == "true" then i += 4 return true
		elseif s:sub(i, i + 4) == "false" then i += 5 return false
		elseif s:sub(i, i + 3) == "null" then i += 4 return nil
		else
			local num = s:match("^-?[%d%.eE+-]+", i)
			assert(num, "bad JSON at " .. i)
			i += #num
			return tonumber(num)
		end
	end
	local result = value()
	ws()
	assert(i > #s, "trailing garbage")
	return result
end
function HttpService:UrlEncode(v)
	return (tostring(v):gsub("[^%w%-_%.~]", function(c) return string.format("%%%02X", c:byte()) end))
end
function HttpService:GenerateGUID() return "00000000-0000-0000-0000-000000000000" end
function HttpService:JSONEncode(v) return encode(v) end
function HttpService:JSONDecode(s) return decode(s) end

function game_:GetService(name)
	return services[name] or service(name)
end

---------------------------------------------------------------- executor file API
local files, folders = {}, {}
Mock.Files = files
makefolder = function(p) folders[p] = true end
isfolder = function(p) return folders[p] == true end
writefile = function(p, c) files[p] = c end
readfile = function(p) assert(files[p], "no such file " .. p) return files[p] end
isfile = function(p) return files[p] ~= nil end
delfile = function(p) files[p] = nil end
listfiles = function(dir)
	local out = {}
	for p in files do
		if p:sub(1, #dir + 1) == dir .. "/" then table.insert(out, p) end
	end
	return out
end

setclipboard = function(text) Mock.Clipboard = text end

---------------------------------------------------------------- input helpers for tests
function Mock.Input(userInputType, extra)
	local input = { UserInputType = Enum.UserInputType[userInputType], Position = Vector3.new(0, 0, 0), KeyCode = Enum.KeyCode.RightShift }
	for k, v in extra or {} do
		input[k] = v
	end
	return input
end
function Mock.Key(name)
	return { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode[name], Position = Vector3.new(0, 0, 0) }
end
function Mock.Find(root, predicate)
	for _, inst in root:GetDescendants() do
		if predicate(inst) then
			return inst
		end
	end
	return nil
end
function Mock.FindAll(root, predicate)
	local out = {}
	for _, inst in root:GetDescendants() do
		if predicate(inst) then
			table.insert(out, inst)
		end
	end
	return out
end

return Mock
