# TUN configuration notes

`tun.json` is strict JSON consumed by sing-box; keep comments in this companion document so the configuration remains compatible with existing loaders.

- `dns.servers[0].server_port` (`5353`) is the local UDP listener port for dohd. It is **not** an audio or multicast port. `service.sh` substitutes the configured `listen_port` into the runtime copy (`run/tun.json`); the checked-in value is the fallback/default.
- `inbounds[0].interface_name` (`dohdtun0`) names the virtual TUN network interface. `service.sh` and `tun-firewall.sh` currently expect this name; changing it requires updating those consumers together.
- `inbounds[0].address` contains private IPv4 (`172.30.253.1/30`) and IPv6 (`fdfe:dcba:9876::1/126`) interface prefixes used for the virtual link; keep each within its respective private/unique-local range and avoid collisions.
- `inbounds[0].mtu` (`1500`) is the link maximum transmission unit in bytes (standard Ethernet MTU).
- `route.rules[0].port` (`53`) is the DNS destination port matched by the hijack rule (UDP/TCP DNS); it is not the local listener port above.

Only the local listener port is dynamically substituted by the current shell startup. Interface name, addresses, MTU, and DNS match port are static settings and are not shell-overridable parameters.
