MechanicBusiness = {}

-- Dono de cada oficina. Quem opera (dono ou equipe cadastrada, de ponto) é decidido pelo coe_businesses (Access).
-- O dono (por personagem) é definido no painel do negócio (coe_admin) e chega aqui em config.Shops[shopId].owner; este módulo só lê. deps: config.
function MechanicBusiness.New(deps)
	local service = {}

	function service.Owner(shopId)
		local shop = deps.config.Shops[shopId]
		return shop and shop.owner and shop.owner.characterId or nil
	end

	function service.IsOwner(shopId, characterId)
		local owner = service.Owner(shopId)
		return characterId ~= nil and owner ~= nil and owner == tostring(characterId)
	end

	return service
end
