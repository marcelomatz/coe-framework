dofile('../coe_mechanic/config.lua')
dofile('../coe_mechanic/server/business.lua')

CoeMechanicConfig.Shops.bennys = { owner = { characterId = '7', name = 'Fulano' } }
CoeMechanicConfig.Shops.livre = {}

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local business = MechanicBusiness.New({ config = CoeMechanicConfig })

eq(business.Owner('bennys'), '7', 'dono vem do negócio')
eq(business.Owner('livre'), nil, 'sem dono')
eq(business.Owner('fantasma'), nil, 'oficina ausente')
eq(business.IsOwner('bennys', 7), true, 'id numérico compara como texto')
eq(business.IsOwner('bennys', nil), false, 'sem personagem')
eq(business.IsOwner('livre', '7'), false, 'oficina sem dono')

-- Quem opera a oficina (dono ou equipe cadastrada, de ponto) é testado no coe_businesses (access_test.lua).
print('business_test ok')
