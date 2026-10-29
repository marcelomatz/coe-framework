-- Testes do fluxo de atualização do server.lua (verificar + aplicar) com HTTP e disco simulados.
-- Rodar a partir da pasta do resource: lua test/apply_test.lua

local function eq(actual, expected, message)
	if actual ~= expected then
		error(('%s: esperado %s, veio %s'):format(message, tostring(expected), tostring(actual)), 2)
	end
end

-- Disco: disk['<resource>/<arquivo>'] = conteúdo. staged = downloads binários ainda não confirmados.
local disk, staged, http, commands = {}, {}, {}, {}
local invoker = 'coe_staff'

-- json falso: o "corpo" é uma chave para a tabela já decodificada.
local documents = {}
json = {
	decode = function(body)
		local doc = documents[body]
		if not doc then
			error('json inválido')
		end
		return doc
	end,
	encode = function()
		return '{}'
	end
}

local function promiseNew()
	local p = { done = false }
	function p:resolve(value)
		self.done = true
		self.value = value
	end
	return p
end
promise = { new = promiseNew }
Citizen = {
	Await = function(p)
		assert(p.done, 'promise não resolvida (fluxo deveria ser síncrono no teste)')
		return p.value
	end
}

GetCurrentResourceName = function() return 'coe_supervisor' end
GetInvokingResource = function() return invoker end
GetResourceState = function(name) return disk[name .. '/fxmanifest.lua'] and 'started' or 'missing' end
GetResourceMetadata = function(name, key) return key == 'version' and '0.1.0-beta.6' or nil end
GetNumResources = function() return 0 end
GetResourceByFindIndex = function() return nil end
GetGameTimer = function() return 0 end
GetConvar = function(_, default) return default end
IsPrincipalAceAllowed = function() return false end
IsPlayerAceAllowed = function() return false end
ExecuteCommand = function(command) commands[#commands + 1] = command end
SetTimeout = function() end
Wait = function() end
CreateThread = function() end
AddEventHandler = function() end
RegisterCommand = function() end
TriggerClientEvent = function() end
GlobalState = {}
LoadResourceFile = function(res, file) return disk[res .. '/' .. file] end
SaveResourceFile = function() return false end

PerformHttpRequest = function(url, cb)
	local body = http[url]
	if body then
		cb(200, body)
	else
		cb(404, nil)
	end
end

local registered = {}
local node = {}
function node.WriteFile(_, res, rel, content) disk[res .. '/' .. rel] = content return true end
function node.ReadFile(_, res, rel) return disk[res .. '/' .. rel] end
function node.HashFile(_, res, rel, isBinary) return SupervisorUpdater.Sha256(disk[res .. '/' .. rel], isBinary) end
function node.DownloadFile(_, url, res, rel, sha, cb)
	local body = http[url]
	if not body then
		cb(false, 'http_404')
	elseif SupervisorUpdater.Sha256(body, true) ~= sha then
		cb(false, 'integrity_mismatch')
	else
		staged[res .. '/' .. rel] = body
		cb(true, nil)
	end
	return true
end
function node.CommitFile(_, res, rel)
	local key = res .. '/' .. rel
	if not staged[key] then
		return false
	end
	disk[key], staged[key] = staged[key], nil
	return true
end
function node.DiscardFile(_, res, rel) staged[res .. '/' .. rel] = nil return true end
function node.VerifySignature(_, body, sig, key) return sig == 'assinado:' .. body and key == 'PUB' end

exports = setmetatable({}, {
	__call = function(_, name, fn) registered[name] = fn end,
	__index = function(_, res) return res == 'coe_supervisor' and node or nil end
})

dofile('../coe_core/lib/access.lua')
dofile('config.lua')
-- Isola o teste da chave real do config.lua: a assinatura é exercitada no cenário 6.
SupervisorConfig.Updater.PublicKey = ''
SupervisorConfig.Updater.RequireSignature = false
dofile('ansi.lua')
dofile('plan.lua')
dofile('replace.lua')
dofile('updater.lua')
local realPrint = print
print = function() end -- banners e logs do supervisor ficam fora da saída do teste
dofile('server.lua')

local S = SupervisorUpdater.Sha256
local BASE = 'https://raw.githubusercontent.com/marcelomatz/coe-framework/v0.1.0-beta.7/'
local MANIFEST_URL = SupervisorConfig.Updater.ManifestUrl

local function reset()
	disk, staged, http, commands, documents = {}, {}, {}, {}, {}
	disk['coe_core/fxmanifest.lua'] = 'fx'
	disk['coe_core/server.lua'] = 'antigo\n'
	disk['coe_core/config.lua'] = 'Config = { A = 1 }\n'
	disk['coe_inventory/fxmanifest.lua'] = 'fx'
	disk['coe_inventory/data/img.webp'] = 'IMG-ANTIGA'
	disk['resource_de_terceiro/fxmanifest.lua'] = 'fx'
	disk['resource_de_terceiro/server.lua'] = 'dono'
	local installed = {
		version = '0.1.0-beta.6',
		resources = {
			coe_core = { files = { 'server.lua', 'config.lua' }, sha256 = { ['config.lua'] = S('Config = { A = 1 }\n') } },
			coe_inventory = { files = { 'data/img.webp' } }
		}
	}
	documents['installed'] = installed
	disk['coe_supervisor/version.json'] = 'installed'
end

local function publish(files)
	local remote = { version = '0.1.0-beta.7', tag = 'v0.1.0-beta.7', resources = {} }
	for res, list in pairs(files) do
		local entry = { version = '0.1.0-beta.7', files = {}, sha256 = {} }
		for rel, spec in pairs(list) do
			entry.files[#entry.files + 1] = rel
			entry.sha256[rel] = spec.sha or S(spec.body, SupervisorUpdater.IsBinaryFile(rel))
			http[BASE .. res .. '/' .. rel] = spec.served or spec.body
		end
		remote.resources[res] = entry
	end
	documents['remote'] = remote
	http[MANIFEST_URL] = 'remote'
	return remote
end

-- 1. Atualização íntegra: grava texto, confirma binário, atualiza config antiga e ignora resource de terceiro.
reset()
publish({
	coe_core = {
		['server.lua'] = { body = 'novo\n' },
		['config.lua'] = { body = 'Config = { A = 1, B = 2 }\n' }
	},
	coe_inventory = { ['data/img.webp'] = { body = 'IMG-NOVA' } },
	resource_de_terceiro = { ['server.lua'] = { body = 'sequestro' } }
})
local status = registered.CheckForUpdates()
eq(status.available, true, 'atualização encontrada')
eq(status.filesCount, 3, 'resource de terceiro fica fora do plano')
local ok, result = registered.ApplyUpdate(1)
eq(ok, true, 'apply ok: ' .. tostring(type(result) == 'string' and result or ''))
eq(disk['coe_core/server.lua'], 'novo\n', 'texto gravado')
eq(disk['coe_core/config.lua'], 'Config = { A = 1, B = 2 }\n', 'config apenas antiga recebe a nova')
eq(disk['coe_inventory/data/img.webp'], 'IMG-NOVA', 'binário confirmado após o hash')
eq(disk['resource_de_terceiro/server.lua'], 'dono', 'resource de terceiro intocado')
eq(disk['coe_supervisor/version.json'], 'remote', 'manifesto instalado atualizado')

-- 2. Um arquivo adulterado aborta antes de qualquer gravação.
reset()
publish({
	coe_core = { ['server.lua'] = { body = 'novo\n', served = 'malicioso\n' } },
	coe_inventory = { ['data/img.webp'] = { body = 'IMG-NOVA' } }
})
registered.CheckForUpdates()
ok, result = registered.ApplyUpdate(1)
eq(ok, false, 'apply recusado')
eq(result, 'update_download_failed', 'erro de download/integridade')
eq(disk['coe_core/server.lua'], 'antigo\n', 'nenhum arquivo gravado')
eq(disk['coe_inventory/data/img.webp'], 'IMG-ANTIGA', 'binário não foi confirmado')
eq(next(staged), nil, 'downloads staged descartados')

-- 3. Binário adulterado também aborta tudo.
reset()
publish({
	coe_core = { ['server.lua'] = { body = 'novo\n' } },
	coe_inventory = { ['data/img.webp'] = { body = 'IMG-NOVA', served = 'IMG-TROCADA' } }
})
registered.CheckForUpdates()
ok = registered.ApplyUpdate(1)
eq(ok, false, 'binário adulterado recusa o apply')
eq(disk['coe_core/server.lua'], 'antigo\n', 'texto não gravado quando binário falha')

-- 4. Config customizada é preservada e a nova vai para .dist.lua.
reset()
disk['coe_core/config.lua'] = 'Config = { A = 99 }\n'
publish({ coe_core = { ['config.lua'] = { body = 'Config = { A = 1, B = 2 }\n' } } })
registered.CheckForUpdates()
ok = registered.ApplyUpdate(1)
eq(ok, true, 'apply ok com config customizada')
eq(disk['coe_core/config.lua'], 'Config = { A = 99 }\n', 'config customizada mantida')
eq(disk['coe_core/config.dist.lua'], 'Config = { A = 1, B = 2 }\n', 'referência nova em .dist.lua')

-- 5. Manifesto sem SHA-256 não é aplicado.
reset()
documents['remote'] = { version = '0.1.0-beta.7', tag = 'v0.1.0-beta.7', resources = { coe_core = { files = { 'server.lua' } } } }
http[MANIFEST_URL] = 'remote'
http[BASE .. 'coe_core/server.lua'] = 'novo\n'
registered.CheckForUpdates()
ok = registered.ApplyUpdate(1)
eq(ok, false, 'manifesto sem sha256 recusado')
eq(disk['coe_core/server.lua'], 'antigo\n', 'nada gravado sem sha256')

-- 6. Assinatura: com chave pública configurada, manifesto sem .sig válido é recusado.
reset()
SupervisorConfig.Updater.PublicKey = 'PUB'
publish({ coe_core = { ['server.lua'] = { body = 'novo\n' } } })
status = registered.CheckForUpdates()
eq(status.lastError, 'invalid_signature', 'sem assinatura: recusado')
http[MANIFEST_URL .. '.sig'] = 'assinado:remote'
status = registered.CheckForUpdates()
eq(status.lastError, nil, 'assinatura válida aceita')
eq(status.available, true, 'atualização disponível com assinatura')
SupervisorConfig.Updater.PublicKey = ''

-- 7. Exports do supervisor exigem chamador autorizado.
invoker = 'meu_script'
eq(registered.CheckForUpdates(), nil, 'CheckForUpdates recusa resource sem ACE')
eq(select(2, registered.ApplyUpdate(1)), 'forbidden', 'ApplyUpdate recusa resource sem ACE')
invoker = 'coe_staff'

print = realPrint
io.write('coe_supervisor apply_test: ok\n')
