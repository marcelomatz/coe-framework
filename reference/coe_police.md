# coe_police — referência da API

> Gerado de `coe_police/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

## Exports

### `Arrest(officerSource, targetSource, minutes, charge)`

Export server `Arrest` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `officerSource` | `any` |  |
| `targetSource` | `any` |  |
| `minutes` | `any` |  |
| `charge` | `any` |  |

**Retorno**

- `any`

### `Cuff(officerSource, targetSource)`

Export server `Cuff` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `officerSource` | `any` |  |
| `targetSource` | `any` |  |

**Retorno**

- `any`

### `Escort(officerSource, targetSource)`

Export server `Escort` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `officerSource` | `any` |  |
| `targetSource` | `any` |  |

**Retorno**

- `any`

### `Fine(officerSource, targetSource, amount, charge)`

Export server `Fine` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `officerSource` | `any` |  |
| `targetSource` | `any` |  |
| `amount` | `any` |  |
| `charge` | `any` |  |

**Retorno**

- `any`

### `IsCuffed(source)`

Export server `IsCuffed` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `source` | `any` |  |

**Retorno**

- `any`

### `IsEscorted(source)`

Export server `IsEscorted` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `source` | `any` |  |

**Retorno**

- `any`

### `IsJailed(source)`

Export server `IsJailed` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `source` | `any` |  |

**Retorno**

- `any`

### `Records(officerSource, subjectCharacterId, limit)`

Ficha criminal de um personagem: exige police.records em um negócio police de ponto.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `officerSource` | `any` |  |
| `subjectCharacterId` | `any` |  |
| `limit` | `any` |  |

**Retorno**

- `any`

### `Search(officerSource, targetSource)`

Export server `Search` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `officerSource` | `any` |  |
| `targetSource` | `any` |  |

**Retorno**

- `any`

### `Seize(officerSource, targetSource, slot, count)`

Export server `Seize` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `officerSource` | `any` |  |
| `targetSource` | `any` |  |
| `slot` | `any` |  |
| `count` | `any` |  |

**Retorno**

- `any`

### `Uncuff(officerSource, targetSource)`

Export server `Uncuff` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `officerSource` | `any` |  |
| `targetSource` | `any` |  |

**Retorno**

- `any`

