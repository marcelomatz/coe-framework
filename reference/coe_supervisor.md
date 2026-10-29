# coe_supervisor — referência da API

> Gerado de `coe_supervisor/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Exports server-only. List/Restart/GetUpdateStatus/CheckForUpdates/ApplyUpdate exigem a ACE `coe.supervisor`
(padrão: coe_staff). WriteFile/ReadFile/HashFile/DownloadFile/CommitFile/DiscardFile/VerifySignature são internos:
só o próprio coe_supervisor pode chamá-los.

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

### `WriteFile(resource, relPath, content, isBinary)`

Interno. Grava um arquivo dentro de um resource (Node.js). Recusa outro chamador e caminho fora do resource.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `resource` | `string` | Nome do resource de destino |
| `relPath` | `string` | Caminho relativo dentro do resource (sem `..`, sem caminho absoluto) |
| `content` | `string` | Conteúdo do arquivo |
| `isBinary` | `boolean\|nil` | Se o arquivo é binário (ex.: imagem/áudio) |

**Retorno**

- `boolean` `ok`

### `ReadFile(resource, relPath)`

Interno. Lê um arquivo de texto dentro de um resource (Node.js).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `resource` | `string` |  |
| `relPath` | `string` |  |

**Retorno**

- `string|nil` `content`

### `HashFile(resource, relPath, isBinary)`

Interno. SHA-256 (hex) de um arquivo instalado; texto com CRLF normalizado para LF.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `resource` | `string` |  |
| `relPath` | `string` |  |
| `isBinary` | `boolean\|nil` |  |

**Retorno**

- `string|nil` `sha256`

### `DownloadFile(url, resource, relPath, sha256, cb)`

Interno. Baixa por HTTPS (hosts do GitHub) para `<arquivo>.coe-new` e só conclui se o SHA-256 bater.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `url` | `string` | URL HTTPS do arquivo |
| `resource` | `string` |  |
| `relPath` | `string` |  |
| `sha256` | `string` | SHA-256 esperado (hex, 64 caracteres) |
| `cb` | `fun(ok:` | boolean, err: string\|nil) Callback de conclusão |

**Retorno**

- `boolean` `started` — Se o download foi iniciado

### `CommitFile(resource, relPath)`

Interno. Move o download conferido (`<arquivo>.coe-new`) para o lugar definitivo.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `resource` | `string` |  |
| `relPath` | `string` |  |

**Retorno**

- `boolean` `ok`

### `DiscardFile(resource, relPath)`

Interno. Descarta um download conferido que não será aplicado.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `resource` | `string` |  |
| `relPath` | `string` |  |

**Retorno**

- `boolean` `ok`

### `VerifySignature(body, signature, publicKeyPem)`

Interno. Confere a assinatura Ed25519 (base64) do version.json com a chave pública em PEM.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `body` | `string` |  |
| `signature` | `string` |  |
| `publicKeyPem` | `string` |  |

**Retorno**

- `boolean` `ok`

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

