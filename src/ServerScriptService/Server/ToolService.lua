-- ToolService: builds the player's equipped collection tool and applies
-- character stats (walk speed) from upgrades.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ToolModels = require(ReplicatedStorage.Shared.ToolModels)
local DataService = require(script.Parent.DataService)

local ToolService = {}

local function buildTool(toolId: string): Tool
	local def = Config.Tools[toolId]
	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.ToolTip = string.format("Power %d • Range %d", def.Power, def.Range)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("ToolId", toolId)
	tool.Grip = CFrame.new(0, -0.2, 0)

	local model, handle = ToolModels.create(toolId)
	for _, d in ipairs(model:GetChildren()) do
		d.Parent = tool
	end
	model:Destroy()
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			d.CastShadow = false
		end
	end
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") and d ~= handle then
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = d
			w.Parent = d
		end
	end
	-- swing / hit sounds
	local swing = Instance.new("Sound")
	swing.Name = "SwingSound"
	swing.SoundId = "rbxasset://sounds/swordslash.wav"
	swing.Volume = 0.35
	swing.PlaybackSpeed = 1.2
	swing.Parent = handle
	return tool
end

function ToolService.give(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local char = player.Character
	for _, container in ipairs({ backpack, char } :: { Instance? }) do
		if container then
			for _, t in ipairs(container:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("ToolId") then
					t:Destroy()
				end
			end
		end
	end
	if not backpack then
		return
	end
	local tool = buildTool(data.EquippedTool)
	tool.Parent = backpack
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		task.defer(function()
			if tool.Parent == backpack and humanoid.Parent and humanoid.Health > 0 then
				humanoid:EquipTool(tool)
			end
		end)
	end
end

function ToolService.applyStats(player: Player)
	local data = DataService.get(player)
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid then
		return
	end
	if player:GetAttribute("SpeedOverride") then
		return
	end
	humanoid.WalkSpeed = Config.WalkSpeed(data.Upgrades.WalkSpeed or 0)
end

function ToolService.onCharacter(player: Player, char: Model)
	local humanoid = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	ToolService.applyStats(player)
	task.wait(0.2)
	ToolService.give(player)
end

return ToolService
