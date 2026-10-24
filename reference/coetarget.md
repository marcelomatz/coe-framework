# coetarget — referência da API

> Gerado de `coetarget/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Exports client-only. As opções ficam registradas por resource chamador e saem ao parar o resource.

## Exports

### `AddTargetEntity(entity, options)`

Opções para uma entidade específica.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `entity` | `integer` |  |
| `options` | `CoeTargetOption[]` |  |

**Retorno**

- `boolean` `ok` — `false` se a entidade não existe ou as opções são inválidas

### `RemoveTargetEntity(entity)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `entity` | `integer` |  |

### `AddTargetModel(model, options)`

Opções para todas as entidades de um modelo.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `model` | `integer\|string` | Hash ou nome do modelo |
| `options` | `CoeTargetOption[]` |  |

**Retorno**

- `boolean` `ok`

### `RemoveTargetModel(model)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `model` | `integer\|string` |  |

### `AddTargetGlobal(entityType, options)`

Opções para todas as entidades de um tipo.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `entityType` | `CoeTargetGlobalType` |  |
| `options` | `CoeTargetOption[]` |  |

**Retorno**

- `boolean` `ok`

### `RemoveTargetGlobal(entityType)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `entityType` | `CoeTargetGlobalType` |  |

### `AddTargetSurface(options)`

Opções para qualquer superfície mirada; `entity` é 0 quando a mira acerta o mapa.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `options` | `CoeTargetOption[]` |  |

**Retorno**

- `boolean` `ok`

### `RemoveTargetSurface()`

## Tipos

```lua
---@class CoeTargetOption
---@field label string
---@field onSelect fun(entity: integer, option: CoeTargetOption, hit: vector3|nil)
---@field distance number|nil Alcance máximo (padrão `DefaultOptionDistance`)
---@field canInteract (fun(entity: integer, distance: number, hit: vector3|nil): boolean)|nil

---@alias CoeTargetGlobalType 'player'|'ped'|'vehicle'|'object'
```

