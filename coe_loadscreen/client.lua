-- Rede de segurança do loadscreen_manual_shutdown: quem fecha a tela de carregamento é o coe_characters,
-- quando a cena da seleção está pronta. Sem ele rodando fecha logo; se ele travar, fecha depois de FALLBACK_MS.
local FALLBACK_MS = 60000

CreateThread(function()
	while not NetworkIsPlayerActive(PlayerId()) do
		Wait(250)
	end
	local elapsed = 0
	while elapsed < FALLBACK_MS do
		if elapsed >= 5000 and GetResourceState('coe_characters') ~= 'started' then
			break
		end
		Wait(500)
		elapsed = elapsed + 500
	end
	ShutdownLoadingScreen()
	ShutdownLoadingScreenNui()
end)
