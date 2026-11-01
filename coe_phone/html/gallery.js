// Apps nativos do smartphone: Câmera e Galeria. As fotos ficam no aparelho, limitadas pelo armazenamento do modelo.
(function () {
	'use strict';

	const phone = window.CoePhone;

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

	function icon(api, name) {
		const node = el('i', 'gl-icon');
		node.innerHTML = api.svg(name);
		return node;
	}

	function fail(api, result) {
		api.status(api.errorText(result && result.error), 'error');
	}

	function megabytes(bytes) {
		const value = Math.max(0, Number(bytes) || 0) / 1048576;
		return value.toLocaleString('pt-BR', { maximumFractionDigits: value < 10 ? 1 : 0 }) + ' MB';
	}

	function when(seconds) {
		const date = new Date(Number(seconds || 0) * 1000);
		const pad = function (n) { return String(n).padStart(2, '0'); };
		return pad(date.getDate()) + '/' + pad(date.getMonth() + 1) + '/' + date.getFullYear() + ' ' + pad(date.getHours()) + ':' + pad(date.getMinutes());
	}

	// Redimensiona e comprime para JPEG, baixando a qualidade até caber em maxBytes (null se não couber).
	function shrink(image, width, quality, maxBytes) {
		return new Promise(function (resolve) {
			const img = new Image();
			img.onload = function () {
				const w = Math.max(1, Math.min(width, img.width));
				const h = Math.max(1, Math.round(img.height * (w / img.width)));
				const canvas = document.createElement('canvas');
				canvas.width = w;
				canvas.height = h;
				canvas.getContext('2d').drawImage(img, 0, 0, w, h);
				let q = quality;
				let out = canvas.toDataURL('image/jpeg', q);
				while (out.length > maxBytes && q > 0.3) {
					q -= 0.1;
					out = canvas.toDataURL('image/jpeg', q);
				}
				resolve(out.length <= maxBytes ? out : null);
			};
			img.onerror = function () { resolve(null); };
			img.src = image;
		});
	}

	function storageBar(storage) {
		const node = el('div', 'gl-storage');
		const used = storage ? storage.used : 0;
		const capacity = storage ? storage.capacity : 0;
		const ratio = capacity > 0 ? Math.min(1, used / capacity) : 1;
		const head = el('div', 'gl-storage-head');
		head.append(
			el('span', null, storage ? storage.count + (storage.count === 1 ? ' foto' : ' fotos') : ''),
			el('small', null, megabytes(used) + ' de ' + megabytes(capacity))
		);
		const bar = el('i', 'gl-storage-bar');
		const fill = el('b');
		fill.style.width = (ratio * 100).toFixed(1) + '%';
		bar.classList.toggle('is-full', ratio >= 0.9);
		bar.appendChild(fill);
		node.append(head, bar);
		return node;
	}

	// Câmera ---------------------------------------------------------------------------------------------

	phone.register('camera', function (root, api) {
		const page = el('div', 'gl-camera');
		root.appendChild(page);
		let info = null;
		let busy = false;

		function viewfinder(content) {
			const frame = el('div', 'gl-finder');
			frame.append(el('i', 'gl-corner gl-corner--tl'), el('i', 'gl-corner gl-corner--tr'), el('i', 'gl-corner gl-corner--bl'), el('i', 'gl-corner gl-corner--br'));
			frame.appendChild(content);
			return frame;
		}

		function shutter() {
			const node = el('button', 'gl-shutter');
			node.type = 'button';
			node.setAttribute('aria-label', 'Fotografar');
			node.disabled = busy || !info;
			node.addEventListener('click', shoot);
			return node;
		}

		function paintReady() {
			const hint = el('div', 'gl-hint');
			hint.append(
				icon(api, 'shutter'),
				el('strong', null, 'Toque no obturador'),
				el('small', null, 'Mouse mira · roda dá zoom · E vira a câmera · clique fotografa · botão direito cancela')
			);
			page.replaceChildren(viewfinder(hint), storageBar(info && info.storage), shutter());
		}

		function paintShot(image, saved) {
			const photo = el('img', 'gl-shot');
			photo.src = image;
			photo.alt = 'Foto';
			const actions = el('div', 'gl-actions');
			actions.append(
				button('Tirar outra', '', paintReady),
				button('Ver na galeria', 'coe-button--primary', function () { api.openApp('gallery', { id: saved.id }); })
			);
			page.replaceChildren(viewfinder(photo), storageBar(info && info.storage), actions);
		}

		function shoot() {
			if (busy || !info) { return; }
			busy = true;
			api.status('');
			api.camera().then(function (result) {
				if (!result || !result.ok) {
					if (result && result.error !== 'cancelled') { fail(api, result); }
					return null;
				}
				api.status('Processando…');
				return Promise.all([
					shrink(result.image, info.width, info.quality, info.maxBytes),
					shrink(result.image, info.thumbWidth, 0.6, info.thumbMaxBytes)
				]);
			}).then(function (images) {
				if (!images) { return null; }
				if (!images[0] || !images[1]) {
					fail(api, { error: 'invalid_photo' });
					return null;
				}
				api.status('Salvando…');
				return api.savePhoto(images[0], images[1]).then(function (saved) {
					if (!saved || !saved.ok) {
						fail(api, saved);
						return null;
					}
					api.status('Foto salva na Galeria.', 'success');
					info.storage.count += 1;
					info.storage.used += images[0].length + images[1].length;
					paintShot(images[0], saved.data);
					return true;
				});
			}).finally(function () {
				busy = false;
				const node = page.querySelector('.gl-shutter');
				if (node) { node.disabled = false; }
			});
			const node = page.querySelector('.gl-shutter');
			if (node) { node.disabled = true; }
		}

		paintReady();
		api.call('camera', 'info').then(function (result) {
			if (!result || !result.ok) {
				fail(api, result);
				return;
			}
			info = result.data;
			paintReady();
		});
	});

	// Galeria --------------------------------------------------------------------------------------------

	phone.register('gallery', function (root, api, args) {
		const page = el('div', 'gl-gallery');
		root.appendChild(page);
		let photos = [];
		let more = false;
		let storage = null;
		let loading = false;

		function load(reset) {
			if (loading) { return Promise.resolve(); }
			loading = true;
			const payload = {};
			if (!reset && photos.length) { payload.before = photos[photos.length - 1].id; }
			return api.call('gallery', 'list', payload).then(function (result) {
				if (!result || !result.ok) {
					fail(api, result);
					return;
				}
				if (reset) { photos = []; }
				photos = photos.concat(result.data.photos || []);
				more = result.data.more === true;
				if (result.data.storage) { storage = result.data.storage; }
			}).finally(function () { loading = false; });
		}

		function paintGrid() {
			const grid = el('div', 'gl-grid');
			photos.forEach(function (photo) {
				const cell = el('button', 'gl-thumb');
				cell.type = 'button';
				const img = el('img');
				img.src = photo.thumb;
				img.alt = when(photo.at);
				img.loading = 'lazy';
				cell.appendChild(img);
				cell.addEventListener('click', function () { view(photo.id); });
				grid.appendChild(cell);
			});
			const nodes = [storageBar(storage)];
			if (!photos.length) {
				const blank = el('div', 'gl-blank');
				blank.append(icon(api, 'gallery'), el('strong', null, 'Nenhuma foto'), el('small', null, 'As fotos da Câmera aparecem aqui.'));
				blank.appendChild(button('Abrir a Câmera', 'coe-button--primary', function () { api.openApp('camera'); }));
				nodes.push(blank);
			} else {
				nodes.push(grid);
			}
			if (more) {
				nodes.push(button('Carregar mais', 'gl-more', function () { load(false).then(paintGrid); }));
			}
			page.replaceChildren.apply(page, nodes);
		}

		function view(id) {
			const known = photos.find(function (photo) { return photo.id === id; });
			const viewer = el('div', 'gl-viewer');
			const frame = el('div', 'gl-frame');
			const img = el('img', 'gl-full is-loading');
			if (known) { img.src = known.thumb; }
			frame.appendChild(img);
			const meta = el('div', 'gl-meta');
			const nav = el('div', 'gl-actions');
			viewer.append(frame, meta, nav);
			page.replaceChildren(viewer);

			api.call('gallery', 'photo', { id: id }).then(function (result) {
				if (!result || !result.ok) {
					fail(api, result);
					nav.replaceChildren(button('Voltar', '', paintGrid));
					return;
				}
				const photo = result.data;
				img.src = photo.image;
				img.classList.remove('is-loading');
				meta.replaceChildren(el('span', null, when(photo.at)));
				const profile = api.profile() || {};
				if ((profile.apps || []).some(function (app) { return app.id === 'editor'; })) {
					meta.appendChild(button('Editar', 'gl-edit', function () { api.openApp('editor', { id: photo.id }); }));
				}

				const newer = button('‹', 'gl-step', function () { view(photo.newer); });
				newer.disabled = !photo.newer;
				newer.title = 'Mais recente';
				const older = button('›', 'gl-step', function () { view(photo.older); });
				older.disabled = !photo.older;
				older.title = 'Mais antiga';
				let armed = false;
				const remove = button('Apagar', 'coe-button--danger', function () {
					if (!armed) {
						armed = true;
						remove.textContent = 'Confirmar';
						setTimeout(function () { armed = false; remove.textContent = 'Apagar'; }, 3000);
						return;
					}
					remove.disabled = true;
					api.call('gallery', 'remove', { id: photo.id }).then(function (removed) {
						if (!removed || !removed.ok) {
							remove.disabled = false;
							fail(api, removed);
							return;
						}
						api.status('Foto apagada.', 'success');
						photos = photos.filter(function (item) { return item.id !== photo.id; });
						if (removed.data && removed.data.storage) { storage = removed.data.storage; }
						const next = photo.older || photo.newer;
						if (next) { view(next); } else { paintGrid(); }
					});
				});
				nav.replaceChildren(newer, button('Grade', '', paintGrid), remove, older);
			});
		}

		load(true).then(function () {
			if (args.id) { view(Number(args.id)); } else { paintGrid(); }
		});
	});
})();
