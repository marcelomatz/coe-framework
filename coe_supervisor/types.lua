---@meta
-- Contrato público de coe_supervisor para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.
-- Exports server-only. List/Restart/GetUpdateStatus/CheckForUpdates/ApplyUpdate exigem a ACE `coe.supervisor`
-- (padrão: coe_staff). WriteFile/ReadFile/HashFile/DownloadFile/CommitFile/DiscardFile/VerifySignature são internos:
-- só o próprio coe_supervisor pode chamá-los.

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

---@class CoeSupervisorExports
local exports_coe_supervisor = {}

---Resources gerenciados, com categoria, dependências e dependentes.
---@return CoeSupervisorEntry[]|nil list `nil` para chamador não autorizado
function exports_coe_supervisor:List() end

---Reinicia o resource e os dependentes na ordem correta (com `refresh` antes dos starts).
---@param name string
---@param requester integer|nil Jogador que pediu (auditoria)
---@return boolean ok
---@return string|nil errorCode
function exports_coe_supervisor:Restart(name, requester) end

---Retorna o estado atual da verificação de atualizações do COE Framework.
---@return CoeSupervisorUpdateStatus|nil status `nil` para chamador não autorizado
function exports_coe_supervisor:GetUpdateStatus() end

---Consulta o repositório oficial por novas versões do COE Framework.
---@param requester integer|nil Jogador que pediu (auditoria)
---@return CoeSupervisorUpdateStatus|nil status `nil` para chamador não autorizado
function exports_coe_supervisor:CheckForUpdates(requester) end

---Interno. Grava um arquivo dentro de um resource (Node.js). Recusa outro chamador e caminho fora do resource.
---@param resource string Nome do resource de destino
---@param relPath string Caminho relativo dentro do resource (sem `..`, sem caminho absoluto)
---@param content string Conteúdo do arquivo
---@param isBinary boolean|nil Se o arquivo é binário (ex.: imagem/áudio)
---@return boolean ok
function exports_coe_supervisor:WriteFile(resource, relPath, content, isBinary) end

---Interno. Lê um arquivo de texto dentro de um resource (Node.js).
---@param resource string
---@param relPath string
---@return string|nil content
function exports_coe_supervisor:ReadFile(resource, relPath) end

---Interno. SHA-256 (hex) de um arquivo instalado; texto com CRLF normalizado para LF.
---@param resource string
---@param relPath string
---@param isBinary boolean|nil
---@return string|nil sha256
function exports_coe_supervisor:HashFile(resource, relPath, isBinary) end

---Interno. Baixa por HTTPS (hosts do GitHub) para `<arquivo>.coe-new` e só conclui se o SHA-256 bater.
---@param url string URL HTTPS do arquivo
---@param resource string
---@param relPath string
---@param sha256 string SHA-256 esperado (hex, 64 caracteres)
---@param cb fun(ok: boolean, err: string|nil) Callback de conclusão
---@return boolean started Se o download foi iniciado
function exports_coe_supervisor:DownloadFile(url, resource, relPath, sha256, cb) end

---Interno. Move o download conferido (`<arquivo>.coe-new`) para o lugar definitivo.
---@param resource string
---@param relPath string
---@return boolean ok
function exports_coe_supervisor:CommitFile(resource, relPath) end

---Interno. Descarta um download conferido que não será aplicado.
---@param resource string
---@param relPath string
---@return boolean ok
function exports_coe_supervisor:DiscardFile(resource, relPath) end

---Interno. Confere a assinatura Ed25519 (base64) do version.json com a chave pública em PEM.
---@param body string
---@param signature string
---@param publicKeyPem string
---@return boolean ok
function exports_coe_supervisor:VerifySignature(body, signature, publicKeyPem) end

---Baixa e aplica a última versão dos scripts do repositório oficial nos resources instalados.
---@param requester integer|nil Jogador que pediu (auditoria)
---@return boolean ok
---@return CoeSupervisorUpdateResult|string resultOrError
function exports_coe_supervisor:ApplyUpdate(requester) end
