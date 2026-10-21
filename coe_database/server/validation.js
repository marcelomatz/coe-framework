const MAX_SQL_LENGTH = 65535
const MAX_PARAMETER_COUNT = 512
const MAX_TRANSACTION_STATEMENTS = 64

function isParameter(value) {
	return value === null
		|| typeof value === 'string'
		|| typeof value === 'boolean'
		|| typeof value === 'bigint'
		|| (typeof value === 'number' && Number.isFinite(value))
		|| Buffer.isBuffer(value)
		|| (value instanceof Date && Number.isFinite(value.getTime()))
}

function validateStatement(sql, parameters) {
	if (typeof sql !== 'string' || sql.trim().length === 0 || sql.length > MAX_SQL_LENGTH) {
		return 'invalid_sql'
	}
	if (!Array.isArray(parameters) || parameters.length > MAX_PARAMETER_COUNT) {
		return 'invalid_parameters'
	}
	if (!parameters.every(isParameter)) {
		return 'invalid_parameters'
	}

	return null
}

function validateTransaction(statements) {
	if (!Array.isArray(statements)
		|| statements.length === 0
		|| statements.length > MAX_TRANSACTION_STATEMENTS) {
		return 'invalid_transaction'
	}

	for (const statement of statements) {
		if (!statement || typeof statement !== 'object') {
			return 'invalid_transaction'
		}

		const error = validateStatement(statement.sql, statement.parameters)
		if (error) {
			return error
		}
	}

	return null
}

module.exports = {
	validateStatement,
	validateTransaction
}
