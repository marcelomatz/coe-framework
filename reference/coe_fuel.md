# coe_fuel — referência da API

> Gerado de `coe_fuel/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Exports server-only. Bombas e galão usam o evento coe_fuel:request (pedido/resposta); o consumo usa
coe_fuel:init e coe_fuel:report. O tanque fica no state bag `coe:fuel` do veículo.

## Exports

### `IsReady()`

Migrações aplicadas e tanques dos postos lidos.

**Retorno**

- `boolean` `ready`

### `GetFuel(vehicleId)`

Tanque de um veículo registrado que está em uso (ou nil).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `string\|integer` |  |

**Retorno**

- `CoeFuelSummary|nil` `fuel`

### `GetEffects(vehicleId)`

Efeito da mistura no motor para o coe_handling (força com etanol e aditivada). nil sem tanque em uso.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `string\|integer` |  |

**Retorno**

- `table|nil` `effects` — `{ mods = { fInitialDriveForce = number }, key = string }`

### `GetStationTanks(stationId)`

Tanques de um posto (postos de jogador vendem só o que está aqui), com nível e capacidade de cada combustível.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `stationId` | `string` |  |

**Retorno**

- `table|nil` `tanks` — `{ business, tanks = { [combustível] = litros }, levels, capacities }`

### `IsStation(businessId)`

É um posto do coe_fuel (o id do negócio do posto)? Usado pelo app do negócio para mostrar a aba Posto.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |

**Retorno**

- `boolean` `station`

### `BusinessTablet(playerId, characterId, businessId, payload)`

Aba Posto do app do negócio no tablet. Só o coe_businesses chama (o acesso ao app já foi conferido lá). payload.op: `overview`, `price` (`fuel`, `price`; `false` volta à tabela), `upgradeTank` (`fuel`) ou `upgradeFleet`. Erros: `forbidden`, `not_ready`, `not_a_station`, `staff_station`, `invalid_price`, `not_enough_sales`, `insufficient_funds`, `max_level`, `no_fleet_garage`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `characterId` | `string` |  |
| `businessId` | `string` |  |
| `payload` | `table` |  |

**Retorno**

- `table` `result`

## Tipos

```lua
---@class CoeFuelSummary
---@field liters number Litros no tanque
---@field capacity integer Capacidade (litros)
---@field level number 0..1
---@field engine 'flex'|'diesel'|'none'
---@field main string|nil Combustível com mais litros
---@field tank table<string,number> Litros de cada combustível (regular, premium, ethanol, diesel)
```

