#!/usr/bin/env node
// tools/sign_manifest.js
// Assina o version.json com Ed25519 para o updater do coe_supervisor (version.json.sig ao lado do manifesto).
//
// Uso:
//   node tools/sign_manifest.js --keygen            gera coe-manifest.key (privada, NÃO versionar) e mostra a pública
//   node tools/sign_manifest.js                     assina version.json com a chave em COE_MANIFEST_KEY (PEM)
//                                                   ou no arquivo apontado por COE_MANIFEST_KEY_FILE
//   node tools/sign_manifest.js --verify <pub.pem>  confere version.json.sig
//
// A chave pública vai em coe_supervisor/config.lua (SupervisorConfig.Updater.PublicKey).

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = path.resolve(__dirname, '..');
const manifestPath = path.join(root, 'version.json');
const signaturePath = manifestPath + '.sig';
const args = process.argv.slice(2);

function readPrivateKey() {
	if (process.env.COE_MANIFEST_KEY) {
		return process.env.COE_MANIFEST_KEY;
	}
	if (process.env.COE_MANIFEST_KEY_FILE) {
		return fs.readFileSync(process.env.COE_MANIFEST_KEY_FILE, 'utf8');
	}
	return null;
}

if (args[0] === '--keygen') {
	const out = path.join(root, 'coe-manifest.key');
	if (fs.existsSync(out)) {
		console.error('[ERRO] coe-manifest.key já existe; não sobrescrevo uma chave.');
		process.exit(1);
	}
	const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
	fs.writeFileSync(out, privateKey.export({ type: 'pkcs8', format: 'pem' }), { mode: 0o600 });
	console.log('[OK] Chave privada em coe-manifest.key (guarde como segredo COE_MANIFEST_KEY no GitHub e fora do repositório).');
	console.log('Chave pública para SupervisorConfig.Updater.PublicKey:\n');
	console.log(publicKey.export({ type: 'spki', format: 'pem' }));
	process.exit(0);
}

const body = fs.readFileSync(manifestPath, 'utf8');

if (args[0] === '--verify') {
	const publicKey = fs.readFileSync(args[1], 'utf8');
	const signature = fs.readFileSync(signaturePath, 'utf8').trim();
	const ok = crypto.verify(null, Buffer.from(body, 'utf8'), crypto.createPublicKey(publicKey), Buffer.from(signature, 'base64'));
	console.log(ok ? '[OK] Assinatura válida.' : '[ERRO] Assinatura inválida.');
	process.exit(ok ? 0 : 1);
}

const privateKey = readPrivateKey();
if (!privateKey) {
	console.error('[ERRO] Defina COE_MANIFEST_KEY (PEM) ou COE_MANIFEST_KEY_FILE.');
	process.exit(1);
}
const signature = crypto.sign(null, Buffer.from(body, 'utf8'), crypto.createPrivateKey(privateKey)).toString('base64');
fs.writeFileSync(signaturePath, signature + '\n');
console.log('[OK] version.json.sig gerado.');
