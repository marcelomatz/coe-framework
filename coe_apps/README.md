# coe_apps

Loja de aplicativos do **COE OS**. A mesma loja e os mesmos apps servem o tablet (`coe_tablet`) e o smartphone (`coe_phone`); o aparelho é identificado pelo resource que chama (`HOSTS`), e cada app diz em `devices` onde roda.

## Apps

- **Loja** (nativa): vitrine por categoria com instalar e remover. App pago é uma **assinatura semanal no cartão de crédito**, paga pela **Carteira** do smartphone: o jogador escolhe o cartão e confirma com o rosto ou a senha do celular; o `coe_phone` gera uma autorização de uso único (`ConsumePayment`) e a cobrança vai para aquele cartão (`coe_banking`, `CardPurchase`). A assinatura fica presa ao **cartão** (`card_id`) e renova nele mesmo sem o celular por perto. No tablet, assinar devolve `wallet_required`. A primeira semana é cobrada ao assinar e a renovação é automática a cada `Subscriptions.PeriodDays` dias (`RenewLeadSeconds` antes de vencer), mesmo com o personagem offline. Cartão bloqueado, substituído ou vencido, sem conta de crédito, com fatura em atraso ou sem limite: a cobrança é recusada e, vencida a semana, o app sai do aparelho (com aviso se estiver online). Cancelar remove o app e para a renovação; reinstalar dentro da semana paga não cobra de novo (passa pela Carteira só para escolher o cartão da renovação). Assinaturas de antes da Carteira não têm cartão e são recusadas na próxima renovação; basta assinar de novo. A instalação é salva por personagem (`coe_apps_installed`) e a tela inicial do tablet se atualiza na hora.
- **Empregos**: grupos do tipo `job` do `coe_core`, com cargos, quantos estão em serviço, o emprego do jogador e o local para se apresentar (GPS, em `Jobs`).
- **Classificados**: anúncios por categoria com título, descrição e preço (ou "a combinar"). Cobra `Fee` por anúncio (`classified_fee`, devolvido se a gravação falhar), fica `DurationHours` no ar e cada personagem tem no máximo `MaxActive` ativos. O contato mostra nome e ID do autor. O autor encerra o próprio anúncio.
- **Insta**: feed de fotos com curtidas (duplo clique ou botão), aba "Meus posts" e paginação. "Nova foto" abre a câmera do jogo: mouse mira, roda dá zoom, **E** alterna selfie e câmera traseira, clique esquerdo ou Enter fotografa, clique direito/Backspace cancela. A foto é reduzida no aparelho (`Photos.Width`, `Quality`, `MaxBytes`), recebe legenda e é publicada.
- **Estúdio** (assinatura semanal, só smartphone): editor das fotos da Galeria do coe_phone. Filtros prontos com prévia, ajustes (brilho, contraste, saturação, temperatura, desbotar, vinheta, nitidez, desfoque), corte por proporção, girar e espelhar, redimensionar (10–100%), texto (posição, cor e tamanho) e molduras. Segure **Antes** para comparar com a original. Tudo é processado no aparelho e salvo como **cópia** na Galeria pelo mesmo caminho validado da câmera (limites de coe_phone); a original nunca muda. Não tem handlers no servidor: usa as ações gallery e camera do próprio celular.

## Fotos

1. A câmera usa o `screenshot-basic`.
2. O aparelho envia a foto já reduzida por evento latente (`coe_apps:photo`); o servidor valida (só JPEG em base64, até `MaxBytes`, uma a cada `UploadCooldownSeconds`) e a guarda pendente por `PendingSeconds`, devolvendo um token.
3. Ao publicar, a foto vai para o host:
   - **Banco** (padrão, nada a configurar): tabela `coe_apps_insta_media`; o post guarda `media:<id>` e o aparelho busca a imagem sob demanda.
   - **HTTP**: defina `set coe_apps_upload_url "https://..."` (e, se o serviço pedir, `set coe_apps_upload_key "..."`). O servidor envia um POST form-urlencoded com `Field=<base64>` (e `KeyField=<chave>`) e lê a URL pública da resposta JSON em `ResponsePath`. Só URLs `https://` são aceitas.

Os apps que podem enviar fotos ficam em `Photos.Apps` (Insta e os portais do `coe_news`). Os resources em `Photos.Callers` guardam a foto pelos exports de servidor `ClaimPhoto(playerId, token)` → `{ ok, image }`, `PhotoData(id)` e `DeletePhoto(image)`.

Vídeos ficam para uma próxima fase.

## Moderação

A ACE `coe_apps.moderate` permite apagar anúncios e posts de qualquer pessoa (registrado no `coe_audit`).

```
add_ace group.admin coe_apps.moderate allow
```

## Integração

- `TabletVisible(playerId, appId)` e `TabletCall(playerId, appId, action, payload)`: só aceitam chamadas dos aparelhos em `HOSTS`. A Loja sempre aparece; os demais apps, só instalados.
- Exports de cliente usados pelo aparelho: `TakePhoto()` → `{ ok, image }` e `StorePhoto(image)` → `{ ok, token }`.
- Interface: `html/apps.js` registra `store`, `jobs`, `classifieds` e `insta` no aparelho; `html/editor.js` (+ `editor.css`) registra o `editor` e serializa as ações (o tablet aceita uma a cada 250 ms).
- Novo app: entrada em `Store` (aqui), entrada em `Apps` do `coe_tablet/config.lua` com `ownerCheck = true` e `resource = 'coe_apps'`, um conjunto de handlers em `server/main.lua` e um `register` em `html/apps.js`.

## Dependências

`coe_core`, `coe_database`, `coe_logging` e `screenshot-basic`; `coe_banking` para as assinaturas (sem ele, assinar devolve `bank_unavailable` e as renovações esperam). Precisa estar nas listas de permissão de `coe_database`, `coe_logging`, `coe_audit` em `Credit.PurchaseCallers` do `coe_banking` e em `Wallet.PaymentCallers` do `coe_phone` (já incluídos).

Teste: `lua test/apps_test.lua` (a partir da pasta do resource).