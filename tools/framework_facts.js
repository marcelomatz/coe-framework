#!/usr/bin/env node
'use strict';
/**
 * Fatos do COE Framework lidos direto do repositório (fonte única para docs e website):
 *   versão/tag/canal (version.json), lista de resources (pastas com fxmanifest.lua),
 *   exports de cada resource (reference/<resource>.md, gerado de types.lua por gen_reference.lua)
 *   e comandos/teclas registrados no código (RegisterCommand / RegisterKeyMapping).
 *
 * Uso como módulo:  const facts = require('./framework_facts.js').collect();
 * Uso como CLI:     node tools/framework_facts.js [--out <arquivo.json>]
 */

const fs = require('node:fs');
const path = require('node:path');

const FRAMEWORK_ROOT = path.resolve(__dirname, '..');
const NOT_RESOURCES = new Set(['tools', 'reference', 'node_modules']);

function read(file) {
	try {
		return fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
	} catch (_) {
		return null;
	}
}

function listResources(root) {
	return fs.readdirSync(root, { withFileTypes: true })
		.filter(d => d.isDirectory() && !d.name.startsWith('.') && !NOT_RESOURCES.has(d.name))
		.filter(d => fs.existsSync(path.join(root, d.name, 'fxmanifest.lua')))
		.map(d => d.name)
		.sort();
}

/** Exports de reference/<resource>.md: nome, assinatura, descrição, parâmetros e retornos. */
function parseReference(md) {
	const exportsList = [];
	if (!md) return exportsList;
	const section = md.split(/\n## Exports\n/)[1];
	if (!section) return exportsList;
	const body = section.split(/\n## (?!#)/)[0];
	const chunks = body.split(/\n### /).slice(1);
	for (const chunk of chunks) {
		const head = chunk.match(/^`([A-Za-z_][\w]*)\(([^`]*)\)`/);
		if (!head) continue;
		const lines = chunk.split('\n').slice(1);
		const desc = [];
		const params = [];
		const returns = [];
		let mode = 'desc';
		for (const raw of lines) {
			const line = raw.trim();
			if (line.startsWith('**Retorno')) { mode = 'returns'; continue; }
			if (line.startsWith('| Parâmetro') || line.startsWith('|---')) { mode = 'params'; continue; }
			if (mode === 'params' && line.startsWith('|')) {
				const cells = line.split(/(?<!\\)\|/).slice(1, -1).map(c => c.trim().replace(/^`|`$/g, '').replace(/\\\|/g, '|'));
				if (cells.length >= 2) params.push({ name: cells[0], type: cells[1], desc: cells[2] || '' });
				continue;
			}
			if (mode === 'returns' && line.startsWith('- ')) {
				const m = line.match(/^- `([^`]*)`(?:\s+`([^`]*)`)?(?:\s+—\s+(.*))?/);
				if (m) returns.push({ type: m[1], name: m[2] || '', desc: m[3] || '' });
				continue;
			}
			if (mode === 'desc' && line && !line.startsWith('|')) desc.push(line);
		}
		exportsList.push({
			name: head[1],
			signature: `${head[1]}(${head[2]})`,
			args: head[2],
			desc: desc.join(' '),
			params,
			returns,
		});
	}
	return exportsList;
}

function luaFiles(dir) {
	const out = [];
	const walk = d => {
		for (const e of fs.readdirSync(d, { withFileTypes: true })) {
			if (e.name.startsWith('.') || e.name === 'node_modules' || e.name === 'test' || e.name === 'tests') continue;
			const p = path.join(d, e.name);
			if (e.isDirectory()) walk(p);
			else if (e.name.endsWith('.lua')) out.push(p);
		}
	};
	walk(dir);
	return out;
}

/** Valor literal de <campo> no config.lua do resource (ex.: Command = 'telefone'). */
function configValue(resDir, field) {
	const cfg = read(path.join(resDir, 'config.lua')) || '';
	const m = cfg.match(new RegExp(`\\b${field}\\s*=\\s*['"]([^'"]+)['"]`));
	return m ? m[1] : null;
}

/** Comandos e teclas registrados no código do resource. */
function collectCommands(resDir) {
	const commands = new Map();
	const keymaps = new Map();
	for (const file of luaFiles(resDir)) {
		const src = read(file) || '';
		for (const m of src.matchAll(/RegisterCommand\(\s*(?:'([^']+)'|"([^"]+)"|([\w.]+))/g)) {
			let name = m[1] || m[2];
			if (!name && m[3]) {
				const field = m[3].split('.').pop();
				if (/^[A-Z]/.test(field)) name = configValue(resDir, field);
			}
			if (!name || /^[+-]/.test(name)) continue;
			if (!commands.has(name)) commands.set(name, { name, kind: 'command' });
		}
		for (const m of src.matchAll(/RegisterKeyMapping\(\s*['"]([^'"]+)['"]\s*,\s*['"]([^'"]*)['"]\s*,\s*['"][^'"]*['"]\s*,\s*([^)]*)\)/g)) {
			let key = (m[3].match(/['"]([^'"]+)['"]\s*$/) || [])[1] || null;
			if (!key) {
				// Tecla vinda do config (ex.: config.OpenKey, Config.Client.openKey)
				const field = (m[3].match(/([A-Za-z_]\w*)\s*$/) || [])[1];
				if (field) key = configValue(resDir, field);
			}
			keymaps.set(m[1].replace(/^\+/, ''), { name: m[1], kind: 'keymap', label: m[2], key });
		}
	}
	// RegisterKeyMapping com campos do config (ex.: CoeCharactersConfig.Command, CoeCharactersConfig.OpenKey).
	for (const file of luaFiles(resDir)) {
		const src = read(file) || '';
		for (const m of src.matchAll(/RegisterKeyMapping\(\s*([A-Za-z_][\w.]*)\s*,\s*([A-Za-z_][\w.]*)\s*,\s*['"]keyboard['"]\s*,\s*([A-Za-z_][\w.]*)\s*\)/g)) {
			const field = expr => configValue(resDir, expr.split('.').pop());
			const name = field(m[1]);
			if (name && !keymaps.has(name)) keymaps.set(name, { name, kind: 'keymap', label: field(m[2]) || name, key: field(m[3]) });
		}
		// bind(Config.Keys.x, ...) com tabelas { command = '...', default = '...', label = '...' } no config.
		if (/RegisterKeyMapping\(\s*key\.command/.test(src)) {
			const cfg = read(path.join(resDir, 'config.lua')) || '';
			for (const t of cfg.matchAll(/\{([^{}]*\bcommand\s*=\s*['"][^'"]+['"][^{}]*)\}/g)) {
				const get = k => (t[1].match(new RegExp(`\\b${k}\\s*=\\s*['"]([^'"]*)['"]`)) || [])[1];
				const name = get('command');
				if (name && !keymaps.has(name)) keymaps.set(name, { name, kind: 'keymap', label: get('label') || name, key: get('default') || null });
			}
		}
	}
	// Comando que só existe como par +/- de uma tecla aparece como tecla; o restante, como comando.
	for (const k of keymaps.keys()) commands.delete(k);
	return { commands: [...commands.values()].sort((a, b) => a.name.localeCompare(b.name)), keymaps: [...keymaps.values()] };
}

function collect(root = FRAMEWORK_ROOT) {
	const versionJson = JSON.parse(read(path.join(root, 'version.json')) || '{}');
	const version = String(versionJson.version || '0.0.0').replace(/^v/, '');
	const latest = (versionJson.releases || [])[0] || {};
	const resources = listResources(root).map(id => {
		const resDir = path.join(root, id);
		const reference = read(path.join(root, 'reference', `${id}.md`));
		const { commands, keymaps } = collectCommands(resDir);
		return {
			id,
			typed: fs.existsSync(path.join(resDir, 'types.lua')),
			hasReference: reference !== null,
			exports: parseReference(reference),
			commands,
			keymaps,
		};
	});
	return {
		version,
		tag: versionJson.tag || `v${version}`,
		channel: versionJson.channel || 'stable',
		date: latest.version === version ? latest.date || null : null,
		notes: versionJson.notes || '',
		resourceCount: resources.length,
		typedCount: resources.filter(r => r.typed).length,
		resources,
	};
}

module.exports = { collect, parseReference, listResources, FRAMEWORK_ROOT };

if (require.main === module) {
	const i = process.argv.indexOf('--out');
	const json = JSON.stringify(collect(), null, 2) + '\n';
	if (i > 0 && process.argv[i + 1]) {
		fs.writeFileSync(process.argv[i + 1], json, 'utf8');
		console.log(`[OK] Fatos do framework gravados em ${process.argv[i + 1]}`);
	} else {
		process.stdout.write(json);
	}
}
