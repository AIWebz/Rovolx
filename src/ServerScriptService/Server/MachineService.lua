-- MachineService: runs every owned machine for every player once a second.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local ScrapService = require(script.Parent.ScrapService)
local EconomyService = require(script.Parent.EconomyService)

local MachineService = {}

local timers: { [Player]: { [string]: number } } = {}
local remotes: Folder

local function fx(player: Player, payload)
	remotes.FX:FireClient(player, payload)
end

local function tick(player: Player, data, t: { [string]: number })
	local stats = Config.MachineStats

	-- Auto Washer: cleans dirty scrap to 1 star
	local washer = data.Machines.AutoWasher or 0
	if washer > 0 then
		t.AutoWasher = (t.AutoWasher or 0) + 1
		if t.AutoWasher >= stats.AutoWasherInterval[washer] then
			t.AutoWasher = 0
			local budget = washer
			local cleanedId, cleaned = nil, 0
			local dirtyKeys = {}
			for key, n in pairs(data.Inventory) do
				local id, stars = Config.ParseKey(key)
				if id and stars == 0 and n > 0 then
					table.insert(dirtyKeys, key)
				end
			end
			for _, key in ipairs(dirtyKeys) do
				local id = Config.ParseKey(key)
				local n = data.Inventory[key] or 0
				if id and n > 0 then
					local take = math.min(n, budget)
					DataService.addItem(player, key, -take)
					DataService.addItem(player, Config.ItemKey(id, 1), take)
					data.ItemsCleaned += take
					budget -= take
					cleaned += take
					cleanedId = id
					if budget <= 0 then
						break
					end
				end
			end
			if cleaned > 0 then
				DataService.markDirty(player)
				fx(player, {
					Kind = "Machine",
					Machine = "AutoWasher",
					Text = string.format("+%d washed %s", cleaned, Config.Scraps[cleanedId :: string].Name),
				})
			end
		end
	end

	-- Magnet Crane: grabs scrap for you
	local crane = data.Machines.MagnetCrane or 0
	if crane > 0 then
		t.MagnetCrane = (t.MagnetCrane or 0) + 1
		if t.MagnetCrane >= stats.MagnetCraneInterval[crane] then
			t.MagnetCrane = 0
			ScrapService.grantRandom(player)
		end
	end

	-- Conveyor Seller: auto-sells low rarity clean scrap
	local seller = data.Machines.AutoSeller or 0
	if seller > 0 then
		t.AutoSeller = (t.AutoSeller or 0) + 1
		if t.AutoSeller >= stats.AutoSellerInterval[seller] then
			t.AutoSeller = 0
			local maxOrder = math.clamp(seller + 1, 1, 6)
			EconomyService.sellWhere(player, function(id)
				return Config.Rarities[Config.Scraps[id].Rarity].Order <= maxOrder
			end, "AutoSeller")
		end
	end
end

function MachineService.init(remoteFolder: Folder)
	remotes = remoteFolder
	Players.PlayerRemoving:Connect(function(player)
		timers[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.get(player)
				if data then
					local t = timers[player]
					if not t then
						t = {}
						timers[player] = t
					end
					local ok, err = pcall(tick, player, data, t)
					if not ok then
						warn("[MachineService]", err)
					end
				end
			end
		end
	end)
end

return MachineService
