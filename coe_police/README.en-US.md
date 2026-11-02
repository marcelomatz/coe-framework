# coe_police

Police. Separate package from EMS; plug-and-play on top of `coe_businesses` and `coe_economy`. **Staff, roles, and salaries live in the business** in the `police` category (police stations): an officer must be clocked in at a `police` business and have the role permission. Payment comes from the society account (`coe_economy`).

## Role permissions

Registered in `coe_businesses` on startup (`RegisterPermissions`): `police.cuff` (cuff/uncuff), `police.fine` (issue fines), `police.jail` (arrest), `police.records` (criminal record), `police.search` (search), `police.seize` (seize), `police.escort` (escort). The business owner has all of them. Mark them in the **Roles** tab of `coe_admin`.

## Actions

All validated on the server: character, clock-in, category, role, target state, and distance (`ActionRange`). The target must have an active character; no one can act on themselves.

- **Cuff/uncuff:** `/algemar <id>`, `/soltar <id>`. A cuffed player cannot shoot or run.
- **Fine:** `/multar <id> <valor> <motivo>`; debits the target (`police_fine`, only if they have sufficient balance), transfers the proceeds to the officer's business society account (`SocietyCollect`, `FinesToSociety`), and records them in the criminal record.
- **Search:** `/revistar <id>` (`police.search`); target must be cuffed. Lists slot, label, and quantity; audited, and the target is notified.
- **Seize:** `/apreender <id> <slot> <qtd>` (`police.seize`); target must be cuffed. The item is transferred to the officer's inventory; if it does not fit, it is returned to the target.
- **Escort:** `/escoltar <id>` (`police.escort`), toggles. The cuffed target follows the officer; the escort ends if the target gets farther than `EscortMaxDistance`, is uncuffed, arrested, or the officer goes off duty.
- **Arrest:** `/prender <id> <minutos> <motivo>`; the target must be cuffed. The sentence (`coe_police_sentences`) survives reconnection: the prisoner returns to jail on joining and is released automatically when the sentence ends. `Jail` and `Release` in `config.lua`.
- `motivo` is a code matching `[a-z0-9_]{2,32}`, not free text.

## API (server)

Single Value or `{ error = codigo }`. Only `ActionResources` may call: `Cuff(policial, alvo)`, `Uncuff`, `Fine(policial, alvo, valor, motivo)`, `Arrest(policial, alvo, minutos, motivo)`, `Search(policial, alvo)` (list), `Seize(policial, alvo, slot, qtd)`, `Escort(policial, alvo)` (toggle), `Records(policial, characterId, limite?)`. Free reads: `IsCuffed(source)`, `IsJailed(source)`, `IsEscorted(source)`.

Server events: `coe_police:cuffChanged`, `coe_police:fined`, `coe_police:arrested`, `coe_police:released`, `coe_police:seized`, `coe_police:escortChanged`. Client events: `coe_police:cuffed`, `coe_police:jail`, `coe_police:release`, `coe_police:escort`.

## Criminal record

Table `coe_police_records` (target, officer, business, type `fine|arrest`, reason, amount, minutes). Every action is also audited.

## Out of scope for this phase

The MDT (`coe_mdt`, with search, incidents, warrants, and BOLO) and dispatch center (`coe_dispatch`) are separate packages. Locker/armory, prison work, helicopter, radar, and radio are planned for later phases (#124). Tests: `lua test/rules_test.lua`.
