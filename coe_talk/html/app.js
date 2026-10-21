(() => {
	'use strict';

	const voiceBadge = document.getElementById('voice-badge');
	const voiceLabel = document.getElementById('voice-label');
	const radioBadge = document.getElementById('radio-badge');
	const radioFreq = document.getElementById('radio-freq');
	const radioTx = document.getElementById('radio-tx');
	const callBadge = document.getElementById('call-badge');

	window.addEventListener('message', (event) => {
		const data = event.data;
		if (!data || !data.action) return;

		switch (data.action) {
			case 'mode':
				if (voiceBadge) {
					voiceBadge.dataset.level = data.level || 2;
				}
				if (voiceLabel) {
					voiceLabel.textContent = data.label || 'Normal';
				}
				break;

			case 'talking':
				if (voiceBadge) {
					voiceBadge.classList.toggle('is-talking', !!data.talking);
				}
				break;

			case 'radioSet':
				if (radioBadge) {
					if (data.frequency != null) {
						const freq = Number(data.frequency);
						radioFreq.textContent = `${freq.toFixed(1)} MHz`;
						radioBadge.hidden = false;
					} else {
						radioBadge.hidden = true;
						if (radioTx) radioTx.hidden = true;
						radioBadge.classList.remove('is-transmitting');
					}
				}
				break;

			case 'radioTransmitting':
				if (radioBadge) {
					radioBadge.classList.toggle('is-transmitting', !!data.transmitting);
					if (radioTx) {
						radioTx.hidden = !data.transmitting;
					}
				}
				break;

			case 'callSet':
				if (callBadge) {
					callBadge.hidden = !data.active;
				}
				break;
		}
	});
})();
