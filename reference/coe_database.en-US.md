# coe_database — API Reference

> Generated from `coe_database/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

## Exports

### `Query(sql, parameters, callback)`

Executes a parameterized SELECT query (using positional `?` placeholders).

| Parameter | Type | Description |
|---|---|---|
| `sql` | `string` | Prepared SQL query string |
| `parameters` | `any[]` | Array of positional parameters |
| `callback` | `CoeDatabaseCallback` | Asynchronous completion callback |

### `Execute(sql, parameters, callback)`

Executes a parameterized INSERT, UPDATE, DELETE, or DDL statement.

| Parameter | Type | Description |
|---|---|---|
| `sql` | `string` | Prepared SQL query string |
| `parameters` | `any[]` | Array of positional parameters |
| `callback` | `CoeDatabaseCallback` | Asynchronous completion callback |

### `Transaction(statements, callback)`

Executes multiple statements within an atomic database transaction (all-or-nothing rollback).

| Parameter | Type | Description |
|---|---|---|
| `statements` | `{ sql: string, parameters: any[] }[]` | List of statements to execute |
| `callback` | `CoeDatabaseCallback` | Asynchronous completion callback |

### `IsReady()`

Verifies if the database connection pool is active and ready for operations.

**Returns**

- `boolean` `ready` — `false` if not ready or caller is unauthorized

## Types

```lua
---@alias CoeDatabaseCallback fun(success: boolean, result: any, errorCode: string|nil)
```
