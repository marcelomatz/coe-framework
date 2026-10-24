# coe_vehicles — referência da API

> Gerado de `coe_vehicles/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

## Exports

### `Create(data)`

Cria um veículo registrado. Somente `WriterResources`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `data` | `CoeVehicleCreate` |  |

**Retorno**

- `CoeVehicle|string` `vehicleOrError` — Código de erro: `invalid_model`, `plate_taken`, `vehicle_limit_reached`, ...

### `Get(vehicleId)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `string` |  |

**Retorno**

- `CoeVehicle|string|nil`

### `GetByPlate(plate)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `plate` | `string` |  |

**Retorno**

- `CoeVehicle|string|nil`

### `ListByOwner(characterId)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `string` |  |

**Retorno**

- `CoeVehicle[]|string`

### `GetEntity(vehicleId)`

Retorna a entidade FiveM do veículo se estiver spawnado no servidor.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `string` |  |

**Retorno**

- `integer|nil` `entity`

### `GetMileage(vehicleId)`

Quilometragem em metros.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `string` |  |

**Retorno**

- `number|string`

### `SetMileage(vehicleId, meters)`

Corrige a quilometragem (grava na hora e audita). Somente `MileageEditors`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `string` |  |
| `meters` | `number` |  |

**Retorno**

- `true|string`

### `Spawn(vehicleId, x, y, z, heading, vehicleType)`

Cria a entidade no mundo, fixa o veículo no registro e ativa o Mileage.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `string` |  |
| `x` | `number` |  |
| `y` | `number` |  |
| `z` | `number` |  |
| `heading` | `number` |  |
| `vehicleType` | `string\|nil` |  |

**Retorno**

- `number|string` `netIdOrError`

### `Store(vehicleId)`

Grava a quilometragem, remove a entidade e marca o veículo como `stored`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `string` |  |

**Retorno**

- `true|string`

### `IsReady()`

**Retorno**

- `boolean` `ready`

### `HasKey(characterId, vehicleId)`

O dono sempre tem a chave; as demais ficam em `coe_vehicle_keys`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `string` |  |
| `vehicleId` | `string` |  |

**Retorno**

- `boolean` `hasKey`

### `GiveKey(vehicleId, characterId)`

Concede uma chave (ex.: concessionária). Somente `WriterResources`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `string` |  |
| `characterId` | `string` |  |

**Retorno**

- `true|string` `okOrError` — `already_owner`, `key_limit_reached`, `invalid_character_id`, ...

### `RevokeKey(vehicleId, characterId)`

Retira uma chave emprestada. Somente `WriterResources`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `string` |  |
| `characterId` | `string` |  |

**Retorno**

- `true|string` `okOrError`

### `ListKeyHolders(vehicleId)`

Personagens (além do dono) que têm a chave.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `vehicleId` | `string` |  |

**Retorno**

- `string[]|nil` `characterIds`

## Tipos

```lua
---@class CoeVehicle
---@field id string
---@field ownerCharacterId string|nil
---@field model string
---@field plate string
---@field mileage number Metros inteiros
---@field state string `stored`, `out` ou `impounded`

---@class CoeVehicleCreate
---@field characterId string|nil Dono; sem dono = estoque
---@field model string
---@field plate string|nil Gerada pelo padrão se omitida
---@field mileage number|nil Metros iniciais (usados)
```

