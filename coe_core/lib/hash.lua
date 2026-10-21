-- Hash de senhas e chaves em Lua 5.4 puro (SHA-256 iterado com salt), sem depender de natives.
-- Formato guardado: sha256$<iterações>$<salt hex>$<hash hex>. Hashes antigos (bcrypt do GetPasswordHash) ainda são
-- conferidos pelo VerifyPasswordHash, quando o native existe. Incluir com '@coe_core/lib/hash.lua' (server_scripts).
CoeHash = CoeHash or {}

local K = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}

local MASK = 0xffffffff

local function rotr(value, bits)
	return ((value >> bits) | (value << (32 - bits))) & MASK
end

function CoeHash.Sha256(message)
	local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
	local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
	local length = #message
	message = message .. '\128' .. string.rep('\0', (55 - length) % 64) .. string.pack('>I8', length * 8)
	local w = {}
	for chunk = 1, #message, 64 do
		for index = 0, 15 do
			w[index] = string.unpack('>I4', message, chunk + index * 4)
		end
		for index = 16, 63 do
			local a, b = w[index - 15], w[index - 2]
			local s0 = rotr(a, 7) ~ rotr(a, 18) ~ (a >> 3)
			local s1 = rotr(b, 17) ~ rotr(b, 19) ~ (b >> 10)
			w[index] = (w[index - 16] + s0 + w[index - 7] + s1) & MASK
		end
		local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
		for index = 0, 63 do
			local S1 = rotr(e, 6) ~ rotr(e, 11) ~ rotr(e, 25)
			local ch = (e & f) ~ (~e & g)
			local temp1 = (h + S1 + ch + K[index + 1] + w[index]) & MASK
			local S0 = rotr(a, 2) ~ rotr(a, 13) ~ rotr(a, 22)
			local maj = (a & b) ~ (a & c) ~ (b & c)
			local temp2 = (S0 + maj) & MASK
			h, g, f, e = g, f, e, (d + temp1) & MASK
			d, c, b, a = c, b, a, (temp1 + temp2) & MASK
		end
		h0, h1, h2, h3 = (h0 + a) & MASK, (h1 + b) & MASK, (h2 + c) & MASK, (h3 + d) & MASK
		h4, h5, h6, h7 = (h4 + e) & MASK, (h5 + f) & MASK, (h6 + g) & MASK, (h7 + h) & MASK
	end
	return ('%08x%08x%08x%08x%08x%08x%08x%08x'):format(h0, h1, h2, h3, h4, h5, h6, h7)
end


local PREFIX = 'sha256'
local DEFAULT_ITERATIONS = 300

local function randomSalt(rand)
	rand = rand or math.random
	local bytes = {}
	for index = 1, 16 do
		bytes[index] = ('%02x'):format(rand(0, 255))
	end
	return table.concat(bytes)
end

local function derive(secret, salt, iterations)
	local digest = CoeHash.Sha256(salt .. ':' .. secret)
	for _ = 2, iterations do
		digest = CoeHash.Sha256(digest .. salt)
	end
	return digest
end

-- Hash novo de um segredo (senha ou chave). opts: { iterations, rand (rand(a, b) para o salt) }.
function CoeHash.Secret(secret, opts)
	if type(secret) ~= 'string' then
		return nil
	end
	opts = opts or {}
	local iterations = math.tointeger(opts.iterations) or DEFAULT_ITERATIONS
	local salt = randomSalt(opts.rand)
	return ('%s$%d$%s$%s'):format(PREFIX, iterations, salt, derive(secret, salt, iterations))
end

-- O hash está no formato próprio (e não no bcrypt antigo)?
function CoeHash.IsCurrent(stored)
	return type(stored) == 'string' and stored:sub(1, #PREFIX + 1) == PREFIX .. '$'
end

-- Confere um segredo com o hash guardado. Hash antigo: tenta o VerifyPasswordHash do FXServer.
function CoeHash.Verify(secret, stored)
	if type(secret) ~= 'string' or type(stored) ~= 'string' or stored == '' then
		return false
	end
	if CoeHash.IsCurrent(stored) then
		local iterations, salt, digest = stored:match('^sha256%$(%d+)%$(%x+)%$(%x+)$')
		iterations = math.tointeger(tonumber(iterations))
		if not iterations or iterations < 1 or iterations > 100000 then
			return false
		end
		return derive(secret, salt, iterations) == digest
	end
	if type(VerifyPasswordHash) ~= 'function' then
		return false
	end
	local ok, valid = pcall(VerifyPasswordHash, secret, stored)
	return ok and valid == true
end
