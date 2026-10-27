-- StatCommands: chat commands to set your own Speed and Money in YOUR game.
-- Put this Script in ServerScriptService.
--
-- Commands (type in chat):
--   /speed <number>      sets your WalkSpeed (default 16)
--   /money <number>      sets your Money (shown on the leaderboard)
--   /reset               restores defaults
--
-- Other scripts can read money with: player:GetAttribute("Money")

local Players = game:GetService("Players")

-- UserIds allowed to use commands. The game creator is always allowed.
-- Leave empty to allow only the creator; set ALLOW_EVERYONE to true for testing.
local ADMINS = {
	-- 12345678,
}
local ALLOW_EVERYONE = false

local DEFAULT_SPEED = 16
local DEFAULT_MONEY = 0
local MAX_SPEED = 200
local MAX_MONEY = 1000000000

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

local function setMoney(player, value)
	player:SetAttribute("Money", value)
	player.leaderstats.Money.Value = value
end

Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Parent = leaderstats

	player:SetAttribute("Speed", DEFAULT_SPEED)
	setMoney(player, DEFAULT_MONEY)

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

		if command == "speed" and value then
			player:SetAttribute("Speed", math.clamp(value, 0, MAX_SPEED))
			applySpeed(player)
		elseif command == "money" and value then
			setMoney(player, math.clamp(math.floor(value), 0, MAX_MONEY))
		elseif command == "reset" then
			player:SetAttribute("Speed", DEFAULT_SPEED)
			applySpeed(player)
			setMoney(player, DEFAULT_MONEY)
		end
	end)
end)
