# coe_factions

Facções ilegais (gangues, máfias, guetos, desmanches e outras): cadastro, graus, membros e crafts liberados. Empregos não passam por aqui: eles pertencem aos negócios (`coe_businesses`). Os grupos de emprego legados (`police`, `ambulance`, `mechanic`) continuam no `coe_core` e não têm interface.

## Modelo

- `coe_faction_registry(faction_id, config JSON)`: nome, categoria, ativa/inativa, graus (0 a 9, com nome), crafts liberados (`recipe` + `minGrade`) e estações físicas (`stations = { crafts = {...}, stashes = {...} }`).
- `coe_faction_members(faction_id, character_id, grade)`: vínculo por personagem, inclusive offline. Um personagem pode estar em mais de uma facção.
- Migrações próprias em `coe_factions_schema_migrations`. Tudo é criado e editado pelo painel admin (aba Grupos).

## Regras

- Uma receita liberada vale para membros de uma facção **ativa** com grau maior ou igual ao grau mínimo da receita.
- Facção inativa não libera crafts nem expõe bancadas/baús no mundo, mas mantém os membros.
- Não é possível remover um grau em uso por algum membro (`grade_in_use`).
- Remover a facção apaga também os vínculos dos membros.
- Limites em `config.lua`: 10 graus, 64 crafts, 8 estações por tipo (`crafts` e `stashes`), 200 membros por facção, 200 facções.

## API (server exports)

Retornos são um valor único ou `{ error = codigo }`.

| Export | Quem pode chamar | Descrição |
|---|---|---|
| `IsReady()` | qualquer | Serviço carregado. |
| `Categories()` | qualquer | Categorias disponíveis. |
| `List()`, `Get(id)` | `coe_admin`, `coe_crafting`, `coe_doors` | Leitura das facções e de suas estações. |
| `Save(raw)`, `Delete(id)` | `coe_admin` | Gestão das facções. |
| `Members(id)`, `SetMember(id, characterId, grade)`, `RemoveMember(id, characterId)` | `coe_admin` | Gestão de membros. |
| `Memberships(characterId)` | `coe_admin`, `coe_crafting`, `coe_doors` | Facções e grau do personagem. |
| `PauseMenuFaction(characterId)` | `coe_pausemenu` | Primeira facção ativa `{ label, grade }` para o dossiê; registrada com `coe_pausemenu:RegisterFactionProvider`. |
| `RecipesFor(characterId)` | `coe_admin`, `coe_crafting` | Receitas liberadas em todas as facções do personagem: `{ recipe, factionId, grade }`. |
| `RecipesForFaction(factionId, characterId)` | `coe_admin`, `coe_crafting` | IDs de receitas liberadas para o personagem naquela facção específica. |
| `CanCraft(characterId, recipeId)` | `coe_admin`, `coe_crafting` | Se alguma facção do personagem libera a receita. |
| `CanCraftInFaction(factionId, characterId, recipeId)` | `coe_admin`, `coe_crafting` | Se o personagem é membro da facção ativa e tem o grau mínimo da receita nela. |

Evento: `coe_factions:changed` (qualquer alteração) e `coe_factions:ready`.

## Uso no craft

As estações `crafts` e `stashes` da facção são operadas pelo `coe_crafting`. Uma bancada de facção usa `exports.coe_factions:RecipesForFaction(factionId, characterId)` para montar a lista de receitas permitidas ao membro e `CanCraftInFaction(factionId, characterId, recipeId)` para revalidar vínculo e grau mínimo em `Begin` e `Complete`, consumindo insumos do jogador e do baú mais próximo da facção (`stash:faction:<facção>:<baú>`).

## Segurança

- Escrita só pelo `coe_admin` (validação por `GetInvokingResource`); o painel exige a permissão `coe_admin.groups.manage` e audita cada alteração.
- Entradas validadas em `server/rules.lua` (puro e testado): IDs `[a-z0-9_]`, textos sem controle ou `<>`, graus e crafts consistentes.
- Sem alerta para a polícia por enquanto.

## COE OS

`TabletResources` (`coe_tablet`) pode chamar `TabletInstances(playerId)` (facções ativas do personagem) e `TabletCall(playerId, 'faction', 'overview', _, factionId)`: um app por facção, com cargo, membros e produção liberada para o cargo. Só leitura; o vínculo é revalidado a cada chamada.

## Arquivos

- `config.lua`: categorias, limites e quem pode ler/escrever.
- `server/rules.lua`: validação e regras de acesso (puro).
- `server/tablet.lua`: lógica do app de facção no COE OS (`TabletInstances` e `TabletCall`).
- `server/persistence.lua`, `server/migrations.lua`: banco.
- `server/main.lua`: cache das facções e exports.
- `test/rules_test.lua`, `test/tablet_test.lua`: testes.
