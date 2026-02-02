#!/bin/bash

get_running_vpn() {
    running_vpn=$(systemctl list-units --type=service | grep openvpn | grep "running")
    provider=$(echo $running_vpn | grep -o -e 'connection to .*' | sed 's/connection to //')
    echo "$provider"
}

restart_vpn() {
    provider=$(get_running_vpn)
    echo "Restarting $provider..."
    systemctl restart "openvpn@$provider"
}

stop_vpn() {
    provider=$(get_running_vpn)
    echo "Stopping $provider..."
    systemctl stop "openvpn@$provider"
}

if [ "$#" -ne 1 ]; then
    echo "Usage: vpn <status|restart|stop|switch>"
    exit 1
fi

SCRIPT_DIR=$(dirname "$0")

case "$1" in
    status)
        # Checking vpn status
        "$SCRIPT_DIR/check_vpn_status.sh"
        ;;
    restart)
        # Restarting current vpn
        restart_vpn
        ;;
    stop)
        # Stopping vpn connection
        stop_vpn
        ;;
    switch)
        # Switching vpn
        "$SCRIPT_DIR/switch_vpn.sh"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Usage: vpn <status|restart|stop|switch>"
        exit 1
        ;;
esac
