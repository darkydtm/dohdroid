(() => {
  const log = document.querySelector("#log");
  const addLog = (message) => {
    const line = document.createElement("div");
    line.textContent = `${new Date().toLocaleTimeString("en-GB")} ${message}`;
    log.append(line);
    log.scrollTop = log.scrollHeight;
  };
  const showError = (message) => addLog(`error: ${message}`);
  const { formElements, statusElements, load, save, validate } =
    window.dohdState;
  const { request, restartDaemon } = window.dohdApi;
  const themeMode = document.querySelector("#themeMode");
  const materialColors = document.querySelector("#materialColors");
  const themes = new Set(["white", "dark", "black"]);

  function applyTheme(theme, persist = true) {
    const selected = themes.has(theme) ? theme : "dark";
    document.documentElement.dataset.theme = selected;
    themeMode.value = selected;
    if (persist) {
      try {
        localStorage.setItem("dohd-theme", selected);
      } catch {}
    }
  }

  function initializeTheme() {
    let savedTheme = "dark";
    let useMaterialColors = true;
    try {
      savedTheme = localStorage.getItem("dohd-theme") || savedTheme;
      useMaterialColors =
        localStorage.getItem("dohd-material-colors") !== "false";
    } catch {}
    applyTheme(savedTheme, false);
    materialColors.checked = useMaterialColors;
    document.documentElement.dataset.materialColors = String(useMaterialColors);
    if (window.buildInfo)
      document.querySelector("#buildInfo").textContent =
        `Build: ${window.buildInfo.branch} @ ${window.buildInfo.commit}`;
  }

  function bindThemeEvents() {
    themeMode.addEventListener("change", () => applyTheme(themeMode.value));
    materialColors.addEventListener("change", () => {
      const enabled = materialColors.checked;
      document.documentElement.dataset.materialColors = String(enabled);
      try {
        localStorage.setItem("dohd-material-colors", String(enabled));
      } catch {}
    });
  }

  let buttonStates = [];
  function setBusy(isBusy) {
    if (isBusy) {
      buttonStates = [...document.querySelectorAll("button")].map((button) => [
        button,
        button.disabled,
      ]);
      buttonStates.forEach(([button]) => {
        button.disabled = true;
      });
      statusElements.daemonStatus.className = "status-badge loading";
      statusElements.daemonStatus.textContent = "Loading";
      statusElements.daemonStatusText.textContent = "Restarting daemon...";
      return;
    }
    buttonStates.forEach(([button, disabled]) => {
      button.disabled = disabled;
    });
    buttonStates = [];
  }

  async function refresh() {
    try {
      await restartDaemon();
      addLog("daemon restarted");
    } catch (error) {
      showError(error.message);
    } finally {
      try {
        await load(addLog, showError);
      } finally {
        setBusy(false);
      }
    }
  }

  function bindEvents() {
    document
      .querySelector("#saveButton")
      .addEventListener("click", () => save(addLog, showError));
    document
      .querySelector("#restartButton")
      .addEventListener("click", async () => {
        setBusy(true);
        await refresh();
      });
    document
      .querySelector("#testButton")
      .addEventListener("click", async () => {
        if (!validate()) return;
        try {
          await request("status");
          addLog("daemon is reachable");
        } catch (error) {
          showError(error.message);
        }
      });
    formElements.url.addEventListener("input", validate);
    formElements.timeout.addEventListener("input", validate);
  }

  initializeTheme();
  bindThemeEvents();
  bindEvents();
  load(addLog, showError);
})();
