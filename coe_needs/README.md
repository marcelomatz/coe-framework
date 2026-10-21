# coe_needs

Fome, sede e estresse por personagem. Escala 0-100: fome/sede 100 = saciado; estresse 0 = calmo.

## Como funciona

- **Servidor autoritativo.** O client só informa a *atividade* (`idle`, `walk`, `run`, `sprint`, `swim`, `drive`, `driveFast`, `combat`); o servidor valida a chave, mede o tempo (limite de 30 s por avanço) e aplica as taxas por minuto de `Config.Needs.Rates`. Mensagens repetidas em menos de 800 ms são ignoradas.
- **Persistência.** Tabela `coe_needs_state` por `character_id` (migração própria), salva a cada 60 s, ao trocar de personagem, ao sair e ao parar o resource. Se a leitura falhar, o estado não é gravado por cima do banco.
- **Consumo de itens.** `inventory.itemUsed` aplica `Config.Needs.ItemEffects[item]` (ex.: `burger = { hunger = 35 }`).
- **Efeitos no ped** (client): recuperação nativa de vida desligada; vida regenera devagar com fome e sede ≥ 60 e estresse ≤ 70; fome ou sede zeradas tiram vida (nunca abaixo de 105); abaixo de 20 a corrida fica mais lenta e zerado o sprint é bloqueado (com aviso ao jogador); estresse ≥ 60/85 treme a câmera.

## API

Servidor: `exports.coe_needs:GetNeeds(source)`, `AddNeed(source, 'stress', 5)`, `SetNeed(source, 'hunger', 50)` (`AddNeed`/`SetNeed` só para resources em `Config.Needs.AllowedResources`; retornam `true` ou um código de erro). Roubos, crimes e eventos devem chamar `AddNeed(source, 'stress', n)`.

Client: `exports.coe_needs:GetState()` e o evento local `coe_needs:changed`.

Testes: `lua test\needs_test.lua` e `lua test\service_test.lua`.

## Referência da API

[Exports, parâmetros e códigos de erro](../reference/coe_needs.md), gerado de [`types.lua`](types.lua).
