-- Internet banking no COE OS (app `bank` do coe_tablet): consulta e operações sem dinheiro em espécie.
BankingTablet = {}

BankingTablet.Actions = {
	overview = true,
	transfer = true,
	blockCard = true,
	issueVirtual = true,
	creditPay = true,
	loanPay = true
}

function BankingTablet.Call(deps, playerId, appId, action, payload)
	local caller = deps.caller and deps.caller() or ''
	if caller ~= 'coe_tablet' or appId ~= 'bank' then
		return { ok = false, error = 'forbidden' }
	end
	local messages = deps.messages or {}
	if deps.ready and not deps.ready() then
		return { ok = false, error = 'not_ready', message = messages.not_ready }
	end
	local source = tonumber(playerId)
	if type(action) ~= 'string' or not BankingTablet.Actions[action] then
		return { ok = false, error = 'unknown_action' }
	end
	local busy = deps.busy
	local throttled = deps.throttled
	if not source or (busy and busy[source]) or (action ~= 'overview' and throttled and throttled(source)) then
		return { ok = false, error = 'busy', message = messages.busy }
	end
	local who = deps.character and deps.character(source) or nil
	if not who then
		return { ok = false, error = 'no_character', message = messages.no_character }
	end
	if busy then
		busy[source] = true
	end
	local ok, errorCode, view = pcall(function()
		local handler = action ~= 'overview' and deps.actions and deps.actions[action] or nil
		local code = handler and handler(source, who, type(payload) == 'table' and payload or {}) or nil
		return code, deps.view(who)
	end)
	if busy then
		busy[source] = nil
	end
	if not ok then
		if deps.log then
			deps.log('error', 'banking', 'tablet_failed', { player_id = source, action = action, error_code = tostring(errorCode):sub(1, 96) })
		end
		return { ok = false, error = 'database_error', message = messages.database_error }
	end
	return { ok = errorCode == nil, error = errorCode, message = errorCode and messages[errorCode] or nil, bank = view }
end
