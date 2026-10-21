const frame = document.getElementById('frame');
const dest = document.getElementById('dest');
const destDist = document.getElementById('dest-dist');
const keysEl = document.getElementById('keys');

function formatDistance(meters) {
	return meters >= 1000 ? `${(meters / 1000).toFixed(1)} km` : `${meters} m`;
}

function renderKeys(keys) {
	keysEl.textContent = '';
	[['extended', 'fechar'], ['full', 'mapa completo']].forEach(([name, text]) => {
		const key = keys && keys[name];
		if (!key) {
			return;
		}
		const kbd = document.createElement('kbd');
		kbd.textContent = key.default || '?';
		keysEl.append(kbd, `${text}  `);
	});
}

function applyMode(message) {
	frame.hidden = message.mode !== 'extended';
	if (!frame.hidden) {
		renderKeys(message.keys);
	}
}

function applyWaypoint(message) {
	dest.hidden = !message.active;
	if (message.active) {
		destDist.textContent = formatDistance(message.distance || 0);
	}
}

window.addEventListener('message', (event) => {
	const message = event.data || {};
	if (message.action === 'mode') {
		applyMode(message);
	} else if (message.action === 'waypoint') {
		applyWaypoint(message);
	}
});
