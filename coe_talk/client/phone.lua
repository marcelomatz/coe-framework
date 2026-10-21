-- coe_talk - Comunicacao Telefonica (Chamadas Privadas)
Phone = {
	callId = nil,
	members = {}
}

local VOICE_TARGET_PHONE = 2

function Phone.SetCall(callId)
	Phone.callId = callId
	SendNUIMessage({ action = 'callSet', active = callId ~= nil, callId = callId })
	if not callId then
		pcall(function()
			for _, serverId in ipairs(Phone.members) do
				Submix.Clear(serverId)
			end
		end)
		Phone.members = {}
	end
end

function Phone.SyncMembers(callId, members)
	if Phone.callId ~= callId then return end
	Phone.members = members or {}

	pcall(function()
		for _, serverId in ipairs(Phone.members) do
			if serverId ~= GetPlayerServerId(PlayerId()) then
				Submix.ApplyPhone(serverId)
			end
		end
	end)
end

RegisterNetEvent('coe_talk:client:callSet', function(callId)
	Phone.SetCall(callId)
end)

RegisterNetEvent('coe_talk:client:syncCallMembers', function(callId, members)
	Phone.SyncMembers(callId, members)
end)
