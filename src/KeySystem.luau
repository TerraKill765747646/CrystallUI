local Import = ...
local Core = Import("src/Core")
local Theme, Animator, New = Core.Theme, Core.Animator, Core.New

local HttpService = game:GetService("HttpService")

local KeySystem = {}

local KEY_DIR = "CrystallUI/keys"

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------

local function Trim(text)
	return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Hwid()
	local ok, id = pcall(function()
		return game:GetService("RbxAnalyticsService"):GetClientId()
	end)
	return if ok and type(id) == "string" then id else "unknown"
end

local function KeyPath(id)
	return KEY_DIR .. "/" .. tostring(id):gsub("[^%w_%-]", "_") .. ".txt"
end

local function ReadSaved(id)
	if not (readfile and isfile) then
		return nil
	end
	local path = KeyPath(id)
	local ok, exists = pcall(isfile, path)
	if not (ok and exists) then
		return nil
	end
	local read, content = pcall(readfile, path)
	content = read and Trim(content) or ""
	return if content ~= "" then content else nil
end

local function WriteSaved(id, key)
	if not (writefile and makefolder and isfolder) then
		return false
	end
	return pcall(function()
		if not isfolder("CrystallUI") then
			makefolder("CrystallUI")
		end
		if not isfolder(KEY_DIR) then
			makefolder(KEY_DIR)
		end
		writefile(KeyPath(id), key)
	end)
end

function KeySystem:ForgetKey(id)
	if delfile and isfile then
		pcall(function()
			if isfile(KeyPath(id)) then
				delfile(KeyPath(id))
			end
		end)
	end
end

-- replaces {key} and {hwid}; `encode` url-encodes the key (for query strings)
local function Substitute(value, vars, encode)
	if type(value) == "string" then
		return (value:gsub("{(%w+)}", function(name)
			local replacement = vars[name]
			if replacement == nil then
				return nil
			end
			return if encode then HttpService:UrlEncode(replacement) else replacement
		end))
	elseif type(value) == "table" then
		local out = {}
		for k, v in value do
			out[k] = Substitute(v, vars, false)
		end
		return out
	end
	return value
end

local function Transport(api)
	if api.Request then
		return api.Request
	end
	return request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
end

local function DefaultSuccess(response)
	-- strict on purpose: a server that answers 200 with some error page must not unlock anything
	local code = response.StatusCode
	if type(code) ~= "number" or code < 200 or code >= 300 then
		return false, "Server answered " .. tostring(code)
	end
	local json = response.Json
	if type(json) == "table" then
		if json.valid == true or json.success == true then
			return true
		end
		local reason = json.message or json.error
		return false, if type(reason) == "string" then reason else nil
	end
	local body = Trim(response.Body):lower()
	return body == "true" or body == "valid" or body == "ok"
end

local function CheckApi(api, key)
	assert(type(api.Url) == "string", "[CrystallUI] KeySystem Api.Url must be a string")
	local vars = { key = key, hwid = Hwid() }
	local method = (api.Method or if api.Body ~= nil then "POST" else "GET"):upper()
	local url = Substitute(api.Url, vars, true)

	local response
	local send = Transport(api)
	if send then
		local body = api.Body
		if type(body) == "table" then
			body = HttpService:JSONEncode(Substitute(body, vars, false))
		elseif type(body) == "string" then
			body = Substitute(body, vars, false)
		end
		local headers = Substitute(api.Headers or {}, vars, false)
		if type(api.Body) == "table" and headers["Content-Type"] == nil then
			headers["Content-Type"] = "application/json"
		end
		local raw = send({ Url = url, Method = method, Headers = headers, Body = body })
		if type(raw) ~= "table" then
			return false, "No response"
		end
		response = {
			StatusCode = raw.StatusCode or raw.status_code or raw.Status,
			Body = raw.Body or raw.body or "",
			Headers = raw.Headers or raw.headers or {},
		}
	elseif method == "GET" then
		-- no request function in this executor, a plain GET still works through HttpGet
		response = { StatusCode = 200, Body = game:HttpGet(url), Headers = {} }
	else
		return false, "This executor has no request function"
	end
	local decoded, json = pcall(HttpService.JSONDecode, HttpService, response.Body)
	response.Json = if decoded then json else nil

	local ok, message = (api.Success or DefaultSuccess)(response)
	return ok == true, if type(message) == "string" then message else nil
end

-- runs `fn` and gives up after `timeout` seconds. Returns pcall-style results.
local function WithTimeout(timeout, fn)
	return Core.Await(function(resolve)
		-- the timer goes first: work that never yields must not be able to outrun it
		task.delay(timeout, function()
			resolve(false, "Timed out")
		end)
		task.spawn(function()
			local result = table.pack(pcall(fn))
			resolve(table.unpack(result, 1, result.n))
		end)
	end)
end

-- Returns ok, message. Sources are tried in order: fixed keys, Validate, Api.
local function Check(o, key)
	local lastMessage
	local keys = o.Keys or (o.Key and { o.Key }) or nil
	if keys then
		local needle = if o.CaseSensitive == false then key:lower() else key
		for _, candidate in keys do
			candidate = tostring(candidate)
			if (if o.CaseSensitive == false then candidate:lower() else candidate) == needle then
				return true
			end
		end
		lastMessage = "Invalid key"
	end
	if o.Validate then
		local ran, ok, message = WithTimeout(o.Timeout or 10, function()
			return o.Validate(key)
		end)
		if ran and ok == true then
			return true
		end
		lastMessage = if ran then (if type(message) == "string" then message else "Invalid key") else tostring(ok)
	end
	if o.Api then
		local ran, ok, message = WithTimeout(o.Api.Timeout or o.Timeout or 10, function()
			return CheckApi(o.Api, key)
		end)
		if ran and ok == true then
			return true
		end
		if ran then
			lastMessage = message or "Invalid key"
		else
			warn("[CrystallUI] Key check failed: " .. tostring(ok))
			lastMessage = if tostring(ok):find("Timed out", 1, true) then "The key server did not respond" else "Could not verify the key"
		end
	end
	return false, lastMessage or "Invalid key"
end

----------------------------------------------------------------------------------------------------
-- public
----------------------------------------------------------------------------------------------------

--[[
Library:KeySystem({
	Title, Subtitle, Icon, Note, Placeholder, ButtonText,
	Id            -- name for the saved key file, defaults to Title
	SaveKey       -- remember a valid key on disk and skip the prompt next time
	Key / Keys    -- fixed key(s), CaseSensitive = true by default
	Validate      -- function(key) -> boolean[, message]
	Api           -- { Url, Method, Headers, Body, Success(response) -> boolean[, message], Request, Timeout }
	Links         -- { { Name = "Get key", Url = "https://..." } }, copied to the clipboard on click
	MaxAttempts, Cooldown (default 1s), Timeout (default 10s), Closable (default true)
	OnSuccess(key), OnFail(reason), OnReady(handle)
	Async         -- return a handle immediately instead of waiting
})
Blocking mode returns `ok, key`. The thread that calls it has to be allowed to yield.
]]
function KeySystem:Run(o)
	o = o or {}
	assert(o.Key or o.Keys or o.Validate or o.Api, "[CrystallUI] KeySystem needs Key, Keys, Validate or Api")
	local id = o.Id or o.Title or "default"
	local handle = { Closed = false, Finished = false, Ok = false, Key = nil, Attempts = 0 }
	local modal, input, status, verify
	local busy, lastAttempt = false, -math.huge

	local function Status(text, kind)
		if status then
			status.Text = text or ""
			Theme:Bind(status, { TextColor3 = kind or "SubText" })
		end
	end

	local function Finish(ok, key, reason)
		if handle.Finished then
			return
		end
		handle.Finished, handle.Ok, handle.Key, handle.Reason = true, ok, key, reason
		if ok then
			Core.Fire(o.OnSuccess, key)
		else
			Core.Fire(o.OnFail, reason or "Closed")
		end
		if handle._resolve then
			handle._resolve(ok, key)
		end
		if modal then
			modal.OnClose = nil
			modal:Close()
		end
	end

	function handle:Close()
		self.Closed = true
		Finish(false, nil, "Closed")
	end

	local function Submit(text)
		if handle.Finished or busy then
			return
		end
		local key = Trim(text)
		if key == "" then
			Status("Enter your key first.", "Warning")
			return
		end
		local cooldown = o.Cooldown or 1
		if os.clock() - lastAttempt < cooldown then
			Status("Slow down a little.", "Warning")
			return
		end
		lastAttempt = os.clock()
		busy = true
		handle.Attempts += 1
		Status("Checking...", "SubText")
		if verify then
			verify.Text = "Checking..."
		end
		task.spawn(function()
			local ok, message = Check(o, key)
			busy = false
			if handle.Finished then
				return
			end
			if verify then
				verify.Text = o.ButtonText or "Verify"
			end
			if ok then
				Status("Key accepted", "Success")
				if o.SaveKey then
					WriteSaved(id, key)
				end
				task.wait(0.5)
				Finish(true, key)
				return
			end
			Status(message or "Invalid key", "Error")
			if modal then
				modal:Shake()
			end
			if o.MaxAttempts and handle.Attempts >= o.MaxAttempts then
				Status("Too many attempts", "Error")
				task.wait(1.2)
				Finish(false, nil, "Too many attempts")
			end
		end)
	end
	handle.Submit = function(_, text)
		if input then
			input.Text = tostring(text or "")
		end
		Submit(text)
	end

	local function BuildUi()
		modal = Core.CreateModal({
			Title = o.Title or "Key required",
			Subtitle = o.Subtitle or "Enter your key to continue.",
			Icon = o.Icon,
			Width = o.Width or 360,
			Closable = o.Closable,
			OnClose = function()
				handle:Close()
			end,
		})
		handle.Modal = modal
		local body = modal.Body

		input = New("TextBox", {
			Text = "",
			PlaceholderText = o.Placeholder or "Enter key...",
			ClearTextOnFocus = false,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 1,
			Theme = { BackgroundColor3 = "Elevated", TextColor3 = "Text", PlaceholderColor3 = "SubText" },
			Parent = body,
		})
		Core.Corner(input, 8)
		Core.Padding(input, 0, 12, 0, 12)
		local stroke = Core.Stroke(input)
		modal.Maid:Give(input.Focused:Connect(function()
			Animator:Tween(stroke, { Color = Theme:Get("Accent") }, "Fast")
		end))
		modal.Maid:Give(input.FocusLost:Connect(function(enterPressed)
			Theme:Refresh(stroke, true)
			if enterPressed then
				Submit(input.Text)
			end
		end))

		status = Core.Text({
			Text = o.Note or "",
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Theme = { TextColor3 = "SubText" },
			Parent = body,
		})

		verify = Core.Button(body, o.ButtonText or "Verify", "Primary", { LayoutOrder = 3 })
		modal.Maid:Give(verify.MouseButton1Click:Connect(function()
			Submit(input.Text)
		end))

		local links = o.Links or (o.GetKey and { { Name = "Get key", Url = o.GetKey } }) or {}
		for i, link in links do
			local button = Core.Button(body, link.Name or "Get key", "Default", { LayoutOrder = 3 + i })
			modal.Maid:Give(button.MouseButton1Click:Connect(function()
				if link.Callback then
					Core.Fire(link.Callback)
				end
				if link.Url then
					local copied = setclipboard and pcall(setclipboard, link.Url)
					Status(if copied then "Link copied to the clipboard" else link.Url, "Info")
				end
			end))
		end
		Core.Fire(o.OnReady, handle)
	end

	task.spawn(function()
		if o.SaveKey then
			local saved = ReadSaved(id)
			if saved then
				local ok = Check(o, saved)
				if ok then
					Finish(true, saved)
					return
				end
				KeySystem:ForgetKey(id)
			end
		end
		if not handle.Finished then
			BuildUi()
		end
	end)

	if o.Async then
		return handle
	end
	return Core.Await(function(resolve)
		handle._resolve = resolve
		if handle.Finished then
			resolve(handle.Ok, handle.Key)
		end
	end)
end

return KeySystem
