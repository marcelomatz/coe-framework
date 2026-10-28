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
