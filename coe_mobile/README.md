# coe_mobile

Telefone básico do framework: o personagem tem um número e usa Telefone, Contatos, Mensagens e Ajustes simples.

- **Aparelho**: o item `phone` do `coe_inventory`. Sem ele no inventário o telefone não abre, não liga e não recebe ligações nem avisos de mensagem (quem liga ouve "fora de área"; as mensagens ficam guardadas). Abre com **F1** (cada jogador troca em Configurações > Teclas > FiveM, "Abrir telefone"), com `/telefone` ou usando o item.
- **Número**: um por personagem, gerado no primeiro uso (`555-0123`, prefixo e dígitos em `config.lua`) e fixo depois disso. Sem chip nem senha.
- **Telefone**: teclado e recentes (feitas, recebidas, perdidas, recusadas, ocupado e fora de área). A voz vai pelo `coe_talk` (efeito de telefone) num canal com id imprevisível, criado pelo servidor ao atender. A ligação toca por `Calls.RingSeconds`; sem resposta vira chamada perdida, com aviso para quem não atendeu. Com o telefone fechado, a ligação aparece no canto da tela com a dica da tecla para atender.
- **Contatos**: nome e número, com busca; ligar e mandar mensagem a partir do contato. Até `Contacts.Max` por personagem.
- **Mensagens**: conversas por número, também para quem está offline. Não lidas aparecem no ícone do app e na conversa. Apagar a conversa apaga só do seu lado.
- **Ajustes**: modo silencioso, volume e toque (gerados na própria tela, sem arquivos de áudio) e papel de parede.

Fora do telefone básico (ficam para pacotes): chips e operadora, senha e desbloqueio, câmera e galeria, carteira, loja de apps e sinal por antena.

## Pacotes que assumem o telefone

Um pacote com smartphone completo chama o export `Yield()` ao iniciar (e de novo no `onResourceStart` do `coe_mobile`). O telefone básico encerra as ligações em andamento, fecha as telas e deixa de abrir (tecla, comando e item) até o resource chamador parar; então volta sozinho. A capacidade vem do `server.cfg`:

```
add_ace resource.<nome> coe.mobile.yield allow
```

O framework não cita o pacote pelo nome: o resource que assume vem do runtime. `Status()` devolve `{ active, yieldedBy }`. `NumberOf(characterId)` devolve o número do personagem no telefone básico (ou nil, sem gerar).

Os números, contatos e mensagens do básico ficam nas tabelas `coe_mobile_*`; um pacote decide se importa esses dados.

## Segurança

- Tudo passa pelo servidor (`coe_mobile:request`, pedido e resposta). A tela não escolhe número de origem, canal de voz nem destinatário de aviso.
- O canal de voz de cada ligação é sorteado pelo servidor e aplicado pelo export `SetPlayerCall` do `coe_talk`.
- Nomes e mensagens são limpos (caracteres de controle, UTF-8 válido, tamanho em caracteres). A tela monta tudo com `textContent`.
- Intervalo mínimo entre gravações (`ActionIntervalMs`) e entre mensagens (`Messages.CooldownMs`), uma operação por jogador de cada vez.

## Configuração

`config.lua`: item, comando e tecla, formato do número, tempo de toque e tamanho dos recentes, limites de contatos e mensagens, ajustes padrão (toques e papéis de parede disponíveis), intervalo entre operações, ACE do `Yield` e a animação do celular na mão.

## Interface

O aparelho fica no canto inferior direito, no visual do `coe_ui` (cantos chanfrados, cores só por tokens, campos e botões `coe-*`), e acompanha o tema do servidor e a cor do jogador (`@coe_ui/theme_bridge.lua`). Apagar contato e conversa confirmam pelo `CoeUI.confirm`.

## Testes

```
cd coe_mobile
lua test/rules_test.lua
lua test/persistence_test.lua
lua test/server_test.lua
```

`server_test.lua` exercita o servidor com inventário, voz, avisos e persistência simulados: número gerado no primeiro uso (pulando colisões), item obrigatório, contatos, mensagens online e offline, ligação atendida, recusada, perdida, cancelada, ocupada e fora de área, queda de quem sai do jogo, ajustes, uso do item, troca de personagem e o `Yield` de um pacote.
