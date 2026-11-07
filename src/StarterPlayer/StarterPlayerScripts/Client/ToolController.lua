-- ToolController: point at scrap and hold click (or tap) to work it loose with
-- the equipped tool. Shows hover info, HP bars, damage numbers and hit FX.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local UIKit = require(script.Parent.UIKit)

local ToolController = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local remotes: Folder
local scrapsFolder: Folder
local isBlocked: () -> boolean

local equipped: Tool? = nil
local holding = false
local nextSwing = 0
local hovered: Model? = nil
local highlight: Highlight
local hoverGui: BillboardGui
local hoverName: TextLabel
local hoverRarity: TextLabel
local hoverFill: Frame
local hoverWarn: TextLabel

local function scrapFromPart(part: Instance?): Model?
	while part and part ~= workspace do
		if part.Parent == scrapsFolder and part:IsA("Model") then
			return part
		end
		part = part.Parent
	end
	return nil
end

local function rootPart(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function toolDef()
	local d = State.Data
	return d and Config.Tools[d.EquippedTool]
end

local function scrapPos(m: Model): Vector3
	local pp = m.PrimaryPart
	return pp and pp.Position or m:GetPivot().Position
end

local function inRange(m: Model, def): boolean
	local root = rootPart()
	if not root then
		return false
	end
	local pp = m.PrimaryPart :: BasePart?
	local size = pp and pp.Size.Magnitude / 2 or 2
	return (scrapPos(m) - root.Position).Magnitude <= def.Range + size
end

-- Picks the scrap under the cursor, else the nearest one in front of you.
local function findTargets(def): { Model }
	local targets = {}
	local root = rootPart()
	if not root then
		return targets
	end
	local primary = scrapFromPart(mouse.Target)
	if primary and inRange(primary, def) then
		table.insert(targets, primary)
	end
	local candidates = {}
	for _, m in ipairs(scrapsFolder:GetChildren()) do
		if m:IsA("Model") and m ~= primary and inRange(m, def) then
			local offset = scrapPos(m) - root.Position
			local facing = root.CFrame.LookVector:Dot(offset.Unit)
			table.insert(candidates, { M = m, Score = offset.Magnitude - facing * 6 })
		end
	end
	table.sort(candidates, function(a, b)
		return a.Score < b.Score
	end)
	for _, c in ipairs(candidates) do
		if #targets >= def.Targets then
			break
		end
		table.insert(targets, c.M)
	end
	return targets
end

local function damageNumber(position: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position + Vector3.new(math.random(-10, 10) / 10, 1.5, math.random(-10, 10) / 10))
	anchor.Parent = workspace.CurrentCamera
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(140, 50)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = anchor
	local l = UIKit.label(bb, {
		Text = text,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = color,
		StrokeThickness = 3,
	})
	UIKit.pop(l, 0.4)
	TweenService
		:Create(
			anchor,
			TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = anchor.CFrame + Vector3.new(0, 3, 0) }
		)
		:Play()
	TweenService:Create(l, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	local st = l:FindFirstChildOfClass("UIStroke")
	if st then
		TweenService:Create(st, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	end
	task.delay(0.85, function()
		anchor:Destroy()
	end)
end

local function hitFX(m: Model, rarity)
	local pos = scrapPos(m)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(pos)
	p.Parent = workspace.CurrentCamera
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), rarity.Color)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.25, 0.45)
	e.Speed = NumberRange.new(10, 18)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Rate = 0
	e.Parent = p
	e:Emit(14)
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(150, 120, 90))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 2.5) })
	dust.Transparency = NumberSequence.new(0.5, 1)
	dust.Lifetime = NumberRange.new(0.4, 0.7)
	dust.Speed = NumberRange.new(3, 6)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Rate = 0
	dust.Parent = p
	dust:Emit(5)
	task.delay(1, function()
		p:Destroy()
	end)
	-- local wobble of the scrap model
	local base = m:GetPivot()
	task.spawn(function()
		for i = 1, 4 do
			if not m.Parent then
				return
			end
			local s = (i % 2 == 0) and 1 or -1
			m:PivotTo(base * CFrame.Angles(math.rad(6 * s), 0, math.rad(-6 * s)))
			task.wait(0.03)
		end
		if m.Parent then
			m:PivotTo(base)
		end
	end)
end

local function swing()
	local def = toolDef()
	local tool = equipped
	if not def or not tool then
		return
	end
	-- play the default slash animation + sound
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	task.delay(0.3, function()
		anim:Destroy()
	end)
	Sound.play("Swing", 0.9 + math.random() * 0.25)

	local targets = findTargets(def)
	if #targets == 0 then
		return
	end
	local ids = {}
	local power = State.toolPower()
	local full = State.itemCount() >= State.capacity()
	for _, m in ipairs(targets) do
		table.insert(ids, m:GetAttribute("Id"))
		local rarity = Config.Rarities[m:GetAttribute("Rarity") :: string] or Config.Rarities.Common
		local zone = m:GetAttribute("Zone") :: string
		if full then
			break -- the server rejects the hit and shows the backpack warning
		elseif State.Data and not State.Data.Zones[zone] then
			damageNumber(scrapPos(m), "🔒", Color3.fromRGB(255, 120, 120))
		elseif power < rarity.MinPower then
			damageNumber(scrapPos(m), "TOO TOUGH!", Color3.fromRGB(255, 90, 90))
		else
			hitFX(m, rarity)
			Sound.play("Hit", 0.9 + math.random() * 0.3)
			damageNumber(scrapPos(m), "-" .. Format.short(power), Color3.fromRGB(255, 240, 120))
		end
	end
	remotes.Hit:FireServer(ids)
end

----------------------------------------------------------------------
-- hover info
----------------------------------------------------------------------
local function buildHover()
	highlight = Instance.new("Highlight")
	highlight.Name = "ScrapHover"
	highlight.FillTransparency = 0.85
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = workspace.CurrentCamera

	hoverGui = Instance.new("BillboardGui")
	hoverGui.Name = "ScrapInfo"
	hoverGui.Size = UDim2.fromOffset(210, 84)
	hoverGui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	hoverGui.AlwaysOnTop = true
	hoverGui.LightInfluence = 0
	hoverGui.Enabled = false
	hoverGui.Parent = player:WaitForChild("PlayerGui")
	hoverName = UIKit.label(hoverGui, { Text = "", Size = UDim2.new(1, 0, 0, 30), StrokeThickness = 3 })
	hoverRarity =
		UIKit.label(hoverGui, { Text = "", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 28), StrokeThickness = 2.5 })
	local _, fill =
		UIKit.bar(hoverGui, { Size = UDim2.new(0.9, 0, 0, 14), Position = UDim2.new(0.05, 0, 0, 52), Color = UIKit.Colors.Green })
	hoverFill = fill
	hoverWarn = UIKit.label(hoverGui, {
		Text = "",
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 68),
		TextColor3 = Color3.fromRGB(255, 110, 110),
		StrokeThickness = 2,
	})
end

local function updateHover()
	local target: Model? = nil
	if not isBlocked() then
		target = scrapFromPart(mouse.Target)
		if not target and UserInputService.TouchEnabled and equipped then
			local def = toolDef()
			if def then
				target = findTargets(def)[1]
			end
		end
	end
	if target ~= hovered then
		hovered = target
		if target then
			local rarity = Config.Rarities[target:GetAttribute("Rarity") :: string] or Config.Rarities.Common
			local scrap = Config.Scraps[target:GetAttribute("ScrapId") :: string]
			highlight.Adornee = target
			highlight.OutlineColor = rarity.Color
			highlight.FillColor = rarity.Color
			highlight.Enabled = true
			hoverGui.Adornee = target.PrimaryPart
			hoverGui.Enabled = true
			hoverName.Text = scrap and scrap.Name or "Scrap"
			hoverRarity.Text = string.upper(rarity.Name)
			hoverRarity.TextColor3 = rarity.Color
			local grad = hoverFill:FindFirstChildOfClass("UIGradient")
			if grad then
				grad.Color = ColorSequence.new(UIKit.lighten(rarity.Color, 0.2), rarity.Color2)
			end
		else
			highlight.Enabled = false
			hoverGui.Enabled = false
		end
	end
	if hovered then
		local hp = (hovered:GetAttribute("HP") :: number?) or 1
		local max = (hovered:GetAttribute("MaxHP") :: number?) or 1
		hoverFill.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
		local rarity = Config.Rarities[hovered:GetAttribute("Rarity") :: string] or Config.Rarities.Common
		local zone = hovered:GetAttribute("Zone") :: string
		if State.Data and not State.Data.Zones[zone] then
			hoverWarn.Text = "🔒 Zone locked"
		elseif State.toolPower() < rarity.MinPower then
			hoverWarn.Text = string.format("Needs %d tool power", rarity.MinPower)
		else
			hoverWarn.Text = ""
		end
	end
end

----------------------------------------------------------------------
local hooked = setmetatable({}, { __mode = "k" }) :: { [Tool]: boolean }

local function watchCharacter(char: Model)
	equipped = nil
	holding = false
	local function onChild(child: Instance)
		if child:IsA("Tool") and child:GetAttribute("ToolId") then
			equipped = child
			if hooked[child] then
				return
			end
			hooked[child] = true
			child.Activated:Connect(function()
				holding = true
			end)
			child.Deactivated:Connect(function()
				holding = false
			end)
			child.Unequipped:Connect(function()
				if equipped == child then
					equipped = nil
					holding = false
				end
			end)
		end
	end
	char.ChildAdded:Connect(onChild)
	for _, c in ipairs(char:GetChildren()) do
		onChild(c)
	end
end

function ToolController.init(remoteFolder: Folder, blocked: () -> boolean)
	remotes = remoteFolder
	isBlocked = blocked
	scrapsFolder = workspace:WaitForChild("Scraps") :: Folder
	buildHover()
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
	RunService.RenderStepped:Connect(function()
		updateHover()
		if holding and equipped and equipped.Parent == player.Character and not isBlocked() then
			local now = os.clock()
			if now >= nextSwing then
				local def = toolDef()
				nextSwing = now + (def and def.Cooldown or 0.5)
				swing()
			end
		end
	end)
end

return ToolController
