# coe_database — referência da API

> Gerado de `coe_database/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

## Exports

### `Query(sql, parameters, callback)`

SELECT parametrizado (placeholders `?`).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `sql` | `string` |  |
| `parameters` | `any[]` |  |
| `callback` | `CoeDatabaseCallback` |  |

### `Execute(sql, parameters, callback)`

INSERT/UPDATE/DELETE/DDL parametrizado.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `sql` | `string` |  |
| `parameters` | `any[]` |  |
| `callback` | `CoeDatabaseCallback` |  |

### `Transaction(statements, callback)`

Executa as instruções numa transação (tudo ou nada).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `statements` | `{` | sql: string, parameters: any[] }[] |
| `callback` | `CoeDatabaseCallback` |  |

### `IsReady()`

Conexão pronta para uso.

**Retorno**

- `boolean` `ready` — `false` também para chamador não autorizado

## Tipos

```lua
---@alias CoeDatabaseCallback fun(success: boolean, result: any, errorCode: string|nil)
```

