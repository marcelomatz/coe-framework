-- Garante que cada statement SQL do repositório recebe exatamente um parâmetro por placeholder.
local captured = {}

Core = {
	Repositories = {},
	Identity = {
		NormalizeLicense = function(value)
			return value
		end,
		IsValidCharacterId = function()
			return true
		end,
		GenerateStateId = function()
			return 'K7M2QX9R'
		end
	},
	Database = {}
}

local function record(sql, parameters)
	captured[#captured + 1] = { sql = sql, parameters = parameters }
end

function Core.Database.Query(sql, parameters)
	record(sql, parameters)
	return true
end

function Core.Database.Execute(sql, parameters)
	record(sql, parameters)
	return true
end

function Core.Database.Transaction(statements)
	for _, statement in ipairs(statements) do
		record(statement.sql, statement.parameters)
	end
	return true
end

dofile('core/server/player_repository.lua')

local repository = Core.Repositories.Player
local function noop() end

repository.FindOrCreateByLicense('license:0123456789abcdef0123456789abcdef01234567', noop)
repository.ListCharacters('1', noop)
repository.GetOwnedCharacter('1', '2', noop)
repository.CreateCharacter('1', 'Marcelo', 'Coelho', nil, 5, 10, noop)
repository.CreateCharacter('1', 'Marcelo', 'Coelho', {
	birthDate = '1990-05-17', gender = 'male', appearanceJson = '{}', appearanceVersion = 1
}, 5, 10, noop)
repository.SetCharacterSlots('1', 3, noop)
repository.ArchiveCharacter('1', '2', noop)
repository.SetInitialAppearance('1', '2', '{}', 1, noop)

assert(#captured > 0)
for index, entry in ipairs(captured) do
	local _, placeholders = entry.sql:gsub('%?', '')
	local count = #(entry.parameters or {})
	assert(placeholders == count, ('statement %d: %d placeholders, %d parameters'):format(index, placeholders, count))
end

print('player repository tests passed')
