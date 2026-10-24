# coe_map — referência da API

> Gerado de `coe_map/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Exports client-only. Evento local: `coe_map:changed` (mode, scale).

## Exports

### `GetMode()`

Modo atual do minimapa.

**Retorno**

- `CoeMapMode`

### `OpenFull()`

Abre o mapa completo do GTA para o jogador marcar um destino.

## Tipos

```lua
---@alias CoeMapMode 'mini'|'extended'
```

