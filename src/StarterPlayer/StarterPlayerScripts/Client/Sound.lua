-- Sound: tiny wrapper around UI / gameplay sounds (built-in Roblox sounds,
-- so they work without uploading anything).
local SoundService = game:GetService("SoundService")

local Sound = {}

local LIBRARY = {
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5, Speed = 1.1 },
	Collect = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Speed = 1.25 },
	Rare = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7, Speed = 0.8 },
	Cash = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Speed = 1.6 },
	Swing = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.3, Speed = 1.3 },
	Hit = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.35, Speed = 1.6 },
	Error = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.6, Speed = 0.6 },
	Splash = { Id = "rbxasset://sounds/impact_water.mp3", Volume = 0.5, Speed = 1.2 },
	Scrub = { Id = "rbxasset://sounds/impact_water.mp3", Volume = 0.18, Speed = 2.2 },
	Sparkle = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Speed = 2 },
	Purchase = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7, Speed = 1.0 },
	Open = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.4, Speed = 1.5 },
}

Sound.Enabled = true
local cache: { [string]: Sound } = {}

function Sound.play(name: string, speedMul: number?)
	if not Sound.Enabled then
		return
	end
	local def = LIBRARY[name]
	if not def then
		return
	end
	local base = cache[name]
	if not base then
		base = Instance.new("Sound")
		base.SoundId = def.Id
		base.Volume = def.Volume
		base.Parent = SoundService
		cache[name] = base
	end
	local s = base:Clone()
	s.PlaybackSpeed = def.Speed * (speedMul or 1)
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(4, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

return Sound
