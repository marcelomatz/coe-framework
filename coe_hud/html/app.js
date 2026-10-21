(() => {
	const LABELS = {
		accent: { theme: 'Tema', lime: 'Lima', cyan: 'Ciano', amber: 'Âmbar', rose: 'Rosa', violet: 'Violeta' },
		style: { glass: 'Vidro', flat: 'Sólido', minimal: 'Mínimo' },
		icons: { round: 'Redondo', square: 'Quadrado', hex: 'Hexágono' },
		position: { left: 'Esquerda', right: 'Direita' },
		unit: { kmh: 'km/h', mph: 'mph' },
		speedo: { panel: 'Painel', modern: 'Moderno', modernpro: 'Moderno Pro', bold: 'Bold', retro: 'Retrô', minimal: 'Mínimo', analog: 'Analógico' },
		tint: { status: 'Por status', accent: 'Cor única' },
		aspect: { full: 'Tela inteira', '16:9': '16:9', '21:9': '21:9' },
		minimapMode: { always: 'Sempre', vehicle: 'Só em veículo' },
		locationMode: { always: 'Sempre', vehicle: 'Só em veículo' }
	};
	// Escala automática: 1080p = 100%; 1440p ≈ 133%, 4K = 200%.
	const REFERENCE_HEIGHT = 1080;
	// Estado de exemplo do modo de edição: o jogador vê todos os componentes mesmo a pé.
	const DEMO = { health: 100, armor: 50, hunger: 80, thirst: 70, stress: 10, dir: 'N', street: 'Vinewood Blvd', zone: 'Vinewood', clock: '12:00' };
	const DEMO_VEHICLE = { vehicle: true, kind: 'car', speed: 88, rpm: 62, gear: 3, fuel: 70, engine: 95, lights: 1, left: false, right: false, belt: true, engineOn: true };

	const $ = (sel, root = document) => root.querySelector(sel);
	const body = document.body;
	const root = document.documentElement;
	const healthGroup = $('#hud-health');
	const vehicleGroup = $('#hud-vehicle');
	const speedoHost = $('#hud-speedo');
	const indicatorsHost = $('#hud-indicators');
	const speedo = window.CoeSpeedo.create(speedoHost);
	const indicators = window.CoeSpeedo.createIndicators(indicatorsHost);
	let speedoKey = '';
	const settings = $('#settings');
	const locationGroup = $('#hud-location');
	const logoGroup = $('#hud-logo');
	const mapFrame = $('#hud-mapframe');
	let prefs = null;
	let options = {};
	let state = null;
	let anchor = null;
	let base = null;
	let extended = false;
	let editing = false;
	let dockKey = '';

	// Elementos de cada componente posicionável (o minimapa é nativo: só a moldura e a âncora).
	const COMPONENTS = {
		status: [healthGroup],
		location: [locationGroup],
		speedo: [speedoHost, vehicleGroup],
		indicators: [indicatorsHost],
		logo: [logoGroup]
	};

	const post = (name, data) => fetch(`https://${GetParentResourceName()}/${name}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(data || {})
	}).catch(() => {});

	function setCorner(group, side) {
		group.classList.toggle('coe-persp-bl', side === 'left');
		group.classList.toggle('coe-persp-br', side === 'right');
	}

	// Área útil do HUD (fração da tela): tela inteira ou centralizada em 16:9/21:9 no ultrawide.
	function areaOf() {
		const aspect = window.innerWidth / Math.max(1, window.innerHeight);
		return window.CoeHudEditor.areaFor(prefs && prefs.aspect, aspect);
	}

	// Retângulo padrão do minimapa já dentro da área útil.
	const areaBase = () => window.CoeHudEditor.shiftBase(base, areaOf());

	function hudScale() {
		const auto = prefs.autoScale ? Math.min(3, Math.max(0.5, Math.round(window.innerHeight / REFERENCE_HEIGHT * 100) / 100)) : 1;
		return Math.round(prefs.scale * auto) / 100;
	}

	function entryOf(id) {
		const layout = (prefs && prefs.layout) || {};
		return Object.assign({ size: 100 }, layout[id]);
	}

	// Posição livre (fração da tela, canto superior esquerdo) ou padrão ancorada; tamanho por componente.
	function applyLayout() {
		const area = areaOf();
		const pct = (value) => `${Math.round(value * 1000000) / 10000}vw`;
		root.style.setProperty('--area-l', pct(area.l));
		root.style.setProperty('--area-r', pct(Math.max(0, 1 - area.l - area.w)));
		Object.keys(COMPONENTS).forEach((id) => {
			const entry = entryOf(id);
			const free = entry.x != null && entry.y != null;
			COMPONENTS[id].forEach((el) => {
				el.style.setProperty('--c-size', entry.size / 100);
				el.classList.toggle('hud-free', free);
				if (free) {
					el.style.setProperty('--fx', `${Math.round((area.l + entry.x * area.w) * 1000000) / 10000}vw`);
					el.style.setProperty('--fy', `${entry.y * 100}vh`);
				} else {
					el.style.removeProperty('--fx');
					el.style.removeProperty('--fy');
				}
			});
		});
		const map = entryOf('minimap');
		mapFrame.style.setProperty('--c-size', map.size / 100);
	}

	function applyPrefs(next) {
		prefs = next;
		const accent = prefs.accent !== 'theme';
		body.classList.toggle('no-percent', !prefs.showPercent);
		body.classList.remove('tint-status', 'tint-accent');
		// Cor escolhida pelo jogador vale para tudo; só o modo Tema deixa os status e o padrão do servidor.
		body.classList.add(accent ? 'tint-accent' : `tint-${prefs.tint}`);
		body.classList.remove('style-glass', 'style-flat', 'style-minimal', 'icons-round', 'icons-square', 'icons-hex');
		body.classList.add(`style-${prefs.style}`, `icons-${prefs.icons}`);
		body.style.setProperty('--hud-scale', hudScale());
		setCorner(healthGroup, prefs.position);
		setCorner(vehicleGroup, prefs.position === 'left' ? 'right' : 'left');
		$('#veh-unit').textContent = prefs.unit === 'mph' ? 'mph' : 'km/h';
		const key = `${prefs.speedo}|${prefs.unit}`;
		if (key !== speedoKey) {
			speedoKey = key;
			speedo.mount(prefs.speedo, prefs.unit);
		}
		applyLayout();
		applyAnchor(currentAnchor());
		render();
		syncSettings();
	}

	// No editor a âncora vem do rascunho (resposta imediata ao arrastar); fora dele, do client.
	function currentAnchor() {
		if (editing && base && prefs) {
			return window.CoeHudEditor.minimapRect(areaBase(), entryOf('minimap'), areaOf());
		}
		return anchor;
	}

	document.querySelectorAll('.gauge-shape').forEach((shape) => {
		const dim = $('svg', shape);
		const fill = dim.cloneNode(true);
		dim.classList.add('g-dim');
		fill.classList.add('g-fill');
		shape.append(fill);
	});

	function applyAnchor(rect) {
		const names = ['--mm-left', '--mm-right', '--mm-bottom', '--mm-above', '--mm-w', '--mm-h'];
		if (!rect || !prefs || !prefs.showMinimap) {
			names.forEach((name) => root.style.removeProperty(name));
			mapFrame.hidden = true;
			if (prefs && !prefs.showMinimap) {
				root.style.setProperty('--mm-left', 'calc(var(--area-l, 0vw) + 2vw)');
				root.style.setProperty('--mm-right', 'calc(var(--area-l, 0vw) + 2vw)');
			}
			return;
		}
		const vw = (value) => `${Math.round(value * 1000) / 10}vw`;
		const vh = (value) => `${Math.round(value * 1000) / 10}vh`;
		root.style.setProperty('--mm-left', vw(rect.l));
		root.style.setProperty('--mm-right', vw(rect.r + 0.006));
		root.style.setProperty('--mm-bottom', vh(1 - rect.b));
		root.style.setProperty('--mm-above', vh(1 - rect.t + 0.008));
		root.style.setProperty('--mm-w', vw(rect.r - rect.l));
		root.style.setProperty('--mm-h', vh(rect.b - rect.t));
		mapFrame.hidden = (extended && !editing) || !radarOn();
	}

	// Radar visível pelo modo (sempre / só em veículo); no editor sempre, para posicionar.
	function radarOn() {
		return editing || !prefs || prefs.minimapMode !== 'vehicle' || !!(state && state.inVehicle);
	}
	let lastInVehicle = null;

	let currentVoiceRange = 5.0;
	let currentVoiceTalking = false;
	let currentVoiceRadio = false;

	function setVoice(range, talking, radio) {
		const el = $('[data-stat="voice"]');
		if (!el) return;
		if (range != null) currentVoiceRange = range;
		if (talking !== undefined) currentVoiceTalking = talking;
		if (radio !== undefined) currentVoiceRadio = radio;

		const pct = currentVoiceRange <= 1.5 ? 0.33 : (currentVoiceRange <= 5.0 ? 0.66 : 1.0);
		el.style.setProperty('--v', pct);
		$('.gauge-val', el).textContent = `${currentVoiceRange}m`;
		el.classList.toggle('talking', !!currentVoiceTalking);
		el.classList.toggle('radio-tx', !!currentVoiceRadio);
	}

	function setStat(name, value) {
		const el = $(`[data-stat="${name}"]`);
		if (!el) return;
		el.style.setProperty('--v', value / 100);
		$('.gauge-val', el).textContent = value;
		const bad = name === 'stress' ? value >= 70 : (name === 'hunger' || name === 'thirst' || name === 'health') && value <= 25;
		el.classList.toggle('low', bad);
	}
	function setChip(name, value) {
		const el = $(`[data-chip="${name}"]`);
		$('b', el).textContent = value;
		el.classList.toggle('low', value <= 20);
	}

	const ROUTE_ARROWS = { frente: '↑', esquerda: '←', direita: '→' };
	const routeBox = $('#loc-route');
	let routeKey = '';

	function renderRoute(route) {
		const steps = Array.isArray(route) ? route : [];
		const key = steps.map((s) => `${s.name}|${s.side}|${s.dist}`).join(';');
		if (key === routeKey) {
			return;
		}
		routeKey = key;
		routeBox.hidden = steps.length === 0;
		routeBox.textContent = '';
		steps.forEach((step) => {
			const row = document.createElement('div');
			row.className = `rt rt-${step.side}`;
			const arrow = document.createElement('i');
			arrow.textContent = ROUTE_ARROWS[step.side] || '↑';
			const name = document.createElement('span');
			name.textContent = step.name;
			const dist = document.createElement('small');
			dist.textContent = `${step.dist} m`;
			row.append(arrow, name, dist);
			routeBox.append(row);
		});
	}

	// Visível, fantasma (oculto mas mostrado no editor com "Ocultos") ou escondido.
	function show(el, visible, applicable = true) {
		const ghost = !visible && applicable && editing && editor.showHidden();
		el.hidden = !(visible || ghost);
		el.classList.toggle('ed-ghost', ghost);
	}

	// Indicadores ancorados ficam logo acima do velocímetro, onde quer que ele esteja.
	function dockIndicators(force) {
		const custom = prefs.speedo !== 'panel';
		const target = custom ? speedoHost : vehicleGroup;
		const key = `${prefs.speedo}|${JSON.stringify(prefs.layout || {})}|${!target.hidden}|${JSON.stringify(currentAnchor())}|${hudScale()}|${prefs.aspect}|${prefs.position}`;
		if (!force && !editing && key === dockKey) return;
		dockKey = key;
		let x = window.innerWidth / 2;
		let y = window.innerHeight * 0.97;
		if (!target.hidden) {
			const rect = target.getBoundingClientRect();
			if (rect.width > 0) {
				x = rect.left + rect.width / 2;
				y = rect.top - 6;
			}
		}
		indicatorsHost.style.setProperty('--dock-x', `${Math.round(x)}px`);
		indicatorsHost.style.setProperty('--dock-y', `${Math.round(y)}px`);
	}
	vehicleGroup.addEventListener('transitionend', () => { if (prefs) dockIndicators(true); });

	function render() {
		if (!prefs || (!state && !editing)) return;
		const view = editing ? Object.assign({}, DEMO, state) : state;
		if (!!view.inVehicle !== lastInVehicle) {
			// Entrar/sair do veículo mostra ou esconde a moldura do minimapa no modo "só em veículo".
			lastInVehicle = !!view.inVehicle;
			applyAnchor(currentAnchor());
		}
		if (editing && !view.vehicle) Object.assign(view, DEMO_VEHICLE);
		show(healthGroup, prefs.showHealth);
		show(logoGroup, prefs.showLogo);
		const hasPlace = prefs.showLocation && view.dir !== undefined;
		show(locationGroup, hasPlace, view.dir !== undefined);
		if (view.dir !== undefined) {
			$('#loc-dir').textContent = view.dir;
			$('#loc-street').textContent = view.street || '—';
			$('#loc-zone').textContent = view.zone;
			$('#loc-clock').textContent = view.clock;
			renderRoute(prefs.showRoute ? view.route : null);
		}
		setStat('health', view.health);
		setStat('armor', view.armor);
		setVoice(view.voiceRange, view.talking, view.radioTransmitting);
		const hasNeeds = prefs.showNeeds && view.hunger !== undefined;
		document.querySelectorAll('.hud-need').forEach((el) => { el.hidden = !hasNeeds; });
		if (hasNeeds) {
			setStat('hunger', view.hunger);
			setStat('thirst', view.thirst);
			setStat('stress', view.stress);
		}

		const driving = !!view.vehicle;
		const custom = prefs.speedo !== 'panel';
		show(speedoHost, prefs.showVehicle && driving && custom, driving && custom);
		show(vehicleGroup, prefs.showVehicle && driving && !custom, driving && !custom);
		show(indicatorsHost, prefs.showIndicators && driving, driving);
		if (driving) {
			if (custom) speedo.update(view);
			indicators.update(view);
			if (!custom) renderPanel(view);
		}
		dockIndicators(false);
	}

	function renderPanel(view) {
		$('#veh-speed').textContent = view.speed;
		const rpm = $('.veh-rpm');
		$('i', rpm).style.setProperty('--v', view.rpm / 100);
		rpm.classList.toggle('hot', view.rpm >= 90);
		const gear = $('#veh-gear');
		gear.hidden = view.kind === 'boat' || view.kind === 'air';
		gear.textContent = view.gear > 0 ? view.gear : (view.speed > 0 ? 'R' : 'N');
		setChip('fuel', view.fuel);
		setChip('engine', view.engine);
	}

	// Retângulo do componente em px, para as caixas do editor.
	function rectOf(id) {
		const view = { w: window.innerWidth, h: window.innerHeight };
		if (id === 'minimap') {
			const rect = window.CoeHudEditor.minimapRect(areaBase(), entryOf('minimap'), areaOf());
			if (!rect) return null;
			return { left: rect.l * view.w, top: rect.t * view.h, width: (rect.r - rect.l) * view.w, height: (rect.b - rect.t) * view.h };
		}
		const el = COMPONENTS[id].find((item) => !item.hidden);
		if (!el) return null;
		const rect = el.getBoundingClientRect();
		return { left: rect.left, top: rect.top, width: rect.width, height: rect.height };
	}

	// Retângulo na posição padrão (zona de âncora): mede o elemento sem a posição livre.
	function defaultRectOf(id) {
		if (id === 'minimap') {
			const view = { w: window.innerWidth, h: window.innerHeight };
			const rect = window.CoeHudEditor.minimapRect(areaBase(), { size: entryOf('minimap').size }, areaOf());
			if (!rect) return null;
			return { left: rect.l * view.w, top: rect.t * view.h, width: (rect.r - rect.l) * view.w, height: (rect.b - rect.t) * view.h };
		}
		const el = COMPONENTS[id].find((item) => !item.hidden);
		if (!el) return null;
		const free = el.classList.contains('hud-free');
		el.classList.remove('hud-free');
		const rect = el.getBoundingClientRect();
		if (free) el.classList.add('hud-free');
		return { left: rect.left, top: rect.top, width: rect.width, height: rect.height };
	}

	function positionSettingsBelowBar(barRect) {
		if (!settings || settings.hidden || settings.dataset.customPos === 'true') return;
		const view = { w: window.innerWidth || 1920, h: window.innerHeight || 1080 };
		const setWidth = settings.offsetWidth || 780;
		const setHeight = settings.offsetHeight || 300;
		const centerLeft = (barRect.left + (barRect.width / 2)) - (setWidth / 2);
		const left = Math.max(10, Math.min(view.w - setWidth - 10, centerLeft));
		const top = Math.max(10, Math.min(view.h - setHeight - 10, barRect.top + barRect.height + 8));
		settings.style.transform = 'none';
		settings.style.left = `${Math.round(left)}px`;
		settings.style.top = `${Math.round(top)}px`;
	}

	function closeSettings() {
		settings.hidden = true;
		const btn = document.querySelector('[data-act="settings"]');
		if (btn) btn.classList.remove('on');
	}

	function toggleSettings() {
		settings.hidden = !settings.hidden;
		const btn = document.querySelector('[data-act="settings"]');
		if (btn) btn.classList.toggle('on', !settings.hidden);
		if (!settings.hidden && settings.dataset.customPos !== 'true') {
			const bar = document.querySelector('.ed-bar');
			if (bar) positionSettingsBelowBar(bar.getBoundingClientRect());
		}
	}

	const editor = window.CoeHudEditor.create($('#hud-editor'), {
		apply(draft) { applyPrefs(draft); },
		rectOf,
		defaultRectOf,
		post,
		openSettings() { toggleSettings(); },
		settingsOpen: () => !settings.hidden,
		area: areaOf,
		onBarMoved(barInfo) {
			if (!settings.hidden && settings.dataset.customPos !== 'true') {
				positionSettingsBelowBar(barInfo);
			}
		},
		onClose(final) {
			editing = false;
			closeSettings();
			settings.dataset.customPos = 'false';
			settings.style.removeProperty('left');
			settings.style.removeProperty('top');
			settings.style.removeProperty('transform');
			if (final) applyPrefs(final);
		}
	});

	// Preferências: dentro do editor toda mudança vai para o rascunho (desfazer, descartar).
	function save(patch) {
		if (editor.isOpen()) {
			editor.change(patch);
			return;
		}
		prefs = Object.assign({}, prefs, patch);
		applyPrefs(prefs);
		post('hudSave', prefs);
	}

	function buildSettings() {
		document.querySelectorAll('.set-field[data-key]').forEach((field) => {
			const key = field.dataset.key;
			const box = $('.set-opts', field);
			box.textContent = '';
			(options[key] || []).forEach((value) => {
				const btn = document.createElement('button');
				btn.type = 'button';
				btn.className = 'coe-button';
				btn.dataset.value = value;
				const label = (LABELS[key] && LABELS[key][value]) || value;
				const i18nKey = `hud.settings.${key}.${value}`;
				btn.setAttribute('data-i18n', i18nKey);
				btn.textContent = (window.CoeUI && window.CoeUI.t) ? window.CoeUI.t(i18nKey, null, label) : label;
				btn.addEventListener('click', () => save({ [key]: value }));
				box.appendChild(btn);
			});
		});
	}

	function syncSettings() {
		if (!prefs) return;
		document.querySelectorAll('.set-field[data-key]').forEach((field) => {
			const key = field.dataset.key;
			field.querySelectorAll('button').forEach((btn) => btn.classList.toggle('on', btn.dataset.value === prefs[key]));
		});
		$('#set-scale').value = prefs.scale;
		$('#set-scale-val').textContent = prefs.scale;
		document.querySelectorAll('[data-toggle]').forEach((input) => { input.checked = !!prefs[input.dataset.toggle]; });
	}

	$('#set-scale').addEventListener('change', (e) => save({ scale: Number(e.target.value) }));
	$('#set-scale').addEventListener('input', (e) => { $('#set-scale-val').textContent = e.target.value; });
	document.querySelectorAll('[data-toggle]').forEach((input) => {
		input.addEventListener('change', () => save({ [input.dataset.toggle]: input.checked }));
	});
	document.querySelectorAll('.set-tab').forEach((tab) => {
		tab.addEventListener('click', () => {
			const target = tab.dataset.tab;
			document.querySelectorAll('.set-tab').forEach((t) => t.classList.toggle('on', t === tab));
			document.querySelectorAll('.set-pane').forEach((p) => p.classList.toggle('on', p.dataset.pane === target));
		});
	});

	let settingsDrag = null;
	const setDragGrip = settings.querySelector('.set-drag-bar') || settings.querySelector('.set-header');

	function startSettingsDrag(e) {
		if (e.button !== 0) return;
		if (e.target.closest && e.target.closest('button, input, label')) return;
		e.preventDefault();
		e.stopPropagation();
		const rect = settings.getBoundingClientRect();
		settingsDrag = {
			x: e.clientX,
			y: e.clientY,
			left: rect.left,
			top: rect.top,
			width: rect.width,
			height: rect.height,
			moved: false
		};
		settings.classList.add('dragging');
	}

	if (setDragGrip) {
		setDragGrip.addEventListener('mousedown', startSettingsDrag);
	}

	document.addEventListener('mousemove', (e) => {
		if (!settingsDrag) return;
		const dx = e.clientX - settingsDrag.x;
		const dy = e.clientY - settingsDrag.y;
		if (!settingsDrag.moved && Math.abs(dx) < 2 && Math.abs(dy) < 2) return;
		settingsDrag.moved = true;
		settings.dataset.customPos = 'true';
		const view = { w: window.innerWidth || 1920, h: window.innerHeight || 1080 };
		const left = Math.max(10, Math.min(view.w - settingsDrag.width - 10, settingsDrag.left + dx));
		const top = Math.max(10, Math.min(view.h - settingsDrag.height - 10, settingsDrag.top + dy));
		settings.style.transform = 'none';
		settings.style.left = `${Math.round(left)}px`;
		settings.style.top = `${Math.round(top)}px`;
	});

	document.addEventListener('mouseup', () => {
		if (settingsDrag) {
			settings.classList.remove('dragging');
			settingsDrag = null;
		}
	});

	$('#set-close').addEventListener('click', () => { closeSettings(); });
	$('#set-reset').addEventListener('click', () => editor.resetAll());
	// Esc fecha primeiro as preferências; só depois o editor (descartar).
	document.addEventListener('keydown', (e) => {
		if (e.key === 'Escape' && !settings.hidden) {
			closeSettings();
			e.stopImmediatePropagation();
		}
	}, true);

	// Trocar de resolução/janela recalcula escala automática e área útil.
	window.addEventListener('resize', () => {
		if (!prefs) return;
		applyPrefs(prefs);
		editor.sync();
	});

	window.addEventListener('message', (event) => {
		const data = event.data || {};
		if (data.action === 'prefs' && data.prefs) {
			// No editor o rascunho manda; o eco da pré-visualização não sobrescreve um arraste em curso.
			if (!editor.isOpen()) applyPrefs(data.prefs);
		} else if (data.action === 'visible') {
			body.classList.toggle('hud-off', !data.visible);
		} else if (data.action === 'minimap') {
			anchor = data.anchor || null;
			base = data.base || base;
			extended = !!data.extended;
			if (base) editor.setSafezone(base.safezone);
			applyAnchor(currentAnchor());
			if (prefs) dockIndicators(true);
			editor.sync();
		} else if (data.action === 'state') {
			state = data.state;
			render();
			if (editing) editor.sync();
		} else if (data.action === 'talking') {
			setVoice(null, data.talking);
		} else if (data.action === 'mode') {
			setVoice(data.distance);
		} else if (data.action === 'radioTransmitting') {
			setVoice(null, null, data.transmitting);
		} else if (data.action === 'editor') {
			if (data.open) {
				options = data.options || options;
				buildSettings();
				editing = true;
				editor.open(data.prefs, data.defaults);
			} else if (editor.isOpen()) {
				editor.dismiss();
			}
		}
	});

	window.addEventListener('coe:localeChanged', () => {
		if (window.CoeUI && typeof window.CoeUI.translateDOM === 'function') {
			window.CoeUI.translateDOM(document);
		}
		if (editing) {
			buildSettings();
			syncSettings();
		}
	});

	if (window.CoeUI && typeof window.CoeUI.translateDOM === 'function') {
		window.CoeUI.translateDOM(document);
	}

	post('hudReady');
})();
