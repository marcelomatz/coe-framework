# coe_mail — referência da API

> Gerado de `coe_mail/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

## Exports

### `Send(from, to, subject, body)`

E-mail do sistema (ex.: avisos de outros resources). from: { address, name }; to: endereço ou lista. Devolve { ok, bounced } ou { ok = false, error }.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `from` | `any` |  |
| `to` | `any` |  |
| `subject` | `any` |  |
| `body` | `any` |  |

**Retorno**

- `any`

### `TabletCall(playerId, appId, action, payload)`

Export server `TabletCall` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |
| `action` | `any` |  |
| `payload` | `any` |  |

**Retorno**

- `any`

### `TabletVisible(playerId, appId)`

Export server `TabletVisible` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |

**Retorno**

- `any`

