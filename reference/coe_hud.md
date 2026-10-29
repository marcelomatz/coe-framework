# coe_hud — referência da API

> Gerado de `coe_hud/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Todos os exports são client-side.

## Exports

### `SetHidden(reason, hidden)`

Esconde ou mostra o HUD por motivo. Use o nome do seu resource como motivo; o HUD só volta quando nenhum motivo restar. Também disponível pelo evento local `coe_hud:setHidden`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `reason` | `string` | Motivo (ex.: `GetCurrentResourceName()`) |
| `hidden` | `boolean` |  |

**Retorno**

- `boolean` `ok` — `false` para motivo vazio ou não-string

### `IsHidden()`

Algum resource está escondendo o HUD agora?

**Retorno**

- `boolean` `hidden`

### `SetLogoVisible(visible)`

Mostra ou esconde a logo do servidor (preferência salva do jogador).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `visible` | `boolean` |  |

**Retorno**

- `boolean` `visible` — Estado final da logo

### `IsLogoVisible()`

A logo está visível pela preferência do jogador?

**Retorno**

- `boolean` `visible`

### `ToggleLogo()`

Alterna a logo (mesmo efeito do comando `/logo`).

**Retorno**

- `boolean` `visible` — Estado depois de alternar

