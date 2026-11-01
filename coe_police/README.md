# coe_police

Polícia. Pacote separado do EMS; plug-and-play sobre `coe_businesses` e `coe_economy`. **Equipe, cargos e salários vivem no negócio** da categoria `police` (Delegacias): o policial precisa estar de ponto num negócio `police` e ter a permissão no cargo. O pagamento sai da conta de sociedade (`coe_economy`).

## Permissões de cargo

Registradas no `coe_businesses` ao iniciar (`RegisterPermissions`): `police.cuff` (algemar/soltar), `police.fine` (multar), `police.jail` (prender), `police.records` (ficha criminal), `police.search` (revistar), `police.seize` (apreender), `police.escort` (escoltar). O dono do negócio tem todas. Marque-as na aba **Cargos** do `coe_admin`.

## Ações

Todas validadas no servidor: personagem, ponto, categoria, cargo, estado do alvo e distância (`ActionRange`). Quem for alvo precisa ter personagem ativo; ninguém age sobre si mesmo.

- **Algemar/soltar:** `/algemar <id>`, `/soltar <id>`. Algemado não atira nem corre.
- **Multar:** `/multar <id> <valor> <motivo>`; debita do alvo (`police_fine`, só com saldo), repassa a receita à conta de sociedade do negócio do policial (`SocietyCollect`, `FinesToSociety`) e grava na ficha.
- **Revistar:** `/revistar <id>` (`police.search`); alvo algemado. Lista slot, rótulo e quantidade; auditada e o alvo é avisado.
- **Apreender:** `/apreender <id> <slot> <qtd>` (`police.seize`); alvo algemado. O item passa ao inventário do policial; se ele não couber, volta ao alvo.
- **Escoltar:** `/escoltar <id>` (`police.escort`), alterna. O alvo algemado segue o policial; a escolta cai se ele se afastar mais de `EscortMaxDistance`, soltar a algema, for preso ou o policial sair de serviço.
- **Prender:** `/prender <id> <minutos> <motivo>`; o alvo precisa estar algemado. A pena (`coe_police_sentences`) sobrevive a reconexão: o preso volta à cela ao entrar e é solto sozinho quando acaba. `Jail` e `Release` em `config.lua`.
- `motivo` é um código `[a-z0-9_]{2,32}`, sem texto livre.

## API (servidor)

Valor único ou `{ error = codigo }`. Só `ActionResources` chamam: `Cuff(policial, alvo)`, `Uncuff`, `Fine(policial, alvo, valor, motivo)`, `Arrest(policial, alvo, minutos, motivo)`, `Search(policial, alvo)` (lista), `Seize(policial, alvo, slot, qtd)`, `Escort(policial, alvo)` (alterna), `Records(policial, characterId, limite?)`. Leitura livre: `IsCuffed(source)`, `IsJailed(source)`, `IsEscorted(source)`.

Eventos de servidor: `coe_police:cuffChanged`, `coe_police:fined`, `coe_police:arrested`, `coe_police:released`, `coe_police:seized`, `coe_police:escortChanged`. Eventos de cliente: `coe_police:cuffed`, `coe_police:jail`, `coe_police:release`, `coe_police:escort`.

## Ficha criminal

Tabela `coe_police_records` (alvo, policial, negócio, tipo `fine|arrest`, motivo, valor, minutos). Cada ação vai também para a auditoria.

## Fora desta fase

O MDT (`coe_mdt`, com busca, ocorrências, mandados e BOLO) e a central de chamados (`coe_dispatch`) vivem em pacotes próprios. Armário/arsenal, trabalho na prisão, helicóptero, radar e rádio ficam para as próximas fases (#124). Testes: `lua test/rules_test.lua`.
