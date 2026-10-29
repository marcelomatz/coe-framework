# coe_spawn

Adaptador client que mantém o spawnmanager desabilitado até receber do servidor a confirmação de personagem carregado. Antes da seleção, o jogador fica sem controle e invisível; ao trocar de personagem, o estado é removido e o jogador retorna à seleção. Após a seleção, o `spawnmanager` realiza o spawn inicial e os respawns.

## Última posição

O personagem volta onde estava ao sair (`CoeSpawnConfig.LastPosition`). O servidor lê a posição do ped a cada `SampleMs` (5 s), só depois do spawn e só no mundo normal (routing bucket 0). Dentro de imóveis e visitas do admin vale a última posição na rua, e o `coe_housing` leva de volta ao interior quem saiu dentro do imóvel. O cliente nunca envia coordenadas. A posição vai para a tabela `coe_spawn_positions` (migration em `server/migrations.lua`) a cada `FlushMs` (60 s), ao trocar de personagem e ao sair.

Ao carregar o personagem, o cliente pede a posição (`coe_spawn:requestPosition`) e só então chama o `spawnmanager`. Sem posição salva (primeiro acesso), com posição inválida ou sem resposta em `TimeoutMs`, usa `CoeSpawnConfig.location`. Respawns seguintes (ex.: após a morte) usam `location`.

O ponto inicial (primeiro acesso) está em [config.lua](./config.lua). Ajuste `CoeSpawnConfig.location` para as coordenadas e heading do mapa utilizado. Com aparência salva (vem no `player.characterLoaded`), o spawn usa o modelo dela e aplica a aparência com o `coe_appearance` (também nos respawns). Sem aparência (personagem antigo, ou sem o `coe_appearance` iniciado), sorteia um ped de `CoeSpawnConfig.models` (peds comuns): um ped freemode sem head blend fica sem rosto. O fade in final é de 500 ms, depois da aparência aplicada. Após o spawn, o adaptador torna o ped visível, remove o congelamento e devolve o controle ao jogador, pois esses estados são alterados durante a seleção. `CoeSpawnConfig.Debug = true` imprime as etapas no console F8 (`[coe_spawn] ...`), incluindo um dump do estado do ped, da câmera e da hora do jogo após o spawn; desative após validar.

Antes da seleção, o adaptador também encerra a tela de loading (`ShutdownLoadingScreen`/`ShutdownLoadingScreenNui`) e faz fade-in, porque com auto-spawn desligado o `spawnmanager` não o faz e a tela ocultaria a UI de seleção.

Este resource não altera `spawnmanager` nem os resources distribuídos pela Cfx. Não inicie `basic-gamemode` junto deste fluxo: ele ativa respawn sem aguardar o estado autoritativo do Core.

## Hotel de nascimento

`exports.coe_spawn:GetStarterHotel()` devolve a configuração atual do hotel onde o personagem novo nasce; `SetStarterHotel(dados)` salva e sincroniza com os jogadores conectados (`true` ou `false, codigo`). O painel `coe_staff` usa os dois. Contrato em [`types.lua`](types.lua).

## Arquivos e testes

- `config.lua`: coordenadas e heading do spawn inicial e ajustes da última posição.
- `shared/positions.lua`: validação e arredondamento da posição (puro).
- `server/main.lua`, `server/persistence.lua`, `server/migrations.lua`: leitura da posição no servidor e gravação em `coe_spawn_positions`.
- `client.lua`: bloqueia auto-spawn até seleção, valida origem de eventos do Core, pede a última posição e delega o spawn ao `spawnmanager`.
- `fxmanifest.lua`: dependências e ordem de carregamento.

Execute `lua test\client_test.lua` e `lua test\positions_test.lua` na pasta do resource. Os testes cobrem origem confiável dos eventos, bloqueio do jogador, registro de callback, spawn na última posição com fallback para o ponto configurado, validação de posição, retorno à seleção e o uso da aparência salva (modelo, aplicação e respawn; sorteio para quem não tem). Natives de spawn/controle, sincronização real de rede e comportamento no Enhanced precisam de smoke test in-game; veja [TEST_COVERAGE.md](../TEST_COVERAGE.md).
