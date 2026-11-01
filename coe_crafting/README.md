# coe_crafting

Central de craft. Concentra receitas, regras e execução; mecânica, comércio e craft ilegal só dizem **onde** fica a bancada e **quem** tem acesso.

## Conceitos

- **Receita**: `id`, `label`, `category`, `timeMs`, `inputs[]`, `outputs[]` (mais de uma saída é permitido). Determinística: sem chance de falha nem bônus.
- **Bancada (tipo)**: aceita categorias de receita e define a origem dos insumos (`player`, `stash` ou `both`) e o destino da saída (`player` ou `stash`).
- **Contexto**: `{ inventoryId, stashId, access = function(playerId) -> bool[, motivo] }`, informado por quem abre a bancada.

## Fluxo

`Begin` valida acesso, receita e materiais e reserva o jogador (uma bancada por vez). `Complete` confere de novo, consome os insumos (jogador primeiro, depois baú, em `both`) e entrega as saídas. Se algo falhar, tudo é devolvido. Audita `craft_completed`.

## Exports (server)

Retornam um valor só: o resultado ou `{ error = codigo }`. Restritos a `AllowedResources`.

- `RegisterBench(type, def)`, `RegisterRecipe(recipe)`, `RemoveRecipe(id)`
- `Open(playerId, benchType, opts)`: abre o painel único. `opts = { label, stashId, recipes = { ids } | function(playerId) -> { ids }, position = { x, y, z, radius }, access = function(playerId, recipeId) -> bool[, motivo] }`. A posição, o acesso e a receita são conferidos de novo a cada produção (`Begin` e `Complete`).
- `Close(playerId)`
- `ListRecipes()`: catálogo `{ id, label, category }`, restrito ao `coe_admin` (usado pelo editor de facções).
- `List`, `Begin`, `Complete`, `Cancel`, `Busy`: usados pelo próprio painel; úteis para testes e fluxos sem interface.

O evento `coe_crafting:ready` é disparado ao iniciar; quem registra bancadas deve registrar de novo ao ouvi-lo.

## Interface

Painel NUI único (`html/`): lista receitas com o que o jogador tem de cada insumo, barra de progresso e animação definida por bancada (`animation = { dict, name }`). Eventos de cliente vêm só do servidor; os callbacks `craft`, `refresh` e `close` voltam ao servidor, que valida a sessão.

## Fora do escopo (v1)

Alerta policial, XP/níveis, falha ou bônus de craft.

## Bancada da DeepWeb (`coe_deepweb`)

O `coe_deepweb` registra a bancada `deepweb_rig` (categoria `hacking`, só dele) e a receita `hacking_onion_usb` (pen drive vazio → pen drive com navegador onion). Abre pelo app Onion de um desktop ou servidor instalado, com a posição da máquina e o acesso conferidos a cada produção. A receita aparece no catálogo do admin.

## Bancadas dos negócios (restaurante e lojinha)

As estações `crafts` de negócios com categoria em `CraftingConfig.BusinessBenches` (`restaurant`, `shop`, `other`) viram bancadas `business_<categoria>`.
O acesso vem do `coe_businesses:Access`: dono (se `ownerAccess`) ou funcionário cadastrado na equipe da oficina e de ponto (salvo `clockRequired = false`).
O servidor revalida acesso e distância a cada ação. Receitas padrão: `kitchen` (restaurante) e `retail` (lojinha), em `config.lua`. `other` usa a categoria `workshop`, sem receitas por padrão.
Os ingredientes novos ficam em `coe_inventory\data\coe_ingredients.lua`. A bancada usa o baú do negócio (estação `stashes`) mais próximo dela, aberto pela equipe no local (`coe_businesses`); sem baú cadastrado, os insumos saem do jogador.

## Bancadas de facção (`coe_factions`)

As estações `crafts` cadastradas numa facção ativa (aba **Grupos > Pontos** do `coe_admin`) viram bancadas do tipo `faction` (`CraftingConfig.FactionBench`, `source = 'both'`, `output = 'player'`).
- **Acesso e grau por receita:** só membros daquela facção veem e abrem a bancada (`not_member`). As receitas exibidas vêm de `exports.coe_factions:RecipesForFaction(factionId, characterId)` e cada produção revalida `exports.coe_factions:CanCraftInFaction(factionId, characterId, recipeId)` em `Begin` e `Complete` (`grade_too_low`).
- **Baús de facção:** as estações `stashes` da facção abrem no local com `E` para membros (`stash:faction:<facção>:<baú>`) e também abastecem a bancada mais próxima daquela facção.

## Bancadas clandestinas livres (craft ilegal)

Bancadas sem vínculo com negócio ou facção, cadastradas em **Negócios > Receitas e cardápios > Bancadas ilegais** (`CraftingConfig.IllegalBench`, tipo `illegal`, categoria `illegal`).
- **Acesso livre:** abertas a qualquer jogador com personagem ativo.
- **Consumo exclusivo do jogador:** `source = 'player'` e `output = 'player'` (não usam baú).
- **Receitas:** oferecem todas as receitas da categoria `illegal` (`illegal_lockpick`, `illegal_ziptie`, `illegal_armour` e receitas próprias criadas no painel) ou apenas o subconjunto marcado naquela bancada.

## Isolamento e regras de segurança

- **Dono do registro:** cada receita e bancada pertence ao resource que registrou (`GetInvokingResource`). Outro resource não substitui nem remove (`id_conflict`); só o `coe_admin` (overrides do painel) pode.
- **Categorias:** `CraftingConfig.CategoryOwners` define quem registra em cada categoria (`mechanic` só o `coe_mechanic`, `kitchen`/`retail`/`workshop`/`illegal` só o `coe_crafting`). Receita em categoria de outro dono é recusada (`category_forbidden`). Uma bancada só enxerga e só executa receitas das suas categorias.
- **Bancadas `business_*`, `faction` e `illegal`:** reservadas ao `coe_crafting` (`reserved_bench`). Os resources externos só registram bancadas próprias.
- **Menu por negócio:** ordem de prioridade: cardápio ajustado do negócio, tipo de cardápio escolhido, `CraftingConfig.BusinessRecipes = { [idDoNegocio] = { 'receita', ... } }` e, sem nada disso, toda receita das categorias da bancada. O filtro vale ao listar e ao produzir.
- **Acesso por negócio:** dono (`ownerAccess`) ou funcionário da equipe **daquele** negócio (`coe_businesses:Access`), de ponto. O ponto é por negócio e só existe um por jogador. O dono de um negócio não opera outro.
- **Revalidação:** o servidor confere acesso, distância, categoria do negócio ou grau na facção ao abrir, ao iniciar e ao concluir. Perder o acesso ou o grau mínimo durante o craft cancela sem consumir nada.
- **Baú e produto:** a bancada usa o baú do negócio (`stash:business:<negócio>:<baú>`) ou da facção (`stash:faction:<facção>:<baú>`) mais próximo. O craft consome só esse baú e o jogador que produz; o produto vai só para quem produziu.

## Receitas, cardápios e bancadas ilegais (painel admin)

Gravados na tabela `coe_crafting_catalog` (`server/catalog.lua`, `server/persistence.lua`). Editados em **Negócios > Receitas e cardápios** do `coe_admin` (exports `AdminCatalog`, `AdminSaveRecipe`, `AdminDeleteRecipe`, `AdminSaveMenu`, `AdminDeleteMenu`, `AdminSaveBench`, `AdminDeleteBench`, `AdminSetBusinessMenu`, só para o `coe_admin`).

- **Receitas próprias:** só nas categorias de `EditableCategories` (`kitchen`, `retail`, `workshop`, `illegal`). As receitas do `config.lua` aparecem como padrão (só leitura, `reserved_recipe`). Todo item precisa existir no `coe_inventory` (`unknown_item`). Limite `MaxCustomRecipes`.
- **Tipos de cardápio:** ex.: Pizzaria, Hamburgueria, Bar. Cada tipo pertence a uma categoria de negócio com bancada e lista receitas dessa bancada (até `MaxMenuRecipes`). Limite `MaxMenus`.
- **Bancadas ilegais:** pontos livres no mundo (`id`, `label`, `enabled`, `x`, `y`, `z`, `radius`, `recipes`), até `MaxIllegalBenches`.
- **Cardápio do negócio:** seção **Cardápio** do negócio: escolhe o tipo e, opcionalmente, ajusta a lista só daquele negócio. Se o negócio mudar de categoria, o cardápio salvo é ignorado.

## Motivos de bancada negada

O jogador recebe o motivo exato, e o servidor registra `craft_denied` com ele: `off_duty` (é da equipe, mas não bateu o ponto; a bancada aparece com "Bata o ponto para produzir"), `not_staff`, `not_member`, `grade_too_low`, `too_far`, `unavailable` (`coe_businesses`/`coe_factions` indisponível) e `forbidden`.


## Testes

`test\crafting_test.lua` (núcleo), `test\business_test.lua` (acesso e estações de negócio, facção e ilegais), `test\isolation_test.lua` (isolamento entre negócios, facções, graus, categorias e baús) e `test\catalog_test.lua` (receitas próprias, tipos, bancadas ilegais e cardápio por negócio).