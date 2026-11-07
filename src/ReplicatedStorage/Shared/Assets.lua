-- Assets: Roblox image IDs for the ForgeGUI-generated UI art in /assets/ForgeGUI.
--
-- The PNGs are in the repository. Upload them in Studio (View > Asset Manager >
-- Bulk Import, or the Creator Dashboard) and paste each "rbxassetid://<id>"
-- below. Any entry left empty falls back to the built-in emoji icon, so the
-- game works either way.
return {
	Images = {
		Cash = "", -- assets/ForgeGUI/icon_cash.png
		Backpack = "", -- assets/ForgeGUI/icon_backpack.png
		Machines = "", -- assets/ForgeGUI/icon_machines.png
		Tools = "", -- (no ForgeGUI image yet; uses the emoji)
	},
	Fallback = {
		Cash = "💰",
		Backpack = "🎒",
		Machines = "⚙️",
		Tools = "🔧",
		Upgrades = "⬆️",
		Sell = "💵",
		Zones = "🗺️",
		Hub = "🏠",
		Clean = "🫧",
	},
}
