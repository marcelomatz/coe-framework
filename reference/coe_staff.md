# coe_staff — referência da API

> Gerado de `coe_staff/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Exports server-only. A tela usa os eventos coe_staff:open / coe_staff:request e não faz parte do contrato.

## Exports

### `Yield()`

Um pacote com painel completo assume: o básico fecha e para de abrir até o resource chamador parar. Só resources com a ACE `coe.staff.yield`. Chame ao iniciar e de novo no `onResourceStart` do coe_staff.

**Retorno**

- `true|{` `error:` — string } result `forbidden`

### `Status()`

Situação do painel básico.

**Retorno**

- `CoeStaffStatus` `status`

### `RegisterGaragesProvider(provider)`

Registra um provedor de garagens para administração pelo painel staff (aba Garagens).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `provider` | `table` | List(), Save(raw), Delete(id) e `kinds` (tipos editáveis, padrão { 'public' }) |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_provider`

### `RegisterRentalsProvider(provider)`

Registra o provedor das estações de aluguel (aba Aluguel). Normalmente o coe_rentals.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `provider` | `table` | List(), Save(raw), Delete(id) e, opcional, Catalog() |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_provider`

## Tipos

```lua
---@class CoeStaffStatus
---@field active boolean O painel básico está atendendo
---@field yieldedBy string|nil Resource que assumiu o painel
```

