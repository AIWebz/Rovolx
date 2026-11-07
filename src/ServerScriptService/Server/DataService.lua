-- DataService: loads, holds, saves and replicates each player's progress.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable (enable Studio API access to save):", result)
	end
end

local profiles: { [Player]: any } = {}
local loaded: { [Player]: boolean } = {}
local canSave: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}

local stateRemote: RemoteEvent

DataService.Changed = Instance.new("BindableEvent")

local function defaultData()
	local upgrades = {}
	for id in pairs(Config.Upgrades) do
		upgrades[id] = 0
	end
	local machines = {}
	for id in pairs(Config.Machines) do
		machines[id] = 0
	end
	return {
		Version = 1,
		Cash = Config.StartingCash,
		TotalEarned = 0,
		ScrapsCollected = 0,
		ItemsCleaned = 0,
		Tools = { RustyGrabber = true },
		EquippedTool = "RustyGrabber",
		Upgrades = upgrades,
		Machines = machines,
		Zones = { Junkyard = true },
		Inventory = {} :: { [string]: number },
		Discovered = {} :: { [string]: boolean },
		Settings = { Music = true, Sfx = true },
	}
end

-- Fill in any fields added after a player's data was first saved.
local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			if type(v) == "table" then
				data[k] = table.clone(v)
			else
				data[k] = v
			end
		elseif type(v) == "table" and type(data[k]) == "table" and k ~= "Inventory" and k ~= "Discovered" then
			reconcile(data[k], v)
		end
	end
	return data
end

function DataService.init(remotes: Folder)
	stateRemote = remotes:WaitForChild("State") :: RemoteEvent
end

function DataService.get(player: Player)
	return profiles[player]
end

function DataService.isLoaded(player: Player): boolean
	return loaded[player] == true
end

----------------------------------------------------------------------
-- Inventory helpers
----------------------------------------------------------------------
function DataService.itemCount(player: Player): number
	local data = profiles[player]
	if not data then
		return 0
	end
	local total = 0
	for _, n in pairs(data.Inventory) do
		total += n
	end
	return total
end

function DataService.capacity(player: Player): number
	local data = profiles[player]
	if not data then
		return 0
	end
	return Config.BackpackCapacity(data.Upgrades.Backpack or 0)
end

function DataService.freeSpace(player: Player): number
	return math.max(0, DataService.capacity(player) - DataService.itemCount(player))
end

function DataService.addItem(player: Player, key: string, amount: number)
	local data = profiles[player]
	if not data or amount == 0 then
		return
	end
	local n = (data.Inventory[key] or 0) + amount
	if n <= 0 then
		data.Inventory[key] = nil
	else
		data.Inventory[key] = n
	end
	local id = Config.ParseKey(key)
	if id and amount > 0 then
		data.Discovered[id] = true
	end
end

function DataService.addCash(player: Player, amount: number)
	local data = profiles[player]
	if not data then
		return
	end
	data.Cash = math.max(0, math.floor(data.Cash + amount))
	if amount > 0 then
		data.TotalEarned += amount
	end
	local ls = player:FindFirstChild("leaderstats")
	local cash = ls and ls:FindFirstChild("Cash")
	if cash then
		cash.Value = data.Cash
	end
end

function DataService.trySpend(player: Player, amount: number): boolean
	local data = profiles[player]
	if not data or data.Cash < amount then
		return false
	end
	DataService.addCash(player, -amount)
	return true
end

----------------------------------------------------------------------
-- Replication: send the full (small) state to the owning client.
----------------------------------------------------------------------
function DataService.markDirty(player: Player)
	dirty[player] = true
end

function DataService.push(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	dirty[player] = false
	stateRemote:FireClient(player, data)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local cash = ls:FindFirstChild("Cash")
		if cash then
			cash.Value = data.Cash
		end
		local scraps = ls:FindFirstChild("Scraps")
		if scraps then
			scraps.Value = data.ScrapsCollected
		end
	end
	DataService.Changed:Fire(player)
end

RunService.Heartbeat:Connect(function()
	for player, isDirty in pairs(dirty) do
		if isDirty then
			DataService.push(player)
		end
	end
end)

----------------------------------------------------------------------
-- Loading / saving
----------------------------------------------------------------------
local function key(player: Player): string
	return "Player_" .. player.UserId
end

function DataService.save(player: Player)
	local data = profiles[player]
	if not data or not store or not canSave[player] then
		return
	end
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function()
			return data
		end)
	end)
	if not ok then
		warn("[DataService] Save failed for", player.Name, err)
	end
end

local function setupLeaderstats(player: Player)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = player
	end
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Parent = ls
	local scraps = Instance.new("NumberValue")
	scraps.Name = "Scraps"
	scraps.Parent = ls
end

function DataService.load(player: Player)
	local data = nil
	local success = true
	if store then
		for attempt = 1, (RunService:IsStudio() and 1 or 3) do
			local ok, result = pcall(function()
				return (store :: DataStore):GetAsync(key(player))
			end)
			if ok then
				data = result
				success = true
				break
			else
				success = false
				warn("[DataService] Load attempt", attempt, "failed:", result)
				if attempt < 3 and not RunService:IsStudio() then
					task.wait(1.5)
				end
			end
		end
	end
	if type(data) ~= "table" then
		data = defaultData()
	else
		data = reconcile(data, defaultData())
	end
	if not player.Parent then
		return nil
	end
	profiles[player] = data
	-- Never overwrite real data if loading failed (DataStore outage).
	canSave[player] = store ~= nil and success
	setupLeaderstats(player)
	loaded[player] = true
	DataService.push(player)
	return data
end

function DataService.release(player: Player)
	DataService.save(player)
	profiles[player] = nil
	loaded[player] = nil
	canSave[player] = nil
	dirty[player] = nil
end

task.spawn(function()
	while true do
		task.wait(Config.AutoSaveInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(DataService.save, player)
		end
	end
end)

game:BindToClose(function()
	if RunService:IsStudio() and not store then
		return
	end
	local threads = 0
	for _, player in ipairs(Players:GetPlayers()) do
		threads += 1
		task.spawn(function()
			DataService.save(player)
			threads -= 1
		end)
	end
	local start = os.clock()
	while threads > 0 and os.clock() - start < 25 do
		task.wait(0.1)
	end
end)

return DataService
