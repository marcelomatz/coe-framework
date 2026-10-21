const test = require('node:test')
const assert = require('node:assert/strict')
const { createDatabaseProvider } = require('../server/provider')

function createHarness({ connection, startupFailures = 0 } = {}) {
	const errors = []
	const calls = []
	let poolCount = 0

	const driver = {
		createPool: () => {
			poolCount += 1
			const shouldFailStartup = poolCount <= startupFailures
			return {
				query: async () => {
					calls.push('ping')
					if (shouldFailStartup) {
						throw Object.assign(new Error('connection refused'), { code: 'ECONNREFUSED' })
					}
				},
				execute: async (sql, parameters) => {
					calls.push(['execute', sql, parameters])
					if (sql.startsWith('SELECT')) {
						return [[{ value: parameters[0] }], []]
					}
					return [{ affectedRows: 1 }, []]
				},
				getConnection: async () => connection,
				end: async () => calls.push('pool-end')
			}
		}
	}

	const provider = createDatabaseProvider({
		driver,
		readOptions: () => ({ host: '127.0.0.1' }),
		reportError: (operation, error) => errors.push([operation, error.code]),
		onReady: () => calls.push('ready'),
		delay: async () => calls.push('retry')
	})

	return { calls, errors, provider }
}

test('initializes, executes queries and closes the pool', async () => {
	const harness = createHarness()
	assert.equal(await harness.provider.initialize(), true)
	assert.equal(harness.provider.isReady(), true)
	assert.deepEqual(await harness.provider.query('SELECT ?', ['value']), [{ value: 'value' }])
	assert.deepEqual(await harness.provider.execute('UPDATE t SET v = ?', [1]), { affectedRows: 1 })

	await harness.provider.shutdown()
	assert.equal(harness.provider.isReady(), false)
	assert.equal(harness.calls.filter((call) => call === 'pool-end').length, 1)
})

test('retries a failed initial connection and becomes ready after recovery', async () => {
	const harness = createHarness({ startupFailures: 1 })
	assert.equal(await harness.provider.initialize(), true)
	assert.deepEqual(harness.calls.slice(0, 3), ['ping', 'pool-end', 'retry'])
	assert.equal(harness.provider.isReady(), true)
	assert.deepEqual(harness.errors, [['startup', 'ECONNREFUSED']])
})

test('commits a transaction and releases its connection', async () => {
	const calls = []
	const connection = {
		beginTransaction: async () => calls.push('begin'),
		execute: async (sql, parameters) => {
			calls.push(['execute', sql, parameters])
			return [[{ affectedRows: 1 }], []]
		},
		commit: async () => calls.push('commit'),
		rollback: async () => calls.push('rollback'),
		release: () => calls.push('release')
	}
	const harness = createHarness({ connection })
	await harness.provider.initialize()

	const results = await harness.provider.transaction([
		{ sql: 'UPDATE a SET n = ?', parameters: [1] },
		{ sql: 'UPDATE b SET n = ?', parameters: [2] }
	])

	assert.equal(results.length, 2)
	assert.deepEqual(calls.map((call) => Array.isArray(call) ? call[0] : call), [
		'begin', 'execute', 'execute', 'commit', 'release'
	])
})

test('rolls back a failed transaction and reports rollback failure', async () => {
	const calls = []
	let executions = 0
	const connection = {
		beginTransaction: async () => calls.push('begin'),
		execute: async () => {
			executions += 1
			if (executions === 2) {
				throw Object.assign(new Error('query failed'), { code: 'ER_PARSE_ERROR' })
			}
			return [[{ affectedRows: 1 }], []]
		},
		commit: async () => calls.push('commit'),
		rollback: async () => {
			calls.push('rollback')
			throw Object.assign(new Error('rollback failed'), { code: 'ER_LOCK_DEADLOCK' })
		},
		release: () => calls.push('release')
	}
	const harness = createHarness({ connection })
	await harness.provider.initialize()

	await assert.rejects(
		harness.provider.transaction([
			{ sql: 'UPDATE a SET n = ?', parameters: [1] },
			{ sql: 'UPDATE b SET n = ?', parameters: [2] }
		]),
		(error) => error.code === 'transaction_rollback_failed'
	)
	assert.deepEqual(calls, ['begin', 'rollback', 'release'])
	assert.deepEqual(harness.errors, [
		['transaction', 'ER_PARSE_ERROR'],
		['transaction-rollback', 'ER_LOCK_DEADLOCK']
	])
})
