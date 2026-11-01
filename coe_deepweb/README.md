# coe_deepweb

A DeepWeb do servidor: uma rede anônima acessada por **níveis de equipamento**, com a cripto do `coe_crypto` como
moeda. Fase 1: aparelhos e níveis, identidade anônima, computadores e mineração. Fase 2: o **navegador onion** (barra
de endereço, abas, favoritos) e os sites da rede: **DuckDark** (buscador), **Rabbit** (fórum), **Deep Market**
(mercado com custódia em cripto e ponto de coleta) e **Fantasma** (perfil da staff do mundo hacking, fora do
diretório), além de sites montados por blocos no admin.

## Níveis de equipamento (`Tiers`)

| Nível | Aparelho | Como acessa |
|---|---|---|
| 1 | Celular | App **Onion**, depois de instalar o navegador com o pen drive `onion_usb` |
| 2 | Tablet | App **Onion** (mesmo pen drive) |
| 3 | Notebook (`laptop`) | Usar o item: abre o computador em qualquer lugar |
| 4 | Desktop (`desktop_pc`) | Instalado num imóvel; `/computador` perto dele |
| 5 | Servidor doméstico (`home_server`) | Instalado num imóvel; `/computador` perto dele |

Cada recurso da rede tem um nível mínimo (`Features`). A tela **Rede** do app mostra o que está liberado, bloqueado
(nível insuficiente) ou em breve:

| Recurso | Nível |
|---|---|
| Identidade anônima, DuckDark, Rabbit (ler, postar, comentar, votar), Deep Market (vitrine) | 1 |
| Deep Market: comprar | 2 |
| Deep Market: vender, Rabbit: criar comunidade | 3 |
| Mineração, gravar navegador | 4 |
| Hospedar site (em breve) | 5 |

Contratos e serviços pagos do sistema continuam como "em breve".

## De onde vêm os itens

| Item | Fontes |
|---|---|
| `laptop`, `desktop_pc`, `home_server`, `usb_black` | **Amzg** (categoria Eletrônicos, entregue no imóvel). Entram no catálogo pela migração 2 do `coe_amzg`; preço e pausa no admin. |
| `onion_usb` | **Bancada do computador** (desktop ou servidor instalado: aba Computador → Abrir bancada; 1 `usb_black` → 1 `onion_usb` em 45 s, `Craft`). **Contato NPC** (abaixo). **Saque de roubos** (`coe_loot`: residência, pedestre, veículo, comércio). Facções: a receita `hacking_onion_usb` pode ser liberada quando as bancadas ilegais existirem (#161). |
| `laptop`, `usb_black` (usados) | Também caem em roubos (`coe_loot`). |
| `crypto_paper`, `crypto_usb` | Criados no app Cripto (`coe_crypto`). |

## Contato NPC (`Dealer`)

- Um contato vende o pen drive onion **em espécie** (paga primeiro com `black_money`, depois com `money`). Fica num lugar
  de `Dealer.Spots` e muda a cada `RotationMinutes` (o mesmo lugar para todos). Não aparece no mapa: o lugar circula no
  RP. Staff vê onde está com `coe_deepweb_dealer` (ACE `command.coe_deepweb_dealer`).
- Estoque por rodízio para o servidor inteiro (`perRotation`); esgotado, só no próximo lugar.
- Cada venda tem `Alert.Chance` (20%) de abrir o chamado **Negociação suspeita** (`suspicious_deal`) no `coe_dispatch`
  no local: é o primeiro risco de chamar a atenção da polícia.
- O ped é local (cada cliente cria o seu perto do lugar) e a compra é pelo alvo (`coetarget`); o servidor confere a
  distância, o estoque e o dinheiro. As coordenadas são provisórias: confira no jogo.

## Navegador onion (celular e tablet)

Usar o item `onion_usb` instala o navegador no **celular em uso** (o último aberto); sem celular ou com o navegador
já nele, instala no **tablet**. O pen drive é consumido. A instalação fica presa ao aparelho (`phone:<serial>`) ou ao
tablet do personagem. O app `onion` aparece só onde está instalado (`TabletVisible`).

## Computadores

- **Notebook**: usar o item liga o computador. A série (`metadata.serial`, ex.: `LT-7KQ2M9XA`) é gravada no item na
  primeira vez. Quem estiver com o notebook (e souber a senha, se houver) usa tudo o que está nele.
- **Desktop e servidor**: usar o item **dentro de um imóvel** (`coe_housing:CurrentSpace`: moradia, comercial ou
  esconderijo) instala a máquina ali, na posição do jogador. Até `Install.MaxPerSpace` por espaço. Para usar,
  `/computador` a até `Install.UseDistance` metros. **Desmontar** (aba Computador) devolve o item com a mesma série.
- A tela do computador é uma NUI própria (moldura de notebook ou monitor), com área de trabalho e os apps **Onion** e
  **Carteira** (`coe_crypto`, se iniciado). O servidor confere a cada ação que o jogador ainda está com o notebook ou
  perto da máquina, no mesmo espaço; senão o computador fecha.
- **Senha do computador** (opcional, aba Computador): presa à série. Sem ela ninguém entra, nem nas carteiras
  guardadas na máquina. Erros seguidos bloqueiam por `Device.LockSeconds`.
- **Reconhecimento facial** (aba Computador, exige senha): cadastra o rosto de quem está usando. Esse personagem abre o
  computador sem digitar a senha (a barra avisa "Desbloqueado pelo reconhecimento facial"); outra pessoa vê o bloqueio
  com o botão do rosto, que recusa, e entra só pela senha. Remover a senha desliga o rosto. Como no celular.
- Carteiras cripto, senha e apelido conectado ficam presos à **série**: desmontar e reinstalar em outro lugar leva
  tudo junto; roubar a máquina também.

## Identidade anônima

- Apelido com senha (`Handles`): 3 a 20 caracteres (minúsculas, números, `.`, `_`, `-`), nomes reservados bloqueados
  (inclusive disfarçados com pontos). Cada personagem cria até `Handles.MaxPerCharacter`.
- O apelido fica **conectado no aparelho**, não no personagem: quem usar o aparelho entra como você. Trocar a senha
  desconecta os outros aparelhos. Erros seguidos de senha bloqueiam o apelido por `Handles.LockSeconds`.
- **Meus apelidos** (aba Identidade): quem criou o apelido redefine a senha sem a antiga; ele sai dos outros aparelhos e
  entra neste.
- Senhas (apelido e computador) usam o hash próprio do framework, `coe_core/lib/hash.lua` (SHA-256 iterado com salt),
  e não o bcrypt do FXServer, que não conferia no servidor. Hashes antigos são refeitos no primeiro acesso que confere.
- O servidor guarda quem criou cada apelido (`owner_character`) e uma reputação (próxima fase); nada disso vai para
  o cliente.

## Mineração

- Desktop e servidor mineram (`Mining.Hash`: 10 e 40). Na aba **Mineração**: carteira que recebe (qualquer endereço
  existente na rede) e liga/desliga.
- A cada `Mining.TickMinutes`, cada máquina ligada: confere o contrato do imóvel (`coe_housing:AddressActive`), cobra
  a energia (`Mining.PowerCost`) do **banco de quem instalou** (`coe_economy`, motivo `deepweb_power`) e entra na
  rodada do `coe_crypto:MintMining`. Sem contrato ou sem saldo, a máquina fica fora da rodada (estado visível no app).
  Se a rede recusar a rodada, a energia é estornada.

## Eventos e exports

- Exports (smartphone e tablet): `TabletVisible`, `TabletCall` (app `onion`). Admin (só `coe_admin`):
  `AdminOverview`, `AdminSaveSite`, `AdminDeleteSite`, `AdminSaveVendor`, `AdminDeleteVendor`, `AdminResolveOrder`,
  `AdminRemovePost`, `AdminReplyContact`, `AdminCloseContact`. Ver
  [`reference/coe_deepweb.md`](../reference/coe_deepweb.md).
- Computador: cliente → servidor `coe_deepweb:computer:nearby`, `coe_deepweb:computer:call`,
  `coe_deepweb:computer:close`; servidor → cliente `coe_deepweb:computer:open`, `coe_deepweb:computer:result`,
  `coe_deepweb:computer:close`. A carteira do computador é encaminhada para `coe_crypto:ComputerCall` com a chave do
  aparelho.

## Tabelas

`coe_deepweb_handles` (apelidos), `coe_deepweb_sessions` (apelido conectado por aparelho), `coe_deepweb_browsers`
(navegador instalado), `coe_deepweb_devices` (senha por série), `coe_deepweb_rigs` (máquinas instaladas: imóvel,
espaço, posição, mineração), `coe_deepweb_bookmarks`, `coe_deepweb_sites`, `coe_deepweb_communities`,
`coe_deepweb_posts`, `coe_deepweb_comments`, `coe_deepweb_votes`, `coe_deepweb_listings`, `coe_deepweb_orders`,
`coe_deepweb_reviews` e `coe_deepweb_state` (migração 3), `coe_deepweb_contacts` e a coluna `listed` dos sites (migração 4). Migrações em `server/migrations.lua`, controle em `coe_deepweb_schema_migrations`.

## Navegador

- O app **Onion** (celular, tablet e computadores) é um navegador: abas (`Browser.MaxTabs`), voltar/avançar,
  recarregar, início (`Browser.Home`, o DuckDark) e barra de endereço. Texto que não é endereço vira busca no DuckDark.
- Endereços: `<nome>.onion[/caminho][/?q=busca]` e páginas internas `about:rede`, `about:identidade`,
  `about:mineracao`, `about:computador`, `about:favoritos`, `about:historico`.
- **Favoritos** ficam no aparelho (`coe_deepweb_bookmarks`, até `Browser.MaxBookmarks`): quem usar o aparelho vê.
  O **histórico** é só da sessão aberta e some ao fechar o navegador.
- Domínio desconhecido ou fora do ar mostra "Não foi possível alcançar o serviço oculto".
- Todo conteúdo vindo da rede é escrito com `textContent`: nenhum HTML de jogador ou da staff chega à NUI.

## Sites (`coe_deepweb_sites`)

- **Sistema** (`Sites.System`): `duckdark.onion` (app `search`), `rabbit.onion` (`forum`), `deepmarket.onion`
  (`market`) e `fantasma.onion` (`profile`). Recriados a cada início com os dados do config; não são editáveis no
  admin. `listed = false` tira o site do diretório e da busca do DuckDark (só abre quem souber o endereço).
  A migração 4 trocou `bazar.onion` por `deepmarket.onion` (favoritos e links de blocos foram reescritos; `bazar`
  virou nome reservado).
- **Por blocos** (app vazio): criados pela staff no admin (**DeepWeb > Sites**). Blocos: `heading`, `text`, `quote`,
  `notice` (tom `info|warn|danger|success`), `list`, `divider`, `link` (endereço `.onion` ou `about:`) e `listing`
  (anúncio do Deep Market). Validados por `DeepwebRules.Blocks`; guardados como JSON. A opção **Aparece no DuckDark**
  (`listed`) esconde o site do diretório e da busca.
- Nomes reservados em `Sites.Reserved` (inclusive disfarçados com hífen). A coluna `owner_handle` já existe para a
  **hospedagem por jogadores** (nível 5), na próxima fase.

## DuckDark

Busca (2 a 40 caracteres) em sites ativos e listados (título, descrição, palavras-chave, domínio), posts do Rabbit e anúncios
ativos do Deep Market. Só o que existe no servidor. Sem busca, mostra o diretório dos sites.

## Rabbit

- Comunidades `r/<nome>` (`Forum.Communities` são criadas no primeiro início), posts com título e texto,
  comentários em árvore (até `Forum.MaxDepth` níveis), votos (+1/-1, não no próprio conteúdo) e perfil `u/<apelido>`
  com pontos (soma das pontuações) e as avaliações de vendedor do Deep Market.
- Ordenação: em alta (pontuação com peso pela idade, `DeepwebRules.Hot`, última semana), novos e top.
- Escrever exige apelido conectado; intervalos `PostCooldownSeconds` e `CommentCooldownSeconds` por apelido.
- **Criar comunidade** exige nível 3 (`forum_create`), até `MaxCommunitiesPerHandle` por apelido. Quem cria modera:
  remove posts e comentários da comunidade. O autor também remove o que é seu. A staff remove posts no admin.

## Deep Market

- **Anúncios**: de **fornecedores NPC** (sem apelido, cadastrados no admin em **DeepWeb > Fornecedores**;
  `Market.Vendors` entram uma vez só) ou de **jogadores** (nível 3, apelido conectado, até
  `MaxListingsPerHandle`). Tipo `item` (item do inventário × quantidade por unidade) ou `service`. Preço em moeda
  (`0,5`), guardado em unidades (`CoinDecimals`). O vendedor informa a carteira que recebe (`payout`).
- **Compra** (nível 2): escolhe uma carteira com chave à mão no aparelho (`coe_crypto:HeldWallets`). O valor (mais
  a taxa da rede) vai para a **custódia** (`coe_crypto:EscrowLock`) e o estoque é reservado.
- **Item**: cada pedido sorteia um **ponto de coleta** (`Market.Drops`). No site, **Ir deixar a entrega** (vendedor) ou
  **Ir coletar** (comprador) **arma o ponto** para o personagem: GPS marcado e, a menos de `DropSpawnDistance`, uma
  caixa local (`DropProp`) com alvo do `coetarget`. A entrega é feita **pelo alvo** no local (evento
  `coe_deepweb:drop:use`): o servidor confere o ponto armado (mesmo personagem e apelido, validade
  `DropTicketMinutes`), a distância (`DropDistance` na horizontal e `DropHeight` de altura, já que as coordenadas são
  provisórias), o estado do pedido e o inventário. Deixar tira os itens do vendedor; coletar põe no comprador e a
  custódia paga o vendedor (`EscrowRelease`), menos a taxa (`FeeBps`, para a reserva da corretora). Pedidos de
  fornecedor NPC já nascem no ponto. Pontos armados ficam em memória: depois de reiniciar o recurso, arme de novo
  pelo site.
- **Serviço**: o vendedor marca como feito; o comprador **confirma** ou **contesta** (com motivo). Sem resposta em
  `AutoReleaseHours`, libera sozinho. Contestação vai para a staff (**DeepWeb > Pedidos**): devolve ou paga.
- **Cancelamento**: o vendedor cancela quando quiser; o comprador, depois de `DeliverHours` sem entrega. A custódia
  volta inteira e o estoque é devolvido. A staff também cancela pedidos pagos e travados.
- **Avaliação** (1 a 5) depois de concluído: entra no perfil do vendedor e soma `nota - 3` na reputação do apelido.
- Deixar ou coletar tem `Market.Alert.Chance` de abrir **Negociação suspeita** no `coe_dispatch`.
- Robustez: troca de estado condicional (`MoveOrder` só se ainda estiver no estado esperado), coleta com estado
  intermediário `collecting`, e `settled` marca o pagamento feito: se a rede cripto falhar, a rodada do mercado
  (1 min) repete. A mesma rodada libera serviços e itens deixados há mais de `AutoReleaseHours`.
- O comprador nunca vê quem é o vendedor além do apelido; o servidor guarda o personagem comprador
  (`buyer_character`) e o livro do `coe_crypto` guarda quem moveu cada valor.

## Perfis da staff (`profile`)

Sites de sistema com `app = 'profile'` e uma tabela `profile` no config: `handle`, `tagline`, `bio` (parágrafos
separados por linha em branco), `skills`, `facts` (`{ label, value }`), `rules` e `contact`. O `fantasma.onion` é a
conta da staff responsável pelo mundo hacking; não aparece no DuckDark.

Com `contact = true`, a página tem um formulário: exige apelido conectado, texto de `Contact.BodyMin` a
`Contact.BodyMax` caracteres, intervalo de `Contact.CooldownSeconds` entre mensagens do apelido e até
`Contact.MaxOpen` mensagens sem resposta por site. As mensagens ficam em `coe_deepweb_contacts` (migração 4) e
chegam ao admin em **DeepWeb > Contatos**. A resposta aparece na própria página (últimas `Contact.Shown`) e quem
estiver online com aquele apelido recebe um aviso. A staff também arquiva mensagens.

## Telas dos sites (`html/sites.js`)

O navegador (`deepweb.js`) carrega `nui://coe_deepweb/html/sites.js` e procura um renderizador em
`window.CoeOnion.sites[app]` (`search`, `forum`, `market`, `profile` e `blocks` para sites por blocos); o visual de cada site
fica em `html/sites.css`. O layout se adapta pela largura disponível (no celular a NUI é pequena dentro de uma
janela larga, então `@media` pela tela não serve). App sem renderizador mostra "Este site não abriu no seu navegador".

Rotas de cada site:

| Site | Endereços |
|---|---|
| DuckDark (`search`) | raiz (busca + diretório), `/?q=texto` (resultados em sites, Rabbit e Deep Market) |
| Rabbit (`forum`) | raiz, `new`, `top`, `criar`, `r/<comunidade>[/new\|top]`, `r/<comunidade>/enviar`, `r/<comunidade>/<id>`, `p/<id>`, `u/<apelido>` |
| Deep Market (`market`) | raiz (`/?q=` busca), `c/<categoria>`, `fornecedores`, `a/<id>`, `painel`, `painel/novo`, `painel/editar/<id>`, `pedido/<id>` |
| Perfil (`profile`) | qualquer caminho: perfil e, com `contact`, formulário e mensagens do apelido |
| Blocos (`blocks`) | qualquer caminho: desenha os blocos do site (`listing` busca o anúncio e mostra o cartão) |

Cada renderizador é `function (page, ctx)`. `window.CoeOnion` traz os utilitários de DOM (`el`, `button`, `input`,
`textarea`, `select`, `field`, `card`, `line`, `link(texto, endereço, classe, ctx.go)`, `when`, `ago`, `parse`) e
`errors` (mensagens por código). O `ctx`:

| Campo | Uso |
|---|---|
| `target` | `{ domain, path = { ... }, query, href }` do endereço aberto |
| `site` | `{ domain, app, title, description, blocks, profile }` (blocos em JSON; `profile` nos perfis da staff) |
| `data` | estado do `state` (nível, apelido conectado, recursos) |
| `call(action, payload)` | Promise com `{ ok, ... }` ou `{ ok = false, error }` |
| `request(action, payload, onDone, message)` | `call` com aviso de erro/sucesso e trava contra clique duplo |
| `alive()` | a página ainda é a mesma? (confira antes de desenhar depois de uma chamada) |
| `go(endereço)`, `replace(endereço)` | navega com ou sem nova entrada no histórico |
| `setTitle(texto)`, `refresh()`, `reloadState()`, `status(texto, tipo)`, `waypoint(x, y)`, `errorText(código)` | |

Ações do servidor (todas pelo app `onion`; leitura sem intervalo mínimo):

| Ação | Payload | Resposta |
|---|---|---|
| `site` | `{ address }` | `{ site }` ou `not_found` |
| `directory` | | `{ sites = { { domain, app, title, description } } }` |
| `search` | `{ q }` | `{ query, sites, posts, listings }` |
| `forumHome` | `{ sort = hot\|new\|top, page }` | `{ communities, posts, more, me, canCreate }` |
| `forumCommunity` | `{ slug, sort, page }` | `{ community, posts, more, me, moderating }` |
| `forumPost` | `{ id }` | `{ post, comments (com depth, ordem de leitura), community, me }` |
| `forumUser` | `{ handle }` | `{ handle, karma, postCount, commentCount, posts, reviews }` |
| `forumSubmit` | `{ slug, title, body }` | `{ id, slug }` |
| `forumComment` | `{ postId, parentId?, body }` | `{ id }` |
| `forumVote` | `{ target = p\|c, id, value = 1\|-1\|0 }` | `{ vote, delta }` |
| `forumRemove` | `{ target, id }` | `{ ok }` |
| `forumCreate` | `{ slug, title, description }` | `{ slug }` |
| `marketHome` | `{ category?, q?, npc?, page }` | `{ listings, categories, more, me, canBuy, canSell, feeBps }` |
| `marketListing` | `{ id }` | `{ listing, reviews, wallets, maxQuantity, canBuy, ... }` |
| `marketBuy` | `{ id, quantity, from }` | `{ orderId, status }` |
| `marketMine` | | `{ listings, bought, sold, categories, canSell, maxListings, decimals }` |
| `marketOrder` | `{ id }` | `{ order }` com `actions`, `drop` (quando a pessoa precisa ir ao ponto) e `canReview` |
| `marketSave` | `{ id?, title, description, kind, category, item, count, price (texto), stock, payout, status? }` | `{ id }` |
| `marketListingStatus` | `{ id, status = active\|paused\|removed }` | `{ ok }` |
| `marketAct` | `{ id, action = deliver\|collect\|confirm\|dispute\|cancel, note? }` | `{ status }`; `not_at_drop` traz `drop` |
| `marketReview` | `{ id, rating, body }` | `{ ok }` |
| `contactThread` | `{ domain }` | `{ handle, messages = { { id, body, reply, status = open\|answered\|closed, createdAt, repliedAt } } }` |
| `contactSend` | `{ domain, body }` | `{ id }`; erros `invalid_message`, `contact_cooldown`, `contact_limit` |
| `bookmarks`, `bookmarkAdd { address, title }`, `bookmarkRemove { address }` | | |

## Próximas fases

1. **Hospedagem** (nível 5): o jogador monta o próprio site por blocos no servidor doméstico (`owner_handle`), com
   blocos novos (vitrine própria, formulário de contato e páginas de golpe para o RP de invasão).
2. **Contratos** entre jogadores com garantia em cripto e arbitragem.
3. **Risco de atenção da polícia**: rastro por aparelho e por carteira, mineração gerando "calor", consultas no MDT.
4. Serviços pagos do sistema (lavagem, rastreio, informação) e vigilância (GPS, microfones, câmeras, vans).

## Dependências

`coe_core`, `coe_database`, `coe_logging`, `coe_ui`. Opcionais: `coe_crypto` (carteira, mineração e custódia do
Deep Market), `coe_dispatch` (alertas), `coe_inventory`
(itens), `coe_housing` (instalação e contrato), `coe_economy` (energia), `coe_phone`/`coe_tablet` (app onion),
`coe_audit`, `coe_notify`. Precisa estar nas listas de `coe_database`, `coe_logging`, `coe_audit`, `coe_notify`,
`AllowedResources` do `coe_economy` e `DeliveryCallers` do `coe_housing` (já incluído).

## Testes

```
cd coe_deepweb
lua test/deepweb_test.lua
lua test/server_test.lua
lua test/web_test.lua
lua test/persistence_test.lua
```
