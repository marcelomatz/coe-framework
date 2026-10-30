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

### `Prompt(data)`

Mostra (ou limpa, com nil) o aviso de interação padrão do resource chamador. Client. Chame só quando o conteúdo mudar; um aviso por resource; o resource parado tem o aviso removido.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `data` | `CoeNotifyPrompt\|nil` |  |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_prompt`

## Tipos

```lua
---@alias CoeNotifyKind 'info'|'success'|'warning'|'error'

---@class CoeNotifyPromptOption
---@field key string tecla mostrada (até 12 caracteres)
---@field label string ação (até 80 caracteres)

---@class CoeNotifyPrompt
---@field title string até 64 caracteres
---@field subtitle string|nil até 64 caracteres
---@field badge string|nil selo à esquerda (até 3 caracteres; padrão: tecla da primeira opção)
---@field options CoeNotifyPromptOption[] até 6
```

