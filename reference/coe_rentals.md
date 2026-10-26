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
---@field coords table
---@field spawn table
---@field returnZone table
---@field blip table

---@class ActiveRentalInfo
---@field entity integer
---@field netId integer
---@field plate string
---@field model string
---@field deposit number
---@field stationId string
---@field rentedAt integer
```

