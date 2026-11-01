# coe_phone

> Upgrade do telefone básico (`coe_mobile`): o `coe_supervisor` não inicia o básico com este resource rodando, e a cada inicialização o `server/upgrade.lua` traz número, contatos, conversas, ligações e ajustes de quem usava o básico (`UpgradeStatus()`, comando `coe_upgrades`). Detalhes em [`UPGRADES.md`](../UPGRADES.md).

Smartphone do COE OS. Abre no **F1** (ou `/celular`), ou usando o item **Celular** no inventário, e reúne:

- **Telefone**: teclado, recentes e o seu número. Ligações com toque, atender, recusar, desligar e ocultar a tela da ligação.
- **Contatos**: agenda com busca; ligar, mandar mensagem, editar e apagar.
- **Mensagens**: conversas por número, com aviso e contador de não lidas. Mensagens para quem está offline ficam guardadas.
- **Câmera** e **Galeria**: fotos guardadas no próprio aparelho (veja abaixo).
- **Carteira**: cartões do banco guardados no aparelho para pagar sem o cartão físico em mãos (veja abaixo).
- **Ajustes**: conexões, sons, tela, tela inicial, senha e reconhecimento facial.
- **Apps da loja** (`coe_apps`): Loja, Empregos, Classificados e Insta, os mesmos do tablet. Só aparecem depois de instalados.

O tablet (`coe_tablet`, F3) e o smartphone compartilham a loja e os componentes visuais (`nui://coe_ui/html/apps.css`).

Substitui o telefone básico do framework (`coe_mobile`): ao iniciar, e sempre que o `coe_mobile` reinicia, chama o export `Yield` (ACE `coe.mobile.yield` no `permissions.cfg`). O básico encerra as ligações dele, fecha a tela e deixa de abrir (tecla, comando e item `phone`) até o `coe_phone` parar. Os dois usam o item `phone` e o F1; com o `coe_phone` no ar, só ele responde. Números, contatos e mensagens do básico ficam nas tabelas `coe_mobile_*` e não são importados: aqui o número é o do chip.

## Tecla

`F1` é o padrão. Cada jogador troca em **Configurações > Teclas > FiveM > "Abrir smartphone (COE OS)"**. Com o
celular aberto, `F1` fecha e `Esc` volta (ou fecha na tela inicial).

## Aparelhos e chips

Cada celular é um objeto: o item `phone` ganha um número de série (`metadata.serial`) na primeira vez que é aberto.
Senha, reconhecimento facial, ajustes, tela inicial e contatos ficam **no aparelho**. Quem estiver com o item e souber
a senha usa o celular, mesmo que seja de outra pessoa. Com mais de um celular no inventário, o F1 abre o último usado;
usar o item abre aquele aparelho.

O número fica no **chip** (item `sim_card`, `metadata.iccid`). Um celular novo de quem ainda não é titular de nenhum
chip já vem com um: `Number.Prefix` + `Number.Digits` dígitos aleatórios (padrão `555-0123`), com o personagem
como titular. Para trocar: **Ajustes > Chip > Retirar** devolve o chip ao inventário; usar o item `sim_card` (ou **Ajustes > Chip > Colocar**, que lista os chips do inventário) coloca
no celular que está em uso (se houver slot livre; o modelo define quantos, `Models[*].sims`). Sem chip o celular
abre, mas não liga nem manda mensagem. Ligações e mensagens vão para o número; tocam no celular que estiver com o chip,
nas mãos de quem estiver online com ele. Mensagens para um chip fora de aparelho ficam guardadas.

O reconhecimento facial guarda o rosto de quem o ativou; outra pessoa só desbloqueia pela senha. Os erros de senha
contam por aparelho.

Na atualização, cada personagem com número ganhou um aparelho migrado (serial `MG…`) com seus ajustes e contatos e o
chip com o número antigo; ele é ligado ao primeiro item de celular sem série que o personagem abrir. Use o item
`phone`: o celular não funciona mais sem ele.

Exports:

| Export | Retorno |
| --- | --- |
| `NumberOf(characterId)` | Número (`555-0123`) do primeiro chip de que o personagem é titular, ou `nil`. |
| `ActiveLine(playerId)` | Chip do celular em uso: `{ number, display, holder }` ou `nil, 'no_phone' \| 'no_sim'`. Usado pelo `coe_telecom`. |
| `ActiveDevice(playerId)` | Aparelho em uso: `{ serial }` ou `nil, erro`. Apps que prendem a sessão ao aparelho (ex.: `coe_mail`) usam o número de série. |

## Ligações

O servidor controla o estado: chamando → em ligação → encerrada. Se ninguém atende em `Calls.RingSeconds`, a ligação
vira perdida e o destinatário é avisado. Ocupado, fora de área (offline ou sem celular) e número inexistente são
respondidos na hora. Fora de área inclui chip fora de aparelho e celular que ninguém online está carregando. Todo o
histórico fica em `coe_phone_calls`.

Voz (`server/voice.lua`): usa a API de voz do FiveM para GTAV Enhanced, controlada só pelo servidor. Ao atender,
o servidor cria um canal não espacial (`CreateVoiceChannel(0, 0.0)`) com os dois jogadores
(`AddPlayerToVoiceChannel`); ao desligar, apaga o canal (`DeleteVoiceChannel`). Não usa natives Mumble nem
pma-voice (sem suporte no Enhanced). Requer `voice_internal` (ou servidor de voz externo) no `server.cfg`. A voz de
proximidade continua: quem está perto de quem fala ao telefone também ouve esse lado da conversa.

Morrer ou sair do servidor encerra a ligação.

Chamada de vídeo: botão **Vídeo** no teclado, nos recentes e nos contatos. Usa o mesmo canal de voz (não há imagem
real); a tela e o histórico mostram que é vídeo, e a operadora cobra a tarifa de vídeo.

## Operadora (`coe_telecom`)

Opcional. Quando iniciado, o telefone pergunta à operadora antes de discar ou mandar mensagem (`Authorize`) e informa
o uso ao fim (`Charge`), sempre pelo número do chip. Quem liga paga. Sem crédito no pré-pago a ligação não sai; com crédito ela cai sozinha
quando o crédito acaba ("Crédito esgotado"). Linha suspensa (fatura vencida) não liga nem envia mensagens, mas
recebe. O app **Minha linha** (ícone `sim`) mostra saldo, plano, consumo, faturas, recarga e troca de plano. Sem o
`coe_telecom`, ligações e mensagens são grátis. Detalhes no README do `coe_telecom`.

## Telas iniciais

A tela inicial tem várias telas (até `Home.MaxPages`, com `Home.PageSize` apps cada) e a barra inferior
(`Home.DockSize`). Troque de tela pelas bolinhas, pela roda do mouse, arrastando para o lado ou pelas setas.

Segure um app para entrar no modo de edição: arraste para outra posição, para a barra inferior, para uma bolinha
(outra tela) ou para a borda (vira a tela; na última, cria uma nova). Soltar sobre um app de uma lista cheia troca os
dois de lugar. Os botões **+ Tela**, **Apagar tela** (só vazia) e **Concluir** ficam embaixo. A organização é salva
no aparelho; **Ajustes > Tela inicial > Restaurar** volta ao padrão. Apps novos entram na primeira tela com espaço.

## Ajustes

| Grupo | Opções |
| --- | --- |
| Conexões | Modo avião (desliga Wi-Fi e Bluetooth), Wi-Fi, Bluetooth. |
| Sons | Silencioso, vibrar, não perturbe, volume (0 a 10) e toque (Clássico, Digital, Suave, Pulso). |
| Tela | Brilho e papel de parede. |
| Tela inicial | Editar e restaurar. |
| Segurança | Senha numérica e reconhecimento facial (exige senha). |
| Chip | Chips no aparelho (número e se você é o titular), Retirar e, em slot vazio, Colocar um chip do inventário. |
| Sobre | Modelo e número de série. |

Não perturbe cala toque, vibração e avisos de mensagem e de chamada perdida. Os padrões ficam em `Settings.Defaults`.

## Sinal

A barra mostra de 0 a 4 barras conforme a distância da antena mais próxima (`Signal.Towers`, faixas em
`Signal.Ranges`). Em interiores cai uma barra; debaixo d'água fica sem sinal. O servidor recalcula pela posição do
jogador: sem sinal ou em modo avião não é possível ligar nem mandar mensagem, e quem liga ouve "fora de área".

## Senha e reconhecimento facial

Com senha, o celular abre bloqueado. Digite no teclado da tela ou no teclado físico. Errar `Passcode.Attempts`
vezes bloqueia por `Passcode.LockoutSeconds`. Com o reconhecimento facial ligado, o aparelho desbloqueia sozinho
(com opção de usar a senha). Bloqueado, só é possível atender ou recusar ligações. A senha é guardada com hash.

## Câmera e Galeria

O obturador da **Câmera** guarda o celular e abre a câmera do jogo (requer `coe_apps` iniciado e `screenshot-basic`):
mouse mira, roda dá zoom, **E** vira para selfie, clique fotografa e botão direito cancela. A foto é reduzida à
resolução e qualidade da câmera do modelo (`Models.*.camera`), ganha uma miniatura e vai para a **Galeria**.

As fotos ficam **no aparelho** (serial), como os contatos: quem pegar o celular e souber a senha vê as fotos; trocar de
celular não leva as fotos junto. Cada modelo tem um armazenamento (`Models.*.storage`, em MB); cheio, a câmera recusa
novas fotos até apagar algumas. A Galeria mostra as miniaturas (mais recentes primeiro), o uso do armazenamento e a
foto inteira com data, navegação entre fotos e **Apagar** (toque duas vezes para confirmar). Com o **Estúdio**
(assinatura semanal da Loja, coe_apps) instalado, a foto aberta ganha o botão **Editar**; a edição é salva como uma nova foto,
que conta no armazenamento.

## Carteira

Cartões do `coe_banking` guardados **no aparelho** (`coe_phone_wallet`, até `Wallet.MaxCards`), sem backup na nuvem.
Exige senha do celular. Entram o cartão **físico** que está no inventário (digitando a senha do cartão; erros contam
tentativas como no caixa eletrônico) e o **cartão virtual** do personagem, que pode ser pedido na própria Carteira, na agência
ou no internet banking. Depois de vinculado, o cartão físico não precisa mais estar em mãos. Um cartão é o **padrão**;
pedir um novo virtual tira o anterior (substituído) da Carteira.

Pagamento (`api.pay({ amount, label, note })` no NUI): folha com os cartões ativos, confirmada pelo **rosto cadastrado**
(se ligado e se o rosto do aparelho for de quem está usando) ou pela **senha** do celular. O servidor gera uma autorização
de uso único, válida por `Wallet.PaymentSeconds`, que o resource pagador consome com o export
`ConsumePayment(playerId, token, amount)` (só `Wallet.PaymentCallers`; devolve o `cardId` ou `nil, erro`) e cobra no
cartão com o `coe_banking`. Hoje usado pelas assinaturas da Loja (`coe_apps`). Nas lojas do `coe_shops` a Carteira entra
como o meio `wallet` (`RegisterPaymentMethod`, kind `device`): o client da loja chama `RequestPayment` e o servidor da
loja cobra pelos exports `ShopCharge`/`ShopRefund` daqui, que consomem o token e lançam no crédito do cartão.

Outros resources pedem o pagamento pelo export de client `RequestPayment({ amount, label, note })`: abre o celular
se estiver guardado (espera até 8 s), mostra a folha de pagamento e devolve `{ token, cardId }` ou `{ error }`
(`cancelled`, também no tempo esgotado; `phone_unavailable`, `invalid_amount`). Fechar o celular cancela o pedido; o celular volta a fechar se foi aberto
pelo pedido. O token segue para o servidor do resource, que chama `ConsumePayment`.

## Botões laterais

À esquerda: chave do silencioso, volume + e volume −. À direita: power (salva o que estiver pendente e guarda o
celular). Os botões de volume e a chave também calam o toque de uma chamada recebida.

## Configuração (`config.lua`)

| Chave | Uso |
| --- | --- |
| `Command`, `OpenKey` | Comando e tecla padrão. |
| `Devices` | Itens de celular e o modelo de cada um (`phone = 'coe_one'`). |
| `Models` | Modelos: nome exibido (`label`), quantos chips cabem (`sims`), armazenamento em MB (`storage`) e câmera (`camera.width`, `camera.quality`). |
| `SimItem` | Item do chip (`sim_card`). |
| `Number` | Prefixo e quantidade de dígitos dos números novos. |
| `Calls` | Tempo de toque e tamanho dos recentes. |
| `Contacts`, `Messages` | Limites da agenda e das mensagens (tamanho, histórico, intervalo entre envios). |
| `Wallet` | Cartões por aparelho, validade da autorização de pagamento, valor máximo e resources que podem consumir pagamentos. |
| `Photos` | Tamanho máximo da foto e da miniatura, largura da miniatura, fotos por página, intervalo entre fotos e taxa de envio. |
| `RingVolume` | Volume máximo do toque (0 a 1), atingido no volume 10 dos Ajustes. |
| `Home` | Apps por tela, máximo de telas e tamanho da barra inferior. |
| `Settings` | Padrões dos ajustes, toques, papéis de parede, limites de brilho e da senha. |
| `Signal` | Antenas e faixas de distância das barras de sinal. |
| `Apps` | Apps do aparelho: nativos (`native`) ou de outro resource (`resource` + `script`). `dock` fixa na barra inferior. |

## Tabelas

`coe_phone_devices` (aparelho: modelo, dono original, rosto, hash da senha, ajustes e tela inicial),
`coe_phone_sims` (chip: número, titular, aparelho e slot), `coe_phone_device_contacts`, `coe_phone_photos` (fotos do
aparelho: imagem, miniatura, tamanho e quem fotografou), `coe_phone_wallet` (cartões na Carteira do aparelho), `coe_phone_messages` e
`coe_phone_calls` (por número). Migrações em `server/migrations.lua`, controle em `coe_phone_schema_migrations`.
`coe_phone_numbers`, `coe_phone_contacts` e `coe_phone_settings` são do modelo antigo (por personagem) e não são
mais usadas; ficam para conferência. Teste de integração: `coe_database/test/integration/phone_telecom_scenario.lua`.

## Testes

```
cd coe_phone
lua test/phone_test.lua
```
