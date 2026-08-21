#!/bin/sh

# 1. MENANGKAP VARIABEL DARI INIT.D
SERVER_IP=$1
PORT=$2
USER=$3
PASS=$4
SNI=$5
PAYLOAD=$6
SOCKS_PORT=$7

# Konfigurasi Interface Internal
TUN_DEV="tun-ssh"
TUN_IP="10.0.0.1"
ROUTER_IP="10.0.0.2"

echo "SSHWS: Memulai Core Routing (IP: $SERVER_IP, SNI: $SNI)"

# 2. JALANKAN PYTHON INJECTOR (LOCAL PROXY)
# Menghidupkan python di port 8888 (berjalan di background dengan ' &')
/usr/bin/python3 /usr/bin/sshws-injector.py --listen 8888 --target_ip "$SERVER_IP" --target_port "$PORT" --ssh_port 22 --sni "$SNI" --payload "$PAYLOAD" &
INJECTOR_PID=$!
echo "SSHWS: Python Injector berjalan (PID: $INJECTOR_PID)"

# Beri waktu 2 detik agar Python siap membuka port
sleep 2

# 3. JALANKAN SSH CLIENT (ProxyCommand melalui Python)
# Menggunakan sshpass untuk memasukkan password otomatis
# Menggunakan ncat (netcat) untuk mengalihkan SSH ke port 8888 (Python)
sshpass -p "$PASS" ssh -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" \
    -o "ServerAliveInterval=30" -o "ServerAliveCountMax=3" \
    -o "ProxyCommand=nc 127.0.0.1 8888" \
    -N -D 0.0.0.0:$SOCKS_PORT "$USER@$SERVER_IP" &
SSH_PID=$!
echo "SSHWS: SSH Client berjalan (PID: $SSH_PID)"

# Beri waktu 3 detik agar SSH Handshake selesai dan port SOCKS5 terbuka
sleep 3

# 4. SETUP VIRTUAL INTERFACE (TUN)
echo "SSHWS: Membuat virtual interface $TUN_DEV"
ip tuntap add dev $TUN_DEV mode tun
ip addr add $TUN_IP/24 dev $TUN_DEV
ip link set $TUN_DEV up

# Menghidupkan badvpn-tun2socks untuk mengubah TCP SOCKS5 menjadi interface
badvpn-tun2socks --tundev $TUN_DEV --netif-ipaddr $ROUTER_IP --netif-netmask 255.255.255.0 --socks-server-addr 127.0.0.1:$SOCKS_PORT &
TUN_PID=$!

# 5. IP ROUTING (Mengarahkan lalu lintas)
echo "SSHWS: Mengkonfigurasi Policy Routing"

# Cari gateway internet asli milik router (misal dari eth0 / wlan0)
DEFAULT_GATEWAY=$(ip route | awk '/default/ {print $3}')

# AMANAN PENTING: IP VPS jangan masuk ke tunnel (mencegah infinite loop)
ip route add "$SERVER_IP" via "$DEFAULT_GATEWAY"

# Masukkan sisa jalur internet ke rute spesial (Table 100) menuju tunnel
ip route add default via $ROUTER_IP dev $TUN_DEV table 100

# Minta router untuk memasukkan paket yang ditandai '0x1' ke Table 100
ip rule add fwmark 0x1 table 100

# 6. NFTABLES (FW4) - Transparent Proxy LAN
# Ini adalah metode khusus OpenWrt 23 untuk menandai lalu lintas dari LAN
echo "SSHWS: Mengkonfigurasi nftables fw4"
nft add table inet sshws_table
nft add chain inet sshws_table prerouting { type filter hook prerouting priority mangle\; }

# Tandai lalu lintas dari jembatan LAN (br-lan) dengan mark 0x1 (kecuali menuju VPS)
nft add rule inet sshws_table prerouting iifname "br-lan" ip daddr != "$SERVER_IP" meta mark set 0x1

# Tandai juga lalu lintas dari router itu sendiri (jika ingin router ikut ter-tunnel)
nft add chain inet sshws_table output { type filter hook output priority mangle\; }
nft add rule inet sshws_table output skuid != 0 ip daddr != "$SERVER_IP" meta mark set 0x1


# 7. CLEANUP SCRIPT (Jika di-Stop dari GUI)
# Skrip ini akan berjalan otomatis saat Procd mematikan proses
trap "
    echo 'SSHWS: Mematikan seluruh proses dan membersihkan firewall...'
    kill $TUN_PID $SSH_PID $INJECTOR_PID 2>/dev/null
    
    # Hapus aturan ip route & rule
    ip rule del fwmark 0x1 table 100 2>/dev/null
    ip route del default via $ROUTER_IP dev $TUN_DEV table 100 2>/dev/null
    ip route del $SERVER_IP via $DEFAULT_GATEWAY 2>/dev/null
    
    # Hapus interface
    ip link delete $TUN_DEV 2>/dev/null
    
    # Hapus nftables
    nft delete table inet sshws_table 2>/dev/null
    
    echo 'SSHWS: Berhasil dimatikan.'
    exit 0
" SIGINT SIGTERM

# Perintah wajib agar skrip terus berjalan (standby) dan siap merespons 'trap'
wait