# coe_pausemenu

Menu de Pausa customizado (`ESC`) do framework **COE Enhanced Roleplay**, substituindo o menu padrão do FiveM com a identidade visual do framework, telemetria em tempo real, dossiê do personagem e atalhos rápidos.

## Características

- **Interceptação Nativa do ESC**: Substitui o menu nativo de pausa do GTA V / FiveM sem conflitos.
- **Identidade Visual COE**: Integrado com tokens, variáveis e temas de `coe_ui` (Cyberpunk / Tactical dark theme).
- **Telemetria do Servidor**: Status online, contagem de jogadores, ping, horário in-game e uptime.
- **Dossiê do Cidadão**: Nome completo, passaporte (`stateId`), profissão, facção, localização e saldo bancário.
- **Acesso Integrado ao Mapa GTA**: Opção que abre o mapa nativo completo com waypoints sem desativar a interceptação posterior.
- **Acesso ao Editor de HUD**: Atalho direto para `/hud`.
- **Configurações Nativas**: Atalho para ajustes de áudio, vídeo e gráficos nativos do GTA V.
- **Guia de Regras & Atalhos**: Painel de regras da cidade e lista das principais teclas.
- **Desconexão Segura**: Diálogo com confirmação prévia antes de desconectar.

## Exports

### Client
- `exports.coe_pausemenu:IsOpen()` -> `boolean`
- `exports.coe_pausemenu:Toggle(open)` -> Alterna ou define a visibilidade do menu.

## Testes

```bash
# Testes unitários Lua (regras, cliente e servidor)
lua test/rules_test.lua
lua test/server_pause_test.lua
lua test/client_pause_test.lua

# Testes automatizados de DOM / NUI
npm test
```
