-- SpeedStrengthBridge: receives Speed/Strength settings from the
-- "Steal And Break Eggs — Speed & Strength" desktop app (speed-strength-app/)
-- through Roblox Open Cloud MessagingService.
--
-- Works only in an experience you own: the desktop app needs an Open Cloud API
-- key for this universe with the universe-messaging-service:publish permission.
-- Put this Script in ServerScriptService and publish the experience.
--
-- Message format (JSON string, sent by the app):
--   {"v":1,"type":"ping"}
--   {"v":1,"type":"apply","userId":123,"speed":24,"strength":5}
-- A null speed/strength means the modifier is disabled: restore the default.
-- Compatible with StatCommands.server.lua (same "Speed"/"Strength" attributes).

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")

local TOPIC = "SBESpeedStrength" -- must match the Topic field in the app

local DEFAULT_SPEED = 16
local DEFAULT_STRENGTH = 1
local SPEED_MIN, SPEED_MAX = 0, 200
local STRENGTH_MIN, STRENGTH_MAX = 1, 1000

local function applySpeed(player)
	local speed = player:GetAttribute("Speed")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and type(speed) == "number" then
		humanoid.WalkSpeed = speed
	end
end

local function setStrength(player, value)
	player:SetAttribute("Strength", value)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild("Strength")
	if stat and stat:IsA("ValueBase") then
		stat.Value = value
	end
end

local function readValue(value, minimum, maximum, default)
	if type(value) ~= "number" or value ~= value then
		return default
	end
	return math.clamp(math.floor(value), minimum, maximum)
end

local function onMessage(message)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, message.Data)
	if not ok or type(data) ~= "table" or data.v ~= 1 then
		warn("[SpeedStrengthBridge] ignored malformed message")
		return
	end
	if data.type == "ping" then
		print("[SpeedStrengthBridge] ping received")
		return
	end
	if data.type ~= "apply" or type(data.userId) ~= "number" then
		return
	end

	local player = Players:GetPlayerByUserId(data.userId)
	if not player then
		return -- the player is not in this server
	end

	player:SetAttribute("Speed", readValue(data.speed, SPEED_MIN, SPEED_MAX, DEFAULT_SPEED))
	applySpeed(player)
	setStrength(player, readValue(data.strength, STRENGTH_MIN, STRENGTH_MAX, DEFAULT_STRENGTH))
	print(("[SpeedStrengthBridge] %s: Speed=%s Strength=%s"):format(
		player.Name, tostring(player:GetAttribute("Speed")), tostring(player:GetAttribute("Strength"))))
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		applySpeed(player)
	end)
end)

local ok, err = pcall(MessagingService.SubscribeAsync, MessagingService, TOPIC, onMessage)
if not ok then
	warn("[SpeedStrengthBridge] could not subscribe to " .. TOPIC .. ": " .. tostring(err))
end
