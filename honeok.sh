#!/bin/bash
# Author: honeok
# Blog: https://www.honeok.com

set -o errexit
clear

yellow='\033[1;33m'  # 提示信息
red='\033[1;31m'     # 警告信息
magenta='\033[1;35m' # 品红色
green='\033[1;32m'   # 成功信息
blue='\033[1;34m'    # 一般信息
cyan='\033[1;36m'    # 特殊信息
purple='\033[1;35m'  # 紫色或粉色信息
gray='\033[1;30m'    # 灰色信息
orange='\033[1;38;5;208m'
white='\033[0m'      # 结束颜色设置
_yellow() { echo -e ${yellow}$@${white}; }
_red() { echo -e ${red}$@${white}; }
_magenta() { echo -e ${magenta}$@${white}; }
_green() { echo -e ${green}$@${white}; }
_blue() { echo -e ${blue}$@${white}; }
_cyan() { echo -e ${cyan}$@${white}; }
_purple() { echo -e ${purple}$@${white}; }
_gray() { echo -e ${gray}$@${white}; }
_orange() { echo -e ${orange}$@${white}; }

honeok_v="v1.0.0"

print_logo(){
	local cyan=$(tput setaf 6)
	local reset=$(tput sgr0)
	local yellow=$(tput setaf 3)
	local bold=$(tput bold)
	local logo="
 _                            _    
| |                          | |   
| |__   ___  _ __   ___  ___ | | __
| '_ \ / _ \| '_ \ / _ \/ _ \| |/ /
| | | | (_) | | | |  __| (_) |   < 
|_| |_|\___/|_| |_|\___|\___/|_|\_\\"

	echo -e "${cyan}${logo}${reset}"
	echo ""
	local text="Tools: ${honeok_v}"
	local padding="                                   "
	echo -e "${padding}${yellow}${bold}${text}${reset}"
}

# 结尾任意键结束
end_of(){
	_green "操作完成"
	_yellow "按任意键继续"
	read -n 1 -s -r -p ""
	echo ""
	clear
}

# 检查用户是否为root
need_root(){
	clear
	if [ "$(id -u)" -ne "0" ]; then
		_red "该功能需要root用户才能运行"
		end_of
		# 回调主菜单
		honeok
	fi
}

# 安装软件包
install(){
	if [ $# -eq 0 ]; then
		_red "未提供软件包参数"
		return 1
	fi

	for package in "$@"; do
		if ! command -v "$package" &>/dev/null; then
			_yellow "正在安装$package"
			if command -v dnf &>/dev/null; then
				dnf install -y "$package"
			elif command -v yum &>/dev/null; then
				yum -y install "$package"
			elif command -v apt &>/dev/null; then
				apt update && apt install -y "$package"
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

# 卸载软件包
remove(){
	if [ $# -eq 0 ]; then
		_red "未提供软件包参数"
		return 1
	fi

	for package in "$@"; do
		_yellow "正在卸载$package"
		if command -v dnf &>/dev/null; then
			dnf remove -y "${package}"*
		elif command -v yum &>/dev/null; then
			yum remove -y "${package}"*
		elif command -v apt &>/dev/null; then
			apt purge -y "${package}"*
		elif command -v apk &>/dev/null; then
			apk del "${package}"*
		else
			_red "未知的包管理器"
			return 1
		fi
	done
	return 0
}

# 通用systemctl函数, 适用于各种发行版
systemctl() {
	local COMMAND="$1"
	local SERVICE_NAME="$2"

	if command -v apk &>/dev/null; then
		service "$SERVICE_NAME" "$COMMAND"
	else
		/bin/systemctl "$COMMAND" "$SERVICE_NAME"
	fi
}

# 重启服务
restart() {
	systemctl restart "$1"
	if [ $? -eq 0 ]; then
		_green "$1服务已重启"
	else
		_red "错误:重启$1服务失败"
	fi
}

# 重载服务
reload() {
	systemctl reload "$1"
	if [ $? -eq 0 ]; then
		_green "$1服务已重载"
	else
		_red "错误:重载$1服务失败"
	fi
}

# 启动服务
start() {
	systemctl start "$1"
	if [ $? -eq 0 ]; then
		_green "$1服务已启动"
	else
		_red "错误:启动$1服务失败"
	fi
}

# 停止服务
stop() {
	systemctl stop "$1"
	if [ $? -eq 0 ]; then
		_green "$1服务已停止"
	else
		_red "错误:停止$1服务失败"
	fi
}

# 查看服务状态
status() {
	systemctl status "$1"
	if [ $? -eq 0 ]; then
		_green "$1服务状态已显示"
	else
		_red "错误:无法显示$1服务状态"
	fi
}

# 设置服务为开机自启
enable() {
	local SERVICE_NAME="$1"
	if command -v apk &>/dev/null; then
		rc-update add "$SERVICE_NAME" default
	else
		/bin/systemctl enable "$SERVICE_NAME"
	fi

	_green "$SERVICE_NAME已设置为开机自启"
}

# 用于检查并设置net.core.default_qdisc参数
set_default_qdisc(){
	local qdisc_control="net.core.default_qdisc"
	local default_qdisc="fq"
	local config_file="/etc/sysctl.conf"
	local current_value
	local choice
	local chosen_qdisc

	# 使用grep查找现有配置,忽略等号周围的空格,排除注释行
	if grep -q "^[^#]*${qdisc_control}\s*=" "${config_file}"; then
		# 存在该设置项,检查其值
		current_value=$(grep "^[^#]*${qdisc_control}\s*=" "${config_file}" | sed -E "s/^[^#]*${qdisc_control}\s*=\s*(.*)/\1/")
		_yellow "当前队列规则为:$current_value"
	else
		# 没有找到该设置项
		current_value=""
	fi

	# 提供用户选择菜单
	while true; do
		echo "请选择要设置的队列规则"
		echo "-------------------------"
		echo "1. fq (默认)"
		echo "2 .fq_pie"
		echo "-------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认(回车使用默认值:fq):${white}"
		read choice

		case "$choice" in
			1|"")
				chosen_qdisc="fq"
				break
				;;
			2)
				chosen_qdisc="fq_pie"
				break
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
	done

	# 如果当前值不等于选择的值,进行更新
	if [ "$current_value" != "$chosen_qdisc" ]; then
		if [ -z "$current_value" ]; then
			# 如果没有设置项,则新增
			echo "${qdisc_control}=${chosen_qdisc}" >> "${config_file}"
		else
			# 如果设置项存在但值不匹配,进行替换
			sed -i -E "s|^[^#]*${qdisc_control}\s*=\s*.*|${qdisc_control}=${chosen_qdisc}|" "${config_file}"
		fi
		sysctl -p
		_green "队列规则已设置为:$chosen_qdisc"
	else
		_yellow "队列规则已经是$current_value,无需更改。"
	fi
}

bbr_on(){
	local congestion_control="net.ipv4.tcp_congestion_control"
	local congestion_bbr="bbr"
	local config_file="/etc/sysctl.conf"
	local current_value

	# 使用grep查找现有配置,忽略等号周围的空格,排除注释行
	if grep -q "^[^#]*${congestion_control}\s*=" "${config_file}"; then
		# 存在该设置项,检查其值
		current_value=$(grep "^[^#]*${congestion_control}\s*=" "${config_file}" | sed -E "s/^[^#]*${congestion_control}\s*=\s*(.*)/\1/")
		if [ "$current_value" = "$congestion_bbr" ]; then
			# 如果当前值已经是bbr,则跳过
			return
		else
			# 如果当前值不是bbr,则替换为bbr
			sed -i -E "s|^[^#]*${congestion_control}\s*=\s*.*|${congestion_control}=${congestion_bbr}|" "${config_file}"
			sysctl -p
		fi
	else
		# 如果没有找到该设置项,则新增
		echo "${congestion_control}=${congestion_bbr}" >> "${config_file}"
		sysctl -p
	fi
}

# 查看当前服务器时区
current_timezone(){
	if grep -q 'Alpine' /etc/issue; then
		date +"%Z %z"
	else
		timedatectl | grep "Time zone" | awk '{print $3}'
	fi
}

# 设置时区
set_timedate(){
	local timezone="$1"
	if grep -q 'Alpine' /etc/issue; then
		install tzdata
		cp /usr/share/zoneinfo/${timezone} /etc/localtime
		hwclock --systohc
	else
		timedatectl set-timezone ${timezone}
	fi
}

set_dns(){
	local cloudflare_ipv4="1.1.1.1"
	local google_ipv4="8.8.8.8"
	local cloudflare_ipv6="2606:4700:4700::1111"
	local google_ipv6="2001:4860:4860::8888"

	local ali_ipv4="223.5.5.5"
	local tencent_ipv4="183.60.83.19"
	local ali_ipv6="2400:3200::1"
	local tencent_ipv6="2400:da00::6666"

	local ipv6_addresses

	if [ $(curl -s ipinfo.io/country) = "CN" ];then
		{
			echo "nameserver $ali_ipv4"
			echo "nameserver $tencent_ipv4"
			if [[ $(ip -6 addr | grep -c "inet6") -gt 0 ]]; then
				echo "nameserver $ali_ipv6"
				echo "nameserver $tencent_ipv6"
			fi
		} | tee /etc/resolv.conf > /dev/null
	else
		{
			echo "nameserver $cloudflare_ipv4"
			echo "nameserver $google_ipv4"
			if [[ $(ip -6 addr | grep -c "inet6") -gt 0 ]]; then
				echo "nameserver $cloudflare_ipv6"
				echo "nameserver $google_ipv6"
			fi
		} | tee /etc/resolv.conf > /dev/null
	fi
}

# 备份DNS配置文件
bak_dns() {
	# 定义源文件和备份文件的位置
	local dns_config="/etc/resolv.conf"
	local backupdns_config="/etc/resolv.conf.bak"

	# 检查源文件是否存在
	if [[ -f "$dns_config" ]]; then
		# 备份文件
		cp "$dns_config" "$backupdns_config"

		# 检查备份是否成功
		if [[ $? -ne 0 ]]; then
			_red "备份DNS配置文件失败"
		fi
	else
		_red "DNS配置文件不存在"
	fi
}

# 回滚到备份的DNS配置文件
rollbak_dns() {
	# 定义源文件和备份文件的位置
	local dns_config="/etc/resolv.conf"
	local backupdns_config="/etc/resolv.conf.bak"
	
	# 查找备份文件
	if [[ -f "$backupdns_config" ]]; then
		# 恢复备份文件
		cp "$backupdns_config" "$dns_config"
		
		if [[ $? -ne 0 ]]; then
			_red "恢复DNS配置文件失败"
		else
			# 删除备份文件
			rm "$backupdns_config"
			if [[ $? -ne 0 ]]; then
				_red "删除备份文件失败"
			fi
		fi
	else
		_red "未找到DNS配置文件备份"
	fi
}

server_reboot(){
	local choice
	echo -n -e "${yellow}现在重启服务器吗?(y/n):${white}"
	read choice

	case "$choice" in
		[Yy])
			_green "已执行"
			reboot
			;;
		*)
			_yellow "已取消"
			;;
	esac
}

update_system(){
	wait_for_lock(){
		local timeout=300  # 设置超时时间为300秒(5分钟)
		local waited=0

		while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
			_yellow "等待dpkg锁释放"
			sleep 1
			waited=$((waited + 1))
			if [ $waited -ge $timeout ]; then
				_red "等待dpkg锁超时"
				break # 等待dpkg锁超时后退出循环
			fi
		done
	}

	# 修复dpkg中断问题
	fix_dpkg(){
		DEBIAN_FRONTEND=noninteractive dpkg --configure -a
	}

	_yellow "系统正在更新"
	if command -v dnf &>/dev/null; then
		dnf -y update
	elif command -v yum &>/dev/null; then
		yum -y update
	elif command -v apt &>/dev/null; then
		wait_for_lock
		fix_dpkg
		DEBIAN_FRONTEND=noninteractive apt update -y
		DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
	elif command -v apk &>/dev/null; then
		apk update && apk upgrade
	else
		_red "未知的包管理器!"
		return 1
	fi

	return 0
}

add_swap() {
	local new_swap=$1

	# 获取当前系统中所有的swap分区
	local swap_partitions
	swap_partitions=$(grep -E '^/dev/' /proc/swaps | awk '{print $1}')

	# 遍历并删除所有的swap分区
	for partition in $swap_partitions; do
		swapoff "$partition"
		wipefs -a "$partition"  # 清除文件系统标识符
		mkswap -f "$partition"
	done

	# 确保/swapfile不再被使用
	swapoff /swapfile 2>/dev/null

	# 删除旧的/swapfile
	if [ -f /swapfile ]; then
		rm -f /swapfile
	fi

	# 创建新的swap文件
	dd if=/dev/zero of=/swapfile bs=1M count=$new_swap status=progress
	chmod 600 /swapfile
	mkswap /swapfile
	swapon /swapfile

	# 更新fstab
	if ! grep -q '/swapfile' /etc/fstab; then
		echo "/swapfile swap swap defaults 0 0" | tee -a /etc/fstab
	fi

	# 针对Alpine Linux的额外设置
	if [ -f /etc/alpine-release ]; then
		echo "nohup swapon /swapfile" > /etc/local.d/swap.start
		chmod +x /etc/local.d/swap.start
		rc-update add local
	fi

	_green "虚拟内存大小已调整为 ${new_swap}MB"
}

check_swap() {
	# 获取当前总交换空间大小(以MB为单位)
	local swap_total
	swap_total=$(free -m | awk 'NR==3{print $2}')

	# 获取当前物理内存大小(以MB为单位)
	local mem_total
	mem_total=$(free -m | awk 'NR==2{print $2}')

	# 判断是否需要创建虚拟内存
	if [ "$swap_total" -le 0 ]; then
		if [ "$mem_total" -le 900 ]; then
			# 系统没有交换空间且物理内存小于等于900MB,设置默认的1024MB交换空间
			local new_swap=1024
			add_swap $new_swap
		else
			_green "物理内存大于900MB,不需要添加交换空间"
		fi
	else
		_green "系统已经有交换空间,总大小为 ${swap_total}MB"
	fi
}

linux_bbr() {
	clear
	if [ -f "/etc/alpine-release" ]; then
		while true; do
			clear
			# 使用局部变量
			local congestion_algorithm
			local queue_algorithm
			local choice

			congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
			queue_algorithm=$(sysctl -n net.core.default_qdisc)

			_yellow "当前TCP阻塞算法:$congestion_algorithm $queue_algorithm"

			echo ""
			echo "BBR管理"
			echo "-------------------------"
			echo "1. 开启BBRv3              2. 关闭BBRv3（会重启）"
			echo "-------------------------"
			echo "0. 返回上一级选单"
			echo "-------------------------"

			echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
			read choice

			case $choice in
				1)
					bbr_on
					;;
				2)
					sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
					sysctl -p
					server_reboot
					;;
				0)
					break  # 跳出循环,退出菜单
					;;
				*)
					break  # 跳出循环,退出菜单
					;;
			esac
		done
	else
		install wget
		wget --no-check-certificate -O tcpx.sh https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcpx.sh && chmod +x tcpx.sh && ./tcpx.sh
		rm tcpx.sh
	fi
}

docker_ps() {
	while true; do
		clear
		echo "Docker容器列表"
		docker ps -a
		echo ""
		echo "容器操作"
		echo "------------------------"
		echo "1. 创建新的容器"
		echo "------------------------"
		echo "2. 启动指定容器             6. 启动所有容器"
		echo "3. 停止指定容器             7. 停止所有容器"
		echo "4. 删除指定容器             8. 删除所有容器"
		echo "5. 重启指定容器             9. 重启所有容器"
		echo "------------------------"
		echo "11. 进入指定容器           12. 查看容器日志           13. 查看容器网络"
		echo "------------------------"
		echo "0. 返回上一级选单"
		echo "------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read choice
		case $choice in
			1)
				echo -n "请输入创建命令:" dockername
				$dockername
				;;
			2)
				echo -n "请输入容器名(多个容器名请用空格分隔):" dockername
				read dockername
				docker start $dockername
				;;
			3)
				echo -n "请输入容器名(多个容器名请用空格分隔):"
				read dockername
				docker stop $dockername
				;;
			4)
				echo -n "请输入容器名(多个容器名请用空格分隔):"
				read dockername
				docker rm -f $dockername
				;;
			5)
				echo -n "请输入容器名(多个容器名请用空格分隔):"
				read dockername
				docker restart $dockername
				;;
			6)
				docker start $(docker ps -a -q)
				;;
			7)
				docker stop $(docker ps -q)
				;;
			8)
				echo -n "${yellow}确定删除所有容器吗?(y/n)${white}"
				read choice

				case "$choice" in
					[Yy])
						docker rm -f $(docker ps -a -q)
						;;
					[Nn])
						;;
					*)
						_red "无效选项,请重新输入"
						;;
				esac
				;;
			9)
				docker restart $(docker ps -q)
				;;
			11)
				echo -n "请输入容器名:"
				read dockername
				docker exec -it $dockername /bin/sh
				end_of
				;;
			12)
				echo -n "请输入容器名:"
				read dockername
				docker logs $dockername
				end_of
				;;
			13)
				echo ""
				container_ids=$(docker ps -q)
				echo "------------------------------------------------------------"
				printf "%-25s %-25s %-25s\n" "容器名称" "网络名称" "IP地址"
				for container_id in $container_ids; do
					container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")
					container_name=$(echo "$container_info" | awk '{print $1}')
					network_info=$(echo "$container_info" | cut -d' ' -f2-)
					while IFS= read -r line; do
						network_name=$(echo "$line" | awk '{print $1}')
						ip_address=$(echo "$line" | awk '{print $2}')
						printf "%-20s %-20s %-15s\n" "$container_name" "$network_name" "$ip_address"
					done <<< "$network_info"
				done
				end_of
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

docker_image() {
	while true; do
		clear
		echo "Docker镜像列表"
		docker image ls
		echo ""
		echo "镜像操作"
		echo "------------------------"
		echo "1. 获取指定镜像             3. 删除指定镜像"
		echo "2. 更新指定镜像             4. 删除所有镜像"
		echo "------------------------"
		echo "0. 返回上一级选单"
		echo "------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read choice
		case $choice in
			1)
				echo -n "请输入镜像名(多个镜像名请用空格分隔):"
				read imagenames
				for name in $imagenames; do
					_yellow "正在获取镜像:" $name
					docker pull $name
				done
				;;
			2)
				echo -n "请输入镜像名(多个镜像名请用空格分隔):"
				read imagenames
				for name in $imagenames; do
					_yellow "正在更新镜像:" $name
					docker pull $name
				done
				;;
			3)
				echo -n "请输入镜像名(多个镜像名请用空格分隔):"
				read imagenames
				for name in $imagenames; do
					docker rmi -f $name
				done
				;;
			4)
				echo -n -e "${yellow}确定删除所有镜像吗?(y/n):${white}"
				read choice

				case "$choice" in
					[Yy])
						docker rmi -f $(docker images -q)
						;;
					[Nn])
						;;
					*)
						_red "无效选项,请重新输入"
						;;
				esac
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

docker_ipv6_on() {
	need_root
	install python3 >/dev/null 2>&1

	local CONFIG_FILE="/etc/docker/daemon.json"
	local REQUIRED_IPV6_CONFIG='{
		"ipv6": true,
		"fixed-cidr-v6": "2001:db8:1::/64"
	}'

	# 检查配置文件是否存在,如果不存在则创建文件并写入默认设置
	if [ ! -f "$CONFIG_FILE" ]; then
		echo "$REQUIRED_IPV6_CONFIG" > "$CONFIG_FILE"
		restart docker
	else
		# Python代码用于处理配置文件的更新
		local PYTHON_CODE=$(cat <<EOF
import json
import sys

config_file = sys.argv[1]

required_config = {
    "ipv6": True,
    "fixed-cidr-v6": "2001:db8:1::/64"
}

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    config = {}

original_config = dict(config)

config.update(required_config)

final_config = dict(config)

if original_config == final_config:
    print("NO_CHANGE")
else:
    with open(config_file, 'w') as f:
        json.dump(final_config, f, indent=4, sort_keys=False)
    print("RELOAD")
EOF
		)
		# 执行Python脚本并获取结果
		local RESULT=$(python3 -c "$PYTHON_CODE" "$CONFIG_FILE")

		# 根据Python脚本的输出结果进行相应操作
		if [[ "$RESULT" == *"RELOAD"* ]]; then
			restart docker
		elif [[ "$RESULT" == *"NO_CHANGE"* ]]; then
			_yellow "当前已开启IPV6访问"
		else
			_red "处理配置时发生错误"
		fi
	fi
}

docker_ipv6_off() {
	need_root
	install python3 >/dev/null 2>&1

	local CONFIG_FILE="/etc/docker/daemon.json"
	local PYTHON_CODE=$(cat <<EOF
import json
import sys

config_file = sys.argv[1]

# 期望的配置
required_config = {
    "ipv6": False,
}

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    config = {}

original_config = dict(config)

# 更新配置项,确保ipv6关闭,且移除fixed-cidr-v6
config['ipv6'] = False
config.pop('fixed-cidr-v6', None)

final_config = dict(config)

if original_config == final_config:
    print("NO_CHANGE")
else:
    with open(config_file, 'w') as f:
        json.dump(final_config, f, indent=4, sort_keys=False)
    print("RELOAD")
EOF
	)

	local RESULT=$(python3 -c "$PYTHON_CODE" "$CONFIG_FILE")

	if [[ "$RESULT" == *"RELOAD"* ]]; then
		restart docker
	elif [[ "$RESULT" == *"NO_CHANGE"* ]]; then
		_yellow "当前已关闭IPV6访问"
	else
		_red "处理配置时发生错误"
	fi
}

docker_manager() {
	while true; do
		clear
		echo "▶ Docker管理"
		echo "-------------------------"
		echo "1. 安装更新Docker环境"
		echo "-------------------------"
		echo "2. 查看Docker全局状态"
		echo "-------------------------"
		echo "3. Docker容器管理 ▶"
		echo "4. Docker镜像管理 ▶"
		echo "5. Docker网络管理 ▶"
		echo "6. Docker卷管理 ▶"
		echo "-------------------------"
		echo "7. 清理无用的docker容器和镜像网络数据卷"
		echo "------------------------"
		echo "8. 更换Docker源"
		echo "9. 编辑daemon.json文件"
		echo "------------------------"
		echo "11. 开启Docker-ipv6访问"
		echo "12. 关闭Docker-ipv6访问"
		echo "------------------------"
		echo "20. 卸载Docker环境"
		echo "------------------------"
		echo "0. 返回主菜单"
		echo "------------------------"
		
		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read choice

		case $choice in
			1)
				clear
				_yellow "嘿嘿"
				;;
			2)
				clear
				echo "Docker版本"
				docker -v
				docker compose version
				echo ""
				echo "Docker镜像列表"
				docker image ls
				echo ""
				echo "Docker容器列表"
				docker ps -a
				echo ""
				echo "Docker卷列表"
				docker volume ls
				echo ""
				echo "Docker网络列表"
				docker network ls
				echo ""
				;;
			3)
				docker_ps
				;;
			4)
				docker_image
				;;
			5)
				while true; do
					clear
					echo "Docker网络列表"
					echo "------------------------------------------------------------"
					docker network ls
					echo ""
					echo "------------------------------------------------------------"
					container_ids=$(docker ps -q)
					printf "%-25s %-25s %-25s\n" "容器名称" "网络名称" "IP地址"

					for container_id in $container_ids; do
						container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")
						container_name=$(echo "$container_info" | awk '{print $1}')
						network_info=$(echo "$container_info" | cut -d' ' -f2-)

						while IFS= read -r line; do
							network_name=$(echo "$line" | awk '{print $1}')
							ip_address=$(echo "$line" | awk '{print $2}')

							printf "%-20s %-20s %-15s\n" "$container_name" "$network_name" "$ip_address"
						done <<< "$network_info"
					done

					echo ""
					echo "网络操作"
					echo "------------------------"
					echo "1. 创建网络"
					echo "2. 加入网络"
					echo "3. 退出网络"
					echo "4. 删除网络"
					echo "------------------------"
					echo "0. 返回上一级选单"
					echo "------------------------"

					echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
					read choice

					case $choice in
						1)
							echo -n "设置新网络名:"
							read dockernetwork
							docker network create $dockernetwork
							;;
						2)
							echo -n "设置新网络名:"
							read dockernetwork
							echo -n "设置新网络名:"
							read dockernames

							for dockername in $dockernames; do
								docker network connect $dockernetwork $dockername
							done                  
							;;
						3)
							echo -n "设置新网络名:"
							read dockernetwork

							echo -n "那些容器退出该网络(多个容器名请用空格分隔):"
							read dockernames
                          
							for dockername in $dockernames; do
								docker network disconnect $dockernetwork $dockername
							done
							;;
						4)
							echo -n "请输入要删除的网络名:"
							read dockernetwork
							docker network rm $dockernetwork
							;;
						0)
							break  # 跳出循环，退出菜单
							;;
						*)
							_red "无效选项,请重新输入"
							;;
					esac
				done
				;;
			6)
				while true; do
					clear
					echo "Docker卷列表"
					docker volume ls
					echo ""
					echo "卷操作"
					echo "------------------------"
					echo "1. 创建新卷"
					echo "2. 删除指定卷"
					echo "3. 删除所有卷"
					echo "------------------------"
					echo "0. 返回上一级选单"
					echo "------------------------"

					echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
					read choice

					case $choice in
						1)
							echo -n "设置新卷名:"
							read dockerjuan
							docker volume create $dockerjuan
							;;
						2)
							echo -n "输入删除卷名(多个卷名请用空格分隔):"
							read dockerjuans

							for dockerjuan in $dockerjuans; do
								docker volume rm $dockerjuan
							done
							;;
						3)
							echo -n "确定删除所有未使用的卷吗:"
							read choice
							case "$choice" in
								[Yy])
									docker volume prune -f
									;;
								[Nn])
									;;
								*)
									_red "无效选项,请重新输入"
									;;
							esac
							;;
						0)
							break  # 跳出循环,退出菜单
							;;
						*)
							_red "无效选项,请重新输入"
							;;
					esac
				done
				;;
			7)
				clear
				echo -n "将清理无用的镜像容器网络，包括停止的容器，确定清理吗?(y/n):"
				read  choice

				case "$choice" in
					[Yy])
						docker system prune -af --volumes
						;;
					[Nn])
						;;
					*)
						_red "无效选项,请重新输入"
						;;
				esac
				;;
			8)
				clear
				bash <(curl -sSL https://linuxmirrors.cn/docker.sh)
				;;
			9)
				clear
				mkdir /etc/docker -p && vim /etc/docker/daemon.json
				restart docker
				;;
			11)
				clear
				docker_ipv6_on
				;;
			12)
				clear
				docker_ipv6_off
				;;
			20)
				clear
				echo -n -e "${yellow}确定卸载docker环境吗?(y/n)${white}"
				read choice

				case "$choice" in
					[Yy])
						docker rm $(docker ps -a -q) && docker rmi $(docker images -q) && docker network prune
						remove docker docker-compose docker-ce docker-ce-cli containerd.io
						;;
					[Nn])
						;;
					*)
						_red "无效选项,请重新输入"
						;;
				esac
				;;
			0)
				honeok
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
		end_of
	done
}

linux_tools() {
	while true; do
		clear
		echo "▶ 常用工具"
		echo "-------------------------"
		echo "1. curl 下载工具                      2. wget下载工具"
		echo "3. sudo 超级管理权限工具              4. socat 通信连接工具"
		echo "5. htop 系统监控工具                  6. iftop 网络流量监控工具"
		echo "7. unzip ZIP压缩解压工具              8. tar GZ压缩解压工具"
		echo "9. tmux 多路后台运行工具              10. ffmpeg 视频编码直播推流工具"
		echo "-------------------------"
		echo "11. btop 现代化监控工具               12. ranger 文件管理工具"
		echo "13. Gdu 磁盘占用查看工具              14. fzf 全局搜索工具"
		echo "15. Vim文本编辑器                     16. nano文本编辑器"
		echo "-------------------------"
		echo "21. 黑客帝国屏保                      22. 跑火车屏保"
		echo "26. 俄罗斯方块小游戏                  27. 贪吃蛇小游戏"
		echo "28. 太空入侵者小游戏"
		echo "-------------------------"
		echo "31. 全部安装                          32. 全部安装(不含屏保和游戏)"
		echo "33. 全部卸载"
		echo "-------------------------"
		echo "41. 安装指定工具                      42. 卸载指定工具"
		echo "-------------------------"
		echo "0. 返回主菜单"
		echo "-------------------------"
		
		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read choice

		case $choice in
			1)
				clear
				install curl
				clear
				_yellow "工具已安装,使用方法如下:"
				curl --help
				;;
			2)
				clear
				install wget
				clear
				_yellow "工具已安装,使用方法如下:"
				wget --help
				;;
			3)
				clear
				install sudo
				clear
				_yellow "工具已安装,使用方法如下:"
				sudo --help
				;;
			4)
				clear
				install socat
				clear
				_yellow "工具已安装,使用方法如下："
				socat -h
				;;
			5)
				clear
				install htop
				clear
				htop
				;;
			6)
				clear
				install iftop
				clear
				iftop
				;;
			7)
				clear
				install unzip
				clear
				_yellow "工具已安装,使用方法如下："
				unzip
				;;
			8)
				clear
				install tar
				clear
				_yellow "工具已安装,使用方法如下："
				tar --help
				;;
			9)
				clear
				install tmux
				clear
				_yellow "工具已安装,使用方法如下："
				tmux --help
				;;
			10)
				clear
				install ffmpeg
				clear
				_yellow "工具已安装,使用方法如下："
				ffmpeg --help
				send_stats "安装ffmpeg"
				;;
			11)
				clear
				install btop
				clear
				btop
				;;
			12)
				clear
				install ranger
				cd /
				clear
				ranger
				cd ~
				;;
			13)
				clear
				install gdu
				cd /
				clear
				gdu
				cd ~
				;;
			14)
				clear
				install fzf
				cd /
				clear
				fzf
				cd ~
				;;
			15)
				clear
				install vim
				cd /
				clear
				vim -h
				cd ~
				;;
			16)
				clear
				install nano
				cd /
				clear
				nano -h
				cd ~
				;;
			21)
				clear
				install cmatrix
				clear
				cmatrix
				;;
			22)
				clear
				install sl
				clear
				sl
				;;
			26)
				clear
				install bastet
				clear
				bastet
				;;
			27)
				clear
				install nsnake
				clear
				nsnake
				;;
			28)
				clear
				install ninvaders
				clear
				ninvaders
				;;
			31)
				clear
				install curl wget sudo socat htop iftop unzip tar tmux ffmpeg btop ranger gdu fzf cmatrix sl bastet nsnake ninvaders vim nano
				;;
			32)
				clear
				install curl wget sudo socat htop iftop unzip tar tmux ffmpeg btop ranger gdu fzf vim nano
				;;
			33)
				clear
				remove htop iftop unzip tmux ffmpeg btop ranger gdu fzf cmatrix sl bastet nsnake ninvaders vim nano
				;;
			41)
				clear
				echo -n -e "${yellow}请输入安装的工具名(wget curl sudo htop):${white}"
				read installname
				install $installname
				;;
			42)
				clear
				echo -n -e "${yellow}请输入卸载的工具名(htop ufw tmux cmatrix):${white}"
				read removename
				remove $removename
				;;
			0)
				honeok
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
		end_of
	done
}

node_create(){
	if [ $(curl -s ipinfo.io/country) = "CN" ];then
		clear
		_red "请遵守你当地的法律法规"
		sleep 1
		honeok # 返回主菜单
	fi

	local choice
	while true; do
		clear
		echo "▶ 节点搭建脚本合集"
		echo "-------------------------------"
		echo "  Sing-box多合一/Argo-tunnel"
		echo "-------------------------------"
		echo "1. Fscarmen Sing-box一键脚本"
		echo "2. Fscarmen ArgoX一键脚本"
		echo "5. 233boy Sing-box一键脚本"
		echo "6. 梭哈一键Argo脚本"
		echo "7. WL一键Argo哪吒脚本"
		echo "-------------------------------"
		echo "     单协议/XRAY面板及其他"
		echo "-------------------------------"
		echo "22. Brutal-Reality一键脚本"
		echo "23. Vaxilu X-UI面板一键脚本"
		echo "24. FranzKafkaYu X-UI面板一键脚本"
		echo "25. Alireza0 X-UI面板一键脚本"
		echo "31. MHSanaei 3X-UI面板一键脚本"
		echo "-------------------------------"
		echo "35. OpenVPN一键安装脚本"
		echo "36. 一键搭建TG代理"
		echo "-------------------------------"
		echo "0. 返回主菜单"
		echo "-------------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read choice

		case $choice in

			1)
				clear
				install wget
				bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh)
				;;
			2)
				clear
				install wget
				bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/argox/main/argox.sh)
				;;
			5)
				clear
				install wget
				bash <(wget -qO- -o- https://github.com/233boy/sing-box/raw/main/install.sh)
				;;
			6)
				clear
				curl https://www.baipiao.eu.org/suoha.sh -o suoha.sh && bash suoha.sh
				;;            
			7)
				clear
				bash <(curl -sL https://raw.githubusercontent.com/dsadsadsss/vps-argo/main/install.sh)
				;;
			22)
				clear
				_yellow "安装Tcp-Brutal-Reality需要内核高于5.8,不符合请手动升级5.8内核以上再安装"
				
				current_kernel_version=$(uname -r | cut -d'-' -f1 | awk -F'.' '{print $1 * 100 + $2}')
				target_kernel_version=508
				
				# 比较内核版本
				if [ "$current_kernel_version" -lt "$target_kernel_version" ]; then
					_red "当前系统内核版本小于 $target_kernel_version,请手动升级内核后重试,正在退出"
					sleep 2
					honeok
				else
					_yellow "当前系统内核版本 $current_kernel_version,符合安装要求"
					sleep 1
					bash <(curl -fsSL https://github.com/vveg26/sing-box-reality-hysteria2/raw/main/tcp-brutal-reality.sh)
					sleep 1
				fi
				;;
			23)
				clear
				bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
				;;
			24)
				clear
				bash <(curl -Ls https://raw.githubusercontent.com/FranzKafkaYu/x-ui/master/install.sh)
				;;
			25)
				clear
				bash <(curl -Ls https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh)
				;;
			31)
				clear
				bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
				;;
			35)
				clear
				install wget
				wget https://git.io/vpn -O openvpn-install.sh && bash openvpn-install.sh
				;;
			36)
				clear
				rm -rf /home/mtproxy && mkdir /home/mtproxy && cd /home/mtproxy
				curl -fsSL -o mtproxy.sh https://github.com/ellermister/mtproxy/raw/master/mtproxy.sh && chmod +x mtproxy.sh && bash mtproxy.sh
				sleep 1
				;;
			0)
				honeok # 返回主菜单
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
	done
}

add_sshpasswd() {
	_yellow "设置你的ROOT密码"
	passwd
	sed -i 's/^\s*#\?\s*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
	sed -i 's/^\s*#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
	rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*
	restart_ssh

	_green "ROOT登录设置完毕"
}

restart_ssh() {
	restart sshd ssh > /dev/null 2>&1
}

oracle_script() {
	while true; do
		clear
		echo "▶ 甲骨文云脚本合集"
		echo "-------------------------"
		echo "1. 安装闲置机器活跃脚本"
		echo "2. 卸载闲置机器活跃脚本"
		echo "-------------------------"
		echo "3. DD重装系统脚本"
		echo "4. R探长开机脚本"
		echo "-------------------------"
		echo "5. 开启ROOT密码登录模式"
		echo "-------------------------"
		echo "0. 返回主菜单"
		echo "------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read choice

		case $choice in
			1)
				clear
				_yellow "活跃脚本: CPU占用10-20% 内存占用20%"
				echo -n -e "${yellow}确定安装吗?(y/n/):${white}"
				read ins
				
				case "$ins" in
					[Yy])
						#install_docker
						# 设置默认值
						DEFAULT_CPU_CORE=1
						DEFAULT_CPU_UTIL="10-20"
						DEFAULT_MEM_UTIL=20
						DEFAULT_SPEEDTEST_INTERVAL=120

						# 提示用户输入CPU核心数和占用百分比,如果回车则使用默认值
						echo -n -e "${yellow}请输入CPU核心数[默认:$DEFAULT_CPU_CORE]:${white}"
						read cpu_core
						cpu_core=${cpu_core:-$DEFAULT_CPU_CORE}

						echo -n -e "${yellow}请输入CPU占用百分比范围(例如10-20)[默认:$DEFAULT_CPU_UTIL]:${white}"
						read cpu_util
						cpu_util=${cpu_util:-$DEFAULT_CPU_UTIL}

						echo -n -e "${yellow}请输入内存占用百分比[默认:$DEFAULT_MEM_UTIL]:${white}"
						read mem_util
						mem_util=${mem_util:-$DEFAULT_MEM_UTIL}

						echo -n -e "${yellow}请输入Speedtest间隔时间(秒)[默认:$DEFAULT_SPEEDTEST_INTERVAL]:${white}"
						read speedtest_interval
						speedtest_interval=${speedtest_interval:-$DEFAULT_SPEEDTEST_INTERVAL}

						# 运行Docker容器
						docker run -itd --name=lookbusy --restart=always \
							-e TZ=Asia/Shanghai \
							-e CPU_UTIL="$cpu_util" \
							-e CPU_CORE="$cpu_core" \
							-e MEM_UTIL="$mem_util" \
							-e SPEEDTEST_INTERVAL="$speedtest_interval" \
							fogforest/lookbusy
						;;
					[Nn])
						echo ""
						;;
					*)
						_red "无效选项,请输入Y或N"
						;;
				esac
				;;
			2)
				clear
				docker rm -f lookbusy
				docker rmi fogforest/lookbusy
				_green "成功卸载甲骨文活跃脚本"
				;;
			3)
				clear
				_yellow "重装系统"
				echo "-------------------------"
				_yellow "注意:重装有风险失联,不放心者慎用,重装预计花费15分钟,请提前备份数据"
				
				echo -n -e "${yellow}确定继续吗?(y/n):${white}"
				read choice

				case "$choice" in
					[Yy])
						while true; do
							echo -n -e "${yellow}请选择要重装的系统:  1. Debian12 | 2. Ubuntu20.04${white}"
							read sys_choice

							case "$sys_choice" in
								1)
									xitong="-d 12"
									break  # 结束循环
									;;
								2)
									xitong="-u 20.04"
									break  # 结束循环
									;;
								*)
									_red "无效选项,请重新输入"
									;;
							esac
						done

						echo -n -e "${yellow}请输入你重装后的密码:${white}"
						read vpspasswd
				
						install wget
						bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/MoeClub/Note/master/InstallNET.sh') $xitong -v 64 -p $vpspasswd -port 22
						;;
					[Nn])
						_yellow "已取消"
						;;
					*)
						_red "无效选项,请输入Y或N"
						;;
				esac
				;;
			4)
				clear
				_yellow "该功能处于开发阶段,敬请期待!"
				;;
			5)
				clear
				add_sshpasswd
				;;
			0)
				honeok
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
		end_of
    done
}

# 查看系统信息
system_info(){
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

	echo ""
	echo "系统信息查询"
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

cloudflare_ddns() {
	need_root

	local choice CFKEY CFUSER CFZONE_NAME CFRECORD_NAME CFRECORD_TYPE CFTTL
	local EXPECTED_HASH="81d3d4528a99069c81f1150bb9fa798684b27f5a0248cd4c227200055ecfa8a9"
	local ipv4_address=$(curl -s ipv4.ip.sb)
	local ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb)

	while true; do
		clear
		echo "Cloudflare ddns解析"
		echo "-------------------------"
		if [ -f /usr/local/bin/cf-ddns.sh ] || [ -f ~/cf-v4-ddns.sh ];then
			echo -e "${yellow}Cloudflare ddns: ${white}${green}已安装${white}"
			crontab -l | grep "/usr/local/bin/cf-ddns.sh"
		else
			_yellow "Cloudflare ddns: 未安装"
			_yellow "使用动态解析之前请解析一个域名,如ddns.honeok.com到你的当前公网IP"
		fi
		echo "公网IPV4地址: ${ipv4_address}"
		echo "公网IPV6地址: ${ipv6_address}"
		echo "-------------------------"
		echo "1. 设置DDNS动态域名解析    2. 删除DDNS动态域名解析"
		echo "-------------------------"
		echo "0. 返回上一级"
		echo "-------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read choice

		case $choice in
			1)
				# 获取CFKEY
				while true; do
					echo "cloudflare后台右上角我的个人资料,选择左侧API令牌,获取Global API Key"
					echo "https://dash.cloudflare.com/login"
					echo -n "请输入你的Global API Key:"
					read CFKEY
					if [[ -n "$CFKEY" ]]; then
						break
					else
						_red "CFKEY不能为空,请重新输入"
					fi
				done

				# 获取CFUSER
				while true; do
					echo -n "请输入你的Cloudflare管理员邮箱:"
					read CFUSER
					if [[ "$CFUSER" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
						break
					else
						_red "无效的邮箱格式,请重新输入"
					fi
				done
				
				# 获取CFZONE_NAME
				while true; do
					echo -n "请输入你的顶级域名(如honeok.com):"
					read CFZONE_NAME
					if [[ "$CFZONE_NAME" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
						break
					else
						_red "无效的域名格式,请重新输入"
					fi
				done
				
				# 获取CFRECORD_NAME
				while true; do
					echo -n "请输入你的主机名(如ddns.honeok.com):"
					read CFRECORD_NAME
					if [[ -n "$CFRECORD_NAME" ]]; then
						break
					else
						_red "主机名不能为空,请重新输入"
					fi
				done

				# 获取CFRECORD_TYPE
				echo -n "请输入记录类型(A记录或AAAA记录,默认IPV4 A记录,回车使用默认值):"
				read CFRECORD_TYPE
				CFRECORD_TYPE=${CFRECORD_TYPE:-A}

				# 获取CFTTL
				echo -n "请输入TTL时间(120~86400秒,默认60秒,回车使用默认值):"
				read CFTTL
				CFTTL=${CFTTL:-60}

				curl -fsSL -o ~/cf-v4-ddns.sh https://raw.githubusercontent.com/honeok8s/shell/main/callscript/cf-v4-ddns.sh
				# 计算文件哈希
				FILE_HASH=$(sha256sum ~/cf-v4-ddns.sh | awk '{ print $1 }')
				
				# 校验哈希值
				if [ "$FILE_HASH" != "$EXPECTED_HASH" ]; then
					_red "文件哈希校验失败,脚本可能被篡改"
					sleep 1
					rm ~/cf-v4-ddns.sh
					linux_system_tools # 返回系统工具菜单
				fi

				sed -i "s/^CFKEY=honeok$/CFKEY=$CFKEY/" ~/cf-v4-ddns.sh
				sed -i "s/^CFUSER=honeok@gmail.com$/CFUSER=$CFUSER/" ~/cf-v4-ddns.sh
				sed -i "s/^CFZONE_NAME=honeok.com$/CFZONE_NAME=$CFZONE_NAME/" ~/cf-v4-ddns.sh
				sed -i "s/^CFRECORD_NAME=honeok$/CFRECORD_NAME=$CFRECORD_NAME/" ~/cf-v4-ddns.sh
				sed -i "s/^CFRECORD_TYPE=A$/CFRECORD_TYPE=$CFRECORD_TYPE/" ~/cf-v4-ddns.sh
				sed -i "s/^CFTTL=60$/CFTTL=$CFTTL/" ~/cf-v4-ddns.sh

				# 复制脚本并设置权限
				cp ~/cf-v4-ddns.sh /usr/local/bin/cf-ddns.sh && chmod a+x /usr/local/bin/cf-ddns.sh

				check_crontab_installed

				if ! (crontab -l 2>/dev/null; echo "*/1 * * * * /usr/local/bin/cf-ddns.sh >/dev/null 2>&1") | crontab -;then
					_red "无法自动添加cron任务,请手动添加以下行到crontab:"
					_yellow "*/1 * * * * /usr/local/bin/cf-ddns.sh >/dev/null 2>&1"
					_yellow "按任意键继续"
					read -n 1 -s -r -p ""
				fi

				_green "Cloudflare ddns安装完成"
				;;
			2)
				if [ -f /usr/local/bin/cf-ddns.sh ]; then
					sudo rm /usr/local/bin/cf-ddns.sh
				else
					_red "/usr/local/bin/cf-ddns.sh文件不存在"
				fi

				if crontab -l 2>/dev/null | grep -q '/usr/local/bin/cf-ddns.sh'; then
					if (crontab -l 2>/dev/null | grep -v '/usr/local/bin/cf-ddns.sh') | crontab -; then
						_green "定时任务已成功移除"
					else
						_red "无法移除定时任务,请手动移除"
						_yellow "您可以手动删除定时任务中包含 '/usr/local/bin/cf-ddns.sh' 的那一行"
						_yellow "按任意键继续"
						read -n 1 -s -r -p ""
					fi
				else
					_red "定时任务中未找到与 '/usr/local/bin/cf-ddns.sh' 相关的任务"
				fi

				if [ -f ~/cf-v4-ddns.sh ]; then
					rm ~/cf-v4-ddns.sh
				fi

				_green "Cloudflare ddns卸载完成"
				;;
			0)
				break
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
		end_of
	done
}

linux_mirror(){
	local choice
	need_root

	while true; do
		clear
		echo "选择更新源区域"
		echo "接入LinuxMirrors切换系统更新源"
		echo "-------------------------"
		echo "1. 中国大陆[默认]          2. 中国大陆[教育网]          3. 海外地区"
		echo "-------------------------"
		echo "0. 返回上一级"
		echo "-------------------------"
	
		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read choice
	
		case $choice in
			1)
				bash <(curl -sSL https://linuxmirrors.cn/main.sh)
				;;
			2)
				bash <(curl -sSL https://linuxmirrors.cn/main.sh) --edu
				;;
			3)
				bash <(curl -sSL https://linuxmirrors.cn/main.sh) --abroad
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

check_crontab_installed() {
	if ! command -v crontab >/dev/null 2>&1; then
		install_crontab
		return $?
	fi
}

install_crontab() {
	if [ -f /etc/os-release ]; then
		. /etc/os-release
			case "$ID" in
				ubuntu|debian|kali)
					apt update
					apt install -y cron
					systemctl enable cron
					systemctl start cron
					;;
				centos|rhel|almalinux|rocky|fedora)
					yum install -y cronie
					systemctl enable crond
					systemctl start crond
					;;
				alpine)
					apk add --no-cache cronie
					rc-update add crond
					rc-service crond start
					;;
				arch|manjaro)
					pacman -S --noconfirm cronie
					systemctl enable cronie
					systemctl start cronie
					;;
				opensuse|suse|opensuse-tumbleweed)
					zypper install -y cron
					systemctl enable cron
					systemctl start cron
					;;
				*)
					_red "不支持的发行版:$ID"
					exit 1
					;;
			esac
	else
		_red "无法确定操作系统。"
		exit 1
	fi

	_yellow "Crontab已安装且Cron服务正在运行"
}

cron_manager(){
	local choice newquest dingshi day weekday hour minute kquest

	while true; do
		clear
		check_crontab_installed
		clear
		echo "定时任务列表"
		echo "-------------------------"
		crontab -l
		echo "-------------------------"
		echo "操作"
		echo "-------------------------"
		echo "1. 添加定时任务              2. 删除定时任务"
		echo "3. 编辑定时任务              4. 删除所有定时任务"
		echo "-------------------------"
		echo "0. 返回上一级选单"
		echo "-------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read choice

		case $choice in
			1)
				echo -n -e "${yellow}请输入新任务的执行命令:${white}"
				read newquest
				echo "-------------------------"
				echo "1. 每月任务                 2. 每周任务"
				echo "3. 每天任务                 4. 每小时任务"
				echo "-------------------------"

				echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
				read dingshi

				case $dingshi in
					1)
						echo -n -e "${yellow}选择每月的几号执行任务?(1-30):${white}"
						read day
						if [[ ! $day =~ ^[1-9]$|^[12][0-9]$|^30$ ]]; then
							_red "无效的日期输入"
							continue
						fi
						if ! (crontab -l ; echo "0 0 $day * * $newquest") | crontab - > /dev/null 2>&1; then
							_red "添加定时任务失败"
						fi
						;;
					2)
						echo -n -e "${yellow}选择周几执行任务?(0-6，0代表星期日):${white}"
						read weekday
						if [[ ! $weekday =~ ^[0-6]$ ]]; then
							_red "无效的星期输入"
							continue
						fi
						if ! (crontab -l ; echo "0 0 * * $weekday $newquest") | crontab - > /dev/null 2>&1; then
							_red "添加定时任务失败"
						fi
						;;
					3)
						echo -n -e "${yellow}选择每天几点执行任务?(小时,0-23):${white}"
						read hour
						if [[ ! $hour =~ ^[0-9]$|^[1][0-9]$|^[2][0-3]$ ]]; then
							_red "无效的小时输入"
							continue
						fi
						if ! (crontab -l ; echo "0 $hour * * * $newquest") | crontab - > /dev/null 2>&1; then
							_red "添加定时任务失败"
						fi
						;;
					4)
						echo -n -e "${yellow}输入每小时的第几分钟执行任务?(分钟,0-60):${white}"
						read minute
						if [[ ! $minute =~ ^[0-5][0-9]$ ]]; then
							_red "无效的分钟输入"
							continue
						fi
						if ! (crontab -l ; echo "$minute * * * * $newquest") | crontab - > /dev/null 2>&1; then
							_red "添加定时任务失败"
						fi
						;;
					*)
						break  # 跳出
						;;
				esac
				;;
			2)
				echo -n -e "${yellow}请输入需要删除任务的关键字:${white}"
				read kquest
				if crontab -l | grep -v "$kquest" | crontab -; then
					_green "$kquest 定时任务已删除"
				else
					_red "删除定时任务失败"
				fi
				;;
			3)
				crontab -e
				;;
			4)
				if crontab -r >/dev/null; then
					_green "所有定时任务已删除"
				else
					_red "删除所有定时任务失败"
				fi
				;;
			0)
				break  # 跳出循环,退出菜单
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
	done
}
telegram_bot(){
	need_root

	local choice TG_check_notify TG_SSH_check_notify
	local TG_check_notify_hash="1a5694045098d5ceed3ab6d9b2827dea9677a0a6aa9cade357dec4a2bc514444"
	local TG_SSH_check_notify_hash="61813dc31c2a3d335924a5d24bf212350848dc748c4811e362c06a9b313167c1"

	echo "TG-bot监控预警功能"
	echo "----------------------------"
	echo "您需要配置TG机器人API和接收预警的用户ID,即可实现本机CPU/内存/硬盘/流量/SSH登录的实时监控预警"
	echo "到达阈值后会向用户发预警消息,流量重启服务器将重新计算"
	echo "----------------------------"
				
	echo -n -e "${yellow}确定继续吗?(y/n):${white}"
	read choice

	case "$choice" in
		[Yy])
			cd ~
			install tmux bc jq
			check_crontab_installed

			if [ -f ~/TG-check-notify.sh ]; then
				chmod +x ~/TG-check-notify.sh
				vim ~/TG-check-notify.sh
			else
				curl -fsSL -o ~/TG-check-notify.sh https://raw.githubusercontent.com/honeok8s/shell/main/callscript/TG-check-notify.sh
				# 计算文件哈希
				TG_check_notify=$(sha256sum ~/TG-check-notify.sh | awk '{ print $1 }')

				# 校验哈希值
				if [ "$TG_check_notify" != "$TG_check_notify_hash" ]; then
					_red "文件哈希校验失败,脚本可能被篡改"
					sleep 1
					rm ~/TG-check-notify.sh
					linux_system_tools # 返回系统工具菜单
				else
					chmod +x ~/TG-check-notify.sh
					vim ~/TG-check-notify.sh
				fi
			fi
			tmux kill-session -t TG-check-notify > /dev/null 2>&1
			tmux new -d -s TG-check-notify "~/TG-check-notify.sh"
			crontab -l | grep -v '~/TG-check-notify.sh' | crontab - > /dev/null 2>&1
			(crontab -l ; echo "@reboot tmux new -d -s TG-check-notify '~/TG-check-notify.sh'") | crontab - > /dev/null 2>&1

			curl -fsSL -o ~/TG-SSH-check-notify.sh https://raw.githubusercontent.com/honeok8s/shell/main/callscript/TG-SSH-check-notify.sh
			# 计算文件哈希
			TG_SSH_check_notify=$(sha256sum ~/TG-SSH-check-notify.sh | awk '{ print $1 }')

			# 校验哈希值
			if [ "$TG_SSH_check_notify" != "$TG_SSH_check_notify_hash" ]; then
				_red "文件哈希校验失败,脚本可能被篡改"
				sleep 1
				rm ~/TG-SSH-check-notify.sh
				linux_system_tools # 返回系统工具菜单
			else
				sed -i "3i$(grep '^TELEGRAM_BOT_TOKEN=' ~/TG-check-notify.sh)" TG-SSH-check-notify.sh
				sed -i "4i$(grep '^CHAT_ID=' ~/TG-check-notify.sh)" TG-SSH-check-notify.sh
				chmod +x ~/TG-SSH-check-notify.sh
			fi

			# 添加到~/.profile文件中
			if ! grep -q 'bash ~/TG-SSH-check-notify.sh' ~/.profile > /dev/null 2>&1; then
				echo 'bash ~/TG-SSH-check-notify.sh' >> ~/.profile
					if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
						echo 'source ~/.profile' >> ~/.bashrc
					fi
			fi

			source ~/.profile

			clear
			_green "TG-bot预警系统已启动"
			_yellow "你还可以将root目录中的TG-check-notify.sh预警文件放到其他机器上直接使用!"
			;;
		[Nn])
			_yellow "已取消"
			;;
		*)
			_red "无效选项,请重新输入"
			;;
	esac
}

xanmod_bbr3(){
	local choice
	need_root

	echo "XanMod BBR3管理"
	if dpkg -l | grep -q 'linux-xanmod'; then
		while true; do
			clear
			local kernel_version=$(uname -r)
			echo "您已安装XanMod的BBRv3内核"
			echo "当前内核版本: $kernel_version"

			echo ""
			echo "内核管理"
			echo "-------------------------"
			echo "1. 更新BBRv3内核              2. 卸载BBRv3内核"
			echo "-------------------------"
			echo "0. 返回上一级选单"
			echo "-------------------------"

			echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
			read choice

			case $choice in
				1)
					apt purge -y 'linux-*xanmod1*'
					update-grub
					# wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes
					wget -qO - https://raw.githubusercontent.com/honeok8s/shell/main/callscript/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes

					# 添加存储库
					echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list

					# kernel_version=$(wget -q https://dl.xanmod.org/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')
					local kernel_version=$(wget -q https://raw.githubusercontent.com/honeok8s/shell/main/callscript/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')

					apt update -y
					apt install -y linux-xanmod-x64v$kernel_version

					_green "XanMod内核已更新,重启后生效"
					rm -f /etc/apt/sources.list.d/xanmod-release.list
					rm -f check_x86-64_psabi.sh*

					server_reboot
					;;
				2)
					apt purge -y 'linux-*xanmod1*'
					update-grub
					_green "XanMod内核已卸载,重启后生效"
					server_reboot
					;;
				0)
					break  # 跳出循环,退出菜单
					;;
				*)
					_red "无效选项,请重新输入"
					;;
			esac
		done
	else
		# 未安装则安装
		clear
		echo "请备份数据,将为你升级Linux内核开启XanMod BBR3"
		echo "------------------------------------------------"
		echo "仅支持Debian/Ubuntu 仅支持x86_64架构"
		echo "VPS是512M内存的,请提前添加1G虚拟内存,防止因内存不足失联!"
		echo "------------------------------------------------"

		echo -n -e "${yellow}确定继续吗?(y/n)${white}"
		read choice

		case "$choice" in
			[Yy])
				if [ -r /etc/os-release ]; then
					. /etc/os-release
					if [ "$ID" != "debian" ] && [ "$ID" != "ubuntu" ]; then
						_red "当前环境不支持,仅支持Debian和Ubuntu系统"
						end_of
						linux_system_tools
					fi
				else
					_red "无法确定操作系统类型"
					end_of
					linux_system_tools
				fi

				# 检查系统架构
				local arch=$(dpkg --print-architecture)
				if [ "$arch" != "amd64" ]; then
					_red "当前环境不支持,仅支持x86_64架构"
					end_of
					linux_system_tools
				fi

				check_swap
				install wget gnupg

				# wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes
				wget -qO - https://raw.githubusercontent.com/honeok8s/shell/main/callscript/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes

				# 添加存储库
				echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list

				# kernel_version=$(wget -q https://dl.xanmod.org/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')
				local kernel_version=$(wget -q https://raw.githubusercontent.com/honeok8s/shell/main/callscript/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')

				apt update -y
				apt install -y linux-xanmod-x64v$kernel_version

				set_default_qdisc
				bbr_on

				_green "XanMod内核安装并启用BBR3成功,重启后生效!"
				rm -f /etc/apt/sources.list.d/xanmod-release.list
				rm -f check_x86-64_psabi.sh*
				
				server_reboot
				;;
			[Nn])
				_yellow "已取消"
				;;
			*)
				_red "无效的选择,请输入Y或N"
				;;
		esac
	fi
}
		
reinstall_system(){
	MollyLau_script(){
		wget --no-check-certificate -qO InstallNET.sh 'https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh' && chmod a+x InstallNET.sh
	}

	bin456789_script(){
		if [ $(curl -s ipinfo.io/country) != "CN" ];then
			curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
		else
			curl -O https://jihulab.com/bin456789/reinstall/-/raw/main/reinstall.sh
		fi
	}

	dd_linux_mollyLau(){
		_yellow "重装后初始用户名: \"root\"  默认密码: \"LeitboGi0ro\"  默认ssh端口: \"22\""
		_yellow "详细参数参考Github项目地址：https://github.com/leitbogioro/Tools"
		_yellow "按任意键继续"
		read -n 1 -s -r -p ""
		install wget
		MollyLau_script
	}

	dd_windows_mollyLau() {
		_yellow "Windows默认用户名：\"Administrator\" 默认密码：\"Teddysun.com\" 默认远程连接端口: \"3389\""
		_yellow "详细参数参考Github项目地址：https://github.com/leitbogioro/Tools"
		_yellow "按任意键继续"
		read -n 1 -s -r -p ""
		install wget
		MollyLau_script
	}

	dd_linux_bin456789() {
		_yellow "重装后初始用户名: \"root\"  默认密码: \"123@@@\"  默认ssh端口: \"22\""
		_yellow "详细参数参考Github项目地址：https://github.com/bin456789/reinstall"
		_yellow "按任意键继续"
		read -n 1 -s -r -p ""
		bin456789_script
	}

	dd_windows_bin456789() {
		_yellow "Windows默认用户名：\"Administrator\" 默认密码：\"123@@@\" 默认远程连接端口: \"3389\""
		_yellow "详细参数参考Github项目地址：https://github.com/bin456789/reinstall"
		_yellow "按任意键继续"
		read -n 1 -s -r -p ""
		bin456789_script
	}

	# 简单判断是否为lxc和openvz容器,随后调用酒神脚本
	dd_openvz_lxc_LloydAsp() {
		if grep -q 'container=lxc' /proc/1/environ || [ -f /proc/vz/veinfo ]; then
			_green "虚拟化环境校验通过"
			install wget
			wget -qO OsMutation.sh https://raw.githubusercontent.com/LloydAsp/OsMutation/main/OsMutation.sh && chmod u+x OsMutation.sh
			bash OsMutation.sh
		else
			clear
			_red "未检测到支持的虚拟化环境(Lxc或OpenVZ)"
			sleep 2
			return
		fi
	}

	# 重装系统
	local choice
	while true; do
		need_root
		clear
		echo "重装有风险失联,不放心者慎用,重装预计花费15分钟,请提前备份数据"
		echo "感谢MollyLau和bin456789的脚本支持!"
		echo "-------------------------"
		echo "1. Debian 12                  2. Debian 11"
		echo "3. Debian 10                  4. Debian 9"
		echo "-------------------------"
		echo "11. Ubuntu 24.04              12. Ubuntu 22.04"
		echo "13. Ubuntu 20.04              14. Ubuntu 18.04"
		echo "-------------------------"
		echo "21. Rocky Linux 9             22. Rocky Linux 8"
		echo "23. Alma Linux 9              24. Alma Linux 8"
		echo "25. Oracle Linux 9            26. Oracle Linux 8"
		echo "27. Fedora Linux 40           28. Fedora Linux 39"
		echo "29. CentOS 7"
		echo "-------------------------"
		echo "31. Alpine Linux              32. Arch Linux"
		echo "-------------------------"
		echo "41. Windows 11                42. Windows 10"
		echo "44. Windows Server 2022"
		echo "45. Windows Server 2019       46. Windows Server 2016"
		echo "-------------------------"
		echo "100. OpenVZ/LXC 重装Debian/CentOS/Alpine"
		echo "-------------------------"
		echo "0. 返回上一级菜单"
		echo "-------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read choice

		case "$choice" in
			1)
				_yellow "重装debian 12"
				dd_linux_mollyLau
				bash InstallNET.sh -debian 12
				reboot
				exit
				;;
			2)
				_yellow "重装debian 11"
				dd_linux_mollyLau
				bash InstallNET.sh -debian 11
				reboot
				exit
				;;
			3)
				_yellow "重装debian 10"
				dd_linux_mollyLau
				bash InstallNET.sh -debian 10
				reboot
				exit
				;;
			4)
				_yellow "重装debian 9"
				dd_linux_mollyLau
				bash InstallNET.sh -debian 9
				reboot
				exit
				;;
			11)
				_yellow "重装ubuntu 24.04"
				dd_linux_mollyLau
				bash InstallNET.sh -ubuntu 24.04
				reboot
				exit
				;;
			12)
				_yellow "重装ubuntu 22.04"
				dd_linux_mollyLau
				bash InstallNET.sh -ubuntu 22.04
				reboot
				exit
				;;
			13)
				_yellow "重装ubuntu 20.04"
				dd_linux_mollyLau
				bash InstallNET.sh -ubuntu 20.04
				reboot
				exit
				;;
			14)
				_yellow "重装ubuntu 18.04"
				dd_linux_mollyLau
				bash InstallNET.sh -ubuntu 18.04
				reboot
				exit
				;;
			21)
				_yellow "重装rockylinux9"
				dd_linux_bin456789
				bash reinstall.sh rocky
				reboot
				exit
				;;
			22)
				_yellow "重装rockylinux8"
				dd_linux_bin456789
				bash reinstall.sh rocky 8
				reboot
				exit
				;;
			23)
				_yellow "重装Alma9"
				dd_linux_bin456789
				bash reinstall.sh alma
				reboot
				exit
				;;
			24)
				_yellow "重装Alma8"
				dd_linux_bin456789
				bash reinstall.sh alma 8
				reboot
				exit
				;;
			25)
				_yellow "重装Oracle9"
				dd_linux_bin456789
				bash reinstall.sh oracle
				reboot
				exit
				;;
			26)
				_yellow "重装Oracle8"
				dd_linux_bin456789
				bash reinstall.sh oracle 8
				reboot
				exit
				;;
			27)
				_yellow "重装Fedora40"
				dd_linux_bin456789
				bash reinstall.sh fedora
				reboot
				exit
				;;
			28)
				_yellow "重装Fedora39"
				dd_linux_bin456789
				bash reinstall.sh fedora 39
				reboot
				exit
				;;
			29)
				_yellow "重装centos 7"
				dd_linux_mollyLau
				bash InstallNET.sh -centos 7
				reboot
				exit
				;;
			31)
				_yellow "重装Alpine"
				dd_linux_mollyLau
				bash InstallNET.sh -alpine
				reboot
				exit
				;;
			32)
				_yellow "重装Arch"
				dd_linux_bin456789
				bash reinstall.sh arch
				reboot
				exit
				;;
			33)
				_yellow "重装Kali"
				dd_linux_bin456789
				bash reinstall.sh kali
				reboot
				exit
				;;
			34)
				_yellow "重装Openeuler"
				dd_linux_bin456789
				bash reinstall.sh openeuler
				reboot
				exit
				;;
			35)
				_yellow "重装Opensuse"
				dd_linux_bin456789
				bash reinstall.sh opensuse
				reboot
				exit
				;;
			41)
				_yellow "重装Windows11"
				dd_windows_mollyLau
				bash InstallNET.sh -windows 11 -lang "cn"
				reboot
				exit
				;;
			42)
				_yellow "重装Windows10"
				dd_windows_mollyLau
				bash InstallNET.sh -windows 10 -lang "cn"
				reboot
				exit
				;;
			44)
				_yellow "重装Windows server 22"
				dd_windows_bin456789
				URL="https://massgrave.dev/windows_server_links"
				iso_link=$(wget -q -O - "$URL" | grep -oP '(?<=href=")[^"]*cn[^"]*windows_server[^"]*2022[^"]*x64[^"]*\.iso')
				bash reinstall.sh windows --iso="$iso_link" --image-name='Windows Server 2022 SERVERDATACENTER'
				reboot
				exit
				;;
			45)
				_yellow "重装Windows server 19"
				dd_windows_mollyLau
				bash InstallNET.sh -windows 2019 -lang "cn"
				reboot
				exit
				;;
			46)
				_yellow "重装Windows server 16"
				dd_windows_mollyLau
				bash InstallNET.sh -windows 2016 -lang "cn"
				reboot
				exit
				;;
			100)
				_yellow "重装Lxc或OpenVZ"
				dd_openvz_lxc_LloydAsp
				;;
			0)
				break
				;;
			*)
				_red "无效选项,请重新输入"
				break
				;;
		esac
	done
}

server_test_script(){
	local choice
	while true; do
		clear
		echo "VPS脚本合集"
		echo ""
		echo "-----IP及解锁状态检测----"
		echo "1. ChatGPT解锁状态检测"
		echo "2. Region流媒体解锁测试"
		echo "3. Yeahwu流媒体解锁检测"
		_purple "4. Xykt_IP质量体检脚本"
		echo ""
		echo "------网络线路测速-------"
		echo "12. Besttrace三网回程延迟路由测试"
		echo "13. Mtr_trace三网回程线路测试"
		echo "14. Superspeed三网测速"
		echo "15. Nxtrace快速回程测试脚本"
		echo "16. Nxtrace指定IP回程测试脚本"
		echo "17. Ludashi2020三网线路测试"
		echo "18. I-abc多功能测速脚本"
		echo ""
		echo "-------硬件性能测试------"
		echo "20. Yabs性能测试"
		echo "21. Icu/gb5 CPU性能测试脚本"
		echo ""
		echo "--------综合性测试-------"
		echo "30. Bench性能测试"
		_purple "31. Spiritysdx融合怪测评"
		echo ""
		echo "-------------------------"
		echo "0. 返回菜单"
		echo "-------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read choice

		case "$choice" in
			1)
				clear
				bash <(curl -Ls https://cdn.jsdelivr.net/gh/missuo/OpenAI-Checker/openai.sh)
				;;
			2)
				clear
				bash <(curl -L -s check.unlock.media)
				;;
			3)
				clear
				install wget
				wget -qO- https://github.com/yeahwu/check/raw/main/check.sh | bash
				;;
			4)
				clear
				bash <(curl -Ls IP.Check.Place)
				;;
			12)
				clear
				install wget
				wget -qO- git.io/besttrace | bash
				;;
			13)
				clear
				curl https://raw.githubusercontent.com/zhucaidan/mtr_trace/main/mtr_trace.sh | bash
				;;
			14)
				clear
				bash <(curl -Lso- https://git.io/superspeed_uxh)
				;;
			15)
				clear
				curl nxtrace.org/nt | bash
				nexttrace --fast-trace --tcp
				;;
			16)
				clear
				echo "Nxtrace指定IP回程测试脚本"
				echo "可参考的IP列表"
				echo "-------------------------"
				echo "北京电信: 219.141.136.12"
				echo "北京联通: 202.106.50.1"
				echo "北京移动: 221.179.155.161"
				echo "上海电信: 202.96.209.133"
				echo "上海联通: 210.22.97.1"
				echo "上海移动: 211.136.112.200"
				echo "广州电信: 58.60.188.222"
				echo "广州联通: 210.21.196.6"
				echo "广州移动: 120.196.165.24"
				echo "成都电信: 61.139.2.69"
				echo "成都联通: 119.6.6.6"
				echo "成都移动: 211.137.96.205"
				echo "湖南电信: 36.111.200.100"
				echo "湖南联通: 42.48.16.100"
				echo "湖南移动: 39.134.254.6"
				echo "-------------------------"

				echo -n -e "${yellow}输入一个指定IP:${white}"
				read testip
				curl nxtrace.org/nt | bash
				nexttrace $testip
				;;
			17)
				clear
				curl https://raw.githubusercontent.com/ludashi2020/backtrace/main/install.sh -sSf | sh
				;;
			18)
				clear
				bash <(curl -sL bash.icu/speedtest)
				;;
			20)
				clear
				check_swap
				curl -sL yabs.sh | bash -s -- -i -5
				;;
			21)
				clear
				check_swap
				bash <(curl -sL bash.icu/gb5)
				;;
			30)
				clear
				curl -Lso- bench.sh | bash
				;;
			31)
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
		end_of
	done
}

linux_system_tools(){
	local choice
	while true; do
		clear
		echo "▶ 系统工具"
		echo "------------------------"
		echo "3. ROOT密码登录模式"
		echo "7. 优化DNS地址                         8. 一键重装系统"
		echo "------------------------"
		echo "12. 修改虚拟内存大小"
		echo "15. 系统时区调整                       16. 设置XanMod BBR3"
		echo "19. 切换系统更新源                     20. 定时任务管理"
		echo "------------------------"
		echo "25. TG-bot系统监控预警"
		echo "------------------------"
		echo "50. Cloudflare ddns解析"
		echo "------------------------"
		echo "99. 重启服务器"
		echo "------------------------"
		echo "0. 返回主菜单"
		echo "------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read choice

		case $choice in
			3)
				need_root
				add_sshpasswd
				;;
			7)
				need_root
				while true; do
					clear
					echo "优化DNS地址"
					echo "------------------------"
					echo "当前DNS地址"
					cat /etc/resolv.conf
					echo "------------------------"
					echo "国外DNS优化: "
					echo "v4: 1.1.1.1 8.8.8.8"
					echo "v6: 2606:4700:4700::1111 2001:4860:4860::8888"
					echo "国内DNS优化: "
					echo "v4: 223.5.5.5 183.60.83.19"
					echo "v6: 2400:3200::1 2400:da00::6666"
					echo "------------------------"
					echo "1. 设置DNS优化"
					echo "2. 恢复DNS原有配置"
					echo "------------------------"
					echo "0. 返回上一级"
					echo "------------------------"

					echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
					read choice

					case "$choice" in
						1)
							bak_dns
							set_dns
							;;
						2)
							rollbak_dns
							;;
						0)
							break
							;;
						*)
							_red "无效选项,请重新输入"
							;;
					esac
				done
				;;
			8)
				reinstall_system
				;;
			12)
				need_root
				echo "设置虚拟内存"
				 while true; do
					clear

					# 获取当前虚拟内存使用情况
					swap_used=$(free -m | awk 'NR==3{print $3}')
					swap_total=$(free -m | awk 'NR==3{print $2}')
					swap_info=$(free -m | awk 'NR==3{used=$3; total=$2; if (total == 0) {percentage=0} else {percentage=used*100/total}; printf "%dMB/%dMB (%d%%)", used, total, percentage}')

					_yellow "当前虚拟内存: ${swap_info}"
					echo "------------------------"
					echo "1. 分配1024MB         2. 分配2048MB         3. 自定义大小         0. 退出"
					echo "------------------------"
					
					echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
					read choice

					case "$choice" in
						1)
							new_swap=1024
							add_swap $new_swap
							_green "已设置1G虚拟内存"
							;;
						2)
							new_swap=2048
							add_swap $new_swap
							_green "已设置2G虚拟内存"
							;;
						3)
							echo -n -e "${yellow}请输入虚拟内存大小MB:${white}" new_swap
							read new_swap
							if [[ "$new_swap" =~ ^[0-9]+$ ]] && [ "$new_swap" -gt 0 ]; then
								add_swap $new_swap
								_green "已设置自定义虚拟内存为 ${new_swap}MB"
							else
								_red "无效输入,请输入正整数"
							fi
							;;
						0)
							break
							;;
						*)
							_red "无效选项,请重新输入"
							;;
					esac
				done
				;;
			15)
				need_root
				while true; do
					clear
					# 获取当前系统时区
					local timezone=$(current_timezone)

					# 获取当前系统时间
					local current_time=$(date +"%Y-%m-%d %H:%M:%S")

					# 显示时区和时间
					_yellow "当前系统时区：$timezone"
					_yellow "当前系统时间：$current_time"

					echo ""
					echo "时区切换"
					echo "------------亚洲------------"
					echo "1. 中国上海时间              2. 中国香港时间"
					echo "3. 日本东京时间              4. 韩国首尔时间"
					echo "5. 新加坡时间                6. 印度加尔各答时间"
					echo "7. 阿联酋迪拜时间            8. 澳大利亚悉尼时间"
					echo "9. 以色列特拉维夫时间        10. 马尔代夫时间"
					echo "------------欧洲------------"
					echo "11. 英国伦敦时间             12. 法国巴黎时间"
					echo "13. 德国柏林时间             14. 俄罗斯莫斯科时间"
					echo "15. 荷兰尤特赖赫特时间       16. 西班牙马德里时间"
					echo "17. 瑞士苏黎世时间           18. 意大利罗马时间"
					echo "------------美洲------------"
					echo "21. 美国西部时间             22. 美国东部时间"
					echo "23. 加拿大时间               24. 墨西哥时间"
					echo "25. 巴西时间                 26. 阿根廷时间"
					echo "27. 智利时间                 28. 哥伦比亚时间"
					echo "------------非洲------------"
					echo "31. 南非约翰内斯堡时间       32. 埃及开罗时间"
					echo "33. 摩洛哥拉巴特时间         34. 尼日利亚拉各斯时间"
					echo "----------------------------"
					echo "0. 返回上一级选单"
					echo "----------------------------"

					# 提示用户输入选项
					echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
					read choice

					case $choice in
						1) set_timedate Asia/Shanghai ;;
						2) set_timedate Asia/Hong_Kong ;;
						3) set_timedate Asia/Tokyo ;;
						4) set_timedate Asia/Seoul ;;
						5) set_timedate Asia/Singapore ;;
						6) set_timedate Asia/Kolkata ;;
						7) set_timedate Asia/Dubai ;;
						8) set_timedate Australia/Sydney ;;
						9) set_timedate Asia/Tel_Aviv ;;
						10) set_timedate Indian/Maldives ;;
						11) set_timedate Europe/London ;;
						12) set_timedate Europe/Paris ;;
						13) set_timedate Europe/Berlin ;;
						14) set_timedate Europe/Moscow ;;
						15) set_timedate Europe/Amsterdam ;;
						16) set_timedate Europe/Madrid ;;
						17) set_timedate Europe/Zurich ;;
						18) set_timedate Europe/Rome ;;
						21) set_timedate America/Los_Angeles ;;
						22) set_timedate America/New_York ;;
						23) set_timedate America/Vancouver ;;
						24) set_timedate America/Mexico_City ;;
						25) set_timedate America/Sao_Paulo ;;
						26) set_timedate America/Argentina/Buenos_Aires ;;
						27) set_timedate America/Santiago ;;
						28) set_timedate America/Bogota ;;
						31) set_timedate Africa/Johannesburg ;;
						32) set_timedate Africa/Cairo ;;
						33) set_timedate Africa/Casablanca ;;
						34) set_timedate Africa/Lagos ;;
						0) break ;;  # 退出循环
						*) _red "无效选项,请重新输入" ;;
					esac
					end_of
				done
				;;
			16)
				xanmod_bbr3
				;;
			19)
				linux_mirror
				;;
			20)
				cron_manager
				;;
			25)
				telegram_bot
				;;
			50)
				cloudflare_ddns
				;;
			99)
				clear
				server_reboot
				;;
			0)
				honeok
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
		end_of
	done
}

honeok(){
	local choice
	while true; do
		clear
		_yellow "脚本地址: https://github.com/honeok8s/shell"
		echo "-------------------------------------------------------"
		print_logo
		echo "-------------------------------------------------------"
		_orange "适配Ubuntu/Debian/CentOS/Alpine系统"
		_cyan "Author: honeok"
		_green "服务器当前时间: $(date +"%Y-%m-%d %H:%M:%S")"
		echo "-------------------------------------------------------"
		echo "1. 系统信息查询                   2. 系统更新"
		echo "3. 系统清理                       4. 常用工具 ▶"
		echo "5. BBR管理 ▶                      6. Docker管理 ▶"
		echo "7. WARP管理 ▶                     8. LDNMP建站 ▶"
		echo "-------------------------------------------------------"
		echo "12. 面板工具 ▶                    13. 系统工具 ▶"
		echo "14. 我的工作区 ▶                  15. VPS测试脚本合集 ▶"
		echo "16. 节点搭建脚本合集 ▶            17. 甲骨文云脚本合集 ▶"
		echo "18. 常用环境管理 ▶"
		echo "-------------------------------------------------------"
		echo "99. 幻兽帕鲁开服脚本 ▶"
		echo "-------------------------------------------------------"
		echo "00.脚本更新                       0. 退出"
		echo "-------------------------------------------------------"
		echo ""
		
		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read choice

		case "$choice" in
			1)
				clear
				system_info
				;;
			2)
				clear
				update_system
				;;
			3)
				echo "敬请期待"
				;;
			4)
				linux_tools
				;;
			5)
				linux_bbr
				;;
			6)
				docker_manager
				;;
			7)
				clear
				install wget
				wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh [option] [lisence/url/token]
				;;
			8)
				echo "敬请期待"
				;;
			12)
				echo "敬请期待"
				;;
			13)
				linux_system_tools
				;;
			14)
				echo "敬请期待"
				;;
			15)
				server_test_script
				;;
			16)
				node_create
				;;
			17)
				oracle_script
				;;
			18)
				echo "敬请期待"
				;;
			99)
				curl -fsSL -o ~/palworld.sh https://raw.githubusercontent.com/honeok8s/shell/main/callscript/palworld.sh && chmod a+x ~/palworld.sh && ./palworld.sh
				exit 0
				;;
			00)
				_green "当前已是最新版本"
				sleep 1
				honeok
				;;
			0)
				clear
				exit 0
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
		end_of
	done
}

# 脚本入口
honeok
exit 0