# coe_rentals — referência da API

> Gerado de `coe_rentals/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Tipagens públicas de coe_rentals para LuaLS.

## Exports

### `GetActiveRental(characterId)`

Retorna o aluguel ativo de um personagem ou nil.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `string` |  |

**Retorno**

- `ActiveRentalInfo|nil`

### `ListStations()`

Estações cadastradas. Só `AdminResources`/ACE `coe.rentals.admin` (outros recebem lista vazia).

**Retorno**

- `RentalStationDef[]`

### `SaveStation(raw)`

Cria ou atualiza uma estação. Só `AdminResources`/ACE `coe.rentals.admin`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `raw` | `RentalStationDef` |  |

**Retorno**

- `RentalStationDef|table` `station` — a estação salva ou { error = código }

### `DeleteStation(stationId)`

Remove uma estação. Só `AdminResources`/ACE `coe.rentals.admin`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `stationId` | `string` |  |

**Retorno**

- `boolean|table` `ok` — `true` ou { error = código }

### `Catalog()`

Catálogo de veículos do aluguel (config.lua).

**Retorno**

- `RentalVehicleDef[]`

## Tipos

```lua
---@class RentalVehicleDef
---@field model string
---@field label string
---@field category string
---@field price number
---@field deposit number

---@class RentalStationDef
---@field id string
---@field label string
---@field enabled boolean
---@field ped table { x, y, z, h, model? } atendente (NPC) e balcão
---@field spawns table[] pontos de retirada { x, y, z, h } (1 a 8); o veículo sai no primeiro livre
---@field returnZone table { x, y, z, radius } zona de devolução
---@field vehicles string[] modelos oferecidos (vazio: todo o catálogo)
---@field blip table { enabled, sprite, color, scale }

---@class ActiveRentalInfo
---@field entity integer
---@field netId integer
---@field plate string
---@field model string
---@field deposit number
---@field stationId string
---@field rentedAt integer
```

