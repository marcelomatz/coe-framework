# coe_bank — referência da API

> Gerado de `coe_bank/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Exports server-only. A tela usa o evento coe_bank:request (pedido/resposta) e não faz parte do contrato.

## Exports

### `Yield()`

Um pacote com banco completo assume o atendimento: o banco básico esconde agências, caixas eletrônicos e blips e fecha as telas abertas até o resource chamador parar. Só resources com a ACE `coe.bank.yield`. Chame ao iniciar e de novo no `onResourceStart` do coe_bank.

**Retorno**

- `true|{` `error:` — string } result `forbidden`

### `Status()`

Situação do banco básico.

**Retorno**

- `CoeBankStatus` `status`

## Tipos

```lua
---@class CoeBankStatus
---@field active boolean O banco básico está atendendo (agências, caixas e blips visíveis)
---@field yieldedBy string|nil Resource que assumiu o banco
```

