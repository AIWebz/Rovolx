-- StatCommands: chat commands to set your own Speed and Strength in YOUR game.
-- Put this Script in ServerScriptService.
--
-- Commands (type in chat):
--   /speed <number>      sets your WalkSpeed (default 16)
--   /strength <number>   sets your Strength stat (shown on the leaderboard)
--   /reset               restores defaults
--
-- Other scripts can read strength with: player:GetAttribute("Strength")

local Players = game:GetService("Players")

-- UserIds allowed to use commands. The game creator is always allowed.
-- Leave empty to allow only the creator; set ALLOW_EVERYONE to true for testing.
local ADMINS = {
	-- 12345678,
}
local ALLOW_EVERYONE = false

local DEFAULT_SPEED = 16
local DEFAULT_STRENGTH = 1
local MAX_VALUE = 1e6

local function isAdmin(player)
	if ALLOW_EVERYONE or player.UserId == game.CreatorId then
		return true
	end
	for _, id in ipairs(ADMINS) do
		if id == player.UserId then
			return true
		end
	end
	return false
end

local function applySpeed(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = player:GetAttribute("Speed")
	end
end

local function setStrength(player, value)
	player:SetAttribute("Strength", value)
	player.leaderstats.Strength.Value = value
end

Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local strength = Instance.new("NumberValue")
	strength.Name = "Strength"
	strength.Parent = leaderstats

	player:SetAttribute("Speed", DEFAULT_SPEED)
	setStrength(player, DEFAULT_STRENGTH)

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		applySpeed(player)
	end)

	player.Chatted:Connect(function(message)
		if not isAdmin(player) then
			return
		end

		local command, arg = message:lower():match("^/(%a+)%s*(%S*)")
		local value = tonumber(arg)
		if value then
			value = math.clamp(value, 0, MAX_VALUE)
		end

		if command == "speed" and value then
			player:SetAttribute("Speed", value)
			applySpeed(player)
		elseif command == "strength" and value then
			setStrength(player, value)
		elseif command == "reset" then
			player:SetAttribute("Speed", DEFAULT_SPEED)
			applySpeed(player)
			setStrength(player, DEFAULT_STRENGTH)
		end
	end)
end)
