# coe_workpad — referência da API

> Gerado de `coe_workpad/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Exports server-only. A tela usa os eventos coe_workpad:open / coe_workpad:call e não faz parte do contrato.
Apps de outros resources respondem por TabletCall(playerId, appId, action, payload, instance) e, com instâncias,
TabletInstances(playerId); a interface registra-se com window.CoeTablet.register(id, render(container, api)).

## Exports

### `Yield()`

Um pacote com tablet completo assume: o básico fecha as telas e para de abrir até o resource chamador parar. Só resources com a ACE `coe.workpad.yield`. Chame ao iniciar e de novo no `onResourceStart` do coe_workpad.

**Retorno**

- `true|{` `error:` — string } result `forbidden`

### `Status()`

Situação do tablet básico.

**Retorno**

- `CoeWorkpadStatus` `status`

## Tipos

```lua
---@class CoeWorkpadStatus
---@field active boolean O tablet básico está atendendo (abre pelo item, tecla e comando)
---@field yieldedBy string|nil Resource que assumiu o tablet
```

