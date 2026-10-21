dofile('lib/hash.lua')

local failures = 0
local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

-- Vetores conhecidos do SHA-256
eq(CoeHash.Sha256(''), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 'vazio')
eq(CoeHash.Sha256('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', 'abc')
eq(CoeHash.Sha256(string.rep('a', 1000)), '41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3', 'mensagem de vários blocos')

-- Segredo com salt e iterações
local stored = CoeHash.Secret('segredo1', { iterations = 10 })
eq(CoeHash.IsCurrent(stored), true, 'formato próprio')
eq(stored:match('^sha256%$10%$') ~= nil, true, 'guarda as iterações')
eq(CoeHash.Verify('segredo1', stored), true, 'confere')
eq(CoeHash.Verify('segredo2', stored), false, 'senha errada')
eq(CoeHash.Verify('segredo1', ''), false, 'hash vazio')
eq(CoeHash.Secret('segredo1', { iterations = 10 }) ~= stored, true, 'salt diferente a cada hash')
eq(CoeHash.Verify('x', 'sha256$999999$aa$bb'), false, 'iterações absurdas recusadas')
eq(CoeHash.Verify('x', 'sha256$abc'), false, 'formato quebrado')

-- Hash antigo (bcrypt): vai para o VerifyPasswordHash, se existir
eq(CoeHash.IsCurrent('$2b$10$abc'), false, 'bcrypt não é o formato próprio')
eq(CoeHash.Verify('x', '$2b$10$abc'), false, 'sem o native, hash antigo não confere')
VerifyPasswordHash = function(secret, hash) return secret == 'x' and hash == '$2b$10$abc' end
eq(CoeHash.Verify('x', '$2b$10$abc'), true, 'com o native, hash antigo confere')

if failures > 0 then
	print(('%d falha(s)'):format(failures))
	os.exit(1)
end
print('hash_test: ok')
