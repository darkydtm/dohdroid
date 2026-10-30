(() => {
	const elements = {
		url: document.querySelector('#resolverUrl'),
		timeout: document.querySelector('#timeout'),
		fallback: document.querySelector('#fallback'),
		tunMode: document.querySelector('#tunMode'),
		killswitchMode: document.querySelector('#killswitchMode'),
		history: document.querySelector('#resolverHistory'),
		historyList: document.querySelector('#resolverHistoryList'),
		resolverError: document.querySelector('#resolverError'),
		timeoutError: document.querySelector('#timeoutError'),
		queries: document.querySelector('#queries'),
		errors: document.querySelector('#errors'),
		daemonStatus: document.querySelector('#daemonStatus'),
		daemonStatusText: document.querySelector('#daemonStatusText'),
	};

	function showHistory(config) {
		const history = config.resolver_history || [];
		elements.history.replaceChildren(...history.map((value) => {
			const option = document.createElement('option');
			option.value = value;
			return option;
		}));
		elements.historyList.replaceChildren(...history.map((value) => {
			const button = document.createElement('button');
			button.type = 'button';
			button.className = 'history-item';
			button.textContent = value;
			button.addEventListener('click', () => {
				elements.url.value = value;
				validate();
			});
			return button;
		}));
	}

	function validate() {
		const value = elements.url.value.trim();
		let parsed;
		try {
			parsed = new URL(value);
		} catch {
			parsed = null;
		}
		const urlValid = Boolean(parsed && parsed.protocol === 'https:' && parsed.hostname && parsed.pathname !== '/');
		const timeoutValue = Number.parseInt(elements.timeout.value.trim().replace(/\s*ms\s*$/i, ''), 10);
		const timeoutValid = Number.isInteger(timeoutValue) && timeoutValue >= 100 && timeoutValue <= 60000;
		elements.url.classList.toggle('invalid', !urlValid);
		elements.timeout.classList.toggle('invalid', !timeoutValid);
		elements.resolverError.textContent = urlValid ? '' : 'Enter a valid HTTPS DoH URL.';
		elements.timeoutError.textContent = timeoutValid ? '' : 'Use a timeout from 100 to 60000 ms.';
		return urlValid && timeoutValid;
	}

	function showDaemonStatus(status) {
		const running = Boolean(status.running);
		elements.daemonStatus.className = `status-badge ${running ? 'running' : 'stopped'}`;
		elements.daemonStatus.textContent = running ? 'Running' : 'Stopped';
		elements.daemonStatusText.textContent = status.enabled
			? (running ? 'Daemon is enabled and accepting requests.' : 'Daemon is enabled but not running.')
			: 'Daemon is disabled. Settings are saved locally.';
	}

	async function load(addLog, showError) {
		try {
			const [daemon, config, tun, killswitch] = await Promise.all([
				window.dohdApi.stateRequest('daemon-status'),
				window.dohdApi.request('get_config'),
				window.dohdApi.stateRequest('tun-status'),
				window.dohdApi.stateRequest('killswitch-status'),
			]);
			showDaemonStatus(daemon);
			elements.tunMode.value = tun ? 'on' : 'off';
			elements.killswitchMode.value = killswitch ? 'on' : 'off';
			if (daemon.running) {
				const status = await window.dohdApi.request('status');
				elements.queries.textContent = status.requests;
				elements.errors.textContent = status.errors;
			} else {
				elements.queries.textContent = '-';
				elements.errors.textContent = '-';
			}
			const resolver = config.resolvers.find((item) => item.enabled) || config.resolvers[0];
			if (resolver) elements.url.value = resolver.url;
			showHistory(config);
			elements.timeout.value = `${config.request_timeout_ms} ms`;
			elements.fallback.value = config.fallback_mode;
			validate();
			addLog('configuration loaded from daemon');
		} catch (error) {
			showError(error.message);
		}
	}

	async function save(addLog, showError) {
		if (!validate()) return;
		try {
			const config = await window.dohdApi.request('get_config');
			const active = config.resolvers.find((item) => item.enabled) || config.resolvers[0];
			if (!active) throw new Error('No resolver configured');
			if (active.url !== elements.url.value.trim()) active.bootstrap_ips = [];
			active.url = elements.url.value.trim();
			config.request_timeout_ms = Number.parseInt(elements.timeout.value, 10);
			config.fallback_mode = elements.fallback.value;
			await window.dohdApi.request('put_config', config);
			showHistory(await window.dohdApi.request('get_config'));
			const tun = elements.tunMode.value === 'on';
			if (tun !== await window.dohdApi.stateRequest('tun-status')) await window.dohdApi.stateRequest(tun ? 'tun-enable' : 'tun-disable');
			const killswitch = elements.killswitchMode.value === 'on';
			if (killswitch !== await window.dohdApi.stateRequest('killswitch-status')) await window.dohdApi.stateRequest(killswitch ? 'killswitch-enable' : 'killswitch-disable');
			const daemon = await window.dohdApi.stateRequest('daemon-status');
			if (daemon.enabled) {
				await window.dohdApi.restartDaemon();
				addLog('configuration saved and daemon restarted');
			} else {
				addLog('configuration saved while daemon is stopped');
			}
		} catch (error) {
			showError(error.message);
		}
	}

	window.dohdState = { elements, load, save, validate };
})();
