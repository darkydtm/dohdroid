(() => {
  const SCRIPT_DIR = "/data/adb/modules/doh-dns/scripts";
  const WEBUI_SCRIPT = `${SCRIPT_DIR}/webui.sh`;
  const SERVICE_SCRIPT = "/data/adb/modules/doh-dns/service.sh";
  const CALLBACK_TIMEOUT_MS = 30000;
  let callbackId = 0;

  function shellQuote(value) {
    return `'${String(value).replace(/'/g, "'\\''")}'`;
  }

  function registerCallback(id, fn) {
    window.__dohd_callbacks = window.__dohd_callbacks || {};
    window.__dohd_callbacks[id] = fn;
    window[id] = (...args) => window.__dohd_callbacks[id]?.(...args);
  }

  function unregisterCallback(id) {
    if (window.__dohd_callbacks) delete window.__dohd_callbacks[id];
    delete window[id];
  }

  function ksuExec(command, args, handler) {
    return new Promise((resolve, reject) => {
      if (!window.ksu || typeof window.ksu.exec !== "function") {
        reject(new Error("KernelSU WebUI is required"));
        return;
      }
      const id = `dohdCallback${callbackId++}`;
      const timeout = setTimeout(() => {
        unregisterCallback(id);
        reject(new Error("KernelSU command timed out"));
      }, CALLBACK_TIMEOUT_MS);
      registerCallback(id, (code, stdout, stderr) => {
        clearTimeout(timeout);
        unregisterCallback(id);
        try {
          if (code !== 0) throw new Error(stderr || "KernelSU command failed");
          resolve(handler(code, stdout, stderr));
        } catch (error) {
          reject(error);
        }
      });
      try {
        window.ksu.exec(command, args, id);
      } catch (error) {
        clearTimeout(timeout);
        unregisterCallback(id);
        reject(error);
      }
    });
  }

  function stateRequest(operation) {
    return ksuExec(
      `sh ${WEBUI_SCRIPT} ${operation}`,
      "{}",
      (code, stdout) => JSON.parse(stdout).result,
    );
  }

  function request(operation, config) {
    const payload = JSON.stringify({ api_version: 1, operation, config });
    return ksuExec(
      `sh ${WEBUI_SCRIPT} ${shellQuote(payload)}`,
      "{}",
      (code, stdout) => {
        const response = JSON.parse(stdout);
        if (!response.ok)
          throw new Error(response.error_code || "Request rejected");
        return response.result;
      },
    );
  }

  function restartDaemon() {
    return ksuExec(`sh ${SERVICE_SCRIPT}`, "{}", () => undefined);
  }

  window.dohdApi = { request, restartDaemon, stateRequest };
  if (typeof module !== "undefined") module.exports = { shellQuote };
})();
