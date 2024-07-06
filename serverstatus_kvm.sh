#!/bin/bash
# Author: honeok
# Blog: honeok.com
# Desc: Script to manage serverstatus probe
# Example: */1 * * * * $PWD/serverstatus_kvm.sh s250 >/dev/null 2>&1
# Github: https://raw.githubusercontent.com/honeok8s/shell/main/serverstatus_kvm.sh

set -o errexit
cd ~

PARAMS=("$@")

# Check if the script is provided with required parameters
if [[ $# -lt 1 ]];then echo "Usage:<server_id>" && exit
elif [[ ! "${PARAMS}" =~ ^s[0-9]+$ ]];then
  echo "Invalid server ID format. Please provide a valid server ID." && exit
fi

# Function to synchronize timezone with Shanghai
TIMEZONE(){
  # Get the current timezone
  ZONE=$(date -R | awk '{print $6}')
  # If not in Shanghai timezone, synchronize it
  if [[ "${ZONE}" != "+0800" ]];then
    timedatectl set-timezone Asia/Shanghai && systemctl restart cron 2>&1
  fi
}

# Function to manage server probe
PROBE(){
  # Count running instances of client-linux.py
  local LOG_TIME=$(date '+%Y-%m-%d %H:%M:%S')
  local GLOBLE_TIME=$(date '+%H:%M:%S')
  local COUNTER=$(ps -ef | grep '[c]lient-linux.py' | wc -l)

    # Download probe file and update configurations
  if [[ ! -f "./client-linux.py" ]]; then
    # Retry downloading for up to 3 times
    for ((i=1; i<=3; i++)); do
      wget --no-check-certificate -qO client-linux.py 'https://raw.githubusercontent.com/cppla/ServerStatus/master/clients/client-linux.py' >/dev/null 2>&1
      #sed -i 's#CU = "cu.tz.cloudcpp.com"#CU = "mall.10010.com"#g; s#CT = "ct.tz.cloudcpp.com"#CT = "www.189.cn"#g; s#CM = "cm.tz.cloudcpp.com"#CM = "www.bj.10086.cn"#g' client-linux.py
    done
  fi

  # Restart probe if not running
  if [[ "${COUNTER}" == 0 ]]; then
    nohup python3 client-linux.py SERVER="127.0.0.1" USER="${PARAMS}" >/dev/null 2>&1 &
    echo "${LOG_TIME} [WARN] Probe started." >> ./main.log
  fi

  # Clear logs every noon
  if [[ "${GLOBLE_TIME}" > "12:00:00" ]] && [[ "${GLOBLE_TIME}" < "12:00:50" ]]; then
    rm -f ./*.log 2>&1
  fi
}

MAIN() {
  TIMEZONE
  PROBE
}

MAIN
