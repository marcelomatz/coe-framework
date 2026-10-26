-- Testes do sistema de verificação de versão SemVer e atualização de scripts (coe_supervisor/updater.lua + server.lua).
dofile('updater.lua')

local function eq(actual, expected, message)
	if actual ~= expected then
		error(('%s: esperado %s, veio %s'):format(message, tostring(expected), tostring(actual)), 2)
	end
end

-- 1. Parsing e comparação SemVer (alpha < beta < rc < stable)
local parsed = SupervisorUpdater.ParseVersion('v0.1.0-beta.1')
eq(parsed ~= nil, true, 'parse v0.1.0-beta.1')
eq(parsed.major, 0, 'major')
eq(parsed.minor, 1, 'minor')
eq(parsed.patch, 0, 'patch')
eq(parsed.channel, 'beta', 'canal beta')
eq(parsed.raw, '0.1.0-beta.1', 'raw sem v')

local stable = SupervisorUpdater.ParseVersion('1.2.3')
eq(stable.channel, 'stable', 'canal stable')

eq(SupervisorUpdater.ParseVersion('invalido'), nil, 'versao invalida retorna nil')

eq(SupervisorUpdater.CompareVersions('0.1.0-alpha.1', '0.1.0-beta.1'), -1, 'alpha < beta')
eq(SupervisorUpdater.CompareVersions('0.1.0-beta.1', '0.1.0-beta.2'), -1, 'beta.1 < beta.2')
eq(SupervisorUpdater.CompareVersions('0.1.0-beta.2', '0.1.0-beta.10'), -1, 'beta.2 < beta.10 numérico')
eq(SupervisorUpdater.CompareVersions('0.1.0-beta.10', '0.1.0-rc.1'), -1, 'beta < rc')
eq(SupervisorUpdater.CompareVersions('0.1.0-rc.1', '0.1.0'), -1, 'rc < stable')
eq(SupervisorUpdater.CompareVersions('0.1.0', '0.1.0'), 0, 'iguais')
eq(SupervisorUpdater.CompareVersions('0.2.0-beta.1', '0.1.9'), 1, 'minor maior vence')
eq(SupervisorUpdater.IsNewer('0.1.0-beta.1', '0.1.0-beta.2'), true, 'beta.2 é mais nova que beta.1')
eq(SupervisorUpdater.IsNewer('0.1.0-beta.2', '0.1.0-beta.1'), false, 'beta.1 não é mais nova que beta.2')

-- 2. Sanitização de caminho relativo (anti-path-traversal)
eq(SupervisorUpdater.SanitizeRelativePath('server/main.lua'), 'server/main.lua', 'caminho válido')
eq(SupervisorUpdater.SanitizeRelativePath('html\\staff.js'), 'html/staff.js', 'normaliza barra invertida')
eq(SupervisorUpdater.SanitizeRelativePath('../secret.cfg'), nil, 'bloqueia ..')
eq(SupervisorUpdater.SanitizeRelativePath('server/../../secret.cfg'), nil, 'bloqueia .. aninhado')
eq(SupervisorUpdater.SanitizeRelativePath('/etc/passwd'), nil, 'bloqueia caminho absoluto')
eq(SupervisorUpdater.SanitizeRelativePath('C:/Windows/win.ini'), nil, 'bloqueia drive letter')

-- 3. Plano de atualização
local localManifest = {
	version = '0.1.0-beta.1',
	channel = 'beta',
	repository = 'marcelomatz/coe-framework',
	branch = 'main',
	resources = {
		coe_staff = { version = '0.1.0-beta.1', files = { 'fxmanifest.lua', 'server/main.lua' } },
		coe_core = { version = '0.1.0-beta.1', files = { 'fxmanifest.lua', 'lib/init.lua' } }
	}
}

local remoteSame = {
	version = '0.1.0-beta.1',
	channel = 'beta',
	repository = 'marcelomatz/coe-framework',
	branch = 'main',
	resources = {
		coe_staff = { version = '0.1.0-beta.1', files = { 'fxmanifest.lua', 'server/main.lua' } }
	}
}

local planUpToDate = SupervisorUpdater.BuildUpdatePlan(localManifest, remoteSame, {}, { coe_core = { critical = true } })
eq(planUpToDate.available, false, 'sem atualização quando versões são iguais')
eq(planUpToDate.outdatedCount, 0, 'zero resources desatualizados')

local remoteNewer = {
	version = '0.1.0-beta.2',
	tag = 'v0.1.0-beta.2',
	channel = 'beta',
	notes = 'Correções no painel F10 e sistema de update.',
	repository = 'marcelomatz/coe-framework',
	branch = 'main',
	resources = {
		coe_staff = { version = '0.1.0-beta.2', files = { 'fxmanifest.lua', 'server/main.lua', '../hack.lua' } },
		coe_core = { version = '0.1.0-beta.2', files = { 'fxmanifest.lua', 'lib/init.lua' } }
	}
}

local planNewer = SupervisorUpdater.BuildUpdatePlan(localManifest, remoteNewer, {}, { coe_core = { critical = true } })
eq(planNewer.available, true, 'atualização detectada para 0.1.0-beta.2')
eq(planNewer.remoteVersion, '0.1.0-beta.2', 'remoteVersion correta')
eq(planNewer.outdatedCount, 2, '2 resources para atualizar')
eq(planNewer.filesCount, 4, '4 arquivos válidos (o ../hack.lua foi filtrado)')
eq(planNewer.requiresFullRestart, true, 'coe_core marca requiresFullRestart')
eq(planNewer.isCumulative, false, '1 release pendente não é cumulativa')
eq(planNewer.pendingCount, 1, '1 release pendente')

-- 4. Testes de 2 ou mais releases atrasadas (plano cumulativo)
local localBeta3 = {
	version = '0.1.0-beta.3',
	channel = 'beta',
	repository = 'marcelomatz/coe-framework',
	branch = 'main',
	resources = {
		coe_staff = { version = '0.1.0-beta.3', files = { 'fxmanifest.lua' } },
		coe_spawn = { version = '0.1.0-beta.3', files = { 'fxmanifest.lua' } }
	}
}

local remoteWithHistory = {
	version = '0.1.0-beta.5',
	tag = 'v0.1.0-beta.5',
	channel = 'beta',
	repository = 'marcelomatz/coe-framework',
	branch = 'main',
	notes = 'Notas da beta.5',
	releases = {
		{ version = '0.1.0-beta.5', tag = 'v0.1.0-beta.5', channel = 'beta', notes = 'Correção em coe_staff' },
		{ version = '0.1.0-beta.4', tag = 'v0.1.0-beta.4', channel = 'beta', notes = 'Hotel de nascimento em coe_spawn' },
		{ version = '0.1.0-beta.3', tag = 'v0.1.0-beta.3', channel = 'beta', notes = 'Release beta.3' },
		{ version = '0.1.0-beta.2', tag = 'v0.1.0-beta.2', channel = 'beta', notes = 'Release beta.2' },
		{ version = '0.1.0-beta.1', tag = 'v0.1.0-beta.1', channel = 'beta', notes = 'Release beta.1' }
	},
	resources = {
		coe_staff = { version = '0.1.0-beta.5', files = { 'fxmanifest.lua', 'client/main.lua' } },
		coe_spawn = { version = '0.1.0-beta.5', files = { 'fxmanifest.lua', 'client.lua' } }
	}
}

local planCumulative = SupervisorUpdater.BuildUpdatePlan(localBeta3, remoteWithHistory, {}, {})
eq(planCumulative.available, true, 'atualização disponível no plano cumulativo')
eq(planCumulative.isCumulative, true, 'detecta 2 ou mais releases atrasadas como cumulativo')
eq(planCumulative.pendingCount, 2, 'exatamente 2 releases pendentes (beta.4 e beta.5)')
eq(planCumulative.pendingReleases[1].version, '0.1.0-beta.4', 'primeira pendente é beta.4')
eq(planCumulative.pendingReleases[2].version, '0.1.0-beta.5', 'segunda pendente é beta.5')
eq(planCumulative.pendingVersions[1], 'v0.1.0-beta.4', 'tag beta.4')
eq(planCumulative.pendingVersions[2], 'v0.1.0-beta.5', 'tag beta.5')
eq(planCumulative.outdatedCount, 2, '2 resources precisam de atualização')
eq(planCumulative.filesCount, 4, '4 arquivos baixados para levar à versão final')

io.write('coe_supervisor updater_test: ok\n')
