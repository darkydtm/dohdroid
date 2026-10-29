# DoH DNS module

The module starts the DNS daemon at boot and keeps the last saved resolver and DNS history across module updates. The WebUI can enable optional TUN interception. TUN captures IPv4 and IPv6 UDP/TCP port 53 using a root-created interface without occupying Android's VPN slot. Other traffic continues through the existing network or VPN. TUN mode requires `/dev/net/tun`, IPv4 and IPv6 policy routing, and iptables mangle support. The module packages sing-box 1.14.4 for the selected Android ABI.

The TUN mode does not intercept Android Private DNS (DNS-over-TLS), DNS-over-HTTPS traffic from individual applications, loopback DNS, or root-owned DNS traffic. Some VPNs, firewall rules, or device kernels may prevent interception. Disable Private DNS if it bypasses the module. The DoH server connection itself follows the device's normal network routing and may use the active VPN.

Install the ABI-specific ZIP with KernelSU or Magisk and reboot. Select the interception mode and save in the KernelSU WebUI. To recover from routing problems, disable the module in the root manager and reboot. Uninstall removes the module's routing rules; disabling the module and rebooting also clears them.
