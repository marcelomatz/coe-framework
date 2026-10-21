VehicleKeys = {}

local function validCharacterId(value)
	return type(value) == 'string' and value:match('^[1-9]%d*$') ~= nil and #value <= 20
end

-- O dono sempre tem a chave (implícita); empréstimos ficam em coe_vehicle_keys.
function VehicleKeys.New(deps)
	local persistence = deps.persistence
	local registry = deps.registry
	local config = deps.config
	local audit = deps.audit or function() end

	local keys = {}
	local held = {}

	local function loaned(characterId)
		local set = held[characterId]
		if set then
			return set
		end
		local list, errorCode = persistence.ListKeysByCharacter(characterId)
		if not list then
			return nil, errorCode
		end
		set = {}
		for _, vehicleId in ipairs(list) do
			set[vehicleId] = true
		end
		held[characterId] = set
		return set
	end

	function keys.HasKey(characterId, vehicleId)
		if not validCharacterId(characterId) or type(vehicleId) ~= 'string' then
			return false
		end
		local record = registry.Get(vehicleId)
		if not record then
			return false
		end
		if record.ownerCharacterId == characterId then
			return true
		end
		local set = loaned(characterId)
		return set ~= nil and set[vehicleId] == true
	end

	function keys.Forget(characterId)
		held[characterId] = nil
	end

	-- Concessão direta (concessionária, administração). Não exige que o ator seja dono.
	function keys.Grant(vehicleId, targetCharacterId, grantedBy)
		if not validCharacterId(targetCharacterId) then
			return nil, 'invalid_character_id'
		end
		local record, errorCode = registry.Get(vehicleId)
		if not record then
			return nil, errorCode
		end
		if record.ownerCharacterId == targetCharacterId then
			return nil, 'already_owner'
		end
		local current, listError = persistence.ListKeysByVehicle(vehicleId)
		if not current then
			return nil, listError
		end
		for _, holder in ipairs(current) do
			if holder == targetCharacterId then
				return true
			end
		end
		if #current >= config.MaxLoanedKeysPerVehicle then
			return nil, 'key_limit_reached'
		end
		local added, addError = persistence.AddKey(vehicleId, targetCharacterId, grantedBy)
		if not added then
			return nil, addError
		end
		held[targetCharacterId] = nil
		audit('vehicle_key_granted', {
			vehicle_id = vehicleId,
			plate = record.plate,
			character_id = targetCharacterId,
			target = grantedBy
		})
		return true
	end

	function keys.Revoke(vehicleId, targetCharacterId, revokedBy)
		if not validCharacterId(targetCharacterId) then
			return nil, 'invalid_character_id'
		end
		local record, errorCode = registry.Get(vehicleId)
		if not record then
			return nil, errorCode
		end
		local removed, removeError = persistence.RemoveKey(vehicleId, targetCharacterId)
		if not removed then
			return nil, removeError
		end
		held[targetCharacterId] = nil
		audit('vehicle_key_revoked', {
			vehicle_id = vehicleId,
			plate = record.plate,
			character_id = targetCharacterId,
			target = revokedBy
		})
		return true
	end

	-- Empréstimo feito por um jogador: somente o dono empresta e retira.
	function keys.Lend(actorCharacterId, vehicleId, targetCharacterId)
		local record, errorCode = registry.Get(vehicleId)
		if not record then
			return nil, errorCode
		end
		if not validCharacterId(actorCharacterId) or record.ownerCharacterId ~= actorCharacterId then
			return nil, 'not_owner'
		end
		return keys.Grant(vehicleId, targetCharacterId, actorCharacterId)
	end

	function keys.Take(actorCharacterId, vehicleId, targetCharacterId)
		local record, errorCode = registry.Get(vehicleId)
		if not record then
			return nil, errorCode
		end
		if not validCharacterId(actorCharacterId) or record.ownerCharacterId ~= actorCharacterId then
			return nil, 'not_owner'
		end
		return keys.Revoke(vehicleId, targetCharacterId, actorCharacterId)
	end

	function keys.ListHolders(vehicleId)
		return persistence.ListKeysByVehicle(vehicleId)
	end

	return keys
end
