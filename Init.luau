local Config = ...
if type(Config) == "string" then
	Config = { RepoUrl = Config }
elseif type(Config) ~= "table" then
	Config = {}
end

local REPO_URL = Config.RepoUrl or Config.REPO_URL or "https://raw.githubusercontent.com/TerraKill765747646/CrystallUI/main/"
if REPO_URL:sub(-1) ~= "/" then
	REPO_URL ..= "/"
end

-- Config.Loader: function(path) -> source string, replaces the HTTP fetch entirely.
-- Config.LocalPath: folder in the executor workspace, modules are read with readfile (handy for development).
local Loader = Config.Loader
if Loader == nil and type(Config.LocalPath) == "string" then
	local base = Config.LocalPath
	if base:sub(-1) ~= "/" then
		base ..= "/"
	end
	Loader = function(path)
		return readfile(base .. path .. ".luau")
	end
end
if Loader ~= nil then
	assert(type(Loader) == "function", "[CrystallUI] Config.Loader must be a function")
end

local Cache, Loading = {}, {}

local function Import(path)
	path = path:gsub("%.luau$", "")
	local cached = Cache[path]
	if cached ~= nil then
		return cached
	end
	assert(not Loading[path], "[CrystallUI] Circular import: " .. path)
	Loading[path] = true
	local ok, source
	if Loader then
		ok, source = pcall(Loader, path)
	else
		ok, source = pcall(game.HttpGet, game, REPO_URL .. path .. ".luau")
	end
	if not ok or type(source) ~= "string" then
		Loading[path] = nil
		error("[CrystallUI] Failed to fetch '" .. path .. "': " .. tostring(source), 2)
	end
	local fn, err = loadstring(source, "=" .. path)
	if not fn then
		Loading[path] = nil
		error("[CrystallUI] Failed to compile '" .. path .. "': " .. tostring(err), 2)
	end
	local ran, result = pcall(fn, Import)
	Loading[path] = nil
	if not ran then
		error("[CrystallUI] Runtime error in '" .. path .. "': " .. tostring(result), 2)
	end
	Cache[path] = if result == nil then true else result
	return Cache[path]
end

local Theme = Import("src/ThemeEngine")
local Core = Import("src/Core")
local Notifications = Import("src/Notifications")
Import("src/Warnings")
local Controls = Import("src/Controls")
local KeySystem = Import("src/KeySystem")

local Library = Core.Library
Library.Import = Import
Library.RepoUrl = REPO_URL
Library.Core = Core
Library.Controls = Controls
Library.Notifications = Notifications
Library.KeySystemModule = KeySystem

function Library:KeySystem(options)
	return KeySystem:Run(options)
end

function Library:ForgetKey(id)
	KeySystem:ForgetKey(id)
end

function Library:Notify(options)
	return Notifications:Notify(options)
end

function Library:SetPalette(name, keepMotion)
	Theme:SetPalette(name, keepMotion)
end

function Library:SetMotion(name)
	Theme:SetMotion(name)
end

function Library:SetTheme(cfg)
	Theme:SetTheme(cfg)
end

function Library:RegisterPalette(name, palette)
	return Theme:RegisterPalette(name, palette)
end

function Library:RegisterMotion(name, motion)
	return Theme:RegisterMotion(name, motion)
end

if Config.Theme then
	Theme:SetTheme(Config.Theme)
end

return Library