# coe_supervisor — referência da API

> Gerado de `coe_supervisor/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Exports server-only, restritos ao resource em `SupervisorConfig.Caller` (coe_admin).

## Exports

### `List()`

Resources gerenciados, com categoria, dependências e dependentes.

**Retorno**

- `CoeSupervisorEntry[]|nil` `list` — `nil` para chamador não autorizado

### `Restart(name, requester)`

Reinicia o resource e os dependentes na ordem correta (com `refresh` antes dos starts).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `name` | `string` |  |
| `requester` | `integer\|nil` | Jogador que pediu (auditoria) |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode`

## Tipos

```lua
---@class CoeSupervisorEntry
---@field name string
---@field category string
---@field critical boolean Reinício afeta muitos resources
---@field description string|nil
---@field dependencies string[]
---@field dependents string[]
---@field replacedBy string|nil Pacote que substitui este básico agora (coe_supervisor_replaces)
```

