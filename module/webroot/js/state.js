(() => {
  const MIN_TIMEOUT_MS = 100;
  const MAX_TIMEOUT_MS = 60000;
  const DEFAULT_COOLDOWN_SECONDS = 30;
  const formElements = {
    url: document.querySelector("#resolverUrl"),
    timeout: document.querySelector("#timeout"),
    fallback: document.querySelector("#fallback"),
    tunMode: document.querySelector("#tunMode"),
    killswitchMode: document.querySelector("#killswitchMode"),
    resolverError: document.querySelector("#resolverError"),
    timeoutError: document.querySelector("#timeoutError"),
  };
  const statusElements = {
    daemonStatus: document.querySelector("#daemonStatus"),
    daemonStatusText: document.querySelector("#daemonStatusText"),
  };
  const historyElements = {
    datalist: document.querySelector("#resolverHistory"),
    list: document.querySelector("#resolverHistoryList"),
  };
  const metricElements = {
    queries: document.querySelector("#queries"),
    errors: document.querySelector("#errors"),
  };

  function createHistoryOption(value) {
    const option = document.createElement("option");
    option.value = value;
    return option;
  }

  function createHistoryButton(value) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "history-item";
    button.textContent = value;
    button.addEventListener("click", () => {
      formElements.url.value = value;
      validate();
    });
    return button;
  }

  function renderHistory(config) {
    const entries = config.resolver_history || [];
    historyElements.datalist.replaceChildren(
      ...entries.map(createHistoryOption),
    );
    historyElements.list.replaceChildren(...entries.map(createHistoryButton));
  }

  function isValidUrl(value) {
    if (value === "") return true;
    try {
      const parsed = new URL(value);
      return (
        parsed.protocol === "https:" &&
        Boolean(parsed.hostname) &&
        parsed.pathname !== "/"
      );
    } catch {
      return false;
    }
  }

  function parseTimeout(value) {
    return Number.parseInt(value.trim().replace(/\s*ms\s*$/i, ""), 10);
  }

  function isValidTimeout(value) {
    const timeout = parseTimeout(value);
    return (
      Number.isInteger(timeout) &&
      timeout >= MIN_TIMEOUT_MS &&
      timeout <= MAX_TIMEOUT_MS
    );
  }

  function validate() {
    const urlValid = isValidUrl(formElements.url.value.trim());
    const timeoutValid = isValidTimeout(formElements.timeout.value);
    formElements.url.classList.toggle("invalid", !urlValid);
    formElements.timeout.classList.toggle("invalid", !timeoutValid);
    formElements.resolverError.textContent = urlValid
      ? ""
      : "Enter a valid HTTPS DoH URL or leave it empty for system DNS.";
    formElements.timeoutError.textContent = timeoutValid
      ? ""
      : "Use a timeout from 100 to 60000 ms.";
    return urlValid && timeoutValid;
  }

  function showDaemonStatus(state) {
    const statusViews = {
      running: {
        className: "running",
        label: "Running",
        description: "Daemon is enabled and accepting requests.",
      },
      stopped: {
        className: "stopped",
        label: "Stopped",
        description: state.enabled
          ? "Daemon is enabled but not running."
          : "Daemon is disabled. Settings are saved locally.",
      },
    };
    const view = statusViews[state.running ? "running" : "stopped"];
    statusElements.daemonStatus.className = `status-badge ${view.className}`;
    statusElements.daemonStatus.textContent = view.label;
    statusElements.daemonStatusText.textContent = view.description;
  }

  function selectResolver(config) {
    return (
      config.resolvers.find((resolver) => resolver.enabled) ||
      config.resolvers[0]
    );
  }

  function showNoResolvers() {
    formElements.url.value = "";
    formElements.tunMode.value = "off";
    formElements.killswitchMode.value = "off";
    formElements.tunMode.disabled = true;
    formElements.killswitchMode.disabled = true;
    statusElements.daemonStatusText.textContent =
      "No DoH resolver configured. System DNS is in use.";
  }

  function updateResolverSelection(config) {
    const resolver = selectResolver(config);
    if (!resolver) {
      showNoResolvers();
      return;
    }
    formElements.url.value = resolver.url;
    formElements.tunMode.disabled = false;
    formElements.killswitchMode.disabled = false;
  }

  async function updateMetrics(daemon) {
    if (!daemon.running) {
      metricElements.queries.textContent = "-";
      metricElements.errors.textContent = "-";
      return;
    }
    const status = await window.dohdApi.request("status");
    metricElements.queries.textContent = status.requests;
    metricElements.errors.textContent = status.errors;
  }

  async function fetchData() {
    const [daemon, config, tun, killswitch] = await Promise.all([
      window.dohdApi.stateRequest("daemon-status"),
      window.dohdApi.request("get_config"),
      window.dohdApi.stateRequest("tun-status"),
      window.dohdApi.stateRequest("killswitch-status"),
    ]);
    return { daemon, config, tun, killswitch };
  }

  async function renderData(data) {
    showDaemonStatus(data.daemon);
    formElements.tunMode.value = data.tun ? "on" : "off";
    formElements.killswitchMode.value = data.killswitch ? "on" : "off";
    await updateMetrics(data.daemon);
    updateResolverSelection(data.config);
    renderHistory(data.config);
    formElements.timeout.value = `${data.config.request_timeout_ms} ms`;
    formElements.fallback.value = data.config.fallback_mode;
    validate();
  }

  async function load(addLog, showError) {
    try {
      const data = await fetchData();
      await renderData(data);
      addLog("configuration loaded from daemon");
    } catch (error) {
      statusElements.daemonStatus.className = "status-badge stopped";
      statusElements.daemonStatus.textContent = "Unknown";
      statusElements.daemonStatusText.textContent =
        "Unable to check daemon state.";
      showError(error.message);
    }
  }

  function resetBootstrapIps(config, url) {
    const resolver = selectResolver(config);
    const active = resolver
      ? { ...resolver, bootstrap_ips: [...(resolver.bootstrap_ips || [])] }
      : {
          name: "custom",
          bootstrap_ips: [],
          enabled: true,
          cooldown_seconds: DEFAULT_COOLDOWN_SECONDS,
        };
    if (active.url !== url) active.bootstrap_ips = [];
    return active;
  }

  function buildNewConfig(config) {
    const next = { ...config };
    const url = formElements.url.value.trim();
    next.resolvers =
      url === ""
        ? []
        : [{ ...resetBootstrapIps(config, url), url, enabled: true }];
    next.request_timeout_ms = parseTimeout(formElements.timeout.value);
    next.fallback_mode = formElements.fallback.value;
    return next;
  }

  async function persistConfig(config) {
    await window.dohdApi.request("put_config", config);
    return window.dohdApi.request("get_config");
  }

  async function setModeIfDifferent(mode, enabled) {
    const current = await window.dohdApi.stateRequest(`${mode}-status`);
    if (current !== enabled) {
      await window.dohdApi.stateRequest(
        `${mode}-${enabled ? "enable" : "disable"}`,
      );
    }
  }

  async function syncModes() {
    await setModeIfDifferent("tun", formElements.tunMode.value === "on");
    await setModeIfDifferent(
      "killswitch",
      formElements.killswitchMode.value === "on",
    );
  }

  async function save(addLog, showError) {
    if (!validate()) return;
    try {
      const current = await window.dohdApi.request("get_config");
      const config = buildNewConfig(current);
      const persisted = await persistConfig(config);
      renderHistory(persisted);
      await syncModes();
      addLog("configuration saved; some changes require a daemon restart");
    } catch (error) {
      showError(error.message);
    }
  }

  window.dohdState = {
    formElements,
    statusElements,
    historyElements,
    metricElements,
    load,
    save,
    validate,
  };
})();
