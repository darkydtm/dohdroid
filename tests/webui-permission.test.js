const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const { execFileSync, spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const dir = fs.mkdtempSync(path.join(process.env.TMPDIR || os.tmpdir(), 'webui-test-'));
try {
	const scripts = path.join(dir, 'scripts');
	const abi = execFileSync('uname', ['-m'], { encoding: 'utf8' }).trim();
	const names = { aarch64: 'arm64-v8a', armv7l: 'armeabi-v7a', armv8l: 'armeabi-v7a', arm: 'armeabi-v7a', x86_64: 'x86_64', i686: 'x86', i386: 'x86' };
	const bin = path.join(dir, 'system/bin', names[abi]);
	fs.mkdirSync(scripts, { recursive: true });
	fs.mkdirSync(bin, { recursive: true });
	fs.copyFileSync(path.join(root, 'module/scripts/webui.sh'), path.join(scripts, 'webui.sh'));
	fs.chmodSync(path.join(scripts, 'webui.sh'), 0o644);
	fs.writeFileSync(path.join(bin, 'dohd'), '#!/bin/sh\ncat >/dev/null\nprintf \'{"ok":true,"result":"ok"}\\n\'\n', { mode: 0o755 });
	const html = fs.readFileSync(path.join(root, 'module/webroot/index.html'), 'utf8');
	const request = html.slice(html.indexOf('\t\tlet callbackId = 0;'), html.indexOf('\t\tfunction validate()'));
	const context = { window: {}, Promise, JSON, Error };
	context.ksu = context.window.ksu = {
		exec(command, options, callback) {
			const result = spawnSync('sh', ['-c', command.replace('/data/adb/modules/doh-dns', dir)], { encoding: 'utf8' });
			context.window[callback](result.status, result.stdout, result.stderr);
		}
	};
	vm.createContext(context);
	vm.runInContext(request, context);
	context.request('status').then(result => assert.equal(result, 'ok')).catch(error => {
		console.error(error);
		process.exitCode = 1;
	});
} finally {
	fs.rmSync(dir, { recursive: true, force: true });
}
