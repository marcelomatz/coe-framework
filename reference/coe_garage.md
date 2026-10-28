# coe_garage — referência da API

> Gerado de `coe_garage/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

## Exports

### `IsReady()`

Informa se o subsistema de garagens está pronto e inicializado.

**Retorno**

- `boolean` `ready`

### `ListGarages()`

Lista todas as garagens públicas cadastradas.

**Retorno**

- `CoeGarage[]` `garages`

### `GetGarage(id)`

Retorna uma garagem cadastrada pelo seu ID único.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `string` | ID único da garagem |

**Retorno**

- `CoeGarage|nil` `garage`

### `GetVehicleGarage(vehicleId)`

Retorna o ID da garagem onde o veículo está alocado/guardado.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `string\|integer` | ID do veículo |

**Retorno**

- `string|nil` `garageId`

### `SaveGarage(data)`

Salva ou atualiza uma garagem pública.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `data` | `table` | Dados brutos da garagem |

**Retorno**

- `CoeGarage|nil` `garage` — Dados sanitizados e salvos
- `string|nil` `errorCode` — Código de erro caso falhe

### `DeleteGarage(id)`

Remove uma garagem cadastrada pelo seu ID único.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `string` | ID único da garagem |

**Retorno**

- `boolean|nil` `ok`
- `string|nil` `errorCode`

## Tipos

```lua
---@class CoeGarageSpot
---@field id string
---@field label string
---@field x number
---@field y number
---@field z number
---@field heading number
---@field radius number

---@class CoeGarageBlip
---@field enabled boolean
---@field sprite integer
---@field color integer
---@field scale number

---@class CoeGarage
---@field id string
---@field label string
---@field kind string
---@field enabled boolean
---@field spots CoeGarageSpot[]
---@field blip CoeGarageBlip
```

