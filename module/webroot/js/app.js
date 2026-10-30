(() => {
	const log = document.querySelector('#log');
	const addLog = (message) => {
		const line = document.createElement('div');
		line.textContent = `${new Date().toLocaleTimeString('en-GB')} ${message}`;
		log.append(line);
		log.scrollTop = log.scrollHeight;
	};
	const showError = (message) => addLog(`error: ${message}`);
	const { elements, load, save, validate } = window.dohdState;
	const { request, restartDaemon } = window.dohdApi;

	if (window.buildInfo) document.querySelector('#buildInfo').textContent = `Build: ${window.buildInfo.branch} @ ${window.buildInfo.commit}`;

	document.querySelector('#saveButton').addEventListener('click', () => save(addLog, showError));
	document.querySelector('#restartButton').addEventListener('click', async () => {
		try {
			await restartDaemon();
			addLog('daemon restarted');
			await load(addLog, showError);
		} catch (error) {
			showError(error.message);
		}
	});
	document.querySelector('#testButton').addEventListener('click', async () => {
		if (!validate()) return;
		try {
			await request('status');
			addLog('daemon is reachable');
		} catch (error) {
			showError(error.message);
		}
	});
	elements.url.addEventListener('input', validate);
	elements.timeout.addEventListener('input', validate);
	load(addLog, showError);
})();
