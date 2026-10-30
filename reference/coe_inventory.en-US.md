# coe_inventory — API Reference

> Generated from `coe_inventory/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Server-authoritative grid-based inventory engine.

## Exports

### `CreateInventory(id, slotCount, maxWeight)`

Creates or initializes an inventory container. Persisted synchronously.

| Parameter | Type | Description |
|---|---|---|
| `id` | `string` | Unique inventory identifier |
| `slotCount` | `integer` | Total slot count capacity |
| `maxWeight` | `number` | Maximum weight limit |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode`

### `DeleteInventory(id)`

Deletes an inventory and flushes persistence.

| Parameter | Type | Description |
|---|---|---|
| `id` | `string` | Inventory identifier |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode`

### `GetInventory(id)`

Retrieves an inventory snapshot by its identifier.

| Parameter | Type | Description |
|---|---|---|
| `id` | `string` | Inventory identifier |

**Returns**

- `CoeInventory|nil` `inventory`
- `string|nil` `errorCode`

### `GetSlot(id, slot)`

Retrieves the item occupying a designated slot index.

| Parameter | Type | Description |
|---|---|---|
| `id` | `string` | Inventory identifier |
| `slot` | `integer` | 1-based slot index |

**Returns**

- `table|nil` `item`
- `string|nil` `errorCode` — `invalid_slot`

### `SwapSlots(id, fromSlot, toSlot)`

Swaps two inventory slots. Uses deferred write-behind persistence (`Config.Server.flushIntervalMs`).

| Parameter | Type | Description |
|---|---|---|
| `id` | `string` | Inventory identifier |
| `fromSlot` | `integer` | Source slot index |
| `toSlot` | `integer` | Target slot index |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode`

### `SplitItem(id, slot, splitCount)`

Splits an item stack into an empty slot. Uses write-behind persistence.

| Parameter | Type | Description |
|---|---|---|
| `id` | `string` | Inventory identifier |
| `slot` | `integer` | Source slot index |
| `splitCount` | `integer` | Quantity to separate |

**Returns**

- `boolean` `ok`
- `integer|string|nil` `emptySlotOrError`

### `AddItem(id, itemName, count, metadata, requestedSlot)`

Adds items to an inventory. Persisted synchronously.

| Parameter | Type | Description |
|---|---|---|
| `id` | `string` | Inventory identifier |
| `itemName` | `string` | Item name registered in catalog |
| `count` | `integer` | Quantity to add |
| `metadata` | `table\|string\|nil` | Optional item metadata |
| `requestedSlot` | `integer\|nil` | Optional preferred destination slot |

**Returns**

- `boolean` `ok`
- `integer|string|nil` `slotOrError`

### `RemoveItem(id, slot, count)`

Removes a specific quantity from a slot. Persisted synchronously.

| Parameter | Type | Description |
|---|---|---|
| `id` | `string` | Inventory identifier |
| `slot` | `integer` | Slot index |
| `count` | `integer` | Quantity to deduct |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_slot|invalid_count|insufficient_items|persistence_failed`

### `UseItem(id, slot)`

Consumes a usable item from the designated slot. Persisted synchronously.

| Parameter | Type | Description |
|---|---|---|
| `id` | `string` | Inventory identifier |
| `slot` | `integer` | Slot index |

**Returns**

- `boolean` `ok`
- `table|string|nil` `itemDataOrError`

### `SetItemMetadata(id, slot, patch)`

Merges metadata attributes into an item, preserving existing keys. Persisted synchronously.

| Parameter | Type | Description |
|---|---|---|
| `id` | `string` | Inventory identifier |
| `slot` | `integer` | Slot index |
| `patch` | `table` | Key-value table of updates |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_slot|invalid_item_metadata|empty_slot|persistence_failed`

### `GetItemCount(id, itemName, metadata, strict)`

Counts total quantity of an item matching optional metadata filters.

| Parameter | Type | Description |
|---|---|---|
| `id` | `string` | Inventory identifier |
| `itemName` | `string` | Item name |
| `metadata` | `table\|string\|nil` | Optional metadata filter |
| `strict` | `boolean\|nil` | Whether metadata comparison is strict |

**Returns**

- `integer|nil` `count`
- `string|nil` `errorCode`

### `GetPersistenceStats()`

Returns telemetry metrics for inventory write-behind persistence and memory cache.

**Returns**

- `CoePersistenceStats`

### `OpenStash(playerId, stashId, definition)`

Opens a persistent world stash container (`stash:<id>`) for a player. The caller governs access control; the inventory engine enforces proximity to `position`. Creates the container on initial interaction.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` | Player server ID |
| `stashId` | `string` | Stash identifier |
| `definition` | `{ label: string, slots: integer, maxWeight: integer\|nil, position: { x: number, y: number, z: number }, radius: number }` | Container configuration |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_id|invalid_stash|container_limit|invalid_storage|no_active_character`

### `RemoveItemByName(id, itemName, count)`

Removes `count` items by name, sweeping across occupied slots.

| Parameter | Type | Description |
|---|---|---|
| `id` | `string` | Inventory identifier |
| `itemName` | `string` | Item name |
| `count` | `integer` | Total quantity to deduct |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_count|insufficient_items|persistence_failed`

### `RemoveItemsByMetadata(id, itemName, filter)`

Removes every unit of an item whose metadata contains `filter` (partial match). E.g. all keys of a vehicle.

| Parameter | Type | Description |
|---|---|---|
| `id` | `string` | Inventory identifier |
| `itemName` | `string` | Item name |
| `filter` | `table` | keys and values the metadata must contain |

**Returns**

- `integer|false` `removed` — units removed (0 when there were none)
- `string|nil` `errorCode` — `invalid_item_metadata|persistence_failed`

### `RegisterItem(definition)`

Dynamically registers an item definition into the active inventory catalog.

| Parameter | Type | Description |
|---|---|---|
| `definition` | `table` | Item definition schema |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode`

### `Items()`

Returns the dictionary of all registered item definitions.

**Returns**

- `table<string, table>` — Registered item definitions

### `GetItem(name)`

Retrieves an item definition by its catalog name.

| Parameter | Type | Description |
|---|---|---|
| `name` | `string` | Item name |

**Returns**

- `table|nil` `item`

### `GetContainerInventory(containerId)`

Retrieves inventory data for a non-player container.

| Parameter | Type | Description |
|---|---|---|
| `containerId` | `string` | Container identifier |

**Returns**

- `CoeInventory|nil` `inventory`
- `string|nil` `errorCode`

### `GetPlayerInventory(playerId)`

Retrieves the inventory associated with a player's active character.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` | Player server ID |

**Returns**

- `CoeInventory|nil` `inventory`
- `string|nil` `errorCode`

### `GetInventoryObject()`

Returns the singleton inventory service engine instance.

**Returns**

- `table` `inventoryService`

## Types

```lua
---@class CoeItemStack
---@field name string Registered item identifier key
---@field count integer Quantity in slot
---@field metadata table|nil Dynamic item metadata

---@class CoeInventory
---@field id string Formatted as `character:<id>` or `container:<...>`
---@field slots integer Total slot slots
---@field maxWeight number Maximum permissible weight
---@field items table<integer, table|false> Slot map (false or nil = vacant slot)

---@class CoePersistenceStats
---@field dirty integer Inventories with pending write-behind changes
---@field cached integer Inventories currently retained in memory
---@field evicted integer Inactive inventories evicted from memory
---@field flushes integer Total batch flush executions
---@field flushed integer Total individual records written to database
---@field failures integer Database write error count
---@field lastFlushMs integer Duration of last write-behind flush in ms
---@field maxFlushMs integer Peak flush duration in ms
```
