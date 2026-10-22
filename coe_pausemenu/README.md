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

### Server
- `exports.coe_pausemenu:RegisterFactionProvider(exportName)` -> `true` ou `{ error }`: a facção do dossiê vem do
  export `exportName` do resource chamador, `(characterId) -> { label, grade }` ou `nil`. Exige a ACE
  `coe.pausemenu.profile` (`add_ace resource.<nome> coe.pausemenu.profile allow`); o registro some quando o resource
  para (registre de novo no `onResourceStart` do `coe_pausemenu`). Sem provedor, vale o grupo do tipo `faction` do core.

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
