# coe_jobs

Open jobs in Coe (#123): jobs that do not depend on a business. Business jobs (positions, salary, clock-in) remain in `coe_businesses`; this resource contains jobs any citizen can pick up from an NPC and start immediately. They all live together in this resource and share the character's **career**: experience in one job provides advantages in others.

## Jobs

| Job | Type | Location | Vehicle / tool | Trains | Requirement | How it pays |
|---|---|---|---|---|---|---|
| **Lumberjack** | cutting, hauling, and sawmill | Paleto Forest → lumberyard | `bison` pickup (deposit $350); axe (visual) | Strength, Fieldwork | — | Cuts **trees from the map itself** in the area (10 s, 2–3 logs; the tree falls, disappears for everyone, and regrows in 15 min), carries logs one at a time to the truck bed (8, more with Strength), saws them (1 log = 4 planks), and sells planks for $7 each. |
| **Farmer** | gathering | 4 fields in Grapeseed + Marlowe Vineyard; market and winery | — | Fieldwork, Strength | — | Cabbage $8 (5 s, 2–3), pumpkin $16 (6 s, 1–2), corn $5 per ear (4 s, 3–4), orange $4 (5 s, 4–5), and grapes $7 per bunch (4 s, 2–3); up to 40 items total. |
| **Fisher** | free fishing | 5 areas (Del Perro and Paleto Cove piers, Chumash coast, Alamo Sea, Land Act Dam); 3 buyers | Rod and bait from `coe_inventory` (fishing shop) | Fieldwork | — | Uses the rod facing the water (works from the top of a pier), each cast uses bait and the minigame determines whether you hook a fish. 10 species from $12 to $100 (saltwater and freshwater); up to 25 fish. Better rods and bait require job levels. |
| **Miner** | gathering | Davis Quartz Quarry | Pickaxe (visual) | Strength, Fieldwork | Strength 2 | Breaks rocks (7 s, 1–2, up to 20) and sells ore for $20. |
| **Delivery driver** | route | GoPostal (Vinewood) → Mirror Park | `boxville2` van (deposit $300); box in hand | Driving, Logistics | — | 6 stops, $45 per delivery and $120 per route. Picks up the package at the van and delivers it to the resident. |
| **Garbage collector** | area collection | Sanitation → 10 Los Santos neighborhoods | `trash` truck (deposit $400); bag in hand | Strength, Driving | — | 3 areas per route, 6 bags per area, $28 per bag and $180 per route. Collects from any trash can, dumpster, or bag on the map within the area; opens the dumpster at the rear of the truck and throws the bag in. |
| **Taxi driver** | passenger route | Downtown Cab Co. → city | `taxi` cab (deposit $250) | Driving, Logistics | Career 2 | 4 rides, $30 + $70 per km and $100 per route. Stops at the designated point: the passenger gets in and out on their own. |
| **Truck driver** | long-haul route | Port of Los Santos → state warehouses | `mule3` truck (deposit $800); cargo in hand | Driving, Logistics | Driving 2 and reputation ≥ 0 | 3 docks, $60 + $35 per km and $200 per route. |

Entry-level jobs (no requirement) train the skills required by others: lumberjack, farmer, and garbage collector train the miner's Strength; delivery driver and garbage collector train the truck driver's Driving; any job contributes to the taxi driver's Career 2.

Every job can have an **optional uniform** (`uniform`): while working, the job attendant offers "Put on …" and "Take off uniform". The player's entire outfit is saved and restored when taking it off or ending the job (visual only, nothing is saved to appearance). Each uniform has male and female clothing (freemode models).

### Job shop and free fishing

- **Shop** (`shop`): vendor always appears on the map (you do not need to have started the job), with a NUI storefront. Each item has a price and the **job level** that unlocks it; locked items show the level required. Payment is in cash (`money` item) or, if unavailable, from the bank (`coe_economy`, statement `job_shop`); a full inventory refunds the purchase. Items are delivered to `coe_inventory` (optional: without it, the shop responds "inventory unavailable").
- **Fishing** (`gather.fishing`): the player **uses the rod from inventory** and holds it in their hand (its own `prop_fishing_rod_01` prop, which does not fall to the ground; use it again or press X to put it away). With the rod: **hold E to charge power** (the meter rises and falls) and **release to cast**; the line lands 4–18 m ahead and must land in water (works from shore and the top of a pier) inside a fishing area. More power means deeper water: bites occur up to 15% earlier and get a +0.15 rare-fish bonus. The first cast starts the job wherever the player is; the job ends at the NPC, a buyer, or the shop. Using **bait** chooses which bait goes on the hook (otherwise, the simplest available bait is used). Each cast consumes one bait (artificial bait has an 85% chance to be reused), and the species is randomly selected by area (weights) with rod + bait bonuses.
- **Hooking and fighting**: when a fish bites, there are `hookSeconds` (1.6 s) to press E; then the fight begins: the fish swims along the bar and the player holds/releases E to keep the rod's zone (larger with better rods) over the fish. Progress increases while it is inside and decreases while it is outside. Full progress hooks the fish; empty progress (or `fightSeconds`) lets it escape. Rare fish swim faster and fill progress more slowly (`JobRules.FightParams`); the server rejects hooks before the bite plus minimum fight time. X reels in the line before a bite.
- Rods: bamboo (level 1, $120), fiberglass (level 2, $650), carbon fiber (level 4, $1,800). Bait: bread (1, $2), worm (2, $5), shrimp (3, $9), artificial (5, $260, reusable). Effects and areas in `jobs/fisher.lua`; items and icons in `coe_inventory/data/coe_fishing.lua`.

Each job is a file in `jobs/` (data only); `Enabled` in `config.lua` enables or disables it. A new job is a new file, with no code changes.

## Career (player XP)

Everything is calculated in `shared/career.lua` (pure and tested) from each job's XP and reputation.

- **Job XP** → job level (5 levels: 0, 150, 450, 1,000, 2,000 XP), +5% pay per level.
- **Career**: total XP across all jobs determines career level (8 levels: 0 to 16,000 XP). Each level above 1 grants **+1% pay and +3% XP for any job**, including jobs the player has never done.
- **Skills**: each job trains skills (`skills`); a skill's XP is the sum of XP from jobs that train it, and its bonus applies to **every job that uses that skill** (per level above 1):

  | Skill | Bonus per level | Jobs that train it today |
  |---|---|---|
  | Strength | +10% carry capacity | Lumberjack, Farmer, Miner, Garbage collector |
  | Fieldwork | -5% action time (up to -30%) | Lumberjack, Farmer, Fisher, Miner |
  | Driving | -15% vehicle deposit | Delivery driver, Garbage collector, Taxi driver, Truck driver |
  | Logistics | +3% pay | Delivery driver, Taxi driver, Truck driver |

  Example: a player who already has Strength from lumberjacking starts the future mining job able to carry more.
- **Reputation** (-100 to 100): completing a sale or route adds 1; leaving the game or changing character with the company vehicle subtracts 10; ending without returning the vehicle subtracts 5. Ranks: **Exemplary** (50+: no vehicle deposit and +5%), **Reliable** (20+: +3%), **Regular**, **Questionable** (-20 or less: double deposit).
- **Requirements**: a job can require career level, reputation, or skill level (`requires`), unlocking more profitable work for players with a track record.
- Total pay bonus is capped (`maxPayBonus`, 60%). The player is notified when leveling up a job, career, or skill.

### At each job NPC

- **Start** and **End the job**. For gathering jobs, ending with a load does not end the job: the server tells the player to sell first, and the **Discard load and end** option asks for confirmation (the load does not become an item and is lost).
- **How it works**: screen (`html/guide.html`) with steps, pay, tips, rules, skills trained by the job, requirements, and the player's history there (level, XP, tasks, earnings, bonuses, load, deposit, and recent jobs). The guide is generated from the job definition itself (`shared/guide.lua`), so every new job gets one; `tips` adds tips. Close with the button or Esc.
- When a job ends, a summary (tasks, XP, earnings, discarded items, and deposit) appears in the notification and is saved among recent jobs.

### Career app (tablet)

Tablet app for everyone (on the basic work tablet `coe_workpad`, or a package tablet): career level and XP, reputation and its effect, recent jobs (when, duration, tasks, XP, earnings, and discarded items), each skill with its current bonus and per-level bonus, and each job with level, tasks, bonus from its history, load, action time, deposit, missing requirements, **How it works** (same guide as the NPC, `html/guide-view.js`), and GPS to the NPC.

## Job definition

Validated in `shared/rules.lua` (`JobRules.Validate`); errors return a code (`invalid_nodes:3` indicates the point). Points accept `{ x, y, z, h }`. LuaLS contract in [`types.lua`](types.lua).

| Field | Purpose |
|---|---|
| `tips` | Up to 6 tips (160 characters) added to the **How it works** guide. |
| `id`, `label`, `description` | `id` matches `[a-z][a-z0-9_]` (2 to 24; `deposit` is reserved). `coe_economy` statement: `job_<id>`. |
| `kind` | `gather` (collect and sell) or `route` (sequential stops). |
| `center`, `centerPed`, `blip` | NPC where players start, end, and view history (targeted by `coetarget`) and map blip. |
| `levels`, `levelBonus` | XP for each job level (starts at 0, ascending) and bonus per level (default 5%). |
| `skills`, `requires` | Skills trained (`Career.skills`) and requirements `{ career?, reputation?, skills = { id = level } }`. |
| `vehicle` | `{ model, spawn, plate?, deposit?, returnRadius? }`: created by the server when starting; the deposit (with career discounts) is refunded when ending if the vehicle is near the center. |
| `tool` | Prop in hand during the action (`{ model, bone, offset, rotation }`), visual only. |
| `uniform` | Optional: `{ label, male, female }`, each outfit `{ components = { [slot] = { drawable, texture } }, props = { [slot] = { drawable, texture } } }` (slots 0–11 and 0–9; drawable -1 on a prop removes it). |
| `gather` | `nodes` (with `nodeProp`), `actionLabel`, `seconds`, `yield = { min, max }`, `capacity`, `nodeCooldown`, `xp`, `unit`/`units`, `animation` (`{ dict, name, flag }` or `{ scenario }`), and `sell = { points, price, ped, label }`. Extensions below. |
| `gather.products` | Multiple products, each with `unit`, `units`, `price` (0 = not sold directly), `prop` (name or list of candidates), `animation`, `seconds`, `yield`, `xp`, `cooldown`, `actionLabel`. Load counts all products; each is paid at its own price. `order` sets the order. |
| `gather.fields` | Grid-based planting fields: `{ product, origin, heading, rows, cols, spacing, rowSpacing?, soil?, label }`. With `soil` (defaults to `gather.soil`), the client only places feet on soil (`SoilMaterials`); points on roads or grass disappear, and if the entire field fails, the filter is disabled for that field. |
| `gather.world` | Objects from the map itself in an area: `{ product, models, area = { x, y, z, radius, label }, fell?, cooldown? }`. With `fell`, the tree falls and disappears for everyone (`CreateModelHide`) until cooldown; players who enter later receive the list. |
| `gather.haul` | Transport (requires `vehicle`): the harvest drops on the ground (`groundProp`), the player carries one at a time (`carry`, `carryAnimation`, `takeLabel`) and loads it into the vehicle (`loadLabel`), up to `capacity`. `rack = { model, slots }` displays the load in the bed for everyone (state bag `coe:jobLoad`). |
| `shop` | Shop: `{ label, ped, points, items = { { item, label, price, level, max, kind, description, stats } } }` (items from `coe_inventory`; `level` = job level). |
| `gather.fishing` | Free fishing: `{ areas = { { x, y, z, radius, label, water, species = { product = weight } } }, rods, baits, castSeconds, biteSeconds, hookSeconds, fightSeconds, rodProp }`. Rod/bait: `{ item, label, level, speed, window, rarity, keep }`. Products gain `tier` (`common`/`uncommon`/`rare`) and `difficulty` (minigame speed). |
| `gather.process` | Processing: at `points`, with the vehicle within `vehicleRange`, load becomes `ratio` units of `product` (`seconds` per unit, up to `maxSeconds`). |
| `route` | `mode`, `stops`, `perRoute`, `pay` per stop, `payPerKm` (from previous stop or pickup), end-of-route `bonus`, `xp`, `stopRadius`, `vehicleRange` (0 disables), `carry` + `carryAnimation`, `pickAnimation`/`dropAnimation` (short, `{ dict, name, flag, ms }`), `recipients`, `stopProp`, `actionLabel`, `pickupLabel`, `dropLabel`; in `zone` mode: `zones` (`{ x, y, z, radius, label }`), `perZone`, `binModels`, `binCooldown`, `rearDoor`, `openLabel`, `closeLabel`. `carry` accepts `fallback` (backup model). |

Route modes (`route.mode`):

- `deliver` (default): pick up cargo from the vehicle (`pickupLabel`) and deliver it to the stop's recipient (`actionLabel`).
- `collect`: collect at the stop (object `stopProp`, `actionLabel`) and load into the vehicle (`dropLabel`). The server checks that the player is at the stop when collecting and within `VehicleReach` of the vehicle when loading. Requires `carry`.
- `zone`: each route randomly selects `perRoute` areas from `zones`. Within the area, any map object in `binModels` (trash cans, dumpsters, bags) gets the `actionLabel` option; the bag is picked up and stored at the rear of the vehicle (`openLabel` opens the `rearDoor`, `dropLabel` stores it, `closeLabel` closes it). The server checks that the player is in the area and within 3.5 m of the trash can; the same trash can (position rounded to 1 m) can only be used again by any player after `binCooldown` seconds; the vehicle must be close to the player and area when storing. `perZone` bags complete the area. Requires `carry`.
- `passenger`: each ride has two stops, pickup and destination. With the vehicle stopped within `stopRadius` and the player driving, the passenger gets in and later gets out automatically; the ride pays `pay` + `payPerKm` for the distance from pickup to destination.

Other resources can also add jobs with `exports.coe_jobs:RegisterJob(definition)` (listening for the `coe_jobs:ready` event), without being added to any allowlist; their jobs are removed when they stop.

## What the server guarantees

- Session per player and character; changing characters ends the session (and counts as abandonment if a vehicle was present).
- Start and end only near the center and with requirements met; gather, sell, and deliver only near the point (`PointRadius` horizontally, `PointHeight` vertically, because point `z` values are approximate).
- Gathering: minimum action time (with Fieldwork bonus applied), cooldown per point, and load capacity (with Strength bonus applied).
- Map objects (`world`): model is on the list, player and object are in the area, player is within 4 m, and cooldown per position for everyone. Transport: one unit at a time from the ground (within 10 m of where it fell) to the vehicle (within `VehicleReach`), without cutting another log on the ground; processing requires the vehicle near the sawmill.
- Routes: only the next randomly selected stop and the correct step (collect before loading, pickup before destination); vehicle within `vehicleRange`; minimum time between stops based on distance (`MaxTravelSpeed`, to prevent teleporting). Finishing the route pays the bonus, increases reputation, and selects another route.
- Minimum interval between actions (`ActionCooldownMs`). Payment is made only here, with all career bonuses applied.
- Load belongs to the session (it does not become an item), so it does not depend on the `coe_inventory` catalog.

## Pay table (level 1, no career)

Estimated pace; `test/jobs_test.lua` fails if an entry-level job falls outside $1,500 to $3,000 per hour or a job with requirements falls outside $2,200 to $3,800.

| Job | Estimated pace | Level 1 |
|---|---|---|
| Lumberjack | ~25 s per tree, ~12 s per log loaded, ~2.5 min round trip, saw every 8 logs | ~$2,300/h |
| Farmer | ~20 s per plant (average across 5 products), sell after every 40 | ~$1,650/h |
| Fisher (basic rod and bait) | ~24 s per cast (wait + fight), ~75% hook rate, sell after every 25, minus bait costs | ~$1,750/h |
| Miner (Strength 2) | ~22 s per rock, sell after every 20 | ~$2,400/h |
| Delivery driver | ~90 s per stop, 6-stop route | ~$2,800/h |
| Garbage collector | ~45 s per bag, 6 per area, 3 areas | ~$2,400/h |
| Taxi driver (Career 2) | ~5 min per ride (drive to pickup and ride) | ~$2,550/h |
| Truck driver (Driving 2) | ~4 min per dock (~4 km) | ~$3,200/h |

Job level adds up to +20% (level 5). Career, skills, and reputation add on top (up to +60% total).

## Points, props, and animations (verify in-game)

- **Provisional** coordinates in `jobs/*.lua`; an incorrect `z` still works (the client probes the actual ground). Farmer fields: adjust each field's `origin`/`heading`/`spacing` instead of adjusting each point.
- Props with candidate lists (uses the first one that exists): corn `prop_veg_corn_01`, grapes `prop_bush_med_03`, logs `prop_log_break_01`/`prop_log_02`/`prop_log_01`, sawmill workbench `prop_tool_bench02`. Others: cabbage `prop_veg_crop_03_cab`, pumpkin `prop_veg_crop_03_pump`, orange tree `prop_veg_crop_orange`, rock `prop_rock_1_d`, bucket `prop_bucket_02a`, bag `hei_prop_heist_binbag` (fallback `prop_cs_rub_binbag_01`), axe `prop_w_me_hatchet`, pickaxe `prop_tool_pickaxe`, box `prop_cs_cardbox_01`.
- In hand: box held with both hands (bone 60309, `0.025, 0.08, 0.255` / `-145, 290, 0`); bag beside the leg (bone 57005, `0.40, 0, 0` / `0, 270, 60`); pickaxe (57005, `0.18, -0.02, -0.02` / `-100, 0, -10`); axe (57005, `0.10, 0.02, -0.02` / `-90, 0, 0`).
- Animations: planting `amb@world_human_gardener_plant@male@base / base` (without the long scenario intro); picking on high ground `amb@prop_human_movie_bulb@base / base`; grapes and sawmill `anim@amb@clubhouse@tutorial@bkr_tut_ig3@ / machinic_loop_mechandplayer`; axe `amb@world_human_hammering@male@base / base`; miner `melee@large_wpn@streamed_core / ground_attack_on_spot`; fishing `WORLD_HUMAN_STAND_FISHING`; box and log `anim@heists@box_carry@ / idle`; garbage `anim@heists@narcotics@trash` (`pickup`, `walk`, `throw_b`).
- Times: cabbage 5 s, pumpkin 6 s, corn 4 s, orange 5 s, grapes 4 s, fishing 12 s, rock 7 s, tree 10 s, 3 s per log at the saw (up to 24 s); pick up bag ~1 s and throw ~1.3 s.
- Vehicles: `boxville2`, `trash`, `taxi`, `mule3`, `bison`. `trash` truck bed: door 5 (`rearDoor`; if the model lacks it, try 4/6/2). The client requests network control before opening (the truck spawns on the server), and rear options use vehicle length because `coetarget` measures distance to its center.
- Uniform values are **provisional** (vary with server DLCs); check and adjust in each `jobs/*.lua`.

## Persistence

Own migrations (`coe_jobs_schema_migrations`): `coe_jobs_progress` (XP, tasks, and earnings by character and job), `coe_jobs_profile` (reputation, completed, and abandoned jobs), and `coe_jobs_sessions` (each ended job: start, end, tasks, XP, earnings, discards, and reason; the app displays the most recent `RecentSessions`). Migration 4 adds time worked per job (`seconds`, `first_at`, `last_at` in `coe_jobs_progress`), used by the `coe_elos` resume. History stays in memory while the character is online; `GetCareer` for someone offline reads from the database without caching it.

## Exports (server)

`RegisterJob`, `UnregisterJob`, `ListJobs`, `IsReady`, `GetSession`, `GetProgress`, `GetCareer`, `TabletVisible`, `TabletCall`. Reference: [reference/coe_jobs.md](../reference/coe_jobs.md).

## Client

No per-frame loop: a 1 s loop creates and removes NPCs, gathering objects, and recipients near the player; actions use `coetarget`. Blips for centers, points, and the current stop (with GPS route).

## Tests

`lua test\rules_test.lua` (contract), `lua test\career_test.lua` (career, skills, reputation, and bonuses), `lua test\guide_test.lua` (the **How it works** guide for each job), `lua test\persistence_test.lua` (no database commands with `nil` parameters), `lua test\server_test.lua` (sessions, deposits, gathering, sales, ending with a load, delivery/collection/passenger routes, pay per km, anti-cheat, requirements, reputation, recent jobs, guide and tablet app, with mocked natives, including lumberjack with map tree, pickup, sawmill and sale, and farmer with multiple products, shop, and free fishing), and `lua test\jobs_test.lua` (jobs in `jobs/` and pay ranges).

## Dependencies and allowlists

`coe_core`, `coe_database`, `coe_economy`, `coe_logging`, `coe_notify`, `coetarget`; `coe_inventory` is optional (shop and fishing rod). `coe_jobs` is included in the access defaults for these resources (database, money, logs, and notifications) and in `coe_supervisor`. The Career app accepts the basic work tablet (`coe_workpad`, default in `TabletResources`) and package tablets with the `coe.jobs.tablet` ACE (`add_ace resource.<name> coe.jobs.tablet allow`).
