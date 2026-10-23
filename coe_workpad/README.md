# coe_workpad

Tablet de trabalho básico do framework, focado em empregos e negócios. Abre com **F3** (cada jogador troca em Configurações > Teclas > FiveM, "Abrir tablet de trabalho"), com `/trabalho` ou usando o item, e só com o item `business_tablet` (Tablet de negócios) no inventário.

Tela inicial com relógio, o serviço atual (de ponto ou livre) e os apps em duas seções:

- **Trabalho**
  - **Ponto**: onde o personagem está de ponto e há quanto tempo, botão para encerrar o ponto e os locais de trabalho (dono ou equipe) com função, salário do cargo, regra de ponto e GPS até o relógio.
  - **Empregos livres** (`coe_jobs`): os empregos abertos a qualquer cidadão, com pagamento, depósito do veículo, o que você já ganhou, requisitos que faltam e GPS até o responsável. Filtro "Disponíveis para mim".
  - **Carreira** (`coe_jobs`, `html/career.js`): nível, reputação, habilidades e cada emprego com o guia "Como funciona".
- **Negócios**: um app por negócio de que o personagem é dono ou funcionário (`coe_businesses`, `html/tablet_app.js`), com resumo, financeiro, equipe, sócios, acessos, estrutura, frota, propriedades e as abas registradas por outros resources. O acesso segue as regras do negócio (dono e gerentes a distância; o resto da equipe de ponto).

Apps de resources parados não aparecem; os que o jogador perde com o tablet aberto fecham sozinhos. Até 6 apps ficam abertos em memória (o estado volta ao trocar de app). Esc volta ao início e, no início, guarda o tablet. Entrar em veículo, morrer ou abrir o menu de pausa também guarda.

## Apps de outros resources

O tablet segue o mesmo contrato dos tablets de pacote, então um app escrito para um serve no outro:

- Servidor: o resource expõe `TabletCall(playerId, appId, action, payload, instance)` (e `TabletInstances(playerId) -> { {id, label, category} }` para um app por instância). O tablet revalida a lista de apps a cada ação, limita a taxa (`CallCooldownMs`) e o tamanho do payload (`MaxPayloadBytes`) e passa a instância vinda do servidor, nunca do payload.
- Interface: o script (`nui://<resource>/html/<arquivo>.js`) chama `window.CoeTablet.register(id, function (container, api) { ... })`. A `api` tem `call(app, action, payload)`, `status(texto, tipo)`, `errorText(codigo)`, `waypoint(x, y)` e `refresh()`. Os componentes visuais são os `tb-*` de `nui://coe_ui/html/apps.css`.
- Um app novo entra em `config.lua` (`Apps`): `resource`, `script`, `group`, `order`, `icon` e, se for o caso, `instances`.

Acesso: o `coe_jobs` (app Carreira) e o `coe_businesses` (app Negócio e encerrar o ponto) têm o `coe_workpad` nos padrões (`TabletResources`, `ClockResources`). O app Ponto encerra só o ponto do próprio jogador.

## Pacotes que assumem o tablet

Um pacote com tablet completo chama o export `Yield()` ao iniciar (e de novo no `onResourceStart` do `coe_workpad`). O tablet básico fecha a tela e deixa de abrir (tecla, comando e item) até o resource chamador parar; então volta sozinho. A capacidade vem do `server.cfg`:

```
add_ace resource.<nome> coe.workpad.yield allow
```

O framework não cita o pacote pelo nome: o resource que assume vem do runtime. `Status()` devolve `{ active, yieldedBy }`.

## Configuração

`config.lua`: item, comando e tecla, seções, apps, rótulos das categorias de negócio, limite de taxa e de payload, ACE do `Yield` e a animação do tablet na mão.

## Interface

Aparelho em paisagem no visual do `coe_ui` (moldura e painéis chanfrados, cores só por tokens), acompanhando o tema do servidor e a cor do jogador (`@coe_ui/theme_bridge.lua`). Encerrar o ponto confirma pelo `CoeUI.confirm`.

## Testes

```
cd coe_workpad
lua test/rules_test.lua
lua test/server_test.lua
```

`server_test.lua` exercita o servidor com inventário, negócios e empregos simulados: item obrigatório, lista de apps com instâncias, encaminhamento para o resource do app, acesso revalidado a cada ação, limite de taxa e de payload, resource parado, Ponto (tempo e encerrar), Empregos livres, uso do item e o `Yield` de um pacote.
