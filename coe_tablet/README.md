# coe_tablet

> Upgrade do tablet de trabalho básico (`coe_workpad`): o `coe_supervisor` não inicia o básico com este resource rodando. Os apps **Ponto** e **Empregos livres** do básico estão no grupo Trabalho (`server/work.lua`, `html/duty.js`, `html/freejobs.js`), e `/trabalho` também abre o tablet. Detalhes em [`UPGRADES.md`](../UPGRADES.md).

**COE OS**: o tablet do personagem e a central de controle de tudo o que ele tem. Um único tablet reúne todos os apps que o jogador pode ver; cada sistema é um app, e cada negócio ou facção de que ele faz parte ativa o seu próprio app.

Substitui o tablet de trabalho básico do framework (`coe_workpad`): ao iniciar, e sempre que o `coe_workpad` reinicia, chama o export `Yield` (ACE `coe.workpad.yield` no `permissions.cfg`). O básico fecha a tela e deixa de abrir (tecla F3, `/trabalho` e item `business_tablet`) até o `coe_tablet` parar. Os apps Carreira e Negócio são os mesmos nos dois; Ponto e Empregos livres são só do básico.

- Seções (`Groups`): **Pessoal** (Banco, Veículos, Casa), **Aplicativos** (Loja e apps instalados), **Trabalho** (apps do emprego), **Negócios** (um app por negócio) e **Ilegal** (Esconderijo, um app por facção). Cada app indica a sua em `group`.
- `everyone = true`: app de todo personagem (Banco, Veículos), sem emprego nem item.
- `instances = true`: o resource expõe `TabletInstances(playerId) -> { {id, label} }` e o tablet cria um app por instância (id `<app>:<instância>`). O `TabletCall` recebe a instância como 5º argumento e revalida o acesso a cada ação.
- **Aparelho**: o mesmo vidro do smartphone (`coe_phone`: fio de luz, reflexo, cantos chanfrados), deitado em 16:10, com botão de guardar e de brilho na borda de cima. Sem teclado e sem a cara de máquina hacker do notebook (`coe_deepweb`), mas com a mesma tela: papel de parede, barra de status (COE OS, perfil do emprego, hora, Wi-Fi, bateria, guardar e central de controle) e painéis chanfrados do `coe_ui`.
- **Início**: widgets à esquerda (relógio e data, total de apps e de apps abertos, recentes) e, à direita, a busca e os apps por seção (`Groups`) em azulejos coloridos (`icon` e `color` de cada app em `Config.Apps`; sem ícone conhecido, a inicial do nome).
- **Dock**: até 6 apps fixos embaixo (padrão: os 5 primeiros do jogador). Botão direito num ícone fixa ou tira da dock. O último botão abre os **apps abertos**.
- **Multitarefa**: cada app aberto mantém o próprio estado ao voltar ao início ou trocar de app (até 6 em memória; o mais antigo fecha). Os apps continuam abertos ao guardar o tablet e ele volta no último app usado. **‹** volta ao início, **✕** fecha o app; na tela de apps abertos dá para trocar, fechar um ou fechar todos. Apps que o jogador perdeu (emprego, negócio) fecham sozinhos.
- **Central de controle**: brilho, tamanho da interface (P, M, G) e papel de parede (os mesmos do smartphone). Salvos por jogador em KVP local (`coe_tablet:prefs`), validados em `shared/prefs.lua` (teste: `lua test\prefs_test.lua`).
- ESC fecha a central ou os apps abertos; dentro de um app volta ao início; no início guarda o tablet.
- Apps de outros resources registram-se com `CoeTablet.register(id, render(container, api))` e usam as classes `tb-*` (`nui://coe_ui/html/apps.css`, as mesmas do smartphone `coe_phone`).

- Abrir: `/tablet` ou a tecla **F3** (`OpenKey`). Cada jogador pode trocar a tecla em Configurações → Teclas → FiveM (`Abrir tablet (COE OS)`). Sem aplicativos para o emprego, o tablet não abre. A ACE `coe_tablet.all` mostra todos os apps (admin/testes).
- Apps: `config.lua` (`Apps`) liga cada app a empregos (`jobs`), grau mínimo (`minGrade`), um resource que responde (`resource`) e um script de interface (`nui://<resource>/html/<arquivo>.js`).
- Segurança: o servidor revalida emprego e grau a cada ação (`coe_tablet:call`), limita taxa (`CallCooldownMs`) e payload (`MaxPayloadBytes`). O resource do app expõe `TabletCall(source, appId, action, payload, instance)` e só aceita chamadas do `coe_tablet`.
- App de oficina (`coe_mechanic`): escanear o veículo próximo, ver desgaste das peças, trocar uma peça ou fazer a revisão completa. Exige estar a até `TabletRadius` do veículo.
- App **Carreira** (`coe_jobs`, todos): histórico nos empregos livres — nível de carreira, reputação, habilidades e cada emprego com bônus, requisitos e GPS.
- App **Banco** (`coe_banking`): saldo, extrato, transferência, cartões, fatura e empréstimos.
- App **Veículos** (`coe_garages`): veículos do personagem, estado, garagem ou posição, com GPS.
- Apps de **negócio** (`coe_businesses`, `instances`): um por negócio de que o personagem é dono ou funcionário. O dono e os cargos com `business.remote` (gerentes) gerenciam a distância; o restante da equipe precisa estar de ponto naquele negócio (salvo negócio sem ponto obrigatório). Veja o README do `coe_businesses`.
- Apps de **facção** (`coe_factions`, `instances`): um por facção ativa do personagem, com membros, cargos e produção liberada (só leitura).
- App **Casa** (`coe_doors`): aparece para quem é dono de algum local de portas. Apps com `ownerCheck = true` só aparecem quando o export `TabletVisible(playerId, appId)` do resource do app retorna `true` (função `canSee` do perfil, reavaliada a cada ação).
- App **Esconderijo** (`coe_housing`): para o dono de um imóvel ilegal escolher quem mais tem acesso (`ownerCheck`).
- App **Aluguéis** (`coe_housing`): contratos de aluguel do jogador e dos negócios de que ele faz parte, com estado (em dia, vencido), diária, ciclo, próxima cobrança e botão de GPS (`ownerCheck`).
- **Loja** e apps instaláveis (`coe_apps`, `ownerCheck`): a Loja vem no sistema; Empregos, Classificados e Insta aparecem depois de instalados nela. Ver o README do `coe_apps`.
- API extra para os apps: `api.camera()` (o tablet sai da tela enquanto o jogador fotografa e volta com `{ ok, image }`), `api.upload(image)` (envia a foto ao servidor fora do canal das ações e devolve `{ ok, token }`), `api.refresh()` (recalcula a tela inicial sem fechar o app aberto) e `api.icon(node, app)`. Respostas com `data` maior que `LatentReplyBytes` (ex.: fotos) seguem por evento latente.
- Atalhos: cada entrada de `Shortcuts` cria um comando, sem item, que abre o mesmo tablet já dentro do primeiro app listado que o jogador vê (ex.: `/casa` abre Casa ou Esconderijo; **‹ Início** mostra os demais apps). Sem nenhum app do atalho visível, o jogador recebe o `deniedMessage` do atalho.
- Criar um app novo: registrar em `Apps`, criar o script que chama `CoeTablet.register(id, (container, api) => ...)` e implementar `TabletCall` no resource.
- Acesso aos apps de trabalho: por categoria de negócio em serviço (`categories`, ex.: `mdt` para quem está de ponto num negócio `police`), por instância (`instances`, ex.: `business` e `faction`) ou por grupo `job` do `coe_core` (`jobs`, ex.: `workshop` para `mechanic` em `coe_core/config/groups.lua` ou dono/equipe da oficina).
