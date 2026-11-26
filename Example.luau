--[[
	CrystallUI demo: every control, theming, config and notifications in one window.

	    loadstring(game:HttpGet("https://raw.githubusercontent.com/TerraKill765747646/CrystallUI/main/Example.luau"))()

	Local development (modules read from the executor workspace instead of GitHub):
	    local Library = loadstring(readfile("CrystallUI/Init.luau"))({ LocalPath = "CrystallUI" })
	    loadstring(readfile("CrystallUI/Example.luau"))(Library)
]]

local Library = ...
if type(Library) ~= "table" then
	Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/TerraKill765747646/CrystallUI/main/Init.luau"))({
		Theme = { Palette = "Amethyst" },
	})
end

----------------------------------------------------------------------------------------------------
-- Key prompt: the script waits here, the window below is only built once a key is accepted.
-- The demo key is shown in the dialog itself. Set USE_KEY_SYSTEM to false to skip the prompt.
----------------------------------------------------------------------------------------------------
local USE_KEY_SYSTEM = true

if USE_KEY_SYSTEM then
	local ok = Library:KeySystem({
		Title = "Crystall Hub",
		Subtitle = "Enter your key to continue.",
		Note = "Demo key: DEMO-KEY-1234",
		SaveKey = false, -- true remembers a valid key on disk and skips the prompt next time

		-- 1) fixed keys (any of these three sources can be combined)
		Keys = { "DEMO-KEY-1234" },

		-- 2) your own check, may call any API itself
		-- Validate = function(key) return key:match("^%u%u%u%u%-%d+$") ~= nil, "Wrong format" end,

		-- 3) a key server; {key} is url-encoded, {hwid} is the client id
		-- Api = {
		-- 	Url = "https://example.com/api/check?key={key}&hwid={hwid}",
		-- 	-- by default a 2xx answer with {"valid": true} (or "success": true, or a plain "true") unlocks
		-- 	-- Success = function(response) return response.Json and response.Json.status == "active" end,
		-- },

		Links = { { Name = "Get key", Url = "https://example.com/get-key" } },
		MaxAttempts = 5,
	})
	if not ok then
		return -- the prompt was closed or the attempts ran out
	end
end

local Window = Library:CreateWindow({
	Name = "Crystall UI",
	Subtitle = "v" .. Library.Version,
	ToggleKey = "RightShift",
})

----------------------------------------------------------------------------------------------------
-- Controls
----------------------------------------------------------------------------------------------------
local Main = Window:CreateTab("Controls")

local Basics = Main:CreateSection("Basics")

Basics:CreateButton({
	Name = "Say hello",
	Callback = function()
		Library:Notify({ Title = "Hello", Content = "Button callbacks run in their own thread.", Type = "Success" })
	end,
})

Basics:CreateToggle({
	Name = "Enabled",
	Flag = "enabled",
	CurrentValue = true,
	Callback = function(value)
		print("Enabled:", value)
	end,
})

Basics:CreateSlider({
	Name = "Speed",
	Flag = "speed",
	Range = { 0, 100 },
	Increment = 5,
	Suffix = "%",
	CurrentValue = 50,
	Callback = function(value)
		print("Speed:", value)
	end,
})

Basics:CreateInput({
	Name = "Nickname",
	Flag = "nickname",
	PlaceholderText = "Type here...",
	Callback = function(text, enterPressed)
		print("Nickname:", text, "enter:", enterPressed)
	end,
})

local Choices = Main:CreateSection("Choices", { Collapsible = true })

-- a locked element ignores input and is dimmed; handy for options that depend on another toggle
local Advanced = Basics:CreateSlider({
	Name = "Advanced tuning",
	Range = { 1, 10 },
	CurrentValue = 5,
	Locked = true,
})
Basics:CreateToggle({
	Name = "Unlock advanced tuning",
	Callback = function(value)
		Advanced:SetLocked(not value)
	end,
})

local Fruit = Choices:CreateDropdown({
	Name = "Fruit",
	Flag = "fruit",
	Options = { "Apple", "Banana", "Cherry", "Dragonfruit" },
	CurrentOption = "Banana",
	Search = true,
	Callback = function(value)
		print("Fruit:", value)
	end,
})

Choices:CreateDropdown({
	Name = "Toppings",
	Flag = "toppings",
	Options = { "Cream", "Syrup", "Nuts", "Sprinkles" },
	Multi = true,
	CurrentOption = { "Cream" },
	Callback = function(list)
		print("Toppings:", table.concat(list, ", "))
	end,
})

Choices:CreateChecklist({
	Name = "Features",
	Flag = "features",
	Options = { "Alpha", "Beta", "Gamma" },
	CurrentValue = { "Alpha" },
	Callback = function(list)
		print("Features:", table.concat(list, ", "))
	end,
})

Choices:CreateKeybind({
	Name = "Action key",
	Flag = "actionKey",
	CurrentKeybind = "F",
	Callback = function(key)
		Library:Notify({ Title = "Keybind", Content = key.Name .. " was pressed", Duration = 2 })
	end,
	ChangedCallback = function(key)
		print("Rebound to", key and key.Name or "None")
	end,
})

Choices:CreateColorPicker({
	Name = "Highlight colour",
	Flag = "highlight",
	CurrentValue = "#7C4DFF", -- Color3 or hex
	Callback = function(color)
		print("Colour:", color)
	end,
})

local Info = Main:CreateSection("Info")
Info:CreateLabel("Labels wrap, so long text is fine: this one is long enough to need a second line in the default window size.")
Info:CreateParagraph({ Title = "Paragraph", Content = "Title and body, both can be replaced with :Set()." })
Info:CreateDivider()

-- refreshing a dropdown at runtime
Info:CreateButton({
	Name = "Replace fruit options",
	Callback = function()
		Fruit:Refresh({ "Mango", "Papaya", "Banana" }, true) -- keep the selection if it still exists
	end,
})

----------------------------------------------------------------------------------------------------
-- Appearance
----------------------------------------------------------------------------------------------------
local Appearance = Window:CreateTab("Appearance")
local Theme = Appearance:CreateSection("Theme")

Theme:CreateDropdown({
	Name = "Palette",
	Options = Library.Theme:ListPalettes(),
	CurrentOption = Library.Theme.PaletteName,
	Callback = function(name)
		if name then
			Library:SetPalette(name)
		end
	end,
})

Theme:CreateDropdown({
	Name = "Motion",
	Options = Library.Theme:ListMotions(),
	CurrentOption = Library.Theme.MotionName,
	Callback = function(name)
		if name then
			Library:SetMotion(name)
		end
	end,
})

-- a custom palette only needs the colours that differ from Amethyst
Library:RegisterPalette("Rose", {
	Accent = Color3.fromRGB(244, 114, 182),
	AccentText = Color3.fromRGB(40, 8, 24),
	Elevated = Color3.fromRGB(52, 32, 52),
})
Theme:CreateButton({
	Name = "Apply custom 'Rose' palette",
	Callback = function()
		Library:SetPalette("Rose", true) -- true: keep the current motion profile
	end,
})

----------------------------------------------------------------------------------------------------
-- Warnings: the same Warning option works on buttons, toggles, dropdowns and checklists
----------------------------------------------------------------------------------------------------
local Warn = Window:CreateTab("Warnings")
local PerControl = Warn:CreateSection("On a control")

-- BEFORE: asks first. Cancel (or the X) leaves everything as it was. Toggles ask when switched on.
PerControl:CreateToggle({
	Name = "Before: confirm, 3s lock, remembered",
	Callback = function(value)
		print("Risky feature:", value)
	end,
	Warning = {
		Id = "demo_risky",
		Title = "Risky feature",
		Content = "This can get your account flagged. The Continue button unlocks in a few seconds.",
		Level = "Danger", -- Info | Success | Warning | Danger
		Delay = 3,
		Remember = true, -- adds a "Don't ask again" tick box, kept on disk
	},
})

-- CHECK: your own condition, runs before the action. Return false and a reason to stop it.
PerControl:CreateButton({
	Name = "Check: needs 'Enabled' (Controls tab)",
	Callback = function()
		Library:Notify({ Title = "Check passed", Content = "The action ran.", Type = "Success", Duration = 3 })
	end,
	Warning = {
		Mode = "Check",
		Level = "Warning",
		Check = function()
			local enabled = Library.Flags.enabled
			return enabled ~= nil and enabled:Get() == true, "Turn on 'Enabled' on the Controls tab first."
		end,
	},
})

-- AFTER: the action runs, then a notice. Once = only the first time this session.
PerControl:CreateButton({
	Name = "After: notice once it ran (first time only)",
	Callback = function()
		print("action ran")
	end,
	Warning = { Mode = "After", Once = true, Level = "Success", Title = "Done", Content = "That was applied." },
})

-- WHEN: the warning only applies to some values.
PerControl:CreateDropdown({
	Name = "When: only 'Reckless' asks",
	Options = { "Safe", "Normal", "Reckless" },
	CurrentOption = "Safe",
	Warning = {
		When = function(ctx)
			return ctx.Value == "Reckless"
		end,
		Level = "Danger",
		Title = "Reckless mode",
		Content = function(ctx)
			return "You picked " .. ctx.Value .. ". Nothing will protect you."
		end,
	},
})

local FromCode = Warn:CreateSection("From code")

FromCode:CreateButton({
	Name = "Library:Warn (one-off notice)",
	Callback = function()
		Library:Warn({ Title = "Heads up", Content = "A one-off notice, no control involved.", Level = "Info" })
	end,
})

FromCode:CreateButton({
	Name = "Library:Guard (confirm, then run)",
	Callback = function()
		local ran = Library:Guard({ Title = "Delete everything?", Content = "There is no undo.", Level = "Danger", Yes = "Delete", Delay = 2 }, function()
			Library:Notify({ Title = "Deleted", Content = "(nothing, it was a demo)", Type = "Success", Duration = 3 })
		end, { Name = "demo" })
		print("ran:", ran)
	end,
})

FromCode:CreateButton({
	Name = "Show the warning log",
	Callback = function()
		local log = Library:GetWarningLog()
		local last = log[#log]
		Library:Notify({
			Title = "Warning log",
			Content = #log .. " entries" .. (if last then ", last: " .. last.Decision .. " (" .. tostring(last.Source) .. ")" else ""),
			Duration = 4,
		})
	end,
})

FromCode:CreateToggle({
	Name = "Warnings enabled",
	CurrentValue = true,
	Callback = function(value)
		-- off: confirmations are accepted automatically and notices are skipped, blocking checks stay
		Library:SetWarnings(value)
	end,
})

----------------------------------------------------------------------------------------------------
-- Config + notifications
----------------------------------------------------------------------------------------------------
local Settings = Window:CreateTab("Settings")
local Configs = Settings:CreateSection("Config")

local configName = "default"
Configs:CreateInput({
	Name = "Config name",
	CurrentValue = configName,
	Callback = function(text)
		configName = text ~= "" and text or "default"
	end,
})

Configs:CreateButton({
	Name = "Save",
	Callback = function()
		local ok, err = Library:SaveConfig(configName)
		Library:Notify({
			Title = ok and "Saved" or "Save failed",
			Content = ok and configName or tostring(err),
			Type = ok and "Success" or "Error",
		})
	end,
})

Configs:CreateButton({
	Name = "Load",
	Callback = function()
		local ok, err = Library:LoadConfig(configName)
		Library:Notify({
			Title = ok and "Loaded" or "Load failed",
			Content = ok and configName or tostring(err),
			Type = ok and "Success" or "Warning",
		})
	end,
})

local Notices = Settings:CreateSection("Notifications")

Notices:CreateButton({
	Name = "Info",
	Callback = function()
		Library:Notify({ Title = "Info", Content = "Disappears after 5 seconds (the default).", Type = "Info" })
	end,
})

Notices:CreateButton({
	Name = "With actions",
	Callback = function()
		Library:Notify({
			Title = "Update available",
			Content = "Stays until you pick something.",
			Type = "Warning",
			Duration = 0, -- 0 or false: sticky
			Actions = {
				{ Name = "Update", Callback = function() print("updating...") end },
				{ Name = "Later" },
			},
		})
	end,
})

Notices:CreateButton({
	Name = "Flood the queue (8)",
	Callback = function()
		for i = 1, 8 do
			Library:Notify({ Title = "#" .. i, Content = "At most " .. Library.Notifications.Max .. " are visible, the rest queue.", Duration = 3 })
		end
	end,
})

local Danger = Settings:CreateSection("Danger zone")
Danger:CreateButton({
	Name = "Unload UI",
	Callback = function()
		-- Confirm yields until the user answers; button callbacks run in their own thread, so that is fine
		if Library:Confirm({ Title = "Unload?", Content = "The window and all settings in memory will be gone.", Yes = "Unload", Danger = true }) then
			Library:Destroy()
		end
	end,
})

Danger:CreateButton({
	Name = "Show a dialog",
	Callback = function()
		Library:Dialog({
			Title = "Custom dialog",
			Content = "Any number of buttons, each with its own callback.",
			Buttons = {
				{ Name = "Not now" },
				{ Name = "Keep open", Keep = true, Callback = function() print("still here") end },
				{ Name = "Do it", Style = "Primary", Callback = function() print("done") end },
			},
		})
	end,
})

Window:SelectTab("Controls")

Library:Notify({ Title = "Crystall UI", Content = "Press RightShift to hide the window.", Type = "Info" })
