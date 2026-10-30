const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const listeners = new Map();
const elements = new Map();
const getElement = (selector) => {
	if (!elements.has(selector)) {
		elements.set(selector, {
			addEventListener: (event, callback) => listeners.set(`${selector}:${event}`, callback),
			append() {},
		scrollHeight: 0,
		scrollTop: 0,
		value: '',
		textContent: '',
	});
	}
	return elements.get(selector);
};
const saved = new Map([['dohd-theme', 'black']]);
const context = {
	Date,
	Set,
	document: {
		documentElement: { dataset: {} },
		querySelector: getElement,
	},
	localStorage: {
		getItem: (key) => saved.get(key) || null,
		setItem: (key, value) => saved.set(key, value),
	},
	window: {
		dohdState: { elements: { url: getElement('#resolverUrl'), timeout: getElement('#timeout') }, load() {}, save() {}, validate() { return true; } },
		dohdApi: { request: async () => ({}), restartDaemon: async () => {} },
	},
};
vm.createContext(context);
vm.runInContext(fs.readFileSync(path.join(root, 'module/webroot/js/app.js'), 'utf8'), context);

assert.equal(context.document.documentElement.dataset.theme, 'black');
assert.equal(getElement('#themeMode').value, 'black');
listeners.get('#themeMode:change')();
assert.equal(context.document.documentElement.dataset.theme, 'black');

getElement('#themeMode').value = 'white';
listeners.get('#themeMode:change')();
assert.equal(context.document.documentElement.dataset.theme, 'white');
assert.equal(saved.get('dohd-theme'), 'white');

getElement('#themeMode').value = 'invalid';
listeners.get('#themeMode:change')();
assert.equal(context.document.documentElement.dataset.theme, 'dark');
assert.equal(saved.get('dohd-theme'), 'dark');