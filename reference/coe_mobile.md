# coe_mobile — referência da API

> Gerado de `coe_mobile/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Exports server-only. A tela usa o evento coe_mobile:request (pedido/resposta) e não faz parte do contrato.

## Exports

### `Yield()`

Um pacote com smartphone completo assume o telefone: o básico encerra as ligações, fecha as telas e para de abrir até o resource chamador parar. Só resources com a ACE `coe.mobile.yield`. Chame ao iniciar e de novo no `onResourceStart` do coe_mobile.

**Retorno**

- `true|{` `error:` — string } result `forbidden`

### `Status()`

Situação do telefone básico.

**Retorno**

- `CoeMobileStatus` `status`

### `NumberOf(characterId)`

Número do personagem no telefone básico (formato 555-0123), ou nil se ele ainda não usou o telefone. Não gera número. Chame de dentro de uma thread (consulta o banco).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `string\|integer` |  |

**Retorno**

- `string|nil` `number`

## Tipos

```lua
---@class CoeMobileStatus
---@field active boolean O telefone básico está atendendo (abre, liga e recebe mensagens)
---@field yieldedBy string|nil Resource que assumiu o telefone
```

