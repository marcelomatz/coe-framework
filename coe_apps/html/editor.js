// Estúdio: editor de fotos da Galeria do smartphone (app pago da loja). Tudo é desenhado no canvas do próprio
// aparelho; o resultado é salvo como uma cópia nova na Galeria (a original não muda).
(function () {
	'use strict';

	const host = window.CoePhone || window.CoeTablet;
	if (!host) { return; }

	if (!document.querySelector('link[data-coe-editor]')) {
		const link = document.createElement('link');
		link.rel = 'stylesheet';
		link.href = 'nui://coe_apps/html/editor.css';
		link.dataset.coeEditor = '1';
		document.head.appendChild(link);
	}

	const MAX_SIDE = 1280;
	const PREVIEW_SIDE = 560;
	const TEXT_MAX = 40;

	// css: filtro do canvas; warmth, fade e vignette somam aos ajustes do jogador.
	const FILTERS = [
		{ id: 'original', label: 'Original', css: '' },
		{ id: 'vivido', label: 'Vívido', css: 'saturate(1.45) contrast(1.08)' },
		{ id: 'quente', label: 'Quente', css: 'saturate(1.1)', warmth: 35 },
		{ id: 'frio', label: 'Frio', css: 'saturate(0.95)', warmth: -35 },
		{ id: 'pb', label: 'P&B', css: 'grayscale(1)' },
		{ id: 'noir', label: 'Noir', css: 'grayscale(1) contrast(1.55) brightness(0.9)', vignette: 35 },
		{ id: 'sepia', label: 'Sépia', css: 'sepia(0.8)' },
		{ id: 'vintage', label: 'Vintage', css: 'sepia(0.35) saturate(1.15) contrast(0.92)', fade: 30, vignette: 25 },
		{ id: 'drama', label: 'Drama', css: 'contrast(1.4) saturate(0.85) brightness(0.95)', vignette: 30 },
		{ id: 'desbotado', label: 'Desbotado', css: 'saturate(0.65) contrast(0.88) brightness(1.06)', fade: 25 },
		{ id: 'neon', label: 'Neon', css: 'saturate(1.7) hue-rotate(-14deg) contrast(1.12)' }
	];

	const ADJUSTMENTS = [
		{ id: 'brightness', label: 'Brilho', min: -100, max: 100 },
		{ id: 'contrast', label: 'Contraste', min: -100, max: 100 },
		{ id: 'saturation', label: 'Saturação', min: -100, max: 100 },
		{ id: 'warmth', label: 'Temperatura', min: -100, max: 100 },
		{ id: 'fade', label: 'Desbotar', min: 0, max: 100 },
		{ id: 'vignette', label: 'Vinheta', min: 0, max: 100 },
		{ id: 'sharpen', label: 'Nitidez', min: 0, max: 100 },
		{ id: 'blur', label: 'Desfoque', min: 0, max: 100 }
	];

	const RATIOS = [
		{ id: 'original', label: 'Livre', value: null },
		{ id: '1:1', label: '1:1', value: 1 },
		{ id: '4:5', label: '4:5', value: 4 / 5 },
		{ id: '3:4', label: '3:4', value: 3 / 4 },
		{ id: '16:9', label: '16:9', value: 16 / 9 },
		{ id: '9:16', label: '9:16', value: 9 / 16 }
	];

	const FRAMES = [
		{ id: 'none', label: 'Nenhuma' },
		{ id: 'white', label: 'Branca' },
		{ id: 'black', label: 'Preta' },
		{ id: 'polaroid', label: 'Polaroid' },
		{ id: 'cinema', label: 'Cinema' }
	];

	const TEXT_POSITIONS = [{ id: 'top', label: 'Topo' }, { id: 'middle', label: 'Centro' }, { id: 'bottom', label: 'Base' }];
	const TEXT_COLORS = [{ id: '#ffffff', label: 'Branco' }, { id: '#111111', label: 'Preto' }, { id: '#f5c542', label: 'Amarelo' }, { id: '#ff5a6e', label: 'Rosa' }];
	const TEXT_SIZES = [{ id: 0.05, label: 'P' }, { id: 0.075, label: 'M' }, { id: 0.105, label: 'G' }];

	function fresh() {
		return {
			filter: 'original', brightness: 0, contrast: 0, saturation: 0, warmth: 0, fade: 0, vignette: 0, sharpen: 0, blur: 0,
			rotate: 0, flip: false, crop: 'original', scale: 100,
			text: '', textPosition: 'bottom', textColor: '#ffffff', textSize: 0.075, frame: 'none'
		};
	}

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined && text !== null) { node.textContent = String(text); }
		return node;
	}

	function button(label, className, onClick) {
		const node = el('button', 'coe-button ' + (className || ''), label);
		node.type = 'button';
		node.addEventListener('click', function (event) { event.stopPropagation(); onClick(event); });
		return node;
	}

	function filterOf(id) {
		return FILTERS.find(function (filter) { return filter.id === id; }) || FILTERS[0];
	}

	function clamp(value, min, max) { return Math.max(min, Math.min(max, value)); }

	function loadImage(src) {
		return new Promise(function (resolve, reject) {
			const img = new Image();
			img.onload = function () { resolve(img); };
			img.onerror = reject;
			img.src = src;
		});
	}

	function scaled(source, maxSide) {
		const k = Math.min(1, maxSide / Math.max(source.width, source.height));
		const canvas = document.createElement('canvas');
		canvas.width = Math.max(1, Math.round(source.width * k));
		canvas.height = Math.max(1, Math.round(source.height * k));
		canvas.getContext('2d').drawImage(source, 0, 0, canvas.width, canvas.height);
		return canvas;
	}

	// Tamanho final (em px) da foto editada, a partir do tamanho original.
	function geometry(width, height, s) {
		const turned = s.rotate % 2 === 1;
		const ow = turned ? height : width;
		const oh = turned ? width : height;
		const ratio = (RATIOS.find(function (r) { return r.id === s.crop; }) || RATIOS[0]).value;
		let cw = ow;
		let ch = oh;
		if (ratio) {
			if (ow / oh > ratio) { cw = oh * ratio; } else { ch = ow / ratio; }
		}
		let fw = cw * s.scale / 100;
		let fh = ch * s.scale / 100;
		const k = Math.min(1, MAX_SIDE / Math.max(fw, fh));
		fw = Math.max(1, Math.round(fw * k));
		fh = Math.max(1, Math.round(fh * k));
		return { cropWidth: cw, width: fw, height: fh };
	}

	function sharpen(ctx, w, h, amount) {
		const image = ctx.getImageData(0, 0, w, h);
		const src = image.data;
		const out = new Uint8ClampedArray(src);
		const center = 1 + 4 * amount;
		for (let y = 1; y < h - 1; y++) {
			for (let x = 1; x < w - 1; x++) {
				const i = (y * w + x) * 4;
				for (let c = 0; c < 3; c++) {
					out[i + c] = center * src[i + c] - amount * (src[i + c - 4] + src[i + c + 4] + src[i + c - w * 4] + src[i + c + w * 4]);
				}
			}
		}
		image.data.set(out);
		ctx.putImageData(image, 0, 0);
	}

	// Desenha a foto editada. source: imagem (pode ser uma cópia reduzida); full: tamanho original;
	// factor: fração do tamanho final (prévia < 1).
	function render(source, full, s, factor) {
		const geo = geometry(full.width, full.height, s);
		const w = Math.max(1, Math.round(geo.width * factor));
		const h = Math.max(1, Math.round(geo.height * factor));
		const preset = filterOf(s.filter);
		const canvas = document.createElement('canvas');
		canvas.width = w;
		canvas.height = h;
		const ctx = canvas.getContext('2d');
		ctx.fillStyle = '#000';
		ctx.fillRect(0, 0, w, h);

		const blur = s.blur / 100 * 10 * (w / 1000);
		ctx.filter = [
			preset.css,
			'brightness(' + (1 + s.brightness / 200) + ')',
			'contrast(' + (1 + s.contrast / 150) + ')',
			'saturate(' + (1 + s.saturation / 100) + ')',
			blur > 0.05 ? 'blur(' + blur.toFixed(2) + 'px)' : ''
		].join(' ').trim() || 'none';
		const sourceScale = source.width / full.width;
		const k = w / (geo.cropWidth * sourceScale);
		ctx.save();
		ctx.translate(w / 2, h / 2);
		ctx.scale(k, k);
		ctx.rotate(s.rotate * Math.PI / 2);
		if (s.flip) { ctx.scale(-1, 1); }
		ctx.drawImage(source, -source.width / 2, -source.height / 2, source.width, source.height);
		ctx.restore();
		ctx.filter = 'none';

		const warmth = clamp(s.warmth + (preset.warmth || 0), -100, 100);
		if (warmth !== 0) {
			ctx.globalCompositeOperation = 'soft-light';
			ctx.fillStyle = warmth > 0 ? 'rgba(255, 138, 40, ' + (warmth / 100 * 0.6) + ')' : 'rgba(40, 120, 255, ' + (-warmth / 100 * 0.6) + ')';
			ctx.fillRect(0, 0, w, h);
		}
		const fade = clamp(s.fade + (preset.fade || 0), 0, 100);
		if (fade > 0) {
			const v = Math.round(fade / 100 * 80);
			ctx.globalCompositeOperation = 'lighten';
			ctx.fillStyle = 'rgb(' + v + ',' + v + ',' + v + ')';
			ctx.fillRect(0, 0, w, h);
		}
		ctx.globalCompositeOperation = 'source-over';
		if (s.sharpen > 0) { sharpen(ctx, w, h, s.sharpen / 100 * 0.8); }
		const vignette = clamp(s.vignette + (preset.vignette || 0), 0, 100);
		if (vignette > 0) {
			const radius = Math.sqrt(w * w + h * h) / 2;
			const gradient = ctx.createRadialGradient(w / 2, h / 2, radius * 0.35, w / 2, h / 2, radius);
			gradient.addColorStop(0, 'rgba(0,0,0,0)');
			gradient.addColorStop(1, 'rgba(0,0,0,' + (vignette / 100 * 0.85) + ')');
			ctx.fillStyle = gradient;
			ctx.fillRect(0, 0, w, h);
		}
		if (s.frame === 'cinema') {
			const bar = Math.round(h * 0.1);
			ctx.fillStyle = '#000';
			ctx.fillRect(0, 0, w, bar);
			ctx.fillRect(0, h - bar, w, bar);
		}
		const text = String(s.text || '').trim();
		if (text) {
			let size = Math.max(8, Math.round(Math.min(w, h * 1.4) * s.textSize));
			ctx.font = '700 ' + size + 'px "Rajdhani", "Segoe UI", sans-serif';
			while (ctx.measureText(text).width > w * 0.9 && size > 8) {
				size -= 1;
				ctx.font = '700 ' + size + 'px "Rajdhani", "Segoe UI", sans-serif';
			}
			const margin = s.frame === 'cinema' ? h * 0.1 + size * 0.4 : size * 0.8;
			const y = s.textPosition === 'top' ? margin + size / 2 : (s.textPosition === 'middle' ? h / 2 : h - margin - size / 2);
			ctx.textAlign = 'center';
			ctx.textBaseline = 'middle';
			ctx.shadowColor = s.textColor === '#111111' ? 'rgba(255,255,255,0.6)' : 'rgba(0,0,0,0.65)';
			ctx.shadowBlur = size * 0.25;
			ctx.fillStyle = s.textColor;
			ctx.fillText(text, w / 2, y);
			ctx.shadowBlur = 0;
		}
		if (s.frame === 'white' || s.frame === 'black' || s.frame === 'polaroid') {
			const pad = Math.round(Math.min(w, h) * (s.frame === 'polaroid' ? 0.05 : 0.04));
			const bottom = s.frame === 'polaroid' ? Math.round(Math.min(w, h) * 0.2) : pad;
			const framed = document.createElement('canvas');
			framed.width = w + pad * 2;
			framed.height = h + pad + bottom;
			const fctx = framed.getContext('2d');
			fctx.fillStyle = s.frame === 'black' ? '#0c0d0e' : (s.frame === 'polaroid' ? '#f4f1ea' : '#ffffff');
			fctx.fillRect(0, 0, framed.width, framed.height);
			fctx.drawImage(canvas, pad, pad);
			return framed;
		}
		return canvas;
	}

	// JPEG de até maxBytes: baixa a qualidade e, se preciso, o tamanho.
	function encode(canvas, maxBytes, quality) {
		let current = canvas;
		for (let attempt = 0; attempt < 8; attempt++) {
			let q = quality;
			let out = current.toDataURL('image/jpeg', q);
			while (out.length > maxBytes && q > 0.35) {
				q -= 0.1;
				out = current.toDataURL('image/jpeg', q);
			}
			if (out.length <= maxBytes) { return out; }
			current = scaled(current, Math.max(current.width, current.height) * 0.8);
		}
		return null;
	}

	host.register('editor', function (root, api, args) {
		const page = el('div', 'ed-page');
		root.appendChild(page);
		let info = null;

		if (api.device !== 'phone') {
			page.appendChild(el('p', 'tb-empty', 'O Estúdio edita as fotos da Galeria do smartphone.'));
			return;
		}

		function fail(result) { api.status(api.errorText(result && result.error), 'error'); }

		function ensureInfo() {
			if (info) { return Promise.resolve(info); }
			return api.call('camera', 'info').then(function (result) {
				if (!result || !result.ok) { fail(result); return null; }
				info = result.data;
				return info;
			});
		}

		// Escolher foto -------------------------------------------------------------------------------

		function picker() {
			let photos = [];
			let more = false;
			const grid = el('div', 'ed-grid');
			const moreButton = button('Carregar mais', 'ed-more', function () { load(); });
			page.replaceChildren(el('p', 'ed-lead', 'Escolha uma foto da Galeria para editar.'), grid, moreButton);
			moreButton.style.display = 'none';

			function load() {
				const payload = photos.length ? { before: photos[photos.length - 1].id } : {};
				return api.call('gallery', 'list', payload).then(function (result) {
					if (!result || !result.ok) { fail(result); return; }
					const list = result.data.photos || [];
					photos = photos.concat(list);
					more = result.data.more === true;
					list.forEach(function (photo) {
						const cell = el('button', 'ed-thumb');
						cell.type = 'button';
						const img = el('img');
						img.src = photo.thumb;
						img.alt = 'Foto';
						cell.appendChild(img);
						cell.addEventListener('click', function () { open(photo.id); });
						grid.appendChild(cell);
					});
					moreButton.style.display = more ? '' : 'none';
					if (!photos.length) {
						const blank = el('div', 'ed-blank');
						blank.append(el('strong', null, 'Nenhuma foto na Galeria'), el('small', null, 'Tire uma foto com a Câmera para começar.'));
						blank.appendChild(button('Abrir a Câmera', 'coe-button--primary', function () { api.openApp('camera'); }));
						grid.replaceWith(blank);
					}
				});
			}
			load();
		}

		function open(id) {
			page.replaceChildren(el('p', 'tb-empty', 'Abrindo a foto…'));
			Promise.all([ensureInfo(), api.call('gallery', 'photo', { id: id })]).then(function (results) {
				const result = results[1];
				if (!results[0]) { return; }
				if (!result || !result.ok) { fail(result); picker(); return; }
				return loadImage(result.data.image).then(editor);
			}).catch(function () { fail({ error: 'invalid_photo' }); picker(); });
		}

		// Editor ---------------------------------------------------------------------------------------

		function editor(img) {
			const full = { width: img.width, height: img.height };
			const preview = scaled(img, PREVIEW_SIDE);
			const tiny = scaled(img, 120);
			let state = fresh();
			let tab = 'filters';
			let comparing = false;
			let queued = false;

			const stage = el('div', 'ed-stage');
			const canvas = el('canvas', 'ed-canvas');
			stage.appendChild(canvas);
			const size = el('span', 'ed-size');
			const compare = el('button', 'ed-compare', 'Antes');
			compare.type = 'button';
			compare.title = 'Segure para ver a original';
			stage.append(size, compare);
			const tabs = el('div', 'tb-tabs ed-tabs');
			const panel = el('div', 'ed-panel');
			const actions = el('div', 'ed-actions');
			page.replaceChildren(stage, tabs, panel, actions);

			function paint() {
				queued = false;
				const geo = geometry(full.width, full.height, state);
				const factor = Math.min(1, PREVIEW_SIDE / Math.max(geo.width, geo.height));
				const out = comparing ? scaled(img, PREVIEW_SIDE) : render(preview, full, state, factor);
				canvas.width = out.width;
				canvas.height = out.height;
				canvas.getContext('2d').drawImage(out, 0, 0);
				const framed = state.frame === 'white' || state.frame === 'black' || state.frame === 'polaroid';
				size.textContent = geo.width + ' × ' + geo.height + ' px' + (framed ? ' + moldura' : '');
			}

			function update(patch) {
				Object.assign(state, patch);
				if (!queued) {
					queued = true;
					requestAnimationFrame(paint);
				}
			}

			['mousedown', 'touchstart'].forEach(function (name) {
				compare.addEventListener(name, function () { comparing = true; paint(); });
			});
			['mouseup', 'mouseleave', 'touchend'].forEach(function (name) {
				compare.addEventListener(name, function () { if (comparing) { comparing = false; paint(); } });
			});

			function chips(list, key, onPick) {
				const box = el('div', 'ed-chips');
				list.forEach(function (item) {
					const chip = el('button', 'ed-chip' + (state[key] === item.id ? ' is-active' : ''), item.label);
					chip.type = 'button';
					chip.addEventListener('click', function () {
						box.querySelectorAll('.ed-chip').forEach(function (node) { node.classList.remove('is-active'); });
						chip.classList.add('is-active');
						const patch = {};
						patch[key] = item.id;
						update(patch);
						if (onPick) { onPick(item); }
					});
					box.appendChild(chip);
				});
				return box;
			}

			function slider(label, key, min, max, format) {
				const row = el('label', 'ed-slider');
				const head = el('span', 'ed-slider-head');
				const value = el('em');
				head.append(el('span', null, label), value);
				const range = el('input', 'ed-range');
				range.type = 'range';
				range.min = String(min);
				range.max = String(max);
				range.value = String(state[key]);
				const sync = function () {
					const v = Number(range.value);
					value.textContent = format ? format(v) : (v > 0 && min < 0 ? '+' + v : String(v));
					range.style.setProperty('--fill', ((v - min) / (max - min) * 100) + '%');
				};
				range.addEventListener('input', function () {
					sync();
					const patch = {};
					patch[key] = Number(range.value);
					update(patch);
				});
				range.addEventListener('dblclick', function () {
					range.value = String(key === 'scale' ? 100 : 0);
					range.dispatchEvent(new Event('input'));
				});
				sync();
				row.append(head, range);
				return row;
			}

			const TABS = {
				filters: { label: 'Filtros', paint: function () {
					const strip = el('div', 'ed-filters');
					FILTERS.forEach(function (filter) {
						const item = el('button', 'ed-filter' + (state.filter === filter.id ? ' is-active' : ''));
						item.type = 'button';
						const thumb = render(tiny, full, Object.assign(fresh(), { filter: filter.id }), Math.min(1, 120 / Math.max(full.width, full.height)));
						thumb.className = 'ed-filter-thumb';
						item.append(thumb, el('span', null, filter.label));
						item.addEventListener('click', function () {
							strip.querySelectorAll('.ed-filter').forEach(function (node) { node.classList.remove('is-active'); });
							item.classList.add('is-active');
							update({ filter: filter.id });
						});
						strip.appendChild(item);
					});
					panel.appendChild(strip);
				} },
				adjust: { label: 'Ajustes', paint: function () {
					ADJUSTMENTS.forEach(function (adj) { panel.appendChild(slider(adj.label, adj.id, adj.min, adj.max)); });
					panel.appendChild(el('small', 'ed-tip', 'Duplo clique no controle volta ao zero.'));
				} },
				crop: { label: 'Corte', paint: function () {
					panel.appendChild(el('span', 'ed-label', 'Proporção'));
					panel.appendChild(chips(RATIOS, 'crop'));
					panel.appendChild(el('span', 'ed-label', 'Orientação'));
					const row = el('div', 'ed-chips');
					row.append(
						button('↺ Girar', 'ed-chip', function () { update({ rotate: (state.rotate + 3) % 4 }); }),
						button('↻ Girar', 'ed-chip', function () { update({ rotate: (state.rotate + 1) % 4 }); }),
						button('⇋ Espelhar', 'ed-chip', function () { update({ flip: !state.flip }); })
					);
					panel.appendChild(row);
				} },
				resize: { label: 'Tamanho', paint: function () {
					const range = slider('Escala', 'scale', 10, 100, function (v) { return v + '%'; });
					panel.appendChild(range);
					const presets = el('div', 'ed-chips');
					[25, 50, 75, 100].forEach(function (value) {
						presets.appendChild(button(value + '%', 'ed-chip', function () {
							const input = range.querySelector('input');
							input.value = String(value);
							input.dispatchEvent(new Event('input'));
						}));
					});
					panel.appendChild(presets);
					panel.appendChild(el('small', 'ed-tip', 'Fotos menores ocupam menos espaço no aparelho. O lado maior fica limitado a ' + MAX_SIDE + ' px.'));
				} },
				text: { label: 'Texto', paint: function () {
					const field = el('input', 'coe-field');
					field.type = 'text';
					field.maxLength = TEXT_MAX;
					field.placeholder = 'Escreva uma legenda';
					field.value = state.text;
					field.addEventListener('input', function () { update({ text: field.value.slice(0, TEXT_MAX) }); });
					panel.appendChild(field);
					panel.appendChild(el('span', 'ed-label', 'Posição'));
					panel.appendChild(chips(TEXT_POSITIONS, 'textPosition'));
					panel.appendChild(el('span', 'ed-label', 'Cor'));
					panel.appendChild(chips(TEXT_COLORS, 'textColor'));
					panel.appendChild(el('span', 'ed-label', 'Tamanho'));
					panel.appendChild(chips(TEXT_SIZES, 'textSize'));
				} },
				frame: { label: 'Moldura', paint: function () {
					panel.appendChild(chips(FRAMES, 'frame'));
				} }
			};

			function showTab(id) {
				tab = id;
				tabs.querySelectorAll('.tb-tab').forEach(function (node) { node.classList.toggle('is-active', node.dataset.tab === id); });
				panel.replaceChildren();
				TABS[id].paint();
			}

			Object.keys(TABS).forEach(function (id) {
				const node = el('button', 'tb-tab', TABS[id].label);
				node.type = 'button';
				node.dataset.tab = id;
				node.addEventListener('click', function () { showTab(id); });
				tabs.appendChild(node);
			});

			let saving = false;
			const save = button('Salvar cópia', 'coe-button--primary', function () {
				if (saving) { return; }
				saving = true;
				save.disabled = true;
				api.status('Gerando a foto…');
				setTimeout(function () {
					const out = render(img, full, state, 1);
					const image = encode(out, info.maxBytes, 0.86);
					const thumb = encode(scaled(out, info.thumbWidth), info.thumbMaxBytes, 0.6);
					if (!image || !thumb) {
						saving = false;
						save.disabled = false;
						fail({ error: 'invalid_photo' });
						return;
					}
					api.status('Salvando…');
					api.savePhoto(image, thumb).then(function (result) {
						saving = false;
						save.disabled = false;
						if (!result || !result.ok) { fail(result); return; }
						api.status('Cópia salva na Galeria.', 'success');
						actions.replaceChildren(
							button('Ver na galeria', '', function () { api.openApp('gallery', { id: result.data.id }); }),
							button('Continuar', 'coe-button--primary', paintActions)
						);
					});
				}, 30);
			});

			function paintActions() {
				actions.replaceChildren(
					button('Fotos', '', picker),
					button('Desfazer', '', function () { state = fresh(); showTab(tab); update({}); }),
					save
				);
			}

			paintActions();
			showTab('filters');
			paint();
		}

		if (args && args.id) { open(Number(args.id)); } else { picker(); }
	});
})();
