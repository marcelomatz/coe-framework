# coe_spawn — referência da API

> Gerado de `coe_spawn/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

## Exports

### `GetStarterHotel()`

Retorna a configuração atual do hotel de nascimento dos jogadores.

**Retorno**

- `StarterHotel`

### `SetStarterHotel(data)`

Salva e atualiza as configurações do hotel de nascimento, sincronizando com os jogadores conectados.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `data` | `StarterHotel\|table` |  |

**Retorno**

- `boolean` `success,` — string? errorCode

## Tipos

```lua
---@class StarterHotelCoords
---@field x number
---@field y number
---@field z number
---@field h number?

---@class StarterHotelStash
---@field x number
---@field y number
---@field z number
---@field slots number
---@field maxWeight number

---@class StarterHotel
---@field name string
---@field enabled boolean
---@field entrance StarterHotelCoords
---@field room StarterHotelCoords
---@field exit StarterHotelCoords
---@field stash StarterHotelStash
```

