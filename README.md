# Crystall UI

A modern, modular, Rayfield-style Roblox Luau UI library with decoupled **Color Palettes** and **Motion Profiles**, live theme hot-swapping, stacked notifications, flag-based config serialization, and full connection/tween cleanup.

---

## Features

- **Remote Modular Loader (`Init.luau`)**: Loads and caches modules dynamically from GitHub via `game:HttpGet` + `loadstring`.
- **Decoupled Visuals & Motion**: Mix any color **Palette** (`Amethyst`, `RoyalTopaz`) with any **Motion Profile** (`Minimal`, `Brutal`) at runtime without recreating UI elements.
- **Rayfield-Style API**: Familiar `CreateWindow` → `CreateTab` → `CreateSection` → `Create*` hierarchy. Controls can be placed directly inside a `Tab` or grouped inside a `Section`.
- **Safe Parenting & Cleanup**: Automatically targets `gethui()` → `CoreGui` → `PlayerGui` (with `syn.protect_gui` support) and cleans up all `RBXScriptConnection`s, tweens, and `ScreenGui` instances via `Destroy()`.
- **Config System**: Built-in `Flags` registry with JSON/table `ExportConfig()` and `ImportConfig()`.

---

## Repository Structure

```text
CrystallUI/
├── Init.luau              # Entry point & remote module loader/cacher
└── src/
    ├── ThemeEngine.luau   # Palettes, Motion Profiles, Animator, ThemeBinder
    ├── Core.luau          # Window, Tabs, Sections, Maid cleanup, Config API
    ├── Notifications.luau # Stacked notification queue
    └── Controls.luau      # All UI controls & element builders
```

---

## Quick Start

```lua
local Crystall = loadstring(game:HttpGet("https://raw.githubusercontent.com/TerraKill765747646/CrystallUI/refs/heads/main/Init.luau"))()

local Window = Crystall:CreateWindow({
	Name = "Crystall Hub",
	Subtitle = "v1.0.0",
	ToggleKey = Enum.KeyCode.RightShift,
	Theme = { Palette = "Amethyst", Motion = "Minimal" },
})

local MainTab = Window:CreateTab("Main")
local Section = MainTab:CreateSection("Actions", { Collapsible = true })

Section:CreateButton({
	Name = "Test Notification",
	Callback = function()
		Crystall:Notify({
			Title = "Ready",
			Content = "Crystall UI loaded successfully.",
			Duration = 4,
			Type = "Success",
		})
	end,
})
```

### Custom Loader Options

You can pass a custom base URL or initial theme table when executing `Init.luau`:

```lua
local Crystall = loadstring(game:HttpGet(".../Init.luau"))({
	RepoUrl = "https://raw.githubusercontent.com/USER/REPO/main/",
	Theme = { Palette = "RoyalTopaz", Motion = "Minimal" },
})
```

Passing a string directly is also supported: `loadstring(game:HttpGet(".../Init.luau"))("https://raw.githubusercontent.com/USER/REPO/main/")`.

---

## API Reference

### `Library` (Root Object)

#### Properties
- `Library.Version`: `string` (`"1.0.0"`)
- `Library.Flags`: `{ [string]: Element }` — Registry of all elements created with a `Flag`.
- `Library.Windows`: `{ Window }` — Active window instances.
- `Library.Theme`: `ThemeEngine` — Direct reference to the theme engine.
- `Library.RepoUrl`: `string` — Active base URL used by `Import`.

#### Methods
- `Library:CreateWindow(options: WindowOptions) -> Window`
- `Library:Notify(options: NotifyOptions | string) -> NotificationHandle`
- `Library:SetPalette(name: string, keepMotion: boolean?)`
  - Switches the active palette. If `keepMotion` is omitted/falsy and the palette defines `DefaultMotion`, it also switches the motion profile. Pass `true` (or use `SetTheme`) to preserve the current motion profile.
- `Library:SetMotion(name: string)`
  - Switches the active motion profile (`"Minimal"`, `"Brutal"`, or custom).
- `Library:SetTheme(config: { Palette: string?, Motion: string? })`
  - Applies palette and/or motion independently in one call.
- `Library:RegisterPalette(name: string, palette: table) -> table`
  - Registers a new palette (clones `Amethyst` defaults for any omitted keys).
- `Library:RegisterMotion(name: string, motion: table) -> table`
  - Registers a new motion profile (clones `Minimal` defaults for any omitted keys).
- `Library:GetFlag(flag: string) -> any`
  - Returns the current value of `Library.Flags[flag]:Get()`.
- `Library:ExportConfig(asTable: boolean?) -> string | table`
  - Exports all flag values as a JSON string (default) or a Lua table (`asTable = true`).
- `Library:ImportConfig(data: string | table) -> (boolean, string?)`
  - Restores flag values from a JSON string or table by calling `:Set(value)` on matching elements.
- `Library:Destroy()`
  - Destroys all windows, notification GUIs, active tweens, connections, theme bindings, and clears `Flags`.

---

### Window

Created via `Library:CreateWindow(options)`.

#### `WindowOptions`
| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `Name` | `string?` | `"Crystall UI"` | Window title. |
| `Subtitle` | `string?` | `nil` | Optional secondary line below title. |
| `Size` | `UDim2?` | `UDim2.fromOffset(560, 380)` | Window dimensions. |
| `ToggleKey` | `Enum.KeyCode \| string?` | `Enum.KeyCode.RightShift` | Keybind to show/hide the window. |
| `Search` | `boolean?` | `true` | Set to `false` to hide the sidebar tab search box. |
| `Theme` | `{ Palette: string?, Motion: string? }?` | `nil` | Optional theme applied on creation. |

#### Window Methods
- `Window:CreateTab(name: string, icon: string?) -> Tab`
- `Window:Toggle(state: boolean?)` — Opens/closes the window (`nil` toggles current state).
- `Window:Minimize(state: boolean?)` — Collapses/expands the window (`nil` toggles current state).
- `Window:SetToggleKey(key: Enum.KeyCode | string | nil)` — Updates the window toggle keybind.
- `Window:Destroy()` — Destroys this window and disconnects all its listeners.

---

### Tabs & Sections

Both `Tab` and `Section` inherit all `Create*` control methods, so controls can be added directly to either.

#### Tab Methods (`Window:CreateTab(name, icon)`)
- `Tab:Select()` — Switches view to this tab.
- `Tab:CreateSection(name: string, options: { Collapsible: boolean?, Collapsed: boolean? }?) -> Section`

#### Section Methods (`Tab:CreateSection(name, options)`)
- `Section:SetCollapsed(state: boolean)` — Collapses or expands section contents (when `Collapsible = true`).
- `Section:Destroy()` — Removes the section frame.

---

### Controls

#### Common Element Methods & Properties
Every control returns an `element` object with:
- `element.Instance`: `Frame`
- `element.Flag`: `string?`
- `element:SetTitle(text: string)`
- `element:SetVisible(state: boolean)`
- `element:Destroy()`

---

#### `CreateButton(options)`
| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `Name` | `string` | `""` | Button label. |
| `Flag` | `string?` | `nil` | Optional flag identifier. |
| `Callback` | `(() -> ())?` | `nil` | Invoked on click. |

---

#### `CreateToggle(options)`
| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `Name` | `string` | `""` | Toggle label. |
| `CurrentValue` / `Default` | `boolean?` | `false` | Initial state (`CurrentValue` takes priority). |
| `Flag` | `string?` | `nil` | Flag key for config export/import. |
| `Callback` | `((value: boolean) -> ())?` | `nil` | Invoked when state changes. |

- `toggle:Set(value: boolean, silent: boolean?)`
- `toggle:Get() -> boolean`

---

#### `CreateChecklist(options)`
Multi-select checkbox list with built-in **Select All** and **Clear** buttons.

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `Name` | `string` | `""` | Checklist header title. |
| `Options` | `{ string }` | `{}` | List of selectable item names. |
| `CurrentValue` / `Default` | `{ string }?` | `{}` | Initially selected options. |
| `Flag` | `string?` | `nil` | Flag key for config export/import. |
| `Callback` | `((selected: { string }) -> ())?` | `nil` | Invoked with ordered array of selected items. |

- `checklist:GetSelected() -> { string }` (alias: `checklist:Get()`)
- `checklist:Set(list: { string }, silent: boolean?)`

---

#### `CreateSlider(options)`
Draggable slider with direct numeric `TextBox` input.

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `Name` | `string` | `""` | Slider label. |
| `Range` | `{ number }` | `{ 0, 100 }` | `{ min, max }` bounds. |
| `Increment` | `number?` | `1` | Step size. |
| `Suffix` | `string?` | `nil` | Optional unit suffix (e.g. `"studs"`, `"%"`). |
| `CurrentValue` / `Default` | `number?` | `min` | Initial value. |
| `Flag` | `string?` | `nil` | Flag key for config export/import. |
| `Callback` | `((value: number) -> ())?` | `nil` | Invoked when value changes. |

- `slider:Set(value: number, silent: boolean?, instant: boolean?)`
- `slider:Get() -> number`

---

#### `CreateDropdown(options)`
Supports single-select, multi-select, live search filtering, and dynamic option refreshing.

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `Name` | `string` | `""` | Dropdown label. |
| `Options` | `{ string }` | `{}` | Available choices. |
| `CurrentOption` / `Default` | `string \| { string }?` | `nil` | Initial selection. |
| `MultipleOptions` / `Multi` | `boolean?` | `false` | Enable multi-select mode. |
| `Search` | `boolean?` | `false` | Enable search filter box inside dropdown. |
| `Flag` | `string?` | `nil` | Flag key for config export/import. |
| `Callback` | `((value: string \| { string }) -> ())?` | `nil` | Invoked when selection changes. |

- `dropdown:Set(value: string | { string } | nil, silent: boolean?)`
- `dropdown:Get() -> string | { string } | nil`
- `dropdown:Refresh(newOptions: { string }, keepSelection: boolean?)`
- `dropdown:SetOpen(state: boolean)`

---

#### `CreateKeybind(options)`
Press `Escape` or `Backspace` while listening to clear a keybind to `"None"`.

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `Name` | `string` | `""` | Keybind label. |
| `CurrentKeybind` / `Default` | `Enum.KeyCode \| string?` | `nil` | Initial key (e.g. `"F"` or `Enum.KeyCode.F`). |
| `Flag` | `string?` | `nil` | Flag key for config export/import. |
| `Callback` | `((key: Enum.KeyCode) -> ())?` | `nil` | Fires when the bound key is pressed (unprocessed). |
| `ChangedCallback` | `((key: Enum.KeyCode?) -> ())?` | `nil` | Fires when the user assigns or clears the key. |

- `keybind:Set(key: Enum.KeyCode | string | nil, silent: boolean?)`
- `keybind:Get() -> string` — Returns `KeyCode.Name` or `"None"`.

---

#### `CreateInput(options)`
| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `Name` | `string` | `""` | Input label. |
| `PlaceholderText` | `string?` | `"Type here..."` | Placeholder shown when empty. |
| `CurrentValue` / `Default` | `string?` | `""` | Initial text. |
| `RemoveTextAfterFocusLost` | `boolean?` | `false` | Clears input box visually after focus lost. |
| `Flag` | `string?` | `nil` | Flag key for config export/import. |
| `Callback` | `((text: string, enterPressed: boolean) -> ())?` | `nil` | Invoked on `FocusLost`. |

- `input:Set(text: string, silent: boolean?)`
- `input:Get() -> string`

---

#### `CreateLabel(options)` / `CreateParagraph(options)` / `CreateDivider()`
- **`CreateLabel(text | { Text?, Name?, Flag? })`**
  - `label:Set(text: string)`
- **`CreateParagraph({ Title?, Content?, Flag? })`**
  - `paragraph:Set(data: string | { Title?: string, Content?: string })`
- **`CreateDivider()`**
  - Renders a horizontal theme-aware separator line.

---

### Notifications

`Library:Notify(options)` manages a bottom-right stacked queue (`Max = 4` concurrent notifications).

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `Title` | `string?` | `"Notification"` | Header text. |
| `Content` | `string?` | `""` | Body text (auto-wraps). |
| `Duration` | `number?` | `5` | Auto-dismiss time in seconds. |
| `Type` | `"Info" \| "Success" \| "Warning" \| "Error"?` | `nil` (`Accent`) | Accent stripe & progress bar color key. |
| `Actions` | `{ { Name: string?, Callback: (() -> ())? } }?` | `nil` | Optional action buttons (clicking closes the toast). |

Returns `handle` with `handle:Close()`.

---

## Themes & Custom Presets

### Built-in Presets
- **Palettes**: `"Amethyst"` (default), `"RoyalTopaz"`
- **Motions**: `"Minimal"` (default for `Amethyst`), `"Brutal"` (default for `RoyalTopaz`)

### Custom Palette & Motion Schema

```lua
Crystall:RegisterPalette("Emerald", {
	Background = Color3.fromRGB(12, 20, 16),
	Surface = Color3.fromRGB(20, 32, 26),
	Elevated = Color3.fromRGB(30, 48, 39),
	Stroke = Color3.fromRGB(48, 78, 62),
	Accent = Color3.fromRGB(64, 224, 144),
	AccentText = Color3.fromRGB(10, 20, 14),
	Text = Color3.fromRGB(235, 245, 240),
	SubText = Color3.fromRGB(145, 175, 160),
})

Crystall:RegisterMotion("Snappy", {
	Duration = 0.2,
	Fast = 0.1,
	Style = Enum.EasingStyle.Exponential,
	Direction = Enum.EasingDirection.Out,
	ColorStyle = Enum.EasingStyle.Quad,
	Scale = 0.88,
	Offset = 20,
})

Crystall:SetTheme({ Palette = "Emerald", Motion = "Snappy" })
```

Listen to live theme changes:

```lua
local conn = Crystall.Theme:OnChanged(function(kind, name)
	print("Theme changed:", kind, name) -- kind is "Palette" or "Motion"
end)
-- conn:Disconnect()
```

---

## Full Usage Example

```lua
local Crystall = loadstring(game:HttpGet("https://raw.githubusercontent.com/TerraKill765747646/CrystallUI/refs/heads/main/Init.luau"))()

local Window = Crystall:CreateWindow({
	Name = "Crystall Demo",
	Subtitle = "Full API",
	ToggleKey = Enum.KeyCode.RightShift,
	Search = true,
	Theme = { Palette = "Amethyst", Motion = "Minimal" },
})

local Combat = Window:CreateTab("Combat")
local Misc = Combat:CreateSection("Utilities", { Collapsible = true })

Misc:CreateToggle({
	Name = "Auto Parry",
	CurrentValue = false,
	Flag = "AutoParry",
	Callback = function(v) print("AutoParry:", v) end,
})

Misc:CreateSlider({
	Name = "Reach",
	Range = { 5, 30 },
	Increment = 0.5,
	Suffix = "studs",
	CurrentValue = 12,
	Flag = "Reach",
	Callback = function(v) print("Reach:", v) end,
})

Misc:CreateDropdown({
	Name = "Targets",
	Options = { "Players", "NPCs", "Bosses" },
	CurrentOption = { "Players" },
	MultipleOptions = true,
	Search = true,
	Flag = "Targets",
	Callback = function(list) print("Targets:", table.concat(list, ", ")) end,
})

Misc:CreateChecklist({
	Name = "Checks",
	Options = { "Visible", "Alive", "TeamCheck" },
	CurrentValue = { "Alive" },
	Flag = "Checks",
	Callback = function(list) print("Checks:", table.concat(list, ", ")) end,
})

local Settings = Window:CreateTab("Settings")

Settings:CreateDropdown({
	Name = "Palette",
	Options = { "Amethyst", "RoyalTopaz" },
	CurrentOption = "Amethyst",
	Callback = function(p) Crystall:SetPalette(p, true) end,
})

Settings:CreateDropdown({
	Name = "Motion",
	Options = { "Minimal", "Brutal" },
	CurrentOption = "Minimal",
	Callback = function(m) Crystall:SetMotion(m) end,
})

local savedJson = ""
Settings:CreateButton({
	Name = "Export Config",
	Callback = function()
		savedJson = Crystall:ExportConfig()
		Crystall:Notify({ Title = "Config", Content = "Exported to memory.", Type = "Info" })
	end,
})

Settings:CreateButton({
	Name = "Import Config",
	Callback = function()
		if savedJson ~= "" then
			Crystall:ImportConfig(savedJson)
		end
	end,
})

Settings:CreateButton({
	Name = "Unload UI",
	Callback = function() Crystall:Destroy() end,
})
```
