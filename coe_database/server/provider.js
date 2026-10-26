const INITIAL_RETRY_DELAY_MS = 5000
const MAX_RETRY_DELAY_MS = 60000

function createDatabaseProvider({
	driver,
	readOptions,
	reportError,
	onReady,
	delay
}) {
	let pool = null
	let ready = false
	let stopping = false
	let retryTimer = null
	let retryResolver = null

	const wait = delay || ((milliseconds) => new Promise((resolve) => {
		retryResolver = resolve
		retryTimer = setTimeout(() => {
			retryTimer = null
			retryResolver = null
			resolve()
		}, milliseconds)
	}))

	function logError(operation, error) {
		reportError(operation, error)
	}

	function createProviderError(code) {
		const error = new Error(code)
		error.code = code
		return error
	}

	async function initialize() {
		let options
		try {
			options = readOptions()
		} catch (error) {
			logError('configuration', error)
			return false
		}

		let retryDelay = INITIAL_RETRY_DELAY_MS
		while (!stopping) {
			let candidatePool
			try {
				candidatePool = driver.createPool(options)
				if (candidatePool && typeof candidatePool.on === 'function') {
					candidatePool.on('connection', (connection) => {
						if (connection && typeof connection.query === 'function') {
							connection.query("SET SESSION sql_mode = CONCAT_WS(',', @@SESSION.sql_mode, 'STRICT_TRANS_TABLES')", () => {})
						}
					})
				}
				await candidatePool.query('SELECT 1')
				if (stopping) {
					await candidatePool.end()
					return false
				}

				pool = candidatePool
				ready = true
				onReady()
				return true
			} catch (error) {
				if (candidatePool) {
					try {
						await candidatePool.end()
					} catch (closeError) {
						logError('failed-startup-pool-close', closeError)
					}
				}

				logError('startup', error)
				await wait(retryDelay)
				retryDelay = Math.min(retryDelay * 2, MAX_RETRY_DELAY_MS)
			}
		}

		return false
	}

	async function query(sql, parameters) {
		if (!ready || !pool || stopping) {
			throw createProviderError('database_not_ready')
		}

		const [rows] = await pool.execute(sql, parameters)
		return rows
	}

	async function execute(sql, parameters) {
		if (!ready || !pool || stopping) {
			throw createProviderError('database_not_ready')
		}

		const [result] = await pool.execute(sql, parameters)
		return result
	}

	async function transaction(statements) {
		if (!ready || !pool || stopping) {
			throw createProviderError('database_not_ready')
		}

		let connection
		let transactionStarted = false
		try {
			connection = await pool.getConnection()
			await connection.beginTransaction()
			transactionStarted = true

			const results = []
			for (const statement of statements) {
				const [result] = await connection.execute(statement.sql, statement.parameters)
				results.push(result)
			}

			await connection.commit()
			transactionStarted = false
			return results
		} catch (error) {
			let errorCode = 'transaction_failed'
			logError('transaction', error)
			if (connection && transactionStarted) {
				try {
					await connection.rollback()
				} catch (rollbackError) {
					errorCode = 'transaction_rollback_failed'
					logError('transaction-rollback', rollbackError)
				}
			}
			throw createProviderError(errorCode)
		} finally {
			if (connection) {
				try {
					connection.release()
				} catch (error) {
					logError('connection-release', error)
				}
			}
		}
	}

	async function shutdown() {
		stopping = true
		ready = false
		if (retryTimer) {
			clearTimeout(retryTimer)
			retryTimer = null
			const resolveRetry = retryResolver
			retryResolver = null
			if (resolveRetry) {
				resolveRetry()
			}
		}

		const activePool = pool
		pool = null
		if (!activePool) {
			return
		}

		try {
			await activePool.end()
		} catch (error) {
			logError('shutdown', error)
		}
	}

	return {
		execute,
		initialize,
		isReady: () => ready && !stopping,
		query,
		shutdown,
		transaction
	}
}

module.exports = { createDatabaseProvider }
