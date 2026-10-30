(() => {
	let callbackId = 0;

	function tunRequest(operation) {
		return new Promise((resolve, reject) => {
			if (!window.ksu) {
				reject(new Error('KernelSU WebUI is required'));
				return;
			}
			const callback = `dohdCallback${callbackId++}`;
			window[callback] = (code, stdout, stderr) => {
				delete window[callback];
				if (code !== 0) {
					reject(new Error(stderr || 'TUN operation failed'));
					return;
				}
				try {
					resolve(JSON.parse(stdout).result);
				} catch (error) {
					reject(error);
				}
			};
			try {
				ksu.exec(`sh /data/adb/modules/doh-dns/scripts/webui.sh ${operation}`, '{}', callback);
			} catch (error) {
				delete window[callback];
				reject(error);
			}
		});
	}

	function request(operation, config) {
		return new Promise((resolve, reject) => {
			if (!window.ksu) {
				reject(new Error('KernelSU WebUI is required'));
				return;
			}
			const payload = JSON.stringify({ api_version: 1, operation, config });
			const quoted = `'${payload.replace(/'/g, "'\\''")}'`;
			const callback = `dohdCallback${callbackId++}`;
			window[callback] = (code, stdout, stderr) => {
				delete window[callback];
				if (code !== 0) {
					reject(new Error(stderr || 'Daemon is unavailable'));
					return;
				}
				try {
					const response = JSON.parse(stdout);
					if (!response.ok) throw new Error(response.error_code || 'Request rejected');
					resolve(response.result);
				} catch (error) {
					reject(error);
				}
			};
			try {
				ksu.exec(`sh /data/adb/modules/doh-dns/scripts/webui.sh ${quoted}`, '{}', callback);
			} catch (error) {
				delete window[callback];
				reject(error);
			}
		});
	}

	function restartDaemon() {
		return new Promise((resolve, reject) => {
			if (!window.ksu) {
				reject(new Error('KernelSU WebUI is required'));
				return;
			}
			const callback = `dohdCallback${callbackId++}`;
			window[callback] = (code, stdout, stderr) => {
				delete window[callback];
				if (code !== 0) reject(new Error(stderr || 'Daemon restart failed'));
				else resolve();
			};
			try {
				ksu.exec('sh /data/adb/modules/doh-dns/service.sh', '{}', callback);
			} catch (error) {
				delete window[callback];
				reject(error);
			}
		});
	}

	window.dohdApi = { request, restartDaemon, tunRequest };
})();
