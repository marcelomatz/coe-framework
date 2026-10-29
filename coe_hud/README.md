# coe_hud

HUD do jogador com painéis em perspectiva (`coe_ui/html/perspective.css`).

- Vida e colete no canto inferior; painel de veículo (velocidade, RPM, marcha, combustível, motor) quando o jogador dirige. Moto, barco e aeronave são identificados (`kind`); barco/aeronave não mostram marcha.
- `/hud` abre o **modo de edição** (ver abaixo); o botão *Preferências* da barra abre cor, estilo (vidro/sólido/mínimo), ícones (redondo/quadrado/hexágono), lado, unidade (km/h ou mph), tamanho e visibilidade. Tudo é salvo por jogador em KVP local e validado em `prefs.lua`.
- Desempenho: um loop (250 ms a pé, 100 ms dirigindo) que só envia mensagem ao NUI quando algum valor muda; CSS sem `backdrop-filter`, sem sombras grandes e sem animação contínua.
- Combustível usa `GetVehicleFuelLevel`; integre um resource de combustível via statebag/native se necessário.

- Fome, sede e estresse vêm do `coe_needs` (evento local `coe_needs:changed`) e podem ser ocultados em `/hud`.
- Veículo: teclas registradas com `RegisterKeyMapping` (mudam em Configurações > Teclado > FiveM): `B` cinto (impede ejeção pelo para-brisa e bloqueia sair do carro), `H` farol (apagado → baixo → alto; o farol nativo é bloqueado), setas `←`/`→` para as setas. O estado é zerado ao trocar de veículo ou descer.
- Vida, colete, fome, sede e estresse são ícones que se enchem conforme o valor, sem painel de fundo. Em `/hud`: cor (destaque), cores dos ícones (por status ou cor única; ao escolher uma cor, ela vale para todos os ícones, e só no modo *Tema* valem o padrão do servidor e as cores por status), formato (redondo, quadrado, hexágono) e *Mostrar porcentagem*.
- Minimapa: o HUD calcula a posição real do minimapa (safezone e proporção da tela, reavaliada a cada 0,5 s) e ancora os painéis ao lado dele, com moldura de cantos. Vida e colete nativos do minimapa são ocultados (as barras são do HUD). Em `/hud` > *Localização e bússola* o painel acima do minimapa mostra bússola, rua, região e hora, e os textos nativos de rua, região e veículo são ocultados.
- Próximas ruas (/hud > *Próximas ruas*): até 3 ruas a frente, com lado (← esquerda, → direita, ↑ em frente) e distância. `route.lua` amostra pontos ao longo do heading e dos lados e lê o nome da rua de cada um; o alcance cresce com a velocidade (180 a 600 m) e a leitura é refeita a cada 1 s.

Testes: `lua test\client_hud_test.lua`, `lua test\prefs_test.lua`, `lua test\route_test.lua` e, em `coe_hud`, `npm ci; npm test` (DOM com jsdom: `speedo.test.js` e `editor.test.js`, também no CI).

## Minimapa e bússola a pé

Em `/hud` > Preferências, **Minimapa** e **Bússola e localização** têm `Sempre` (padrão) ou `Só em veículo` (`minimapMode`, `locationMode`). No modo veículo eles aparecem para motorista e passageiro e somem ao descer; o loop do HUD que já existe detecta a troca (sem loop novo) e só chama `DisplayRadar` quando o estado muda. Vida e necessidades continuam no lugar ao lado do espaço do minimapa, sem pular ao entrar e sair. No modo de edição os dois aparecem mesmo a pé, para poderem ser posicionados.

## Esconder o HUD

Outros recursos escondem o HUD e o minimapa por motivo, usando o nome do recurso: `TriggerEvent('coe_hud:setHidden', GetCurrentResourceName(), true)` (ou `exports.coe_hud:SetHidden(motivo, true)`). O HUD só volta quando nenhum motivo restar; se o recurso que escondeu parar, o motivo dele é liberado. `exports.coe_hud:IsHidden()` informa o estado. Usado pela seleção (`coe_characters`) e pelo criador (`coe_appearance`).

A logo do servidor segue a preferência do jogador: `exports.coe_hud:SetLogoVisible(true|false)`, `IsLogoVisible()` e `ToggleLogo()` (mesmo efeito de `/logo`) devolvem o estado final. Contrato completo em [`types.lua`](types.lua) e na [referência da API](../reference/coe_hud.md).

## Velocímetros

Em `/hud` > *Velocímetro* o jogador escolhe o visual do painel de veículo; a escolha fica salva por jogador (`speedo` em `prefs.lua`).

| Opção | Visual |
| --- | --- |
| `panel` | Painel em perspectiva (padrão, comportamento anterior) |
| `modern` | Anel de velocidade com marcha, e anéis de motor e combustível |
| `modernpro` | Mostrador com arcos de velocidade (esquerda) e rotação (direita) e escala de marcas |
| `bold` | Velocidade grande com zeros apagados, barra de velocidade e barras de combustível e motor |
| `retro` | Velocidade grande, marcha, chips de motor e combustível e barra segmentada de rotação |
| `minimal` | Pílula compacta com marcha, velocidade, combustível e motor |
| `analog` | Relógios de rotação e velocidade com agulhas, e relógio de combustível |

A faixa de indicadores (setas, motor, farol baixo/alto, cinto, combustível baixo) é um componente próprio, usado com todos os estilos: por padrão fica logo acima do velocímetro e pode ser movida no modo de edição. O fundo de escala é 240 km/h ou 160 mph; barco e aeronave ocultam a marcha. A implementação está em `html/speedo.js` (templates SVG/HTML estáticos, atualização só do que mudou) e `html/speedo.css`.
## Modo de edição (`/hud`)

`/hud` abre o editor sobre o HUD (com foco do mouse); `/hud` de novo descarta. Componentes: **vida e necessidades** (`status`), **localização** (`location`), **minimapa** (`minimap`), **velocímetro** (`speedo`, painel ou estilos) e **indicadores** (`indicators`). Fora de um veículo o editor mostra um estado de exemplo, para tudo poder ser posicionado a pé.

- Arrastar a caixa move; a alça do canto redimensiona (50% a 200%, sobre o *Tamanho* global); o ícone de olho oculta/mostra (usa `showHealth`, `showLocation`, `showMinimap`, `showVehicle`, `showIndicators`).
- Barra: **Grade** (encaixe de 20 px e tamanho em passos de 5%), **Zona segura** (moldura da safezone do GTA), **Zonas de âncora** (posição padrão de cada componente; soltar com metade ou mais sobre a zona volta a ancorar), **Ocultos** (mostra componentes ocultos esmaecidos para posicionar). As opções ficam salvas (`editor`).
- **Desfazer/Refazer** (também `Ctrl+Z` / `Ctrl+Y`), **Restaurar padrão** (layout e visibilidade; cor e estilo ficam), **Descartar** (`Esc`) e **Concluir** (salva). As preferências abertas pelo editor entram no mesmo rascunho.
- Enquanto edita, o client só pré-visualiza (`hudPreview`, sem gravar KVP); `hudDone` grava e `hudDiscard` volta ao salvo.
- Formato salvo: `layout[componente] = { x, y, size }`. `x`/`y` são o canto superior esquerdo como fração da tela (0–1, 4 casas), então o layout vale em qualquer resolução; sem `x`/`y` o componente fica ancorado na posição padrão. `prefs.lua` limita tamanho e coordenadas, exige `x` e `y` juntos e descarta componentes desconhecidos.
- Minimapa: `minimap.lua` converte o retângulo escolhido em `SetMinimapComponentPosition` (minimapa, máscara e desfoque, deslocados e escalados a partir do canto padrão) e alterna o bigmap uma vez para o radar reler as posições. Vida/necessidades e localização ancorados continuam seguindo o minimapa movido, inclusive no estendido do `coe_map` (que abre a partir do canto do minimapa). Ao parar o recurso, o radar volta à posição padrão do GTA.
- Sem loops novos por frame: a reposição do radar é uma alternância única do bigmap.

## Ultrawide e 4K

Nas *Preferências* do `/hud`:

- **Área do HUD**: `Tela inteira` (padrão), `16:9` ou `21:9`. Em telas mais largas que a proporção escolhida, o HUD fica numa área centralizada: o minimapa nativo (`minimap.lua`, `MinimapLayout.Area`/`AreaBase`) e os componentes ancorados a ele entram na área, painéis do lado direito respeitam a margem dela e, no editor, a área aparece como moldura e limita o arraste. O `x` do layout passa a ser relativo à área, então o mesmo layout serve em 16:9 e 21:9. Em telas mais estreitas que a proporção, vale a tela inteira.
- **Escala automática pela resolução** (`autoScale`, ligada por padrão): o HUD escala pela altura da tela tomando 1080p como 100% (1440p ≈ 133%, 4K = 200%, limites de 50% a 300%); o *Tamanho* continua como ajuste fino por cima. Reavaliada ao redimensionar a janela.
