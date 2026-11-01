# coe_handling

Handling estilo simulador por classe/categoria, com impacto do tipo e do desgaste dos pneus. Parte do pacote de veículos (#139).

## Como funciona

1. A classe vem do `coe_vehicle_catalog`; uma categoria definida por override vence a classe (`CategoryProfiles`). Addons sem classe usam `FallbackProfile`.
2. O servidor combina perfil × pneu × desgaste em multiplicadores e publica nos state bags `coe:handling` e `coe:tyre`.
3. O cliente lê o handling original do modelo uma vez e aplica `original × multiplicador` com `SetVehicleHandlingFloat`. Ao parar o resource, os valores originais são restaurados.

O desgaste é calculado pela quilometragem (`coe_vehicles`) desde a montagem: sem timers. A republicação ocorre apenas quando o composto ou o desgaste muda 1%.

## Perfil base (simulador)

Mais massa, menos força de arranque, pico de aderência menor, mais patinagem em baixa velocidade, freio e suspensão mais pesados. Cada classe (`ClassProfiles`) ajusta isso: super com mais downforce e aderência, muscle com pouca aderência e muita patinagem, SUV/vans/comerciais mais pesados e menos ágeis, offroad tolerante a piso ruim. Classes ausentes (barcos, helicópteros, aviões) não são alteradas.

## Pneus

| Composto | Aderência | Freio | Piso ruim | Vida |
|---|---|---|---|---|
| street | 1.00 | 1.00 | 1.00 | 60 km |
| sport | 1.08 | 1.05 | 1.10 | 40 km |
| performance | 1.15 | 1.10 | 1.25 | 25 km |
| slick | 1.25 | 1.18 | 1.60 | 15 km |
| all_terrain | 0.94 | 0.97 | 0.65 | 70 km |
| offroad | 0.88 | 0.95 | 0.50 | 80 km |
| drift | 0.80 | 0.95 | 1.10 | 12 km |

"Piso ruim" é a perda de tração fora do asfalto (menor = melhor). Classe padrão: super usa `performance`, sports usa `sport`, offroad usa `all_terrain`, o restante `street`.

## API

Exports no servidor: `GetTyre(vehicleId)`, `SetTyre(vehicleId, compound)` (apenas `WriterResources`), `ListTyres()`, `ListClasses()`, `GetModifiers(vehicleId)`, `IsReady()`. Ver `types.lua`.

Comandos: `coe_tyre <placa> <composto>` (ACE `command.coe_tyre` ou console) e `coe_handling_dump` (cliente, imprime state bag e valores atuais do veículo em que você está).

Eventos consumidos de `coe_vehicles`: `coe_vehicles:spawned`, `coe_vehicles:mileageChanged`, `coe_vehicles:released`.

## Combustível

A mistura do tanque (`coe_fuel:GetEffects`) multiplica a força do motor (`fInitialDriveForce`) junto com o desgaste das peças: etanol +6%, aditivada +2% (proporcional aos litros). O handling é recalculado no evento `coe_fuel:effectsChanged` (ao abastecer).

## Limitações

- Os multiplicadores são pontos de partida e precisam de ajuste dirigindo no jogo (`config.lua`).
- Se este resource reiniciar com veículos modificados na rua, o valor original dos modelos é perdido: reaparecer os veículos.
- Editor avançado, telemetria, perfis exportáveis e integração com a mecânica seguem em #139.
