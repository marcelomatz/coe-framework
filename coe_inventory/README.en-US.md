# coe_inventory

Resource responsible for the inventory domain and implementation, item catalog, inventory UI, and container integration. Imports `coe_core`; Core does not import the inventory.

## Organization and responsibilities

- `domain/items.lua`: item and instance definitions, validation, and behavior.
- `data/coe_base_items.lua` and `data/coe_catalog.lua`: base items, registration, and catalog grouping.
- `data/coe_weapons.lua`, `coe_ammo.lua`, `coe_attachments.lua`, `coe_food.lua`, `coe_consumables.lua`, `coe_containers.lua`, `coe_misc.lua`: declarative definitions by category.
- `data/coe_animations.lua` and `data/coe_weapon_profiles.lua`: presentation and weapon behavior profiles.
- `application/`: server-side service split by responsibility; all files share `Inventory.Service`, created in `state.lua` and loaded in `fxmanifest.lua` order.
  - `state.lua`: in-memory state (inventories, containers, rate limits), logging, and basic validation.
  - `storage.lua`: inventory serialization, persistence, and loading.
  - `world_containers.lua`: loose containers in the world (spawn, adoption, restoration, synchronization).
  - `opened_containers.lua`: containers opened by players (validation, indexes, snapshots).
  - `inventory_ops.lua`: domain operations (add/remove/use/swap/split/transfer) and public exports.
  - `player_inventory.lua`: active character inventory.
  - `weapons.lua`: reloads weapons with inventory ammunition and deducts fired rounds.
  - `action_guard.lua`: rate limiting, player cleanup, and standard action response.
  - `handlers_inventory.lua` and `handlers_containers.lua`: network handlers.
  - `lifecycle.lua`: `playerDropped`, persistence initialization, and resource shutdown.
- `adapters/persistence.lua`: asynchronous MariaDB adapter, per-key serialization, and local inventory schema.
- `presentation/`: FiveM client, loaded in manifest order into the `Inventory.Client` namespace:
  - `state.lua`: single state (`C.state`), constants (container profiles, error messages), and native helpers (models, animations, feedback).
  - `item_animation.lua`: animation + prop for used item and equipped weapon.
  - `container_props.lua`: props for portable containers (pick up, store, equip native briefcase, reconcile with inventory).
  - `container_placement.lua`: aiming and confirmation mode for dropping a container in the world.
  - `world_targets.lua`: Open/Pick up options (`coetarget`) and world action results.
  - `weapon_ammo.lua`: R key for the equipped weapon and reporting ammunition spent.
  - `item_use.lua`: `inventory.useItem` dispatch (container, weapon, or generic item).
  - `inventory_ui.lua`: open/close/toggle the UI and nearby players.
  - `nui_callbacks.lua`: NUI callbacks with payload validation.
  - `server_events.lua`: `inventory.*` events received from the server.
  - `bootstrap.lua`: commands, keys, threads, exports, and lifecycle cleanup.
- `client/target_adapter.lua`: the single integration point with `coetarget`.
- `html/` and `data/images/`: NUI presentation and catalog images.
- `lib/init.lua`: import API for `Inventory`.
- `config.lua`: the only file edited by the administrator (see [Configuration](#configuration)). `domain/config_schema.lua` applies defaults and validates on load.
- Persistence: JSON records in MariaDB are addressed by `character:<character_id>` for character inventories and by their own IDs for containers. The active ID is resolved server-side through `coe_core`, never received from the client.

The application service still registers FiveM handlers in the same module; extracting them into separate input adapters is a future step. No interface should persist directly from NUI or trust validations performed only on the client.

## Configuration

Everything the administrator adjusts is in `config.lua`, divided into three sections. **Every key is optional**: omitted keys use the defaults from `domain/config_schema.lua`.

| Section | Contents |
|---|---|
| `Config.Client` | `openKey`, `hotbarSlots` (1–9), `targetDistance`, `placementRange`, `placementPreviewAlpha` (0–255), `streamTimeoutMs`, `networkControlTimeoutMs` |
| `Config.Server` | `defaultSlots`, `maxSlots`, `giveDistance`, `worldInteractDistance`, `adoptTimeoutMs`, `rateLimits` (`requestMs`, `swapMs`, `actionMs`, `dropMs`, `syncMs`), `starterItems` |
| `Config.Containers` | `items[itemName] = { model, bone, position, rotation }`: model and pose for each container. Omitted fields inherit the default; a new item requires only `model` |

Validation on load (client and server): a value with the wrong type or outside its range is ignored, the default is used, and the console displays `[coe_inventory] config: <reason>`. Unknown keys (including old ones `OpenKey`, `GiveDistance`, `DefaultSlots`, `MaxSlots`, `StarterItems`) also generate warnings. `defaultSlots` never exceeds `maxSlots`. Invalid `starterItems` entries are discarded.

The file is loaded on both sides, so do not put secrets in it. `giveDistance` is in `Server`, but the client uses it to list nearby players, keeping the list and validation consistent. Slots and weight for each container are in the catalog (`data/coe_containers.lua`).

## Startup and dependencies

`coe_inventory` depends on `coe_core`, `coe_database`, `coe_logging`, `coe_notify`, and `coetarget`. Core does not depend on inventory or target. Start logger and notify before gameplay resources, and Core before inventory and admin. To access the catalog/API in another resource:

```lua
dependencies {
	'coe_core',
	'coe_inventory'
}
shared_script '@coe_core/lib/init.lua'
shared_script '@coe_inventory/lib/init.lua'
```

The inventory opens with `F2` by default (`config.lua`, `Config.Client.openKey`). Each player inventory receives the items defined in `Config.Server.starterItems` once.

## Usability

Slots 1–5 form the hotbar and work with the interface open or closed. Keys can be configured through FiveM controls. Right-clicking allows you to use items, give an amount to a nearby player, split stacks, or open containers. The default give distance is 3 m (`Config.Server.giveDistance`).

Up to two containers can be open simultaneously. Items can be transferred between them, respecting slots and maximum weight. Containers inside other containers are not accepted. World containers are ephemeral: they can be opened or picked up through the target, but disappear on restart (with their contents) if not picked up. Each briefcase leaves only one `worldref:*` marker in the database, cleared at boot; limits are in `Config.Server.maxWorldContainers` and `maxWorldContainersPerPlayer`. Restarting only `coe_inventory` also removes briefcases from the world.

Persistence: slot swaps/splits are written in batches every `Config.Server.flushIntervalMs` (default 1500 ms; 0 = synchronous); everything else is written immediately. Flush also runs when leaving the game and when the resource stops. `exports.coe_inventory:GetPersistenceStats()` exposes metrics.

Cache and cleanup: idle inventories are evicted from the cache after `Config.Server.cacheTtlMs` (default 600000; 0 = never) and reloaded from the database when needed. `coe_gc_containers` in the server console lists orphaned `container:*` records; `coe_gc_containers apply` removes them. Load test: `node coe_inventory/tools/loadtest/inventory_load.js` (see the script header).

## Catalog and items

Definitions are registered before use through `Inventory.Items.Register`, and each slot holds an instance with `count`, `slot`, and metadata. Different metadata prevents stacking.

The catalog is divided into `data/coe_weapons.lua`, `coe_ammo.lua`, `coe_attachments.lua`, `coe_food.lua`, `coe_consumables.lua`, `coe_containers.lua`, and `coe_misc.lua`. Weapon and animation profiles are in `coe_weapon_profiles.lua` and `coe_animations.lua`. Accessory items (`coe_attachments.lua`) continue to exist as common items, but there is no compatibility or equipping logic for weapons; this will be in a dedicated weapons and ammunition script.

### Ammunition and reloading

A weapon's `metadata.ammo` is the ammunition loaded in it; new weapons start unloaded. When drawn, the ped receives only the loaded rounds, without reserve ammunition. With a firearm equipped, **R** asks the server (`inventory.reloadWeapon`) to fill the magazine with ammunition for the weapon's caliber (`weapon.ammoType` in `coe_weapon_profiles.lua`, e.g. `ammo-9` for 9 mm pistols). The server consumes ammunition items and saves the new loaded count in one write (failure rolls everything back). Shots are reported (`inventory.weaponAmmo`) and the server only accepts a reduction in loaded ammunition. Thrown weapons do not use reloading.

To register an item server-side:

```lua
local registered, itemOrError = exports.coe_inventory:RegisterItem('carta_rara', {
	label = 'Carta rara',
	weight = 5,
	stack = false,
	maxStack = 1
})

if not registered then
	print(('Falha ao registrar item: %s'):format(itemOrError))
end
```

To create an inventory and add items:

```lua
local inventoryId, inventory = exports.coe_inventory:GetPlayerInventory(targetSource)
if inventoryId then
	local success, result = exports.coe_inventory:AddItem(
		inventoryId,
		'water',
		1,
		{ source = 'spring', quality = 85 }
	)
end
```

`GetPlayerInventory(source)` returns an inventory only if the player has an active character and initializes starter items only once per character. Use the server-side `source`, never an ID supplied by the client.

`RegisterItem` accepts `label`, `weight` in grams, `stack`, `maxStack`, `close`, `image`, `usable`, `consume`, `animation`, and default metadata. `Inventory.Items.Create` builds instances. Maximum weight is enforced for containers; the common player inventory does not yet have a total weight limit configured.

Items with `consume` remove that amount when used. The server validates that the item exists and is usable before notifying the client; specific gameplay effects must be implemented as server-authoritative handlers, not only in NUI/client code.

## Server-side API

Exports belong to the `coe_inventory` resource:

- `CreateInventory(id, slotCount?, maxWeight?)`, `DeleteInventory(id)`.
- `GetPlayerInventory(source)` resolves and initializes the active character's inventory.
- `GetInventory(id)`, `GetContainerInventory(playerInventoryId, slot)`, `GetSlot(id, slot)`.
- `RegisterItem(name, definition)`, `Items(name?)`.
- `AddItem(id, name, count, metadata?, slot?)`, `RemoveItem(id, slot, count)`.
- `SwapSlots(id, fromSlot, toSlot)`, `SplitItem(id, slot, count)`.
- `UseItem(id, slot)`, `GetItem(id, name, metadata?, strict?)`, `GetItemCount(id, name, metadata?, strict?)`.
- `GetInventoryObject()` provides the shared domain API in the current Lua context.
- `OpenStash(source, stashId, { label, slots, maxWeight?, position, radius })` opens a persistent fixed stash (ID `stash:...`) as the player's container; closes automatically when the player moves beyond `radius` from `position` (max. 10). The caller validates access rights.
- `RemoveItemByName(id, name, count)` removes from multiple slots (all or nothing: `insufficient_items`).
- `SetItemMetadata(id, slot, patch)` merges `patch` into the slot item's metadata, retaining other keys (e.g. `coe_phone` stores the phone's `serial`). Synchronous write; failure reverts to the previous state.

The `sim_card` item (phone SIM) carries `metadata.iccid`; using it inserts the SIM into the phone in use (`coe_phone`).

Rods (`fishing_rod`, `fishing_rod_fiber`, `fishing_rod_carbon`) and bait (`bait_bread`, `bait_worm`, `bait_shrimp`, `bait_lure`) are in `data/coe_fishing.lua`: sold at the `coe_jobs` fishing shop, usable and not consumed on use (`coe_jobs` listens to `inventory.itemUsed`: the rod casts the line, bait selects what goes on the hook, and each cast removes one bait).

The `fuel_can` item (jerry can, `data/coe_shop_items.lua`) carries `metadata.fuel` and `metadata.liters`; using it does not consume the item: `coe_fuel` pours into the nearest vehicle and reduces the liters.

Reads return snapshots, not mutable references. Operations return `false` or `nil` and an error key as the second value on failure. String metadata is normalized to `{ type = value }`; `GetItemCount` compares metadata exactly by default, while `strict = false` allows filtering by the supplied properties.

## Persistence and MVP limitations

The MVP creates the `coe_inventory_records` table in MariaDB through a versioned migration (`adapters/migrations.lua`, tracked in `coe_inventory_schema_migrations`) and persists each inventory as a JSON snapshot under its stable key. This is intentional for the initial stage: objects, slots, and metadata can evolve without spreading SQL across inventory rules. Transfers between two inventories use a single MariaDB transaction. Previous KVP data is not imported and is not supported by the MVP.

Writes wait for provider confirmation before completing the operation and serialize concurrent access by key. Initialization and persistence failures are recorded in structured format by `coe_logging`; failures in actions sent through the interface may also generate a generic notification, without exposing internal codes to the player. The initial schema is created idempotently; a versioned migration strategy for future changes, player inventory weight limits, and integration tests against real MariaDB remain pending.

## Tests

Run `lua test\inventory_service_test.lua` and `lua test\persistence_test.lua` from the resource folder. The harnesses use a mock MariaDB provider and cover character identity, blocking without an active character, idempotent starter items, character isolation, stacks, metadata, persistence failures, and transactions. Interaction integration is encapsulated by `client/target_adapter.lua`; UI, animations/natives, networked containers, and NUI rendering still require validation in FXServer Enhanced. Testing against real MariaDB is also pending; see [TEST_COVERAGE.md](../TEST_COVERAGE.md).

## Briefcases: animations and camera

- Picking up from the ground (`container_pickup`), equipping from inventory (`container_equip`), and storing (`container_stow`) have their own animations in `data/coe_animations.lua`, separate from weapon looting. The prop only appears/disappears at the animation's `equipAt` point.
- When **opening** a world briefcase through the target, `presentation/container_camera.lua` frames the briefcase with a camera only while the inventory is open. It does not affect the ped or entity (shared with other players) and is cleared when the inventory closes or the briefcase disappears. Cinematics will be in a separate library.
- Range: `Client.targetDistance` (3.0) must not exceed `Server.worldInteractDistance` (3.0), and `Place here` never places anything beyond it. Out of range, the target displays `Briefcase: move closer to use`. To diagnose, aim at the briefcase and run `/targetdebug`.

## API reference

[Exports, parameters, and error codes](../reference/coe_inventory.md), generated from [`types.lua`](types.lua).
