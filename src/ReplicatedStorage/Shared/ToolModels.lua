-- ToolModels: detailed multi-part models for the collection tools.
-- Every model is built around a "Handle" (the grip) at the origin, with the
-- business end pointing up the Handle's +Y axis, which is how Roblox holds a
-- tool with the default Grip.

local Build = require(script.Parent.Build)

local C = Build.Colors
local M = Enum.Material
local rad = math.rad
local CF = CFrame.new
local ANG = CFrame.Angles
local V3 = Vector3.new
local RGB = Color3.fromRGB

local ToolModels = {}

local builders: { [string]: (Model, BasePart, CFrame) -> () } = {}

local function grip(m: Model, color: Color3): BasePart
	local handle = Build.cylY(m, 1.3, 0.36, CFrame.new(), color, M.Rubber)
	handle.Name = "Handle"
	for i = -2, 2 do
		Build.cylY(m, 0.08, 0.4, CF(0, i * 0.24, 0), RGB(25, 25, 28), M.Rubber)
	end
	Build.cylY(m, 0.16, 0.46, CF(0, -0.68, 0), RGB(60, 60, 66), M.Metal)
	return handle
end

builders.RustyGrabber = function(m, _h, o)
	local rust = RGB(196, 112, 58)
	Build.cylY(m, 0.16, 0.44, o * CF(0, 0.7, 0), C.DarkSteel, M.Metal)
	Build.cylY(m, 3.0, 0.16, o * CF(0, 2.2, 0), rust, M.CorrodedMetal)
	-- trigger
	Build.block(m, V3(0.12, 0.4, 0.3), o * CF(0, 0.3, -0.28) * ANG(rad(-15), 0, 0), RGB(230, 70, 40), M.SmoothPlastic)
	-- pull cable
	Build.cylY(m, 2.9, 0.05, o * CF(0, 2.2, -0.12), C.Steel, M.Metal)
	-- claw head
	local head = o * CF(0, 3.75, 0)
	Build.block(m, V3(0.55, 0.3, 0.36), head, C.DarkSteel, M.Metal)
	Build.cylX(m, 0.6, 0.18, head, C.Steel, M.Metal)
	for _, side in ipairs({ -1, 1 }) do
		local jaw = head * CF(side * 0.22, 0.32, 0) * ANG(0, 0, rad(-side * 18))
		Build.block(m, V3(0.12, 0.6, 0.3), jaw, rust, M.CorrodedMetal)
		Build.wedge(m, V3(0.3, 0.3, 0.12), jaw * CF(-side * 0.06, 0.38, 0) * ANG(0, rad(side * 90), 0), C.Steel, M.Metal)
	end
	-- spring
	for i = 0, 4 do
		Build.torus(m, o * CF(0, 3.2 + i * 0.07, 0), 0.13, 0.025, 8, C.Steel, M.Metal)
	end
	-- duct tape patch
	Build.cylY(m, 0.3, 0.2, o * CF(0, 1.8, 0), RGB(170, 170, 176), M.Fabric)
end

builders.SteelCrowbar = function(m, _h, o)
	local red = RGB(226, 40, 46)
	Build.cylY(m, 3.2, 0.24, o * CF(0, 2.15, 0), red, M.Metal)
	-- hex facets
	Build.block(m, V3(0.18, 3.2, 0.18), o * CF(0, 2.15, 0) * ANG(0, rad(45), 0), RGB(200, 30, 36), M.Metal)
	-- hook arc
	local base = o * CF(0, 3.75, 0)
	local segs = 6
	for i = 0, segs - 1 do
		local a = (i + 0.5) / segs * math.pi
		local p = base * CF(0.45 - math.cos(a) * 0.45, math.sin(a) * 0.45, 0) * ANG(0, 0, a - math.pi / 2)
		Build.block(m, V3(0.24, 0.3, 0.24), p, red, M.Metal)
	end
	-- split claw tip
	local tip = base * CF(0.9, -0.12, 0) * ANG(0, 0, rad(-12))
	Build.shiny(Build.wedge(m, V3(0.1, 0.4, 0.22), tip * CF(0, 0, 0.07), C.Chrome, M.Metal))
	Build.shiny(Build.wedge(m, V3(0.1, 0.4, 0.22), tip * CF(0, 0, -0.07), C.Chrome, M.Metal))
	-- grip collar
	Build.shiny(Build.cylY(m, 0.14, 0.34, o * CF(0, 0.72, 0), C.Chrome, M.Metal))
	-- brand stripe
	Build.cylY(m, 0.18, 0.27, o * CF(0, 1.6, 0), C.White, M.SmoothPlastic)
end

builders.MagnetWand = function(m, h, o)
	Build.shiny(Build.cylY(m, 2.2, 0.22, o * CF(0, 1.8, 0), C.Chrome, M.Metal), 0.25)
	Build.cylY(m, 0.24, 0.42, o * CF(0, 0.75, 0), RGB(40, 90, 220), M.SmoothPlastic)
	for i = 0, 3 do
		Build.cylY(m, 0.06, 0.3, o * CF(0, 1.2 + i * 0.35, 0), RGB(60, 140, 255), M.Neon)
	end
	-- horseshoe magnet
	local base = o * CF(0, 3.0, 0)
	local red = RGB(232, 44, 50)
	for i = 0, 6 do
		local a = math.pi + (i / 6) * math.pi
		local p = base * CF(math.cos(a) * 0.5, math.sin(a) * 0.5 + 0.5, 0) * ANG(0, 0, a + math.pi / 2)
		Build.block(m, V3(0.28, 0.3, 0.38), p, red, M.SmoothPlastic)
	end
	for _, side in ipairs({ -1, 1 }) do
		Build.block(m, V3(0.3, 0.7, 0.38), base * CF(side * 0.5, 0.85, 0), red, M.SmoothPlastic)
		Build.shiny(Build.block(m, V3(0.32, 0.3, 0.4), base * CF(side * 0.5, 1.33, 0), C.Chrome, M.Metal), 0.3)
	end
	-- energy orb between the poles
	local orb = Build.ball(m, 0.42, base * CF(0, 1.35, 0), RGB(90, 200, 255), M.Neon)
	orb.Transparency = 0.15
	orb.Name = "Effect"
	Build.light(orb, RGB(90, 200, 255), 8, 2)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(RGB(120, 220, 255))
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(0.4, 0.7)
	sparkle.Rate = 12
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Parent = orb
	local _ = h
end

builders.HydraulicClaw = function(m, _h, o)
	local yellow = RGB(255, 196, 30)
	-- piston housing
	Build.cylY(m, 1.6, 0.5, o * CF(0, 1.5, 0), yellow, M.Metal)
	Build.cylY(m, 0.16, 0.6, o * CF(0, 0.75, 0), C.Black, M.Metal)
	Build.cylY(m, 0.16, 0.6, o * CF(0, 2.3, 0), C.Black, M.Metal)
	Build.shiny(Build.cylY(m, 1.1, 0.24, o * CF(0, 2.85, 0), C.Chrome, M.Metal), 0.35)
	-- hazard stripes
	for i = 0, 3 do
		Build.block(m, V3(0.52, 0.1, 0.52), o * CF(0, 1.0 + i * 0.32, 0) * ANG(0, 0, rad(25)), C.Black, M.SmoothPlastic)
	end
	-- hoses
	for _, side in ipairs({ -1, 1 }) do
		Build.cylY(m, 2.1, 0.1, o * CF(side * 0.34, 1.9, 0.1) * ANG(0, 0, rad(side * 4)), C.Black, M.Rubber)
	end
	-- claw head
	local head = o * CF(0, 3.5, 0)
	Build.block(m, V3(0.9, 0.36, 0.9), head, C.DarkSteel, M.DiamondPlate)
	Build.cylY(m, 0.4, 0.5, head * CF(0, 0.3, 0), yellow, M.Metal)
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		local finger = head * ANG(0, a, 0) * CF(0.36, 0.4, 0) * ANG(0, 0, rad(-25))
		Build.block(m, V3(0.18, 0.7, 0.24), finger, yellow, M.Metal)
		local tipCf = finger * CF(-0.1, 0.5, 0) * ANG(0, 0, rad(50))
		Build.block(m, V3(0.16, 0.45, 0.22), tipCf, C.DarkSteel, M.Metal)
		Build.ball(m, 0.24, finger * CF(0, -0.32, 0), C.Steel, M.Metal)
	end
end

builders.PlasmaCutter = function(m, _h, o)
	local body = RGB(40, 36, 60)
	local pink = RGB(255, 60, 200)
	Build.block(m, V3(0.55, 1.2, 0.7), o * CF(0, 1.3, 0), body, M.Metal)
	Build.wedge(m, V3(0.55, 0.4, 0.7), o * CF(0, 2.1, 0), body, M.Metal)
	for _, side in ipairs({ -1, 1 }) do
		Build.block(m, V3(0.06, 1.0, 0.1), o * CF(side * 0.29, 1.3, -0.2), pink, M.Neon)
	end
	Build.block(m, V3(0.6, 0.12, 0.75), o * CF(0, 0.75, 0), C.Chrome, M.Metal)
	-- battery cell
	Build.cylY(m, 0.8, 0.3, o * CF(0, 1.3, 0.48), RGB(80, 255, 220), M.Neon)
	-- emitter rings
	for i = 0, 2 do
		Build.shiny(Build.cylY(m, 0.1, 0.5 - i * 0.08, o * CF(0, 2.4 + i * 0.18, 0), C.Chrome, M.Metal), 0.3)
	end
	-- plasma blade
	local blade = Build.cylY(m, 2.4, 0.22, o * CF(0, 3.9, 0), pink, M.Neon)
	blade.Transparency = 0.15
	blade.Name = "Effect"
	local inner = Build.cylY(m, 2.4, 0.1, o * CF(0, 3.9, 0), RGB(255, 230, 250), M.Neon)
	inner.Transparency = 0
	Build.light(blade, pink, 10, 3)
end

builders.QuantumVacuum = function(m, _h, o)
	local shell = RGB(236, 240, 250)
	local teal = RGB(60, 255, 220)
	-- body
	Build.shiny(Build.cylY(m, 1.4, 0.6, o * CF(0, 1.35, 0), shell, M.Metal), 0.2)
	Build.cylY(m, 0.2, 0.7, o * CF(0, 0.7, 0), RGB(40, 44, 60), M.Metal)
	-- side tank
	local tank = o * CF(0.55, 1.3, 0.1)
	Build.cylY(m, 1.1, 0.42, tank, RGB(200, 255, 245), M.Glass).Transparency = 0.4
	Build.cylY(m, 0.9, 0.3, tank, teal, M.Neon)
	Build.cylY(m, 0.1, 0.46, tank * CF(0, 0.58, 0), C.Chrome, M.Metal)
	Build.cylY(m, 0.1, 0.46, tank * CF(0, -0.58, 0), C.Chrome, M.Metal)
	-- nozzle (flared)
	Build.cylY(m, 0.5, 0.5, o * CF(0, 2.3, 0), RGB(40, 44, 60), M.Metal)
	Build.cylY(m, 0.3, 0.8, o * CF(0, 2.65, 0), shell, M.Metal)
	Build.cylY(m, 0.3, 1.1, o * CF(0, 2.92, 0), shell, M.Metal)
	Build.cylY(m, 0.32, 0.85, o * CF(0, 2.95, 0), RGB(20, 22, 30), M.SmoothPlastic)
	-- floating quantum ring
	local ring = Build.torus(m, o * CF(0, 3.45, 0), 0.62, 0.07, 14, teal, M.Neon)
	for _, p in ipairs(ring) do
		p.Name = "Effect"
	end
	local core = Build.ball(m, 0.36, o * CF(0, 3.45, 0), RGB(255, 255, 255), M.Neon)
	core.Name = "Effect"
	Build.light(core, teal, 10, 3)
end

-- Returns (model, handle). Parts are anchored; the server welds them for a Tool.
function ToolModels.create(toolId: string): (Model, BasePart)
	local m = Instance.new("Model")
	m.Name = toolId
	local colors = {
		RustyGrabber = RGB(70, 60, 50),
		SteelCrowbar = RGB(30, 60, 160),
		MagnetWand = RGB(40, 40, 50),
		HydraulicClaw = RGB(40, 40, 46),
		PlasmaCutter = RGB(60, 30, 80),
		QuantumVacuum = RGB(30, 40, 60),
	}
	local handle = grip(m, colors[toolId] or RGB(40, 40, 46))
	local builder = builders[toolId]
	if builder then
		builder(m, handle, CFrame.new())
	end
	m.PrimaryPart = handle
	return m, handle
end

return ToolModels
