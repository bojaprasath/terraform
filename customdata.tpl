packages: 
  - iperf3
repo_update: true
bootcmd:
 - ip route add ${destination_ip} via ${gw}
 - ip -6 route add ${destination_ip6} via ${gw6}
