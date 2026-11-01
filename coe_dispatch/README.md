# coe_dispatch

Despacho de chamados e alertas para **polícia** e **EMS**, plug-and-play sobre `coe_businesses`. Quem recebe é quem está **de ponto** em um negócio da categoria do chamado (`police` ou `ems`); não há lista paralela de jogadores. Pensado para ser usado por `coe_ems`, `coe_police`, heists e qualquer resource que precise chamar socorro ou força policial.

## Fluxo

1. Um resource (ou o cidadão) abre o chamado com um **código** (`robbery`, `shots_fired`, `person_down`...). O código define categoria, prioridade (1 = mais urgente) e rótulo; ver `config.lua`.
2. O servidor valida código e posição, **soma relatos** a um chamado igual por perto (`DedupeRadius`, `DedupeSeconds`) e envia aos que estão de ponto na categoria. No cliente aparece um blip (pisca na prioridade 1) e toca um aviso.
3. O policial/médico usa `/atender <id>` (marca a rota) e `/encerrar <id>`. Chamados vencem sozinhos em `TtlSeconds`.

## Comandos

- `/chamado <codigo>`: cidadão pede ajuda (`help_police`, `help_ems`) na própria posição, com intervalo de `CitizenCooldownSeconds`.
- `/chamados`: lista os chamados da sua categoria por urgência.
- `/atender <id>`, `/encerrar <id>`: exigem estar de ponto na categoria do chamado.

## API (servidor)

Só `ActionResources` chamam. Valor único ou `{ error = codigo }`.

- `Alert(codigo, x, y, z)`: abre (ou soma relato) e retorna o id do chamado.
- `Active(source)`: chamados visíveis para quem está de ponto.
- `Accept(source, id)`, `Close(source, id)`.

Eventos de servidor: `coe_dispatch:created (id, categoria, codigo, origem)`, `coe_dispatch:accepted (id, source)`, `coe_dispatch:closed (id, source)`. Eventos de cliente: `coe_dispatch:call`, `coe_dispatch:route`, `coe_dispatch:clear`.

## Integração

- `coe_ems` abre `person_down` ao paciente ficar inconsciente, se o `coe_dispatch` estiver ativo.
- Heists devem chamar `exports.coe_dispatch:Alert('store_robbery', x, y, z)` (o resource `coe_heists` já consta em `ActionResources`).
- `coe_deepweb` abre `suspicious_deal` (Negociação suspeita) em parte das vendas do contato da DeepWeb; `coe_loot` está em `ActionResources` para os scripts de roubo.
- Códigos novos: acrescente em `Codes` no `config.lua`.

## Limites desta fase

Chamados ficam em memória (efêmeros) e criação/encerramento vão para a auditoria. Fora desta fase: painel no MDT/tablet, alertas por disparo detectado no cliente, canais de rádio e histórico durável de chamados. Testes: `lua test/rules_test.lua`. Ordem no servidor: `ensure coe_dispatch` após `coe_businesses`.
