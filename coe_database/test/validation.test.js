const test = require('node:test')
const assert = require('node:assert/strict')
const { validateStatement, validateTransaction } = require('../server/validation')

test('accepts parameterized statements with supported values', () => {
	assert.equal(validateStatement('SELECT ? AS value', ['safe']), null)
})

test('rejects malformed statements and parameters', () => {
	assert.equal(validateStatement('', []), 'invalid_sql')
	assert.equal(validateStatement('SELECT ?', [undefined]), 'invalid_parameters')
	assert.equal(validateStatement('SELECT ?', [{}]), 'invalid_parameters')
	assert.equal(validateStatement('SELECT ?', 'not-an-array'), 'invalid_parameters')
	assert.equal(validateStatement('SELECT ?', [new Date(Number.NaN)]), 'invalid_parameters')
})

test('validates every statement before a transaction starts', () => {
	assert.equal(validateTransaction([
		{ sql: 'UPDATE accounts SET balance = ? WHERE id = ?', parameters: [20, 1] },
		{ sql: 'INSERT INTO ledger (account_id) VALUES (?)', parameters: [1] }
	]), null)
	assert.equal(validateTransaction([
		{ sql: 'UPDATE accounts SET balance = ?', parameters: [20] },
		{ sql: '', parameters: [] }
	]), 'invalid_sql')
	assert.equal(validateTransaction([]), 'invalid_transaction')
})
