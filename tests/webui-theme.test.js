const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const listeners = new Map();
const elements = new Map();
function createElement(selector) {
	return {
		addEventListener: (event, callback) => listeners.set(`${selector}:${event}`, callback),
		append() {}, checked: selector === '#materialColors', scrollHeight: 0, scrollTop: 0, value: '', textContent: '',
	};
}
const getElement = (selector) => {
	if (!elements.has(selector)) elements.set(selector, createElement(selector));
	return elements.get(selector);
};
function createEnvironment() {
	const saved = new Map([['dohd-theme', 'black']]);
	const context = {
		Date, Set,
		document: { documentElement: { dataset: {} }, querySelector: getElement },
		localStorage: {
			getItem: (key) => saved.get(key) || null,
			setItem: (key, value) => saved.set(key, value),
		},
		window: {
			dohdState: { elements: { url: getElement('#resolverUrl'), timeout: getElement('#timeout') }, load() {}, save() {}, validate() { return true; } },
			dohdApi: { request: async () => ({}), restartDaemon: async () => {} },
		},
	};
	return { context, saved };
}
const { context, saved } = createEnvironment();
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
function declarationsFor(selector) {
	const start = css.indexOf(`${selector} {`);
	assert.notEqual(start, -1, `missing selector: ${selector}`);
	const end = css.indexOf('}', start);
	return Object.fromEntries(css.slice(start, end).split(';').map((line) => line.trim()).filter((line) => line.startsWith('--')).map((line) => {
		const separator = line.indexOf(':');
		return [line.slice(0, separator).trim(), line.slice(separator + 1).trim()];
	}));
}
assert.equal(declarationsFor(':root[data-theme="black"]')['--md-sys-color-surface'], '#000000');
assert.ok(css.includes('--md-sys-color-surface-container: #0a1119;'));
assert.ok(css.includes('@import url("https://mui.kernelsu.org/internal/colors.css")'));
assert.ok(css.indexOf('@import url("https://mui.kernelsu.org/internal/colors.css")') < css.indexOf(':root[data-theme="black"]'));
const rootBlockStart = css.indexOf(':root,\n:root[data-theme="dark"] {');
assert.notEqual(rootBlockStart, -1);
const rootBlockEnd = css.indexOf('}', rootBlockStart);
const defaultMaterialColors = css.slice(rootBlockStart, rootBlockEnd).split(';').map((line) => line.trim()).filter((line) => line.startsWith('--')).map((line) => line.slice(line.indexOf(':') + 2));
for (const declaration of [
	'--md-sys-color-primary: var(--primary, #b9c8ff)',
	'--md-sys-color-on-surface: var(--onSurface, #e2e2e9)',
	'--md-sys-color-surface-container: var(--surfaceContainer, #1d2026)',
]) {
	assert.ok(Object.values(defaultMaterialColors).includes(declaration.slice(declaration.indexOf(':') + 2)), `missing CSS declaration: ${declaration}`);
}
