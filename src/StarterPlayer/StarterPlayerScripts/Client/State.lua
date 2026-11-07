-- State: the latest copy of this player's data, pushed by the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local State = {}

State.Data = nil :: any
State.Changed = Instance.new("BindableEvent")
State.Ready = false

function State.set(data)
	State.Data = data
	State.Ready = true
	State.Changed:Fire(data)
end

function State.itemCount(): number
	local total = 0
	if State.Data then
		for _, n in pairs(State.Data.Inventory) do
			total += n
		end
	end
	return total
end

function State.capacity(): number
	if not State.Data then
		return 0
	end
	return Config.BackpackCapacity(State.Data.Upgrades.Backpack or 0)
end

-- Inventory as a sorted list of stacks.
function State.stacks(filter: ((string, number) -> boolean)?)
	local list = {}
	if not State.Data then
		return list
	end
	for key, n in pairs(State.Data.Inventory) do
		local id, stars = Config.ParseKey(key)
		if id and n > 0 and (not filter or filter(id, stars)) then
			table.insert(list, { Key = key, Id = id, Stars = stars, Count = n, Def = Config.Scraps[id] })
		end
	end
	table.sort(list, function(a, b)
		local ra = Config.Rarities[a.Def.Rarity].Order
		local rb = Config.Rarities[b.Def.Rarity].Order
		if ra ~= rb then
			return ra > rb
		end
		if a.Id ~= b.Id then
			return a.Def.Value > b.Def.Value
		end
		return a.Stars > b.Stars
	end)
	return list
end

function State.dirtyCount(): number
	local n = 0
	for _, s in
		ipairs(State.stacks(function(_, stars)
			return stars == 0
		end))
	do
		n += s.Count
	end
	return n
end

function State.cleanCount(): number
	local n = 0
	for _, s in
		ipairs(State.stacks(function(_, stars)
			return stars > 0
		end))
	do
		n += s.Count
	end
	return n
end

function State.toolPower(): number
	local d = State.Data
	if not d then
		return 0
	end
	local tool = Config.Tools[d.EquippedTool]
	return tool and tool.Power * Config.ToolPowerMultiplier(d.Upgrades.ToolStrength or 0) or 0
end

return State
