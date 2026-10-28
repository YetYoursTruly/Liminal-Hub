--[[
	Liminal Hub | Loader.lua
	Usage:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/YetYoursTruly/Liminal-Hub/main/Loader.lua"))()
]]

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local RAW = "https://raw.githubusercontent.com/YetYoursTruly/Liminal-Hub/main/"

-- Make sure the executor can actually run the hub
for _, fnName in ipairs({ "getcustomasset", "writefile", "readfile", "isfile", "isfolder", "makefolder", "getgenv" }) do
	if not getgenv or not getgenv()[fnName] then
		warn("[Liminal Hub] Your executor is missing: " .. fnName)
		return
	end
end

local ok, src = pcall(game.HttpGet, game, RAW .. "Main.lua")
if not ok or type(src) ~= "string" or #src < 100 then
	warn("[Liminal Hub] Failed to download Main.lua: " .. tostring(src))
	return
end

local fn, err = loadstring(src, "=LiminalHub")
if not fn then
	warn("[Liminal Hub] Failed to compile Main.lua: " .. tostring(err))
	return
end

local runOk, runErr = pcall(fn)
if not runOk then
	warn("[Liminal Hub] Runtime error: " .. tostring(runErr))
end