# coe_bank

Banco básico do framework: a conta do personagem no dia a dia, sem produtos bancários.

- **Conta**: o saldo é o do `coe_economy` (um por personagem). **Espécie** é o item `money` do `coe_inventory`.
- **Agência** (balcão com prompt "E", blip "Banco"): saldo, saque, depósito, transferência por ID de cidadão e extrato, até `MaxAgencyAmount` por operação.
- **Caixa eletrônico** (mira em qualquer caixa dos modelos de `AtmModels`; alvo de superfície, porque muitos caixas fazem parte do mapa): saldo, saque, depósito e últimas movimentações da conta do próprio personagem, até `MaxAtmAmount` por operação. Sem cartão nem senha.
- **Transferência**: pelo ID de cidadão (o mesmo do comando `/id`), também para quem está offline. A tela mostra o nome do destinatário e pede confirmação antes de enviar. Quem recebe e está online é avisado.

Fora do banco básico (ficam para pacotes): cartões e senha, crédito e fatura, empréstimos, contas empresariais, tarifas e internet banking.

## Pacotes que assumem o banco

Um pacote com banco completo chama o export `Yield()` ao iniciar (e de novo no `onResourceStart` do `coe_bank`). O banco básico esconde agências, caixas eletrônicos e blips, fecha as telas abertas e recusa os pedidos até o resource chamador parar; então volta sozinho. A capacidade vem do `server.cfg`:

```
add_ace resource.<nome> coe.bank.yield allow
```

O framework não cita o pacote pelo nome: o resource que assume vem do runtime. `Status()` devolve `{ active, yieldedBy }`.

Os motivos de extrato são os mesmos de um banco completo, então o histórico continua coerente ao trocar: `bank_withdraw`, `bank_deposit`, `bank_transfer` (referência `state:<ID do destinatário>`) e `bank_refund`. A referência de saque e depósito é `agency:<id>` ou `atm`.

## Consistência

Conta e inventário são resources separados; as operações usam compensação:

- Saque: debita a conta e entrega a espécie; se não couber no inventário, devolve à conta (`bank_refund`).
- Depósito: retira a espécie e credita; se o crédito falhar, devolve a espécie.

Falha de estorno é registrada em log (`bank_refund_failed`). Cada jogador tem uma operação por vez e um intervalo mínimo entre movimentações (`ActionIntervalMs`). O servidor confere a distância do balcão (agência) e do ponto onde a tela abriu; a tela fecha ao se afastar `SessionRadius`.

## Configuração

`config.lua`: tetos por operação, atalhos de valor (agência e caixa), tamanho do extrato, intervalo entre operações, raio da sessão, modelos de caixa eletrônico, blip e agências (`id`, `label`, coordenadas e `radius`).

## Interface

Agência e caixa eletrônico usam a mesma página (`html/`), no visual do `coe_ui` (painel chanfrado, botões e campos `coe-*`, cores só por tokens), e acompanham o tema do servidor e a cor do jogador (`@coe_ui/theme_bridge.lua`). A transferência confirma pelo `CoeUI.confirm`.

## Testes

```
cd coe_bank
lua test/rules_test.lua
lua test/server_test.lua
```

`server_test.lua` exercita o servidor com economia, inventário, banco de dados e sessões simulados: agência e caixa, saque e depósito com estorno, intervalo entre operações, destinatário online e offline, transferência, limites, distância e o `Yield` de um pacote.
