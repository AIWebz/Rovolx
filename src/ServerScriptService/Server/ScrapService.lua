-- ScrapService: spawns collectable scrap across the zones and handles tool hits.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ScrapModels = require(ReplicatedStorage.Shared.ScrapModels)
local DataService = require(script.Parent.DataService)

local ScrapService = {}

type ScrapState = {
	Id: number,
	Model: Model,
	ScrapId: string,
	Rarity: string,
	Zone: string,
	HP: number,
	MaxHP: number,
	Position: Vector3,
}

local scraps: { [number]: ScrapState } = {}
local zoneCounts: { [string]: number } = {}
local nextId = 0
local rng = Random.new()
local folder: Folder
local remotes: Folder
local lastHit: { [Player]: number } = {}
local lastFullWarn: { [Player]: number } = {}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function notify(player: Player, text: string, kind: string?)
	remotes.Notify:FireClient(player, text, kind or "info")
end

local function pickRarity(weights: { [string]: number }, luckBoost: number?): string
	local total = 0
	for rarity, w in pairs(weights) do
		local boost = 1 + (luckBoost or 0) * (Config.Rarities[rarity].Order - 1) * 0.15
		total += w * boost
	end
	local roll = rng:NextNumber(0, total)
	local acc = 0
	for _, rarity in ipairs(Config.RarityOrder) do
		local w = weights[rarity]
		if w then
			local boost = 1 + (luckBoost or 0) * (Config.Rarities[rarity].Order - 1) * 0.15
			acc += w * boost
			if roll <= acc then
				return rarity
			end
		end
	end
	return "Common"
end

local function pickScrap(rarity: string): string
	local list = Config.ScrapsByRarity[rarity]
	return list[rng:NextInteger(1, #list)]
end

local function addRarityFX(model: Model, rarity: string)
	local def = Config.Rarities[rarity]
	local hb = model.PrimaryPart :: BasePart
	if not def.Glow then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = def.Color
	light.Range = 6 + def.Order * 2
	light.Brightness = 1.2 + def.Order * 0.3
	light.Shadows = false
	light.Parent = hb
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "RarityFX"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	if rarity == "Mythic" then
		sparkles.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 120)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 180, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
		})
	else
		sparkles.Color = ColorSequence.new(def.Color)
	end
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Lifetime = NumberRange.new(0.8, 1.5)
	sparkles.Rate = 3 + def.Order * 2
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.LightEmission = 1
	sparkles.Parent = hb
	if def.Order >= 5 then
		-- tall beacon so legendary / mythic scrap is visible from afar
		local beam = Instance.new("Part")
		beam.Name = "Beacon"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Material = Enum.Material.Neon
		beam.Color = def.Color
		beam.Transparency = 0.55
		beam.Shape = Enum.PartType.Cylinder
		beam.Size = Vector3.new(60, 1.2, 1.2)
		beam.CFrame = CFrame.new(hb.Position + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90))
		beam.Parent = model
	end
end

local function findSpot(zone: Config.ZoneDef): Vector3?
	for _ = 1, 14 do
		local x = rng:NextNumber(-zone.HalfWidth + 8, zone.HalfWidth - 8)
		local z = rng:NextNumber(zone.ZMin + 6, zone.ZMax - 6)
		local origin = Vector3.new(x, 120, z)
		rayParams.FilterDescendantsInstances = { folder }
		local result = workspace:Raycast(origin, Vector3.new(0, -200, 0), rayParams)
		if result and result.Instance == workspace.Terrain and result.Normal.Y > 0.8 then
			local pos = result.Position
			local clear = true
			for _, s in pairs(scraps) do
				if (s.Position - pos).Magnitude < 7 then
					clear = false
					break
				end
			end
			if clear and result.Material ~= Enum.Material.Water then
				return pos
			end
		end
	end
	return nil
end

function ScrapService.spawn(zoneId: string): boolean
	local zone = Config.Zones[zoneId]
	local pos = findSpot(zone)
	if not pos then
		return false
	end
	local rarity = pickRarity(zone.Weights)
	local scrapId = pickScrap(rarity)
	local model = ScrapModels.create(scrapId, false)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = d.Name == "Hitbox"
		end
	end
	local hb = model.PrimaryPart :: BasePart
	local height = hb.Size.Y
	model:PivotTo(CFrame.new(pos + Vector3.new(0, height / 2 - 0.25, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	nextId += 1
	local hp = Config.Rarities[rarity].HP
	model.Name = "Scrap_" .. nextId
	model:SetAttribute("Id", nextId)
	model:SetAttribute("ScrapId", scrapId)
	model:SetAttribute("Rarity", rarity)
	model:SetAttribute("Zone", zoneId)
	model:SetAttribute("HP", hp)
	model:SetAttribute("MaxHP", hp)
	addRarityFX(model, rarity)
	model.Parent = folder
	scraps[nextId] = {
		Id = nextId,
		Model = model,
		ScrapId = scrapId,
		Rarity = rarity,
		Zone = zoneId,
		HP = hp,
		MaxHP = hp,
		Position = pos,
	}
	zoneCounts[zoneId] = (zoneCounts[zoneId] or 0) + 1
	return true
end

local function remove(state: ScrapState)
	scraps[state.Id] = nil
	zoneCounts[state.Zone] = math.max(0, (zoneCounts[state.Zone] or 1) - 1)
	state.Model:Destroy()
end

local function playerPower(data): number
	local tool = Config.Tools[data.EquippedTool]
	if not tool then
		return 0
	end
	return tool.Power * Config.ToolPowerMultiplier(data.Upgrades.ToolStrength or 0)
end

-- Gives a collected scrap to the player (with the lucky double roll).
local function award(player: Player, scrapId: string, rarity: string, position: Vector3?, source: string)
	local data = DataService.get(player)
	if not data then
		return
	end
	local free = DataService.freeSpace(player)
	if free <= 0 then
		return
	end
	local amount = 1
	local lucky = false
	local chance = Config.LuckChance(data.Upgrades.Luck or 0, data.Machines.RarityRadar or 0)
	if free >= 2 and rng:NextNumber() < chance then
		amount = 2
		lucky = true
	end
	local firstTime = not data.Discovered[scrapId]
	DataService.addItem(player, Config.ItemKey(scrapId, 0), amount)
	data.ScrapsCollected += amount
	DataService.markDirty(player)
	remotes.FX:FireClient(player, {
		Kind = "Collect",
		ScrapId = scrapId,
		Rarity = rarity,
		Amount = amount,
		Lucky = lucky,
		Position = position,
		New = firstTime,
		Source = source,
	})
	if Config.Rarities[rarity].Order >= 5 then
		for _, other in ipairs(Players:GetPlayers()) do
			notify(other, string.format("%s found a %s %s!", player.DisplayName, rarity, Config.Scraps[scrapId].Name), rarity)
		end
	end
end

local function onHit(player: Player, ids: any)
	if type(ids) ~= "table" then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local tool = char and char:FindFirstChildOfClass("Tool")
	if not root or not tool or tool:GetAttribute("ToolId") ~= data.EquippedTool then
		return
	end
	local toolDef = Config.Tools[data.EquippedTool]
	local now = os.clock()
	if now - (lastHit[player] or 0) < toolDef.Cooldown * 0.75 then
		return
	end
	lastHit[player] = now

	if DataService.freeSpace(player) <= 0 then
		if now - (lastFullWarn[player] or 0) > 2 then
			lastFullWarn[player] = now
			notify(player, "🎒 Backpack full! Clean and sell your scrap.", "error")
			remotes.FX:FireClient(player, { Kind = "BackpackFull" })
		end
		return
	end

	local power = playerPower(data)
	local hits = 0
	for _, rawId in ipairs(ids) do
		if hits >= toolDef.Targets then
			break
		end
		local id = tonumber(rawId)
		local state = id and scraps[id]
		if state and state.Model.Parent then
			local dist = (state.Position - root.Position).Magnitude
			local size = (state.Model.PrimaryPart :: BasePart).Size.Magnitude / 2
			if dist <= toolDef.Range + size + 6 then
				hits += 1
				local rarityDef = Config.Rarities[state.Rarity]
				if not data.Zones[state.Zone] then
					notify(player, "🔒 Unlock this zone first!", "error")
				elseif power < rarityDef.MinPower then
					remotes.FX:FireClient(player, { Kind = "TooWeak", Id = id, Rarity = state.Rarity })
				else
					state.HP -= power
					state.Model:SetAttribute("HP", math.max(0, state.HP))
					if state.HP <= 0 then
						local pos = (state.Model.PrimaryPart :: BasePart).Position
						remove(state)
						award(player, state.ScrapId, state.Rarity, pos, "Tool")
						remotes.FX:FireAllClients({ Kind = "Break", Position = pos, Rarity = state.Rarity, Player = player.UserId })
						if DataService.freeSpace(player) <= 0 then
							break
						end
					end
				end
			end
		end
	end
end

-- Used by the Magnet Crane machine: grabs a virtual scrap from the best zone
-- the player has unlocked, limited to rarities their tool can handle.
function ScrapService.grantRandom(player: Player): boolean
	local data = DataService.get(player)
	if not data or DataService.freeSpace(player) <= 0 then
		return false
	end
	local best = "Junkyard"
	for _, id in ipairs(Config.ZoneOrder) do
		if data.Zones[id] then
			best = id
		end
	end
	local power = playerPower(data)
	local weights = {}
	for rarity, w in pairs(Config.Zones[best].Weights) do
		if Config.Rarities[rarity].MinPower <= power then
			weights[rarity] = w
		end
	end
	if next(weights) == nil then
		weights = { Common = 1 }
	end
	local rarity = pickRarity(weights)
	award(player, pickScrap(rarity), rarity, nil, "Crane")
	return true
end

function ScrapService.init(remoteFolder: Folder)
	remotes = remoteFolder
	folder = workspace:WaitForChild("Scraps") :: Folder
	remotes.Hit.OnServerEvent:Connect(onHit)
	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
		lastFullWarn[player] = nil
	end)
	-- initial fill
	for _, zoneId in ipairs(Config.ZoneOrder) do
		local zone = Config.Zones[zoneId]
		zoneCounts[zoneId] = 0
		for _ = 1, zone.MaxScraps do
			ScrapService.spawn(zoneId)
		end
	end
	-- respawn loop
	task.spawn(function()
		while true do
			task.wait(Config.ScrapRespawnTime)
			for _, zoneId in ipairs(Config.ZoneOrder) do
				local zone = Config.Zones[zoneId]
				local missing = zone.MaxScraps - (zoneCounts[zoneId] or 0)
				for _ = 1, math.min(3, missing) do
					ScrapService.spawn(zoneId)
				end
			end
		end
	end)
end

return ScrapService
