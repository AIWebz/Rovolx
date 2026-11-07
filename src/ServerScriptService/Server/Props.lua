-- Props: detailed decorative models for the scrapyard map.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(ReplicatedStorage.Shared.Build)

local C = Build.Colors
local M = Enum.Material
local rad = math.rad
local CF = CFrame.new
local ANG = CFrame.Angles
local V3 = Vector3.new
local RGB = Color3.fromRGB

local Props = {}

local rng = Random.new(1337)

local BRIGHT = {
	RGB(255, 90, 90),
	RGB(255, 170, 50),
	RGB(255, 220, 60),
	RGB(90, 210, 110),
	RGB(70, 170, 255),
	RGB(150, 110, 255),
	RGB(255, 110, 200),
	RGB(60, 210, 210),
}

function Props.randomBright(): Color3
	return BRIGHT[rng:NextInteger(1, #BRIGHT)]
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function collide(m: Model)
	Build.setAll(m, { CanCollide = true })
end

----------------------------------------------------------------------
-- Shipping container with ribbed walls and doors.
----------------------------------------------------------------------
function Props.container(parent: Instance, cf: CFrame, color: Color3?): Model
	local m = model(parent, "Container")
	local col = color or Props.randomBright()
	local dark = col:Lerp(Color3.new(0, 0, 0), 0.25)
	local L, H, W = 24, 10, 9.6
	Build.block(m, V3(L, H, W), cf * CF(0, H / 2, 0), col, M.Metal)
	-- ribs
	for i = 0, 15 do
		local x = -L / 2 + 0.9 + i * ((L - 1.8) / 15)
		Build.block(m, V3(0.5, H - 0.8, W + 0.3), cf * CF(x, H / 2, 0), dark, M.Metal)
	end
	-- top / bottom rails
	Build.block(m, V3(L + 0.2, 0.6, W + 0.4), cf * CF(0, H - 0.3, 0), dark, M.Metal)
	Build.block(m, V3(L + 0.2, 0.6, W + 0.4), cf * CF(0, 0.3, 0), dark, M.Metal)
	-- doors
	local door = cf * CF(L / 2 + 0.1, H / 2, 0)
	Build.block(m, V3(0.3, H - 1.2, W - 0.6), door, dark, M.Metal)
	for _, z in ipairs({ -2.6, -1.2, 1.2, 2.6 }) do
		Build.cylY(m, H - 1.6, 0.25, door * CF(0.3, 0, z), C.Steel, M.Metal)
	end
	Build.block(m, V3(0.1, H - 1.2, 0.12), door * CF(0.2, 0, 0), RGB(20, 20, 24))
	-- corner castings
	for _, x in ipairs({ -L / 2, L / 2 }) do
		for _, y in ipairs({ 0.5, H - 0.5 }) do
			for _, z in ipairs({ -W / 2, W / 2 }) do
				Build.block(m, V3(1, 1, 1), cf * CF(x, y, z), RGB(60, 60, 64), M.Metal)
			end
		end
	end
	-- logo stripe
	local stripe = Build.block(m, V3(10, 2.4, 0.2), cf * CF(-2, H * 0.62, -W / 2 - 0.2), C.White, M.SmoothPlastic)
	Build.sign(stripe, Enum.NormalId.Front, "SCRAPCO", col, RGB(30, 30, 30))
	collide(m)
	return m
end

----------------------------------------------------------------------
-- Oil drum. `toxic` makes it leak glowing goo.
----------------------------------------------------------------------
function Props.barrel(parent: Instance, cf: CFrame, color: Color3?, toxic: boolean?, tipped: boolean?): Model
	local m = model(parent, "Barrel")
	local col = color or Props.randomBright()
	local base = cf
	if tipped then
		base = cf * CF(0, 1.5, 0) * ANG(0, 0, rad(90)) * CF(0, -1.5, 0) * CF(-1.5, 0, 0)
	end
	local body = base * CF(0, 1.9, 0)
	Build.cylY(m, 3.8, 2.6, body, col, M.Metal)
	for _, y in ipairs({ -1.85, -0.65, 0.65, 1.85 }) do
		Build.cylY(m, 0.18, 2.72, body * CF(0, y, 0), col:Lerp(Color3.new(0, 0, 0), 0.3), M.Metal)
	end
	Build.cylY(m, 0.08, 2.4, body * CF(0, 1.92, 0), col:Lerp(Color3.new(1, 1, 1), 0.2), M.Metal)
	Build.cylY(m, 0.2, 0.4, body * CF(0.7, 1.98, 0), C.DarkSteel, M.Metal)
	if toxic then
		local label = Build.block(m, V3(0.1, 1.0, 1.0), body * CF(1.31, 0, 0), RGB(255, 220, 40))
		Build.sign(label, Enum.NormalId.Right, "☢", RGB(20, 20, 20), RGB(255, 220, 40))
		local goo = Build.cylY(m, 0.2, 3.6, (tipped and base or cf) * CF(2.4, 0.1, 0), RGB(120, 255, 60), M.Neon)
		goo.Transparency = 0.15
		Build.light(goo, RGB(120, 255, 60), 10, 1.5)
	end
	collide(m)
	return m
end

----------------------------------------------------------------------
-- Wooden crate with plank frame.
----------------------------------------------------------------------
function Props.crate(parent: Instance, cf: CFrame, size: number?): Model
	local m = model(parent, "Crate")
	local s = size or 4
	local wood = RGB(196, 140, 80)
	local frame = RGB(150, 98, 52)
	local c = cf * CF(0, s / 2, 0)
	Build.block(m, V3(s, s, s), c, wood, M.WoodPlanks)
	local t = s * 0.12
	for _, a in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		Build.block(m, V3(t, s + 0.05, t), c * CF(a[1] * (s / 2 - t / 2 + 0.02), 0, a[2] * (s / 2 - t / 2 + 0.02)), frame, M.Wood)
		Build.block(m, V3(s + 0.05, t, t), c * CF(0, a[1] * (s / 2 - t / 2 + 0.02), a[2] * (s / 2 - t / 2 + 0.02)), frame, M.Wood)
		Build.block(m, V3(t, t, s + 0.05), c * CF(a[1] * (s / 2 - t / 2 + 0.02), a[2] * (s / 2 - t / 2 + 0.02), 0), frame, M.Wood)
	end
	-- diagonal braces
	for _, z in ipairs({ -1, 1 }) do
		Build.block(m, V3(s * 1.25, t, t * 0.6), c * CF(0, 0, z * (s / 2 + 0.03)) * ANG(0, 0, rad(45)), frame, M.Wood)
	end
	collide(m)
	return m
end

----------------------------------------------------------------------
-- Stack of tyres.
----------------------------------------------------------------------
function Props.tireStack(parent: Instance, cf: CFrame, count: number?): Model
	local m = model(parent, "Tires")
	local n = count or rng:NextInteger(2, 5)
	for i = 0, n - 1 do
		local t = cf * CF(rng:NextNumber(-0.25, 0.25), 0.75 + i * 1.35, rng:NextNumber(-0.25, 0.25)) * ANG(0, rng:NextNumber(0, 6.28), 0)
		Build.torus(m, t, 1.6, 0.68, 14, C.Rubber, M.Rubber)
		Build.cylY(m, 1.1, 2.2, t, RGB(28, 28, 30), M.Rubber)
		if i == n - 1 then
			Build.cylY(m, 1.14, 1.6, t, C.Steel, M.Metal)
		end
	end
	collide(m)
	return m
end

----------------------------------------------------------------------
-- Wrecked car (rusty, wheels missing, broken windows).
----------------------------------------------------------------------
function Props.carWreck(parent: Instance, cf: CFrame, color: Color3?): Model
	local m = model(parent, "CarWreck")
	local col = (color or Props.randomBright()):Lerp(C.Rust, 0.35)
	local body = cf * CF(0, 1.9, 0) * ANG(rad(rng:NextNumber(-3, 3)), 0, rad(rng:NextNumber(-4, 4)))
	-- chassis + body
	Build.block(m, V3(13, 2.2, 6), body, col, M.CorrodedMetal)
	Build.block(m, V3(13.2, 0.6, 6.2), body * CF(0, -1.1, 0), RGB(50, 46, 44), M.Metal)
	-- hood & trunk slopes
	Build.wedge(m, V3(6, 0.8, 3.2), body * CF(0, 1.5, -3.4) * ANG(0, rad(90), 0), col, M.CorrodedMetal)
	-- cabin
	local cabin = body * CF(0.6, 2.4, 0)
	Build.block(m, V3(6, 2.4, 5.6), cabin, col, M.CorrodedMetal)
	Build.block(m, V3(6.2, 0.3, 5.8), cabin * CF(0, 1.3, 0), col:Lerp(Color3.new(0, 0, 0), 0.2), M.CorrodedMetal)
	-- windows (broken glass)
	local glass = RGB(150, 200, 220)
	for _, z in ipairs({ -2.82, 2.82 }) do
		local w = Build.block(m, V3(2.4, 1.4, 0.1), cabin * CF(-1.4, 0.2, z), glass, M.Glass)
		w.Transparency = 0.5
		local w2 = Build.block(m, V3(2.2, 0.8, 0.1), cabin * CF(1.4, -0.1, z) * ANG(0, 0, rad(8)), glass, M.Glass)
		w2.Transparency = 0.5
	end
	local wind = Build.block(m, V3(0.1, 1.8, 5.2), cabin * CF(-3.05, 0.1, 0) * ANG(0, 0, rad(-20)), glass, M.Glass)
	wind.Transparency = 0.55
	-- lights / bumpers
	for _, z in ipairs({ -2.2, 2.2 }) do
		Build.cylX(m, 0.2, 0.9, body * CF(-6.55, 0.3, z), RGB(255, 245, 200), M.Glass)
		Build.block(m, V3(0.2, 0.5, 1), body * CF(6.55, 0.4, z), RGB(220, 40, 40), M.Glass)
	end
	Build.block(m, V3(0.5, 0.6, 6.4), body * CF(-6.7, -0.7, 0), C.Steel, M.Metal)
	Build.block(m, V3(0.5, 0.6, 6.4), body * CF(6.7, -0.7, 0) * ANG(rad(6), 0, 0), C.Steel, M.CorrodedMetal)
	-- remaining wheels
	for _, p in ipairs({ { -4.2, -3 }, { 4.2, 3 } }) do
		local w = body * CF(p[1], -1.1, p[2])
		Build.cylZ(m, 1.2, 2.6, w, C.Rubber, M.Rubber)
		Build.cylZ(m, 1.3, 1.4, w, C.Steel, M.Metal)
	end
	-- cinder blocks under the bare axles
	for _, p in ipairs({ { -4.2, 2.4 }, { 4.2, -2.4 } }) do
		Build.block(m, V3(1.6, 1.6, 1.2), cf * CF(p[1], 0.8, p[2]), RGB(150, 150, 150), M.Concrete)
	end
	collide(m)
	return m
end

----------------------------------------------------------------------
-- Crushed car cube (for stacks / walls).
----------------------------------------------------------------------
function Props.crushedCube(parent: Instance, cf: CFrame, color: Color3?): Model
	local m = model(parent, "CrushedCar")
	local col = (color or Props.randomBright()):Lerp(C.Rust, 0.25)
	local c = cf * CF(0, 2.5, 0)
	Build.block(m, V3(6, 5, 5), c, col, M.CorrodedMetal)
	for i = 0, 4 do
		local y = -2 + i
		local shade = (i % 2 == 0) and col:Lerp(Color3.new(0, 0, 0), 0.25) or col:Lerp(Color3.new(1, 1, 1), 0.1)
		Build.block(
			m,
			V3(6.2, 0.35, 5.2),
			c * CF(rng:NextNumber(-0.15, 0.15), y, 0) * ANG(0, 0, rad(rng:NextNumber(-3, 3))),
			shade,
			M.CorrodedMetal
		)
	end
	-- bits poking out
	Build.cylZ(m, 0.4, 2.0, c * CF(-2.3, -1.4, 2.6), C.Rubber, M.Rubber)
	Build.block(m, V3(1.6, 0.8, 0.15), c * CF(1.2, 0.9, -2.6), RGB(170, 210, 230), M.Glass)
	Build.cylX(m, 2.0, 0.3, c * CF(3.6, 1.6, 0.8) * ANG(0, rad(20), rad(15)), C.Steel, M.Metal)
	collide(m)
	return m
end

----------------------------------------------------------------------
-- Traffic cone.
----------------------------------------------------------------------
function Props.cone(parent: Instance, cf: CFrame): Model
	local m = model(parent, "Cone")
	local orange = RGB(255, 120, 30)
	Build.block(m, V3(2, 0.3, 2), cf * CF(0, 0.15, 0), orange)
	local steps = 5
	for i = 0, steps - 1 do
		local d = 1.4 - i * 0.24
		local col = (i == 2 or i == 3) and C.White or orange
		Build.cylY(m, 0.5, d, cf * CF(0, 0.55 + i * 0.5, 0), col)
	end
	collide(m)
	return m
end

----------------------------------------------------------------------
-- Street lamp with a warm light.
----------------------------------------------------------------------
function Props.lamp(parent: Instance, cf: CFrame, color: Color3?): Model
	local m = model(parent, "Lamp")
	local pole = RGB(52, 56, 70)
	Build.cylY(m, 1, 1.6, cf * CF(0, 0.5, 0), pole, M.Metal)
	Build.cylY(m, 18, 0.6, cf * CF(0, 9.5, 0), pole, M.Metal)
	Build.block(m, V3(4, 0.4, 0.4), cf * CF(1.8, 18.3, 0), pole, M.Metal)
	local head = cf * CF(3.6, 17.9, 0)
	Build.block(m, V3(1.8, 0.6, 1.2), head, pole, M.Metal)
	local bulb = Build.block(m, V3(1.5, 0.2, 0.9), head * CF(0, -0.38, 0), color or RGB(255, 230, 170), M.Neon)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 40
	light.Angle = 100
	light.Brightness = 2.5
	light.Color = color or RGB(255, 220, 160)
	light.Parent = bulb
	collide(m)
	return m
end

----------------------------------------------------------------------
-- Rusty steel girder pile.
----------------------------------------------------------------------
function Props.girders(parent: Instance, cf: CFrame): Model
	local m = model(parent, "Girders")
	for i = 0, 3 do
		local g = cf * CF(rng:NextNumber(-1, 1), 0.6 + i * 1.1, (i - 1.5) * 1.6) * ANG(0, rad(rng:NextNumber(-20, 20)), 0)
		local col = C.Rust:Lerp(RGB(200, 90, 40), rng:NextNumber())
		Build.block(m, V3(16, 0.25, 1.4), g * CF(0, 0.5, 0), col, M.CorrodedMetal)
		Build.block(m, V3(16, 0.25, 1.4), g * CF(0, -0.5, 0), col, M.CorrodedMetal)
		Build.block(m, V3(16, 1.0, 0.25), g, col, M.CorrodedMetal)
	end
	collide(m)
	return m
end

----------------------------------------------------------------------
-- Pile of junk (mound + random clutter).
----------------------------------------------------------------------
function Props.junkPile(parent: Instance, cf: CFrame, radius: number): Model
	local m = model(parent, "JunkPile")
	local mound = Build.ball(m, radius * 2, cf * CF(0, -radius * 0.45, 0), RGB(110, 92, 74), M.Ground)
	mound.Size = V3(radius * 2, radius * 2, radius * 2)
	for _ = 1, math.floor(radius * 1.4) do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(0, radius * 0.75)
		local h = math.sqrt(math.max(0, radius * radius - d * d)) - radius * 0.45
		local p = cf * CF(math.cos(a) * d, h, math.sin(a) * d) * ANG(rng:NextNumber(-1, 1), rng:NextNumber(0, 6), rng:NextNumber(-1, 1))
		local kind = rng:NextInteger(1, 5)
		local col = Props.randomBright():Lerp(C.Rust, 0.45)
		if kind == 1 then
			Build.block(m, V3(rng:NextNumber(2, 5), rng:NextNumber(0.3, 1), rng:NextNumber(2, 4)), p, col, M.CorrodedMetal)
		elseif kind == 2 then
			Build.cylX(m, rng:NextNumber(3, 7), rng:NextNumber(0.5, 1.2), p, C.Rust, M.CorrodedMetal)
		elseif kind == 3 then
			Build.torus(m, p, 1.2, 0.5, 10, C.Rubber, M.Rubber)
		elseif kind == 4 then
			Build.block(m, V3(2, 2, 2), p, RGB(180, 130, 80), M.WoodPlanks)
		else
			Build.wedge(m, V3(rng:NextNumber(2, 4), rng:NextNumber(1, 3), rng:NextNumber(2, 4)), p, col, M.CorrodedMetal)
		end
	end
	collide(m)
	return m
end

----------------------------------------------------------------------
-- Huge junkyard crane (landmark).
----------------------------------------------------------------------
function Props.crane(parent: Instance, cf: CFrame): Model
	local m = model(parent, "Crane")
	local yellow = RGB(255, 190, 30)
	local dark = RGB(50, 52, 60)
	-- tracks
	for _, z in ipairs({ -5, 5 }) do
		Build.block(m, V3(16, 3, 3.2), cf * CF(0, 1.5, z), dark, M.DiamondPlate)
		for i = 0, 6 do
			Build.cylZ(m, 3.4, 2.4, cf * CF(-6.6 + i * 2.2, 1.4, z), RGB(70, 72, 80), M.Metal)
		end
	end
	-- body
	local body = cf * CF(0, 6, 0)
	Build.block(m, V3(14, 6, 10), body, yellow, M.Metal)
	Build.block(m, V3(6, 5, 8), body * CF(-3, 5.5, 0), yellow, M.Metal)
	local win = Build.block(m, V3(0.2, 3, 6), body * CF(-6.1, 6, 0), RGB(140, 210, 255), M.Glass)
	win.Transparency = 0.3
	Build.block(m, V3(14.2, 0.8, 10.2), body * CF(0, -2.6, 0), C.Black, M.Metal)
	for i = 0, 5 do
		Build.block(m, V3(1.2, 0.82, 10.25), body * CF(-6 + i * 2.4, -2.6, 0) * ANG(0, 0, rad(30)), yellow, M.SmoothPlastic)
	end
	-- exhaust
	Build.cylY(m, 5, 0.8, body * CF(4, 5, 3), C.DarkSteel, M.Metal)
	-- lattice boom
	local boomBase = body * CF(3, 3, 0) * ANG(0, 0, rad(55))
	local boomLen = 46
	for _, z in ipairs({ -1.6, 1.6 }) do
		for _, y in ipairs({ -1.6, 1.6 }) do
			Build.block(m, V3(0.5, boomLen, 0.5), boomBase * CF(y, boomLen / 2, z), yellow, M.Metal)
		end
	end
	for i = 0, 14 do
		local y = 1.5 + i * 3
		Build.block(m, V3(3.4, 0.35, 0.35), boomBase * CF(0, y, 1.6) * ANG(0, 0, rad(45)), yellow, M.Metal)
		Build.block(m, V3(3.4, 0.35, 0.35), boomBase * CF(0, y, -1.6) * ANG(0, 0, rad(-45)), yellow, M.Metal)
		Build.block(m, V3(0.35, 0.35, 3.4), boomBase * CF(1.6, y, 0), yellow, M.Metal)
	end
	-- cable + magnet
	local tip = boomBase * CF(0, boomLen, 0)
	local tipPos = tip.Position
	local magnetPos = Vector3.new(tipPos.X, cf.Position.Y + 14, tipPos.Z)
	local cableLen = (tipPos - magnetPos).Magnitude
	Build.cylY(m, cableLen, 0.3, CFrame.new((tipPos + magnetPos) / 2), RGB(30, 30, 30), M.Metal)
	local mag = CFrame.new(magnetPos)
	Build.cylY(m, 1.6, 7, mag, RGB(60, 62, 70), M.Metal)
	Build.cylY(m, 0.4, 7.4, mag * CF(0, -0.9, 0), RGB(230, 60, 60), M.Metal)
	Build.cylY(m, 1.4, 1.4, mag * CF(0, 1.4, 0), yellow, M.Metal)
	-- dangling car under the magnet
	Props.crushedCube(m, mag * CF(0, -6.5, 0) * ANG(rad(8), rad(30), rad(-6)))
	collide(m)
	return m
end

----------------------------------------------------------------------
-- Corrugated metal fence panel (for perimeter walls).
----------------------------------------------------------------------
function Props.fencePanel(parent: Instance, cf: CFrame, length: number, height: number, color: Color3): Model
	local m = model(parent, "Fence")
	Build.block(m, V3(length, height, 0.6), cf * CF(0, height / 2, 0), color, M.Metal)
	local ribs = math.floor(length / 1.6)
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.22)
	for i = 0, ribs - 1 do
		local x = -length / 2 + 0.8 + i * 1.6
		Build.block(m, V3(0.6, height, 0.9), cf * CF(x, height / 2, 0), dark, M.Metal)
	end
	Build.block(m, V3(length, 0.8, 1.2), cf * CF(0, height, 0), RGB(70, 72, 80), M.Metal)
	-- barbed wire
	for i = 0, math.floor(length / 4) - 1 do
		local x = -length / 2 + 2 + i * 4
		Build.torus(m, cf * CF(x, height + 1.0, 0) * ANG(0, 0, rad(90)), 0.8, 0.06, 8, RGB(170, 170, 176), M.Metal)
	end
	-- support posts
	for _, x in ipairs({ -length / 2, length / 2 }) do
		Build.block(m, V3(1.4, height + 2, 1.4), cf * CF(x, (height + 2) / 2, 0), RGB(60, 62, 70), M.Metal)
		Build.block(m, V3(1.8, 0.6, 1.8), cf * CF(x, height + 2.2, 0), RGB(255, 196, 40), M.SmoothPlastic)
	end
	collide(m)
	return m
end

----------------------------------------------------------------------
-- Toxic pool.
----------------------------------------------------------------------
function Props.toxicPool(parent: Instance, cf: CFrame, radius: number): Model
	local m = model(parent, "ToxicPool")
	local pool = Build.cylY(m, 0.6, radius * 2, cf * CF(0, 0.15, 0), RGB(110, 255, 50), M.Neon)
	pool.Transparency = 0.15
	Build.torus(m, cf * CF(0, 0.3, 0), radius, 0.7, 18, RGB(70, 60, 50), M.Slate)
	Build.light(pool, RGB(120, 255, 60), radius * 1.6, 1.4)
	local att = Instance.new("Attachment")
	att.Parent = pool
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(RGB(150, 255, 90))
	bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	bubbles.Lifetime = NumberRange.new(1, 2)
	bubbles.Rate = radius * 1.5
	bubbles.Speed = NumberRange.new(1, 3)
	bubbles.SpreadAngle = Vector2.new(20, 20)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Shape = Enum.ParticleEmitterShape.Cylinder
	bubbles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	bubbles.LightEmission = 0.8
	bubbles.Parent = pool
	return m
end

----------------------------------------------------------------------
-- Glowing crystal cluster (meteor crater).
----------------------------------------------------------------------
function Props.crystals(parent: Instance, cf: CFrame, color: Color3): Model
	local m = model(parent, "Crystals")
	for i = 1, rng:NextInteger(4, 7) do
		local h = rng:NextNumber(3, 9)
		local w = rng:NextNumber(0.8, 1.8)
		local c = cf
			* CF(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
			* ANG(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6), rng:NextNumber(-0.5, 0.5))
		local p = Build.block(m, V3(w, h, w), c * CF(0, h / 2, 0), color, M.Neon)
		p.Transparency = 0.2
		Build.block(
			m,
			V3(w * 0.7, w * 0.7, w * 0.7),
			c * CF(0, h, 0) * ANG(rad(45), 0, rad(45)),
			color:Lerp(Color3.new(1, 1, 1), 0.3),
			M.Neon
		)
		if i == 1 then
			Build.light(p, color, 18, 2)
		end
	end
	collide(m)
	return m
end

----------------------------------------------------------------------
-- Dead tree (toxic zone).
----------------------------------------------------------------------
function Props.deadTree(parent: Instance, cf: CFrame): Model
	local m = model(parent, "DeadTree")
	local bark = RGB(70, 58, 50)
	Build.cylY(m, 10, 1.4, cf * CF(0, 5, 0) * ANG(0, 0, rad(rng:NextNumber(-6, 6))), bark, M.Wood)
	for i = 1, 4 do
		local a = rng:NextNumber(0, 6.28)
		local b = cf * CF(0, 5 + i * 1.2, 0) * ANG(0, a, 0) * ANG(0, 0, rad(-50)) * CF(0, 2, 0)
		Build.cylY(m, 4, 0.5, b, bark, M.Wood)
	end
	collide(m)
	return m
end

return Props
