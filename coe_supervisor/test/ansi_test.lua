dofile('ansi.lua')

local eq = function(a, b, msg)
	if a ~= b then
		error(string.format('%s: esperado %s, recebido %s', msg or 'erro', tostring(b), tostring(a)), 2)
	end
end

-- 1. Sanitização de UTF-8
local clean = SupervisorAnsi.SanitizeUtf8('COE Framework v0.1.0-beta.4: 2 atualizações.')
eq(clean, 'COE Framework v0.1.0-beta.4: 2 atualizações.', 'string utf-8 pura mantida')

local withPattern = SupervisorAnsi.SanitizeUtf8('COE Framework v0.1.0-beta.4 (beta): 2 atualiza??o(?es). Destaque: Atualiza coe_spawn, reference.')
eq(withPattern, 'COE Framework v0.1.0-beta.4 (beta): 2 atualização(ões). Destaque: Atualiza coe_spawn, reference.', 'correcao de atualiza??o(?es)')

-- Bytes isolados no range ISO-8859-1 (ex: \xe7\xe3o)
local rawIso = 'atualiza' .. string.char(0xe7) .. string.char(0xe3) .. 'o'
local converted = SupervisorAnsi.SanitizeUtf8(rawIso)
eq(converted, 'atualização', 'conversao iso/windows-1252 para utf-8')

-- 2. VisibleLength
local styled = '\27[1;36m[COE Framework]\27[0m'
eq(SupervisorAnsi.VisibleLength(styled), 15, 'comprimento visivel ignora ansi')

-- 3. Renderização sem exceções
local dummyPlan = {
	channel = 'beta',
	localVersion = '0.1.0-beta.3',
	remoteVersion = '0.1.0-beta.4',
	tag = 'v0.1.0-beta.4',
	notes = 'COE Framework v0.1.0-beta.4 (beta): 2 atualização(ões).',
	outdatedCount = 27,
	filesCount = 816
}

local okBanner = pcall(function()
	SupervisorAnsi.PrintUpdateAvailable(dummyPlan)
end)
eq(okBanner, true, 'PrintUpdateAvailable executa sem erro')

local okVersion = pcall(function()
	SupervisorAnsi.PrintVersion({
		localVersion = '0.1.0-beta.4',
		channel = 'beta',
		repository = 'marcelomatz/coe-framework',
		branch = 'main',
		available = false,
		remoteVersion = '0.1.0-beta.4'
	})
end)
eq(okVersion, true, 'PrintVersion executa sem erro')

local okProgress = pcall(function()
	SupervisorAnsi.PrintProgress(15, 27, 'coe_inventory')
end)
eq(okProgress, true, 'PrintProgress executa sem erro')

local okComplete = pcall(function()
	SupervisorAnsi.PrintUpdateCompleted({
		version = '0.1.0-beta.4',
		updatedResources = 27,
		filesUpdated = 816,
		requiresFullRestart = false
	})
end)
eq(okComplete, true, 'PrintUpdateCompleted executa sem erro')

print('coe_supervisor ansi_test: ok')
