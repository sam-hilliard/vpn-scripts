#!/bin/bash
BASE_DIR="$(dirname $0)/switch_vpn"
PYTHON_PATH="$BASE_DIR/venv/bin/python"
$PYTHON_PATH $BASE_DIR/switch_vpn.py
