Core.Repositories.Player = {}

local repository = Core.Repositories.Player

local function query(sql, parameters, callback)
	local dispatched, errorMessage = Core.Database.Query(sql, parameters, callback)
	if not dispatched then
		callback(false, nil, errorMessage)
	end
end

function repository.FindOrCreateByLicense(license, callback)
	local normalizedLicense, licenseError = Core.Identity.NormalizeLicense(license)
	if not normalizedLicense then
		callback(false, nil, licenseError)
		return
	end

	local function findPlayer(afterCreateError)
		query([[
			SELECT p.player_id
			FROM coe_players AS p
			INNER JOIN coe_player_identifiers AS i ON i.player_id = p.player_id
			WHERE i.identifier_type = ? AND i.identifier_value = ?
			LIMIT 1
		]], { 'license', normalizedLicense }, function(success, rows, errorMessage)
			if not success then
				callback(false, nil, errorMessage)
				return
			end
			if type(rows) ~= 'table' then
				callback(false, nil, 'invalid_database_result')
				return
			end

			local row = rows[1]
			if row then
				callback(true, tostring(row.player_id))
				return
			end
			if afterCreateError then
				callback(false, nil, afterCreateError)
				return
			end

			local dispatched, dispatchError = Core.Database.Transaction({
				{
					sql = 'INSERT INTO coe_players () VALUES ()',
					parameters = {}
				},
				{
					sql = [[
						INSERT INTO coe_player_identifiers
							(player_id, identifier_type, identifier_value)
						VALUES (LAST_INSERT_ID(), ?, ?)
					]],
					parameters = { 'license', normalizedLicense }
				}
			}, function(created, _, createError)
				if created then
					findPlayer()
					return
				end
				findPlayer(createError or 'player_creation_failed')
			end)
			if not dispatched then
				callback(false, nil, dispatchError)
			end
		end)
	end

	findPlayer()
end

-- Aparência guardada como JSON (opaca para o core); texto inválido vira nil.
local function decodeAppearance(row)
	local text, version = row.appearance, tonumber(row.appearance_version)
	if not version or version < 1 then
		return nil, nil
	end
	-- O driver pode devolver a coluna JSON já decodificada.
	if type(text) == 'table' then
		return text, version
	end
	if type(text) ~= 'string' or text == '' or not json then
		return nil, nil
	end
	local ok, value = pcall(json.decode, text)
	if not ok or type(value) ~= 'table' then
		return nil, nil
	end
	return value, version
end

function repository.ListCharacters(playerId, callback)
	query([[
		SELECT character_id, player_id, state_id, first_name, last_name, created_at,
			DATE_FORMAT(birth_date, '%Y-%m-%d') AS birth_date, gender, appearance, appearance_version
		FROM coe_characters
		WHERE player_id = ? AND archived_at IS NULL
		ORDER BY created_at, character_id
	]], { playerId }, function(success, rows, errorMessage)
		if not success then
			callback(false, nil, errorMessage)
			return
		end
		if type(rows) ~= 'table' then
			callback(false, nil, 'invalid_database_result')
			return
		end

		local characters = {}
		for _, row in ipairs(rows) do
			local appearance, appearanceVersion = decodeAppearance(row)
			characters[#characters + 1] = {
				characterId = tostring(row.character_id),
				playerId = tostring(row.player_id),
				stateId = row.state_id,
				firstName = row.first_name,
				lastName = row.last_name,
				birthDate = row.birth_date,
				gender = row.gender,
				appearance = appearance,
				appearanceVersion = appearanceVersion,
				createdAt = row.created_at
			}
		end
		callback(true, characters)
	end)
end

function repository.GetOwnedCharacter(playerId, characterId, callback)
	query([[
		SELECT character_id, player_id, state_id, first_name, last_name, created_at,
			DATE_FORMAT(birth_date, '%Y-%m-%d') AS birth_date, gender, appearance, appearance_version
		FROM coe_characters
		WHERE character_id = ? AND player_id = ? AND archived_at IS NULL
		LIMIT 1
	]], { characterId, playerId }, function(success, rows, errorMessage)
		if not success then
			callback(false, nil, errorMessage)
			return
		end
		if type(rows) ~= 'table' then
			callback(false, nil, 'invalid_database_result')
			return
		end

		local row = rows[1]
		if not row then
			callback(false, nil, 'character_not_found')
			return
		end
		local appearance, appearanceVersion = decodeAppearance(row)
		callback(true, {
			characterId = tostring(row.character_id),
			playerId = tostring(row.player_id),
			stateId = row.state_id,
			firstName = row.first_name,
			lastName = row.last_name,
			birthDate = row.birth_date,
			gender = row.gender,
			appearance = appearance,
			appearanceVersion = appearanceVersion,
			createdAt = row.created_at
		})
	end)
end

local STATE_ID_ATTEMPTS = 5

-- O stateId é gerado aqui e a unicidade é decidida pelo banco: em colisão (ER_DUP_ENTRY)
-- a transação inteira é desfeita e repetida com outro valor, sem consulta prévia.
-- Limite efetivo = LEAST(valor do jogador em coe_player_settings ou o padrão, teto absoluto).
-- É calculado no mesmo INSERT para a checagem continuar atômica.
-- profile já vem validado (Core.CharacterProfile.Normalize); campos ausentes viram NULL.
function repository.CreateCharacter(playerId, firstName, lastName, profile, defaultLimit, hardLimit, callback)
	profile = profile or {}
	local function attempt(number)
		local stateId = Core.Identity.GenerateStateId()
		local dispatched, dispatchError = Core.Database.Transaction({
			{
				sql = 'SELECT player_id FROM coe_players WHERE player_id = ? FOR UPDATE',
				parameters = { playerId }
			},
			{
				sql = [[
					INSERT INTO coe_characters
						(player_id, first_name, last_name, state_id, birth_date, gender, appearance, appearance_version)
					SELECT p.player_id, ?, ?, ?, NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, 0)
					FROM coe_players AS p
					WHERE p.player_id = ?
						AND (
							SELECT COUNT(*)
							FROM coe_characters AS c
							WHERE c.player_id = p.player_id AND c.archived_at IS NULL
						) < LEAST(
							COALESCE((
								SELECT s.character_slots FROM coe_player_settings AS s WHERE s.player_id = p.player_id
							), ?),
							?
						)
				]],
				parameters = {
					firstName, lastName, stateId,
					profile.birthDate or '', profile.gender or '',
					profile.appearanceJson or '', profile.appearanceVersion or 0,
					playerId, defaultLimit, hardLimit
				}
			}
		}, function(success, results, errorMessage)
			if not success then
				if errorMessage == 'ER_DUP_ENTRY' and number < STATE_ID_ATTEMPTS then
					attempt(number + 1)
					return
				end
				callback(false, nil, errorMessage)
				return
			end
			if type(results) ~= 'table' or type(results[1]) ~= 'table' or type(results[2]) ~= 'table' then
				callback(false, nil, 'invalid_database_result')
				return
			end
			if #results[1] == 0 then
				callback(false, nil, 'player_not_found')
				return
			end

			local insertResult = results[2]
			if tonumber(insertResult.affectedRows) ~= 1
				or not Core.Identity.IsValidCharacterId(tostring(insertResult.insertId)) then
				callback(false, nil, 'character_limit_reached')
				return
			end

			callback(true, {
				characterId = tostring(insertResult.insertId),
				playerId = playerId,
				stateId = stateId,
				firstName = firstName,
				lastName = lastName,
				birthDate = profile.birthDate,
				gender = profile.gender,
				appearance = profile.appearance,
				appearanceVersion = profile.appearanceVersion
			})
		end)
		if not dispatched then
			callback(false, nil, dispatchError)
		end
	end
	attempt(1)
end
function repository.ArchiveCharacter(playerId, characterId, callback)
	local dispatched, dispatchError = Core.Database.Execute([[
		UPDATE coe_characters
		SET archived_at = CURRENT_TIMESTAMP(3)
		WHERE character_id = ? AND player_id = ? AND archived_at IS NULL
	]], { characterId, playerId }, function(success, result, errorMessage)
		if not success then
			callback(false, nil, errorMessage)
			return
		end
		if type(result) ~= 'table' or tonumber(result.affectedRows) ~= 1 then
			callback(false, nil, 'character_not_found')
			return
		end
		callback(true)
	end)
	if not dispatched then
		callback(false, nil, dispatchError)
	end
end

-- Primeira definição da aparência de um personagem sem aparência (personagens criados antes do criador).
-- Só grava se ainda estiver vazia: trocar o visual depois é papel de barbearia/loja.
function repository.SetInitialAppearance(playerId, characterId, appearanceJson, appearanceVersion, callback)
	local dispatched, dispatchError = Core.Database.Execute([[
		UPDATE coe_characters
		SET appearance = ?, appearance_version = ?
		WHERE character_id = ? AND player_id = ? AND archived_at IS NULL
			AND (appearance IS NULL OR appearance = '')
	]], { appearanceJson, appearanceVersion, characterId, playerId }, function(success, result, errorMessage)
		if not success then
			callback(false, nil, errorMessage)
			return
		end
		if type(result) ~= 'table' or tonumber(result.affectedRows) ~= 1 then
			callback(false, nil, 'appearance_locked')
			return
		end
		callback(true)
	end)
	if not dispatched then
		callback(false, nil, dispatchError)
	end
end

-- Define (ou limpa, com nil) o número de slots de personagem de um jogador.
function repository.SetCharacterSlots(playerId, slots, callback)
	local dispatched, dispatchError = Core.Database.Transaction({
		{
			sql = 'SELECT player_id FROM coe_players WHERE player_id = ? FOR UPDATE',
			parameters = { playerId }
		},
		{
			sql = [[
				INSERT INTO coe_player_settings (player_id, character_slots)
				SELECT player_id, NULLIF(?, 0) FROM coe_players WHERE player_id = ?
				ON DUPLICATE KEY UPDATE character_slots = VALUES(character_slots)
			]],
			parameters = { slots or 0, playerId }
		}
	}, function(success, results, errorMessage)
		if not success then
			callback(false, errorMessage)
			return
		end
		if type(results) ~= 'table' or type(results[1]) ~= 'table' then
			callback(false, 'invalid_database_result')
			return
		end
		if #results[1] == 0 then
			callback(false, 'player_not_found')
			return
		end
		callback(true)
	end)
	if not dispatched then
		callback(false, dispatchError)
	end
end
