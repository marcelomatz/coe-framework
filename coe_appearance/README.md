# coe_appearance

Aparência de personagem: formato salvo, aplicação no ped e o **criador de personagem**. Fecha a issue #54.

## Formato (versão 1)

`shared/schema.lua` (puro, testado) define e normaliza a aparência guardada pelo `coe_core` como JSON opaco (`appearance` + `appearance_version` em `coe_characters`, até 16 KB):

- `model`: `mp_m_freemode_01` ou `mp_f_freemode_01`.
- `heritage`: `mother` e `father` (índices do GTA Online, 0 a 45), `shapeMix` e `skinMix` (0 a 1; 0 = mãe, 1 = pai).
- `features`: 20 ajustes do rosto (-1 a 1, `SetPedFaceFeature` 0 a 19).
- `overlays`: 13 sobreposições (`SetPedHeadOverlay` 0 a 12) com `style` (-1 = nenhuma), `opacity`, `color` e `secondColor`.
- `hair` (`style`, `texture`, `color`, `highlight`), `eyeColor` (0 a 31).
- `components` e `props`: drawable e textura por id (roupas e acessórios; prop -1 = nenhum).

Valores fora da faixa são trazidos para a faixa e chaves desconhecidas são descartadas. Na hora de aplicar, roupas e cabelos além do que o modelo tem voltam para 0 (natives), então uma aparência antiga nunca deixa o ped sem rosto.

## Exports (client)

- `Apply(ped, appearance)`: aplica tudo menos o modelo.
- `ApplyToPlayer(appearance)`: troca o modelo do jogador e aplica.
- `CreatePed(appearance, x, y, z, heading, gender?)`: ped local para cenas (seleção, criador); sem aparência usa o modelo do gênero.
- `Normalize(appearance)`, `Default(gender)`, `Version()`.
- Criador: `OpenCreator({ mode = 'create'|'appearance', characterId?, gender?, firstName?, lastName?, birthDate? })`, `CloseCreator()` (deixa a tela escura para quem chamou montar a próxima cena), `CreatorError(mensagem)`, `IsCreatorOpen()`.
- Eventos locais: `coe_appearance:creatorSubmit` (`{ mode, characterId, identity, appearance, version }`) e `coe_appearance:creatorCancelled`. O `coe_characters` ouve e fala com o servidor.

## Criador de personagem

Abre na sala de lineup do criador do GTA Online (`Creator.Ped` em `config.lua`), com ped local, animação de espera do próprio jogo, hora congelada e câmeras com interpolação e desfoque de profundidade (corpo, busto, rosto e pernas; cada etapa escolhe a sua). Etapas:

1. **Identidade** (só na criação): nome, sobrenome, nascimento e gênero.
2. **Herança**: mãe e pai com os retratos do jogo (`https://nui-img/char_creator_portraits/...`), semelhança e tom de pele.
3. **Rosto**: os 20 ajustes agrupados (nariz, sobrancelhas, maçãs, olhos e lábios, mandíbula e queixo, pescoço).
4. **Detalhes**: cor dos olhos, pele, envelhecimento, sardas, manchas e danos do sol.
5. **Cabelo e maquiagem**: corte e variação, cor e luzes da paleta do jogo (`GetPedHairRgbColor`), sobrancelhas, barba e pelos (masculino), maquiagem, blush e batom (`GetPedMakeupRgbColor`).
6. **Roupas**: abas por subcategoria (Conjuntos, Tronco, Pernas e pés, Cabeça, Acessórios — `AppearanceSchema.ClothingCategories`), pílulas por peça, grade com a foto de cada peça (carrega conforme a rolagem; campo "Nº" pula direto) e as variações de cor da peça escolhida. Limitado ao que o modelo tem, incluindo DLCs e addons; a câmera acompanha a peça.
7. **Revisão** e registro.

Arrastar no espaço livre (ou A/D) gira o personagem; "Aleatório" sorteia herança, rosto e detalhes coerentes. Depois de registrado, o visual só muda por barbearia e loja de roupas (futuro): o `coe_core` só aceita definir a aparência de um personagem que ainda não tem.

## Fotos das peças

As fotos são geradas no próprio servidor, uma vez (e de novo quando entrarem roupas novas):

1. Dê a ACE: `add_ace group.admin coe_appearance.thumbs allow` e deixe o `screenshot-basic` iniciado.
2. No jogo: `/coe_fotos_roupas` (os dois gêneros), `/coe_fotos_roupas male` ou `female`; `refazer` tira de novo as que já existem. Backspace ou repetir o comando interrompe.
3. O cliente monta a sala do criador, veste cada peça sobre a roupa base (`Thumbnails.BaseOutfit`), enquadra pela subcategoria (`Thumbnails.Cameras`), fotografa, recorta o centro e reduz para 256 px em WebP na NUI, e envia ao servidor (evento latente). O servidor confere nome, tipo e tamanho e salva em `thumbs/<male|female>_<c|p><id>_<drawable>.webp`.
4. Reinicie o `coe_appearance`: as fotos são arquivos do recurso e os jogadores baixam uma vez (ficam em cache). Para não pesar no download, `Thumbnails.Base` pode apontar para uma CDN https com os mesmos nomes.

Sem foto, o card mostra o número da peça.

## Configuração

`config.lua`: posição do ped e do foco de streaming, câmeras, câmera de cada etapa, animação de espera, desfoque, hora e conjuntos prontos. Os drawables dos conjuntos variam com DLCs e addons de roupa: confira no jogo.

## Testes

`lua test/schema_test.lua`: modelos, padrão, normalização (faixas, tipos, chaves desconhecidas, idempotência), sorteio, retratos, catálogo de ajustes, subcategorias de roupa e nomes das fotos. `lua test/thumbs_server_test.lua`: base64, conferência das fotos, ACE e sessão do gerador. Natives, câmeras e a NUI precisam de validação no jogo.
