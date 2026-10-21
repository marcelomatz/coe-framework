# coe_supervisor

Reinício ordenado dos resources do framework, sem reiniciar o servidor.

Não declara `dependencies`: precisa continuar de pé quando qualquer resource gerenciado é parado. Adicione `ensure coe_supervisor` ao `server.cfg`, antes dos demais `coe_*`.

## Como funciona

1. Lê o grafo de dependências (`dependency` e `dependencies` do `fxmanifest`) de todos os resources.
2. O alvo e todos os resources **iniciados** que dependem dele (direta ou indiretamente) formam o conjunto afetado.
3. Para os dependentes primeiro e a base por último (ordem inversa).
4. Inicia da base para os dependentes (ordenação topológica estável) e espera cada um chegar a `started`; timeout ou falha aborta e registra no console.

O plano é puro (`plan.lua`) e testado em `test/plan_test.lua`. Dependências circulares são recusadas (`dependency_cycle`).

## Exports (somente `SupervisorConfig.Caller` = `coe_admin`)

- `List()`: resources gerenciados com `state`, `description`/`version` (do fxmanifest), `dependencies`, `dependents` e `restart` (ordem que será seguida).
- `Restart(name, requesterSource)`: `true` ou código de erro (`forbidden`, `restart_in_progress`, `resource_not_managed`, `dependency_cycle`). Um reinício por vez.

A autorização do operador é do `coe_admin` (ACE `coe_admin.resources.manage`). O resultado final é notificado ao solicitante via `coe_notify`.

## Configuração

`config.lua`: `Managed` (lista permitida), `Catalog` (categoria e criticidade de cada um; fora dele vira `other`), `StopTimeoutMs`, `StartTimeoutMs`.

Dependentes fora de `Managed` (ex.: scripts de terceiros que dependem do core) também são reiniciados, para não ficarem quebrados.

## Limitações

Reiniciar `coe_core` descarrega sessões e personagens dos jogadores online; teste em jogo antes de usar com jogadores conectados. Os logs deste resource usam `print` porque o `coe_logging` pode estar parado.

## Refresh antes de iniciar

Por padrão o supervisor roda `refresh` entre parar e iniciar (`RefreshBeforeStart`, espera `RefreshWaitMs`), para o servidor reler o `fxmanifest` de resources que ganharam ou renomearam arquivos. Sem isso o cliente carregava scripts novos sem os arquivos novos.

## Referência da API

[Exports, parâmetros e códigos de erro](../reference/coe_supervisor.md), gerado de [`types.lua`](types.lua).
