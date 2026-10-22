# coe_shops

Lojas de conveniência do mapa como negócios do `coe_businesses`: **24/7**, **LTD Gasoline** e **Rob's Liquor**
(fase 1). Toda loja começa **da staff** (negócio sem dono) e pode ser passada para um jogador definindo o dono na
aba Negócios do `coe_admin`.

Fases seguintes: 2) combustível e bombas dos postos (o negócio do LTD já é da categoria `gas_station`);
3) Ammu-Nation, roupas, barbearia e tatuagem; 4) carregamentos de abastecimento (`GetShelves` já expõe o estoque).

## Como funciona

- Balconista (`mp_m_shopkeep_01`) em cada loja, com alvo **Comprar** (`coetarget`). Blip curto por tipo; as LTD
  não têm blip de loja (`blip = false`), o blip é o do posto (`coe_fuel`), que usa o mesmo negócio. Balconistas e
  blips saem do config no client e aparecem mesmo com o servidor ainda abrindo as lojas; nesse caso **Comprar** responde
  "Loja ainda abrindo" e o console mostra `shops_migrations_failed` (o servidor tenta de novo a cada 15 s).
- O balconista só é criado com o interior da loja carregado e vai para a sala do jogador se ficou fora dela.
  `/lojadebug` (F8) mostra a loja mais perto, o balconista, a posição e o interior/sala do balconista e do jogador.
- A vitrine (NUI) mostra categorias, busca, estoque e o carrinho. Preço, estoque e cobrança são decididos no servidor;
  o jogador precisa estar a até `CounterRadius` (4 m) do balcão.
- Pagamento: **dinheiro** (item `money`) é da loja; os demais meios são registrados por outros resources com
  `RegisterPaymentMethod` (ver abaixo), como o cartão na maquininha e a carteira do celular dos pacotes comerciais.
  Inventário cheio estorna a compra pelo mesmo meio.
- A receita vai para o caixa do negócio (`coe_economy:SocietyCollect`, motivo `shop_sale`), nos dois modos.

| Modo | Quando | Estoque | Preço |
| --- | --- | --- | --- |
| `staff` | Negócio sem dono | Infinito (abastecimento automático) | Tabela do config |
| `player` | Negócio com dono | Prateleira da loja; começa vazia | Definido pelo dono, entre `PriceBand.Min` (0,5×) e `PriceBand.Max` (3×) da tabela |

## Gestão (aba Gestão da vitrine)

| Quem | Pode |
| --- | --- |
| Dono | Tudo, mesmo fora de ponto |
| Equipe de ponto | Abastecer a prateleira com itens do próprio inventário (até `MaxStock`, 500 por produto) |
| Cargo com `shops.prices` | Definir preços |
| Cargo com `shops.stock` | Retirar itens da prateleira para o inventário |
| ACE `coe_shops.manage` | Ver o relatório das lojas da staff |

Relatório: vendas de hoje e dos últimos 7 dias, saldo do caixa e as últimas `ReportSales` (30) vendas. O negócio de
cada loja tem baú `estoque` e ponto `ponto` no balcão (criados só na primeira vez; o dono pode mudar no admin).

## Tablet (app do negócio)

Cada loja é um negócio, então aparece como app no COE OS para o dono e a equipe (`coe_businesses`). A aba **Loja**
(só para lojas, via `IsStore`) mostra a prateleira (estoque e preço de cada produto), as vendas de hoje e dos 7 dias,
o caixa e as últimas vendas, e deixa o dono ou o cargo com `shops.prices` mudar preços a distância (ou voltar ao de
tabela). Abastecer e retirar continuam no balcão, porque mexem no inventário de quem está lá. A tela vem do próprio
`coe_shops` (`html/business.js` + `business.css`), registrada com `coe_businesses:RegisterTab` (visível onde `IsStore`
responde `true`) e de novo sempre que o `coe_businesses` reiniciar.

## Meios de pagamento de outros resources

Qualquer resource com a ACE `coe.shops.payments` registra um meio (o registro some quando ele para; registre de novo
no `onResourceStart` do `coe_shops`):

```lua
exports.coe_shops:RegisterPaymentMethod({
	id = 'card', label = 'Cartão na maquininha', order = 30,
	kind = 'pin',            -- instant | pin (escolhe uma opção e digita a senha) | device (passo no client)
	options = 'ShopOptions', -- opcional: (playerId) -> { detail?, available?, options = { { id, label } } }
	charge = 'ShopCharge',   -- (playerId, { option, pin, token }, total, descrição) -> { ok, ref } | { ok = false, error, left? }
	refund = 'ShopRefund',   -- (playerId, ref, total, descrição) -> { ok }
	client = nil             -- device: export client ({ amount, label, note }) -> { token } | { error }
})
```

O meio entra ligado; `Payments = { <id> = false }` no `config.lua` desliga. O relatório de vendas mostra o rótulo
registrado.

## Diagnóstico

- Cada client avisa o servidor quando monta as lojas e quando cria um balconista; o console do servidor mostra
  `shops_client_loaded` (lojas e blips), `shops_client_clerk` (loja, interior, altura) e `shops_client_error`.
  Se nenhum `shops_client_loaded` aparece depois que você entra, o script do client nem está rodando.
- `/lojadebug` (F8) mostra a loja mais perto e o estado do balconista.

## Config

`config.lua` (`ShopsConfig`): `Categories`, `Products` (produto → item, categoria, preço de tabela), `Types`
(produtos, balconista, blip, categoria do negócio) e `Stores` (id do negócio, nome, tipo e balconista `{ x, y, z, h }`).
Limites do carrinho em `Cart` (20 linhas, 50 por produto, total até 50 000). As posições dos balconistas são
provisórias: confira no jogo e ajuste.

Itens novos no `coe_inventory` (`data/coe_shop_items.lua`) e efeitos no `coe_needs` (`ItemEffects`): sanduíche,
salgadinho, chocolate, barra de cereal, eCola, café, energético, cerveja, uísque, vodca e analgésico. A água passou a
ser consumível.

## Banco

| Tabela | Conteúdo |
| --- | --- |
| `coe_shops_shelves` | Prateleira das lojas de jogador: quantidade e preço por produto (nulo = tabela). |
| `coe_shops_sales` | Vendas: loja, personagem, modo, forma de pagamento, total, unidades e itens. |

Migrações em `coe_shops_schema_migrations`.

## Exports (servidor)

| Export | Retorno |
| --- | --- |
| `IsReady()` | `true` depois das migrações e da criação dos negócios. |
| `IsStore(businessId)` | `true` se o negócio é uma loja do `coe_shops`. |
| `BusinessTablet(playerId, characterId, businessId, payload)` | Aba Loja do app do negócio (só `coe_businesses`): `op` `overview` ou `price`. |
| `GetShelves(storeId)` | `{ [produto] = { quantity, price } }` da loja de jogador, ou `nil` (loja da staff ou desconhecida). |
| `RegisterPaymentMethod(def)` | Meio de pagamento de outro resource (ACE `coe.shops.payments`): `true` ou `{ error }` (`forbidden`, `invalid_method`, `method_taken`, `too_many_methods`). |

## Dependências e listas de permissão

`coe_core`, `coe_database`, `coe_logging`, `coe_inventory`, `coe_businesses`, `coetarget`; opcionais em tempo de uso:
`coe_economy`, `coe_audit`, `coe_notify` e os meios de pagamento registrados. O `coe_shops` está nos padrões de acesso
do framework (banco, logs, notificações, auditoria, caixa do negócio, gravação de negócios, permissões de cargo e
abas) e no `coe_supervisor`. Pacotes que cobram nas lojas costumam exigir o `coe_shops` na própria lista de chamadores.

Auditoria: `shop_sale`, `shop_price`, `shop_restock`, `shop_withdraw`.

## Testes

`test/rules_test.lua` (catálogo, modos, faixa de preço, orçamento, estoque, abastecer e retirar) e
`test/server_test.lua` (natives e exports simulados: compra nos três pagamentos, estorno, estoque de jogador,
gestão e permissões) e `test/client_test.lua` (balconistas e blips a partir do config, sem esperar o servidor).
