# coe_tablet — referência da API

> Gerado de `coe_tablet/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

## Exports

### `TabletVisible(playerId, appId)`

Apps próprios do tablet (Ponto e Empregos livres, os do tablet de trabalho básico): o app aparece? Só o próprio coe_tablet chama (ownerCheck). `duty` precisa do coe_businesses; `freejobs`, do coe_jobs.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` | `duty` ou `freejobs` |

**Retorno**

- `boolean` `visible`

### `TabletCall(playerId, appId, action)`

Ações dos apps próprios do tablet. Só o próprio coe_tablet chama (a lista de apps e o acesso já foram conferidos). `duty`: `overview`, `clockOut`. `freejobs`: `list`. Erros: `forbidden`, `invalid_action`, `no_character`, `app_unavailable`, `not_on_duty`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` |  |
| `action` | `string` |  |

**Retorno**

- `table` `result` — `{ ok = true, data }` ou `{ ok = false, error }`

## Tipos

```lua
---@class CoeTabletApp
---@field id string
---@field label string
---@field script string

---@class CoeTabletProfile
---@field job string|nil
---@field label string|nil
---@field grade number
---@field apps CoeTabletApp[]
```

