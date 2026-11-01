# coe_garages — referência da API

> Gerado de `coe_garages/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

## Exports

### `AddBusinessFleet(businessId, model, staff)`

Frota comprada por um resource do negócio (FleetResources, ex.: coe_fuel): cria o veículo na primeira garagem de negócio do negócio e, se `staff`, libera para a equipe. Devolve o registro ({ id, plate, ... }) ou { error }.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `any` |  |
| `model` | `any` |  |
| `staff` | `any` |  |

**Retorno**

- `any`

### `AddFleetVehicle(garageId, model)`

Export server `AddFleetVehicle` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `garageId` | `any` |  |
| `model` | `any` |  |

**Retorno**

- `any`

### `BusinessFleet(businessId)`

Export server `BusinessFleet` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `any` |  |

**Retorno**

- `any`

### `DeleteGarage(garageId)`

Export server `DeleteGarage` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `garageId` | `any` |  |

**Retorno**

- `any`

### `ListFleet(garageId)`

Export server `ListFleet` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `garageId` | `any` |  |

**Retorno**

- `any`

### `ListGarages()`

Export server `ListGarages` (server/main.lua).

**Retorno**

- `any`

### `RemoveFleetVehicle(garageId, vehicleId)`

Export server `RemoveFleetVehicle` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `garageId` | `any` |  |
| `vehicleId` | `any` |  |

**Retorno**

- `any`

### `SaveGarage(raw)`

Export server `SaveGarage` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `raw` | `any` |  |

**Retorno**

- `any`

### `SetFleetStaffAccess(businessId, vehicleId, enabled)`

Export server `SetFleetStaffAccess` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `any` |  |
| `vehicleId` | `any` |  |
| `enabled` | `any` |  |

**Retorno**

- `any`

### `TabletCall(playerId, appId, action)`

Export server `TabletCall` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |
| `action` | `any` |  |

**Retorno**

- `any`

