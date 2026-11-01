# coe_telecom — referência da API

> Gerado de `coe_telecom/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

## Exports

### `Authorize(number, kind, holder)`

O telefone pergunta antes de ligar ou mandar mensagem pela linha `number` (chip do aparelho). holder: titular do chip (nil = anônimo). Retorna { ok, maxSeconds } ou { ok = false, error }.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `number` | `any` |  |
| `kind` | `any` |  |
| `holder` | `any` |  |

**Retorno**

- `any`

### `Charge(number, kind, seconds, peer, holder)`

Uso concluído (ligação encerrada ou mensagem enviada). seconds só vale para voz e vídeo.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `number` | `any` |  |
| `kind` | `any` |  |
| `seconds` | `any` |  |
| `peer` | `any` |  |
| `holder` | `any` |  |

**Retorno**

- `any`

### `LineOf(number)`

Resumo da linha de um número para outros resources.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `number` | `any` |  |

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

