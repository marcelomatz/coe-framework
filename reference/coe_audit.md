# coe_audit — referência da API

> Gerado de `coe_audit/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

## Exports

### `Record(severity, category, event, context)`

Enfileira um evento de auditoria e retorna na hora; a gravação é assíncrona em lote. O recurso chamador é registrado automaticamente e precisa estar em `AllowedResources`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `severity` | `string` |  |
| `category` | `string` |  |
| `event` | `string` |  |
| `context` | `table\|nil` | Só campos de `AllowedContextFields` |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_*`, `resource_not_allowed`, `queue_full`, ...

### `IsReady()`

Persistência inicializada (migrações aplicadas).

**Retorno**

- `boolean` `ready`

