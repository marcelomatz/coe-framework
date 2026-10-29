# coe_garage

Garagens públicas básicas do COE Framework (Open-Core MIT).
Permite aos cidadãos guardar e retirar seus veículos pessoais em vagas marcadas pelo mapa, com suporte a blips visíveis e administração completa via painel administrativo (`coe_staff`).

## Funcionalidades

- **Garagens públicas pelo mapa**: Pink Cage, Legion Square, Aeroporto LSIA e Sandy Shores criadas automaticamente via migração.
- **Interação nativa (0.00 ms em repouso)**:
  - A pé na vaga: abre a interface para selecionar e retirar o veículo guardado (com entrega de chave automática).
  - Dentro do veículo como motorista: opção de guardar o veículo na vaga atual.
- **Integração com `coe_staff`**: registra-se automaticamente como provedor de garagens para administração pelo painel staff (adicionar novas garagens nas coordenadas atuais, editar vagas, alternar blips, deletar e teleportar).
- **Interface NUI**: menu moderno com tokens do design system `coe_ui`.

## Exports (servidor)

| Export | Parâmetros | Retorno | Descrição |
|---|---|---|---|
| `IsReady()` | — | `boolean` | Informa se o subsistema está inicializado |
| `ListGarages()` | — | `CoeGarage[]` | Lista todas as garagens cadastradas |
| `GetGarage(id)` | `id: string` | `CoeGarage\|nil` | Retorna uma garagem específica |
| `GetVehicleGarage(vehicleId)` | `vehicleId: string\|number` | `string\|nil` | Retorna onde o veículo está guardado |
| `SaveGarage(data)` | `data: table` | `CoeGarage\|nil, error` | Salva ou atualiza uma garagem |
| `DeleteGarage(id)` | `id: string` | `boolean, error` | Remove uma garagem |

## Acesso a outros resources

O `coe_garage` está nos padrões do framework para o que usa: `coe_database` (`DEFAULT_CALLERS`) e `coe_vehicles` (`WriterResources`: `Spawn`, `GiveKey`, `Store`). Nada a configurar no `server.cfg` além do `ensure coe_garage` (já no `recipe.yaml`). O `tools/check_contracts.lua` falha o CI se uma dessas allowlists perder o resource.

Regras no servidor: o jogador precisa estar dentro do raio da vaga (padrão 4 m) para listar e retirar, e o veículo a até 5 m para guardar; só o dono retira; um veículo com vaga fixa só sai da garagem onde foi guardado (`wrong_garage`); uma ação por jogador a cada `GarageConfig.Limits.ActionCooldownMs`.

## Banco de Dados

- Tabela `coe_garage_registry`: armazena as garagens e suas vagas em JSON.
- Tabela `coe_garage_slots`: rastreia em qual garagem cada veículo está guardado.
- Migrações automáticas versionadas via `CoeMigrations`.

## Testes

```powershell
cd coe_garage
lua test/domain_test.lua
lua test/service_test.lua
```

A integração MariaDB (`coe_database/test/integration/garage_mobile_scenario.lua`) cobre migrações, garagens e vagas no banco real.
