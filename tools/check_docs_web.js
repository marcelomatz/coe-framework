#!/usr/bin/env node
'use strict';
/**
 * Confere se o website (../website) e a documentação (../docs) dizem o mesmo que o framework.
 * O framework é a fonte: versão/tag (version.json), lista de resources, exports (reference/, gerado
 * dos types.lua) e comandos/teclas (código). Ver tools/framework_facts.js.
 *
 * Uso:
 *   node tools/check_docs_web.js [--fix] [--json] [--strict] [--docs <pasta>] [--website <pasta>]
 *
 *   --fix     corrige o que é mecânico: fatos do site, referência da API nos docs, recipe, releases.json,
 *             selos de versão, contagens de resources, entradas do CHANGELOG (a partir do releases.json),
 *             texto com acentuação corrompida e páginas geradas (roda website/tools/generate_site.js).
 *             O que exige texto novo (descrever um resource novo no catálogo, no radar ou nos docs)
 *             continua como erro, com a instrução do que fazer.
 *   --strict  avisos também reprovam (exit 1).
 *   --json    relatório em JSON (usado pelo COE Build Manager).
 *   --only docs|website   confere só uma das partes (usado no CI de cada repositório).
 *
 * Sai com 1 quando sobra erro.
 */

const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { execFileSync } = require('node:child_process');
const { collect, FRAMEWORK_ROOT } = require('./framework_facts.js');

// ---------------------------------------------------------------------------------------------------
// Argumentos e utilitários
// ---------------------------------------------------------------------------------------------------
const argv = process.argv.slice(2);
const flag = name => argv.includes(name);
const option = (name, fallback) => {
	const i = argv.indexOf(name);
	return i >= 0 && argv[i + 1] ? path.resolve(argv[i + 1]) : fallback;
};
const FIX = flag('--fix');
const JSON_OUT = flag('--json');
const STRICT = flag('--strict');
// --only docs|website: cada repositório confere só a sua parte no CI (evita um PR depender do outro estar mergeado).
const ONLY = (() => { const i = argv.indexOf('--only'); return i >= 0 ? String(argv[i + 1] || '') : ''; })();
const want = part => !ONLY || ONLY === part;
const WORKSPACE = path.resolve(FRAMEWORK_ROOT, '..');
const DOCS = option('--docs', path.join(WORKSPACE, 'docs'));
const WEBSITE = option('--website', path.join(WORKSPACE, 'website'));

const issues = [];
const fixed = [];
const err = (area, message, hint = '') => issues.push({ level: 'error', area, message, hint });
const warn = (area, message, hint = '') => issues.push({ level: 'warning', area, message, hint });
const didFix = (area, message) => fixed.push({ area, message });

const exists = p => fs.existsSync(p);
const readRaw = p => fs.readFileSync(p, 'utf8');
const lf = s => s.replace(/\r\n/g, '\n');
const read = p => (exists(p) ? lf(readRaw(p)) : null);
const rel = p => path.relative(WORKSPACE, p).replace(/\\/g, '/');

/** Grava preservando o fim de linha do arquivo existente (o repositório usa CRLF no Windows). */
function write(p, content) {
	const eol = exists(p) && readRaw(p).includes('\r\n') ? '\r\n' : '\n';
	fs.mkdirSync(path.dirname(p), { recursive: true });
	fs.writeFileSync(p, lf(content).replace(/\n/g, eol), 'utf8');
}

function listFiles(dir, filter, recursive = false) {
	if (!exists(dir)) return [];
	const out = [];
	for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
		const p = path.join(dir, e.name);
		if (e.isDirectory()) {
			if (recursive && !e.name.startsWith('.') && e.name !== 'node_modules' && e.name !== 'vendor') out.push(...listFiles(p, filter, true));
		} else if (filter(e.name)) out.push(p);
	}
	return out.sort();
}

// Acentuação corrompida (UTF-8 lido como Latin-1): "atualizaÃ§Ã£o", "Ã©", "â€”".
const MOJIBAKE = /Ã[\u0080-¿¡-¿§£©ª³µº]|â€[\u0080-¿"™œ“”–—]/;
function repairMojibake(text) {
	if (!MOJIBAKE.test(text)) return text;
	try {
		const repaired = Buffer.from(text, 'latin1').toString('utf8');
		if (!repaired.includes('�')) return repaired;
	} catch (_) { /* segue */ }
	return text.replace(/Ã§/g, 'ç').replace(/Ã£/g, 'ã').replace(/Ãµ/g, 'õ').replace(/Ã©/g, 'é').replace(/Ã¡/g, 'á')
		.replace(/Ã³/g, 'ó').replace(/Ãª/g, 'ê').replace(/Ã­/g, 'í').replace(/Ãº/g, 'ú').replace(/Ã¢/g, 'â')
		.replace(/â€”/g, '—').replace(/â€“/g, '–').replace(/â€œ/g, '“').replace(/â€/g, '”');
}
function repairDeep(value) {
	if (typeof value === 'string') return repairMojibake(value);
	if (Array.isArray(value)) return value.map(repairDeep);
	if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, repairDeep(v)]));
	return value;
}

function requireFresh(p) {
	delete require.cache[require.resolve(p)];
	return require(p);
}

// ---------------------------------------------------------------------------------------------------
// Fatos
// ---------------------------------------------------------------------------------------------------
const facts = collect();
const RES = facts.resources.map(r => r.id);
const RES_SET = new Set(RES);
const EXPORTS = new Map(facts.resources.map(r => [r.id, new Set(r.exports.map(e => e.name))]));
const TAG = facts.tag;
const VERSION_RE = /\bv\d+\.\d+\.\d+(?:-(?:alpha|beta|rc)\.\d+)?\b/g;

// Totais antigos de resources (para achar contagens esquecidas sem confundir com contagens por camada).
function priorTotals(releases) {
	const totals = new Set([27]);
	for (const r of releases || []) if (Number.isInteger(r.resourcesCount)) totals.add(r.resourcesCount);
	totals.delete(facts.resourceCount);
	return totals;
}

// Tiers (núcleo / base) vêm do catálogo do coe.ps1 na raiz do ambiente, quando existe.
function tierCounts() {
	const ps1 = read(path.join(WORKSPACE, 'coe.ps1'));
	if (!ps1) return null;
	const counts = { core: 0, base: 0 };
	for (const m of ps1.matchAll(/'(\w+)'\s*=\s*@\{\s*Repo\s*=\s*'framework';\s*Tier\s*=\s*'Tier (\d)/g)) {
		if (!RES_SET.has(m[1])) continue;
		if (m[2] === '1') counts.core++;
		else if (m[2] === '2') counts.base++;
	}
	return counts.core + counts.base === facts.resourceCount ? counts : null;
}

// ---------------------------------------------------------------------------------------------------
// Contagens de resources em textos
// ---------------------------------------------------------------------------------------------------
const COUNT_RE = /(?<![\w.#\/-])(\d{1,3})(?![\w.])((?:\*\*|`|\s|%20|--|-)+(?:[\wÀ-ÿ\-.,/]+(?:\s|%20|--|-)+){0,4}?(?:resources?|Resources?|recursos|first-party|First-Party))/g;

/**
 * Confere/corrige contagens num texto. Retorna o texto (corrigido se FIX).
 * opts.skipLine(line) ignora linhas (ex.: histórico de releases).
 */
function checkCounts(file, text, opts = {}) {
	const totals = opts.priorTotals || new Set([27]);
	const tiers = opts.tiers;
	let changed = false;
	const lines = text.split('\n');
	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		if (/coe-count-ignore|rel-row|rel-latest|data-release-version/.test(line)) continue;
		if (opts.skipLine && opts.skipLine(line, i)) continue;
		const heading = line.match(/^#{1,6}\s.*\((\d+)\s+[Rr]esources?\b/);
		if (heading && !totals.has(Number(heading[1]))) continue; // contagem de seção: ver checkSectionCounts
		lines[i] = line.replace(COUNT_RE, (whole, num, rest, offset) => {
			const n = Number(num);
			if (/^0\d/.test(num)) return whole;
			const ctx = line.slice(Math.max(0, offset - 40), offset + whole.length + 40);
			const after = whole + line.slice(offset + whole.length).split(/[,.;|(<]/)[0].slice(0, 30);
			let expected = null;
			let kind = 'total';
			if (/tipad|typed|LuaLS/i.test(after)) {
				expected = facts.typedCount;
				kind = 'tipados';
			} else if (tiers && /infra|núcleo|nucleo|\bcore\b/i.test(ctx) && !/total|todos|all\b/i.test(ctx) && n !== facts.resourceCount) {
				expected = tiers.core;
				kind = 'núcleo (Tier 1)';
			} else if (tiers && /community|comunit|cidade|city base|\bbase\b/i.test(ctx) && n !== facts.resourceCount) {
				expected = tiers.base;
				kind = 'base (Tier 2)';
			} else if (totals.has(n)) {
				expected = facts.resourceCount;
			}
			if (expected === null || n === expected) return whole;
			if (FIX) {
				changed = true;
				didFix('contagens', `${rel(file)}:${i + 1} ${n} → ${expected} (${kind})`);
				return `${expected}${rest}`;
			}
			err('contagens', `${rel(file)}:${i + 1} diz ${n} ${kind === 'total' ? 'resources' : kind} (o framework tem ${expected})`, '--fix corrige');
			return whole;
		});
	}
	// Selo do shields.io: resources-<N>%20first--party
	let out = lines.join('\n').replace(/(img\.shields\.io\/badge\/resources-)(\d+)(%20first--party)/g, (whole, pre, num, post) => {
		if (Number(num) === facts.resourceCount) return whole;
		if (FIX) { changed = true; didFix('contagens', `${rel(file)}: selo resources ${num} → ${facts.resourceCount}`); return `${pre}${facts.resourceCount}${post}`; }
		err('contagens', `${rel(file)}: selo "resources-${num} first-party" (o framework tem ${facts.resourceCount})`, '--fix corrige');
		return whole;
	});
	return { text: out, changed };
}

/** Títulos "### Seção (N resources)": N tem de ser a quantidade de resources citados na seção. */
function checkSectionCounts(file, text, totals = new Set([27])) {
	const lines = text.split('\n');
	let changed = false;
	for (let i = 0; i < lines.length; i++) {
		const m = lines[i].match(/^(#{1,6})\s.*\((\d+)\s+([Rr]esources?)\b/);
		if (!m) continue;
		const level = m[1].length;
		const n = Number(m[2]);
		if (totals.has(n) || n === facts.resourceCount) continue; // total do framework: tratado em checkCounts
		const listed = new Set();
		for (let j = i + 1; j < lines.length; j++) {
			const h = lines[j].match(/^(#{1,6})\s/);
			if (h && h[1].length <= level) break;
			// Só conta o resource que abre a linha de tabela ou de lista (citações no meio do texto não contam).
			const t = lines[j].trim();
			let head = null;
			if (t.startsWith('|')) head = t.split('|')[1] || '';
			else if (/^([-*+]|\d+\.)\s/.test(t)) head = t.replace(/^([-*+]|\d+\.)\s+/, '').slice(0, 60);
			const id = head && (head.match(/\bcoe_[a-z_]+\b|\bcoetarget\b/) || [])[0];
			if (id && RES_SET.has(id)) listed.add(id);
		}
		if (listed.size === 0 || listed.size === n) continue;
		if (FIX) {
			lines[i] = lines[i].replace(`(${m[2]} ${m[3]}`, `(${listed.size} ${listed.size === 1 ? 'resource' : m[3].replace(/s?$/, 's')}`);
			changed = true;
			didFix('contagens', `${rel(file)}:${i + 1} seção com ${n} → ${listed.size} resources`);
		} else {
			err('contagens', `${rel(file)}:${i + 1} a seção diz ${n} resources e cita ${listed.size}`, '--fix ajusta o número');
		}
	}
	return { text: lines.join('\n'), changed };
}

// ---------------------------------------------------------------------------------------------------
// Referências a exports e comandos
// ---------------------------------------------------------------------------------------------------
const EXPORT_CALL_RE = /exports(?:\.([A-Za-z_]\w*)|\[\s*(?:'|"|&#39;|&quot;)([A-Za-z_]\w*)(?:'|"|&#39;|&quot;)\s*\])\s*:\s*([A-Za-z_]\w*)\s*\(/g;

function checkExportCalls(file, text) {
	const seen = new Set();
	for (const m of text.matchAll(EXPORT_CALL_RE)) {
		const res = m[1] || m[2];
		const fn = m[3];
		if (!/^coe/.test(res)) continue; // só resources first-party
		const key = `${res}:${fn}`;
		if (seen.has(key)) continue;
		seen.add(key);
		if (!RES_SET.has(res)) continue; // pacotes comerciais e de terceiros ficam fora (não estão neste repositório)
		if (!EXPORTS.get(res).has(fn)) err('exports', `${rel(file)} chama exports.${res}:${fn}(), que não existe (veja reference/${res}.md)`);
	}
}

// ---------------------------------------------------------------------------------------------------
// WEBSITE
// ---------------------------------------------------------------------------------------------------
function htmlFiles() {
	return [
		...listFiles(WEBSITE, n => n.endsWith('.html')),
		...listFiles(path.join(WEBSITE, 'en'), n => n.endsWith('.html')),
		...listFiles(path.join(WEBSITE, 'scripts'), n => n.endsWith('.html')),
		...listFiles(path.join(WEBSITE, 'en', 'scripts'), n => n.endsWith('.html')),
	];
}

/** Faixas [início, fim) da seção #releases (histórico de versões fica de fora das checagens de versão/contagem). */
function releaseRanges(html) {
	const marker = html.indexOf('id="releases"');
	if (marker < 0) return [];
	const start = html.lastIndexOf('<section', marker);
	const re = /<section\b|<\/section>/g;
	re.lastIndex = start;
	let depth = 0;
	let m;
	while ((m = re.exec(html))) {
		depth += m[0] === '</section>' ? -1 : 1;
		if (depth === 0) return [[start, m.index + m[0].length]];
	}
	return [];
}

function checkWebsite() {
	if (!exists(WEBSITE)) {
		warn('website', `pasta do website não encontrada (${WEBSITE})`);
		return;
	}
	const tools = path.join(WEBSITE, 'tools');

	// 1. Fatos do framework usados pelo gerador
	const factsPath = path.join(tools, 'framework_facts.json');
	const factsJson = JSON.stringify(facts, null, 2) + '\n';
	if (read(factsPath) !== factsJson) {
		if (FIX) {
			write(factsPath, factsJson);
			didFix('website', 'tools/framework_facts.json atualizado a partir do framework');
		} else err('website', 'tools/framework_facts.json não corresponde ao framework (versão, resources, exports ou comandos)', '--fix regrava');
	}

	// 2. Catálogo: um verbete por resource, nas duas línguas
	const catalogs = {};
	for (const [lang, file, key] of [['pt', 'catalog.js', 'SCRIPTS_CATALOG'], ['en', 'catalog_en.js', 'SCRIPTS_CATALOG_EN']]) {
		const p = path.join(tools, file);
		if (!exists(p)) { err('website', `tools/${file} não encontrado`); continue; }
		const list = requireFresh(p)[key] || [];
		catalogs[lang] = list;
		const ids = new Set(list.map(s => s.id));
		for (const id of RES) if (!ids.has(id)) err('website', `${id} não está em tools/${file}`, `descreva o resource em tools/${file} (título, descrição, recursos); exports e comandos vêm do framework`);
		for (const id of ids) if (!RES_SET.has(id)) err('website', `tools/${file} descreve ${id}, que não existe no framework`, 'remova o verbete e as páginas scripts/' + id + '.html');
	}

	// 3. Radar do ecossistema: os filtros da home contam os nós que o radar.js realmente desenha
	const radar = read(path.join(WEBSITE, 'assets', 'js', 'radar.js'));
	if (radar) {
		const nodes = [...radar.matchAll(/^\s*'([a-z_]+)':\s*\{\s*\n\s*name:[^\n]*\n\s*orbit:\s*(\d+)/gm)].map(m => ({ id: m[1], orbit: Number(m[2]) }));
		const perOrbit = {};
		for (const n of nodes) perOrbit[n.orbit] = (perOrbit[n.orbit] || 0) + 1;
		const missing = RES.filter(id => !nodes.some(n => n.id === id));
		if (missing.length) warn('website', `o radar da home não mostra ${missing.length} resource(s): ${missing.join(', ')}`, 'o radar é uma seleção; adicione o nó em assets/js/radar.js se fizer sentido');
		for (const file of [path.join(WEBSITE, 'index.html'), path.join(WEBSITE, 'en', 'index.html')].filter(exists)) {
			let html = read(file);
			const before = html;
			html = html.replace(/(data-orbit-filter="(all|\d)"[^>]*>[^<(]*\()(\d+)(\))/g, (whole, pre, key, num, post) => {
				const expected = key === 'all' ? nodes.length : (perOrbit[Number(key)] || 0);
				if (Number(num) === expected) return whole;
				if (FIX) return `${pre}${expected}${post}`;
				err('website', `${rel(file)}: filtro do radar "${key}" diz ${num}, o radar desenha ${expected}`, '--fix ajusta');
				return whole;
			});
			if (FIX && html !== before) { write(file, html); didFix('website', `${rel(file)}: contadores do radar ajustados`); }
		}
	}

	// 4. releases.json (duas cópias) e recipe
	const relTools = path.join(tools, 'releases.json');
	const relAssets = path.join(WEBSITE, 'assets', 'data', 'releases.json');
	let releases = null;
	if (exists(relTools)) {
		releases = JSON.parse(readRaw(relTools));
		let dirty = false;
		const repaired = repairDeep(releases);
		if (JSON.stringify(repaired) !== JSON.stringify(releases)) {
			if (FIX) { releases = repaired; dirty = true; didFix('website', 'releases.json: acentuação corrompida reparada'); }
			else err('website', 'releases.json tem acentuação corrompida (ex.: "atualizaÃ§Ã£o")', '--fix repara');
		}
		const top = (releases.releases || [])[0];
		if (releases.latestVersion !== facts.version || releases.latestTag !== TAG) {
			if (FIX) { releases.latestVersion = facts.version; releases.latestTag = TAG; releases.channel = facts.channel; dirty = true; didFix('website', `releases.json: versão atual → ${TAG}`); }
			else err('website', `releases.json diz ${releases.latestTag}, o framework está em ${TAG}`, 'rode node tools/sync_release_docs_web.js (ou --fix)');
		}
		if (!top || top.tag !== TAG) {
			err('website', `releases.json não tem a entrada de ${TAG} no topo`, 'rode node tools/sync_release_docs_web.js --notes-file <notas.md> (o ciclo de release do Build Manager faz isso)');
		} else if (top.resourcesCount !== facts.resourceCount) {
			if (FIX) { top.resourcesCount = facts.resourceCount; dirty = true; didFix('website', `releases.json: resourcesCount de ${TAG} → ${facts.resourceCount}`); }
			else err('website', `releases.json: ${TAG} diz ${top.resourcesCount} resources (o framework tem ${facts.resourceCount})`, '--fix corrige');
		}
		if (dirty) write(relTools, JSON.stringify(releases, null, 2) + '\n');
		const toolsText = read(relTools);
		if (read(relAssets) !== toolsText) {
			if (FIX) { write(relAssets, toolsText); didFix('website', 'assets/data/releases.json igualado a tools/releases.json'); }
			else err('website', 'assets/data/releases.json difere de tools/releases.json', '--fix copia');
		}
	} else err('website', 'tools/releases.json não encontrado');

	const recipeFw = read(path.join(FRAMEWORK_ROOT, 'recipe.yaml'));
	const recipeWeb = path.join(WEBSITE, 'recipe.yaml');
	if (recipeFw && read(recipeWeb) !== recipeFw) {
		if (FIX) { write(recipeWeb, recipeFw); didFix('website', 'recipe.yaml copiado do framework'); }
		else err('website', 'recipe.yaml do site difere do recipe.yaml do framework', '--fix copia');
	}

	// 5. Páginas: geradas a partir do catálogo + fatos (o gerador também renova #scripts e #releases da home)
	if (FIX) {
		try {
			execFileSync(process.execPath, [path.join(tools, 'generate_site.js')], { cwd: WEBSITE, stdio: 'pipe' });
			didFix('website', 'páginas regeneradas (scripts/*.html, en/scripts/*.html e seções #scripts/#releases da home)');
		} catch (e) {
			err('website', 'generate_site.js falhou: ' + String(e.stderr || e.message).split('\n')[0]);
		}
	} else {
		checkGeneratorParity(tools);
	}

	// 6. Textos: versão, contagens, exports chamados e acentuação
	const totals = priorTotals(releases && releases.releases);
	for (const file of htmlFiles()) {
		let html = read(file);
		const original = html;
		const ranges = releaseRanges(html);
		const inRelease = i => ranges.some(([a, b]) => i >= a && i < b);
		html = html.replace(VERSION_RE, (v, offset) => {
			if (v === TAG || inRelease(offset)) return v;
			const before = html.slice(Math.max(0, offset - 40), offset);
			if (/releases\/tag\/$|data-release-version="$|#v$/.test(before)) return v;
			if (FIX) return TAG;
			err('versão', `${rel(file)} mostra ${v} (atual: ${TAG})`, '--fix atualiza');
			return v;
		});
		if (html !== original) didFix('versão', `${rel(file)}: selos de versão → ${TAG}`);
		// contagens fora do histórico de releases
		const ranges2 = releaseRanges(html);
		let lineStart = 0;
		const lineOffsets = html.split('\n').map(l => { const s = lineStart; lineStart += l.length + 1; return s; });
		const counts = checkCounts(file, html, { priorTotals: totals, skipLine: (_, i) => ranges2.some(([a, b]) => lineOffsets[i] >= a && lineOffsets[i] < b) });
		html = counts.text;
		checkExportCalls(file, html);
		if (MOJIBAKE.test(html)) {
			if (FIX) html = repairMojibake(html);
			else err('acentuação', `${rel(file)} tem acentuação corrompida`, '--fix repara');
		}
		if (FIX && html !== read(file)) write(file, html);
	}
	for (const file of ['catalog.js', 'catalog_en.js', 'i18n.js', 'script_extras.js', 'generate_site.js'].map(f => path.join(tools, f)).filter(exists)) {
		let text = read(file);
		const counts = checkCounts(file, text, { priorTotals: totals });
		checkExportCalls(file, counts.text);
		if (FIX && counts.changed) write(file, counts.text);
	}

	// 7. Comandos documentados x comandos do código
	const cmdDocsPath = path.join(tools, 'command_docs.js');
	if (exists(cmdDocsPath)) {
		const { COMMAND_DOCS } = requireFresh(cmdDocsPath);
		const real = new Set(facts.resources.flatMap(r => r.commands.map(c => c.name)));
		for (const name of Object.keys(COMMAND_DOCS)) if (!real.has(name)) warn('comandos', `tools/command_docs.js descreve /${name}, que não está registrado no framework`);
		for (const r of facts.resources) for (const c of r.commands) if (!COMMAND_DOCS[c.name]) warn('comandos', `${r.id} registra /${c.name} sem descrição em tools/command_docs.js`);
	}

	// 8. Descrições em inglês dos exports
	if (catalogs.en) {
		const enDesc = new Map(catalogs.en.map(s => [s.id, new Set((s.exports || []).map(e => String(e.name).split('(')[0].trim()))]));
		let missing = 0;
		for (const r of facts.resources) for (const e of r.exports) if (!(enDesc.get(r.id) || new Set()).has(e.name)) missing++;
		if (missing) warn('website', `${missing} export(s) sem descrição em inglês em tools/catalog_en.js (a página em inglês usa a descrição da referência, em português)`);
	}
}

/** Gera o site numa cópia temporária e compara com as páginas versionadas. */
function checkGeneratorParity(tools) {
	const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'coe-site-'));
	try {
		const tmpSite = path.join(tmp, 'website');
		for (const sub of ['tools', 'scripts', path.join('en', 'scripts')]) fs.cpSync(path.join(WEBSITE, sub), path.join(tmpSite, sub), { recursive: true });
		for (const f of ['index.html', path.join('en', 'index.html')]) if (exists(path.join(WEBSITE, f))) fs.cpSync(path.join(WEBSITE, f), path.join(tmpSite, f));
		const refDir = exists(path.join(DOCS, 'reference')) ? path.join(DOCS, 'reference') : path.join(FRAMEWORK_ROOT, 'reference');
		if (exists(refDir)) fs.cpSync(refDir, path.join(tmp, 'docs', 'reference'), { recursive: true });
		for (const f of ['CHANGELOG.md', 'CHANGELOG.en-US.md']) {
			const cf = exists(path.join(DOCS, f)) ? path.join(DOCS, f) : (f === 'CHANGELOG.md' && exists(path.join(FRAMEWORK_ROOT, f)) ? path.join(FRAMEWORK_ROOT, f) : null);
			if (cf) fs.cpSync(cf, path.join(tmp, 'docs', f));
		}
		fs.writeFileSync(path.join(tmpSite, 'tools', 'framework_facts.json'), JSON.stringify(facts, null, 2) + '\n');
		execFileSync(process.execPath, [path.join(tmpSite, 'tools', 'generate_site.js')], { cwd: tmpSite, stdio: 'pipe' });
		const stale = [];
		const compare = relPath => {
			const a = read(path.join(WEBSITE, relPath));
			const b = read(path.join(tmpSite, relPath));
			if (a === null || a !== b) stale.push(relPath.replace(/\\/g, '/'));
		};
		for (const dir of ['scripts', path.join('en', 'scripts')]) {
			for (const f of fs.readdirSync(path.join(tmpSite, dir))) compare(path.join(dir, f));
		}
		compare('index.html');
		compare(path.join('en', 'index.html'));
		if (stale.length) {
			err('website', `${stale.length} página(s) não batem com o gerador: ${stale.slice(0, 6).join(', ')}${stale.length > 6 ? '…' : ''}`,
				'rode node tools/generate_site.js no website (ou --fix): exports, comandos, catálogo e releases vêm dos dados');
		}
	} catch (e) {
		err('website', 'não foi possível rodar o gerador para conferir: ' + String(e.stderr || e.message).split('\n')[0]);
	} finally {
		fs.rmSync(tmp, { recursive: true, force: true });
	}
}

// ---------------------------------------------------------------------------------------------------
// DOCS
// ---------------------------------------------------------------------------------------------------
function changelogEntry(rel, isEn) {
	const L = (pt, en) => (isEn ? en : pt);
	const list = (a, b) => ((isEn ? b : a) || []).map(x => `- ${x}`).join('\n');
	return `## [${rel.tag}] — ${rel.date} · \`${String(rel.channel || 'beta').toUpperCase()}\`

${(isEn ? rel.summaryEn : rel.summaryPt) || ''}

${L('### ✨ Implementações (Novos Recursos & Sistemas)', '### ✨ Implementations (New Features & Systems)')}

${list(rel.implementationsPt, rel.implementationsEn)}

${L('### ⚡ Melhorias de Arquitetura & UX', '### ⚡ Architectural & UX Improvements')}

${list(rel.improvementsPt, rel.improvementsEn)}

${L('### 🐛 Correções de Bugs', '### 🐛 Bug Fixes')}

${list(rel.fixesPt, rel.fixesEn)}
`;
}

function checkDocs() {
	if (!exists(DOCS)) {
		warn('docs', `pasta da documentação não encontrada (${DOCS})`);
		return;
	}
	// 1. Referência da API: cópia fiel de coe-framework/reference
	const srcRef = path.join(FRAMEWORK_ROOT, 'reference');
	const dstRef = path.join(DOCS, 'reference');
	for (const src of listFiles(srcRef, n => n.endsWith('.md'))) {
		const dst = path.join(dstRef, path.basename(src));
		if (read(dst) !== read(src)) {
			if (FIX) { write(dst, read(src)); didFix('docs', `reference/${path.basename(src)} copiado do framework`); }
			else err('docs', `reference/${path.basename(src)} difere do framework`, '--fix copia (ou rode o sync de release)');
		}
	}
	for (const f of listFiles(dstRef, n => n.endsWith('.md') && !n.includes('.en-US.') && n !== 'README.md')) {
		const id = path.basename(f, '.md');
		if (!RES_SET.has(id)) warn('docs', `reference/${id}.md não corresponde a nenhum resource do framework`);
	}
	for (const f of listFiles(dstRef, n => n.endsWith('.en-US.md') && n !== 'README.en-US.md')) {
		const id = path.basename(f, '.en-US.md');
		if (!EXPORTS.has(id)) continue;
		const names = new Set([...lf(readRaw(f)).matchAll(/^###\s+`([A-Za-z_]\w*)\(/gm)].map(m => m[1]));
		const missing = [...EXPORTS.get(id)].filter(n => !names.has(n));
		const extra = [...names].filter(n => !EXPORTS.get(id).has(n));
		if (missing.length || extra.length) warn('docs', `reference/${id}.en-US.md desatualizado (faltam ${missing.length}, sobram ${extra.length} exports)`, 'atualize a tradução ou apague o arquivo para o portal usar a versão gerada');
	}

	// 2. Selo de versão nos READMEs
	for (const [file, isEn] of [['README.md', true], ['README.pt-BR.md', false]]) {
		const p = path.join(DOCS, file);
		const text = read(p);
		if (!text) continue;
		const badge = `Release-${TAG.replace(/-/g, '--')}%20`;
		if (!text.includes(badge)) {
			if (FIX && /<!-- COE_DOC_VERSION_START -->[\s\S]*?<!-- COE_DOC_VERSION_END -->/.test(text)) {
				const color = facts.channel === 'stable' ? 'brightgreen' : facts.channel === 'rc' ? 'blue' : 'orange';
				const block = `<!-- COE_DOC_VERSION_START -->\n[![${isEn ? 'Current Release' : 'Release Atual'}](https://img.shields.io/badge/Release-${TAG.replace(/-/g, '--')}%20%28${facts.channel.toUpperCase()}%29-${color}.svg)](${isEn ? 'CHANGELOG.en-US.md' : 'CHANGELOG.md'})\n<!-- COE_DOC_VERSION_END -->`;
				write(p, text.replace(/<!-- COE_DOC_VERSION_START -->[\s\S]*?<!-- COE_DOC_VERSION_END -->/, block));
				didFix('docs', `${file}: selo de versão → ${TAG}`);
			} else err('docs', `${file} não mostra ${TAG} no selo de versão`, '--fix atualiza');
		}
	}

	// 3. CHANGELOG com a versão atual
	const releases = exists(path.join(WEBSITE, 'tools', 'releases.json')) ? JSON.parse(readRaw(path.join(WEBSITE, 'tools', 'releases.json'))) : null;
	const relEntry = releases && (releases.releases || []).find(r => r.tag === TAG);
	for (const [file, isEn] of [['CHANGELOG.md', false], ['CHANGELOG.en-US.md', true]]) {
		const p = path.join(DOCS, file);
		const text = read(p);
		if (!text) continue;
		if (!text.includes(`## [${TAG}]`)) {
			if (FIX && relEntry && text.includes('<!-- COE_RELEASES_START -->')) {
				write(p, text.replace('<!-- COE_RELEASES_START -->', `<!-- COE_RELEASES_START -->\n\n${changelogEntry(repairDeep(relEntry), isEn).trimEnd()}\n`));
				didFix('docs', `${file}: entrada de ${TAG} criada a partir do releases.json`);
			} else err('docs', `${file} não tem a entrada de ${TAG}`, 'o ciclo de release (sync_release_docs_web.js --notes-file) escreve a entrada');
		}
	}

	// 4. Todo resource citado nos documentos de arquitetura e catálogo
	for (const file of ['ARCHITECTURE.md', 'ARCHITECTURE.en-US.md', 'PACKS.md', 'PACKS.en-US.md']) {
		const text = read(path.join(DOCS, file));
		if (!text) continue;
		for (const id of RES) if (!new RegExp(`\\b${id}\\b`).test(text)) err('docs', `${file} não cita ${id}`, 'descreva o resource na camada/pacote certo');
	}

	// 5. Textos: contagens, seções, exports chamados e acentuação
	const totals = priorTotals(releases && releases.releases);
	const tiers = tierCounts();
	const files = [
		...listFiles(DOCS, n => n.endsWith('.md') && !n.startsWith('CHANGELOG')),
		path.join(DOCS, 'public', 'index.html'),
		path.join(DOCS, 'public', 'js', 'portal.js'),
		path.join(DOCS, 'tools', 'generate_portal.js'),
	].filter(exists);
	for (const file of files) {
		let text = read(file);
		const isTierDoc = /^(PACKS|LICENSING)/.test(path.basename(file));
		let r = checkCounts(file, text, { priorTotals: totals, tiers: isTierDoc ? tiers : null });
		let changed = r.changed;
		text = r.text;
		if (file.endsWith('.md')) {
			r = checkSectionCounts(file, text, totals);
			changed = changed || r.changed;
			text = r.text;
			checkExportCalls(file, text);
		}
		if (MOJIBAKE.test(text)) {
			if (FIX) { text = repairMojibake(text); changed = true; didFix('acentuação', `${rel(file)} reparado`); }
			else err('acentuação', `${rel(file)} tem acentuação corrompida`, '--fix repara');
		}
		if (FIX && changed) write(file, text);
	}
	for (const file of ['CHANGELOG.md', 'CHANGELOG.en-US.md'].map(f => path.join(DOCS, f)).filter(exists)) {
		const text = read(file);
		if (MOJIBAKE.test(text)) {
			if (FIX) { write(file, repairMojibake(text)); didFix('acentuação', `${rel(file)} reparado`); }
			else err('acentuação', `${rel(file)} tem acentuação corrompida`, '--fix repara');
		}
	}
}

// ---------------------------------------------------------------------------------------------------
// README do framework
// ---------------------------------------------------------------------------------------------------
function checkFrameworkReadmes() {
	const totals = priorTotals([]);
	for (const file of ['README.md', 'README.pt-BR.md'].map(f => path.join(FRAMEWORK_ROOT, f)).filter(exists)) {
		const r = checkCounts(file, read(file), { priorTotals: totals });
		checkExportCalls(file, r.text);
		if (FIX && r.changed) write(file, r.text);
	}
}

// ---------------------------------------------------------------------------------------------------
if (!ONLY) checkFrameworkReadmes();
if (want('docs')) checkDocs();
if (want('website')) checkWebsite();

// Depois de corrigir, confere de novo para relatar só o que sobrou.
if (FIX) {
	const fixes = fixed.slice();
	issues.length = 0;
	const child = (() => {
		try {
			return { code: 0, out: execFileSync(process.execPath, [__filename, '--json', '--docs', DOCS, '--website', WEBSITE, ...(ONLY ? ['--only', ONLY] : [])], { encoding: 'utf8' }) };
		} catch (e) {
			return { code: e.status, out: e.stdout };
		}
	})();
	try { issues.push(...JSON.parse(child.out).issues); } catch (_) { err('check', 'falha ao reconferir depois do --fix'); }
	fixed.length = 0;
	fixed.push(...fixes);
}

const errors = issues.filter(i => i.level === 'error');
const warnings = issues.filter(i => i.level === 'warning');
const failed = errors.length > 0 || (STRICT && warnings.length > 0);

if (JSON_OUT) {
	process.stdout.write(JSON.stringify({ ok: !failed, version: facts.version, tag: TAG, resources: facts.resourceCount, errors: errors.length, warnings: warnings.length, issues, fixed }, null, 2) + '\n');
} else {
	console.log(`COE docs/site x framework ${TAG} · ${facts.resourceCount} resources (${facts.typedCount} tipados)`);
	for (const f of fixed) console.log(`[CORRIGIDO] ${f.area}: ${f.message}`);
	for (const i of issues) console.log(`${i.level === 'error' ? '[ERRO]' : '[AVISO]'} ${i.area}: ${i.message}${i.hint ? `\n          → ${i.hint}` : ''}`);
	console.log(failed
		? `\n${errors.length} erro(s), ${warnings.length} aviso(s). Site e docs NÃO estão de acordo com o framework.`
		: `\n[OK] Site e docs de acordo com o framework${warnings.length ? ` (${warnings.length} aviso(s))` : ''}.`);
}
process.exit(failed ? 1 : 0);
