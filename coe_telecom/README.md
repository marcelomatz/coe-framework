# coe_telecom

Operadora de telefonia do COE OS. Cuida das linhas (pré-pago e pós-pago), tarifa ligações de voz, de vídeo e mensagens, gera as faturas do pós-pago e oferece o app **Minha linha** no smartphone (`coe_phone`).

É opcional: sem o `coe_telecom` iniciado, o celular continua funcionando e ligações e mensagens são grátis.

## Como funciona

- **Linha**: é do **número** (o chip do `coe_phone`), não do personagem. Nasce no primeiro uso, no plano `DefaultPlan` (pré-pago) com `StartingCredit` de crédito de boas-vindas. O **titular** do chip é quem paga mensalidade e faturas; quem estiver com o chip no celular pode ligar, recarregar e pagar faturas, mas só o titular troca de plano (`not_holder`). Linha sem titular (chip anônimo, ex.: descartável) só pode ser pré-paga (`holder_required`).
- **Migração**: linhas, faturas e extrato antigos (por personagem) passam para o número na primeira vez que o titular usa o chip.
- **Quem liga paga**: quem recebe a ligação não paga nada. A cobrança é por minuto iniciado, depois de `GraceSeconds` de tolerância.
- **Pré-pago**: antes de discar o telefone pergunta à operadora (`Authorize`). Sem crédito para um minuto, a ligação não sai (`no_credit`). Com crédito, a ligação cai sozinha quando ele acaba (motivo "Crédito esgotado"). A recarga é feita no app e debitada da conta do banco (`Recharges`, até `MaxBalance`).
- **Pós-pago**: mensalidade por ciclo de `CycleDays` dias. O plano Controle tem franquia de minutos (`allowance`) e cobra o excedente na fatura; o Ilimitado não tem excedente.
- **Fatura**: no fim do ciclo a fatura é gerada e o débito automático é tentado. Se a conta não tiver saldo, ela fica em aberto por `GraceDays` dias; depois disso a linha é **suspensa** (não liga nem manda mensagem, mas continua recebendo). Pagar todas as faturas em aberto pelo app reativa a linha.
- **Troca de plano**: uma vez a cada `PlanChangeHours`. Sair do pós-pago fecha o ciclo na hora, com a mensalidade proporcional. Para entrar no pós-pago a linha precisa estar ativa e sem faturas em aberto.
- **Mensagens**: o preço fica em `rates.sms` (0 = grátis). Linha suspensa não envia.

## Configuração (`config.lua`)

| Chave | Uso |
| --- | --- |
| `AllowedCallers` | Resources que podem chamar `Authorize`/`Charge` |
| `Carriers`, `DefaultCarrier` | Operadoras (nesta fase, só uma) |
| `Plans` | Planos: `kind` (`prepaid`/`postpaid`), `monthly`, `allowance`, `rates` |
| `StartingCredit`, `MaxBalance`, `Recharges` | Crédito do pré-pago |
| `CycleDays`, `GraceDays`, `PlanChangeHours` | Ciclo, carência e intervalo de troca |
| `TickSeconds`, `UsageKeepDays` | Rotina de faturamento e limpeza do extrato |

Os valores são inteiros (a economia só trabalha com inteiros).

## Exports

| Export | Quem usa | Retorno |
| --- | --- | --- |
| `Authorize(number, kind, holder)` | `coe_phone` | `{ ok = true, maxSeconds }` (nil = sem limite) ou `{ ok = false, error }` (`no_credit`, `line_suspended`) |
| `Charge(number, kind, seconds, peer, holder)` | `coe_phone` | `{ ok = true, cost }` |
| `LineOf(number)` | qualquer | `{ plan, carrier, status, balance }` |
| `TabletVisible` / `TabletCall` | `coe_phone` | App Minha linha (`overview`, `recharge`, `pay`, `plan`) |

`number`: só dígitos (`5550123`). `holder`: titular do chip (`nil` = sem titular), usado para criar a linha. `kind`: `voice`, `video` ou `sms`.

O app Minha linha mostra a linha do chip no celular em uso (`exports.coe_phone:ActiveLine`); sem chip responde `no_sim`.

## Banco

Débitos e estornos entram no extrato com os motivos `telecom` e `telecom_refund` (referências `recharge` e `invoice_<id>`).

## Tabelas

`coe_telecom_lines` (uma por número; `character_id` = titular), `coe_telecom_invoices` e `coe_telecom_usage` (com `number`; migrações em `server/migrations.lua`).

## Testes

```
lua test/telecom_test.lua
```

## Próximas fases

Operadoras de jogadores e antenas (#241), dados móveis (#242), banda larga e Wi-Fi (#243) e redes para hacking (#244).
