# coe_races

Rachas pela cidade: corridas ilegais entre jogadores em pistas com checkpoints, organizadas pelo **tablet de
corridas** (item `race_tablet`), com entrada apostada em cripto (`coe_crypto`), ranking de pilotos, recordes por
pista e o risco de a polícia aparecer (`coe_dispatch`).

## Tablet de corridas

- Aparelho próprio (visual "RACHA//NET"): usar o item `race_tablet` ou `/corridas` (só com o item). Funciona a pé
  ou dentro do carro.
- O mesmo app aparece no COE OS (`coe_tablet`), no grupo **Ilegal**, para quem carrega o item.
- Abas: **Corridas** (abertas na cidade e a sua), **Organizar**, **Pistas** (com mapa, recordes e gravação),
  **Ranking** e **Histórico**.
- Primeiro acesso: o piloto escolhe um **vulgo** (único, 3–16 letras, números, `_` ou `-`). É o nome no grid, no
  ranking e nos recordes.

## Pistas

- **Sprint** (A → B) ou **circuito** (com voltas; a chegada é na própria largada, fechada automaticamente).
- Gravadas **dirigindo**: no tablet, "Gravar nova pista" (nome, descrição, tipo); depois, no carro, `Y` marca a
  largada (posição e direção do grid) e cada checkpoint, `U` desfaz, `Enter` salva e `Delete` cancela (teclas em
  Configurações > Teclas > FiveM). O servidor valida espaçamento mínimo (`MinSpacing`), de 3 a 60 checkpoints e
  coordenadas.
- Quem cria: pilotos com `MinRacesToCreate` corridas terminadas (até `MaxPerCreator` pistas cada) e a staff, sem
  limite.
- Moderação: a staff (`coe_races.admin`) destaca (★), oculta e reativa; o criador oculta e reativa a própria. Pista
  oculta some da lista e não recebe corridas novas.
- Recordes por pista: melhores voltas e melhores tempos totais por número de voltas.

## Corridas

1. **Organizar**: pista, voltas (circuito), classe de veículo, entrada, máximo de corredores e a largada em X
   minutos. O organizador pode correr ou só organizar, e pode largar antes do horário.
2. **Entrar**: com entrada, o piloto escolhe a carteira que paga (as do celular e as de papel/pen drive no
   inventário) e onde recebe o prêmio. A entrada fica na **custódia** do `coe_crypto` (`EscrowLock`) até o fim.
   Sair do lobby devolve a entrada.
3. **Grid**: na largada todos precisam estar perto do ponto de partida (`GridRadius`), no banco do motorista e com
   um veículo da classe. Quem não estiver sai com a entrada devolvida. Com menos de `MinRacers`, a corrida é
   cancelada e todos recebem de volta.
4. **Contagem**: carros presos, checkpoints na tela e **largada fantasma** — sem colisão entre os corredores do
   grid até `GhostSeconds` depois do "VAI".
5. **Prova**: o próximo checkpoint e o seguinte aparecem com seta (bandeira quadriculada na chegada), blip numerado
   e rota no GPS. O client avisa ao cruzar e o **servidor confere** ordem, posição (raio + folga), altura, velocidade
   plausível desde o último (anti-teleporte) e se é o mesmo veículo da largada; a hora é a do servidor. O HUD mostra
   posição, tempo, volta, checkpoint, melhor volta e o top 8.
6. **Chegada**: quando o primeiro cruza, os demais têm `FinishWindowSeconds` para terminar. Também abandona quem
   fica fora do carro por `OutOfVehicleSeconds`, desconecta, usa `/sairdacorrida` ou estoura o tempo máximo
   (`MaxSecondsPerKm`).

### Pote

- Pote = entrada × corredores que largaram. O organizador fica com `OrganizerFeeBps` (5%) na carteira que escolheu.
- O resto é dividido pela tabela `Payouts`, escolhida pelo número de corredores (2: 100%; 3+: 70/30; 5+: 60/25/15;
  8+: 50/25/15/10). Posições premiadas sem quem terminou e o arredondamento vão para o 1º.
- Ninguém terminou: todos recebem a entrada de volta. A taxa da rede cripto do envio não volta.
- Se o resource cair no meio, as entradas ainda na custódia são devolvidas na inicialização seguinte.

## Ranking

- Rating tipo Elo entre todos os pares de cada prova (`Rating.K` dividido pelos adversários), começa em 1000 e não
  cai abaixo de `Rating.Min`. Abandono conta como último.
- Carreira: corridas, vitórias, pódios, abandonos e prêmios. Histórico com as últimas `HistorySize` corridas.

## Polícia

- Na largada, chance de alerta `street_race` no `coe_dispatch` (`StartChance` + `PerRacer` por corredor além de
  dois, + `SirenBonus` com viatura de sirene ligada a `SirenRadius` do grid; teto `MaxChance`).
- Durante a prova, a cada `TickSeconds`, chance `TickChance` de novo alerta na posição do líder.

## Integração

- `coe_crypto`: `coe_races` em `Escrow.Callers` (`HeldWallets`, `EscrowLock`, `EscrowRelease`, `IsAddress`,
  `Format`). Sem `coe_crypto`, só corridas sem entrada.
- `coe_dispatch`: código `street_race` e `coe_races` em `ActionResources`.
- `coe_tablet`: app `races` (grupo `illegal`, `item = 'race_tablet'`), chamando `TabletCall`.
- `coe_phone`: a chave das carteiras do celular vem de `ActiveDevice` (`phone:<serial>`).
- Item `race_tablet` no `coe_inventory` do framework.
- ACEs em `permissions.cfg`: `coe.database`, `coe.audit`, `coe.logging`, `coe.notify`. Staff:
  `add_ace group.admin coe_races.admin allow`.

## Testes

```
lua test/rules_test.lua
lua test/server_test.lua
lua test/client_test.lua
```
