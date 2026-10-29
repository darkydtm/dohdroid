# DoH DNS Magisk Module Design

## Goal

Build a Magisk module that redirects device DNS traffic to a Rust local proxy and resolves queries over DNS-over-HTTPS. The first release targets UDP and TCP DNS on port 53, supports multiple DoH resolvers, has a safe fallback, exposes a root-only Unix control socket, and provides an `action.sh` menu. The design must leave a stable control and configuration boundary for a future WebUI.

## Scope

Included:

- Rust daemon for UDP and TCP DNS listeners.
- DoH POST requests using `application/dns-message`.
- Resolver pool with bootstrap IPs, health checks, failover, and cooldown.
- Optional in-memory DNS cache.
- TOML configuration with validation and atomic reload.
- Unix socket control API with status, configuration, reload, resolver test, and cache clear operations.
- Magisk lifecycle scripts.
- Idempotent firewall rules for UDP and TCP DNS.
- `action.sh` interactive menu.
- CI builds for Android targets, initially including `aarch64-linux-android`.

Excluded from the first release:

- TUN mode.
- Full WebUI.
- DoT and DoQ.
- Per-application policy.
- Captive portal handling.
- Custom certificate management.

## Components

### Rust daemon

The daemon is divided into these boundaries:

- `config`: typed configuration, validation, atomic persistence, and reload state.
- `dns`: UDP and TCP listeners, DNS packet framing, query dispatch, and response serialization.
- `doh`: HTTPS DNS-message client using rustls, request timeouts, bootstrap IP support, and resolver health.
- `cache`: bounded TTL-aware in-memory cache.
- `control`: Unix socket request handling and versioned JSON API.
- `runtime`: startup, shutdown, metrics, health state, and signal handling.

The DNS layer must not know whether configuration comes from TOML or a future WebUI. It consumes an in-memory validated configuration snapshot. The control layer must call the same configuration and runtime services used by the daemon rather than modifying files directly.

### Configuration

The default file is `/data/adb/modules/doh-dns/config/config.toml`. Runtime state and the Unix socket live below `/data/adb/modules/doh-dns/run/`.

The configuration contains listener address and port, request and connection timeouts, cache settings, fallback mode, and an ordered list of resolvers. Each resolver has a stable name, HTTPS URL, bootstrap IPs, enabled state, and health cooldown settings.

Updates are validated before activation and persisted atomically. An invalid update leaves the last known-good snapshot active. A configuration must contain at least one enabled resolver, valid HTTPS URLs, valid ports, bounded timeouts, and valid IP literals for bootstrap addresses.

### Control API

The daemon listens only on the Unix socket `/data/adb/modules/doh-dns/run/dohd.sock`. The socket is created with root ownership and mode `0600`.

The API uses newline-delimited JSON requests and responses to avoid coupling the daemon to a future HTTP implementation. Every request includes an API version and operation name. Initial operations:

- `status`
- `get_config`
- `put_config`
- `reload`
- `test_resolvers`
- `clear_cache`
- `enable`
- `disable`

Responses include a success flag, an optional typed result, and a stable error code. A future WebUI backend can translate HTTP or WebSocket requests to this local API without embedding DNS behavior.

### Magisk scripts

`service.sh` runs in late start service mode:

1. Create runtime directories and permissions.
2. Wait for a usable network route.
3. Start `dohd` with the module configuration.
4. Wait for the daemon health endpoint over the Unix socket.
5. Detect the available firewall backend.
6. Install the module-owned redirect chains.
7. Start watchdog and network-change recovery logic.

The daemon starts before firewall rules are installed. If health checks fail, redirect rules are not installed. Rule installation and removal are idempotent and affect only chains owned by this module. UDP and TCP DNS traffic are redirected to the local listener. The daemon's own traffic is excluded by UID or firewall mark where supported.

`uninstall.sh` stops the daemon, removes only module-owned rules, removes runtime files, and leaves system DNS configuration untouched.

`action.sh` is a thin terminal menu. It invokes the control API for status, enable, disable, restart, resolver tests, cache clearing, and recent logs. It must not duplicate daemon or firewall logic.

## Runtime behavior

The resolver pool tries enabled resolvers in configured order. Failed resolvers enter a cooldown and become eligible again after the cooldown expires. A request has a total deadline and cannot wait indefinitely on one resolver.

The default fallback is `system`: when all DoH resolvers fail, remove or bypass the redirect and allow the system DNS path. Other explicit modes are `servfail` and `disabled`. The daemon must expose the active fallback state in status.

A bootstrap IP is used to avoid resolving the DoH hostname through the DNS path being intercepted. HTTPS certificate validation must still use the configured hostname, even when the connection uses a bootstrap IP. IPv6 and Android-specific network changes must not cause a permanent stale route; recovery logic rechecks connectivity and reinstalls only the module's rules.

Shutdown must remove redirect rules before exiting when possible. Unexpected termination is handled by watchdog and boot-time cleanup. All external commands are invoked with absolute paths or discovered safely, and failures are logged without treating partial firewall state as healthy.

## Security and safety

- Never listen on a non-loopback address in the first release.
- Keep the control socket root-only.
- Do not accept arbitrary shell commands through the control API.
- Validate resolver URLs and reject non-HTTPS schemes.
- Keep secrets out of logs and configuration. The first release has no credentials.
- Use unique chain names and verify ownership before deleting rules.
- Do not enable a redirect before a successful daemon health check.
- Preserve the last known-good configuration and provide a disable path.
- Bound packet sizes, request body sizes, queue lengths, and cache capacity.

## Build and packaging

The Rust binary is built in CI for Android targets and copied into the module package as `system/bin/dohd`. The module package contains metadata, lifecycle scripts, an example configuration, and the binary. The initial acceptance target is `aarch64-linux-android`; the packaging layout must allow adding `armv7`, `x86_64`, and `i686` binaries later.

The build must use the Android NDK linker and produce a device-compatible executable. CI verifies Rust formatting, linting, unit tests, target compilation, package layout, shell syntax, and a dry-run check of firewall script idempotency where device privileges are unavailable.

## Testing strategy

Rust tests cover configuration validation, atomic reload behavior, DNS UDP and TCP framing, DoH response handling with a mock HTTPS boundary, resolver failover, cooldown, fallback transitions, cache TTL behavior, control API validation, and bounded resource handling.

Shell tests cover argument handling, module path resolution, chain ownership checks, idempotent install, safe removal, and daemon health gating. Device validation is a separate optional job for a rooted Android test device and verifies DNS UDP/TCP redirection, DoH resolution, disable and uninstall cleanup, network loss recovery, and reboot persistence.

## Acceptance criteria

- A packaged module installs under Magisk and starts the Rust daemon after boot.
- UDP and TCP DNS queries can be answered through configured DoH resolvers.
- The daemon does not depend on resolving its own DoH hostname through intercepted DNS.
- Resolver failure triggers bounded failover and the configured fallback.
- Repeated service starts do not duplicate firewall rules.
- Disable and uninstall remove module-owned rules without changing unrelated rules.
- `action.sh` can show status and control the daemon through the Unix API.
- Configuration updates are validated, atomic, and visible through the same API boundary intended for a future WebUI.
- CI produces and verifies the Android package without requiring a local heavyweight build.
