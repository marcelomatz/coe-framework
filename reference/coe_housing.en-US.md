# coe_housing — API reference

> Generated from `coe_housing/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Generated from the exports registered in code; refine descriptions and types when editing each export.

## Exports

### `AddressActive(propertyId, owner)`

Does the address still exist (active contract or illegal property with an instance)? Returns the interior used to position a delivery.

| Parameter | Type | Description |
|---|---|---|
| `propertyId` | `any` |  |
| `owner` | `any` |  |

**Returns**

- `any`

### `BeginPreview(playerId)`

Preview: moves the admin to a private instance while visiting interiors; EndPreview returns them to the shared world.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |

**Returns**

- `any`

### `BusinessProperties(businessId)`

Commercial properties for a business (rented or assigned), for the business tablet.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `any` |  |

**Returns**

- `any`

### `CurrentSpace(playerId)`

The instance the player is currently in: `{ propertyId, owner, interior }`, or nil when outside a property.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |

**Returns**

- `any`

### `DeleteProperty(propertyId)`

Server export `DeleteProperty` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `propertyId` | `any` |  |

**Returns**

- `any`

### `DeliveryAddresses(playerId)`

Addresses where the character can receive deliveries: residences, commercial properties belonging to businesses where they work, and accessible illegal properties. Expired contracts outside the grace period are excluded.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |

**Returns**

- `any`

### `EndContract(kind, contractId)`

Real estate management (admin): ends a contract. Initial and business-assigned contracts cannot be ended this way.

| Parameter | Type | Description |
|---|---|---|
| `kind` | `any` |  |
| `contractId` | `any` |  |

**Returns**

- `any`

### `EndPreview(playerId)`

Server export `EndPreview` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |

**Returns**

- `any`

### `InteriorThumbs()`

Thumbnails captured in-game: interior ID -> JPEG data URL.

**Returns**

- `any`

### `Interiors()`

Catalog of native interiors (`shared/interiors.lua`) for admins to select an interior for each property.

**Returns**

- `any`

### `IsReady()`

Server export `IsReady` (`server/main.lua`).

**Returns**

- `any`

### `ListProperties()`

Server export `ListProperties` (`server/main.lua`).

**Returns**

- `any`

### `PlayersInSpace(propertyId, owner)`

Players inside an instance (used to show deliveries to people already there).

| Parameter | Type | Description |
|---|---|---|
| `propertyId` | `any` |  |
| `owner` | `any` |  |

**Returns**

- `any`

### `PropertyContracts(propertyId)`

Real estate management (admin): contracts for a property, including who is currently inside.

| Parameter | Type | Description |
|---|---|---|
| `propertyId` | `any` |  |

**Returns**

- `any`

### `SaveInteriorThumb(interiorId, image)`

Server export `SaveInteriorThumb` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `interiorId` | `any` |  |
| `image` | `any` |  |

**Returns**

- `any`

### `SaveProperty(raw)`

Server export `SaveProperty` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `raw` | `any` |  |

**Returns**

- `any`

### `TabletCall(playerId, appId, action, payload)`

Server export `TabletCall` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |
| `action` | `any` |  |
| `payload` | `any` |  |

**Returns**

- `any`

### `TabletVisible(playerId, appId)`

Server export `TabletVisible` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |

**Returns**

- `any`
