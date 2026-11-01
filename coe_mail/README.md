# coe_mail

App de e-mail do smartphone e do tablet. Vem instalado em todo aparelho (`coe_apps`, categoria Sistema).

## Contas

- Qualquer personagem cria contas no domínio público `PublicDomain` (`nome@correio.coe`). O limite é `Accounts.MaxPerCharacter` (3) contas por personagem.
- O nome antes do @ tem de 3 a 24 caracteres: letras minúsculas, números, `.`, `_` ou `-`. Não pode começar nem terminar com símbolo, nem ter dois símbolos seguidos. Nomes em `Reserved` ficam bloqueados.
- A senha tem de 6 a 32 caracteres e é guardada com hash (`GetPasswordHash`).
- Quem sabe a senha entra na conta em qualquer aparelho.
- **Minhas contas** lista as contas criadas pelo personagem. Ali dá para:
  - **Redefinir senha** ("esqueci a senha"): a conta sai dos outros aparelhos e abre neste.
  - **Excluir** a conta (pede a senha): apaga as mensagens e libera o endereço.
- **Ajustes**:
  - nome de exibição e assinatura (vai no fim das mensagens novas);
  - troca de senha (pede a atual e encerra a conta nos outros aparelhos);
  - **Sair** deste aparelho.
- Depois de `Login.MaxFailures` senhas erradas seguidas, a conta fica bloqueada por `Login.LockSeconds`.

## Sessões por aparelho

- A sessão fica presa ao aparelho, não ao personagem:
  - **Smartphone**: pelo número de série (`coe_phone:ActiveDevice`). Quem pega o celular desbloqueado vê as contas abertas nele.
  - **Tablet**: pelo personagem.
- Cada aparelho abre até `Login.MaxSessionsPerDevice` contas e troca entre elas pelo seletor no topo. **Adicionar conta** entra em outra.

## Mensagens

- **Pastas**:
  - Entrada, Com estrela, Enviados, Rascunhos, Arquivo e Lixeira.
  - A Lixeira é apagada sozinha depois de `Messages.TrashDays` dias; o botão **Esvaziar** pede confirmação.
- **Escrever**:
  - campos Para, Cc e Cco: até `MaxRecipients` endereços no total, separados por vírgula;
  - o assunto e o texto têm limite de tamanho;
  - entre envios da mesma conta há uma espera de `SendCooldownSeconds`.
- **Endereços**: um endereço que não existe recusa o envio inteiro e mostra qual é. Uma conta cheia (`MaxPerAccount` mensagens) não recebe; o remetente é avisado.
- **Cco**: só quem enviou vê a lista de cópias ocultas.
- **Leitura**: responder, responder a todos (sem repetir o próprio endereço), encaminhar, estrela, marcar como não lida, arquivar ou desarquivar, mandar para a Lixeira, restaurar e apagar para sempre.
- **Rascunhos**:
  - **Salvar rascunho** guarda o texto; sair do editor com alterações também salva;
  - abrir um rascunho volta ao editor;
  - enviar tira a mensagem dos Rascunhos.
- **Busca** no assunto, no texto, no remetente e nos destinatários da pasta aberta.
- **Aviso de chegada**: um e-mail novo avisa (`coe_notify`) quem está com um aparelho conectado na conta. Com o app aberto, a caixa se atualiza a cada 20 s.

## Para outros resources

`Send(from, to, subject, body)` envia e-mails do sistema. Só resources em `SystemCallers` podem usar.

| Parâmetro | Formato |
|---|---|
| `from` | `{ address, name }` |
| `to` | endereço ou lista |
| retorno | `{ ok, bounced }` ou `{ ok = false, error }` |

## Banco

| Tabela | Conteúdo |
|---|---|
| `coe_mail_accounts` | endereço, domínio, nome, assinatura, hash da senha e personagem que criou |
| `coe_mail_sessions` | contas abertas por aparelho (`phone:<serial>` ou `tablet:<personagem>`) |
| `coe_mail_messages` | conteúdo: remetente, assunto, texto e listas Para/Cc/Cco |
| `coe_mail_boxes` | uma linha por conta que vê a mensagem: pasta, lida, estrela e papel (`from`/`to`) |

A coluna `domain` já separa o domínio público dos domínios próprios. Eles virão depois, com o provedor de e-mail e o registro de domínios das operadoras (`coe_telecom`). A limpeza periódica (`PurgeMinutes`) apaga a Lixeira vencida e as mensagens que nenhuma caixa usa mais.

## Dependências

`coe_core`, `coe_database`, `coe_logging`, `coe_apps` (instalação), `coe_phone`/`coe_tablet` (aparelhos) e `coe_notify` (avisos). O resource precisa estar nas listas de `coe_database`, `coe_notify`, `coe_logging` e `coe_audit`.
