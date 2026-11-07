-- Build: small helpers for assembling detailed models out of many parts.
-- Used by the scrap, tool, machine and world builders (server and client).

local Build = {}

local HALF_PI = math.pi / 2

Build.Colors = {
	Steel = Color3.fromRGB(168, 174, 184),
	DarkSteel = Color3.fromRGB(78, 82, 92),
	Chrome = Color3.fromRGB(226, 232, 240),
	Black = Color3.fromRGB(32, 32, 38),
	Rubber = Color3.fromRGB(40, 40, 44),
	Rust = Color3.fromRGB(150, 74, 36),
	Gold = Color3.fromRGB(255, 196, 56),
	Copper = Color3.fromRGB(214, 112, 58),
	White = Color3.fromRGB(245, 245, 245),
	Yellow = Color3.fromRGB(255, 206, 40),
	Red = Color3.fromRGB(230, 56, 56),
	Wood = Color3.fromRGB(150, 98, 58),
}

local DEFAULTS = {
	Anchored = true,
	CanCollide = false,
	CastShadow = true,
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
}

-- Generic part constructor. `props` may contain any Part property.
function Build.part(parent: Instance, className: string?, props: { [string]: any }): BasePart
	local p = Instance.new((className or "Part") :: any) :: BasePart
	for k, v in pairs(DEFAULTS) do
		p[k] = v
	end
	for k, v in pairs(props) do
		if k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

function Build.block(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, name: string?): BasePart
	return Build.part(parent, "Part", {
		Name = name or "Block",
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

function Build.wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	return Build.part(parent, "WedgePart", {
		Name = "Wedge",
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

function Build.ball(parent: Instance, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	return Build.part(parent, "Part", {
		Name = "Ball",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

-- Cylinder whose axis runs along the given CFrame's local X.
function Build.cylX(parent: Instance, length: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	return Build.part(parent, "Part", {
		Name = "Cylinder",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, diameter, diameter),
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

-- Cylinder whose axis runs along local Y.
function Build.cylY(parent: Instance, length: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	return Build.cylX(parent, length, diameter, cf * CFrame.Angles(0, 0, HALF_PI), color, material)
end

-- Cylinder whose axis runs along local Z.
function Build.cylZ(parent: Instance, length: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	return Build.cylX(parent, length, diameter, cf * CFrame.Angles(0, HALF_PI, 0), color, material)
end

-- Torus lying in the CFrame's local XZ plane (around its Y axis).
function Build.torus(
	parent: Instance,
	cf: CFrame,
	radius: number,
	tube: number,
	segments: number,
	color: Color3,
	material: Enum.Material?
): { BasePart }
	local parts = {}
	local segLen = (2 * math.pi * radius / segments) * 1.12
	for i = 0, segments - 1 do
		local a = (i / segments) * math.pi * 2
		local segCf = cf * CFrame.Angles(0, a, 0) * CFrame.new(radius, 0, 0) * CFrame.Angles(0, HALF_PI, 0)
		table.insert(parts, Build.cylX(parent, segLen, tube * 2, segCf, color, material))
	end
	return parts
end

-- Ring of blocks (e.g. gear teeth, tire tread) around local Y.
function Build.radial(
	parent: Instance,
	cf: CFrame,
	count: number,
	radius: number,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	offsetAngle: number?
): { BasePart }
	local parts = {}
	for i = 0, count - 1 do
		local a = (i / count) * math.pi * 2 + (offsetAngle or 0)
		table.insert(parts, Build.block(parent, size, cf * CFrame.Angles(0, a, 0) * CFrame.new(radius, 0, 0), color, material))
	end
	return parts
end

-- Small hex-ish bolt head pointing along local Y.
function Build.bolt(parent: Instance, cf: CFrame, size: number, color: Color3?): BasePart
	local c = color or Build.Colors.Steel
	local head = Build.cylY(parent, size * 0.5, size, cf, c, Enum.Material.Metal)
	head.Name = "Bolt"
	return head
end

-- Mark a part as chrome so the "clean" pass makes it reflective.
function Build.shiny(part: BasePart, amount: number?): BasePart
	part:SetAttribute("Shiny", amount or 0.18)
	return part
end

-- Mark a part as something that glows only once the scrap is cleaned.
function Build.glow(part: BasePart): BasePart
	part:SetAttribute("Glow", true)
	return part
end

-- Invisible hitbox used as the PrimaryPart of scraps/tools.
function Build.hitbox(parent: Instance, size: Vector3, cf: CFrame): BasePart
	local hb = Build.part(parent, "Part", {
		Name = "Hitbox",
		Size = size,
		CFrame = cf,
		Transparency = 1,
		CanCollide = false,
		CanQuery = true,
		CanTouch = false,
		CastShadow = false,
	})
	return hb
end

function Build.weldTo(model: Instance, root: BasePart)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
end

function Build.setAll(model: Instance, props: { [string]: any })
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			for k, v in pairs(props) do
				d[k] = v
			end
		end
	end
end

function Build.light(parent: Instance, color: Color3, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

-- Simple text sign on a part face.
function Build.sign(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	textColor: Color3,
	strokeColor: Color3?,
	font: Enum.Font?
): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = font or Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor or Color3.new(0, 0, 0)
	stroke.Thickness = 4
	stroke.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.Parent = label
	return gui
end

return Build
