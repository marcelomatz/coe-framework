# coe_inventory

Resource responsável pelo domínio e aplicação de inventário, catálogo de itens, UI de inventário e integração de containers. Importa `coe_core`; o Core não importa o inventário.

## Organização e responsabilidades

- `domain/items.lua`: definições, validação e comportamento de itens e instâncias.
- `data/coe_base_items.lua` e `data/coe_catalog.lua`: base, registro e agrupamento de catálogo.
- `data/coe_weapons.lua`, `coe_ammo.lua`, `coe_attachments.lua`, `coe_food.lua`, `coe_consumables.lua`, `coe_containers.lua`, `coe_misc.lua`: definições declarativas por categoria.
- `data/coe_animations.lua` e `data/coe_weapon_profiles.lua`: perfis de apresentação e comportamento de armas.
- `application/`: serviço server-side dividido por responsabilidade; todos compartilham `Inventory.Service`, criado em `state.lua` e carregado na ordem do `fxmanifest.lua`.
  - `state.lua`: estado em memória (inventários, containers, rate limits), logging e validações básicas.
  - `storage.lua`: serialização, persistência e carga de inventários.
  - `world_containers.lua`: containers soltos no mundo (spawn, adoção, restauração, sincronização).
  - `opened_containers.lua`: containers abertos por jogador (validação, índices, snapshots).
  - `inventory_ops.lua`: operações de domínio (add/remove/use/swap/split/transfer) e exports públicos.
  - `player_inventory.lua`: inventário do personagem ativo.
  - `weapons.lua`: recarga de armas com munição do inventário e desconto dos disparos.
  - `action_guard.lua`: rate limit, limpeza por jogador e resposta padrão de ações.
  - `handlers_inventory.lua` e `handlers_containers.lua`: handlers de rede.
  - `lifecycle.lua`: `playerDropped`, inicialização da persistência e parada do resource.
- `adapters/persistence.lua`: adaptador MariaDB assíncrono, serialização por chave e schema local do inventário.
- `presentation/`: cliente FiveM, carregado na ordem do manifest sobre o namespace `Inventory.Client`:
  - `state.lua`: estado único (`C.state`), constantes (perfis de containers, mensagens de erro) e helpers de natives (modelos, animações, feedback).
  - `item_animation.lua`: animação + prop de item usado e arma equipada.
  - `container_props.lua`: props de containers portáteis (pegar, guardar, equipar maleta nativa, reconciliar com o inventário).
  - `container_placement.lua`: modo de mira e confirmação para soltar um container no mundo.
  - `world_targets.lua`: opções Abrir/Pegar (coetarget) e resultado das ações no mundo.
  - `weapon_ammo.lua`: tecla R da arma empunhada e envio da munição gasta.
  - `item_use.lua`: despacho de `inventory.useItem` (container, arma ou item genérico).
  - `inventory_ui.lua`: abrir/fechar/alternar a UI e jogadores próximos.
  - `nui_callbacks.lua`: callbacks NUI com validação de payload.
  - `server_events.lua`: eventos `inventory.*` recebidos do servidor.
  - `bootstrap.lua`: comandos, teclas, threads, exports e limpeza do ciclo de vida.
- `client/target_adapter.lua`: único ponto de integração com `coetarget`.
- `html/` e `data/images/`: apresentação NUI e imagens do catálogo.
- `lib/init.lua`: API de importação de `Inventory`.
- `config.lua`: único arquivo editado pelo administrador (ver [Configuração](#configuração)). `domain/config_schema.lua` aplica padrões e valida na carga.
- persistência: registros JSON no MariaDB são endereçados por `character:<character_id>` para inventários de personagem e por IDs próprios para containers. O ID ativo é resolvido pelo servidor via `coe_core`, nunca recebido do client.

O serviço de aplicação ainda registra handlers FiveM no mesmo módulo; extraí-los para adaptadores de entrada separados é uma próxima etapa. Nenhuma interface deve persistir diretamente a partir da NUI nem confiar em validações feitas apenas no client.

## Configuração

Tudo que o administrador ajusta está em `config.lua`, dividido em três seções. **Toda chave é opcional**: o que for omitido usa o padrão de `domain/config_schema.lua`.

| Seção | Conteúdo |
|---|---|
| `Config.Client` | `openKey`, `hotbarSlots` (1–9), `targetDistance`, `placementRange`, `placementPreviewAlpha` (0–255), `streamTimeoutMs`, `networkControlTimeoutMs` |
| `Config.Server` | `defaultSlots`, `maxSlots`, `giveDistance`, `worldInteractDistance`, `adoptTimeoutMs`, `rateLimits` (`requestMs`, `swapMs`, `actionMs`, `dropMs`, `syncMs`), `starterItems` |
| `Config.Containers` | `items[nomeDoItem] = { model, bone, position, rotation }`: modelo e pose de cada container. Campos omitidos herdam o padrão; um item novo exige só `model` |

Validação na carga (cliente e servidor): valor com tipo errado ou fora da faixa é ignorado, o padrão é usado e o console mostra `[coe_inventory] config: <motivo>`. Chaves desconhecidas (inclusive as antigas `OpenKey`, `GiveDistance`, `DefaultSlots`, `MaxSlots`, `StarterItems`) também são avisadas. `defaultSlots` nunca passa de `maxSlots`. Entradas inválidas de `starterItems` são descartadas.

O arquivo é carregado nos dois lados, então não coloque segredos nele. `giveDistance` fica em `Server`, mas o cliente a usa para listar jogadores próximos, mantendo lista e validação iguais. Slots e peso de cada container ficam no catálogo (`data/coe_containers.lua`).
## Inicialização e dependências

`coe_inventory` depende de `coe_core`, `coe_database`, `coe_logging`, `coe_notify` e `coetarget`. O Core não depende do inventário nem do target. Inicie logger e notify antes dos resources de gameplay, e o Core antes do inventário e do admin. Para acessar o catálogo/API em outro resource:

```lua
dependencies {
	'coe_core',
	'coe_inventory'
}
shared_script '@coe_core/lib/init.lua'
shared_script '@coe_inventory/lib/init.lua'
```

O inventário abre com `F2` por padrão (`config.lua`, `Config.Client.openKey`). Cada inventário de jogador recebe uma vez os itens definidos em `Config.Server.starterItems`.

## Usabilidade

Os slots 1–5 formam a hotbar e funcionam com a interface aberta ou fechada. As teclas são configuráveis pelos controles do FiveM. Com o botão direito, é possível usar itens, entregar uma quantidade a um jogador próximo, dividir pilhas ou abrir containers. A distância padrão de entrega é 3 m (`Config.Server.giveDistance`).

Até dois containers podem ficar abertos simultaneamente. É possível transferir itens entre eles, respeitando slots e peso máximo. Containers dentro de outros containers não são aceitos. Containers no mundo são efêmeros: podem ser abertos ou recolhidos pelo target, mas somem no restart (com o conteúdo) se não forem recolhidos. Cada maleta deixa só um marcador `worldref:*` no banco, limpo no boot; os limites ficam em `Config.Server.maxWorldContainers` e `maxWorldContainersPerPlayer`. Reiniciar apenas o `coe_inventory` também apaga as maletas do mundo.

Persistência: trocar/dividir slots é gravado em lote a cada `Config.Server.flushIntervalMs` (padrão 1500 ms; 0 = síncrono); o restante grava na hora. O flush também roda ao sair do jogo e ao parar o resource. `exports.coe_inventory:GetPersistenceStats()` expõe métricas.

Cache e limpeza: inventários ociosos são despejados do cache após `Config.Server.cacheTtlMs` (padrão 600000; 0 = nunca) e recarregados do banco quando necessário. `coe_gc_containers` no console do servidor lista registros `container:*` órfãos; `coe_gc_containers apply` os remove. Teste de carga: `node coe_inventory/tools/loadtest/inventory_load.js` (ver cabeçalho do script).

## Catálogo e itens

As definições são registradas antes do uso via `Inventory.Items.Register` e cada slot mantém uma instância com `count`, `slot` e metadata. Metadata diferente impede empilhamento.

O catálogo está dividido em `data/coe_weapons.lua`, `coe_ammo.lua`, `coe_attachments.lua`, `coe_food.lua`, `coe_consumables.lua`, `coe_containers.lua` e `coe_misc.lua`. Os perfis de armas e animações ficam em `coe_weapon_profiles.lua` e `coe_animations.lua`. Os itens de acessório (coe_attachments.lua) continuam existindo como itens comuns, mas não há lógica de compatibilidade nem de equipar em armas: isso ficará num script próprio de armas e munições.

### Munição e recarga

`metadata.ammo` da arma é a munição carregada nela; arma nova vem descarregada. Ao sacar, o ped recebe só esse carregado, sem reserva. Com a arma de fogo empunhada, **R** pede ao servidor (`inventory.reloadWeapon`) para completar o pente com a munição do calibre da arma (`weapon.ammoType` em `coe_weapon_profiles.lua`, ex.: `ammo-9` para pistolas 9 mm). O servidor consome os itens de munição e grava o novo carregado numa única escrita (falha desfaz tudo). Os disparos são reportados (`inventory.weaponAmmo`) e o servidor só aceita diminuir o carregado. Arremessáveis não usam recarga.

Para registrar um item server-side:

```lua
local registered, itemOrError = exports.coe_inventory:RegisterItem('carta_rara', {
	label = 'Carta rara',
	weight = 5,
	stack = false,
	maxStack = 1
})

if not registered then
	print(('Falha ao registrar item: %s'):format(itemOrError))
end
```

Para criar um inventário e adicionar itens:

```lua
local inventoryId, inventory = exports.coe_inventory:GetPlayerInventory(targetSource)
if inventoryId then
	local success, result = exports.coe_inventory:AddItem(
		inventoryId,
		'water',
		1,
		{ source = 'spring', quality = 85 }
	)
end
```

`GetPlayerInventory(source)` só retorna inventário se o jogador tiver um personagem ativo e inicializa os itens iniciais uma única vez por personagem. Use o `source` server-side, nunca um ID fornecido pelo client.

`RegisterItem` aceita `label`, `weight` em gramas, `stack`, `maxStack`, `close`, `image`, `usable`, `consume`, `animation` e metadata padrão. `Inventory.Items.Create` constrói instâncias. O peso máximo é aplicado a containers; o inventário comum de jogador ainda não tem limite total configurado.

Itens com `consume` removem essa quantidade quando usados. O servidor valida a existência e usabilidade do item antes de notificar o client; efeitos específicos de gameplay devem ser implementados como handlers server-authoritative, não apenas em NUI/client.

## API server-side

Os exports pertencem ao resource `coe_inventory`:

- `CreateInventory(id, slotCount?, maxWeight?)`, `DeleteInventory(id)`.
- `GetPlayerInventory(source)` resolve e inicializa o inventário do personagem ativo.
- `GetInventory(id)`, `GetContainerInventory(playerInventoryId, slot)`, `GetSlot(id, slot)`.
- `RegisterItem(name, definition)`, `Items(name?)`.
- `AddItem(id, name, count, metadata?, slot?)`, `RemoveItem(id, slot, count)`.
- `SwapSlots(id, fromSlot, toSlot)`, `SplitItem(id, slot, count)`.
- `UseItem(id, slot)`, `GetItem(id, name, metadata?, strict?)`, `GetItemCount(id, name, metadata?, strict?)`.
- `GetInventoryObject()` fornece a API de domínio compartilhada no contexto Lua corrente.
- `OpenStash(source, stashId, { label, slots, maxWeight?, position, radius })` abre um baú persistente fixo (id `stash:...`) como contêiner do jogador; fecha sozinho ao se afastar de `position` além de `radius` (máx. 10). Quem chama valida o direito de acesso.
- `RemoveItemByName(id, name, count)` remove de vários slots (tudo ou nada: `insufficient_items`).
- `SetItemMetadata(id, slot, patch)` mescla `patch` na metadata do item do slot, mantendo as demais chaves (ex.: o `coe_phone` grava o `serial` do celular). Gravação síncrona; falha volta ao estado anterior.

O item `sim_card` (chip de celular) carrega `metadata.iccid`; usar coloca o chip no celular em uso (`coe_phone`).

O item `fuel_can` (galão, `data/coe_shop_items.lua`) carrega `metadata.fuel` e `metadata.liters`; usar não consome o item: o `coe_fuel` despeja no veículo mais perto e baixa os litros.

Leituras retornam snapshots, não referências mutáveis. Operações retornam `false` ou `nil` e uma chave de erro como segundo valor em caso de falha. Metadata em string é normalizada para `{ type = value }`; `GetItemCount` compara metadata exatamente por padrão, e `strict = false` permite filtrar pelas propriedades fornecidas.

## Persistência e limitações do MVP

O MVP cria a tabela `coe_inventory_records` no MariaDB por migration versionada (`adapters/migrations.lua`, controle em `coe_inventory_schema_migrations`) e persiste cada inventário como um snapshot JSON sob sua chave estável. A decisão é intencional para a etapa inicial: objetos, slots e metadata evoluem sem espalhar SQL pela regra de inventário. Transferências entre dois inventários usam uma transação MariaDB única. Os dados KVP anteriores não são importados e não fazem parte do suporte do MVP.

Os writes aguardam a confirmação do provider antes de concluir a operação e serializam acesso concorrente por chave. Falhas de inicialização e persistência são registradas em formato estruturado pelo `coe_logging`; falhas em ações enviadas pela interface podem também gerar uma notificação genérica, sem expor códigos internos ao jogador. O schema inicial é criado idempotentemente; uma estratégia de migrations versionadas para futuras mudanças, controle de peso do inventário do jogador e testes de integração contra MariaDB real permanecem pendentes.

## Testes

Execute `lua test\inventory_service_test.lua` e `lua test\persistence_test.lua` a partir da pasta do resource. Os harnesses usam um provider MariaDB dublê e cobrem identidade por personagem, bloqueio sem personagem ativo, itens iniciais idempotentes, isolamento entre personagens, pilhas, metadata, falhas de persistência e transações. A integração de interação é encapsulada por `client/target_adapter.lua`; UI, animações/natives, containers em rede e renderização NUI ainda exigem validação no FXServer Enhanced. O teste contra MariaDB real também está pendente; veja [TEST_COVERAGE.md](../TEST_COVERAGE.md).

## Maletas: animações e câmera

- Pegar do chão (`container_pickup`), equipar pelo inventário (`container_equip`) e guardar (`container_stow`) têm animações próprias em `data/coe_animations.lua`, separadas do saque de arma. O prop só aparece/some no ponto da animação (`equipAt`).
- Ao **Abrir** uma maleta do mundo pelo target, `presentation/container_camera.lua` só enquadra a maleta com uma câmera enquanto o inventário está aberto. Não mexe no ped nem na entidade (compartilhada com outros jogadores) e se desfaz ao fechar o inventário ou se a maleta sumir. Cinemáticas ficarão numa lib à parte.
- Alcance: `Client.targetDistance` (3.0) não deve passar de `Server.worldInteractDistance` (3.0), e `Colocar aqui` nunca coloca além dele. Fora do alcance o target mostra `Maleta: aproxime-se para usar`. Para diagnosticar, mire na maleta e rode `/targetdebug`.

## Referência da API

[Exports, parâmetros e códigos de erro](../reference/coe_inventory.md), gerado de [`types.lua`](types.lua).
