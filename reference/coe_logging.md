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

### `GetRecent(limit)`

Retorna as entradas recentes mantidas no buffer circular Zero-GC em memória. Exige permissão ACE `coe.logging.log` do recurso chamador.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `limit` | `integer\|nil` | Quantidade máxima de entradas (padrão: capacidade total do RingBuffer) |

**Retorno**

- `table|nil` `entries` — Lista de entradas estruturadas (da mais antiga para a mais recente)
- `string|nil` `errorCode` — `resource_not_allowed` se o chamador não possuir ACE

## Tipos

```lua
---@alias CoeLogLevel 'debug'|'info'|'warn'|'error'
```

