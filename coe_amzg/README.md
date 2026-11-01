# coe_amzg

Loja virtual (e-commerce) do smartphone e do tablet. O jogador escolhe produtos, paga com cartão de crédito pela Carteira do celular e escolhe em qual imóvel quer receber. A compra chega numa caixa dentro do imóvel, perto do ponto de entrada interno.

## Fluxo

1. Instalar o app **Amzg** na loja de apps (`coe_apps`, categoria Compras). Ele aparece no celular e no tablet.
2. **Loja**: busca, categorias e vitrine. O carrinho fica guardado enquanto o recurso estiver aberto.
3. **Carrinho**: itens, espaço ocupado na caixa, endereço, frete e total. **Pagar** só funciona no celular: abre a Carteira (`coe_phone`), que cobra o cartão escolhido via `coe_banking:CardPurchase`. No tablet o botão pede para usar o celular.
4. O servidor recalcula o preço de tudo. Se o catálogo mudou desde que a vitrine foi aberta, a compra é recusada (`price_changed`) e nada é cobrado.
5. **Pedidos**: situação (a caminho, entregue, retirado, estornado) e previsão de chegada.

## Entrega

- Endereços válidos: residências, imóveis comerciais e esconderijos aos quais o personagem tem acesso (`coe_housing:DeliveryAddresses`).
- Fretes em `Config.Shipping`: padrão (30 min, grátis) e expresso (5 min, taxa).
- A cada `DeliveryTickSeconds`, pedidos vencidos viram uma caixa (`stash:amzg:<pedido>`) com os itens. Se o contrato do imóvel acabou nesse meio tempo, o valor é estornado no cartão.
- A caixa (`Config.Box.Model`) aparece só para quem está dentro daquele imóvel, enfileirada perto do ponto interno. Mire e use **Abrir caixa Amzg**: abre como um baú.
- Caixa vazia some (pedido vira "retirado") e o inventário é apagado após `CollectDelaySeconds`. Se alguém devolver itens antes disso, ela volta.
- Visitantes num contrato de outra pessoa não veem caixas.

## Limites (`config.lua`)

- `Cart`: até 10 linhas, 50 unidades por linha, 20 espaços na caixa e total máximo.
- `Orders.MaxPending`: pedidos a caminho por personagem; `Orders.History`: pedidos listados.
- `Products`: até 300 produtos, preço máximo e tamanho do nome.
- `Promo`: tamanho do selo do banner (`BannerTextMax`), troca do carrossel (`RotateSeconds`) e a cada quantos produtos entra um banner na grade (`InlineEvery`).

## Catálogo

Começa com os eletrônicos da DeepWeb (migração 2: Notebook, Computador desktop, Servidor doméstico e Pen drive, na categoria Eletrônicos, só se o item ainda não estiver cadastrado). É editado no painel admin (`coe_admin`, aba **Amzg**, permissão de negócios): cada produto aponta para um item do inventário, com nome na vitrine, categoria, preço, ordem e opção de pausar sem apagar. Fica gravado em `coe_amzg_products`; pedidos em `coe_amzg_orders`.

### Promoções e banners

No mesmo editor, o bloco **Promoção e banner** define preço promocional (menor que o normal; 0 = sem promoção), fim opcional (data no futuro; vazio = sem prazo), selo do banner (vazio = `-N% OFF`) e destaque. Com promoção ativa, o app mostra "De $X por $Y" e o desconto no card; os banners são montados com a imagem do item: carrossel no topo da vitrine (destaques; sem destaque, todas as promoções da categoria) e faixas menores entre os produtos. Há contagem regressiva quando há prazo e botão **Aproveitar** que põe no carrinho. O servidor decide o preço: o catálogo já envia o valor promocional, o checkout recalcula com o relógio do servidor e a promoção vencida volta ao preço cheio (o app recarrega a vitrine; carrinho com preço antigo recebe `price_changed`). Migração 3 adiciona `promo_price`, `promo_until`, `featured` e `banner_text`.

## Exports

| Export | Quem chama | Uso |
| --- | --- | --- |
| `TabletVisible(playerId, appId)` | `coe_phone`, `coe_tablet` | App instalado no aparelho. |
| `TabletCall(playerId, appId, action, payload)` | `coe_phone`, `coe_tablet` | `catalog`, `addresses`, `checkout`, `orders`. |
| `AdminCatalog()` | `coe_admin` | Categorias, produtos e limites. |
| `AdminSaveProduct(input)` | `coe_admin` | Cria (sem `id`) ou atualiza um produto. |
| `AdminDeleteProduct({ id })` | `coe_admin` | Remove um produto. |

Exports admin recusam outros chamadores (`forbidden`).

## Dependências

`coe_core`, `coe_database`, `coe_logging`, `coe_inventory`; em tempo de execução também `coe_housing` (endereços e espaço atual, liberados em `DeliveryCallers`), `coe_apps` (`HasApp`), `coe_phone` (Carteira, `Wallet.PaymentCallers`), `coe_banking` (`PurchaseCallers`), `coe_notify`, `coe_audit` e `coetarget`.

## Auditoria

`amzg_order_placed`, `amzg_order_refunded`, `amzg_product_saved`, `amzg_product_deleted`.

## Testes

`lua test/amzg_test.lua` (regras de preço, espaço e posição das caixas).
