# coe_crypto

Criptomoeda do jogo (**Noxcoin**, `NOX`): carteiras com chave privada, rede pública, corretora com cotação flutuante e
mineração. É a moeda da DeepWeb (`coe_deepweb`): mercado, serviços e contratos das próximas fases são pagos nela.

## Carteiras

- Uma carteira é um **endereço** público (`nx` + 28 caracteres base58) e uma **chave privada**
  (`NXK-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX`). Quem tem a chave move os fundos. O servidor guarda só o hash da chave, no
  formato próprio do framework (`coe_core/lib/hash.lua`, SHA-256 iterado com salt). Carteiras criadas com o hash antigo
  (bcrypt do FXServer, que não conferia) continuam válidas quando a mesma chave está guardada em algum aparelho, e o hash
  é refeito no primeiro uso.
- Para levar uma carteira a outro aparelho: **Anotar em papel** ou **Gravar em pen drive** (com o item no inventário a
  carteira aparece em qualquer aparelho) ou **Importar** digitando endereço e chave. A importação diz o que está errado:
  endereço mal digitado, chave fora do formato, endereço inexistente ou chave de outra carteira (só esta última conta
  como tentativa para o bloqueio).
- A chave fica em um destes lugares:
  - **Num aparelho** (carteira quente): smartphone (`phone:<serial>`), tablet (`tablet:<personagem>`) ou computador do
    `coe_deepweb` (`laptop:<serial>`, `desktop:<serial>`, `server:<serial>`). Quem usa o aparelho usa as carteiras dele.
    Até `Wallets.MaxPerDevice` por aparelho.
  - **Num papel** (`crypto_paper`) ou **num pen drive** (`crypto_usb`), com `metadata { address, key, label }`. Quem
    carrega o item usa a carteira; o item pode ser roubado, entregue ou apreendido (`coe_police:Seize`).
- **Nova carteira** cria a chave no aparelho (até `Wallets.MaxCreatedPerDay` por personagem por dia). **Importar** pede
  endereço + chave (ex.: lidos de um papel); `Wallets.ImportFailures` chaves erradas bloqueiam o aparelho por
  `ImportLockSeconds`. **Ver chave**, **Anotar em papel**, **Gravar em pen drive** (consome um `usb_black` vazio) e
  **Remover** (tira a chave do aparelho; sem outra cópia os fundos ficam inacessíveis).

## Rede

- Livro público (`coe_crypto_tx`): o **Explorador** mostra saldo e movimentações de qualquer endereço. O livro também
  guarda, só no servidor, o personagem e o aparelho que executaram cada movimento (rastro para investigação).
- Envio: taxa fixa `Transfer.Fee` (queimada), intervalo `Transfer.CooldownSeconds` por endereço e mensagem pública
  opcional. Destino precisa existir na rede. Saldos são `BIGINT UNSIGNED` em modo estrito: um débito além do saldo
  desfaz a transação inteira (o resource exige `sql_mode` estrito ao iniciar, como o `coe_economy`).

## Corretora (`Exchange`)

- Compra e venda contra o saldo do banco (`coe_economy`, motivos `crypto_buy`, `crypto_sell`, `crypto_refund`). As
  ordens são **identificadas** (ligadas ao personagem): é a porta legal de entrada e saída da cripto.
- Liquidez de uma carteira de reserva sem chave (`ReserveAddress`, criada com `Reserve` unidades). Sem reserva:
  `no_liquidity`.
- Cotação em $ por moeda: a cada `TickMinutes`, passeio aleatório com volta à âncora (`MeanReversion`), ruído
  (`Volatility`) e **impacto do fluxo líquido** de ordens (`ImpactPerMillion`): muita compra sobe o preço, muita venda
  derruba. Limites `MinPrice`/`MaxPrice`. Histórico de 24 h para o gráfico (`coe_crypto_prices`).
- Spread `SpreadBps` de cada lado, ordem de `MinOrder` a `MaxOrder`, limites diários por personagem
  (`DailyBuyLimit`, `DailySellLimit`) e intervalo `OrderCooldownSeconds`.
- Se o banco recusar o crédito de uma venda, as moedas voltam para a carteira (`refund`); se a reserva falhar numa
  compra, o dinheiro é estornado.

## Mineração (`Mining`)

`MintMining(entries)` (só `Mining.Callers`, hoje o `coe_deepweb`, no máximo uma rodada por `TickMinutes`): cada
máquina recebe `EmissionPerTick * hash / max(hash total, ReferenceHash)`. Rede fraca emite menos que o total; o teto
`MaxMined` vale só para mineração (a reserva da corretora é emissão separada, `genesis`). Pagamentos ao mesmo
endereço são somados e gravados em transações de até 30 pagamentos.

## Custódia do mercado (`Escrow`)

Carteira sem chave (`Escrow.Address`, criada vazia ao iniciar) que segura os pagamentos do Deep Market do
`coe_deepweb` até a entrega. Só `Escrow.Callers`: `HeldWallets(playerId, deviceKey)` lista as carteiras com chave à mão
no aparelho e no inventário (com saldo); `EscrowLock(playerId, deviceKey, from, amount, memo)` trava o valor mais a
taxa da rede (exige a chave, livro `escrow_lock` com personagem e aparelho); `EscrowRelease(to, amount, memo)` paga o
vendedor, devolve ao comprador ou manda a taxa para a reserva (`escrow_out`, sem taxa). `ReserveAddress()` informa a
reserva da corretora.

## App Cripto

Instalado pela **Loja** (`coe_apps`, categoria Finanças) no smartphone e no tablet, e presente em todo computador do
`coe_deepweb`. Abas: Carteiras, Enviar, Corretora (cotação, gráfico, compra e venda) e Explorador.

## Exports

Ver [`reference/coe_crypto.md`](../reference/coe_crypto.md). `TabletVisible`/`TabletCall` (só `coe_phone` e
`coe_tablet`), `ComputerCall` (só `coe_deepweb`), `MintMining` (só `Mining.Callers`), administração via `coe_admin`
(`AdminOverview`, `AdminInspect`, `AdminSaveSettings`, `AdminResetSettings`, `AdminSetPrice`) e leitura livre: `IsReady`,
`Price`, `Balance`, `IsAddress`, `Format`.

## Tabelas

`coe_crypto_wallets` (endereço, hash da chave, saldo, quem criou), `coe_crypto_keystore` (chaves por aparelho),
`coe_crypto_tx` (livro), `coe_crypto_prices` (cotações), `coe_crypto_state` (contadores, ex.: `minted`) e
`coe_crypto_settings` (configurações editáveis pelo admin). Migrações em `server/migrations.lua`, controle em
`coe_crypto_schema_migrations`.

## Dependências

`coe_core`, `coe_database`, `coe_logging`. Opcionais: `coe_economy` (corretora), `coe_inventory` (papel e pen drive),
`coe_apps` (instalação), `coe_phone` (série do aparelho), `coe_audit`, `coe_notify`. Precisa estar nas listas de
`coe_database`, `coe_logging`, `coe_audit`, `coe_notify` e em `AllowedResources` do `coe_economy` (já incluído).

## Testes

```
cd coe_crypto
lua test/crypto_test.lua
lua test/server_test.lua
```
