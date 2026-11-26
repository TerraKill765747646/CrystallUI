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

test("floating toggle button follows MobileButton", function()
	eq(win.ToggleButton, nil, "off by default without touch")
	local w = Library:CreateWindow({ Name = "Mobile", MobileButton = true })
	truthy(w.ToggleButton, "created when forced on")
	w:SetMobileButton(false)
	eq(w.ToggleButton.Visible, false, "hidden")
	w:SetMobileButton(true)
	eq(w.ToggleButton.Visible, true, "shown again")
	local off = Library:CreateWindow({ Name = "NoMobile", MobileButton = false })
	eq(off.ToggleButton, nil, "forced off")
	off:SetMobileButton(true)
	truthy(off.ToggleButton, "can be enabled later")
	w:Destroy()
	off:Destroy()
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

print("\n[Extra controls]")

test("colour picker Set/Get/hex and config export", function()
	local last
	local picker = section:CreateColorPicker({ Name = "C", Flag = "cp_flag", CurrentValue = "#336699", Callback = function(c) last = c end })
	eq(picker:GetHex(), "#336699", "initial from hex")
	picker:Set("#FF8000")
	eq(picker:GetHex(), "#FF8000", "Set(hex)")
	truthy(math.abs(picker:Get().G - 128 / 255) < 0.01, "green channel")
	truthy(last, "callback fired")
	last = nil
	picker:Set(Color3.fromRGB(10, 20, 30), true)
	eq(picker:GetHex(), "#0A141E", "Set(Color3), silent")
	eq(last, nil, "silent")
	picker:Set("not a colour")
	eq(picker:GetHex(), "#0A141E", "garbage is ignored")
	picker:Set("#abc")
	eq(picker:GetHex(), "#AABBCC", "short hex")
	picker:Set("#000000")
	picker:Set("#FF0000", true)
	eq(picker:GetHex(), "#FF0000", "recovers from black")

	local data = Library:ExportConfig(true)
	eq(data.cp_flag, "#FF0000", "colours are exported as hex strings")
	picker:Set("#00FF00", true)
	eq(Library:ImportConfig(Library:ExportConfig()), true, "json round trip")
	picker:Set("#0000FF", true)
	Library:ImportConfig({ cp_flag = "#123456" })
	eq(picker:GetHex(), "#123456", "import")
	picker:Destroy()
end)

test("SetLocked works on any element and via the Locked option", function()
	local toggle = section:CreateToggle({ Name = "L", Locked = true })
	eq(toggle.Locked, true, "locked from the start")
	toggle:SetLocked(false)
	eq(toggle.Locked, false, "unlocked")
	toggle:Set(true)
	eq(toggle:Get(), true, "code can still Set a locked element")
	toggle:Destroy()

	local dd = section:CreateDropdown({ Name = "D", Options = { "a" } })
	dd:SetOpen(true)
	dd:SetLocked(true)
	eq(dd.Open, false, "locking closes a dropdown")
	dd:SetOpen(true)
	eq(dd.Open, false, "and it can't be reopened")
	dd:Destroy()
end)

test("opening a dropdown closes the other one; switching tabs closes both", function()
	local a = section:CreateDropdown({ Name = "A", Options = { "1" } })
	local b = section:CreateDropdown({ Name = "B", Options = { "1" } })
	a:SetOpen(true)
	b:SetOpen(true)
	eq(a.Open, false, "first closed")
	eq(b.Open, true, "second open")
	win:SelectTab(tabOther)
	eq(b.Open, false, "tab switch closes it")
	win:SelectTab(tabMain)
	a:Destroy()
	b:Destroy()
end)

test("the theme is part of the config", function()
	local before = Library.Theme.PaletteName
	Library:SetPalette("Emerald")
	local json = Library:ExportConfig()
	local data = Library:ExportConfig(true)
	eq(data.__theme.Palette, "Emerald", "exported")
	Library:SetPalette(before)
	Library:ImportConfig(json)
	eq(Library.Theme.PaletteName, "Emerald", "imported")
	Library:ImportConfig({ __theme = { Palette = "NoSuchPalette" } })
	eq(Library.Theme.PaletteName, "Emerald", "unknown palette is ignored")
	Library:SetPalette(before)
end)

print("\n[Dialogs]")

test("Dialog returns a closable modal; Confirm resolves false when closed", function()
	local closed = 0
	local dialog = Library:Dialog({ Title = "Hello", Content = "World", OnClose = function() closed += 1 end })
	eq(dialog.Closed, false, "open")
	dialog:Close()
	dialog:Close()
	eq(dialog.Closed, true, "closed")
	eq(closed, 1, "OnClose fires once")
	settle(1)

	local answer = "unset"
	task.spawn(function()
		answer = Library:Confirm({ Title = "Sure?" })
	end)
	settle(0.3)
	eq(answer, "unset", "still waiting")
	local modal = next(Library.Modals)
	truthy(modal, "modal shown")
	modal:Close()
	settle(1)
	eq(answer, false, "closing counts as no")
end)

print("\n[Key system]")

local function submit(handle, text)
	handle:Submit(text)
	settle(2)
end

test("fixed key: wrong, right, trimmed, callbacks", function()
	local accepted
	local handle = Library:KeySystem({ Async = true, Key = "secret", Cooldown = 0, OnSuccess = function(k) accepted = k end })
	settle(0.3)
	submit(handle, "wrong")
	eq(handle.Finished, false, "wrong key does not finish")
	eq(handle.Attempts, 1, "attempts")
	submit(handle, "")
	eq(handle.Attempts, 1, "empty input is not an attempt")
	submit(handle, "  secret ")
	eq(handle.Ok, true, "accepted")
	eq(handle.Key, "secret", "trimmed key")
	eq(accepted, "secret", "OnSuccess")
end)

test("several keys and case-insensitive mode", function()
	local handle = Library:KeySystem({ Async = true, Keys = { "Alpha", "Beta" }, CaseSensitive = false, Cooldown = 0 })
	settle(0.3)
	submit(handle, "BETA")
	eq(handle.Ok, true, "case-insensitive match")

	local strict = Library:KeySystem({ Async = true, Keys = { "Alpha" }, Cooldown = 0 })
	settle(0.3)
	submit(strict, "alpha")
	eq(strict.Finished, false, "case-sensitive by default")
	strict:Close()
	settle(1)
end)

test("custom validator with a message", function()
	local calls = {}
	local handle = Library:KeySystem({
		Async = true, Cooldown = 0,
		Validate = function(key) table.insert(calls, key); return key == "good", "Expired key" end,
	})
	settle(0.3)
	submit(handle, "bad")
	eq(handle.Finished, false, "rejected")
	submit(handle, "good")
	eq(handle.Ok, true, "accepted")
	eq(#calls, 2, "validator called per attempt")
end)

test("a throwing validator is a failed attempt, not a crash", function()
	local handle = Library:KeySystem({ Async = true, Cooldown = 0, Validate = function() error("boom") end })
	settle(0.3)
	submit(handle, "x")
	eq(handle.Finished, false, "still waiting for a valid key")
	handle:Close()
	settle(1)
end)

test("API: url is encoded, {key}/{hwid} substituted, default success is strict", function()
	local seen
	local reply = { StatusCode = 200, Body = '{"valid":true}' }
	local handle = Library:KeySystem({
		Async = true, Cooldown = 0,
		Api = {
			Url = "https://example.com/check?key={key}&hwid={hwid}",
			Request = function(req) seen = req; return reply end,
		},
	})
	settle(0.3)

	reply = { StatusCode = 200, Body = "Invalid key, sorry" }
	submit(handle, "a b&c")
	eq(handle.Finished, false, "a 200 with an error page does not unlock")
	truthy(seen.Url:find("key=a%%20b%%26c"), "key is url-encoded: " .. tostring(seen.Url))
	truthy(not seen.Url:find("{hwid}", 1, true), "hwid substituted")
	eq(seen.Method, "GET", "GET by default")

	reply = { StatusCode = 500, Body = '{"valid":true}' }
	submit(handle, "k")
	eq(handle.Finished, false, "server error")

	reply = { StatusCode = 200, Body = '{"success":false,"message":"expired"}' }
	submit(handle, "k")
	eq(handle.Finished, false, "explicit failure")

	reply = { StatusCode = 200, Body = '{"valid":true}' }
	submit(handle, "k")
	eq(handle.Ok, true, "valid:true unlocks")
end)

test("API: POST with a JSON body, headers and a custom Success", function()
	local seen
	local handle = Library:KeySystem({
		Async = true, Cooldown = 0,
		Api = {
			Url = "https://example.com/verify",
			Body = { key = "{key}", product = "demo" },
			Headers = { Authorization = "Bearer abc" },
			Request = function(req) seen = req; return { StatusCode = 201, Body = "granted" } end,
			Success = function(response) return response.StatusCode == 201 and response.Body == "granted", "nope" end,
		},
	})
	settle(0.3)
	submit(handle, "K-1")
	eq(handle.Ok, true, "custom Success decides")
	eq(seen.Method, "POST", "POST when a body is given")
	eq(seen.Headers["Content-Type"], "application/json", "content type added")
	eq(seen.Headers.Authorization, "Bearer abc", "headers kept")
	truthy(seen.Body:find('"key":"K-1"', 1, true), "key substituted inside the JSON body")
end)

test("API: a hanging server times out", function()
	local handle = Library:KeySystem({
		Async = true, Cooldown = 0, Timeout = 0.3,
		Api = { Url = "https://example.com/slow", Request = function() task.wait(30); return { StatusCode = 200, Body = "true" } end },
	})
	settle(0.3)
	handle:Submit("k")
	settle(3)
	eq(handle.Finished, false, "a late answer must not unlock after the timeout")
	handle:Close()
	settle(1)
end)

test("API errors do not unlock", function()
	local handle = Library:KeySystem({
		Async = true, Cooldown = 0,
		Api = { Url = "https://example.com", Request = function() error("network down") end },
	})
	settle(0.3)
	submit(handle, "k")
	eq(handle.Finished, false, "request error")
	handle:Close()
	settle(1)
end)

test("MaxAttempts locks the prompt", function()
	local reason
	local handle = Library:KeySystem({ Async = true, Key = "k", MaxAttempts = 2, Cooldown = 0, OnFail = function(r) reason = r end })
	settle(0.3)
	submit(handle, "1")
	eq(handle.Finished, false, "first miss")
	submit(handle, "2")
	settle(2)
	eq(handle.Finished, true, "second miss ends it")
	eq(handle.Ok, false, "failed")
	eq(reason, "Too many attempts", "reason")
	handle:Submit("k")
	settle(1)
	eq(handle.Ok, false, "no way back in after the lock")
end)

test("Cooldown blocks rapid attempts", function()
	local handle = Library:KeySystem({ Async = true, Key = "k", Cooldown = 60 })
	settle(0.3)
	handle:Submit("1")
	settle(0.2)
	handle:Submit("2")
	settle(0.2)
	eq(handle.Attempts, 1, "second attempt was refused")
	handle:Close()
	settle(1)
end)

test("blocking mode returns ok, key", function()
	local ok, key = "unset", nil
	task.spawn(function()
		ok, key = Library:KeySystem({
			Key = "pass", Cooldown = 0,
			OnReady = function(handle) handle:Submit("pass") end,
		})
	end)
	settle(2)
	eq(ok, true, "ok")
	eq(key, "pass", "key")

	local closedOk = "unset"
	task.spawn(function()
		closedOk = Library:KeySystem({ Key = "pass", OnReady = function(handle) handle:Close() end })
	end)
	settle(1)
	eq(closedOk, false, "closing returns false")
end)

test("saved key skips the prompt; a stale one is forgotten", function()
	if not (writefile and readfile and isfile and delfile) then
		return
	end
	Library:ForgetKey("_crystall_test")
	local first = Library:KeySystem({ Async = true, Key = "abc", SaveKey = true, Id = "_crystall_test", Cooldown = 0 })
	settle(0.3)
	submit(first, "abc")
	eq(first.Ok, true, "accepted and saved")

	local second = Library:KeySystem({ Async = true, Key = "abc", SaveKey = true, Id = "_crystall_test" })
	settle(1)
	eq(second.Ok, true, "saved key accepted without a prompt")
	eq(second.Modal, nil, "no UI was built")

	local third = Library:KeySystem({ Async = true, Key = "changed", SaveKey = true, Id = "_crystall_test" })
	settle(1)
	eq(third.Finished, false, "a key that no longer matches shows the prompt again")
	truthy(third.Modal, "prompt shown")
	third:Close()
	settle(1)
	local fourth = Library:KeySystem({ Async = true, Key = "abc", SaveKey = true, Id = "_crystall_test" })
	settle(1)
	eq(fourth.Finished, false, "the stale key was deleted")
	fourth:Close()
	settle(1)
	Library:ForgetKey("_crystall_test")
end)

test("a key system needs a key source", function()
	throws(function() Library:KeySystem({}) end, "empty options")
end)

print("\n[Warnings]")

-- runs Library:Guard in its own thread (a dialog makes it wait) and reports what happened
local function guard(specs, ctx)
	local result = { applied = 0 }
	task.spawn(function()
		result.allowed = Library:Guard(specs, function()
			result.applied += 1
		end, ctx or { Name = "test", Action = "Click" })
		result.done = true
	end)
	return result
end

local function openDialog()
	settle(0.3)
	return next(Library.Modals)
end

local function toasts()
	return Library.Notifications.Active
end

test("Before: confirming runs the action, Cancel and the X do not", function()
	local run = guard({ Title = "Sure?", Content = "This is risky." })
	local modal = openDialog()
	truthy(modal, "dialog shown")
	eq(run.applied, 0, "nothing runs while the question is open")
	eq(run.done, nil, "the caller waits")
	eq(modal:Press("Continue"), true, "Continue is pressable")
	settle(0.5)
	eq(run.allowed, true, "allowed")
	eq(run.applied, 1, "applied once")

	local declined = guard({ Title = "Sure?" })
	openDialog():Press("Cancel")
	settle(0.5)
	eq(declined.allowed, false, "declined")
	eq(declined.applied, 0, "not applied")

	local closed = guard({ Title = "Sure?" })
	openDialog():Close()
	settle(0.5)
	eq(closed.allowed, false, "closing counts as no")
	eq(closed.applied, 0, "not applied")
end)

test("Before: custom button names and the Delay lock", function()
	local run = guard({ Title = "Wait", Yes = "Do it", No = "Nope", Delay = 2 })
	local modal = openDialog()
	eq(modal:Press("Do it"), false, "locked at first")
	eq(run.applied, 0, "still nothing")
	settle(2.6)
	eq(modal:Press("Do it"), true, "unlocked after the delay")
	settle(0.5)
	eq(run.applied, 1, "applied")
end)

test("Before: Remember mutes the question for good, only when ticked and accepted", function()
	Library.Warnings:ClearRemembered()
	local spec = { Id = "t_remember", Remember = true, Title = "Again?" }

	local first = guard(spec)
	local modal = openDialog()
	modal.Checked = true
	modal:Press("Cancel")
	settle(0.5)
	eq(first.allowed, false, "declined")
	local second = guard(spec)
	local again = openDialog()
	truthy(again, "ticking the box and declining does not remember anything")
	again.Checked = true
	again:Press("Continue")
	settle(0.5)
	eq(second.applied, 1, "accepted")

	local third = guard(spec)
	settle(0.5)
	eq(next(Library.Modals), nil, "no dialog the third time")
	eq(third.applied, 1, "applied straight away")
	Library.Warnings:ClearRemembered()
end)

test("Before: Once asks until it is accepted, then stays quiet", function()
	local spec = { Id = "t_once", Once = true }
	local first = guard(spec)
	openDialog():Press("Cancel")
	settle(0.5)
	local second = guard(spec)
	local modal = openDialog()
	truthy(modal, "a declined question is asked again")
	modal:Press("Continue")
	settle(0.5)
	eq(second.applied, 1, "accepted")
	local third = guard(spec)
	settle(0.5)
	eq(third.applied, 1, "no dialog after it was accepted")
	eq(first.applied, 0, "the declined one never ran")
end)

test("Check: pass, block and warn-only", function()
	eq(toasts(), 0, "no toast to start with")
	local pass = guard({ Mode = "Check", Check = function() return true end })
	eq(pass.allowed, true, "passes")
	eq(pass.applied, 1, "applied")
	eq(toasts(), 0, "silent on success")

	local blocked = guard({ Check = function() return false, "Not in a round" end, Level = "Danger", Duration = 0.3 })
	eq(blocked.allowed, false, "mode is inferred from Check, and it blocks")
	eq(blocked.applied, 0, "not applied")
	eq(toasts(), 1, "the reason is shown as a toast")
	settle(1)

	local soft = guard({ Mode = "Check", Block = false, Check = function() return false, "Heads up" end, Duration = 0.3 })
	eq(soft.allowed, true, "Block = false lets it through")
	eq(soft.applied, 1, "applied")
	eq(toasts(), 1, "but still warns")
	settle(1)

	local broken = guard({ Mode = "Check", Check = function() error("boom") end, Duration = 0.3 })
	eq(broken.allowed, false, "a check that errors blocks")
	settle(1)

	local viaDialog = guard({ Mode = "Check", Check = function() return false, "Read this" end, Display = "Dialog" })
	local modal = openDialog()
	truthy(modal, "Display = Dialog shows a dialog")
	eq(viaDialog.allowed, false, "still blocked")
	modal:Press("OK")
	settle(1)
end)

test("After: the action runs first, then the notice, and Once keeps it to one", function()
	local order = {}
	local spec = { Mode = "After", Id = "t_after", Once = true, Title = "Done", Level = "Success", Duration = 0.3 }
	local ok = Library:Guard(spec, function()
		table.insert(order, "action:" .. toasts())
	end, { Name = "t", Action = "Click" })
	eq(ok, true, "allowed")
	settle(0.1)
	eq(order[1], "action:0", "the notice was not up yet when the action ran")
	eq(toasts(), 1, "notice shown afterwards")
	settle(1)
	Library:Guard(spec, function() end, { Name = "t", Action = "Click" })
	settle(0.1)
	eq(toasts(), 0, "Once: no second notice")
end)

test("Trigger and When decide whether a warning applies", function()
	local onDisable = { Mode = "After", Trigger = "Disable", Duration = 0.3 }
	Library:Guard(onDisable, function() end, { Name = "t", Action = "Enable" })
	settle(0.1)
	eq(toasts(), 0, "Trigger = Disable ignores Enable")
	Library:Guard(onDisable, function() end, { Name = "t", Action = "Disable" })
	settle(0.1)
	eq(toasts(), 1, "and fires on Disable")
	settle(1)

	local defaults = { Mode = "After", Duration = 0.3 }
	Library:Guard(defaults, function() end, { Name = "t", Action = "Disable" })
	settle(0.1)
	eq(toasts(), 0, "toggles warn on Enable only by default")
	Library:Guard(defaults, function() end, { Name = "t", Action = "Click" })
	settle(0.1)
	eq(toasts(), 1, "other actions always apply")
	settle(1)

	local big = { Mode = "After", Duration = 0.3, When = function(ctx) return ctx.Value > 5 end }
	Library:Guard(big, function() end, { Name = "t", Action = "Select", Value = 3 })
	settle(0.1)
	eq(toasts(), 0, "When = false")
	Library:Guard(big, function() end, { Name = "t", Action = "Select", Value = 9 })
	settle(0.1)
	eq(toasts(), 1, "When = true")
	settle(1)

	local broken = { Mode = "After", Duration = 0.3, When = function() error("nope") end }
	local ran = Library:Guard(broken, function() end, { Name = "t", Action = "Click" })
	settle(0.1)
	eq(ran, true, "a throwing When never blocks the action")
	eq(toasts(), 0, "and shows nothing")
end)

test("Cooldown stops a blocking check from spamming, it still blocks", function()
	local spec = { Mode = "Check", Id = "t_cool", Cooldown = 30, Duration = 0.5, Check = function() return false, "No" end }
	local first = guard(spec)
	eq(toasts(), 1, "first failure shows a toast")
	local second = guard(spec)
	eq(toasts(), 1, "second failure inside the cooldown stays quiet")
	eq(first.allowed, false, "first blocked")
	eq(second.allowed, false, "second blocked")
	settle(1)
end)

test("several warnings run in order and stop at the first that blocks", function()
	local calls = {}
	local run = guard({
		{ Mode = "Check", Check = function() table.insert(calls, "check"); return false, "blocked" end, Duration = 0.3 },
		{ Mode = "Before", Title = "never asked" },
	})
	settle(0.3)
	eq(next(Library.Modals), nil, "the dialog after a blocking check never opens")
	eq(run.allowed, false, "blocked")
	eq(#calls, 1, "check ran once")
	settle(1)

	local second = guard({
		{ Mode = "Before", Title = "first" },
		{ Mode = "Check", Check = function() table.insert(calls, "late"); return true end },
	})
	openDialog():Press("Continue")
	settle(0.5)
	eq(second.applied, 1, "both passed")
	eq(calls[2], "late", "the check ran after the confirmation")
end)

test("Library:SetWarnings(false): no questions, no notices, blocking checks stay", function()
	Library:SetWarnings(false)
	local asked = guard({ Title = "Skipped?" })
	settle(0.3)
	eq(next(Library.Modals), nil, "no dialog")
	eq(asked.allowed, true, "Before is accepted automatically")
	Library:Guard({ Mode = "After", Duration = 0.3 }, function() end, { Name = "t", Action = "Click" })
	settle(0.1)
	eq(toasts(), 0, "After notices are skipped")
	local blocked = guard({ Mode = "Check", Duration = 0.3, Check = function() return false, "Still on" end })
	eq(blocked.allowed, false, "a blocking check still blocks")
	eq(toasts(), 1, "and still explains why")
	settle(1)
	Library:SetWarnings(true)
	local again = guard({ Title = "Asked again" })
	truthy(openDialog(), "back to asking")
	next(Library.Modals):Close()
	settle(0.5)
	eq(again.allowed, false, "closed")
end)

test("the log and OnWarning see every decision", function()
	local seenByHook = {}
	local connection = Library:OnWarning(function(entry)
		table.insert(seenByHook, entry.Decision)
	end)
	local before = #Library:GetWarningLog()
	guard({ Title = "Q1", Level = "Danger" })
	openDialog():Press("Continue")
	settle(0.5)
	guard({ Title = "Q2" })
	openDialog():Press("Cancel")
	settle(0.5)
	guard({ Mode = "Check", Check = function() return false, "no" end, Duration = 0.3 })
	settle(1)
	local log = Library:GetWarningLog()
	eq(#log - before, 3, "three entries")
	eq(log[#log - 2].Decision, "Accepted", "accepted")
	eq(log[#log - 2].Level, "Danger", "level recorded")
	eq(log[#log - 1].Decision, "Declined", "declined")
	eq(log[#log].Decision, "Blocked", "blocked")
	eq(table.concat(seenByHook, ","), "Accepted,Declined,Blocked", "hook saw them in order")
	connection.Disconnect()
	guard({ Mode = "Check", Check = function() return false, "no" end, Duration = 0.3 })
	settle(1)
	eq(#seenByHook, 3, "disconnected hooks hear nothing")
	log[1] = nil
	truthy(#Library:GetWarningLog() > 0, "the returned log is a copy")
end)

test("Library:Warn shows a one-off notice", function()
	eq(Library:Warn({ Content = "Careful", Level = "Danger", Duration = 0.3 }), true, "toast")
	eq(toasts(), 1, "shown")
	settle(1)
	eq(Library:Warn("just text"), true, "string shorthand")
	settle(8)
	Library:Warn({ Title = "Dialog", Content = "Read me", Display = "Dialog" })
	local modal = openDialog()
	truthy(modal, "dialog")
	modal:Press("OK")
	settle(1)
	eq(Library:Warn({ Id = "t_warn_once", Once = true, Content = "x", Duration = 0.3 }), true, "first")
	settle(1)
	eq(Library:Warn({ Id = "t_warn_once", Once = true, Content = "x", Duration = 0.3 }), false, "muted the second time")
end)

test("unknown levels fall back to Warning, unknown modes to Before", function()
	local before = #Library:GetWarningLog()
	guard({ Level = "Catastrophic", Mode = "sometimes", Title = "Odd" })
	local modal = openDialog()
	truthy(modal, "treated as Before")
	modal:Press("Continue")
	settle(0.5)
	local log = Library:GetWarningLog()
	eq(log[#log].Level, "Warning", "level fell back")
	eq(#log - before, 1, "one entry")
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
	eq(next(Library.Modals), nil, "no modals")
end)

----------------------------------------------------------------------------------------------------

print(string.format("\n%d passed, %d failed", passed, failed))
for _, line in failures do
	print("  - " .. line)
end

return { Passed = passed, Failed = failed, Failures = failures }
