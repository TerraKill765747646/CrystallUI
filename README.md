# Crystall UI

Библиотека интерфейса для Roblox (Luau): окна, вкладки, секции, контролы, темы с анимацией, уведомления, конфиги.
Модули подгружаются по HTTP одной строкой, зависимостей нет.

```
Init.luau            точка входа, лоадер модулей, публичный API
src/ThemeEngine      палитры, профили анимации, биндинг цветов к инстансам
src/Core             окно, вкладки, секции, Maid, флаги, конфиги
src/Controls         все контролы
src/Notifications    очередь уведомлений
Example.luau         демо всех возможностей
Tests.luau           переносимый набор тестов (executor и headless)
tests/               мок Roblox API и раннер для headless-прогона
```

## Установка

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/TerraKill765747646/CrystallUI/main/Init.luau"))()
```

### Параметры загрузки

| Поле | Что делает |
|---|---|
| `RepoUrl` | Базовый URL с файлами (`src/Core.luau` и т.д.). Слэш в конце необязателен. |
| `Theme` | `{ Palette = "...", Motion = "..." }`, применяется сразу после загрузки. |
| `LocalPath` | Папка в workspace экзекьютора. Модули читаются через `readfile`, сеть не нужна. Удобно при разработке. |
| `Loader` | `function(path) -> string`, полная замена загрузчика. `path` вида `"src/Core"`. |

## Быстрый старт

```lua
local Window = Library:CreateWindow({ Name = "My Hub", Subtitle = "v1", ToggleKey = "RightShift" })
local Tab = Window:CreateTab("Main")
local Section = Tab:CreateSection("Combat")

Section:CreateToggle({
	Name = "Auto farm",
	Flag = "autofarm",
	CurrentValue = false,
	Callback = function(value) print(value) end,
})

Library:Notify({ Title = "Ready", Content = "Loaded.", Type = "Success" })
```

Полный пример со всеми контролами: `Example.luau`.

## Окно

```lua
Library:CreateWindow({
	Name = "Crystall UI",       -- заголовок
	Subtitle = nil,             -- мелкий текст под заголовком
	Size = UDim2.fromOffset(560, 380),
	ToggleKey = "RightShift",   -- имя KeyCode, EnumItem или false (без хоткея)
	Search = true,              -- false убирает поиск по вкладкам
	Theme = { Palette = "Amethyst", Motion = "Minimal" },
})
```

| Метод | Описание |
|---|---|
| `Window:CreateTab(name, icon?)` | Новая вкладка. `icon` — любая строка (эмодзи, символ), печатается перед названием. Первая вкладка выбирается сама. |
| `Window:SelectTab(tab \| name \| index)` | Выбрать вкладку, возвращает её или `nil`. |
| `Window:Toggle(state?)` | Показать/скрыть. Без аргумента переключает. |
| `Window:Minimize(state?)` | Свернуть до заголовка. |
| `Window:SetToggleKey(key)` | Сменить хоткей. Невалидное имя отключает его. |
| `Window:Destroy()` | Убрать окно и все его подключения. |

Окно перетаскивается за заголовок и не уходит за пределы экрана.

`Tab:CreateSection(name, { Collapsible = false, Collapsed = false })` создаёт секцию. У секции есть `SetCollapsed(bool)`, `SetTitle(text)`, `Destroy()`.
Контролы можно создавать и прямо на вкладке, без секции.

## Контролы

Создаются методами `CreateXxx` у вкладки или секции. Общие поля и методы у всех:

| | |
|---|---|
| `Name` | Подпись. |
| `Flag` | Строковый ключ для конфигов и `Library:GetFlag`. Повтор ключа выводит предупреждение, побеждает последний элемент. |
| `Callback` | Вызывается в отдельном потоке, ошибки ловятся и выводятся через `warn`. |
| `api:SetTitle(text)`, `api:SetVisible(bool)`, `api:Destroy()` | Работают у каждого элемента. `Destroy` освобождает флаг. |
| `api.Instance` | Корневой `Frame` элемента. |

`Set(value, silent)` у всех значимых элементов: если `silent` истинно, колбэк не вызывается.

| Контрол | Опции | Методы | Колбэк |
|---|---|---|---|
| `CreateButton` | `Name`, `Callback` | | `()` |
| `CreateToggle` | `CurrentValue` (или `Default`) | `Get()`, `Set(bool)` | `(value)` |
| `CreateSlider` | `Range = {min, max}`, `Increment = 1`, `Suffix`, `CurrentValue` | `Get()`, `Set(n)` | `(value)` |
| `CreateDropdown` | `Options`, `CurrentOption`, `Multi` (`MultipleOptions`), `Search` | `Get()`, `Set(v)`, `Refresh(options, keepSelection)`, `SetOpen(bool)` | `(value)`, у `Multi` — список |
| `CreateChecklist` | `Options`, `CurrentValue` (список) | `Get()`, `Set(list)` | `(list)` |
| `CreateKeybind` | `CurrentKeybind` (имя или EnumItem) | `Get()` (имя клавиши или `"None"`), `Set(key)` | `Callback(key)` при нажатии, `ChangedCallback(key)` при смене |
| `CreateInput` | `CurrentValue`, `PlaceholderText`, `RemoveTextAfterFocusLost` | `Get()`, `Set(text)` | `(text, enterPressed)` |
| `CreateLabel` | строка или `{ Text }` | `Set(text)` | |
| `CreateParagraph` | `Title`, `Content` | `Set(string \| { Title, Content })` | |
| `CreateDivider` | | | |

Детали поведения:

- Слайдер зажимает значение в диапазон и округляет до `Increment`. Число можно ввести руками, строки с числом принимаются, мусор игнорируется. Нулевой или отрицательный `Increment` заменяется на `1`, перевёрнутый `Range` разворачивается.
- Клавиша в `CreateKeybind` после клика на кнопку ждёт нажатия. `Escape` и `Backspace` снимают привязку.
- `Dropdown:Refresh(newOptions, true)` сохраняет только те выбранные значения, что остались в новом списке.
- Метки (`CreateLabel`) переносят длинный текст.

## Флаги и конфиги

```lua
Library:GetFlag("autofarm")            -- текущее значение или nil
local json = Library:ExportConfig()    -- JSON-строка
local tbl  = Library:ExportConfig(true)-- таблица { flag = value }
Library:ImportConfig(json)             -- принимает строку или таблицу, возвращает true | false, причина
```

Неизвестные флаги при импорте пропускаются. Импорт вызывает колбэки, как обычный `Set`.

Сохранение на диск (нужны `writefile`/`readfile` в экзекьюторе, файлы лежат в `CrystallUI/configs/<имя>.json`):

```lua
Library:SaveConfig("legit")   -- true | false, причина
Library:LoadConfig("legit")
Library:ListConfigs()         -- { "legit", ... }
```

Без файлового API методы возвращают `false` и текст причины, ничего не падает. Недопустимые символы в имени заменяются на `_`.

## Темы

```lua
Library:SetPalette("RoyalTopaz")          -- сменит и профиль анимации на дефолтный для палитры
Library:SetPalette("RoyalTopaz", true)    -- оставить текущую анимацию
Library:SetMotion("Brutal")
Library:SetTheme({ Palette = "Emerald", Motion = "Minimal" })
```

Встроенные палитры: `Amethyst` (по умолчанию), `RoyalTopaz`, `Emerald`, `Quartz` (светлая).
Профили анимации: `Minimal`, `Brutal`, `Instant` (без анимации).
Неизвестное имя вызывает ошибку. Смена палитры плавно перекрашивает все живые элементы.

Свои палитры и профили наследуют недостающие ключи от дефолтных, значения проверяются:

```lua
Library:RegisterPalette("Rose", {
	Accent = Color3.fromRGB(244, 114, 182),
	AccentText = Color3.fromRGB(40, 8, 24),
})
Library:RegisterMotion("Slow", { Duration = 0.6, Fast = 0.3 })
```

Ключи палитры (все `Color3`): `Background`, `Surface`, `Elevated`, `Stroke`, `Accent`, `AccentText`, `Text`, `SubText`, `Success`, `Warning`, `Error`, `Info`. Плюс необязательный `DefaultMotion` (строка).
Ключи профиля: `Duration`, `Fast`, `Style`, `Direction`, `ColorStyle`, `Scale`, `Offset`.

Прочее: `Library.Theme:Get(key)`, `:ListPalettes()`, `:ListMotions()`, `:OnChanged(fn)` (колбэк получает `"Palette" | "Motion"` и имя, возвращает объект с `Disconnect()`).

Для своих инстансов используй `Library.Core.New` с полем `Theme`:

```lua
local Core = Library.Core
Core.New("Frame", { Theme = { BackgroundColor3 = "Surface" }, Parent = somewhere })
Core.New("TextLabel", { Theme = { TextColor3 = function(p) return flag and p.Accent or p.Text end }, Parent = somewhere })
```

Значение привязки: имя ключа палитры или функция `palette -> value`. Привязка снимается сама при `Destroy` инстанса.

## Уведомления

```lua
local handle = Library:Notify({
	Title = "Update",
	Content = "A new version is available.",
	Type = "Warning",        -- Info | Success | Warning | Error, влияет на цвет
	Duration = 5,            -- секунды; 0 или false: не исчезает само
	Actions = {
		{ Name = "Update", Callback = function() end },
		{ Name = "Later" },
	},
})
handle:Close()
```

`Library:Notify("просто текст")` тоже работает. Одновременно видно `Library.Notifications.Max` штук (по умолчанию 4), остальные ждут в очереди. Закрытие уведомления из очереди просто выкидывает его. Первая кнопка в `Actions` подсвечивается акцентом, любая кнопка закрывает уведомление.

## Жизненный цикл

`Library:Destroy()` закрывает все окна, уведомления, отключает все подключения, сбрасывает флаги и биндинги темы.
`Window:Destroy()` убирает только своё окно. Если нужен только один контрол, `api:Destroy()`.

## Запуск тестов

**В игре (экзекьютор).** Набор использует только публичный API и работает с настоящим UI. Запускай в чистой сессии: в конце он вызывает `Library:Destroy()`.

```lua
local Library = loadstring(game:HttpGet(REPO .. "Init.luau"))()
loadstring(game:HttpGet(REPO .. "Tests.luau"))()(Library)
```

Результат печатается в консоль, в конце возвращается `{ Passed, Failed, Failures }`.

**Headless (без Roblox).** Нужен бинарник `luau` в PATH ([релизы](https://github.com/luau-lang/luau/releases)) и Python 3:

```
python3 tests/run.py
```

Раннер собирает все модули в один скрипт, грузит их через `Config.Loader` поверх мока Roblox API (`tests/mock_roblox.luau`), гоняет `Tests.luau` и дополнительные интерактивные тесты (`tests/headless_extra.luau`: клики, драг слайдера, ввод клавиш, поиск, перетаскивание окна).
Мок не движок: твины применяют конечное значение, размеры не считаются. Он ловит логические и рантайм-ошибки, но верстку не проверяет.

## Что изменено в этой версии

Исправлено:

- Утечка памяти в движке тем: привязки цветов держали элементы живыми после `Destroy`. Теперь снимаются по `Destroying`.
- `api:Destroy()` не убирал элемент из Maid окна, список рос при каждом пересоздании контролов.
- `Init`: ошибка при выполнении модуля оставляла его в состоянии «загружается», все следующие попытки падали с ложным `Circular import`.
- Уведомления: проверка живого контейнера смотрела на `Parent`, который у уничтоженного `ScreenGui` остаётся прежним, поэтому после его удаления уведомления пропадали. Теперь проверяется `IsDescendantOf(game)`. `Duration = 0` и `math.huge` ломали твин прогресс-бара, теперь это «не исчезать». Таймер отменяется при ручном закрытии.
- Слайдер: на тач-устройствах страница скроллилась под пальцем при перетаскивании; нулевой `Increment` давал `NaN`; перевёрнутый `Range` ломал расчёты.
- Окно можно было утащить за экран без возможности вернуть.
- Индикатор активной вкладки рисовался поверх поиска, если вкладка уехала за край списка.
- Длинные `CreateLabel` вылезали за границы.
- `Window:CreateTab` и `Tab:CreateSection` падали при `nil` вместо имени.

Добавлено: `Window:SelectTab`, `Section:SetTitle`, `ToggleKey = false`, `Library:SaveConfig/LoadConfig/ListConfigs`, `Theme:ListPalettes/ListMotions`, палитры `Emerald` и `Quartz`, профиль `Instant`, загрузка через `Config.Loader` и `Config.LocalPath`, валидация в `RegisterPalette/RegisterMotion`, предупреждение о повторных флагах, `Maid:Remove`, поддержка потоков в `Maid`.

Проверено линтером `luau-analyze` и 49 тестами на моке. В живом Roblox не запускалось, так что верстку (перенос в `CreateLabel`, индикатор вкладок) стоит глянуть глазами.
