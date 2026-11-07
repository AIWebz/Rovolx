-- CleaningGame: the interactive scrubbing minigame at the wash stations.
--
-- The scrap sits in a tub covered in stains. Hold the mouse (or finger) and
-- scrub over each stain with the matching tool:
--   🧽 Sponge  -> Mud      🪥 Wire Brush -> Rust      💦 Power Spray -> Grease
-- The wrong tool barely works. As stains come off, the 3D model gradually
-- turns from rusty to shiny. Finish fast for up to 3 stars (more money).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ScrapModels = require(ReplicatedStorage.Shared.ScrapModels)
local UIKit = require(script.Parent.UIKit)
local Sound = require(script.Parent.Sound)
local Notify = require(script.Parent.Notify)

local CleaningGame = {}
CleaningGame.Active = false

local player = Players.LocalPlayer
local gui: ScreenGui
local request: (string, any?, any?) -> (boolean, any)

local root: Frame? = nil
local connections: { RBXScriptConnection } = {}
local controls: any = nil

local C = UIKit.Colors
local BRUSH_RADIUS = 34

local function getControls()
	if controls then
		return controls
	end
	local ok, result = pcall(function()
		local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
		return require(module :: ModuleScript):GetControls()
	end)
	if ok then
		controls = result
	end
	return controls
end

local function disconnectAll()
	for _, c in ipairs(connections) do
		c:Disconnect()
	end
	table.clear(connections)
end

function CleaningGame.close()
	disconnectAll()
	CleaningGame.Active = false
	local c = getControls()
	if c then
		c:Enable()
	end
	if root then
		local r = root
		root = nil
		local s = r:FindFirstChild("BounceScale") :: UIScale?
		if s then
			TweenService:Create(s, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.6 }):Play()
		end
		TweenService:Create(r, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
		task.delay(0.2, function()
			r:Destroy()
		end)
	end
end

-- Irregular stain made of a few overlapping blobs.
local function makeStain(parent: Frame, spot, dirt): Frame
	local f = UIKit.new("Frame", {
		Name = "Stain",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(spot.X, spot.Y),
		Size = UDim2.fromScale(spot.Size, spot.Size),
		Rotation = spot.Rot,
		ZIndex = 86,
		Parent = parent,
	})
	UIKit.new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width, Parent = f })
	local blobs = {
		{ 0.5, 0.5, 1.0 },
		{ 0.22, 0.35, 0.55 },
		{ 0.8, 0.3, 0.45 },
		{ 0.72, 0.78, 0.55 },
		{ 0.25, 0.75, 0.42 },
	}
	for i, b in ipairs(blobs) do
		local blob = UIKit.new("Frame", {
			Name = "Blob",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(b[1], b[2]),
			Size = UDim2.fromScale(b[3], b[3]),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 86,
			Parent = f,
		})
		UIKit.round(blob)
		UIKit.gradient(blob, dirt.Color, dirt.Color2, 45 + i * 30)
		if i == 1 then
			UIKit.stroke(blob, 2, UIKit.darken(dirt.Color2, 0.3), true).Transparency = 0.3
		end
	end
	-- specks / texture
	for _ = 1, 4 do
		local speck = UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(math.random(25, 75) / 100, math.random(25, 75) / 100),
			Size = UDim2.fromScale(0.12, 0.12),
			BackgroundColor3 = UIKit.lighten(dirt.Color, 0.25),
			BackgroundTransparency = 0.3,
			ZIndex = 87,
			Parent = f,
		})
		UIKit.round(speck)
	end
	return f
end

local function setStainAlpha(stain: Frame, alpha: number)
	for _, d in ipairs(stain:GetDescendants()) do
		if d:IsA("Frame") then
			d.BackgroundTransparency = (d.Name == "Blob") and alpha or math.max(alpha, 0.3)
		end
	end
end

local function spawnBubble(layer: Frame, pos: Vector2, color: Color3?)
	local size = math.random(10, 26)
	local b = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color or Color3.fromRGB(235, 250, 255),
		BackgroundTransparency = 0.35,
		ZIndex = 90,
		Parent = layer,
	})
	UIKit.round(b)
	UIKit.stroke(b, 1.5, Color3.fromRGB(150, 210, 255), true)
	local drift = Vector2.new(math.random(-40, 40), math.random(-70, -20))
	local tw = TweenService:Create(b, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(pos.X + drift.X, pos.Y + drift.Y),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size * 1.4, size * 1.4),
	})
	tw:Play()
	local st = b:FindFirstChildOfClass("UIStroke")
	if st then
		TweenService:Create(st, TweenInfo.new(0.7), { Transparency = 1 }):Play()
	end
	task.delay(0.72, function()
		b:Destroy()
	end)
end

local function sparkleBurst(layer: Frame, center: Vector2, count: number, color: Color3?)
	for _ = 1, count do
		local s = UIKit.label(layer, {
			Text = "✦",
			Font = Enum.Font.GothamBold,
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.fromOffset(center.X, center.Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextColor3 = color or Color3.fromRGB(255, 240, 120),
			ZIndex = 95,
			StrokeThickness = 0,
		})
		local a = math.random() * math.pi * 2
		local d = math.random(60, 180)
		TweenService:Create(s, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(center.X + math.cos(a) * d, center.Y + math.sin(a) * d),
			TextTransparency = 1,
			Rotation = math.random(-180, 180),
		}):Play()
		task.delay(0.62, function()
			s:Destroy()
		end)
	end
end

----------------------------------------------------------------------
function CleaningGame.start(session, stationIndex: number)
	if root then
		CleaningGame.close()
	end
	CleaningGame.Active = true
	local c = getControls()
	if c then
		c:Disable()
	end
	local def = Config.Scraps[session.ScrapId]
	local rarity = Config.Rarities[def.Rarity]

	-- backdrop
	local r = UIKit.new("Frame", {
		Name = "Cleaning",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 30, 60),
		BackgroundTransparency = 0.35,
		Active = true,
		ZIndex = 80,
		Parent = gui,
	})
	root = r
	UIKit.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(40, 120, 220), Color3.fromRGB(10, 20, 60)),
		Rotation = 90,
		Parent = r,
	})

	local main = UIKit.new("Frame", {
		Name = "Main",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(900, 600),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 81,
		Parent = r,
	})
	UIKit.pop(main, 0.7)

	-- title
	UIKit.label(main, {
		Text = "🫧 WASH STATION " .. stationIndex,
		Size = UDim2.new(0, 520, 0, 44),
		Position = UDim2.fromOffset(0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 82,
		StrokeThickness = 4,
	})
	UIKit.label(main, {
		Text = string.format("%s  x%d", def.Name, session.Count),
		Size = UDim2.new(0, 420, 0, 30),
		Position = UDim2.fromOffset(2, 44),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = rarity.Color,
		ZIndex = 82,
		StrokeThickness = 3,
	})
	UIKit.rarityChip(main, rarity, { Position = UDim2.fromOffset(4, 80), Size = UDim2.fromOffset(110, 24), ZIndex = 82 })

	-- progress + timer
	local progBack, progFill = UIKit.bar(main, {
		Size = UDim2.fromOffset(340, 30),
		Position = UDim2.new(1, -150, 0, 14),
		AnchorPoint = Vector2.new(1, 0),
		Color = C.Green,
		ZIndex = 82,
	})
	local progText = UIKit.label(progBack, {
		Text = "CLEAN 0%",
		Size = UDim2.new(1, 0, 1, -4),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 85,
		StrokeThickness = 2,
	})
	local timerText = UIKit.label(main, {
		Text = "⏱ 0.0s",
		Size = UDim2.fromOffset(200, 28),
		Position = UDim2.new(1, -150, 0, 52),
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 82,
		StrokeThickness = 2.5,
	})
	local starsText = UIKit.label(main, {
		Text = string.format("★★★ under %.0fs", session.ParTime),
		Size = UDim2.fromOffset(240, 24),
		Position = UDim2.new(1, -150, 0, 82),
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.Yellow,
		ZIndex = 82,
		StrokeThickness = 2,
	})

	-- cancel
	UIKit.button(main, {
		Text = "✕",
		Color = C.Red,
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.new(1, 0, 0, 10),
		AnchorPoint = Vector2.new(1, 0),
		Radius = 30,
		ZIndex = 84,
		OnClick = function()
			request("CancelCleaning")
			CleaningGame.close()
		end,
	})

	-- the tub
	local tub = UIKit.new("Frame", {
		Name = "Tub",
		Size = UDim2.fromOffset(600, 430),
		Position = UDim2.fromOffset(0, 120),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Active = true,
		ZIndex = 83,
		Parent = main,
	})
	UIKit.corner(tub, 28)
	UIKit.gradient(tub, Color3.fromRGB(150, 225, 255), Color3.fromRGB(40, 130, 230))
	UIKit.stroke(tub, 6, C.Outline, true)
	-- water caustic stripes
	local caustics = UIKit.new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.fromScale(1.6, 1.6), Position = UDim2.fromScale(-0.3, -0.3), ZIndex = 83, Parent = tub }
	)
	for i = 0, 9 do
		local stripe = UIKit.new("Frame", {
			Size = UDim2.new(0, 30, 1, 0),
			Position = UDim2.fromScale(i / 10, 0),
			Rotation = 30,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.88,
			BorderSizePixel = 0,
			ZIndex = 83,
			Parent = caustics,
		})
		UIKit.round(stripe)
	end
	-- rim
	local rim = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 89, Parent = tub })
	UIKit.corner(rim, 28)
	UIKit.stroke(rim, 10, Color3.fromRGB(240, 248, 255), true).Transparency = 0.2

	-- 3D scrap (dirty) + clean reference colours for the gradual reveal
	local dirtyModel = ScrapModels.create(session.ScrapId, false)
	local cleanModel = ScrapModels.create(session.ScrapId, true)
	local dirtyParts, cleanParts = {}, {}
	for _, d in ipairs(dirtyModel:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(dirtyParts, d)
		end
	end
	for _, d in ipairs(cleanModel:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(cleanParts, d)
		end
	end
	local startColors = {}
	for i, p in ipairs(dirtyParts) do
		startColors[i] = p.Color
	end
	local vpf = UIKit.viewport(
		tub,
		dirtyModel,
		{ ZIndex = 84, Spin = true, SpinSpeed = 0.35, Zoom = 1.0, Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.05, 0.05) }
	)
	vpf.Ambient = Color3.fromRGB(190, 200, 220)

	-- stains
	local dirtLayer =
		UIKit.new("Frame", { Name = "Dirt", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 86, Parent = tub })
	local fxLayer = UIKit.new("Frame", { Name = "FX", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 90, Parent = tub })
	local stains = {}
	local totalHP = 0
	for i, spot in ipairs(session.Spots) do
		local dirt = Config.Cleaning.DirtTypes[spot.Type]
		local frame = makeStain(dirtLayer, spot, dirt)
		frame.ZIndex = 86 + (i % 3)
		stains[i] = { Spot = spot, Dirt = dirt, Frame = frame, HP = spot.HP, MaxHP = spot.HP }
		totalHP += spot.HP
		UIKit.pop(frame, 0.2)
	end

	-- tool palette
	local palette = UIKit.new("Frame", {
		Name = "Palette",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(270, 430),
		Position = UDim2.new(1, 0, 0, 120),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 82,
		Parent = main,
	})
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = palette })
	local selected = 1
	local toolButtons = {}
	local function selectTool(index: number)
		selected = index
		for i, b in ipairs(toolButtons) do
			local st = b:FindFirstChild("Select") :: UIStroke
			st.Enabled = i == index
			if i == index then
				UIKit.bump(b, 1.08)
			end
		end
		Sound.play("Click")
	end
	for i, tool in ipairs(Config.Cleaning.Tools) do
		local dirt = Config.Cleaning.DirtTypes[i]
		local b = UIKit.button(palette, {
			Text = "",
			Color = tool.Color,
			Size = UDim2.fromOffset(260, 120),
			LayoutOrder = i,
			ZIndex = 83,
			OnClick = function()
				selectTool(i)
			end,
		})
		local sel = UIKit.new("UIStroke", {
			Name = "Select",
			Thickness = 6,
			Color = Color3.fromRGB(255, 255, 255),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Enabled = false,
			Parent = b,
		})
		local _ = sel
		UIKit.label(b, {
			Text = tool.Emoji,
			Font = Enum.Font.GothamBold,
			Size = UDim2.fromOffset(72, 72),
			Position = UDim2.fromOffset(14, 24),
			ZIndex = 86,
			StrokeThickness = 0,
		})
		UIKit.label(b, {
			Text = tool.Name,
			Size = UDim2.new(1, -110, 0, 34),
			Position = UDim2.fromOffset(96, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 86,
			StrokeThickness = 2.5,
		})
		local legend = UIKit.new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.fromOffset(130, 30),
			Position = UDim2.fromOffset(96, 64),
			ZIndex = 86,
			Parent = b,
		})
		UIKit.round(legend)
		UIKit.gradient(legend, dirt.Color, dirt.Color2, 0)
		UIKit.stroke(legend, 2, C.Outline, true)
		UIKit.label(legend, {
			Text = "cleans " .. dirt.Name,
			Size = UDim2.new(1, -10, 1, -6),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 87,
			StrokeThickness = 1.5,
		})
		UIKit.label(b, {
			Text = tostring(i),
			Size = UDim2.fromOffset(30, 30),
			Position = UDim2.new(1, -10, 0, 8),
			AnchorPoint = Vector2.new(1, 0),
			ZIndex = 86,
			StrokeThickness = 2,
			TextColor3 = C.Yellow,
		})
		toolButtons[i] = b
		local _ = legend
	end
	selectTool(1)

	-- hint + cursor
	local hint = UIKit.label(main, {
		Text = "Hold & scrub over the stains! Match the tool to the stain.",
		Size = UDim2.new(0, 600, 0, 28),
		Position = UDim2.fromOffset(0, 560),
		ZIndex = 82,
		StrokeThickness = 2.5,
	})
	local cursor = UIKit.label(r, {
		Text = Config.Cleaning.Tools[1].Emoji,
		Font = Enum.Font.GothamBold,
		Size = UDim2.fromOffset(64, 64),
		AnchorPoint = Vector2.new(0.3, 0.3),
		ZIndex = 99,
		StrokeThickness = 0,
		Visible = false,
	})
	local ring = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(BRUSH_RADIUS * 2, BRUSH_RADIUS * 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 98,
		Visible = false,
		Parent = r,
	})
	UIKit.round(ring)
	UIKit.stroke(ring, 2.5, Color3.new(1, 1, 1), true).Transparency = 0.3

	-- state
	local scrubbing = false
	local pointer = Vector2.new()
	local lastMove = 0
	local lastPointer = Vector2.new()
	local started = os.clock()
	local finished = false
	local lastScrubSound = 0
	local lastWrongHint = 0
	local lastBubble = 0
	local remaining = totalHP

	local function inTub(p: Vector2): boolean
		local pos, size = tub.AbsolutePosition, tub.AbsoluteSize
		return p.X >= pos.X and p.Y >= pos.Y and p.X <= pos.X + size.X and p.Y <= pos.Y + size.Y
	end

	local function updateReveal(progress: number)
		for i, p in ipairs(dirtyParts) do
			local target = cleanParts[i]
			if target then
				p.Color = startColors[i]:Lerp(target.Color, progress)
			end
		end
		progFill.Size = UDim2.fromScale(progress, 1)
		progText.Text = string.format("CLEAN %d%%", math.floor(progress * 100))
	end

	local function finish()
		if finished then
			return
		end
		finished = true
		scrubbing = false
		local elapsed = os.clock() - started
		-- fully clean the model
		for i, p in ipairs(dirtyParts) do
			local target = cleanParts[i]
			if target then
				p.Color = target.Color
				p.Material = target.Material
				p.Reflectance = target.Reflectance
				p.Transparency = target.Transparency
			end
		end
		updateReveal(1)
		Sound.play("Sparkle")
		local center = tub.AbsoluteSize / 2
		sparkleBurst(fxLayer, center, 26)
		local shine = UIKit.label(tub, {
			Text = "SPARKLING CLEAN!",
			Size = UDim2.fromOffset(520, 70),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextColor3 = Color3.fromRGB(255, 250, 200),
			ZIndex = 96,
			StrokeThickness = 5,
		})
		UIKit.gradient(shine, Color3.fromRGB(255, 255, 255), C.Yellow, 90)
		UIKit.pop(shine, 0.3)
		hint.Text = "Polishing..."
		task.wait(0.9)
		shine:Destroy()

		local ok, result = request("FinishCleaning", session.Id)
		if not root or root ~= r then
			return
		end
		if not ok then
			Notify.toast(result or "Wash failed", "error")
			CleaningGame.close()
			return
		end

		-- result card
		local card = UIKit.new("Frame", {
			Name = "Result",
			Size = UDim2.fromOffset(460, 330),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 100,
			Parent = r,
		})
		UIKit.corner(card, 26)
		UIKit.gradient(card, Color3.fromRGB(255, 255, 255), Color3.fromRGB(210, 235, 255))
		UIKit.stroke(card, 6, C.Outline, true)
		UIKit.pop(card, 0.5)
		UIKit.label(card, {
			Text = "WASH COMPLETE!",
			Size = UDim2.new(1, -40, 0, 50),
			Position = UDim2.fromOffset(20, 16),
			TextColor3 = C.Blue,
			ZIndex = 101,
			StrokeThickness = 3.5,
		})
		local starHolder = UIKit.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(300, 90),
			Position = UDim2.new(0.5, 0, 0, 70),
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = 101,
			Parent = card,
		})
		local starLabels = {}
		for i = 1, 3 do
			local s = UIKit.label(starHolder, {
				Text = "★",
				Font = Enum.Font.GothamBold,
				Size = UDim2.fromOffset(86, 86),
				Position = UDim2.fromOffset((i - 1) * 104, i == 2 and 0 or 8),
				TextColor3 = Color3.fromRGB(200, 205, 220),
				ZIndex = 102,
				StrokeThickness = 4,
			})
			starLabels[i] = s
		end
		UIKit.label(card, {
			Text = string.format("+%d Clean %s", result.Count, def.Name),
			Size = UDim2.new(1, -40, 0, 32),
			Position = UDim2.fromOffset(20, 168),
			TextColor3 = C.DarkText,
			ZIndex = 101,
			StrokeThickness = 0,
		})
		UIKit.label(card, {
			Text = "Worth " .. Format.cash(result.Value),
			Size = UDim2.new(1, -40, 0, 34),
			Position = UDim2.fromOffset(20, 202),
			TextColor3 = Color3.fromRGB(40, 190, 80),
			ZIndex = 101,
			StrokeThickness = 2.5,
		})
		UIKit.label(card, {
			Text = string.format("Time: %.1fs", elapsed),
			Size = UDim2.new(1, -40, 0, 22),
			Position = UDim2.fromOffset(20, 236),
			TextColor3 = C.Grey,
			Font = UIKit.BodyFont,
			ZIndex = 101,
			StrokeThickness = 0,
		})
		UIKit.button(card, {
			Text = "CONTINUE",
			Color = C.Green,
			Size = UDim2.fromOffset(220, 50),
			Position = UDim2.new(0.5, 0, 1, -14),
			AnchorPoint = Vector2.new(0.5, 1),
			ZIndex = 103,
			OnClick = function()
				CleaningGame.close()
			end,
		})
		task.spawn(function()
			for i = 1, result.Stars do
				task.wait(0.28)
				local s = starLabels[i]
				s.TextColor3 = C.Yellow
				UIKit.pop(s, 0.2)
				Sound.play("Sparkle", 0.8 + i * 0.15)
				sparkleBurst(card, Vector2.new(80 + (i - 1) * 104 + 43, 113), 8)
			end
		end)
		Notify.item(session.ScrapId, result.Count, { Clean = true, Sub = string.rep("★", result.Stars) .. " CLEANED" })
	end

	-- input ------------------------------------------------------------
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				local p = Vector2.new(input.Position.X, input.Position.Y)
				if inTub(p) and not finished then
					scrubbing = true
					pointer = p
					lastPointer = p
					lastMove = os.clock()
				end
			elseif input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.One then
					selectTool(1)
				elseif input.KeyCode == Enum.KeyCode.Two then
					selectTool(2)
				elseif input.KeyCode == Enum.KeyCode.Three then
					selectTool(3)
				end
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				scrubbing = false
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				local p = Vector2.new(input.Position.X, input.Position.Y)
				if (p - pointer).Magnitude > 1.5 then
					lastMove = os.clock()
				end
				pointer = p
			end
		end)
	)

	-- main loop ----------------------------------------------------------
	local inset = game:GetService("GuiService"):GetGuiInset()
	local wiggle = 0
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function(dt)
			if finished then
				cursor.Visible = false
				ring.Visible = false
				return
			end
			local elapsed = os.clock() - started
			timerText.Text = string.format("⏱ %.1fs", elapsed)
			if elapsed > session.ParTime * 1.8 then
				starsText.Text = "★☆☆"
				starsText.TextColor3 = C.Grey
			elseif elapsed > session.ParTime then
				starsText.Text = string.format("★★☆ under %.0fs", session.ParTime * 1.8)
				starsText.TextColor3 = C.Orange
			end
			caustics.Position = UDim2.fromScale(-0.3 + math.sin(elapsed * 0.6) * 0.05, -0.3 + math.cos(elapsed * 0.4) * 0.05)

			-- cursor (screen position includes the top-bar inset; GUI coordinates do not)
			local mouse = UserInputService:GetMouseLocation() - inset
			local p = UserInputService.TouchEnabled and scrubbing and pointer or mouse
			local over = inTub(p)
			cursor.Visible = over
			ring.Visible = over
			cursor.Text = Config.Cleaning.Tools[selected].Emoji
			local rootPos = r.AbsolutePosition
			if scrubbing and os.clock() - lastMove < 0.12 then
				wiggle += dt * 30
			end
			cursor.Position = UDim2.fromOffset(p.X - rootPos.X, p.Y - rootPos.Y)
			cursor.Rotation = math.sin(wiggle) * 18
			ring.Position = UDim2.fromOffset(p.X - rootPos.X, p.Y - rootPos.Y)

			if not scrubbing or not over then
				return
			end
			local moving = os.clock() - lastMove < 0.12
			if not moving then
				return
			end
			local tubPos = tub.AbsolutePosition
			local local_ = p - tubPos
			-- bubbles while scrubbing
			if os.clock() - lastBubble > 0.05 then
				lastBubble = os.clock()
				spawnBubble(fxLayer, local_)
			end
			local scrubbedDirt = false
			for _, s in ipairs(stains) do
				if s.HP > 0 then
					local f = s.Frame
					local center = f.AbsolutePosition + f.AbsoluteSize / 2
					local radius = f.AbsoluteSize.X * 0.5
					if (center - p).Magnitude <= radius + BRUSH_RADIUS then
						local correct = Config.Cleaning.Tools[selected].Id == s.Dirt.Tool
						local mult = correct and 1 or Config.Cleaning.WrongToolMultiplier
						local dmg = session.ScrubRate * mult * dt
						s.HP -= dmg
						remaining -= math.min(dmg, s.HP + dmg)
						scrubbedDirt = true
						if not correct and os.clock() - lastWrongHint > 1.6 then
							lastWrongHint = os.clock()
							local need
							for _, t in ipairs(Config.Cleaning.Tools) do
								if t.Id == s.Dirt.Tool then
									need = t
								end
							end
							if need then
								hint.Text = string.format("%s needs the %s %s!", s.Dirt.Name, need.Emoji, need.Name)
								hint.TextColor3 = C.Orange
								UIKit.bump(hint, 1.1)
								UIKit.shake(f)
							end
						end
						local frac = math.clamp(s.HP / s.MaxHP, 0, 1)
						setStainAlpha(f, 1 - (0.25 + frac * 0.75))
						f.Size = UDim2.fromScale(s.Spot.Size * (0.55 + frac * 0.45), s.Spot.Size * (0.55 + frac * 0.45))
						if s.HP <= 0 then
							local burstAt = center - tubPos
							sparkleBurst(fxLayer, burstAt, 6, Color3.fromRGB(200, 240, 255))
							for _ = 1, 4 do
								spawnBubble(fxLayer, burstAt + Vector2.new(math.random(-20, 20), math.random(-20, 20)))
							end
							Sound.play("Collect", 1.4 + math.random() * 0.4)
							local tw = TweenService:Create(f, TweenInfo.new(0.2), { Size = UDim2.fromScale(0, 0) })
							tw:Play()
							task.delay(0.2, function()
								f:Destroy()
							end)
						end
					end
				end
			end
			if scrubbedDirt and os.clock() - lastScrubSound > 0.22 then
				lastScrubSound = os.clock()
				Sound.play("Scrub", 0.9 + math.random() * 0.3)
			end
			local progress = math.clamp(1 - remaining / totalHP, 0, 1)
			updateReveal(progress)
			local allClean = true
			for _, s in ipairs(stains) do
				if s.HP > 0 then
					allClean = false
					break
				end
			end
			if allClean then
				task.spawn(finish)
			end
			local _ = lastPointer
		end)
	)
end

function CleaningGame.init(screen: ScreenGui, requestFn)
	gui = screen
	request = requestFn
end

return CleaningGame
