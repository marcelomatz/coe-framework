-- Equipe de um negócio editada pelo painel (abas Negócios e Imprensa). Regra pura, sem natives:
-- só se removem membros existentes (ou se troca o cargo deles); novos entram por stateId validado no banco.
AdminStaff = {}

---@param current table[] equipe atual do negócio ({ characterId, name, grade })
---@param requested table[]|nil lista enviada pelo painel ({ characterId, grade }); quem não vier é removido
---@param dismissAll boolean demite todos (troca de dono com "demitir toda a equipe")
---@param add string[]|nil stateIds a contratar (até 20)
---@param addGrades table|nil cargo por stateId contratado
---@param deps table { isValidStateId(stateId) -> bool, find(stateId) -> found|nil, errorCode }
---@return table[]|nil kept
---@return string|nil errorKey invalid_state_id | owner_not_found | database_error
function AdminStaff.Merge(current, requested, dismissAll, add, addGrades, deps)
	local kept, wanted = {}, {}
	for _, member in ipairs(type(requested) == 'table' and requested or {}) do
		if type(member) == 'table' then
			wanted[tostring(member.characterId)] = type(member.grade) == 'string' and member.grade or false
		end
	end
	addGrades = type(addGrades) == 'table' and addGrades or {}
	for _, member in ipairs(dismissAll and {} or (type(current) == 'table' and current or {})) do
		local grade = wanted[tostring(member.characterId)]
		if grade ~= nil then
			kept[#kept + 1] = { characterId = member.characterId, name = member.name, grade = grade or member.grade }
		end
	end
	if add == nil then
		return kept
	end
	if type(add) ~= 'table' or #add > 20 then
		return nil, 'invalid_state_id'
	end
	for _, stateId in ipairs(add) do
		if type(stateId) ~= 'string' or not deps.isValidStateId(stateId:upper()) then
			return nil, 'invalid_state_id'
		end
		local found, findError = deps.find(stateId:upper())
		if not found then
			return nil, findError == 'character_not_found' and 'owner_not_found' or 'database_error'
		end
		local duplicate = false
		for _, member in ipairs(kept) do
			if tostring(member.characterId) == tostring(found.characterId) then
				duplicate = true
			end
		end
		if not duplicate then
			local grade = addGrades[stateId]
			kept[#kept + 1] = { characterId = found.characterId, name = found.name, grade = type(grade) == 'string' and grade or nil }
		end
	end
	return kept
end
