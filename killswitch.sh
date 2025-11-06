#!/bin/bash

backup_rules() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    IPV4_BACKUP="$SCRIPT_DIR/.iptables-backup.txt"
    IPV6_BACKUP="$SCRIPT_DIR/.ip6tables-backup.txt"

    echo "[*] Checking for existing firewall backups..."

    # Only back up the *first time* (to preserve original firewall state)
    if [[ ! -f $IPV4_BACKUP ]]; then
        echo "[-] Backing up original IPv4 rules to $IPV4_BACKUP"
        sudo iptables-save > "$IPV4_BACKUP"
    else
        echo "[✓] IPv4 backup already exists — not overwriting."
    fi

    if [[ ! -f $IPV6_BACKUP ]]; then
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

    # === Allow the VPN client to connect to the VPN server ===
    # Adjust interface and port as needed (example assumes UDP 1194 on wlan0)
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
    sudo iptables-restore < ./.iptables-backup.txt
    sudo ip6tables-restore < ./.ip6tables-backup.txt

    sudo rm ./.iptables-backup.txt
    sudo rm ./.ip6tables-backup.txt
}

check_status() {
    OUTPUT_POLICY=$(sudo iptables -L OUTPUT -n | grep "Chain OUTPUT" | awk '{print $4}')
    INPUT_POLICY=$(sudo iptables -L INPUT -n | grep "Chain INPUT" | awk '{print $4}')
    FORWARD_POLICY=$(sudo iptables -L FORWARD -n | grep "Chain FORWARD" | awk '{print $4}')

    BOLD_GREEN="\e[1;32m"
    BOLD_RED="\e[1;31m"
    RESET="\e[0m"

    if [[ "$OUTPUT_POLICY" == "DROP" && "$INPUT_POLICY" == "DROP" && "$FORWARD_POLICY" == "DROP" ]]; then
        echo -e "[+] Killswitch: ${BOLD_GREEN}ON${RESET}"
    else
        echo -e "[-] Killswitch: ${BOLD_RED}OFF${RESET}"
    fi

}

if [ "$#" -ne 1 ]; then
    echo "[-] Usage: killswitch.sh <status|on|off>"
    exit 1
fi

case "$1" in
    status)
        check_status
        ;;
    on)
       echo "[+] Enabling on killswitch..."
       apply_rules 
        ;;
    off)
        echo "[+] Disabling killswitch..."
        restore_rules
        ;;
    *)
        echo "[-] Unknown command: $1"
        echo "Usage: killswitch.sh <status|on|off>"
        exit 1 ;;
esac
