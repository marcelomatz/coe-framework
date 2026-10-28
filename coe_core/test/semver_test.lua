-- test/semver_test.lua
-- Teste unitário para a biblioteca SemVer do COE Framework

local SemVer = dofile('lib/semver.lua')

local function assertEq(actual, expected, msg)
	if actual ~= expected then
		error(string.format('%s: esperado [%s], obtido [%s]', msg or 'assertEq falhou', tostring(expected), tostring(actual)))
	end
end

local function assertTrue(condition, msg)
	if not condition then
		error(string.format('%s: esperado true, obtido false/nil', msg or 'assertTrue falhou'))
	end
end

local function assertFalse(condition, msg)
	if condition then
		error(string.format('%s: esperado false, obtido true', msg or 'assertFalse falhou'))
	end
end

print('Iniciando testes de SemVer...')

-- 1. Testes de Parsing
do
	local p1 = SemVer.Parse('1.2.3')
	assertEq(p1.major, 1, 'Major 1.2.3')
	assertEq(p1.minor, 2, 'Minor 1.2.3')
	assertEq(p1.patch, 3, 'Patch 1.2.3')
	assertEq(p1.prerelease, nil, 'Prerelease 1.2.3')

	local p2 = SemVer.Parse('v0.1.0-beta.10+build.2026')
	assertEq(p2.major, 0, 'Major v0.1.0-beta.10')
	assertEq(p2.minor, 1, 'Minor v0.1.0-beta.10')
	assertEq(p2.patch, 0, 'Patch v0.1.0-beta.10')
	assertEq(p2.prerelease, 'beta.10', 'Prerelease v0.1.0-beta.10')
	assertEq(p2.build, 'build.2026', 'Build v0.1.0-beta.10')

	local err, msg = SemVer.Parse('invalid.version')
	assertEq(err, nil, 'Parse erro para formato inválido')
	assertEq(msg, 'invalid_semver_format', 'Mensagem de erro de parsing')
end

-- 2. Testes de Formatação
do
	local str = SemVer.Format({ major = 2, minor = 0, patch = 1, prerelease = 'rc.1' })
	assertEq(str, '2.0.1-rc.1', 'Format com prerelease')
end

-- 3. Testes de Comparação
do
	assertEq(SemVer.Compare('1.0.0', '1.0.0'), 0, '1.0.0 == 1.0.0')
	assertEq(SemVer.Compare('1.0.1', '1.0.0'), 1, '1.0.1 > 1.0.0')
	assertEq(SemVer.Compare('0.9.9', '1.0.0'), -1, '0.9.9 < 1.0.0')
	assertEq(SemVer.Compare('1.2.0', '1.1.9'), 1, '1.2.0 > 1.1.9')
	assertEq(SemVer.Compare('2.0.0', '1.99.99'), 1, '2.0.0 > 1.99.99')

	-- Prereleases: versão estável sempre maior que pré-release correspondente
	assertEq(SemVer.Compare('1.0.0', '1.0.0-beta.1'), 1, '1.0.0 > 1.0.0-beta.1')
	assertEq(SemVer.Compare('1.0.0-alpha', '1.0.0-beta'), -1, '1.0.0-alpha < 1.0.0-beta')
	assertEq(SemVer.Compare('1.0.0-beta.2', '1.0.0-beta.10'), -1, '1.0.0-beta.2 < 1.0.0-beta.10 numericamente')
end

-- 4. Testes de Bump
do
	assertEq(SemVer.Bump('1.0.0', 'patch'), '1.0.1', 'Bump patch')
	assertEq(SemVer.Bump('1.0.5', 'minor'), '1.1.0', 'Bump minor')
	assertEq(SemVer.Bump('1.2.3', 'major'), '2.0.0', 'Bump major')
	assertEq(SemVer.Bump('0.1.0-beta.10', 'patch'), '0.1.1', 'Bump patch limpa prerelease')
end

-- 5. Testes de Faixas (Satisfies)
do
	assertTrue(SemVer.Satisfies('1.2.3', '>=1.0.0'), 'Satisfies >=1.0.0')
	assertFalse(SemVer.Satisfies('0.9.0', '>=1.0.0'), 'Not satisfies >=1.0.0')

	assertTrue(SemVer.Satisfies('1.2.5', '^1.2.0'), 'Caret ^1.2.0 match')
	assertTrue(SemVer.Satisfies('1.9.0', '^1.2.0'), 'Caret ^1.2.0 match minor higher')
	assertFalse(SemVer.Satisfies('2.0.0', '^1.2.0'), 'Caret ^1.2.0 reject major jump')

	assertTrue(SemVer.Satisfies('1.2.5', '~1.2.0'), 'Tilde ~1.2.0 match')
	assertFalse(SemVer.Satisfies('1.3.0', '~1.2.0'), 'Tilde ~1.2.0 reject minor jump')

	assertTrue(SemVer.Satisfies('1.5.0', '>=1.0.0 <2.0.0'), 'Intervalo composto match')
	assertFalse(SemVer.Satisfies('2.1.0', '>=1.0.0 <2.0.0'), 'Intervalo composto reject')
end

print('✅ Todos os testes de SemVer passaram com sucesso!')
