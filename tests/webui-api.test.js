(async () => {
  const assert = require("node:assert/strict");
  const fs = require("node:fs");
  const path = require("node:path");
  const vm = require("node:vm");

  const exportContext = {
    window: {},
    setTimeout,
    clearTimeout,
    module: { exports: {} },
  };
  vm.runInNewContext(
    fs.readFileSync(
      path.join(__dirname, "../module/webroot/js/api.js"),
      "utf8",
    ),
    exportContext,
  );
  const { shellQuote } = exportContext.module.exports;

  assert.equal(shellQuote("plain"), "'plain'");
  assert.equal(shellQuote("it's"), "'it'\\''s'");
  assert.equal(shellQuote("back\\slash"), "'back\\slash'");
  assert.equal(shellQuote("$HOME; `id` && *"), "'$HOME; `id` && *'");
  assert.equal(shellQuote(""), "''");

  let timeoutHandler;
  const context = {
    window: {},
    setTimeout: (callback) => {
      timeoutHandler = callback;
      return 1;
    },
    clearTimeout() {},
    module: undefined,
  };
  vm.createContext(context);
  vm.runInContext(
    fs.readFileSync(
      path.join(__dirname, "../module/webroot/js/api.js"),
      "utf8",
    ),
    context,
  );
  const api = context.window.dohdApi;
  assert.equal(
    await api.request("status").catch((error) => error.message),
    "KernelSU WebUI is required",
  );
  context.window.ksu = {
    exec(command, args, id) {
      assert.equal(args, "{}");
      context.window[id](0, JSON.stringify({ ok: true, result: "ok" }), "");
    },
  };
  assert.equal(await api.request("status"), "ok");
  assert.deepEqual(Object.keys(context.window.__dohd_callbacks), []);

  context.window.ksu.exec = () => {};
  const pending = api.request("status");
  assert.equal(Object.keys(context.window.__dohd_callbacks).length, 1);
  timeoutHandler();
  assert.equal(
    await pending.catch((error) => error.message),
    "KernelSU command timed out",
  );
  assert.deepEqual(Object.keys(context.window.__dohd_callbacks), []);
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
