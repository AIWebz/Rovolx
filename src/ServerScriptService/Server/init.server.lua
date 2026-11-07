-- Scrapyard Simulator — server entry point.
-- Builds the shared scrapyard, creates remotes and wires up every service.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Remotes ------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in ipairs({ "State", "Notify", "Open", "Hit", "FX" }) do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
end
local action = Instance.new("RemoteFunction")
action.Name = "Action"
action.Parent = remotes
remotes.Parent = ReplicatedStorage

-- World --------------------------------------------------------------
local WorldBuilder = require(script.WorldBuilder)
WorldBuilder.build()

-- Services -----------------------------------------------------------
local DataService = require(script.DataService)
local ToolService = require(script.ToolService)
local ScrapService = require(script.ScrapService)
local CleaningService = require(script.CleaningService)
local EconomyService = require(script.EconomyService)
local MachineService = require(script.MachineService)

DataService.init(remotes)
ScrapService.init(remotes)
CleaningService.init(remotes)
EconomyService.init(remotes)
MachineService.init(remotes)

-- Actions (client -> server requests) --------------------------------
local lastAction: { [Player]: number } = {}

action.OnServerInvoke = function(player: Player, name: any, a: any, b: any)
	if typeof(name) ~= "string" or not DataService.isLoaded(player) then
		return false, "Loading..."
	end
	-- light rate limit
	local now = os.clock()
	if now - (lastAction[player] or 0) < 0.08 then
		return false, "Slow down!"
	end
	lastAction[player] = now

	local ok, result, extra = pcall(function()
		local r1, r2 = CleaningService.handleAction(player, name, a, b)
		if r1 ~= nil then
			return r1, r2
		end
		return EconomyService.handleAction(player, name, a)
	end)
	if not ok then
		warn("[Action]", name, result)
		return false, "Something went wrong"
	end
	if result == nil then
		return false, "Unknown action"
	end
	return result, extra
end

-- Players -------------------------------------------------------------
local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(char)
		while player.Parent and not DataService.isLoaded(player) do
			task.wait(0.1)
		end
		ToolService.onCharacter(player, char)
	end)
	-- restore the upgrade speed after an admin /reset
	player:GetAttributeChangedSignal("SpeedOverride"):Connect(function()
		ToolService.applyStats(player)
	end)
	DataService.load(player)
	if player.Character then
		task.spawn(ToolService.onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	CleaningService.cancel(player)
	EconomyService.forget(player)
	lastAction[player] = nil
	DataService.release(player)
end)

-- Refresh walk speed whenever data changes (upgrades)
DataService.Changed.Event:Connect(function(player: Player)
	ToolService.applyStats(player)
end)
