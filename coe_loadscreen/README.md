# coe_loadscreen

Tela de carregamento do Coe (NUI), no mesmo visual da seleção de personagem (`coe_characters`) e do criador
(`coe_appearance`):

- **Cena ao fundo** com câmera lenta (aproximação e deriva, como a câmera cinematográfica da seleção): o pôr do sol de
  Los Santos visto do Observatório, desenhado no próprio HTML (céu, sol, colinas de Vinewood, prédios com janelas que
  piscam e luzes de aviso), ou fotos suas em `html/backgrounds/` em sequência com transição suave. Granulado leve de
  filme por cima.
- **Mesma grade, tipografia, cartões e vinhetas** da seleção (`coe_characters`) e do criador (`coe_appearance`): marca no
  topo à esquerda (`COE · LOS SANTOS`), selo no topo à direita, etapas embaixo à esquerda (cartões `40x40` com barra de
  progresso individual, estado ao vivo, deslocamento `translateX(8px)` e barra lateral de destaque na etapa ativa) e, à
  direita, a etapa atual em destaque grande com a mensagem divertida ativa, chips e barra de progresso com brilho.
- **Ordem da folha de estilos (Temas)**: assim como `coe_characters` e `coe_appearance`, segue estritamente a cascata:
  1. **Tema padrão** (`:root` e `:root[data-coe-theme="..."]`)
  2. **Tema definido pelo usuário** (`:root[data-coe-user-theme="..."]`)
  Se o usuário não escolheu um tema, usa o tema padrão; se escolheu, sempre aplica o tema do usuário (entregue já na
  conexão via `deferrals.handover` pelo `coe_ui` e persistido em `localStorage`/KVP).
- **Etapas vivas e sincronizadas (sem caixa de dicas para manter o visual limpo)**: Conectando → Preparando o esquema →
  Abastecendo a cidade → Acendendo Los Santos → Entrando na cidade. As etapas avançam tanto pelos eventos nativos do
  FiveM (`loadProgress`, `startInitFunctionOrder`, `initFunctionInvoking`, `startDataFileEntries`, `onDataFileEntry`,
  `performMapLoadFunction`, `endDataFileEntries`) quanto pelos limiares (`floor`) da barra de progresso, com mensagens
  divertidas rotativas (como *"Calibrando lockpicks e pés de cabra…"*, *"Escondendo bancadas ilegais nos becos…"*).
  Clicar nas etapas ou no subtítulo do destaque sorteia outra atividade na hora.
- Respeita `prefers-reduced-motion` (sem câmera, brilho e piscadas).

## Ajustar

Tudo no topo do `html/app.js`:

| Chave | Uso |
|---|---|
| `CONFIG.eyebrow`, `title`, `subtitle`, `tag` | Textos da marca e do selo. |
| `CONFIG.backgrounds` | Nomes das fotos em `html/backgrounds/` (vazio: pôr do sol desenhado). `backgroundSeconds`: troca. |
| `CONFIG.activitySeconds` | Intervalo de troca automática das mensagens divertidas de cada etapa. |
| `STEPS` | Etapas, textos, `activities` (frases divertidas rotativas) e o mínimo da barra (`floor`) em cada uma. |

## Limites

- Declara `loadscreen 'html/index.html'` com `loadscreen_manual_shutdown 'yes'`: a tela fica até a seleção de personagem (`coe_characters`) estar com a cena 3D pronta, que então chama `ShutdownLoadingScreenNui`. Assim não aparece o jogo cru nem a interface sem cena entre o carregamento e a seleção.
- `client.lua` é só a rede de segurança: sem o `coe_characters` iniciado fecha a tela 5 s depois de o jogador ficar ativo; se a seleção travar, fecha em 60 s. Teste: `lua test\client_test.lua`.
- Carrega `nui://coe_ui/html/tokens.css`, `components.css` e `surfaces.css` e mantém os tokens de tema padrão e tema do
  usuário em `style.css` na mesma ordem para funcionar imediatamente desde o primeiro frame da conexão.
- A tela de carregamento não tem o jogo por trás, por isso a cena é desenhada (ou vem das fotos), e não a cena 3D da
  seleção.

## Usar

`ensure [coelho]` já inicia o resource. Mantenha **apenas um** resource com `loadscreen` no servidor; qualquer outro
(por exemplo o padrão de templates) deve ficar fora do `server.cfg`. Se ao conectar a tela antiga ainda aparecer, a
causa é outro resource de loadscreen iniciado ou o cache do cliente (limpe o cache do FiveM).
