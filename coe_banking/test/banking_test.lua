dofile('../coe_banking/config.lua')
dofile('../coe_banking/server/rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local c = BankingConfig
local R = BankingRules

-- Hash determinístico de teste (32 bits, estilo one-at-a-time).
local function hash(text)
	local h = 0
	for i = 1, #text do
		h = (h + text:byte(i)) & 0xffffffff
		h = (h + (h << 10)) & 0xffffffff
		h = h ~ (h >> 6)
	end
	h = (h + (h << 3)) & 0xffffffff
	h = h ~ (h >> 11)
	return (h + (h << 15)) & 0xffffffff
end

eq(R.Amount(100, 1000), 100, 'valor')
eq(R.Amount('250', 1000), 250, 'valor texto numérico')
eq(R.Amount(0, 1000), nil, 'zero')
eq(R.Amount(-5, 1000), nil, 'negativo')
eq(R.Amount(1.5, 1000), nil, 'fração')
eq(R.Amount(1001, 1000), nil, 'acima do teto')
eq(R.Amount(0 / 0, 1000), nil, 'NaN')
eq(R.Amount(nil, 1000), nil, 'nulo')

eq(R.Pin('1234'), '1234', 'senha')
eq(R.Pin('123'), nil, 'senha curta')
eq(R.Pin('12a4'), nil, 'senha com letra')
eq(R.Pin(1234), nil, 'senha numérica')

eq(R.StateId(' abcd2345 '), 'ABCD2345', 'stateId normalizado')
eq(R.StateId('ab'), nil, 'stateId curto')
eq(R.StateId('AB-CD'), nil, 'stateId com símbolo')

eq(R.CardId('12'), 12, 'id de cartão')
eq(R.CardId(0), nil, 'id zero')
eq(R.CardId(1.2), nil, 'id fracionado')

local seq = 0
local function digit()
	seq = (seq + 7) % 10
	return seq
end
local serial = R.Serial(digit)
eq(#serial, 16, 'número com 16 dígitos')
eq(serial:match('^%d+$') ~= nil, true, 'só dígitos')
eq(R.Last4(serial), serial:sub(13, 16), 'últimos 4')
eq(#R.Salt(digit), 12, 'salt')

local salt = 'abcdefghijkl'
local stored = R.HashPin('4321', salt, c.PinHashRounds, hash)
eq(#stored, 8, 'hash hex de 32 bits')
eq(R.HashPin('4321', salt, c.PinHashRounds, hash), stored, 'hash determinístico')
eq(R.HashPin('4321', 'outrosaltxyz', c.PinHashRounds, hash) ~= stored, true, 'salt muda o hash')
eq(R.HashPin('4322', salt, c.PinHashRounds, hash) ~= stored, true, 'senha muda o hash')

local card = { pinHash = stored, pinSalt = salt, attempts = 0 }
eq(R.Status(card), 'active', 'ativo')
card.expiresAt = 1000
eq(R.Status(card, 999), 'active', 'dentro da validade')
eq(R.Status(card, 1000), 'expired', 'vencido')
card.expiresAt = nil
eq(R.CheckPin(card, '4321', c, hash).ok, true, 'senha certa')
local wrong = R.CheckPin(card, '0000', c, hash)
eq(wrong.ok, false, 'senha errada')
eq(wrong.attempts, 1, 'conta tentativa')
eq(wrong.blocked, false, 'ainda não bloqueia')
card.attempts = c.MaxPinAttempts - 1
eq(R.CheckPin(card, '0000', c, hash).blocked, true, 'bloqueia no limite')
card.attempts = 0
card.blockedReason = 'pin'
eq(R.Status(card), 'blocked', 'bloqueado')
local blocked = R.CheckPin(card, '4321', c, hash)
eq(blocked.ok, false, 'bloqueado não autentica nem com senha certa')
eq(blocked.already, true, 'já bloqueado')
eq(R.CanResetPin(card), true, 'bloqueio por senha se desfaz com nova senha')
card.blockedReason = 'lost'
eq(R.CanResetPin(card), false, 'perda/roubo é definitivo')
card.blockedReason = 'replaced'
eq(R.CanResetPin(card), false, 'substituído é definitivo')
card.blockedReason = nil
eq(R.CanResetPin(card), true, 'ativo pode trocar senha')

local snapshot = { items = {
	[1] = { name = 'card_bank', metadata = { cardId = 9 } },
	[2] = false,
	[3] = { name = 'money', metadata = {} },
	[4] = { name = 'card_bank', metadata = { cardId = 3 } },
	[5] = { name = 'card_bank', metadata = { cardId = 9 } },
	[6] = { name = 'card_bank', metadata = {} },
	[7] = { name = 'card_bank', metadata = { cardId = 'x' } }
} }
local ids = R.CardsInInventory(snapshot)
eq(#ids, 2, 'cartões únicos e válidos')
eq(ids[1], 3, 'ordenado')
eq(ids[2], 9, 'ordenado 2')
eq(#R.CardsInInventory(nil), 0, 'inventário ausente')

-- Carteira digital
local now = 1000
local physical = { kind = 'physical', accountRef = '7', expiresAt = 2000 }
eq(R.CanLink(physical, 7, true, now), true, 'físico em mãos')
eq(select(2, R.CanLink(physical, 7, false, now)), 'no_card', 'físico precisa estar em mãos')
eq(R.CanLink(physical, 8, true, now), true, 'físico de outra pessoa, em mãos, vale (com a senha)')
local virtual = { kind = 'virtual', accountRef = '7', expiresAt = 2000 }
eq(R.CanLink(virtual, '7', false, now), true, 'virtual da própria conta')
eq(select(2, R.CanLink(virtual, '8', false, now)), 'not_owner', 'virtual só do titular')
virtual.blockedReason = 'replaced'
eq(select(2, R.CanLink(virtual, '7', false, now)), 'card_blocked', 'virtual substituído')
eq(select(2, R.CanLink(physical, 7, true, 3000)), 'card_expired', 'vencido')
eq(c.VirtualCardFee >= 0 and c.WalletCallers.coe_phone, true, 'carteira liberada para o coe_phone')

local agencyIds = {}
for _, agency in ipairs(c.Agencies) do
	eq(agencyIds[agency.id], nil, 'id de agência único: ' .. agency.id)
	agencyIds[agency.id] = true
	eq(type(agency.label) == 'string' and agency.radius > 0, true, 'agência válida: ' .. agency.id)
end
eq(c.MaxAtmAmount <= c.MaxAgencyAmount, true, 'teto do caixa eletrônico menor que o da agência')

-- GCRA Rate Limiter e Saga Compensatória
local limiter = R.NewRateLimiter(400, 0)
eq(type(limiter), 'table', 'NewRateLimiter disponível')
eq(limiter:allow(1, 1000), true, 'primeira ação permitida no GCRA')
eq(limiter:allow(1, 1100), false, 'segunda ação dentro de 400ms bloqueada no GCRA')
eq(limiter:allow(1, 1450), true, 'ação após 400ms liberada no GCRA')

local refunded = false
local sagaOk, _, sagaErr = R.ExecuteSaga({
	{
		name = 'step1',
		action = function() return true end,
		compensate = function() refunded = true end,
	},
	{
		name = 'step2',
		action = function() return false, 'inventory_full' end,
	},
})
eq(sagaOk, false, 'Saga falha quando segunda etapa falha')
eq(sagaErr, 'inventory_full', 'Saga preserva código de erro da etapa que falhou')
eq(refunded, true, 'Saga executa compensação automática da primeira etapa')

print('banking_test ok')
