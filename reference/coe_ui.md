# coe_ui — referência da API

> Gerado de `coe_ui/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

## Exports

### `GetTheme()`

Tema ativo. Server: tema padrão; client: tema recebido (`nil` antes do primeiro envio).

**Retorno**

- `string|nil` `name`

### `GetThemes()`

Temas disponíveis e o atual. Server.

**Retorno**

- `{` `current:` — string, options: CoeThemeOption[] }

### `SetTheme(name)`

Define o tema padrão do servidor e avisa todos os clientes. Server; só `UiConfig.Caller` (coe_admin).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `name` | `string` |  |

**Retorno**

- `true|string` `result` — `true` ou `forbidden`, `invalid_theme`

### `GetAccent()`

Cor escolhida pelo jogador (`theme` = usar o padrão do servidor). Client.

**Retorno**

- `CoeAccent`

### `SetAccent(name)`

Define a cor do jogador, grava em KVP e dispara `coe_ui:accentChanged`. Client.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `name` | `CoeAccent` |  |

## Tipos

```lua
---@alias CoeAccent 'theme'|'lime'|'cyan'|'amber'|'rose'|'violet'

---@class CoeThemeOption
---@field name string
---@field label string
```

