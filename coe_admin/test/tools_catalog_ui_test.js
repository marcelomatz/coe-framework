// Offline NUI harness: exercise the real tools.js without Cfx or browser dependencies.
'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

class Element {
	constructor(tag) {
		this.tag = tag;
		this.children = [];
		this.listeners = {};
		this.value = '';
		this.textContent = '';
		this.classList = { add() {}, remove() {} };
	}
	append(...children) { this.children.push(...children); }
	replaceChildren(...children) { this.children = children; }
	addEventListener(name, fn) { this.listeners[name] = fn; }
	setAttribute() {}
	get text() { return this.textContent + this.children.map(node => node.text).join(' '); }
	find(text) {
		if (this.tag === 'button' && this.textContent === text) { return this; }
		for (const node of this.children) {
			const match = node.find(text);
			if (match) { return match; }
		}
		return null;
	}
}

function harness(mode) {
	const ids = Object.fromEntries(['staff', 'sf-tabs', 'sf-body', 'sf-status', 'sf-close'].map(id => [id, new Element('div')]));
	const listeners = {};
	const requests = [];
	let lastRequestAt = -Infinity;
	let responseMode = mode;
	const clock = { now: 1000 };
	vm.runInNewContext(fs.readFileSync(path.join(__dirname, '..', 'html', 'tools.js'), 'utf8'), {
		document: {
			getElementById: id => ids[id] || null,
			createElement: tag => new Element(tag),
			addEventListener() {},
			querySelector: () => null
		},
		window: { addEventListener: (name, fn) => { listeners[name] = fn; } },
		setTimeout: () => 1,
		clearTimeout() {},
		fetch: async (_url, options) => {
			const request = JSON.parse(options.body);
			requests.push(request);
			let result;
			if (clock.now - lastRequestAt < 200) {
				result = { ok: false, error: 'busy' };
			} else if (responseMode === 'transport') {
				throw new Error('network unavailable');
			} else if (responseMode === 'malformed') {
				result = { ok: true, data: {} };
			} else if (responseMode !== 'success') {
				result = { ok: false, error: responseMode };
			} else {
				const filters = { classes: [{ id: 7, name: 'super' }], categories: ['super'], dlcs: ['TitleUpdate'] };
				const page = {
					vehicles: [{ model: 'adder', name: 'Adder', class: 'super' }],
					total: 921, offset: request.data.offset || 0, limit: 40, catalog: true,
					filters
				};
				result = { ok: true, data: request.action === 'catalogFilters' ? filters : page };
			}
			lastRequestAt = clock.now;
			return { json: async () => result };
		}
	}, { filename: 'tools.js' });
	return {
		ids, requests, clock,
		setMode: value => { responseMode = value; },
		open: () => listeners.message({ data: { action: 'toolsOpen', data: { modules: { vehicles: true } } } })
	};
}

const flush = () => new Promise(resolve => setImmediate(resolve));

async function main() {
	const success = harness('success');
	success.open();
	await flush();
	assert.match(success.ids['sf-body'].text, /Adder/, 'initial load renders vehicles under the real 200ms rate limit');
	assert.equal(success.requests.length, 1, 'initial load uses a single authorized request for page and filters');
	assert.equal(success.requests[0].action, 'catalog');
	assert.equal(success.requests[0].data.includeFilters, true);
	success.clock.now += 300;
	success.ids['sf-body'].find('Próxima').listeners.click();
	await flush();
	assert.equal(success.requests[1].data.offset, 40);
	assert.equal(success.requests[1].data.includeFilters, false);

	for (const mode of ['catalog_not_ready', 'catalog_unavailable', 'forbidden', 'busy', 'timeout', 'transport', 'malformed']) {
		const failed = harness(mode);
		failed.open();
		await flush();
		assert.doesNotMatch(failed.ids['sf-body'].text, /Carregando/, mode + ' must not leave the UI loading');
		assert.ok(failed.ids['sf-status'].textContent, mode + ' displays an explicit error');
		const retry = failed.ids['sf-body'].find('Tentar novamente');
		assert.ok(retry, mode + ' offers recovery');
		failed.setMode('success');
		failed.clock.now += 300;
		retry.listeners.click();
		await flush();
		assert.match(failed.ids['sf-body'].text, /Adder/, mode + ' recovers on retry');
	}
	console.log('coe_admin catalog UI: ok (rate limit, pagination, explicit failures and retry)');
}

main().catch(error => { console.error(error); process.exitCode = 1; });
