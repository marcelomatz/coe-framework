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

### `EvaluateSignal(carrierId, coords, context)`

Avalia a qualidade de sinal, banda (5G/4G/3G/SAT/FIBRA/OFFLINE) e latência para uma operadora e coordenada.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `carrierId` | `string` |  |
| `coords` | `table\|nil` |  |
| `context` | `table\|nil` |  |

**Retorno**

- `table`

### `CanAccessBandFeature(band, feature)`

Verifica se a banda atual suporta a feature requisitada (text, voice, video, high_freq_market, remote_rig, cloud_sync).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `band` | `string` |  |
| `feature` | `string` |  |

**Retorno**

- `boolean`

### `SabotageTower(towerId, durationSec)`

Sabota fisicamente uma torre de celular (ERB) pelo tempo determinado.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `towerId` | `string` |  |
| `durationSec` | `number\|nil` |  |

**Retorno**

- `boolean,` `string|nil`

### `RepairTower(towerId)`

Repara imediatamente uma torre de celular (ERB) sabotada.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `towerId` | `string` |  |

**Retorno**

- `boolean`

### `ActivateFiber(spaceKey)`

Ativa um contrato de fibra óptica dedicada Wi-Fi 6 para um espaço (imóvel/empresa).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `spaceKey` | `string` |  |

**Retorno**

- `boolean`

### `HasActiveFiber(spaceKey)`

Verifica se o espaço possui fibra óptica dedicada ativa.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `spaceKey` | `string` |  |

**Retorno**

- `boolean`

### `SetVehicleOrbitlink(plate, active)`

Instala ou remove o kit veicular de antena satelital OrbitLink em uma placa.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `plate` | `string` |  |
| `active` | `boolean` |  |

**Retorno**

- `boolean`

### `AdminOverview()`

Retorna o panorama em memória das ERBs (3G/4G/5G), fibras ópticas e operadoras para o painel admin.

**Retorno**

- `table`

