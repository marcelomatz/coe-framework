# coe_news

Portais de notícias do COE OS. Cada veículo de comunicação é um **negócio** da categoria `media` (`coe_businesses`) e tem o **próprio app** no smartphone e no tablet, instalado grátis pela Loja (categoria Notícias):

| App | Veículo | Região | Negócio |
|---|---|---|---|
| `weazel` | Weazel News | Los Santos | `weazel_news` |
| `rebel` | Rebel News | Condado de Blaine | `rebel_news` |

Os dois negócios são semeados na primeira subida (área, ponto "Redação", baú "Arquivo" e cargos). Depois disso, área, pontos, **dono** e **equipe** ficam na aba Negócios do `coe_admin`.

## Portal (qualquer leitor)

- Manchete e lista de matérias publicadas, filtro por editoria, busca por título/linha fina e paginação.
- Leitura com foto de capa, linha fina, assinatura, data e contagem de leituras (uma por jogador por matéria enquanto estiver online).
- Matérias **urgentes** avisam quem tem o app instalado (uma por veículo a cada `Articles.BreakingCooldownMinutes`).
- Anúncios no ar aparecem como "Publicidade" a cada `Ads.FeedEvery` matérias.

## Linha editorial

Cada veículo define slogan, texto da linha editorial, editorias ativas (Notícias, Acontecimentos, Fofocas, Opinião, Polícia, Economia, Esportes) e o preço do anúncio por dia. Exige a permissão `news.editorial`.

## Redação

Fluxo da matéria: **rascunho → em revisão → publicada → fora do ar** (republicável).

| Ação | Quem |
|---|---|
| Escrever, editar o próprio rascunho, enviar para revisão | `news.write` |
| Editar em revisão, devolver ao autor (com observação), publicar (com ou sem urgente), tirar do ar, editar publicada | `news.publish` |
| Apagar | autor (rascunho ou revisão) ou `news.publish` |

- Capa pela câmera do aparelho (mesmo envio do Insta, `coe_apps`); a foto antiga é apagada ao trocar.
- "Assinar como Redação" esconde o autor do público (útil para fofocas).
- Limites em `Articles` (tamanhos, `MaxDraftsPerAuthor`, `SaveCooldownSeconds`).

Cargos semeados: Estagiário e Repórter (`news.write`), Editor (+ `news.publish`, `news.ads`), Editor-chefe (todas + `business.staff`, `business.funds`, `business.remote`). O dono tem todas. Como em todo negócio, a equipe precisa estar de ponto para agir (`clockRequired`); na categoria `media` o ponto continua aberto fora da área (`clockOffsite`), para cobrir pautas na rua.

## Anúncios

1. Qualquer cidadão ou negócio compra pelo app (aba Anunciar): anunciante, título, texto e duração (`Ads.Days`). Paga pela conta pessoal ou pelo caixa de um negócio em que tenha `business.funds`.
2. O valor (dias × preço do veículo) é debitado na hora e fica **retido**.
3. Quem tem `news.ads` aprova ou recusa (aba Anúncios). Aprovado, entra no ar por N dias e o valor vai para o **caixa do veículo**. Recusado, cancelado pelo comprador ou sem resposta em `Ads.PendingHours`, o valor volta para quem pagou.

Limites: `MaxPendingPerBuyer` por comprador, `MaxActivePerOutlet` no ar por veículo, preço por dia entre `MinPricePerDay` e `MaxPricePerDay`.

## Equipamentos

Câmera de TV (`news_camera`), microfone (`news_mic`) e microfone boom (`news_boom`) são itens do `coe_inventory` (`data/coe_base_items.lua`, imagens em `data/images/news_*.png`). O estoque fica no baú `Equipment.Stash` do negócio (padrão `arquivo`, o baú "Arquivo" da semente); a staff abastece e retira pela aba **Imprensa** do admin e a equipe pega no baú. Usar o item segura o equipamento com prop e animação (`client.lua`); usar de novo, apertar X (`Equipment.CancelKey`) ou entrar num veículo guarda. É só visual: nada muda no servidor. Prop, osso, offset, rotação e animação de cada item ficam em `Equipment.Items` e precisam de ajuste no jogo.

## Painel admin (aba Imprensa)

Exports só para `AdminResources` (`coe_admin`), que confere a permissão `coe_admin.news.manage`:

- `AdminOverview()`: veículos com linha editorial, números (`NewsPersistence.Stats`: matérias por status, leituras, anúncios, receita total e dos últimos 30 dias) e caixa da sociedade; catálogo de editorias e de equipamentos; limites.
- `AdminQuery(kind, { outlet, ... })`: `ads` (`group` = `pending`, `active` ou `history`, com o nome do comprador), `articles` (`status`, `search`), `article` (`id`, com o corpo) e `equipment` (estoque no baú e quem da equipe ou o dono está com cada item).
- `AdminAction(op, { outlet, admin, ... })`: `editorial`, `adApprove`, `adReject` (estorna a quem pagou), `adTakedown` (`refund` = `none`, `remaining` ou `full`; o estorno sai do caixa do veículo com `SocietyCharge` e volta para a conta pessoal ou o caixa pagador; sem saldo nada muda), `articleUnpublish`, `articleRepublish`, `articleDelete` (apaga a foto) e `stock` (`item`, `count` de 1 a `MaxPerOperation`, `op` = `add` ou `remove`; cria o inventário do baú se ainda não existir).

Toda ação é auditada no `coe_audit` com `source = admin:<id>`. Novo status de anúncio: `removed` (retirado do ar pela staff). Equipe, cargos e frota são gravados pelo próprio `coe_admin` (no `coe_businesses` e no `coe_garages`), restritos a negócios da categoria `media`.

## Integração

- Exports `TabletVisible(playerId, appId)` e `TabletCall(playerId, appId, action, payload)`, só para `coe_tablet` e `coe_phone`. O app precisa estar instalado (`coe_apps:HasApp`).
- Fotos: `coe_apps` (`ClaimPhoto`, `PhotoData`, `DeletePhoto`; `Photos.Apps` e `Photos.Callers`).
- Dinheiro: `coe_economy` (`Debit`/`Credit` com motivos `news_ad`/`news_ad_refund`, `SocietyCharge`/`SocietyCollect`).
- Interface: `html/news.js` (+ `news.css`) registra todos os veículos de `OUTLETS`, com a cor de cada um.
- Tabelas: `coe_news_outlets`, `coe_news_articles`, `coe_news_ads` (migrações em `server/migrations.lua`).

Novo veículo: adicione em `Outlets` (config), nos apps do `coe_apps`, `coe_phone` e `coe_tablet` e em `OUTLETS` (`news.js`).

Testes: `lua test/news_test.lua` (regras) e `lua test/admin_test.lua` (exports do painel com economia, inventário e banco falsos).

Podcasts dos veículos ficam para uma próxima fase.
