-- Panels: every pop-up menu (Backpack, Tools, Upgrades, Machines, Sell,
-- Zones, and the wash-station item picker).

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ScrapModels = require(ReplicatedStorage.Shared.ScrapModels)
local ToolModels = require(ReplicatedStorage.Shared.ToolModels)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Notify = require(script.Parent.Notify)
local Sound = require(script.Parent.Sound)

local Panels = {}

type PanelDef = {
	Title: string,
	Emoji: string,
	Color: Color3,
	Size: UDim2?,
	Build: (Frame) -> (),
	Refresh: (Frame, any) -> (),
	Frame: Frame?,
	Content: Frame?,
}

local gui: ScreenGui
local overlay: Frame
local defs: { [string]: PanelDef } = {}
local current: string? = nil
local currentCtx: any = nil
local request: (string, any?, any?) -> (boolean, any)
local onStartCleaning: (any, number) -> ()

local C = UIKit.Colors

----------------------------------------------------------------------
-- Shared bits
----------------------------------------------------------------------
local function scrapViewport(parent: Instance, scrapId: string, clean: boolean, silhouette: boolean?, spin: boolean?)
	local holder = UIKit.new("Frame", {
		Name = "IconBox",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.35,
		Size = UDim2.new(1, -16, 0, 104),
		Position = UDim2.fromOffset(8, 8),
		ZIndex = 14,
		Parent = parent,
	})
	UIKit.corner(holder, 12)
	local rarity = Config.Rarities[Config.Scraps[scrapId].Rarity]
	UIKit.gradient(holder, UIKit.lighten(rarity.Color, 0.6), UIKit.lighten(rarity.Color2, 0.3))
	local model = ScrapModels.create(scrapId, clean)
	if silhouette then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Color = Color3.fromRGB(30, 32, 50)
				d.Material = Enum.Material.SmoothPlastic
				d.Reflectance = 0
				d.Transparency = (d.Transparency > 0.9) and 1 or 0
			end
		end
	end
	UIKit.viewport(holder, model, { ZIndex = 15, Spin = spin, SpinSpeed = 0.7, Angle = 0.5 })
	return holder
end

local function starText(stars: number): string
	if stars <= 0 then
		return "DIRTY"
	end
	return string.rep("★", stars) .. string.rep("☆", 3 - stars)
end

local function priceButton(parent: Instance, opts)
	return UIKit.button(parent, opts)
end

local function emptyMessage(parent: Instance, text: string)
	UIKit.label(parent, {
		Name = "Empty",
		Text = text,
		Size = UDim2.new(1, -40, 0, 80),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = C.DarkText,
		StrokeThickness = 0,
		ZIndex = 14,
	})
end

----------------------------------------------------------------------
-- Inventory
----------------------------------------------------------------------
local inventoryTab = "Backpack"

defs.Inventory = {
	Title = "Backpack",
	Emoji = "🎒",
	Color = Color3.fromRGB(255, 150, 50),
	Build = function(content)
		local top =
			UIKit.new("Frame", { Name = "Top", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), ZIndex = 13, Parent = content })
		local tabs = { { "Backpack", "🎒 Backpack" }, { "Collection", "📖 Collection" } }
		for i, t in ipairs(tabs) do
			UIKit.button(top, {
				Name = "Tab" .. t[1],
				Text = t[2],
				Color = C.Grey,
				Size = UDim2.fromOffset(160, 40),
				Position = UDim2.fromOffset((i - 1) * 170, 0),
				ZIndex = 14,
				OnClick = function()
					inventoryTab = t[1]
					Panels.refresh()
				end,
			})
		end
		local _, fill = UIKit.bar(top, {
			Name = "Capacity",
			Size = UDim2.new(0, 220, 0, 24),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Color = C.Orange,
			ZIndex = 14,
		})
		local _ = fill
		UIKit.label(top, {
			Name = "CapText",
			Text = "",
			Size = UDim2.new(0, 220, 0, 20),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			ZIndex = 17,
			StrokeThickness = 2,
		})
		local body = UIKit.new("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -54),
			Position = UDim2.fromOffset(0, 54),
			ZIndex = 13,
			Parent = content,
		})
		UIKit.scrollGrid(body, UDim2.fromOffset(148, 196), 12)
	end,
	Refresh = function(content)
		local d = State.Data
		local top = content:FindFirstChild("Top") :: Frame
		for _, name in ipairs({ "Backpack", "Collection" }) do
			local tab = top:FindFirstChild("Tab" .. name) :: TextButton
			UIKit.setButton(tab, name == "Backpack" and "🎒 Backpack" or "📖 Collection", inventoryTab == name and C.Orange or C.Grey)
		end
		local count, cap = State.itemCount(), State.capacity()
		local barBack = top:FindFirstChild("Capacity") :: Frame
		local fill = barBack:FindFirstChild("Fill") :: Frame
		fill.Size = UDim2.fromScale(math.clamp(count / math.max(cap, 1), 0, 1), 1)
		local capText = top:FindFirstChild("CapText") :: TextLabel
		capText.Text = string.format("%d / %d", count, cap)

		local grid = (content:FindFirstChild("Body") :: Frame):FindFirstChild("Grid") :: ScrollingFrame
		UIKit.clear(grid)
		local old = grid.Parent:FindFirstChild("Empty")
		if old then
			old:Destroy()
		end

		if inventoryTab == "Backpack" then
			local stacks = State.stacks()
			if #stacks == 0 then
				emptyMessage(grid.Parent :: Instance, "Your backpack is empty!\nGrab a tool and collect scrap in the yard.")
				return
			end
			for i, s in ipairs(stacks) do
				local rarity = Config.Rarities[s.Def.Rarity]
				local card = UIKit.card(grid, rarity.Color, i)
				scrapViewport(card, s.Id, s.Stars > 0)
				UIKit.label(card, {
					Text = "x" .. s.Count,
					Size = UDim2.fromOffset(60, 26),
					Position = UDim2.new(1, -12, 0, 12),
					AnchorPoint = Vector2.new(1, 0),
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 17,
					StrokeThickness = 2.5,
				})
				UIKit.label(card, {
					Text = s.Def.Name,
					Size = UDim2.new(1, -12, 0, 22),
					Position = UDim2.fromOffset(6, 116),
					TextColor3 = C.DarkText,
					StrokeThickness = 0,
					ZIndex = 16,
				})
				local status = UIKit.label(card, {
					Text = s.Stars > 0 and starText(s.Stars) or "🧽 DIRTY",
					Size = UDim2.new(1, -12, 0, 22),
					Position = UDim2.fromOffset(6, 138),
					TextColor3 = s.Stars > 0 and C.Yellow or Color3.fromRGB(190, 120, 70),
					ZIndex = 16,
					StrokeThickness = 2,
				})
				local _ = status
				UIKit.rarityChip(
					card,
					rarity,
					{ Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(110, 22) }
				)
			end
		else
			local ids = {}
			for id in pairs(Config.Scraps) do
				table.insert(ids, id)
			end
			table.sort(ids, function(a, b)
				local ra = Config.Rarities[Config.Scraps[a].Rarity].Order
				local rb = Config.Rarities[Config.Scraps[b].Rarity].Order
				if ra ~= rb then
					return ra < rb
				end
				return Config.Scraps[a].Value < Config.Scraps[b].Value
			end)
			for i, id in ipairs(ids) do
				local def = Config.Scraps[id]
				local rarity = Config.Rarities[def.Rarity]
				local found = d.Discovered[id] == true
				local card = UIKit.card(grid, found and rarity.Color or C.Grey, i)
				scrapViewport(card, id, true, not found)
				UIKit.label(card, {
					Text = found and def.Name or "???",
					Size = UDim2.new(1, -12, 0, 22),
					Position = UDim2.fromOffset(6, 116),
					TextColor3 = C.DarkText,
					StrokeThickness = 0,
					ZIndex = 16,
				})
				UIKit.label(card, {
					Text = found and ("Worth " .. Format.cash(def.Value) .. "+") or "Not found yet",
					Size = UDim2.new(1, -12, 0, 18),
					Position = UDim2.fromOffset(6, 140),
					TextColor3 = found and C.Cash or C.Grey,
					ZIndex = 16,
					StrokeThickness = 1.5,
				})
				UIKit.rarityChip(
					card,
					rarity,
					{ Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(110, 22) }
				)
			end
		end
	end,
}

----------------------------------------------------------------------
-- Tools
----------------------------------------------------------------------
defs.Tools = {
	Title = "Tool Shop",
	Emoji = "🔧",
	Color = Color3.fromRGB(240, 80, 80),
	Size = UDim2.fromOffset(780, 500),
	Build = function(content)
		UIKit.scrollGrid(content, UDim2.fromOffset(226, 330), 14)
	end,
	Refresh = function(content)
		local d = State.Data
		local grid = content:FindFirstChild("Grid") :: ScrollingFrame
		UIKit.clear(grid)
		for i, id in ipairs(Config.ToolOrder) do
			local def = Config.Tools[id]
			local card = UIKit.card(grid, def.Color, i)
			local box = UIKit.new("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.3,
				Size = UDim2.new(1, -16, 0, 130),
				Position = UDim2.fromOffset(8, 8),
				ZIndex = 14,
				Parent = card,
			})
			UIKit.corner(box, 12)
			UIKit.gradient(box, UIKit.lighten(def.Color, 0.7), UIKit.lighten(def.Color, 0.3))
			local model = ToolModels.create(id)
			UIKit.viewport(box, model, { ZIndex = 15, Spin = true, SpinSpeed = 0.9, Zoom = 0.9 })
			UIKit.label(card, {
				Text = def.Name,
				Size = UDim2.new(1, -12, 0, 28),
				Position = UDim2.fromOffset(6, 142),
				TextColor3 = def.Color,
				ZIndex = 16,
				StrokeThickness = 2.5,
			})
			UIKit.label(card, {
				Text = def.Description,
				Size = UDim2.new(1, -20, 0, 36),
				Position = UDim2.fromOffset(10, 172),
				TextColor3 = C.DarkText,
				Font = UIKit.BodyFont,
				TextWrapped = true,
				StrokeThickness = 0,
				ZIndex = 16,
			})
			local minRarity = "Common"
			for _, r in ipairs(Config.RarityOrder) do
				if Config.Rarities[r].MinPower <= def.Power then
					minRarity = r
				end
			end
			UIKit.label(card, {
				Text = string.format("⚡ %d   📏 %d   🎯 x%d", def.Power, def.Range, def.Targets),
				Size = UDim2.new(1, -12, 0, 22),
				Position = UDim2.fromOffset(6, 212),
				ZIndex = 16,
				StrokeThickness = 2,
			})
			UIKit.label(card, {
				Text = "Mines up to " .. minRarity,
				Size = UDim2.new(1, -12, 0, 18),
				Position = UDim2.fromOffset(6, 238),
				TextColor3 = Config.Rarities[minRarity].Color,
				ZIndex = 16,
				StrokeThickness = 2,
			})
			local owned = d.Tools[id] == true
			local equipped = d.EquippedTool == id
			local text, color
			if equipped then
				text, color = "EQUIPPED", C.Grey
			elseif owned then
				text, color = "EQUIP", C.Blue
			else
				text = "BUY " .. Format.cash(def.Price)
				color = d.Cash >= def.Price and C.Green or C.Red
			end
			priceButton(card, {
				Text = text,
				Color = color,
				Size = UDim2.new(1, -24, 0, 46),
				Position = UDim2.new(0.5, 0, 1, -10),
				AnchorPoint = Vector2.new(0.5, 1),
				ZIndex = 16,
				OnClick = function()
					if equipped then
						return
					end
					local ok, err = request(owned and "EquipTool" or "BuyTool", id)
					if not ok then
						Notify.toast(err or "Can't do that", "error")
					elseif not owned then
						Notify.banner("NEW TOOL!", def.Name, def.Color)
					end
				end,
			})
		end
	end,
}

----------------------------------------------------------------------
-- Upgrades
----------------------------------------------------------------------
defs.Upgrades = {
	Title = "Upgrades",
	Emoji = "⬆️",
	Color = Color3.fromRGB(80, 210, 110),
	Build = function(content)
		UIKit.scrollList(content, 10)
	end,
	Refresh = function(content)
		local d = State.Data
		local list = content:FindFirstChild("List") :: ScrollingFrame
		UIKit.clear(list)
		for i, id in ipairs(Config.UpgradeOrder) do
			local def = Config.Upgrades[id]
			local lvl = d.Upgrades[id] or 0
			local maxed = lvl >= def.MaxLevel
			local cost = Config.UpgradeCost(id, lvl)
			local row = UIKit.card(list, def.Color, i)
			row.Size = UDim2.new(1, -8, 0, 92)
			local iconBox = UIKit.new("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				Size = UDim2.fromOffset(70, 70),
				Position = UDim2.fromOffset(11, 11),
				ZIndex = 14,
				Parent = row,
			})
			UIKit.corner(iconBox, 16)
			UIKit.gradient(iconBox, UIKit.lighten(def.Color, 0.3), UIKit.darken(def.Color, 0.15))
			UIKit.stroke(iconBox, 3, C.Outline, true)
			UIKit.label(iconBox, {
				Text = def.Emoji,
				Font = Enum.Font.GothamBold,
				Size = UDim2.fromScale(0.8, 0.8),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				StrokeThickness = 0,
				ZIndex = 15,
			})
			UIKit.label(row, {
				Text = def.Name,
				Size = UDim2.new(0, 260, 0, 30),
				Position = UDim2.fromOffset(94, 8),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = UIKit.darken(def.Color, 0.1),
				ZIndex = 15,
				StrokeThickness = 2.5,
			})
			UIKit.label(row, {
				Text = string.format("Lv %d/%d", lvl, def.MaxLevel),
				Size = UDim2.new(0, 100, 0, 24),
				Position = UDim2.fromOffset(330, 12),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = C.DarkText,
				StrokeThickness = 0,
				ZIndex = 15,
			})
			local desc = maxed and def.Describe(lvl) or (def.Describe(lvl) .. "  →  " .. def.Describe(lvl + 1))
			UIKit.label(row, {
				Text = desc,
				Size = UDim2.new(1, -300, 0, 20),
				Position = UDim2.fromOffset(94, 40),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = C.DarkText,
				Font = UIKit.BodyFont,
				StrokeThickness = 0,
				ZIndex = 15,
			})
			local _, fill =
				UIKit.bar(row, { Size = UDim2.new(1, -300, 0, 12), Position = UDim2.fromOffset(94, 68), Color = def.Color, ZIndex = 15 })
			fill.Size = UDim2.fromScale(lvl / def.MaxLevel, 1)
			priceButton(row, {
				Text = maxed and "MAXED" or Format.cash(cost),
				Color = maxed and C.Grey or (d.Cash >= cost and C.Green or C.Red),
				Size = UDim2.fromOffset(170, 56),
				Position = UDim2.new(1, -14, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				ZIndex = 16,
				OnClick = function()
					if maxed then
						return
					end
					local ok, err = request("BuyUpgrade", id)
					if ok then
						Sound.play("Purchase")
					else
						Notify.toast(err or "Can't buy that", "error")
					end
				end,
			})
		end
	end,
}

----------------------------------------------------------------------
-- Machines
----------------------------------------------------------------------
defs.Machines = {
	Title = "Machines",
	Emoji = "⚙️",
	Color = Color3.fromRGB(70, 150, 255),
	Build = function(content)
		UIKit.scrollList(content, 10)
	end,
	Refresh = function(content, ctx)
		local d = State.Data
		local list = content:FindFirstChild("List") :: ScrollingFrame
		UIKit.clear(list)
		for i, id in ipairs(Config.MachineOrder) do
			local def = Config.Machines[id]
			local lvl = d.Machines[id] or 0
			local maxed = lvl >= def.MaxLevel
			local cost = Config.MachineCost(id, lvl)
			local row = UIKit.card(list, def.Color, i)
			row.Size = UDim2.new(1, -8, 0, 100)
			if ctx and ctx.MachineId == id then
				local border = row:FindFirstChild("Border") :: UIStroke
				border.Color = C.Yellow
				border.Thickness = 5
				task.defer(function()
					list.CanvasPosition = Vector2.new(0, math.max(0, (i - 1) * 110 - 20))
				end)
			end
			local iconBox = UIKit.new("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				Size = UDim2.fromOffset(78, 78),
				Position = UDim2.fromOffset(11, 11),
				ZIndex = 14,
				Parent = row,
			})
			UIKit.corner(iconBox, 18)
			UIKit.gradient(iconBox, UIKit.lighten(def.Color, 0.3), UIKit.darken(def.Color, 0.15))
			UIKit.stroke(iconBox, 3, C.Outline, true)
			UIKit.label(iconBox, {
				Text = def.Emoji,
				Font = Enum.Font.GothamBold,
				Size = UDim2.fromScale(0.8, 0.8),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				StrokeThickness = 0,
				ZIndex = 15,
			})
			UIKit.label(row, {
				Text = def.Name,
				Size = UDim2.new(0, 260, 0, 30),
				Position = UDim2.fromOffset(102, 8),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = UIKit.darken(def.Color, 0.1),
				ZIndex = 15,
				StrokeThickness = 2.5,
			})
			local stars = ""
			for s = 1, def.MaxLevel do
				stars ..= (s <= lvl) and "●" or "○"
			end
			UIKit.label(row, {
				Text = lvl == 0 and "NOT BUILT" or stars,
				Size = UDim2.new(0, 120, 0, 22),
				Position = UDim2.fromOffset(330, 12),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = lvl == 0 and C.Red or C.Yellow,
				StrokeThickness = 2,
				ZIndex = 15,
			})
			local now = lvl > 0 and ("Now: " .. def.Describe(lvl)) or "Not built yet"
			local nxt = maxed and "Fully upgraded!" or ((lvl == 0 and "Builds: " or "Next: ") .. def.Describe(lvl + 1))
			UIKit.label(row, {
				Text = now,
				Size = UDim2.new(1, -310, 0, 20),
				Position = UDim2.fromOffset(102, 42),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = C.DarkText,
				Font = UIKit.BodyFont,
				TextWrapped = true,
				StrokeThickness = 0,
				ZIndex = 15,
			})
			UIKit.label(row, {
				Text = nxt,
				Size = UDim2.new(1, -310, 0, 20),
				Position = UDim2.fromOffset(102, 66),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(40, 150, 70),
				Font = UIKit.BodyFont,
				TextWrapped = true,
				StrokeThickness = 0,
				ZIndex = 15,
			})
			priceButton(row, {
				Text = maxed and "MAXED" or ((lvl == 0 and "BUILD " or "UPGRADE ") .. Format.cash(cost)),
				Color = maxed and C.Grey or (d.Cash >= cost and C.Green or C.Red),
				Size = UDim2.fromOffset(190, 58),
				Position = UDim2.new(1, -14, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				ZIndex = 16,
				OnClick = function()
					if maxed then
						return
					end
					local ok, err = request("BuyMachine", id)
					if ok then
						if lvl == 0 then
							Notify.banner("MACHINE BUILT!", def.Name, def.Color)
						else
							Sound.play("Purchase")
						end
					else
						Notify.toast(err or "Can't buy that", "error")
					end
				end,
			})
		end
	end,
}

----------------------------------------------------------------------
-- Sell
----------------------------------------------------------------------
defs.Sell = {
	Title = "Scrap Exchange",
	Emoji = "💰",
	Color = Color3.fromRGB(60, 200, 100),
	Build = function(content)
		local top =
			UIKit.new("Frame", { Name = "Top", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), ZIndex = 13, Parent = content })
		UIKit.label(top, {
			Name = "Summary",
			Text = "",
			Size = UDim2.new(1, -300, 0, 28),
			Position = UDim2.fromOffset(4, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.DarkText,
			StrokeThickness = 0,
			ZIndex = 14,
		})
		UIKit.label(top, {
			Name = "Dirty",
			Text = "",
			Size = UDim2.new(1, -300, 0, 22),
			Position = UDim2.fromOffset(4, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(190, 110, 60),
			Font = UIKit.BodyFont,
			StrokeThickness = 0,
			ZIndex = 14,
		})
		UIKit.button(top, {
			Name = "SellAll",
			Text = "SELL ALL",
			Color = C.Green,
			Size = UDim2.fromOffset(270, 60),
			Position = UDim2.new(1, -4, 0, 2),
			AnchorPoint = Vector2.new(1, 0),
			ZIndex = 14,
			OnClick = function()
				local ok, res = request("Sell", "All")
				if not ok then
					Notify.toast(res or "Nothing to sell", "error")
				end
			end,
		})
		local body = UIKit.new("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -76),
			Position = UDim2.fromOffset(0, 76),
			ZIndex = 13,
			Parent = content,
		})
		UIKit.scrollList(body, 8)
	end,
	Refresh = function(content)
		local d = State.Data
		local top = content:FindFirstChild("Top") :: Frame
		local list = (content:FindFirstChild("Body") :: Frame):FindFirstChild("List") :: ScrollingFrame
		UIKit.clear(list)
		local old = list.Parent:FindFirstChild("Empty")
		if old then
			old:Destroy()
		end
		local stacks = State.stacks(function(_, stars)
			return stars > 0
		end)
		local total, count = 0, 0
		for _, s in ipairs(stacks) do
			local each = Config.SellPrice(s.Id, s.Stars, d.Upgrades.SellBonus or 0, d.Machines.PolishLab or 0)
			total += each * s.Count
			count += s.Count
		end
		top:FindFirstChild("Summary").Text =
			string.format("%d clean item%s  •  Worth %s", count, count == 1 and "" or "s", Format.cash(total))
		local dirty = State.dirtyCount()
		top:FindFirstChild("Dirty").Text = dirty > 0
				and string.format("🧽 %d dirty item%s must be washed before selling", dirty, dirty == 1 and "" or "s")
			or ""
		UIKit.setButton(
			top:FindFirstChild("SellAll") :: TextButton,
			count > 0 and ("SELL ALL " .. Format.cash(total)) or "SELL ALL",
			count > 0 and C.Green or C.Grey
		)
		if #stacks == 0 then
			emptyMessage(list.Parent :: Instance, "No clean scrap to sell!\nWash your scrap at a Wash Station first. 🫧")
			return
		end
		for i, s in ipairs(stacks) do
			local rarity = Config.Rarities[s.Def.Rarity]
			local each = Config.SellPrice(s.Id, s.Stars, d.Upgrades.SellBonus or 0, d.Machines.PolishLab or 0)
			local row = UIKit.card(list, rarity.Color, i)
			row.Size = UDim2.new(1, -8, 0, 84)
			local iconBox = UIKit.new("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.3,
				Size = UDim2.fromOffset(68, 68),
				Position = UDim2.fromOffset(8, 8),
				ZIndex = 14,
				Parent = row,
			})
			UIKit.corner(iconBox, 12)
			UIKit.gradient(iconBox, UIKit.lighten(rarity.Color, 0.6), UIKit.lighten(rarity.Color2, 0.3))
			UIKit.viewport(iconBox, ScrapModels.create(s.Id, true), { ZIndex = 15 })
			UIKit.label(row, {
				Text = string.format("%s  x%d", s.Def.Name, s.Count),
				Size = UDim2.new(0, 300, 0, 28),
				Position = UDim2.fromOffset(88, 10),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = C.DarkText,
				StrokeThickness = 0,
				ZIndex = 15,
			})
			UIKit.label(row, {
				Text = starText(s.Stars),
				Size = UDim2.new(0, 90, 0, 24),
				Position = UDim2.fromOffset(88, 44),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = C.Yellow,
				StrokeThickness = 2,
				ZIndex = 15,
			})
			UIKit.rarityChip(row, rarity, { Position = UDim2.fromOffset(186, 46) })
			UIKit.label(row, {
				Text = Format.cash(each) .. " each",
				Size = UDim2.new(0, 140, 0, 22),
				Position = UDim2.new(1, -170, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Color3.fromRGB(40, 150, 70),
				Font = UIKit.BodyFont,
				StrokeThickness = 0,
				ZIndex = 15,
			})
			priceButton(row, {
				Text = "SELL " .. Format.cash(each * s.Count),
				Color = C.Green,
				Size = UDim2.fromOffset(150, 52),
				Position = UDim2.new(1, -12, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				ZIndex = 16,
				OnClick = function()
					local ok, res = request("Sell", s.Key)
					if not ok then
						Notify.toast(res or "Can't sell", "error")
					end
				end,
			})
		end
	end,
}

----------------------------------------------------------------------
-- Zones
----------------------------------------------------------------------
defs.Zones = {
	Title = "Zones",
	Emoji = "🗺️",
	Color = Color3.fromRGB(170, 100, 255),
	Size = UDim2.fromOffset(820, 500),
	Build = function(content)
		UIKit.scrollGrid(content, UDim2.fromOffset(186, 360), 12)
	end,
	Refresh = function(content)
		local d = State.Data
		local grid = content:FindFirstChild("Grid") :: ScrollingFrame
		UIKit.clear(grid)
		for i, id in ipairs(Config.ZoneOrder) do
			local def = Config.Zones[id]
			local unlocked = d.Zones[id] == true
			local prev = Config.ZoneOrder[def.Order - 1]
			local available = not prev or d.Zones[prev] == true
			local card = UIKit.card(grid, def.Color, i)
			local banner = UIKit.new("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				Size = UDim2.new(1, -16, 0, 100),
				Position = UDim2.fromOffset(8, 8),
				ZIndex = 14,
				Parent = card,
			})
			UIKit.corner(banner, 12)
			UIKit.gradient(banner, UIKit.lighten(def.Color, 0.25), UIKit.darken(def.Color, 0.3))
			UIKit.label(banner, {
				Text = def.Emoji,
				Font = Enum.Font.GothamBold,
				Size = UDim2.fromScale(0.6, 0.8),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				StrokeThickness = 0,
				ZIndex = 15,
			})
			if not unlocked then
				UIKit.label(banner, {
					Text = "🔒",
					Font = Enum.Font.GothamBold,
					Size = UDim2.fromOffset(34, 34),
					Position = UDim2.new(1, -4, 0, 4),
					AnchorPoint = Vector2.new(1, 0),
					StrokeThickness = 0,
					ZIndex = 16,
				})
			end
			UIKit.label(card, {
				Text = def.Name,
				Size = UDim2.new(1, -12, 0, 28),
				Position = UDim2.fromOffset(6, 112),
				TextColor3 = UIKit.darken(def.Color, 0.1),
				ZIndex = 15,
				StrokeThickness = 2.5,
			})
			-- drop chances
			local total = 0
			for _, w in pairs(def.Weights) do
				total += w
			end
			local y = 146
			for _, r in ipairs(Config.RarityOrder) do
				local w = def.Weights[r]
				if w then
					local rarity = Config.Rarities[r]
					UIKit.rarityChip(card, rarity, { Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(100, 20) })
					UIKit.label(card, {
						Text = string.format("%d%%", math.floor(w / total * 100 + 0.5)),
						Size = UDim2.fromOffset(56, 20),
						Position = UDim2.fromOffset(118, y),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextColor3 = C.DarkText,
						StrokeThickness = 0,
						ZIndex = 15,
					})
					y += 26
				end
			end
			local text, color
			if unlocked then
				text, color = "TELEPORT", C.Blue
			elseif not available then
				text, color = "🔒 LOCKED", C.Grey
			else
				text = "UNLOCK " .. Format.cash(def.Price)
				color = d.Cash >= def.Price and C.Green or C.Red
			end
			priceButton(card, {
				Text = text,
				Color = color,
				Size = UDim2.new(1, -20, 0, 48),
				Position = UDim2.new(0.5, 0, 1, -10),
				AnchorPoint = Vector2.new(0.5, 1),
				ZIndex = 16,
				OnClick = function()
					if unlocked then
						local ok, err = request("Teleport", id)
						if ok then
							Panels.close()
						else
							Notify.toast(err or "Can't teleport", "error")
						end
					elseif available then
						local ok, err = request("UnlockZone", id)
						if ok then
							Notify.banner("ZONE UNLOCKED!", def.Emoji .. " " .. def.Name, def.Color)
						else
							Notify.toast(err or "Can't unlock", "error")
						end
					else
						Notify.toast("Unlock " .. Config.Zones[prev].Name .. " first!", "error")
					end
				end,
			})
		end
	end,
}

----------------------------------------------------------------------
-- Wash station item picker
----------------------------------------------------------------------
defs.CleanSelect = {
	Title = "Pick scrap to wash",
	Emoji = "🫧",
	Color = Color3.fromRGB(60, 170, 255),
	Build = function(content)
		UIKit.label(content, {
			Name = "Hint",
			Text = "",
			Size = UDim2.new(1, 0, 0, 24),
			TextColor3 = C.DarkText,
			Font = UIKit.BodyFont,
			StrokeThickness = 0,
			ZIndex = 14,
		})
		local body = UIKit.new("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -34),
			Position = UDim2.fromOffset(0, 34),
			ZIndex = 13,
			Parent = content,
		})
		UIKit.scrollGrid(body, UDim2.fromOffset(148, 214), 12)
	end,
	Refresh = function(content, ctx)
		local d = State.Data
		local batch = Config.WashBatch(d.Upgrades.WashTub or 0)
		content:FindFirstChild("Hint").Text = string.format("Your tub washes up to %d of the same scrap at once  🛁", batch)
		local grid = (content:FindFirstChild("Body") :: Frame):FindFirstChild("Grid") :: ScrollingFrame
		UIKit.clear(grid)
		local stacks = State.stacks(function(_, stars)
			return stars == 0
		end)
		if #stacks == 0 then
			Panels.close()
			Notify.toast("No dirty scrap left!", "info")
			return
		end
		for i, s in ipairs(stacks) do
			local rarity = Config.Rarities[s.Def.Rarity]
			local card = UIKit.card(grid, rarity.Color, i)
			scrapViewport(card, s.Id, false, false, true)
			UIKit.label(card, {
				Text = "x" .. s.Count,
				Size = UDim2.fromOffset(60, 26),
				Position = UDim2.new(1, -12, 0, 12),
				AnchorPoint = Vector2.new(1, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 17,
				StrokeThickness = 2.5,
			})
			UIKit.label(card, {
				Text = s.Def.Name,
				Size = UDim2.new(1, -12, 0, 22),
				Position = UDim2.fromOffset(6, 116),
				TextColor3 = C.DarkText,
				StrokeThickness = 0,
				ZIndex = 16,
			})
			UIKit.rarityChip(
				card,
				rarity,
				{ Position = UDim2.new(0.5, 0, 0, 142), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(110, 20) }
			)
			local n = math.min(batch, s.Count)
			UIKit.button(card, {
				Text = "WASH x" .. n,
				Color = C.Blue,
				Size = UDim2.new(1, -20, 0, 38),
				Position = UDim2.new(0.5, 0, 1, -8),
				AnchorPoint = Vector2.new(0.5, 1),
				ZIndex = 16,
				OnClick = function()
					local ok, session = request("StartCleaning", ctx and ctx.Station, s.Id)
					if ok then
						Panels.close()
						onStartCleaning(session, ctx.Station)
					else
						Notify.toast(session or "Can't start washing", "error")
					end
				end,
			})
		end
	end,
}

----------------------------------------------------------------------
-- Framework
----------------------------------------------------------------------
function Panels.init(screen: ScreenGui, requestFn, startCleaningFn)
	gui = screen
	request = requestFn
	onStartCleaning = startCleaningFn
	overlay = UIKit.new("TextButton", {
		Name = "Overlay",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(10, 12, 30),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 9,
		Parent = gui,
	})
	overlay.Activated:Connect(function()
		Panels.close()
	end)
	for name, def in pairs(defs) do
		local frame, content, close = UIKit.panel(gui, {
			Name = name .. "Panel",
			Title = def.Title,
			Emoji = def.Emoji,
			Color = def.Color,
			Size = def.Size or UDim2.fromOffset(760, 500),
		})
		def.Frame = frame
		def.Content = content
		def.Build(content)
		close.Activated:Connect(function()
			Sound.play("Click")
			Panels.close()
		end)
	end
	State.Changed.Event:Connect(function()
		if current then
			Panels.refresh()
		end
	end)
end

function Panels.refresh()
	if not current or not State.Data then
		return
	end
	local def = defs[current]
	def.Refresh(def.Content :: Frame, currentCtx)
end

function Panels.open(name: string, ctx: any?)
	local def = defs[name]
	if not def or not State.Data then
		return
	end
	if current == name then
		currentCtx = ctx or currentCtx
		Panels.refresh()
		return
	end
	if current then
		defs[current].Frame.Visible = false
	end
	current = name
	currentCtx = ctx
	Sound.play("Open")
	overlay.Visible = true
	TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
	local frame = def.Frame :: Frame
	frame.Visible = true
	UIKit.pop(frame, 0.75)
	Panels.refresh()
end

function Panels.close()
	if not current then
		return
	end
	local def = defs[current]
	current = nil
	currentCtx = nil
	local frame = def.Frame :: Frame
	local s = frame:FindFirstChild("BounceScale") :: UIScale?
	if s then
		local t = TweenService:Create(s, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 })
		t:Play()
	end
	TweenService:Create(overlay, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
	task.delay(0.15, function()
		if current == nil then
			overlay.Visible = false
		end
		if defs[current or ""] ~= def then
			frame.Visible = false
		end
	end)
end

function Panels.isOpen(name: string?): boolean
	if name then
		return current == name
	end
	return current ~= nil
end

return Panels
