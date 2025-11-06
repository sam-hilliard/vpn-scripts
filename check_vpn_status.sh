#!/bin/bash
#############################################
# Ensures that VPN is running on startup
# Startup script that:
# 1. Check if OpenVPN service is running
# 2. Which config is being used
# 3. What your IP address is
#############################################

max_attempts=5
attempt=0

# Check if openvpn service is running
while [[ $attempt -lt $max_attempts ]]; do
    # Check if openvpn service is running
    vpn_status=$(systemctl list-units --type=service | grep openvpn | grep "running")

    if [[ -n $vpn_status ]]; then
        break
    else
        echo "Waiting for OpenVPN service to start..."
        sleep 2  # Wait for 2 seconds before the next check
        ((attempt++))
    fi
done

if [[ $attempt -eq $max_attempts ]]; then
    echo -e "\033[1;31mDisconnected!\033[0m"
    echo "Make sure OpenVPN is running."
else
  provider=$(echo $vpn_status | grep -o -e 'connection to .*' | sed 's/connection to //')

  # Report current IP 
  ip_data=$(curl -s "https://ipinfo.io")
  cur_ip=$(echo $ip_data | jq -r '.ip')
  city=$(echo $ip_data | jq -r '.city')
  region=$(echo $ip_data | jq -r '.region')
  country=$(echo $ip_data | jq -r '.country')

  echo -e "\033[1;32mConnected!\033[0m"
  echo "Provider: $provider"
  echo "Current IP: $cur_ip"
  echo "Location: $city, $region $country"
fi

echo -e "\n"
read -p "Press enter to continue"
