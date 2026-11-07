# ♻️ Scrapyard Simulator (Roblox)

A colorful simulator set in one shared scrapyard (one plot for every player in the server).
Collect rare scrap with tools, scrub it clean in an interactive minigame, sell it, then
buy upgrades, better tools, machines and new zones.

## Open it in Roblox Studio
**Quick way:** open `build/ScrapyardSimulator.rbxlx` in Studio and press Play.

**With Rojo (live sync):**
```bash
rojo serve
```
Then connect from the Rojo plugin in Studio. To rebuild the place file: `rojo build -o build/ScrapyardSimulator.rbxlx`.

To save progress, publish the place and turn on **Game Settings → Security → Enable Studio Access to API Services**.

## Gameplay loop
1. **Collect.** You spawn in the hub of the scrapyard holding a Rusty Grabber. Point at scrap and hold click (or tap) to pry it loose. Rare scrap needs stronger tools.
2. **Clean.** Use a **Wash Station** (4 shared stations, each one used by one player at a time). Pick a scrap, then *scrub* the stains with the right tool:
   🧽 Sponge removes Mud, 🪥 Wire Brush removes Rust, 💦 Power Spray removes Grease (keys 1/2/3).
   The 3D model goes from rusty to shiny as you scrub. Faster washes earn up to ★★★ (×1.6 value).
3. **Sell.** Step on the glowing pad at the **Scrap Exchange**. Only clean scrap can be sold.
4. **Grow.** Spend your money on tools, upgrades, machines and new zones.

## Content
| | |
|---|---|
| **Rarities** | Common, Uncommon, Rare, Epic, Legendary, Mythic. Rare and above glow; Legendary and Mythic have sky beacons |
| **Scraps (16)** | Rusty Can, Bent Pipe, Old Tire, Scrap Gear, Car Battery, Chrome Hubcap, Copper Coil, Vintage Radio, Traffic Light, V8 Engine Block, Robot Head, Jet Turbine, Golden Pocket Watch, Mech Reactor Core, Alien Hover Drive, Titan Power Crystal |
| **Tools (6)** | Rusty Grabber, Steel Crowbar, Magnet Wand, Hydraulic Claw (hits 2), Plasma Cutter (hits 2), Quantum Vacuum (hits 4) |
| **Upgrades (7)** | Bigger Backpack, Tool Strength, Running Shoes, Scrub Power, Bigger Wash Tub (washes several at once), Haggling (sell %), Lucky Finds (double drops) |
| **Machines (5, levels 1–5)** | Auto Washer, Magnet Crane (auto-collects), Rarity Radar (marks rare scrap through walls, adds luck), Conveyor Seller (auto-sells), Polish Lab (+value) |
| **Zones (4)** | Junk Fields → Rust Canyon ($1.5K) → Toxic Wasteland ($22K) → Meteor Crater ($250K) |

There's also a goal tracker with a guide beam, a scrap collection book, a zone teleporter and saving through DataStores.
Every model (scrap, tools, machines, buildings, props, NPCs) is built from many detailed parts in code, so no uploaded meshes are needed.
All the balancing numbers are in `src/ReplicatedStorage/Shared/Config.lua`.

## ForgeGUI art
`assets/ForgeGUI/` has the generated HUD icons (cash, backpack, machines). Upload them in Studio (Asset Manager → Bulk Import),
then paste the `rbxassetid://` IDs into `src/ReplicatedStorage/Shared/Assets.lua`. Until you do, the UI uses emoji icons.

## Code layout
```
src/ReplicatedStorage/Shared     Config, Build helpers, ScrapModels, ToolModels, Format, Assets
src/ServerScriptService/Server   World generation, data, scrap spawning, cleaning, economy, machines
src/StarterPlayer/.../Client     UI kit, HUD, panels, cleaning minigame, tool controller, world FX
```
