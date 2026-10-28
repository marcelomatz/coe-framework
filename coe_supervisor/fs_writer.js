// coe_supervisor: fs_writer.js
// Utilitário de I/O em disco nativo via Node.js do FXServer para atualização segura do COE Framework.
// O runtime Node.js do FXServer (libnode) permite operações síncronas de escrita física sem restrições
// de VFS sandbox que impedem o Lua padrão de gravar arquivos em outros resources.

const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

exports('DownloadFile', (url, filePath, cb) => {
	try {
		if (typeof url !== 'string' || typeof filePath !== 'string') {
			if (typeof cb === 'function') cb(false, 'invalid_arguments');
			return false;
		}
		const normalized = path.resolve(filePath);
		const parentDir = path.dirname(normalized);
		if (!fs.existsSync(parentDir)) {
			fs.mkdirSync(parentDir, { recursive: true });
		}

		function fetchUrl(targetUrl, redirectsLeft) {
			if (redirectsLeft <= 0) {
				if (typeof cb === 'function') cb(false, 'too_many_redirects');
				return;
			}
			const client = targetUrl.startsWith('http://') ? http : https;
			const req = client.get(targetUrl, { headers: { 'User-Agent': 'COE-Framework-Supervisor' } }, (res) => {
				if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
					fetchUrl(res.headers.location, redirectsLeft - 1);
					return;
				}
				if (res.statusCode !== 200) {
					if (typeof cb === 'function') cb(false, 'http_' + res.statusCode);
					return;
				}
				const fileStream = fs.createWriteStream(normalized);
				res.pipe(fileStream);
				fileStream.on('finish', () => {
					fileStream.close(() => {
						if (typeof cb === 'function') cb(true, null);
					});
				});
				fileStream.on('error', (err) => {
					fs.unlink(normalized, () => {});
					if (typeof cb === 'function') cb(false, err.message);
				});
			});
			req.on('error', (err) => {
				if (typeof cb === 'function') cb(false, err.message);
			});
			req.setTimeout(25000, () => {
				req.destroy();
				if (typeof cb === 'function') cb(false, 'timeout');
			});
		}

		fetchUrl(url, 5);
		return true;
	} catch (err) {
		if (typeof cb === 'function') cb(false, err && err.message ? err.message : String(err));
		return false;
	}
});

exports('WriteFile', (filePath, content, isBinary) => {
	try {
		if (typeof filePath !== 'string' || filePath === '') {
			return false;
		}
		const normalized = path.resolve(filePath);
		const parentDir = path.dirname(normalized);
		if (!fs.existsSync(parentDir)) {
			fs.mkdirSync(parentDir, { recursive: true });
		}
		if (isBinary) {
			fs.writeFileSync(normalized, Buffer.from(content, 'binary'));
		} else {
			fs.writeFileSync(normalized, content, 'utf8');
		}
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
