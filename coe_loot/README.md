# coe_loot

Tabelas de saque dos roubos. Os scripts de roubo (residência, pedestre, veículo, comércio, heists) não guardam a própria
lista de itens: chamam `exports.coe_loot:Give(playerId, 'house_robbery')` ao concluir e o saque sai daqui. Assim o
balanceamento (o que cai e com que chance) fica num lugar só.

## Tabelas (`config.lua`)

Cada tabela tem `rolls` (quantos sorteios, de `min` a `max`) e `entries` com peso (`weight`). `nothing = true` é sorteio
vazio; `min`/`max` é a quantidade; `unique = true` marca item que não empilha (entra uma unidade por vez).

Chance de sair **pelo menos um** em um roubo (calculada por `LootRules.Chance`, com os pesos padrão):

| Tabela | Uso | Pen drive onion | Notebook | Pen drive vazio |
|---|---|---|---|---|
| `house_robbery` | Roubo a residência | 11,5% | 16,8% | 26,8% |
| `pedestrian_robbery` | Assalto a pedestre | 4,5% | — | 7,4% |
| `vehicle_break_in` | Arrombamento de veículo | 4,5% | 7,4% | 11,7% |
| `store_robbery` | Assalto a comércio | 7,4% | — | 14,5% |

Também caem dinheiro em espécie, celulares, cigarros, bandagens e kit de reparo, conforme a tabela.

## Exports (servidor)

Ver [`reference/coe_loot.md`](../reference/coe_loot.md). `Give(playerId, tableId)` → `{ ok, given, lost }` (`lost`: o que
não coube; o script de roubo decide se larga no chão) e `Roll(tableId)` → `{ ok, items }`: só resources de `Callers`
(`coe_heists`, `coe_robbery`, `coe_admin`; inclua o seu). `Tables()` é leitura livre. Cada entrega é auditada
(`loot_given`, com a tabela e o resource).

## Testar

`/coe_loot_test <tabela>` (ACE `command.coe_loot_test`) dá o saque a você mesmo:

```
add_ace group.admin command.coe_loot_test allow
```

## Ainda não existe

Os scripts de roubo em si (residência, pedestre, veículo). Este resource é o ponto de integração deles; o `coe_dispatch`
já aceita `coe_loot`/`coe_heists` para abrir chamados.

## Testes

```
cd coe_loot
lua test/loot_test.lua
```
