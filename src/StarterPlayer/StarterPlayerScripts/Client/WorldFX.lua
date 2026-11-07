-- WorldFX: everything 3D the client handles locally — scrap pop-in, break and
-- collect effects, per-player machine holograms, gates, radar markers, the
-- guide beam and opening menus from world prompts.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ScrapModels = require(ReplicatedStorage.Shared.ScrapModels)
local State = require(script.Parent.State)
local UIKit = require(script.Parent.UIKit)
local HUD = require(script.Parent.HUD)
local Sound = require(script.Parent.Sound)

local WorldFX = {}

local player = Players.LocalPlayer
local scrapsFolder: Folder
local hub: Instance
local openPanel: (string, any?) -> ()

local machineOriginals: { [BasePart]: { Color: Color3, Material: Enum.Material, Transparency: number } } = {}
local machineInfo: { [string]: { Name: TextLabel, Level: TextLabel } } = {}
local radarMarkers: { [Model]: BillboardGui } = {}

local function rootPart(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function tempPart(cf: CFrame): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = cf
	p.Parent = workspace.CurrentCamera
	return p
end

----------------------------------------------------------------------
-- Scrap spawn pop-in
----------------------------------------------------------------------
local function popIn(m: Model)
	task.defer(function()
		if not m.Parent then
			return
		end
		local ok = pcall(function()
			m:ScaleTo(0.05)
		end)
		if not ok then
			return
		end
		local v = Instance.new("NumberValue")
		v.Value = 0.05
		v.Changed:Connect(function(x)
			if m.Parent then
				pcall(function()
					m:ScaleTo(math.max(0.05, x))
				end)
			end
		end)
		local tw = TweenService:Create(v, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 })
		tw:Play()
		tw.Completed:Connect(function()
			v:Destroy()
		end)
	end)
end

----------------------------------------------------------------------
-- FX events
----------------------------------------------------------------------
local function breakFX(position: Vector3, rarityId: string)
	local rarity = Config.Rarities[rarityId] or Config.Rarities.Common
	local p = tempPart(CFrame.new(position))
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(rarity.Color, rarity.Color2)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(12, 24)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -25, 0)
	e.LightEmission = 1
	e.Rate = 0
	e.Parent = p
	e:Emit(20 + rarity.Order * 8)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(180, 160, 130))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
	smoke.Transparency = NumberSequence.new(0.4, 1)
	smoke.Lifetime = NumberRange.new(0.6, 1)
	smoke.Speed = NumberRange.new(4, 8)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Rate = 0
	smoke.Parent = p
	smoke:Emit(8)
	if rarity.Order >= 4 then
		local flash = Instance.new("PointLight")
		flash.Color = rarity.Color
		flash.Range = 24
		flash.Brightness = 6
		flash.Parent = p
		TweenService:Create(flash, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	end
	task.delay(1.5, function()
		p:Destroy()
	end)
end

-- A small copy of the scrap flies into the player.
local function collectFX(scrapId: string, position: Vector3?)
	local root = rootPart()
	if not root or not position then
		return
	end
	local model = ScrapModels.create(scrapId, false)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CastShadow = false
		end
	end
	model:PivotTo(CFrame.new(position))
	model.Parent = workspace.CurrentCamera
	local start = position
	local t0 = os.clock()
	local duration = 0.45
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - t0) / duration, 0, 1)
		local r = rootPart()
		if not r or a >= 1 then
			conn:Disconnect()
			model:Destroy()
			return
		end
		local target = r.Position + Vector3.new(0, 1, 0)
		local pos = start:Lerp(target, a * a) + Vector3.new(0, math.sin(a * math.pi) * 5, 0)
		pcall(function()
			model:ScaleTo(math.max(0.1, 1 - a * 0.85))
		end)
		model:PivotTo(CFrame.new(pos) * CFrame.Angles(a * 8, a * 10, 0))
	end)
end

function WorldFX.onFX(payload)
	local kind = payload.Kind
	if kind == "Break" then
		breakFX(payload.Position, payload.Rarity)
	elseif kind == "Collect" then
		collectFX(payload.ScrapId, payload.Position)
	end
end

----------------------------------------------------------------------
-- Machines: hologram when not owned, alive when owned
----------------------------------------------------------------------
local function setupMachines()
	local bay = hub:WaitForChild("MachineBay")
	for _, pad in ipairs(bay:GetChildren()) do
		local id = pad:GetAttribute("MachineId")
		local machine = pad:FindFirstChild("Machine")
		if id and machine and Config.Machines[id] then
			for _, d in ipairs(machine:GetDescendants()) do
				if d:IsA("BasePart") then
					machineOriginals[d] = { Color = d.Color, Material = d.Material, Transparency = d.Transparency }
				end
			end
			-- floating info sign
			local anchor = pad:FindFirstChild("InfoAnchor") :: BasePart
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(260, 90)
			bb.LightInfluence = 0
			bb.MaxDistance = 90
			bb.Adornee = anchor
			bb.Parent = player:WaitForChild("PlayerGui")
			local def = Config.Machines[id]
			local name = UIKit.label(bb, {
				Text = def.Emoji .. " " .. def.Name,
				Size = UDim2.new(1, 0, 0, 40),
				TextColor3 = UIKit.lighten(def.Color, 0.2),
				StrokeThickness = 3.5,
			})
			local level =
				UIKit.label(bb, { Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 42), StrokeThickness = 3 })
			machineInfo[id] = { Name = name, Level = level }
		end
	end
end

local function refreshMachines(d)
	local bay = hub:FindFirstChild("MachineBay")
	if not bay then
		return
	end
	for _, pad in ipairs(bay:GetChildren()) do
		local id = pad:GetAttribute("MachineId")
		local machine = pad:FindFirstChild("Machine")
		if id and machine and Config.Machines[id] then
			local lvl = d.Machines[id] or 0
			local owned = lvl > 0
			machine:SetAttribute("Owned", owned)
			for _, part in ipairs(machine:GetDescendants()) do
				if part:IsA("BasePart") then
					local orig = machineOriginals[part]
					if orig and part.Name ~= "Pivot" then
						if owned then
							part.Color = orig.Color
							part.Material = orig.Material
							part.Transparency = orig.Transparency
						else
							part.Material = Enum.Material.ForceField
							part.Color = Color3.fromRGB(90, 200, 255)
							part.Transparency = 0
						end
					end
				elseif part:IsA("ParticleEmitter") and part.Name == "MachineFX" then
					part.Enabled = owned
				end
			end
			local info = machineInfo[id]
			if info then
				if owned then
					info.Level.Text = lvl >= Config.Machines[id].MaxLevel and "⭐ MAX LEVEL ⭐" or ("Level " .. lvl)
					info.Level.TextColor3 = UIKit.Colors.Yellow
				else
					info.Level.Text = "Build for " .. Format.cash(Config.MachineCost(id, 0))
					info.Level.TextColor3 = UIKit.Colors.Cash
				end
			end
		end
	end
end

-- Spins every Rotor model on owned machines (plus the Teleporter) and the
-- scrap sitting on wash stations.
local function spinLoop(dt: number)
	local bay = hub:FindFirstChild("MachineBay")
	if bay then
		for _, pad in ipairs(bay:GetChildren()) do
			local machine = pad:FindFirstChild("Machine")
			if machine and (machine:GetAttribute("Owned") or pad:GetAttribute("MachineId") == "Teleporter") then
				for _, r in ipairs(machine:GetChildren()) do
					if r:IsA("Model") and r.Name == "Rotor" and r.PrimaryPart then
						local speed = (r:GetAttribute("Speed") :: number?) or 1
						local axis = r:GetAttribute("Axis")
						local rot
						if axis == "X" then
							rot = CFrame.Angles(speed * dt, 0, 0)
						elseif axis == "Z" then
							rot = CFrame.Angles(0, 0, speed * dt)
						else
							rot = CFrame.Angles(0, speed * dt, 0)
						end
						r:PivotTo(r:GetPivot() * rot)
					end
				end
			end
		end
	end
	local shed = hub:FindFirstChild("CleaningShed")
	if shed then
		for _, st in ipairs(shed:GetChildren()) do
			local display = st:FindFirstChild("Display")
			if display and display:IsA("Model") then
				display:PivotTo(display:GetPivot() * CFrame.Angles(0, dt * 1.2, 0))
			end
		end
	end
end

----------------------------------------------------------------------
-- Gates (unlocked zones lose their barrier locally)
----------------------------------------------------------------------
local function refreshGates(d)
	local root = workspace:FindFirstChild("Scrapyard")
	if not root then
		return
	end
	for _, id in ipairs(Config.ZoneOrder) do
		local gate = root:FindFirstChild("Gate_" .. id)
		local barrier = gate and gate:FindFirstChild("Barrier") :: BasePart?
		if barrier then
			local open = d.Zones[id] == true
			barrier.CanCollide = not open
			barrier.Transparency = open and 1 or 0
			barrier.CanQuery = not open
			local tag = barrier:FindFirstChild("PriceTag") :: BillboardGui?
			if tag then
				tag.Enabled = not open
			end
			local prompt = barrier:FindFirstChild("GatePrompt") :: ProximityPrompt?
			if prompt then
				prompt.Enabled = not open
			end
		end
	end
end

----------------------------------------------------------------------
-- Rarity radar markers
----------------------------------------------------------------------
local function radarThreshold(): number?
	local d = State.Data
	local lvl = d and d.Machines.RarityRadar or 0
	if lvl <= 0 then
		return nil
	end
	return Config.MachineStats.RadarThreshold[lvl]
end

local function addMarker(m: Model)
	local threshold = radarThreshold()
	if not threshold or radarMarkers[m] then
		return
	end
	local rarity = Config.Rarities[m:GetAttribute("Rarity") :: string]
	if not rarity or rarity.Order < threshold then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(40, 40)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 260
	bb.Adornee = m.PrimaryPart
	bb.Parent = player:WaitForChild("PlayerGui")
	local diamond = UIKit.new("Frame", {
		Size = UDim2.fromScale(0.62, 0.62),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 45,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = bb,
	})
	UIKit.corner(diamond, 4)
	UIKit.gradient(diamond, rarity.Color, rarity.Color2, 0)
	UIKit.stroke(diamond, 2.5, UIKit.Colors.Outline, true)
	radarMarkers[m] = bb
end

local function refreshRadar()
	for m, bb in pairs(radarMarkers) do
		bb:Destroy()
		radarMarkers[m] = nil
	end
	for _, m in ipairs(scrapsFolder:GetChildren()) do
		if m:IsA("Model") then
			addMarker(m)
		end
	end
end

----------------------------------------------------------------------
-- Guide beam towards the current goal
----------------------------------------------------------------------
local beam: Beam
local beamA0: Attachment
local beamA1: Attachment
local beamTargetPart: Part

local function setupBeam()
	beamTargetPart = tempPart(CFrame.new())
	beamTargetPart.Name = "GuideTarget"
	beamA1 = Instance.new("Attachment")
	beamA1.Parent = beamTargetPart
	beamA0 = Instance.new("Attachment")
	beam = Instance.new("Beam")
	beam.Attachment0 = beamA0
	beam.Attachment1 = beamA1
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Segments = 20
	beam.CurveSize0 = 0
	beam.CurveSize1 = 0
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Static
	beam.TextureLength = 3
	beam.TextureSpeed = 2
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 230, 80), Color3.fromRGB(120, 255, 140))
	beam.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(1, 0.1) })
	beam.Enabled = false
	beam.Parent = beamTargetPart
end

local function guideTarget(): Vector3?
	local d = State.Data
	if not d then
		return nil
	end
	local root = workspace:FindFirstChild("Scrapyard")
	if not root then
		return nil
	end
	local count, cap = State.itemCount(), State.capacity()
	local goal = HUD.CurrentGoal
	local target = goal and goal.Target
	-- full backpack overrides: go wash / sell
	if count >= cap and cap > 0 then
		target = State.cleanCount() > 0 and "Sell" or "Wash"
	end
	if target == "Wash" then
		if State.dirtyCount() == 0 then
			return nil
		end
		local shed = hub:FindFirstChild("CleaningShed")
		local best, bestDist = nil, math.huge
		local r = rootPart()
		if shed and r then
			for _, st in ipairs(shed:GetChildren()) do
				local spot = st:FindFirstChild("ItemSpot") :: BasePart?
				if spot then
					local dist = (spot.Position - r.Position).Magnitude
					if dist < bestDist then
						best, bestDist = spot.Position, dist
					end
				end
			end
		end
		return best
	elseif target == "Sell" then
		if State.cleanCount() == 0 then
			return nil
		end
		local shop = hub:FindFirstChild("ScrapExchange")
		local pad = shop and shop:FindFirstChild("SellPad") :: BasePart?
		return pad and pad.Position
	elseif target == "Tools" then
		local nextTool
		for _, id in ipairs(Config.ToolOrder) do
			if not d.Tools[id] then
				nextTool = Config.Tools[id]
				break
			end
		end
		if not nextTool or d.Cash < nextTool.Price then
			return nil
		end
		local shop = hub:FindFirstChild("ToolShop")
		local pp = shop and shop:FindFirstChild("PromptPart") :: BasePart?
		return pp and pp.Position
	elseif typeof(target) == "string" and string.sub(target, 1, 5) == "Gate_" then
		local zoneId = string.sub(target, 6)
		local zone = Config.Zones[zoneId]
		if not zone or d.Cash < zone.Price then
			return nil
		end
		local gate = root:FindFirstChild(target)
		local barrier = gate and gate:FindFirstChild("Barrier") :: BasePart?
		return barrier and barrier.Position
	elseif typeof(target) == "string" and string.sub(target, 1, 4) == "Pad_" then
		local id = string.sub(target, 5)
		if not Config.Machines[id] or d.Cash < Config.MachineCost(id, 0) then
			return nil
		end
		local bay = hub:FindFirstChild("MachineBay")
		local pad = bay and bay:FindFirstChild(target)
		local pp = pad and pad:FindFirstChild("PromptPart") :: BasePart?
		return pp and pp.Position
	end
	return nil
end

local function updateBeam()
	local r = rootPart()
	local target = guideTarget()
	if not r or not target or (target - r.Position).Magnitude < 14 then
		beam.Enabled = false
		return
	end
	if beamA0.Parent ~= r then
		beamA0.Parent = r
	end
	beamA0.Position = Vector3.new(0, -2.4, 0)
	beamTargetPart.CFrame = CFrame.new(target)
	beam.Enabled = true
end

----------------------------------------------------------------------
-- Zone detection for the banner
----------------------------------------------------------------------
local currentZone: string? = nil
local function zoneAt(pos: Vector3): string
	for _, id in ipairs(Config.ZoneOrder) do
		local z = Config.Zones[id]
		if pos.Z >= z.ZMin - 8 and pos.Z <= z.ZMax + 8 then
			return id
		end
	end
	return "Hub"
end

----------------------------------------------------------------------
function WorldFX.init(open: (string, any?) -> ())
	openPanel = open
	scrapsFolder = workspace:WaitForChild("Scraps") :: Folder
	hub = workspace:WaitForChild("Scrapyard"):WaitForChild("Hub")

	scrapsFolder.ChildAdded:Connect(function(m)
		if m:IsA("Model") then
			popIn(m)
			task.defer(addMarker, m)
		end
	end)
	scrapsFolder.ChildRemoved:Connect(function(m)
		local bb = radarMarkers[m :: Model]
		if bb then
			bb:Destroy()
			radarMarkers[m :: Model] = nil
		end
	end)

	setupMachines()
	setupBeam()

	local lastRadar = -1
	local function onState(d)
		refreshMachines(d)
		refreshGates(d)
		local lvl = d.Machines.RarityRadar or 0
		if lvl ~= lastRadar then
			lastRadar = lvl
			refreshRadar()
		end
	end
	State.Changed.Event:Connect(onState)
	if State.Data then
		onState(State.Data)
	end

	-- prompts that open menus
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		local ui = prompt:GetAttribute("OpenUI")
		if ui == "Gate" then
			openPanel("Zones")
		elseif typeof(ui) == "string" then
			openPanel(ui, { MachineId = prompt:GetAttribute("MachineId") })
		end
	end)

	-- stepping on the sell pad opens the sell menu
	local shop = hub:WaitForChild("ScrapExchange")
	local pad = shop:WaitForChild("SellPad") :: BasePart
	local lastPad = 0
	pad.Touched:Connect(function(hit)
		local char = player.Character
		if char and hit:IsDescendantOf(char) and os.clock() - lastPad > 3 then
			lastPad = os.clock()
			openPanel("Sell")
		end
	end)

	RunService.RenderStepped:Connect(spinLoop)

	task.spawn(function()
		while true do
			task.wait(0.4)
			updateBeam()
			local r = rootPart()
			if r then
				local z = zoneAt(r.Position)
				if z ~= currentZone then
					local first = currentZone == nil
					currentZone = z
					if not first then
						if z == "Hub" then
							HUD.showZone("🏠 Scrapyard Hub", UIKit.Colors.Yellow)
						else
							local def = Config.Zones[z]
							HUD.showZone(def.Emoji .. " " .. def.Name, def.Color)
							Sound.play("Open")
						end
					end
				end
			end
		end
	end)
end

return WorldFX
