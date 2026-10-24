# coe_notify — referência da API

> Gerado de `coe_notify/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

## Exports

### `Notify(playerId, kind, message, duration)`

Mostra uma notificação a um jogador. Server; só resources autorizados.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `kind` | `CoeNotifyKind` |  |
| `message` | `string` | 1 a 240 caracteres |
| `duration` | `integer\|nil` | 1500 a 10000 ms (padrão 4000) |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode` — `caller_not_allowed`, `invalid_target`, `invalid_notification`

### `Show(kind, message, duration)`

Mostra uma notificação local. Client.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `kind` | `CoeNotifyKind` |  |
| `message` | `string` | 1 a 240 caracteres |
| `duration` | `integer\|nil` | 1500 a 10000 ms (padrão 4000) |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_notification`

## Tipos

```lua
---@alias CoeNotifyKind 'info'|'success'|'warning'|'error'
```

