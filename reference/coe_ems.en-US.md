# coe_ems — API reference

> Generated from `coe_ems/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Generated from the exports registered in code; refine descriptions and types when editing each export.

## Exports

### `Records(medicSource, patientCharacterId, limit)`

Patient (character) medical record: requires the `ems.records` role at an EMS business with a duty location.

| Parameter | Type | Description |
|---|---|---|
| `medicSource` | `any` |  |
| `patientCharacterId` | `any` |  |
| `limit` | `any` |  |

**Returns**

- `any`

### `Revive(medicSource, targetSource, detail)`

Server export `Revive` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `medicSource` | `any` |  |
| `targetSource` | `any` |  |
| `detail` | `any` |  |

**Returns**

- `any`

### `SetState(source, state)`

coe_needs, coe_hud, and coe_admin can set the state (e.g. damage from another system).

| Parameter | Type | Description |
|---|---|---|
| `source` | `any` |  |
| `state` | `any` |  |

**Returns**

- `any`

### `State(source)`

Server export `State` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `source` | `any` |  |

**Returns**

- `any`

### `Treat(medicSource, targetSource, detail)`

Server export `Treat` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `medicSource` | `any` |  |
| `targetSource` | `any` |  |
| `detail` | `any` |  |

**Returns**

- `any`
