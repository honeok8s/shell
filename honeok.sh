#!/bin/bash
# Author: honeok
# Project: https://github.com/honeok8s
# Blog: https://www.honeok.com

set -o errexit
clear

yellow='\033[1;33m'  # 提示信息
red='\033[1;31m'     # 警告信息
magenta='\033[0;35m' # 品红色
green='\033[1;32m'   # 成功信息
blue='\033[1;34m'    # 一般信息
cyan='\033[1;36m'    # 特殊信息
purple='\033[1;35m'  # 紫色或粉色信息
gray='\033[1;30m'    # 灰色信息
white='\033[0m'      # 结束颜色设置
_yellow() { echo -e ${yellow}$@${white}; }
_red() { echo -e ${red}$@${white}; }
_magenta() { echo -e ${magenta}$@${white}; }
_green() { echo -e ${green}$@${white}; }
_blue() { echo -e ${blue}$@${white}; }
_cyan() { echo -e ${cyan}$@${white}; }
_purple() { echo -e ${purple}$@${white}; }
_gray() { echo -e ${gray}$@${white}; }

install_package(){
	if [ $# -eq 0 ]; then
		_red "未提供软件包参数"
		return 1
	fi

	for package in "$@"; do
		if ! command -v "$package" &>/dev/null; then
			_yellow "正在安装 $package"
			if command -v dnf &>/dev/null; then
				dnf install -y "$package"
			elif command -v yum &>/dev/null; then
				yum -y install "$package"
			elif command -v apt &>/dev/null; then
				apt install -y "$package"
			elif command -v apk &>/dev/null; then
				apk add "$package"
			else
				_red "未知的包管理器"
				return 1
			fi
		else
			_green "$package已经安装"
		fi
	done
	return 0
}

system_info() {
	local hostname=$(hostnamectl | sed -n 's/^[[:space:]]*Static hostname:[[:space:]]*\(.*\)$/\1/p')
	# 获取运营商信息
	local isp_info=$(curl -s https://ipinfo.io | grep '"org":' | awk -F'"' '{print $4}')

	# 获取操作系统版本信息
	local os_release
	if command -v lsb_release >/dev/null 2>&1; then
		os_release=$(lsb_release -d | awk -F: '{print $2}' | xargs)
	else
		os_release=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d '"' -f 2)
	fi
	# 获取虚拟化类型
	local virt_type
	if command -v lscpu >/dev/null 2>&1; then
		virt_type=$(lscpu | grep -i 'Hypervisor vendor:' | awk '{print $3}')
	else
		virt_type=$(grep -i 'virtualization' /sys/class/dmi/id/product_name 2>/dev/null || echo "Unknown")
	fi
	# 获取内核版本信息
	local kernel_version
	if command -v hostnamectl >/dev/null 2>&1; then
		kernel_version=$(hostnamectl | sed -n 's/^[[:space:]]*Kernel:[[:space:]]*Linux \?\(.*\)$/\1/p')
	else
		kernel_version=$(uname -r)
	fi

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

	# 将字节数转换为GB(获取出网入网数据)
	bytes_to_gb() {
		local bytes=$1
		# 使用整数除法计算 GB
		local gb=$((bytes / 1024 / 1024 / 1024))
		# 计算余数以获取小数部分
		local remainder=$((bytes % (1024 * 1024 * 1024)))
		local fraction=$((remainder * 100 / (1024 * 1024 * 1024)))
		echo "$gb.$fraction GB"
	}

	# 初始化总接收字节数和总发送字节数
	local total_recv_bytes=0
	local total_sent_bytes=0

	# 遍历/proc/net/dev文件中的每一行
	while read -r line; do
		# 提取接口名(接口名后面是冒号)
		local interface=$(echo "$line" | awk -F: '{print $1}' | xargs)
		
		# 过滤掉不需要的行(只处理接口名)
		if [ -n "$interface" ] && [ "$interface" != "Inter-| Receive | Transmit" ] && [ "$interface" != "face |bytes packets errs drop fifo frame compressed multicast|bytes packets errs drop fifo colls carrier compressed" ]; then
			# 提取接收和发送字节数
			local stats=$(echo "$line" | awk -F: '{print $2}' | xargs)
			local recv_bytes=$(echo "$stats" | awk '{print $1}')
			local sent_bytes=$(echo "$stats" | awk '{print $9}')

			# 累加接收和发送字节数
			total_recv_bytes=$((total_recv_bytes + recv_bytes))
			total_sent_bytes=$((total_sent_bytes + sent_bytes))
		fi
	done < /proc/net/dev

	# 获取网络拥塞控制算法和队列算法
	local congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
	local queue_algorithm=$(sysctl -n net.core.default_qdisc)

	local ipv4_address=$(curl -s ipv4.ip.sb)
	local ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb)

	# 获取地理位置,系统时区,系统时间和运行时长
	local location=$(curl -s ipinfo.io/city)
	local system_time=$(timedatectl | grep 'Time zone' | awk '{print $3}' | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/,""); print}')
	local current_time=$(date +"%Y-%m-%d %H:%M:%S")
	local uptime_str=$(cat /proc/uptime | awk -F. '{run_days=int($1 / 86400);run_hours=int(($1 % 86400) / 3600);run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d天 ", run_days); if (run_hours > 0) printf("%d时 ", run_hours); printf("%d分\n", run_minutes)}')

	clear
	echo ""
	_yellow "系统信息查询"
	echo "-------------------------"
	echo "主机名: ${hostname}"
	echo "运营商: ${isp_info}"
	echo "-------------------------"
	echo "操作系统: ${os_release}"
	echo "虚拟化: ${virt_type}"
	echo "内核版本: ${kernel_version}"
	echo "-------------------------"
	echo "CPU架构: ${cpu_architecture}"
	echo "CPU型号: ${cpu_model}"
	echo "CPU核心: ${cpu_cores}"
	echo "-------------------------"
	echo "CPU占用率: ${cpu_usage}"
	echo "物理内存: ${mem_usage}"
	echo "虚拟内存: ${swap_usage}"
	echo "硬盘空间: ${disk_output}"
	echo "-------------------------"
	echo "网络接收数据量: $(bytes_to_gb $total_recv_bytes)"
	echo "网络发送数据量: $(bytes_to_gb $total_sent_bytes)"
	echo "-------------------------"
	echo "网络拥塞控制算法: ${congestion_algorithm} ${queue_algorithm}"
	echo "-------------------------"
	echo "公网IPv4地址: ${ipv4_address}"
	echo "公网IPv6地址: ${ipv6_address}"
	echo "-------------------------"
	echo "地理位置: ${location}"
	echo "系统时区: ${system_time}"
	echo "系统时间: ${current_time}"
	echo "运行时长: ${uptime_str}"
	echo "-------------------------"
	echo
}

reinstall_system() {
	mollyLau_reinstall_script(){
		wget --no-check-certificate -qO InstallNET.sh 'https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh' && chmod a+x InstallNET.sh
	}

	dd_system_mollyLau(){
		_yellow "重装后初始用户名: \"root\"  初始密码: \"LeitboGi0ro\"  初始端口: \"22\""
		_yellow "按任意键继续"
		read -n 1 -s -r -p ""
		install_package wget
		mollyLau_reinstall_script
	}

	local choice
	while true; do
		_red "请备份数据,将为你重装系统,预计花费15分钟"
		echo "-------------------------"
		echo "1. Debian 12                  2. Debian 11"
		echo "3. Debian 10                  4. Debian 9"
		echo "-------------------------"
		echo "11. Ubuntu 24.04              12. Ubuntu 22.04"
		echo "13. Ubuntu 20.04              14. Ubuntu 18.04"
		echo "-------------------------"
		echo "0. 返回上一级选单"
		echo "-------------------------"

		read -p "请选择要重装的系统: " choice
		case "$choice" in
			1)
				_yellow "重装debian 12"
				dd_system_mollyLau
				bash InstallNET.sh -debian 12
				reboot
				exit 0
				;;
			2)
				_yellow "重装debian 11"
				dd_system_mollyLau
				bash InstallNET.sh -debian 11
				reboot
				exit 0
				;;
			3)
				_yellow "重装debian 10"
				dd_system_mollyLau
				bash InstallNET.sh -debian 10
				reboot
				exit 0
				;;
			4)
				_yellow "重装debian 9"
				dd_system_mollyLau
				bash InstallNET.sh -debian 9
				reboot
				exit 0
				;;
			11)
				_yellow "重装ubuntu 24.04"
				dd_system_mollyLau
				bash InstallNET.sh -ubuntu 24.04
				reboot
				exit 0
				;;
			12)
				_yellow "重装ubuntu 22.04"
				dd_system_mollyLau
				bash InstallNET.sh -ubuntu 22.04
				reboot
				exit 0
				;;
			13)
				_yellow "重装ubuntu 20.04"
				dd_system_mollyLau
				bash InstallNET.sh -ubuntu 20.04
				reboot
				exit 0
				;;
			14)
				_yellow "重装ubuntu 18.04"
				dd_system_mollyLau
				bash InstallNET.sh -ubuntu 18.04
				reboot
				exit 0
				;;
			0)
				break
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
	done
}

server_test_script(){
	local choice
	while true; do
		clear
		echo "===== 测试脚本 ====="
		echo ""
		echo "----IP及解锁状态检测----"
		echo "1. 流媒体解锁"
		echo "8. VPS融合怪服务器测评"
		echo "-------------------------"
		echo "0. 返回菜单"
		read -p "请输入选项并按Enter:" choice

		case "$choice" in
			1)
				clear
				bash <(curl -L -s check.unlock.media)
				;;
			8)
				clear
				curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh
				;;
			0)
				break
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
		_green "操作完成"
		_yellow "按任意键继续"
		read -n 1 -s -r
	done
}

linux_system_tools(){
	local choice
	while true; do
		clear
		# send_stats "系统工具"
		echo "▶ 系统工具"
		echo "------------------------"
		_yellow "8. 一键重装系统"
		echo "0. 返回主菜单"
		echo "------------------------"
		read -p "请输入选项并按Enter:" choice

		case $choice in
			8)
				reinstall_system
				;;
			0)
				break
				;;
		esac
	done
}

honeok_sh(){
	local choice
	while true; do
		# 打印带颜色的 ASCII 艺术文本
		clear
		# https://www.lddgo.net/string/text-to-ascii-art
		_yellow "  _                            _    "
		_yellow " | |                          | |   "
		_yellow " | |__   ___  _ __   ___  ___ | | __"
		_yellow " | '_ \ / _ \| '_ \ / _ \/ _ \| |/ /"
		_yellow " | | | | (_) | | | |  __| (_) |   < "
		_yellow " |_| |_|\___/|_| |_|\___|\___/|_|\_\""
		echo "-------------------------"
		_purple "Author: honeok"
		_purple "Github: https://github.com/honeok8s/shell"

		echo "-------------------------"
		echo "1. 系统信息查询"
		echo "8. 测试脚本合集"
		echo "13. 系统工具"
		echo "-------------------------"
		
		read -p "请输入选项并按Enter:" choice

		case "$choice" in
			1)
				system_info
				;;
			8)
				server_test_script
				;;
			13)
				linux_system_tools
				;;
			0)
				clear
				exit 0
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
		_green "操作完成"
		_yellow "按任意键继续"
		read -n 1 -s -r
	done
}
honeok_sh
exit 0