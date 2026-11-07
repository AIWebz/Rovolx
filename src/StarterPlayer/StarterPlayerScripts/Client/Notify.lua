-- Notify: toasts, item pop-ups, big banners and floating cash.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ScrapModels = require(ReplicatedStorage.Shared.ScrapModels)
local UIKit = require(script.Parent.UIKit)
local Sound = require(script.Parent.Sound)

local Notify = {}

local gui: ScreenGui
local toastHolder: Frame
local itemHolder: Frame

local KIND_COLORS = {
	info = UIKit.Colors.Blue,
	success = UIKit.Colors.Green,
	error = UIKit.Colors.Red,
}

function Notify.init(screen: ScreenGui)
	gui = screen
	toastHolder = UIKit.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 520, 0, 300),
		Position = UDim2.new(0.5, 0, 0, 70),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 50,
		Parent = gui,
	})
	UIKit.new("UIListLayout", {
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = toastHolder,
	})
	itemHolder = UIKit.new("Frame", {
		Name = "ItemPopups",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 340, 0, 260),
		Position = UDim2.new(0.5, 0, 1, -110),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 40,
		Parent = gui,
	})
	UIKit.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = itemHolder,
	})
end

local order = 0

function Notify.toast(text: string, kind: string?)
	order += 1
	local k = kind or "info"
	local rarity = Config.Rarities[k]
	local color = rarity and rarity.Color or KIND_COLORS[k] or UIKit.Colors.Blue
	local toast = UIKit.new("Frame", {
		Name = "Toast",
		Size = UDim2.new(0, 480, 0, 46),
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
		ZIndex = 50,
		Parent = toastHolder,
	})
	UIKit.round(toast)
	if rarity then
		UIKit.gradient(toast, rarity.Color, rarity.Color2, 0)
	else
		UIKit.gradient(toast, UIKit.lighten(color, 0.15), UIKit.darken(color, 0.15))
	end
	UIKit.stroke(toast, 3, UIKit.Colors.Outline, true)
	UIKit.gloss(toast, 20)
	UIKit.label(toast, {
		Text = text,
		Size = UDim2.new(1, -30, 1, -12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 52,
	})
	UIKit.pop(toast, 0.5)
	if k == "error" then
		Sound.play("Error")
	elseif rarity then
		Sound.play("Rare")
	end
	task.delay(k == "error" and 2.2 or 3.2, function()
		local s = toast:FindFirstChild("BounceScale") :: UIScale?
		if s then
			local t = TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
			t:Play()
			t.Completed:Wait()
		end
		toast:Destroy()
	end)
	-- keep at most 4 toasts
	local toasts = {}
	for _, c in ipairs(toastHolder:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(toasts, c)
		end
	end
	if #toasts > 4 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
end

-- "+1 Rusty Can" card with a 3D icon.
function Notify.item(scrapId: string, amount: number, opts: { [string]: any }?)
	local o = opts or {}
	local def = Config.Scraps[scrapId]
	if not def then
		return
	end
	local rarity = Config.Rarities[def.Rarity]
	order += 1
	local card = UIKit.new("Frame", {
		Name = "ItemPopup",
		Size = UDim2.new(0, 320, 0, 64),
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
		ZIndex = 40,
		Parent = itemHolder,
	})
	UIKit.corner(card, 16)
	UIKit.gradient(card, UIKit.lighten(rarity.Color, 0.35), rarity.Color2, 90)
	UIKit.stroke(card, 3, UIKit.Colors.Outline, true)
	local iconBox = UIKit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.4,
		Size = UDim2.fromOffset(54, 54),
		Position = UDim2.fromOffset(5, 5),
		ZIndex = 41,
		Parent = card,
	})
	UIKit.corner(iconBox, 12)
	UIKit.viewport(iconBox, ScrapModels.create(scrapId, o.Clean == true), { ZIndex = 42, Spin = true, SpinSpeed = 1.6 })
	local prefix = o.Prefix or "+"
	UIKit.label(card, {
		Text = string.format("%s%d %s", prefix, amount, def.Name),
		Size = UDim2.new(1, -76, 0, 30),
		Position = UDim2.fromOffset(66, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 42,
	})
	local sub = o.Sub or string.upper(rarity.Name)
	if o.Lucky then
		sub = "🍀 LUCKY x2!  " .. sub
	end
	if o.New then
		sub = "✨ NEW!  " .. sub
	end
	UIKit.label(card, {
		Text = sub,
		Size = UDim2.new(1, -76, 0, 20),
		Position = UDim2.fromOffset(66, 38),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 255, 210),
		ZIndex = 42,
		StrokeThickness = 2,
	})
	UIKit.pop(card, 0.4)
	task.delay(2.4, function()
		local tween = TweenService:Create(card, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
		tween:Play()
		for _, d in ipairs(card:GetDescendants()) do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			elseif d:IsA("ViewportFrame") then
				TweenService:Create(d, TweenInfo.new(0.3), { ImageTransparency = 1 }):Play()
			elseif d:IsA("Frame") then
				TweenService:Create(d, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			end
		end
		task.wait(0.32)
		card:Destroy()
	end)
	local items = {}
	for _, c in ipairs(itemHolder:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(items, c)
		end
	end
	if #items > 3 then
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		items[1]:Destroy()
	end
end

-- Big centre banner (zone unlocked, machine built...).
function Notify.banner(title: string, subtitle: string?, color: Color3?)
	local c = color or UIKit.Colors.Yellow
	local holder = UIKit.new("Frame", {
		Name = "Banner",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 640, 0, 130),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 60,
		Parent = gui,
	})
	-- rays
	local rays = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(300, 300),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 60,
		Parent = holder,
	})
	for i = 0, 7 do
		local ray = UIKit.new("Frame", {
			Size = UDim2.new(0, 26, 1, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = i * 22.5,
			BackgroundColor3 = UIKit.lighten(c, 0.4),
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = 60,
			Parent = rays,
		})
		UIKit.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 90,
			Parent = ray,
		})
	end
	local t = UIKit.label(holder, {
		Text = title,
		Size = UDim2.new(1, 0, 0, 78),
		Position = UDim2.fromScale(0.5, 0.38),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = UIKit.lighten(c, 0.3),
		ZIndex = 62,
		StrokeThickness = 5,
	})
	UIKit.gradient(t, Color3.new(1, 1, 1), c, 90)
	if subtitle then
		UIKit.label(holder, {
			Text = subtitle,
			Size = UDim2.new(1, 0, 0, 34),
			Position = UDim2.fromScale(0.5, 0.85),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 62,
			StrokeThickness = 3,
		})
	end
	UIKit.pop(holder, 0.2)
	Sound.play("Purchase")
	local spin = true
	task.spawn(function()
		while spin and rays.Parent do
			rays.Rotation += 1
			task.wait()
		end
	end)
	task.delay(2.2, function()
		local s = holder:FindFirstChild("BounceScale") :: UIScale?
		if s then
			local tw = TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
			tw:Play()
			tw.Completed:Wait()
		end
		spin = false
		holder:Destroy()
	end)
end

-- Floating "+$123" that drifts up from a screen position.
function Notify.floatText(text: string, position: UDim2, color: Color3?)
	local l = UIKit.label(gui, {
		Text = text,
		Size = UDim2.fromOffset(240, 44),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = color or UIKit.Colors.Cash,
		ZIndex = 70,
		StrokeThickness = 3,
	})
	UIKit.pop(l, 0.3)
	local tween = TweenService:Create(l, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = position - UDim2.fromOffset(0, 70),
		TextTransparency = 1,
	})
	tween:Play()
	local st = l:FindFirstChildOfClass("UIStroke")
	if st then
		TweenService:Create(st, TweenInfo.new(1.2), { Transparency = 1 }):Play()
	end
	task.delay(1.25, function()
		l:Destroy()
	end)
end

function Notify.cash(amount: number)
	Sound.play("Cash")
	Notify.floatText("+" .. Format.cash(amount), UDim2.new(0, 190, 0, 70))
end

return Notify
