# coe_logging — referência da API

> Gerado de `coe_logging/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

## Exports

### `Log(level, category, event, context)`

Registra uma linha estruturada (JSON ou "pretty", conforme convar). O recurso chamador vira o campo `resource`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `level` | `CoeLogLevel` |  |
| `category` | `string` | Até 48 caracteres |
| `event` | `string` | Até 80 caracteres |
| `context` | `table\|nil` | Contexto sanitizado (sem segredos) |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_level`, `invalid_event`, `encoding_failed`, ...

## Tipos

```lua
---@alias CoeLogLevel 'debug'|'info'|'warn'|'error'
```

