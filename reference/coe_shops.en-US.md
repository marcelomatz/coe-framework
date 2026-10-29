# coe_shops — API Reference

> Generated from `coe_shops/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Server-only exports. The storefront NUI uses the `coe_shops:request` event (request/reply pattern) and is not part of this programmatic export contract.

## Exports

### `IsReady()`

Verifies if database migrations are applied and store business records are initialized.

**Returns**

- `boolean` `ready`

### `GetShelves(storeId)`

Retrieves the product shelves of a player-owned store. Returns `nil` for staff stores (infinite stock) or unknown stores. Serves as the foundation for logistics restocking missions.

| Parameter | Type | Description |
|---|---|---|
| `storeId` | `string` | Store identifier (= business ID) |

**Returns**

- `table<string,CoeShopsShelf>|nil` `shelves`

### `IsStore(businessId)`

Checks if a registered business is a retail store managed by `coe_shops`. Used by the business management app to render the Store tab.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Target business ID |

**Returns**

- `boolean` `store`

### `BusinessTablet(playerId, characterId, businessId, payload)`

Handles Store tab operations in the business management tablet app. Invoked exclusively by `coe_businesses` (permission validation performed beforehand). `payload.op`: `overview` (shelves, pricing, sales metrics, and cash balance) or `price` (`productId`, `price`; `false` resets to default wholesale price). Restocking and cash withdrawals take place physically at the counter. Error codes: `forbidden`, `not_ready`, `not_a_store`, `unknown_action`, `invalid_price`.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` | Player server ID |
| `characterId` | `string` | Active character ID |
| `businessId` | `string` | Business ID |
| `payload` | `table` | Operation payload descriptor |

**Returns**

- `table` `result`

### `RegisterPaymentMethod(def)`

Registers an extensible payment provider from the calling resource (requires ACE permission `coe.shops.payments`). Registration automatically unbinds when the provider resource stops. `def`: `{ id, label, kind = 'instant'|'pin'|'device', charge, refund, options?, client? (device), order? }`, pointing to export names hosted by the provider. Error codes: `forbidden`, `invalid_method`, `method_taken`, `too_many_methods`.

| Parameter | Type | Description |
|---|---|---|
| `def` | `table` | Payment provider definition table |

**Returns**

- `boolean|table` `result` — `true` or `{ error = ... }`

## Types

```lua
---@class CoeShopsShelf
---@field quantity integer Units currently in stock on shelf
---@field price integer|nil Custom unit price configured by store owner (nil = default catalog price)
```
