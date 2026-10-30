const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const nodes = new Map();
const listeners = new Map();
function node(selector) {
	if (!nodes.has(selector)) nodes.set(selector, {
		disabled: false,
		value: selector === '#resolverUrl' ? 'https://example.com/dns' : selector === '#timeout' ? '5000 ms' : 'off',
		classList: { toggle() {} },
		addEventListener(event, callback) { listeners.set(`${selector}:${event}`, callback); },
		replaceChildren() {}, append() {},
	});
	return nodes.get(selector);
}
let restarted = 0;
let resolveRestart;
const config = { resolvers: [{ enabled: true, url: 'https://example.com/dns' }], request_timeout_ms: 5000, fallback_mode: 'system' };
const api = {
	async request(operation) { return operation === 'get_config' ? config : {}; },
	async stateRequest(operation) { return operation === 'daemon-status' ? { enabled: true, running: false } : false; },
	restartDaemon() { restarted++; if (restarted === 1) return Promise.resolve(); return new Promise((resolve) => { resolveRestart = resolve; }); },
};
const document = {
	documentElement: { dataset: {} },
	querySelector: node,
	querySelectorAll: () => [node('#saveButton'), node('#testButton'), node('#restartButton')],
	createElement: () => ({ addEventListener() {} }),
};
const context = { document, window: { dohdApi: api }, localStorage: { getItem() {}, setItem() {} }, URL, Date, Set };
vm.createContext(context);
vm.runInContext(fs.readFileSync(path.join(root, 'module/webroot/js/state.js'), 'utf8'), context);
(async () => {
	await context.window.dohdState.save(() => {}, (error) => { throw Error(error); });
	assert.equal(restarted, 0, 'saving must not restart the daemon');
	restarted = 1;
	vm.runInContext(fs.readFileSync(path.join(root, 'module/webroot/js/app.js'), 'utf8'), context);
	const pending = listeners.get('#restartButton:click')();
	assert.equal(node('#saveButton').disabled, true);
	assert.equal(node('#testButton').disabled, true);
	assert.equal(node('#restartButton').disabled, true);
	assert.match(node('#daemonStatus').textContent, /loading/i);
	resolveRestart();
	await pending;
	assert.equal(node('#saveButton').disabled, false);
	assert.equal(node('#testButton').disabled, false);
	assert.equal(node('#restartButton').disabled, false);
})().catch((error) => { console.error(error); process.exitCode = 1; });
