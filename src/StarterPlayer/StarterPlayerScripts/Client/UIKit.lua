-- UIKit: the visual language of the game's UI — chunky, glossy, bouncy
-- simulator style. Every screen is built from these helpers.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Sound = require(script.Parent.Sound)

local UIKit = {}

UIKit.Font = Enum.Font.FredokaOne
UIKit.BodyFont = Enum.Font.GothamBold

UIKit.Colors = {
	Outline = Color3.fromRGB(28, 30, 52),
	Panel = Color3.fromRGB(255, 255, 255),
	Panel2 = Color3.fromRGB(222, 232, 255),
	Card = Color3.fromRGB(244, 247, 255),
	Text = Color3.fromRGB(255, 255, 255),
	DarkText = Color3.fromRGB(40, 44, 70),
	Green = Color3.fromRGB(70, 220, 100),
	Blue = Color3.fromRGB(60, 160, 255),
	Red = Color3.fromRGB(255, 80, 90),
	Yellow = Color3.fromRGB(255, 200, 50),
	Orange = Color3.fromRGB(255, 140, 50),
	Purple = Color3.fromRGB(160, 100, 255),
	Pink = Color3.fromRGB(255, 100, 190),
	Grey = Color3.fromRGB(150, 156, 176),
	Cash = Color3.fromRGB(110, 255, 120),
}

local function lighten(c: Color3, amt: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), amt)
end
local function darken(c: Color3, amt: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), amt)
end
UIKit.lighten = lighten
UIKit.darken = darken

function UIKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className :: any)
	if props then
		local parent = props.Parent
		for k, v in pairs(props) do
			if k ~= "Parent" then
				inst[k] = v
			end
		end
		if children then
			for _, c in ipairs(children) do
				c.Parent = inst
			end
		end
		if parent then
			inst.Parent = parent
		end
	end
	return inst
end

function UIKit.corner(parent: Instance, radius: number?): UICorner
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 14), Parent = parent })
end

function UIKit.round(parent: Instance): UICorner
	return UIKit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent })
end

function UIKit.stroke(parent: Instance, thickness: number?, color: Color3?, border: boolean?): UIStroke
	return UIKit.new("UIStroke", {
		Thickness = thickness or 3,
		Color = color or UIKit.Colors.Outline,
		ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function UIKit.gradient(parent: Instance, c1: Color3, c2: Color3, rotation: number?): UIGradient
	return UIKit.new("UIGradient", {
		Color = ColorSequence.new(c1, c2),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

function UIKit.padding(parent: Instance, px: number)
	return UIKit.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = parent,
	})
end

-- Text with a thick dark outline (the classic simulator look).
function UIKit.label(parent: Instance, props: { [string]: any }): TextLabel
	local strokeThickness = props.StrokeThickness or 2.5
	local strokeColor = props.StrokeColor or UIKit.Colors.Outline
	props.StrokeThickness = nil
	props.StrokeColor = nil
	local base = {
		BackgroundTransparency = 1,
		Font = UIKit.Font,
		TextColor3 = UIKit.Colors.Text,
		TextScaled = true,
		Parent = parent,
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	local label = UIKit.new("TextLabel", base)
	if strokeThickness > 0 then
		UIKit.new("UIStroke", {
			Thickness = strokeThickness,
			Color = strokeColor,
			LineJoinMode = Enum.LineJoinMode.Round,
			Parent = label,
		})
	end
	return label
end

-- Soft drop shadow: a sibling frame placed behind `target` (ScreenGuis use
-- Sibling z-ordering, so a child would render on top). Follows visibility.
function UIKit.shadow(target: GuiObject, offset: number?, radius: number?)
	local s = UIKit.new("Frame", {
		Name = target.Name .. "Shadow",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6,
		Size = target.Size,
		AnchorPoint = target.AnchorPoint,
		Position = target.Position + UDim2.fromOffset(0, offset or 6),
		ZIndex = math.max(1, target.ZIndex - 1),
		LayoutOrder = target.LayoutOrder,
		Visible = target.Visible,
		Parent = target.Parent,
	})
	UIKit.corner(s, radius or 16)
	target:GetPropertyChangedSignal("Visible"):Connect(function()
		s.Visible = target.Visible
	end)
	return s
end

-- Glossy highlight across the top half of a button/card.
function UIKit.gloss(parent: GuiObject, radius: number?)
	local g = UIKit.new("Frame", {
		Name = "Gloss",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.78,
		Size = UDim2.new(1, -8, 0.45, 0),
		Position = UDim2.new(0, 4, 0, 4),
		ZIndex = parent.ZIndex + 1,
		Parent = parent,
	})
	UIKit.corner(g, radius or 10)
	UIKit.new("UIGradient", {
		Transparency = NumberSequence.new(0.2, 1),
		Rotation = 90,
		Parent = g,
	})
	return g
end

-- Scale tween helper (needs a UIScale child).
local function getScale(gui: GuiObject): UIScale
	local s = gui:FindFirstChild("BounceScale") :: UIScale?
	if not s then
		s = UIKit.new("UIScale", { Name = "BounceScale", Parent = gui })
	end
	return s :: UIScale
end

function UIKit.pop(gui: GuiObject, from: number?)
	local s = getScale(gui)
	s.Scale = from or 0.6
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function UIKit.bump(gui: GuiObject, amount: number?)
	local s = getScale(gui)
	s.Scale = amount or 1.15
	TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function UIKit.shake(gui: GuiObject)
	local start = gui.Position
	task.spawn(function()
		for i = 1, 6 do
			gui.Position = start + UDim2.fromOffset((i % 2 == 0) and 6 or -6, 0)
			task.wait(0.03)
		end
		gui.Position = start
	end)
end

-- Icon: uses a ForgeGUI image when an asset ID is configured, otherwise emoji.
function UIKit.icon(parent: Instance, key: string, props: { [string]: any }?): GuiObject
	local image = Assets.Images[key]
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	}
	if props then
		for k, v in pairs(props) do
			base[k] = v
		end
	end
	if image and image ~= "" then
		base.Image = image
		base.ScaleType = Enum.ScaleType.Fit
		return UIKit.new("ImageLabel", base)
	end
	base.Text = Assets.Fallback[key] or key
	base.TextScaled = true
	base.Font = Enum.Font.GothamBold
	base.TextColor3 = Color3.new(1, 1, 1)
	return UIKit.new("TextLabel", base)
end

-- Big glossy button. opts: Text, Color, Size, Position, AnchorPoint, Icon, TextSize, OnClick
function UIKit.button(parent: Instance, opts: { [string]: any }): TextButton
	local color: Color3 = opts.Color or UIKit.Colors.Green
	local btn = UIKit.new("TextButton", {
		Name = opts.Name or "Button",
		Size = opts.Size or UDim2.fromOffset(160, 50),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.new(),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = opts.LayoutOrder or 0,
		ZIndex = opts.ZIndex or 1,
		Parent = parent,
	})
	UIKit.corner(btn, opts.Radius or 12)
	local grad = UIKit.gradient(btn, lighten(color, 0.25), darken(color, 0.12))
	grad.Name = "Fill"
	UIKit.stroke(btn, opts.StrokeThickness or 3, UIKit.Colors.Outline, true)
	local lip = UIKit.new("Frame", {
		Name = "Lip",
		BackgroundColor3 = darken(color, 0.35),
		BackgroundTransparency = 0.25,
		Size = UDim2.new(1, 0, 0, 6),
		Position = UDim2.new(0, 0, 1, -6),
		BorderSizePixel = 0,
		ZIndex = btn.ZIndex,
		Parent = btn,
	})
	UIKit.corner(lip, 6)
	UIKit.gloss(btn)
	local label = UIKit.label(btn, {
		Name = "Label",
		Text = opts.Text or "",
		Size = UDim2.new(1, -16, 1, -12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = btn.ZIndex + 2,
		RichText = opts.RichText or false,
		StrokeThickness = 2,
	})
	if opts.TextSize then
		label.TextScaled = false
		label.TextSize = opts.TextSize
	end
	local scale = getScale(btn)
	btn.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.93 }):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1.05 }):Play()
	end)
	if opts.OnClick then
		btn.Activated:Connect(function()
			Sound.play("Click")
			opts.OnClick()
		end)
	end
	return btn
end

function UIKit.setButton(btn: TextButton, text: string, color: Color3)
	local label = btn:FindFirstChild("Label") :: TextLabel
	label.Text = text
	local fill = btn:FindFirstChild("Fill") :: UIGradient
	fill.Color = ColorSequence.new(lighten(color, 0.25), darken(color, 0.12))
	local lip = btn:FindFirstChild("Lip") :: Frame?
	if lip then
		lip.BackgroundColor3 = darken(color, 0.35)
	end
end

-- Pill-shaped info display used in the HUD.
function UIKit.pill(parent: Instance, opts: { [string]: any }): (Frame, TextLabel)
	local color: Color3 = opts.Color or UIKit.Colors.Green
	local frame = UIKit.new("Frame", {
		Name = opts.Name or "Pill",
		Size = opts.Size or UDim2.fromOffset(220, 54),
		Position = opts.Position or UDim2.new(),
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = opts.LayoutOrder or 0,
		Parent = parent,
	})
	UIKit.round(frame)
	UIKit.gradient(frame, lighten(color, 0.2), darken(color, 0.15))
	UIKit.stroke(frame, 3.5, UIKit.Colors.Outline, true)
	UIKit.gloss(frame, 20)
	local iconHolder = UIKit.new("Frame", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 70, 0, 70),
		Position = UDim2.new(0, -18, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 4,
		Parent = frame,
	})
	UIKit.icon(iconHolder, opts.Icon or "Cash", { ZIndex = 4 })
	local text = UIKit.label(frame, {
		Name = "Value",
		Text = opts.Text or "",
		Size = UDim2.new(1, -66, 0.78, 0),
		Position = UDim2.new(0, 56, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		StrokeThickness = 3,
	})
	return frame, text
end

-- Rotating 3D preview of a model inside a ViewportFrame.
function UIKit.viewport(parent: Instance, model: Model, opts: { [string]: any }?): ViewportFrame
	local o = opts or {}
	local vpf = UIKit.new("ViewportFrame", {
		Name = "Preview",
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromScale(1, 1),
		Position = o.Position or UDim2.new(),
		AnchorPoint = o.AnchorPoint or Vector2.new(),
		Ambient = Color3.fromRGB(170, 170, 185),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1.4, -0.8),
		ZIndex = o.ZIndex or 2,
		Parent = parent,
	})
	local world = UIKit.new("WorldModel", { Parent = vpf })
	model.Parent = world
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local cam = UIKit.new("Camera", { FieldOfView = 30, Parent = vpf })
	vpf.CurrentCamera = cam
	local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) * (o.Zoom or 1.05)
	local angle = o.Angle or 0.6
	local center = cf.Position
	local function place(a: number)
		local offset = Vector3.new(math.sin(a), 0.42, math.cos(a)).Unit * dist
		cam.CFrame = CFrame.lookAt(center + offset, center)
	end
	place(angle)
	if o.Spin then
		local a = angle
		local conn
		conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
			if not vpf.Parent then
				conn:Disconnect()
				return
			end
			if vpf.Visible then
				a += dt * (o.SpinSpeed or 0.8)
				place(a)
			end
		end)
	end
	return vpf
end

-- Rarity tag chip.
function UIKit.rarityChip(parent: Instance, rarity, props: { [string]: any }?): Frame
	local chip = UIKit.new("Frame", {
		Name = "Rarity",
		Size = UDim2.fromOffset(90, 22),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
		Parent = parent,
	})
	if props then
		for k, v in pairs(props) do
			chip[k] = v
		end
	end
	UIKit.round(chip)
	UIKit.gradient(chip, rarity.Color, rarity.Color2, 0)
	UIKit.stroke(chip, 2, UIKit.Colors.Outline, true)
	UIKit.label(chip, {
		Text = string.upper(rarity.Name),
		Size = UDim2.new(1, -8, 1, -4),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 6,
		StrokeThickness = 1.5,
	})
	return chip
end

-- Standard modal panel with header, close button and content area.
function UIKit.panel(parent: Instance, opts: { [string]: any }): (Frame, Frame, TextButton)
	local color: Color3 = opts.Color or UIKit.Colors.Blue
	local panel = UIKit.new("Frame", {
		Name = opts.Name or "Panel",
		Size = opts.Size or UDim2.fromOffset(720, 480),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 10,
		Parent = parent,
	})
	UIKit.corner(panel, 22)
	UIKit.gradient(panel, UIKit.Colors.Panel, UIKit.Colors.Panel2)
	UIKit.stroke(panel, 5, UIKit.Colors.Outline, true)

	-- header
	local header = UIKit.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 11,
		Parent = panel,
	})
	UIKit.corner(header, 22)
	UIKit.gradient(header, lighten(color, 0.2), darken(color, 0.1))
	-- square off the header bottom
	local fillBottom = UIKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 1, -24),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = header,
	})
	UIKit.gradient(fillBottom, lighten(color, 0.05), darken(color, 0.1))
	-- diagonal stripes for texture
	for i = 0, 14 do
		local stripe = UIKit.new("Frame", {
			Size = UDim2.new(0, 18, 2, 0),
			Position = UDim2.new(0, i * 52 - 20, -0.5, 0),
			Rotation = 25,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
			ZIndex = 11,
			Parent = header,
		})
		local _ = stripe
	end
	header.ClipsDescendants = true
	local headerLine = UIKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 5),
		Position = UDim2.new(0, 0, 0, 68),
		BackgroundColor3 = UIKit.Colors.Outline,
		BorderSizePixel = 0,
		ZIndex = 12,
		Parent = panel,
	})
	local _ = headerLine
	UIKit.label(panel, {
		Name = "Title",
		Text = (opts.Emoji and (opts.Emoji .. "  ") or "") .. (opts.Title or ""),
		Size = UDim2.new(1, -160, 0, 50),
		Position = UDim2.new(0, 24, 0, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
		StrokeThickness = 3.5,
	})

	local close = UIKit.button(panel, {
		Name = "Close",
		Text = "✕",
		Color = UIKit.Colors.Red,
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.new(1, 14, 0, -14),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 20,
		Radius = 28,
		StrokeThickness = 4,
	})
	close.Rotation = 0

	local content = UIKit.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -36, 1, -96),
		Position = UDim2.new(0, 18, 0, 84),
		ZIndex = 12,
		Parent = panel,
	})
	return panel, content, close
end

-- Scrolling grid used by most panels.
function UIKit.scrollGrid(parent: Instance, cellSize: UDim2, padding: number?): ScrollingFrame
	local sf = UIKit.new("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UIKit.Colors.Outline,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 12,
		Parent = parent,
	})
	UIKit.new("UIGridLayout", {
		CellSize = cellSize,
		CellPadding = UDim2.fromOffset(padding or 12, padding or 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = sf,
	})
	UIKit.new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 12),
		Parent = sf,
	})
	return sf
end

function UIKit.scrollList(parent: Instance, padding: number?): ScrollingFrame
	local sf = UIKit.new("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UIKit.Colors.Outline,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 12,
		Parent = parent,
	})
	UIKit.new("UIListLayout", {
		Padding = UDim.new(0, padding or 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = sf,
	})
	UIKit.new("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 12),
		Parent = sf,
	})
	return sf
end

-- White card with a coloured border.
function UIKit.card(parent: Instance, color: Color3, layoutOrder: number?): Frame
	local card = UIKit.new("Frame", {
		Name = "Card",
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = layoutOrder or 0,
		ZIndex = 13,
		Parent = parent,
	})
	UIKit.corner(card, 16)
	UIKit.gradient(card, Color3.fromRGB(255, 255, 255), lighten(color, 0.78))
	local st = UIKit.stroke(card, 3.5, darken(color, 0.25), true)
	st.Name = "Border"
	return card
end

function UIKit.clear(container: Instance)
	for _, c in ipairs(container:GetChildren()) do
		if not c:IsA("UIGridLayout") and not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

-- Horizontal progress bar.
function UIKit.bar(parent: Instance, props: { [string]: any }): (Frame, Frame)
	local back = UIKit.new("Frame", {
		Name = props.Name or "Bar",
		Size = props.Size or UDim2.fromOffset(200, 18),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		BackgroundColor3 = Color3.fromRGB(40, 42, 66),
		ZIndex = props.ZIndex or 5,
		Parent = parent,
	})
	UIKit.round(back)
	UIKit.stroke(back, 2.5, UIKit.Colors.Outline, true)
	local fill = UIKit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = (props.ZIndex or 5) + 1,
		Parent = back,
	})
	UIKit.round(fill)
	local c: Color3 = props.Color or UIKit.Colors.Green
	UIKit.gradient(fill, lighten(c, 0.25), darken(c, 0.1))
	return back, fill
end

return UIKit
