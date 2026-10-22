# coe_economy

Saldo por personagem, extrato (`coe_economy_ledger`) e operações atômicas. É a base de cobrança para residências, negócios e mecânica.

- Conta criada no primeiro uso com `StartingBalance` (`config.lua`).
- Valores sempre inteiros e positivos; saldo `BIGINT UNSIGNED`, então um débito além do saldo falha e desfaz a transação. O resource exige `sql_mode` estrito ao iniciar.
- Só resources autorizados chamam os exports; o nome vem do runtime. Padrão do framework (`AllowedResources`): `coe_economy`, `coe_businesses`, `coe_pausemenu`, `coe_jobs` e `coe_shops`. Os demais (pacotes comerciais e scripts de terceiros) recebem a ACE no `server.cfg`: `add_ace resource.<nome> coe.economy.money allow`. Pacotes de empregos pagam pelo `coe_jobs` e não precisam dela.

Exports (server): `GetBalance(characterId)`, `Credit(characterId, valor, motivo, referencia?)`, `Debit(...)`, `Transfer(deId, paraId, valor, motivo, referencia?)`. Retornam `true`/valor ou `nil, codigo` (`insufficient_funds`, `invalid_amount`, `balance_limit`, `same_account`, `forbidden`, `not_ready`...). `motivo` é `[a-z0-9_]{1,32}`.

> **Atenção:** chamado por `exports` a partir de outro resource, só o primeiro valor de retorno chega; o código de erro de `nil, codigo` se perde e o chamador vê só `nil`. Os exports novos (`Ledger`, `LedgerStats`, sociedade) já usam valor único ou `{ error = codigo }`. A padronização dos demais segue a mesma linha da #167.

`Summary()`: totais da economia para a Visão Geral do admin; só quem tem `coe.economy.admin` (ex.: `coe_admin`; senão `{ error = 'forbidden' }`).

`Ledger(characterId, limite?)`: extrato pessoal, mais recentes primeiro (`{ delta, reason, reference, created_at }`, até 100), ou `{ error = codigo }`. Usado pelo `coe_banking`.

`LedgerStats(characterId, dias, motivosIgnorados?)`: `{ firstAt, inflow }`: epoch do primeiro lançamento (ou nil) e soma das entradas dos últimos `dias` (1 a 365), sem os motivos ignorados (até 20); ou `{ error = codigo }`. Usado na pontuação de crédito do `coe_banking`.

Comandos: `/saldo` (jogador) e `coe_economy_credit <characterId> <valor>` (ACE `command.coe_economy_credit`).

Novos resources que cobram recebem `coe.economy.money` por ACE; não é preciso editar o `config.lua`. Capacidades: `coe.economy.money`, `coe.economy.society.collect`, `coe.economy.society.pay`, `coe.economy.society.bank` e `coe.economy.admin` (resumo, extratos e folha do painel de staff). `add_ace resource.<nome> coe.economy allow` concede todas.

## Contas de sociedade e folha

Cada negócio tem uma conta de sociedade (`coe_economy_societies`) com extrato próprio (`coe_economy_society_ledger`), criada no primeiro depósito. Exports (valor único ou `{ error = codigo }`):

- `SocietyBalance(businessId)`, `SocietyLedger(businessId, limite?)`.
- `SocietyDeposit(businessId, characterId, valor)`: dono ou equipe do próprio negócio, do saldo pessoal para a sociedade.
- `SocietyWithdraw(businessId, characterId, valor)`: exige a permissão de cargo `business.funds` (o dono tem tudo).
- `SocietyCredit(businessId, valor, motivo?)`: aporte administrativo, só `coe.economy.admin`.
- `SocietyCollect(businessId, valor, motivo)`: repasse de receita já debitada de um cidadão (ex.: multas, anúncios) ou estorno; só quem tem `coe.economy.society.collect` (padrão: `coe_shops`).
- `SocietyCharge(businessId, valor, motivo, referência?)`: despesa do negócio sem personagem (ex.: aluguel de imóvel comercial); só quem tem `coe.economy.society.pay`. Sem saldo: `insufficient_funds`.
- `RunPayroll(businessId)`: só o próprio `coe_economy`, `coe.economy.admin` e `coe.economy.society.bank`; retorna `{ paid, total, skipped }`.
- Conta bancária empresarial (só `coe.economy.society.bank`, ex.: `coe_banking`, que confere as permissões de cargo e registra quem fez): `BankSocietyPay(businessId, characterId, valor, motivo, referência?)` (caixa → conta pessoal), `BankSocietyDeposit(businessId, characterId, valor, motivo, referência?)` (conta pessoal → caixa, sem exigir que seja da equipe), `BankSocietyDebit`/`BankSocietyCredit(businessId, valor, motivo, referência?)` (saída/entrada sem conta pessoal: espécie, cartão, ajuste), `BankSocietyTransfer(deId, paraId, valor, motivo, referência?)` (entre empresas) e `BankSocietyLedger(businessId, filtro)` (extrato filtrado por direção, motivos, dias e página, com totais do período; também `coe.economy.admin`). Saldos e limites conferidos na transação; sem saldo: `insufficient_funds`.

Folha: a cada `PayrollIntervalMinutes` (padrão 30; 0 desliga) cada negócio ativo paga o salário do cargo (`coe_businesses:Payroll`), da sociedade para o personagem, **só a quem está de ponto**. Sem saldo na sociedade a pessoa não recebe e não há dívida acumulada (`skipped`: `off_duty`, `insufficient_funds`, `balance_limit`). Pagamentos e saques são atômicos. Evento de servidor: `coe_economy:payrollPaid` (businessId, pagos, total, pulados). Motivos de extrato: `society_deposit`, `society_withdraw`, `payroll`.

## Persistência e testes

Tabelas `coe_economy_accounts` e `coe_economy_ledger` (migração 1), `coe_economy_societies` e `coe_economy_society_ledger` (migração 2), versionadas em `server/migrations.lua`. Testes: `lua test/rules_test.lua` (validação de valores e motivos, filtro do extrato empresarial e transações sem buracos nos parâmetros). A integração MariaDB ainda não cobre a economia (#173).
