# coe_vehicle_catalog — referência da API

> Gerado de `coe_vehicle_catalog/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

## Exports

### `GetVehicleInfo(model)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `model` | `string` |  |

**Retorno**

- `CoeVehicleInfo|nil`

### `ListVehicles(filter)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `filter` | `CoeVehicleFilter\|nil` |  |

**Retorno**

- `CoeVehicleInfo[]`

### `GetBaseHandling(model)`

Valores escalares do handling.meta carregado (ex.: `fMass`), ou nil.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `model` | `string` |  |

**Retorno**

- `table<string,` `number>|nil`

### `GetIssues()`

**Retorno**

- `CoeVehicleCatalogIssue[]`

### `SetOverride(model, fields)`

Mescla e grava um override. Somente `WriterResources`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `model` | `string` |  |
| `fields` | `CoeVehicleOverride` |  |

**Retorno**

- `true|string` `okOrError` — `forbidden`, `unknown_model`, `invalid_price`, ...

### `ClearOverride(model)`

Remove o override do modelo. Somente `WriterResources`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `model` | `string` |  |

**Retorno**

- `true|string` `okOrError`

### `Rescan()`

Relê os resources de veículo. Somente `WriterResources`.

**Retorno**

- `true|string` `okOrError`

### `IsReady()`

**Retorno**

- `boolean` `ready`

## Tipos

```lua
---@class CoeVehicleInfo
---@field model string Minúsculo
---@field name string|nil
---@field brand string|nil
---@field class string `compacts`, `sedans`, `super`, ... ou `unknown` (addon sem classe)
---@field type string `automobile`, `bike`, `boat`, `heli`, `plane`, `submarine`, `trailer`, `train`
---@field seats number|nil
---@field isAddon boolean
---@field resource string|nil Resource do addon
---@field handlingId string|nil
---@field hasHandling boolean
---@field price number Override ou preço da classe
---@field stock number|nil nil = ilimitado
---@field category string Override ou a classe
---@field hidden boolean

---@class CoeVehicleFilter
---@field type string|nil
---@field class string|nil
---@field category string|nil
---@field brand string|nil
---@field addon boolean|nil
---@field search string|nil Trecho do modelo, nome ou marca
---@field minPrice number|nil
---@field maxPrice number|nil
---@field includeHidden boolean|nil
---@field limit integer|nil Padrão 200, máximo 500

---@class CoeVehicleOverride
---@field price integer|nil
---@field stock integer|nil
---@field category string|nil
---@field hidden boolean|nil

---@class CoeVehicleCatalogIssue
---@field level string `warn` ou `error`
---@field code string `duplicate_model`, `handling_missing`, `replaces_native`, ...
---@field model string|nil
---@field resource string|nil
```

