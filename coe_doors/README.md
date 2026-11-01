# coe_doors

Portas e fechaduras do mapa e de MLOs. Cadastro na aba **Portas** do admin (`coe_doors_registry`).

- **Local:** cada cadastro é um local (casa, prédio, sede) com até 12 portas (`Limits.MaxEntries`). Acesso, senha e chave são do local e valem para todas as portas dele; cada porta tranca e destranca separadamente.
- **Porta:** tipo (simples, dupla, portão de garagem, portão), 1 ou 2 folhas capturadas mirando no objeto, além de nome, distância, trancamento automático e estado padrão próprios. O cliente registra as folhas no sistema de portas do jogo e aplica o estado trancada/destrancada para todos. Garagens e portões aceitam folhas mais afastadas (`WideLeafGap`) e distância até 12 m (de dentro do veículo); destrancados, ficam abertos (a pé ou de carro) até alguém fechar.
- **Interação:** perto da porta (1 a 6 m; garagem/portão até 12 m) aparece o aviso padrão do `coe_ui` com o estado e **E** para trancar/destrancar (abrir/fechar em garagens e portões). O servidor confere distância, acesso e limite de frequência.
- **Acesso** (qualquer regra basta, para todas as portas do local):
  - **Personagem:** lista de personagens (busca por nome ou ID, offline também).
  - **Negócio/corporação:** dono, sócios e equipe; opcionalmente só com ponto batido (`coe_businesses`).
  - **Facção:** membros com grau mínimo (`coe_factions`, `ReaderResources`).
  - **Itens:** até 4 itens que abrem (ex.: cartão de acesso).
  - **Chave:** item `key` com metadata `{"door":"<id do local>"}` (entregue pela aba **Itens** do admin); abre todas as portas do local.
- **Senha:** teclado numérico (4 a 8 dígitos) para quem não tem acesso pelas regras. Guardada só como SHA-256 com salt; após `Pin.MaxAttempts` (5) erros o jogador espera `Pin.LockoutSeconds` (60 s) naquele local (auditado: `door_pin_lockout`).
- **Dono:** personagem definido no admin (aba **Local**). Abre todas as portas do local e gerencia cada porta no tablet (`/casa`, app **Casa**).
- **Porta exclusiva:** só o dono e até 6 pessoas (`Limits.MaxEntryCharacters`) abrem; chave, regras e senha do local não valem nela.
- **Senha da porta:** pedida para destrancar mesmo de quem tem acesso (dono incluído); trancar não pede. Com senha do local e da porta, o teclado pede as duas em sequência. Também só como hash.
- No tablet, o dono torna portas exclusivas, adiciona pessoas pelo ID (`/id`, precisam estar na cidade), remove pessoas e define/remove a senha de cada porta (auditado: `door_owner_<ação>`). Acesso geral do local continua só no admin.
- **Trancamento automático:** opcional, por porta, em segundos (até 1 hora) depois de destrancada. Um novo toque na porta reinicia a contagem.
- **Estado:** em memória. Ao reiniciar o servidor (ou o resource), cada porta volta ao padrão do cadastro ("Trancada por padrão").

## Exports (server)

- Só `coe_admin`: `List()`, `Save(local)` (`isNew` recusa ID repetido), `Delete(id)`.
- Livres: `IsLocked(id)`, `SetLocked(id, trancada)` (assaltos, eventos, scripts de negócio), `CanAccess(playerId, id)`, `IsReady()`. `id` é `"<local>:<porta>"` para uma porta ou `"<local>"` para todas (`IsLocked` só é `true` com todas trancadas).
- Só `coe_tablet`: `TabletVisible(playerId)` (é dono de algum local) e `TabletCall(playerId, 'home', ação, dados)` com `list`, `restrict`, `allow` (`stateId`), `revoke` (`characterId`), `pin`, `clearPin`.

Cadastros antigos (uma porta por registro) são lidos como um local com a porta `principal`; ao salvar, passam ao formato novo.

Erros: `invalid_id`, `invalid_label`, `invalid_doors`, `invalid_entry`, `duplicate_entry`, `entry_limit`, `invalid_distance`, `invalid_autolock`, `invalid_access`, `invalid_pin`, `invalid_owner`, `duplicate_id`, `door_limit`, `unknown_door`, `not_ready`, `forbidden`. No tablet: `not_owner`, `unknown_entry`, `target_not_found`, `target_not_online`, `is_owner`, `already_allowed`, `allowed_limit`, `unknown_person`, `no_character`.

## Mapa dos scripts

- `config.lua`: limites, distâncias, senha e item de chave.
- `server/rules.lua`: validação do cadastro, senha e avaliação de acesso (puro, testado em `test/doors_test.lua`).
- `server/sha256.lua`: SHA-256 em Lua puro.
- `server/persistence.lua` / `server/migrations.lua`: tabela `coe_doors_registry` (JSON por local).
- `server/main.lua`: estado, eventos de rede, trancamento automático e exports.
- `client/main.lua`: sistema de portas do jogo, aviso e teclado.
- `html/`: teclado de senha, aviso padrão (`coe_ui`) e app **Casa** do tablet (`tablet_app.js`).

## Validação no jogo

1. `ensure coe_doors` (já incluído por `ensure [coelho]`).
2. Admin → **Portas** → **+ Nova** → aba **Portas** → **Mirar na porta**: mire, **E** em cada folha, **Enter**. Use **+ Adicionar porta** para fundos, garagem, portão etc. e escolha o tipo de cada uma.
3. Defina o acesso e/ou a senha e salve. Chegue perto de qualquer porta do local: o aviso mostra o estado; **E** alterna só aquela porta.
4. Defina um dono (aba **Local**). Com esse personagem, `/casa`: torne uma porta exclusiva, adicione alguém pelo `/id` e defina uma senha. Confirme que a chave do local não abre a porta exclusiva e que a senha é pedida ao destrancar.
