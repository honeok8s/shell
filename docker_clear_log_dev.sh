#!/bin/bash
# Author: honeok
# Date: 2024.7.10
# Description: cleans Docker container logs that exceed a specified size limit.
# Blog: honeok.com
################################################################################

set -o errexit

yellow='\033[1;33m' # 用于提示信息
red='\033[1;31m'    # 用于警告信息
green='\033[1;32m'  # 用于成功信息
blue='\033[1;34m'   # 用于一般信息
cyan='\033[1;36m'   # 用于特殊信息
purple='\033[1;35m' # 用于紫色信息
white='\033[0m'     # 用于结束颜色设置

printf "${yellow}========== start clean docker containers logs ==========${white}\n"
echo""

log_dir="/var/lib/docker/containers/"
max_log_size="28M"

if [ ! -d "$log_dir" ]; then
  printf "${red}${log_dir} does not exist. Exiting.${white}\n"
  exit 1
fi

find "$log_dir" -name '*-json.log' | while IFS= read -r log; do
  printf "${yellow}Cleaning log: ${log}${white}\n"
  echo""

  # 获取日志大小
  size=$(du -h "$log" | awk '{print $1}')
  
  # 检查是否超过阈值
  if [[ "$size" > "$max_log_size" ]]; then
    printf "${cyan}Log size ${size} exceeds maximum size ${max_log_size}, cleaning.${white}\n"
    sleep 2s
    echo ""

    truncate -s 0 "$log"

    # 再次检查日志文件大小
    check=$(du -h "$log" | awk '{print $1}')
    if [[ "$check" == "0" ]]; then
      printf "${green}Log cleaned.${white}\n"
      echo ""
    else
      printf "${red}Failed to clean log.${white}\n"
    fi
  else
    printf "${purple}Log size $size is within limits, no cleaning needed.${white}\n"
  fi
done

printf "${yellow}========== end clean docker containers logs ==========${white}\n"