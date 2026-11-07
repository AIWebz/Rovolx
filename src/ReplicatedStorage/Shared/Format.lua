-- Format: number formatting helpers used by all UI.
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1.23K", 12345678 -> "12.3M"
function Format.short(n: number): string
	n = math.floor(n)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local i = 1
	local v = n
	while math.abs(v) >= 1000 and i < #SUFFIXES do
		v = v / 1000
		i += 1
	end
	local str
	if math.abs(v) >= 100 then
		str = string.format("%d", math.floor(v))
	elseif math.abs(v) >= 10 then
		str = string.format("%.1f", math.floor(v * 10) / 10)
	else
		str = string.format("%.2f", math.floor(v * 100) / 100)
	end
	if string.find(str, ".", 1, true) then
		str = (string.gsub(str, "0+$", ""))
		str = (string.gsub(str, "%.$", ""))
	end
	return str .. SUFFIXES[i]
end

-- 1234567 -> "1,234,567"
function Format.commas(n: number): string
	local s = tostring(math.floor(n))
	local formatted, k = s, 0
	repeat
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return formatted
end

function Format.cash(n: number): string
	return "$" .. Format.short(n)
end

function Format.stars(n: number): string
	return string.rep("★", n) .. string.rep("☆", 3 - n)
end

return Format
