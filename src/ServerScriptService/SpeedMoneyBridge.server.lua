-- SpeedMoneyBridge: receives Speed/Money settings from the
-- "Steal And Break Eggs — Speed & Money" desktop app (speed-strength-app/)
-- through Roblox Open Cloud MessagingService.
--
-- Works only in an experience you own: the desktop app needs an Open Cloud API
-- key for this universe with the universe-messaging-service:publish permission.
-- Put this Script in ServerScriptService and publish the experience.
--
-- Message format (JSON string, sent by the app):
--   {"v":2,"type":"ping"}
--   {"v":2,"type":"apply","userId":123,"speed":24,"money":5000}
-- speed = null  -> WalkSpeed returns to the default (16)
-- money = null  -> money is left unchanged
-- Compatible with StatCommands.server.lua (same "Speed"/"Money" attributes
-- and leaderstats.Money).

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")

local TOPIC = "SBESpeedMoney" -- must match the Topic field in the app
local PROTOCOL_VERSION = 2

local DEFAULT_SPEED = 16
local SPEED_MIN, SPEED_MAX = 0, 200
local MONEY_MIN, MONEY_MAX = 0, 1000000000

local function applySpeed(player)
	local speed = player:GetAttribute("Speed")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and type(speed) == "number" then
		humanoid.WalkSpeed = speed
	end
end

local function getMoneyStat(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	local stat = leaderstats:FindFirstChild("Money")
	if not stat then
		stat = Instance.new("IntValue")
		stat.Name = "Money"
		stat.Parent = leaderstats
	end
	return stat
end

local function setMoney(player, value)
	player:SetAttribute("Money", value)
	getMoneyStat(player).Value = value
end

local function clampNumber(value, minimum, maximum)
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	return math.clamp(math.floor(value), minimum, maximum)
end

local function onMessage(message)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, message.Data)
	if not ok or type(data) ~= "table" or data.v ~= PROTOCOL_VERSION then
		warn("[SpeedMoneyBridge] ignored malformed or old-version message")
		return
	end
	if data.type == "ping" then
		print("[SpeedMoneyBridge] ping received")
		return
	end
	if data.type ~= "apply" or type(data.userId) ~= "number" then
		return
	end

	local player = Players:GetPlayerByUserId(data.userId)
	if not player then
		return -- the player is not in this server
	end

	player:SetAttribute("Speed", clampNumber(data.speed, SPEED_MIN, SPEED_MAX) or DEFAULT_SPEED)
	applySpeed(player)
	local money = clampNumber(data.money, MONEY_MIN, MONEY_MAX)
	if money then
		setMoney(player, money)
	end
	print(("[SpeedMoneyBridge] %s: Speed=%s Money=%s"):format(
		player.Name, tostring(player:GetAttribute("Speed")), tostring(getMoneyStat(player).Value)))
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		applySpeed(player)
	end)
end)

local ok, err = pcall(MessagingService.SubscribeAsync, MessagingService, TOPIC, onMessage)
if not ok then
	warn("[SpeedMoneyBridge] could not subscribe to " .. TOPIC .. ": " .. tostring(err))
end
