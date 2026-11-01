dofile('server/staff.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local db = { ABCD2345 = { characterId = '10', name = 'Ana' }, EFGH6789 = { characterId = '2', name = 'Bia' } }
local deps = {
	isValidStateId = function(text) return #text == 8 and text:match('^[A-Z0-9]+$') ~= nil end,
	find = function(stateId)
		if stateId == 'ZZZZ9999' then return nil, 'database_error' end
		return db[stateId], db[stateId] == nil and 'character_not_found' or nil
	end
}
local current = { { characterId = '1', name = 'Caio', grade = 'reporter' }, { characterId = '2', name = 'Bia', grade = 'editor' } }

-- Mantém quem veio, troca o cargo e remove quem ficou de fora
local kept = AdminStaff.Merge(current, { { characterId = 1, grade = 'editor' } }, false, nil, nil, deps)
eq(#kept, 1, 'só quem veio fica')
eq(kept[1].grade, 'editor', 'cargo trocado')
eq(kept[1].name, 'Caio', 'nome vem do registro, não do painel')

-- Cargo ausente mantém o atual
kept = AdminStaff.Merge(current, { { characterId = '2' } }, false, nil, nil, deps)
eq(kept[1].grade, 'editor', 'cargo atual mantido')

-- Painel não inventa membros: characterId desconhecido é ignorado
kept = AdminStaff.Merge(current, { { characterId = '99', grade = 'chefe' } }, false, nil, nil, deps)
eq(#kept, 0, 'desconhecido não entra')

-- Demitir todos
kept = AdminStaff.Merge(current, { { characterId = '1' } }, true, nil, nil, deps)
eq(#kept, 0, 'demissão geral')

-- Contratação por stateId (minúsculas aceitas), com cargo e sem duplicar
kept = AdminStaff.Merge(current, { { characterId = '2' } }, false, { 'abcd2345', 'EFGH6789' }, { abcd2345 = 'estagiario' }, deps)
eq(#kept, 2, 'contratado sem duplicar quem já está')
eq(kept[2].characterId, '10', 'contratado pelo banco')
eq(kept[2].grade, 'estagiario', 'cargo do contratado')

-- Erros
eq(select(2, AdminStaff.Merge(current, {}, false, { 'curto' }, nil, deps)), 'invalid_state_id', 'stateId inválido')
eq(select(2, AdminStaff.Merge(current, {}, false, { 'QQQQ1111' }, nil, deps)), 'owner_not_found', 'personagem inexistente')
eq(select(2, AdminStaff.Merge(current, {}, false, { 'ZZZZ9999' }, nil, deps)), 'database_error', 'falha do banco')
eq(select(2, AdminStaff.Merge(current, {}, false, 'ABCD2345', nil, deps)), 'invalid_state_id', 'lista inválida')
local many = {}
for index = 1, 21 do many[index] = 'ABCD2345' end
eq(select(2, AdminStaff.Merge(current, {}, false, many, nil, deps)), 'invalid_state_id', 'mais de 20')

print('staff_test ok')
