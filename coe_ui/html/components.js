/* Componentes interativos do framework Coe. Script clássico: expõe window.CoeUI. */
(function () {
	'use strict';

	const queue = [];
	let active = false;

	function element(tag, className, text) {
		const node = document.createElement(tag);
		if (className) node.className = className;
		if (text !== undefined) node.textContent = text;
		return node;
	}

	function present(options, resolve) {
		const previousFocus = document.activeElement;
		const overlay = element('div', 'coe-modal-overlay');
		const dialog = element('div', 'coe-modal');
		dialog.setAttribute('role', 'alertdialog');
		dialog.setAttribute('aria-modal', 'true');

		const title = element('h2', 'coe-modal__title', options.title);
		title.id = 'coe-modal-title';
		const body = element('p', 'coe-modal__body', options.message);
		body.id = 'coe-modal-body';
		dialog.setAttribute('aria-labelledby', title.id);
		dialog.setAttribute('aria-describedby', body.id);

		const cancel = element('button', 'coe-button', options.cancelLabel);
		cancel.type = 'button';
		const confirm = element('button', `coe-button ${options.danger ? 'coe-button--danger' : 'coe-button--primary'}`, options.confirmLabel);
		confirm.type = 'button';
		const actions = element('div', 'coe-modal__actions');
		actions.append(cancel, confirm);
		let guard = null;
		if (options.panic) dialog.classList.add('coe-modal--panic');
		dialog.append(title, body);
		if (options.requireText) {
			const field = element('div', 'coe-modal__guard');
			const guardText = t('ui.type_to_confirm', { text: options.requireText }, `Digite ${options.requireText} para confirmar`);
			field.append(element('label', 'coe-modal__guard-label', guardText));
			guard = element('input', 'coe-modal__guard-input');
			guard.type = 'text';
			guard.autocomplete = 'off';
			guard.spellcheck = false;
			guard.setAttribute('aria-label', guardText);
			confirm.disabled = true;
			guard.addEventListener('input', () => { confirm.disabled = guard.value.trim() !== options.requireText; });
			field.append(guard);
			dialog.append(field);
		}
		dialog.append(actions);
		overlay.append(dialog);

		let finished = false;
		function finish(result) {
			if (finished) return;
			finished = true;
			document.removeEventListener('keydown', onKeydown, true);
			overlay.remove();
			if (previousFocus instanceof HTMLElement) previousFocus.focus();
			resolve(result);
		}

		// Captura: Esc/Tab/Enter pertencem ao diálogo e não chegam aos atalhos da página.
		function onKeydown(event) {
			if (event.key === 'Escape') {
				event.preventDefault();
				event.stopImmediatePropagation();
				finish(false);
			} else if (event.key === 'Tab') {
				event.preventDefault();
				event.stopImmediatePropagation();
				const cycle = [guard, cancel, confirm].filter((node) => node && !node.disabled);
				const index = cycle.indexOf(document.activeElement);
				cycle[(index + (event.shiftKey ? cycle.length - 1 : 1)) % cycle.length].focus();
			} else if (event.key === 'Enter' && document.activeElement !== cancel) {
				event.preventDefault();
				event.stopImmediatePropagation();
				if (!confirm.disabled) finish(true);
			}
		}

		cancel.addEventListener('click', () => finish(false));
		confirm.addEventListener('click', () => { if (!confirm.disabled) finish(true); });
		overlay.addEventListener('mousedown', (event) => {
			if (event.target === overlay) finish(false);
		});
		document.addEventListener('keydown', onKeydown, true);
		document.body.append(overlay);
		// Ação destrutiva abre com foco no Cancelar para evitar confirmação acidental.
		(guard || (options.danger ? cancel : confirm)).focus();
	}

	function next() {
		if (active || queue.length === 0) return;
		active = true;
		const { options, resolve } = queue.shift();
		present(options, (result) => {
			active = false;
			resolve(result);
			next();
		});
	}

	const DEFAULT_LOCALES = {
		'pt-BR': {
			'ui.confirm': 'Confirmar',
			'ui.cancel': 'Cancelar',
			'ui.modal_title': 'Confirmar ação',
			'ui.type_to_confirm': 'Digite %{text} para confirmar',
			'ui.close': 'Fechar',
			'ui.preferences': 'Preferências',
			'ui.undo': 'Desfazer',
			'ui.redo': 'Refazer',
			'ui.reset': 'Restaurar padrão',
			'ui.discard': 'Descartar',
			'ui.done': 'Concluir',
			// HUD
			'hud.editor.title': 'Editar HUD',
			'hud.editor.drag_bar': 'Arrastar barra de edição',
			'hud.editor.undo': 'Desfazer',
			'hud.editor.undo_title': 'Desfazer (Ctrl+Z)',
			'hud.editor.redo': 'Refazer',
			'hud.editor.redo_title': 'Refazer (Ctrl+Y)',
			'hud.editor.settings': 'Preferências',
			'hud.editor.reset': 'Restaurar padrão',
			'hud.editor.discard': 'Descartar',
			'hud.editor.discard_title': 'Esc',
			'hud.editor.done': 'Concluir',
			'hud.editor.opt_grid': 'Grade',
			'hud.editor.opt_safezone': 'Zona segura',
			'hud.editor.opt_anchors': 'Zonas de âncora',
			'hud.editor.opt_hidden': 'Ocultos',
			'hud.editor.box_status': 'Vida e necessidades',
			'hud.editor.box_location': 'Localização',
			'hud.editor.box_minimap': 'Minimapa',
			'hud.editor.box_speedo': 'Velocímetro',
			'hud.editor.box_indicators': 'Indicadores',
			'hud.editor.box_logo': 'Logotipo',
			'hud.editor.toggle_visibility': 'Mostrar/ocultar',
			'hud.editor.resize': 'Redimensionar',
			'hud.settings.title': 'PREFERÊNCIAS',
			'hud.settings.drag_bar': 'Arrastar painel de preferências',
			'hud.settings.tab_appearance': 'Aparência',
			'hud.settings.tab_vehicle': 'Veículo',
			'hud.settings.tab_radar': 'Radar & Bússola',
			'hud.settings.tab_components': 'Componentes',
			'hud.settings.close_title': 'Fechar preferências',
			'hud.settings.accent': 'Cor do Tema',
			'hud.settings.style': 'Estilo Visual',
			'hud.settings.icons': 'Formato dos Ícones',
			'hud.settings.position': 'Posição dos Ícones',
			'hud.settings.tint': 'Cores dos Ícones',
			'hud.settings.speedo': 'Modelo do Velocímetro',
			'hud.settings.unit': 'Unidade de Velocidade',
			'hud.settings.show_vehicle': 'Painel de veículo',
			'hud.settings.show_indicators': 'Indicadores do veículo',
			'hud.settings.minimap_mode': 'Modo do Minimapa',
			'hud.settings.location_mode': 'Bússola e Localização',
			'hud.settings.aspect': 'Área do HUD (Ultrawide)',
			'hud.settings.show_minimap': 'Minimapa',
			'hud.settings.show_location': 'Localização e bússola',
			'hud.settings.show_route': 'Próximas ruas no radar',
			'hud.settings.scale': 'Tamanho do HUD',
			'hud.settings.auto_scale': 'Escala automática pela resolução (1440p, 4K)',
			'hud.settings.show_health': 'Vida e colete',
			'hud.settings.show_percent': 'Mostrar porcentagem nos medidores',
			'hud.settings.show_needs': 'Fome, sede, estresse, álcool e drogas',
			'hud.settings.show_logo': 'Logotipo do servidor',
			'hud.aria.alcohol': 'Álcool',
			'hud.aria.drugs': 'Drogas',
			'hud.settings.hint': 'Arraste a barra superior ou este painel para visualizar o HUD livremente.',
			'hud.settings.reset': 'Restaurar tudo',
			// Tablet
			'tablet.power_title': 'Guardar o tablet',
			'tablet.brighter_title': 'Mais brilho',
			'tablet.dimmer_title': 'Menos brilho',
			'tablet.close_title': 'Guardar o tablet (Esc)',
			'tablet.close_aria': 'Guardar o tablet',
			'tablet.control_title': 'Central de controle',
			'tablet.control_aria': 'Central de controle',
			'tablet.home_aria': 'Início',
			'tablet.apps': 'Aplicativos',
			'tablet.opened': 'Abertos',
			'tablet.recent': 'Recentes',
			'tablet.search_placeholder': 'Buscar aplicativo',
			'tablet.back_aria': 'Início',
			'tablet.app_close_title': 'Fechar o aplicativo',
			'tablet.app_close_aria': 'Fechar o aplicativo',
			'tablet.switcher_aria': 'Aplicativos abertos',
			'tablet.opened_apps': 'Aplicativos abertos',
			'tablet.close_all': 'Fechar todos',
			'tablet.brightness': 'Brilho',
			'tablet.scale': 'Tamanho',
			'tablet.wallpaper': 'Papel de parede',
			'tablet.dock': 'Dock',
			'tablet.dock_hint': 'Clique com o botão direito num ícone para fixar ou tirar da dock.',
			'tablet.dock_aria': 'Dock',
			// Phone
			'phone.silent_title': 'Modo silencioso',
			'phone.vol_up_title': 'Aumentar volume',
			'phone.vol_down_title': 'Diminuir volume',
			'phone.signal_title': 'Sinal',
			'phone.apps_aria': 'Aplicativos',
			'phone.screens_aria': 'Telas',
			'phone.back_aria': 'Voltar',
			'phone.favorites_aria': 'Favoritos',
			'phone.home_aria': 'Início',
			'phone.power_title': 'Bloquear e guardar'
		},
		'en-US': {
			'ui.confirm': 'Confirm',
			'ui.cancel': 'Cancel',
			'ui.modal_title': 'Confirm action',
			'ui.type_to_confirm': 'Type %{text} to confirm',
			'ui.close': 'Close',
			'ui.preferences': 'Preferences',
			'ui.undo': 'Undo',
			'ui.redo': 'Redo',
			'ui.reset': 'Reset to default',
			'ui.discard': 'Discard',
			'ui.done': 'Done',
			// HUD
			'hud.editor.title': 'Edit HUD',
			'hud.editor.drag_bar': 'Drag edit bar',
			'hud.editor.undo': 'Undo',
			'hud.editor.undo_title': 'Undo (Ctrl+Z)',
			'hud.editor.redo': 'Redo',
			'hud.editor.redo_title': 'Redo (Ctrl+Y)',
			'hud.editor.settings': 'Preferences',
			'hud.editor.reset': 'Reset default',
			'hud.editor.discard': 'Discard',
			'hud.editor.discard_title': 'Esc',
			'hud.editor.done': 'Done',
			'hud.editor.opt_grid': 'Grid',
			'hud.editor.opt_safezone': 'Safe zone',
			'hud.editor.opt_anchors': 'Anchor zones',
			'hud.editor.opt_hidden': 'Hidden',
			'hud.editor.box_status': 'Health and Needs',
			'hud.editor.box_location': 'Location',
			'hud.editor.box_minimap': 'Minimap',
			'hud.editor.box_speedo': 'Speedometer',
			'hud.editor.box_indicators': 'Indicators',
			'hud.editor.box_logo': 'Logo',
			'hud.editor.toggle_visibility': 'Show/hide',
			'hud.editor.resize': 'Resize',
			'hud.settings.title': 'PREFERENCES',
			'hud.settings.drag_bar': 'Drag preferences panel',
			'hud.settings.tab_appearance': 'Appearance',
			'hud.settings.tab_vehicle': 'Vehicle',
			'hud.settings.tab_radar': 'Radar & Compass',
			'hud.settings.tab_components': 'Components',
			'hud.settings.close_title': 'Close preferences',
			'hud.settings.accent': 'Theme Color',
			'hud.settings.style': 'Visual Style',
			'hud.settings.icons': 'Icon Shape',
			'hud.settings.position': 'Icon Position',
			'hud.settings.tint': 'Icon Colors',
			'hud.settings.speedo': 'Speedometer Style',
			'hud.settings.unit': 'Speed Unit',
			'hud.settings.show_vehicle': 'Vehicle Panel',
			'hud.settings.show_indicators': 'Vehicle Indicators',
			'hud.settings.minimap_mode': 'Minimap Mode',
			'hud.settings.location_mode': 'Compass & Location',
			'hud.settings.aspect': 'HUD Area (Ultrawide)',
			'hud.settings.show_minimap': 'Minimap',
			'hud.settings.show_location': 'Location & Compass',
			'hud.settings.show_route': 'Upcoming Streets on Radar',
			'hud.settings.scale': 'HUD Size',
			'hud.settings.auto_scale': 'Auto-scale by resolution (1440p, 4K)',
			'hud.settings.show_health': 'Health & Armor',
			'hud.settings.show_percent': 'Show percentage on gauges',
			'hud.settings.show_needs': 'Hunger, thirst, stress, alcohol & drugs',
			'hud.settings.show_logo': 'Server logo',
			'hud.aria.alcohol': 'Alcohol',
			'hud.aria.drugs': 'Drugs',
			'hud.settings.hint': 'Drag the top bar or this panel to view the HUD freely.',
			'hud.settings.reset': 'Reset all',
			// Tablet
			'tablet.power_title': 'Stow tablet',
			'tablet.brighter_title': 'Increase brightness',
			'tablet.dimmer_title': 'Decrease brightness',
			'tablet.close_title': 'Stow tablet (Esc)',
			'tablet.close_aria': 'Stow tablet',
			'tablet.control_title': 'Control center',
			'tablet.control_aria': 'Control center',
			'tablet.home_aria': 'Home',
			'tablet.apps': 'Apps',
			'tablet.opened': 'Open',
			'tablet.recent': 'Recent',
			'tablet.search_placeholder': 'Search app',
			'tablet.back_aria': 'Home',
			'tablet.app_close_title': 'Close app',
			'tablet.app_close_aria': 'Close app',
			'tablet.switcher_aria': 'Open apps',
			'tablet.opened_apps': 'Open apps',
			'tablet.close_all': 'Close all',
			'tablet.brightness': 'Brightness',
			'tablet.scale': 'Scale',
			'tablet.wallpaper': 'Wallpaper',
			'tablet.dock': 'Dock',
			'tablet.dock_hint': 'Right-click an icon to pin or unpin from dock.',
			'tablet.dock_aria': 'Dock',
			// Phone
			'phone.silent_title': 'Silent mode',
			'phone.vol_up_title': 'Volume up',
			'phone.vol_down_title': 'Volume down',
			'phone.signal_title': 'Signal',
			'phone.apps_aria': 'Apps',
			'phone.screens_aria': 'Screens',
			'phone.back_aria': 'Back',
			'phone.favorites_aria': 'Favorites',
			'phone.home_aria': 'Home',
			'phone.power_title': 'Lock and stow'
		}
	};

	let activeLocale = 'pt-BR';
	let serverName = 'Coe RP';
	let customDict = {};

	function t(key, params, fallback) {
		if (typeof key !== 'string' || !key) return '';
		let template = (customDict && customDict[key])
			|| (DEFAULT_LOCALES[activeLocale] && DEFAULT_LOCALES[activeLocale][key])
			|| (DEFAULT_LOCALES['pt-BR'] && DEFAULT_LOCALES['pt-BR'][key])
			|| (typeof fallback === 'string' ? fallback : key);

		if (params && typeof params === 'object') {
			template = template.replace(/%\{([a-zA-Z0-9_]+)\}/g, (match, paramName) => {
				return params[paramName] !== undefined ? String(params[paramName]) : match;
			});
		} else if (params !== undefined) {
			template = template.replace(/%[sd]/g, String(params));
		}
		return template;
	}

	function getLocale() {
		return activeLocale;
	}

	function getServerName() {
		return serverName;
	}

	function translateDOM(root = document) {
		if (!root || typeof root.querySelectorAll !== 'function') return;

		root.querySelectorAll('[data-i18n]').forEach((el) => {
			const key = el.getAttribute('data-i18n');
			if (key) el.textContent = t(key);
		});

		root.querySelectorAll('[data-i18n-title]').forEach((el) => {
			const key = el.getAttribute('data-i18n-title');
			if (key) el.title = t(key);
		});

		root.querySelectorAll('[data-i18n-placeholder]').forEach((el) => {
			const key = el.getAttribute('data-i18n-placeholder');
			if (key) el.placeholder = t(key);
		});

		root.querySelectorAll('[data-i18n-aria-label]').forEach((el) => {
			const key = el.getAttribute('data-i18n-aria-label');
			if (key) el.setAttribute('aria-label', t(key));
		});

		root.querySelectorAll('[data-server-name]').forEach((el) => {
			el.textContent = serverName;
		});
	}

	function applyLocale(lang, dict, name) {
		if (typeof lang === 'string' && /^[a-z]{2}(-[A-Z]{2})?$/.test(lang)) {
			activeLocale = lang;
			document.documentElement.setAttribute('lang', lang);
			try { localStorage.setItem('coe_ui:locale', lang); } catch (_) {}
		}
		if (typeof name === 'string' && name.trim()) {
			serverName = name.trim();
		}
		if (dict && typeof dict === 'object') {
			customDict = Object.assign({}, customDict, dict);
		}

		translateDOM();

		try {
			window.dispatchEvent(new CustomEvent('coe:localeChanged', {
				detail: { lang: activeLocale, dict: customDict, serverName }
			}));
		} catch (_) {}
	}

	// Substitui window.confirm. Resolve true/false; pedidos simultâneos são enfileirados.
	function confirm(options = {}) {
		const normalized = {
			title: String(options.title || t('ui.modal_title', null, 'Confirmar ação')),
			message: String(options.message || ''),
			confirmLabel: String(options.confirmLabel || t('ui.confirm', null, 'Confirmar')),
			cancelLabel: String(options.cancelLabel || t('ui.cancel', null, 'Cancelar')),
			danger: options.danger === true,
			panic: options.panic === true,
			requireText: options.requireText ? String(options.requireText) : ''
		};
		return new Promise((resolve) => {
			queue.push({ options: normalized, resolve });
			next();
		});
	}

	window.CoeUI = Object.freeze({
		confirm,
		getLocale,
		getServerName,
		setAccent: applyAccent,
		setLocale: applyLocale,
		setTheme: applyTheme,
		t,
		translateDOM
	});

	// 1. Tema padrão do servidor (data-coe-theme).
	function applyTheme(name) {
		if (typeof name === 'string' && /^[a-z0-9_-]{1,24}$/.test(name)) {
			document.documentElement.setAttribute('data-coe-theme', name);
			try { localStorage.setItem('coe_ui:theme', name); } catch (_) {}
		}
	}

	// 2. Tema definido pelo usuário (data-coe-user-theme): declarado após o tema padrão na folha de estilos.
	// Se não tiver tema definido ('theme' ou inválido), remove o atributo e volta para o tema padrão.
	const ACCENTS = {
		lime: ['#c4df9b', '196, 223, 155'],
		moss: ['#c4df9b', '196, 223, 155'],
		cyan: ['#7fd6e6', '127, 214, 230'],
		ocean: ['#8db6d8', '141, 182, 216'],
		amber: ['#e6b65c', '230, 182, 92'],
		rose: ['#e69bb0', '230, 155, 176'],
		violet: ['#b9a4ee', '185, 164, 238']
	};
	function applyAccent(name) {
		const root = document.documentElement;
		const accent = ACCENTS[name];
		if (accent) {
			root.setAttribute('data-coe-user-theme', name);
			root.style.setProperty('--coe-accent', accent[0]);
			root.style.setProperty('--coe-accent-rgb', accent[1]);
			try { localStorage.setItem('coe_ui:user_theme', name); } catch (_) {}
		} else {
			root.removeAttribute('data-coe-user-theme');
			root.style.removeProperty('--coe-accent');
			root.style.removeProperty('--coe-accent-rgb');
			try { localStorage.removeItem('coe_ui:user_theme'); } catch (_) {}
		}
	}

	try {
		const cachedTheme = localStorage.getItem('coe_ui:theme');
		const cachedUserTheme = localStorage.getItem('coe_ui:user_theme');
		const cachedLocale = localStorage.getItem('coe_ui:locale');
		if (cachedTheme) applyTheme(cachedTheme);
		if (cachedUserTheme) applyAccent(cachedUserTheme);
		if (cachedLocale) applyLocale(cachedLocale);
	} catch (_) {}

	// Handshake com o theme_bridge.lua do resource. Páginas que só recebem avisos (coe_notify, prompts)
	// nunca recebem 'open': enquanto o tema não chegar, qualquer mensagem pede de novo (no máximo a cada 2 s).
	let themeReceived = false;
	let lastThemeRequest = 0;
	function requestThemeReady() {
		lastThemeRequest = Date.now();
		if (typeof GetParentResourceName === 'function') {
			fetch(`https://${GetParentResourceName()}/coe_theme_ready`, { method: 'POST', body: '{}' }).catch(() => {});
		}
	}

	window.addEventListener('message', (event) => {
		if (!event.data) return;
		if (event.data.action === 'coe:theme') {
			themeReceived = true;
			applyTheme(event.data.theme);
		}
		if (event.data.action === 'coe:accent' || event.data.action === 'coe:userTheme') {
			applyAccent(event.data.userTheme || event.data.accent);
		}
		if (event.data.action === 'coe:locale') {
			applyLocale(event.data.lang, event.data.dict, event.data.serverName);
		}
		if (event.data.action === 'open' || event.data.action === 'selectionRequired') {
			requestThemeReady();
		} else if (!themeReceived && Date.now() - lastThemeRequest > 2000) {
			requestThemeReady();
		}
	});

	requestThemeReady();
})();
