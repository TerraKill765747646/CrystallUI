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
	local hit = Mock.Find(toggle.Instance, function(i) return i:IsA("TextButton") end)
	hit.MouseButton1Click:Fire()
	eq(toggle:Get(), true, "after click")
	eq(last, true, "callback")
	hit.MouseButton1Click:Fire()
	eq(toggle:Get(), false, "after second click")
	toggle:Destroy()
end)

test("destroyed element no longer reacts", function()
	local toggle = section:CreateToggle({ Name = "T" })
	local hit = Mock.Find(toggle.Instance, function(i) return i:IsA("TextButton") end)
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
	local item = Mock.Find(dd.Instance, function(i) return i:IsA("TextButton") and i.Text == "B" end)
	item.MouseButton1Click:Fire()
	eq(dd:Get(), "B", "selected")
	eq(last, "B", "callback")
	eq(dd.Open, false, "closed after single select")
	dd:Destroy()
end)

test("dropdown search filters the item list", function()
	local dd = section:CreateDropdown({ Name = "D", Options = { "Apple", "Banana", "Cherry" }, Search = true })
	local box = Mock.Find(dd.Instance, function(i) return i:IsA("TextBox") end)
	box.Text = "an"
	local visible = Mock.FindAll(dd.Instance, function(i) return i:IsA("TextButton") and i.Text ~= "" and i.Visible end)
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

win:Destroy()
print(string.format("\n%d passed, %d failed", passed, failed))
return { Passed = passed, Failed = failed }
