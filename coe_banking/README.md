# coe_banking

Sistema bancário sobre o `coe_economy`: agências, caixas eletrônicos, dinheiro em espécie, cartões com senha e contas empresariais.

Substitui o banco básico do framework (`coe_bank`): ao iniciar, e sempre que o `coe_bank` reinicia, chama o export `Yield` (ACE `coe.bank.yield` no `permissions.cfg`). O básico esconde as próprias agências, caixas e blips até o `coe_banking` parar. As agências e os motivos de extrato (`bank_withdraw`, `bank_deposit`, `bank_transfer`, `bank_refund`) são os mesmos, então o histórico do jogador continua coerente.

- **Conta**: o saldo é o do `coe_economy` (um por personagem). **Espécie** é o item `money` do inventário.
- **Agência** (balcão com prompt "E", blip "Banco"): saldo, saque e depósito em espécie, transferência por identidade (state ID, também para quem está offline), extrato e cartões. Quem é dono, equipe ou sócio de um negócio escolhe ao abrir: conta pessoal ou a conta de uma das empresas.
- **Caixa eletrônico** (mira em qualquer caixa dos modelos de `AtmModels`; é alvo de superfície, porque muitos caixas fazem parte do mapa e não aparecem como entidade para a mira): exige um `card_bank` no inventário e a senha de 4 dígitos. Saque (rápido ou outro valor), depósito, saldo e últimas movimentações, até `MaxAtmAmount` por operação.

## Cartões

- Emitidos na agência com senha definida pelo cliente; tarifa `CardFee` (debitada da conta). Uma nova emissão (2ª via) bloqueia o cartão anterior (`replaced`).
- **Validade** de `CardValidityDays` dias (padrão 60). Vencido, o cartão para de funcionar no caixa eletrônico e a agência oferece "Renovar cartão" (tarifa `CardRenewFee`, padrão 0). A renovação é uma nova emissão: nível, limite, pontos e histórico ficam na conta de crédito e não se perdem.
- **Cartão virtual**: pedido na agência, no internet banking (tablet) ou na Carteira do smartphone (tarifa `VirtualCardFee`, padrão 0). Não tem item nem senha e só existe na Carteira do celular; usa o mesmo crédito da conta. Um novo virtual substitui o anterior (`replaced`) e não mexe no físico.
- O item `card_bank` leva `metadata.cardId`. Quem estiver com o cartão e souber a senha usa a conta do titular (roubo faz parte do RP); o titular corta o acesso bloqueando o cartão na agência.
- `MaxPinAttempts` senhas erradas seguidas bloqueiam o cartão (`pin`); o titular desbloqueia definindo nova senha na agência. Bloqueio por perda/roubo (`lost`) e substituição são definitivos.
- A senha é guardada com salt e hash em rodadas (`PinHashRounds`), nunca em texto.

## Conta empresarial

O caixa de cada negócio (sociedade do `coe_economy`) é uma conta própria, separada da pessoal (`server/business.lua`, regras puras em `server/business_rules.lua`):

- **Acesso:** ao abrir a agência, quem é dono, equipe ou sócio de algum negócio escolhe a conta (pessoal ou empresa); **Trocar conta** volta à escolha. A conta da empresa tem resumo, seções e regras próprias.
- **Permissões de cargo** (registradas no `coe_businesses` com `RegisterPermissions`): `banking.view` (saldo, extrato e relatórios), `banking.withdraw` (sacar), `banking.transfer` (pagar e transferir), `banking.cards` (cartões empresariais), `banking.loans` (pagar empréstimos) e `banking.payroll` (folha e bônus). O dono tem tudo; qualquer permissão bancária libera ver a conta; qualquer pessoa do negócio deposita; sócios acompanham a conta. Quem tem a permissão antiga `business.funds` (`Business.LegacyPermission`) continua com acesso total até o dono ajustar os cargos.
- **Resumo e extrato:** resultado do período (hoje, 7, 30 ou 90 dias: entradas, saídas, saldo do período e lançamentos), alertas (empréstimo atrasado, caixa que não cobre a folha) e extrato filtrável por período, entradas/saídas e categoria (depósitos, saques, transferências, folha e bônus, cartões, empréstimos, receitas, despesas), paginado. Cada lançamento feito pelo banco mostra quem fez, para quem e a descrição (tabela `coe_banking_business_ops`, ligada ao extrato do `coe_economy` pela referência `bop:<id>`); salários e depósitos mostram o nome da pessoa.
- **Depósito e saque:** da conta pessoal ou em espécie (espécie só na agência). Fica no extrato com o nome de quem fez.
- **Transferências e pagamentos:** da empresa para uma pessoa (identidade; cai na conta pessoal, motivo `business_payment`) ou outra empresa (código do negócio; cai no caixa dela, `business_transfer`), com descrição, até `Business.MaxTransfer`.
- **Folha:** próxima folha (quem está de ponto recebe agora e quanto; quem está fora), aviso quando o caixa não cobre, pagar a folha agora (mesma regra da automática, export `RunPayroll` do `coe_economy`), bônus para alguém do negócio (`business_bonus`) e o que foi pago nos últimos 30 dias.
- **Cartões empresariais:** débito no caixa, emitidos na agência para alguém do negócio (dono ou equipe) com senha e limite diário (`Business.DefaultDailyLimit`, 0 = livre, até `MaxDailyLimit`); a tarifa (`Business.CardFee`) sai do caixa e o plástico (item `card_bank` com o nome da empresa) vai para quem pediu entregar ao titular. Funcionam no caixa eletrônico (saque e depósito no caixa da empresa, `Business.AtmFee`) e na Carteira do celular (compras via `CardPurchase`/`CardRefund`, débito no caixa). O limite do dia é reservado de forma atômica; operação desfeita devolve ao limite. O cartão para de funcionar se o titular sair do negócio. Até `Business.MaxCards` cartões ativos por empresa; limite, troca de senha e bloqueio pela conta da empresa.
- **Empréstimos:** os empréstimos empresariais e o pedido ao banco (só o dono, na agência) ficam na conta da empresa; o pagamento pelo caixa exige `banking.loans`. Qualquer devedor continua podendo pagar pela conta pessoal (aba Crédito).
- **Tablet:** aba **Banco** no app de cada negócio, registrada com `coe_businesses:RegisterTab` (substitui o Financeiro; handler `BusinessTablet`, só aceito do `coe_businesses`; tela em `window.CoeBusinessTabs.bank` no `html/business.js`): resumo, extrato, transferências, cartões (limite e bloqueio), folha, bônus e pagamento de empréstimos, com as mesmas permissões. Espécie, emissão de cartão, troca de senha e pedido de empréstimo são só na agência.
- **Admin** (Banco > Empresas): lista de contas com saldo, cartões e empréstimos; por conta, extrato com quem fez cada operação, ajuste do caixa pela staff (`admin_adjustment`) e cartões (limite, bloqueio, desbloqueio e validade). Exports `AdminBusinessAccounts`, `AdminBusinessAccount`, `AdminBusinessAdjust` e `AdminBusinessCardLimit` (só `coe_admin`).

A interface (`html/business.js` + `html/bank-ui.css`) é a mesma na agência e no tablet.

## Crédito

O cartão é múltiplo: débito na conta e crédito no nível da conta de crédito (um por personagem, aba "Crédito" da agência).

- **Relacionamento (0 a 1000)**: idade da conta (1º lançamento do extrato), entradas dos últimos `InflowDays` dias (sem estornos, depósitos de espécie, transferências e ajustes, para não inflar com saque e depósito), saldo atual e histórico de faturas (em dia soma, atraso subtrai; atraso atual pesa `LateNowPenalty`).
- **Níveis** (`Credit.Tiers`): Essencial, Gold, Platinum e Black, com pontuação mínima, limite, pontos a cada $ 100 no crédito, anuidade por fatura e saque grátis no caixa eletrônico. O cliente pede o cartão ou o upgrade na agência; o nível cai um degrau no fechamento se a pontuação ficar `DowngradeMargin` abaixo do mínimo. O `config.lua` só semeia a tabela `coe_banking_tiers` na primeira subida; depois os níveis são editados no painel admin (aba Banco).
- **Limite personalizado e trava**: a staff pode fixar um limite próprio (até `Credit.AdminMaxLimit`) e travar o nível para que não seja rebaixado.
- **Fatura**: fecha a cada `CycleDays` dias e vence `DueDays` depois. Mínimo de `MinPaymentRate` (piso `MinPaymentFloor`). Saldo não pago entra no rotativo (`RevolvingRate` no fechamento seguinte). Pagamento na agência: total, mínimo ou valor livre (motivo `card_invoice`).
- **Atraso**: multa (`LateFeeRate` + `LateFeeFlat`), juros diários (`LateDailyRate`), crédito bloqueado até pagar o mínimo e débito automático do saldo após `AutoDebitDays` dias.
- Um laço no servidor processa fechamentos, vencimentos e juros a cada `TickSeconds`, mesmo com o titular offline. Cada conta tem trava por personagem e gravação otimista (`version`).
- **Caixa eletrônico**: tarifa `AtmWithdrawFee` por saque (motivo `atm_fee`), isenta nos níveis com `freeAtm`.

- **Carteira digital** (exports só para `WalletCallers`, hoje `coe_phone`): `WalletEligible(playerId)` lista os cartões que podem entrar (físicos ativos no inventário e o virtual ativo do personagem); `WalletLink(playerId, cardId, pin)` valida o vínculo (`BankingRules.CanLink`: virtual só do titular; físico em mãos e com a senha, e senha errada conta tentativas como no caixa eletrônico); `WalletCards(ids)` devolve a situação de até 10 cartões; `WalletIssueVirtual(playerId)` emite o virtual.
- **Compras no crédito** (`CardPurchase(cardId, amount, description)` e `CardRefund(cardId, amount, description)`): só para os resources de `Credit.PurchaseCallers` (hoje `coe_apps`, `coe_amzg`, `coe_shops`, `coe_fuel` e `coe_phone`, que cobra a Carteira nas lojas), até `MaxPurchase` por compra, cobrando no crédito do titular da conta do cartão. A compra exige o cartão ativo (não bloqueado nem vencido), mas não em mãos: quem paga escolhe o cartão na Carteira do smartphone. Entra nas compras em aberto da fatura (lançamento `purchase`) e soma pontos; o estorno abate primeiro as compras em aberto e depois a fatura fechada (lançamento `refund`). Devolvem `{ ok, points, available }` / `{ ok, refunded }` ou `{ ok = false, error }` (`no_card`, `card_blocked`, `card_expired`, `no_credit`, `credit_late`, `credit_limit`, `busy`).
- **Maquininha** (`PosCards(playerId)` e `PosPurchase(playerId, cardId, pin, amount, description)`, mesmos chamadores de `Credit.PurchaseCallers`): compra presencial com o **cartão físico em mãos**. `PosCards` lista os cartões ativos no inventário do jogador (`{ id, last4, holder, business }`); `PosPurchase` confere o cartão no inventário e a senha (as mesmas tentativas do caixa eletrônico: `wrong_pin` com `left`, depois `card_blocked`) e cobra como `CardPurchase` (crédito do titular, ou débito no caixa para cartão empresarial). Nas lojas do `coe_shops` entra como o meio `card` (`RegisterPaymentMethod`, kind `pin`), pelos exports `ShopOptions`, `ShopCharge` e `ShopRefund`; o registro se repete quando o `coe_shops` ou o `coe_businesses` reiniciam.

## Empréstimos

Concedidos pela staff (aba Banco do admin): valor, juros totais (%) e número de parcelas, dentro dos tetos de `Loans` (`MaxPrincipal`, `MaxRate`, `MaxInstallments`, `MaxActive`). O valor cai na conta (motivo `bank_loan`) e as parcelas vencem a cada `IntervalDays` dias com débito automático do saldo. Parcela não paga fica em atraso (conta no relacionamento) até haver saldo. Na aba "Crédito" da agência o cliente paga a parcela ou quita antes (motivo `loan_payment`). A staff pode perdoar o saldo (já com os juros de atraso).

- **Taxas pelo relacionamento** (`Loans.Pricing`): faixas `{ minScore, rate, lateDailyRate }`. Quanto melhor a pontuação, menores os juros do contrato (sugeridos à staff) e os juros diários de atraso. Os juros de atraso ficam fixos no contrato.
- **Juros diários de atraso**: parcela vencida rende juros compostos por dia inteiro de atraso sobre o valor em aberto da parcela (lançamento `loan_interest` no histórico de crédito). Cada passada aplica no máximo `MaxAccrueDays` dias; o resto entra na seguinte. Pagar a parcela encerra os juros dela.
- **Empréstimo empresarial**: o proprietário pede na conta da empresa, na agência (valor, parcelas e finalidade); o pedido vai para a fila da staff (admin, Banco > Pedidos), que aprova (podendo ajustar juros e parcelas) ou recusa com motivo. Um pedido pendente e `MaxActiveBusiness` empréstimo ativo por negócio; se o negócio mudar de dono antes da decisão, a aprovação é recusada (`owner_changed`). Aprovado, o valor cai no caixa do negócio (motivo `bank_loan`) e a dívida fica registrada em nome do proprietário e dos sócios do momento (`coe_banking_loan_debtors`). A pontuação usada é a média dos devedores. As parcelas saem do caixa (motivo `loan_payment`); se o caixa não cobrir, a parcela atrasa, corre juros e o atraso pesa no relacionamento de todos os devedores. Quem tem `banking.loans` paga pelo caixa na conta da empresa (agência ou tablet); qualquer devedor também pode pagar pela conta pessoal (aba "Crédito").

## Exports de administração

Só aceitam chamadas do `coe_admin` e devolvem `true` ou `{ error }`: `AdminTiers`, `AdminSaveTiers`, `AdminAccount`, `AdminSetCredit`, `AdminPoints`, `AdminCard` (`block`, `unblock`, `extend`), `AdminGrantLoan`, `AdminForgiveLoan`, `AdminLoanRequests` e `AdminDecideRequest`.
## Consistência

Conta e inventário são resources separados; as operações usam compensação:

- Saque: debita a conta e entrega a espécie; se não couber no inventário, estorna (`bank_refund`).
- Depósito: retira a espécie e credita; se o crédito falhar, devolve a espécie.
- Conta empresarial: cada operação é registrada antes de mover o dinheiro (pendente → concluída ou falha); espécie entregue depois do débito volta ao caixa se não couber no inventário; depósito em espécie que falha devolve a espécie.

Falha de estorno é registrada em log (`refund_failed`). Motivos de extrato: `bank_withdraw`, `bank_deposit`, `bank_transfer` (referência `state:<ID>`), `bank_refund`, `card_fee`, `card_invoice`, `atm_fee`.

## Configuração

`config.lua`: tarifa, tentativas de senha, tetos por operação, valores de saque rápido, tamanhos de extrato, tempo da sessão do caixa eletrônico, modelos de caixa eletrônico e agências (`id`, `label`, coordenadas e `radius`).

## Persistência

Tabelas `coe_banking_cards` (com `expires_at`), `coe_banking_credit` (com `custom_limit` e `tier_locked`), `coe_banking_credit_entries`, `coe_banking_tiers`, `coe_banking_loans` (com `late_rate`, `interest`, `interest_at` e o negócio), `coe_banking_loan_debtors` e `coe_banking_loan_requests` (migrações versionadas em `server/migrations.lua`, controle em `coe_banking_schema_migrations`; a v3 preenche a validade dos cartões existentes com a data de emissão + 60 dias; a v4 deixa os empréstimos existentes sem juros de atraso e registra o titular como devedor; a v5 adiciona `kind` aos cartões: `physical` ou `virtual`; a v6 adiciona o limite diário dos cartões empresariais (`daily_limit`, `spent_amount`, `spent_day`) e `coe_banking_business_ops`). Cartão empresarial: `account_type = 'business'` e `account_ref` = id do negócio.

## Testes

```
cd coe_banking
lua test/banking_test.lua
lua test/credit_test.lua
lua test/loan_test.lua
lua test/tablet_test.lua
lua test/business_test.lua
lua test/business_flow_test.lua
```

`business_test.lua` cobre as regras da conta empresarial (permissões, limite diário, destino, filtro e categorias do extrato, folha prevista); `business_flow_test.lua` exercita `server/business.lua` com banco, economia, negócios e inventário simulados (depósito, saque, transferências, bônus, folha, emissão e limite de cartão, caixa eletrônico, compra pela carteira, titular que saiu, visão, tablet e admin).

## Interface

Agência e caixa eletrônico usam a mesma página (`html/`), no visual do `coe_ui`: painel chanfrado (`coe-panel`), botões e campos `coe-*`, cores só por tokens. Acompanham o tema do servidor e a cor escolhida pelo jogador em `/hud` (`@coe_ui/theme_bridge.lua`; a página pede o tema a cada abertura).

- **Agência:** resumo lateral (saldo, espécie, crédito disponível e relacionamento) e seções Conta, Cartões e Crédito na conta pessoal (Resumo, Extrato, Transferir, Cartões, Folha e Empréstimos na empresarial); um ponto vermelho marca a seção com algo atrasado ou sem cartão ativo.
- **Crédito:** a meta de pontuação é sempre o primeiro nível acima do maior entre o nível atual e o liberado pela pontuação. Quem recebeu upgrade (inclusive do banco, acima da pontuação atual) não vê "faltam X pontos" para o nível que já tem ou para os de baixo; esses aparecem como "Seu nível" e "Abaixo do seu nível".
- **Caixa eletrônico:** escolha do cartão, senha com teclado na tela ou no teclado físico (dígitos, Backspace, Enter), saque rápido, outro valor, depósito e últimas movimentações.

## COE OS

App **Banco** do `coe_tablet` (`html/tablet_app.js`, `server/tablet.lua`, export `TabletCall`, só aceito do `coe_tablet`): saldo, cartões (com pedido do cartão virtual) e extrato; transferência por ID de cidadão; bloqueio de cartão; pagamento da fatura (mínimo ou total) e de empréstimos (parcela ou total). Usa as mesmas regras e limites da agência.
