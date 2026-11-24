-- Interaction tests that need to poke at GuiObjects and fire input events.
-- Only runnable against tests/mock_roblox.luau, the portable suite is Tests.luau.

local Library, Mock = ...

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  PASS  " .. name)
	else
		failed += 1
		print("  FAIL  " .. name .. "\n        " .. tostring(err))
	end
end
local function eq(a, b, label)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", label or "value", tostring(b), tostring(a)), 2)
	end
end

local function truthy(value, label)
	if not value then
		error((label or "value") .. " is falsy", 2)
	end
end

-- the mock leaves Position/Size unset on instances that never assigned them
local function Pos(i) return i.Position or UDim2.new() end
local function Siz(i) return i.Size or UDim2.new() end

local UIS = game:GetService("UserInputService")
local function buttons(root)
	return Mock.FindAll(root, function(i) return i:IsA("TextButton") end)
end

print("\n[Interaction (mock only)]")

local win = Library:CreateWindow({ Name = "Interaction", ToggleKey = "K" })
local tab = win:CreateTab("T")
local section = tab:CreateSection("S")

test("clicking a toggle flips it and fires the callback", function()
	local last
	local toggle = section:CreateToggle({ Name = "T", Callback = function(v) last = v end })
	local hit = Mock.Find(toggle.Instance, function(i) return i:IsA("TextButton") and i.ZIndex == 2 end)
	hit.MouseButton1Click:Fire()
	eq(toggle:Get(), true, "after click")
	eq(last, true, "callback")
	hit.MouseButton1Click:Fire()
	eq(toggle:Get(), false, "after second click")
	toggle:Destroy()
end)

test("destroyed element no longer reacts", function()
	local toggle = section:CreateToggle({ Name = "T" })
	local hit = Mock.Find(toggle.Instance, function(i) return i:IsA("TextButton") and i.ZIndex == 2 end)
	toggle:Destroy()
	hit.MouseButton1Click:Fire()
	eq(toggle:Get(), false, "value untouched")
end)

test("keyboard toggle key hides and shows the window", function()
	UIS.InputBegan:Fire(Mock.Key("K"), false)
	eq(win.Visible, false, "hidden")
	UIS.InputBegan:Fire(Mock.Key("K"), false)
	eq(win.Visible, true, "shown")
	UIS.InputBegan:Fire(Mock.Key("K"), true)
	eq(win.Visible, true, "ignored when the game already consumed the key")
	task.wait(1)
end)

test("slider drag sets the value and unlocks scrolling after release", function()
	local last
	local slider = section:CreateSlider({ Name = "S", Range = { 0, 100 }, Increment = 1, Callback = function(v) last = v end })
	local bar = Mock.Find(slider.Instance, function(i) return i:IsA("TextButton") and i.Size.Y.Offset == 6 end)
	bar.AbsoluteSize = Vector2.new(200, 6)
	bar.AbsolutePosition = Vector2.new(0, 0)
	local page = bar:FindFirstAncestorWhichIsA("ScrollingFrame")
	eq(page.ScrollingEnabled, true, "scroll enabled before")
	local down = Mock.Input("MouseButton1", { Position = Vector3.new(100, 0, 0) })
	bar.InputBegan:Fire(down)
	eq(slider:Get(), 50, "value at the middle")
	eq(page.ScrollingEnabled, false, "scroll locked while dragging")
	UIS.InputChanged:Fire(Mock.Input("MouseMovement", { Position = Vector3.new(150, 0, 0) }))
	eq(slider:Get(), 75, "value follows the pointer")
	UIS.InputEnded:Fire(Mock.Input("MouseButton1"))
	eq(page.ScrollingEnabled, true, "scroll restored")
	UIS.InputChanged:Fire(Mock.Input("MouseMovement", { Position = Vector3.new(20, 0, 0) }))
	eq(slider:Get(), 75, "no change after release")
	eq(last, 75, "callback")
	slider:Destroy()
end)

test("destroying a slider mid-drag restores scrolling", function()
	local slider = section:CreateSlider({ Name = "S", Range = { 0, 10 } })
	local bar = Mock.Find(slider.Instance, function(i) return i:IsA("TextButton") and i.Size.Y.Offset == 6 end)
	local page = bar:FindFirstAncestorWhichIsA("ScrollingFrame")
	bar.InputBegan:Fire(Mock.Input("MouseButton1", { Position = Vector3.new(0, 0, 0) }))
	eq(page.ScrollingEnabled, false, "locked")
	slider:Destroy()
	eq(page.ScrollingEnabled, true, "restored by the maid")
end)

test("dropdown item click selects and closes", function()
	local last
	local dd = section:CreateDropdown({ Name = "D", Options = { "A", "B", "C" }, Callback = function(v) last = v end })
	dd:SetOpen(true)
	local item = Mock.Find(dd.Popup, function(i) return i:IsA("TextButton") and i.Text == "B" end)
	item.MouseButton1Click:Fire()
	eq(dd:Get(), "B", "selected")
	eq(last, "B", "callback")
	eq(dd.Open, false, "closed after single select")
	dd:Destroy()
end)

test("dropdown search filters the item list", function()
	local dd = section:CreateDropdown({ Name = "D", Options = { "Apple", "Banana", "Cherry" }, Search = true })
	local box = Mock.Find(dd.Popup, function(i) return i:IsA("TextBox") end)
	box.Text = "an"
	local visible = Mock.FindAll(dd.Popup, function(i) return i:IsA("TextButton") and i.Text ~= "" and i.Visible end)
	eq(#visible, 1, "only Banana matches")
	eq(visible[1].Text, "Banana", "match")
	dd:Destroy()
end)

test("checklist items toggle on click, Select All / Clear work", function()
	local list = section:CreateChecklist({ Name = "C", Options = { "x", "y", "z" } })
	local all = Mock.Find(list.Instance, function(i) return i:IsA("TextButton") and i.Text == "Select All" end)
	local clear = Mock.Find(list.Instance, function(i) return i:IsA("TextButton") and i.Text == "Clear" end)
	all.MouseButton1Click:Fire()
	eq(#list:Get(), 3, "all selected")
	clear.MouseButton1Click:Fire()
	eq(#list:Get(), 0, "cleared")
	list:Destroy()
end)

test("keybind: click, press a key, then the key fires the callback", function()
	local presses = 0
	local bind = section:CreateKeybind({ Name = "B", Callback = function() presses += 1 end })
	local button = Mock.Find(bind.Instance, function(i) return i:IsA("TextButton") and i.Text == "None" end)
	button.MouseButton1Click:Fire()
	eq(bind.Listening, true, "listening")
	UIS.InputBegan:Fire(Mock.Key("H"), false)
	eq(bind:Get(), "H", "bound")
	eq(bind.Listening, false, "stopped listening")
	UIS.InputBegan:Fire(Mock.Key("H"), false)
	eq(presses, 1, "callback fires on the bound key")
	button.MouseButton1Click:Fire()
	UIS.InputBegan:Fire(Mock.Key("Escape"), false)
	eq(bind:Get(), "None", "Escape unbinds")
	bind:Destroy()
end)

test("window search filters tabs", function()
	local win2 = Library:CreateWindow({ Name = "Search" })
	win2:CreateTab("Alpha")
	win2:CreateTab("Beta")
	local box = Mock.Find(win2.Sidebar, function(i) return i:IsA("TextBox") end)
	box.Text = "bet"
	eq(win2.Tabs[1].Button.Visible, false, "Alpha hidden")
	eq(win2.Tabs[2].Button.Visible, true, "Beta visible")
	box.Text = ""
	eq(win2.Tabs[1].Button.Visible, true, "Alpha back")
	win2:Destroy()
end)

test("theme bindings are released when an instance is destroyed", function()
	local toggle = section:CreateToggle({ Name = "leak" })
	local count = Library.Theme:_BindingCount()
	toggle:Destroy()
	eq(Library.Theme:_BindingCount() < count, true, "bindings dropped")
end)

test("theme change recolours live elements", function()
	local toggle = section:CreateToggle({ Name = "T", CurrentValue = true })
	local track = Mock.Find(toggle.Instance, function(i) return i:IsA("Frame") and i.Size.X.Offset == 38 end)
	Library:SetPalette("Emerald")
	task.wait(1)
	eq(track.BackgroundColor3, Library.Theme.Palettes.Emerald.Accent, "track follows the accent")
	Library:SetPalette("Amethyst")
	task.wait(1)
	toggle:Destroy()
end)

test("dragging the title bar stays on screen", function()
	local top = Mock.Find(win.Main, function(i) return i.Name == "TopBar" end)
	win.Gui.AbsoluteSize = Vector2.new(1000, 600)
	win.Main.AbsoluteSize = Vector2.new(560, 380)
	top.InputBegan:Fire(Mock.Input("MouseButton1", { Position = Vector3.new(500, 100, 0) }))
	UIS.InputChanged:Fire(Mock.Input("MouseMovement", { Position = Vector3.new(5000, 5000, 0) }))
	local pos = win.Main.Position
	eq(pos.X.Offset <= 500 - 40, true, "x clamped (" .. pos.X.Offset .. ")")
	eq(pos.Y.Offset <= 448, true, "y clamped (" .. pos.Y.Offset .. ")")
	UIS.InputChanged:Fire(Mock.Input("MouseMovement", { Position = Vector3.new(-5000, -5000, 0) }))
	pos = win.Main.Position
	eq(pos.X.Offset >= -500 + 40, true, "x clamped left (" .. pos.X.Offset .. ")")
	eq(300 + pos.Y.Offset - 190 >= 0, true, "title bar not above the screen (" .. pos.Y.Offset .. ")")
	UIS.InputEnded:Fire(Mock.Input("MouseButton1"))
end)

test("dropdown lives in a popup above the page, not inside the row", function()
	local dd = section:CreateDropdown({ Name = "D", Options = { "A", "B" } })
	eq(dd.Popup.Parent, win.Gui, "popup parented to the window gui")
	eq(Mock.Find(dd.Instance, function(i) return i.Text == "A" end), nil, "row holds no option buttons")
	dd:Destroy()
	eq(dd.Popup.Parent, nil, "popup destroyed with the element")
end)

test("popup closes on outside click, stays open on inside click", function()
	local dd = section:CreateDropdown({ Name = "D", Options = { "A", "B" } })
	dd:SetOpen(true)
	task.wait(1)
	eq(dd.Popup.Visible, true, "visible")
	UIS.InputBegan:Fire(Mock.Input("MouseButton1", { Position = Vector3.new(10, 10, 0) }), false)
	eq(dd.Open, true, "inside click keeps it open")
	UIS.InputBegan:Fire(Mock.Input("MouseButton1", { Position = Vector3.new(800, 500, 0) }), false)
	eq(dd.Open, false, "outside click closes")
	task.wait(1)
	eq(dd.Popup.Visible, false, "hidden after the animation")
	dd:Destroy()
end)

test("only one popup is open at a time, tab switch closes them", function()
	local a = section:CreateDropdown({ Name = "A", Options = { "1" } })
	local b = section:CreateDropdown({ Name = "B", Options = { "1" } })
	a:SetOpen(true)
	b:SetOpen(true)
	eq(a.Open, false, "first closed when the second opened")
	eq(b.Open, true, "second open")
	local other = win:CreateTab("Elsewhere")
	other:Select()
	eq(b.Open, false, "tab switch closes popups")
	tab:Select()
	b:SetOpen(true)
	win:Toggle(false)
	eq(b.Open, false, "hiding the window closes popups")
	win:Toggle(true)
	task.wait(1)
	a:Destroy()
	b:Destroy()
end)

test("locked elements ignore SetOpen and show the shield", function()
	local dd = section:CreateDropdown({ Name = "D", Options = { "A" } })
	dd:SetOpen(true)
	dd:SetLocked(true)
	eq(dd.Open, false, "locking closes it")
	dd:SetOpen(true)
	eq(dd.Open, false, "stays closed while locked")
	local shield = Mock.Find(dd.Instance, function(i) return i:IsA("TextButton") and i.ZIndex == 30 end)
	eq(shield.Visible, true, "shield visible")
	dd:SetLocked(false)
	eq(shield.Visible, false, "shield hidden")
	dd:Destroy()
end)

test("locked keybind does not fire its hotkey", function()
	local presses = 0
	local bind = section:CreateKeybind({ Name = "B", CurrentKeybind = "H", Locked = true, Callback = function() presses += 1 end })
	UIS.InputBegan:Fire(Mock.Key("H"), false)
	eq(presses, 0, "locked")
	bind:SetLocked(false)
	UIS.InputBegan:Fire(Mock.Key("H"), false)
	eq(presses, 1, "unlocked")
	bind:Destroy()
end)

test("colour picker: dragging the square and the hue bar", function()
	local last
	local picker = section:CreateColorPicker({ Name = "C", CurrentValue = Color3.fromRGB(255, 0, 0), Callback = function(c) last = c end })
	local sv = Mock.Find(picker.Popup, function(i) return i.Name == "SV" end)
	local hue = Mock.Find(picker.Popup, function(i) return i.Name == "Hue" end)
	sv.AbsoluteSize, sv.AbsolutePosition = Vector2.new(100, 100), Vector2.new(0, 0)
	hue.AbsoluteSize, hue.AbsolutePosition = Vector2.new(20, 120), Vector2.new(0, 0)
	sv.InputBegan:Fire(Mock.Input("MouseButton1", { Position = Vector3.new(100, 0, 0) }))
	UIS.InputEnded:Fire(Mock.Input("MouseButton1"))
	eq(picker:GetHex(), "#FF0000", "top right corner is the pure hue")
	sv.InputBegan:Fire(Mock.Input("MouseButton1", { Position = Vector3.new(0, 0, 0) }))
	UIS.InputEnded:Fire(Mock.Input("MouseButton1"))
	eq(picker:GetHex(), "#FFFFFF", "top left is white")
	sv.InputBegan:Fire(Mock.Input("MouseButton1", { Position = Vector3.new(50, 100, 0) }))
	UIS.InputEnded:Fire(Mock.Input("MouseButton1"))
	eq(picker:GetHex(), "#000000", "bottom is black")
	hue.InputBegan:Fire(Mock.Input("MouseButton1", { Position = Vector3.new(0, 40, 0) }))
	UIS.InputEnded:Fire(Mock.Input("MouseButton1"))
	sv.InputBegan:Fire(Mock.Input("MouseButton1", { Position = Vector3.new(100, 0, 0) }))
	UIS.InputEnded:Fire(Mock.Input("MouseButton1"))
	eq(picker:GetHex(), "#00FF00", "hue at one third is green")
	eq(last.G, 1, "callback receives the colour")
	UIS.InputChanged:Fire(Mock.Input("MouseMovement", { Position = Vector3.new(0, 0, 0) }))
	eq(picker:GetHex(), "#00FF00", "no change after release")
	picker:Destroy()
end)

test("colour picker: hex box accepts input and reverts on garbage", function()
	local picker = section:CreateColorPicker({ Name = "C", CurrentValue = "#336699" })
	local box = Mock.Find(picker.Popup, function(i) return i:IsA("TextBox") end)
	eq(box.Text, "#336699", "initial")
	box.Text = "f80"
	box.FocusLost:Fire(true)
	eq(picker:GetHex(), "#FF8800", "short hex expands")
	box.Text = "banana"
	box.FocusLost:Fire(true)
	eq(box.Text, "#FF8800", "text reverts")
	eq(picker:GetHex(), "#FF8800", "value untouched")
	picker:Destroy()
end)

test("dialog buttons fire callbacks and close, Confirm returns a boolean", function()
	local clicked = 0
	local dialog = Library:Dialog({
		Title = "Hi", Content = "There",
		Buttons = { { Name = "One", Callback = function() clicked += 1 end }, { Name = "Keep", Keep = true, Callback = function() clicked += 10 end } },
	})
	local keep = Mock.Find(dialog.Gui, function(i) return i:IsA("TextButton") and i.Text == "Keep" end)
	keep.MouseButton1Click:Fire()
	eq(clicked, 10, "callback")
	eq(dialog.Closed, false, "Keep leaves it open")
	local one = Mock.Find(dialog.Gui, function(i) return i:IsA("TextButton") and i.Text == "One" end)
	one.MouseButton1Click:Fire()
	eq(dialog.Closed, true, "closed")
	task.wait(1)

	local answers = {}
	for _, label in { "Yes!", "Nope" } do
		task.spawn(function()
			table.insert(answers, Library:Confirm({ Yes = "Yes!", No = "Nope" }))
		end)
		local modal = next(Library.Modals)
		local button = Mock.Find(modal.Gui, function(i) return i:IsA("TextButton") and i.Text == label end)
		button.MouseButton1Click:Fire()
		task.wait(1)
	end
	eq(answers[1], true, "confirm")
	eq(answers[2], false, "cancel")
	eq(next(Library.Modals), nil, "no modal left")
end)

test("key system UI: typing, Enter, wrong key shakes, link copies", function()
	local result = {}
	local handle = Library:KeySystem({
		Async = true, Key = "letmein", Cooldown = 0, Links = { { Name = "Get key", Url = "https://example.com/k" } },
		OnSuccess = function(k) result.key = k end,
	})
	local modal = handle.Modal
	local box = Mock.Find(modal.Gui, function(i) return i:IsA("TextBox") end)
	local verify = Mock.Find(modal.Gui, function(i) return i:IsA("TextButton") and i.Text == "Verify" end)
	local link = Mock.Find(modal.Gui, function(i) return i:IsA("TextButton") and i.Text == "Get key" end)

	link.MouseButton1Click:Fire()
	eq(Mock.Clipboard, "https://example.com/k", "link copied")

	box.Text = "nope"
	verify.MouseButton1Click:Fire()
	eq(handle.Finished, false, "wrong key")
	eq(handle.Attempts, 1, "attempt counted")
	task.wait(1)
	eq(box.Text, "nope", "input is kept so a typo can be fixed")

	box.Text = "   letmein  "
	box.FocusLost:Fire(true)
	task.wait(2)
	eq(handle.Ok, true, "Enter submits and whitespace is trimmed")
	eq(result.key, "letmein", "OnSuccess")
	task.wait(1)
	eq(next(Library.Modals), nil, "modal gone")
end)

test("key system: the X button fails the attempt", function()
	local reason
	local handle = Library:KeySystem({ Async = true, Key = "x", OnFail = function(r) reason = r end })
	local close = Mock.Find(handle.Modal.Gui, function(i) return i:IsA("TextButton") and i.Name == "Close" end)
	close.MouseButton1Click:Fire()
	eq(handle.Finished, true, "finished")
	eq(handle.Ok, false, "not ok")
	eq(reason, "Closed", "reason")
	task.wait(1)
end)

test("theme: accent line under the title bar is recoloured", function()
	local gradient = Mock.Find(win.Main, function(i) return i:IsA("UIGradient") end)
	Library:SetPalette("Emerald")
	task.wait(1)
	eq(gradient.Color.args[1], Library.Theme.Palettes.Emerald.Accent, "gradient start follows the accent")
	Library:SetPalette("Amethyst")
	task.wait(1)
end)

test("icons are drawn, not typed: no font glyphs anywhere in the UI", function()
	local glyphs = { "◆", "›", "▾", "▸", "▴", "×", "✓", "–", "✕" }
	local w = Library:CreateWindow({ Name = "Glyphs", MobileButton = true })
	local t = w:CreateTab("T")
	local sec = t:CreateSection("S", { Collapsible = true })
	sec:CreateButton({ Name = "b" })
	sec:CreateDropdown({ Name = "d", Options = { "a" } })
	sec:CreateChecklist({ Name = "c", Options = { "x" } })
	sec:CreateColorPicker({ Name = "p" })
	Library:Notify({ Title = "n", Content = "c", Duration = 30 })
	local dialog = Library:Dialog({ Title = "x", Content = "y" })
	local keys = Library:KeySystem({ Async = true, Key = "k" })
	task.wait(0.5)
	local scanned, offenders = 0, {}
	for _, inst in game:GetService("CoreGui"):GetDescendants() do
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			scanned += 1
			for _, glyph in glyphs do
				if inst.Text:find(glyph, 1, true) or (inst.PlaceholderText or ""):find(glyph, 1, true) then
					table.insert(offenders, inst.Name .. ":" .. inst.Text)
				end
			end
		end
	end
	truthy(scanned > 30, "the scan actually looked at the UI (" .. scanned .. ")")
	eq(#offenders, 0, "text glyphs found: " .. table.concat(offenders, ", "))
	keys:Close()
	dialog:Close()
	w:Destroy()
	task.wait(1)
end)

test("custom text icons are still honoured", function()
	local w = Library:CreateWindow({ Name = "Custom", Icon = "★", MobileButton = true, ToggleIcon = "☰" })
	local found = Mock.Find(w.Gui, function(i) return i:IsA("TextLabel") and i.Text == "★" end)
	truthy(found, "window icon")
	eq(w.ToggleButton.Text, "☰", "toggle button icon")
	local function iconHolder(window)
		return Mock.Find(window.Main, function(i) return i:IsA("Frame") and Siz(i).X.Offset == 22 and Siz(i).Y.Offset == 42 end)
	end
	local plain = Library:CreateWindow({ Name = "Plain" })
	truthy(iconHolder(plain), "default window draws the diamond")
	plain:Destroy()
	local none = Library:CreateWindow({ Name = "None", Icon = false })
	eq(iconHolder(none), nil, "Icon = false draws nothing")
	none:Destroy()
	w:Destroy()
end)

test("window corners: the sidebar fill is clipped so only the bottom-left corner shows", function()
	local w = Library:CreateWindow({ Name = "Corners" })
	local sidebar = Mock.Find(w.Body, function(i) return i:IsA("Frame") and i.ClipsDescendants == true and Siz(i).X.Offset == 160 end)
	truthy(sidebar, "sidebar clips its fill")
	eq(sidebar.BackgroundTransparency, 1, "the clip box itself is invisible")
	local fill = Mock.Find(sidebar, function(i) return i:IsA("Frame") and Pos(i).Y.Offset == -12 end)
	truthy(fill, "fill overhangs the top")
	eq(Mock.Find(fill, function(i) return i:IsA("UICorner") end).CornerRadius.Offset, 10, "fill uses the window's radius")
	eq(Mock.Find(w.Main, function(i) return i:IsA("UICorner") end).CornerRadius.Offset, 10, "window radius")
	w:Destroy()
end)

test("notification edge: accent crescent under a face with the same radius, timer inside the face", function()
	Library:Notify({ Title = "Edge", Content = "x", Type = "Warning", Duration = 30 })
	task.wait(0.5)
	local close
	for _, inst in game:GetService("CoreGui"):GetDescendants() do
		if inst.Name == "Close" and inst.Parent and Mock.Find(inst.Parent, function(i) return i:IsA("TextLabel") and i.Text == "Edge" end) then
			close = inst
		end
	end
	truthy(close, "found the card")
	local card = close.Parent
	local accent = Mock.Find(card, function(i) return i.Parent == card and i:IsA("Frame") and Siz(i).X.Offset == 24 end)
	local face = Mock.Find(card, function(i) return i.Parent == card and i:IsA("Frame") and Pos(i).X.Offset == 3 end)
	truthy(accent and face, "both layers exist")
	eq(Mock.Find(accent, function(i) return i:IsA("UICorner") end).CornerRadius.Offset, 8, "accent radius")
	eq(Mock.Find(face, function(i) return i:IsA("UICorner") end).CornerRadius.Offset, 8, "face radius")
	eq(face.ZIndex > (accent.ZIndex or 1), true, "face sits above the accent")
	eq((close.ZIndex or 1) > face.ZIndex, true, "close button sits above the face")
	local timer = Mock.Find(face, function(i) return i.Parent == face and i:IsA("Frame") and Siz(i).Y.Offset == 2 end)
	truthy(timer, "timer lives inside the face")
	eq(Pos(timer).X.Offset >= 12, true, "timer keeps its distance from the accent edge")
	Library.Notifications.Queue = {}
	task.wait(0.1)
end)

test("section mark is rounded and collapsing swaps the drawn chevron's direction", function()
	local w = Library:CreateWindow({ Name = "Sec" })
	local t = w:CreateTab("T")
	local sec = t:CreateSection("S", { Collapsible = true })
	local mark = Mock.Find(sec.Header, function(i) return i:IsA("Frame") and Siz(i).X.Offset == 3 end)
	truthy(Mock.Find(mark, function(i) return i:IsA("UICorner") end), "mark has rounded ends")
	local chevron = Mock.Find(sec.Header, function(i) return i:IsA("Frame") and i.Rotation == 90 and Siz(i).X.Offset == 9 end)
	truthy(chevron, "expanded chevron points down")
	sec:SetCollapsed(true)
	task.wait(1)
	eq(chevron.Rotation, 0, "collapsed chevron points right")
	w:Destroy()
end)

test("minimize button draws a minus and turns into a plus", function()
	local w = Library:CreateWindow({ Name = "Min" })
	eq(w.MinVertical.Visible, false, "minus while open")
	w:Minimize(true)
	eq(w.MinVertical.Visible, true, "plus while minimized")
	w:Minimize(false)
	eq(w.MinVertical.Visible, false, "minus again")
	task.wait(1)
	w:Destroy()
end)

local function buttonWindow()
	local w = Library:CreateWindow({ Name = "Btn", MobileButton = true, ToggleKey = false })
	w.Gui.AbsoluteSize = Vector2.new(1000, 600)
	return w, w.ToggleButton
end

test("floating button: a tap toggles the window", function()
	local w, button = buttonWindow()
	eq(w.Visible, true, "start")
	button.InputBegan:Fire(Mock.Input("MouseButton1", { Position = Vector3.new(100, 100, 0) }))
	UIS.InputEnded:Fire(Mock.Input("MouseButton1"))
	eq(w.Visible, false, "hidden by tap")
	button.InputBegan:Fire(Mock.Input("MouseButton1", { Position = Vector3.new(100, 100, 0) }))
	UIS.InputEnded:Fire(Mock.Input("MouseButton1"))
	eq(w.Visible, true, "shown by tap")
	task.wait(1)
	w:Destroy()
end)

test("floating button: a small wobble still counts as a tap", function()
	local w, button = buttonWindow()
	button.InputBegan:Fire(Mock.Input("Touch", { Position = Vector3.new(100, 100, 0) }))
	UIS.InputChanged:Fire(Mock.Input("Touch", { Position = Vector3.new(103, 104, 0) }))
	UIS.InputEnded:Fire(Mock.Input("Touch"))
	eq(w.Visible, false, "toggled")
	task.wait(1)
	w:Destroy()
end)

test("floating button: it follows the finger, snaps to an edge and does not toggle", function()
	local w, button = buttonWindow()
	-- centre of the button at rest: 12px margin + 23px radius, 40% down the screen
	button.InputBegan:Fire(Mock.Input("Touch", { Position = Vector3.new(100, 100, 0) }))
	eq(button.Position.X.Offset, 35, "pressing alone does not move it (x)")
	eq(button.Position.Y.Offset, 240, "pressing alone does not move it (y)")
	UIS.InputChanged:Fire(Mock.Input("Touch", { Position = Vector3.new(700, 300, 0) }))
	eq(button.Position.X.Offset, 35 + 600, "moves by exactly the finger's travel (x)")
	eq(button.Position.Y.Offset, 240 + 200, "moves by exactly the finger's travel (y)")
	UIS.InputEnded:Fire(Mock.Input("Touch"))
	eq(w.Visible, true, "drag must not toggle the window")
	task.wait(1)
	eq(button.Position.X.Offset, 1000 - 12 - 23, "snapped to the right edge")
	eq(button.Position.Y.Offset, 440, "height kept")
	-- and back to the left
	button.InputBegan:Fire(Mock.Input("Touch", { Position = Vector3.new(0, 0, 0) }))
	UIS.InputChanged:Fire(Mock.Input("Touch", { Position = Vector3.new(-900, 0, 0) }))
	UIS.InputEnded:Fire(Mock.Input("Touch"))
	task.wait(1)
	eq(button.Position.X.Offset, 12 + 23, "snapped to the left edge")
	w:Destroy()
end)

test("floating button: grabbing it while it is still snapping does not make it jump", function()
	local w, button = buttonWindow()
	button.InputBegan:Fire(Mock.Input("Touch", { Position = Vector3.new(0, 0, 0) }))
	UIS.InputChanged:Fire(Mock.Input("Touch", { Position = Vector3.new(600, 0, 0) }))
	UIS.InputEnded:Fire(Mock.Input("Touch"))
	-- the snap animation is under way (not finished): the position is somewhere in between
	local before = button.Position.X.Offset
	button.InputBegan:Fire(Mock.Input("Touch", { Position = Vector3.new(0, 0, 0) }))
	eq(button.Position.X.Offset, before, "a new press keeps the position it finds")
	UIS.InputChanged:Fire(Mock.Input("Touch", { Position = Vector3.new(-50, 20, 0) }))
	eq(button.Position.X.Offset, before - 50, "and follows from there")
	UIS.InputEnded:Fire(Mock.Input("Touch"))
	task.wait(1)
	w:Destroy()
end)

test("floating button: can't be dragged off screen", function()
	local w, button = buttonWindow()
	button.InputBegan:Fire(Mock.Input("Touch", { Position = Vector3.new(0, 0, 0) }))
	UIS.InputChanged:Fire(Mock.Input("Touch", { Position = Vector3.new(9000, 9000, 0) }))
	eq(button.Position.X.Offset, 1000 - 12 - 23, "x clamped")
	eq(button.Position.Y.Offset, 600 - 12 - 23, "y clamped")
	UIS.InputEnded:Fire(Mock.Input("Touch"))
	-- viewport shrinks (rotation): the button is pulled back inside
	w.Gui.AbsoluteSize = Vector2.new(500, 300)
	task.wait(1)
	eq(button.Position.X.Offset, 500 - 12 - 23, "x follows the new width")
	eq(button.Position.Y.Offset, 300 - 12 - 23, "y follows the new height")
	w:Destroy()
end)

test("floating button follows the theme and window state", function()
	local w, button = buttonWindow()
	task.wait(1)
	eq(button.BackgroundTransparency, 0.35, "see-through while the window is open")
	w:Toggle(false)
	task.wait(1)
	eq(button.BackgroundTransparency, 0, "solid when hidden")
	Library:SetPalette("Emerald")
	task.wait(1)
	eq(button.TextColor3, Library.Theme.Palettes.Emerald.Accent, "glyph recoloured")
	Library:SetPalette("Amethyst")
	task.wait(1)
	w:Destroy()
end)

win:Destroy()
print(string.format("\n%d passed, %d failed", passed, failed))
return { Passed = passed, Failed = failed }
