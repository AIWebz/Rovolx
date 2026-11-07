-- ScrapModels: hand-built, multi-part models for every collectable scrap.
-- ScrapModels.create(id, clean) returns a Model whose PrimaryPart is an
-- invisible "Hitbox" that wraps the whole object.
--
-- Every model is built "clean" (true colours, chrome, glowing neon). A dirty
-- pass then corrodes, darkens and de-powers it, so the cleaning minigame has a
-- real visual payoff.

local Build = require(script.Parent.Build)
local Config = require(script.Parent.Config)

local C = Build.Colors
local M = Enum.Material
local rad = math.rad
local CF = CFrame.new
local ANG = CFrame.Angles
local V3 = Vector3.new
local RGB = Color3.fromRGB

local ScrapModels = {}

local builders: { [string]: (Model, CFrame) -> () } = {}

----------------------------------------------------------------------
-- COMMON
----------------------------------------------------------------------
builders.RustyCan = function(m, o)
	o = o * ANG(0, 0, rad(78)) -- lying on its side
	Build.shiny(Build.cylY(m, 1.9, 1.42, o, C.Steel, M.Metal))
	Build.cylY(m, 1.15, 1.47, o, RGB(220, 44, 52), M.SmoothPlastic)
	Build.cylY(m, 0.16, 1.49, o * CF(0, 0.32, 0), C.White, M.SmoothPlastic)
	Build.cylY(m, 0.08, 1.49, o * CF(0, -0.36, 0), RGB(255, 210, 60), M.SmoothPlastic)
	for _, y in ipairs({ 0.95, -0.95 }) do
		Build.torus(m, o * CF(0, y, 0), 0.7, 0.07, 14, C.Chrome, M.Metal)
	end
	for _, y in ipairs({ 0.7, -0.7 }) do
		Build.torus(m, o * CF(0, y, 0), 0.72, 0.035, 14, C.Steel, M.Metal)
	end
	Build.shiny(Build.cylY(m, 0.04, 1.3, o * CF(0, 0.96, 0), C.Chrome, M.Metal))
	-- pull tab
	Build.block(m, V3(0.32, 0.04, 0.16), o * CF(0.12, 0.99, 0), C.Chrome, M.Metal)
	Build.torus(m, o * CF(0.34, 0.99, 0), 0.1, 0.025, 8, C.Chrome, M.Metal)
	Build.cylY(m, 0.06, 0.12, o * CF(0, 1, 0), C.DarkSteel, M.Metal)
	-- dent
	Build.block(m, V3(0.3, 0.5, 0.2), o * CF(0, 0.1, 0.68) * ANG(0, 0, rad(12)), RGB(190, 40, 46), M.SmoothPlastic)
end

builders.BentPipe = function(m, o)
	local pipe = RGB(96, 140, 128)
	local flange = RGB(70, 96, 92)
	-- horizontal run
	Build.cylX(m, 2.3, 0.72, o * CF(-0.25, -0.6, 0), pipe, M.Metal)
	-- elbow
	Build.ball(m, 0.76, o * CF(0.9, -0.6, 0), pipe, M.Metal)
	Build.cylX(m, 0.5, 0.78, o * CF(0.9, -0.6, 0) * ANG(0, 0, rad(45)), pipe, M.Metal)
	-- vertical run (slightly bent)
	Build.cylY(m, 1.7, 0.72, o * CF(0.92, 0.3, 0) * ANG(0, 0, rad(-6)), pipe, M.Metal)
	-- flanges + bolts
	local ends = {
		o * CF(-1.42, -0.6, 0) * ANG(0, 0, rad(90)),
		o * CF(1.02, 1.16, 0) * ANG(0, 0, rad(-6)),
	}
	for _, e in ipairs(ends) do
		Build.cylY(m, 0.18, 1.18, e, flange, M.Metal)
		Build.cylY(m, 0.2, 0.5, e, C.Black, M.SmoothPlastic)
		for i = 0, 3 do
			local a = i * math.pi / 2 + math.pi / 4
			Build.bolt(m, e * ANG(0, a, 0) * CF(0.44, 0.1, 0), 0.16, C.Steel)
		end
	end
	-- valve wheel
	local valve = o * CF(-0.3, -0.18, 0)
	Build.cylY(m, 0.36, 0.22, valve, C.DarkSteel, M.Metal)
	local wheel = valve * CF(0, 0.26, 0)
	Build.torus(m, wheel, 0.36, 0.05, 12, RGB(230, 50, 50), M.SmoothPlastic)
	for i = 0, 2 do
		Build.block(m, V3(0.72, 0.06, 0.07), wheel * ANG(0, i * math.pi / 3, 0), RGB(230, 50, 50), M.SmoothPlastic)
	end
	Build.cylY(m, 0.1, 0.16, wheel, C.Chrome, M.Metal)
	-- pressure gauge
	local gauge = o * CF(0.92, 0.25, -0.42)
	Build.cylZ(m, 0.14, 0.42, gauge, C.Chrome, M.Metal)
	Build.cylZ(m, 0.02, 0.34, gauge * CF(0, 0, -0.07), C.White, M.SmoothPlastic)
	Build.block(m, V3(0.03, 0.14, 0.02), gauge * CF(0.03, 0.04, -0.085) * ANG(0, 0, rad(-35)), C.Red, M.SmoothPlastic)
end

builders.OldTire = function(m, o)
	o = o * ANG(rad(62), 0, rad(10)) -- leaning tire
	local R, r = 1.22, 0.46
	Build.torus(m, o, R, r, 22, C.Rubber, M.Rubber)
	-- tread blocks
	for i = 0, 25 do
		local a = (i / 26) * math.pi * 2
		local cf = o * ANG(0, a, 0) * CF(R + r - 0.06, (i % 2 == 0) and 0.18 or -0.18, 0)
		Build.block(m, V3(0.16, 0.3, 0.28), cf, RGB(28, 28, 30), M.Rubber)
	end
	-- sidewall lettering band
	Build.torus(m, o * CF(0, 0.38, 0), R, 0.05, 22, RGB(250, 250, 250), M.SmoothPlastic)
	-- rim + hub
	Build.shiny(Build.cylY(m, 0.62, 1.7, o, C.Chrome, M.Metal))
	Build.cylY(m, 0.66, 1.32, o, C.DarkSteel, M.Metal)
	Build.shiny(Build.cylY(m, 0.72, 0.66, o, C.Chrome, M.Metal))
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		Build.cylY(m, 0.8, 0.13, o * ANG(0, a, 0) * CF(0.42, 0, 0), C.Steel, M.Metal)
	end
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		Build.block(m, V3(0.5, 0.64, 0.12), o * ANG(0, a, 0) * CF(0.55, 0, 0), C.Steel, M.Metal)
	end
end

builders.ScrapGear = function(m, o)
	o = o * ANG(rad(70), rad(20), 0)
	local steel = RGB(176, 180, 192)
	Build.shiny(Build.cylY(m, 0.42, 2.3, o, steel, M.Metal), 0.12)
	Build.radial(m, o, 14, 1.24, V3(0.42, 0.42, 0.38), steel, M.Metal)
	-- bevel ring
	Build.cylY(m, 0.48, 1.7, o, RGB(150, 154, 168), M.Metal)
	-- hub
	Build.shiny(Build.cylY(m, 0.7, 0.9, o, C.Chrome, M.Metal))
	Build.cylY(m, 0.74, 0.42, o, C.Black, M.SmoothPlastic)
	Build.block(m, V3(0.12, 0.74, 0.12), o * CF(0.24, 0, 0), C.Black, M.SmoothPlastic)
	-- lightening holes
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		Build.cylY(m, 0.5, 0.36, o * ANG(0, a, 0) * CF(0.64, 0, 0), RGB(40, 42, 48), M.SmoothPlastic)
	end
	-- bolts
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2 + 0.6
		Build.bolt(m, o * ANG(0, a, 0) * CF(0.36, 0.36, 0), 0.14, C.Gold)
	end
end

----------------------------------------------------------------------
-- UNCOMMON
----------------------------------------------------------------------
builders.CarBattery = function(m, o)
	o = o * ANG(0, rad(20), rad(-6))
	Build.block(m, V3(2.2, 1.4, 1.3), o * CF(0, -0.1, 0), RGB(36, 38, 44), M.SmoothPlastic)
	Build.block(m, V3(2.26, 0.22, 1.36), o * CF(0, 0.68, 0), RGB(66, 70, 82), M.SmoothPlastic)
	Build.block(m, V3(2.26, 0.12, 1.36), o * CF(0, -0.78, 0), RGB(56, 60, 70), M.SmoothPlastic)
	-- terminals
	local pos = o * CF(0.72, 0.9, 0.3)
	local neg = o * CF(-0.72, 0.9, 0.3)
	Build.cylY(m, 0.24, 0.42, pos, RGB(230, 46, 46), M.SmoothPlastic)
	Build.shiny(Build.cylY(m, 0.3, 0.22, pos * CF(0, 0.1, 0), C.Gold, M.Metal))
	Build.cylY(m, 0.24, 0.42, neg, RGB(30, 30, 34), M.SmoothPlastic)
	Build.shiny(Build.cylY(m, 0.3, 0.22, neg * CF(0, 0.1, 0), C.Steel, M.Metal))
	-- + / - symbols
	Build.block(m, V3(0.28, 0.04, 0.07), o * CF(0.72, 0.8, -0.18), C.White)
	Build.block(m, V3(0.07, 0.04, 0.28), o * CF(0.72, 0.8, -0.18), C.White)
	Build.block(m, V3(0.28, 0.04, 0.07), o * CF(-0.72, 0.8, -0.18), C.White)
	-- vent caps
	for i = 0, 5 do
		Build.cylY(m, 0.08, 0.2, o * CF(-0.55 + i * 0.22, 0.81, -0.4), RGB(250, 200, 50), M.SmoothPlastic)
	end
	-- handle
	Build.block(m, V3(0.12, 0.4, 0.12), o * CF(-0.4, 0.95, 0), C.Black)
	Build.block(m, V3(0.12, 0.4, 0.12), o * CF(0.4, 0.95, 0), C.Black)
	Build.block(m, V3(0.92, 0.12, 0.14), o * CF(0, 1.15, 0), C.Black)
	-- label
	Build.block(m, V3(1.5, 0.7, 0.04), o * CF(0, -0.05, -0.67), RGB(255, 210, 40), M.SmoothPlastic)
	Build.block(m, V3(1.5, 0.16, 0.05), o * CF(0, -0.18, -0.68), RGB(40, 180, 90), M.SmoothPlastic)
	Build.glow(Build.block(m, V3(0.3, 0.3, 0.05), o * CF(0.5, 0.12, -0.68), RGB(90, 255, 120), M.Neon))
	-- ribs on the sides
	for i = -2, 2 do
		Build.block(m, V3(0.06, 1.2, 1.32), o * CF(i * 0.42, -0.1, 0), RGB(46, 48, 56))
	end
end

builders.ChromeHubcap = function(m, o)
	o = o * ANG(rad(-72), 0, 0) -- lying back on the ground
	local up = o
	Build.shiny(Build.cylY(m, 0.2, 3.1, up, C.Chrome, M.Metal), 0.3)
	Build.torus(m, up * CF(0, 0.1, 0), 1.5, 0.12, 22, C.Chrome, M.Metal)
	Build.cylY(m, 0.24, 2.4, up * CF(0, 0.04, 0), RGB(190, 198, 210), M.Metal)
	-- spokes
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		Build.shiny(Build.block(m, V3(1.05, 0.14, 0.32), up * ANG(0, a, 0) * CF(0.7, 0.2, 0), C.Chrome, M.Metal), 0.3)
		Build.block(m, V3(0.5, 0.18, 0.16), up * ANG(0, a + math.pi / 6, 0) * CF(0.95, 0.16, 0), RGB(60, 64, 76), M.Metal)
	end
	-- center cap with emblem
	Build.shiny(Build.cylY(m, 0.34, 0.86, up * CF(0, 0.22, 0), C.Chrome, M.Metal), 0.35)
	Build.cylY(m, 0.36, 0.56, up * CF(0, 0.24, 0), RGB(30, 90, 220), M.SmoothPlastic)
	Build.glow(Build.block(m, V3(0.3, 0.38, 0.08), up * CF(0, 0.26, 0), RGB(255, 220, 80), M.Neon))
	Build.glow(Build.block(m, V3(0.08, 0.38, 0.3), up * CF(0, 0.26, 0), RGB(255, 220, 80), M.Neon))
	-- lug holes
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2 + 0.3
		Build.cylY(m, 0.26, 0.16, up * ANG(0, a, 0) * CF(0.55, 0.12, 0), C.Black)
	end
end

builders.CopperCoil = function(m, o)
	o = o * ANG(0, rad(30), 0)
	local base = o * CF(0, -0.95, 0)
	Build.block(m, V3(2.8, 0.22, 1.3), base, RGB(60, 64, 72), M.Metal)
	Build.block(m, V3(0.26, 0.6, 0.9), base * CF(-1.15, 0.38, 0), RGB(60, 64, 72), M.Metal)
	Build.block(m, V3(0.26, 0.6, 0.9), base * CF(1.15, 0.38, 0), RGB(60, 64, 72), M.Metal)
	local axis = o * CF(0, -0.15, 0)
	Build.cylX(m, 2.9, 0.42, axis, C.DarkSteel, M.Metal)
	for i = 0, 13 do
		local x = -1.0 + i * (2.0 / 13)
		local shade = (i % 2 == 0) and RGB(222, 120, 62) or RGB(196, 98, 48)
		Build.shiny(Build.cylX(m, 0.13, 1.3, axis * CF(x, 0, 0), shade, M.Metal), 0.15)
	end
	-- end caps
	Build.cylX(m, 0.16, 1.6, axis * CF(-1.12, 0, 0), RGB(40, 40, 46), M.SmoothPlastic)
	Build.cylX(m, 0.16, 1.6, axis * CF(1.12, 0, 0), RGB(40, 40, 46), M.SmoothPlastic)
	-- wire leads
	Build.block(m, V3(0.09, 0.7, 0.09), axis * CF(0.8, 0.95, 0.2) * ANG(0, 0, rad(-25)), C.Copper, M.Metal)
	Build.block(m, V3(0.09, 0.7, 0.09), axis * CF(-0.8, 0.95, -0.2) * ANG(0, 0, rad(25)), C.Copper, M.Metal)
	Build.ball(m, 0.18, axis * CF(0.95, 1.27, 0.2), C.Red)
	Build.ball(m, 0.18, axis * CF(-0.95, 1.27, -0.2), C.Black)
	-- label tag
	Build.block(m, V3(0.5, 0.3, 0.04), axis * CF(0, 0, -0.67), RGB(255, 255, 220))
end

----------------------------------------------------------------------
-- RARE
----------------------------------------------------------------------
builders.VintageRadio = function(m, o)
	o = o * ANG(0, rad(-18), rad(4))
	local wood = RGB(158, 98, 52)
	local trim = RGB(250, 232, 190)
	Build.block(m, V3(2.9, 1.8, 1.1), o, wood, M.Wood)
	-- rounded top
	Build.cylX(m, 2.9, 1.1, o * CF(0, 0.9, 0), wood, M.Wood)
	-- front panel
	local front = o * CF(0, -0.05, -0.56)
	Build.block(m, V3(2.6, 1.5, 0.05), front, RGB(80, 46, 26), M.SmoothPlastic)
	-- speaker grille
	Build.block(m, V3(1.3, 1.1, 0.04), front * CF(-0.55, 0, -0.03), RGB(60, 40, 30), M.Fabric)
	for i = 0, 6 do
		Build.shiny(Build.block(m, V3(0.06, 1.1, 0.06), front * CF(-1.1 + i * 0.18, 0, -0.06), trim, M.Metal))
	end
	-- tuning dial window
	Build.block(m, V3(0.95, 0.45, 0.05), front * CF(0.7, 0.28, -0.03), trim)
	Build.glow(Build.block(m, V3(0.85, 0.35, 0.05), front * CF(0.7, 0.28, -0.05), RGB(255, 200, 90), M.Neon))
	Build.block(m, V3(0.03, 0.35, 0.06), front * CF(0.6, 0.28, -0.07), C.Red)
	-- knobs
	for _, x in ipairs({ 0.45, 0.95 }) do
		Build.shiny(Build.cylZ(m, 0.18, 0.34, front * CF(x, -0.32, -0.08), trim, M.Metal))
		Build.block(m, V3(0.04, 0.14, 0.05), front * CF(x, -0.26, -0.18), RGB(60, 40, 30))
	end
	-- handle
	Build.shiny(Build.block(m, V3(0.12, 0.42, 0.14), o * CF(-0.75, 1.5, 0), C.Chrome, M.Metal))
	Build.shiny(Build.block(m, V3(0.12, 0.42, 0.14), o * CF(0.75, 1.5, 0), C.Chrome, M.Metal))
	Build.block(m, V3(1.65, 0.16, 0.24), o * CF(0, 1.72, 0), RGB(60, 40, 30), M.Leather)
	-- antenna
	local ant = o * CF(1.25, 1.35, 0.3) * ANG(0, 0, rad(-28))
	Build.shiny(Build.cylY(m, 1.6, 0.06, ant * CF(0, 0.8, 0), C.Chrome, M.Metal))
	Build.ball(m, 0.14, ant * CF(0, 1.62, 0), C.Chrome, M.Metal)
	-- feet + trim strips
	for _, x in ipairs({ -1.25, 1.25 }) do
		Build.block(m, V3(0.3, 0.14, 0.9), o * CF(x, -0.96, 0), RGB(40, 30, 24))
		Build.block(m, V3(0.06, 1.8, 1.12), o * CF(x * 1.15, 0, 0), trim, M.SmoothPlastic)
	end
end

builders.TrafficLight = function(m, o)
	o = o * ANG(rad(-75), rad(15), 0) -- fallen over
	local yellow = RGB(255, 196, 30)
	Build.block(m, V3(1.35, 3.7, 1.0), o, yellow, M.Metal)
	Build.block(m, V3(1.95, 4.2, 0.1), o * CF(0, 0, 0.55), RGB(28, 28, 32))
	Build.block(m, V3(2.05, 4.3, 0.06), o * CF(0, 0, 0.6), C.White)
	local lenses = {
		{ RGB(255, 50, 50), 1.18 },
		{ RGB(255, 200, 40), 0 },
		{ RGB(60, 255, 100), -1.18 },
	}
	for _, l in ipairs(lenses) do
		local cf = o * CF(0, l[2], -0.5)
		Build.cylZ(m, 0.1, 1.04, cf, RGB(30, 30, 34))
		Build.glow(Build.cylZ(m, 0.12, 0.86, cf * CF(0, 0, -0.04), l[1], M.Neon))
		Build.cylZ(m, 0.04, 0.6, cf * CF(0, 0, -0.1), l[1]:Lerp(C.White, 0.5), M.Glass)
		-- visor
		Build.block(m, V3(1.1, 0.06, 0.6), cf * CF(0, 0.52, -0.3) * ANG(rad(-8), 0, 0), RGB(30, 30, 34))
		Build.block(m, V3(0.06, 0.5, 0.6), cf * CF(0.55, 0.27, -0.3), RGB(30, 30, 34))
		Build.block(m, V3(0.06, 0.5, 0.6), cf * CF(-0.55, 0.27, -0.3), RGB(30, 30, 34))
	end
	-- mounting
	Build.cylY(m, 0.6, 0.5, o * CF(0, 2.1, 0), C.DarkSteel, M.Metal)
	Build.cylY(m, 0.2, 0.75, o * CF(0, 1.9, 0), C.DarkSteel, M.Metal)
	Build.bolt(m, o * CF(0.5, 1.7, -0.5) * ANG(rad(-90), 0, 0), 0.16)
	Build.bolt(m, o * CF(-0.5, 1.7, -0.5) * ANG(rad(-90), 0, 0), 0.16)
end

builders.EngineBlock = function(m, o)
	o = o * ANG(0, rad(25), 0)
	local block = RGB(80, 86, 98)
	local red = RGB(232, 40, 46)
	Build.block(m, V3(2.6, 1.3, 1.5), o * CF(0, -0.45, 0), block, M.Metal)
	Build.block(m, V3(2.4, 0.4, 1.2), o * CF(0, -1.25, 0), RGB(60, 64, 74), M.Metal)
	-- V heads and valve covers
	for _, side in ipairs({ -1, 1 }) do
		local head = o * CF(0, 0.4, side * 0.55) * ANG(rad(side * 38), 0, 0)
		Build.block(m, V3(2.5, 0.7, 0.7), head, block, M.Metal)
		local cover = head * CF(0, 0.45, 0)
		Build.shiny(Build.block(m, V3(2.3, 0.26, 0.56), cover, red, M.SmoothPlastic), 0.1)
		for i = 0, 5 do
			Build.block(m, V3(0.08, 0.1, 0.5), cover * CF(-0.9 + i * 0.36, 0.17, 0), RGB(250, 250, 250), M.Metal)
		end
		-- exhaust headers
		for i = 0, 3 do
			local x = -0.9 + i * 0.6
			Build.cylZ(m, 0.5, 0.24, o * CF(x, -0.05, side * 0.98), C.Steel, M.Metal)
		end
		Build.cylX(m, 2.3, 0.28, o * CF(0, -0.22, side * 1.18), C.Steel, M.Metal)
	end
	-- intake + air filter
	Build.block(m, V3(1.8, 0.4, 0.5), o * CF(0, 0.75, 0), C.Steel, M.Metal)
	Build.shiny(Build.cylY(m, 0.42, 1.25, o * CF(0, 1.15, 0), C.Chrome, M.Metal), 0.3)
	Build.cylY(m, 0.44, 0.9, o * CF(0, 1.15, 0), RGB(40, 40, 46), M.Fabric)
	Build.cylY(m, 0.1, 0.36, o * CF(0, 1.4, 0), C.Chrome, M.Metal)
	-- front pulleys + belt
	local front = o * CF(-1.38, -0.4, 0)
	Build.cylX(m, 0.18, 0.95, front, C.DarkSteel, M.Metal)
	Build.cylX(m, 0.2, 0.55, front * CF(0, 0.75, 0.25), C.DarkSteel, M.Metal)
	Build.cylX(m, 0.2, 0.5, front * CF(0, 0.55, -0.42), C.DarkSteel, M.Metal)
	Build.cylX(m, 0.22, 0.2, front, C.Chrome, M.Metal)
	Build.block(m, V3(0.12, 0.85, 0.1), front * CF(0, 0.38, 0.38), C.Black)
end

----------------------------------------------------------------------
-- EPIC
----------------------------------------------------------------------
builders.RobotHead = function(m, o)
	o = o * ANG(rad(-12), rad(-25), rad(14))
	local metal = RGB(150, 172, 210)
	local dark = RGB(44, 52, 70)
	Build.shiny(Build.block(m, V3(2.4, 2.1, 2.2), o, metal, M.Metal), 0.12)
	Build.block(m, V3(2.5, 0.25, 2.3), o * CF(0, 1.1, 0), RGB(120, 140, 180), M.Metal)
	Build.block(m, V3(1.6, 0.18, 1.6), o * CF(0, 1.3, 0), dark, M.Metal)
	-- face plate
	local face = o * CF(0, 0, -1.11)
	Build.block(m, V3(2.1, 1.75, 0.05), face, dark, M.SmoothPlastic)
	-- visor + eyes
	Build.block(m, V3(1.9, 0.65, 0.08), face * CF(0, 0.32, -0.05), RGB(20, 24, 34), M.Glass)
	for _, x in ipairs({ -0.5, 0.5 }) do
		Build.shiny(Build.cylZ(m, 0.1, 0.62, face * CF(x, 0.32, -0.1), C.Chrome, M.Metal))
		Build.glow(Build.cylZ(m, 0.12, 0.46, face * CF(x, 0.32, -0.12), RGB(60, 240, 255), M.Neon))
	end
	-- mouth grille
	for i = 0, 4 do
		Build.shiny(Build.block(m, V3(0.12, 0.42, 0.08), face * CF(-0.48 + i * 0.24, -0.48, -0.06), C.Chrome, M.Metal))
	end
	-- ears
	for _, side in ipairs({ -1, 1 }) do
		local ear = o * CF(side * 1.25, 0.05, 0)
		Build.cylX(m, 0.24, 1.0, ear, dark, M.Metal)
		Build.shiny(Build.cylX(m, 0.3, 0.55, ear * CF(side * 0.06, 0, 0), C.Chrome, M.Metal))
		Build.glow(Build.cylX(m, 0.32, 0.25, ear * CF(side * 0.08, 0, 0), RGB(255, 80, 120), M.Neon))
		-- cheek vents
		for i = 0, 2 do
			Build.block(m, V3(0.06, 0.08, 1.4), o * CF(side * 1.21, -0.55 - i * 0.18, 0), dark)
		end
	end
	-- antenna
	Build.cylY(m, 0.9, 0.1, o * CF(0.5, 1.75, 0.2), C.Chrome, M.Metal)
	Build.glow(Build.ball(m, 0.3, o * CF(0.5, 2.25, 0.2), RGB(255, 60, 80), M.Neon))
	Build.cylY(m, 0.5, 0.08, o * CF(-0.55, 1.6, 0.3), C.Chrome, M.Metal)
	Build.ball(m, 0.18, o * CF(-0.55, 1.88, 0.3), C.Chrome, M.Metal)
	-- corner bolts
	for _, x in ipairs({ -1.0, 1.0 }) do
		for _, y in ipairs({ -0.85, 0.85 }) do
			Build.bolt(m, face * CF(x, y, -0.04) * ANG(rad(-90), 0, 0), 0.14)
		end
	end
	-- neck stub
	Build.cylY(m, 0.4, 1.0, o * CF(0, -1.2, 0), dark, M.Metal)
	Build.torus(m, o * CF(0, -1.25, 0), 0.5, 0.06, 12, C.Chrome, M.Metal)
end

builders.JetTurbine = function(m, o)
	o = o * ANG(0, rad(30), rad(-8))
	local white = RGB(236, 240, 246)
	Build.shiny(Build.cylX(m, 3.4, 2.4, o, white, M.Metal), 0.15)
	-- intake lip
	local intake = o * CF(-1.75, 0, 0) * ANG(0, 0, rad(90))
	Build.torus(m, intake, 1.18, 0.16, 20, C.Chrome, M.Metal)
	Build.cylX(m, 0.1, 2.15, o * CF(-1.62, 0, 0), RGB(30, 32, 40))
	-- fan blades
	local hub = o * CF(-1.68, 0, 0)
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2
		Build.block(m, V3(0.06, 0.95, 0.24), hub * ANG(a, 0, 0) * CF(0, 0.55, 0) * ANG(0, rad(35), 0), RGB(160, 168, 182), M.Metal)
	end
	-- spinner
	Build.shiny(Build.cylX(m, 0.2, 0.62, hub * CF(-0.05, 0, 0), C.Chrome, M.Metal))
	Build.shiny(Build.cylX(m, 0.2, 0.44, hub * CF(-0.22, 0, 0), C.Chrome, M.Metal))
	Build.shiny(Build.ball(m, 0.36, hub * CF(-0.34, 0, 0), C.Chrome, M.Metal))
	-- body bands
	for _, x in ipairs({ -0.9, 0, 0.9 }) do
		Build.cylX(m, 0.12, 2.46, o * CF(x, 0, 0), RGB(60, 120, 230), M.SmoothPlastic)
	end
	-- exhaust nozzle
	Build.cylX(m, 0.7, 1.8, o * CF(1.95, 0, 0), RGB(70, 72, 80), M.Metal)
	Build.cylX(m, 0.4, 1.4, o * CF(2.3, 0, 0), RGB(50, 52, 60), M.Metal)
	Build.glow(Build.cylX(m, 0.42, 1.0, o * CF(2.34, 0, 0), RGB(255, 140, 40), M.Neon))
	-- pylon
	Build.block(m, V3(1.6, 0.6, 0.35), o * CF(0.1, 1.35, 0), white, M.Metal)
	Build.wedge(m, V3(0.35, 0.6, 0.6), o * CF(1.1, 1.35, 0) * ANG(0, rad(90), 0), white, M.Metal)
	-- warning stripe
	Build.block(m, V3(0.6, 0.08, 2.0), o * CF(-0.5, 1.15, 0), C.Red)
end

----------------------------------------------------------------------
-- LEGENDARY
----------------------------------------------------------------------
builders.GoldenWatch = function(m, o)
	o = o * ANG(rad(-60), rad(15), 0)
	local gold = RGB(255, 196, 48)
	local face = o
	Build.shiny(Build.cylY(m, 0.42, 3.0, face, gold, M.Metal), 0.32)
	Build.torus(m, face * CF(0, 0.2, 0), 1.42, 0.12, 24, RGB(255, 220, 110), M.Metal)
	Build.cylY(m, 0.44, 2.55, face, RGB(255, 248, 228), M.SmoothPlastic)
	Build.cylY(m, 0.46, 2.5, face, RGB(200, 230, 255), M.Glass).Transparency = 0.7
	-- hour markers
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local size = (i % 3 == 0) and V3(0.36, 0.06, 0.12) or V3(0.2, 0.06, 0.08)
		Build.block(m, size, face * ANG(0, a, 0) * CF(1.0, 0.23, 0), (i % 3 == 0) and gold or RGB(60, 50, 40), M.Metal)
	end
	-- sub dial
	Build.cylY(m, 0.02, 0.6, face * CF(0, 0.22, 0.55), RGB(240, 226, 196))
	Build.torus(m, face * CF(0, 0.23, 0.55), 0.3, 0.025, 12, gold, M.Metal)
	-- hands
	Build.block(m, V3(0.08, 0.05, 0.9), face * CF(0, 0.25, -0.38), RGB(30, 30, 40), M.Metal)
	Build.block(m, V3(0.6, 0.05, 0.08), face * ANG(0, rad(-30), 0) * CF(0.28, 0.26, 0), RGB(30, 30, 40), M.Metal)
	Build.block(m, V3(0.02, 0.05, 1.05), face * ANG(0, rad(65), 0) * CF(0, 0.27, -0.4), C.Red, M.SmoothPlastic)
	Build.cylY(m, 0.08, 0.16, face * CF(0, 0.28, 0), gold, M.Metal)
	-- crown + bow
	Build.shiny(Build.cylZ(m, 0.3, 0.32, face * CF(0, 0, -1.62), gold, M.Metal), 0.3)
	Build.cylZ(m, 0.22, 0.42, face * CF(0, 0, -1.84), RGB(255, 214, 90), M.Metal)
	Build.torus(m, face * CF(0, 0, -2.18) * ANG(0, 0, rad(90)), 0.32, 0.07, 12, gold, M.Metal)
	-- chain
	local link = face * CF(0, -0.05, -2.5)
	for i = 0, 5 do
		local cf = link * CF(0.35 * math.sin(i * 0.7), -0.06 * i, -0.36 * i) * ANG(0, 0, (i % 2 == 0) and rad(90) or 0)
		Build.torus(m, cf * ANG(rad(90), 0, 0), 0.16, 0.04, 8, gold, M.Metal)
	end
	-- engraving gems
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		Build.glow(Build.ball(m, 0.18, face * ANG(0, a, 0) * CF(1.45, 0.12, 0), RGB(255, 40, 90), M.Neon))
	end
end

builders.ReactorCore = function(m, o)
	o = o * ANG(rad(-10), 0, rad(70))
	local dark = RGB(56, 60, 72)
	local glow = RGB(70, 255, 190)
	Build.cylY(m, 3.0, 1.45, o, RGB(170, 255, 230), M.Glass).Transparency = 0.45
	Build.glow(Build.cylY(m, 2.8, 0.85, o, glow, M.Neon))
	for _, y in ipairs({ -1.0, 0, 1.0 }) do
		Build.glow(Build.cylY(m, 0.16, 1.5, o * CF(0, y, 0), RGB(120, 255, 220), M.Neon))
	end
	-- caps
	for _, side in ipairs({ -1, 1 }) do
		local cap = o * CF(0, side * 1.6, 0)
		Build.cylY(m, 0.42, 2.2, cap, dark, M.Metal)
		Build.shiny(Build.cylY(m, 0.24, 1.6, cap * CF(0, side * 0.3, 0), C.Chrome, M.Metal))
		Build.cylY(m, 0.3, 0.6, cap * CF(0, side * 0.5, 0), dark, M.Metal)
		-- hazard band
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			Build.block(m, V3(0.2, 0.2, 0.54), cap * ANG(0, a, 0) * CF(1.06, 0, 0), (i % 2 == 0) and C.Yellow or C.Black)
		end
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2 + 0.2
			Build.bolt(m, cap * ANG(0, a, 0) * CF(0.85, side * 0.22, 0) * ANG(side < 0 and math.pi or 0, 0, 0), 0.16)
		end
	end
	-- cage bars
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		Build.shiny(Build.cylY(m, 3.0, 0.14, o * ANG(0, a, 0) * CF(0.9, 0, 0), C.Chrome, M.Metal))
	end
	-- side port
	Build.block(m, V3(0.6, 0.8, 0.5), o * CF(1.25, 0.2, 0), dark, M.Metal)
	Build.glow(Build.block(m, V3(0.08, 0.5, 0.3), o * CF(1.56, 0.2, 0), RGB(255, 60, 60), M.Neon))
end

----------------------------------------------------------------------
-- MYTHIC
----------------------------------------------------------------------
builders.HoverDrive = function(m, o)
	o = o * ANG(rad(14), 0, rad(-8))
	local silver = RGB(210, 216, 232)
	local pink = RGB(255, 60, 200)
	Build.shiny(Build.cylY(m, 0.28, 4.8, o, silver, M.Metal), 0.25)
	Build.shiny(Build.cylY(m, 0.42, 4.0, o * CF(0, 0.3, 0), silver, M.Metal), 0.25)
	Build.cylY(m, 0.36, 3.0, o * CF(0, 0.66, 0), RGB(170, 176, 200), M.Metal)
	Build.cylY(m, 0.34, 3.6, o * CF(0, -0.28, 0), RGB(150, 156, 180), M.Metal)
	Build.glow(Build.cylY(m, 0.1, 2.4, o * CF(0, -0.48, 0), RGB(80, 255, 255), M.Neon))
	-- neon rim ring
	for _, p in ipairs(Build.torus(m, o * CF(0, 0.05, 0), 2.38, 0.09, 26, pink, M.Neon)) do
		Build.glow(p)
	end
	-- rim lights
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		Build.glow(
			Build.ball(m, 0.24, o * ANG(0, a, 0) * CF(2.0, 0.42, 0), (i % 2 == 0) and RGB(80, 255, 255) or RGB(255, 240, 80), M.Neon)
		)
	end
	-- dome
	local dome = Build.ball(m, 2.0, o * CF(0, 0.95, 0), RGB(120, 230, 255), M.Glass)
	dome.Transparency = 0.35
	Build.glow(Build.ball(m, 0.7, o * CF(0, 1.05, 0), RGB(120, 255, 140), M.Neon))
	-- fins
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		Build.wedge(m, V3(0.12, 0.6, 1.0), o * ANG(0, a, 0) * CF(0, -0.55, 1.6), silver, M.Metal)
	end
	-- thrusters
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2 + math.pi / 3
		local t = o * ANG(0, a, 0) * CF(1.1, -0.55, 0)
		Build.cylY(m, 0.36, 0.55, t, RGB(80, 84, 100), M.Metal)
		Build.glow(Build.cylY(m, 0.38, 0.32, t * CF(0, -0.02, 0), RGB(255, 120, 255), M.Neon))
	end
end

builders.TitanCrystal = function(m, o)
	o = o * ANG(0, 0, rad(-12))
	local gold = RGB(255, 200, 64)
	local crystal = RGB(255, 90, 210)
	-- pedestal
	local base = o * CF(0, -1.85, 0)
	Build.shiny(Build.cylY(m, 0.4, 2.6, base, gold, M.Metal), 0.3)
	Build.cylY(m, 0.3, 2.1, base * CF(0, 0.32, 0), RGB(60, 40, 90), M.Marble)
	Build.shiny(Build.cylY(m, 0.18, 1.6, base * CF(0, 0.55, 0), gold, M.Metal), 0.3)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		Build.glow(Build.block(m, V3(0.08, 0.18, 0.28), base * ANG(0, a, 0) * CF(1.05, 0.32, 0), RGB(120, 230, 255), M.Neon))
	end
	-- main crystal: prism + gabled tips
	local c = o * CF(0, 0.15, 0) * ANG(0, rad(45), 0)
	local main = Build.glow(Build.block(m, V3(1.15, 2.4, 1.15), c, crystal, M.Neon))
	main.Transparency = 0.12
	for _, side in ipairs({ 1, -1 }) do
		local tip = c * CF(0, side * 1.6, 0) * ANG(side < 0 and math.pi or 0, 0, 0)
		local w1 = Build.wedge(m, V3(1.15, 0.8, 0.575), tip * CF(0, 0, -0.2875), RGB(255, 140, 230), M.Neon)
		local w2 = Build.wedge(m, V3(1.15, 0.8, 0.575), tip * CF(0, 0, 0.2875) * ANG(0, math.pi, 0), RGB(255, 140, 230), M.Neon)
		Build.glow(w1)
		Build.glow(w2)
	end
	-- inner core
	Build.glow(Build.block(m, V3(0.5, 1.6, 0.5), c, RGB(255, 255, 255), M.Neon))
	-- side shards
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local s = o * ANG(0, a, 0) * CF(0.85, -0.9, 0) * ANG(0, 0, rad(-28)) * ANG(0, rad(45), 0)
		local shard = Build.glow(Build.block(m, V3(0.42, 1.1, 0.42), s, RGB(160, 110, 255), M.Neon))
		shard.Transparency = 0.1
		Build.glow(Build.block(m, V3(0.3, 0.3, 0.3), s * CF(0, 0.62, 0) * ANG(rad(45), 0, rad(45)), RGB(200, 160, 255), M.Neon))
	end
	-- golden claws
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		local claw = o * ANG(0, a, 0) * CF(0.7, -0.95, 0)
		Build.shiny(Build.block(m, V3(0.18, 1.0, 0.24), claw * ANG(0, 0, rad(-15)), gold, M.Metal), 0.3)
		Build.shiny(Build.block(m, V3(0.16, 0.6, 0.22), claw * CF(-0.05, 0.75, 0) * ANG(0, 0, rad(18)), gold, M.Metal), 0.3)
		Build.ball(m, 0.22, claw * CF(-0.15, 1.05, 0), gold, M.Metal)
	end
end

----------------------------------------------------------------------
-- Clean / dirty passes
----------------------------------------------------------------------
local RUST = RGB(124, 72, 38)
local MUD = RGB(92, 70, 46)

local function hash(n: number): number
	local x = math.sin(n * 12.9898) * 43758.5453
	return x - math.floor(x)
end

local function applyDirty(model: Model)
	local i = 0
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Hitbox" then
			i += 1
			local roll = hash(i)
			local dirt = (roll > 0.5) and RUST or MUD
			p.Color = p.Color:Lerp(dirt, 0.5 + roll * 0.25)
			p.Reflectance = 0
			if p.Material == Enum.Material.Metal or p.Material == Enum.Material.SmoothPlastic or p.Material == Enum.Material.Foil then
				p.Material = (roll > 0.35) and Enum.Material.CorrodedMetal or Enum.Material.Slate
			elseif p.Material == Enum.Material.Neon then
				p.Material = Enum.Material.SmoothPlastic
				p.Color = p.Color:Lerp(RGB(40, 36, 32), 0.55)
			elseif p.Material == Enum.Material.Glass then
				p.Transparency = math.min(p.Transparency, 0.2)
				p.Material = Enum.Material.Slate
			end
		end
	end
end

local function applyClean(model: Model)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local shiny = p:GetAttribute("Shiny")
			if typeof(shiny) == "number" then
				p.Reflectance = shiny
			end
		end
	end
end

-- Builds the model. `clean` = true returns the polished version.
function ScrapModels.create(scrapId: string, clean: boolean): Model
	local def = Config.Scraps[scrapId]
	local model = Instance.new("Model")
	model.Name = scrapId
	local builder = builders[scrapId]
	if builder then
		builder(model, CFrame.new())
	else
		Build.block(model, Vector3.new(2, 2, 2), CFrame.new(), C.Steel, Enum.Material.Metal)
	end
	if clean then
		applyClean(model)
	else
		applyDirty(model)
	end
	local bbCf, bbSize = model:GetBoundingBox()
	local pad = def and math.max(0, def.Size * 0.08) or 0.2
	local hitbox = Build.hitbox(model, bbSize + Vector3.new(pad, pad, pad), CFrame.new(bbCf.Position))
	model.PrimaryPart = hitbox
	model:SetAttribute("ScrapId", scrapId)
	model:SetAttribute("Clean", clean)
	return model
end

-- Glow parts (neon that only shines once clean) — lets the client light up a
-- cleaned model in the minigame.
function ScrapModels.hasBuilder(scrapId: string): boolean
	return builders[scrapId] ~= nil
end

return ScrapModels
