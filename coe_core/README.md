# coe_core

`coe_core` é a fundação compartilhada do framework. Ele não carrega inventário, interface administrativa ou sistema de target.

## Arquitetura

Os resources seguem uma arquitetura modular em camadas, inspirada em Clean/Hexagonal Architecture:

- **Domínio:** modelos e regras próprias do módulo, sem acesso direto a NUI ou persistência.
- **Aplicação:** coordena casos de uso, valida entradas e define os fluxos do resource.
- **Adaptadores:** conectam eventos, exports FiveM e providers externos.
- **Apresentação:** scripts client e interfaces NUI.

Os limites dos resources são módulos de implantação. As dependências devem apontar para dentro das capacidades necessárias, nunca de volta para o Core:

```text
coe_admin ───────> coe_inventory ───────> coe_core ───────> coe_database
coe_characters ─────────────────────────>   |
coe_spawn ──────────────────────────────>   +─────────────> spawnmanager
coetarget (integração de interação usada por coe_inventory)
coe_core, coe_inventory, coe_admin, coe_database ─────────> coe_logging
coe_core, coe_inventory, coe_admin, coe_characters ───────> coe_notify
```

O diagrama mostra só a fundação; hoje quase todos os resources `coe_*` dependem do `coe_core` (mapa completo em `ARCHITECTURE.md`, no coe-docs). O `coe_core` não depende de `coe_inventory` ou `coetarget`. A identidade e os personagens usam repositórios MariaDB próprios por meio do provider `coe_database`. `coe_inventory` e `coe_admin` persistem seus próprios dados MariaDB por adaptadores do respectivo resource; o Core não fornece persistência genérica nem mantém regras de negócio desses módulos. `coe_logging` e `coe_notify` são recursos de infraestrutura independentes: logging é server-side e não depende do banco; notificações são uma saída explícita de UX, nunca uma projeção automática dos logs.

## Inicialização

Inicie `coe_core` antes dos resources que o importam. Este workspace também inicia `coe_inventory` antes de `coe_admin`:

```cfg
ensure coe_logging
ensure coe_notify
ensure coe_database
ensure coe_core
ensure coe_spawn
ensure coe_characters
ensure coe_inventory
ensure coe_admin
ensure [coelho]
```

`basic-gamemode` não deve ser iniciado junto do fluxo de seleção: ele força respawn antes de existir personagem ativo. `coe_spawn` mantém o jogador sem controle até a seleção server-side e usa `spawnmanager` somente após o Core confirmar o personagem.

## Importar APIs

Um resource que precisa apenas da fundação deve declarar:

```lua
dependency 'coe_core'
shared_script '@coe_core/lib/init.lua'
```

Um resource que precisa também da API de inventário pode declarar:

```lua
dependencies {
	'coe_core',
	'coe_inventory'
}
shared_script '@coe_core/lib/init.lua'
shared_script '@coe_inventory/lib/init.lua'
```

Isso disponibiliza `Core` e, quando solicitado, `Inventory` no client e no servidor. APIs de inventário e catálogo pertencem a `coe_inventory`, não a `Core`.

### Migração da API anterior

Scripts que usavam `exports.coe_core` para operações de inventário devem passar a usar `exports.coe_inventory`. Scripts Lua que acessavam `Core.Items` devem importar `@coe_inventory/lib/init.lua` e usar `Inventory.Items`. A configuração antiga `ensure coe_core` deve ser complementada por `ensure coe_inventory`. O prefixo dos eventos do barramento permanece `coe_core:`.

## APIs do Core

- `Core.Functions`: `DeepCopy`, `IsInteger`, `IsValidName` e `Trim`.
- `Core.Classes`: registro, herança e verificação de classes.
- `Core.Events`: eventos locais e de rede com prefixo `coe_core:`.
- `Core.States`: acesso a GlobalState replicado. Não publique dados privados ou segredos.
Eventos de rede são entradas não confiáveis: valide `source`, argumentos, permissões e frequência no resource que implementa o caso de uso.

### Mapa dos scripts

- `core/shared/bootstrap.lua`, `functions.lua`, `identity.lua`, `classes.lua`, `events.lua`, `states.lua`: API compartilhada e contratos sem I/O persistente.
- `core/server/database.lua`: fachada validada para os exports assíncronos de `coe_database`.
- `core/server/migrations.lua`: aplicação ordenada e versionada das migrations do Core. Cada passo é uma string SQL ou uma função `function(done)` em Lua (usada no preenchimento de `state_id` da migração 2). Migrações atuais: 1 identidade (`coe_players`, `coe_player_identifiers`, `coe_characters`), 2 `state_id` (preenchimento em Lua), 3 `state_id` obrigatório, 4 `coe_player_settings` (slots), 5 perfil do personagem, 6 grupos (`coe_groups`, `coe_character_groups`) e 7 índices de busca por nome (`first_name`/`last_name` com `archived_at`), usados pela busca de jogadores do `coe_admin`. Faça backup do banco antes de subir uma versão com migração nova (#46).
- `stateId`: identidade pública do personagem (8 caracteres de `ABCDEFGHJKMNPQRSTUVWXYZ23456789`), gerada no servidor por `Core.Identity.GenerateStateId` e única no banco (`UNIQUE`; colisão repete a criação). Não é segredo. `characterId` continua sendo a chave interna.
- `lib/migrations.lua`: executor genérico (`CoeMigrations.Run`) usado pelos demais resources com persistência, cada um com a própria tabela `*_schema_migrations`.
- `core/server/player_repository.lua`: consultas e transações de player/personagem.
- `core/server/session_registry.lua`: estados transitórios por conexão e geração da sessão.
- `core/application/player_service.lua`: casos de uso de identidade, seleção, criação, arquivamento e ciclo de vida.
- `core/server/player_lifecycle.lua`: ciclo de conexão e adaptador dos requests/eventos FiveM, incluindo o handshake `player.clientReady` que reenvia a seleção de personagem a sessões em `character_selection`.
- `core/server/init.lua`: inicialização dependente do banco, estado `ready` e encerramento.
- `core/client/init.lua` e `lib/init.lua`: acesso ao objeto compartilhado nos contextos correspondentes. `lib/init.lua` redefine `Core.Events.On`, `OnNet`, `Remove` e `Core.Classes` (`Register`, `Get`, `Is`, com registro local) em cada resource consumidor: funções vindas de `exports` executam no `coe_core`, o que registraria handlers no resource errado, deixaria `source` incorreto e faria instâncias de classe perderem a metatable (métodos) ao voltar pelo export.

## Testes e lacunas

Execute na pasta do resource:

```powershell
lua test\identity_lifecycle_test.lua
lua test\player_service_test.lua
lua test\migrations_test.lua
lua test\group_definitions_test.lua
lua test\group_service_test.lua
lua test\migration_runner_test.lua
lua test\player_lifecycle_test.lua
lua test\lib_init_test.lua
lua test\player_repository_test.lua
lua test\character_profile_test.lua
```

Esses testes cobrem identidade, perfil do personagem, grupos, invariantes e operações do serviço, migrations e parte do registro/encerramento do lifecycle. O cenário de integração MariaDB (`coe_database/test/integration/core_scenario.lua`) aplica as migrations duas vezes e exercita o repositório. Repositório contra MariaDB, bridge real com Node 22, sessão completa em FXServer Enhanced e contrato de startup precisam de integração no runtime alvo. A matriz geral está em [TEST_COVERAGE.md](../TEST_COVERAGE.md).

## Observabilidade e feedback de gameplay

`coe_logging` fornece logs server-side estruturados com allowlist de resources, campos de contexto permitidos e nível mínimo configurável. Eventos de auditoria devem usar códigos estáveis e não incluir licenças, SQL, credenciais, metadata arbitrária ou mensagens de exceção.

`coe_notify` disponibiliza `exports.coe_notify:Show(type, message, duration?)` no client e `exports.coe_notify:Notify(source, type, message, duration?)` no servidor para resources autorizados. Notifique somente resultados relevantes ao jogador; mensagens técnicas ficam nos logs. Consulte os READMEs de [coe_logging](../coe_logging/README.md) e [coe_notify](../coe_notify/README.md).

## Documentação dos módulos

- [Plano de identidade e ciclo de vida](./IDENTITY_LIFECYCLE_PLAN.md): modelo de player/personagem, persistência MariaDB, segurança e fases de implementação.
- [coe_database](../coe_database/README.md): provider MariaDB próprio, exports assíncronos e configuração.
- [coe_logging](../coe_logging/README.md): contrato de logs, níveis e segurança de contexto.
- [coe_notify](../coe_notify/README.md): biblioteca NUI de notificações client/server.
- [coe_inventory](../coe_inventory/README.md): catálogo, itens, containers, exports e configuração.
- [coe_admin](../coe_admin/README.md): painel e modelo de permissões.
- [coe_characters](../coe_characters/README.md): seleção, criação e arquivamento de personagens.
- [coe_spawn](../coe_spawn/README.md): integração de spawn condicionada ao ciclo de vida.
- [Mapa de testes](../TEST_COVERAGE.md): cobertura automatizada e lacunas de integração.
- [Histórico de engenharia e auditoria](../HISTORY.md): ações documentadas, eventos auditáveis e limites de retenção.

## Slots de personagem

O limite efetivo é o valor do jogador em `coe_player_settings.character_slots` ou, se nulo, o convar `coe_max_characters` (padrão 5), sempre limitado por `coe_max_characters_hard` (padrão 10). Definir por jogador: `Core.Players.SetCharacterSlots` (uso interno; autorização fica no `coe_admin`).

## Perfil do personagem

`character.createRequest` aceita um `profile` opcional (`birthDate` `YYYY-MM-DD`, `gender`, `appearance` + `appearanceVersion`). O servidor valida tudo e rejeita chaves desconhecidas. Regras: convars `coe_character_min_age` (18), `coe_character_max_age` (90) e `coe_character_genders` (`male,female`). A aparência é opaca para o core (máx. 16 KB) e o formato é do `coe_appearance`. Ela volta na lista de personagens, no `character.selectResult` e no `player.characterLoaded` (`appearance`, `appearanceVersion`). Personagens criados antes do criador podem definir a aparência uma única vez na seleção: `character.appearanceRequest(requestId, characterId, appearance, version)` → `character.appearanceResult` (`Core.Players.SetInitialAppearance`; recusa com `appearance_locked` se já houver aparência). Trocar o visual depois é papel de barbearia e loja.

## Identificação pública (stateId)

- Statebag replicado `Player(src).state['coe:stateId']`: definido ao selecionar o personagem e limpo ao trocar de personagem ou parar o core. Somente o `stateId` é replicado; `characterId` fica no servidor. O client deve tratá-lo como somente leitura.
- Consulta entre jogadores online: exports `GetCharacterByStateId(stateId)` (snapshot do personagem) e `GetPlayerByStateId(stateId)` (`source`, `playerId` e personagem ativo); retornam `nil, 'invalid_state_id'` ou `nil, 'character_not_online'`. Também em `Core.Players`.
- `GetActiveCharacter(source)`: snapshot do personagem ativo de um jogador online, ou `nil` (valor único, seguro entre resources); usado pelos painéis para mostrar o nome do personagem.
- Comando `/id`: o jogador vê o próprio `stateId` em uma notificação (intervalo de 2 s entre usos). É o ID que o admin informa para definir o dono de um negócio.
- Evento local `player.characterCreated` (`source`, `playerId`, `generation`, `character`), emitido após a criação persistida.

## Grupos

Os grupos do core são a camada de ACE. **Empregos, cargos e salários vivem nos negócios** (`coe_businesses`) e **facções ilegais** no `coe_factions`; os grupos de emprego `police`, `mechanic` e `ambulance` do `config/groups.lua` são legados e não têm interface no admin.

- Definições em `config/groups.lua` (`CoeGroupsConfig`): tipos (`job`, `gang`), grupos com `type`, `label` e `grades` (0–255). Validadas na inicialização; configuração inválida impede o core de ficar pronto.
- `Core.Groups.Sync` faz upsert em `coe_groups` (nunca apaga; mudar o tipo de um grupo existente é recusado com group_type_changed). Graus não vão ao banco.
- `coe_character_groups`: um grupo ativo por tipo por personagem, garantido pelo banco.
- API (servidor, `Core.Groups`): `GetCharacterGroups(source)` → `{ [tipo] = { name, grade } }` do personagem ativo; `Has(source, nome, grauMinimo?)`; `Set(characterId, nome, grau, cb)` torna o grupo ativo no seu tipo e `Remove(characterId, nome, cb)` apaga o vínculo (idempotente). Os grupos são carregados ao selecionar o personagem; até a carga terminar, ou se ela falhar, `Has` é falso. Evento local `player.groupChanged` (`source`, `characterId`, `type`, `group`, `grade`, `previous`; `source` é nil se o personagem está offline). Autorização de quem chama `Set`/`Remove` é responsabilidade do chamador. Exports: `GetGroupDefinitions()`, `GetPlayerGroups(source)` (leitura) e `SetPlayerGroup`/`RemovePlayerGroup(source, nome, [grau,] cb)`, que só aceitam chamadas do `coe_admin` (`forbidden` caso contrário); a autorização do operador e o teto de grau ficam no painel. 
- ACE: o personagem carregado herda `coe.group.<grupo>` e `coe.group.<grupo>.<grau>`; cada grau herda os inferiores. A política fica no `server.cfg`, por exemplo `add_ace coe.group.police.2 coe.police.arrest allow` (sargento ou acima). Os principais saem ao trocar de personagem, sair do servidor, mudar o grupo ou parar o core. Só a conta com personagem ativo recebe principais; grupos nunca dão acesso ao painel admin.

## Referência da API

[Exports, parâmetros e códigos de erro](../reference/coe_core.md), gerado de [`types.lua`](types.lua).
