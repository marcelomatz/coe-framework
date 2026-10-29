// Testes do fs_writer.js (node --test coe_supervisor/test/fs_writer.test.js).
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const { EventEmitter } = require('events');
const W = require('../fs_writer.js');

function sandbox() {
	const base = fs.mkdtempSync(path.join(os.tmpdir(), 'coe-fsw-'));
	const roots = { coe_core: path.join(base, 'coe_core') };
	fs.mkdirSync(roots.coe_core);
	fs.writeFileSync(path.join(base, 'server.cfg'), 'set secret 1');
	return { base, root: (name) => roots[name] };
}

test('sanitizeRelative bloqueia traversal, absolutos e drive', () => {
	assert.strictEqual(W.sanitizeRelative('server/main.lua'), 'server/main.lua');
	assert.strictEqual(W.sanitizeRelative('html\\a.js'), 'html/a.js');
	for (const bad of ['../x', 'a/../../x', '/etc/passwd', 'C:/x', 'a//b', '', 'a/']) {
		assert.strictEqual(W.sanitizeRelative(bad), null, bad);
	}
});

test('resolveInside só aceita resource conhecido e caminho dentro dele', () => {
	const { base, root } = sandbox();
	assert.ok(W.resolveInside('coe_core', 'lib/init.lua', root).startsWith(path.join(base, 'coe_core')));
	assert.strictEqual(W.resolveInside('coe_core', '../server.cfg', root), null);
	assert.strictEqual(W.resolveInside('nao_existe', 'a.lua', root), null);
	assert.strictEqual(W.resolveInside('../coe_core', 'a.lua', root), null);
});

test('resolveInside recusa symlink que sai do resource', (t) => {
	const { base, root } = sandbox();
	try {
		fs.symlinkSync(base, path.join(base, 'coe_core', 'link'), 'dir');
	} catch (err) {
		t.skip('symlink indisponível');
		return;
	}
	assert.strictEqual(W.resolveInside('coe_core', 'link/server.cfg', root), null);
});

test('writeInside/readInside/hashInside gravam e leem só dentro do resource', () => {
	const { base, root } = sandbox();
	assert.strictEqual(W.writeInside('coe_core', 'a/b.lua', 'x\r\ny', false, root), true);
	assert.strictEqual(W.readInside('coe_core', 'a/b.lua', root), 'x\r\ny');
	const lf = crypto.createHash('sha256').update('x\ny').digest('hex');
	assert.strictEqual(W.hashInside('coe_core', 'a/b.lua', false, root), lf);
	assert.strictEqual(W.writeInside('coe_core', '../server.cfg', 'pwn', false, root), false);
	assert.strictEqual(fs.readFileSync(path.join(base, 'server.cfg'), 'utf8'), 'set secret 1');
	assert.strictEqual(W.readInside('coe_core', '../server.cfg', root), null);
});

test('isAllowedUrl exige https e host conhecido', () => {
	assert.strictEqual(W.isAllowedUrl('https://raw.githubusercontent.com/a/b', W.DOWNLOAD_HOSTS), true);
	assert.strictEqual(W.isAllowedUrl('http://raw.githubusercontent.com/a/b', W.DOWNLOAD_HOSTS), false);
	assert.strictEqual(W.isAllowedUrl('https://evil.example/a', W.DOWNLOAD_HOSTS), false);
});

function fakeClient(responses) {
	return {
		get(url, opts, onResponse) {
			const req = new EventEmitter();
			req.setTimeout = () => {};
			req.destroy = () => {};
			const spec = responses[url];
			setImmediate(() => {
				const res = new EventEmitter();
				res.statusCode = spec.status;
				res.headers = spec.location ? { location: spec.location } : {};
				res.resume = () => {};
				onResponse(res);
				if (spec.body) {
					res.emit('data', Buffer.from(spec.body));
				}
				res.emit('end');
			});
			return req;
		}
	};
}

function download(url, rel, sha, root, client) {
	return new Promise((resolve) => {
		W.downloadInside(url, 'coe_core', rel, sha, root, (ok, err) => resolve({ ok, err }), client);
	});
}

test('downloadInside só deixa o arquivo pronto quando o SHA-256 bate', async () => {
	const { base, root } = sandbox();
	const body = 'conteudo binario';
	const sha = crypto.createHash('sha256').update(body).digest('hex');
	const url = 'https://raw.githubusercontent.com/r/v1/coe_core/img.png';
	const client = fakeClient({ [url]: { status: 200, body } });

	const ok = await download(url, 'img.png', sha, root, client);
	assert.deepStrictEqual(ok, { ok: true, err: null });
	assert.strictEqual(fs.existsSync(path.join(base, 'coe_core', 'img.png')), false, 'só fica staged');
	assert.strictEqual(W.commitInside('coe_core', 'img.png', root), true);
	assert.strictEqual(fs.readFileSync(path.join(base, 'coe_core', 'img.png'), 'utf8'), body);

	const bad = await download(url, 'img2.png', 'f'.repeat(64), root, client);
	assert.deepStrictEqual(bad, { ok: false, err: 'integrity_mismatch' });
	assert.strictEqual(fs.existsSync(path.join(base, 'coe_core', 'img2.png.coe-new')), false);
});

test('downloadInside recusa http, redirect para host desconhecido e hash ausente', async () => {
	const { root } = sandbox();
	const sha = 'a'.repeat(64);
	const url = 'https://raw.githubusercontent.com/r/v1/coe_core/x.png';
	assert.strictEqual((await download('http://raw.githubusercontent.com/x', 'x.png', sha, root)).err, 'insecure_url');
	assert.strictEqual((await download(url, 'x.png', null, root)).err, 'integrity_missing');
	const client = fakeClient({ [url]: { status: 302, location: 'https://evil.example/x.png' } });
	assert.strictEqual((await download(url, 'x.png', sha, root, client)).err, 'insecure_redirect');
});

test('verifySignature aceita só a assinatura Ed25519 da chave configurada', () => {
	const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
	const pem = publicKey.export({ type: 'spki', format: 'pem' });
	const body = '{"version":"0.1.0"}';
	const sig = crypto.sign(null, Buffer.from(body), privateKey).toString('base64');
	assert.strictEqual(W.verifySignature(body, sig, pem), true);
	assert.strictEqual(W.verifySignature(body + ' ', sig, pem), false);
	assert.strictEqual(W.verifySignature(body, sig, 'lixo'), false);
});

test('callerAllowed recusa outro resource', () => {
	global.GetCurrentResourceName = () => 'coe_supervisor';
	global.GetInvokingResource = () => 'meu_script';
	assert.strictEqual(W.callerAllowed(), false);
	global.GetInvokingResource = () => 'coe_supervisor';
	assert.strictEqual(W.callerAllowed(), true);
	delete global.GetInvokingResource;
	delete global.GetCurrentResourceName;
});
