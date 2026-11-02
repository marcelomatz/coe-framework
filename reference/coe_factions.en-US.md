# coe_factions — API reference

> Generated from `coe_factions/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Generated from the exports registered in code; refine descriptions and types when editing each export.

## Exports

### `CanCraft(characterId, recipeId)`

Server export `CanCraft` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `any` |  |
| `recipeId` | `any` |  |

**Returns**

- `any`

### `CanCraftInFaction(factionId, characterId, recipeId)`

Server export `CanCraftInFaction` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `factionId` | `any` |  |
| `characterId` | `any` |  |
| `recipeId` | `any` |  |

**Returns**

- `any`

### `Categories()`

Server export `Categories` (`server/main.lua`).

**Returns**

- `any`

### `Delete(factionId)`

Server export `Delete` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `factionId` | `any` |  |

**Returns**

- `any`

### `Get(factionId)`

Server export `Get` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `factionId` | `any` |  |

**Returns**

- `any`

### `IsReady()`

Server export `IsReady` (`server/main.lua`).

**Returns**

- `any`

### `List()`

Server export `List` (`server/main.lua`).

**Returns**

- `any`

### `Members(factionId)`

Server export `Members` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `factionId` | `any` |  |

**Returns**

- `any`

### `Memberships(characterId)`

Server export `Memberships` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `any` |  |

**Returns**

- `any`

### `PauseMenuFaction(characterId)`

Faction shown in the pause-menu dossier (`coe_pausemenu:RegisterFactionProvider`): the character's first active faction.

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `any` |  |

**Returns**

- `any`

### `RecipesFor(characterId)`

Server export `RecipesFor` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `any` |  |

**Returns**

- `any`

### `RecipesForFaction(factionId, characterId)`

Recipes specifically unlocked for a member in a faction; nil if the character is not a member or the faction is inactive.

| Parameter | Type | Description |
|---|---|---|
| `factionId` | `any` |  |
| `characterId` | `any` |  |

**Returns**

- `any`

### `RemoveMember(factionId, characterId)`

Server export `RemoveMember` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `factionId` | `any` |  |
| `characterId` | `any` |  |

**Returns**

- `any`

### `Save(raw)`

Server export `Save` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `raw` | `any` |  |

**Returns**

- `any`

### `SetMember(factionId, characterId, grade)`

Server export `SetMember` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `factionId` | `any` |  |
| `characterId` | `any` |  |
| `grade` | `any` |  |

**Returns**

- `any`

### `TabletCall(playerId, appId, action, payload, factionId)`

Server export `TabletCall` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |
| `action` | `any` |  |
| `payload` | `any` |  |
| `factionId` | `any` |  |

**Returns**

- `any`

### `TabletInstances(playerId)`

Server export `TabletInstances` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |

**Returns**

- `any`
