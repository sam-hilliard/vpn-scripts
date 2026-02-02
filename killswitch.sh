#!/bin/bash
set -euo pipefail

# Resolve the directory this script lives in (alias / symlink safe)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IPV4_BACKUP="$SCRIPT_DIR/.iptables-backup.txt"
IPV6_BACKUP="$SCRIPT_DIR/.ip6tables-backup.txt"

backup_rules() {
    echo "[*] Checking for existing firewall backups..."

    # Only back up the first time (preserve original firewall state)
    if [[ ! -f "$IPV4_BACKUP" ]]; then
        echo "[-] Backing up original IPv4 rules to $IPV4_BACKUP"
        sudo iptables-save > "$IPV4_BACKUP"
    else
        echo "[✓] IPv4 backup already exists — not overwriting."
    fi

    if [[ ! -f "$IPV6_BACKUP" ]]; then
        echo "[-] Backing up original IPv6 rules to $IPV6_BACKUP"
        sudo ip6tables-save > "$IPV6_BACKUP"
    else
        echo "[✓] IPv6 backup already exists — not overwriting."
    fi
}

apply_rules() {
    backup_rules

    # === Flush and reset rules ===
    sudo iptables -F
    sudo iptables -X
    sudo ip6tables -F
    sudo ip6tables -X

    # === Default policies: deny everything ===
    sudo iptables -P INPUT DROP
    sudo iptables -P OUTPUT DROP
    sudo iptables -P FORWARD DROP

    sudo ip6tables -P INPUT DROP
    sudo ip6tables -P OUTPUT DROP
    sudo ip6tables -P FORWARD DROP

    # === Allow localhost ===
    sudo iptables -A INPUT -i lo -j ACCEPT
    sudo iptables -A OUTPUT -o lo -j ACCEPT

    # === Allow VPN tunnel traffic ===
    sudo iptables -A INPUT -i tun+ -j ACCEPT
    sudo iptables -A OUTPUT -o tun+ -j ACCEPT

    # === Allow VPN client to connect to VPN server ===
    VPN_INTERFACE="wlan0"
    VPN_PORT="1194"

    sudo iptables -A OUTPUT -o "$VPN_INTERFACE" -p udp --dport "$VPN_PORT" -j ACCEPT
    sudo iptables -A INPUT  -i "$VPN_INTERFACE" -p udp --sport "$VPN_PORT" -j ACCEPT

    # === Allow LAN traffic (optional) ===
    sudo iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT
    sudo iptables -A INPUT  -s 192.168.0.0/16 -j ACCEPT

    # === Log drops with rate limit ===
    sudo iptables -A INPUT  -m limit --limit 3/min -j LOG --log-prefix "INPUT DROP: "  --log-level 7
    sudo iptables -A OUTPUT -m limit --limit 3/min -j LOG --log-prefix "OUTPUT DROP: " --log-level 7

    echo "[+] Firewall killswitch rules applied successfully."
}

restore_rules() {
    if [[ ! -f "$IPV4_BACKUP" || ! -f "$IPV6_BACKUP" ]]; then
        echo "[-] Firewall backup files not found in $SCRIPT_DIR"
        echo "    Cannot safely restore firewall state."
        exit 1
    fi

    sudo iptables-restore < "$IPV4_BACKUP"
    sudo ip6tables-restore < "$IPV6_BACKUP"

    sudo rm -f "$IPV4_BACKUP" "$IPV6_BACKUP"

    echo "[+] Firewall rules restored."
}

check_status() {
    VPN_INTERFACE="tun0"
    TEST_HOST="8.8.8.8"

    BOLD_GREEN="\e[1;32m"
    BOLD_RED="\e[1;31m"
    RESET="\e[0m"

    if ip link show "$VPN_INTERFACE" > /dev/null 2>&1; then
        vpn_iface_up=true
    else
        vpn_iface_up=false
    fi

    # Test non-VPN traffic
    if ping -I eth0 -c 1 -W 1 "$TEST_HOST" >/dev/null 2>&1; then
        non_vpn_ok=true
    else
        non_vpn_ok=false
    fi

    # Test VPN traffic
    if [[ "$vpn_iface_up" == true ]] && ping -I "$VPN_INTERFACE" -c 1 -W 1 "$TEST_HOST" >/dev/null 2>&1; then
        vpn_ok=true
    else
        vpn_ok=false
    fi

    if [[ "$vpn_ok" == true && "$non_vpn_ok" == false ]]; then
        echo -e "[+] Killswitch: ${BOLD_GREEN}ON${RESET}"
    elif [[ "$vpn_ok" == false && "$non_vpn_ok" == false ]]; then
        echo "[*] Killswitch active, but VPN appears DOWN."
    else
        echo -e "[-] Killswitch: ${BOLD_RED}OFF${RESET}"
        echo "    (Non-VPN traffic is still getting through)"
    fi
}

if [[ "$#" -ne 1 ]]; then
    echo "[-] Usage: killswitch.sh <status|on|off>"
    exit 1
fi

case "$1" in
    status)
        check_status
        ;;
    on)
        echo "[+] Enabling killswitch..."
        apply_rules
        ;;
    off)
        echo "[+] Disabling killswitch..."
        restore_rules
        ;;
    *)
        echo "[-] Unknown command: $1"
        echo "Usage: killswitch.sh <status|on|off>"
        exit 1
        ;;
esac
