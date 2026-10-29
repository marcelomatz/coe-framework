// coe_supervisor: fs_writer.js
// I/O em disco via Node.js do FXServer, usado só pelo updater deste resource.
// O Node não passa pelo sandbox de arquivos do FXServer, por isso cada função:
//   1. aceita apenas chamadas do próprio coe_supervisor (GetInvokingResource);
//   2. recebe (resource, caminho relativo) e nunca um caminho absoluto: o destino é resolvido dentro de
//      GetResourcePath(resource) e qualquer escape (.., absoluto, symlink de pasta) é recusado;
//   3. baixa apenas por HTTPS, de hosts conhecidos, e só move o arquivo para o lugar depois de conferir o SHA-256.

const fs = require('fs');
const path = require('path');
const https = require('https');
const crypto = require('crypto');

const RESOURCE_NAME_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;
const STAGED_SUFFIX = '.coe-new';
const DOWNLOAD_HOSTS = new Set([
	'raw.githubusercontent.com',
	'objects.githubusercontent.com',
	'github.com',
	'codeload.github.com'
]);
const MAX_DOWNLOAD_BYTES = 32 * 1024 * 1024;

function selfName() {
	return typeof GetCurrentResourceName === 'function' ? GetCurrentResourceName() : 'coe_supervisor';
}

// Só o próprio resource. Chamadas de outro resource sempre trazem o nome dele em GetInvokingResource.
function callerAllowed() {
	if (typeof GetInvokingResource !== 'function') {
		return true;
	}
	const invoker = GetInvokingResource();
	return invoker === null || invoker === undefined || invoker === '' || invoker === selfName();
}

function sanitizeRelative(relPath) {
	if (typeof relPath !== 'string' || relPath.length === 0 || relPath.length > 240) {
		return null;
	}
	if (/[\u0000-\u001f:]/.test(relPath)) {
		return null;
	}
	const norm = relPath.replace(/\\/g, '/');
	if (norm.startsWith('/') || norm.endsWith('/') || norm.includes('//')) {
		return null;
	}
	for (const segment of norm.split('/')) {
		if (segment === '' || segment === '.' || segment === '..') {
			return null;
		}
	}
	return norm;
}

function resourceRoot(resourceName, resolveRoot) {
	if (typeof resourceName !== 'string' || !RESOURCE_NAME_PATTERN.test(resourceName)) {
		return null;
	}
	const root = resolveRoot(resourceName);
	if (typeof root !== 'string' || root === '') {
		return null;
	}
	return path.resolve(root);
}

// Caminho absoluto dentro do resource, ou null. Também recusa quando a pasta pai real (symlink) sai da raiz.
function resolveInside(resourceName, relPath, resolveRoot) {
	const root = resourceRoot(resourceName, resolveRoot);
	const rel = sanitizeRelative(relPath);
	if (!root || !rel) {
		return null;
	}
	const target = path.resolve(root, rel);
	if (!target.startsWith(root + path.sep)) {
		return null;
	}
	let realRoot = root;
	try {
		realRoot = fs.realpathSync(root);
	} catch (err) {
		return null;
	}
	let probe = path.dirname(target);
	while (!fs.existsSync(probe) && probe.startsWith(root + path.sep)) {
		probe = path.dirname(probe);
	}
	try {
		const realProbe = fs.realpathSync(probe);
		if (realProbe !== realRoot && !realProbe.startsWith(realRoot + path.sep)) {
			return null;
		}
	} catch (err) {
		return null;
	}
	return target;
}

// Mesma normalização do SupervisorUpdater.Sha256: texto tem CRLF trocado por LF antes do hash.
function sha256Of(buffer, isBinary) {
	let data = buffer;
	if (!isBinary) {
		data = Buffer.from(buffer.toString('latin1').replace(/\r\n/g, '\n'), 'latin1');
	}
	return crypto.createHash('sha256').update(data).digest('hex');
}

function isAllowedUrl(url, allowedHosts) {
	try {
		const parsed = new URL(url);
		return parsed.protocol === 'https:' && allowedHosts.has(parsed.hostname);
	} catch (err) {
		return false;
	}
}

function writeInside(resourceName, relPath, content, isBinary, resolveRoot) {
	const target = resolveInside(resourceName, relPath, resolveRoot);
	if (!target || typeof content !== 'string') {
		return false;
	}
	fs.mkdirSync(path.dirname(target), { recursive: true });
	const tmp = target + STAGED_SUFFIX;
	fs.writeFileSync(tmp, isBinary ? Buffer.from(content, 'binary') : content, isBinary ? undefined : 'utf8');
	fs.renameSync(tmp, target);
	return true;
}

function readInside(resourceName, relPath, resolveRoot) {
	const target = resolveInside(resourceName, relPath, resolveRoot);
	if (!target || !fs.existsSync(target)) {
		return null;
	}
	return fs.readFileSync(target, 'utf8');
}

function hashInside(resourceName, relPath, isBinary, resolveRoot) {
	const target = resolveInside(resourceName, relPath, resolveRoot);
	if (!target || !fs.existsSync(target)) {
		return null;
	}
	return sha256Of(fs.readFileSync(target), isBinary === true);
}

// Baixa para <arquivo>.coe-new e só conclui com sucesso se o SHA-256 bater. CommitFile move para o lugar.
function downloadInside(url, resourceName, relPath, expectedSha256, resolveRoot, cb, client) {
	const done = typeof cb === 'function' ? cb : () => {};
	const target = resolveInside(resourceName, relPath, resolveRoot);
	if (!target) {
		done(false, 'invalid_path');
		return false;
	}
	if (typeof expectedSha256 !== 'string' || !/^[0-9a-f]{64}$/.test(expectedSha256)) {
		done(false, 'integrity_missing');
		return false;
	}
	if (!isAllowedUrl(url, DOWNLOAD_HOSTS)) {
		done(false, 'insecure_url');
		return false;
	}
	const staged = target + STAGED_SUFFIX;
	fs.mkdirSync(path.dirname(target), { recursive: true });

	let finished = false;
	const finish = (ok, err) => {
		if (finished) {
			return;
		}
		finished = true;
		if (!ok) {
			fs.unlink(staged, () => {});
		}
		done(ok, err);
	};

	const fetchUrl = (targetUrl, redirectsLeft) => {
		if (redirectsLeft <= 0) {
			finish(false, 'too_many_redirects');
			return;
		}
		if (!isAllowedUrl(targetUrl, DOWNLOAD_HOSTS)) {
			finish(false, 'insecure_redirect');
			return;
		}
		const req = (client || https).get(targetUrl, { headers: { 'User-Agent': 'COE-Framework-Supervisor' } }, (res) => {
			if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
				res.resume();
				fetchUrl(new URL(res.headers.location, targetUrl).toString(), redirectsLeft - 1);
				return;
			}
			if (res.statusCode !== 200) {
				res.resume();
				finish(false, 'http_' + res.statusCode);
				return;
			}
			const chunks = [];
			let size = 0;
			res.on('data', (chunk) => {
				size += chunk.length;
				if (size > MAX_DOWNLOAD_BYTES) {
					req.destroy();
					finish(false, 'too_large');
					return;
				}
				chunks.push(chunk);
			});
			res.on('end', () => {
				if (finished) {
					return;
				}
				const body = Buffer.concat(chunks);
				if (sha256Of(body, true) !== expectedSha256) {
					finish(false, 'integrity_mismatch');
					return;
				}
				try {
					fs.writeFileSync(staged, body);
					finish(true, null);
				} catch (err) {
					finish(false, err && err.message ? err.message : 'write_failed');
				}
			});
			res.on('error', (err) => finish(false, err.message));
		});
		req.on('error', (err) => finish(false, err.message));
		req.setTimeout(25000, () => {
			req.destroy();
			finish(false, 'timeout');
		});
	};

	fetchUrl(url, 5);
	return true;
}

function commitInside(resourceName, relPath, resolveRoot) {
	const target = resolveInside(resourceName, relPath, resolveRoot);
	if (!target || !fs.existsSync(target + STAGED_SUFFIX)) {
		return false;
	}
	fs.renameSync(target + STAGED_SUFFIX, target);
	return true;
}

function discardInside(resourceName, relPath, resolveRoot) {
	const target = resolveInside(resourceName, relPath, resolveRoot);
	if (!target) {
		return false;
	}
	try {
		fs.unlinkSync(target + STAGED_SUFFIX);
	} catch (err) {
		return false;
	}
	return true;
}

// Assinatura Ed25519 (base64) do version.json. Chave pública em PEM (SupervisorConfig.Updater.PublicKey).
function verifySignature(body, signatureB64, publicKeyPem) {
	if (typeof body !== 'string' || typeof signatureB64 !== 'string' || typeof publicKeyPem !== 'string') {
		return false;
	}
	try {
		const key = crypto.createPublicKey(publicKeyPem);
		return crypto.verify(null, Buffer.from(body, 'utf8'), key, Buffer.from(signatureB64.trim(), 'base64'));
	} catch (err) {
		return false;
	}
}

function guarded(fallback, fn) {
	return (...args) => {
		if (!callerAllowed()) {
			console.error('[coe_supervisor:fs_writer] Chamada recusada de', GetInvokingResource());
			return fallback;
		}
		try {
			return fn(...args);
		} catch (err) {
			console.error('[coe_supervisor:fs_writer]', err && err.message ? err.message : err);
			return fallback;
		}
	};
}

if (typeof exports === 'function' && typeof GetResourcePath === 'function') {
	const root = (name) => GetResourcePath(name);
	exports('WriteFile', guarded(false, (res, rel, content, isBinary) => writeInside(res, rel, content, isBinary === true, root)));
	exports('ReadFile', guarded(null, (res, rel) => readInside(res, rel, root)));
	exports('HashFile', guarded(null, (res, rel, isBinary) => hashInside(res, rel, isBinary, root)));
	exports('DownloadFile', guarded(false, (url, res, rel, sha, cb) => downloadInside(url, res, rel, sha, root, cb)));
	exports('CommitFile', guarded(false, (res, rel) => commitInside(res, rel, root)));
	exports('DiscardFile', guarded(false, (res, rel) => discardInside(res, rel, root)));
	exports('VerifySignature', guarded(false, (body, sig, key) => verifySignature(body, sig, key)));
}

if (typeof module !== 'undefined' && module.exports) {
	module.exports = {
		sanitizeRelative,
		resolveInside,
		sha256Of,
		isAllowedUrl,
		writeInside,
		readInside,
		hashInside,
		downloadInside,
		commitInside,
		discardInside,
		verifySignature,
		callerAllowed,
		DOWNLOAD_HOSTS
	};
}
