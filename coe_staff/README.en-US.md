# coe_staff

Basic staff panel for administrators to test the server and scripts. Opens with **F10** (each player can change it in Settings > Key Bindings > FiveM, "Open staff panel") or `/staff`, only for users with one of the ACEs below. Each tab is a module; the server checks the module's ACE on every action, validates the data, and audits it (`coe_audit`, category `admin`).

## Installation

```cfg
ensure coe_staff

# tudo
add_ace group.admin coe.staff.all allow
# ou por módulo
add_ace group.moderator coe.staff.self allow
add_ace group.moderator coe.staff.players allow
add_principal identifier.license:SUA_LICENSE group.admin
```

ACE names are in `config.lua` (`Ace`).

## Modules

- **Self** (`coe.staff.self`): noclip (W/A/S/D, Q/E descend and ascend, Shift accelerates, mouse wheel changes speed; shortcut `/noclip`), invisible, invincible, on-screen coordinates, heal, revive, go to map marker, teleport to coordinates (accepts `x, y, z` or `vector3(...)`), and current position to copy as `vector3`, `vector4`, or `{ x, y, z }`.
- **Players** (`coe.staff.players`): online list with ID, account, character, citizen ID, and ping. Per player: go to, bring, freeze, heal, revive, kick (with reason), give item (catalog from `coe_inventory`, with search and images), give or remove cash (item `money`) or account funds (`coe_economy`, reason `admin_adjustment`), and set or remove `coe_core` groups (`config/groups.lua`).
- **Vehicles** (`coe.staff.vehicles`): search `coe_vehicle_catalog` (or enter a model) and create a **temporary** vehicle (not registered) or **registered** vehicle (in `coe_vehicles`, under the admin's character, with key). For the current or nearest vehicle: repair, refuel, clean, flip, and delete (registered vehicles are stored by `coe_vehicles`).
- **World** (`coe.staff.world`): time (with option to stop the clock) and weather for everyone, return to natural cycle, and broadcast to all online players. If nothing is set, the game follows its own cycle.
- **Businesses** (`coe.staff.businesses`): list, create, and edit `coe_businesses` businesses. The area starts as a circle around the admin (radius can be adjusted or reset); clock-in points, stashes, workbenches, and showroom are marked at the admin's position ("Add here"). Also: name, active status, category rules, owner and staff by citizen ID (online or offline), roles with salary and permissions, go to, and delete. Changing or removing the owner dissolves the society.

Garages: `coe_garage` registers a provider with `exports.coe_staff:RegisterGaragesProvider({ List, Save, Delete })`, after which the panel can list, create, and delete garages through it.

## Access to other resources

`coe_staff` is included in the framework defaults for the resources it uses: `coe_core` (groups), `coe_economy` (account), `coe_vehicles` and `coe_businesses` (records), `coe_database` (offline character search), `coe_notify`, `coe_logging`, and `coe_audit`.

## Packages that take over the panel

A package with a complete panel calls the `Yield()` export on startup (and again on `onResourceStart` of `coe_staff`). The basic panel closes and stops opening until the calling resource stops; it then returns automatically. Grant the capability in `server.cfg`:

```
add_ace resource.<nome> coe.staff.yield allow
```

The framework does not name the package: the resource taking over is determined at runtime. `Status()` returns `{ active, yieldedBy }`.

## Configuration

`config.lua`: command and key, ACEs, interval between actions, payload size, limits (items, money, text, radii), ledger reason, available weather types, and noclip speeds.

## Interface

Panel uses the `coe_ui` visual style (chamfered panel, `coe-*` fields and buttons, colors only from tokens), following the server theme and player color (`@coe_ui/theme_bridge.lua`). Kick and business deletion are confirmed with `CoeUI.confirm`.

## Tests

```
cd coe_staff
lua test/rules_test.lua
lua test/server_test.lua
```

`server_test.lua` exercises the server with simulated natives and exports: per-module ACEs, rate and payload limits, personal tools, players (teleport, freeze, kick, item, cash and account funds, groups), temporary and registered vehicles, world, businesses (create, points, online and offline owner, staff, roles, delete), and a package's `Yield`.
