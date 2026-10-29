# DoH DNS Magisk Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Magisk module with a Rust UDP/TCP DNS proxy, DoH resolver pool, safe firewall lifecycle, root-only control socket, and an Action menu ready for a future WebUI.

**Architecture:** A Tokio Rust daemon listens only on loopback, parses DNS packets, forwards DNS wire messages over HTTPS to configured DoH endpoints, and exposes a versioned newline-delimited JSON Unix API. Magisk shell scripts own lifecycle and firewall chains; the daemon owns DNS, resolver, cache, configuration, metrics, and control behavior. Configuration is accessed through a service boundary so a future WebUI does not modify DNS internals.

**Tech Stack:** Rust stable, Tokio, Hickory DNS protocol, Reqwest with rustls, Serde, TOML, tracing, POSIX shell, Magisk late-start service, iptables or nftables, GitHub Actions, Android NDK.

**Spec:** `.superpowers/specs/2026-10-29-doh-magisk-module-design.md`

## Global Constraints

- Listen only on `127.0.0.1` and never expose the first-release daemon remotely.
- Use UDP and TCP DNS on a configurable local port, defaulting to `5353`.
- Send DoH POST requests with `application/dns-message`.
- Validate and require HTTPS resolver URLs and valid bootstrap IP literals.
- Use bootstrap IPs without disabling TLS hostname verification.
- Keep the control socket at `/data/adb/modules/doh-dns/run/dohd.sock`, owned by root, mode `0600`.
- Activate only validated configurations and preserve the last known-good configuration.
- Install firewall redirects only after daemon health succeeds.
- Modify and remove only module-owned firewall chains.
- Default all-resolver failure behavior to `system` fallback.
- Bound packet sizes, request sizes, queue sizes, timeouts, and cache capacity.
- Build the first Android artifact for `aarch64-linux-android` in CI; keep packaging extensible for other ABIs.
- Keep plans and specifications untracked and out of Git.

## Review Focus

1. DNS loop prevention: daemon-originated DoH traffic must not be redirected back into the local DNS listener. Test with firewall exclusion and a mock resolver.
2. TLS bootstrap correctness: connecting to a bootstrap IP must still verify the configured DoH hostname. Test a hostname/IP mismatch and a valid certificate.
3. Partial firewall state: failed or interrupted installation must not be reported healthy and cleanup must remove only owned rules. Test duplicate install and partial teardown.
4. Oversized and malformed DNS/control input: reject bounded-invalid data without panic or unbounded allocation. Test UDP, TCP, and Unix socket frames.
5. Network and resolver failure: all resolvers failing must enter the configured fallback and recover after cooldown without a stuck redirect. Test state transitions with fake clocks.

---

### Task 1: Scaffold the Rust daemon and CI foundation

**Files:**
- Create: `Cargo.toml`
- Create: `src/main.rs`
- Create: `src/lib.rs`
- Create: `.rustfmt.toml`
- Create: `rust-toolchain.toml`
- Create: `.github/workflows/ci.yml`
- Create: `tests/smoke.rs`

**Interfaces:**
- Produces crate modules `config`, `dns`, `doh`, `cache`, `control`, and `runtime` for later tasks.
- Produces CI commands for formatting, tests, linting, and Android target compilation.

- [ ] **Step 1: Write the failing smoke test**

Create a test that imports the crate and asserts the public version constant is non-empty.

- [ ] **Step 2: Run the test and verify it fails**

Run: `cargo test`
Expected: FAIL because the crate and version constant do not exist.

- [ ] **Step 3: Add the crate skeleton and dependencies**

Define the library modules, a binary entry point, and pinned dependency ranges for Tokio, Hickory protocol, Reqwest rustls, Serde, TOML, tracing, and Unix socket support. Keep the binary entry point limited to argument parsing and runtime startup delegation.

- [ ] **Step 4: Add CI validation**

Configure CI to run `cargo fmt --check`, `cargo test`, `cargo clippy --all-targets --all-features -- -D warnings`, and target compilation for `aarch64-linux-android`. Install the Android target and use the NDK linker supplied by the runner.

- [ ] **Step 5: Run the foundation checks**

Run: `cargo fmt --check && cargo test && cargo clippy --all-targets --all-features -- -D warnings`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Cargo.toml Cargo.lock src tests .rustfmt.toml rust-toolchain.toml .github/workflows/ci.yml
git commit -m "add Rust daemon foundation"
```

### Task 2: Implement validated configuration and atomic persistence

**Files:**
- Create: `src/config.rs`
- Create: `tests/config_tests.rs`
- Create: `config/config.toml.example`

**Interfaces:**
- Produces `Config`, `ResolverConfig`, `FallbackMode`, `ConfigStore`, `ConfigError`, and `ConfigStore::load`, `ConfigStore::replace`, `ConfigStore::reload`.
- `ConfigStore` returns immutable validated snapshots to DNS and control services.

- [ ] **Step 1: Write tests for valid defaults, invalid schemes, invalid IPs, empty enabled resolvers, and atomic replacement**

Assert that valid TOML loads, `http://` is rejected, malformed bootstrap IPs are rejected, zero enabled resolvers are rejected, and a failed replacement leaves the previous file and snapshot intact.

- [ ] **Step 2: Run the tests and verify they fail**

Run: `cargo test --test config_tests`
Expected: FAIL because configuration types and validation are absent.

- [ ] **Step 3: Implement typed configuration and validation**

Use Serde TOML deserialization, explicit bounds for ports/timeouts/cache capacity, URL parsing, HTTPS enforcement, IP parsing, and resolver uniqueness. Provide defaults matching the design.

- [ ] **Step 4: Implement atomic writes and reload**

Write a validated configuration to a temporary file in the same directory, flush it, rename it into place, and update the in-memory snapshot only after success. Keep the previous snapshot on every error.

- [ ] **Step 5: Run the configuration tests**

Run: `cargo test --test config_tests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/config.rs tests/config_tests.rs config/config.toml.example
 git commit -m "add validated configuration store"
```

### Task 3: Implement DNS UDP/TCP framing and bounded dispatch

**Files:**
- Create: `src/dns.rs`
- Create: `tests/dns_tests.rs`

**Interfaces:**
- Produces `DnsServer`, `DnsHandler`, `DnsQuery`, and `DnsResponse` interfaces.
- `DnsHandler::handle(query)` returns a DNS wire response or a typed failure without knowing the DoH transport implementation.

- [ ] **Step 1: Write tests for UDP round-trip, TCP two-byte framing, malformed packets, and size limits**

Use a fake handler that returns a deterministic DNS response. Assert malformed and oversized frames are rejected without panic.

- [ ] **Step 2: Run the tests and verify they fail**

Run: `cargo test --test dns_tests`
Expected: FAIL because listeners and framing are absent.

- [ ] **Step 3: Implement Hickory wire parsing and UDP/TCP listeners**

Bind configurable loopback endpoints, cap packet and TCP frame sizes, preserve the query ID, and pass validated wire messages to `DnsHandler`. Use bounded Tokio tasks and graceful shutdown.

- [ ] **Step 4: Run the DNS tests**

Run: `cargo test --test dns_tests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/dns.rs tests/dns_tests.rs
git commit -m "add bounded DNS listeners"
```

### Task 4: Implement DoH client, bootstrap transport, resolver pool, and fallback

**Files:**
- Create: `src/doh.rs`
- Create: `src/resolver.rs`
- Create: `tests/resolver_tests.rs`
- Create: `tests/doh_tests.rs`

**Interfaces:**
- Produces `DohClient::resolve`, `ResolverPool::resolve`, `ResolverPool::status`, and `FallbackMode` transitions consumed by runtime and DNS dispatch.

- [ ] **Step 1: Write tests for DoH content type, failover order, cooldown, bootstrap TLS hostname verification, and fallback transitions**

Run a local mock HTTPS boundary and fake clock. Assert failed resolvers are skipped during cooldown, valid certificates use the configured hostname, and all failures produce `system`, `servfail`, or `disabled` behavior exactly as configured.

- [ ] **Step 2: Run the tests and verify they fail**

Run: `cargo test --test doh_tests --test resolver_tests`
Expected: FAIL because the DoH client and pool do not exist.

- [ ] **Step 3: Implement bounded DoH requests**

POST raw DNS wire data with `application/dns-message`, enforce connection and total deadlines, cap response bodies, use bootstrap IPs while retaining TLS hostname verification, and reject malformed DNS responses.

- [ ] **Step 4: Implement resolver health and fallback state**

Track per-resolver failures and cooldown deadlines, try enabled resolvers in order, expose active resolver and error state, and return explicit fallback decisions when the pool is unavailable.

- [ ] **Step 5: Run the DoH and resolver tests**

Run: `cargo test --test doh_tests --test resolver_tests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/doh.rs src/resolver.rs tests/doh_tests.rs tests/resolver_tests.rs
git commit -m "add DoH resolver pool"
```

### Task 5: Add bounded DNS cache and runtime metrics

**Files:**
- Create: `src/cache.rs`
- Create: `src/runtime.rs`
- Create: `tests/cache_tests.rs`

**Interfaces:**
- Produces `DnsCache::get`, `DnsCache::insert`, `DnsCache::clear`, and `RuntimeStatus` used by the control API and DNS handler.

- [ ] **Step 1: Write tests for TTL expiry, capacity eviction, cache hits, and clear**

Use a fake clock and assert expired records never return, capacity stays bounded, and clear removes all entries.

- [ ] **Step 2: Run the tests and verify they fail**

Run: `cargo test --test cache_tests`
Expected: FAIL because cache and runtime status are absent.

- [ ] **Step 3: Implement TTL-aware bounded cache**

Cache raw DNS responses with expiry derived from DNS TTL, enforce configured capacity, and keep hit/miss counters. Never cache failed or fallback responses.

- [ ] **Step 4: Implement runtime state and shutdown**

Add uptime, request/error counters, active resolver, fallback state, last error, graceful cancellation, and signal handling. Keep external firewall cleanup behind a separate lifecycle command boundary.

- [ ] **Step 5: Run tests and commit**

Run: `cargo test --test cache_tests`
Expected: PASS.

```bash
git add src/cache.rs src/runtime.rs tests/cache_tests.rs
git commit -m "add DNS cache and runtime status"
```

### Task 6: Implement the versioned Unix control API

**Files:**
- Create: `src/control.rs`
- Create: `tests/control_tests.rs`

**Interfaces:**
- Produces newline-delimited JSON operations `status`, `get_config`, `put_config`, `reload`, `test_resolvers`, `clear_cache`, `enable`, and `disable`.
- Produces stable response fields `ok`, `api_version`, `result`, and `error_code`.

- [ ] **Step 1: Write tests for permissions, malformed JSON, unknown operations, configuration replacement, status, and cache clear**

Assert malformed or oversized lines are rejected, unknown operations return stable errors, and mutation operations call shared services rather than editing files directly.

- [ ] **Step 2: Run the tests and verify they fail**

Run: `cargo test --test control_tests`
Expected: FAIL because the socket server and operation handlers are absent.

- [ ] **Step 3: Implement the root-only Unix socket server**

Create the parent directory, unlink only a stale socket owned by the daemon, bind the socket, set mode `0600`, cap line length and concurrent clients, and dispatch operations through configuration, resolver, cache, and runtime services.

- [ ] **Step 4: Run the control API tests**

Run: `cargo test --test control_tests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/control.rs tests/control_tests.rs
 git commit -m "add versioned Unix control API"
```

### Task 7: Add daemon composition, module scripts, and firewall ownership

**Files:**
- Modify: `src/main.rs`
- Create: `module.prop`
- Create: `service.sh`
- Create: `uninstall.sh`
- Create: `action.sh`
- Create: `scripts/firewall.sh`
- Create: `scripts/lifecycle.sh`
- Create: `scripts/status.sh`
- Create: `tests/shell/firewall_test.sh`
- Create: `tests/shell/lifecycle_test.sh`

**Interfaces:**
- Produces a packaged Magisk module with `system/bin/dohd`, configuration, runtime directory, and scripts.
- `firewall.sh` exposes `detect`, `install`, `remove`, and `status` operations and never removes rules outside owned chains.

- [ ] **Step 1: Write shell tests for detection, idempotent install, ownership checks, health gating, and safe removal**

Use fake `iptables`, `iptables-legacy`, `nft`, and `dohd` commands in a temporary PATH. Assert duplicate installation is harmless and foreign chains remain untouched.

- [ ] **Step 2: Run shell tests and verify they fail**

Run: `bash tests/shell/firewall_test.sh && bash tests/shell/lifecycle_test.sh`
Expected: FAIL because scripts are absent.

- [ ] **Step 3: Implement firewall backend abstraction**

Detect usable `iptables`/`iptables-legacy`/`nft`, create module-owned chains, redirect UDP and TCP port 53 to the local listener, exclude daemon traffic, verify ownership before removal, and return failure for partial state.

- [ ] **Step 4: Implement lifecycle and action scripts**

Start the daemon before installing rules, wait for the Unix health response, run watchdog/recovery logic, remove rules before shutdown, and make `action.sh` a thin menu over the control API. Use absolute paths where available and quote all paths.

- [ ] **Step 5: Add module packaging**

Place the compiled daemon at `system/bin/dohd`, install the example configuration, set executable permissions, and include only module-owned files.

- [ ] **Step 6: Run shell tests and commit**

Run: `bash tests/shell/firewall_test.sh && bash tests/shell/lifecycle_test.sh`
Expected: PASS.

```bash
git add src/main.rs module.prop service.sh uninstall.sh action.sh scripts tests/shell
 git commit -m "add Magisk lifecycle and firewall scripts"
```

### Task 8: Add CI packaging and release verification

**Files:**
- Modify: `.github/workflows/ci.yml`
- Create: `package.sh`
- Create: `tests/package_test.sh`
- Create: `.gitignore`

**Interfaces:**
- Produces a reproducible module ZIP artifact for `aarch64-linux-android`.
- Package validation checks metadata, executable binary, scripts, configuration, and absence of build or secret files.

- [ ] **Step 1: Write package validation tests**

Assert required paths exist, scripts are executable, `module.prop` contains the module ID, the binary targets Android ARM64, and no temporary or secret files are included.

- [ ] **Step 2: Run the package test and verify it fails**

Run: `bash tests/package_test.sh`
Expected: FAIL because the package builder and artifact are absent.

- [ ] **Step 3: Implement reproducible packaging**

Build or consume the CI-produced Android binary, copy module files into a staging directory, normalize permissions and timestamps where practical, create the ZIP, and emit its SHA-256 checksum.

- [ ] **Step 4: Extend CI**

Run package tests, build the Android binary with the NDK linker, package the module, upload the ZIP and checksum as CI artifacts, and keep device tests optional.

- [ ] **Step 5: Run complete verification**

Run: `cargo fmt --check && cargo test && cargo clippy --all-targets --all-features -- -D warnings && bash tests/shell/firewall_test.sh && bash tests/shell/lifecycle_test.sh && bash tests/package_test.sh`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/ci.yml package.sh tests/package_test.sh .gitignore
git commit -m "add Android module packaging pipeline"
```

## Final verification

After all tasks, run the complete CI-equivalent suite from a clean branch checkout. Inspect the generated ZIP listing and verify the binary architecture with `file` or `readelf`. On a rooted Android test device, install the module, verify UDP and TCP DNS resolution, query the Unix status API, exercise `action.sh`, disable the module, reboot, and uninstall. Do not claim device acceptance from host-only tests.
