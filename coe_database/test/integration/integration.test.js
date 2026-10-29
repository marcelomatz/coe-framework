// Teste de integração contra MariaDB real. Só roda com COE_TEST_DB_USER,
// COE_TEST_DB_PASSWORD e COE_TEST_DB_NAME definidos (o nome deve terminar em `_test`
// porque o schema é apagado a cada cenário). Requer `lua` no PATH.
const test = require('node:test')
const assert = require('node:assert/strict')
const path = require('node:path')
const readline = require('node:readline')
const { spawn, spawnSync } = require('node:child_process')
const mysql = require('mysql2/promise')
const { createDatabaseProvider } = require('../../server/provider')
const { validateStatement, validateTransaction } = require('../../server/validation')

const env = process.env
const root = path.resolve(__dirname, '..', '..', '..')
const configured = env.COE_TEST_DB_USER && env.COE_TEST_DB_PASSWORD && env.COE_TEST_DB_NAME
const hasLua = spawnSync('lua', ['-v']).status === 0

const connectionOptions = {
	host: env.COE_TEST_DB_HOST || '127.0.0.1',
	port: Number(env.COE_TEST_DB_PORT || 3306),
	user: env.COE_TEST_DB_USER,
	password: env.COE_TEST_DB_PASSWORD,
	database: env.COE_TEST_DB_NAME,
	connectionLimit: 5
}

function luaString(value) {
	const bytes = Buffer.isBuffer(value) ? value : Buffer.from(value, 'utf8')
	return `"${[...bytes].map((byte) => `\\${String(byte).padStart(3, '0')}`).join('')}"`
}

function luaLiteral(value) {
	if (value === null || value === undefined) return 'nil'
	if (typeof value === 'boolean') return String(value)
	if (typeof value === 'number') return Number.isFinite(value) ? String(value) : 'nil'
	if (typeof value === 'bigint') return value.toString()
	if (typeof value === 'string' || Buffer.isBuffer(value)) return luaString(value)
	if (value instanceof Date) return luaString(value.toISOString())
	if (Array.isArray(value)) return `{${value.map(luaLiteral).join(',')}}`
	const entries = Object.entries(value).filter(([, entry]) => entry !== null && entry !== undefined)
	return `{${entries.map(([key, entry]) => `[${luaString(key)}]=${luaLiteral(entry)}`).join(',')}}`
}

async function resetSchema(pool) {
	const [tables] = await pool.query(
		'SELECT table_name AS name FROM information_schema.tables WHERE table_schema = DATABASE()'
	)
	await pool.query('SET FOREIGN_KEY_CHECKS = 0')
	try {
		for (const { name } of tables) {
			await pool.query(`DROP TABLE IF EXISTS \`${name}\``)
		}
	} finally {
		await pool.query('SET FOREIGN_KEY_CHECKS = 1')
	}
}

async function handleRequest(provider, request) {
	try {
		if (request.op === 'Transaction') {
			const invalid = validateTransaction(request.statements)
			if (invalid) return { ok: false, error: invalid }
			return { ok: true, result: await provider.transaction(request.statements) }
		}

		const invalid = validateStatement(request.sql, request.parameters)
		if (invalid) return { ok: false, error: invalid }
		const operation = request.op === 'Query' ? provider.query : provider.execute
		return { ok: true, result: await operation(request.sql, request.parameters) }
	} catch (error) {
		return { ok: false, error: typeof error.code === 'string' ? error.code : 'database_error' }
	}
}

function runScenario(provider, scenario) {
	return new Promise((resolve, reject) => {
		const child = spawn('lua', [path.join('coe_database', 'test', 'integration', scenario)], {
			cwd: root,
			stdio: ['pipe', 'pipe', 'pipe']
		})
		let stderr = ''
		let done = false
		let queue = Promise.resolve()

		child.stderr.on('data', (chunk) => { stderr += chunk })
		const lines = readline.createInterface({ input: child.stdout })
		lines.on('line', (line) => {
			queue = queue.then(async () => {
				const request = JSON.parse(line)
				if (request.op === 'Done') {
					done = true
					return
				}
				const response = await handleRequest(provider, request)
				const literal = response.ok
					? `{ok=true,result=${luaLiteral(response.result)}}`
					: `{ok=false,error=${luaString(response.error)}}`
				child.stdin.write(`${literal}\n`)
			}).catch(reject)
		})
		child.on('error', reject)
		child.on('close', (code) => {
			queue.then(() => {
				if (code !== 0 || !done) {
					reject(new Error(`${scenario} failed (exit ${code}):\n${stderr}`))
					return
				}
				resolve()
			})
		})
	})
}

test('integração MariaDB', { skip: !configured ? 'COE_TEST_DB_* não definido' : (!hasLua ? 'lua não encontrado no PATH' : false) }, async (t) => {
	assert.match(connectionOptions.database, /_test$/, 'COE_TEST_DB_NAME deve terminar em _test')

	const adminPool = mysql.createPool(connectionOptions)
	const errors = []
	const provider = createDatabaseProvider({
		driver: mysql,
		readOptions: () => connectionOptions,
		reportError: (operation, error) => errors.push(`${operation}:${error.code}`),
		onReady: () => {}
	})
	assert.equal(await provider.initialize(), true, 'provider conecta ao MariaDB de teste')

	t.after(async () => {
		await provider.shutdown()
		await adminPool.end()
	})

	for (const [name, scenario] of [
		['coe_core: migrations e repositório de personagens', 'core_scenario.lua'],
		['coe_inventory: migrations e persistência', 'inventory_scenario.lua'],
		['coe_audit: migrations, lote e retenção', 'audit_scenario.lua'],
		['coe_garage + coe_mobile: garagens, vagas fixas e números de telefone', 'garage_mobile_scenario.lua'],
		['coe_needs: migrations, estado por personagem e salvamento em lote', 'needs_scenario.lua'],
		['coe_vehicles + coe_vehicle_catalog: ciclo de vida do veículo, chaves e quilometragem', 'vehicles_scenario.lua'],
		['coe_economy + coe_shops + coe_inventory: ciclo de comércio, loja e transações', 'commerce_scenario.lua'],
		['coe_businesses + coe_jobs + coe_economy: gestao de empresas, equipe, folha de pagamento e carreira', 'jobs_businesses_scenario.lua'],
		['validação cumulativa: migrations de todos os resources com banco (fresh db)', 'all_migrations_scenario.lua']
	]) {
		await t.test(name, async () => {
			await resetSchema(adminPool)
			await runScenario(provider, scenario)
		})
	}
})
