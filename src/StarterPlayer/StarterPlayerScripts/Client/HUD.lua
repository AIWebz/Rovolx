-- HUD: cash + backpack counters, the side menu, the goal tracker and the
-- zone banner.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Notify = require(script.Parent.Notify)

local HUD = {}

local player = Players.LocalPlayer
local cashText: TextLabel
local cashPill: Frame
local bagText: TextLabel
local bagPill: Frame
local bagFill: Frame
local goalFrame: Frame
local goalText: TextLabel
local goalSub: TextLabel
local goalFill: Frame
local zoneBanner: TextLabel
local badges: { [string]: Frame } = {}
local displayedCash = 0
local cashValue: NumberValue
local openPanel: (string, any?) -> ()
local requestAction: (string, any?) -> (boolean, any)

HUD.CurrentGoal = nil :: any

----------------------------------------------------------------------
-- Goals (light tutorial / progression tracker)
----------------------------------------------------------------------
local GOALS = {
	{
		Text = "Collect 5 scraps in the yard",
		Target = "Scrap",
		Progress = function(d)
			return d.ScrapsCollected, 5
		end,
	},
	{
		Text = "Wash scrap at a Wash Station",
		Target = "Wash",
		Progress = function(d)
			return d.ItemsCleaned, 1
		end,
	},
	{
		Text = "Sell clean scrap at the Scrap Exchange",
		Target = "Sell",
		Progress = function(d)
			return math.min(d.TotalEarned, 1), 1
		end,
	},
	{
		Text = "Buy the Steel Crowbar",
		Target = "Tools",
		Progress = function(d)
			return d.Tools.SteelCrowbar and 1 or 0, 1
		end,
	},
	{
		Text = "Unlock Rust Canyon",
		Target = "Gate_RustCanyon",
		Progress = function(d)
			return d.Zones.RustCanyon and 1 or 0, 1
		end,
	},
	{
		Text = "Build an Auto Washer",
		Target = "Pad_AutoWasher",
		Progress = function(d)
			return math.min(d.Machines.AutoWasher or 0, 1), 1
		end,
	},
	{
		Text = "Buy the Magnet Wand",
		Target = "Tools",
		Progress = function(d)
			return d.Tools.MagnetWand and 1 or 0, 1
		end,
	},
	{
		Text = "Unlock the Toxic Wasteland",
		Target = "Gate_ToxicWaste",
		Progress = function(d)
			return d.Zones.ToxicWaste and 1 or 0, 1
		end,
	},
	{
		Text = "Buy the Hydraulic Claw",
		Target = "Tools",
		Progress = function(d)
			return d.Tools.HydraulicClaw and 1 or 0, 1
		end,
	},
	{
		Text = "Unlock the Meteor Crater",
		Target = "Gate_MeteorCrater",
		Progress = function(d)
			return d.Zones.MeteorCrater and 1 or 0, 1
		end,
	},
	{
		Text = "Discover every scrap",
		Target = nil,
		Progress = function(d)
			local n = 0
			for _ in pairs(d.Discovered) do
				n += 1
			end
			local total = 0
			for _ in pairs(Config.Scraps) do
				total += 1
			end
			return n, total
		end,
	},
}

local function currentGoal(d)
	for i, g in ipairs(GOALS) do
		local have, need = g.Progress(d)
		if have < need then
			return i, g, have, need
		end
	end
	return nil
end

----------------------------------------------------------------------
local function menuButton(parent: Instance, key: string, label: string, color: Color3, order: number, panel: string)
	local holder = UIKit.new("Frame", {
		Name = key,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(84, 98),
		LayoutOrder = order,
		Parent = parent,
	})
	local btn = UIKit.button(holder, {
		Color = color,
		Size = UDim2.fromOffset(78, 78),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Radius = 20,
		StrokeThickness = 3.5,
		OnClick = function()
			if panel == "Hub" then
				local ok, err = requestAction("Teleport", "Hub")
				if not ok and err then
					Notify.toast(err, "error")
				end
			else
				openPanel(panel)
			end
		end,
	})
	local iconBox = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -14, 1, -14),
		Position = UDim2.fromScale(0.5, 0.48),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 4,
		Parent = btn,
	})
	UIKit.icon(iconBox, key, { ZIndex = 4 })
	UIKit.label(holder, {
		Text = label,
		Size = UDim2.new(1, 8, 0, 22),
		Position = UDim2.new(0.5, 0, 1, -18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 5,
		StrokeThickness = 2.5,
	})
	local badge = UIKit.new("Frame", {
		Name = "Badge",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -2, 0, -4),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = UIKit.Colors.Red,
		Visible = false,
		ZIndex = 8,
		Parent = holder,
	})
	UIKit.round(badge)
	UIKit.stroke(badge, 2.5, UIKit.Colors.Outline, true)
	UIKit.label(badge, { Text = "!", Size = UDim2.fromScale(1, 1), ZIndex = 9, StrokeThickness = 1.5 })
	badges[panel] = badge
end

function HUD.init(gui: ScreenGui, open: (string, any?) -> (), request: (string, any?) -> (boolean, any))
	openPanel = open
	requestAction = request

	-- top-left counters
	local stats = UIKit.new("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(260, 200),
		Position = UDim2.fromOffset(40, 54),
		Parent = gui,
	})
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = stats })
	cashPill, cashText =
		UIKit.pill(stats, { Name = "Cash", Icon = "Cash", Color = Color3.fromRGB(70, 210, 90), LayoutOrder = 1, Text = "$0" })
	bagPill, bagText =
		UIKit.pill(stats, { Name = "Backpack", Icon = "Backpack", Color = Color3.fromRGB(255, 150, 50), LayoutOrder = 2, Text = "0/12" })
	local _, fill = UIKit.bar(bagPill, {
		Size = UDim2.new(1, -70, 0, 10),
		Position = UDim2.new(0, 58, 1, -6),
		Color = UIKit.Colors.Yellow,
		ZIndex = 6,
	})
	bagFill = fill
	bagText.Size = UDim2.new(1, -66, 0.62, 0)
	bagText.Position = UDim2.new(0, 56, 0.4, 0)

	-- goal tracker
	goalFrame = UIKit.new("Frame", {
		Name = "Goal",
		Size = UDim2.fromOffset(300, 74),
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = 3,
		Parent = stats,
	})
	UIKit.corner(goalFrame, 16)
	UIKit.gradient(goalFrame, Color3.fromRGB(70, 74, 110), Color3.fromRGB(40, 42, 70))
	UIKit.stroke(goalFrame, 3, UIKit.Colors.Outline, true)
	UIKit.label(goalFrame, {
		Text = "🎯 GOAL",
		Size = UDim2.new(0, 120, 0, 20),
		Position = UDim2.fromOffset(12, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UIKit.Colors.Yellow,
		ZIndex = 3,
		StrokeThickness = 2,
	})
	goalText = UIKit.label(goalFrame, {
		Text = "",
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(12, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		StrokeThickness = 2,
	})
	goalSub = UIKit.label(goalFrame, {
		Text = "",
		Size = UDim2.new(0, 70, 0, 16),
		Position = UDim2.new(1, -12, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
		StrokeThickness = 1.5,
	})
	local _, gf = UIKit.bar(goalFrame, {
		Size = UDim2.new(1, -24, 0, 10),
		Position = UDim2.new(0, 12, 1, -16),
		Color = UIKit.Colors.Yellow,
		ZIndex = 4,
	})
	goalFill = gf

	-- side menu
	local menu = UIKit.new("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(180, 340),
		Position = UDim2.new(0, 24, 0.5, 40),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = gui,
	})
	UIKit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(84, 98),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	menuButton(menu, "Backpack", "Backpack", Color3.fromRGB(255, 150, 50), 1, "Inventory")
	menuButton(menu, "Tools", "Tools", Color3.fromRGB(240, 80, 80), 2, "Tools")
	menuButton(menu, "Upgrades", "Upgrades", Color3.fromRGB(80, 210, 110), 3, "Upgrades")
	menuButton(menu, "Machines", "Machines", Color3.fromRGB(70, 150, 255), 4, "Machines")
	menuButton(menu, "Zones", "Zones", Color3.fromRGB(170, 100, 255), 5, "Zones")
	menuButton(menu, "Hub", "Hub", Color3.fromRGB(255, 200, 50), 6, "Hub")

	-- zone banner
	zoneBanner = UIKit.label(gui, {
		Name = "ZoneBanner",
		Text = "",
		Size = UDim2.fromOffset(600, 70),
		Position = UDim2.new(0.5, 0, 0, 120),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextTransparency = 1,
		StrokeThickness = 5,
		ZIndex = 30,
	})
	local st = zoneBanner:FindFirstChildOfClass("UIStroke") :: UIStroke
	st.Transparency = 1

	-- cash counter animation
	cashValue = Instance.new("NumberValue")
	cashValue.Changed:Connect(function(v)
		cashText.Text = Format.cash(v)
	end)

	State.Changed.Event:Connect(HUD.update)
	if State.Data then
		HUD.update(State.Data)
	end
	local _ = player
end

function HUD.update(d)
	if not d then
		return
	end
	-- cash
	if d.Cash ~= displayedCash then
		local diff = d.Cash - displayedCash
		displayedCash = d.Cash
		TweenService:Create(cashValue, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Value = d.Cash }):Play()
		if diff > 0 then
			UIKit.bump(cashPill, 1.12)
		end
	end
	-- backpack
	local count, cap = State.itemCount(), State.capacity()
	bagText.Text = string.format("%d/%d", count, cap)
	local frac = cap > 0 and math.clamp(count / cap, 0, 1) or 0
	TweenService:Create(bagFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(frac, 1) }):Play()
	local fillGrad = bagFill:FindFirstChildOfClass("UIGradient")
	if fillGrad then
		local c = frac >= 1 and UIKit.Colors.Red or (frac > 0.75 and UIKit.Colors.Orange or UIKit.Colors.Yellow)
		fillGrad.Color = ColorSequence.new(UIKit.lighten(c, 0.25), UIKit.darken(c, 0.1))
	end
	-- goal
	local index, goal, have, need = currentGoal(d)
	if goal then
		HUD.CurrentGoal = goal
		goalFrame.Visible = true
		goalText.Text = goal.Text
		goalSub.Text = string.format("%d/%d", math.min(have, need), need)
		TweenService:Create(goalFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(have / need, 0, 1), 1) }):Play()
		if HUD.LastGoal and HUD.LastGoal ~= index then
			Notify.toast("🎯 Goal complete!", "success")
			UIKit.bump(goalFrame, 1.1)
		end
		HUD.LastGoal = index
	else
		HUD.CurrentGoal = nil
		goalFrame.Visible = false
	end
	-- "!" badges when something is affordable
	local cash = d.Cash
	local function anyUpgrade()
		for id, def in pairs(Config.Upgrades) do
			local lvl = d.Upgrades[id] or 0
			if lvl < def.MaxLevel and Config.UpgradeCost(id, lvl) <= cash then
				return true
			end
		end
		return false
	end
	local function anyTool()
		for id, def in pairs(Config.Tools) do
			if not d.Tools[id] and def.Price <= cash then
				return true
			end
		end
		return false
	end
	local function anyMachine()
		for id, def in pairs(Config.Machines) do
			local lvl = d.Machines[id] or 0
			if lvl < def.MaxLevel and Config.MachineCost(id, lvl) <= cash then
				return true
			end
		end
		return false
	end
	local function anyZone()
		for _, id in ipairs(Config.ZoneOrder) do
			local def = Config.Zones[id]
			if not d.Zones[id] then
				local prev = Config.ZoneOrder[def.Order - 1]
				return (not prev or d.Zones[prev]) and def.Price <= cash
			end
		end
		return false
	end
	badges.Upgrades.Visible = anyUpgrade()
	badges.Tools.Visible = anyTool()
	badges.Machines.Visible = anyMachine()
	badges.Zones.Visible = anyZone()
	badges.Inventory.Visible = count >= cap
end

function HUD.backpackFull()
	UIKit.shake(bagPill)
	UIKit.bump(bagPill, 1.15)
end

function HUD.showZone(name: string, color: Color3)
	zoneBanner.Text = name
	zoneBanner.TextColor3 = color
	local st = zoneBanner:FindFirstChildOfClass("UIStroke") :: UIStroke
	zoneBanner.TextTransparency = 1
	st.Transparency = 1
	TweenService:Create(zoneBanner, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	TweenService:Create(st, TweenInfo.new(0.4), { Transparency = 0 }):Play()
	UIKit.pop(zoneBanner, 0.6)
	task.delay(2.5, function()
		if zoneBanner.Text == name then
			TweenService:Create(zoneBanner, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			TweenService:Create(st, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		end
	end)
end

return HUD
