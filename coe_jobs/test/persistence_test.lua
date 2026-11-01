-- Persistência do coe_jobs com o coe_database simulado: nenhum comando sai com nil na lista de parâmetros
-- (o coe_database recusa com invalid_parameters, como no progresso do primeiro peixe de um personagem novo).
local calls = {}
function GetResourceState() return 'started' end
promise = { new = function()
	local p = {}
	function p:resolve(value) self.value = value end
	return p
end }
Citizen = { Await = function(p) return p.value end }
local function sequence(list)
	local count = 0
	for key in pairs(list) do
		assert(math.type(key) == 'integer' and key >= 1, 'chave fora da sequencia')
		count = count + 1
	end
	return count == #list
end
exports = { coe_database = {
	Execute = function(_, sql, parameters, cb)
		calls[#calls + 1] = { sql = sql, parameters = parameters }
		cb(sequence(parameters), 1, not sequence(parameters) and 'invalid_parameters' or nil)
	end,
	Query = function(_, _, _, cb) cb(true, {}) end
} }
JobsConfig = { Career = { reputation = { start = 0 } } }
dofile('server/persistence.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

-- primeiro progresso: sem firstAt/lastAt ainda
eq(JobsPersistence.Save('1', 'fisher', { xp = 4, tasks = 1, earned = 0, seconds = 0 }) ~= nil, true, 'progresso novo grava')
eq(#calls[1].parameters, 9, 'nove parametros')
eq(calls[1].parameters[7] ~= nil and calls[1].parameters[8] ~= nil, true, 'first_at/last_at preenchidos')
eq(JobsPersistence.Save('1', 'fisher', { xp = 4, tasks = 1, earned = 0, seconds = 30, firstAt = 10, lastAt = 40 }) ~= nil, true, 'progresso com datas')
eq(calls[2].parameters[7], 10, 'first_at preservado')
eq(JobsPersistence.SaveSession('1', { jobId = 'fisher', endedAt = 50, tasks = 1, xp = 4, earned = 0, discarded = 0 }) ~= nil, true, 'sessao sem inicio e sem motivo grava')
eq(JobsPersistence.SaveProfile('1', { reputation = 0, completed = 0, abandoned = 0 }) ~= nil, true, 'perfil grava')

print('coe_jobs persistence tests passed')
