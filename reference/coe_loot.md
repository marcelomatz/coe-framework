# coe_loot — referência da API

> Gerado de `coe_loot/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

## Exports

### `Give(playerId, tableId)`

Sorteia uma tabela e entrega no inventário do personagem do jogador.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `tableId` | `string` | Ex.: `house_robbery`, `pedestrian_robbery`, `vehicle_break_in`, `store_robbery` |

**Retorno**

- `CoeLootGiveResult` `result`

### `Roll(tableId)`

Sorteia sem entregar (para pôr o saque num baú, num container ou no chão).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `tableId` | `string` |  |

**Retorno**

- `CoeLootRollResult` `result`

### `Tables()`

Tabelas carregadas. Leitura livre.

**Retorno**

- `{` `id:` — string, label: string }[] tables

## Tipos

```lua
---@class CoeLootGiveResult
---@field ok boolean
---@field error string|nil `forbidden|unknown_table|no_character`
---@field given { item: string, count: integer }[]|nil Entregue
---@field lost { item: string, count: integer }[]|nil Não coube no inventário

---@class CoeLootRollResult
---@field ok boolean
---@field error string|nil `forbidden|unknown_table`
---@field items { item: string, count: integer, unique: boolean }[]|nil
```

