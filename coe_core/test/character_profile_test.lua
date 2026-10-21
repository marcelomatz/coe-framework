Core = {}
dofile([=[core/shared/character_profile.lua]=])

local P = Core.CharacterProfile

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message or 'assertEqual', tostring(expected), tostring(actual)))
	end
end

local today = { year = 2026, month = 10, day = 16 }
local function encode(value)
	return '{"ok":true}'
end

-- Data de nascimento: formato, data real e faixa de idade (18..90 por padrão).
assertEqual(P.NormalizeBirthDate('1990-05-17', today), '1990-05-17', 'valid birth date')
assertEqual(P.NormalizeBirthDate('2008-10-16', today), '2008-10-16', 'turns 18 today')
local _, young = P.NormalizeBirthDate('2008-10-17', today)
assertEqual(young, 'birth_date_out_of_range', 'one day short of 18')
local _, old = P.NormalizeBirthDate('1935-10-16', today)
assertEqual(old, 'birth_date_out_of_range', 'over 90')
assertEqual(P.NormalizeBirthDate('1936-10-16', today), '1936-10-16', 'exactly 90')
assertEqual(P.NormalizeBirthDate('2000-02-29', today), '2000-02-29', 'leap day')
for _, invalid in ipairs({ '2001-02-29', '1900-02-29', '1990-13-01', '1990-00-10', '1990-04-31',
	'1990-5-17', '17/05/1990', '1990-05-17 ', '', 19900517 }) do
	local value, err = P.NormalizeBirthDate(invalid, today)
	assertEqual(value, nil, 'rejects ' .. tostring(invalid))
	assertEqual(err, 'invalid_birth_date', 'error for ' .. tostring(invalid))
end

-- Regras configuráveis.
assertEqual((P.SetRules(16, 60, { 'male', 'female', 'other' })), true, 'rules accepted')
assertEqual(P.NormalizeBirthDate('2010-01-01', today), '2010-01-01', 'custom min age')
assertEqual(P.NormalizeGender('OTHER'), 'other', 'custom gender list')
for _, bad in ipairs({
	{ 'x', 60, { 'a' } }, { 20, 10, { 'a' } }, { 18, 200, { 'a' } }, { 18, 90, {} },
	{ 18, 90, { 'Male' } }, { 18, 90, { 'a b' } }, { 18, 90, { 'x123456789012345678' } }, { 18.5, 90, { 'a' } }
}) do
	local ok, err = P.SetRules(bad[1], bad[2], bad[3])
	assertEqual(ok, false, 'invalid rules rejected')
	assertEqual(err, 'invalid_profile_rules', 'invalid rules code')
end
assertEqual(P.NormalizeGender('other'), 'other', 'failed SetRules keeps previous rules')
P.SetRules(18, 90, { 'male', 'female' })

-- Gênero: só a lista configurada, nunca texto livre.
assertEqual(P.NormalizeGender(' male'), nil, 'whitespace is not trimmed into a match')
assertEqual(P.NormalizeGender('Male'), 'male', 'case-insensitive')
assertEqual(P.NormalizeGender('robot'), nil, 'unknown gender rejected')
assertEqual(P.NormalizeGender(1), nil, 'non-string gender rejected')
assertEqual(P.NormalizeGender(string.rep('a', 17)), nil, 'long gender rejected')

-- Aparência: formas aceitas.
local json, version = P.NormalizeAppearance({ hair = 3, tags = { 'a', 'b' }, ok = true, scale = 1.5 }, 2, encode)
assertEqual(json, '{"ok":true}', 'serialized appearance returned')
assertEqual(version, 2, 'version returned')
assertEqual((P.NormalizeAppearance({}, 1, encode)), '{"ok":true}', 'empty table accepted')

-- Aparência: rejeições.
local function reject(value, appearanceVersion, message, encoder)
	local result, _, err = P.NormalizeAppearance(value, appearanceVersion, encoder or encode)
	assertEqual(result, nil, message)
	assertEqual(err, 'invalid_appearance', message .. ' code')
end
reject('string', 1, 'non-table')
reject({ f = function() end }, 1, 'function value')
reject({ f = print }, 1, 'builtin value')
reject({ n = 0 / 0 }, 1, 'NaN')
reject({ n = math.huge }, 1, 'infinity')
reject({ [1.5] = 'x' }, 1, 'float key')
reject({ [true] = 'x' }, 1, 'boolean key')
reject({ 'a', b = 'c' }, 1, 'mixed list and object')
reject({ [1] = 'a', [3] = 'c' }, 1, 'list with a hole')
reject({ [''] = 1 }, 1, 'empty key')
reject({ [string.rep('k', 65)] = 1 }, 1, 'long key')
reject({ s = string.rep('x', 1025) }, 1, 'long string')
reject({ a = 1 }, 0, 'version 0')
reject({ a = 1 }, 65536, 'version too large')
reject({ a = 1 }, 1.5, 'fractional version')
reject({ a = 1 }, '1', 'string version')
reject({ a = 1 }, nil, 'missing version')
reject({ a = 1 }, 1, 'encoded payload too large', function() return string.rep('x', 16385) end)
reject({ a = 1 }, 1, 'non-string encoder result', function() return 1 end)
reject({ a = 1 }, 1, 'encoder error', function() error('boom') end)

local deep = {}
local cursor = deep
for _ = 1, 8 do cursor.n = {}; cursor = cursor.n end
reject(deep, 1, 'depth beyond 8')
local shallow = { a = { b = { c = { d = { e = { f = { g = 1 } } } } } } }
assertEqual((P.NormalizeAppearance(shallow, 1, encode)), '{"ok":true}', 'depth within limit')

local cyclic = {}
cyclic.self = cyclic
reject(cyclic, 1, 'cyclic table')

local wide = {}
for index = 1, 1100 do wide[index] = index end
reject(wide, 1, 'too many nodes')

local noEncoder, _, noEncoderError = P.NormalizeAppearance({ a = 1 }, 1, nil)
assertEqual(noEncoder, nil, 'missing encoder')
assertEqual(noEncoderError, 'json_unavailable', 'missing encoder code')

-- Normalize: perfil completo, vazio, chaves desconhecidas e pares incompletos.
local empty = P.Normalize(nil, encode, today)
assertEqual(next(empty), nil, 'nil profile is an empty profile')
local full = P.Normalize({
	birthDate = '1990-05-17', gender = 'FEMALE', appearance = { a = 1 }, appearanceVersion = 3
}, encode, today)
assertEqual(full.birthDate, '1990-05-17', 'profile birth date')
assertEqual(full.gender, 'female', 'profile gender normalized')
assertEqual(full.appearanceJson, '{"ok":true}', 'profile appearance serialized')
assertEqual(full.appearanceVersion, 3, 'profile appearance version')

local function rejectProfile(profile, expected, message)
	local result, err = P.Normalize(profile, encode, today)
	assertEqual(result, nil, message)
	assertEqual(err, expected, message .. ' code')
end
rejectProfile('x', 'invalid_profile', 'non-table profile')
rejectProfile({ isAdmin = true }, 'invalid_profile', 'unknown key')
rejectProfile({ birthDate = '1990-02-30' }, 'invalid_birth_date', 'bad birth date')
rejectProfile({ gender = 'robot' }, 'invalid_gender', 'bad gender')
rejectProfile({ appearance = { a = 1 } }, 'invalid_appearance', 'appearance without version')
rejectProfile({ appearanceVersion = 1 }, 'invalid_appearance', 'version without appearance')
rejectProfile({ appearance = { f = print }, appearanceVersion = 1 }, 'invalid_appearance', 'bad appearance')

print('character profile tests passed')
