# coe_needs — referência da API

> Gerado de `coe_needs/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

## Exports

### `GetNeeds(source)`

Estado atual do jogador. Server.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `source` | `integer` |  |

**Retorno**

- `CoeNeedsState|nil` `snapshot` — `nil` se o personagem não está carregado

### `AddNeed(source, name, delta)`

Soma `delta` a uma necessidade (limitada a 0-100). Server; só resources em `AllowedResources`. Gravação em lote periódico.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `source` | `integer` |  |
| `name` | `CoeNeedName` |  |
| `delta` | `number` |  |

**Retorno**

- `true|string` `result` — `true` ou `caller_not_allowed`, `needs_not_loaded`, `invalid_need`

### `SetNeed(source, name, value)`

Define o valor de uma necessidade. Mesmas regras de `AddNeed`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `source` | `integer` |  |
| `name` | `CoeNeedName` |  |
| `value` | `number` |  |

**Retorno**

- `true|string` `result` — `true` ou `caller_not_allowed`, `needs_not_loaded`, `invalid_need`

### `GetState()`

Último estado recebido do servidor. Client.

**Retorno**

- `CoeNeedsState|nil`

## Tipos

```lua
---@alias CoeNeedName 'hunger'|'thirst'|'stress'

---@class CoeNeedsState
---@field hunger integer 0-100
---@field thirst integer 0-100
---@field stress integer 0-100
```

