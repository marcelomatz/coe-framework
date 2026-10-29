# coe_businesses — referência da API

> Gerado de `coe_businesses/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Exports server-only. Multi-retorno se perde entre resources: erros voltam como { error = codigo }.
ACEs (padrões em config.lua): coe.businesses.write (Save/Seed/Delete/ClockIn), coe.businesses.clock (Clock/ClockOut),
coe.businesses.tablet (Tablet*), coe.businesses.permissions (RegisterPermissions), coe.businesses.payroll
(Salary/Payroll), coe.businesses.admin (DutySummary), coe.businesses.extend (RegisterTab/RegisterProvider).
Registro -----------------------------------------------------------------------------------------------------

## Exports

### `IsReady()`

**Retorno**

- `boolean` `ready`

### `Categories()`

Categorias de negócio de `BusinessesConfig.Categories`.

**Retorno**

- `table` `categories`

### `RuleSchema()`

Esquema das regras configuráveis por negócio (`BusinessesConfig.Rules`).

**Retorno**

- `table` `schema`

### `List(category)`

Negócios cadastrados (opcionalmente de uma categoria). Vazio antes do `IsReady`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `category` | `string\|nil` |  |

**Retorno**

- `table[]` `businesses`

### `Get(id)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `string` |  |

**Retorno**

- `table|nil` `business`

### `Save(raw, by)`

Cria ou atualiza um negócio (área, pontos, dono, equipe, cargos). ACE `coe.businesses.write`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `raw` | `table` |  |
| `by` | `string\|integer\|nil` | Autor (auditoria) |

**Retorno**

- `table|CoeBusinessesError` `business`

### `Seed(raw)`

Cria o negócio só se ainda não existir (seed de pacotes, ex.: lojas do coe_shops). ACE `coe.businesses.write`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `raw` | `table` |  |

**Retorno**

- `table|CoeBusinessesError` `business`

### `Delete(id, by)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `string` |  |
| `by` | `string\|integer\|nil` |  |

**Retorno**

- `true|CoeBusinessesError` `result`

### `ClockIn(source, characterId, businessId, at, atStation)`

Marca o jogador de ponto. ACE `coe.businesses.write`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `source` | `integer` |  |
| `characterId` | `string\|integer` |  |
| `businessId` | `string` |  |
| `at` | `vector3\|table\|nil` | Posição (conferida contra a área do negócio) |
| `atStation` | `boolean\|nil` | Ponto batido numa estação |

**Retorno**

- `true|CoeBusinessesError` `result` — `unknown_business`, `already_on_duty`, `on_duty_elsewhere`, `outside_area`

### `ClockOut(source, reason)`

Encerra o ponto do jogador. ACE `coe.businesses.write` ou `coe.businesses.clock`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `source` | `integer` |  |
| `reason` | `string\|nil` |  |

**Retorno**

- `true|CoeBusinessesError` `result` — `not_on_duty`

### `Clock(source, businessId, stationId)`

Fluxo completo de bater/encerrar ponto numa estação (validações, notificação, auditoria). ACE `coe.businesses.clock`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `source` | `integer` |  |
| `businessId` | `string` |  |
| `stationId` | `string` |  |

**Retorno**

- `{` `ok:` — true }|CoeBusinessesError result

### `IsOnDuty(businessId, characterId)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |
| `characterId` | `string\|integer` |  |

**Retorno**

- `boolean` `onDuty`

### `DutySummary()`

Contagem de quem está de ponto. ACE `coe.businesses.admin`.

**Retorno**

- `{` `total:` — integer, byBusiness: table<string, integer> } summary

### `CurrentDuty(source)`

Negócio em que o jogador está de ponto agora.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `source` | `integer` |  |

**Retorno**

- `string|nil` `businessId`

### `Access(businessId, characterId)`

Quem é o quê no negócio. Nada vaza entre negócios.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |
| `characterId` | `string\|integer` |  |

**Retorno**

- `CoeBusinessAccess` `access`

### `Partners(businessId)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |

**Retorno**

- `{` `characterId:` — string|integer, name: string }[] partners

### `Debtors(businessId)`

Quem responde pelas dívidas: o dono primeiro, depois os sócios. Vazio sem dono.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |

**Retorno**

- `(string|integer)[]` `characterIds`

### `Permissions()`

Permissões de cargo conhecidas (`nome = rótulo`), incluindo as registradas por pacotes.

**Retorno**

- `table<string,` `string>` — permissions

### `RegisterPermissions(list)`

Registra permissões de cargo de um pacote. O prefixo é o nome do resource sem `coe_` (ex.: `police.arrest`). ACE `coe.businesses.permissions`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `list` | `{` | name: string, label: string }[] Até 64 |

**Retorno**

- `true|CoeBusinessesError` `result` — `invalid_permissions`

### `Grades(businessId)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |

**Retorno**

- `table[]` `grades` — Nome, nível, salário e permissões de cada cargo

### `GradeOf(businessId, characterId)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |
| `characterId` | `string\|integer` |  |

**Retorno**

- `table|nil` `grade` — `nil` se não é da equipe ou o negócio não tem cargos

### `Can(businessId, characterId, permission, remoteOnly)`

O personagem pode exercer a permissão? O dono tem todas; a equipe, as do cargo (de ponto, salvo acesso remoto).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |
| `characterId` | `string\|integer` |  |
| `permission` | `string` | Ex.: `business.funds` |
| `remoteOnly` | `boolean\|nil` | Exige acesso sem ponto batido |

**Retorno**

- `boolean` `allowed`

### `Salary(businessId, characterId)`

Salário do cargo do personagem. ACE `coe.businesses.payroll` (sem ela, 0).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |
| `characterId` | `string\|integer` |  |

**Retorno**

- `integer` `salary`

### `Payroll(businessId)`

Folha do negócio. ACE `coe.businesses.payroll` (sem ela, lista vazia).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |

**Retorno**

- `{` `characterId:` — string|integer, name: string, grade: string, salary: integer }[] payroll

### `RegisterTab(def)`

Registra uma aba no app do negócio. ACE `coe.businesses.extend`. O registro some quando o resource para.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `def` | `table` |  |

**Retorno**

- `true|CoeBusinessesError` `result`

### `RegisterProvider(kind, def)`

Provedor de dados das abas Frota (`fleet`: { list, setStaff? }) e Propriedades (`properties`: { list }). ACE `coe.businesses.extend`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `kind` | `'fleet'\|'properties'` |  |
| `def` | `table` | Nomes dos exports do seu resource |

**Retorno**

- `true|CoeBusinessesError` `result`

### `TabletInstances(playerId)`

Apps de negócio do jogador no tablet (um por negócio de que é dono ou da equipe). ACE `coe.businesses.tablet`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |

**Retorno**

- `table[]` `instances`

### `TabletCall(playerId, appId, action, payload, instance)`

Ação do app `business` no tablet. `instance` é o negócio do app (nunca vem do payload). ACE `coe.businesses.tablet`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `'business'` |  |
| `action` | `string` |  |
| `payload` | `table\|nil` |  |
| `instance` | `string` |  |

**Retorno**

- `table` `result` — `{ ok = false, error = codigo }` em falha

## Tipos

```lua
---@class CoeBusinessesError
---@field error string `forbidden`, `not_ready`, `invalid_*`, `database_error`, ...

---@class CoeBusinessAccess
---@field owner boolean
---@field staff boolean
---@field partner boolean
---@field canClock boolean
---@field canWork boolean
```

