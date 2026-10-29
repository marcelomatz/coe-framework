# coe_appearance — referência da API

> Gerado de `coe_appearance/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Todos os exports são client-side. A aparência é uma tabela no formato de `shared/schema.lua` (versão `Version()`).

## Exports

### `OpenCreator(options)`

Abre o criador de personagem. O resultado chega pelos eventos locais `coe_appearance:creatorSubmit` e `coe_appearance:creatorCancelled`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `options` | `CoeAppearanceCreatorOptions` |  |

**Retorno**

- `boolean` `opened` — `false` se já estiver aberto, sem opções ou durante a geração de miniaturas

### `CloseCreator()`

Fecha o criador e deixa a tela escura: quem chamou monta a próxima cena e faz o fade in.

### `CreatorError(message)`

Mostra um erro na tela do criador (ex.: falha ao salvar no servidor).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `message` | `string\|nil` |  |

### `IsCreatorOpen()`

**Retorno**

- `boolean` `open`

### `Apply(ped, appearance)`

Aplica a aparência num ped que já é do modelo certo (não troca o modelo).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `ped` | `integer` |  |
| `appearance` | `table` |  |

**Retorno**

- `boolean` `ok`

### `ApplyToPlayer(appearance)`

Troca o modelo do jogador local e aplica a aparência.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `appearance` | `table` |  |

**Retorno**

- `boolean` `ok`

### `CreatePed(appearance, x, y, z, heading, gender)`

Cria um ped local (não sincronizado) para cenas, com a aparência ou com a roupa padrão do gênero. Quem chamou apaga o ped.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `appearance` | `table\|nil` |  |
| `x` | `number` |  |
| `y` | `number` |  |
| `z` | `number` |  |
| `heading` | `number\|nil` |  |
| `gender` | `'male'\|'female'\|nil` | Usado quando `appearance` é nil |

**Retorno**

- `integer|nil` `ped`

### `Normalize(raw)`

Valida e normaliza uma aparência recebida (banco, outro resource). `nil` quando inválida.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `raw` | `any` |  |

**Retorno**

- `table|nil` `appearance`

### `Default(gender)`

Aparência inicial do gênero.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `gender` | `'male'\|'female'` |  |

**Retorno**

- `table` `appearance`

### `Version()`

Versão do formato da aparência (`AppearanceSchema.Version`).

**Retorno**

- `integer` `version`

## Tipos

```lua
---@class CoeAppearanceCreatorOptions
---@field mode 'create'|'appearance'|nil `create` (novo personagem, padrão) ou `appearance` (editar a existente)
---@field characterId string|integer|nil Personagem que está sendo criado/editado
---@field gender 'male'|'female'|nil Gênero inicial (padrão `male`)
---@field firstName string|nil
---@field lastName string|nil
---@field birthDate string|nil
```

