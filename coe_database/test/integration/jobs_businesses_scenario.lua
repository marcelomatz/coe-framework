dofile([=[coe_database/test/integration/bridge.lua]=])
local assertEqual = Bridge.AssertEqual
Bridge.InstallFiveMStubs()

dofile([=[coe_core/lib/migrations.lua]=])
dofile([=[coe_economy/server/migrations.lua]=])
dofile([=[coe_economy/server/persistence.lua]=])
dofile([=[coe_businesses/server/migrations.lua]=])
dofile([=[coe_businesses/server/persistence.lua]=])
dofile([=[coe_jobs/config.lua]=])
dofile([=[coe_jobs/server/migrations.lua]=])
dofile([=[coe_jobs/server/persistence.lua]=])

-- 1. Migrações idempotentes dos três recursos integrados
for attempt = 1, 2 do
	local ok, err = EconomyPersistence.Initialize()
	assertEqual(ok, true, 'economy initialize ' .. attempt .. ' ' .. tostring(err))
	ok, err = BusinessesPersistence.Initialize()
	assertEqual(ok, true, 'businesses initialize ' .. attempt .. ' ' .. tostring(err))
	ok, err = JobsPersistence.Initialize()
	assertEqual(ok, true, 'jobs initialize ' .. attempt .. ' ' .. tostring(err))
end

local economyVersions = Bridge.Query('SELECT version, name FROM coe_economy_schema_migrations')
assertEqual(#economyVersions.result, 2, 'economy migrations count')
local businessesVersions = Bridge.Query('SELECT version, name FROM coe_businesses_schema_migrations')
assertEqual(#businessesVersions.result, 1, 'businesses migrations count')
local jobsVersions = Bridge.Query('SELECT version, name FROM coe_jobs_schema_migrations')
assertEqual(#jobsVersions.result, 4, 'jobs migrations count')

-- 2. Cadastro de Empresa e Equipe em coe_businesses
local savedOk = BusinessesPersistence.Save({
	id = 'bennys_motorworks',
	category = 'mechanic',
	label = 'Benny Motorworks',
	enabled = true,
	owner = { characterId = '100' },
	staff = {
		{ characterId = '101', role = 'mechanic', salary = 350 },
		{ characterId = '102', role = 'apprentice', salary = 200 }
	},
	rules = { deposit = true, withdraw = false }
})
assertEqual(savedOk, true, 'business entity saved')

local list = BusinessesPersistence.List()
assertEqual(#list, 1, '1 business in registry')
assertEqual(list[1].id, 'bennys_motorworks', 'business id matches')
assertEqual(list[1].owner.characterId, '100', 'business owner matches')
assertEqual(#list[1].staff, 2, 'business has 2 staff members')
assertEqual(list[1].staff[1].salary, 350, 'mechanic salary matches')

-- 3. Fluxo Financeiro Empresarial (coe_economy)
-- 3.1 Setup de contas e tesouraria
assertEqual(EconomyPersistence.EnsureSociety('bennys_motorworks'), true, 'business society treasury created')
assertEqual(EconomyPersistence.SocietyBalance('bennys_motorworks'), 0, 'initial treasury balance is $0')

assertEqual(EconomyPersistence.EnsureAccount('100', 10000, 'coe_economy'), true, 'owner account created')
assertEqual(EconomyPersistence.EnsureAccount('101', 0, 'coe_economy'), true, 'mechanic account created')
assertEqual(EconomyPersistence.EnsureAccount('102', 0, 'coe_economy'), true, 'apprentice account created')

-- 3.2 Aporte de Capital Social: Dono transfere $5.000 para a tesouraria da empresa
assertEqual(EconomyPersistence.SocietyDeposit('bennys_motorworks', '100', 5000, 'capital_injection', 'cap:01', 'coe_businesses'), true, 'capital injection')
assertEqual(EconomyPersistence.Balance('100'), 5000, 'owner balance reduced to $5000')
assertEqual(EconomyPersistence.SocietyBalance('bennys_motorworks'), 5000, 'company treasury is $5000')

-- 3.3 Fechamento de Folha de Pagamento: Empresa paga os salários dos dois funcionários
assertEqual(EconomyPersistence.SocietyPay('bennys_motorworks', '101', 350, 'payroll', 'pay:oct1', 'coe_businesses'), true, 'mechanic salary paid')
assertEqual(EconomyPersistence.SocietyPay('bennys_motorworks', '102', 200, 'payroll', 'pay:oct1', 'coe_businesses'), true, 'apprentice salary paid')

assertEqual(EconomyPersistence.Balance('101'), 350, 'mechanic received $350')
assertEqual(EconomyPersistence.Balance('102'), 200, 'apprentice received $200')
assertEqual(EconomyPersistence.SocietyBalance('bennys_motorworks'), 4450, 'company treasury has $4450 after payroll')

-- 4. Carreira e Sessões de Trabalho Autônomo em coe_jobs
-- O aprendiz (102) também realiza trabalhos avulsos de entrega
assert(JobsPersistence.Save('102', 'delivery', {
	xp = 150,
	tasks = 5,
	earned = 1200,
	seconds = 1800,
	firstAt = 1000,
	lastAt = 2800
}), 'delivery progress saved')

assert(JobsPersistence.SaveSession('102', {
	jobId = 'delivery',
	startedAt = 1000,
	endedAt = 2800,
	tasks = 5,
	xp = 150,
	earned = 1200,
	discarded = 0,
	reason = 'completed'
}), 'delivery session recorded')

local progress = JobsPersistence.Progress('102', 'delivery')
assertEqual(progress.xp, 150, 'worker earned 150 xp')
assertEqual(progress.tasks, 5, 'worker completed 5 tasks')
assertEqual(progress.earned, 1200, 'worker earned $1200 from delivery')

local sessions = JobsPersistence.Sessions('102', 5)
assertEqual(#sessions, 1, '1 completed session recorded')
assertEqual(sessions[1].jobId, 'delivery', 'session job is delivery')
assertEqual(sessions[1].earned, 1200, 'session payout matches')

-- Atualização e persistência de reputação no perfil de carreira
assert(JobsPersistence.SaveProfile('102', { reputation = 15, completed = 1, abandoned = 0 }), 'career profile saved')
local profile = JobsPersistence.Profile('102')
assertEqual(profile.reputation, 15, 'career reputation is 15')
assertEqual(profile.completed, 1, 'career completed count is 1')
assertEqual(profile.abandoned, 0, 'career abandoned count is 0')

-- 5. Auditoria de Livro-Razão (Double-entry Ledger)
local ownerLedger = Bridge.Query('SELECT delta, reason FROM coe_economy_ledger WHERE character_id = 100 ORDER BY id')
assertEqual(#ownerLedger.result, 2, 'owner has 2 ledger entries')
assertEqual(ownerLedger.result[1].delta, 10000, 'starting balance')
assertEqual(ownerLedger.result[2].delta, -5000, 'capital injection deduction')

local mechanicLedger = Bridge.Query('SELECT delta, reason FROM coe_economy_ledger WHERE character_id = 101 ORDER BY id')
assertEqual(#mechanicLedger.result, 1, 'mechanic has 1 ledger entry')
assertEqual(mechanicLedger.result[1].delta, 350, 'mechanic payroll credit')

local apprenticeLedger = Bridge.Query('SELECT delta, reason FROM coe_economy_ledger WHERE character_id = 102 ORDER BY id')
assertEqual(#apprenticeLedger.result, 1, 'apprentice has 1 ledger entry')
assertEqual(apprenticeLedger.result[1].delta, 200, 'apprentice payroll credit')

local societyLedger = Bridge.Query('SELECT delta, reason FROM coe_economy_society_ledger WHERE business_id = ? ORDER BY id', { 'bennys_motorworks' })
assertEqual(#societyLedger.result, 3, 'business treasury has 3 ledger entries')
assertEqual(societyLedger.result[1].delta, 5000, 'capital injection revenue')
assertEqual(societyLedger.result[2].delta, -350, 'mechanic salary deduction')
assertEqual(societyLedger.result[3].delta, -200, 'apprentice salary deduction')

-- 6. Remoção de entidade empresarial
assertEqual(BusinessesPersistence.Delete('bennys_motorworks'), true, 'business deleted')
assertEqual(#BusinessesPersistence.List(), 0, 'business registry is now empty')

Bridge.Done()
