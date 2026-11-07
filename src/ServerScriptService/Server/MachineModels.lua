-- MachineModels: the purchasable machines shown in the Machine Bay.
-- Moving parts are grouped in Models named "Rotor" (attribute Speed = rad/s,
-- Axis = "X"/"Y"/"Z"); the client spins them while the machine is owned.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(ReplicatedStorage.Shared.Build)

local C = Build.Colors
local M = Enum.Material
local rad = math.rad
local CF = CFrame.new
local ANG = CFrame.Angles
local V3 = Vector3.new
local RGB = Color3.fromRGB

local MachineModels = {}

local function rotor(parent: Instance, pivot: CFrame, speed: number, axis: string?): Model
	local r = Instance.new("Model")
	r.Name = "Rotor"
	r:SetAttribute("Speed", speed)
	r:SetAttribute("Axis", axis or "Y")
	r.Parent = parent
	local p = Build.part(r, "Part", {
		Name = "Pivot",
		Size = V3(0.2, 0.2, 0.2),
		CFrame = pivot,
		Transparency = 1,
		CanQuery = false,
	})
	r.PrimaryPart = p
	return r
end

local function emitter(parent: Instance, color: Color3, rate: number, texture: string?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "MachineFX"
	e.Texture = texture or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Rate = rate
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(25, 25)
	e.LightEmission = 0.7
	e.Enabled = false
	e.Parent = parent
	return e
end

local builders: { [string]: (Model, CFrame) -> () } = {}

builders.AutoWasher = function(m, o)
	local body = RGB(240, 246, 255)
	local blue = RGB(60, 150, 255)
	local b = o * CF(0, 4.6, 0)
	Build.block(m, V3(9, 9, 7), b, body, M.SmoothPlastic)
	Build.block(m, V3(9.2, 0.6, 7.2), b * CF(0, -4.5, 0), blue, M.SmoothPlastic)
	Build.block(m, V3(9.2, 1.6, 7.2), b * CF(0, 3.9, 0), blue, M.SmoothPlastic)
	-- control panel
	local panel = b * CF(0, 3.9, -3.62)
	Build.block(m, V3(5, 1.0, 0.1), panel * CF(-1.4, 0, 0), RGB(20, 24, 34), M.Glass)
	Build.block(m, V3(3.4, 0.6, 0.12), panel * CF(-1.4, 0, -0.02), RGB(90, 255, 160), M.Neon).Name = "Light"
	for i = 0, 2 do
		Build.cylZ(m, 0.3, 0.6, panel * CF(1.8 + i * 0.9, 0, -0.1), ({ C.Red, C.Yellow, RGB(80, 230, 110) })[i + 1], M.SmoothPlastic)
	end
	-- door
	local door = b * CF(0, -0.4, -3.55)
	Build.torus(m, door * ANG(rad(90), 0, 0), 2.7, 0.35, 24, C.Chrome, M.Metal)
	local glass = Build.cylZ(m, 0.2, 5.2, door * CF(0, 0, -0.05), RGB(170, 230, 255), M.Glass)
	glass.Transparency = 0.45
	Build.cylZ(m, 0.1, 5.4, door * CF(0, 0, 0.3), RGB(30, 40, 60), M.Metal)
	Build.block(m, V3(0.5, 1.4, 0.5), door * CF(2.9, 0, -0.3), C.Chrome, M.Metal)
	-- spinning drum (laundry + water)
	local r = rotor(m, door * CF(0, 0, 0.15), 6, "Z")
	Build.cylZ(r, 0.1, 4.6, door * CF(0, 0, 0.18), RGB(90, 190, 255), M.Neon)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		Build.block(r, V3(0.6, 1.8, 0.4), door * ANG(0, 0, a) * CF(0, 1.2, 0.05), RGB(255, 255, 255), M.SmoothPlastic)
		Build.ball(r, 0.9, door * ANG(0, 0, a + 0.7) * CF(0, 1.6, 0.05), Build.Colors.Yellow, M.SmoothPlastic)
	end
	-- pipes + soap bottle
	Build.cylY(m, 5, 0.7, b * CF(3.2, 6.8, 2.2), C.Chrome, M.Metal)
	Build.ball(m, 0.9, b * CF(3.2, 9.3, 2.2), C.Chrome, M.Metal)
	Build.cylX(m, 2.5, 0.7, b * CF(2.0, 9.3, 2.2), C.Chrome, M.Metal)
	local bottle = b * CF(-2.6, 5.4, 1)
	Build.block(m, V3(1.6, 2.4, 1.2), bottle, RGB(255, 90, 200), M.SmoothPlastic)
	Build.cylY(m, 0.6, 0.6, bottle * CF(0, 1.5, 0), C.White)
	local fx = Build.block(m, V3(4, 0.2, 4), b * CF(0, 4.9, 0), body, M.SmoothPlastic)
	fx.Transparency = 1
	emitter(fx, RGB(200, 240, 255), 14)
end

builders.MagnetCrane = function(m, o)
	local red = RGB(235, 60, 60)
	local dark = RGB(50, 54, 64)
	Build.cylY(m, 1.2, 8, o * CF(0, 0.6, 0), dark, M.DiamondPlate)
	local r = rotor(m, o * CF(0, 1.2, 0), 0.6, "Y")
	Build.cylY(r, 1.4, 6, o * CF(0, 1.9, 0), red, M.Metal)
	Build.block(r, V3(3.6, 3.6, 3.4), o * CF(0, 4.4, 1), red, M.Metal)
	local win = Build.block(r, V3(3.4, 1.8, 0.2), o * CF(0, 5, -0.8), RGB(150, 210, 255), M.Glass)
	win.Transparency = 0.3
	-- column + arm
	Build.block(r, V3(1.6, 12, 1.6), o * CF(0, 8, 2.2), RGB(255, 196, 40), M.Metal)
	for i = 0, 5 do
		Build.block(r, V3(1.7, 0.3, 1.7), o * CF(0, 3 + i * 2, 2.2) * ANG(0, 0, rad(30)), dark, M.Metal)
	end
	Build.block(r, V3(1.2, 1.2, 12), o * CF(0, 13.6, -2.5), RGB(255, 196, 40), M.Metal)
	Build.block(r, V3(1.6, 1.6, 2), o * CF(0, 13.6, 4.5), dark, M.Metal)
	-- cable + magnet
	Build.cylY(r, 5, 0.2, o * CF(0, 10.6, -8), RGB(30, 30, 30), M.Metal)
	Build.cylY(r, 0.9, 4, o * CF(0, 7.6, -8), dark, M.Metal)
	Build.cylY(r, 0.3, 4.2, o * CF(0, 7.05, -8), red, M.Metal)
	local glow = Build.cylY(r, 0.1, 3.6, o * CF(0, 6.88, -8), RGB(120, 200, 255), M.Neon)
	glow.Name = "Light"
	-- scrap held by the magnet
	Build.block(r, V3(2, 1.4, 1.6), o * CF(0, 6.0, -8) * ANG(rad(10), rad(20), 0), C.Rust, M.CorrodedMetal)
	emitter(glow, RGB(120, 200, 255), 10)
end

builders.RarityRadar = function(m, o)
	local green = RGB(90, 230, 120)
	local dark = RGB(48, 52, 62)
	Build.block(m, V3(7, 1, 7), o * CF(0, 0.5, 0), dark, M.DiamondPlate)
	-- lattice tower
	for _, x in ipairs({ -1.6, 1.6 }) do
		for _, z in ipairs({ -1.6, 1.6 }) do
			Build.block(m, V3(0.4, 11, 0.4), o * CF(x * 0.8, 6, z * 0.8) * ANG(rad(-z * 2), 0, rad(x * 2)), green, M.Metal)
		end
	end
	for i = 0, 4 do
		Build.block(m, V3(3, 0.3, 0.3), o * CF(0, 2 + i * 2, 1.3) * ANG(0, 0, rad(i % 2 == 0 and 35 or -35)), green, M.Metal)
		Build.block(m, V3(3, 0.3, 0.3), o * CF(0, 2 + i * 2, -1.3) * ANG(0, 0, rad(i % 2 == 0 and -35 or 35)), green, M.Metal)
	end
	-- rotating dish
	local r = rotor(m, o * CF(0, 11.5, 0), 1.2, "Y")
	Build.cylY(r, 1, 1.4, o * CF(0, 11.8, 0), dark, M.Metal)
	local dish = o * CF(0, 13.4, -0.6) * ANG(rad(-35), 0, 0)
	Build.cylY(r, 0.5, 7, dish, RGB(235, 240, 250), M.SmoothPlastic)
	Build.cylY(r, 0.6, 5, dish * CF(0, 0.15, 0), RGB(210, 220, 235), M.SmoothPlastic)
	Build.cylY(r, 2.6, 0.25, dish * CF(0, 1.5, 0), C.Steel, M.Metal)
	local tip = Build.ball(r, 0.7, dish * CF(0, 2.9, 0), RGB(255, 60, 80), M.Neon)
	tip.Name = "Light"
	-- screen
	local screen = Build.block(m, V3(3.2, 2, 0.3), o * CF(0, 2.4, -3.2), RGB(20, 30, 30), M.Glass)
	Build.block(m, V3(2.8, 1.6, 0.1), o * CF(0, 2.4, -3.36), RGB(60, 255, 120), M.Neon).Name = "Light"
	Build.torus(m, o * CF(0, 2.4, -3.42) * ANG(rad(90), 0, 0), 0.5, 0.05, 12, RGB(10, 60, 30), M.SmoothPlastic)
	local _ = screen
	emitter(tip, RGB(120, 255, 140), 6)
end

builders.AutoSeller = function(m, o)
	local yellow = RGB(255, 196, 40)
	local dark = RGB(48, 50, 58)
	-- conveyor
	local belt = o * CF(-1.5, 2.6, 0)
	Build.block(m, V3(11, 0.4, 3.6), belt, RGB(30, 30, 34), M.Fabric)
	Build.block(m, V3(11, 0.9, 0.4), belt * CF(0, 0.1, 1.9), yellow, M.Metal)
	Build.block(m, V3(11, 0.9, 0.4), belt * CF(0, 0.1, -1.9), yellow, M.Metal)
	for _, x in ipairs({ -5, -1.6, 1.8, 5 }) do
		Build.block(m, V3(0.5, 2.4, 0.5), belt * CF(x, -1.3, 1.6), dark, M.Metal)
		Build.block(m, V3(0.5, 2.4, 0.5), belt * CF(x, -1.3, -1.6), dark, M.Metal)
	end
	for i = 0, 2 do
		local box = belt * CF(-4 + i * 3.2, 0.9, 0) * ANG(0, rad(i * 17), 0)
		Build.block(m, V3(1.6, 1.4, 1.6), box, RGB(200, 150, 90), M.Cardboard)
		Build.block(m, V3(1.62, 0.2, 0.4), box * CF(0, 0.6, 0), RGB(230, 210, 160), M.Fabric)
	end
	-- gear rotor on the side
	local r = rotor(m, belt * CF(-5.6, 0, -2.2), 2.5, "Z")
	Build.cylZ(r, 0.4, 2.0, belt * CF(-5.6, 0, -2.2), C.Steel, M.Metal)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		Build.block(r, V3(0.4, 0.5, 0.4), belt * CF(-5.6, 0, -2.2) * ANG(0, 0, a) * CF(0, 1.1, 0), C.Steel, M.Metal)
	end
	-- cash machine
	local cash = o * CF(6.2, 3.8, 0)
	Build.block(m, V3(4, 7.6, 5), cash, RGB(70, 200, 110), M.SmoothPlastic)
	Build.block(m, V3(4.2, 1, 5.2), cash * CF(0, 3.6, 0), RGB(40, 150, 80), M.SmoothPlastic)
	Build.block(m, V3(0.3, 2, 3), cash * CF(-2.1, 1, 0), RGB(20, 30, 20), M.Glass)
	local sign = Build.block(m, V3(0.2, 1.6, 2.4), cash * CF(-2.2, 1, 0), RGB(255, 230, 80), M.Neon)
	sign.Name = "Light"
	Build.sign(sign, Enum.NormalId.Left, "$", RGB(40, 120, 40), RGB(255, 255, 255))
	Build.block(m, V3(1.2, 1.4, 3.8), cash * CF(-2.4, -1.4, 0), dark, M.Metal)
	emitter(sign, RGB(255, 230, 80), 8)
end

builders.PolishLab = function(m, o)
	local purple = RGB(170, 100, 255)
	local white = RGB(245, 245, 252)
	-- lab bench
	Build.block(m, V3(12, 0.6, 5), o * CF(0, 3.4, 0), white, M.SmoothPlastic)
	Build.block(m, V3(11.6, 3, 4.6), o * CF(0, 1.6, 0), RGB(90, 70, 140), M.SmoothPlastic)
	for i = 0, 3 do
		Build.block(m, V3(2.6, 2.4, 0.1), o * CF(-4.2 + i * 2.8, 1.6, -2.32), RGB(110, 90, 170), M.SmoothPlastic)
		Build.block(m, V3(0.8, 0.2, 0.2), o * CF(-4.2 + i * 2.8, 2.4, -2.42), C.Chrome, M.Metal)
	end
	-- tanks
	local colors = { RGB(255, 80, 180), RGB(80, 220, 255), RGB(255, 220, 60) }
	for i, col in ipairs(colors) do
		local t = o * CF(-5 + i * 1.6, 5.4, 1.2)
		local g = Build.cylY(m, 3.4, 1.3, t, RGB(220, 240, 255), M.Glass)
		g.Transparency = 0.5
		Build.cylY(m, 2.4, 1.05, t * CF(0, -0.4, 0), col, M.Neon).Name = "Light"
		Build.cylY(m, 0.3, 1.4, t * CF(0, 1.8, 0), C.Chrome, M.Metal)
	end
	-- floating gem in rings
	local center = o * CF(3, 7, 0)
	Build.cylY(m, 0.6, 2.6, o * CF(3, 3.9, 0), C.Chrome, M.Metal)
	local r = rotor(m, center, 1.5, "Y")
	local gem = Build.block(r, V3(1.6, 1.6, 1.6), center * ANG(rad(45), 0, rad(45)), RGB(120, 230, 255), M.Neon)
	gem.Name = "Light"
	Build.torus(r, center * ANG(rad(60), 0, 0), 2.2, 0.1, 18, purple, M.Neon)
	Build.torus(r, center * ANG(rad(-60), 0, rad(30)), 2.6, 0.1, 18, RGB(255, 140, 220), M.Neon)
	-- robot polishing arm
	Build.cylY(m, 1, 1.4, o * CF(-1, 4.2, -1.2), RGB(60, 60, 70), M.Metal)
	Build.block(m, V3(0.6, 3, 0.6), o * CF(-1, 5.8, -1.2) * ANG(0, 0, rad(-25)), RGB(255, 200, 60), M.Metal)
	Build.block(m, V3(0.5, 2.4, 0.5), o * CF(0.1, 7.4, -1.2) * ANG(0, 0, rad(-80)), RGB(255, 200, 60), M.Metal)
	Build.cylX(m, 0.6, 1.0, o * CF(1.4, 7.6, -1.2), C.Chrome, M.Metal)
	emitter(gem, RGB(200, 160, 255), 12)
end

builders.Teleporter = function(m, o)
	local cyan = RGB(80, 220, 255)
	Build.cylY(m, 1, 12, o * CF(0, 0.5, 0), RGB(50, 54, 70), M.DiamondPlate)
	Build.cylY(m, 1.1, 9, o * CF(0, 0.55, 0), cyan, M.Neon)
	local ring = o * CF(0, 7, 0) * ANG(rad(90), 0, 0)
	Build.torus(m, ring, 5.5, 0.6, 28, RGB(60, 64, 84), M.Metal)
	for _, p in ipairs(Build.torus(m, ring, 5.5, 0.66, 28, cyan, M.Neon)) do
		p.Size = Vector3.new(p.Size.X * 0.3, p.Size.Y, p.Size.Z)
	end
	local portal = Build.cylZ(m, 0.2, 10.4, o * CF(0, 7, 0), RGB(140, 90, 255), M.Neon)
	portal.Transparency = 0.35
	portal.Name = "Light"
	for _, x in ipairs({ -5.8, 5.8 }) do
		Build.block(m, V3(1.6, 3, 2.4), o * CF(x, 1.5, 0), RGB(60, 64, 84), M.Metal)
	end
	local r = rotor(m, o * CF(0, 7, 0), 2, "Z")
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		Build.ball(r, 0.7, o * CF(0, 7, 0) * ANG(0, 0, a) * CF(0, 4.2, 0), RGB(255, 255, 255), M.Neon)
	end
	local fx = emitter(portal, RGB(160, 120, 255), 20)
	fx.Enabled = true
	Build.light(portal, RGB(140, 90, 255), 20, 2)
end

function MachineModels.create(id: string, parent: Instance, cf: CFrame): Model
	local m = Instance.new("Model")
	m.Name = id
	local b = builders[id]
	if b then
		b(m, cf)
	end
	Build.setAll(m, { CanCollide = true })
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Pivot" then
			d.CanCollide = false
		end
	end
	m.Parent = parent
	return m
end

return MachineModels
