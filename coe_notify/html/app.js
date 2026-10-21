const container = document.getElementById('notifications')
const MAX_NOTIFICATIONS = 5

function showNotification(data) {
	if (!data || typeof data.message !== 'string') return

	const notification = document.createElement('div')
	notification.className = 'notification'
	notification.dataset.type = data.type
	notification.textContent = data.message
	container.appendChild(notification)

	while (container.children.length > MAX_NOTIFICATIONS) {
		container.firstElementChild.remove()
	}

	window.setTimeout(() => notification.remove(), data.duration)
}

window.addEventListener('message', (event) => {
	if (event.data?.action === 'show') {
		showNotification(event.data)
	} else if (event.data?.action === 'clear') {
		container.replaceChildren()
	}
})
