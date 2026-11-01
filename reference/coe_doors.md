# coe_doors — referência da API

> Gerado de `coe_doors/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

## Exports

### `CanAccess(playerId, id)`

Export server `CanAccess` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `id` | `any` |  |

**Retorno**

- `any`

### `Delete(placeId)`

Export server `Delete` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `placeId` | `any` |  |

**Retorno**

- `any`

### `IsLocked(id)`

API para outros resources (assaltos, eventos, scripts de negócio) ------------------------------------- id: "<local>:<porta>" para uma porta, ou "<local>" para todas as portas do local.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `any` |  |

**Retorno**

- `any`

### `IsReady()`

Export server `IsReady` (server/main.lua).

**Retorno**

- `any`

### `List()`

Export server `List` (server/main.lua).

**Retorno**

- `any`

### `Save(raw)`

Export server `Save` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `raw` | `any` |  |

**Retorno**

- `any`

### `SetLocked(id, locked)`

Export server `SetLocked` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `any` |  |
| `locked` | `any` |  |

**Retorno**

- `any`

### `TabletCall(playerId, _, action, payload)`

Export server `TabletCall` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `_` | `any` |  |
| `action` | `any` |  |
| `payload` | `any` |  |

**Retorno**

- `any`

### `TabletVisible(playerId)`

Export server `TabletVisible` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |

**Retorno**

- `any`

