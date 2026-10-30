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
			checked: selector === '#materialColors',
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
assert.equal(context.document.documentElement.dataset.materialColors, 'true');
listeners.get('#themeMode:change')();
assert.equal(context.document.documentElement.dataset.theme, 'black');

getElement('#themeMode').value = 'white';
listeners.get('#themeMode:change')();
assert.equal(context.document.documentElement.dataset.theme, 'white');
assert.equal(saved.get('dohd-theme'), 'white');

getElement('#materialColors').checked = false;
listeners.get('#materialColors:change')();
assert.equal(context.document.documentElement.dataset.materialColors, 'false');
assert.equal(saved.get('dohd-material-colors'), 'false');

getElement('#themeMode').value = 'invalid';
listeners.get('#themeMode:change')();
assert.equal(context.document.documentElement.dataset.theme, 'dark');
assert.equal(saved.get('dohd-theme'), 'dark');

const html = fs.readFileSync(path.join(root, 'module/webroot/index.html'), 'utf8');
assert.match(html, /class="card palette-card"/);
assert.match(html, /id="materialColors"/);
assert.doesNotMatch(html, /KernelSU module|brand-mark/);
assert.ok(html.indexOf('id="themeMode"') > html.indexOf('id="timeout"'));
const css = fs.readFileSync(path.join(root, 'module/webroot/styles.css'), 'utf8');
assert.match(css, /:root\[data-theme="black"\][\s\S]*?--md-sys-color-surface: #000000/);
assert.match(css, /--md-sys-color-surface-container: #0a1119/);