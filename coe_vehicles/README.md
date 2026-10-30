# coe_vehicles

Registro persistente de veículos de jogador: dono, modelo, placa, estado e **Mileage** (quilometragem). Todo veículo registrado possui Mileage. É a base para garagem, mecânica, concessionária e handling.

## Mileage

- Unidade: **metros inteiros** (`mileage_m`). A conversão para km/mph é de apresentação (`VehicleMileage.ToUnit`).
- O client do motorista amostra a posição e reporta em lote (`ReportIntervalMs`).
- O servidor valida cada reporte: o veículo precisa ter sido criado pelo servidor, o remetente precisa ser o motorista e a distância é limitada por um crédito proporcional ao tempo decorrido. Reportes inválidos são recusados e registrados.
- O contador fica em memória e é gravado em lotes transacionais (`FlushIntervalMs`), ao guardar o veículo, ao remover a entidade e ao parar o resource.
- Só quem tem `coe.vehicles.mileage` (ACE no `server.cfg`, ex.: painel e oficina) corrige o valor, sempre com auditoria.
- State bags no veículo: `coe:vehicleId` e `coe:mileage` (atualizado a cada 100 m).

## Chaves

- A chave é o item `carkey` do inventário (metadata `vehicleId`, `plate`). O dono recebe o item quando o veículo é
  criado na rua (retirada da garagem, painel, concessionária) e **todas** as chaves do veículo saem dos inventários
  online (e do dono offline) quando ele é guardado ou removido — nada acumula. Chaves de veículos já guardados também
  saem ao carregar o personagem (reinício com o carro na rua).
- Sem o item o veículo não liga nem tranca. Entregar a chave a outro jogador (inventário) passa o uso junto.
- Trancar/destrancar: tecla `L` (configurável em Teclas > FiveM) ou usar a chave no inventário, a até `LockDistanceMeters`.
- Veículos alugados (`coe_rentals`) usam o mesmo item com `{ plate, rental = true }` e o state bag `coe:keyPlate`.
- Sem `coe_inventory` no ar, vale a regra antiga: o dono tem a chave implícita e as emprestadas.
- O dono empresta a chave a outro jogador próximo e pode retirá-la. Quem recebeu não reempresta. Limite: `MaxLoanedKeysPerVehicle`.
- A quilometragem conta para o veículo, independente de quem dirige.
- O client pergunta ao servidor (`coe_vehicles:checkKey`) ao assumir o banco do motorista; sem resposta ou sem chave, o veículo fica indriveável. A decisão é do servidor, mas o bloqueio em si é aplicado no client (não é proteção contra cheats; hotwire/roubo ficam para o pacote de crime).
- Comandos: `/chave_emprestar <id do jogador>` e `/chave_retirar <id do jogador>` (veículo que o jogador ocupa ou o mais próximo, até `LendDistanceMeters`).
- Concessionária/administração usam os exports `GiveKey`/`RevokeKey`.

## Exports (servidor)

| Export | Quem pode chamar | Retorno |
| --- | --- | --- |
| `Create(data)` | `coe.vehicles.write` (padrão: `coe_vehicles`, o painel `coe_staff` e o `coe_garage`) | veículo ou código de erro |
| `Get(id)`, `GetByPlate(plate)`, `ListByOwner(characterId)`, `GetMileage(id)` | qualquer um | dados ou erro |
| `GetEntity(id)` | qualquer um | entidade spawnada ou `nil` |
| `SetMileage(id, meters)` | `coe.vehicles.mileage` | `true` ou erro |
| `Spawn(id, x, y, z, heading, type)` | `coe.vehicles.write` | netId ou erro |
| `Store(id)` | `coe.vehicles.write` | `true` ou erro |
| `IsReady()` | qualquer um | boolean |
| `HasKey(characterId, id)`, `ListKeyHolders(id)` | qualquer um | boolean / lista |
| `GiveKey(id, characterId)`, `RevokeKey(id, characterId)` | `coe.vehicles.write` | `true` ou erro |

Contrato completo em `types.lua`.

## Comandos (ACE)

- `coe_vehicle_create <modelo> [placa]`: cria, spawna e coloca o jogador no veículo.
- `coe_vehicle_mileage <placa> <km>`: define a quilometragem.

## Banco

Tabela `coe_vehicles` criada por migração própria (`coe_vehicles_schema_migrations`). O acesso passa por `coe_database`, que precisa listar `coe_vehicles` entre os chamadores permitidos.

## Testes

```
cd coe_vehicles
lua test/vehicles_test.lua
lua test/keys_test.lua
```

## Fora do escopo

Chaves, garagens, apreensão, combustível e seguro (#130); catálogo (#138); odômetro no HUD (#117).
