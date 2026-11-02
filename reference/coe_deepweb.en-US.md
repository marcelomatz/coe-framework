# coe_deepweb — API reference

> Generated from `coe_deepweb/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Computers use this resource's own NUI (events `coe_deepweb:computer:*`).

## Exports

### `TabletVisible(playerId, appId)`

Does the `onion` app appear on the device in use? Only after installing the browser from the USB drive (`onion_usb`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` |  |

**Returns**

- `boolean` `visible`

### `TabletCall(playerId, appId, action, payload)`

Action for the `onion` app on a smartphone or tablet.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` |  |
| `action` | `string` | Identity: `state\|handleCreate\|handleLogin\|handleLogout\|handlePassword\|handleReset`; browser: `bookmarks\|bookmarkAdd\|bookmarkRemove\|site\|directory\|search\|contactThread\|contactSend`; Rabbit: `forumHome\|forumCommunity\|forumPost\|forumUser\|forumSubmit\|forumComment\|forumVote\|forumRemove\|forumCreate`; Deep Market: `marketHome\|marketListing\|marketBuy\|marketMine\|marketOrder\|marketSave\|marketListingStatus\|marketAct\|marketReview` |
| `payload` | `table\|nil` |  |

**Returns**

- `table` `result` — `{ ok, ... }` or `{ ok = false, error }`

### `AdminOverview()`

DeepWeb overview for admins: sites, NPC suppliers, disputed or paid-but-undelivered orders, recent posts, and profile contacts. Only `coe_admin`.

**Returns**

- `table` `result` — `{ available, ready, sites, vendors, orders, posts, contacts, categories, decimals, blockTypes }` or `{ error }`

### `AdminSaveSite(raw)`

Creates or updates a block-based (`.onion`) site. System sites cannot be edited. Only `coe_admin`.

| Parameter | Type | Description |
|---|---|---|
| `raw` | `table` | `{ domain, title, description, keywords, blocks, active, listed }` (`listed = false`: excluded from the directory and search) |

**Returns**

- `table` `result` — `{ ok, domain }` or `{ error, index }`

### `AdminDeleteSite(raw)`

Deletes a block-based site. Only `coe_admin`.

| Parameter | Type | Description |
|---|---|---|
| `raw` | `table` | `{ domain }` |

**Returns**

- `table` `result` — `{ ok }` or `{ error }`

### `AdminSaveVendor(raw)`

Creates or updates an NPC Deep Market supplier listing (price as currency text, e.g. `0,5`). Only `coe_admin`.

| Parameter | Type | Description |
|---|---|---|
| `raw` | `table` | `{ id?, vendor, kind, category, title, description, item, count, price, stock, status }` |

**Returns**

- `table` `result` — `{ ok, id }` or `{ error }`

### `AdminDeleteVendor(raw)`

Removes an NPC supplier listing (ongoing orders continue). Only `coe_admin`.

| Parameter | Type | Description |
|---|---|---|
| `raw` | `table` | `{ id }` |

**Returns**

- `table` `result` — `{ ok }` or `{ error }`

### `AdminResolveOrder(raw)`

Decides a disputed order (or cancels a paid order with no delivery): `buyer` refunds the buyer, `seller` pays the seller. Only `coe_admin`.

| Parameter | Type | Description |
|---|---|---|
| `raw` | `table` | `{ id, decision }` |

**Returns**

- `table` `result` — `{ ok, status }` or `{ error }`

### `AdminRemovePost(raw)`

Removes a Rabbit post. Only `coe_admin`.

| Parameter | Type | Description |
|---|---|---|
| `raw` | `table` | `{ id }` |

**Returns**

- `table` `result` — `{ ok }` or `{ error }`

### `AdminReplyContact(raw)`

Replies to a contact message sent to a profile site (e.g. `fantasma.onion`) and notifies the handle if online. Only `coe_admin`.

| Parameter | Type | Description |
|---|---|---|
| `raw` | `table` | `{ id, reply }` |

**Returns**

- `table` `result` — `{ ok }` or `{ error }` (`invalid_reply`, `contact_closed`, `not_found`)

### `AdminCloseContact(raw)`

Archives a contact message. Only `coe_admin`.

| Parameter | Type | Description |
|---|---|---|
| `raw` | `table` | `{ id }` |

**Returns**

- `table` `result` — `{ ok }` or `{ error }`
