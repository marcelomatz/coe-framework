-- Primitivas criptográficas em Lua 5.4 puro: SHA-256 (Zero-GC com W[1..64] estático), HMAC-SHA256,
-- constantTimeEquals, normalizeSignedJoaat (#3827), Janela Deslizante Anti-Replay 64-bit e Forensic Hash Chain.
local string_pack = string.pack
local string_unpack = string.unpack
local string_byte = string.byte
local string_char = string.char
local string_rep = string.rep
local string_format = string.format

local Crypto = {}

-- Constantes redondas SHA-256 (primeiros 32 bits das raízes cúbicas dos primeiros 64 primos)
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

local W = {} -- Array estático pré-alocado para evitar GC em sha256

--- Retorna o hash SHA-256 em hexadecimal (64 caracteres) e em bytes brutos (32 bytes)
---@param msg string
---@return string hex, string rawBytes
function Crypto.sha256(msg)
	local len = #msg
	local bitLen = len * 8
	local padLen = (55 - (len % 64)) % 64
	local padded = msg .. '\128' .. string_rep('\0', padLen) .. string_pack('>I8', bitLen)

	local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
	local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19

	for i = 1, #padded, 64 do
		for j = 1, 16 do
			W[j] = string_unpack('>I4', padded, i + (j - 1) * 4)
		end
		for j = 17, 64 do
			local v15 = W[j - 15]
			local s0 = (((v15 >> 7) | (v15 << 25)) ~ ((v15 >> 18) | (v15 << 14)) ~ (v15 >> 3)) & 0xFFFFFFFF
			local v2 = W[j - 2]
			local s1 = (((v2 >> 17) | (v2 << 15)) ~ ((v2 >> 19) | (v2 << 13)) ~ (v2 >> 10)) & 0xFFFFFFFF
			W[j] = (W[j - 16] + s0 + W[j - 7] + s1) & 0xFFFFFFFF
		end

		local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
		for j = 1, 64 do
			local S1 = (((e >> 6) | (e << 26)) ~ ((e >> 11) | (e << 21)) ~ ((e >> 25) | (e << 7))) & 0xFFFFFFFF
			local ch = ((e & f) ~ ((~e) & g)) & 0xFFFFFFFF
			local temp1 = (h + S1 + ch + K[j] + W[j]) & 0xFFFFFFFF
			local S0 = (((a >> 2) | (a << 30)) ~ ((a >> 13) | (a << 19)) ~ ((a >> 22) | (a << 10))) & 0xFFFFFFFF
			local maj = ((a & b) ~ (a & c) ~ (b & c)) & 0xFFFFFFFF
			local temp2 = (S0 + maj) & 0xFFFFFFFF

			h = g; g = f; f = e
			e = (d + temp1) & 0xFFFFFFFF
			d = c; c = b; b = a
			a = (temp1 + temp2) & 0xFFFFFFFF
		end

		h0 = (h0 + a) & 0xFFFFFFFF
		h1 = (h1 + b) & 0xFFFFFFFF
		h2 = (h2 + c) & 0xFFFFFFFF
		h3 = (h3 + d) & 0xFFFFFFFF
		h4 = (h4 + e) & 0xFFFFFFFF
		h5 = (h5 + f) & 0xFFFFFFFF
		h6 = (h6 + g) & 0xFFFFFFFF
		h7 = (h7 + h) & 0xFFFFFFFF
	end

	local raw = string_pack('>I4I4I4I4I4I4I4I4', h0, h1, h2, h3, h4, h5, h6, h7)
	local hex = string_format('%08x%08x%08x%08x%08x%08x%08x%08x', h0, h1, h2, h3, h4, h5, h6, h7)
	return hex, raw
end

--- Calcula o código de autenticação de mensagem HMAC-SHA256 (RFC 2104)
---@param key string
---@param message string
---@return string hex, string rawBytes
function Crypto.hmacSha256(key, message)
	if #key > 64 then
		local _, rawKey = Crypto.sha256(key)
		key = rawKey
	end
	if #key < 64 then
		key = key .. string_rep('\0', 64 - #key)
	end
	local oKeyPad, iKeyPad = {}, {}
	for i = 1, 64 do
		local b = string_byte(key, i)
		oKeyPad[i] = string_char(b ~ 0x5c)
		iKeyPad[i] = string_char(b ~ 0x36)
	end
	local _, innerRaw = Crypto.sha256(table.concat(iKeyPad) .. message)
	return Crypto.sha256(table.concat(oKeyPad) .. innerRaw)
end

--- Comparação de strings em tempo constante O(N) imune a Timing Side-Channel Attacks
---@param a any
---@param b any
---@return boolean
function Crypto.constantTimeEquals(a, b)
	if type(a) ~= 'string' or type(b) ~= 'string' or #a ~= #b then
		return false
	end
	local diff = 0
	for i = 1, #a do
		diff = diff | (string_byte(a, i) ~ string_byte(b, i))
	end
	return diff == 0
end

--- Normaliza hashes JOAAT de 32 bits não assinados (ex.: weaponDamageEvent issue #3827) para int32 assinado
---@param hashValue integer
---@return integer
function Crypto.normalizeSignedJoaat(hashValue)
	local u = hashValue & 0xFFFFFFFF
	if u > 0x7FFFFFFF then
		return u - 0x100000000
	end
	return u
end

--- Janela Deslizante Anti-Replay de 64 Bits (O(1) para validação de sequência de eventos de rede)
function Crypto.newReplayWindow()
	return {
		highestSeq = 0,
		bitmap = 0, -- Inteiro 64 bits onde o bit k representa (highestSeq - k)
		verifyAndMark = function(self, seq)
			if type(seq) ~= 'number' or seq <= 0 then
				return false, 'invalid_seq'
			end
			if seq > self.highestSeq then
				local shift = seq - self.highestSeq
				if shift >= 64 then
					self.bitmap = 1
				else
					self.bitmap = ((self.bitmap << shift) | 1)
				end
				self.highestSeq = seq
				return true, nil
			end
			local diff = self.highestSeq - seq
			if diff >= 64 then
				return false, 'seq_too_old'
			end
			local mask = 1 << diff
			if (self.bitmap & mask) ~= 0 then
				return false, 'replay_detected'
			end
			self.bitmap = self.bitmap | mask
			return true, nil
		end
	}
end

--- Encadeador de Livro-Razão Forense (Hash Chain para coe_audit e coe_economy)
---@param genesisSeed? string
function Crypto.newForensicChain(genesisSeed)
	local genesisHex = Crypto.sha256(genesisSeed or 'COE_FRAMEWORK_GEN9_GENESIS_2026')
	return {
		lastHash = genesisHex,
		sequence = 0,
		append = function(self, timestampUs, resource, actorId, eventName, canonicalPayload)
			self.sequence = self.sequence + 1
			local recordStr = string_format(
				'%s|%d|%d|%s|%s|%s|%s',
				self.lastHash,
				self.sequence,
				timestampUs,
				tostring(resource),
				tostring(actorId),
				tostring(eventName),
				tostring(canonicalPayload)
			)
			local currentHash = Crypto.sha256(recordStr)
			local prevHash = self.lastHash
			self.lastHash = currentHash
			return currentHash, prevHash, self.sequence
		end
	}
end

return Crypto
