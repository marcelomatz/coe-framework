# coe_characters

Seleção de personagem com cena 3D e integração com o criador de personagem (`coe_appearance`). Cria, seleciona e arquiva personagens da conta persistente do jogador. Todas as regras de ownership, limite, validação e estado são aplicadas no servidor pelo `coe_core`; a NUI só envia solicitações e apresenta respostas.

## Fluxo

- Ao entrar, o jogador permanece sem controle até o Core carregar a conta e exigir uma seleção.
- O envio inicial da lista pelo servidor (`playerJoining`) pode chegar antes de este client registrar seus handlers. Por isso, ao ficar ativo, o client envia `player.clientReady` e o Core reenvia `player.loaded` e `character.selectionRequired` se a sessão estiver em seleção (limitado a uma vez por segundo, ignorado em outros estados).
- A lista apresenta apenas personagens ativos pertencentes à conta autenticada.
- **Cena**: os personagens aparecem lado a lado como peds locais (só o jogador vê) no lugar de `Scene` em `config.lua` (padrão: terraço do Observatório Galileo, de costas para Los Santos, ao pôr do sol), com hora e clima fixos só para o jogador, câmera geral e câmera no personagem escolhido com interpolação e desfoque de profundidade, poses de espera (cenários nativos) e o escolhido virado para a câmera. Personagem sem aparência aparece com o visual padrão (o aviso fica só na interface). O HUD (`coe_hud`) e o minimapa ficam escondidos desde a seleção até o personagem nascer, via evento `coe_hud:setHidden`. Para mudar o lugar: fique no ponto olhando para a paisagem, use `/coe_scene_anchor` e copie o resultado do F8 para `Scene.Anchor`/`Scene.Facing`; o chão é procurado a partir do ponto. Sem o `coe_appearance` a seleção funciona só com a NUI.
- **NUI**: lista à esquerda (setas ↑ ↓ ou clique) e destaque à direita com nome, ID, idade, gênero e "Jogar" (Enter ou duplo clique).
- **Criação**: "Criar personagem" abre o criador do `coe_appearance` (identidade, herança, rosto, detalhes, cabelo, roupas). Ao registrar, o client envia `character.createRequest` com `birthDate`, `gender`, `appearance` e `appearanceVersion`; erros do servidor aparecem dentro do criador e, no sucesso, a seleção volta com a câmera no novo personagem. Sem o `coe_appearance`, abre o formulário simples (só nome, nascimento e gênero; a NUI nunca envia aparência).
- **Personagens antigos sem aparência**: ao jogar, passam pelo criador uma vez (modo aparência, sem a etapa de identidade); o client envia `character.appearanceRequest` e, salvo, entra direto. O `coe_core` só aceita definir a aparência de quem ainda não tem.
- As regras (idade mínima/máxima, gêneros) são validadas no servidor; as opções do formulário simples vêm de `Genders` em `config.lua` (devem coincidir com `coe_character_genders`).
- Limite de personagens: o limite padrão é cinco e pode ser alterado pelo convar server-only `coe_max_characters`.
- O comando e o atalho de abertura são configuráveis em `config.lua` (`Command`, `OpenKey` e `KeyDescription`). `Debug = true` imprime no console F8 do client as etapas do fluxo (`player.clientReady enviado`, `selectionRequired recebido`, `página NUI carregada`, eventos rejeitados por origem e erros JavaScript da NUI); desative após validar o fluxo in-game.
- Arquivar preserva o registro e seus dados. Personagens arquivados não aparecem na lista nem contam para o limite ativo.
- A tecla `F7` solicita a troca do personagem ativo. O vínculo atual é encerrado no servidor antes de exibir a lista.

A seleção não envia `player_id`, proprietário ou licença do cliente. IDs e nomes recebidos pela UI são tratados como entrada não confiável e validados pelo Core.

## Dependências

`coe_core`, `coe_spawn` e `coe_notify` precisam estar iniciados. O Core requer `coe_database` e o provider MariaDB disponível antes de aceitar conexões. Ações bem-sucedidas de criação, seleção e arquivamento emitem um evento de auditoria e uma notificação breve; dados internos do log não são enviados à interface.

## Arquivos e testes

- `config.lua`: comando, tecla, descrição de mapeamento e a cena (`Scene`).
- `client/scene.lua`: cena 3D (peds, câmeras, hora, clima, streaming por `SetFocusPosAndVel`).
- `client.lua`: valida origem server-side dos eventos, conecta callbacks NUI ao barramento do Core e configura atalho.
- `html/`: lista, destaque, formulário simples e envio de callbacks NUI. O fundo da página precisa permanecer transparente: não defina `color-scheme: dark` em `:root`/`html`/`body`, pois isso pinta a NUI de opaco e cobre o jogo (use-o apenas nos controles de formulário).
- `fxmanifest.lua`: dependências, ordem de config/client e assets da NUI.

Execute `lua test\client_test.lua` na pasta do resource. O harness verifica o aviso `player.clientReady`, bloqueio de evento forjado, encaminhamento de requests, rejeição de payload inválido, resposta de seleção, configuração da tecla e a integração com o criador (personagem sem aparência abre o criador, envio de aparência e de criação com perfil, erro do servidor exibido no criador). O JavaScript da NUI, acessibilidade visual e o fluxo real com o servidor não têm testes automatizados neste resource; veja [TEST_COVERAGE.md](../TEST_COVERAGE.md).

## Tela de carregamento

O `coe_loadscreen` usa `loadscreen_manual_shutdown`: quem fecha a tela de carregamento é esta seleção, quando a cena 3D termina de montar (`ShutdownLoadingScreen` e `ShutdownLoadingScreenNui`). A interface da seleção também fica escondida (`waitScene`) até a mensagem `reveal`, que vem depois do fade in da cena; a cada abertura (inclusive F7 e volta do criador) ela só aparece com a cena pronta. Se a seleção não abrir em `LoadingScreenTimeoutMs` (30 s) depois do `player.clientReady`, a tela de carregamento fecha mesmo assim.
