# coe_admin

Resource administrativo que consome o Core compartilhado e os exports de `coe_inventory`. O painel tem visão geral, entrega de itens por player ID e gestão de cargos persistidos.

Substitui o painel básico da staff do framework (`coe_staff`): declara `coe_supervisor_replaces 'coe_staff'` e, com o `coe_admin` rodando, o `coe_supervisor` não inicia o básico. As ferramentas do básico vêm junto, em **Ferramentas da staff** (`tools/`): Pessoal (noclip, invisível, invencível, coordenadas, curar, reviver, marcador e teleporte; `/noclip`), Jogadores (ir até, trazer, congelar, curar, reviver, expulsar, item, dinheiro e grupos), Veículos (temporário, registrado, consertar, abastecer, limpar, desvirar e apagar), Mundo (hora, clima e aviso) e Negócios. Abrem pelo botão do painel, por `/staff` ou pelo F10 (quem só tem ferramentas). As ACEs do básico (`coe.staff.all`, `coe.staff.<módulo>`) continuam valendo, junto com `coe_admin.tools.all`, `coe_admin.tools.<módulo>` e `coe_admin.root`; admin do txAdmin libera tudo. Mapa completo em [`UPGRADES.md`](../UPGRADES.md).

## Instalação

Inicie `coe_logging`, `coe_notify`, `coe_database`, `coe_core` e `coe_inventory` antes do painel e atribua as ACE permissions no `server.cfg`:

```cfg
ensure coe_logging
ensure coe_notify
ensure coe_database
ensure coe_core
ensure coe_inventory
ensure coe_admin

add_ace group.admin coe_admin.open allow
add_ace group.admin coe_admin.items.give allow
add_ace group.admin coe_admin.staff.manage allow
add_ace group.admin coe_admin.groups.manage allow
add_ace group.admin coe_admin.resources.manage allow
add_ace group.admin coe_admin.theme.manage allow
add_ace group.admin coe_admin.businesses.manage allow
add_ace group.admin coe_admin.players.view allow
add_ace group.admin coe_admin.news.manage allow
add_ace group.admin coe_admin.root allow
# Banco (alto nível): só root ou esta ACE explícita
# add_ace group.admin coe_admin.banking.manage allow
add_principal identifier.license:SUA_LICENSE group.admin
```

Abra com `/coeadmin`. Os nomes ACE podem ser ajustados em `config.lua`. Evite conceder `coe_admin.staff.manage` a cargos que não devem administrar outros membros.

## Permissões

- `coe_admin.open`: abre a visão geral.
- `coe_admin.items.give`: habilita lista de jogadores e entrega de itens.
- `coe_admin.staff.manage`: habilita gestão de cargos dentro das próprias permissões.
- `coe_admin.theme.manage`: aba "Aparência" para escolher o tema de cores global (via `coe_ui`).
- `coe_admin.businesses.manage`: aba "Negócios" (via `coe_businesses`, opcional: sem ele a aba mostra aviso). Cadastra negócios por categoria (mecânicas, lojinhas, postos, restaurantes, outros): área (círculo ou polígono), baús, mesas de craft, showroom (mecânicas) e regras (`ownerAccess`, `priceMultiplier`, `clockRequired`, `clockOffsite`) e equipe. A marcação é feita no mundo: o painel some, ande até o local e use **E** (marca), **Enter** (conclui lista de vértices) e **Backspace** (cancela). O dono é definido no próprio painel do negócio, pelo ID do personagem (`/id` no jogo; o personagem pode estar offline). Com o `coe_crafting` iniciado, a aba **Receitas e cardápios** cria receitas próprias (ingredientes, resultado e tempo) e tipos de cardápio por categoria (ex.: Pizzaria, Hamburgueria, Bar); na seção **Cardápio** de cada negócio com bancada, escolhe-se o tipo e, se quiser, ajusta-se a lista daquele negócio.
  - Aba **Imóveis** (via `coe_housing`), seção **Interior**: catálogo de interiores nativos com filtro por categoria, busca e miniaturas. "Usar" atribui o interior ao imóvel (e o ponto interior); "Visitar e ajustar" leva o admin ao interior em mundo isolado, `E` marca o ponto e `Backspace` cancela. "Gerar miniaturas faltantes" visita cada interior sem miniatura, escolhe um ângulo e fotografa com `screenshot-basic` (precisa estar iniciado). "Ponto personalizado" mantém o interior marcado à mão (MLO de terceiros).
  - Aba **Imóveis**, guia **Imobiliária**: carteira de todos os imóveis cadastrados (miniatura do interior, tipo, ocupação, baú) com **Visitar** (mundo isolado, `E`/`Backspace` volta), **Editar** e **Contratos** (moradores ou negócio, diária, situação, quem está dentro; **Encerrar** com confirmação, exceto inicial e cedido). Subguia **Interiores**: catálogo com uso por imóvel, **Visitar** e **Criar imóvel** (cadastro novo já com o interior; falta marcar a porta).
  - Aba **Imóveis**, guia **Ilegais**: entradas escondidas para outro ambiente (sem mapa, sem aluguel, fora da imobiliária). Cadastro com porta, interior e baú como os demais, mais o dono e as pessoas com acesso (até 10); o dono também gerencia as pessoas no `/casa`.
  - Aba **Portas** (via `coe_doors`): cadastro de locais (casa, prédio, sede) com todas as suas portas do mapa/MLO (até 12: simples, dupla, portão de garagem, portão). Em cada porta, **Mirar na porta** esconde o painel; mire com a câmera, **E** marca cada folha (até 2), **Enter** conclui e **Backspace** cancela. Por porta: nome, tipo, padrão trancada, distância e trancamento automático. Para o local inteiro: acesso (negócio com ou sem ponto, facção com grau mínimo, personagens, itens e chave `key` com metadata `{"door":"<id do local>"}`, que abre todas as portas) e senha (só o hash fica salvo; remover ou trocar). Na aba **Local**, o dono (personagem) que gerencia as portas pelo `/casa`; em cada porta, acesso exclusivo (até 6 personagens) e senha própria.
  - Aba **Amzg** (via `coe_amzg`, opcional: sem ele a aba mostra aviso): catálogo da loja virtual do celular e do tablet, em grade com imagens e busca. Cada produto aponta para um item do inventário, escolhido num seletor igual ao da aba **Itens** (categorias, busca e imagens), com nome na vitrine, categoria, preço, ordem e opção de pausar.
- `coe_admin.players.view`: aba **Jogadores** (perfil somente leitura, também aberto ao clicar num jogador online). Mostra, por personagem online ou offline: identidade, conta e personagens irmãos, identificadores (mascarados), grupos, necessidades, inventário (via `coe_inventory:GetInventory('character:<id>')`, memória primeiro), veículos e chaves, garagem de cada veículo, imóveis, negócios (dono/funcionário) e economia (saldo e últimas 25 movimentações). Cada seção carrega isolada: se uma fonte estiver indisponível, só ela mostra aviso. Cada abertura é auditada (`admin_profile_viewed`) e limitada a uma consulta a cada 500 ms por admin. Os perfis são lidos direto do banco (consultas indexadas por `character_id`, sem cache) e o inventário vem do serviço, que reflete alterações ainda não gravadas.
- `coe_admin.resources.manage`: aba "Framework" para reiniciar resources do framework pela ordem de dependências (via `coe_supervisor`, que precisa de `ensure` no `server.cfg`). O painel pode fechar durante o reinício.
- Atalho: `Config.OpenKey` (padrão `F10`; `nil`/`false` desativa) abre/fecha o painel; sem permissão ACE nada acontece. O jogador pode remapear em Configurações > Teclas.
- `coe_admin.groups.manage`: aba "Grupos", que gerencia **facções ilegais** (gangues, máfias, guetos, desmanches) do resource `coe_factions`: cria/edita/remove facções com categoria, graus, crafts liberados (com grau mínimo por receita) e membros, inclusive offline (busca por nome do personagem). Empregos não ficam aqui: pertencem aos negócios. Cada alteração é auditada (`faction_saved`, `faction_deleted`, `faction_member_set`, `faction_member_removed`). Grupos de jogo nunca concedem acesso ao painel.
- `coe_admin.news.manage`: aba **Imprensa** (via `coe_news`, opcional: sem ele a aba mostra aviso). Uma aba por veículo (Weazel News, Rebel News) com as seções: **Visão geral** (matérias por status, leituras, anúncios, receita total e dos últimos 30 dias, caixa da sociedade, equipe online e de ponto, frota); **Negócio e recursos** (identificação, dono, sócios, área, ponto da redação, baús e regras; atalho para a aba Negócios quando o admin também tem `businesses.manage`); **Linha editorial** (slogan, texto, editorias e preço do anúncio por dia); **Equipe e cargos** (quem está online, cargos com salário e permissões `news.*`/`business.*`, contratar por busca e demitir; grava no `coe_businesses` sem passar pela permissão de negócios); **Equipamentos e frota** (estoque de câmera, microfone e boom no baú do veículo, abastecer e retirar, quem da equipe está com cada um; veículos das garagens de negócio do veículo, adicionar com sugestões e remover); **Publicidade** (pendentes, no ar e histórico; aprovar, recusar com estorno, tirar do ar sem estorno, com os dias restantes ou com o valor total, que sai do caixa do veículo); **Matérias** (filtro por status e busca, ler, tirar do ar, publicar de novo, apagar). Consultas e ações passam por `coe_admin:newsQuery`/`coe_admin:newsAction`; o `coe_news` revalida e audita (`news_*_admin`, `news_equipment_*`, `news_team_saved`). Entra no cargo Administrador por padrão.
- `coe_admin.deepweb.manage`: aba **DeepWeb** (via `coe_deepweb`, no cargo Administrador e no root). **Sites**: cria e edita sites `.onion` montados por blocos (título, texto, citação, aviso, lista, divisória, link e anúncio do Deep Market), com descrição e palavras-chave para o DuckDark e a opção de ficar fora do diretório e da busca; sites de sistema só aparecem. **Fornecedores**: anúncios NPC do Deep Market (item ou serviço, categoria, preço em moeda, estoque, pausa). **Pedidos**: disputas (devolver ou pagar o vendedor) e pedidos pagos sem entrega (cancelar e devolver). **Rabbit**: posts recentes, com remoção. **Contatos**: mensagens dos jogadores aos perfis da staff (ex.: `fantasma.onion`); a resposta aparece na página para o apelido, que recebe um aviso se estiver online, e a mensagem pode ser arquivada. Ações passam por `coe_admin:deepweb` e os exports `Admin*` do `coe_deepweb`, que validam e auditam.
- `coe_admin.root`: acesso total e permissão para atribuir qualquer cargo configurado.
- `coe_admin.banking.manage`: aba **Banco** (via `coe_banking`), restrita ao alto nível da staff: não entra em nenhum cargo de `Config.Roles` nem pode ser atribuída pelo painel; vem de `coe_admin.root` ou de ACE explícita. Edita os níveis do cartão de crédito (nome, pontuação mínima, limite, pontos por $ 100, anuidade, saque grátis; gravados no banco e aplicados na hora) e, por cliente (busca por nome ou ID, online ou offline): saldo e relacionamento, liberar crédito em qualquer nível com limite personalizado e trava contra rebaixamento, ajustar pontos, bloquear/desbloquear cartões e renovar a validade, conceder empréstimo (valor, juros totais sugeridos pela pontuação e parcelas semanais com débito automático; o atraso rende juros diários pela pontuação) e perdoar o saldo de um empréstimo. Sub-aba **Empresas**: contas empresariais (caixa de cada negócio) com saldo, cartões e empréstimos; por conta, extrato do período com quem fez cada operação, ajuste do caixa pela staff e cartões empresariais (limite diário, bloqueio, desbloqueio, validade). Sub-aba **Pedidos**: fila de pedidos de empréstimo empresarial com pontuação média dos devedores e juros sugeridos; aprovar (ajustando juros e parcelas) credita o caixa do negócio, recusar exige motivo. A aba **Negócios** preserva os sócios definidos pelo dono no tablet; trocar ou remover o dono desfaz a sociedade. Cada consulta e ação é auditada (`bank_admin_view`, `bank_admin_<ação>`).
- `coe_admin.crypto.manage`: aba **Cripto** (via `coe_crypto`, incluída no cargo Administrador, em `coe_admin.banking.manage` e em `coe_admin.root`). Exibe o panorama ao vivo (cotação atual, preço de compra/venda com spread, variação, fluxo líquido, reserva da corretora e total minerado), permite fixar imediatamente a cotação (`AdminSetPrice`), editar e salvar todas as configurações de `CryptoConfig` (identidade da moeda, limites de carteiras e proteção de importação, taxas e limites de transferência, parâmetros da corretora e formação de preço, emissão e teto de mineração; gravadas em `coe_crypto_settings` e aplicadas na hora) ou restaurar os padrões do `config.lua` (`AdminResetSettings`).

Os cargos definidos em `Config.Roles` são salvos por license na tabela MariaDB `coe_admin_staff`, criada pela migration versionada `server/migrations.lua` (controle em `coe_admin_schema_migrations`). Um gestor só pode atribuir cargos cujas permissões já possua; apenas `coe_admin.root` pode atribuir qualquer cargo configurado. O MVP começa com a tabela vazia e não importa dados KVP antigos. Ações continuam autorizadas novamente no servidor, independentemente do estado da NUI.

A entrega aceita metadata JSON opcional, valida o item pelo catálogo de `coe_inventory`, exige que o destinatário tenha personagem ativo e persiste via export `AddItem`. A API `GetPlayerInventory(source)` do inventário resolve a identidade pelo Core; o painel não monta IDs de inventário nem usa license como chave do personagem. As licenças mantidas pelo admin são usadas somente na identificação interna de staff. O servidor importa `Core` para validação compartilhada e todas as permissões são reavaliadas no servidor.

Ações de concessão de itens e gestão de cargos geram eventos de auditoria estruturados via `coe_logging`, sem persistir license, metadata do item ou nomes de jogadores no contexto do log. A negação de acesso ao painel usa `coe_notify` para feedback local.

## Mapa dos scripts

- `config.lua`: comando, permissões ACE e catálogo de roles.
- `server.lua`: autorização server-side, projeção de dados do painel, concessão de itens, gestão de roles, facções e auditoria.
- `server/persistence.lua`: schema e adapter MariaDB de staff.
- `server/directory.lua`: busca de personagens por nome ou ID (puro, testável).
- `server/profile.lua`: carga do perfil do jogador por seção (testável com banco dublê).
- `server/analytics.lua`: agregados da Visão geral e cache com atualização em segundo plano.
- `server/staff.lua`: regra pura de edição da equipe de um negócio (abas Negócios e Imprensa), testada em `test/staff_test.lua`.
- `client.lua`: comando, integração NUI, requests e resultados.
- `html/`: interface administrativa (`news.js`: aba Imprensa).
- `fxmanifest.lua`: dependências, ordem de scripts e assets.

## Busca de personagens e analytics

- Jogadores online mostram o nome do personagem ativo (`coe_core:GetActiveCharacter`, memória, sem banco); a conta aparece como texto secundário.
- Dono e funcionários são escolhidos por busca de nome ou ID. A busca é por prefixo (mínimo 2 caracteres, até 3 termos), usa os índices `first_name`/`last_name` (migration v7) e o índice único de `state_id`, com `LIMIT`. Online vêm da memória primeiro.
- Camadas de custo: cache TTL de 30 s (máx. 200 entradas, inclui resultados vazios), intervalo mínimo por admin no servidor e debounce de 300 ms no cliente.
- Uma view comum do MariaDB não é materializada e não reduz custo; por isso o desenho usa índices + cache em memória.
- Analytics: quase tudo é calculado de dados já em memória. Contagem de personagens e resumo da economia são consultas agregadas cacheadas por 60 s, atualizadas em segundo plano (nunca bloqueiam a abertura do painel).
- Exports consumidos: `coe_businesses:DutySummary`, `coe_economy:Summary` (somente `coe_admin`).

## Testes e lacunas

Execute os testes da pasta `test` a partir da pasta do resource (`lua test\staff_test.lua`, `persistence_test.lua`, `directory_test.lua`, `analytics_test.lua`, `profile_test.lua`). O teste cobre schema, leitura/escrita/remoção e propagação de falhas via provider dublê. Os handlers de autorização, NUI, ações administrativas e integração com inventário ainda precisam de testes dedicados; ações online devem também ser validadas no FXServer. Ver [TEST_COVERAGE.md](../TEST_COVERAGE.md).
