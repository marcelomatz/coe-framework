const mysql = require('mysql2/promise')
// O FXServer resolve require() a partir da raiz do resource, não da pasta deste arquivo.
const { createDatabaseProvider } = require('./server/provider')
const { validateStatement, validateTransaction } = require('./server/validation')

const ALLOWED_CALLERS = new Set(['coe_core', 'coe_inventory', 'coe_admin', 'coe_audit', 'coe_vehicles', 'coe_vehicle_catalog', 'coe_handling', 'coe_mechanic', 'coe_businesses', 'coe_garages', 'coe_needs', 'coe_economy', 'coe_housing', 'coe_banking', 'coe_doors', 'coe_spawn', 'coe_crafting', 'coe_apps', 'coe_phone', 'coe_telecom', 'coe_amzg', 'coe_mail', 'coe_news', 'coe_factions', 'coe_police', 'coe_ems', 'coe_mdt', 'coe_crypto', 'coe_deepweb', 'coe_jobs', 'coe_elos', 'coe_shops', 'coe_fuel'])
const MAX_CONNECTION_LIMIT = 50

function logStructured(level, category, event, context) {
	try {
		const logged = exports.coe_logging.Log(level, category, event, context)
		return logged === true
	} catch (error) {
		console.error(JSON.stringify({
			timestamp: new Date().toISOString(),
			level: 'error',
			category: 'logging',
			event: 'structured_logger_unavailable',
			resource: 'coe_database',
			context: {}
		}))
		return false
	}
}

function logDatabaseError(operation, error) {
	const code = error && typeof error.code === 'string' ? error.code : 'UNKNOWN'
	const logged = logStructured('error', 'database', `${operation}_failed`, {
		error_code: code,
		operation
	})
	if (!logged) {
		console.error(JSON.stringify({
			level: 'error',
			category: 'database',
			event: `${operation}_failed`,
			resource: 'coe_database',
			context: { error_code: code, operation }
		}))
	}
}

function complete(callback, success, result, errorCode) {
	if (typeof callback !== 'function') {
		logStructured('warn', 'validation', 'database_callback_required')
		return
	}

	setImmediate(() => {
		try {
			callback(success, result, errorCode)
		} catch (error) {
			logDatabaseError('callback', error)
		}
	})
}

function isAuthorizedCaller() {
	const caller = GetInvokingResource()
	return typeof caller === 'string' && ALLOWED_CALLERS.has(caller)
}

function configurationError(code) {
	const error = new Error(code)
	error.code = code
	return error
}

function readConnectionOptions() {
	const host = GetConvar('coe_database_host', '127.0.0.1').trim()
	const user = GetConvar('coe_database_user', '').trim()
	const password = GetConvar('coe_database_password', '')
	const database = GetConvar('coe_database_name', '').trim()
	const portValue = GetConvar('coe_database_port', '3306')
	const connectionLimitValue = GetConvar('coe_database_connection_limit', '10')
	const sslValue = GetConvar('coe_database_ssl', 'false')
	const port = Number(portValue)
	const connectionLimit = Number(connectionLimitValue)

	if (!host || !user || !password || !database) {
		throw configurationError('database_configuration_incomplete')
	}
	if (!/^\d+$/.test(portValue) || !Number.isInteger(port) || port < 1 || port > 65535) {
		throw configurationError('invalid_database_port')
	}
	if (!/^\d+$/.test(connectionLimitValue) || !Number.isInteger(connectionLimit)
		|| connectionLimit < 1
		|| connectionLimit > MAX_CONNECTION_LIMIT) {
		throw configurationError('invalid_connection_limit')
	}
	if (sslValue !== 'true' && sslValue !== 'false') {
		throw configurationError('invalid_ssl_setting')
	}

	return {
		host,
		user,
		password,
		database,
		port,
		waitForConnections: true,
		connectionLimit,
		queueLimit: 100,
		connectTimeout: 10000,
		enableKeepAlive: true,
		keepAliveInitialDelay: 0,
		charset: 'utf8mb4',
		timezone: 'Z',
		dateStrings: true,
		supportBigNumbers: true,
		bigNumberStrings: true,
		multipleStatements: false,
		ssl: sslValue === 'true' ? { rejectUnauthorized: true } : undefined
	}
}

const database = createDatabaseProvider({
	driver: mysql,
	readOptions: readConnectionOptions,
	reportError: logDatabaseError,
	onReady: () => logStructured('info', 'database', 'database_connection_ready')
})

function registerQueryExport(name, execute, operation) {
	exports(name, (sql, parameters, callback) => {
		if (typeof callback !== 'function') {
			complete(callback, false, null, 'callback_required')
			return
		}
		if (!isAuthorizedCaller()) {
			complete(callback, false, null, 'caller_not_allowed')
			return
		}

		const validationError = validateStatement(sql, parameters)
		if (validationError) {
			logStructured('warn', 'validation', `${operation}_validation_failed`, {
				error_code: validationError,
				operation
			})
			complete(callback, false, null, validationError)
			return
		}
		// Responde pelo callback sem criar uma promise já rejeitada, que o runtime reporta como não tratada.
		if (!database.isReady()) {
			complete(callback, false, null, 'database_not_ready')
			return
		}

		execute(sql, parameters)
			.then((result) => complete(callback, true, result, null))
			.catch((error) => {
				const code = error && typeof error.code === 'string'
					? error.code
					: 'query_failed'
				logDatabaseError(operation, error)
				complete(callback, false, null, code)
			})
	})
}

registerQueryExport('Query', database.query, 'query')
registerQueryExport('Execute', database.execute, 'execute')

exports('Transaction', (statements, callback) => {
	if (typeof callback !== 'function') {
		complete(callback, false, null, 'callback_required')
		return
	}
	if (!isAuthorizedCaller()) {
		complete(callback, false, null, 'caller_not_allowed')
		return
	}

	const validationError = validateTransaction(statements)
	if (validationError) {
		logStructured('warn', 'validation', 'transaction_validation_failed', {
			error_code: validationError,
			operation: 'transaction'
		})
		complete(callback, false, null, validationError)
		return
	}
	if (!database.isReady()) {
		complete(callback, false, null, 'database_not_ready')
		return
	}

	database.transaction(statements)
		.then((result) => complete(callback, true, result, null))
		.catch((error) => {
			const code = error && typeof error.code === 'string'
				? error.code
				: 'transaction_failed'
			complete(callback, false, null, code)
		})
})

exports('IsReady', () => isAuthorizedCaller() && database.isReady())

on('onResourceStart', (resourceName) => {
	if (resourceName === GetCurrentResourceName()) {
		database.initialize().catch((error) => logDatabaseError('initialization', error))
	}
})

on('onResourceStop', (resourceName) => {
	if (resourceName === GetCurrentResourceName()) {
		database.shutdown().catch((error) => logDatabaseError('shutdown', error))
	}
})
