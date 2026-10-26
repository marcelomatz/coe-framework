# coe_supervisor — referência da API

> Gerado de `coe_supervisor/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Exports server-only, restritos ao resource em `SupervisorConfig.Caller` (coe_admin).

## Exports

### `List()`

Resources gerenciados, com categoria, dependências e dependentes.

**Retorno**

- `CoeSupervisorEntry[]|nil` `list` — `nil` para chamador não autorizado

### `Restart(name, requester)`

Reinicia o resource e os dependentes na ordem correta (com `refresh` antes dos starts).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `name` | `string` |  |
| `requester` | `integer\|nil` | Jogador que pediu (auditoria) |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode`

### `GetUpdateStatus()`

Retorna o estado atual da verificação de atualizações do COE Framework.

**Retorno**

- `CoeSupervisorUpdateStatus|nil` `status` — `nil` para chamador não autorizado

### `CheckForUpdates(requester)`

Consulta o repositório oficial por novas versões do COE Framework.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `requester` | `integer\|nil` | Jogador que pediu (auditoria) |

**Retorno**

- `CoeSupervisorUpdateStatus|nil` `status` — `nil` para chamador não autorizado

### `ApplyUpdate(requester)`

Baixa e aplica a última versão dos scripts do repositório oficial nos resources instalados.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `requester` | `integer\|nil` | Jogador que pediu (auditoria) |

**Retorno**

- `boolean` `ok`
- `CoeSupervisorUpdateResult|string` `resultOrError`

## Tipos

```lua
---@class CoeSupervisorEntry
---@field name string
---@field category string
---@field critical boolean Reinício afeta muitos resources
---@field description string|nil
---@field dependencies string[]
---@field dependents string[]
---@field replacedBy string|nil Pacote que substitui este básico agora (coe_supervisor_replaces)

---@class CoeSupervisorUpdateStatus
---@field available boolean Se há versão mais nova no repositório
---@field checking boolean Se uma verificação está em andamento
---@field updating boolean Se uma atualização de arquivos está em andamento
---@field localVersion string Versão instalada atualmente (ex.: '0.1.0-beta.1')
---@field remoteVersion string|nil Última versão disponível no repositório
---@field tag string|nil Tag da release remota (ex.: 'v0.1.0-beta.1')
---@field channel string Canal de release ('beta', 'rc', 'stable', ...)
---@field notes string|nil Resumo da release
---@field repository string Repositório GitHub (ex.: 'marcelomatz/coe-framework')
---@field branch string Branch ou ref monitorada
---@field outdatedCount integer Quantidade de resources com atualização pendente
---@field outdatedResources string[] Lista de resources desatualizados
---@field filesCount integer Quantidade de arquivos no plano de atualização
---@field requiresFullRestart boolean Se a atualização inclui resources críticos de base
---@field needsRestart boolean Se uma atualização já foi aplicada e aguarda reinício
---@field lastError string|nil Código do último erro de verificação/atualização

---@class CoeSupervisorUpdateResult
---@field version string Versão instalada após a atualização
---@field updatedResources integer Total de resources atualizados
---@field filesUpdated integer Total de arquivos gravados
---@field requiresFullRestart boolean Se recomenda reiniciar o servidor completo
```

