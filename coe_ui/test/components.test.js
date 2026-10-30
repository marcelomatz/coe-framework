'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { describe, it, beforeEach, afterEach } = require('node:test');
const { JSDOM } = require('jsdom');

const source = fs.readFileSync(path.join(__dirname, '..', 'html', 'components.js'), 'utf8');

let window;
let document;

beforeEach(() => {
	const dom = new JSDOM('<!doctype html><body><button id="opener">abrir</button></body>', {
		runScripts: 'outside-only',
		pretendToBeVisual: true
	});
	window = dom.window;
	document = window.document;
	window.eval(source);
});

afterEach(() => window.close());

function key(name, options = {}) {
	const event = new window.KeyboardEvent('keydown', { key: name, bubbles: true, cancelable: true, ...options });
	document.activeElement.dispatchEvent(event);
	return event;
}

const flush = () => new Promise((resolve) => setImmediate(resolve));

function buttons() {
	const [cancel, confirm] = document.querySelectorAll('.coe-modal__actions button');
	return { cancel, confirm };
}

describe('CoeUI.confirm', () => {
	it('expõe a API congelada', () => {
		assert.ok(Object.isFrozen(window.CoeUI));
		assert.deepEqual(Object.keys(window.CoeUI).sort(), [
			'confirm',
			'getLocale',
			'getServerName',
			'setAccent',
			'setLocale',
			'setTheme',
			't',
			'translateDOM'
		]);
	});

	it('abre um alertdialog acessível com título e mensagem', () => {
		window.CoeUI.confirm({ title: 'Apagar', message: 'Tem certeza?' });
		const dialog = document.querySelector('.coe-modal');
		assert.equal(dialog.getAttribute('role'), 'alertdialog');
		assert.equal(dialog.getAttribute('aria-modal'), 'true');
		assert.equal(document.getElementById(dialog.getAttribute('aria-labelledby')).textContent, 'Apagar');
		assert.equal(document.getElementById(dialog.getAttribute('aria-describedby')).textContent, 'Tem certeza?');
	});

	it('usa textos padrão quando não recebe opções', () => {
		window.CoeUI.confirm();
		const { cancel, confirm } = buttons();
		assert.equal(document.querySelector('.coe-modal__title').textContent, 'Confirmar ação');
		assert.equal(cancel.textContent, 'Cancelar');
		assert.equal(confirm.textContent, 'Confirmar');
	});

	it('resolve true ao clicar em confirmar e remove o diálogo', async () => {
		const result = window.CoeUI.confirm({ message: 'x' });
		buttons().confirm.click();
		assert.equal(await result, true);
		assert.equal(document.querySelector('.coe-modal-overlay'), null);
	});

	it('resolve false ao cancelar', async () => {
		const result = window.CoeUI.confirm({ message: 'x' });
		buttons().cancel.click();
		assert.equal(await result, false);
	});

	it('resolve false ao clicar fora (overlay) e mantém ao clicar dentro', async () => {
		const result = window.CoeUI.confirm({ message: 'x' });
		const overlay = document.querySelector('.coe-modal-overlay');
		document.querySelector('.coe-modal').dispatchEvent(new window.MouseEvent('mousedown', { bubbles: true }));
		assert.ok(document.querySelector('.coe-modal-overlay'));
		overlay.dispatchEvent(new window.MouseEvent('mousedown', { bubbles: true }));
		assert.equal(await result, false);
	});

	it('Esc cancela e não chega aos atalhos da página', async () => {
		let reached = false;
		document.addEventListener('keydown', () => { reached = true; });
		const result = window.CoeUI.confirm({ message: 'x' });
		key('Escape');
		assert.equal(await result, false);
		assert.equal(reached, false);
	});

	it('Enter confirma, exceto com o foco no Cancelar', async () => {
		const first = window.CoeUI.confirm({ message: 'x' });
		key('Enter');
		assert.equal(await first, true);

		const second = window.CoeUI.confirm({ message: 'y' });
		buttons().cancel.focus();
		key('Enter');
		assert.ok(document.querySelector('.coe-modal'), 'Enter no Cancelar não fecha o diálogo');
		buttons().cancel.click();
		assert.equal(await second, false);
	});

	it('ação danger abre com foco no Cancelar; a normal, no Confirmar', () => {
		window.CoeUI.confirm({ danger: true });
		assert.equal(document.activeElement, buttons().cancel);
		assert.ok(buttons().confirm.classList.contains('coe-button--danger'));
		buttons().cancel.click();
	});

	it('ação normal abre com foco no Confirmar', () => {
		window.CoeUI.confirm({});
		assert.equal(document.activeElement, buttons().confirm);
		assert.ok(buttons().confirm.classList.contains('coe-button--primary'));
	});

	it('Tab circula entre os botões e Shift+Tab volta', () => {
		window.CoeUI.confirm({ message: 'x' });
		const { cancel, confirm } = buttons();
		assert.equal(document.activeElement, confirm);
		key('Tab');
		assert.equal(document.activeElement, cancel);
		key('Tab');
		assert.equal(document.activeElement, confirm);
		key('Tab', { shiftKey: true });
		assert.equal(document.activeElement, cancel);
	});

	it('devolve o foco ao elemento anterior ao fechar', async () => {
		const opener = document.getElementById('opener');
		opener.focus();
		const result = window.CoeUI.confirm({});
		assert.notEqual(document.activeElement, opener);
		buttons().cancel.click();
		await result;
		assert.equal(document.activeElement, opener);
	});

	it('requireText bloqueia o confirmar até digitar o texto exato', async () => {
		const result = window.CoeUI.confirm({ requireText: 'APAGAR', danger: true });
		const input = document.querySelector('.coe-modal__guard-input');
		const { confirm } = buttons();
		assert.equal(document.activeElement, input);
		assert.equal(confirm.disabled, true);

		input.value = 'apagar';
		input.dispatchEvent(new window.Event('input'));
		assert.equal(confirm.disabled, true);
		key('Enter');
		assert.ok(document.querySelector('.coe-modal'), 'Enter com o botão desabilitado não confirma');

		input.value = '  APAGAR ';
		input.dispatchEvent(new window.Event('input'));
		assert.equal(confirm.disabled, false);
		confirm.click();
		assert.equal(await result, true);
	});

	it('Tab inclui o campo de guarda e ignora o botão desabilitado', () => {
		window.CoeUI.confirm({ requireText: 'OK' });
		const input = document.querySelector('.coe-modal__guard-input');
		const { cancel } = buttons();
		assert.equal(document.activeElement, input);
		key('Tab');
		assert.equal(document.activeElement, cancel);
		key('Tab');
		assert.equal(document.activeElement, input);
	});

	it('enfileira pedidos simultâneos e os mostra um de cada vez', async () => {
		const first = window.CoeUI.confirm({ title: 'Primeiro' });
		const second = window.CoeUI.confirm({ title: 'Segundo' });
		assert.equal(document.querySelectorAll('.coe-modal').length, 1);
		assert.equal(document.querySelector('.coe-modal__title').textContent, 'Primeiro');

		buttons().confirm.click();
		assert.equal(await first, true);
		await flush();
		assert.equal(document.querySelector('.coe-modal__title').textContent, 'Segundo');
		buttons().cancel.click();
		assert.equal(await second, false);
		assert.equal(document.querySelector('.coe-modal-overlay'), null);
	});

	it('insere título e mensagem como texto, nunca como HTML', () => {
		window.CoeUI.confirm({ title: '<img src=x onerror=1>', message: '<b>negrito</b>' });
		assert.equal(document.querySelector('.coe-modal img'), null);
		assert.equal(document.querySelector('.coe-modal b'), null);
		assert.equal(document.querySelector('.coe-modal__body').textContent, '<b>negrito</b>');
	});

	it('marca o modo panic', () => {
		window.CoeUI.confirm({ panic: true });
		assert.ok(document.querySelector('.coe-modal').classList.contains('coe-modal--panic'));
	});
});

describe('tema', () => {
	it('aplica o tema recebido por mensagem e por setTheme', () => {
		window.dispatchEvent(new window.MessageEvent('message', { data: { action: 'coe:theme', theme: 'ocean' } }));
		assert.equal(document.documentElement.getAttribute('data-coe-theme'), 'ocean');
		window.CoeUI.setTheme('rose');
		assert.equal(document.documentElement.getAttribute('data-coe-theme'), 'rose');
	});

	it('rejeita nomes inválidos de tema', () => {
		window.CoeUI.setTheme('moss');
		for (const invalid of ['', 'Ocean', 'a b', 'x'.repeat(25), '"><script>', 42, null, undefined]) {
			window.CoeUI.setTheme(invalid);
		}
		assert.equal(document.documentElement.getAttribute('data-coe-theme'), 'moss');
	});
});

describe('cor do jogador', () => {
	const value = (name) => document.documentElement.style.getPropertyValue(name);

	it('define data-coe-user-theme e --coe-accent para temas escolhidos pelo usuário', () => {
		window.CoeUI.setAccent('cyan');
		assert.equal(document.documentElement.getAttribute('data-coe-user-theme'), 'cyan');
		assert.equal(value('--coe-accent'), '#7fd6e6');
		assert.equal(value('--coe-accent-rgb'), '127, 214, 230');
	});

	it('"theme" ou valor desconhecido remove data-coe-user-theme e volta ao tema padrão', () => {
		window.CoeUI.setAccent('amber');
		window.CoeUI.setAccent('theme');
		assert.equal(document.documentElement.getAttribute('data-coe-user-theme'), null);
		assert.equal(value('--coe-accent'), '');
		window.CoeUI.setAccent('lime');
		window.CoeUI.setAccent('inexistente');
		assert.equal(document.documentElement.getAttribute('data-coe-user-theme'), null);
		assert.equal(value('--coe-accent-rgb'), '');
	});

	it('aplica o tema do usuário recebido por mensagem', () => {
		window.dispatchEvent(new window.MessageEvent('message', { data: { action: 'coe:accent', accent: 'violet' } }));
		assert.equal(document.documentElement.getAttribute('data-coe-user-theme'), 'violet');
		assert.equal(value('--coe-accent'), '#b9a4ee');
	});
});

describe('mensagens NUI', () => {
	it('ignora mensagens sem dados ou de outra ação', () => {
		window.dispatchEvent(new window.MessageEvent('message', { data: null }));
		window.dispatchEvent(new window.MessageEvent('message', { data: { action: 'outra', theme: 'ocean' } }));
		assert.equal(document.documentElement.getAttribute('data-coe-theme'), null);
	});

	it('avisa o resource dono quando GetParentResourceName existe', () => {
		const calls = [];
		const other = new JSDOM('<!doctype html><body></body>', { runScripts: 'outside-only' });
		other.window.GetParentResourceName = () => 'meu_resource';
		other.window.fetch = (url, init) => {
			calls.push([url, init.method]);
			return Promise.resolve();
		};
		other.window.eval(source);
		assert.deepEqual(calls, [['https://meu_resource/coe_theme_ready', 'POST']]);
		other.window.close();
	});

	it('páginas sem "open" pedem o tema de novo até ele chegar', () => {
		const calls = [];
		const other = new JSDOM('<!doctype html><body></body>', { runScripts: 'outside-only' });
		other.window.GetParentResourceName = () => 'coe_notify';
		other.window.fetch = (url) => {
			calls.push(url);
			return Promise.resolve();
		};
		let now = 1000000;
		other.window.Date.now = () => now;
		other.window.eval(source);
		const send = (data) => other.window.dispatchEvent(new other.window.MessageEvent('message', { data }));
		assert.equal(calls.length, 1, 'pedido inicial');
		send({ action: 'show', message: 'a' });
		assert.equal(calls.length, 1, 'não repete antes de 2 s');
		now += 2500;
		send({ action: 'show', message: 'b' });
		assert.equal(calls.length, 2, 'sem tema, pede de novo');
		send({ action: 'coe:theme', theme: 'ocean' });
		now += 5000;
		send({ action: 'show', message: 'c' });
		assert.equal(calls.length, 2, 'com o tema recebido, não pede mais');
		assert.equal(other.window.document.documentElement.getAttribute('data-coe-theme'), 'ocean');
		other.window.close();
	});
});

describe('internacionalização (i18n / l10n)', () => {
	it('traduz chaves padrão em pt-BR e suporta interpolação', () => {
		assert.equal(window.CoeUI.getLocale(), 'pt-BR');
		assert.equal(window.CoeUI.t('ui.confirm'), 'Confirmar');
		assert.equal(window.CoeUI.t('ui.cancel'), 'Cancelar');
		assert.equal(window.CoeUI.t('ui.type_to_confirm', { text: 'DELETAR' }), 'Digite DELETAR para confirmar');
	});

	it('permite alternar idioma para en-US e registrar dicionário customizado', () => {
		window.CoeUI.setLocale('en-US', {
			'custom.welcome': 'Welcome, %{user}!'
		}, 'My Server RP');

		assert.equal(window.CoeUI.getLocale(), 'en-US');
		assert.equal(window.CoeUI.getServerName(), 'My Server RP');
		assert.equal(document.documentElement.getAttribute('lang'), 'en-US');
		assert.equal(window.CoeUI.t('ui.confirm'), 'Confirm');
		assert.equal(window.CoeUI.t('custom.welcome', { user: 'John' }), 'Welcome, John!');
	});

	it('auto-traduz elementos do DOM com atributos data-i18n', () => {
		document.body.innerHTML = `
			<h1 data-i18n="ui.preferences">Preferências antigas</h1>
			<button data-i18n="ui.close" data-i18n-title="ui.close" data-i18n-aria-label="ui.close">Fechar</button>
			<input data-i18n-placeholder="ui.confirm" />
			<span data-server-name></span>
		`;

		window.CoeUI.setLocale('en-US', {}, 'Enhanced FiveM');

		assert.equal(document.querySelector('h1').textContent, 'Preferences');
		const btn = document.querySelector('button');
		assert.equal(btn.textContent, 'Close');
		assert.equal(btn.title, 'Close');
		assert.equal(btn.getAttribute('aria-label'), 'Close');
		assert.equal(document.querySelector('input').placeholder, 'Confirm');
		assert.equal(document.querySelector('[data-server-name]').textContent, 'Enhanced FiveM');
	});

	it('reage à mensagem NUI coe:locale', () => {
		window.dispatchEvent(new window.MessageEvent('message', {
			data: {
				action: 'coe:locale',
				lang: 'en-US',
				serverName: 'RP World',
				dict: { 'test.msg': 'Hello World' }
			}
		}));

		assert.equal(window.CoeUI.getLocale(), 'en-US');
		assert.equal(window.CoeUI.getServerName(), 'RP World');
		assert.equal(window.CoeUI.t('test.msg'), 'Hello World');
	});
});
