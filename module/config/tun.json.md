# TUN configuration parameters

`config/tun.json` is the sing-box runtime configuration template. `service.sh` copies it to the runtime directory and replaces the `server_port` value `5353` with the validated `DOHD_PORT`; keep the template default synchronized with the service fallback. The JSON format does not support comments, so document tun values here rather than embedding non-JSON annotations.

- `dns.servers[0].server_port`: local dohd DNS listener port, normally `5353`.
- `inbounds[0].interface_name`: Linux TUN interface consumed by `tun-firewall.sh`; keep it synchronized with the interface name used by that script (`dohdtun0`).
- `inbounds[0].address`: private IPv4 and IPv6 addresses assigned to the TUN interface; the prefixes reserve point-to-point ranges for the local tunnel.
- `inbounds[0].mtu`: interface MTU in bytes; `1500` is the standard Ethernet MTU.
- `route.rules[0].port`: DNS destination port in the packet, in this case UDP/TCP DNS port `53`, which is redirected to the local DNS inbound.
