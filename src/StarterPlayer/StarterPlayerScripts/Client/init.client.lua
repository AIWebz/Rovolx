-- Scrapyard Simulator — client entry point.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local actionRemote = remotes:WaitForChild("Action") :: RemoteFunction

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local State = require(script.State)
local UIKit = require(script.UIKit)
local Sound = require(script.Sound)
local Notify = require(script.Notify)
local HUD = require(script.HUD)
local Panels = require(script.Panels)
local CleaningGame = require(script.CleaningGame)
local ToolController = require(script.ToolController)
local WorldFX = require(script.WorldFX)

-- Screen -------------------------------------------------------------
local screen = Instance.new("ScreenGui")
screen.Name = "ScrapyardUI"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = player:WaitForChild("PlayerGui")

-- scale the whole UI with the screen size (phones -> big monitors)
local uiScale = Instance.new("UIScale")
uiScale.Parent = screen
local function rescale()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local size = cam.ViewportSize
	uiScale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.5, 1.25)
end
rescale()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
end)

-- Requests -----------------------------------------------------------
local function request(name: string, a: any?, b: any?): (boolean, any)
	local ok, result, extra = pcall(function()
		return actionRemote:InvokeServer(name, a, b)
	end)
	if not ok then
		return false, "Connection problem, try again"
	end
	return result == true, extra
end

-- Modules ------------------------------------------------------------
Notify.init(screen)
CleaningGame.init(screen, request)
Panels.init(screen, request, function(session, station)
	CleaningGame.start(session, station)
end)
HUD.init(screen, function(name, ctx)
	if CleaningGame.Active then
		return
	end
	Panels.open(name, ctx)
end, request)
ToolController.init(remotes, function()
	return CleaningGame.Active or Panels.isOpen()
end)
WorldFX.init(function(name, ctx)
	if CleaningGame.Active then
		return
	end
	Panels.open(name, ctx)
end)

-- Server events -------------------------------------------------------
local lastCash: number? = nil
local lastWeakToast = 0
remotes:WaitForChild("State").OnClientEvent:Connect(function(data)
	State.set(data)
	lastCash = data.Cash
end)

remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text, kind)
	Notify.toast(text, kind)
end)

remotes:WaitForChild("Open").OnClientEvent:Connect(function(name, ctx)
	if name == "CloseCleaning" then
		CleaningGame.close()
		return
	end
	if CleaningGame.Active then
		return
	end
	Panels.open(name, ctx)
end)

remotes:WaitForChild("FX").OnClientEvent:Connect(function(payload)
	local kind = payload.Kind
	WorldFX.onFX(payload)
	if kind == "Collect" then
		local rarity = Config.Rarities[payload.Rarity]
		if rarity and rarity.Order >= 3 then
			Sound.play("Rare")
		else
			Sound.play("Collect", 0.9 + math.random() * 0.3)
		end
		Notify.item(payload.ScrapId, payload.Amount, {
			Lucky = payload.Lucky,
			New = payload.New,
			Sub = payload.Source == "Crane" and "🧲 MAGNET CRANE" or nil,
		})
		if payload.New then
			Notify.toast("✨ New scrap discovered: " .. Config.Scraps[payload.ScrapId].Name .. "!", payload.Rarity)
		end
	elseif kind == "Sell" then
		Notify.cash(payload.Amount)
		if payload.Source == "AutoSeller" then
			Notify.toast(string.format("🏭 Conveyor sold %d scrap for %s", payload.Count, Format.cash(payload.Amount)), "success")
		else
			Notify.banner("SOLD!", string.format("%d scrap for %s", payload.Count, Format.cash(payload.Amount)), UIKit.Colors.Green)
		end
	elseif kind == "Purchase" then
		Sound.play("Purchase")
		Notify.toast("✅ " .. payload.Text, "success")
	elseif kind == "ZoneUnlocked" then
		Sound.play("Purchase")
	elseif kind == "Machine" then
		Notify.toast(payload.Text, "info")
	elseif kind == "BackpackFull" then
		HUD.backpackFull()
	elseif kind == "TooWeak" then
		if os.clock() - lastWeakToast > 4 then
			lastWeakToast = os.clock()
			Notify.toast("This scrap is too tough! Buy a stronger tool. 🔧", "error")
		end
	end
end)

local _ = lastCash
