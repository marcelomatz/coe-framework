# coe_staff

Painel básico da staff, para o administrador testar o servidor e os scripts. Abre com **F10** (cada jogador troca em Configurações > Teclas > FiveM, "Abrir painel da staff") ou `/staff`, só para quem tem alguma ACE abaixo. Cada aba é um módulo; o servidor confere a ACE do módulo em toda ação, valida os dados e audita (`coe_audit`, categoria `admin`).

## Instalação

```cfg
ensure coe_staff

# tudo
add_ace group.admin coe.staff.all allow
# ou por módulo
add_ace group.moderator coe.staff.self allow
add_ace group.moderator coe.staff.players allow
add_principal identifier.license:SUA_LICENSE group.admin
```

Os nomes das ACEs ficam em `config.lua` (`Ace`).

## Módulos

- **Pessoal** (`coe.staff.self`): noclip (W/A/S/D, Q/E desce e sobe, Shift acelera, roda do mouse muda a velocidade; atalho `/noclip`), invisível, invencível, coordenadas na tela, curar, reviver, ir ao marcador do mapa, teleporte por coordenadas (aceita `x, y, z` ou `vector3(...)`) e a posição atual para copiar como `vector3`, `vector4` ou `{ x, y, z }`.
- **Jogadores** (`coe.staff.players`): lista online com ID, conta, personagem, ID de cidadão e ping. Por jogador: ir até, trazer, congelar, curar, reviver, expulsar (com motivo), dar item (catálogo do `coe_inventory`, com busca e imagens), dar ou retirar dinheiro em espécie (item `money`) ou na conta (`coe_economy`, motivo `admin_adjustment`) e definir ou remover grupos do `coe_core` (`config/groups.lua`).
- **Veículos** (`coe.staff.vehicles`): busca no `coe_vehicle_catalog` (ou modelo digitado) e cria **temporário** (sem registro) ou **registrado** (no `coe_vehicles`, em nome do personagem do admin, com chave). No veículo atual ou no mais próximo: consertar, abastecer, limpar, desvirar e apagar (o registrado é guardado pelo `coe_vehicles`).
- **Mundo** (`coe.staff.world`): horário (com opção de parar o relógio) e clima para todos, volta ao ciclo natural e aviso para todos os jogadores online. Sem nada definido, o jogo segue o próprio ciclo.
- **Negócios** (`coe.staff.businesses`): lista, cria e edita negócios do `coe_businesses`. A área nasce como um círculo em volta do admin (raio ajustável, redefinível); relógios de ponto, baús, bancadas e showroom são marcados na posição do admin ("Adicionar aqui"). Também: nome, ativo, regras da categoria, dono e equipe pelo ID de cidadão (online ou offline), cargos com salário e permissões, ir até e apagar. Trocar ou remover o dono desfaz a sociedade.

## Acesso a outros resources

O `coe_staff` está nos padrões do framework para o que usa: `coe_core` (grupos), `coe_economy` (conta), `coe_vehicles` e `coe_businesses` (gravação), `coe_database` (busca de personagem offline), `coe_notify`, `coe_logging` e `coe_audit`.

## Pacotes que assumem o painel

Um pacote com painel completo chama o export `Yield()` ao iniciar (e de novo no `onResourceStart` do `coe_staff`). O básico fecha e deixa de abrir até o resource chamador parar; então volta sozinho. A capacidade vem do `server.cfg`:

```
add_ace resource.<nome> coe.staff.yield allow
```

O framework não cita o pacote pelo nome: o resource que assume vem do runtime. `Status()` devolve `{ active, yieldedBy }`.

## Configuração

`config.lua`: comando e tecla, ACEs, intervalo entre ações, tamanho do payload, limites (itens, dinheiro, textos, raios), motivo do extrato, climas oferecidos e velocidades do noclip.

## Interface

Painel no visual do `coe_ui` (painel chanfrado, campos e botões `coe-*`, cores só por tokens), acompanhando o tema do servidor e a cor do jogador (`@coe_ui/theme_bridge.lua`). Expulsar e apagar negócio confirmam pelo `CoeUI.confirm`.

## Testes

```
cd coe_staff
lua test/rules_test.lua
lua test/server_test.lua
```

`server_test.lua` exercita o servidor com natives e exports simulados: ACE por módulo, limite de taxa e de payload, ferramentas pessoais, jogadores (teleporte, congelar, expulsar, item, dinheiro em espécie e na conta, grupos), veículos temporários e registrados, mundo, negócios (criar, pontos, dono online e offline, equipe, cargos, apagar) e o `Yield` de um pacote.
