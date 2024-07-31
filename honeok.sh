#!/bin/bash
# Author: honeok

set -o errexit
clear

# ANSI颜色码,用于彩色输出
yellow='\033[1;33m' # 提示信息
red='\033[1;31m'    # 警告信息
green='\033[1;32m'  # 成功信息
blue='\033[1;34m'   # 一般信息
cyan='\033[1;36m'   # 特殊信息
purple='\033[1;35m' # 紫色或粉色信息
gray='\033[1;30m'   # 灰色信息
white='\033[0m'     # 结束颜色设置

system_info() {
	local hostname=$(hostnamectl | sed -n 's/^[[:space:]]*Static hostname:[[:space:]]*\(.*\)$/\1/p')
	# 获取运营商信息
	local isp_info=$(curl -s ipinfo.io/org)

	# 获取操作系统版本信息
	local os_release=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d '"' -f 2)
	# 获取内核版本信息
	local kernel_version=$(hostnamectl | sed -n 's/^[[:space:]]*Kernel:[[:space:]]*\(.*\)$/\1/p')

	# 获取CPU架构,型号和核心数
	local cpu_architecture=$(uname -m)
	local cpu_model=$(lscpu | sed -n 's/^Model name:[[:space:]]*\(.*\)$/\1/p')
	local cpu_cores=$(lscpu | sed -n 's/^CPU(s):[[:space:]]*\(.*\)$/\1/p')

	# 计算CPU使用率,处理可能的除零错误
	local cpu_usage=$(awk -v OFMT='%0.2f' '
		NR==1 {idle1=$5; total1=$2+$3+$4+$5+$6+$7+$8+$9}
		NR==2 {
			idle2=$5
			total2=$2+$3+$4+$5+$6+$7+$8+$9
			diff_idle = idle2 - idle1
			diff_total = total2 - total1
			if (diff_total == 0) {
				cpu_usage=0
			} else {
				cpu_usage=100*(1-(diff_idle/diff_total))
			}
			printf "%.2f%%\n", cpu_usage
		}' <(sleep 1; cat /proc/stat))
	local mem_usage=$(free -b | awk 'NR==2{printf "%.2f/%.2f MB (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')
	local swap_usage=$(free -m | awk 'NR==3{used=$3; total=$2; if (total == 0) {percentage=0} else {percentage=used*100/total}; printf "%dMB/%dMB (%d%%)", used, total, percentage}')

	# 获取网络接口的统计信息
	local network_stats=$(cat /proc/net/dev)
	local rx_bytes=$(echo "$network_stats" | awk 'NR>2 {rx+=$2} END {print rx}')
	local tx_bytes=$(echo "$network_stats" | awk 'NR>2 {tx+=$10} END {print tx}')

	# 将字节转换为TB和GB
	convert_bytes() {
		local bytes=$(printf "%.0f" "$1")  # 转换为整数
		local tb=$((bytes / 1024 / 1024 / 1024 / 1024))
		local gb=$(( (bytes / 1024 / 1024 / 1024) % 1024 ))
		echo "$tb TB / $gb GB"
	}

	# 获取网络拥塞控制算法和队列算法
	local congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
	local queue_algorithm=$(sysctl -n net.core.default_qdisc)

	# 获取公网IPv4和IPv6地址
	local ipv4_address=$(curl -s ipv4.ip.sb)
	local ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb || true)

	# 获取地理位置,系统时区,系统时间和运行时长
	local location=$(curl -s ipinfo.io/city)
	local system_time=$(timedatectl | grep 'Time zone' | awk '{print $3}' | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/,""); print}')
	local current_time=$(date +"%Y-%m-%d %H:%M:%S")

	local uptime_str=$(uptime | awk -F'up ' '{print $2}' | awk -F', ' '{days=$1; hours_minutes=$2; gsub(/[^0-9 ]/, "", days); split(hours_minutes, a, ":"); hours=a[1]; minutes=a[2]; printf "%d天 %d时 %d分\n", days, hours, minutes}')

	printf "${purple}系统信息查询${white}\n"
	printf "${yellow}-------------------------${white}\n"
	printf "${yellow}主机名: ${hostname}${white}\n"
	printf "${yellow}运营商: ${isp_info}${white}\n"
	printf "${yellow}-------------------------${white}\n"
	printf "${yellow}操作系统: ${os_release}${white}\n"
	printf "${yellow}内核版本: ${kernel_version}${white}\n"
	printf "${yellow}-------------------------${white}\n"
	printf "${yellow}CPU架构: ${cpu_architecture}${white}\n"
	printf "${yellow}CPU型号: ${cpu_model}${white}\n"
	printf "${yellow}CPU核心: ${cpu_cores}${white}\n"
	printf "${yellow}-------------------------${white}\n"
	printf "${yellow}CPU占用率: %s${white}\n" "${cpu_usage}"
	printf "${yellow}物理内存: %s${white}\n" "${mem_usage}"
	printf "${yellow}虚拟内存: %s${white}\n" "${swap_usage}"

	# 获取并格式化磁盘空间使用情况
	local disk_info=$(df -h --output=source,size,used,pcent | grep -E "^/dev/" | grep -vE "tmpfs|devtmpfs|overlay|swap|loop")
	local disk_output=""

	while read -r line; do
		local disk=$(echo "$line" | awk '{print $1}')
		local size=$(echo "$line" | awk '{print $2}')
		local used=$(echo "$line" | awk '{print $3}')
		local percent=$(echo "$line" | awk '{print $4}')
		
		# 拼接磁盘信息
		disk_output+="${disk} ${used}/${size} (${percent})  "
	done <<< "$disk_info"
	# 打印硬盘空间
	printf "${yellow}硬盘空间: %s${white}\n" "${disk_output}"

	printf "${yellow}-------------------------${white}\n"
	printf "${yellow}网络接收数据量: $(convert_bytes $rx_bytes)${white}\n"
	printf "${yellow}网络发送数据量: $(convert_bytes $tx_bytes)${white}\n"
	printf "${yellow}-------------------------${white}\n"
	printf "${yellow}网络拥塞控制算法: ${congestion_algorithm} ${queue_algorithm}${white}\n"
	printf "${yellow}-------------------------${white}\n"
	printf "${yellow}公网IPv4地址: ${ipv4_address}${white}\n"
	printf "${yellow}公网IPv6地址: ${ipv6_address}${white}\n"
	printf "${yellow}-------------------------${white}\n"
	printf "${yellow}地理位置: ${location}${white}\n"
	printf "${yellow}系统时区: ${system_time}${white}\n"
	printf "${yellow}系统时间: ${current_time}${white}\n"
	printf "${yellow}运行时长: ${uptime_str}${white}\n"
	printf "${yellow}-------------------------${white}\n"
}

system_info