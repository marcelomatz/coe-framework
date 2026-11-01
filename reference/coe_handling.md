# coe_handling — referência da API

> Gerado de `coe_handling/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

## Exports

### `GetTyre(vehicleId)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `number` |  |

**Retorno**

- `CoeTyreState|nil`

### `SetTyre(vehicleId, compound)`

Monta pneus novos (zera o desgaste). Apenas resources em `WriterResources`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `number` |  |
| `compound` | `string` |  |

**Retorno**

- `true|string` `result` — `true` ou código de erro (`forbidden`, `unknown_tyre`, `vehicle_not_found`, `not_ready`)

### `ListTyres()`

**Retorno**

- `string[]`

### `ListClasses()`

**Retorno**

- `string[]`

### `GetModifiers(vehicleId)`

Multiplicadores finais (perfil x pneu x desgaste) por campo de CHandlingData.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `number` |  |

**Retorno**

- `table<string,` `number>|nil`

### `IsReady()`

**Retorno**

- `boolean`

## Tipos

```lua
---@class CoeTyreState
---@field compound string `street`, `sport`, `performance`, `slick`, `all_terrain`, `offroad` ou `drift`
---@field fittedAtMeters number Quilometragem do veículo (m) quando os pneus foram montados
---@field wear number 0 = novo, 1 = no limite

---@class exports_coe_handling
```

