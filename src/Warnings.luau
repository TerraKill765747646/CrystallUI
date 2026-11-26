local Import = ...
local Core = Import("src/Core")
local Library = Core.Library
local HttpService = game:GetService("HttpService")

local Warnings = { Log = {}, Enabled = true }
Core.Warnings = Warnings

local MAX_LOG = 100
local FILE = "CrystallUI/acknowledged.json"

local MODES = { before = "Before", after = "After", check = "Check" }

local seen = {} -- ids acknowledged during this session
local lastShown = {} -- id -> os.clock() of the last time a notice was shown
local listeners = {}
local remembered -- ids the user ticked "don't ask again" for, kept on disk when the executor allows it

----------------------------------------------------------------------------------------------------
-- remembered acknowledgements
----------------------------------------------------------------------------------------------------

local function Remembered()
	if remembered then
		return remembered
	end
	remembered = {}
	if readfile and isfile then
		local ok, content = pcall(function()
			return if isfile(FILE) then readfile(FILE) else nil
		end)
		if ok and content then
			local decoded, data = pcall(HttpService.JSONDecode, HttpService, content)
			if decoded and type(data) == "table" then
				for _, id in data do
					remembered[tostring(id)] = true
				end
			end
		end
	end
	return remembered
end

local function Remember(id)
	Remembered()[id] = true
	if writefile and makefolder and isfolder then
		pcall(function()
			if not isfolder("CrystallUI") then
				makefolder("CrystallUI")
			end
			local ids = {}
			for key in remembered do
				table.insert(ids, key)
			end
			table.sort(ids)
			writefile(FILE, HttpService:JSONEncode(ids))
		end)
	end
end

function Warnings:ClearRemembered()
	remembered = {}
	table.clear(seen)
	if delfile and isfile then
		pcall(function()
			if isfile(FILE) then
				delfile(FILE)
			end
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- log + observers
----------------------------------------------------------------------------------------------------

local function Record(spec, ctx, title, content, decision)
	local entry = {
		Time = os.time(),
		Mode = spec.Mode,
		Level = spec.Level,
		Title = title,
		Content = content,
		Source = ctx.Name,
		Decision = decision, -- Accepted | Declined | Blocked | Warned | Shown | Skipped
	}
	table.insert(Warnings.Log, entry)
	if #Warnings.Log > MAX_LOG then
		table.remove(Warnings.Log, 1)
	end
	for _, fn in table.clone(listeners) do
		task.spawn(fn, entry)
	end
end

function Warnings:OnWarning(fn)
	assert(type(fn) == "function", "[CrystallUI] OnWarning expects a function")
	table.insert(listeners, fn)
	return {
		Disconnect = function()
			local i = table.find(listeners, fn)
			if i then
				table.remove(listeners, i)
			end
		end,
	}
end

----------------------------------------------------------------------------------------------------
-- spec handling
----------------------------------------------------------------------------------------------------

local function Normalize(specs)
	if type(specs) ~= "table" then
		return {}
	end
	-- a single spec is a dictionary, several are an array of them
	if specs[1] ~= nil or next(specs) == nil then
		return specs
	end
	return { specs }
end

local function Prepare(raw, idBase, index)
	local spec = table.clone(raw)
	local mode = if type(spec.Mode) == "string" then MODES[spec.Mode:lower()] else nil
	if spec.Mode ~= nil and not mode then
		warn("[CrystallUI] Unknown warning mode '" .. tostring(spec.Mode) .. "', using Before")
	end
	spec.Mode = mode or (if spec.Mode == nil and spec.Check then "Check" else "Before")
	spec.Level = if Core.Levels[spec.Level] then spec.Level else "Warning"
	spec.Id = tostring(spec.Id or (idBase .. "#" .. index))
	if spec.Block == nil then
		spec.Block = true
	end
	return spec
end

local function Applies(spec, ctx)
	local trigger = spec.Trigger
	if trigger == nil then
		-- toggles ask when they are switched on; everything else asks every time
		trigger = if ctx.Action == "Enable" or ctx.Action == "Disable" then "Enable" else "Any"
	end
	if trigger ~= "Any" and trigger ~= ctx.Action then
		return false
	end
	if spec.When then
		local ok, result = pcall(spec.When, ctx)
		if not ok then
			warn("[CrystallUI] Warning 'When' failed: " .. tostring(result))
			return false
		end
		return result and true or false
	end
	return true
end

local function Text(value, ctx, fallback)
	if type(value) == "function" then
		local ok, result = pcall(value, ctx)
		value = if ok then result else nil
	end
	if value == nil then
		return fallback
	end
	return tostring(value)
end

local function Cooling(spec)
	local cooldown = tonumber(spec.Cooldown)
	return cooldown ~= nil and lastShown[spec.Id] ~= nil and os.clock() - lastShown[spec.Id] < cooldown
end

-- true when a notice for this spec was already acknowledged or is cooling down
local function Muted(spec)
	if spec.Once and seen[spec.Id] then
		return true
	end
	if spec.Remember and Remembered()[spec.Id] then
		return true
	end
	return Cooling(spec)
end

local function Titles(spec, ctx)
	local level = Core.Levels[spec.Level]
	return Text(spec.Title, ctx, level.title), Text(spec.Content, ctx, "")
end

-- toast or an OK dialog, never blocks the caller
local function Notice(spec, ctx, title, content, display)
	lastShown[spec.Id] = os.clock()
	if display == "Dialog" then
		Library:Dialog({
			Title = title,
			Content = content,
			Level = spec.Level,
			Buttons = { { Name = spec.Ok or "OK", Style = if spec.Level == "Danger" then "Danger" else "Primary" } },
		})
	else
		Library:Notify({
			Title = title,
			Content = content,
			Type = Core.Levels[spec.Level].notify,
			Duration = spec.Duration or 6,
		})
	end
end

local function Before(spec, ctx)
	local title, content = Titles(spec, ctx)
	if not Warnings.Enabled then
		Record(spec, ctx, title, content, "Skipped")
		return true
	end
	if Muted(spec) then
		return true
	end
	local modal
	local accepted, ticked = Core.Await(function(resolve)
		modal = Library:Dialog({
			Title = title,
			Content = content,
			Level = spec.Level,
			Checkbox = if spec.Remember then (spec.RememberText or "Don't ask again") else nil,
			OnClose = function()
				resolve(false)
			end,
			Buttons = {
				{
					Name = spec.No or "Cancel",
					Callback = function()
						resolve(false)
					end,
				},
				{
					Name = spec.Yes or "Continue",
					Style = if spec.Level == "Danger" then "Danger" else "Primary",
					Delay = spec.Delay,
					Callback = function()
						resolve(true, modal and modal.Checked)
					end,
				},
			},
		})
	end)
	lastShown[spec.Id] = os.clock()
	if accepted then
		seen[spec.Id] = true
		if spec.Remember and ticked then
			Remember(spec.Id)
		end
	end
	Record(spec, ctx, title, content, if accepted then "Accepted" else "Declined")
	return accepted == true
end

local function Check(spec, ctx)
	local ran, ok, message = pcall(spec.Check, ctx)
	if not ran then
		warn("[CrystallUI] Warning check failed to run: " .. tostring(ok))
		ok, message = false, "The check could not run"
	end
	if ok then
		return true
	end
	local title, content = Titles(spec, ctx)
	if type(message) == "string" and message ~= "" then
		content = message
	end
	local blocks = spec.Block ~= false
	-- A blocking check always blocks. Its notice only backs off during a Cooldown (so repeated clicks
	-- don't spam), while a non-blocking one is a plain warning and also honours Once and Remember.
	local silent = if blocks then Cooling(spec) else Muted(spec)
	if not silent and (Warnings.Enabled or blocks) then
		Notice(spec, ctx, title, content, spec.Display or "Toast")
		if spec.Once then
			seen[spec.Id] = true
		end
	end
	Record(spec, ctx, title, content, if blocks then "Blocked" else "Warned")
	return not blocks
end

local function After(spec, ctx)
	if not Warnings.Enabled or Muted(spec) then
		return
	end
	local title, content = Titles(spec, ctx)
	Notice(spec, ctx, title, content, spec.Display or "Toast")
	seen[spec.Id] = true
	Record(spec, ctx, title, content, "Shown")
end

----------------------------------------------------------------------------------------------------
-- public
----------------------------------------------------------------------------------------------------

--[[
Warnings:Guard(specs, ctx, apply, idBase) -> boolean
	specs  one warning or a list of them, each:
		Mode      "Before" (ask first, default) | "After" (notice once the action ran) | "Check" (run Check first)
		Level     "Info" | "Success" | "Warning" (default) | "Danger"
		Title, Content   strings or function(ctx) -> string
		Check     function(ctx) -> ok, message   (Mode "Check")
		Block     false lets a failed check through after warning (default true)
		Display   "Toast" (default for After and Check) | "Dialog"
		Trigger   "Enable" | "Disable" | "Any", toggles default to "Enable", everything else to "Any"
		When      function(ctx) -> boolean, the warning only applies when it returns true
		Once      show only the first time this session
		Remember  adds a "Don't ask again" tick box, the answer is kept on disk
		Cooldown  seconds before the same notice may appear again
		Delay     seconds the Continue button stays locked (Mode "Before")
		Yes, No, Ok, Duration, Id
	ctx    { Name, Action, Value, Old, Element }
	apply  runs when nothing blocked the action
Yields while a confirmation dialog is open, so call it from a thread that may yield.
]]
function Warnings:Guard(specs, ctx, apply, idBase)
	ctx = ctx or {}
	idBase = tostring(idBase or ctx.Name or "guard")
	local after = {}
	for index, raw in Normalize(specs) do
		local spec = Prepare(raw, idBase, index)
		if Applies(spec, ctx) then
			if spec.Mode == "Before" then
				if not Before(spec, ctx) then
					return false
				end
			elseif spec.Mode == "Check" then
				if not Check(spec, ctx) then
					return false
				end
			else
				table.insert(after, spec)
			end
		end
	end
	if apply then
		apply()
	end
	for _, spec in after do
		task.spawn(After, spec, ctx)
	end
	return true
end

-- Library:Guard(specs, fn, ctx?) runs `fn` only if the warnings allow it, returns whether it ran
function Library:Guard(specs, fn, ctx)
	return Warnings:Guard(specs, ctx, fn)
end

-- Library:Warn("text") or Library:Warn({ Title, Content, Level, Display = "Toast" | "Dialog", ... })
function Library:Warn(spec)
	if type(spec) == "string" then
		spec = { Content = spec }
	end
	spec = Prepare(spec or {}, "warn", 1)
	spec.Mode = "After"
	local ctx = { Name = spec.Title, Action = "Any" }
	if not Warnings.Enabled or Muted(spec) then
		return false
	end
	local title, content = Titles(spec, ctx)
	Notice(spec, ctx, title, content, spec.Display or "Toast")
	seen[spec.Id] = true
	Record(spec, ctx, title, content, "Shown")
	return true
end

-- false turns confirmations and notices off: "Before" asks are accepted automatically,
-- "After" notices are skipped. Blocking checks stay in force.
function Library:SetWarnings(state)
	Warnings.Enabled = state ~= false
end

function Library:OnWarning(fn)
	return Warnings:OnWarning(fn)
end

function Library:GetWarningLog()
	return table.clone(Warnings.Log)
end

Library.Warnings = Warnings

return Warnings
