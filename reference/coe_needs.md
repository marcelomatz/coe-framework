# coe_needs — referência da API

> Gerado de `coe_needs/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

## Exports

### `GetNeeds(playerSource)`

[shared] No servidor recebe `playerSource`; no cliente nao recebe argumentos e retorna o snapshot local.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerSource?` | `integer` |  |

**Retorno**

- `CoeNeedsSnapshot|nil`

### `SetNeed(playerSource, needName, value)`

[server] Define o valor absoluto (0..100) de uma necessidade. Requer ACE `coe.needs`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerSource` | `integer` |  |
| `needName` | `CoeNeedName` |  |
| `value` | `number` |  |

**Retorno**

- `boolean|'caller_not_allowed'|'character_not_loaded'|'invalid_need'`

### `AddNeed(playerSource, needName, delta)`

[server] Soma `delta` (positivo ou negativo) a uma necessidade. Requer ACE `coe.needs`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerSource` | `integer` |  |
| `needName` | `CoeNeedName` |  |
| `delta` | `number` |  |

**Retorno**

- `boolean|'caller_not_allowed'|'character_not_loaded'|'invalid_need'`

## Tipos

```lua
---@alias CoeNeedName 'hunger'|'thirst'|'stress'|'alcohol'|'drugs'

---@class CoeNeedsSnapshot
---@field hunger integer # 0..100 (100 = saciado, 0 = faminto)
---@field thirst integer # 0..100 (100 = hidratado, 0 = desidratado)
---@field stress integer # 0..100 (0 = calmo, 100 = estressado)
---@field alcohol integer # 0..100 (0 = sobrio, 100 = alcoolizado)
---@field drugs integer # 0..100 (0 = limpo, 100 = sob efeito de substancias)

---@class exports_coe_needs
```

