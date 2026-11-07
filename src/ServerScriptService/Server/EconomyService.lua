-- EconomyService: selling, buying tools / upgrades / machines / zones,
-- equipping tools and teleporting between unlocked zones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local ToolService = require(script.Parent.ToolService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local EconomyService = {}

local remotes: Folder
local lastTeleport: { [Player]: number } = {}

local function fx(player: Player, payload)
	remotes.FX:FireClient(player, payload)
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function sellPad(): BasePart?
	local hub = workspace:FindFirstChild("Scrapyard") and workspace.Scrapyard:FindFirstChild("Hub")
	local shop = hub and hub:FindFirstChild("ScrapExchange")
	return shop and shop:FindFirstChild("SellPad") :: BasePart?
end

-- Sells clean items. `filter(scrapId, stars)` decides which stacks are sold.
function EconomyService.sellWhere(player: Player, filter: (string, number) -> boolean, source: string): (number, number)
	local data = DataService.get(player)
	if not data then
		return 0, 0
	end
	local total, count = 0, 0
	local sellLvl = data.Upgrades.SellBonus or 0
	local polishLvl = data.Machines.PolishLab or 0
	for key, n in pairs(data.Inventory) do
		local id, stars = Config.ParseKey(key)
		if id and stars >= 1 and n > 0 and filter(id, stars) then
			total += Config.SellPrice(id, stars, sellLvl, polishLvl) * n
			count += n
			data.Inventory[key] = nil
		end
	end
	if count > 0 then
		DataService.addCash(player, total)
		DataService.markDirty(player)
		fx(player, { Kind = "Sell", Amount = total, Count = count, Source = source })
		if source == "Shop" then
			local pad = sellPad()
			local coins = pad and pad:FindFirstChild("CoinFX") :: ParticleEmitter?
			if coins then
				coins:Emit(math.clamp(count * 4, 10, 80))
			end
		end
	end
	return total, count
end

local function sell(player: Player, key: any)
	local root = rootOf(player)
	local pad = sellPad()
	if not root or not pad or (root.Position - pad.Position).Magnitude > 45 then
		return false, "Go to the Sell Shop to sell!"
	end
	local total, count
	if key == "All" then
		total, count = EconomyService.sellWhere(player, function()
			return true
		end, "Shop")
	elseif typeof(key) == "string" then
		local wantId, wantStars = Config.ParseKey(key)
		if not wantId then
			return false, "Invalid item"
		end
		total, count = EconomyService.sellWhere(player, function(id, stars)
			return id == wantId and stars == wantStars
		end, "Shop")
	else
		return false, "Invalid item"
	end
	if count == 0 then
		return false, "Nothing clean to sell! Wash your scrap first."
	end
	return true, { Amount = total, Count = count }
end

local function buyTool(player: Player, toolId: any)
	local data = DataService.get(player)
	local def = typeof(toolId) == "string" and Config.Tools[toolId]
	if not data or not def then
		return false, "Invalid tool"
	end
	if data.Tools[toolId] then
		return false, "Already owned"
	end
	if not DataService.trySpend(player, def.Price) then
		return false, "Not enough cash!"
	end
	data.Tools[toolId] = true
	data.EquippedTool = toolId
	DataService.markDirty(player)
	ToolService.give(player)
	fx(player, { Kind = "Purchase", Text = def.Name })
	return true
end

local function equipTool(player: Player, toolId: any)
	local data = DataService.get(player)
	if not data or typeof(toolId) ~= "string" or not data.Tools[toolId] then
		return false, "You don't own that tool"
	end
	data.EquippedTool = toolId
	DataService.markDirty(player)
	ToolService.give(player)
	return true
end

local function buyUpgrade(player: Player, id: any)
	local data = DataService.get(player)
	local def = typeof(id) == "string" and Config.Upgrades[id]
	if not data or not def then
		return false, "Invalid upgrade"
	end
	local level = data.Upgrades[id] or 0
	if level >= def.MaxLevel then
		return false, "Maxed out!"
	end
	if not DataService.trySpend(player, Config.UpgradeCost(id, level)) then
		return false, "Not enough cash!"
	end
	data.Upgrades[id] = level + 1
	DataService.markDirty(player)
	ToolService.applyStats(player)
	fx(player, { Kind = "Purchase", Text = def.Name .. " Lv." .. (level + 1) })
	return true
end

local function buyMachine(player: Player, id: any)
	local data = DataService.get(player)
	local def = typeof(id) == "string" and Config.Machines[id]
	if not data or not def then
		return false, "Invalid machine"
	end
	local level = data.Machines[id] or 0
	if level >= def.MaxLevel then
		return false, "Maxed out!"
	end
	if not DataService.trySpend(player, Config.MachineCost(id, level)) then
		return false, "Not enough cash!"
	end
	data.Machines[id] = level + 1
	DataService.markDirty(player)
	fx(player, { Kind = "Purchase", Text = level == 0 and (def.Name .. " built!") or (def.Name .. " Lv." .. (level + 1)) })
	return true
end

local function unlockZone(player: Player, id: any)
	local data = DataService.get(player)
	local def = typeof(id) == "string" and Config.Zones[id]
	if not data or not def then
		return false, "Invalid zone"
	end
	if data.Zones[id] then
		return false, "Already unlocked"
	end
	local prev = Config.ZoneOrder[def.Order - 1]
	if prev and not data.Zones[prev] then
		return false, "Unlock " .. Config.Zones[prev].Name .. " first!"
	end
	if not DataService.trySpend(player, def.Price) then
		return false, "Need " .. Format.cash(def.Price) .. "!"
	end
	data.Zones[id] = true
	DataService.markDirty(player)
	fx(player, { Kind = "ZoneUnlocked", Zone = id })
	return true
end

local function teleport(player: Player, id: any)
	local data = DataService.get(player)
	local root = rootOf(player)
	if not data or not root then
		return false, "Can't teleport right now"
	end
	if os.clock() - (lastTeleport[player] or 0) < 2 then
		return false, "Teleporter recharging..."
	end
	local target: CFrame?
	if id == "Hub" then
		target = WorldBuilder.HubSpawn
	elseif typeof(id) == "string" and Config.Zones[id] then
		if not data.Zones[id] then
			return false, "Zone locked!"
		end
		target = WorldBuilder.ZoneSpawns[id]
	end
	if not target then
		return false, "Invalid destination"
	end
	lastTeleport[player] = os.clock()
	local char = player.Character :: Model
	char:PivotTo(target)
	return true
end

function EconomyService.handleAction(player: Player, action: string, a: any)
	if action == "Sell" then
		return sell(player, a)
	elseif action == "BuyTool" then
		return buyTool(player, a)
	elseif action == "EquipTool" then
		return equipTool(player, a)
	elseif action == "BuyUpgrade" then
		return buyUpgrade(player, a)
	elseif action == "BuyMachine" then
		return buyMachine(player, a)
	elseif action == "UnlockZone" then
		return unlockZone(player, a)
	elseif action == "Teleport" then
		return teleport(player, a)
	end
	return nil
end

function EconomyService.init(remoteFolder: Folder)
	remotes = remoteFolder
end

function EconomyService.forget(player: Player)
	lastTeleport[player] = nil
end

return EconomyService
