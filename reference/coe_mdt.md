# coe_mdt — referência da API

> Gerado de `coe_mdt/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

## Exports

### `AccessLog(subject, limit)`

Registro de acessos para a corregedoria (somente resources autorizados).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `subject` | `any` |  |
| `limit` | `any` |  |

**Retorno**

- `any`

### `TabletCall(playerId, appId, action, payload)`

Ponto único de entrada: coe_tablet:call -> TabletCall(playerId, appId, action, payload).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |
| `action` | `any` |  |
| `payload` | `any` |  |

**Retorno**

- `any`

