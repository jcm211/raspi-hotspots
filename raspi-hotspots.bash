#!/bin/bash

# Run as root: sudo ./raspi-hotspot.sh

echo "Updating system..."
apt update && apt upgrade -y

echo "Installing required packages..."
apt install -y hostapd dnsmasq netfilter-persistent iptables-persistent

echo "Enabling services..."
systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq

echo "Configuring static IP for wlan0..."
cat >> /etc/dhcpcd.conf <<EOF

interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
EOF

echo "Configuring dnsmasq..."
mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig 2>/dev/null
cat > /etc/dnsmasq.conf <<EOF
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
EOF

echo "Creating hostapd config..."
cat > /etc/hostapd/hostapd.conf <<EOF
interface=wlan0
driver=nl80211
ssid=MyPiHotspot
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=SuperSecret123
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

echo "Linking hostapd config..."
sed -i 's|#DAEMON_CONF="".*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

echo "Enabling IP forwarding..."
sed -i 's|#net.ipv4.ip_forward=1|net.ipv4.ip_forward=1|' /etc/sysctl.conf
sysctl -p

echo "Setting up iptables for NAT..."
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

echo "Saving iptables rules..."
netfilter-persistent save

echo "Restarting services..."
systemctl restart dhcpcd
systemctl restart hostapd
systemctl restart dnsmasq

echo "✅ Hotspot setup complete!"
echo "SSID: MyPiHotspot | Password: SuperSecret123"
