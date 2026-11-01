# coe_mechanic

Mecânica de veículos (#140). Peças e serviço por quilometragem, tuning visual/pintura/livery, oficinas e orçamentos (`coe_businesses`), bancadas de craft (`coe_crafting`), baús (`coe_inventory`) e app Diagnóstico no tablet (`coe_tablet`). Próximas fases: reparos e lataria, motores e câmbio, dyno, cobrança e faturas (#140).

## Peças

Cada peça desgasta pela quilometragem do `coe_vehicles` desde a última troca (sem timers). Veículos sem registro usam a fábrica (km 0), então carros já rodados chegam desgastados.

| Peça | Vida | Efeito quando gasta |
|---|---|---|
| engine_oil | 20 km | menos força, mais dano ao motor |
| air_filter | 30 km | menos força |
| spark_plugs | 40 km | menos força |
| brake_pads | 35 km | menos freio |
| brake_discs | 80 km | menos freio |
| clutch | 90 km | trocas de marcha mais lentas |
| suspension | 100 km | suspensão e barra estabilizadora mais fracas |

Sem efeito até o `threshold` de cada peça; depois o efeito cresce até o máximo. O desgaste é aplicado no handling por `coe_handling` (multiplicadores via `GetEffects`). Tudo configurável em `config.lua`.

## API (servidor)

`Inspect`, `ReplacePart`, `ServiceVehicle`, `AdjustMileage`, `AddWear`, `GetEffects`, `ListParts`, `IsReady`. Escritas só para `WriterResources`; `AdjustMileage` também exige que o resource esteja em `MileageEditors` de `coe_vehicles`. Evento local `coe_mechanic:partsChanged(vehicleId)`. Ver `types.lua`.

**Desgaste extra** (`AddWear(vehicleId, metros, peças)`, só `WearResources`): soma metros ao desgaste das peças (coluna `extra_wear_m`, migração 4) sem mexer na quilometragem. O `coe_fuel` soma com gasolina comum (velas, filtro de ar e óleo gastam mais cedo) e desconta com a aditivada (só o extra já acumulado). A troca da peça zera o extra.

## Comandos (ACE `command.<nome>` ou console)

- `coe_parts <placa>`: inspeção no console.
- `coe_part_replace <placa> <peça|all>`: troca uma peça ou faz a revisão.
- `coe_mechanic_mileage <placa> <km>`: ajusta a quilometragem (auditado).

## Tuning visual, pintura e livery (fase 2)

A aparência é salva por veículo (`coe_vehicle_appearance`, JSON validado) e publicada no state bag `coe:appearance`; o cliente aplica ao carregar o veículo. Cobre: cores GTA (primária, secundária, perolada, rodas, interior, painel), cor RGB livre, mods (`SetVehicleMod` por tipo), turbo/fumaça/xenon, **livery** (nativa do modelo ou mod 48, usada quando o modelo oferece), vidros, placa, tipo de roda, cor do xenon, neon e extras.

- O servidor só aceita campos conhecidos e dentro dos limites (`config.Appearance`); o cliente ainda confere a quantidade de mods que o modelo suporta, então índices inexistentes são ignorados.
- `QuoteAppearance` calcula o orçamento como fração do valor do veículo no catálogo, com multiplicador por classe e acréscimo por nível (`config.Pricing`). Remover um item é grátis. A cobrança não existe ainda: quem chama (`coe_economy`/tablet) cobra e depois chama `SetAppearance`.
- Cliente: `coe_appearance_options` (no veículo) imprime os mods, liveries e extras que o modelo suporta; o export `GetVehicleOptions(vehicle)` serve à UI futura.
- Comandos (ACE `command.<nome>`): `coe_paint <placa> <primária> [secundária]`, `coe_livery <placa> <índice>`, `coe_tune <placa> <tipoMod> <índice>`, `coe_appearance_quote <placa> <tipoMod> <índice>`.

Pendente: câmera de prévia, stance e LightingControl com efeitos.

## Oficinas e orçamento (Benny's)

As oficinas **não são mais definidas na config**: cada uma é um negócio da categoria *Mecânicas* criado na aba **Negócios** do `coe_admin` (área de trabalho, showroom, baús, mesas de craft e regras), guardado no `coe_businesses`. Sem nenhum negócio cadastrado não há oficina em jogo. O `config.Shops` é só a tabela em memória preenchida a partir do registro. Regras: `ownerAccess` (dono pode atender; padrão sim) e `priceMultiplier` (aplicado no orçamento; o mecânico ainda ajusta dentro dos limites). Receitas ficam em `config.Recipes.mechanic` e são registradas no `coe_crafting` (categoria `mechanic`).

Fluxo do cliente:
1. Entra no showroom dirigindo o veículo (precisa ter a chave) e aperta **E**.
2. Monta a lista (cores, peças, turbo/xenon/fumaça, vidros, livery). A prévia é local, no próprio veículo, e é desfeita ao sair; a estimativa de preço vem do servidor.
3. **Pedir orçamento** abre um pedido (um por veículo; expira sem resposta, `Orders.TtlMs`).
4. O mecânico vê o pedido no tablet (app Diagnóstico, aba **Orçamentos**), ajusta o valor dentro de ±50% da estimativa e envia com uma observação.
5. O cliente aprova ou recusa. Aprovado, o mecânico **executa o serviço** (precisa estar a até `TabletRadius` do veículo): a aparência é gravada e publicada.

Regras no servidor: chave, veículo e jogador dentro do showroom, estados do pedido (`requested → quoted → approved → done`), só o cliente dono aprova, só mecânico da equipe da oficina (`coe_businesses:Access`, de ponto) no perímetro (`ShopWorkRadius`) precifica ou executa. Os pedidos ficam em memória. A cobrança entra por `deps.charge` quando ligada ao `coe_economy`; hoje o serviço é gratuito.

### Interface e câmera do showroom

- Abas por categoria: Cores, Carroceria, Desempenho, Rodas, Interior, Luzes e Livery (ponto marca abas com alterações).
- Seletores: passo + slider para peças, chaves para turbo/xenon/extras, paleta nomeada e seletor livre (RGB) para pintura, tipos de roda, vidros e neon (4 lados + cor).
- Câmera orbital com predefinições (frente, lateral, traseira, topo, rodas, motor, cabine), **interior** (cabeça do motorista; arrastar olha ao redor, roda ajusta o FOV), arrastar para girar, roda do mouse para zoom e giro automático.
- **Câmera livre**: WASD, E/Q sobe/desce, Shift acelera, Ctrl desacelera, Backspace sai. Limitada ao raio da oficina (`Camera` em `config.lua`).
- O veículo fica congelado enquanto o showroom está aberto.

Pendente: cobrança automática pelo `coe_economy`, consumo de itens do `coe_inventory` na aplicação, troca física de peças e lataria.

## Negócio: dono, bancada de craft e baú

- **Dono** (por personagem): definido na aba **Negócios** do `coe_admin`, no painel do próprio negócio (ID do personagem, o mesmo do `/id`; funciona com o personagem offline) e guardado no `coe_businesses`. O dono tem acesso completo ao tablet da oficina e atende como mecânico mesmo sem o emprego (regra `ownerAccess`); sem dono, vale o emprego da oficina. Export `GetShopOwner(shopId)`. O comando `coe_shop_owner` e a tabela `coe_mechanic_businesses` não são mais usados.
- **Ponto** (`clocks`, regras `clockRequired` e `clockOffsite` do `coe_businesses`): a equipe cadastrada da oficina (aba Equipe; o emprego não vale) precisa bater o ponto para atender; o dono também, salvo `clockRequired = false`. Bata no ponto marcado (E, dentro da área) ou, se a oficina não tiver nenhum, com `/ponto` dentro da área; `/ponto` também encerra o ponto de qualquer lugar. Sem `clockOffsite`, sair da área encerra o ponto (checagem a cada 5 s).
- **Bancadas de craft** (`crafts`: lista de pontos; receitas em `Recipes.mechanic`): só dono e equipe de ponto batido. A execução e o painel são do `coe_crafting` (a mecânica só decide o ponto e quem tem acesso). O painel mostra o que cada receita consome (tenho/preciso). Produzir leva `timeMs` com animação; o servidor confere de novo equipe, distância e materiais ao concluir, consome os insumos e entrega a peça (se não couber na mochila, os insumos voltam). Uma produção por vez; sair da área ou fechar cancela. Itens novos (borracha, plástico, kit de reparo e peças de oficina) estão em `coe_inventory/data/coe_parts.lua`.
- **Baús** (`stashes`: lista de pontos com slots e peso): só dono e equipe, abertos pelo `OpenStash` do `coe_inventory` (id `stash:mechanic:<oficina>` para o baú `main`, senão `stash:mechanic:<oficina>:<baú>`), que fecha sozinho se o jogador se afastar. Os conteúdos persistem. Eventos: `openCraft/openStash(shopId, stationId)`.
- **Aviso de interação**: no canto superior esquerdo, no mesmo visual do painel de localização do HUD, mostra a oficina e a opção com a tecla **E** (showroom dentro do veículo; bancada e baú a pé, só para quem é da equipe).
- As coordenadas da bancada e do baú da Benny's são provisórias: ajuste em `config.lua` jogando.

## Limitações

A cobrança de orçamentos (`deps.charge` via `coe_economy`) e o consumo de peças do `coe_inventory` na troca ainda não estão ligados (#140); as trocas são feitas pelo app Diagnóstico do tablet, por quem estiver em `WriterResources` ou pelos comandos administrativos. Valores precisam de ajuste jogando.
