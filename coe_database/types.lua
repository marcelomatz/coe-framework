---@meta
-- Contrato público de coe_database (provider MariaDB) para LuaLS. Não é carregado pelo servidor.
-- Ver docs/ANNOTATIONS.md. Todos os exports são server-only e exigem chamador autorizado.

---Callback padrão: (success, result, errorCode).
---Códigos: `callback_required`, `caller_not_allowed`, `database_not_ready`, ou o código do driver.
---@alias CoeDatabaseCallback fun(success: boolean, result: any, errorCode: string|nil)

---@class CoeDatabaseExports
local exports_coe_database = {}

---SELECT parametrizado (placeholders `?`).
---@param sql string
---@param parameters any[]
---@param callback CoeDatabaseCallback
function exports_coe_database:Query(sql, parameters, callback) end

---INSERT/UPDATE/DELETE/DDL parametrizado.
---@param sql string
---@param parameters any[]
---@param callback CoeDatabaseCallback
function exports_coe_database:Execute(sql, parameters, callback) end

---Executa as instruções numa transação (tudo ou nada).
---@param statements { sql: string, parameters: any[] }[]
---@param callback CoeDatabaseCallback
function exports_coe_database:Transaction(statements, callback) end

---Conexão pronta para uso.
---@return boolean ready `false` também para chamador não autorizado
function exports_coe_database:IsReady() end
