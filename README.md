# Crystall UI

Библиотека интерфейса для Roblox (Luau): окна, вкладки, секции, контролы, темы с анимацией, уведомления, конфиги.
Модули подгружаются по HTTP одной строкой, зависимостей нет.

```
Init.luau            точка входа, лоадер модулей, публичный API
src/ThemeEngine      палитры, профили анимации, биндинг цветов к инстансам
src/Core             окно, вкладки, секции, Maid, флаги, конфиги
src/Controls         все контролы
src/Notifications    очередь уведомлений
src/KeySystem        окно ввода ключа и проверка (фиксированные ключи, свой валидатор, HTTP API)
Example.luau         демо всех возможностей
Tests.luau           переносимый набор тестов (executor и headless)
tests/               мок Roblox API и раннер для headless-прогона
```

## Установка

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/TerraKill765747646/CrystallUI/main/Init.luau"))()
```

По умолчанию модули берутся из `TerraKill765747646/CrystallUI` (ветка `main`). Если репозиторий лежит в другом месте, передай адрес явно:

```lua
local Library = loadstring(game:HttpGet(INIT_URL))("https://example.com/crystall/")          -- строка = RepoUrl
local Library = loadstring(game:HttpGet(INIT_URL))({ RepoUrl = "https://example.com/crystall/" })
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
	MobileButton = nil,         -- плавающая кнопка открытия: nil = только на тач-устройствах, true/false = принудительно
	ToggleIcon = nil,           -- своя строка-символ для плавающей кнопки, по умолчанию рисуется ромб
	Icon = nil,                 -- своя строка-символ слева от заголовка, по умолчанию рисуется ромб, false убирает
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
| `Window:SetMobileButton(bool)` | Показать/скрыть плавающую кнопку (при `true` создаст её, если её не было). |
| `Window:Destroy()` | Убрать окно и все его подключения. |

Окно перетаскивается за заголовок и не уходит за пределы экрана.

### Плавающая кнопка (телефон)

На тач-устройствах у окна появляется круглая кнопка с акцентной обводкой и символом кристалла. Тап открывает и закрывает окно (хоткей на телефоне недоступен, а крестик окно только прячет). Кнопка следует за пальцем только по его смещению: она не читает `AbsolutePosition`, поэтому отступ сверху, безопасные зоны и момент раскладки не могут увести её от точки касания. Если схватить её во время примагничивания, она продолжит с того места, где остановилась. Кнопку можно перетащить: сдвиг меньше 8 px считается тапом, больше начинает перетаскивание. При отпускании она примагничивается к левому или правому краю, не выходит за экран и подтягивается обратно при повороте экрана. Пока окно открыто, кнопка полупрозрачная, когда скрыто, залита сплошным цветом. Цвета следуют за палитрой. Внешний вид доступен как `Window.ToggleButton`.

```lua
Library:CreateWindow({ Name = "Hub", MobileButton = true })  -- показать и на ПК
```

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
| `api:SetLocked(bool)`, опция `Locked` | Блокировка: элемент затемняется и не принимает ввод. Из кода `Set` по-прежнему работает. У открытого списка блокировка его закрывает. |
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
| `CreateColorPicker` | `CurrentValue` (Color3 или hex), `Default` | `Get()` (Color3), `GetHex()`, `Set(Color3 \| hex, silent)`, `SetOpen(bool)` | `(color3)` |
| `CreateLabel` | строка или `{ Text }` | `Set(text)` | |
| `CreateParagraph` | `Title`, `Content` | `Set(string \| { Title, Content })` | |
| `CreateDivider` | | | |

Детали поведения:

- Слайдер зажимает значение в диапазон и округляет до `Increment`. Число можно ввести руками, строки с числом принимаются, мусор игнорируется. Нулевой или отрицательный `Increment` заменяется на `1`, перевёрнутый `Range` разворачивается.
- Клавиша в `CreateKeybind` после клика на кнопку ждёт нажатия. `Escape` и `Backspace` снимают привязку.
- `Dropdown:Refresh(newOptions, true)` сохраняет только те выбранные значения, что остались в новом списке.
- Метки (`CreateLabel`) переносят длинный текст.
- Выпадающий список и палитра открываются отдельной панелью поверх окна, а не раздвигают страницу. Панель следует за строкой при скролле и перетаскивании окна, переворачивается вверх, если снизу нет места, закрывается кликом вне её, при смене вкладки и при скрытии окна. Одновременно открыта только одна. Сама панель доступна как `api.Popup`.
- `CreateColorPicker`: квадрат насыщенности и яркости, полоса оттенка, поле hex (`#RRGGBB` или `#RGB`). В конфиг цвет пишется строкой hex. Серый и чёрный цвета не сбрасывают выбранный оттенок.

## Флаги и конфиги

```lua
Library:GetFlag("autofarm")            -- текущее значение или nil
local json = Library:ExportConfig()    -- JSON-строка
local tbl  = Library:ExportConfig(true)-- таблица { flag = value }
Library:ImportConfig(json)             -- принимает строку или таблицу, возвращает true | false, причина
```

В конфиг входит и тема (`__theme = { Palette, Motion }`), она применяется до значений контролов. Неизвестная палитра в конфиге игнорируется. Неизвестные флаги при импорте пропускаются. Импорт вызывает колбэки, как обычный `Set`.

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

## Диалоги

```lua
Library:Dialog({
	Title = "Update",
	Content = "A new version is available.",
	Buttons = {
		{ Name = "Later" },
		{ Name = "Details", Keep = true, Callback = function() end },       -- Keep: не закрывать после клика
		{ Name = "Update", Style = "Primary", Callback = function() end },  -- Style: Primary | Default | Danger
	},
	OnClose = function() end,
})

if Library:Confirm({ Title = "Delete?", Content = "This can't be undone.", Yes = "Delete", No = "Cancel", Danger = true }) then
	-- ...
end
```

`Dialog` возвращает модальное окно с `:Close()`. `Confirm` блокирует поток до ответа и возвращает `true` или `false` (закрытие крестиком это `false`). Вызывай его из потока, которому можно уступать (колбэки контролов и основной поток скрипта подходят).

## Система ключей

Окно ввода ключа перед запуском скрипта. Скрипт ждёт, пока ключ не будет принят.

```lua
local ok, key = Library:KeySystem({
	Title = "My Hub",
	Subtitle = "Enter your key to continue.",
	Keys = { "ABC-123", "DEF-456" },            -- фиксированные ключи (или Key = "..." для одного)
	Links = { { Name = "Get key", Url = "https://example.com/key" } },
	SaveKey = true,
	MaxAttempts = 5,
})
if not ok then return end
-- дальше строим окно
```

Источники проверки можно комбинировать, подходит любой из них. Порядок: фиксированные ключи, `Validate`, `Api`.

**Свой валидатор.** Функция получает ключ и возвращает `true` или `false, "сообщение"`. Внутри можно ходить в любой API самостоятельно. Ошибка внутри считается неудачной попыткой, а не падением.

```lua
Validate = function(key)
	local response = game:HttpGet("https://example.com/check?key=" .. key)
	return response == "ok", "Key expired"
end
```

**HTTP API из коробки.**

```lua
Api = {
	Url = "https://example.com/api/check?key={key}&hwid={hwid}",
	Method = "GET",                      -- по умолчанию GET, а с Body POST
	Headers = { Authorization = "Bearer ..." },
	Body = { key = "{key}", product = "hub" },   -- таблица уходит как JSON
	Success = function(response)
		return response.Json and response.Json.status == "active", response.Json and response.Json.message
	end,
	Timeout = 10,
}
```

`{key}` в URL кодируется, `{hwid}` это идентификатор клиента. Используется `request`/`http_request` экзекьютора, для GET без него запасной вариант `game:HttpGet`. `response` содержит `StatusCode`, `Body`, `Headers` и `Json` (разобранное тело или `nil`). `Request = function(options) -> response` заменяет транспорт целиком.
Без своей `Success` ключ принимается только если ответ 2xx и тело это `{"valid": true}`, `{"success": true}` или голое `true`/`valid`/`ok`. Страница ошибки с кодом 200 ничего не открывает. Таймаут, сетевая ошибка и исключение это неудачная попытка.

| Опция | |
|---|---|
| `Title`, `Subtitle`, `Icon`, `Note`, `Placeholder`, `ButtonText`, `Width` | Тексты и вид окна. |
| `Links` | Кнопки со ссылками (`Name`, `Url`, `Callback`). Ссылка копируется в буфер, без `setclipboard` показывается текстом. `GetKey = "url"` короткая форма для одной. |
| `SaveKey`, `Id` | Запомнить принятый ключ в `CrystallUI/keys/<Id>.txt`. При запуске он проверяется заново, устаревший удаляется и окно показывается снова. `Id` по умолчанию равен `Title`. |
| `MaxAttempts` | После стольких неудач окно закрывается, результат `false`. |
| `Cooldown` | Пауза между попытками, по умолчанию 1 секунда. |
| `Timeout` | Предел ожидания проверки, по умолчанию 10 секунд. |
| `Closable` | `false` убирает крестик, по умолчанию `true`. |
| `OnSuccess(key)`, `OnFail(reason)`, `OnReady(handle)` | Колбэки. |
| `Async` | Вернуть управление сразу и получить `handle` (`Finished`, `Ok`, `Key`, `Reason`, `Attempts`, `:Close()`, `:Submit(text)`). |

`Library:ForgetKey(id)` удаляет сохранённый ключ.

Честно о защите: всё, что выполняется на клиенте, можно прочитать и обойти, это относится и к зашитым ключам, и к проверке по API (ответ сервера можно подделать, а вызов проверки вырезать). Фиксированные ключи это вежливая табличка, серверная проверка с привязкой к `hwid` делает обход заметно дороже, но не невозможным. Не клади в скрипт секреты, которые нельзя раскрывать.

## Жизненный цикл

`Library:Destroy()` закрывает все окна, диалоги, уведомления, отключает все подключения, сбрасывает флаги и биндинги темы.
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

Раннер собирает все модули в один скрипт, грузит их через `Config.Loader` поверх мока Roblox API (`tests/mock_roblox.luau`), гоняет `Tests.luau` и дополнительные интерактивные тесты (`tests/headless_extra.luau`: клики, драг слайдера и палитры, ввод клавиш, поиск, перетаскивание окна, закрытие панелей, диалоги, окно ключа).
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

Внешний вид (по замечаниям с телефона): иконки (ромб, стрелки списков и секций, крестик и плюс/минус в шапке, закрытие диалогов и уведомлений, галочка в чекбоксе) теперь рисуются из скруглённых полос и повёрнутых квадратов, а не печатаются символами шрифта, поэтому лежат ровно по центру. Левый край сайдбара больше не прорезает скругление окна: из четырёх скруглённых углов его заливки виден только нижний левый, того же радиуса, что у окна. У уведомления цветная кромка идёт ровно по скруглению карточки (акцентная форма под лицевой частью, сдвинутой на 3 пикселя), а таймер лежит внутри карточки с отступом и больше не упирается в кромку и не выходит за углы. Страницы не доходят 6 пикселей до верха и низа окна, и полоса прокрутки не цепляет скругления. Метка у заголовка секции со скруглёнными концами.

Добавлено: система ключей (`Library:KeySystem`), диалоги (`Dialog`, `Confirm`), `CreateColorPicker`, блокировка элементов (`SetLocked`, `Locked`), выпадающие списки поверх страницы вместо раздвигания строки, тема внутри конфига, внешний вид (символ перед заголовком окна, акцентная линия под шапкой, подсветка вкладок при наведении, акцентная метка у секций), плавающая кнопка открытия для телефона (`MobileButton`, `ToggleIcon`, `Window:SetMobileButton`), `Window:SelectTab`, `Section:SetTitle`, `ToggleKey = false`, `Library:SaveConfig/LoadConfig/ListConfigs`, `Theme:ListPalettes/ListMotions`, палитры `Emerald` и `Quartz`, профиль `Instant`, загрузка через `Config.Loader` и `Config.LocalPath`, валидация в `RegisterPalette/RegisterMotion`, предупреждение о повторных флагах, `Maid:Remove`, поддержка потоков в `Maid`.

Проверено линтером `luau-analyze` и 91 тестом на моке. В живом Roblox не запускалось, так что верстку и внешний вид (перенос в `CreateLabel`, индикатор вкладок, панели списков и палитры, градиенты в ColorPicker, окно ключа) стоит глянуть глазами.
