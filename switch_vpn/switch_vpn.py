"""
List UI for switching openvpn connections.
"""

import inquirer
from inquirer.themes import GreenPassion
import subprocess
import os
import re

def get_current_vpn_connection():
    try:
        # Run the command to list services
        result = subprocess.run(
            ['systemctl', 'list-units', '--type=service'],
            capture_output=True,
            text=True,
            check=True
        )

        # Check if OpenVPN is running
        vpn_status = [line for line in result.stdout.splitlines() if 'openvpn' in line and 'active' in line and 'running' in line]

        if vpn_status:
            # Extract the provider name using regex
            match = re.search(r'connection to (.+)', vpn_status[0])
            if match:
                return match.group(1)  # Return the matched provider name
        return None  # No active running OpenVPN service found
    except subprocess.CalledProcessError as e:
        print(f"Error checking VPN status: {e}")
        return None

def get_vpn_configs():
    files = os.listdir('/etc/openvpn/')
    
    # Filter for .conf files and remove the extension
    config_names = [file[:-5] for file in files if file.endswith('.conf')]
    
    return config_names

def exec_systemctl(action, config):
    subprocess.run(['sudo', 'systemctl', action, 'openvpn@{}'.format(config)])

def switch_connection(old_conn, new_conn):
    exec_systemctl('stop', old_conn)
    exec_systemctl('start', new_conn)

def main():
    current_conn = get_current_vpn_connection()
    print("Current VPN provider:", current_conn)
    questions = [
        inquirer.List(
            "vpn_provider",
            message="Choose a provider",
            choices=get_vpn_configs(),
        ),
    ]

    chosen_conn = inquirer.prompt(questions, theme=GreenPassion()).get("vpn_provider")
    try:
        switch_connection(current_conn, chosen_conn)
        print("Successfully switched to", chosen_conn)
    except Exception as e:
        print("Error switching to", chosen_conn)
        print(e)

if __name__ == "__main__":
    main()