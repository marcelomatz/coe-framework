BusinessAccess = {}

local function resolveContainers()
	if type(Core) == 'table' and type(Core.Algorithms) == 'table' and type(Core.Algorithms.Containers) == 'table' then
		return Core.Algorithms.Containers
	end
	if type(CoeAlgorithms) == 'table' and type(CoeAlgorithms.Containers) == 'table' then
		return CoeAlgorithms.Containers
	end
	if type(LoadResourceFile) == 'function' and type(load) == 'function' then
		local src = LoadResourceFile('coe_core', 'lib/algorithms/containers.lua')
		if type(src) == 'string' and src ~= '' then
			local fn = load(src, '@@coe_core/lib/algorithms/containers.lua', 't', _G)
			if fn then
				local ok, mod = pcall(fn)
				if ok and type(mod) == 'table' then
					return mod
				end
			end
		end
		return nil
	end
	if type(loadfile) == 'function' then
		local candidates = {
			'../coe_core/lib/algorithms/containers.lua',
			'coe-framework/coe_core/lib/algorithms/containers.lua',
			'dev/coe_core/lib/algorithms/containers.lua',
		}
		for i = 1, #candidates do
			local chunk = loadfile(candidates[i])
			if chunk then
				local ok, mod = pcall(chunk)
				if ok and type(mod) == 'table' then
					return mod
				end
			end
		end
	end
	return nil
end

local Containers = resolveContainers()

function BusinessAccess.NewCache(capacity, ttlMs)
	if Containers and type(Containers.newLRUCache) == 'function' then
		return Containers.newLRUCache(capacity or 1024, ttlMs)
	end
	return nil
end

local function same(a, b)
	return a ~= nil and b ~= nil and tostring(a) == tostring(b)
end

function BusinessAccess.IsOwner(business, characterId)
	return type(business) == 'table' and type(business.owner) == 'table' and same(business.owner.characterId, characterId)
end

function BusinessAccess.IsStaff(business, characterId)
	if type(business) ~= 'table' or type(business.staff) ~= 'table' then
		return false
	end
	for _, member in ipairs(business.staff) do
		if same(member.characterId, characterId) then
			return true
		end
	end
	return false
end

-- Quem pode usar um negócio. Cada negócio é único: só o dono dele (se ownerAccess) e os funcionários cadastrados nele
-- entram; o emprego não concede nada. Dono e equipe operam/administram de ponto batido naquele negócio,
-- salvo clockRequired = false (a regra vale só para o próprio negócio). Quem é dono de vários negócios bate ponto em cada um.
function BusinessAccess.IsPartner(business, characterId)
	if type(business) ~= 'table' or type(business.partners) ~= 'table' then
		return false
	end
	for _, partner in ipairs(business.partners) do
		if same(partner.characterId, characterId) then
			return true
		end
	end
	return false
end

-- Sócio (partner) responde pelas dívidas do negócio, mas não bate ponto nem trabalha por ser sócio.
-- canWork: operação física nas estações do negócio (exige ponto quando clockRequired ~= false).
-- canRemote: gestão e atuação em nome do negócio sem ponto batido (dono com ownerAccess, negócio sem ponto obrigatório ou cargo com business.remote).
-- Retorna { owner, staff, partner, canClock, canWork, canRemote }.
function BusinessAccess.Evaluate(business, characterId, onDuty)
	local result = { owner = false, staff = false, partner = false, canClock = false, canWork = false, canRemote = false }
	if type(business) ~= 'table' or business.enabled == false or characterId == nil then
		return result
	end
	local rules = type(business.rules) == 'table' and business.rules or {}
	result.owner = BusinessAccess.IsOwner(business, characterId) and rules.ownerAccess ~= false
	result.staff = BusinessAccess.IsStaff(business, characterId)
	result.partner = BusinessAccess.IsPartner(business, characterId)
	result.canClock = result.owner or result.staff
	result.canWork = (result.owner or result.staff) and (rules.clockRequired == false or onDuty == true)
	local remoteGrade = result.staff and type(BusinessGrades) == 'table' and BusinessGrades.Can(business, characterId, 'business.remote', false) or false
	result.canRemote = result.owner or (result.staff and (rules.clockRequired == false or remoteGrade))
	return result
end

-- Confere se o personagem pode exercer `permission` no negócio.
-- Quando `remoteOnly == true`, exige permissão de atuar sem ponto batido (`canRemote`, ex.: alugar imóvel comercial fora do expediente).
-- Quando `remoteOnly ~= true`, aceita quem está de ponto (`canWork`) OU quem tem acesso remoto (`canRemote`).
function BusinessAccess.Can(business, characterId, permission, onDuty, remoteOnly)
	if type(business) ~= 'table' or characterId == nil or type(BusinessGrades) ~= 'table' or not BusinessGrades.IsPermission(permission) then
		return false
	end
	local access = BusinessAccess.Evaluate(business, characterId, onDuty)
	local allowed = remoteOnly == true and access.canRemote or (access.canWork or access.canRemote)
	if not allowed then
		return false
	end
	return BusinessGrades.Can(business, characterId, permission, access.owner)
end
