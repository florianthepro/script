1. install tailscale
```
curl -fsSL https://tailscale.com/install.sh | sh && systemctl enable --now tailscaled
```
3. setup tailscale
```
iptables -P INPUT DROP && iptables -P FORWARD DROP && iptables -P OUTPUT DROP && iptables -F INPUT && iptables -F FORWARD && iptables -F OUTPUT && iptables -A INPUT -i lo -j ACCEPT && iptables -A OUTPUT -o lo -j ACCEPT && iptables -A INPUT -i tailscale0 -j ACCEPT && iptables -A OUTPUT -o tailscale0 -j ACCEPT && iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT && iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```
[tailscale ip] vai dashbourd einsehen
```
cat <<EOF >/etc/hosts
127.0.0.1 localhost
[tailscale ip] pve
EOF
```
systemctl restart pveproxy pvedaemon

4. setup tailscale subnetting
```
tailscale up --reset --hostname=pve --advertise-routes=10.200.0.0/24 && echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-tailscale.conf && sysctl --system && sysctl -w net.ipv4.ip_forward=1 && iptables -t nat -A POSTROUTING -s 10.200.0.0/24 -o tailscale0 -j MASQUERADE
```
5. setup new virtual interface `vmbr1`in proxmox (`Linux Bridge`>IPv4:`10.200.0.1/24`>ok)
6. setup proxmox dhcp
```
apt install isc-dhcp-server -y
```
in
```
nano /etc/default/isc-dhcp-server
```
enter
```
INTERFACESv4="vmbr1"
```
in
```
nano /etc/dhcp/dhcpd.conf
```
enter
```
default-lease-time 600;
max-lease-time 7200;
authoritative;

subnet 10.200.0.0 netmask 255.255.255.0 {
  range 10.200.0.50 10.200.0.200;
  option routers 10.200.0.1;
  option domain-name-servers 1.1.1.1, 8.8.8.8;
}
```
```
systemctl restart isc-dhcp-server
```
natting
```
sed -i '/iface vmbr1 inet static/a \    post-up iptables -t nat -A POSTROUTING -s 10.200.0.0/24 -o vmbr0 -j MASQUERADE\n    post-down iptables -t nat -D POSTROUTING -s 10.200.0.0/24 -o vmbr0 -j MASQUERADE' /etc/network/interfaces
```
