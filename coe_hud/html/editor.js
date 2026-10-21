(() => {
	// Modo de edição do HUD (/hud): arrastar, ocultar e redimensionar componentes num rascunho,
	// com desfazer/refazer. O app aplica o rascunho no HUD; o client só grava ao concluir.
	const IDS = ['status', 'location', 'minimap', 'speedo', 'indicators', 'logo'];
	const VISIBILITY = {
		status: 'showHealth',
		location: 'showLocation',
		minimap: 'showMinimap',
		speedo: 'showVehicle',
		indicators: 'showIndicators',
		logo: 'showLogo'
	};
	const LABELS = {
		status: 'Vida e necessidades',
		location: 'Localização',
		minimap: 'Minimapa',
		speedo: 'Velocímetro',
		indicators: 'Indicadores',
		logo: 'Logotipo'
	};
	const OPTIONS = { grid: 'Grade', safezone: 'Zona segura', anchors: 'Zonas de âncora', hidden: 'Ocultos' };
	const SIZE_MIN = 50;
	const SIZE_MAX = 200;
	const GRID_PX = 20;
	const HISTORY_MAX = 50;
	// Soltar com esta fração do componente sobre a zona padrão volta a ancorar.
	const ANCHOR_OVERLAP = 0.5;

	const clone = (value) => JSON.parse(JSON.stringify(value));
	const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
	const round4 = (value) => Math.round(value * 10000) / 10000;

	const t = (key, fallback) => {
		if (typeof window !== 'undefined' && window.CoeUI && typeof window.CoeUI.t === 'function') {
			return window.CoeUI.t(key, null, fallback);
		}
		return fallback;
	};

	// Pilha de estados: push descarta o "refazer"; o primeiro estado nunca sai da pilha.
	function createHistory(initial, max) {
		const limit = max || HISTORY_MAX;
		let stack = [clone(initial)];
		let index = 0;
		return {
			push(state) {
				stack = stack.slice(0, index + 1);
				stack.push(clone(state));
				if (stack.length > limit) {
					stack.shift();
				}
				index = stack.length - 1;
			},
			undo() {
				if (index === 0) return null;
				index -= 1;
				return clone(stack[index]);
			},
			redo() {
				if (index >= stack.length - 1) return null;
				index += 1;
				return clone(stack[index]);
			},
			canUndo: () => index > 0,
			canRedo: () => index < stack.length - 1
		};
	}

	const snap = (value, step) => Math.round(value / step) * step;

	const RATIOS = { '16:9': 16 / 9, '21:9': 21 / 9 };
	const FULL = { l: 0, w: 1 };

	// Mesmo cálculo de MinimapLayout.Area: área útil centralizada na proporção escolhida.
	function areaFor(mode, screenAspect) {
		const ratio = RATIOS[mode];
		if (!ratio || !(screenAspect > ratio)) return FULL;
		const w = round4(ratio / screenAspect);
		return { l: round4((1 - w) / 2), w };
	}

	// MinimapLayout.AreaBase: retângulo padrão do minimapa deslocado para dentro da área.
	function shiftBase(base, area) {
		if (!base || !area || !area.l) return base;
		return Object.assign({}, base, { l: round4(base.l + area.l), r: round4(base.r + area.l) });
	}

	// Mesmo cálculo de MinimapLayout.Rect (minimap.lua), sem o modo estendido. base já na área.
	function minimapRect(base, entry, zone) {
		if (!base) return null;
		const area = zone || FULL;
		const size = ((entry && Number(entry.size)) || 100) / 100;
		const width = (base.r - base.l) * size;
		const height = (base.b - base.t) * size;
		let left = base.l;
		let top = base.b - height;
		if (entry && entry.x != null && entry.y != null) {
			left = area.l + entry.x * area.w;
			top = entry.y;
		}
		left = clamp(left, area.l, Math.max(area.l, area.l + area.w - width));
		top = clamp(top, 0, Math.max(0, 1 - height));
		return { l: round4(left), t: round4(top), r: round4(left + width), b: round4(top + height) };
	}

	// Fração da área de a que fica dentro de b (retângulos em px: left, top, width, height).
	function overlap(a, b) {
		if (!a || !b || a.width <= 0 || a.height <= 0) return 0;
		const w = Math.min(a.left + a.width, b.left + b.width) - Math.max(a.left, b.left);
		const h = Math.min(a.top + a.height, b.top + b.height) - Math.max(a.top, b.top);
		if (w <= 0 || h <= 0) return 0;
		return (w * h) / (a.width * a.height);
	}

	function layoutOf(draft) {
		const layout = Object.assign({}, draft.layout);
		IDS.forEach((id) => { layout[id] = Object.assign({ size: 100 }, layout[id]); });
		return layout;
	}

	// O que entra no desfazer: layout, visibilidade e preferências. As opções do editor ficam de fora.
	const snapshot = (draft) => {
		const copy = clone(draft);
		delete copy.editor;
		return copy;
	};

	/**
	 * hooks: apply(draft) aplica no HUD; rectOf(id) e defaultRectOf(id) devolvem o retângulo em px
	 * (left, top, width, height) do componente na posição atual e na padrão; post(nome, dados);
	 * openSettings() abre as preferências; onClose(prefs) devolve o HUD às preferências finais;
	 * area() devolve a área útil { l, w } (x do layout é relativo a ela).
	 */
	function create(root, hooks) {
		const doc = root.ownerDocument;
		const win = doc.defaultView;
		let draft = null;
		let saved = null;
		let defaults = null;
		let history = null;
		let drag = null;
		let safezone = 1;

		root.innerHTML = '<div class="ed-grid"></div><div class="ed-safe"></div><div class="ed-area"></div><div class="ed-zones"></div><div class="ed-boxes"></div>'
			+ '<nav class="ed-bar">'
			+ '<div class="ed-drag-handle" title="' + t('hud.editor.drag_bar', 'Arrastar barra de edição') + '" data-i18n-title="hud.editor.drag_bar">'
			+ '<svg class="ed-grip-icon" width="14" height="14" viewBox="0 0 16 16" fill="currentColor">'
			+ '<circle cx="5" cy="4" r="1.5"/><circle cx="11" cy="4" r="1.5"/>'
			+ '<circle cx="5" cy="8" r="1.5"/><circle cx="11" cy="8" r="1.5"/>'
			+ '<circle cx="5" cy="12" r="1.5"/><circle cx="11" cy="12" r="1.5"/>'
			+ '</svg>'
			+ '<b class="ed-title" data-i18n="hud.editor.title">' + t('hud.editor.title', 'Editar HUD') + '</b>'
			+ '</div>'
			+ '<span class="ed-opts"></span>'
			+ '<span class="ed-actions">'
			+ '<button type="button" class="coe-button" data-act="undo" title="' + t('hud.editor.undo_title', 'Desfazer (Ctrl+Z)') + '" data-i18n-title="hud.editor.undo_title" data-i18n="hud.editor.undo">' + t('hud.editor.undo', 'Desfazer') + '</button>'
			+ '<button type="button" class="coe-button" data-act="redo" title="' + t('hud.editor.redo_title', 'Refazer (Ctrl+Y)') + '" data-i18n-title="hud.editor.redo_title" data-i18n="hud.editor.redo">' + t('hud.editor.redo', 'Refazer') + '</button>'
			+ '<button type="button" class="coe-button" data-act="settings" data-i18n="hud.editor.settings">' + t('hud.editor.settings', 'Preferências') + '</button>'
			+ '<button type="button" class="coe-button" data-act="reset" data-i18n="hud.editor.reset">' + t('hud.editor.reset', 'Restaurar padrão') + '</button>'
			+ '<button type="button" class="coe-button" data-act="discard" title="' + t('hud.editor.discard_title', 'Esc') + '" data-i18n-title="hud.editor.discard_title" data-i18n="hud.editor.discard">' + t('hud.editor.discard', 'Descartar') + '</button>'
			+ '<button type="button" class="coe-button ed-done" data-act="done" data-i18n="hud.editor.done">' + t('hud.editor.done', 'Concluir') + '</button>'
			+ '</span></nav>';
		root.hidden = true;
		const $ = (sel) => root.querySelector(sel);
		const bar = $('.ed-bar');
		let barDrag = null;

		function startBarDrag(event) {
			if (!draft || event.button !== 0) return;
			if (event.target.closest && event.target.closest('button, input, label')) return;
			event.preventDefault();
			event.stopPropagation();
			const rect = bar.getBoundingClientRect();
			barDrag = {
				x: event.clientX,
				y: event.clientY,
				left: rect.left,
				top: rect.top,
				width: rect.width,
				height: rect.height,
				moved: false
			};
			bar.classList.add('dragging');
		}

		bar.addEventListener('mousedown', (e) => {
			if (e.target.closest && (e.target.closest('.ed-drag-handle, .ed-title') || (!e.target.closest('button, input, label') && e.target === bar))) {
				startBarDrag(e);
			}
		});
		const opts = $('.ed-opts');
		Object.keys(OPTIONS).forEach((key) => {
			const label = doc.createElement('label');
			label.className = 'ed-opt';
			const input = doc.createElement('input');
			input.type = 'checkbox';
			input.dataset.opt = key;
			input.addEventListener('change', () => setOption(key, input.checked));
			const span = doc.createElement('span');
			span.setAttribute('data-i18n', `hud.editor.opt_${key}`);
			span.textContent = t(`hud.editor.opt_${key}`, OPTIONS[key]);
			label.append(input, ' ', span);
			opts.append(label);
		});
		const boxes = {};
		const zones = {};
		IDS.forEach((id) => {
			const box = doc.createElement('div');
			box.className = 'ed-box';
			box.dataset.id = id;
			const boxLabel = t(`hud.editor.box_${id}`, LABELS[id]);
			const toggleTitle = t('hud.editor.toggle_visibility', 'Mostrar/ocultar');
			const resizeTitle = t('hud.editor.resize', 'Redimensionar');
			box.innerHTML = `<span class="ed-label" data-i18n="hud.editor.box_${id}">${boxLabel}</span>`
				+ `<button type="button" class="ed-eye" title="${toggleTitle}" data-i18n-title="hud.editor.toggle_visibility"></button>`
				+ `<i class="ed-resize" title="${resizeTitle}" data-i18n-title="hud.editor.resize"></i>`;
			box.querySelector('.ed-eye').addEventListener('click', (e) => { e.stopPropagation(); toggleVisible(id); });
			box.querySelector('.ed-resize').addEventListener('mousedown', (e) => startDrag(e, id, 'resize'));
			box.addEventListener('mousedown', (e) => startDrag(e, id, 'move'));
			$('.ed-boxes').append(box);
			boxes[id] = box;
			const zone = doc.createElement('div');
			zone.className = 'ed-zone';
			zone.dataset.id = id;
			$('.ed-zones').append(zone);
			zones[id] = zone;
		});
		root.querySelectorAll('[data-act]').forEach((btn) => {
			btn.addEventListener('click', () => act(btn.dataset.act));
		});

		const isOpen = () => !!draft;
		const viewport = () => ({ w: win.innerWidth || 1, h: win.innerHeight || 1 });

		function place(el, rect) {
			if (!rect) {
				el.hidden = true;
				return;
			}
			el.hidden = false;
			el.style.left = `${Math.round(rect.left)}px`;
			el.style.top = `${Math.round(rect.top)}px`;
			el.style.width = `${Math.max(24, Math.round(rect.width))}px`;
			el.style.height = `${Math.max(24, Math.round(rect.height))}px`;
		}

		// Reposiciona caixas, zonas e o estado da barra a partir do rascunho.
		function sync() {
			if (!draft) return;
			const editor = draft.editor;
			root.classList.toggle('show-grid', !!editor.grid);
			root.classList.toggle('show-safe', !!editor.safezone);
			root.classList.toggle('show-anchors', !!editor.anchors);
			const margin = `${Math.round((1 - safezone) / 2 * 10000) / 100}%`;
			['top', 'right', 'bottom', 'left'].forEach((side) => { $('.ed-safe').style[side] = margin; });
			const area = hooks.area();
			const areaBox = $('.ed-area');
			areaBox.hidden = area.w >= 1;
			areaBox.style.left = `${round4(area.l * 100)}%`;
			areaBox.style.width = `${round4(area.w * 100)}%`;
			root.querySelectorAll('[data-opt]').forEach((input) => { input.checked = !!editor[input.dataset.opt]; });
			$('[data-act="undo"]').disabled = !history.canUndo();
			$('[data-act="redo"]').disabled = !history.canRedo();
			const layout = layoutOf(draft);
			IDS.forEach((id) => {
				const visible = !!draft[VISIBILITY[id]];
				const box = boxes[id];
				box.classList.toggle('off', !visible);
				box.classList.toggle('free', layout[id].x != null);
				box.dataset.size = layout[id].size;
				if (!visible && !editor.hidden) {
					box.hidden = true;
				} else {
					place(box, hooks.rectOf(id));
				}
				place(zones[id], editor.anchors ? hooks.defaultRectOf(id) : null);
			});
		}

		function apply() {
			hooks.apply(draft);
			sync();
		}

		// Uma alteração concluída: entra no histórico e vai para a pré-visualização do client.
		function commit() {
			history.push(snapshot(draft));
			apply();
			hooks.post('hudPreview', draft);
		}

		function restore(state) {
			if (!state) return;
			draft = Object.assign(state, { editor: draft.editor });
			apply();
			hooks.post('hudPreview', draft);
		}

		function setOption(key, value) {
			if (!draft) return;
			draft.editor = Object.assign({}, draft.editor, { [key]: !!value });
			apply();
		}

		function setEntry(id, patch) {
			const layout = layoutOf(draft);
			layout[id] = Object.assign({}, layout[id], patch);
			if (layout[id].x == null || layout[id].y == null) {
				delete layout[id].x;
				delete layout[id].y;
			}
			draft.layout = layout;
		}

		function toggleVisible(id) {
			if (!draft) return;
			draft[VISIBILITY[id]] = !draft[VISIBILITY[id]];
			commit();
		}

		function change(patch) {
			if (!draft) return;
			Object.assign(draft, clone(patch));
			commit();
		}

		// Layout e visibilidade voltam ao padrão; cor, estilo e demais preferências ficam.
		function resetLayout() {
			draft.layout = clone(defaults.layout);
			IDS.forEach((id) => { draft[VISIBILITY[id]] = defaults[VISIBILITY[id]]; });
			commit();
		}

		// Restaurar tudo (botão das preferências).
		function resetAll() {
			if (!draft) return;
			const editor = draft.editor;
			draft = Object.assign(clone(defaults), { editor });
			commit();
		}

		function close(prefs) {
			draft = null;
			drag = null;
			barDrag = null;
			bar.classList.remove('dragging');
			bar.style.removeProperty('left');
			bar.style.removeProperty('top');
			bar.style.removeProperty('transform');
			root.hidden = true;
			doc.body.classList.remove('editing');
			hooks.onClose(prefs);
		}

		function act(name) {
			if (!draft) return;
			if (name === 'undo') restore(history.undo());
			else if (name === 'redo') restore(history.redo());
			else if (name === 'reset') resetLayout();
			else if (name === 'settings') hooks.openSettings();
			else if (name === 'done') {
				const final = draft;
				hooks.post('hudDone', final);
				close(final);
			} else if (name === 'discard') {
				hooks.post('hudDiscard');
				close(saved);
			}
		}

		function startDrag(event, id, mode) {
			if (!draft || event.button !== 0) return;
			if (event.target.closest && event.target.closest('.ed-eye')) return;
			event.preventDefault();
			event.stopPropagation();
			const rect = hooks.rectOf(id);
			if (!rect) return;
			drag = { id, mode, x: event.clientX, y: event.clientY, rect, size: layoutOf(draft)[id].size, moved: false };
			boxes[id].classList.add('dragging');
		}

		function onMove(event) {
			if (barDrag) {
				const dx = event.clientX - barDrag.x;
				const dy = event.clientY - barDrag.y;
				if (!barDrag.moved && Math.abs(dx) < 2 && Math.abs(dy) < 2) return;
				barDrag.moved = true;
				const view = viewport();
				const left = clamp(barDrag.left + dx, 10, Math.max(10, view.w - barDrag.width - 10));
				const top = clamp(barDrag.top + dy, 10, Math.max(10, view.h - barDrag.height - 10));
				bar.style.transform = 'none';
				bar.style.left = `${Math.round(left)}px`;
				bar.style.top = `${Math.round(top)}px`;
				if (hooks.onBarMoved) {
					hooks.onBarMoved({ left, top, width: barDrag.width, height: barDrag.height });
				}
				return;
			}
			if (!drag) return;
			const dx = event.clientX - drag.x;
			const dy = event.clientY - drag.y;
			if (!drag.moved && Math.abs(dx) < 2 && Math.abs(dy) < 2) return;
			drag.moved = true;
			const view = viewport();
			const { rect } = drag;
			if (drag.mode === 'resize') {
				const ratio = Math.max(0.1, (rect.width + dx) / Math.max(1, rect.width));
				let size = drag.size * ratio;
				if (draft.editor.grid) size = snap(size, 5);
				setEntry(drag.id, { size: Math.round(clamp(size, SIZE_MIN, SIZE_MAX)) });
			} else {
				let left = rect.left + dx;
				let top = rect.top + dy;
				if (draft.editor.grid) {
					left = snap(left, GRID_PX);
					top = snap(top, GRID_PX);
				}
				// A área útil (16:9/21:9) limita o arraste; x fica relativo a ela.
				const area = hooks.area();
				const areaLeft = area.l * view.w;
				const areaWidth = area.w * view.w;
				left = clamp(left, areaLeft, Math.max(areaLeft, areaLeft + areaWidth - rect.width));
				top = clamp(top, 0, Math.max(0, view.h - rect.height));
				setEntry(drag.id, { x: round4((left - areaLeft) / areaWidth), y: round4(top / view.h) });
			}
			apply();
		}

		function onUp() {
			if (barDrag) {
				bar.classList.remove('dragging');
				barDrag = null;
				return;
			}
			if (!drag) return;
			const { id, moved, mode } = drag;
			boxes[id].classList.remove('dragging');
			drag = null;
			if (!moved) return;
			if (mode === 'move' && draft.editor.anchors && overlap(hooks.rectOf(id), hooks.defaultRectOf(id)) >= ANCHOR_OVERLAP) {
				setEntry(id, { x: null, y: null });
			}
			commit();
		}

		doc.addEventListener('mousemove', onMove);
		doc.addEventListener('mouseup', onUp);
		doc.addEventListener('keydown', (event) => {
			if (!draft) return;
			const key = event.key.toLowerCase();
			if (event.ctrlKey && key === 'z' && !event.shiftKey) act('undo');
			else if (event.ctrlKey && (key === 'y' || (key === 'z' && event.shiftKey))) act('redo');
			else if (key === 'escape' && !hooks.settingsOpen()) act('discard');
		});

		function open(prefs, defaultPrefs) {
			saved = clone(prefs);
			defaults = clone(defaultPrefs);
			draft = clone(prefs);
			draft.layout = layoutOf(draft);
			draft.editor = Object.assign({ grid: true, safezone: false, anchors: true, hidden: true }, draft.editor);
			history = createHistory(snapshot(draft));
			root.hidden = false;
			doc.body.classList.add('editing');
			apply();
		}

		function setSafezone(value) {
			safezone = Number(value) > 0 ? Number(value) : 1;
			sync();
		}

		// Fechado pelo client (/hud de novo): o client já descartou, só volta às preferências salvas.
		function dismiss() {
			if (draft) close(saved);
		}

		return {
			open,
			dismiss,
			change,
			resetAll,
			sync,
			setSafezone,
			isOpen,
			act,
			draft: () => draft,
			showHidden: () => !!(draft && draft.editor.hidden)
		};
	}

	const api = { IDS, VISIBILITY, createHistory, areaFor, shiftBase, minimapRect, overlap, snap, create };
	if (typeof module !== 'undefined' && module.exports) {
		module.exports = api;
	}
	if (typeof window !== 'undefined') {
		window.CoeHudEditor = api;
	}
})();
