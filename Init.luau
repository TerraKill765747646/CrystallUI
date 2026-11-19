local Config = ...
if type(Config) == "string" then
	Config = { RepoUrl = Config }
elseif type(Config) ~= "table" then
	Config = {}
end

local REPO_URL = Config.RepoUrl or Config.REPO_URL or "https://raw.githubusercontent.com/USER/CrystallUI/main/"
if REPO_URL:sub(-1) ~= "/" then
	REPO_URL ..= "/"
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
	local ok, source = pcall(game.HttpGet, game, REPO_URL .. path .. ".luau")
	if not ok or type(source) ~= "string" then
		Loading[path] = nil
		error("[CrystallUI] Failed to fetch '" .. path .. "': " .. tostring(source), 2)
	end
	local fn, err = loadstring(source, "=" .. path)
	if not fn then
		Loading[path] = nil
		error("[CrystallUI] Failed to compile '" .. path .. "': " .. tostring(err), 2)
	end
	local result = fn(Import)
	Loading[path] = nil
	Cache[path] = if result == nil then true else result
	return Cache[path]
end

local Theme = Import("src/ThemeEngine")
local Core = Import("src/Core")
local Notifications = Import("src/Notifications")
local Controls = Import("src/Controls")

local Library = Core.Library
Library.Import = Import
Library.RepoUrl = REPO_URL
Library.Core = Core
Library.Controls = Controls
Library.Notifications = Notifications

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