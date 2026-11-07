-- Config: every tunable number in Scrapyard Simulator lives here.
-- Both the server and the client read this module, so the UI always matches the
-- rules the server enforces.

local Config = {}

----------------------------------------------------------------------
-- Rarities
----------------------------------------------------------------------
export type Rarity = {
	Id: string,
	Name: string,
	Order: number,
	Color: Color3,
	Color2: Color3, -- second gradient colour for UI
	HP: number, -- how much tool damage a scrap of this rarity needs
	MinPower: number, -- minimum tool power needed to even dent it
	DirtSpots: number, -- dirt spots in the cleaning minigame
	DirtLayers: number, -- how many dirt types (mud / rust / grease) can appear
	ParTime: number, -- seconds for a 3-star clean (single item)
	Glow: boolean,
}

Config.Rarities = {
	Common = {
		Id = "Common",
		Name = "Common",
		Order = 1,
		Color = Color3.fromRGB(196, 204, 214),
		Color2 = Color3.fromRGB(132, 142, 156),
		HP = 10,
		MinPower = 0,
		DirtSpots = 5,
		DirtLayers = 1,
		ParTime = 5,
		Glow = false,
	},
	Uncommon = {
		Id = "Uncommon",
		Name = "Uncommon",
		Order = 2,
		Color = Color3.fromRGB(96, 230, 120),
		Color2 = Color3.fromRGB(32, 168, 78),
		HP = 28,
		MinPower = 0,
		DirtSpots = 7,
		DirtLayers = 2,
		ParTime = 7,
		Glow = false,
	},
	Rare = {
		Id = "Rare",
		Name = "Rare",
		Order = 3,
		Color = Color3.fromRGB(74, 178, 255),
		Color2 = Color3.fromRGB(40, 96, 230),
		HP = 80,
		MinPower = 10,
		DirtSpots = 9,
		DirtLayers = 2,
		ParTime = 9,
		Glow = true,
	},
	Epic = {
		Id = "Epic",
		Name = "Epic",
		Order = 4,
		Color = Color3.fromRGB(196, 110, 255),
		Color2 = Color3.fromRGB(120, 48, 220),
		HP = 260,
		MinPower = 25,
		DirtSpots = 11,
		DirtLayers = 3,
		ParTime = 11,
		Glow = true,
	},
	Legendary = {
		Id = "Legendary",
		Name = "Legendary",
		Order = 5,
		Color = Color3.fromRGB(255, 208, 64),
		Color2 = Color3.fromRGB(255, 136, 24),
		HP = 800,
		MinPower = 70,
		DirtSpots = 13,
		DirtLayers = 3,
		ParTime = 13,
		Glow = true,
	},
	Mythic = {
		Id = "Mythic",
		Name = "Mythic",
		Order = 6,
		Color = Color3.fromRGB(255, 82, 156),
		Color2 = Color3.fromRGB(110, 70, 255),
		HP = 2600,
		MinPower = 160,
		DirtSpots = 15,
		DirtLayers = 3,
		ParTime = 15,
		Glow = true,
	},
} :: { [string]: Rarity }

Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

----------------------------------------------------------------------
-- Scraps (collectables). Model builders live in Shared/ScrapModels.
----------------------------------------------------------------------
export type Scrap = {
	Id: string,
	Name: string,
	Rarity: string,
	Value: number, -- base sell value when cleaned (1 star)
	Size: number, -- approximate size in studs (used for hitbox / camera fit)
	Description: string,
}

Config.Scraps = {
	RustyCan = {
		Id = "RustyCan",
		Name = "Rusty Can",
		Rarity = "Common",
		Value = 6,
		Size = 2.2,
		Description = "A dented soup can. Smells like 1987.",
	},
	BentPipe = { Id = "BentPipe", Name = "Bent Pipe", Rarity = "Common", Value = 8, Size = 3.2, Description = "Plumbing that gave up." },
	OldTire = { Id = "OldTire", Name = "Old Tire", Rarity = "Common", Value = 11, Size = 3.6, Description = "Bald, cracked, still round." },
	ScrapGear = { Id = "ScrapGear", Name = "Scrap Gear", Rarity = "Common", Value = 14, Size = 3, Description = "Missing a tooth or two." },

	CarBattery = {
		Id = "CarBattery",
		Name = "Car Battery",
		Rarity = "Uncommon",
		Value = 38,
		Size = 3,
		Description = "Probably still has a spark.",
	},
	ChromeHubcap = {
		Id = "ChromeHubcap",
		Name = "Chrome Hubcap",
		Rarity = "Uncommon",
		Value = 46,
		Size = 3.4,
		Description = "Shines up like a mirror.",
	},
	CopperCoil = {
		Id = "CopperCoil",
		Name = "Copper Coil",
		Rarity = "Uncommon",
		Value = 58,
		Size = 3,
		Description = "Pure copper. Buyers love it.",
	},

	VintageRadio = {
		Id = "VintageRadio",
		Name = "Vintage Radio",
		Rarity = "Rare",
		Value = 160,
		Size = 3.6,
		Description = "Picks up stations from the past.",
	},
	TrafficLight = {
		Id = "TrafficLight",
		Name = "Traffic Light",
		Rarity = "Rare",
		Value = 210,
		Size = 4.6,
		Description = "Stuck on yellow forever.",
	},
	EngineBlock = {
		Id = "EngineBlock",
		Name = "V8 Engine Block",
		Rarity = "Rare",
		Value = 270,
		Size = 4.4,
		Description = "Eight cylinders of raw power.",
	},

	RobotHead = { Id = "RobotHead", Name = "Robot Head", Rarity = "Epic", Value = 850, Size = 4, Description = "It blinked. Did it blink?" },
	JetTurbine = {
		Id = "JetTurbine",
		Name = "Jet Turbine",
		Rarity = "Epic",
		Value = 1150,
		Size = 5,
		Description = "Fell off something very fast.",
	},

	GoldenWatch = {
		Id = "GoldenWatch",
		Name = "Golden Pocket Watch",
		Rarity = "Legendary",
		Value = 4200,
		Size = 4,
		Description = "Solid gold. Still ticking.",
	},
	ReactorCore = {
		Id = "ReactorCore",
		Name = "Mech Reactor Core",
		Rarity = "Legendary",
		Value = 5800,
		Size = 4.8,
		Description = "Humming with leftover energy.",
	},

	HoverDrive = {
		Id = "HoverDrive",
		Name = "Alien Hover Drive",
		Rarity = "Mythic",
		Value = 26000,
		Size = 5.4,
		Description = "Not from around here.",
	},
	TitanCrystal = {
		Id = "TitanCrystal",
		Name = "Titan Power Crystal",
		Rarity = "Mythic",
		Value = 42000,
		Size = 5.2,
		Description = "Pulses with ancient power.",
	},
} :: { [string]: Scrap }

-- Scraps grouped by rarity (built once).
Config.ScrapsByRarity = {} :: { [string]: { string } }
for id, scrap in pairs(Config.Scraps) do
	local list = Config.ScrapsByRarity[scrap.Rarity]
	if not list then
		list = {}
		Config.ScrapsByRarity[scrap.Rarity] = list
	end
	table.insert(list, id)
end
for _, list in pairs(Config.ScrapsByRarity) do
	table.sort(list, function(a, b)
		return Config.Scraps[a].Value < Config.Scraps[b].Value
	end)
end

----------------------------------------------------------------------
-- Cleaning
----------------------------------------------------------------------
Config.Cleaning = {
	-- Dirt types used in the minigame. The matching tool removes them fast,
	-- the wrong tool only chips away slowly.
	DirtTypes = {
		{ Id = "Mud", Name = "Mud", Tool = "Sponge", Color = Color3.fromRGB(122, 84, 46), Color2 = Color3.fromRGB(84, 56, 30), HP = 1 },
		{
			Id = "Rust",
			Name = "Rust",
			Tool = "Brush",
			Color = Color3.fromRGB(206, 104, 38),
			Color2 = Color3.fromRGB(140, 62, 24),
			HP = 1.35,
		},
		{
			Id = "Grease",
			Name = "Grease",
			Tool = "Spray",
			Color = Color3.fromRGB(46, 44, 58),
			Color2 = Color3.fromRGB(22, 20, 30),
			HP = 1.6,
		},
	},
	Tools = {
		{ Id = "Sponge", Name = "Sponge", Key = "One", Emoji = "🧽", Color = Color3.fromRGB(255, 214, 64) },
		{ Id = "Brush", Name = "Wire Brush", Key = "Two", Emoji = "🪥", Color = Color3.fromRGB(255, 120, 72) },
		{ Id = "Spray", Name = "Power Spray", Key = "Three", Emoji = "💦", Color = Color3.fromRGB(80, 200, 255) },
	},
	WrongToolMultiplier = 0.2,
	BaseScrubRate = 1.6, -- dirt HP removed per second of scrubbing at 0 upgrades
	-- Server-side minimum time per spot (anti-cheat) as a fraction of the
	-- fastest humanly possible time.
	MinSecondsPerSpot = 0.18,
	StarMultipliers = { 1, 1.25, 1.6 }, -- 1 / 2 / 3 stars
	BatchParTimeFactor = 0.25, -- each extra item in the batch adds 25% par time
	StationCount = 4,
}

----------------------------------------------------------------------
-- Collection tools
----------------------------------------------------------------------
export type ToolDef = {
	Id: string,
	Name: string,
	Order: number,
	Price: number,
	Power: number,
	Cooldown: number,
	Range: number,
	Targets: number, -- how many scraps one swing hits
	Color: Color3,
	Description: string,
}

Config.Tools = {
	RustyGrabber = {
		Id = "RustyGrabber",
		Name = "Rusty Grabber",
		Order = 1,
		Price = 0,
		Power = 5,
		Cooldown = 0.45,
		Range = 14,
		Targets = 1,
		Color = Color3.fromRGB(196, 120, 64),
		Description = "A squeaky claw on a stick. Everyone starts somewhere.",
	},
	SteelCrowbar = {
		Id = "SteelCrowbar",
		Name = "Steel Crowbar",
		Order = 2,
		Price = 600,
		Power = 13,
		Cooldown = 0.4,
		Range = 15,
		Targets = 1,
		Color = Color3.fromRGB(230, 60, 60),
		Description = "Pries open Rare scrap with ease.",
	},
	MagnetWand = {
		Id = "MagnetWand",
		Name = "Magnet Wand",
		Order = 3,
		Price = 6500,
		Power = 32,
		Cooldown = 0.36,
		Range = 19,
		Targets = 1,
		Color = Color3.fromRGB(70, 140, 255),
		Description = "Magnetic pull strong enough for Epic scrap.",
	},
	HydraulicClaw = {
		Id = "HydraulicClaw",
		Name = "Hydraulic Claw",
		Order = 4,
		Price = 45000,
		Power = 80,
		Cooldown = 0.34,
		Range = 19,
		Targets = 2,
		Color = Color3.fromRGB(255, 196, 40),
		Description = "Crushes Legendary scrap. Hits 2 scraps at once.",
	},
	PlasmaCutter = {
		Id = "PlasmaCutter",
		Name = "Plasma Cutter",
		Order = 5,
		Price = 320000,
		Power = 190,
		Cooldown = 0.3,
		Range = 21,
		Targets = 2,
		Color = Color3.fromRGB(255, 70, 200),
		Description = "Slices through Mythic alloys.",
	},
	QuantumVacuum = {
		Id = "QuantumVacuum",
		Name = "Quantum Vacuum",
		Order = 6,
		Price = 2000000,
		Power = 480,
		Cooldown = 0.25,
		Range = 25,
		Targets = 4,
		Color = Color3.fromRGB(80, 255, 220),
		Description = "Bends space to suck up 4 scraps at a time.",
	},
} :: { [string]: ToolDef }

Config.ToolOrder = { "RustyGrabber", "SteelCrowbar", "MagnetWand", "HydraulicClaw", "PlasmaCutter", "QuantumVacuum" }

----------------------------------------------------------------------
-- Upgrades (permanent, levelled)
----------------------------------------------------------------------
export type UpgradeDef = {
	Id: string,
	Name: string,
	Emoji: string,
	Order: number,
	MaxLevel: number,
	BaseCost: number,
	CostGrowth: number,
	Color: Color3,
	Describe: (level: number) -> string,
}

Config.Upgrades = {
	Backpack = {
		Id = "Backpack",
		Name = "Bigger Backpack",
		Emoji = "🎒",
		Order = 1,
		MaxLevel = 25,
		BaseCost = 90,
		CostGrowth = 1.5,
		Color = Color3.fromRGB(255, 150, 60),
		Describe = function(level: number)
			return string.format("Carry %d scraps", 12 + level * 6)
		end,
	},
	ToolStrength = {
		Id = "ToolStrength",
		Name = "Tool Strength",
		Emoji = "💪",
		Order = 2,
		MaxLevel = 20,
		BaseCost = 150,
		CostGrowth = 1.55,
		Color = Color3.fromRGB(255, 80, 80),
		Describe = function(level: number)
			return string.format("+%d%% tool power", level * 12)
		end,
	},
	WalkSpeed = {
		Id = "WalkSpeed",
		Name = "Running Shoes",
		Emoji = "👟",
		Order = 3,
		MaxLevel = 10,
		BaseCost = 140,
		CostGrowth = 1.7,
		Color = Color3.fromRGB(80, 200, 255),
		Describe = function(level: number)
			return string.format("%d walk speed", 16 + math.floor(level * 1.6 + 0.5))
		end,
	},
	ScrubPower = {
		Id = "ScrubPower",
		Name = "Scrub Power",
		Emoji = "🫧",
		Order = 4,
		MaxLevel = 15,
		BaseCost = 120,
		CostGrowth = 1.6,
		Color = Color3.fromRGB(120, 230, 255),
		Describe = function(level: number)
			return string.format("x%.2f cleaning speed", 1 + level * 0.2)
		end,
	},
	WashTub = {
		Id = "WashTub",
		Name = "Bigger Wash Tub",
		Emoji = "🛁",
		Order = 5,
		MaxLevel = 11,
		BaseCost = 350,
		CostGrowth = 1.85,
		Color = Color3.fromRGB(110, 140, 255),
		Describe = function(level: number)
			return string.format("Clean %d items per wash", 1 + level)
		end,
	},
	SellBonus = {
		Id = "SellBonus",
		Name = "Haggling",
		Emoji = "🤝",
		Order = 6,
		MaxLevel = 20,
		BaseCost = 250,
		CostGrowth = 1.6,
		Color = Color3.fromRGB(90, 230, 110),
		Describe = function(level: number)
			return string.format("+%d%% sell price", level * 10)
		end,
	},
	Luck = {
		Id = "Luck",
		Name = "Lucky Finds",
		Emoji = "🍀",
		Order = 7,
		MaxLevel = 12,
		BaseCost = 400,
		CostGrowth = 1.75,
		Color = Color3.fromRGB(70, 220, 140),
		Describe = function(level: number)
			return string.format("%d%% double-scrap chance", level * 4)
		end,
	},
} :: { [string]: UpgradeDef }

Config.UpgradeOrder = { "Backpack", "ToolStrength", "WalkSpeed", "ScrubPower", "WashTub", "SellBonus", "Luck" }

function Config.UpgradeCost(id: string, level: number): number
	local def = Config.Upgrades[id]
	return math.floor(def.BaseCost * def.CostGrowth ^ level + 0.5)
end

function Config.BackpackCapacity(level: number): number
	return 12 + level * 6
end

function Config.WalkSpeed(level: number): number
	return 16 + math.floor(level * 1.6 + 0.5)
end

function Config.ScrubMultiplier(level: number): number
	return 1 + level * 0.2
end

function Config.WashBatch(level: number): number
	return 1 + level
end

function Config.ToolPowerMultiplier(level: number): number
	return 1 + level * 0.12
end

function Config.LuckChance(upgradeLevel: number, radarLevel: number): number
	return math.min(0.75, upgradeLevel * 0.04 + radarLevel * 0.02)
end

----------------------------------------------------------------------
-- Machines (bought once, then levelled up to MaxLevel)
----------------------------------------------------------------------
export type MachineDef = {
	Id: string,
	Name: string,
	Emoji: string,
	Order: number,
	Price: number,
	UpgradeGrowth: number,
	MaxLevel: number,
	Color: Color3,
	Describe: (level: number) -> string,
}

Config.Machines = {
	AutoWasher = {
		Id = "AutoWasher",
		Name = "Auto Washer",
		Emoji = "🧺",
		Order = 1,
		Price = 1800,
		UpgradeGrowth = 2.3,
		MaxLevel = 5,
		Color = Color3.fromRGB(80, 190, 255),
		Describe = function(level: number)
			return string.format("Cleans %d dirty scrap every %ds (1★)", level, ({ 10, 8, 6, 5, 4 })[math.max(level, 1)])
		end,
	},
	MagnetCrane = {
		Id = "MagnetCrane",
		Name = "Magnet Crane",
		Emoji = "🧲",
		Order = 2,
		Price = 4500,
		UpgradeGrowth = 2.4,
		MaxLevel = 5,
		Color = Color3.fromRGB(255, 90, 90),
		Describe = function(level: number)
			return string.format("Grabs a scrap from your best zone every %ds", ({ 20, 16, 12, 9, 6 })[math.max(level, 1)])
		end,
	},
	RarityRadar = {
		Id = "RarityRadar",
		Name = "Rarity Radar",
		Emoji = "📡",
		Order = 3,
		Price = 8000,
		UpgradeGrowth = 2.5,
		MaxLevel = 5,
		Color = Color3.fromRGB(120, 255, 140),
		Describe = function(level: number)
			local threshold = ({ "Rare", "Rare", "Uncommon", "Uncommon", "Uncommon" })[math.max(level, 1)]
			return string.format("Reveals %s+ scrap through walls, +%d%% luck", threshold, level * 2)
		end,
	},
	AutoSeller = {
		Id = "AutoSeller",
		Name = "Conveyor Seller",
		Emoji = "🏭",
		Order = 4,
		Price = 15000,
		UpgradeGrowth = 2.5,
		MaxLevel = 5,
		Color = Color3.fromRGB(255, 196, 60),
		Describe = function(level: number)
			local cap = Config.RarityOrder[math.clamp(level + 1, 1, 6)]
			return string.format("Auto-sells clean %s-or-lower scrap every %ds", cap, ({ 15, 12, 10, 8, 6 })[math.max(level, 1)])
		end,
	},
	PolishLab = {
		Id = "PolishLab",
		Name = "Polish Lab",
		Emoji = "💎",
		Order = 5,
		Price = 40000,
		UpgradeGrowth = 2.6,
		MaxLevel = 5,
		Color = Color3.fromRGB(200, 120, 255),
		Describe = function(level: number)
			return string.format("+%d%% value on every sale", level * 15)
		end,
	},
} :: { [string]: MachineDef }

Config.MachineOrder = { "AutoWasher", "MagnetCrane", "RarityRadar", "AutoSeller", "PolishLab" }

function Config.MachineCost(id: string, currentLevel: number): number
	local def = Config.Machines[id]
	if currentLevel <= 0 then
		return def.Price
	end
	return math.floor(def.Price * def.UpgradeGrowth ^ currentLevel + 0.5)
end

Config.MachineStats = {
	AutoWasherInterval = { 10, 8, 6, 5, 4 },
	MagnetCraneInterval = { 20, 16, 12, 9, 6 },
	AutoSellerInterval = { 15, 12, 10, 8, 6 },
	RadarThreshold = { 3, 3, 2, 2, 2 }, -- rarity Order shown by radar
}

----------------------------------------------------------------------
-- Zones (one shared scrapyard, unlocked per player)
----------------------------------------------------------------------
export type ZoneDef = {
	Id: string,
	Name: string,
	Order: number,
	Price: number,
	ZMin: number,
	ZMax: number,
	HalfWidth: number,
	MaxScraps: number,
	Weights: { [string]: number },
	Color: Color3,
	Emoji: string,
}

Config.Zones = {
	Junkyard = {
		Id = "Junkyard",
		Name = "Junk Fields",
		Order = 1,
		Price = 0,
		ZMin = 78,
		ZMax = 270,
		HalfWidth = 120,
		MaxScraps = 46,
		Weights = { Common = 76, Uncommon = 21, Rare = 3 },
		Color = Color3.fromRGB(150, 210, 90),
		Emoji = "🗑️",
	},
	RustCanyon = {
		Id = "RustCanyon",
		Name = "Rust Canyon",
		Order = 2,
		Price = 1500,
		ZMin = 290,
		ZMax = 460,
		HalfWidth = 120,
		MaxScraps = 40,
		Weights = { Common = 28, Uncommon = 45, Rare = 22, Epic = 5 },
		Color = Color3.fromRGB(255, 140, 60),
		Emoji = "🏜️",
	},
	ToxicWaste = {
		Id = "ToxicWaste",
		Name = "Toxic Wasteland",
		Order = 3,
		Price = 22000,
		ZMin = 480,
		ZMax = 650,
		HalfWidth = 120,
		MaxScraps = 36,
		Weights = { Uncommon = 24, Rare = 44, Epic = 26, Legendary = 6 },
		Color = Color3.fromRGB(120, 255, 60),
		Emoji = "☢️",
	},
	MeteorCrater = {
		Id = "MeteorCrater",
		Name = "Meteor Crater",
		Order = 4,
		Price = 250000,
		ZMin = 670,
		ZMax = 840,
		HalfWidth = 120,
		MaxScraps = 32,
		Weights = { Rare = 30, Epic = 40, Legendary = 24, Mythic = 6 },
		Color = Color3.fromRGB(180, 110, 255),
		Emoji = "☄️",
	},
} :: { [string]: ZoneDef }

Config.ZoneOrder = { "Junkyard", "RustCanyon", "ToxicWaste", "MeteorCrater" }

Config.ScrapRespawnTime = 6 -- seconds between respawn ticks per zone

----------------------------------------------------------------------
-- Selling
----------------------------------------------------------------------
function Config.SellPrice(scrapId: string, stars: number, sellLevel: number, polishLevel: number): number
	local scrap = Config.Scraps[scrapId]
	if not scrap or stars < 1 then
		return 0
	end
	local mult = Config.Cleaning.StarMultipliers[math.clamp(stars, 1, 3)]
	local bonus = (1 + sellLevel * 0.1) * (1 + polishLevel * 0.15)
	return math.floor(scrap.Value * mult * bonus + 0.5)
end

----------------------------------------------------------------------
-- Inventory keys: "<ScrapId>:<stars>"  (stars 0 = still dirty)
----------------------------------------------------------------------
function Config.ItemKey(scrapId: string, stars: number): string
	return scrapId .. ":" .. tostring(stars)
end

function Config.ParseKey(key: string): (string?, number)
	local id, stars = string.match(key, "^(%w+):(%d)$")
	if not id or not Config.Scraps[id] then
		return nil, 0
	end
	return id, tonumber(stars) or 0
end

Config.StartingCash = 0
Config.DataStoreName = "ScrapyardSimulator_v1"
Config.AutoSaveInterval = 90

return Config
