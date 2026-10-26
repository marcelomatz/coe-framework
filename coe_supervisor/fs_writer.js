// coe_supervisor: fs_writer.js
// Utilitário de I/O em disco nativo via Node.js do FXServer para atualização segura do COE Framework.
// O runtime Node.js do FXServer (libnode) permite operações síncronas de escrita física sem restrições
// de VFS sandbox que impedem o Lua padrão de gravar arquivos em outros resources.

const fs = require('fs');
const path = require('path');

exports('WriteFile', (filePath, content) => {
	try {
		if (typeof filePath !== 'string' || filePath === '') {
			return false;
		}
		const normalized = path.resolve(filePath);
		const parentDir = path.dirname(normalized);
		if (!fs.existsSync(parentDir)) {
			fs.mkdirSync(parentDir, { recursive: true });
		}
		fs.writeFileSync(normalized, content, 'utf8');
		return true;
	} catch (err) {
		console.error('[coe_supervisor:fs_writer] Falha ao gravar arquivo:', filePath, err && err.message ? err.message : err);
		return false;
	}
});

exports('ReadFile', (filePath) => {
	try {
		if (typeof filePath !== 'string' || filePath === '') {
			return null;
		}
		const normalized = path.resolve(filePath);
		if (!fs.existsSync(normalized)) {
			return null;
		}
		return fs.readFileSync(normalized, 'utf8');
	} catch (err) {
		return null;
	}
});
