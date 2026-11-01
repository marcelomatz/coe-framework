# coe_jobs

Empregos livres do Coe (#123): os trabalhos que não dependem de um negócio. Os empregos de negócio (cargos,
salário, ponto) continuam no `coe_businesses`; aqui ficam os que qualquer cidadão pega no NPC e começa na hora.
Todos vivem juntos neste resource e compartilham a **carreira** do personagem: o histórico em um emprego dá
vantagem nos outros.

## Empregos

| Emprego | Tipo | Onde | Veículo / ferramenta | Treina | Requisito | Como paga |
| --- | --- | --- | --- | --- | --- | --- |
| **Lenhador** | corte, transporte e serraria | Floresta de Paleto → madeireira | Pickup `bison` (depósito $350); machado (visual) | Força, Campo | — | Derruba **árvores do próprio mapa** na área (10 s, 2–3 toras; a árvore tomba, some para todos e rebrota em 15 min), leva as toras uma por vez até a caçamba (8, mais com Força), desdobra na serra (1 tora = 4 tábuas) e vende a $7 a tábua. |
| **Fazendeiro** | coleta | 4 campos em Grapeseed + vinhedo Marlowe; mercado e vinícola | — | Campo, Força | — | Repolho $8 (5 s, 2–3), abóbora $16 (6 s, 1–2), milho $5 a espiga (4 s, 3–4), laranja $4 (5 s, 4–5) e uva $7 o cacho (4 s, 2–3); até 40 itens somando tudo. |
| **Pescador** | pesca livre | 5 áreas (píeres de Del Perro e Paleto Cove, litoral de Chumash, Alamo Sea, represa do Land Act); 3 compradores | Vara e iscas do `coe_inventory` (loja de pesca) | Campo | — | Usa a vara de frente para a água (do alto do píer vale), cada lance gasta uma isca e o minigame decide a fisgada. 10 espécies de $12 a $100 (mar e água doce); até 25 peixes. Varas e iscas melhores pedem nível no emprego. |
| **Mineiro** | coleta | Pedreira Davis Quartz | Picareta (visual) | Força, Campo | Força 2 | Quebra rochas (7 s, 1–2, até 20) e vende a $20 o minério. |
| **Entregador** | rota | GoPostal (Vinewood) → Mirror Park | Van `boxville2` (depósito $300); caixa na mão | Direção, Logística | — | 6 paradas, $45 por entrega e $120 por rota. Pega a encomenda na van e entrega ao morador. |
| **Lixeiro** | coleta por áreas | Limpeza urbana → 10 bairros de Los Santos | Caminhão `trash` (depósito $400); saco na mão | Força, Direção | — | 3 áreas por rota, 6 sacos por área, $28 por saco e $180 por rota. Recolhe em qualquer lixeira, caçamba ou saco do mapa dentro da área; abre a caçamba na traseira do caminhão e joga o saco. |
| **Taxista** | rota de passageiros | Downtown Cab Co. → cidade | Táxi `taxi` (depósito $250) | Direção, Logística | Carreira 2 | 4 corridas, $30 + $70 por km e $100 por rota. Para no ponto: o passageiro embarca e desembarca sozinho. |
| **Caminhoneiro** | rota longa | Porto de Los Santos → armazéns do estado | Caminhão `mule3` (depósito $800); carga na mão | Direção, Logística | Direção 2 e reputação ≥ 0 | 3 docas, $60 + $35 por km e $200 por rota. |

Os empregos de entrada (sem requisito) treinam as habilidades que os outros pedem: o lenhador, o fazendeiro e o
lixeiro levam à Força do mineiro; o entregador e o lixeiro à Direção do caminhoneiro; qualquer emprego à carreira 2
do taxista.

Todo emprego pode ter um **uniforme opcional** (`uniform`): trabalhando, o responsável oferece "Vestir …" e
"Tirar o uniforme". A roupa do jogador é guardada inteira e volta ao tirar ou ao encerrar o trabalho (só visual,
nada é salvo na aparência). Cada uniforme tem roupa masculina e feminina (modelos freemode).

### Loja do emprego e pesca livre

- **Loja** (`shop`): vendedor sempre no mapa (não precisa ter começado o trabalho), com vitrine NUI. Cada item tem
  preço e o **nível do emprego** que o libera; bloqueados aparecem com o nível que falta. Paga em dinheiro vivo
  (item `money`) e, sem ele, no banco (`coe_economy`, extrato `job_shop`); inventário cheio estorna. Os itens vão
  para o `coe_inventory` (opcional: sem ele a loja responde "inventário indisponível").
- **Pesca** (`gather.fishing`): o jogador **usa a vara no inventário** e ela fica na mão (prop próprio
  `prop_fishing_rod_01`, que não cai no chão; usar de novo ou X guarda). Com a vara: **segurar E carrega a força** (vai e
  volta) e **soltar arremessa**; a linha cai a 4-18 m à frente e precisa cair na água (funciona da beira e do alto do
  píer) dentro de uma área de pesca. Mais força = água mais funda: mordida até 15% antes e +0,15 de bônus de raros.
  O primeiro arremesso já começa o trabalho onde ele estiver; encerra-se no NPC, num comprador ou na loja. Usar uma
  **isca** escolhe qual vai no anzol (sem escolher, vai a mais simples que tiver). Cada arremesso gasta uma isca (a
  artificial sobra em 85%) e a espécie é sorteada pela área (pesos) com o bônus da vara + isca.
- **Fisgada e briga**: na mordida há `hookSeconds` (1,6 s) para apertar E; depois vem a briga: o peixe nada pela barra
  e o jogador segura/solta E para manter a faixa da vara (maior nas varas melhores) em cima dele. Dentro, o progresso
  enche; fora, esvazia. Cheio fisga, vazio (ou `fightSeconds`) escapa. Raros nadam mais rápido e enchem mais devagar
  (`JobRules.FightParams`); o servidor recusa fisgadas antes da mordida + tempo mínimo da briga. X recolhe a linha
  antes da mordida.
- Varas: bambu (nível 1, $120), fibra (nível 2, $650), carbono (nível 4, $1.800). Iscas: pão (1, $2), minhoca
  (2, $5), camarão (3, $9), artificial (5, $260, reaproveitável). Efeitos e áreas em `jobs/fisher.lua`; itens e
  ícones em `coe_inventory/data/coe_fishing.lua`.

Cada emprego é um arquivo em `jobs/` (só dados); `Enabled` em `config.lua` liga ou desliga. Um emprego novo é um
arquivo novo, sem mexer no código.

## Carreira (XP do jogador)

Tudo é calculado em `shared/career.lua` (puro e testado) a partir do XP de cada emprego e da reputação.

- **XP do emprego** → nível do emprego (5 níveis: 0, 150, 450, 1.000, 2.000 XP), +5% de pagamento por nível.
- **Carreira**: a soma do XP de todos os empregos dá o nível de carreira (8 níveis: 0 a 16.000 XP). Cada nível
  acima do 1 dá **+1% de pagamento e +3% de XP em qualquer emprego**, inclusive nos que o jogador nunca fez.
- **Habilidades**: cada emprego treina habilidades (`skills`); o XP de uma habilidade é a soma do XP dos empregos
  que a treinam, e o bônus vale em **todo emprego que usa a habilidade** (por nível acima do 1):

  | Habilidade | Bônus por nível | Quem treina hoje |
  | --- | --- | --- |
  | Força | +10% de carga | Lenhador, Fazendeiro, Mineiro, Lixeiro |
  | Campo | -5% no tempo das ações (até -30%) | Lenhador, Fazendeiro, Pescador, Mineiro |
  | Direção | -15% no depósito do veículo | Entregador, Lixeiro, Taxista, Caminhoneiro |
  | Logística | +3% de pagamento | Entregador, Taxista, Caminhoneiro |

  Ex.: quem já tem Força do lenhador começa o futuro mineiro carregando mais.
- **Reputação** (-100 a 100): concluir uma venda ou uma rota soma 1; sair do jogo ou trocar de personagem com o
  veículo da empresa tira 10; encerrar sem devolver o veículo tira 5. Faixas: **Exemplar** (50+: sem depósito de
  veículo e +5%), **Confiável** (20+: +3%), **Regular**, **Duvidosa** (-20 ou menos: depósito em dobro).
- **Requisitos**: um emprego pode exigir carreira, reputação ou nível de habilidade (`requires`), liberando
  trabalhos mais rentáveis para quem tem histórico.
- O bônus total de pagamento tem teto (`maxPayBonus`, 60%). Subir de nível no emprego, na carreira ou numa
  habilidade avisa o jogador.

### No NPC de cada emprego

- **Começar** e **Encerrar o trabalho**. Na coleta, encerrar com carga não encerra: o servidor avisa para vender
  antes, e a opção **Descartar a carga e encerrar** confirma (a carga não vira item e se perde).
- **Como funciona**: tela (NUI `html/guide.html`) com o passo a passo, pagamento, dicas, regras, habilidades que o
  emprego treina, requisito e o histórico do jogador ali (nível, XP, tarefas, ganhos, bônus, carga, depósito e as
  últimas vezes). O guia sai da própria definição (`shared/guide.lua`), então todo emprego novo já ganha o seu;
  `tips` acrescenta dicas. Fecha com o botão ou Esc.
- Ao encerrar, o resumo do trabalho (tarefas, XP, ganhos, descarte e depósito) aparece na notificação e fica nos
  últimos trabalhos.

### App Carreira (tablet)

App de tablet para todos (no tablet de trabalho básico `coe_workpad`, ou num tablet de pacote): nível e XP de carreira, reputação e o efeito
dela, os últimos trabalhos (quando, quanto tempo, tarefas, XP, ganhos e o que foi descartado), cada habilidade com
o bônus atual e por nível, e cada emprego com nível, tarefas, bônus que o histórico dá ali, carga, tempo da ação,
depósito, requisitos que faltam, **Como funciona** (o mesmo guia do NPC, `html/guide-view.js`) e GPS até o NPC.

## Definição de um emprego

Validada em `shared/rules.lua` (`JobRules.Validate`); erro devolve o código (`invalid_nodes:3` indica o ponto).
Pontos aceitam `{ x, y, z, h }`. Contrato LuaLS em [`types.lua`](types.lua).

| Campo | Uso |
| --- | --- |
| `tips` | Até 6 dicas (160 caracteres) somadas ao guia **Como funciona**. |
| `id`, `label`, `description` | `id` em `[a-z][a-z0-9_]` (2 a 24; `deposit` é reservado). Extrato do `coe_economy`: `job_<id>`. |
| `kind` | `gather` (coletar e vender) ou `route` (paradas em sequência). |
| `center`, `centerPed`, `blip` | NPC onde começa, encerra e vê o histórico (alvo do `coetarget`) e blip no mapa. |
| `levels`, `levelBonus` | XP de cada nível do emprego (começa em 0, crescente) e bônus por nível (padrão 5%). |
| `skills`, `requires` | Habilidades que treina (`Career.skills`) e requisitos `{ career?, reputation?, skills = { id = nível } }`. |
| `vehicle` | `{ model, spawn, plate?, deposit?, returnRadius? }`: criado pelo servidor ao começar; o depósito (com os descontos da carreira) volta ao encerrar com o veículo perto do centro. |
| `tool` | Prop na mão durante a ação (`{ model, bone, offset, rotation }`), só visual. |
| `uniform` | Opcional: `{ label, male, female }`, cada roupa `{ components = { [slot] = { drawable, texture } }, props = { [slot] = { drawable, texture } } }` (slots 0–11 e 0–9; drawable -1 num prop tira). |
| `gather` | `nodes` (com `nodeProp`), `actionLabel`, `seconds`, `yield = { min, max }`, `capacity`, `nodeCooldown`, `xp`, `unit`/`units`, `animation` (`{ dict, name, flag }` ou `{ scenario }`) e `sell = { points, price, ped, label }`. Extensões abaixo. |
| `gather.products` | Vários produtos, cada um com `unit`, `units`, `price` (0 = não vende direto), `prop` (nome ou lista de candidatos), `animation`, `seconds`, `yield`, `xp`, `cooldown`, `actionLabel`. A carga soma todos; a venda paga cada um pelo seu preço. `order` define a ordem. |
| `gather.fields` | Campos de plantio em grade: `{ product, origin, heading, rows, cols, spacing, rowSpacing?, soil?, label }`. Com `soil` (padrão de `gather.soil`), o client só põe pé onde o chão é terra (`SoilMaterials`); pontos na estrada ou na grama somem, e se o campo inteiro falhar o filtro desliga nele. |
| `gather.world` | Objetos do próprio mapa numa área: `{ product, models, area = { x, y, z, radius, label }, fell?, cooldown? }`. Com `fell`, a árvore tomba e some para todos (`CreateModelHide`) até o cooldown; quem entra depois recebe a lista. |
| `gather.haul` | Transporte (exige `vehicle`): a colheita cai no chão (`groundProp`), o jogador leva uma por vez (`carry`, `carryAnimation`, `takeLabel`) e guarda no veículo (`loadLabel`), até `capacity`. `rack = { model, slots }` desenha a carga na caçamba para todos (state bag `coe:jobLoad`). |
| `shop` | Loja: `{ label, ped, points, items = { { item, label, price, level, max, kind, description, stats } } }` (itens do `coe_inventory`; `level` = nível do emprego). |
| `gather.fishing` | Pesca livre: `{ areas = { { x, y, z, radius, label, water, species = { produto = peso } } }, rods, baits, castSeconds, biteSeconds, hookSeconds, fightSeconds, rodProp }`. Vara/isca: `{ item, label, level, speed, window, rarity, keep }`. Produtos ganham `tier` (`common`/`uncommon`/`rare`) e `difficulty` (velocidade do minigame). |
| `gather.process` | Beneficiamento: em `points`, com o veículo a `vehicleRange`, a carga vira `ratio` unidades de `product` (`seconds` por unidade, até `maxSeconds`). |
| `route` | `mode`, `stops`, `perRoute`, `pay` por parada, `payPerKm` (desde a parada anterior ou o embarque), `bonus` no fim da rota, `xp`, `stopRadius`, `vehicleRange` (0 desliga), `carry` + `carryAnimation`, `pickAnimation`/`dropAnimation` (curtas, `{ dict, name, flag, ms }`), `recipients`, `stopProp`, `actionLabel`, `pickupLabel`, `dropLabel`; no modo `zone`: `zones` (`{ x, y, z, radius, label }`), `perZone`, `binModels`, `binCooldown`, `rearDoor`, `openLabel`, `closeLabel`. `carry` aceita `fallback` (modelo reserva). |

Modos de rota (`route.mode`):

- `deliver` (padrão): pega a carga no veículo (`pickupLabel`) e entrega ao destinatário da parada (`actionLabel`).
- `collect`: recolhe na parada (objeto `stopProp`, `actionLabel`) e guarda no veículo (`dropLabel`). O servidor
  confere o jogador na parada ao recolher e a até `VehicleReach` do veículo ao guardar. Exige `carry`.
- `zone`: cada rota sorteia `perRoute` áreas de `zones`. Dentro da área, qualquer objeto do mapa de `binModels`
  (lixeiras, caçambas, sacos) ganha a opção `actionLabel`; o saco vai para a mão e é guardado na traseira do veículo
  (`openLabel` abre a porta `rearDoor`, `dropLabel` guarda, `closeLabel` fecha). O servidor confere o jogador na área
  e a até 3,5 m da lixeira, a mesma lixeira (posição arredondada a 1 m) só de novo depois de `binCooldown` segundos
  para qualquer jogador, e o veículo perto do jogador e da área ao guardar. `perZone` sacos completam a área. Exige
  `carry`.
- `passenger`: cada corrida usa duas paradas, embarque e destino. Com o veículo parado a até `stopRadius` e o
  jogador ao volante, o passageiro embarca e depois desembarca sozinho; a corrida paga `pay` + `payPerKm` pela
  distância do embarque ao destino.

Outros resources também podem somar empregos com `exports.coe_jobs:RegisterJob(definição)` (ouvindo o evento
`coe_jobs:ready`), sem entrar em nenhuma allowlist; ao parar, os empregos deles saem.

## O que o servidor garante

- Sessão por jogador e personagem; trocar de personagem encerra (e conta como abandono se havia veículo).
- Começar e encerrar só perto do centro e com os requisitos; coletar, vender e entregar só perto do ponto
  (`PointRadius` na horizontal, `PointHeight` de altura, porque os pontos têm `z` aproximado).
- Coleta: tempo mínimo da ação (já com o bônus de Campo), cooldown por ponto e carga (com o bônus de Força).
- Objetos do mapa (`world`): modelo da lista, jogador e objeto dentro da área, jogador a até 4 m, cooldown por
  posição para todos. Transporte: uma unidade por vez do chão (a até 10 m de onde caiu) para o veículo (a até
  `VehicleReach`), sem cortar outra com toras no chão; beneficiamento só com o veículo perto da serra.
- Rota: só a próxima parada sorteada e na etapa certa (recolher antes de guardar, embarcar antes do destino);
  veículo a `vehicleRange`; tempo mínimo entre paradas pela distância (`MaxTravelSpeed`, contra teleporte). Fim da
  rota paga o bônus, soma reputação e sorteia outra.
- Intervalo mínimo entre ações (`ActionCooldownMs`). Pagamento só aqui, com todos os bônus da carreira.
- A carga é da sessão (não vira item), então não depende do catálogo do `coe_inventory`.

## Tabela de salários (nível 1, sem carreira)

Estimativa de ritmo; `test/jobs_test.lua` falha se um emprego de entrada sair da faixa de $1.500 a $3.000 por hora ou
um emprego com requisito sair da faixa de $2.200 a $3.800.

| Emprego | Ritmo estimado | Nível 1 |
| --- | --- | --- |
| Lenhador | ~25 s por árvore, ~12 s por tora carregada, ~2,5 min de ida e volta e a serra a cada 8 toras | ~$2.300/h |
| Fazendeiro | ~20 s por pé (média dos 5 produtos), venda a cada 40 | ~$1.650/h |
| Pescador (vara e isca básicas) | ~24 s por arremesso (espera + briga), ~75% de fisgada, venda a cada 25, menos as iscas | ~$1.750/h |
| Mineiro (Força 2) | ~22 s por rocha, venda a cada 20 | ~$2.400/h |
| Entregador | ~90 s por parada, rota de 6 | ~$2.800/h |
| Lixeiro | ~45 s por saco, 6 por área, 3 áreas | ~$2.400/h |
| Taxista (carreira 2) | ~5 min por corrida (ida ao embarque e corrida) | ~$2.550/h |
| Caminhoneiro (Direção 2) | ~4 min por doca (~4 km) | ~$3.200/h |

O nível do emprego soma até +20% (nível 5). Carreira, habilidades e reputação somam por cima (até +60% no total).

## Pontos, props e animações (validar no jogo)

- Coordenadas **provisórias** em `jobs/*.lua`; `z` errado ainda funciona (o client sonda o chão de verdade).
  Campos do fazendeiro: ajuste `origin`/`heading`/`spacing` de cada campo em vez de ponto por ponto.
- Props com lista de candidatos (usa o primeiro que existir): milho `prop_veg_corn_01`, uva `prop_bush_med_03`,
  toras `prop_log_break_01`/`prop_log_02`/`prop_log_01`, bancada da serra `prop_tool_bench02`. Demais: repolho
  `prop_veg_crop_03_cab`, abóbora `prop_veg_crop_03_pump`, laranjeira `prop_veg_crop_orange`, rocha `prop_rock_1_d`,
  balde `prop_bucket_02a`, saco `hei_prop_heist_binbag` (reserva `prop_cs_rub_binbag_01`), machado
  `prop_w_me_hatchet`, picareta `prop_tool_pickaxe`, caixa `prop_cs_cardbox_01`.
- Na mão: caixa nas duas mãos (osso 60309, `0.025, 0.08, 0.255` / `-145, 290, 0`); saco ao lado da perna (osso
  57005, `0.40, 0, 0` / `0, 270, 60`); picareta (57005, `0.18, -0.02, -0.02` / `-100, 0, -10`); machado (57005,
  `0.10, 0.02, -0.02` / `-90, 0, 0`).
- Animações: plantio `amb@world_human_gardener_plant@male@base / base` (sem a entrada longa do cenário); colher no
  alto `amb@prop_human_movie_bulb@base / base`; uva e serra `anim@amb@clubhouse@tutorial@bkr_tut_ig3@ /
  machinic_loop_mechandplayer`; machado `amb@world_human_hammering@male@base / base`; mineiro
  `melee@large_wpn@streamed_core / ground_attack_on_spot`; pesca `WORLD_HUMAN_STAND_FISHING`; caixa e tora
  `anim@heists@box_carry@ / idle`; lixo `anim@heists@narcotics@trash` (`pickup`, `walk`, `throw_b`).
- Tempos: repolho 5 s, abóbora 6 s, milho 4 s, laranja 5 s, uva 4 s, pesca 12 s, rocha 7 s, árvore 10 s, serra 3 s
  por tora (até 24 s); pegar saco ~1 s e jogar ~1,3 s.
- Veículos: `boxville2`, `trash`, `taxi`, `mule3`, `bison`. Caçamba do `trash`: porta 5 (`rearDoor`; se o modelo
  não tiver, tenta 4/6/2). O client pede o controle de rede antes de abrir (o caminhão nasce no servidor) e as
  opções da traseira usam o comprimento do veículo, porque o `coetarget` mede a distância até o centro dele.
- Uniformes: valores de roupa **provisórios** (variam com os DLCs do servidor); confira e ajuste em cada `jobs/*.lua`.

## Persistência

Migrações próprias (`coe_jobs_schema_migrations`): `coe_jobs_progress` (XP, tarefas e ganhos por personagem e
emprego), `coe_jobs_profile` (reputação, concluídos e abandonados) e `coe_jobs_sessions` (cada trabalho encerrado:
início, fim, tarefas, XP, ganhos, descarte e motivo; o app mostra os últimos `RecentSessions`). A migração 4 soma o tempo trabalhado em
cada emprego (`seconds`, `first_at`, `last_at` em `coe_jobs_progress`), usado pelo currículo do `coe_elos`. O
histórico fica em memória enquanto o personagem está online; `GetCareer` de quem está offline lê do banco sem guardar.

## Exports (servidor)

`RegisterJob`, `UnregisterJob`, `ListJobs`, `IsReady`, `GetSession`, `GetProgress`, `GetCareer`, `TabletVisible`,
`TabletCall`. Referência: [reference/coe_jobs.md](../reference/coe_jobs.md).

## Client

Sem loop por quadro: um laço de 1 s cria e remove NPCs, objetos de coleta e destinatários perto do jogador; as
ações usam o `coetarget`. Blips dos centros, dos pontos e da parada atual (com rota no GPS).

## Testes

`lua test\rules_test.lua` (contrato), `lua test\career_test.lua` (carreira, habilidades, reputação e bônus),
`lua test\guide_test.lua` (guia "Como funciona" de cada emprego), `lua test\persistence_test.lua` (nenhum comando ao
banco com `nil` nos parâmetros),
`lua test\server_test.lua` (sessões, depósito, coleta, venda, encerrar com carga, rotas de entrega, coleta e
passageiro, pagamento por km, anti-trapaça, requisitos, reputação, últimos trabalhos, guia e app do tablet, com
natives simulados, inclusive o lenhador com árvore do mapa, pickup, serra e venda, e o fazendeiro com vários
produtos, a loja e a pesca livre) e `lua test\jobs_test.lua` (empregos de `jobs/` e faixa de salário).

## Dependências e allowlists

`coe_core`, `coe_database`, `coe_economy`, `coe_logging`, `coe_notify`, `coetarget`; `coe_inventory` opcional (loja
e pesca com vara). O `coe_jobs` está nos padrões
de acesso desses resources (banco, dinheiro, logs e notificações) e no `coe_supervisor`. O app Carreira aceita o
tablet de trabalho básico (`coe_workpad`, padrão em `TabletResources`) e tablets de pacotes com a ACE
`coe.jobs.tablet` (`add_ace resource.<nome> coe.jobs.tablet allow`).
