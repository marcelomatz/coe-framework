# coe_factions — referência da API

> Gerado de `coe_factions/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

## Exports

### `CanCraft(characterId, recipeId)`

Export server `CanCraft` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `any` |  |
| `recipeId` | `any` |  |

**Retorno**

- `any`

### `CanCraftInFaction(factionId, characterId, recipeId)`

Export server `CanCraftInFaction` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `factionId` | `any` |  |
| `characterId` | `any` |  |
| `recipeId` | `any` |  |

**Retorno**

- `any`

### `Categories()`

Export server `Categories` (server/main.lua).

**Retorno**

- `any`

### `Delete(factionId)`

Export server `Delete` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `factionId` | `any` |  |

**Retorno**

- `any`

### `Get(factionId)`

Export server `Get` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `factionId` | `any` |  |

**Retorno**

- `any`

### `IsReady()`

Export server `IsReady` (server/main.lua).

**Retorno**

- `any`

### `List()`

Export server `List` (server/main.lua).

**Retorno**

- `any`

### `Members(factionId)`

Export server `Members` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `factionId` | `any` |  |

**Retorno**

- `any`

### `Memberships(characterId)`

Export server `Memberships` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `any` |  |

**Retorno**

- `any`

### `PauseMenuFaction(characterId)`

Facção no dossiê de identidade: a primeira facção ativa do personagem.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `any` |  |

**Retorno**

- `any`

### `RecipesFor(characterId)`

Export server `RecipesFor` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `any` |  |

**Retorno**

- `any`

### `RecipesForFaction(factionId, characterId)`

Receitas liberadas especificamente numa facção para o membro; nil se não for membro ou facção inativa.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `factionId` | `any` |  |
| `characterId` | `any` |  |

**Retorno**

- `any`

### `RemoveMember(factionId, characterId)`

Export server `RemoveMember` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `factionId` | `any` |  |
| `characterId` | `any` |  |

**Retorno**

- `any`

### `Save(raw)`

Export server `Save` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `raw` | `any` |  |

**Retorno**

- `any`

### `SetMember(factionId, characterId, grade)`

Export server `SetMember` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `factionId` | `any` |  |
| `characterId` | `any` |  |
| `grade` | `any` |  |

**Retorno**

- `any`

### `TabletCall(playerId, appId, action, payload, factionId)`

Export server `TabletCall` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |
| `action` | `any` |  |
| `payload` | `any` |  |
| `factionId` | `any` |  |

**Retorno**

- `any`

### `TabletInstances(playerId)`

Export server `TabletInstances` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |

**Retorno**

- `any`

