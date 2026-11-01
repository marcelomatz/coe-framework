# coe_ems — referência da API

> Gerado de `coe_ems/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

## Exports

### `Records(medicSource, patientCharacterId, limit)`

Prontuário de um paciente (personagem): exige o cargo com ems.records em um negócio ems de ponto.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `medicSource` | `any` |  |
| `patientCharacterId` | `any` |  |
| `limit` | `any` |  |

**Retorno**

- `any`

### `Revive(medicSource, targetSource, detail)`

Export server `Revive` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `medicSource` | `any` |  |
| `targetSource` | `any` |  |
| `detail` | `any` |  |

**Retorno**

- `any`

### `SetState(source, state)`

coe_needs, coe_hud e coe_admin podem definir o estado (ex.: dano vindo de outro sistema).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `source` | `any` |  |
| `state` | `any` |  |

**Retorno**

- `any`

### `State(source)`

Export server `State` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `source` | `any` |  |

**Retorno**

- `any`

### `Treat(medicSource, targetSource, detail)`

Export server `Treat` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `medicSource` | `any` |  |
| `targetSource` | `any` |  |
| `detail` | `any` |  |

**Retorno**

- `any`

