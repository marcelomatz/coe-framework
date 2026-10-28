#!/usr/bin/env node
/**
 * COE Framework — Sincronizador Automático de Release para Website & Documentação
 *
 * Atualiza automaticamente:
 *   1. docs/CHANGELOG.md e docs/CHANGELOG.en-US.md (com Implementações, Melhorias e Correções)
 *   2. docs/README.pt-BR.md e docs/README.md (badge da Release atual)
 *   3. docs/reference/*.md (espelhando coe-framework/reference/*.md)
 *   4. website/tools/releases.json e website/assets/data/releases.json
 *   5. website/recipe.yaml (versão sincronizada)
 *   6. website/index.html, website/en/index.html e website/scripts/*.html (via tools/generate_site.js)
 *
 * Uso:
 *   node tools/sync_release_docs_web.js [--notes-file <caminho.md>] [--summary <texto>]
 */

'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const FRAMEWORK_ROOT = path.resolve(__dirname, '..');
const WORKSPACE_ROOT = path.resolve(FRAMEWORK_ROOT, '..');
const DOCS_ROOT = path.join(WORKSPACE_ROOT, 'docs');
const WEBSITE_ROOT = path.join(WORKSPACE_ROOT, 'website');

function parseArgs(argv) {
	const opts = {
		notesFile: null,
		summary: null,
		title: null
	};
	for (let i = 2; i < argv.length; i++) {
		const a = argv[i];
		if (a === '--notes-file' && argv[i + 1]) {
			opts.notesFile = argv[++i];
		} else if (a === '--summary' && argv[i + 1]) {
			opts.summary = argv[++i];
		} else if (a === '--title' && argv[i + 1]) {
			opts.title = argv[++i];
		}
	}
	return opts;
}

function parseMarkdownSections(md) {
	const result = {
		implementations: [],
		improvements: [],
		fixes: []
	};
	if (!md) return result;

	let currentBucket = null;
	const lines = md.split(/\r?\n/);

	for (const rawLine of lines) {
		const line = rawLine.trim();
		if (line.startsWith('### ')) {
			const h = line.toLowerCase();
			if (h.includes('implementa') || h.includes('novidades') || h.includes('feature') || h.includes('✨')) {
				currentBucket = 'implementations';
			} else if (h.includes('corre') || h.includes('fix') || h.includes('bug') || h.includes('🐛')) {
				currentBucket = 'fixes';
			} else if (h.includes('melhoria') || h.includes('perf') || h.includes('otimiza') || h.includes('arquitetura') || h.includes('⚡') || h.includes('🔧')) {
				currentBucket = 'improvements';
			} else {
				currentBucket = null;
			}
			continue;
		}

		if (currentBucket && (line.startsWith('- ') || line.startsWith('* '))) {
			const cleanItem = line.slice(2).trim().replace(/\*\*/g, '');
			if (cleanItem) {
				result[currentBucket].push(cleanItem);
			}
		}
	}

	return result;
}

function updateDocsChangelog(filePath, version, tag, channel, date, summaryText, sections, isEn) {
	if (!fs.existsSync(filePath)) return false;

	let content = fs.readFileSync(filePath, 'utf8');
	const startMarker = '<!-- COE_RELEASES_START -->';
	const endMarker = '<!-- COE_RELEASES_END -->';

	const implTitle = isEn ? '### ✨ Implementations (New Features & Systems)' : '### ✨ Implementações (Novos Recursos & Sistemas)';
	const imprTitle = isEn ? '### ⚡ Architectural & UX Improvements' : '### ⚡ Melhorias de Arquitetura & UX';
	const fixTitle = isEn ? '### 🐛 Bug Fixes' : '### 🐛 Correções de Bugs';

	const implList = (sections.implementations.length ? sections.implementations : [
		isEn ? `Release ${tag} (${channel.toUpperCase()}) consolidated with 27 first-party resources.` : `Release ${tag} (${channel.toUpperCase()}) consolidada com os 27 resources first-party.`
	]).map(x => `- ${x}`).join('\n');

	const imprList = (sections.improvements.length ? sections.improvements : [
		isEn ? 'Performance, HAL contract validation, and bilingual documentation parity.' : 'Otimizações de performance, validação estrita de contratos HAL e paridade bilíngue.'
	]).map(x => `- ${x}`).join('\n');

	const fixList = (sections.fixes.length ? sections.fixes : [
		isEn ? 'General stability and persistence fixes across core and gameplay modules.' : 'Correções gerais de estabilidade e persistência nos módulos Core e Gameplay.'
	]).map(x => `- ${x}`).join('\n');

	const entryHeader = `## [${tag}] — ${date} · \`${channel.toUpperCase()}\``;
	const newEntry = `${entryHeader}

${summaryText}

${implTitle}

${implList}

${imprTitle}

${imprList}

${fixTitle}

${fixList}
`;

	// Se já existe uma seção para essa tag, substitui; caso contrário, insere no topo após startMarker
	const escapedTag = tag.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
	const existingRegex = new RegExp(`## \\[${escapedTag}\\][\\s\\S]*?(?=\\n## \\[v|\\n<!-- COE_RELEASES_END -->)`, 'm');

	if (existingRegex.test(content)) {
		content = content.replace(existingRegex, newEntry.trimEnd() + '\n\n');
	} else if (content.includes(startMarker)) {
		content = content.replace(startMarker, `${startMarker}\n\n${newEntry.trimEnd()}\n`);
	} else {
		content += `\n\n${startMarker}\n\n${newEntry.trimEnd()}\n\n${endMarker}\n`;
	}

	fs.writeFileSync(filePath, content, 'utf8');
	return true;
}

// Link para a camada de documentação do portal (hash #doc=), já na seção da versão.
// O slug replica `renderer.heading` de docs/public/js/app.js; o título segue o formato de updateDocsChangelog.
// Links com ?doc= abrem a camada website do portal e não mostram a doc.
function changelogDocsUrl(file, tag, date, channel) {
	const heading = `[${tag}] — ${date} · \`${channel.toUpperCase()}\``;
	const anchor = heading
		.toLowerCase()
		.replace(/<[^>]+>/g, '')
		.replace(/[^\w\s-]/g, '')
		.replace(/\s+/g, '-')
		.replace(/^-+|-+$/g, '');
	return `https://docs.coeroleplay.app/#doc=${file}#${anchor}`;
}

function updateDocsReadmeBadge(filePath, tag, channel, isEn) {
	if (!fs.existsSync(filePath)) return false;
	let content = fs.readFileSync(filePath, 'utf8');
	const badgeTag = tag.replace(/-/g, '--');
	const badgeColor = channel === 'stable' ? 'brightgreen' : (channel === 'rc' ? 'blue' : 'orange');
	const targetDoc = isEn ? 'CHANGELOG.en-US.md' : 'CHANGELOG.md';
	const label = isEn ? 'Current Release' : 'Release Atual';

	const block = `<!-- COE_DOC_VERSION_START -->\n[![${label}](https://img.shields.io/badge/Release-${badgeTag}%20%28${channel.toUpperCase()}%29-${badgeColor}.svg)](${targetDoc})\n<!-- COE_DOC_VERSION_END -->`;
	const regex = /<!-- COE_DOC_VERSION_START -->[\s\S]*?<!-- COE_DOC_VERSION_END -->/m;

	if (regex.test(content)) {
		content = content.replace(regex, block);
		fs.writeFileSync(filePath, content, 'utf8');
		return true;
	}
	return false;
}

function syncDocsReference() {
	const srcRefDir = path.join(FRAMEWORK_ROOT, 'reference');
	const dstRefDir = path.join(DOCS_ROOT, 'reference');
	if (!fs.existsSync(srcRefDir) || !fs.existsSync(DOCS_ROOT)) return 0;

	if (!fs.existsSync(dstRefDir)) {
		fs.mkdirSync(dstRefDir, { recursive: true });
	}

	let copied = 0;
	for (const f of fs.readdirSync(srcRefDir)) {
		if (f.endsWith('.md')) {
			fs.copyFileSync(path.join(srcRefDir, f), path.join(dstRefDir, f));
			copied++;
		}
	}
	return copied;
}

function main() {
	const opts = parseArgs(process.argv);
	const versionJsonPath = path.join(FRAMEWORK_ROOT, 'version.json');
	if (!fs.existsSync(versionJsonPath)) {
		console.error('[ERRO] version.json não encontrado em coe-framework/');
		process.exit(1);
	}

	const vData = JSON.parse(fs.readFileSync(versionJsonPath, 'utf8'));
	const version = vData.version || '0.1.0-beta.1';
	const tag = version.startsWith('v') ? version : `v${version}`;
	const channel = vData.channel || 'beta';
	const date = vData.releaseDate || new Date().toISOString().slice(0, 10);
	const resourcesCount = vData.resourcesCount || 27;
	const summaryPt = opts.summary || vData.releaseNotesSummary || `Release oficial ${tag} (${channel.toUpperCase()}) do COE Framework para FiveM Enhanced (Gen9 / DirectX 12).`;
	const summaryEn = vData.releaseNotesSummaryEn || summaryPt;
	const titlePt = opts.title || `Release ${tag} (${channel.toUpperCase()}) — Ecossistema FiveM Enhanced`;
	const titleEn = `Release ${tag} (${channel.toUpperCase()}) — FiveM Enhanced Ecosystem`;

	let rawNotes = '';
	if (opts.notesFile && fs.existsSync(opts.notesFile)) {
		rawNotes = fs.readFileSync(opts.notesFile, 'utf8');
	}

	const parsed = parseMarkdownSections(rawNotes);

	// 1. Atualiza docs/CHANGELOG.md, docs/CHANGELOG.en-US.md, README badges e reference/
	if (fs.existsSync(DOCS_ROOT)) {
		// Se não vieram seções customizadas via --notes-file e a tag já existe em releases.json, preserva os itens ricos
		const releasesJsonPath = path.join(WEBSITE_ROOT, 'tools', 'releases.json');
		if (!rawNotes && fs.existsSync(releasesJsonPath)) {
			try {
				const existingData = JSON.parse(fs.readFileSync(releasesJsonPath, 'utf8'));
				const existingRel = (existingData.releases || []).find(r => r.version === version || r.tag === tag);
				if (existingRel) {
					parsed.implementations = existingRel.implementationsPt || [];
					parsed.improvements = existingRel.improvementsPt || [];
					parsed.fixes = existingRel.fixesPt || [];
				}
			} catch (_) {}
		}

		if (rawNotes) {
			updateDocsChangelog(path.join(DOCS_ROOT, 'CHANGELOG.md'), version, tag, channel, date, summaryPt, parsed, false);
			updateDocsChangelog(path.join(DOCS_ROOT, 'CHANGELOG.en-US.md'), version, tag, channel, date, summaryEn, parsed, true);
		}
		updateDocsReadmeBadge(path.join(DOCS_ROOT, 'README.pt-BR.md'), tag, channel, false);
		updateDocsReadmeBadge(path.join(DOCS_ROOT, 'README.md'), tag, channel, true);
		const refCount = syncDocsReference();
		console.log(`[DOCS] CHANGELOG, badges e ${refCount} arquivos de referência sincronizados para ${tag}.`);
	}

	// 2. Atualiza website/tools/releases.json, website/assets/data/releases.json, recipe.yaml e regenera HTMLs
	if (fs.existsSync(WEBSITE_ROOT)) {
		const toolsReleasesPath = path.join(WEBSITE_ROOT, 'tools', 'releases.json');
		const assetsReleasesPath = path.join(WEBSITE_ROOT, 'assets', 'data', 'releases.json');

		let relData = {
			latestVersion: version,
			latestTag: tag,
			channel,
			updatedAt: date,
			releases: []
		};

		if (fs.existsSync(toolsReleasesPath)) {
			try {
				relData = JSON.parse(fs.readFileSync(toolsReleasesPath, 'utf8'));
			} catch (_) {}
		}

		relData.latestVersion = version;
		relData.latestTag = tag;
		relData.channel = channel;
		relData.updatedAt = date;
		if (!Array.isArray(relData.releases)) relData.releases = [];

		const existingIdx = relData.releases.findIndex(r => r.version === version || r.tag === tag);
		const existingEntry = existingIdx >= 0 ? relData.releases[existingIdx] : null;

		const newReleaseObj = {
			version,
			tag,
			channel,
			date,
			resourcesCount,
			githubUrl: `https://github.com/marcelomatz/coe-framework/releases/tag/${tag}`,
			docsUrlPt: changelogDocsUrl('CHANGELOG.md', tag, date, channel),
			docsUrlEn: changelogDocsUrl('CHANGELOG.en-US.md', tag, date, channel),
			titlePt: existingEntry && !opts.title ? existingEntry.titlePt : titlePt,
			titleEn: existingEntry && !opts.title ? existingEntry.titleEn : titleEn,
			summaryPt: opts.summary ? summaryPt : (existingEntry ? existingEntry.summaryPt : summaryPt),
			summaryEn: opts.summary ? summaryEn : (existingEntry ? existingEntry.summaryEn : summaryEn),
			implementationsPt: parsed.implementations.length ? parsed.implementations : (existingEntry ? existingEntry.implementationsPt : [summaryPt]),
			implementationsEn: parsed.implementations.length ? parsed.implementations : (existingEntry ? existingEntry.implementationsEn : [summaryEn]),
			improvementsPt: parsed.improvements.length ? parsed.improvements : (existingEntry ? existingEntry.improvementsPt : ['Validação estrita de contratos HAL, locales pt-BR/en-US e telemetria 0.00ms idle.']),
			improvementsEn: parsed.improvements.length ? parsed.improvements : (existingEntry ? existingEntry.improvementsEn : ['Strict HAL contract validation, pt-BR/en-US locale parity, and 0.00ms idle telemetry.']),
			fixesPt: parsed.fixes.length ? parsed.fixes : (existingEntry ? existingEntry.fixesPt : ['Correções gerais de estabilidade e persistência MariaDB.']),
			fixesEn: parsed.fixes.length ? parsed.fixes : (existingEntry ? existingEntry.fixesEn : ['General stability and MariaDB persistence fixes.'])
		};

		if (existingIdx >= 0) {
			relData.releases[existingIdx] = newReleaseObj;
		} else {
			relData.releases.unshift(newReleaseObj);
		}

		const jsonStr = JSON.stringify(relData, null, 2) + '\n';
		fs.writeFileSync(toolsReleasesPath, jsonStr, 'utf8');
		const assetsDataDir = path.dirname(assetsReleasesPath);
		if (!fs.existsSync(assetsDataDir)) fs.mkdirSync(assetsDataDir, { recursive: true });
		fs.writeFileSync(assetsReleasesPath, jsonStr, 'utf8');

		// Sincroniza versão no website/recipe.yaml
		const webRecipePath = path.join(WEBSITE_ROOT, 'recipe.yaml');
		if (fs.existsSync(webRecipePath)) {
			let rec = fs.readFileSync(webRecipePath, 'utf8');
			rec = rec.replace(/^version:\s*"[^"]*"/m, `version: "${version}"`);
			fs.writeFileSync(webRecipePath, rec, 'utf8');
		}

		// Regenera o website bilíngue (index.html, en/index.html, scripts/*.html)
		const genScript = path.join(WEBSITE_ROOT, 'tools', 'generate_site.js');
		if (fs.existsSync(genScript)) {
			execFileSync(process.execPath, [genScript], { cwd: WEBSITE_ROOT, stdio: 'inherit' });
		}
		console.log(`[WEBSITE] releases.json, recipe.yaml e páginas HTML atualizados para ${tag}.`);
	}
}

main();
