const test = require('node:test')
const assert = require('node:assert/strict')
const { DEFAULT_CALLERS, createCallerCheck } = require('../server/access')

test('framework resources are allowed without ACE', () => {
	const allowed = createCallerCheck({ isAceAllowed: () => false })
	for (const name of DEFAULT_CALLERS) {
		assert.equal(allowed(name), true)
	}
})

test('defaults only list framework resources', () => {
	for (const name of DEFAULT_CALLERS) {
		assert.match(name, /^coe_/)
	}
	// os scripts avançados do framework estão na allowlist padrão
	assert.equal(DEFAULT_CALLERS.includes('coe_admin'), true)
	assert.equal(DEFAULT_CALLERS.includes('coe_banking'), true)
	assert.equal(DEFAULT_CALLERS.includes('coe_shield'), true)
})

test('other resources need the coe.database ACE on their resource principal', () => {
	const asked = []
	const allowed = createCallerCheck({
		isAceAllowed: (principal, ace) => {
			asked.push([principal, ace])
			return principal === 'resource.meu_script'
		}
	})
	assert.equal(allowed('meu_script'), true)
	assert.equal(allowed('random_script'), false)
	assert.deepEqual(asked, [['resource.meu_script', 'coe.database'], ['resource.random_script', 'coe.database']])
})

test('invalid callers are refused', () => {
	const allowed = createCallerCheck({ isAceAllowed: () => true })
	assert.equal(allowed(null), false)
	assert.equal(allowed(''), false)
	assert.equal(allowed(42), false)
})

test('ACE answers are cached for a few seconds', () => {
	let clock = 0
	let calls = 0
	const allowed = createCallerCheck({ now: () => clock, isAceAllowed: () => { calls += 1; return true } })
	allowed('x')
	allowed('x')
	assert.equal(calls, 1)
	clock = 6000
	allowed('x')
	assert.equal(calls, 2)
})
