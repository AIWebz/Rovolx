-- WorldBuilder: generates the whole shared scrapyard at server start.
-- Hub (spawn, wash stations, sell shop, tool shop, upgrade lab, machine bay)
-- followed by four gated scrap zones.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local ToolModels = require(ReplicatedStorage.Shared.ToolModels)
local Format = require(ReplicatedStorage.Shared.Format)
local Props = require(script.Parent.Props)
local MachineModels = require(script.Parent.MachineModels)

local C = Build.Colors
local M = Enum.Material
local rad = math.rad
local CF = CFrame.new
local ANG = CFrame.Angles
local V3 = Vector3.new
local RGB = Color3.fromRGB

local WorldBuilder = {}

local rng = Random.new(2024)
local terrain = workspace.Terrain

WorldBuilder.Stations = {} :: { Model }
WorldBuilder.ZoneSpawns = {} :: { [string]: CFrame }
WorldBuilder.HubSpawn = CFrame.new(0, 4, -20)

local root: Folder

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function newModel(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function collide(m: Instance)
	Build.setAll(m, { CanCollide = true })
end

local function prompt(parent: BasePart, action: string, object: string, openUI: string?, holdTime: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = holdTime or 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Style = Enum.ProximityPromptStyle.Default
	if openUI then
		p:SetAttribute("OpenUI", openUI)
	end
	p.Parent = parent
	return p
end

local function promptPart(parent: Instance, cf: CFrame, size: Vector3?): BasePart
	return Build.part(parent, "Part", {
		Name = "PromptPart",
		Size = size or V3(2, 2, 2),
		CFrame = cf,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
end

-- Big chunky sign with a coloured frame.
local function bigSign(parent: Instance, cf: CFrame, size: Vector3, text: string, bg: Color3, textColor: Color3?): BasePart
	local board = Build.block(parent, size, cf, bg, M.SmoothPlastic, "Sign")
	Build.block(
		parent,
		size + V3(0.6, 0.6, -size.Z * 0.4),
		cf * CF(0, 0, size.Z * 0.3),
		bg:Lerp(Color3.new(0, 0, 0), 0.35),
		M.SmoothPlastic
	)
	Build.sign(board, Enum.NormalId.Front, text, textColor or C.White, bg:Lerp(Color3.new(0, 0, 0), 0.55))
	Build.sign(board, Enum.NormalId.Back, text, textColor or C.White, bg:Lerp(Color3.new(0, 0, 0), 0.55))
	-- bulbs around the edge
	local bulbs = math.floor(size.X / 2.2)
	for i = 0, bulbs - 1 do
		local x = -size.X / 2 + 1.1 + i * ((size.X - 2.2) / math.max(1, bulbs - 1))
		for _, y in ipairs({ size.Y / 2 + 0.3, -size.Y / 2 - 0.3 }) do
			Build.ball(parent, 0.5, cf * CF(x, y, -size.Z / 2), RGB(255, 240, 160), M.Neon)
		end
	end
	return board
end

----------------------------------------------------------------------
-- Lighting / atmosphere for the bright simulator look
----------------------------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 14.2
	Lighting.Brightness = 3
	Lighting.GlobalShadows = true
	Lighting.Ambient = RGB(110, 105, 120)
	Lighting.OutdoorAmbient = RGB(150, 150, 165)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.ExposureCompensation = 0.1
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	for _, c in ipairs(Lighting:GetChildren()) do
		if c:IsA("PostEffect") or c:IsA("Atmosphere") or c:IsA("Sky") then
			c:Destroy()
		end
	end
	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.28
	atmo.Offset = 0.1
	atmo.Color = RGB(205, 225, 255)
	atmo.Decay = RGB(255, 190, 140)
	atmo.Glare = 0.3
	atmo.Haze = 1.2
	atmo.Parent = Lighting
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.55
	bloom.Size = 28
	bloom.Threshold = 1.25
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.28
	cc.Contrast = 0.1
	cc.Brightness = 0.02
	cc.TintColor = RGB(255, 250, 245)
	cc.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting
end

----------------------------------------------------------------------
-- Terrain
----------------------------------------------------------------------
local function setupTerrain()
	terrain:Clear()
	terrain:SetMaterialColor(M.Ground, RGB(132, 104, 76))
	terrain:SetMaterialColor(M.Mud, RGB(98, 76, 58))
	terrain:SetMaterialColor(M.LeafyGrass, RGB(110, 190, 80))
	terrain:SetMaterialColor(M.Grass, RGB(110, 190, 80))
	terrain:SetMaterialColor(M.Sandstone, RGB(222, 132, 74))
	terrain:SetMaterialColor(M.Sand, RGB(240, 180, 110))
	terrain:SetMaterialColor(M.Rock, RGB(170, 96, 62))
	terrain:SetMaterialColor(M.Slate, RGB(70, 84, 72))
	terrain:SetMaterialColor(M.Basalt, RGB(74, 56, 98))
	terrain:SetMaterialColor(M.CrackedLava, RGB(255, 90, 160))
	terrain:SetMaterialColor(M.Asphalt, RGB(70, 72, 80))

	local function slab(x0: number, x1: number, z0: number, z1: number, material: Enum.Material)
		local size = V3(x1 - x0, 8, z1 - z0)
		terrain:FillBlock(CF((x0 + x1) / 2, -4, (z0 + z1) / 2), size, material)
	end
	-- whole map base
	slab(-150, 150, -120, 870, M.Ground)
	-- hub surroundings: grass verge
	slab(-150, 150, -120, 74, M.LeafyGrass)
	-- zone grounds
	slab(-150, 150, 74, 276, M.Ground)
	slab(-150, 150, 276, 466, M.Sandstone)
	slab(-150, 150, 466, 656, M.Slate)
	slab(-150, 150, 656, 870, M.Basalt)

	-- mud patches in the junk fields
	for _ = 1, 14 do
		local x = rng:NextNumber(-110, 110)
		local z = rng:NextNumber(90, 260)
		terrain:FillCylinder(CF(x, -0.9, z), 2, rng:NextNumber(6, 14), M.Mud)
	end
	-- sand dunes in rust canyon
	for _ = 1, 10 do
		local x = rng:NextNumber(-110, 110)
		local z = rng:NextNumber(300, 455)
		terrain:FillCylinder(CF(x, -0.9, z), 2, rng:NextNumber(6, 12), M.Sand)
	end
	-- canyon walls
	for z = 285, 465, 12 do
		for _, side in ipairs({ -1, 1 }) do
			local x = side * rng:NextNumber(118, 128)
			terrain:FillBall(V3(x, rng:NextNumber(2, 10), z), rng:NextNumber(12, 18), M.Rock)
			terrain:FillBall(V3(x + side * 8, rng:NextNumber(14, 22), z + 5), rng:NextNumber(8, 12), M.Sandstone)
		end
	end
	-- rock mesas in the canyon
	for _, p in ipairs({ V3(-70, 0, 340), V3(75, 0, 410), V3(-55, 0, 440), V3(60, 0, 320) }) do
		terrain:FillCylinder(CF(p.X, 6, p.Z), 14, 9, M.Rock)
		terrain:FillCylinder(CF(p.X, 14, p.Z), 3, 11, M.Sandstone)
	end
	-- meteor crater: carve a bowl and line its floor with glowing lava rock
	local crater = V3(0, 0, 760)
	terrain:FillBall(crater + V3(0, 50, 0), 62, M.Air)
	for a = 0, 330, 30 do
		local p = crater + V3(math.cos(rad(a)) * 42, 1, math.sin(rad(a)) * 42)
		terrain:FillBall(p, rng:NextNumber(7, 11), M.Basalt)
	end
	local floor = Region3.new(crater + V3(-24, -16, -24), crater + V3(24, -6, 24)):ExpandToGrid(4)
	terrain:ReplaceMaterial(floor, 4, M.Basalt, M.CrackedLava)
end

----------------------------------------------------------------------
-- Hub
----------------------------------------------------------------------
local function buildPlaza(hub: Instance)
	local plaza = newModel("Plaza", hub)
	Build.block(plaza, V3(180, 1, 160), CF(0, -0.3, -10), RGB(196, 200, 210), M.Pavement)
	-- coloured tile ring around the spawn
	Build.cylY(plaza, 0.3, 34, CF(0, 0.3, -20), RGB(80, 170, 255), M.SmoothPlastic)
	Build.cylY(plaza, 0.35, 30, CF(0, 0.33, -20), RGB(240, 245, 255), M.SmoothPlastic)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		Build.block(plaza, V3(5, 0.4, 2), CF(0, 0.36, -20) * ANG(0, a, 0) * CF(12.5, 0, 0), RGB(255, 200, 60), M.SmoothPlastic)
	end
	-- road to the junk fields
	Build.block(plaza, V3(26, 0.4, 92), CF(0, 0.22, 26), RGB(70, 72, 82), M.Asphalt)
	for z = -14, 66, 10 do
		Build.block(plaza, V3(0.8, 0.45, 5), CF(0, 0.25, z), RGB(255, 210, 60), M.SmoothPlastic)
	end
	Build.block(plaza, V3(0.8, 0.45, 92), CF(-12.6, 0.25, 26), C.White, M.SmoothPlastic)
	Build.block(plaza, V3(0.8, 0.45, 92), CF(12.6, 0.25, 26), C.White, M.SmoothPlastic)
	collide(plaza)

	-- spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = V3(12, 1, 12)
	spawn.CFrame = CF(0, 0.5, -20) * ANG(0, math.pi, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Material = M.Neon
	spawn.Color = RGB(90, 200, 255)
	spawn.Transparency = 0.2
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = hub
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	-- lamps around the plaza
	for _, p in ipairs({ V3(-20, 0, -40), V3(20, 0, -40), V3(-18, 0, 10), V3(18, 0, 10), V3(-18, 0, 60), V3(18, 0, 60) }) do
		Props.lamp(hub, CF(p) * ANG(0, p.X > 0 and math.pi or 0, 0))
	end
	-- benches/planters
	for _, x in ipairs({ -26, 26 }) do
		for _, z in ipairs({ -60, -2 }) do
			local planter = newModel("Planter", hub)
			Build.block(planter, V3(8, 2, 8), CF(x, 1, z), RGB(150, 110, 80), M.WoodPlanks)
			Build.block(planter, V3(7, 0.4, 7), CF(x, 2, z), RGB(90, 70, 50), M.Ground)
			Build.ball(planter, 5.5, CF(x, 4.2, z), RGB(90, 200, 90), M.Grass)
			Build.ball(planter, 3.5, CF(x + 1.5, 6, z - 1), RGB(110, 220, 100), M.Grass)
			for i = 0, 4 do
				local a = i / 5 * math.pi * 2
				Build.ball(planter, 0.8, CF(x, 4.4, z) * ANG(0, a, 0) * CF(2.6, 0.5, 0), Props.randomBright(), M.SmoothPlastic)
			end
			collide(planter)
		end
	end
end

local function buildArch(parent: Instance, z: number, text: string, color: Color3)
	local arch = newModel("Arch", parent)
	for _, x in ipairs({ -17, 17 }) do
		Props.crushedCube(arch, CF(x, 0, z) * ANG(0, rad(8), 0), RGB(80, 150, 255))
		Props.crushedCube(arch, CF(x, 5, z) * ANG(0, rad(-6), 0), RGB(255, 90, 90))
		Props.crushedCube(arch, CF(x, 10, z) * ANG(0, rad(4), 0), RGB(255, 200, 50))
	end
	Build.block(arch, V3(42, 2, 4), CF(0, 16, z), RGB(60, 62, 72), M.Metal)
	bigSign(arch, CF(0, 20.5, z) * ANG(0, math.pi, 0), V3(34, 7, 1.2), text, color)
	collide(arch)
end

-- Wash station: cabinet, tub, faucet, pressure washer, tool shelf.
local function buildStation(parent: Instance, index: number, cf: CFrame): Model
	local st = newModel("Station" .. index, parent)
	st:SetAttribute("StationId", index)
	local blue = RGB(70, 170, 255)
	local white = RGB(245, 248, 255)
	-- cabinet (local -Z faces the player)
	Build.block(st, V3(8, 3.4, 5), cf * CF(0, 1.7, 0), white, M.SmoothPlastic)
	Build.block(st, V3(8.2, 0.4, 5.2), cf * CF(0, 0.2, 0), blue, M.SmoothPlastic)
	for _, x in ipairs({ -2, 2 }) do
		Build.block(st, V3(3.6, 2.4, 0.1), cf * CF(x, 1.8, -2.52), RGB(225, 232, 245), M.SmoothPlastic)
		Build.block(st, V3(1.2, 0.2, 0.2), cf * CF(x, 2.7, -2.62), C.Chrome, M.Metal)
	end
	-- tub rim + water
	local top = cf * CF(0, 3.5, 0)
	Build.block(st, V3(8.4, 0.4, 0.8), top * CF(0, 0, -2.3), blue, M.SmoothPlastic)
	Build.block(st, V3(8.4, 0.4, 0.8), top * CF(0, 0, 2.3), blue, M.SmoothPlastic)
	Build.block(st, V3(0.8, 0.4, 5.4), top * CF(-3.8, 0, 0), blue, M.SmoothPlastic)
	Build.block(st, V3(0.8, 0.4, 5.4), top * CF(3.8, 0, 0), blue, M.SmoothPlastic)
	local water = Build.block(st, V3(6.8, 0.2, 3.8), top * CF(0, -0.15, 0), RGB(110, 210, 255), M.Glass, "Water")
	water.Transparency = 0.25
	-- foam blobs
	for i = 1, 6 do
		Build.ball(
			st,
			rng:NextNumber(0.6, 1.1),
			top * CF(rng:NextNumber(-3, 3), 0, rng:NextNumber(-1.5, 1.5)),
			RGB(255, 255, 255),
			M.SmoothPlastic
		)
	end
	-- spot where the scrap sits while being cleaned
	local spot = Build.part(st, "Part", {
		Name = "ItemSpot",
		Size = V3(1, 1, 1),
		CFrame = top * CF(0, 2.2, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "Bubbles"
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(RGB(200, 240, 255), RGB(255, 200, 255))
	bubbles.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 0) })
	bubbles.Transparency = NumberSequence.new(0.2)
	bubbles.Lifetime = NumberRange.new(1, 2)
	bubbles.Rate = 30
	bubbles.Speed = NumberRange.new(2, 4)
	bubbles.SpreadAngle = Vector2.new(60, 60)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.LightEmission = 0.4
	bubbles.Enabled = false
	bubbles.Parent = spot
	local sparkle = bubbles:Clone()
	sparkle.Name = "Sparkle"
	sparkle.Color = ColorSequence.new(RGB(255, 240, 120))
	sparkle.Rate = 0
	sparkle.Speed = NumberRange.new(6, 12)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Parent = spot
	-- backsplash + faucet
	Build.block(st, V3(8.4, 6, 0.6), cf * CF(0, 6.4, 2.8), RGB(190, 230, 255), M.CeramicTiles)
	Build.block(st, V3(8.6, 0.5, 1.6), cf * CF(0, 9.4, 2.4), blue, M.SmoothPlastic)
	local faucet = cf * CF(0, 6.2, 2.3)
	Build.cylZ(st, 1.4, 0.5, faucet, C.Chrome, M.Metal)
	Build.cylY(st, 1.6, 0.45, faucet * CF(0, 0.8, -0.7), C.Chrome, M.Metal)
	Build.cylZ(st, 1.6, 0.42, faucet * CF(0, 1.55, -1.4), C.Chrome, M.Metal)
	Build.cylY(st, 0.6, 0.6, faucet * CF(0, 1.2, -2.2), C.Chrome, M.Metal)
	for _, x in ipairs({ -1, 1 }) do
		Build.cylY(st, 0.5, 0.5, faucet * CF(x * 1.2, 0.4, 0), x < 0 and C.Red or blue, M.SmoothPlastic)
	end
	local nozzle = Build.part(st, "Part", {
		Name = "Nozzle",
		Size = V3(0.4, 0.4, 0.4),
		CFrame = faucet * CF(0, 0.85, -2.2),
		Transparency = 1,
		CanCollide = false,
	})
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spray.Color = ColorSequence.new(RGB(150, 220, 255))
	spray.Size = NumberSequence.new(0.25)
	spray.Lifetime = NumberRange.new(0.3, 0.5)
	spray.Rate = 60
	spray.Speed = NumberRange.new(6, 8)
	spray.SpreadAngle = Vector2.new(8, 8)
	spray.EmissionDirection = Enum.NormalId.Bottom
	spray.Acceleration = V3(0, -20, 0)
	spray.Enabled = false
	spray.Parent = nozzle
	-- shelf with soaps / brushes
	local shelf = cf * CF(0, 8.0, 2.2)
	Build.block(st, V3(7, 0.25, 1.0), shelf, RGB(150, 100, 60), M.Wood)
	for i, col in ipairs({ RGB(255, 90, 200), RGB(90, 220, 255), RGB(255, 220, 60), RGB(120, 255, 120) }) do
		local x = -3 + i * 1.2
		Build.block(st, V3(0.7, 1.1, 0.6), shelf * CF(x, 0.68, 0), col, M.SmoothPlastic)
		Build.cylY(st, 0.25, 0.3, shelf * CF(x, 1.35, 0), C.White)
	end
	Build.block(st, V3(1.2, 0.3, 0.5), shelf * CF(2.8, 0.3, 0), RGB(255, 130, 60))
	Build.block(st, V3(1.1, 0.2, 0.4), shelf * CF(2.8, 0.55, 0), RGB(250, 250, 240), M.Fabric)
	-- pressure washer cart beside the cabinet
	local pw = cf * CF(5.6, 0, 0.5)
	Build.block(st, V3(2.6, 2.4, 3.2), pw * CF(0, 2.0, 0), RGB(255, 200, 40), M.SmoothPlastic)
	Build.block(st, V3(2.7, 0.4, 3.3), pw * CF(0, 3.3, 0), RGB(40, 40, 46), M.SmoothPlastic)
	Build.cylX(st, 0.5, 1.4, pw * CF(1.3, 0.7, 1.1), C.Rubber, M.Rubber)
	Build.cylX(st, 0.5, 1.4, pw * CF(-1.3, 0.7, 1.1), C.Rubber, M.Rubber)
	Build.cylY(st, 1.6, 0.25, pw * CF(0, 4.1, 1.2), C.Chrome, M.Metal)
	Build.torus(st, pw * CF(0, 2.0, -1.65) * ANG(rad(90), 0, 0), 0.7, 0.12, 12, C.Black, M.Rubber)
	-- number sign
	local numberSign = Build.block(st, V3(2.6, 2.2, 0.4), cf * CF(0, 11.2, 2.6), RGB(255, 200, 60), M.SmoothPlastic)
	Build.sign(numberSign, Enum.NormalId.Front, tostring(index), C.White, RGB(150, 90, 20))
	-- status light (server recolours: green = free, red = busy)
	local status = Build.ball(st, 0.9, cf * CF(3.6, 9.9, 2.4), RGB(90, 255, 120), M.Neon)
	status.Name = "StatusLight"
	collide(st)
	-- prompt
	local pp = promptPart(st, cf * CF(0, 3, -3.4), V3(6, 3, 1))
	local p = prompt(pp, "Clean Scrap", "Wash Station " .. index, nil)
	p.Name = "CleanPrompt"
	p:SetAttribute("StationId", index)
	st.PrimaryPart = spot
	return st
end

local function buildCleaningShed(hub: Instance)
	local shed = newModel("CleaningShed", hub)
	local x0 = -62
	-- floor
	Build.block(shed, V3(24, 0.6, 78), CF(x0, 0.3, -10), RGB(180, 230, 255), M.CeramicTiles)
	-- back wall
	Build.block(shed, V3(1.4, 20, 78), CF(x0 - 11.5, 10, -10), RGB(90, 170, 240), M.SmoothPlastic)
	for z = -46, 26, 8 do
		Build.block(shed, V3(1.6, 20, 0.8), CF(x0 - 11.4, 10, z), RGB(70, 140, 210), M.SmoothPlastic)
	end
	-- side walls
	for _, z in ipairs({ -49, 29 }) do
		Build.block(shed, V3(24, 20, 1.4), CF(x0, 10, z), RGB(90, 170, 240), M.SmoothPlastic)
	end
	-- pillars
	for z = -48, 28, 19 do
		Build.block(shed, V3(1.6, 20, 1.6), CF(x0 + 11.2, 10, z), RGB(255, 255, 255), M.SmoothPlastic)
	end
	-- slanted roof with corrugation stripes
	local roof = CF(x0, 21.6, -10) * ANG(0, 0, rad(-8))
	Build.block(shed, V3(28, 1, 82), roof, RGB(70, 200, 230), M.Metal)
	for i = 0, 19 do
		Build.block(
			shed,
			V3(28.2, 1.15, 1.2),
			roof * CF(0, 0, -39 + i * 4.1),
			(i % 2 == 0) and RGB(255, 255, 255) or RGB(110, 220, 240),
			M.Metal
		)
	end
	collide(shed)
	-- sign on front fascia
	bigSign(
		shed,
		CF(x0 + 13, 19, -10) * ANG(0, math.rad(90), 0) * ANG(0, math.pi, 0),
		V3(30, 5.5, 1),
		"🫧 WASH STATION 🫧",
		RGB(60, 160, 255)
	)
	-- stations face east (toward the plaza)
	local zs = { -36, -19, -2, 15 }
	for i, z in ipairs(zs) do
		local pos = V3(x0 - 4, 0.6, z)
		local cf = CFrame.lookAt(pos, pos + V3(1, 0, 0))
		WorldBuilder.Stations[i] = buildStation(shed, i, cf)
	end
	-- soap bubbles drifting from the roof
	local fxPart = Build.part(
		shed,
		"Part",
		{ Name = "FX", Size = V3(20, 1, 70), CFrame = CF(x0, 18, -10), Transparency = 1, CanCollide = false, CanQuery = false }
	)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(RGB(220, 245, 255), RGB(255, 210, 255))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.2) })
	e.Transparency = NumberSequence.new(0.4, 1)
	e.Lifetime = NumberRange.new(4, 6)
	e.Rate = 6
	e.Speed = NumberRange.new(0.5, 1.5)
	e.Acceleration = V3(0, -0.6, 0)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = fxPart
end

-- Friendly blocky shopkeeper NPC.
local function buildNPC(parent: Instance, cf: CFrame, shirt: Color3, hat: Color3): Model
	local npc = newModel("Shopkeeper", parent)
	local skin = RGB(255, 210, 160)
	Build.block(npc, V3(2, 2, 1), cf * CF(0, 3, 0), shirt, M.SmoothPlastic)
	Build.block(npc, V3(1.6, 1.4, 0.2), cf * CF(0, 3.2, -0.55), RGB(70, 110, 200), M.Fabric)
	for _, x in ipairs({ -0.5, 0.5 }) do
		Build.block(npc, V3(1, 2, 1), cf * CF(x, 1, 0), RGB(70, 110, 200), M.Fabric)
		Build.block(npc, V3(1.02, 0.4, 1.1), cf * CF(x, 0.2, -0.05), RGB(60, 40, 30), M.Leather)
	end
	Build.block(npc, V3(1, 2, 1), cf * CF(-1.5, 3, 0) * ANG(rad(10), 0, 0), skin)
	Build.block(npc, V3(1, 2, 1), cf * CF(1.5, 3.2, -0.4) * ANG(rad(50), 0, rad(-10)), skin)
	local head = Build.cylY(npc, 1.2, 1.25, cf * CF(0, 4.6, 0), skin)
	head.Size = V3(1.2, 1.25, 1.25)
	Build.block(npc, V3(1.0, 1.0, 1.0), cf * CF(0, 4.6, 0), skin)
	for _, x in ipairs({ -0.25, 0.25 }) do
		Build.block(npc, V3(0.16, 0.24, 0.05), cf * CF(x, 4.75, -0.52), RGB(20, 20, 20))
	end
	Build.block(npc, V3(0.5, 0.08, 0.05), cf * CF(0, 4.35, -0.52), RGB(120, 40, 40))
	Build.block(npc, V3(0.12, 0.12, 0.05), cf * CF(-0.28, 4.4, -0.52), RGB(120, 40, 40))
	Build.block(npc, V3(0.12, 0.12, 0.05), cf * CF(0.28, 4.4, -0.52), RGB(120, 40, 40))
	-- hard hat
	Build.cylY(npc, 0.6, 1.5, cf * CF(0, 5.4, 0), hat, M.SmoothPlastic)
	Build.cylY(npc, 0.12, 1.9, cf * CF(0, 5.15, -0.1), hat, M.SmoothPlastic)
	Build.block(npc, V3(0.2, 0.62, 1.52), cf * CF(0, 5.42, 0), hat:Lerp(Color3.new(1, 1, 1), 0.3), M.SmoothPlastic)
	collide(npc)
	return npc
end

local function buildSellShop(hub: Instance)
	local shop = newModel("ScrapExchange", hub)
	local x0 = 62
	local green = RGB(70, 210, 110)
	Build.block(shop, V3(24, 0.6, 78), CF(x0, 0.3, -10), RGB(240, 230, 200), M.WoodPlanks)
	Build.block(shop, V3(1.4, 20, 78), CF(x0 + 11.5, 10, -10), green, M.SmoothPlastic)
	for z = -46, 26, 8 do
		Build.block(shop, V3(1.6, 20, 0.8), CF(x0 + 11.4, 10, z), RGB(50, 170, 90), M.SmoothPlastic)
	end
	for _, z in ipairs({ -49, 29 }) do
		Build.block(shop, V3(24, 20, 1.4), CF(x0, 10, z), green, M.SmoothPlastic)
	end
	for z = -48, 28, 19 do
		Build.block(shop, V3(1.6, 20, 1.6), CF(x0 - 11.2, 10, z), C.White, M.SmoothPlastic)
	end
	local roof = CF(x0, 21.6, -10) * ANG(0, 0, rad(8))
	Build.block(shop, V3(28, 1, 82), roof, RGB(255, 210, 60), M.Metal)
	for i = 0, 19 do
		Build.block(
			shop,
			V3(28.2, 1.15, 1.2),
			roof * CF(0, 0, -39 + i * 4.1),
			(i % 2 == 0) and RGB(255, 255, 255) or RGB(255, 225, 110),
			M.Metal
		)
	end
	-- counter
	Build.block(shop, V3(3, 4, 40), CF(x0 + 2, 2, -10), RGB(170, 110, 60), M.Wood)
	Build.block(shop, V3(3.6, 0.5, 40.6), CF(x0 + 2, 4.25, -10), RGB(250, 240, 220), M.Marble)
	for z = -28, 8, 6 do
		Build.block(shop, V3(0.2, 3, 4), CF(x0 + 0.45, 2, z), RGB(140, 90, 50), M.Wood)
	end
	-- cash register
	local reg = CF(x0 + 2, 4.5, -2)
	Build.block(shop, V3(2, 1.2, 2.4), reg * CF(0, 0.6, 0), RGB(60, 64, 76), M.Metal)
	Build.wedge(shop, V3(2, 0.8, 1.4), reg * CF(0, 1.6, 0.4) * ANG(0, math.pi, 0), RGB(60, 64, 76), M.Metal)
	Build.block(shop, V3(0.1, 0.5, 1.4), reg * CF(-1.05, 1.5, 0), RGB(90, 255, 140), M.Neon)
	-- big scale
	local scale = CF(x0 - 3, 0.6, -40)
	Build.block(shop, V3(8, 0.8, 8), scale * CF(0, 0.4, 0), RGB(80, 84, 96), M.DiamondPlate)
	Build.block(shop, V3(1, 9, 1), scale * CF(0, 5, 3.6), RGB(80, 84, 96), M.Metal)
	local dial = scale * CF(0, 10, 3.6)
	Build.cylZ(shop, 0.8, 5, dial, RGB(255, 255, 255), M.SmoothPlastic)
	Build.torus(shop, dial * ANG(rad(90), 0, 0), 2.5, 0.25, 20, RGB(255, 200, 60), M.Metal)
	Build.block(shop, V3(0.2, 2.0, 0.1), dial * CF(0.5, 0.4, -0.45) * ANG(0, 0, rad(-30)), C.Red)
	collide(shop)
	-- NPC behind the counter
	buildNPC(shop, CFrame.lookAt(V3(x0 + 5.5, 0.6, -10), V3(x0 - 10, 0.6, -10)), RGB(255, 200, 60), RGB(255, 200, 40))
	-- sign
	bigSign(
		shop,
		CF(x0 - 13, 19, -10) * ANG(0, math.rad(-90), 0) * ANG(0, math.pi, 0),
		V3(30, 5.5, 1),
		"💰 SELL SCRAP 💰",
		RGB(50, 190, 90)
	)
	-- glowing sell pad on the floor in front of the counter
	local pad = Build.cylY(shop, 0.4, 14, CF(x0 - 5, 0.8, -10), RGB(90, 255, 130), M.Neon)
	pad.Name = "SellPad"
	pad.CanCollide = false
	pad.CanTouch = true
	pad.Transparency = 0.25
	Build.torus(shop, CF(x0 - 5, 0.9, -10), 7, 0.4, 24, RGB(255, 255, 255), M.SmoothPlastic)
	local padSign = Build.part(
		shop,
		"Part",
		{ Name = "PadText", Size = V3(10, 4, 0.2), CFrame = CF(x0 - 5, 5, -10) * ANG(0, rad(-90), 0), Transparency = 1, CanCollide = false }
	)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(12, 3)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.Parent = padSign
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Font = Enum.Font.FredokaOne
	tl.Text = "SELL HERE"
	tl.TextScaled = true
	tl.TextColor3 = RGB(120, 255, 150)
	tl.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = RGB(20, 80, 30)
	st.Parent = tl
	local coins = Instance.new("ParticleEmitter")
	coins.Name = "CoinFX"
	coins.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	coins.Color = ColorSequence.new(RGB(255, 220, 60))
	coins.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	coins.Lifetime = NumberRange.new(0.8, 1.4)
	coins.Rate = 0
	coins.Speed = NumberRange.new(14, 22)
	coins.SpreadAngle = Vector2.new(35, 35)
	coins.EmissionDirection = Enum.NormalId.Top
	coins.Acceleration = V3(0, -40, 0)
	coins.LightEmission = 1
	coins.Parent = pad
	local pp = promptPart(shop, CF(x0, 4.5, -10), V3(1, 3, 10))
	prompt(pp, "Sell Scrap", "Scrap Exchange", "Sell")
end

local function buildToolShop(hub: Instance)
	local shop = newModel("ToolShop", hub)
	local o = CF(-40, 0, -78)
	local red = RGB(235, 70, 70)
	Build.block(shop, V3(30, 0.6, 16), o * CF(0, 0.3, 0), RGB(200, 160, 110), M.WoodPlanks)
	-- pegboard back wall with tools on display
	Build.block(shop, V3(30, 16, 1), o * CF(0, 8.5, -7.5), RGB(214, 170, 120), M.WoodPlanks)
	Build.block(shop, V3(26, 10, 0.3), o * CF(0, 9, -6.85), RGB(240, 210, 160), M.Cardboard)
	for i, toolId in ipairs(Config.ToolOrder) do
		local tm, handle = ToolModels.create(toolId)
		local x = -11 + (i - 1) * 4.4
		local target = o * CF(x, 8, -6.2) * ANG(0, 0, rad(-12))
		local offset = handle.CFrame
		for _, d in ipairs(tm:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CFrame = target * offset:Inverse() * d.CFrame
				d.Anchored = true
				d.CanCollide = false
			end
		end
		tm.Parent = shop
		local tag = Build.block(shop, V3(3.2, 0.8, 0.2), o * CF(x, 4.6, -6.6), Config.Tools[toolId].Color, M.SmoothPlastic)
		Build.sign(tag, Enum.NormalId.Front, Format.cash(Config.Tools[toolId].Price), C.White, RGB(30, 30, 30))
	end
	-- counter
	Build.block(shop, V3(22, 4, 3), o * CF(0, 2, 3), red, M.SmoothPlastic)
	Build.block(shop, V3(22.6, 0.5, 3.6), o * CF(0, 4.25, 3), RGB(250, 245, 235), M.Marble)
	-- striped awning
	for i = 0, 9 do
		local col = (i % 2 == 0) and red or C.White
		Build.wedge(shop, V3(3.1, 3, 8), o * CF(-13.5 + i * 3, 15.5, 2) * ANG(0, math.pi, 0), col, M.Fabric)
	end
	for _, x in ipairs({ -14.4, 14.4 }) do
		Build.block(shop, V3(1, 16, 1), o * CF(x, 8, 5.5), RGB(120, 80, 50), M.Wood)
	end
	collide(shop)
	buildNPC(shop, o * CF(4, 0.6, -2) * ANG(0, math.pi, 0), RGB(235, 70, 70), RGB(60, 60, 70))
	bigSign(shop, o * CF(0, 19, 5) * ANG(0, math.pi, 0), V3(20, 5, 1), "🔧 TOOL SHOP", RGB(230, 70, 70))
	local pp = promptPart(shop, o * CF(0, 3, 5), V3(16, 3, 1))
	prompt(pp, "Browse Tools", "Tool Shop", "Tools")
end

local function buildUpgradeLab(hub: Instance)
	local lab = newModel("UpgradeLab", hub)
	local o = CF(40, 0, -78)
	local purple = RGB(150, 90, 255)
	Build.block(lab, V3(30, 0.6, 16), o * CF(0, 0.3, 0), RGB(60, 50, 90), M.DiamondPlate)
	Build.block(lab, V3(30, 16, 1), o * CF(0, 8.5, -7.5), RGB(80, 60, 140), M.SmoothPlastic)
	for i = 0, 4 do
		Build.block(lab, V3(0.4, 14, 0.4), o * CF(-12 + i * 6, 8.5, -6.9), RGB(120, 230, 255), M.Neon)
	end
	-- holographic arrow
	local arrow = o * CF(0, 9, -5.5)
	Build.block(lab, V3(2.4, 5, 0.4), arrow * CF(0, -1.5, 0), RGB(90, 255, 140), M.Neon).Transparency = 0.2
	Build.wedge(lab, V3(0.4, 3, 2.6), arrow * CF(1.3, 2.5, 0) * ANG(0, rad(90), 0), RGB(90, 255, 140), M.Neon).Transparency = 0.2
	Build.wedge(lab, V3(0.4, 3, 2.6), arrow * CF(-1.3, 2.5, 0) * ANG(0, rad(-90), 0), RGB(90, 255, 140), M.Neon).Transparency = 0.2
	-- tech consoles
	for _, x in ipairs({ -9, 9 }) do
		local con = o * CF(x, 0, 0)
		Build.block(lab, V3(5, 4, 3), con * CF(0, 2.6, 0), RGB(70, 70, 90), M.Metal)
		Build.wedge(lab, V3(5, 1.6, 3), con * CF(0, 5.4, 0) * ANG(0, math.pi, 0), RGB(70, 70, 90), M.Metal)
		Build.block(lab, V3(4, 0.1, 2), con * CF(0, 5.5, 0.1) * ANG(rad(-28), 0, 0), RGB(120, 230, 255), M.Neon)
		for i = 0, 2 do
			Build.cylY(lab, 0.3, 0.5, con * CF(-1.4 + i * 1.4, 4.7, -1.2), ({ C.Red, C.Yellow, RGB(80, 255, 120) })[i + 1], M.Neon)
		end
	end
	-- counter
	Build.block(lab, V3(12, 4, 3), o * CF(0, 2, 3), purple, M.SmoothPlastic)
	Build.block(lab, V3(12.6, 0.5, 3.6), o * CF(0, 4.25, 3), RGB(230, 230, 250), M.Marble)
	for _, x in ipairs({ -14.4, 14.4 }) do
		Build.block(lab, V3(1, 16, 1), o * CF(x, 8, 5.5), RGB(60, 60, 80), M.Metal)
	end
	Build.block(lab, V3(30, 1, 12), o * CF(0, 16.5, 0), RGB(80, 60, 140), M.Metal)
	collide(lab)
	buildNPC(lab, o * CF(0, 0.6, -1) * ANG(0, math.pi, 0), RGB(240, 240, 255), RGB(150, 90, 255))
	bigSign(lab, o * CF(0, 19, 5) * ANG(0, math.pi, 0), V3(20, 5, 1), "⬆️ UPGRADES", purple)
	local pp = promptPart(lab, o * CF(0, 3, 5), V3(12, 3, 1))
	prompt(pp, "Buy Upgrades", "Upgrade Lab", "Upgrades")
end

local function buildMachineBay(hub: Instance)
	local bay = newModel("MachineBay", hub)
	local slots = {
		{ Id = "AutoWasher", X = -70 },
		{ Id = "MagnetCrane", X = -48 },
		{ Id = "RarityRadar", X = -26 },
		{ Id = "AutoSeller", X = 26 },
		{ Id = "PolishLab", X = 48 },
		{ Id = "Teleporter", X = 70 },
	}
	for _, s in ipairs(slots) do
		local o = CF(s.X, 0.6, 48)
		local pad = newModel("Pad_" .. s.Id, bay)
		Build.block(pad, V3(19, 0.8, 19), o * CF(0, 0, 0), RGB(70, 74, 86), M.DiamondPlate)
		for i = 0, 11 do
			local col = (i % 2 == 0) and RGB(255, 200, 40) or RGB(30, 30, 34)
			Build.block(pad, V3(1.6, 0.85, 0.8), o * CF(-8.8 + i * 1.6, 0.05, -9.4), col, M.SmoothPlastic)
			Build.block(pad, V3(1.6, 0.85, 0.8), o * CF(-8.8 + i * 1.6, 0.05, 9.4), col, M.SmoothPlastic)
		end
		collide(pad)
		local machine = MachineModels.create(s.Id, pad, o * CF(0, 0.4, 2))
		machine.Name = "Machine"
		pad:SetAttribute("MachineId", s.Id)
		local info = Build.part(pad, "Part", {
			Name = "InfoAnchor",
			Size = V3(1, 1, 1),
			CFrame = o * CF(0, 17, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local _ = info
		local pp = promptPart(pad, o * CF(0, 3, -9), V3(10, 3, 1))
		if s.Id == "Teleporter" then
			prompt(pp, "Teleport", "Zone Teleporter", "Zones")
		else
			local def = Config.Machines[s.Id]
			local p = prompt(pp, "View Machine", def.Name, "Machines")
			p:SetAttribute("MachineId", s.Id)
		end
	end
end

----------------------------------------------------------------------
-- Perimeter, zone walls and gates
----------------------------------------------------------------------
local function buildPerimeter(map: Instance)
	local walls = newModel("Perimeter", map)
	local colors = { RGB(80, 150, 230), RGB(230, 90, 90), RGB(240, 180, 50), RGB(90, 190, 110) }
	local idx = 0
	local function run(a: Vector3, b: Vector3)
		local len = (b - a).Magnitude
		local n = math.ceil(len / 40)
		local dir = (b - a).Unit
		for i = 0, n - 1 do
			idx += 1
			local p0 = a + dir * (i * len / n)
			local p1 = a + dir * ((i + 1) * len / n)
			local mid = (p0 + p1) / 2
			Props.fencePanel(walls, CFrame.lookAt(mid, mid + dir) * ANG(0, rad(90), 0), len / n, 16, colors[(idx % #colors) + 1])
		end
	end
	run(V3(-132, 0, -100), V3(-132, 0, 852))
	run(V3(132, 0, -100), V3(132, 0, 852))
	run(V3(-132, 0, -100), V3(132, 0, -100))
	run(V3(-132, 0, 852), V3(132, 0, 852))
	-- hub side walls (between hub and the outer verge)
	for _, x in ipairs({ -96, 96 }) do
		for z = -86, 60, 24 do
			Props.junkPile(walls, CF(x + rng:NextNumber(-6, 6), 0, z), rng:NextNumber(7, 10))
		end
	end
end

local function buildGate(map: Instance, zoneId: string, z: number)
	local def = Config.Zones[zoneId]
	local gate = newModel("Gate_" .. zoneId, map)
	gate:SetAttribute("ZoneId", zoneId)
	local wallColor = RGB(90, 94, 108)
	-- walls either side
	for _, side in ipairs({ -1, 1 }) do
		local x0, x1 = side * 16, side * 132
		local len = math.abs(x1 - x0)
		local n = math.ceil(len / 38)
		for i = 0, n - 1 do
			local xa = x0 + (x1 - x0) * (i / n)
			local xb = x0 + (x1 - x0) * ((i + 1) / n)
			Props.fencePanel(gate, CF((xa + xb) / 2, 0, z), math.abs(xb - xa), 16, wallColor)
		end
	end
	-- gate frame
	for _, x in ipairs({ -16, 16 }) do
		Build.block(gate, V3(5, 26, 5), CF(x, 13, z), RGB(60, 62, 72), M.Metal)
		Build.block(gate, V3(5.6, 1.2, 5.6), CF(x, 26.4, z), def.Color, M.SmoothPlastic)
		for i = 0, 4 do
			Build.block(gate, V3(5.1, 1, 5.1), CF(x, 3 + i * 5, z) * ANG(0, 0, rad(30)), RGB(255, 200, 40), M.SmoothPlastic)
		end
	end
	Build.block(gate, V3(38, 4, 5), CF(0, 24, z), RGB(60, 62, 72), M.Metal)
	collide(gate)
	local sign = bigSign(gate, CF(0, 30, z) * ANG(0, math.pi, 0), V3(30, 6, 1), def.Emoji .. " " .. string.upper(def.Name), def.Color)
	local _ = sign
	-- energy barrier (client hides it once unlocked)
	local barrier = Build.part(gate, "Part", {
		Name = "Barrier",
		Size = V3(27, 22, 1.4),
		CFrame = CF(0, 11, z),
		Color = def.Color,
		Material = M.ForceField,
		Transparency = 0,
		CanCollide = true,
		CanQuery = true,
	})
	barrier:SetAttribute("ZoneId", zoneId)
	local bb = Instance.new("BillboardGui")
	bb.Name = "PriceTag"
	bb.Size = UDim2.fromScale(16, 6)
	bb.StudsOffset = V3(0, 1, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 140
	bb.Parent = barrier
	local tl = Instance.new("TextLabel")
	tl.Name = "Label"
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Font = Enum.Font.FredokaOne
	tl.RichText = true
	tl.Text = string.format('🔒 %s\n<font color="#7CFF8C">%s</font>', def.Name, Format.cash(def.Price))
	tl.TextScaled = true
	tl.TextColor3 = C.White
	tl.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = RGB(20, 20, 30)
	st.Parent = tl
	local gp = prompt(barrier, "Unlock", def.Name .. " (" .. Format.cash(def.Price) .. ")", "Gate")
	gp.Name = "GatePrompt"
	gp:SetAttribute("ZoneId", zoneId)
	gp.MaxActivationDistance = 16
end

----------------------------------------------------------------------
-- Zone decoration
----------------------------------------------------------------------
local function scatter(count: number, zMin: number, zMax: number, fn: (CFrame) -> ())
	for _ = 1, count do
		local x
		repeat
			x = rng:NextNumber(-112, 112)
		until math.abs(x) > 18
		local z = rng:NextNumber(zMin, zMax)
		fn(CF(x, 0, z) * ANG(0, rng:NextNumber(0, math.pi * 2), 0))
	end
end

local function buildJunkyard(map: Instance)
	local zone = newModel("JunkFields", map)
	local def = Config.Zones.Junkyard
	scatter(7, def.ZMin + 10, def.ZMax - 10, function(cf)
		Props.carWreck(zone, cf)
	end)
	scatter(6, def.ZMin + 10, def.ZMax - 10, function(cf)
		Props.tireStack(zone, cf)
	end)
	scatter(10, def.ZMin + 5, def.ZMax - 5, function(cf)
		Props.barrel(zone, cf, nil, false, rng:NextNumber() > 0.6)
	end)
	scatter(6, def.ZMin + 10, def.ZMax - 10, function(cf)
		Props.crate(zone, cf, rng:NextNumber(3, 5))
	end)
	scatter(6, def.ZMin + 10, def.ZMax - 10, function(cf)
		Props.junkPile(zone, cf, rng:NextNumber(6, 10))
	end)
	scatter(10, def.ZMin, def.ZMax, function(cf)
		Props.cone(zone, cf)
	end)
	-- container stacks along the edges
	for _, p in ipairs({ { -100, 120 }, { 100, 170 }, { -100, 230 }, { 100, 100 } }) do
		local base = CF(p[1], 0, p[2]) * ANG(0, rad(90 + rng:NextNumber(-8, 8)), 0)
		Props.container(zone, base)
		Props.container(zone, base * CF(rng:NextNumber(-2, 2), 10, 0) * ANG(0, rad(rng:NextNumber(-6, 6)), 0))
	end
	-- crushed car towers
	for _, p in ipairs({ { -60, 260 }, { 60, 90 }, { 70, 250 } }) do
		for i = 0, 2 do
			Props.crushedCube(zone, CF(p[1], i * 5, p[2]) * ANG(0, rad(rng:NextNumber(-15, 15)), 0))
		end
	end
	Props.crane(zone, CF(-85, 0, 175) * ANG(0, rad(-30), 0))
	for z = def.ZMin + 20, def.ZMax - 10, 45 do
		Props.lamp(zone, CF(-16, 0, z))
		Props.lamp(zone, CF(16, 0, z + 22) * ANG(0, math.pi, 0))
	end
end

local function buildRustCanyon(map: Instance)
	local zone = newModel("RustCanyon", map)
	local def = Config.Zones.RustCanyon
	scatter(6, def.ZMin + 10, def.ZMax - 10, function(cf)
		Props.girders(zone, cf)
	end)
	scatter(5, def.ZMin + 10, def.ZMax - 10, function(cf)
		Props.carWreck(zone, cf, RGB(255, 140, 60))
	end)
	scatter(8, def.ZMin + 5, def.ZMax - 5, function(cf)
		Props.barrel(zone, cf, RGB(255, 120, 40), false, rng:NextNumber() > 0.5)
	end)
	scatter(5, def.ZMin + 10, def.ZMax - 10, function(cf)
		Props.junkPile(zone, cf, rng:NextNumber(6, 9))
	end)
	for _, p in ipairs({ { -95, 330 }, { 95, 380 }, { -95, 420 } }) do
		Props.container(zone, CF(p[1], 0, p[2]) * ANG(0, rad(90), 0) * ANG(0, 0, rad(rng:NextNumber(-3, 3))), RGB(255, 130, 50))
	end
	for z = def.ZMin + 20, def.ZMax - 10, 50 do
		Props.lamp(zone, CF(-16, 0, z), RGB(255, 190, 120))
		Props.lamp(zone, CF(16, 0, z + 25) * ANG(0, math.pi, 0), RGB(255, 190, 120))
	end
end

local function buildToxicWaste(map: Instance)
	local zone = newModel("ToxicWaste", map)
	local def = Config.Zones.ToxicWaste
	scatter(7, def.ZMin + 15, def.ZMax - 15, function(cf)
		Props.toxicPool(zone, cf, rng:NextNumber(6, 11))
	end)
	scatter(14, def.ZMin + 5, def.ZMax - 5, function(cf)
		Props.barrel(zone, cf, RGB(255, 210, 40), true, rng:NextNumber() > 0.5)
	end)
	scatter(9, def.ZMin + 5, def.ZMax - 5, function(cf)
		Props.deadTree(zone, cf)
	end)
	for _, p in ipairs({ { -98, 520 }, { 98, 600 } }) do
		Props.container(zone, CF(p[1], 0, p[2]) * ANG(0, rad(90), 0), RGB(90, 200, 70))
	end
	-- green fog in the wasteland
	local fogPart = Build.part(zone, "Part", {
		Name = "ToxicFog",
		Size = V3(230, 2, 160),
		CFrame = CF(0, 2, (def.ZMin + def.ZMax) / 2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local fog = Instance.new("ParticleEmitter")
	fog.Texture = "rbxasset://textures/particles/smoke_main.dds"
	fog.Color = ColorSequence.new(RGB(140, 255, 90))
	fog.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 12) })
	fog.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 1) })
	fog.Lifetime = NumberRange.new(6, 9)
	fog.Rate = 8
	fog.Speed = NumberRange.new(0.5, 1)
	fog.Shape = Enum.ParticleEmitterShape.Box
	fog.Parent = fogPart
	for z = def.ZMin + 20, def.ZMax - 10, 50 do
		Props.lamp(zone, CF(-16, 0, z), RGB(150, 255, 110))
		Props.lamp(zone, CF(16, 0, z + 25) * ANG(0, math.pi, 0), RGB(150, 255, 110))
	end
end

local function buildMeteorCrater(map: Instance)
	local zone = newModel("MeteorCrater", map)
	local def = Config.Zones.MeteorCrater
	local colors = { RGB(255, 90, 200), RGB(150, 110, 255), RGB(80, 220, 255) }
	scatter(14, def.ZMin + 10, def.ZMax - 10, function(cf)
		Props.crystals(zone, cf, colors[rng:NextInteger(1, 3)])
	end)
	-- the meteor itself
	local meteor = newModel("Meteor", zone)
	local center = CF(0, -2, 760)
	local rock = Build.ball(meteor, 22, center, RGB(60, 44, 70), M.Basalt)
	local _ = rock
	for _ = 1, 10 do
		local dir = rng:NextUnitVector()
		local p = center * CF(dir * 10.5)
		Build.block(
			meteor,
			V3(rng:NextNumber(4, 8), 0.5, 0.6),
			CFrame.lookAt(p.Position, p.Position + dir) * ANG(0, 0, rng:NextNumber(0, 3)),
			RGB(255, 90, 200),
			M.Neon
		)
	end
	Build.light(rock, RGB(255, 90, 200), 40, 3)
	collide(meteor)
	for z = def.ZMin + 15, def.ZMax - 10, 50 do
		Props.lamp(zone, CF(-40, 0, z), RGB(200, 140, 255))
		Props.lamp(zone, CF(40, 0, z + 25) * ANG(0, math.pi, 0), RGB(200, 140, 255))
	end
end

----------------------------------------------------------------------
function WorldBuilder.build()
	setupLighting()
	setupTerrain()

	root = folder("Scrapyard", workspace)
	local hub = folder("Hub", root)
	buildPlaza(hub)
	buildCleaningShed(hub)
	buildSellShop(hub)
	buildToolShop(hub)
	buildUpgradeLab(hub)
	buildMachineBay(hub)
	buildArch(hub, 72, "♻️ SCRAPYARD SIMULATOR ♻️", RGB(255, 140, 40))

	buildPerimeter(root)
	buildJunkyard(root)
	buildRustCanyon(root)
	buildToxicWaste(root)
	buildMeteorCrater(root)

	buildGate(root, "RustCanyon", 280)
	buildGate(root, "ToxicWaste", 470)
	buildGate(root, "MeteorCrater", 660)

	for _, id in ipairs(Config.ZoneOrder) do
		local def = Config.Zones[id]
		WorldBuilder.ZoneSpawns[id] = CF(0, 4, def.ZMin + 6)
	end

	local scraps = folder("Scraps", workspace)
	local _ = scraps
	return root
end

return WorldBuilder
