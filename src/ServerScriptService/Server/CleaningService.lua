-- CleaningService: runs the wash stations and validates the scrubbing
-- minigame that the client plays.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local ScrapModels = require(ReplicatedStorage.Shared.ScrapModels)
local DataService = require(script.Parent.DataService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local CleaningService = {}

type Session = {
	Id: string,
	Station: number,
	ScrapId: string,
	Count: number,
	Started: number,
	MinTime: number,
	ParTime: number,
	Spots: { any },
}

local sessions: { [Player]: Session } = {}
local stationOwner: { [number]: Player? } = {}
local remotes: Folder
local rng = Random.new()

local GREEN = Color3.fromRGB(90, 255, 120)
local RED = Color3.fromRGB(255, 80, 80)

local function notify(player: Player, text: string, kind: string?)
	remotes.Notify:FireClient(player, text, kind or "info")
end

local function station(index: number): Model?
	return WorldBuilder.Stations[index]
end

local function setStationBusy(index: number, busy: boolean)
	local st = station(index)
	if not st then
		return
	end
	local light = st:FindFirstChild("StatusLight") :: BasePart?
	if light then
		light.Color = busy and RED or GREEN
	end
	local spot = st:FindFirstChild("ItemSpot")
	local bubbles = spot and spot:FindFirstChild("Bubbles") :: ParticleEmitter?
	if bubbles then
		bubbles.Enabled = busy
	end
	local nozzle = st:FindFirstChild("Nozzle")
	local spray = nozzle and nozzle:FindFirstChild("Spray") :: ParticleEmitter?
	if spray then
		spray.Enabled = busy
	end
	local prompt = st:FindFirstChild("CleanPrompt", true) :: ProximityPrompt?
	if prompt then
		prompt.Enabled = not busy
	end
end

local function setDisplay(index: number, scrapId: string?, clean: boolean)
	local st = station(index)
	if not st then
		return
	end
	local old = st:FindFirstChild("Display")
	if old then
		old:Destroy()
	end
	if not scrapId then
		return
	end
	local spot = st:FindFirstChild("ItemSpot") :: BasePart
	local model = ScrapModels.create(scrapId, clean)
	model.Name = "Display"
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	model:PivotTo(spot.CFrame)
	model.Parent = st
end

local function nearStation(player: Player, index: number): boolean
	local st = station(index)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not st or not root then
		return false
	end
	local spot = st:FindFirstChild("ItemSpot") :: BasePart
	return (spot.Position - root.Position).Magnitude < 20
end

local function endSession(player: Player, keepDisplayClean: boolean)
	local s = sessions[player]
	if not s then
		return
	end
	sessions[player] = nil
	local index = s.Station
	if keepDisplayClean then
		setDisplay(index, s.ScrapId, true)
		local st = station(index)
		local spot = st and st:FindFirstChild("ItemSpot")
		local sparkle = spot and spot:FindFirstChild("Sparkle") :: ParticleEmitter?
		if sparkle then
			sparkle:Emit(60)
		end
		local bubbles = spot and spot:FindFirstChild("Bubbles") :: ParticleEmitter?
		if bubbles then
			bubbles.Enabled = false
		end
		task.delay(2.5, function()
			if stationOwner[index] == player and not sessions[player] then
				stationOwner[index] = nil
				setDisplay(index, nil, false)
				setStationBusy(index, false)
			end
		end)
	else
		stationOwner[index] = nil
		setDisplay(index, nil, false)
		setStationBusy(index, false)
	end
end

function CleaningService.cancel(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	-- give the dirty items back
	DataService.addItem(player, Config.ItemKey(s.ScrapId, 0), s.Count)
	DataService.markDirty(player)
	endSession(player, false)
end

local function generateSpots(rarity: Config.Rarity, count: number): { any }
	local spots = {}
	local n = math.min(26, rarity.DirtSpots + math.floor((count - 1) * 1.5))
	local types = math.clamp(rarity.DirtLayers, 1, #Config.Cleaning.DirtTypes)
	for i = 1, n do
		local typeIndex = ((i - 1) % types) + 1
		if types > 1 and rng:NextNumber() < 0.35 then
			typeIndex = rng:NextInteger(1, types)
		end
		local dirt = Config.Cleaning.DirtTypes[typeIndex]
		local size = rng:NextNumber(0.13, 0.22)
		table.insert(spots, {
			Type = typeIndex,
			X = rng:NextNumber(0.14, 0.86),
			Y = rng:NextNumber(0.16, 0.84),
			Size = size,
			Rot = rng:NextNumber(0, 360),
			HP = dirt.HP,
		})
	end
	return spots
end

local function start(player: Player, index: any, scrapId: any)
	if typeof(index) ~= "number" or typeof(scrapId) ~= "string" then
		return false, "Invalid request"
	end
	index = math.floor(index)
	local data = DataService.get(player)
	local scrap = Config.Scraps[scrapId]
	if not data or not scrap or not station(index) then
		return false, "Invalid request"
	end
	if sessions[player] then
		return false, "You're already cleaning!"
	end
	if stationOwner[index] and stationOwner[index] ~= player then
		return false, "Station in use"
	end
	if not nearStation(player, index) then
		return false, "Walk closer to the station"
	end
	local key = Config.ItemKey(scrapId, 0)
	local have = data.Inventory[key] or 0
	if have <= 0 then
		return false, "You don't have that scrap"
	end
	local count = math.min(have, Config.WashBatch(data.Upgrades.WashTub or 0))
	DataService.addItem(player, key, -count)
	DataService.markDirty(player)

	local rarity = Config.Rarities[scrap.Rarity]
	local spots = generateSpots(rarity, count)
	local totalHP = 0
	for _, s in ipairs(spots) do
		totalHP += s.HP
	end
	local rate = Config.Cleaning.BaseScrubRate * Config.ScrubMultiplier(data.Upgrades.ScrubPower or 0)
	local expected = totalHP / rate
	local session: Session = {
		Id = HttpService:GenerateGUID(false),
		Station = index,
		ScrapId = scrapId,
		Count = count,
		Started = os.clock(),
		MinTime = math.max(1, #spots * Config.Cleaning.MinSecondsPerSpot, expected * 0.35),
		ParTime = expected * 1.6 + rarity.ParTime * 0.35,
		Spots = spots,
	}
	sessions[player] = session
	stationOwner[index] = player
	setStationBusy(index, true)
	setDisplay(index, scrapId, false)
	return true,
		{
			Id = session.Id,
			ScrapId = scrapId,
			Count = count,
			Spots = spots,
			ScrubRate = rate,
			ParTime = session.ParTime,
		}
end

local function finish(player: Player, sessionId: any)
	local s = sessions[player]
	if not s or s.Id ~= sessionId then
		return false, "No active wash"
	end
	local elapsed = os.clock() - s.Started
	if elapsed < s.MinTime then
		-- too quick to be real scrubbing: make the player wait it out
		task.wait(s.MinTime - elapsed)
		if sessions[player] ~= s then
			return false, "Wash cancelled"
		end
	end
	local data = DataService.get(player)
	if not data then
		return false, "No data"
	end
	local stars = 1
	if elapsed <= s.ParTime then
		stars = 3
	elseif elapsed <= s.ParTime * 1.8 then
		stars = 2
	end
	DataService.addItem(player, Config.ItemKey(s.ScrapId, stars), s.Count)
	data.ItemsCleaned += s.Count
	DataService.markDirty(player)
	local value = Config.SellPrice(s.ScrapId, stars, data.Upgrades.SellBonus or 0, data.Machines.PolishLab or 0) * s.Count
	endSession(player, true)
	return true, {
		Stars = stars,
		Count = s.Count,
		ScrapId = s.ScrapId,
		Value = value,
		Time = elapsed,
	}
end

function CleaningService.handleAction(player: Player, action: string, a: any, b: any)
	if action == "StartCleaning" then
		return start(player, a, b)
	elseif action == "FinishCleaning" then
		return finish(player, a)
	elseif action == "CancelCleaning" then
		CleaningService.cancel(player)
		return true
	end
	return nil
end

function CleaningService.init(remoteFolder: Folder)
	remotes = remoteFolder
	for index, st in ipairs(WorldBuilder.Stations) do
		setStationBusy(index, false)
		local prompt = st:FindFirstChild("CleanPrompt", true) :: ProximityPrompt
		prompt.Triggered:Connect(function(player)
			local data = DataService.get(player)
			if not data then
				return
			end
			if sessions[player] then
				return
			end
			if stationOwner[index] and stationOwner[index] ~= player then
				notify(player, "That station is busy — try another!", "error")
				return
			end
			local hasDirty = false
			for key, n in pairs(data.Inventory) do
				local _, stars = Config.ParseKey(key)
				if stars == 0 and n > 0 then
					hasDirty = true
					break
				end
			end
			if not hasDirty then
				notify(player, "No dirty scrap! Go collect some in the yard.", "error")
				return
			end
			remotes.Open:FireClient(player, "CleanSelect", { Station = index })
		end)
	end
	-- free stations if a session is abandoned
	task.spawn(function()
		while true do
			task.wait(5)
			for player, s in pairs(sessions) do
				if not player.Parent or os.clock() - s.Started > 240 or not nearStation(player, s.Station) then
					if player.Parent then
						notify(player, "Wash cancelled — you walked away.", "error")
						remotes.Open:FireClient(player, "CloseCleaning")
					end
					CleaningService.cancel(player)
				end
			end
		end
	end)
end

return CleaningService
