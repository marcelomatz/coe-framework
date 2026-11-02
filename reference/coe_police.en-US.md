# coe_police — API reference

> Generated from `coe_police/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Generated from the exports registered in code; refine descriptions and types when editing each export.

## Exports

### `Arrest(officerSource, targetSource, minutes, charge)`

Server export `Arrest` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `officerSource` | `any` |  |
| `targetSource` | `any` |  |
| `minutes` | `any` |  |
| `charge` | `any` |  |

**Returns**

- `any`

### `Cuff(officerSource, targetSource)`

Server export `Cuff` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `officerSource` | `any` |  |
| `targetSource` | `any` |  |

**Returns**

- `any`

### `Escort(officerSource, targetSource)`

Server export `Escort` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `officerSource` | `any` |  |
| `targetSource` | `any` |  |

**Returns**

- `any`

### `Fine(officerSource, targetSource, amount, charge)`

Server export `Fine` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `officerSource` | `any` |  |
| `targetSource` | `any` |  |
| `amount` | `any` |  |
| `charge` | `any` |  |

**Returns**

- `any`

### `IsCuffed(source)`

Server export `IsCuffed` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `source` | `any` |  |

**Returns**

- `any`

### `IsEscorted(source)`

Server export `IsEscorted` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `source` | `any` |  |

**Returns**

- `any`

### `IsJailed(source)`

Server export `IsJailed` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `source` | `any` |  |

**Returns**

- `any`

### `Records(officerSource, subjectCharacterId, limit)`

Criminal record for a character: requires `police.records` at a police business with a duty location.

| Parameter | Type | Description |
|---|---|---|
| `officerSource` | `any` |  |
| `subjectCharacterId` | `any` |  |
| `limit` | `any` |  |

**Returns**

- `any`

### `Search(officerSource, targetSource)`

Server export `Search` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `officerSource` | `any` |  |
| `targetSource` | `any` |  |

**Returns**

- `any`

### `Seize(officerSource, targetSource, slot, count)`

Server export `Seize` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `officerSource` | `any` |  |
| `targetSource` | `any` |  |
| `slot` | `any` |  |
| `count` | `any` |  |

**Returns**

- `any`

### `Uncuff(officerSource, targetSource)`

Server export `Uncuff` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `officerSource` | `any` |  |
| `targetSource` | `any` |  |

**Returns**

- `any`
