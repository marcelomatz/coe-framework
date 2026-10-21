(() => {
	const container = document.getElementById('pause-container');
	const dcDialog = document.getElementById('disconnect-dialog');
	const mapViewport = document.getElementById('map-viewport');
	const mapCanvas = document.getElementById('map-canvas');
	const playerMarker = document.getElementById('player-map-marker');
	const playerArrow = document.getElementById('player-heading-arrow');
	const waypointMarker = document.getElementById('waypoint-map-marker');
	const gpsRouteLine = document.getElementById('gps-route-line');
	const activeWpHud = document.getElementById('active-waypoint-hud');
	const wpHudDist = document.getElementById('wp-hud-dist');
	const mapTooltip = document.getElementById('map-tooltip');
	const cursorCoordsEl = document.getElementById('map-cursor-coords');
	const setSavePill = document.getElementById('set-save-pill');

	let currentView = 'dashboard';
	let lastCoords = { x: 0, y: 0, z: 0 };
	let lastHeading = 0;
	let currentWaypoint = null;
	let listeningKeybindBtn = null;
	let saveDebounceTimer = null;

	// Estado de Navegação do Mapa (Pan & Zoom)
	let mapScale = 1;
	const MIN_SCALE = 1;
	const MAX_SCALE = 4.5;
	let mapTranslateX = 0;
	let mapTranslateY = 0;
	let isDragging = false;
	let startDragX = 0;
	let startDragY = 0;
	let dragDistance = 0;

	function post(endpoint, data = {}) {
		const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'coe_pausemenu';
		return fetch(`https://${resourceName}/${endpoint}`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify(data)
		}).then((r) => r.json()).catch(() => ({}));
	}

	function switchView(viewName) {
		currentView = viewName;
		document.querySelectorAll('.nav-tab').forEach((t) => {
			t.classList.toggle('active', t.dataset.view === viewName);
		});
		document.querySelectorAll('.view-panel').forEach((p) => {
			p.classList.toggle('active', p.id === `view-${viewName}`);
		});

		if (viewName === 'map') {
			updateGpsRoute();
		}
	}

	// =========================================================================
	// Transformação de Coordenadas GTA V (Mapeamento canônico da imagem 8192x8192)
	// =========================================================================
	function worldToMap(x, y) {
		const pctX = ((0.66304 * x + 3753.6) / 8192) * 100;
		const pctY = ((-0.656 * y + 5529.6) / 8192) * 100;
		return {
			x: Math.max(0, Math.min(100, pctX)),
			y: Math.max(0, Math.min(100, pctY))
		};
	}

	function mapToWorld(pctX, pctY) {
		const pixelX = (pctX / 100) * 8192;
		const pixelY = (pctY / 100) * 8192;
		const worldX = (pixelX - 3753.6) / 0.66304;
		const worldY = (5529.6 - pixelY) / 0.656;
		return {
			x: Math.round(worldX * 10) / 10,
			y: Math.round(worldY * 10) / 10
		};
	}

	function calcDistance(c1, c2) {
		if (!c1 || !c2) return 0;
		const dx = c1.x - c2.x;
		const dy = c1.y - c2.y;
		return Math.sqrt(dx * dx + dy * dy);
	}

	function formatDistance(distMeters) {
		if (distMeters >= 1000) {
			return `${(distMeters / 1000).toFixed(2)} km`;
		}
		return `${Math.round(distMeters)} m`;
	}

	// =========================================================================
	// Pan & Zoom Engine
	// =========================================================================
	function clampTransform() {
		if (!mapViewport) return;
		const vpWidth = mapViewport.clientWidth || 800;
		const vpHeight = mapViewport.clientHeight || 600;

		const maxTranslateX = 0;
		const minTranslateX = vpWidth - vpWidth * mapScale;
		const maxTranslateY = 0;
		const minTranslateY = vpHeight - vpHeight * mapScale;

		mapTranslateX = Math.min(maxTranslateX, Math.max(minTranslateX, mapTranslateX));
		mapTranslateY = Math.min(maxTranslateY, Math.max(minTranslateY, mapTranslateY));
	}

	function applyMapTransform(smooth = false) {
		if (!mapCanvas) return;
		clampTransform();
		if (smooth) {
			mapCanvas.style.transition = 'transform 260ms cubic-bezier(0.2, 0.8, 0.2, 1)';
			setTimeout(() => { if (mapCanvas) mapCanvas.style.transition = ''; }, 270);
		} else {
			mapCanvas.style.transition = '';
		}
		mapCanvas.style.transform = `translate(${mapTranslateX}px, ${mapTranslateY}px) scale(${mapScale})`;
	}

	function zoomAt(factor, clientX, clientY) {
		if (!mapViewport) return;
		const rect = mapViewport.getBoundingClientRect();
		const cx = (clientX != null) ? (clientX - rect.left) : (rect.width / 2);
		const cy = (clientY != null) ? (clientY - rect.top) : (rect.height / 2);

		const oldScale = mapScale;
		const newScale = Math.max(MIN_SCALE, Math.min(MAX_SCALE, oldScale * factor));
		if (newScale === oldScale) return;

		mapTranslateX = cx - (cx - mapTranslateX) * (newScale / oldScale);
		mapTranslateY = cy - (cy - mapTranslateY) * (newScale / oldScale);
		mapScale = newScale;

		applyMapTransform(false);
	}

	function centerOnPlayer() {
		if (!mapViewport || !lastCoords) return;
		const rect = mapViewport.getBoundingClientRect();
		const pos = worldToMap(lastCoords.x, lastCoords.y);

		mapScale = Math.max(2.0, mapScale);
		const targetCanvasX = (pos.x / 100) * rect.width * mapScale;
		const targetCanvasY = (pos.y / 100) * rect.height * mapScale;

		mapTranslateX = rect.width / 2 - targetCanvasX;
		mapTranslateY = rect.height / 2 - targetCanvasY;

		applyMapTransform(true);
	}

	function resetMapView() {
		mapScale = 1;
		mapTranslateX = 0;
		mapTranslateY = 0;
		applyMapTransform(true);
	}

	// =========================================================================
	// Atualização do Jogador e Waypoint
	// =========================================================================
	function updateMapPlayer(coords, heading) {
		if (!coords) return;
		lastCoords = coords;
		if (heading != null) lastHeading = heading;

		const pos = worldToMap(coords.x, coords.y);
		if (playerMarker) {
			playerMarker.style.left = `${pos.x}%`;
			playerMarker.style.top = `${pos.y}%`;
		}
		if (playerArrow && heading != null) {
			playerArrow.style.transform = `rotate(${Math.round(heading)}deg)`;
		}
		const coordsTag = document.getElementById('map-coords-tag');
		if (coordsTag) {
			coordsTag.textContent = `X: ${Math.round(coords.x)} | Y: ${Math.round(coords.y)} | Z: ${Math.round(coords.z)}`;
		}

		updateGpsRoute();
	}

	function setMapWaypoint(targetWorld) {
		currentWaypoint = targetWorld;
		if (!targetWorld) {
			if (waypointMarker) waypointMarker.style.display = 'none';
			if (gpsRouteLine) gpsRouteLine.style.display = 'none';
			if (activeWpHud) activeWpHud.style.display = 'none';
			return;
		}

		const pos = worldToMap(targetWorld.x, targetWorld.y);
		if (waypointMarker) {
			waypointMarker.style.left = `${pos.x}%`;
			waypointMarker.style.top = `${pos.y}%`;
			waypointMarker.style.display = 'flex';
		}

		updateGpsRoute();
	}

	function updateGpsRoute() {
		if (!currentWaypoint || !lastCoords) {
			if (gpsRouteLine) gpsRouteLine.style.display = 'none';
			if (activeWpHud) activeWpHud.style.display = 'none';
			return;
		}

		const pPos = worldToMap(lastCoords.x, lastCoords.y);
		const wPos = worldToMap(currentWaypoint.x, currentWaypoint.y);

		if (gpsRouteLine) {
			gpsRouteLine.setAttribute('x1', `${pPos.x}%`);
			gpsRouteLine.setAttribute('y1', `${pPos.y}%`);
			gpsRouteLine.setAttribute('x2', `${wPos.x}%`);
			gpsRouteLine.setAttribute('y2', `${wPos.y}%`);
			gpsRouteLine.style.display = 'block';
		}

		const dist = calcDistance(lastCoords, currentWaypoint);
		if (wpHudDist) {
			wpHudDist.textContent = `Distância: ${formatDistance(dist)}`;
		}
		if (activeWpHud) {
			activeWpHud.style.display = 'flex';
		}
	}

	// =========================================================================
	// Renderização do Payload
	// =========================================================================
	function renderPayload(payload) {
		if (!payload) return;

		// Telemetria do servidor
		const s = payload.server || {};
		if (s.sub) document.getElementById('server-sub').textContent = s.sub;
		if (s.onlinePlayers != null && s.maxPlayers != null) {
			document.getElementById('player-count').textContent = `${s.onlinePlayers} / ${s.maxPlayers}`;
		}
		if (s.ping != null) document.getElementById('player-ping').textContent = `${s.ping} ms`;
		if (s.gameTime) document.getElementById('rp-clock').textContent = s.gameTime;
		if (s.uptime) document.getElementById('server-uptime').textContent = s.uptime;

		// Dossiê do personagem
		const c = payload.character || {};
		document.getElementById('char-name').textContent = c.name || 'Cidadão';
		document.getElementById('char-state-id').textContent = c.stateId || 'COE0000';
		document.getElementById('char-job').textContent = c.job || 'Civil';
		document.getElementById('char-job-grade').textContent = `Cargo: ${c.jobGrade || 'N/A'}`;
		document.getElementById('char-faction').textContent = c.faction || 'Nenhuma';
		document.getElementById('char-faction-grade').textContent = `Nível: ${c.factionGrade || 'N/A'}`;
		document.getElementById('char-location').textContent = c.location || 'Los Santos';
		document.getElementById('char-gender').textContent = c.gender || 'N/A';
		document.getElementById('char-birth').textContent = c.birthDate || 'N/A';
		document.getElementById('char-bank').textContent = c.bank || 'R$ 0';

		// Atualiza tag do mapa
		const mapStreetTag = document.getElementById('map-street-tag');
		if (mapStreetTag) mapStreetTag.textContent = c.location || 'Los Santos';

		// Atualiza posição do jogador no mapa
		if (c.coords) {
			updateMapPlayer(c.coords, c.heading);
		}

		// Atualiza waypoint ativo se houver
		if (payload.waypoint) {
			setMapWaypoint(payload.waypoint);
		} else {
			setMapWaypoint(null);
		}

		// Atalhos rápidos
		const bindsList = document.getElementById('quick-binds');
		if (bindsList) {
			bindsList.innerHTML = '';
			(payload.quickBinds || []).forEach((b) => {
				const item = document.createElement('div');
				item.className = 'bind-item';
				item.innerHTML = `<span class="bind-desc">${b.desc}</span><span class="bind-k">${b.key}</span>`;
				bindsList.appendChild(item);
			});
		}

		// Regras completas
		const fullRulesBody = document.getElementById('full-rules-body');
		if (fullRulesBody) {
			fullRulesBody.innerHTML = '';
			(payload.rules || []).forEach((sec) => {
				const section = document.createElement('div');
				section.className = 'rule-section';
				const items = (sec.items || []).map((it) => `<li>${it}</li>`).join('');
				section.innerHTML = `<h4>${sec.title}</h4><ul>${items}</ul>`;
				fullRulesBody.appendChild(section);
			});
		}

		// Links da comunidade
		if (s.discord) document.getElementById('discord-url').textContent = s.discord;
		if (s.website) document.getElementById('website-url').textContent = s.website;

		// Carrega configurações persistidas
		loadAllSettings();
	}

	function closeMenu() {
		container.hidden = true;
		dcDialog.hidden = true;
		if (listeningKeybindBtn) {
			listeningKeybindBtn.classList.remove('listening');
			listeningKeybindBtn.textContent = listeningKeybindBtn.dataset.currentKey || listeningKeybindBtn.dataset.default;
			listeningKeybindBtn = null;
		}
		if (mapTooltip) mapTooltip.style.display = 'none';
		switchView('dashboard');
		post('close');
	}

	// =========================================================================
	// Event Listeners: Navegação Geral & Dashboard
	// =========================================================================
	document.querySelectorAll('.nav-tab').forEach((tab) => {
		tab.addEventListener('click', () => {
			switchView(tab.dataset.view);
		});
	});

	document.querySelectorAll('[data-view-btn]').forEach((btn) => {
		btn.addEventListener('click', () => {
			switchView(btn.dataset.viewBtn);
		});
	});

	document.querySelectorAll('[data-act]').forEach((btn) => {
		btn.addEventListener('click', () => {
			const act = btn.dataset.act;
			if (act === 'resume') {
				closeMenu();
			} else if (act === 'hud') {
				closeMenu();
				post('openHud');
			} else if (act === 'disconnect') {
				dcDialog.hidden = false;
			}
		});
	});

	document.getElementById('btn-resume-top').addEventListener('click', closeMenu);

	// =========================================================================
	// Event Listeners: Interatividade e Navegação no Mapa (Pan & Zoom)
	// =========================================================================
	if (mapViewport && mapCanvas) {
		mapViewport.addEventListener('mousedown', (e) => {
			if (e.button !== 0) return;
			isDragging = true;
			startDragX = e.clientX - mapTranslateX;
			startDragY = e.clientY - mapTranslateY;
			dragDistance = 0;
			mapCanvas.classList.add('is-dragging');
		});

		window.addEventListener('mousemove', (e) => {
			if (isDragging) {
				const nextX = e.clientX - startDragX;
				const nextY = e.clientY - startDragY;
				dragDistance += Math.hypot(nextX - mapTranslateX, nextY - mapTranslateY);
				mapTranslateX = nextX;
				mapTranslateY = nextY;
				applyMapTransform(false);
			}

			// Atualiza telemetria de coordenadas sob o cursor
			if (currentView === 'map' && cursorCoordsEl && mapViewport) {
				const rect = mapViewport.getBoundingClientRect();
				if (
					e.clientX >= rect.left && e.clientX <= rect.right &&
					e.clientY >= rect.top && e.clientY <= rect.bottom
				) {
					const canvasX = (e.clientX - rect.left - mapTranslateX) / mapScale;
					const canvasY = (e.clientY - rect.top - mapTranslateY) / mapScale;
					const pctX = (canvasX / rect.width) * 100;
					const pctY = (canvasY / rect.height) * 100;
					const wCoords = mapToWorld(pctX, pctY);
					cursorCoordsEl.textContent = `Cursor: X: ${Math.round(wCoords.x)} | Y: ${Math.round(wCoords.y)}`;
				}
			}
		});

		window.addEventListener('mouseup', () => {
			if (isDragging) {
				isDragging = false;
				mapCanvas.classList.remove('is-dragging');
			}
		});

		mapViewport.addEventListener('wheel', (e) => {
			e.preventDefault();
			const zoomFactor = e.deltaY < 0 ? 1.25 : 0.8;
			zoomAt(zoomFactor, e.clientX, e.clientY);
		}, { passive: false });

		// Clique no Mapa (ou em Blips)
		mapCanvas.addEventListener('click', (e) => {
			if (dragDistance > 6) return;

			const blip = e.target.closest('.map-blip');
			let targetWorld = null;

			if (blip && blip.dataset.wpX && blip.dataset.wpY) {
				targetWorld = { x: Number(blip.dataset.wpX), y: Number(blip.dataset.wpY) };
			} else {
				const rect = mapViewport.getBoundingClientRect();
				const canvasX = (e.clientX - rect.left - mapTranslateX) / mapScale;
				const canvasY = (e.clientY - rect.top - mapTranslateY) / mapScale;
				const pctX = (canvasX / rect.width) * 100;
				const pctY = (canvasY / rect.height) * 100;
				targetWorld = mapToWorld(pctX, pctY);
			}

			if (targetWorld) {
				post('setWaypoint', targetWorld);
				setMapWaypoint(targetWorld);
			}
		});

		// Tooltips em Blips
		mapCanvas.addEventListener('mouseover', (e) => {
			const blip = e.target.closest('.map-blip');
			if (!blip || !mapTooltip) return;

			const title = blip.dataset.title || blip.querySelector('.blip-label')?.textContent || 'Ponto de Interesse';
			const cat = blip.dataset.cat || 'Serviço';
			const desc = blip.dataset.desc || '';
			const wpX = Number(blip.dataset.wpX);
			const wpY = Number(blip.dataset.wpY);

			document.getElementById('tooltip-title').textContent = title;
			document.getElementById('tooltip-category').textContent = cat;
			document.getElementById('tooltip-desc').textContent = desc;

			if (!isNaN(wpX) && !isNaN(wpY) && lastCoords) {
				const d = calcDistance(lastCoords, { x: wpX, y: wpY });
				document.getElementById('tooltip-dist').textContent = `Distância: ${formatDistance(d)}`;
				document.getElementById('tooltip-dist').style.display = 'block';
			} else {
				document.getElementById('tooltip-dist').style.display = 'none';
			}

			const rect = blip.getBoundingClientRect();
			const vpRect = mapViewport.getBoundingClientRect();
			mapTooltip.style.left = `${rect.left - vpRect.left + rect.width / 2}px`;
			mapTooltip.style.top = `${rect.top - vpRect.top - 8}px`;
			mapTooltip.style.display = 'flex';
		});

		mapCanvas.addEventListener('mouseout', (e) => {
			if (e.target.closest('.map-blip') && mapTooltip) {
				mapTooltip.style.display = 'none';
			}
		});
	}

	// =========================================================================
	// Filtros de POIs no Mapa
	// =========================================================================
	document.querySelectorAll('[data-poi-filter]').forEach((chip) => {
		chip.addEventListener('click', () => {
			document.querySelectorAll('[data-poi-filter]').forEach((c) => c.classList.remove('active'));
			chip.classList.add('active');

			const filter = chip.dataset.poiFilter;
			document.querySelectorAll('.map-blip').forEach((blip) => {
				if (filter === 'all' || blip.classList.contains(filter)) {
					blip.classList.remove('is-hidden');
				} else {
					blip.classList.add('is-hidden');
				}
			});
		});
	});

	// Botões de Ferramentas do Mapa
	const btnCenterPlayer = document.getElementById('btn-center-player');
	if (btnCenterPlayer) btnCenterPlayer.addEventListener('click', centerOnPlayer);

	const btnZoomIn = document.getElementById('map-zoom-in');
	if (btnZoomIn) btnZoomIn.addEventListener('click', () => zoomAt(1.35));

	const btnZoomOut = document.getElementById('map-zoom-out');
	if (btnZoomOut) btnZoomOut.addEventListener('click', () => zoomAt(0.75));

	const btnZoomReset = document.getElementById('map-zoom-reset');
	if (btnZoomReset) btnZoomReset.addEventListener('click', resetMapView);

	const btnClearWp = document.getElementById('btn-clear-waypoint');
	if (btnClearWp) {
		btnClearWp.addEventListener('click', () => {
			post('clearWaypoint');
			setMapWaypoint(null);
		});
	}

	const btnCancelRoute = document.getElementById('btn-cancel-route');
	if (btnCancelRoute) {
		btnCancelRoute.addEventListener('click', () => {
			post('clearWaypoint');
			setMapWaypoint(null);
		});
	}

	// =========================================================================
	// Configurações & Teclado (Sub-abas, Sliders e Mapeamento Interativo)
	// =========================================================================
	document.querySelectorAll('[data-set-tab]').forEach((tabBtn) => {
		tabBtn.addEventListener('click', () => {
			document.querySelectorAll('[data-set-tab]').forEach((b) => b.classList.remove('active'));
			tabBtn.classList.add('active');
			const tabId = tabBtn.dataset.setTab;
			document.querySelectorAll('.set-tab-pane').forEach((pane) => {
				pane.classList.toggle('active', pane.id === `set-tab-${tabId}`);
			});
		});
	});

	// Mapeamento de Teclas Interativo
	function formatKeyName(e) {
		if (e.code === 'Space') return 'ESPAÇO';
		if (e.code === 'Enter') return 'ENTER';
		if (e.code === 'Tab') return 'TAB';
		if (e.code === 'CapsLock') return 'CAPS LOCK';
		if (e.code === 'ShiftLeft' || e.code === 'ShiftRight') return 'SHIFT';
		if (e.code === 'ControlLeft' || e.code === 'ControlRight') return 'CTRL';
		if (e.code === 'AltLeft' || e.code === 'AltRight') return 'ALT';
		if (e.key === 'PageUp') return 'PAGE UP';
		if (e.key === 'PageDown') return 'PAGE DOWN';
		if (e.key === 'ArrowUp') return 'SETA CIMA';
		if (e.key === 'ArrowDown') return 'SETA BAIXO';
		if (e.key === 'ArrowLeft') return 'SETA ESQ';
		if (e.key === 'ArrowRight') return 'SETA DIR';
		if (e.key && e.key.length === 1) return e.key.toUpperCase();
		return (e.key || e.code || 'TECLA').toUpperCase();
	}

	document.querySelectorAll('.keybind-btn:not(.locked)').forEach((btn) => {
		btn.addEventListener('click', (e) => {
			e.stopPropagation();
			if (listeningKeybindBtn === btn) {
				btn.classList.remove('listening');
				btn.textContent = btn.dataset.currentKey || btn.dataset.default;
				listeningKeybindBtn = null;
				return;
			}
			if (listeningKeybindBtn) {
				listeningKeybindBtn.classList.remove('listening');
				listeningKeybindBtn.textContent = listeningKeybindBtn.dataset.currentKey || listeningKeybindBtn.dataset.default;
			}
			listeningKeybindBtn = btn;
			btn.classList.add('listening');
			btn.textContent = 'Pressione...';
		});
	});

	const btnResetKeybinds = document.getElementById('btn-reset-keybinds');
	if (btnResetKeybinds) {
		btnResetKeybinds.addEventListener('click', () => {
			document.querySelectorAll('.keybind-btn').forEach((btn) => {
				const def = btn.dataset.default;
				btn.textContent = def;
				btn.dataset.currentKey = def;
				btn.classList.remove('listening');
			});
			listeningKeybindBtn = null;
			saveAllKeybinds();
			triggerSaveFeedback();
		});
	}

	function saveSingleKeybind(id, key) {
		post('updateKeybind', { id, key });
		try {
			const saved = JSON.parse(localStorage.getItem('coe_pausemenu_keybinds') || '{}');
			saved[id] = key;
			localStorage.setItem('coe_pausemenu_keybinds', JSON.stringify(saved));
		} catch {}
		triggerSaveFeedback();
	}

	function saveAllKeybinds() {
		const binds = {};
		document.querySelectorAll('.keybind-btn').forEach((btn) => {
			const id = btn.dataset.bindId;
			if (id) binds[id] = btn.textContent.trim();
		});
		try {
			localStorage.setItem('coe_pausemenu_keybinds', JSON.stringify(binds));
		} catch {}
		post('saveSettings', { keybinds: binds });
	}

	// Sliders e seus rótulos numéricos
	const slidersMap = [
		{ id: 'cfg-mouse-sens', valId: 'val-mouse-sens', unit: '' },
		{ id: 'cfg-aim-sens', valId: 'val-aim-sens', unit: '' },
		{ id: 'cfg-veh-sens', valId: 'val-veh-sens', unit: '' },
		{ id: 'cfg-master-vol', valId: 'val-master-vol', unit: '%' },
		{ id: 'cfg-sfx-vol', valId: 'val-sfx-vol', unit: '%' },
		{ id: 'cfg-music-vol', valId: 'val-music-vol', unit: '%' },
		{ id: 'cfg-voice-vol', valId: 'val-voice-vol', unit: '%' },
		{ id: 'cfg-mic-sens', valId: 'val-mic-sens', unit: '%' },
		{ id: 'cfg-brightness', valId: 'val-brightness', unit: '%' },
		{ id: 'cfg-safezone', valId: 'val-safezone', unit: '%' },
		{ id: 'cfg-fov-foot', valId: 'val-fov-foot', unit: '°' },
		{ id: 'cfg-fov-veh', valId: 'val-fov-veh', unit: '°' }
	];

	slidersMap.forEach(({ id, valId, unit }) => {
		const slider = document.getElementById(id);
		const valEl = document.getElementById(valId);
		if (slider && valEl) {
			slider.addEventListener('input', () => {
				valEl.textContent = `${slider.value}${unit}`;
				queueAutoSave();
			});
		}
	});

	// Checkboxes e Selects
	document.querySelectorAll('.set-tab-pane input[type="checkbox"], .set-tab-pane select').forEach((el) => {
		el.addEventListener('change', () => {
			queueAutoSave();
		});
	});

	function triggerSaveFeedback() {
		if (setSavePill) {
			setSavePill.style.opacity = '1';
			setSavePill.style.borderColor = 'var(--coe-accent, #38ef7d)';
			setSavePill.textContent = '✓ Configurações salvas';
			setTimeout(() => {
				if (setSavePill) setSavePill.style.opacity = '0.7';
			}, 1800);
		}
	}

	function queueAutoSave() {
		if (saveDebounceTimer) clearTimeout(saveDebounceTimer);
		saveDebounceTimer = setTimeout(() => {
			saveAllSettings();
		}, 300);
	}

	function saveAllSettings() {
		const settings = {
			mouseSens: document.getElementById('cfg-mouse-sens')?.value,
			aimSens: document.getElementById('cfg-aim-sens')?.value,
			vehSens: document.getElementById('cfg-veh-sens')?.value,
			mouseInvert: document.getElementById('cfg-mouse-invert')?.checked,
			mouseRaw: document.getElementById('cfg-mouse-raw')?.checked,

			masterVol: document.getElementById('cfg-master-vol')?.value,
			sfxVol: document.getElementById('cfg-sfx-vol')?.value,
			musicVol: document.getElementById('cfg-music-vol')?.value,
			voiceVol: document.getElementById('cfg-voice-vol')?.value,
			micSens: document.getElementById('cfg-mic-sens')?.value,
			micMode: document.getElementById('cfg-mic-mode')?.value,
			radioSfx: document.getElementById('cfg-radio-sfx')?.checked,
			phoneSfx: document.getElementById('cfg-phone-sfx')?.checked,
			muteBg: document.getElementById('cfg-mute-bg')?.checked,

			brightness: document.getElementById('cfg-brightness')?.value,
			safezone: document.getElementById('cfg-safezone')?.value,
			screenMode: document.getElementById('cfg-screen-mode')?.value,
			vsync: document.getElementById('cfg-vsync')?.value,
			fpsLimit: document.getElementById('cfg-fps-limit')?.value,
			hud4k: document.getElementById('cfg-hud-4k')?.checked,

			minimapVisibility: document.getElementById('cfg-minimap-visibility')?.value,
			minimapStyle: document.getElementById('cfg-minimap-style')?.value,
			hudCompass: document.getElementById('cfg-hud-compass')?.checked,
			hudStatus: document.getElementById('cfg-hud-status')?.checked,
			speedoUnit: document.getElementById('cfg-speedo-unit')?.value,
			speedoStyle: document.getElementById('cfg-speedo-style')?.value,

			fovFoot: document.getElementById('cfg-fov-foot')?.value,
			fovVeh: document.getElementById('cfg-fov-veh')?.value,
			vehCamDist: document.getElementById('cfg-veh-cam-dist')?.value,
			headbob: document.getElementById('cfg-headbob')?.checked,
			vehAutocenter: document.getElementById('cfg-veh-autocenter')?.checked,
			autoReload: document.getElementById('cfg-auto-reload')?.checked
		};

		try {
			localStorage.setItem('coe_pausemenu_settings', JSON.stringify(settings));
		} catch {}

		post('saveSettings', settings);
		triggerSaveFeedback();
	}

	function loadAllSettings() {
		let settings = null;
		let keybinds = null;
		try {
			const s = localStorage.getItem('coe_pausemenu_settings');
			if (s) settings = JSON.parse(s);
			const k = localStorage.getItem('coe_pausemenu_keybinds');
			if (k) keybinds = JSON.parse(k);
		} catch {}

		if (settings) {
			applySettingsToDom(settings);
		}
		if (keybinds) {
			applyKeybindsToDom(keybinds);
		}

		post('getSettings').then((res) => {
			if (res && res.ok) {
				if (res.settings && !settings) applySettingsToDom(res.settings);
				if (res.keybinds && !keybinds) applyKeybindsToDom(res.keybinds);
			}
		});
	}

	function applySettingsToDom(s) {
		if (!s) return;
		const setVal = (id, val) => {
			const el = document.getElementById(id);
			if (el && val != null) el.value = val;
		};
		const setCheck = (id, val) => {
			const el = document.getElementById(id);
			if (el && val != null) el.checked = Boolean(val);
		};

		setVal('cfg-mouse-sens', s.mouseSens);
		setVal('cfg-aim-sens', s.aimSens);
		setVal('cfg-veh-sens', s.vehSens);
		setCheck('cfg-mouse-invert', s.mouseInvert);
		setCheck('cfg-mouse-raw', s.mouseRaw);

		setVal('cfg-master-vol', s.masterVol);
		setVal('cfg-sfx-vol', s.sfxVol);
		setVal('cfg-music-vol', s.musicVol);
		setVal('cfg-voice-vol', s.voiceVol);
		setVal('cfg-mic-sens', s.micSens);
		setVal('cfg-mic-mode', s.micMode);
		setCheck('cfg-radio-sfx', s.radioSfx);
		setCheck('cfg-phone-sfx', s.phoneSfx);
		setCheck('cfg-mute-bg', s.muteBg);

		setVal('cfg-brightness', s.brightness);
		setVal('cfg-safezone', s.safezone);
		setVal('cfg-screen-mode', s.screenMode);
		setVal('cfg-vsync', s.vsync);
		setVal('cfg-fps-limit', s.fpsLimit);
		setCheck('cfg-hud-4k', s.hud4k);

		setVal('cfg-minimap-visibility', s.minimapVisibility);
		setVal('cfg-minimap-style', s.minimapStyle);
		setCheck('cfg-hud-compass', s.hudCompass);
		setCheck('cfg-hud-status', s.hudStatus);
		setVal('cfg-speedo-unit', s.speedoUnit);
		setVal('cfg-speedo-style', s.speedoStyle);

		setVal('cfg-fov-foot', s.fovFoot);
		setVal('cfg-fov-veh', s.fovVeh);
		setVal('cfg-veh-cam-dist', s.vehCamDist);
		setCheck('cfg-headbob', s.headbob);
		setCheck('cfg-veh-autocenter', s.vehAutocenter);
		setCheck('cfg-auto-reload', s.autoReload);

		slidersMap.forEach(({ id, valId, unit }) => {
			const slider = document.getElementById(id);
			const valEl = document.getElementById(valId);
			if (slider && valEl) {
				valEl.textContent = `${slider.value}${unit}`;
			}
		});
	}

	function applyKeybindsToDom(binds) {
		if (!binds) return;
		document.querySelectorAll('.keybind-btn').forEach((btn) => {
			const id = btn.dataset.bindId;
			if (id && binds[id]) {
				btn.textContent = binds[id];
				btn.dataset.currentKey = binds[id];
			}
		});
	}

	// Restaurar todos os padrões
	const btnResetAll = document.getElementById('btn-reset-all-settings');
	if (btnResetAll) {
		btnResetAll.addEventListener('click', () => {
			try {
				localStorage.removeItem('coe_pausemenu_settings');
				localStorage.removeItem('coe_pausemenu_keybinds');
			} catch {}

			post('resetSettings');

			// Restaura teclado
			document.querySelectorAll('.keybind-btn').forEach((btn) => {
				const def = btn.dataset.default;
				btn.textContent = def;
				btn.dataset.currentKey = def;
				btn.classList.remove('listening');
			});
			listeningKeybindBtn = null;

			// Restaura valores de sliders
			const defaults = {
				mouseSens: 5, aimSens: 5, vehSens: 5, mouseInvert: false, mouseRaw: true,
				masterVol: 80, sfxVol: 70, musicVol: 40, voiceVol: 85, micSens: 60, micMode: 'ptt',
				radioSfx: true, phoneSfx: true, muteBg: true,
				brightness: 50, safezone: 5, screenMode: 'fullscreen', vsync: 'off', fpsLimit: 'unlimited', hud4k: true,
				minimapVisibility: 'always', minimapStyle: 'rect', hudCompass: true, hudStatus: true,
				speedoUnit: 'kmh', speedoStyle: 'modern',
				fovFoot: 85, fovVeh: 90, vehCamDist: 'normal', headbob: true, vehAutocenter: true, autoReload: true
			};
			applySettingsToDom(defaults);
			triggerSaveFeedback();
		});
	}

	// Botões de Ação do HUD existentes
	document.getElementById('btn-open-hud-editor').addEventListener('click', () => {
		closeMenu();
		post('openHud');
	});

	document.getElementById('btn-toggle-minimap-mode').addEventListener('click', () => {
		post('toggleMinimap');
	});

	// Diálogo de Desconexão
	document.getElementById('btn-cancel-dc').addEventListener('click', () => { dcDialog.hidden = true; });
	document.getElementById('btn-confirm-dc').addEventListener('click', () => {
		dcDialog.hidden = true;
		container.hidden = true;
		post('disconnect');
	});

	// Copiar links da comunidade
	document.querySelectorAll('[data-copy]').forEach((link) => {
		link.addEventListener('click', (e) => {
			e.preventDefault();
			const type = link.dataset.copy;
			const targetEl = type === 'discord' ? document.getElementById('discord-url') : document.getElementById('website-url');
			if (targetEl && navigator.clipboard) {
				navigator.clipboard.writeText(targetEl.textContent);
				const orig = targetEl.textContent;
				targetEl.textContent = 'Link copiado!';
				setTimeout(() => { targetEl.textContent = orig; }, 1500);
			}
		});
	});

	// ESC Key listener
	document.addEventListener('keydown', (e) => {
		if (container.hidden) return;

		// Se estiver ouvindo tecla para rebind
		if (listeningKeybindBtn) {
			e.preventDefault();
			e.stopPropagation();

			if (e.key === 'Escape') {
				listeningKeybindBtn.classList.remove('listening');
				listeningKeybindBtn.textContent = listeningKeybindBtn.dataset.currentKey || listeningKeybindBtn.dataset.default;
				listeningKeybindBtn = null;
				return;
			}

			const newKey = formatKeyName(e);
			listeningKeybindBtn.textContent = newKey;
			listeningKeybindBtn.dataset.currentKey = newKey;
			listeningKeybindBtn.classList.remove('listening');

			const bindId = listeningKeybindBtn.dataset.bindId;
			saveSingleKeybind(bindId, newKey);
			listeningKeybindBtn = null;
			return;
		}

		if (e.key === 'Escape') {
			if (!dcDialog.hidden) {
				dcDialog.hidden = true;
			} else if (currentView !== 'dashboard') {
				switchView('dashboard');
			} else {
				closeMenu();
			}
		}
	});

	window.addEventListener('message', (event) => {
		const data = event.data || {};
		if (data.action === 'open') {
			renderPayload(data.data);
			dcDialog.hidden = true;
			switchView('dashboard');
			container.hidden = false;
		} else if (data.action === 'close') {
			container.hidden = true;
			dcDialog.hidden = true;
			if (listeningKeybindBtn) {
				listeningKeybindBtn.classList.remove('listening');
				listeningKeybindBtn.textContent = listeningKeybindBtn.dataset.currentKey || listeningKeybindBtn.dataset.default;
				listeningKeybindBtn = null;
			}
			if (mapTooltip) mapTooltip.style.display = 'none';
			switchView('dashboard');
		}
	});
})();
