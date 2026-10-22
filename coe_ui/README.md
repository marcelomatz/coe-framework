# coe_ui

Biblioteca de UI do framework Coe: tokens de design, componentes e API JS compartilhados por todas as NUIs. Sem dependências e sem build.

## Uso em outra NUI

No `fxmanifest.lua` do resource consumidor:

```lua
dependencies { 'coe_ui' }
```

No HTML:

```html
<link rel="stylesheet" href="nui://coe_ui/html/tokens.css">
<link rel="stylesheet" href="nui://coe_ui/html/components.css">
<script src="nui://coe_ui/html/components.js"></script>
```

## Conteúdo

- `tokens.css`: variáveis `--coe-*` (cores, espaçamento, tipografia, raio, z-index). Nunca use cores literais nas NUIs; use os tokens.
- `components.css`: classes `.coe-button` (`--primary`, `--danger`), `.coe-field`, `.coe-card`, `.coe-badge`, `.coe-modal*`.
- `surfaces.css` (carregar depois de `tokens.css`): visual "tech" discreto, sem neon. `.coe-glass` (painel translúcido, sem `backdrop-filter`, que na NUI do FiveM renderiza fundo preto), `.coe-chamfer` (cantos cortados, `--coe-chamfer`), `.coe-reticle` (mira; estados `is-visible` e `has-target`) e, em `callout.css`, `.coe-callout` (ações flutuando em perspectiva 3D sobre a mira, sem painel: `.coe-callout__stage` > `.coe-callout__list` > `.coe-callout__item` com `--i` para profundidade e entrada escalonada; `is-interactive` ativa o hover; `--rx`/`--ry` no stage inclinam com o mouse). Tokens de profundidade e movimento: `--coe-shadow-depth`, `--coe-ease`, `--coe-dur`, `--coe-dur-slow`. Respeita `prefers-reduced-motion`.
- `components.js`: `CoeUI.confirm({ title, message, confirmLabel, cancelLabel, danger })` → `Promise<boolean>`. Substitui `window.confirm`: foco preso no diálogo, Esc cancela, Enter confirma, foco volta ao elemento anterior, pedidos simultâneos são enfileirados. Em ações `danger` o foco inicial é o Cancelar.
- `prompt.css` + `prompt.js` (carregar depois de `perspective.css`): aviso de interação padrão (canto superior esquerdo), usado pelo ponto e pelas bancadas de todos os negócios. Cria o próprio elemento; envie `SendNUIMessage({ action = 'prompt', data = { title, subtitle, options = { { key = 'E', label = '...' } } } })` e `data = nil` para esconder.

## Temas

Cinco temas de cores (`moss` padrão, `ocean`, `amber`, `rose`, `violet`) definidos em `tokens.css` via `:root[data-coe-theme="nome"]` e listados em `config.lua`. O tema ativo é global, fica salvo no KVP do servidor e é trocado pelo painel admin (aba "Aparência", ACE `coe_admin.theme.manage`).

Para uma NUI acompanhar o tema:

1. Carregue `tokens.css` e `components.js` (o JS aplica `data-coe-theme` ao receber a mensagem `coe:theme`).
2. Adicione `'@coe_ui/theme_bridge.lua'` aos `client_scripts` do resource; ele entrega o tema inicial e as trocas em tempo real.
3. Use só `var(--coe-*)` e `rgba(var(--coe-accent-rgb), .2)` (também `--coe-ink-rgb` e `--coe-panel-rgb`) para transparências.

Novo tema: adicione o bloco em `tokens.css` e a entrada em `config.lua`.

Exports (server): `GetTheme()`, `GetThemes()`, `SetTheme(nome)` (só resources com a ACE `coe.ui.theme`, ex.: `add_ace resource.coe_admin coe.ui.theme allow`).

## Guia de estilos

`/coeui` (comando client) abre uma página com todos os componentes para revisão visual.

## Regras

- Componente novo entra aqui, com exemplo no guia de estilos, antes de ser usado em uma NUI.
- Classes sempre com prefixo `.coe-`; estilo específico de uma tela fica na própria NUI.
- Mudança que quebra classe ou API pede nova versão minor/major do repositório.

## Testes

Testes de DOM com jsdom (`confirm`: ARIA, Esc, Enter, foco, fila; tema, accent e mensagens NUI), executados no CI:

```
cd coe_ui
npm ci
npm test
```

## Cor do jogador

O jogador escolhe a cor em /hud. O coe_ui guarda a escolha no KVP local (coe_ui:accent) e o `theme_bridge.lua` a entrega a todas as NUIs (mensagem coe:accent, tratada em components.js). Cor escolhida sobrescreve o destaque do tema; em *Tema* vale o padrão do servidor. Exports: `GetAccent` e `SetAccent(nome)`.

## Referência da API

[Exports, parâmetros e códigos de erro](../reference/coe_ui.md), gerado de [`types.lua`](types.lua).
