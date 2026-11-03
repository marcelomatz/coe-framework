# coe_fuel — API reference

> Generated from `coe_fuel/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Server-only exports. Pumps and the jerrycan use the `coe_fuel:request` request/response event; fuel consumption uses `coe_fuel:init` and `coe_fuel:report`. The vehicle's fuel tank is stored in the `coe:fuel` state bag.

## Exports

### `IsReady()`

Migrations have been applied and station tanks have been loaded.

**Returns**

- `boolean` `ready`

### `GetFuel(vehicleId)`

Fuel tank for a registered vehicle currently in use (or nil).

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `string\|integer` |  |

**Returns**

- `CoeFuelSummary|nil` `fuel`

### `GetEffects(vehicleId)`

Engine effect of the fuel mixture for coe_handling (ethanol and premium fuel). Nil when no tank is in use.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `string\|integer` |  |

**Returns**

- `table|nil` `effects` — `{ mods = { fInitialDriveForce = number }, key = string }`

### `GetStationTanks(stationId)`

Fuel tanks for a station (player-owned stations sell only the fuel listed here), including each fuel's level and capacity.

| Parameter | Type | Description |
|---|---|---|
| `stationId` | `string` |  |

**Returns**

- `table|nil` `tanks` — `{ business, tanks = { [fuel] = liters }, levels, capacities }`

### `IsStation(businessId)`

Is this a coe_fuel station (the station business ID)? Used by the business app to show the Station tab.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` |  |

**Returns**

- `boolean` `station`

### `BusinessTablet(playerId, characterId, businessId, payload)`

Station tab in the business app on the tablet. Only coe_businesses calls this (app access has already been checked there). `payload.op`: `overview`, `price` (`fuel`, `price`; `false` restores the table price), `upgradeTank` (`fuel`), or `upgradeFleet`. Errors: `forbidden`, `not_ready`, `not_a_station`, `staff_station`, `invalid_price`, `not_enough_sales`, `insufficient_funds`, `max_level`, `no_fleet_garage`.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` |  |
| `characterId` | `string` |  |
| `businessId` | `string` |  |
| `payload` | `table` |  |

**Returns**

- `table` `result`

## Types

```lua
---@class CoeFuelSummary
---@field liters number Liters in the tank
---@field capacity integer Tank capacity (liters)
---@field level number 0..1
---@field engine 'flex'|'diesel'|'none'
---@field main string|nil Fuel with the greatest volume
---@field tank table<string,number> Liters of each fuel (regular, premium, ethanol, diesel)
```
