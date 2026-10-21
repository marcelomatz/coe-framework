# coe_map

Controle do mapa. O radar continua sendo desenhado pelo GTA; o `coe_map` decide o modo e o `coe_hud` acompanha o tamanho.

| Modo | Como | Controle do personagem |
| --- | --- | --- |
| Minimapa | padrao | mantido |
| Minimapa estendido | **Z** (alterna) | mantido |
| Mapa completo (pause map do GTA) | **M** ou `/destino` | tela de mapa |

- No mapa completo, marque o destino com Enter (nativo do GTA).
- Com o estendido aberto, um chip mostra a distancia ate o destino.
- `/destino limpar` ou a tecla "Coe: limpar destino" (sem tecla padrao) remove o destino.
- Todas as teclas sao rebindaveis em Configuracoes > Teclado > FiveM.
- O Z nativo (expandir radar) e desativado para nao conflitar.

## Integracao

- Evento local `coe_map:changed (mode, scale)` — o `coe_hud` reposiciona a moldura, o painel de local e os icones.
- Exports: `GetMode()` e `OpenFull()`.

## Ajuste

- `Config.ExtendedScale` (1.9): usado so pelo HUD para afastar icones e painel de local do minimapa estendido (bigmap nativo, sem moldura).
- `Config.FootZoom` (1250): zoom a pe; maior = mais afastado. `nil` usa o padrao do GTA.

## Testes

`lua test\client_map_test.lua` (na pasta do recurso).

## Referência da API

[Exports, parâmetros e códigos de erro](../reference/coe_map.md), gerado de [`types.lua`](types.lua).
