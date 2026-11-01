# coe_fuel

Combustível do Coe: consumo nos veículos, quatro combustíveis, todos os postos do mapa com bandeira, bombas com
pagamento e galão (etapa A) e, para os postos de jogador, tanques por nível, preço por litro do dono, frota de
abastecimento (van → caminhão → caminhão-tanque), refinaria e upgrades liberados por dinheiro + litros vendidos
(etapa B).

## Combustíveis

| Combustível | Motor | Preço/L | Consumo | Força | Peças do motor |
| --- | --- | --- | --- | --- | --- |
| Gasolina comum | flex | $6 | 1,00× | 1,00× | +0,5 m de desgaste extra por metro (velas, filtro de ar, óleo) |
| Gasolina aditivada | flex | $7 | 0,88× (rende mais) | 1,02× | −0,25 m por metro: limpa o desgaste extra acumulado pela comum |
| Etanol | flex | $4 | 1,30× (queima mais) | 1,06× (anda mais) | — |
| Diesel | diesel | $5 | 1,00× | 1,00× | — |

- O tanque guarda a **mistura** (litros de cada combustível). Consumo, força e desgaste são a média pelos litros;
  o consumo tira de cada combustível na proporção.
- A força entra no handling pelo `coe_handling` (campo `fInitialDriveForce`, multiplicando com o desgaste das peças).
- O desgaste extra vai para o `coe_mechanic` (`AddWear`, a cada 500 m acumulados) e zera quando a peça é trocada.
- Tudo em `config.lua` (`Fuels`).

## Motores

- **Flex** (gasolina e etanol): todos os veículos, exceto os abaixo.
- **Diesel**: classes comerciais, industriais, utilitários, serviço e militares (`DieselClasses`) e os modelos de
  `DieselModels` (picapes e vans de carga). `FlexModels` força flex num modelo.
- **Sem combustível**: bicicletas, helicópteros, aviões e trens (`NoFuelClasses`; aeronaves entram depois).
- A bomba e o galão **bloqueiam** o combustível errado.

## Consumo

- Tanque e consumo por classe do GTA (`Classes`: litros e L/100 km), multiplicados por `ConsumptionScale` (8×,
  escala do mapa: um tanque cheio dura cerca de uma hora dirigindo), pela rotação e pela mistura. Marcha lenta:
  `IdlePerHour`.
- O client do motorista mede distância, tempo com o motor ligado e rotação média e manda a cada `ReportSeconds`
  (5 s). O servidor só aceita o motorista, limita o tempo ao real e a distância a `MaxSpeed` × tempo, e calcula os
  litros. Saltos grandes (teleporte) não contam.
- O tanque fica no state bag `coe:fuel` (`liters`, `capacity`, `level`, `engine`, `main`, `tank`). O client põe o
  nível no `SetVehicleFuelLevel`, então o HUD (`coe_hud`) mostra sem mudança. Tanque vazio desliga o motor.
- Veículos registrados (`coe_vehicles`) guardam o tanque no banco (começam com metade); os demais (NPC, admin)
  começam com 20% a 60% e não são gravados.
- `/combustivel` (F8) mostra o tanque do veículo em que você está.

## Postos e bombas

- 27 postos (`Stations`) com bandeira: **Ron**, **Globe Oil**, **Xero**, **LTD Gasoline** e **sem bandeira**.
  Blip de posto com a cor da bandeira ("Posto Ron", "Posto sem bandeira"...). Bandeiras e posições são provisórias:
  confira a placa de cada posto no jogo e ajuste no config.
- Cada posto é um negócio do `coe_businesses` (categoria `gas_station`): `posto_<id>`, criado sem dono. Os cinco
  LTD usam o negócio da loja do `coe_shops` (`ltd_*`), então loja e bombas são o mesmo negócio.
- Alvo **Abastecer** em todas as bombas do mapa (`PumpModels`), só dentro de um posto. A tela imita a frente de uma
  bomba com a identidade da bandeira (`Brands[...].theme`: cor principal, destaque e texto): visor de cristal líquido
  com total, litros e preço por litro, botões de produto com o preço por litro, destino (veículo perto da bomba, um
  galão seu ou um galão novo), litros e pagamento: **dinheiro**, **Carteira do celular** ou **cartão na maquininha**
  (com senha), como nas lojas.
- Abastecendo, um **mostrador** no canto da tela conta os litros e o total até o valor pago, na cor da bandeira. O
  tempo é proporcional aos litros (`PumpRate`, 2,5 L/s na bomba; `Can.pourRate`, 2 L/s no galão) e o marcador de
  combustível do veículo sobe junto.
- A receita vai para o caixa do negócio (`SocietyCollect`, motivo `fuel_sale`); a venda fica em `coe_fuel_sales`.
- **Posto da staff** (sem dono): estoque infinito e preço de tabela. **Posto de jogador**: vende só o que está nos
  tanques do posto, pelo preço do dono.

## Postos de jogador: tanques, frota e refinaria

Tudo pela aba **Posto** do app do negócio no tablet (`coe_businesses`), que mostra litros vendidos (histórico),
vendas de hoje e de 7 dias, caixa, tanques, preços, frota e o GPS da refinaria.

- **Preço por litro**: o dono (ou cargo com `fuel.manage`) define cada combustível entre 0,5× e 3× o de tabela
  (`PriceBand`), ou volta ao de tabela.
- **Tanques por nível** (`TankLevels`), um nível por combustível: 5.000 L → 10.000 L ($20.000 + 10.000 L vendidos)
  → 20.000 L ($50.000 + 40.000 L) → 40.000 L ($120.000 + 120.000 L).
- **Frota de abastecimento** (`FleetTiers`), comprada em ordem: **Van pequena** (`speedo`, 800 L, $8.000) →
  **Caminhão** (`benson`, 3.500 L, $45.000 + 15.000 L vendidos) → **Caminhão-tanque** (`phantom`, 12.000 L,
  $150.000 + 80.000 L vendidos). Cada compra cria um veículo registrado (`coe_vehicles`) na **garagem de frota do
  posto** (`coe_garages`, liberado para a equipe). A staff precisa criar essa garagem (tipo Negócio, ligada ao posto)
  na aba Garagens do admin; sem ela a compra é recusada e o valor não é cobrado.
- **Histórico de funcionamento**: litros vendidos pelo posto como posto de jogador (`coe_fuel_sales`, modo `player`).
- Upgrades e combustível de atacado saem do **caixa do posto** (`SocietyCharge`: `fuel_tank_upgrade`,
  `fuel_fleet_upgrade`, `fuel_refinery`).
- **Refinaria** (`Refinery`, blip no mapa; posição provisória): com o veículo da frota estacionado lá, o alvo
  **Carregar combustível** abre a tela de carga: litros de cada combustível (inteiros, somando até a capacidade do
  veículo), preço de atacado por litro (`Refinery.prices`), custo e caixa. A carga fica no veículo (state bag
  `coe:fuelCargo` e banco), também depois de guardar.
- **Descarga**: no próprio posto, o alvo **Descarregar no posto** passa a carga para os tanques até encherem; o que
  não couber fica no veículo.
- Carga e descarga têm o mostrador na tela e tempo proporcional aos litros (`LoadRate`, 100 L/s).
- **Quem faz**: carregar e descarregar, o dono ou a equipe de ponto com `fuel.supply` (Posto: carregamentos na
  refinaria); preços e melhorias, o dono ou `fuel.manage` (Posto: preços e melhorias).
- A staff ainda pode corrigir um tanque com `coe_fuel_tank <posto> <combustível> <litros>`.

## Galão

Item `fuel_can` (`coe_inventory`, 20 L, metadata `{ fuel, liters }`). Na bomba: galão novo ($60 + o combustível)
ou completar um seu (galão vazio aceita qualquer combustível). **Usar** no inventário despeja no veículo mais perto
(até 3,5 m), conferindo o motor.

## Banco

| Tabela | Conteúdo |
| --- | --- |
| `coe_fuel_vehicles` | Tanque dos veículos registrados: motor, capacidade e litros de cada combustível. |
| `coe_fuel_tanks` | Tanques dos postos de jogador: litros e nível de cada combustível. |
| `coe_fuel_prices` | Preço por litro definido pelo dono (sem linha = tabela). |
| `coe_fuel_fleet` | Veículos da frota de abastecimento: posto, nível e carga de cada combustível. |
| `coe_fuel_sales` | Vendas: posto, personagem, combustível, litros, total, pagamento, destino e modo. Base do histórico de funcionamento dos upgrades. |

Migrações em `coe_fuel_schema_migrations`.

## Exports (servidor)

| Export | Retorno |
| --- | --- |
| `IsReady()` | `true` depois das migrações e da leitura dos tanques. |
| `GetFuel(vehicleId)` | Resumo do tanque de um veículo registrado em uso, ou `nil`. |
| `GetEffects(vehicleId)` | `{ mods = { fInitialDriveForce }, key }` da mistura (usado pelo `coe_handling`). |
| `GetStationTanks(stationId)` | `{ business, tanks, levels, capacities }` dos tanques do posto. |
| `IsStation(businessId)` | `true` se o negócio é um posto (aba Posto do tablet). |
| `BusinessTablet(playerId, characterId, businessId, payload)` | Aba Posto (handler da aba registrada; só `coe_businesses` chama): `op` `overview`, `price`, `upgradeTank` ou `upgradeFleet`. |

Evento local `coe_fuel:effectsChanged(vehicleId)` quando a mistura muda a força.

## Comandos (ACE `coe_fuel.manage` ou console)

- `coe_fuel_tank <posto> <combustível> <litros>`: define o tanque de um posto de jogador.
- `coe_fuel_fill [id do jogador] [combustível]`: enche o tanque do veículo do jogador (testes).

## Dependências e listas de permissão

`coe_core`, `coe_database`, `coe_logging`, `coe_inventory`, `coe_businesses`, `coetarget`; em tempo de uso
`coe_vehicles`, `coe_mechanic`, `coe_economy`, `coe_banking`, `coe_phone`, `coe_audit`, `coe_notify`. No framework, as
capacidades vêm do framework (`CoeAccess.FirstParty`: banco, dinheiro, caixa do negócio, logs, auditoria,
notificações, gravação de negócios, permissões de cargo e abas) e o `coe_supervisor` lê `coe_supervisor 'business'` do
`fxmanifest`. A aba **Posto** é registrada com `coe_businesses:RegisterTab` (visível onde `IsStation` responde `true`).
Nos pacotes: `coe_banking` (`Credit.PurchaseCallers`), `coe_phone` (`Wallet.PaymentCallers`), `coe_mechanic`
(`WearResources`) e `coe_garages` (`FleetResources`).

Auditoria: `fuel_sale`, `fuel_tank_set`, `fuel_price`, `fuel_tank_upgrade`, `fuel_fleet_upgrade`,
`fuel_refinery_load`, `fuel_unload`.

## Testes

`test/rules_test.lua` (catálogo, motor, mistura, consumo, efeitos, preço, postos), `test/server_test.lua` (tanque
registrado e sem registro, consumo validado, desgaste e efeitos, bomba com os três pagamentos, combustível errado,
galão, posto de jogador com estoque, comandos, aba Posto, preços, upgrades de tanque e frota, refinaria e descarga) e
`test/client_test.lua` (blips, alvo, pedido do tanque, relatório, nível nativo, motor desligado, mostrador, alvo da
frota).
