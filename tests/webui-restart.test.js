const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const nodes = new Map();
const listeners = new Map();
const INITIAL_VALUES = { '#resolverUrl': 'https://example.com/dns', '#timeout': '5000 ms' };
const CONFIG = { resolvers: [{ enabled: true, url: INITIAL_VALUES['#resolverUrl'] }], request_timeout_ms: 5000, fallback_mode: 'system' };
function createInitialValues() {
	return { ...INITIAL_VALUES };
}
function createElement(selector) {
	return {
		disabled: false,
		value: createInitialValues()[selector] || 'off',
		classList: { toggle() {} },
		addEventListener(event, callback) { listeners.set(`${selector}:${event}`, callback); },
		replaceChildren() {}, append() {},
	};
}
function node(selector) {
	if (!nodes.has(selector)) nodes.set(selector, createElement(selector));
	return nodes.get(selector);
}
let restartCalls = 0;
let resolveRestart;
const config = CONFIG;
const api = {
	async request(operation) { return operation === 'get_config' ? config : {}; },
	async stateRequest(operation) { return operation === 'daemon-status' ? { enabled: true, running: false } : false; },
	restartDaemon() { restartCalls++; return new Promise((resolve) => { resolveRestart = resolve; }); },
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
	assert.equal(restartCalls, 0, 'saving must not restart the daemon');
	vm.runInContext(fs.readFileSync(path.join(root, 'module/webroot/js/app.js'), 'utf8'), context);
	const restartPendingScenario = listeners.get('#restartButton:click')();
	const pending = restartPendingScenario;
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
