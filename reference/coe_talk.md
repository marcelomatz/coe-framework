# coe_talk — referência da API

> Gerado de `coe_talk/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Servidor ---------------------------------------------------------------------------------------------------

## Exports

### `SetPlayerRadio(source, frequency)`

Coloca o jogador numa frequência de rádio (ou tira, com `nil`/`0`). Só `Config.Access.Resources` (padrão `coe_mobile`) ou quem tem a ACE `coe.talk`. Não aplica a restrição por job: quem chama decide.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `source` | `integer` | Jogador |
| `frequency` | `number\|nil` |  |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode` — `forbidden`, `invalid_player`

### `GetPlayerRadio(source)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `source` | `integer` |  |

**Retorno**

- `number|nil` `frequency`

### `SetPlayerCall(source, callId)`

Coloca o jogador numa chamada de voz (ou tira, com `nil`). É o único jeito de entrar numa chamada: o client não escolhe a chamada. Mesmo controle de acesso de `SetPlayerRadio`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `source` | `integer` |  |
| `callId` | `string\|nil` | Até 64 caracteres `[A-Za-z0-9_:-]` |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode` — `forbidden`, `invalid_player`, `invalid_call`

### `GetPlayerCall(source)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `source` | `integer` |  |

**Retorno**

- `string|nil` `callId`

### `GetRadioMembers(frequency)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `frequency` | `number` |  |

**Retorno**

- `integer[]` `members`

### `GetCallMembers(callId)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `callId` | `string` |  |

**Retorno**

- `integer[]` `members`

### `GetVoiceRange()`

Modo de voz atual.

**Retorno**

- `number` `distance`
- `string` `label`
- `string` `id`

### `SetVoiceRange(modeOrDistance)`

Troca o modo de voz por id (`whisper`, `normal`, `shout`) ou distância.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `modeOrDistance` | `string\|number` |  |

**Retorno**

- `boolean` `ok`

### `GetRadioChannel()`

**Retorno**

- `number|nil` `frequency`

### `SetRadioChannel(frequency)`

Pede ao servidor para entrar numa frequência (canais restritos exigem o job; ver `Config.Radio.restricted`).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `frequency` | `number\|nil` | `nil`/`0` sai do rádio |

**Retorno**

- `boolean` `sent`

### `GetCallChannel()`

**Retorno**

- `string|nil` `callId`

### `SetCallChannel(callId)`

Só sai da chamada atual (`nil`). Entrar numa chamada é decisão do servidor (`SetPlayerCall`).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `callId` | `nil` |  |

**Retorno**

- `boolean` `ok` — `false` quando recebe um id

### `IsTalking()`

**Retorno**

- `boolean` `talking`

### `IsRadioTransmitting()`

**Retorno**

- `boolean` `transmitting`

### `SetVoiceVolume(volume)`

Volume da voz recebida (0-100).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `volume` | `number` |  |

**Retorno**

- `boolean` `ok`

