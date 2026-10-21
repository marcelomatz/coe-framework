-- Sincroniza as definições para coe_groups (integridade referencial dos vínculos).
-- Nunca apaga: grupos que saíram do arquivo ficam na tabela e os vínculos são preservados.
Core.Groups = Core.Groups or {}

function Core.Groups.Sync(callback)
	if type(callback) ~= 'function' then
		return false, 'invalid_callback'
	end

	local groups = Core.Groups.List()
	if #groups == 0 then
		callback(true)
		return true
	end

	return Core.Database.Query('SELECT name, type FROM coe_groups', {}, function(success, rows, errorMessage)
		if not success then
			callback(false, errorMessage)
			return
		end

		local existing = {}
		for _, row in ipairs(rows) do
			existing[row.name] = row.type
		end

		local placeholders, parameters = {}, {}
		for _, group in ipairs(groups) do
			-- O tipo é parte do vínculo (FK composta e um grupo ativo por tipo); mudar exige migração explícita.
			if existing[group.name] and existing[group.name] ~= group.type then
				callback(false, 'group_type_changed')
				return
			end
			placeholders[#placeholders + 1] = '(?, ?, ?)'
			parameters[#parameters + 1] = group.name
			parameters[#parameters + 1] = group.type
			parameters[#parameters + 1] = group.label
		end

		local dispatched, dispatchError = Core.Database.Execute(
			'INSERT INTO coe_groups (name, type, label) VALUES ' .. table.concat(placeholders, ', ')
				.. ' ON DUPLICATE KEY UPDATE label = VALUES(label)',
			parameters,
			function(synced, _, syncError)
				callback(synced, syncError)
			end
		)
		if not dispatched then
			callback(false, dispatchError)
		end
	end)
end

-- Vínculos do personagem (todos, ativos ou não).
function Core.Groups.LoadLinks(characterId, callback)
	if not Core.Identity.IsValidCharacterId(characterId) then
		return false, 'invalid_character_id'
	end
	if type(callback) ~= 'function' then
		return false, 'invalid_callback'
	end

	return Core.Database.Query(
		'SELECT group_name, group_type, grade, active FROM coe_character_groups WHERE character_id = ?',
		{ characterId },
		function(success, rows, errorMessage)
			if not success then
				callback(false, nil, errorMessage)
				return
			end

			local links = {}
			for _, row in ipairs(rows or {}) do
				links[#links + 1] = {
					name = row.group_name,
					type = row.group_type,
					grade = tonumber(row.grade),
					active = tonumber(row.active) == 1
				}
			end
			callback(true, links)
		end
	)
end

-- Ativa o grupo no seu tipo: desativa o ativo anterior do mesmo tipo e grava o grau na mesma transação.
function Core.Groups.WriteLink(characterId, group, grade, callback)
	if not Core.Identity.IsValidCharacterId(characterId) then
		return false, 'invalid_character_id'
	end
	if type(callback) ~= 'function' then
		return false, 'invalid_callback'
	end

	return Core.Database.Transaction({
		{
			sql = 'UPDATE coe_character_groups SET active = 0 WHERE character_id = ? AND group_type = ? AND group_name <> ? AND active = 1',
			parameters = { characterId, group.type, group.name }
		},
		{
			sql = [[
				INSERT INTO coe_character_groups (character_id, group_name, group_type, grade, active)
				VALUES (?, ?, ?, ?, 1)
				ON DUPLICATE KEY UPDATE grade = VALUES(grade), active = 1
			]],
			parameters = { characterId, group.name, group.type, grade }
		}
	}, function(success, _, errorMessage)
		if not success then
			callback(false, errorMessage)
			return
		end
		callback(true)
	end)
end

function Core.Groups.DeleteLink(characterId, name, callback)
	if not Core.Identity.IsValidCharacterId(characterId) then
		return false, 'invalid_character_id'
	end
	if type(callback) ~= 'function' then
		return false, 'invalid_callback'
	end

	return Core.Database.Execute(
		'DELETE FROM coe_character_groups WHERE character_id = ? AND group_name = ?',
		{ characterId, name },
		function(success, _, errorMessage)
			callback(success, errorMessage)
		end
	)
end
