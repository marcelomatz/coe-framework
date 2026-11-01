-- Apps de trabalho do COE OS: Ponto e Empregos livres, os mesmos do tablet de trabalho básico do framework
-- (coe_workpad). Com o coe_tablet rodando, o básico não sobe (coe_supervisor_replaces) e estes apps assumem o papel.
-- O coe_tablet responde por eles pelo próprio export TabletCall (a lista de apps e o acesso são os do tablet).
local config = CoeTabletConfig
local Rules = TabletWorkRules

local dutySince = {}   -- playerId -> { businessId, at } (início do ponto visto por este resource)

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function started(resource)
	return GetResourceState(resource) == 'started'
end

local function remote(resource, name, ...)
	if not started(resource) then
		return nil
	end
	local args = table.pack(...)
	local ok, result = pcall(function()
		return exports[resource][name](exports[resource], table.unpack(args, 1, args.n))
	end)
	if not ok then
		log('warn', 'system', 'tablet_work_remote_failed', { action = resource .. ':' .. name, error_code = tostring(result):sub(1, 96) })
		return nil
	end
	return result
end

local function characterOf(playerId)
	local id = Core.Players.GetActiveCharacterId(playerId)
	return id and tostring(id) or nil
end

local function dutyView(playerId, characterId)
	local entries = {}
	for _, business in ipairs(remote('coe_businesses', 'List') or {}) do
		local access = remote('coe_businesses', 'Access', business.id, characterId)
		if type(access) == 'table' and (access.owner or access.staff) then
			entries[#entries + 1] = {
				business = business, access = access,
				grade = not access.owner and remote('coe_businesses', 'GradeOf', business.id, characterId) or nil
			}
		end
	end
	local current = remote('coe_businesses', 'CurrentDuty', playerId)
	local since = dutySince[playerId]
	local at = (since and since.businessId == current) and since.at or nil
	return Rules.Workplaces(config, entries, current, at, os.time())
end

local Apps = { duty = {}, freejobs = {} }

function Apps.duty.overview(playerId, characterId)
	if not started('coe_businesses') then
		return { ok = false, error = 'app_unavailable' }
	end
	return { ok = true, data = dutyView(playerId, characterId) }
end

function Apps.duty.clockOut(playerId, characterId)
	local current = remote('coe_businesses', 'CurrentDuty', playerId)
	if not current then
		return { ok = false, error = 'not_on_duty' }
	end
	local result = remote('coe_businesses', 'ClockOut', playerId, 'clock_out')
	if type(result) == 'table' and result.error then
		return { ok = false, error = result.error }
	end
	if result == nil then
		return { ok = false, error = 'app_unavailable' }
	end
	log('info', 'gameplay', 'tablet_clock_out', { player_id = playerId, target = current })
	return { ok = true, data = dutyView(playerId, characterId) }
end

function Apps.freejobs.list(playerId, characterId)
	if not started('coe_jobs') then
		return { ok = false, error = 'app_unavailable' }
	end
	local session = remote('coe_jobs', 'GetSession', playerId)
	local working = type(session) == 'table' and session.jobId or nil
	return { ok = true, data = {
		jobs = Rules.FreeJobs(remote('coe_jobs', 'ListJobs'), remote('coe_jobs', 'GetCareer', characterId), working)
	} }
end

-- O app aparece só com o resource de que depende de pé.
local REQUIRES = { duty = 'coe_businesses', freejobs = 'coe_jobs' }

exports('TabletVisible', function(_playerId, appId)
	return GetInvokingResource() == GetCurrentResourceName() and REQUIRES[appId] ~= nil and started(REQUIRES[appId])
end)

exports('TabletCall', function(playerId, appId, action)
	if GetInvokingResource() ~= GetCurrentResourceName() then
		return { ok = false, error = 'forbidden' }
	end
	local handler = Apps[appId] and Apps[appId][action]
	if not handler then
		return { ok = false, error = 'invalid_action' }
	end
	local characterId = characterOf(tonumber(playerId))
	if not characterId then
		return { ok = false, error = 'no_character' }
	end
	return handler(tonumber(playerId), characterId)
end)

-- Início do ponto (tempo no app Ponto) e aviso para a tela recarregar.
AddEventHandler('coe_businesses:dutyChanged', function(playerId, businessId, onDuty)
	if type(playerId) ~= 'number' then
		return
	end
	dutySince[playerId] = onDuty and { businessId = businessId, at = os.time() } or nil
	TriggerClientEvent('coe_tablet:duty', playerId, onDuty and businessId or nil)
end)

AddEventHandler('playerDropped', function()
	dutySince[source] = nil
end)
