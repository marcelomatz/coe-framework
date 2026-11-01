# coe_mechanic — referência da API

> Gerado de `coe_mechanic/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

## Exports

### `TabletCall(source, appId, action, payload)`

Ações do tablet de oficina (`scan`, `replace`). Só aceita o `coe_tablet`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `source` | `number` |  |
| `appId` | `string` |  |
| `action` | `string` |  |
| `payload` | `table` |  |

**Retorno**

- `table` `result` — `{ ok = true, vehicle = ... }` ou `{ ok = false, error = string }`

### `Inspect(vehicleId)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `number` |  |

**Retorno**

- `CoePartStatus[]|nil`

### `ReplacePart(vehicleId, part)`

Apenas resources em `WriterResources`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `number` |  |
| `part` | `string` |  |

**Retorno**

- `true|string` `result` — `true` ou `forbidden`, `unknown_part`, `vehicle_not_found`, `not_ready`

### `ServiceVehicle(vehicleId)`

Troca todas as peças em aviso/crítico.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `number` |  |

**Retorno**

- `true|string`

### `AdjustMileage(vehicleId, meters)`

Corrige a quilometragem (metros); auditado por `coe_vehicles`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `number` |  |
| `meters` | `number` |  |

**Retorno**

- `true|string`

### `AddWear(vehicleId, meters, parts)`

Desgaste extra nas peças (só `WearResources`, hoje o coe_fuel). meters > 0 envelhece; < 0 desconta o extra já acumulado (nunca deixa a peça mais nova que a troca). Zera quando a peça é trocada.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `number\|string` |  |
| `meters` | `integer` |  |
| `parts` | `string[]` |  |

**Retorno**

- `true|string`

### `GetEffects(vehicleId, mileage)`

Efeitos das peças no handling, usados por `coe_handling`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `number` |  |
| `mileage` | `number\|nil` |  |

**Retorno**

- `{` `mods:` — table<string, number>, key: string }|nil

### `ListParts()`

**Retorno**

- `string[]`

### `IsReady()`

**Retorno**

- `boolean`

### `GetShopOwner(shopId)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `shopId` | `string` |  |

**Retorno**

- `string|nil` `characterId` — Dono da oficina (personagem), ou nil sem dono

### `GetAppearance(vehicleId)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `number` |  |

**Retorno**

- `CoeAppearance|nil`

### `QuoteAppearance(vehicleId, patch)`

Orçamento (proporcional ao valor do catálogo) de um patch, sem gravar.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `number` |  |
| `patch` | `CoeAppearance` |  |

**Retorno**

- `{` `total:` — number, lines: table[] }|string result Orçamento ou código de erro

### `SetAppearance(vehicleId, patch)`

Mescla o patch na aparência salva e aplica no veículo. Apenas `WriterResources`; a cobrança é do chamador.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `number` |  |
| `patch` | `CoeAppearance` |  |

**Retorno**

- `true|string` `result` — `true` ou `forbidden`, `invalid_*`, `vehicle_not_found`, `not_ready`

### `GetShops()`

Lista de oficinas configuradas.

**Retorno**

- `table<string,` `table>` — shops

### `GetVehicleOptions(vehicle)`

Opções de customização e mods disponíveis para a entidade do veículo. Client.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicle` | `integer` | Entidade do veículo |

**Retorno**

- `table|nil` `options`

## Tipos

```lua
---@class CoePartStatus
---@field part string
---@field wear number 0 = novo, 1 = no limite
---@field installedAtMeters number
---@field condition string `ok`, `warn` ou `critical`

---@class exports_coe_mechanic

---@class CoeAppearance
---@field colors table|nil `primary`, `secondary`, `pearl`, `wheel`, `interior`, `dashboard` (índices GTA), `primaryRgb`/`secondaryRgb` ({r,g,b})
---@field mods table<string, number>|nil Tipo de mod (string) -> índice; -1 remove
---@field toggles table<string, boolean>|nil `turbo`, `tyreSmoke`, `xenon`
---@field livery number|nil -1 remove
---@field tint number|nil
---@field plateIndex number|nil
---@field wheelType number|nil
---@field xenonColor number|nil
---@field neon { sides: boolean[]|nil, rgb: number[]|nil }|nil
---@field extras table<string, boolean>|nil
```

