--[[
	CrystallUI test suite.

	In an executor (the UI is built for real, give it a second to settle):
		local Library = loadstring(game:HttpGet(REPO .. "Init.luau"))()
		loadstring(game:HttpGet(REPO .. "Tests.luau"))()(Library)

	Headless: `python3 tests/run.py` (needs the `luau` binary in PATH).

	The suite only uses the public API, so it works against both. It creates and destroys
	its own windows, but it does call Library:Destroy() at the end, so run it in a fresh session.
]]

local Library = ...
if type(Library) ~= "table" then
	Library = (getgenv and getgenv().CrystallUI) or error("[Tests] pass the Library as the first argument")
end

local passed, failed, failures = 0, 0, {}

local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  PASS  " .. name)
	else
		failed += 1
		table.insert(failures, name .. ": " .. tostring(err))
		print("  FAIL  " .. name .. "\n        " .. tostring(err))
	end
end

local function eq(actual, expected, label)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", label or "value", tostring(expected), tostring(actual)), 2)
	end
end

local function truthy(value, label)
	if not value then
		error((label or "value") .. " is falsy", 2)
	end
end

local function throws(fn, label)
	local ok = pcall(fn)
	if ok then
		error((label or "call") .. " was expected to throw", 2)
	end
end

local function sameSet(list, expected, label)
	local a, b = table.clone(list), table.clone(expected)
	table.sort(a)
	table.sort(b)
	eq(table.concat(a, ","), table.concat(b, ","), label)
end

local function settle(seconds)
	task.wait(seconds or 0.5)
end

----------------------------------------------------------------------------------------------------

local win = Library:CreateWindow({ Name = "Tests", Subtitle = "CrystallUI", ToggleKey = "F" })
local tabMain = win:CreateTab("Main")
local tabOther = win:CreateTab("Other")
local section = tabMain:CreateSection("Controls", { Collapsible = true })

print("\n[Window]")

test("window exposes expected structure", function()
	truthy(win.Main, "Main")
	eq(#win.Tabs, 2, "tab count")
	eq(win.Selected, tabMain, "first tab auto-selected")
end)

test("SelectTab by name, index and object", function()
	eq(win:SelectTab("Other"), tabOther, "by name")
	eq(win.Selected, tabOther, "selected")
	eq(win:SelectTab(1), tabMain, "by index")
	eq(win:SelectTab(tabOther), tabOther, "by object")
	eq(win:SelectTab("nope"), nil, "unknown tab")
	win:SelectTab(tabMain)
end)

test("Toggle hides and shows the window", function()
	eq(win.Visible, true, "initial")
	win:Toggle(false)
	eq(win.Visible, false, "after hide")
	settle(1)
	eq(win.Main.Visible, false, "Main hidden after animation")
	win:Toggle(true)
	eq(win.Main.Visible, true, "Main visible")
	settle(1)
end)

test("Minimize round trip", function()
	win:Minimize(true)
	eq(win.Minimized, true, "minimized")
	win:Minimize(false)
	eq(win.Minimized, false, "restored")
	settle(1)
end)

test("ToggleKey can be changed and disabled", function()
	win:SetToggleKey("G")
	eq(win.ToggleKey.Name, "G", "key")
	win:SetToggleKey("NotARealKey")
	eq(win.ToggleKey, nil, "invalid key clears it")
	win:SetToggleKey("F")
end)

test("sections collapse and rename", function()
	section:SetCollapsed(true)
	eq(section.Collapsed, true, "collapsed")
	eq(section.Container.Visible, false, "container hidden")
	section:SetCollapsed(false)
	eq(section.Container.Visible, true, "container shown")
	section:SetTitle("Renamed")
	eq(section.Title.Text, "RENAMED", "title")
	section:SetTitle("Controls")
end)

print("\n[Controls]")

test("button fires its callback through the element API", function()
	local clicks = 0
	local button = section:CreateButton({ Name = "Press", Callback = function() clicks += 1 end })
	truthy(button.Instance, "Instance")
	button:SetTitle("Pressed")
	button:SetVisible(false)
	button:SetVisible(true)
	button:Destroy()
	eq(clicks, 0, "callback never fires without a click")
end)

test("toggle Set/Get and callback semantics", function()
	local seen = {}
	local toggle = section:CreateToggle({
		Name = "T",
		Flag = "t_flag",
		CurrentValue = false,
		Callback = function(v) table.insert(seen, v) end,
	})
	eq(toggle:Get(), false, "initial")
	toggle:Set(true)
	eq(toggle:Get(), true, "after Set(true)")
	toggle:Set(false, true)
	eq(toggle:Get(), false, "after silent Set(false)")
	toggle:Set("truthy but not true")
	eq(toggle:Get(), false, "non-boolean is coerced strictly")
	eq(#seen, 2, "callbacks: silent calls must not fire")
	eq(seen[1], true, "first callback value")
	eq(Library:GetFlag("t_flag"), false, "flag lookup")
	toggle:Destroy()
	eq(Library.Flags.t_flag, nil, "flag removed on Destroy")
end)

test("slider clamps, snaps and ignores garbage", function()
	local last
	local slider = section:CreateSlider({
		Name = "S", Flag = "s_flag", Range = { 0, 10 }, Increment = 0.5, CurrentValue = 3,
		Callback = function(v) last = v end,
	})
	eq(slider:Get(), 3, "initial")
	slider:Set(7.3)
	eq(slider:Get(), 7.5, "snapped to increment")
	eq(last, 7.5, "callback value")
	slider:Set(999)
	eq(slider:Get(), 10, "clamped to max")
	slider:Set(-5)
	eq(slider:Get(), 0, "clamped to min")
	slider:Set("abc")
	eq(slider:Get(), 0, "garbage leaves value alone")
	slider:Set("4.2")
	eq(slider:Get(), 4, "numeric strings are accepted")
	slider:Destroy()
end)

test("slider survives a broken increment or reversed range", function()
	local slider = section:CreateSlider({ Name = "S2", Range = { 10, 0 }, Increment = 0, CurrentValue = 5 })
	eq(slider:Get(), 5, "value")
	slider:Set(2.4)
	eq(slider:Get(), 2, "falls back to increment 1")
	slider:Destroy()
end)

test("dropdown single select", function()
	local last
	local dd = section:CreateDropdown({
		Name = "D", Flag = "d_flag", Options = { "A", "B", "C" }, CurrentOption = "B",
		Callback = function(v) last = v end,
	})
	eq(dd:Get(), "B", "initial")
	dd:Set("C")
	eq(dd:Get(), "C", "Set")
	eq(last, "C", "callback")
	dd:Set("missing")
	eq(dd:Get(), nil, "unknown option clears")
	dd:Set({ "A", "B" })
	eq(dd:Get(), "A", "table input keeps the first entry only")
	dd:SetOpen(true)
	eq(dd.Open, true, "open")
	dd:SetOpen(false)
	dd:Destroy()
end)

test("dropdown multi select and Refresh", function()
	local dd = section:CreateDropdown({ Name = "M", Options = { "A", "B", "C" }, Multi = true, CurrentOption = { "A", "C" } })
	sameSet(dd:Get(), { "A", "C" }, "initial")
	dd:Refresh({ "B", "C", "D" }, true)
	sameSet(dd:Get(), { "C" }, "Refresh keeps only options that still exist")
	dd:Refresh({ "X", "Y" }, false)
	sameSet(dd:Get(), {}, "Refresh without keepSelection clears")
	dd:Destroy()
end)

test("checklist select all / clear / Set", function()
	local last
	local list = section:CreateChecklist({
		Name = "C", Flag = "c_flag", Options = { "one", "two", "three" }, CurrentValue = { "two" },
		Callback = function(v) last = v end,
	})
	sameSet(list:Get(), { "two" }, "initial")
	list:Set({ "one", "three", "ghost" })
	sameSet(list:Get(), { "one", "three" }, "unknown entries ignored")
	sameSet(last, { "one", "three" }, "callback")
	list:Set({}, true)
	sameSet(list:Get(), {}, "cleared")
	list:Destroy()
end)

test("keybind accepts names and EnumItems, rejects junk", function()
	local changed
	local bind = section:CreateKeybind({ Name = "K", Flag = "k_flag", CurrentKeybind = "F", ChangedCallback = function(k) changed = k end })
	eq(bind:Get(), "F", "initial")
	bind:Set("G")
	eq(bind:Get(), "G", "by name")
	eq(changed.Name, "G", "callback gets the EnumItem")
	bind:Set("NotAKey")
	eq(bind:Get(), "None", "invalid name becomes None")
	bind:Set(nil, true)
	eq(bind:Get(), "None", "nil")
	bind:Destroy()
end)

test("input Set/Get", function()
	local last
	local input = section:CreateInput({ Name = "I", Flag = "i_flag", CurrentValue = "hi", Callback = function(v) last = v end })
	eq(input:Get(), "hi", "initial")
	input:Set("changed")
	eq(input:Get(), "changed", "Set")
	eq(last, "changed", "callback")
	input:Set(123, true)
	eq(input:Get(), "123", "numbers become strings")
	input:Set(nil, true)
	eq(input:Get(), "", "nil becomes empty")
	input:Destroy()
end)

test("label, paragraph and divider", function()
	local label = section:CreateLabel("plain string")
	label:Set("updated")
	local paragraph = section:CreateParagraph({ Title = "T", Content = "C" })
	paragraph:Set("only content")
	paragraph:Set({ Title = "New title" })
	local divider = section:CreateDivider()
	truthy(divider.Instance, "divider instance")
	label:Destroy()
	paragraph:Destroy()
	divider:Destroy()
end)

test("elements work directly on a tab (no section)", function()
	local toggle = tabOther:CreateToggle({ Name = "Direct", CurrentValue = true })
	eq(toggle:Get(), true, "value")
	toggle:Destroy()
end)

print("\n[Config]")

test("export/import round trip, including JSON", function()
	local toggle = section:CreateToggle({ Name = "T", Flag = "cfg_toggle", CurrentValue = true })
	local slider = section:CreateSlider({ Name = "S", Flag = "cfg_slider", Range = { 0, 100 }, CurrentValue = 25 })
	local list = section:CreateChecklist({ Name = "C", Flag = "cfg_list", Options = { "a", "b" }, CurrentValue = { "a" } })
	local json = Library:ExportConfig()
	eq(type(json), "string", "JSON export")
	local data = Library:ExportConfig(true)
	eq(data.cfg_toggle, true, "toggle in table export")
	eq(data.cfg_slider, 25, "slider in table export")

	toggle:Set(false, true)
	slider:Set(80, true)
	list:Set({ "b" }, true)
	local ok = Library:ImportConfig(json)
	eq(ok, true, "import ok")
	eq(toggle:Get(), true, "toggle restored")
	eq(slider:Get(), 25, "slider restored")
	sameSet(list:Get(), { "a" }, "list restored")

	local bad, reason = Library:ImportConfig("{not json")
	eq(bad, false, "bad JSON rejected")
	truthy(reason, "reason given")
	local ignored = Library:ImportConfig({ unknown_flag = 1 })
	eq(ignored, true, "unknown flags are skipped, not fatal")

	toggle:Destroy()
	slider:Destroy()
	list:Destroy()
end)

test("save/load config via the file API (skipped when unavailable)", function()
	if not (writefile and readfile and isfile) then
		return
	end
	local toggle = section:CreateToggle({ Name = "T", Flag = "file_toggle", CurrentValue = true })
	local saved = Library:SaveConfig("_crystall_test")
	eq(saved, true, "save")
	toggle:Set(false, true)
	local loaded = Library:LoadConfig("_crystall_test")
	eq(loaded, true, "load")
	eq(toggle:Get(), true, "value restored from disk")
	local names = Library:ListConfigs()
	truthy(table.find(names, "_crystall_test"), "listed")
	local missing = Library:LoadConfig("_definitely_missing_")
	eq(missing, false, "missing config")
	if delfile then
		pcall(delfile, "CrystallUI/configs/_crystall_test.json")
	end
	toggle:Destroy()
end)

print("\n[Theme]")

test("palette switching and unknown names", function()
	local before = Library.Theme.PaletteName
	Library:SetPalette("Emerald")
	eq(Library.Theme.PaletteName, "Emerald", "palette")
	eq(Library.Theme:Get("Accent"), Library.Theme.Palettes.Emerald.Accent, "Get reads the active palette")
	throws(function() Library:SetPalette("Nope") end, "unknown palette")
	Library:SetPalette(before)
end)

test("keepMotion keeps the motion profile", function()
	Library:SetMotion("Minimal")
	Library:SetPalette("RoyalTopaz", true)
	eq(Library.Theme.MotionName, "Minimal", "motion untouched")
	Library:SetPalette("RoyalTopaz")
	eq(Library.Theme.MotionName, "Brutal", "default motion applied")
	Library:SetPalette("Amethyst")
end)

test("SetTheme applies palette and motion together", function()
	Library:SetTheme({ Palette = "Quartz", Motion = "Instant" })
	eq(Library.Theme.PaletteName, "Quartz", "palette")
	eq(Library.Theme.MotionName, "Instant", "motion")
	Library:SetTheme({ Palette = "Amethyst", Motion = "Minimal" })
end)

test("custom palettes inherit and validate", function()
	local palette = Library:RegisterPalette("TestRed", { Accent = Color3.fromRGB(255, 0, 0) })
	eq(palette.Accent.R, 1, "override applied")
	truthy(palette.Background, "missing keys inherited from the default")
	throws(function() Library:RegisterPalette("Broken", { Accent = "red" }) end, "non-Color3 value")
	throws(function() Library:RegisterPalette("", {}) end, "empty name")
	Library:SetPalette("TestRed")
	Library:SetPalette("Amethyst")
end)

test("custom motion inherits and can be selected", function()
	local motion = Library:RegisterMotion("TestSlow", { Duration = 1 })
	eq(motion.Duration, 1, "override")
	truthy(motion.Style, "inherited style")
	Library:SetMotion("TestSlow")
	eq(Library.Theme.Motion.Duration, 1, "active")
	Library:SetMotion("Minimal")
end)

test("OnChanged fires and disconnects", function()
	local events = {}
	local conn = Library.Theme:OnChanged(function(kind, name) table.insert(events, kind .. ":" .. name) end)
	Library:SetPalette("Emerald", true)
	settle(0.1)
	conn.Disconnect()
	Library:SetPalette("Amethyst", true)
	settle(0.1)
	eq(#events, 1, "only the first change was observed")
	eq(events[1], "Palette:Emerald", "event payload")
end)

test("palette/motion listings are sorted and complete", function()
	local palettes = Library.Theme:ListPalettes()
	truthy(table.find(palettes, "Amethyst"), "Amethyst")
	truthy(table.find(palettes, "Quartz"), "Quartz")
	truthy(table.find(Library.Theme:ListMotions(), "Brutal"), "Brutal")
end)

print("\n[Notifications]")

local Notifications = Library.Notifications

test("notifications queue beyond Max and drain on close", function()
	local handles = {}
	for i = 1, Notifications.Max + 2 do
		handles[i] = Library:Notify({ Title = "N" .. i, Content = "body", Duration = 30 })
	end
	eq(Notifications.Active, Notifications.Max, "active is capped")
	eq(#Notifications.Queue, 2, "the rest wait")
	handles[1]:Close()
	settle(0.3)
	eq(Notifications.Active, Notifications.Max, "queue refilled a slot")
	eq(#Notifications.Queue, 1, "queue shrank")
	handles[1]:Close()
	for _, handle in handles do
		handle:Close()
	end
	settle(1)
	eq(Notifications.Active, 0, "all released")
	eq(#Notifications.Queue, 0, "queue empty")
end)

test("closing a queued notification skips it", function()
	local handles = {}
	for i = 1, Notifications.Max + 1 do
		handles[i] = Library:Notify({ Content = "n", Duration = 30 })
	end
	local queued = handles[#handles]
	queued:Close()
	eq(#Notifications.Queue, 1, "still in the queue list until drained")
	handles[1]:Close()
	settle(0.3)
	eq(Notifications.Active, Notifications.Max - 1, "closed entry was never shown")
	for _, handle in handles do
		handle:Close()
	end
	settle(1)
	eq(Notifications.Active, 0, "clean")
end)

test("duration expires on its own", function()
	Library:Notify({ Content = "short", Duration = 0.2 })
	eq(Notifications.Active, 1, "shown")
	settle(1.5)
	eq(Notifications.Active, 0, "expired")
end)

test("sticky notifications stay until closed", function()
	local handle = Library:Notify({ Content = "sticky", Duration = 0 })
	settle(6)
	eq(Notifications.Active, 1, "still here")
	handle:Close()
	settle(1)
	eq(Notifications.Active, 0, "closed")
end)

test("string shorthand and actions", function()
	local fired = false
	local handle = Library:Notify("just text")
	handle:Close()
	local withActions = Library:Notify({
		Title = "Act", Content = "x", Duration = 30,
		Actions = { { Name = "Do", Callback = function() fired = true end }, { Name = "Skip" } },
	})
	withActions:Close()
	settle(1)
	eq(fired, false, "callbacks only fire on click")
	eq(Notifications.Active, 0, "clean")
	local weird = Library:Notify(nil)
	weird:Close()
	local weird2 = Library:Notify(42)
	weird2:Close()
	settle(1)
end)

print("\n[Lifecycle]")

test("destroying an element frees its flag and its window-maid slot", function()
	local before = #win.Maid.Tasks
	local toggle = section:CreateToggle({ Name = "tmp", Flag = "life_flag" })
	eq(#win.Maid.Tasks > before, true, "registered")
	toggle:Destroy()
	eq(#win.Maid.Tasks, before, "unregistered")
	eq(Library.Flags.life_flag, nil, "flag removed")
end)

test("duplicate flags warn instead of failing silently", function()
	local a = section:CreateToggle({ Name = "a", Flag = "dup" })
	local b = section:CreateToggle({ Name = "b", Flag = "dup" })
	eq(Library.Flags.dup, b, "last registration wins")
	a:Destroy()
	eq(Library.Flags.dup, b, "destroying the loser does not drop the winner's flag")
	b:Destroy()
end)

test("section Destroy removes it from the tab", function()
	local extra = tabMain:CreateSection("Temp")
	local count = #tabMain.Sections
	extra:Destroy()
	eq(#tabMain.Sections, count - 1, "section list")
end)

test("second window and Window:Destroy", function()
	local other = Library:CreateWindow({ Name = "Second", Search = false })
	other:CreateTab("T")
	local count = #Library.Windows
	other:Destroy()
	eq(#Library.Windows, count - 1, "window removed")
end)

test("Library:Destroy tears everything down", function()
	Library:Destroy()
	eq(#Library.Windows, 0, "no windows")
	eq(next(Library.Flags), nil, "no flags")
	eq(Notifications.Active, 0, "no notifications")
end)

----------------------------------------------------------------------------------------------------

print(string.format("\n%d passed, %d failed", passed, failed))
for _, line in failures do
	print("  - " .. line)
end

return { Passed = passed, Failed = failed, Failures = failures }
