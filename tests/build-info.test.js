const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '..');
const directory = fs.mkdtempSync(path.join(process.env.TMPDIR || os.tmpdir(), 'doh-build-info-'));
try {
	const branch = 'feature/test\"branch\\path\nnext';
	execFileSync('sh', ['scripts/build-info.sh', directory], { cwd: root, env: { ...process.env, BUILD_BRANCH: branch } });
	const context = { window: {} };
	vm.runInNewContext(fs.readFileSync(path.join(directory, 'build-info.js'), 'utf8'), context);
	assert.equal(context.window.buildInfo.branch, branch);
	assert.equal(context.window.buildInfo.commit, execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim());
} finally {
	fs.rmSync(directory, { recursive: true, force: true });
}
