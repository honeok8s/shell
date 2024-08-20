#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2024 honeok
# Forked from kejilion
# Current Author: honeok
# Blog: https://www.honeok.com
# Original Author: kejilion

yellow='\033[1;33m'       # 黄色
red='\033[1;31m'          # 红色
magenta='\033[1;35m'      # 品红色
green='\033[1;32m'        # 绿色
blue='\033[1;34m'         # 蓝色
cyan='\033[1;36m'         # 青色
purple='\033[1;35m'       # 紫色
gray='\033[1;30m'         # 灰色
orange='\033[1;38;5;208m' # 橙色
white='\033[0m'           # 白色
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

#################### 系统信息START ####################
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
	virt_type=$(hostnamectl | awk -F ': ' '/Virtualization/ {print $2}')

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

#################### 系统信息END ####################

#################### 通用函数START ####################
# 安装软件包
install() {
	if [ $# -eq 0 ]; then
		_red "未提供软件包参数"
		return 1
	fi

	for package in "$@"; do
		if ! command -v "$package" &>/dev/null; then
			_yellow "正在安装$package"
			if command -v dnf &>/dev/null; then
				dnf update -y
				dnf install epel-release -y
				dnf install "$package" -y
			elif command -v yum &>/dev/null; then
				yum update -y
				yum install epel-release -y
				yum install "$package" -y
			elif command -v apt &>/dev/null; then
				apt update -y
				apt install "$package" -y
			elif command -v apk &>/dev/null; then
				apk update
				apk add "$package"
			else
				_red "未知的包管理器"
				return 1
			fi
		else
			_green "$package已安装"
		fi
	done

	return 0
}

# 卸载软件包
remove() {
	if [ $# -eq 0 ]; then
		_red "未提供软件包参数"
		return 1
	fi

	for package in "$@"; do
		_yellow "正在卸载$package"
		if command -v dnf &>/dev/null; then
			if rpm -q "$package" &>/dev/null; then
				dnf remove "$package"* -y
			fi
		elif command -v yum &>/dev/null; then
			if rpm -q "${package}" >/dev/null 2>&1; then
				yum remove "${package}"* -y
			fi
		elif command -v apt &>/dev/null; then
			if dpkg -l | grep -qw "${package}"; then
				apt purge "${package}"* -y
			fi
		elif command -v apk &>/dev/null; then
			if apk info | grep -qw "${package}"; then
				apk del "${package}"*
			fi
		else
			_red "未知的包管理器"
			return 1
		fi
	done

	return 0
}

# 通用systemctl函数,适用于各种发行版
systemctl() {
	local cmd="$1"
	local service_name="$2"

	if command -v apk &>/dev/null; then
		service "$service_name" "$cmd"
	else
		/bin/systemctl "$cmd" "$service_name"
	fi
}

# 重载systemd管理的服务
daemon_reload() {
	if command -v apk &>/dev/null; then
		# Alpine使用OpenRC
		rc-service -a
	else
		/bin/systemctl daemon-reload
	fi
}

disable() {
	local service_name="$1"
	if command -v apk &>/dev/null; then
		# Alpine使用OpenRC
		rc-update del "$service_name"
	else
		/bin/systemctl disable "$service_name"
	fi
}

# 设置服务为开机自启
enable() {
	local service_name="$1"
	if command -v apk &>/dev/null; then
		rc-update add "$service_name" default
	else
		systemctl enable "$service_name"
	fi

	if [ $? -eq 0 ]; then
		_green "$service_name已设置为开机自启"
	else
		_red "$service_name设置开机自启失败"
	fi
}

# 启动服务
start() {
	local service_name="$1"
	systemctl start "$service_name"
	if [ $? -eq 0 ]; then
		_green "$service_name已启动"
	else
		_red "$service_name启动失败"
	fi
}

# 停止服务
stop() {
	local service_name="$1"
	systemctl stop "$service_name"
	if [ $? -eq 0 ]; then
		_green "$service_name已停止"
	else
		_red "$service_name停止失败"
	fi
}

# 重启服务
restart() {
	local service_name="$1"
	systemctl restart "$service_name"
	if [ $? -eq 0 ]; then
		_green "$service_name已重启"
	else
		_red "$service_name重启失败"
	fi
}

# 重载服务
reload() {
	local service_name="$1"
	systemctl reload "$service_name"
	if [ $? -eq 0 ]; then
		_green "$service_name已重载"
	else
		_red "$service_name重载失败"
	fi
}

# 查看服务状态
status() {
	local service_name="$1"
	systemctl status "$service_name"
	if [ $? -eq 0 ]; then
		_green "$service_name状态已显示"
	else
		_red "$service_name状态显示失败"
	fi
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

# 获取公网IP地址
ip_address() {
	local ipv4_services=("http://ifconfig.me" "https://api.ipify.org" "https://checkip.amazonaws.com")
	local ipv6_services=("https://ipv6.ip.sb" "https://api6.ipify.org" "https://v6.ident.me")

	# 获取IPv4地址
	for service in "${ipv4_services[@]}"; do
		ipv4_address=$(curl -s "$service")
		if [[ $ipv4_address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
			break
		fi
	done

	# 获取IPv6地址
	for service in "${ipv6_services[@]}"; do
		ipv6_address=$(curl -s "$service")
		if [[ $ipv6_address =~ ^[0-9a-fA-F:]+$ ]]; then
			break
		else
			ipv6_address=""
		fi
	done
}
#################### 通用函数END ####################

#################### 系统更新START ####################
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
#################### 系统更新END ####################

#################### 系统清理START ####################
linux_clean() {
	_yellow "正在系统清理"

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

	if command -v dnf &>/dev/null; then
		dnf autoremove -y
		dnf clean all
		dnf makecache
		journalctl --rotate
		journalctl --vacuum-time=7d # 删除所有早于7天前的日志
		journalctl --vacuum-size=500M
	elif command -v yum &>/dev/null; then
		yum autoremove -y
		yum clean all
		yum makecache
		journalctl --rotate
		journalctl --vacuum-time=7d # 删除所有早于7天前的日志
		journalctl --vacuum-size=500M
	elif command -v apt &>/dev/null; then
		wait_for_lock
		fix_dpkg
		apt autoremove --purge -y
		apt clean -y
		apt autoclean -y
		journalctl --rotate
		journalctl --vacuum-time=7d # 删除所有早于7天前的日志
		journalctl --vacuum-size=500M
	elif command -v apk &>/dev/null; then
		apk cache clean
		rm -fr /var/log/*
		rm -fr /var/cache/apk/*
		rm -fr /tmp/*
	else
		_red "未知的包管理器!"
		return 1
	fi

	return 0
}
#################### 系统清理END ####################

#################### 常用工具START ####################
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
		read -r choice

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
				read -r installname
				install $installname
				;;
			42)
				clear
				echo -n -e "${yellow}请输入卸载的工具名(htop ufw tmux cmatrix):${white}"
				read -r removename
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
#################### 常用工具END ####################

#################### BBR START ####################
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
			read -r choice

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
#################### BBR END ####################

#################### Docker START ####################
install_docker() {
	if ! command -v docker >/dev/null 2>&1; then
		install_add_docker
	else
		_green "Docker已安装"
	fi
}

install_docker_official() {
	if [[ "$(curl -s ipinfo.io/country)" == "CN" ]]; then
		cd ~
		curl -fsSL -O https://raw.githubusercontent.com/honeok8s/shell/main/docker/get-docker-official.sh && chmod a+x get-docker-official.sh
		bash get-docker-official.sh --mirror Aliyun
		[ -f ~/get-docker-official.sh ] && rm -f get-docker-official.sh
	else
		curl -fsSL https://get.docker.com | sh
	fi

	enable docker
	start docker
}

install_add_docker() {
    _yellow "正在安装docker环境"

	if [ -f /etc/os-release ] && grep -q "Fedora" /etc/os-release; then
		install_docker_official
		enable docker && start docker
		generate_docker_config
		docker_main_version
	elif command -v dnf &>/dev/null; then
		install yum-utils device-mapper-persistent-data lvm2
		[ -f /etc/yum.repos.d/docker*.repo ] && rm -f /etc/yum.repos.d/docker*.repo > /dev/null

		# 判断地区安装
		if [[ "$(curl -s ipinfo.io/country)" == "CN" ]]; then
			yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo > /dev/null
		else
			yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null
		fi

		install docker-ce docker-ce-cli containerd.io
		enable docker
		start docker
		generate_docker_config
		docker_main_version
	elif command -v apt &>/dev/null || command -v yum &>/dev/null; then
		install_docker_official
		enable docker
		start docker
		generate_docker_config
		docker_main_version
	else
		install docker docker-compose
		enable docker
		start docker
		generate_docker_config
		docker_main_version
	fi

	sleep 2
}

docker_main_version() {
	local docker_version=""
	local docker_compose_version=""

	# 获取 Docker 版本
	if command -v docker >/dev/null 2>&1; then
		docker_version=$(docker --version | awk -F '[ ,]' '{print $3}')
	elif command -v docker.io >/dev/null 2>&1; then
		docker_version=$(docker.io --version | awk -F '[ ,]' '{print $3}')
	fi

	# 获取 Docker Compose 版本
	if command -v docker-compose >/dev/null 2>&1; then
		docker_compose_version=$(docker-compose version --short)
	elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
		docker_compose_version=$(docker compose version --short)
	fi

	echo -e "${white}已安装Docker版本: ${yellow}v$docker_version${white}"
	echo -e "${white}已安装Docker Compose版本: ${yellow}v$docker_compose_version${white}"
}

# Docker调优
generate_docker_config() {
	local config_file="/etc/docker/daemon.json"
	local is_china_server='false'

	if ! command -v docker &> /dev/null; then
		_red "Docker未安装在系统上,无法优化"
		return 1
	fi

	if [ -f "$config_file" ]; then
		# 如果文件存在,检查是否已经优化过
		if grep -q '"storage-driver": "overlay2"' "$config_file"; then
			_yellow "Docker配置文件已经优化,无需再次优化"
			return 0
		fi
	fi

	install python3

	# 检查服务器是否在中国
	if [[ "$(curl -s ipinfo.io/country)" == "CN" ]]; then
		is_china_server='true'
	fi

	# Python脚本
	python3 - <<EOF
import json
import sys

registry_mirrors = [
	"https://registry.honeok.com",
	"https://docker.ima.cm",
	"https://hub.littlediary.cn",
	"https://h.ysicing.net"
]

base_config = {
	"exec-opts": [
		"native.cgroupdriver=systemd"
	],
	"max-concurrent-downloads": 10,
	"max-concurrent-uploads": 5,
	"log-driver": "json-file",
	"log-opts": {
		"max-size": "30m",
		"max-file": "3"
	},
	"storage-driver": "overlay2",
	"ipv6": False
}

# 如果是中国服务器，将 registry-mirrors 放在前面
if "$is_china_server" == "true":
	config = {
		"registry-mirrors": registry_mirrors,
		**base_config
	}
else:
	config = base_config

with open("/etc/docker/daemon.json", "w") as f:
	json.dump(config, f, indent=4)

EOF

	# 校验和重新加载Docker守护进程
	_green "Docker配置文件已重新加载并重启Docker服务"
	daemon_reload
	restart docker
	_yellow "Docker配置文件已根据服务器IP归属做相关优化,如需调整自行修改$config_file"
}

docker_ipv6_on() {
	need_root
	install python3

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
	install python3

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

# 卸载Docker
uninstall_docker() {
	local os_name
	local docker_files=("/var/lib/docker" "/var/lib/containerd" "/etc/docker" "/opt/containerd" "/data/docker_data")
	local repo_files=("/etc/yum.repos.d/docker*" "/etc/apt/sources.list.d/docker.*" "/etc/apt/keyrings/docker.*")
	local binary_files=("/usr/bin/docker" "/usr/bin/docker-compose")  # 删除二进制文件路径

	need_root

	# 停止并删除Docker服务和容器
	stop_and_remove_docker() {
		local running_containers=$(docker ps -aq)
		[ -n "$running_containers" ] && docker rm -f $running_containers >/dev/null 2>&1
		stop docker >/dev/null 2>&1
		disable docker >/dev/null 2>&1
	}

	# 移除Docker文件和仓库文件
	cleanup_files() {
		for pattern in "${repo_files[@]}"; do
			for file in $pattern; do
				[ -e "$file" ] && rm -fr "$file" >/dev/null 2>&1
			done
		done

		for file in "${docker_files[@]}" "${binary_files[@]}"; do
			[ -e "$file" ] && rm -fr "$file" >/dev/null 2>&1
		done
	}

	# 获取操作系统信息
	if [ -f /etc/os-release ]; then
		os_name=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
	else
		_red "无法识别操作系统版本"
		return 1
	fi

	# 检查Docker是否安装
	if ! command -v docker &> /dev/null; then
		_red "Docker未安装在系统上,无法继续卸载"
		return 1
	fi

	stop_and_remove_docker

	case "$os_name" in
		centos|ubuntu|debian)
			remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
			;;
		alpine)
			remove docker docker-compose
			;;
		*)
			_red "此脚本不支持您的 Linux 发行版"
			return 1
			;;
	esac

	cleanup_files

	# 清除命令缓存
	hash -r

	sleep 2

	# 检查卸载是否成功
	if command -v docker &> /dev/null || [ -e "/usr/bin/docker" ]; then
		_red "Docker卸载失败,请手动检查"
		return 1
	else
		_green "Docker和Docker Compose已卸载,并清理文件夹和相关依赖"
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
		read -r choice
		case $choice in
			1)
				echo -n "请输入创建命令:" dockername
				$dockername
				;;
			2)
				echo -n "请输入容器名(多个容器名请用空格分隔):" dockername
				read -r dockername
				docker start $dockername
				;;
			3)
				echo -n "请输入容器名(多个容器名请用空格分隔):"
				read -r dockername
				docker stop $dockername
				;;
			4)
				echo -n "请输入容器名(多个容器名请用空格分隔):"
				read -r dockername
				docker rm -f $dockername
				;;
			5)
				echo -n "请输入容器名(多个容器名请用空格分隔):"
				read -r dockername
				docker restart $dockername
				;;
			6)
				docker start $(docker ps -a -q)
				;;
			7)
				docker stop $(docker ps -q)
				;;
			8)
				echo -n -e "${yellow}确定删除所有容器吗?(y/n):${white}"
				read -r choice

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
				read -r dockername
				docker exec -it $dockername /bin/sh
				end_of
				;;
			12)
				echo -n "请输入容器名:"
				read -r dockername
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
		read -r choice
		case $choice in
			1)
				echo -n "请输入镜像名(多个镜像名请用空格分隔):"
				read -r imagenames
				for name in $imagenames; do
					_yellow "正在获取镜像:" $name
					docker pull $name
				done
				;;
			2)
				echo -n "请输入镜像名(多个镜像名请用空格分隔):"
				read -r imagenames
				for name in $imagenames; do
					_yellow "正在更新镜像:" $name
					docker pull $name
				done
				;;
			3)
				echo -n "请输入镜像名(多个镜像名请用空格分隔):"
				read -r imagenames
				for name in $imagenames; do
					docker rmi -f $name
				done
				;;
			4)
				echo -n -e "${yellow}确定删除所有镜像吗?(y/n):${white}"
				read -r choice

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

# Docker管理主面板菜单
docker_manager(){
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
		echo "9. 编辑Docker配置文件"
		echo "10. Docker配置文件一键优化(CN提供镜像加速)"
		echo "------------------------"
		echo "11. 开启Docker-ipv6访问"
		echo "12. 关闭Docker-ipv6访问"
		echo "------------------------"
		echo "20. 卸载Docker环境"
		echo "------------------------"
		echo "0. 返回主菜单"
		echo "------------------------"
		
		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read -r choice

		case $choice in
			1)
				clear
				if ! command -v docker >/dev/null 2>&1; then
					install_add_docker
				else
					docker_main_version
					while true; do
						echo -n -e "是否升级Docker环境?(y/n):"
						read -r answer

						case $answer in
							[Y/y])
								install_add_docker
								break
								;;
							[N/n])
								break
								;;
							*)
								_red "无效选项,请重新输入"
								;;
						esac
					done
				fi
				;;
			2)
				clear
				echo "Docker版本"
				docker -v
				if docker compose version >/dev/null 2>&1; then
					docker compose version
				elif command -v docker-compose >/dev/null 2>&1; then
					docker-compose version
				fi
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
					read -r choice

					case $choice in
						1)
							echo -n "设置新网络名:"
							read -r dockernetwork
							docker network create $dockernetwork
							;;
						2)
							echo -n "设置新网络名:"
							read -r dockernetwork
							echo -n "设置新网络名:"
							read -r dockernames

							for dockername in $dockernames; do
								docker network connect $dockernetwork $dockername
							done                  
							;;
						3)
							echo -n "设置新网络名:"
							read -r dockernetwork

							echo -n "那些容器退出该网络(多个容器名请用空格分隔):"
							read -r dockernames
                          
							for dockername in $dockernames; do
								docker network disconnect $dockernetwork $dockername
							done
							;;
						4)
							echo -n "请输入要删除的网络名:"
							read -r dockernetwork
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
					read -r choice

					case $choice in
						1)
							echo -n "设置新卷名:"
							read -r dockerjuan
							docker volume create $dockerjuan
							;;
						2)
							echo -n "输入删除卷名(多个卷名请用空格分隔):"
							read -r dockerjuans

							for dockerjuan in $dockerjuans; do
								docker volume rm $dockerjuan
							done
							;;
						3)
							echo -n "确定删除所有未使用的卷吗:"
							read -r choice
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
				read -r choice

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
			10)
				generate_docker_config
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
				echo -n "确定卸载docker环境吗?(y/n)"
				read -r choice

				case "$choice" in
					[Yy])
						uninstall_docker
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

has_ipv4_has_ipv6() {
	ip_address
	has_ipv4=false
	has_ipv6=false

	[ -n "$ipv4_address" ] && has_ipv4=true
	[ -n "$ipv6_address" ] && has_ipv6=true
}

check_docker_app_ip() {
	echo "------------------------"
	echo "访问地址:"
	$has_ipv4 && echo "http://$ipv4_address:$docker_port_1"
	$has_ipv6 && echo "http://[$ipv6_address]:$docker_port_1"
}

check_docker_app() {
	if docker inspect "$docker_name" &>/dev/null; then
		check_docker="${green}已安装${white}"
	else
		check_docker="${yellow}未安装${white}"
	fi
}

check_panel_app() {
	if $path; then
		check_panel="${green}已安装${white}"
	else
		check_panel="${yellow}未安装${white}"
	fi
}

install_panel() {
	local choice
	while true; do
		clear
		check_panel_app
		echo -e "$panelname $check_panel"
		echo "${panelname}是一款时下流行且强大的运维管理面板。"
		echo "官网介绍: $panelurl "

		echo ""
		echo "------------------------"
		echo "1. 安装            2. 管理            3. 卸载"
		echo "------------------------"
		echo "0. 返回上一级"
		echo "------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read -r choice

		case $choice in
			1)
				iptables_open
				install wget
				if grep -q 'Alpine' /etc/issue; then
					$ubuntu_command
					$ubuntu_command2
				elif command -v dnf &>/dev/null; then
					$centos_command
					$centos_command2
				elif grep -qi 'Ubuntu' /etc/os-release; then
					$ubuntu_command
					$ubuntu_command2
				elif grep -qi 'Debian' /etc/os-release; then
					$ubuntu_command
					$ubuntu_command2
				else
					echo "不支持的系统"
				fi
				;;
			2)
				$feature1
				$feature1_1
				;;
			3)
				$feature2
				$feature2_1
				$feature2_2
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

docker_app() {
	local choice
	has_ipv4_has_ipv6
	while true; do
		clear
		check_docker_app
		echo -e "$docker_name $check_docker"
		echo "$docker_describe"
		echo "$docker_url"

		# 获取并显示当前端口
		if docker inspect "$docker_name" &>/dev/null; then
			check_docker_app_ip
		fi
		echo "------------------------"
		echo "1. 安装            2. 更新"
		echo "3. 编辑            4. 卸载"
		echo "------------------------"
		echo "0. 返回上一级"
		echo "------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read -r choice

		case $choice in
			1)
				install_docker
				[ ! -d $docker_workdir ] && mkdir -p $docker_workdir
				cd $docker_workdir || { _red "无法进入目录$docker_workdir"; return 1; }

				# 生成compose文件
				echo "$docker_compose_content" > docker-compose.yml

				if docker compose version >/dev/null 2>&1; then
					docker compose up -d
				elif command -v docker-compose >/dev/null 2>&1; then
					docker-compose up -d
				fi

				clear
				_green "${docker_name}安装完成"
				check_docker_app_ip
				echo ""
				$docker_use
				$docker_passwd
				;;
			2)
				cd $docker_workdir || { _red "无法进入目录$docker_workdir"; return 1; }

				if docker compose version >/dev/null 2>&1; then
					docker compose pull && docker compose up -d
				elif command -v docker-compose >/dev/null 2>&1; then
					docker-compose pull && docker-compose up -d
				fi

				clear
				_green "$docker_name更新完成"
				check_docker_app_ip
				echo ""
				$docker_use
				$docker_passwd
				;;
			3)
				cd $docker_workdir || { _red "无法进入目录$docker_workdir"; return 1; }
				vim docker-compose.yml

				if docker compose version >/dev/null 2>&1; then
					docker compose restart
				elif command -v docker-compose >/dev/null 2>&1; then
					docker-compose restart
				fi

				if [ $? -eq 0 ]; then
					_green "$docker_name重启成功"
				else
					_red "$docker_name重启失败"
				fi
				;;
			4)
				cd $docker_workdir || { _red "无法进入目录$docker_workdir"; return 1; }

				if docker compose version >/dev/null 2>&1; then
					docker compose down --rmi all --volumes
				elif command -v docker-compose >/dev/null 2>&1; then
					docker-compose down --rmi all --volumes
				fi

				[ -d $docker_workdir ] && rm -fr "${docker_workdir}"
				_green "${docker_name}应用已卸载"
				break
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

find_available_port() {
	local start_port=$1
	local end_port=$2
	local port
	for port in $(seq $start_port $end_port); do
		if ! ss -tuln | grep -q ":$port "; then
			echo $port
			return
		fi
	done
	_red "在范围$start_port-$end_port内没有找到可用的端口" >&2
	return 1
}

check_available_port() {
	# 检查并设置docker_port_1
	if docker inspect "$docker_name" >/dev/null 2>&1; then
		# 如果容器已存在,获取当前映射的端口
		docker_port_1=$(docker inspect "$docker_name" --format '{{ range $p, $conf := .NetworkSettings.Ports }}{{ range $conf }}{{ $p }}:{{ .HostPort }}{{ end }}{{ end }}' | grep -oP '(\d+)$')
	else
		while true; do
			if ss -tuln | grep -q ":$default_port_1 "; then
				# 查找可用的端口
				docker_port_1=$(find_available_port 30000 50000)
				_yellow "默认端口$default_port_1被占用,端口跳跃为$docker_port_1"
				sleep 1
				break
			else
				docker_port_1=$default_port_1
				_yellow "使用默认端口$docker_port_1"
				sleep 1
				break
			fi
		done
	fi

	# 检查并设置docker_port_2
	if ! docker inspect "$docker_name" >/dev/null 2>&1; then
		if [ -n "$default_port_2" ]; then
			if ss -tuln | grep -q ":$default_port_2 "; then
				docker_port_2=$(find_available_port 35000 50000)
				_yellow "默认端口$default_port_2被占用,端口跳跃为$docker_port_2"
				sleep 1
			else
				docker_port_2=$default_port_2
				_yellow "使用默认端口$docker_port_2"
				sleep 1
			fi
		fi
	fi

	# 检查并设置docker_port_3
	if ! docker inspect "$docker_name" >/dev/null 2>&1; then
		if [ -n "$default_port_3" ]; then
			if ss -tuln | grep -q ":$default_port_3 "; then
				docker_port_3=$(find_available_port 40000 50000)
				_yellow "默认端口$default_port_3被占用,端口跳跃为$docker_port_3"
				sleep 1
			else
				docker_port_3=$default_port_3
				_yellow "使用默认端口$docker_port_3"
				sleep 1
			fi
		fi
	fi
}

linux_panel() {
	local choice
	while true; do
		clear
		echo "▶ 面板工具"
		echo "------------------------"
		echo "1. 宝塔面板官方版                      2. aaPanel宝塔国际版"
		echo "3. 1Panel新一代管理面板                4. NginxProxyManager可视化面板"
		echo "5. AList多存储文件列表程序             6. Ubuntu远程桌面网页版"
		echo "7. 哪吒探针VPS监控面板                 8. QB离线BT磁力下载面板"
		echo "------------------------"
		echo "11. 禅道项目管理软件                   12. 青龙面板定时任务管理平台"
		echo "14. 简单图床图片管理程序"
		echo "15. emby多媒体管理系统                 16. Speedtest测速面板"
		echo "17. AdGuardHome去广告软件              18. onlyoffice在线办公OFFICE"
		echo "19. 雷池WAF防火墙面板                  20. portainer容器管理面板"
		echo "------------------------"
		echo "21. VScode网页版                       22. UptimeKuma监控工具"
		echo "23. Memos网页备忘录                    24. Webtop远程桌面网页版"
		echo "25. Nextcloud网盘                      26. QD-Today定时任务管理框架"
		echo "27. Dockge容器堆栈管理面板             28. LibreSpeed测速工具"
		echo "29. searxng聚合搜索站                  30. PhotoPrism私有相册系统"
		echo "------------------------"
		echo "31. StirlingPDF工具大全                32. drawio免费的在线图表软件"
		echo "33. Sun-Panel导航面板                  34. Pingvin-Share文件分享平台"
		echo "35. 极简朋友圈                         36. LobeChatAI聊天聚合网站"
		echo "37. MyIP工具箱                         38. 小雅alist全家桶"
		echo "39. Bililive直播录制工具               40. It-tools工具箱(中文版)"
		echo "------------------------"
		echo "51. PVE开小鸡面板"
		echo "------------------------"
		echo "0. 返回主菜单"
		echo "------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read -r choice

		case $choice in
			1)
				path="[ -d "/www/server/panel" ]"
				panelname="宝塔面板"

				feature1="bt"
				feature1_1=""
				feature2="curl -o bt-uninstall.sh http://download.bt.cn/install/bt-uninstall.sh > /dev/null 2>&1 && chmod +x bt-uninstall.sh && ./bt-uninstall.sh"
				feature2_1="chmod +x bt-uninstall.sh"
				feature2_2="./bt-uninstall.sh"

				panelurl="https://www.bt.cn/new/index.html"

				centos_command="wget -O install.sh https://download.bt.cn/install/install_6.0.sh"
				centos_command2="sh install.sh ed8484bec"

				ubuntu_command="wget -O install.sh https://download.bt.cn/install/install-ubuntu_6.0.sh"
				ubuntu_command2="bash install.sh ed8484bec"

				install_panel
				;;
			2)
				path="[ -d "/www/server/panel" ]"
				panelname="aapanel"

				feature1="bt"
				feature1_1=""
				feature2="curl -o bt-uninstall.sh http://download.bt.cn/install/bt-uninstall.sh > /dev/null 2>&1 && chmod +x bt-uninstall.sh && ./bt-uninstall.sh"
				feature2_1="chmod +x bt-uninstall.sh"
				feature2_2="./bt-uninstall.sh"

				panelurl="https://www.aapanel.com/new/index.html"

				centos_command="wget -O install.sh http://www.aapanel.com/script/install_6.0_en.sh"
				centos_command2="bash install.sh aapanel"

				ubuntu_command="wget -O install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh"
				ubuntu_command2="bash install.sh aapanel"

				install_panel
				;;
			3)
				path="command -v 1pctl &> /dev/null"
				panelname="1Panel"

				feature1="1pctl user-info"
				feature1_1="1pctl update password"
				feature2="1pctl uninstall"
				feature2_1=""
				feature2_2=""

				panelurl="https://1panel.cn/"

				centos_command="curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh"
				centos_command2="sh quick_start.sh"

				ubuntu_command="curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh"
				ubuntu_command2="bash quick_start.sh"

				install_panel
				;;
			4)
				docker_name="npm"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="如果您已经安装了其他面板工具或者LDNMP建站环境,建议先卸载,再安装npm!"
				docker_url="官网介绍: https://nginxproxymanager.com/"
				default_port_1=81

				if ! docker inspect "$docker_name" >/dev/null 2>&1; then
					while true;do
						echo "------------------------"
						echo "1. 完整安装npm,基于mariadb(默认)"
						echo "2. 精简安装npm,基于SQLlite"
						echo "------------------------"
						echo "0. 返回上一级"
						echo "------------------------"
						echo -n -e "${yellow}请输入选项并按回车键确认(回车使用默认值:完整安装):${white}"

						# 重置choice变量
						choice=""
						read -r choice

						case $choice in
							1|"")
								docker_compose_content=$(curl -sS https://raw.githubusercontent.com/honeok8s/conf/main/npm/docker-compose-latest.yml)
								break
								;;
							2)
								docker_compose_content=$(curl -sS https://raw.githubusercontent.com/honeok8s/conf/main/docker_app/npm-docker-compose.yml)
								break
								;;
							0)
								linux_panel # 返回面板管理界面
								;;
							*)
								_red "无效选项,请重新输入"
								;;
						esac
					done
				fi

				docker_use="echo \"初始用户名: admin@example.com\""
				docker_passwd="echo \"初始密码: changeme\""
				docker_app
				;;
			5)
				docker_name="alist"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="一个支持多种存储,支持网页浏览和WebDAV的文件列表程序,由gin和Solidjs驱动"
				docker_url="官网介绍: https://alist.nn.ci/zh/"
				default_port_1=5244

				# 检查端口,如冲突则使用动态端口
				check_available_port

				docker_compose_content=$(cat <<EOF
services:
  alist:
    image: xhofe/alist:latest
    container_name: alist
    volumes:
      - ./config:/opt/alist/data
    ports:
      - $docker_port_1:5244
    environment:
      - PUID=0
      - PGID=0
      - UMASK=022
      - TZ=Asia/Shanghai
    restart: unless-stopped
EOF
)
				docker_use="docker exec -it alist ./alist admin random"
				docker_passwd=""
				docker_app
				;;
			6)
				docker_name="webtop-ubuntu"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="webtop基于Ubuntu的容器,包含官方支持的完整桌面环境,可通过任何现代Web浏览器访问"
				docker_url="官网介绍: https://docs.linuxserver.io/images/docker-webtop/"
				default_port_1=3000

				# 检查端口,如冲突则使用动态端口
				check_available_port

				docker_compose_content=$(cat <<EOF
services:
  webtop:
    image: lscr.io/linuxserver/webtop:ubuntu-kde
    container_name: webtop-ubuntu
    ports:
      - $docker_port_1:3000
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Shanghai
      - SUBFOLDER=/
      - TITLE=Webtop
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/config
    security_opt:
      - seccomp=unconfined
    shm_size: "1gb"
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			7)
				local choice
				while true; do
					clear
					echo "哪吒监控管理"
					echo "开源,轻量,易用的服务器监控与运维工具"
					echo "------------------------"
					echo "1. 使用           0. 返回上一级"
					echo "------------------------"
					
					echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
					read -r choice

					case $choice in
						1)
							curl -L https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh  -o nezha.sh && chmod +x nezha.sh
							./nezha.sh
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
				;;
			8)
				docker_name="qbittorrent"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="qbittorrent离线BT磁力下载服务"
				docker_url="官网介绍: https://hub.docker.com/r/linuxserver/qbittorrent"
				default_port_1=8081

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  qbittorrent:
    image: linuxserver/qbittorrent:latest
    container_name: qbittorrent
    ports:
      - "$docker_port_1:8081"
      - "6881:6881"
      - "6881:6881/udp"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Shanghai
      - WEBUI_PORT=8081
    volumes:
      - ./config:/config
      - ./downloads:/downloads
    restart: unless-stopped
EOF
)	
				docker_use="sleep 3"
				docker_passwd="docker logs qbittorrent"
				docker_app
				;;
			11)
				docker_name="zentao-server"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="禅道是通用的项目管理软件"
				docker_url="官网介绍: https://www.zentao.net/"
				default_port_1=8080
				default_port_2=3306

				# 处理端口冲突
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  zentao-server:
    image: idoop/zentao:latest
    container_name: zentao-server
    ports:
      - "$docker_port_1:80"
      - "$docker_port_2:3306"
    environment:
      - ADMINER_USER=root
      - ADMINER_PASSWD=123456
      - BIND_ADDRESS=false
    volumes:
      - ./zentao-server/:/opt/zbox/
    extra_hosts:
      - "smtp.exmail.qq.com:163.177.90.125"
    restart: unless-stopped
EOF
)
				docker_use="echo \"初始用户名: admin\""
				docker_passwd="echo \"初始密码: 123456\""
				docker_app
				;;
			12)
				docker_name="qinglong"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="青龙面板是一个定时任务管理平台"
				docker_url="官网介绍: https://github.com/whyour/qinglong"
				default_port_1=5700

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  qinglong:
    image: whyour/qinglong:latest
    container_name: qinglong
    hostname: qinglong
    ports:
      - "$docker_port_1:5700"
    volumes:
      - ./data:/ql/data
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			14)
				docker_name="easyimage"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="简单图床是一个简单的图床程序"
				docker_url="官网介绍: https://github.com/icret/EasyImages2.0"
				default_port_1=8080

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  easyimage:
    image: ddsderek/easyimage:latest
    container_name: easyimage
    ports:
      - "$docker_port_1:80"
    environment:
      - TZ=Asia/Shanghai
      - PUID=1000
      - PGID=1000
    volumes:
      - ./config:/app/web/config
      - ./i:/app/web/i
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			15)
				docker_name="emby"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="emby是一个主从式架构的媒体服务器软件,可以用来整理服务器上的视频和音频,并将音频和视频流式传输到客户端设备"
				docker_url="官网介绍: https://emby.media/"
				default_port_1=8096
				default_port_2=8920

				# 检查HTTP端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  emby:
    image: linuxserver/emby:latest
    container_name: emby
    ports:
      - "$docker_port_1:8096"
      - "$docker_port_2:8920"
    environment:
      - UID=1000
      - GID=100
      - GIDLIST=100
    volumes:
      - ./config:/config
      - ./share1:/mnt/share1
      - ./share2:/mnt/share2
      - ./notify:/mnt/notify
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			16)
				docker_name="looking-glass"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="Speedtest测速面板是一个VPS网速测试工具,多项测试功能,还可以实时监控VPS进出站流量"
				docker_url="官网介绍: https://github.com/wikihost-opensource/als"
				default_port_1=8080
				default_port_2=30000

				if docker inspect "$docker_name" >/dev/null 2>&1; then
					# 如果容器已存在,获取当前映射的端口
					docker_port_1=$(docker inspect "$docker_name" --format '{{ range $p, $conf := .NetworkSettings.Ports }}{{ range $conf }}{{ $p }}:{{ .HostPort }}{{ end }}{{ end }}' | grep -oP '(\d+)$')
				else
					while true; do
						if ss -tuln | grep -q ":$default_port_1 "; then
							# 查找可用的端口
							docker_port_1=$(find_available_port 30000 50000)
							_yellow "默认端口$default_port_1被占用,端口跳跃为$docker_port_1"
							sleep 1
							break
						else
							docker_port_1=$default_port_1
							_yellow "使用默认端口$docker_port_1"
							sleep 1
							break
						fi
					done
				fi

				if ! docker inspect "$docker_name" >/dev/null 2>&1; then
					if [[ "$docker_port_1" -eq "$default_port_2" ]];then
						docker_port_2=$(find_available_port 30500 31000)
						_yellow "默认端口$default_iperf_port被占用,端口跳跃为$docker_port_2"
						sleep 1
					else
						docker_port_2=$default_port_2
						_yellow "使用默认端口$docker_port_2"
						sleep 1
					fi
				else
					docker_port_2=$(docker ps --filter "name=$docker_name" --format "{{.Ports}}" | grep -oP '(\d+)->\1/tcp' | grep -oP '^\d+' | grep -v '80')
				fi

							docker_compose_content=$(cat <<EOF
services:
  looking-glass:
    image: wikihostinc/looking-glass-server
    container_name: looking-glass
    ports:
      - "$docker_port_1:80"
      - "$docker_port_2:$docker_port_2"
    environment:
      - DISPLAY_TRAFFIC=true
      - ENABLE_SPEEDTEST=true
      - UTILITIES_PING=true
      - UTILITIES_SPEEDTESTDOTNET=true
      - UTILITIES_FAKESHELL=true
      - UTILITIES_IPERF3=true
      - UTILITIES_IPERF3_PORT_MIN=$docker_port_2
      - UTILITIES_IPERF3_PORT_MAX=$docker_port_2
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			17)
				docker_name="adguardhome"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="AdGuardHome是一款全网广告拦截与反跟踪软件,未来将不止是一个DNS服务器"
				docker_url="官网介绍: https://hub.docker.com/r/adguard/adguardhome"
				default_port_1=3000

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  adguardhome:
    image: adguard/adguardhome
    container_name: adguardhome
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "$docker_port_1:3000/tcp"
    volumes:
      - ./work:/opt/adguardhome/work
      - ./conf:/opt/adguardhome/conf
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			18)
				docker_name="onlyoffice"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="onlyoffice是一款开源的在线office工具,太强大了!"
				docker_url="官网介绍: https://www.onlyoffice.com/"
				default_port_1=8080

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  onlyoffice:
    image: onlyoffice/documentserver:latest
    container_name: onlyoffice
    ports:
      - "$docker_port_1:80"
    volumes:
      - ./logs:/var/log/onlyoffice
      - ./data:/var/www/onlyoffice/Data
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			19)
				has_ipv4_has_ipv6
				docker_name="safeline-mgt"
				docker_port_1=9443
				while true; do
					check_docker_app
					clear
					echo -e "雷池服务 $check_docker"
					echo "雷池是长亭科技开发的WAF站点防火墙程序面板,可以反代站点进行自动化防御"

					if docker inspect "$docker_name" &>/dev/null; then
						check_docker_app_ip
					fi
					echo ""

					echo "------------------------"
					echo "1. 安装           2. 更新           3. 重置密码           4. 卸载"
					echo "------------------------"
					echo "0. 返回上一级"
					echo "------------------------"

					echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
					read -r choice

					case $choice in
						1)
							install_docker
							bash -c "$(curl -fsSLk https://waf-ce.chaitin.cn/release/latest/setup.sh)"
							clear
							_green "雷池WAF面板已经安装完成"
							check_docker_app_ip
							docker exec safeline-mgt resetadmin
							;;
						2)
							bash -c "$(curl -fsSLk https://waf-ce.chaitin.cn/release/latest/upgrade.sh)"
							docker rmi $(docker images | grep "safeline" | grep "none" | awk '{print $3}')
							echo ""
							clear
							_green "雷池WAF面板已经更新完成"
							check_docker_app_ip
							;;
						3)
							docker exec safeline-mgt resetadmin
							;;
						4)
							cd /data/safeline
							if docker compose version >/dev/null 2>&1; then
								docker compose down --rmi all --volumes
							elif command -v docker-compose >/dev/null 2>&1; then
								docker-compose down --rmi all --volumes
							fi
							echo "如果你是默认安装目录那现在项目已经卸载,如果你是自定义安装目录你需要到安装目录下自行执行:"
							echo "docker compose down --rmi all --volumes"
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
				;;
			20)
				docker_name="portainer"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="portainer是一个轻量级的docker容器管理面板"
				docker_url="官网介绍: https://www.portainer.io/"
				default_port_1=9000

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  portainer:
    image: portainer/portainer
    container_name: portainer
    ports:
      - "$docker_port_1:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/data
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			21)
				docker_name="vscode-web"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="VScode是一款强大的在线代码编写工具"
				docker_url="官网介绍: https://github.com/coder/code-server"
				default_port_1=8080

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  vscode-web:
    image: codercom/code-server:latest
    container_name: vscode-web
    ports:
      - "$docker_port_1:8080"
    volumes:
      - ./vscode-web:/home/coder/.local/share/code-server
    restart: unless-stopped
EOF
)
				docker_use="sleep 3"
				docker_passwd="docker exec vscode-web cat /home/coder/.config/code-server/config.yaml"
				docker_app
				;;
			22)
				docker_name="uptimekuma"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="uptimekuma易于使用的自托管监控工具"
				docker_url="官网介绍: https://github.com/louislam/uptime-kuma"
				default_port_1=3001

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  uptimekuma:
    image: louislam/uptime-kuma:latest
    container_name: uptimekuma
    volumes:
      - ./uptimekuma:/app/data
    ports:
      - "$docker_port_1:3001"
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			23)
				docker_name="memeos"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="Memos是一款轻量级,自托管的备忘录中心"
				docker_url="官网介绍: https://github.com/usememos/memos"
				default_port_1=5230

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  memos:
    image: neosmemo/memos:latest
    container_name: memeos
    hostname: memeos
    ports:
      - "$docker_port_1:5230"
    volumes:
      - ./memos:/var/opt/memos
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			24)
				docker_name="webtop"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="webtop基于Alpine,Ubuntu,Fedora和Arch的容器,包含官方支持的完整桌面环境,可通过任何现代Web浏览器访问"
				docker_url="官网介绍: https://docs.linuxserver.io/images/docker-webtop/"
				default_port_1=3000

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  webtop:
    image: lscr.io/linuxserver/webtop:latest
    container_name: webtop
    security_opt:
      - seccomp=unconfined
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Shanghai
      - SUBFOLDER=/
      - TITLE=Webtop
      - LC_ALL=zh_CN.UTF-8
      - DOCKER_MODS=linuxserver/mods:universal-package-install
      - INSTALL_PACKAGES=font-noto-cjk
    ports:
      - "$docker_port_1:3000"
    volumes:
      - ./config:/config
      - /var/run/docker.sock:/var/run/docker.sock
    shm_size: "1gb"
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			25)
				docker_name="nextcloud"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="Nextcloud拥有超过400,000个部署,是您可以下载的最受欢迎的本地内容协作平台"
				docker_url="官网介绍: https://nextcloud.com/"
				rootpasswd=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c16)

				default_port_1=8080

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud
    restart: unless-stopped
    ports:
      - "$docker_port_1:80"
    environment:
      - NEXTCLOUD_ADMIN_USER=nextcloud
      - NEXTCLOUD_ADMIN_PASSWORD=$rootpasswd
    volumes:
      - ./nextcloud:/var/www/html
EOF
)
				docker_use="echo \"账号: nextcloud  密码: $rootpasswd\""
				docker_passwd=""
				docker_app
				;;
			26)
				docker_name="qd"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="QD-Today是一个HTTP请求定时任务自动执行框架"
				docker_url="官网介绍: https://qd-today.github.io/qd/zh_CN/"
				default_port_1=8080

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  qd:
    image: qdtoday/qd:latest
    container_name: qd
    ports:
      - "$docker_port_1:80"
    volumes:
      - ./config:/usr/src/app/config
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			27)
				docker_name="dockge"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="dockge是一个可视化的docker-compose容器管理面板"
				docker_url="官网介绍: https://github.com/louislam/dockge"
				default_port_1=5001

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  dockge:
    image: louislam/dockge:latest
    container_name: dockge
    ports:
      - "$docker_port_1:5001"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/app/data
      - ./stacks:/data/docker_data/dockge/stacks
    environment:
      - DOCKGE_STACKS_DIR=/data/docker_data/dockge/stacks
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			28)
				docker_name="speedtest"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="speedtest是用Javascript实现的轻量级速度测试工具,即开即用"
				docker_url="官网介绍: https://github.com/librespeed/speedtest"
				default_port_1=8080

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  speedtest:
    image: ghcr.io/librespeed/speedtest:latest
    container_name: speedtest
    environment:
      - MODE=standalone
    ports:
      - "$docker_port_1:80"
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			29)
				docker_name="searxng"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="searxng是一个私有且隐私的搜索引擎站点"
				docker_url="官网介绍: https://hub.docker.com/r/alandoyle/searxng"
				default_port_1=8080

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  searxng:
    image: alandoyle/searxng:latest
    container_name: searxng
    init: true
    volumes:
      - ./config:/etc/searxng
      - ./templates:/usr/local/searxng/searx/templates/simple
      - ./theme:/usr/local/searxng/searx/static/themes/simple
    ports:
      - "$docker_port_1:8080"
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			30)
				docker_name="photoprism"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="photoprism非常强大的私有相册系统"
				docker_url="官网介绍: https://www.photoprism.app/"
				rootpasswd=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c16)
				default_port_1=2342

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  photoprism:
    image: photoprism/photoprism
    container_name: photoprism
    security_opt:
      - seccomp=unconfined
      - apparmor=unconfined
    ports:
      - "$docker_port_1:2342"
    environment:
      - PHOTOPRISM_UPLOAD_NSFW=true
      - PHOTOPRISM_ADMIN_PASSWORD=${rootpasswd}
    volumes:
      - ./storage:/photoprism/storage
      - ./Pictures:/photoprism/originals
    restart: unless-stopped
EOF
)
				docker_use="echo \"账号: admin  密码: $rootpasswd\""
				docker_passwd=""
				docker_app
				;;
			31)
				docker_name="s-pdf"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="这是一个强大的本地托管基于Web的PDF操作工具使用docker,允许您对PDF文件执行各种操作,例如拆分合并,转换,重新组织,添加图像,旋转,压缩等"
				docker_url="官网介绍: https://github.com/Stirling-Tools/Stirling-PDF"
				default_port_1=8080

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  stirling-pdf:
    image: frooodle/s-pdf:latest
    container_name: s-pdf
    restart: unless-stopped
    ports:
      - "$docker_port_1:8080"
    volumes:
      - ./data:/usr/share/tesseract-ocr/5/tessdata
      - ./config:/configs
      - ./logs:/logs
    environment:
      - DOCKER_ENABLE_SECURITY=false
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			32)
				docker_name="drawio"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="这是一个强大图表绘制软件,思维导图,拓扑图,流程图,都能画"
				docker_url="官网介绍: https://www.drawio.com/"
				default_port_1=8080

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  drawio:
    image: jgraph/drawio:latest
    container_name: drawio
    ports:
      - "$docker_port_1:8080"
    volumes:
      - ./drawio:/var/lib/drawio
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			33)
				docker_name="sun-panel"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="Sun-Panel服务器,NAS导航面板,Homepage,浏览器首页"
				docker_url="官网介绍: https://doc.sun-panel.top/zh_cn/"
				default_port_1=3002

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  sun-panel:
    image: hslr/sun-panel:latest
    container_name: sun-panel
    ports:
      - "$docker_port_1:3002"
    volumes:
      - ./conf:/app/conf
      - ./uploads:/app/uploads
      - ./database:/app/database
    restart: unless-stopped
EOF
)
				docker_use="echo \"账号: admin@sun.cc  密码: 12345678\""
				docker_passwd=""
				docker_app
				;;
			34)
				docker_name="pingvin-share"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="Pingvin Share是一个可自建的文件分享平台,是WeTransfer的一个替代品"
				docker_url="官网介绍: https://github.com/stonith404/pingvin-share"
				default_port_1=3000

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  pingvin-share:
    image: stonith404/pingvin-share
    container_name: pingvin-share
    ports:
      - "$docker_port_1:3000"
    volumes:
      - ./data:/opt/app/backend/data
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			35)
				docker_name="moments"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="极简朋友圈,高仿微信朋友圈,记录你的美好生活"
				docker_url="官网介绍: https://github.com/kingwrcy/moments?tab=readme-ov-file"
				default_port_1=3000

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  moments:
    image: kingwrcy/moments:latest
    container_name: moments
    ports:
      - "$docker_port_1:3000"
    volumes:
      - ./data:/app/data
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
    restart: unless-stopped
EOF
)
				docker_use="echo \"账号: admin  密码: a123456\""
				docker_passwd=""
				docker_app
				;;
			36)
				docker_name="lobe-chat"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="LobeChat聚合市面上主流的AI大模型,ChatGPT/Claude/Gemini/Groq/Ollama"
				docker_url="官网介绍: https://github.com/lobehub/lobe-chat"
				default_port_1=3210

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  lobe-chat:
    image: lobehub/lobe-chat:latest
    container_name: lobe-chat
    ports:
      - "$docker_port_1:3210"
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			37)
				docker_name="myip"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="是一个多功能IP工具箱,可以查看自己IP信息及连通性,用网页面板呈现"
				docker_url="官网介绍: https://github.com/jason5ng32/MyIP/blob/main/README_ZH.md"
				default_port_1=18966

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  myip:
    image: ghcr.io/jason5ng32/myip:latest
    container_name: myip
    ports:
      - "$docker_port_1:18966"
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			38)
				clear
				install_docker
				bash -c "$(curl --insecure -fsSL https://ddsrem.com/xiaoya_install.sh)"
				;;
			39)
				docker_name="bililive"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="Bililive-go是一个支持多种直播平台的直播录制工具"
				docker_url="官网介绍: https://github.com/hr3lxphr6j/bililive-go"
				if [ ! -d $docker_workdir ]; then
					mkdir -p $docker_workdir > /dev/null 2>&1
					wget -O $docker_workdir/config.yml https://raw.githubusercontent.com/hr3lxphr6j/bililive-go/master/config.yml > /dev/null 2>&1
				fi
				default_port_1=8080

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  bililive:
    image: chigusa/bililive-go:latest
    container_name: bililive
    ports:
      - "$docker_port_1:8080"
    volumes:
      - ./config.yml:/etc/bililive-go/config.yml
      - ./videos:/srv/bililive
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			40)
				docker_name="it-tools"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="为方便开发人员提供的在线工具"
				docker_url="官网介绍: https://github.com/CorentinTh/it-tools"
				default_port_1=8080

				# 检查端口,如冲突则使用动态端口
				check_available_port

							docker_compose_content=$(cat <<EOF
services:
  it-tools:
    image: qingfeng2336/it-tools:latest
    container_name: it-tools
    ports:
      - "$docker_port_1:80"
    restart: unless-stopped
EOF
)
				docker_use=""
				docker_passwd=""
				docker_app
				;;
			51)
				clear
				curl -L https://raw.githubusercontent.com/oneclickvirt/pve/main/scripts/install_pve.sh -o install_pve.sh && chmod +x install_pve.sh && bash install_pve.sh
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
#################### Docker END ####################

#################### LDNMP建站START ####################
ldnmp_install_status_1() {
	if docker inspect "ldnmp" &>/dev/null; then
		_yellow "LDNMP环境已安装,无法再次安装,可以使用选项37进行更新LDNMP环境"
		end_of
		linux_ldnmp
	else
		:
	fi
}

ldnmp_install_status_2() {
	if docker inspect "ldnmp" &>/dev/null; then
		_red "LDNMP环境已安装,无法还原LDNMP环境,请先卸载现有环境再次尝试还原"
		end_of
		linux_ldnmp
	else
		:
	fi
}

ldnmp_install_status() {
	if docker inspect "ldnmp" &>/dev/null; then
		_yellow "LDNMP环境已安装,开始部署$WEB_NAME"
	else
		_yellow "LDNMP环境未安装,请先安装LDNMP环境,再部署网站"
		end_of
		linux_ldnmp
	fi
}

repeat_add_domain() {
	domain_regex="^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$"
	if [[ $domain =~ $domain_regex ]]; then
		:
	else
		_red "域名格式不正确,请重新输入"
		end_of
		linux_ldnmp
	fi

	if [ -e /data/docker_data/web/nginx/conf.d/$domain.conf ]; then
		_red "当前域名${domain}已被使用,请前往31站点管理,删除站点,再部署${WEB_NAME}"
		end_of
		linux_ldnmp
	fi
}

add_domain() {
	ip_address

	echo -e "先将域名解析到本机IP: ${yellow}$ipv4_address  $ipv6_address${white}"
	echo -n "请输入你解析的域名:"
	read -r domain

	repeat_add_domain
}

add_database() {
	DB_NAME=$(echo "$domain" | sed -e 's/[^A-Za-z0-9]/_/g')

	DBROOT_PASSWD=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /data/docker_data/web/docker-compose.yml | tr -d '[:space:]')
	DB_USER=$(grep -oP 'MYSQL_USER:\s*\K.*' /data/docker_data/web/docker-compose.yml | tr -d '[:space:]')
	DB_USER_PASSWD=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /data/docker_data/web/docker-compose.yml | tr -d '[:space:]')

	if [[ -z "$DBROOT_PASSWD" || -z "$DB_USER" || -z "$DB_USER_PASSWD" ]]; then
		_red "无法获取MySQL凭据"
		return 1
	fi

	docker exec mysql mysql -u root -p"$DBROOT_PASSWD" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME; GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';" || {
		_red "创建数据库或授予权限失败"
		return 1
	}
}

restart_ldnmp() {
	docker exec nginx chmod -R 777 /var/www/html
	docker exec php chmod -R 777 /var/www/html
	docker exec php74 chmod -R 777 /var/www/html

	if nginx_check; then
		docker restart nginx >/dev/null 2>&1
	else
		_red "Nginx配置校验失败,请检查配置文件"
		return 1
	fi
	docker restart php >/dev/null 2>&1
	docker restart php74 >/dev/null 2>&1
}

check_ldnmp_port() {
	docker rm -f nginx >/dev/null 2>&1

	# 定义要检测的端口
	ports=("80" "443")

	# 检查端口占用情况
	for port in "${ports[@]}"; do
		result=$(netstat -tulpn | grep ":$port ")

		if [ -n "$result" ]; then
			clear
			_red "端口$port已被占用,无法安装环境,卸载以下程序后重试"
			_yellow "$result"
			end_of
			linux_ldnmp
			return 1
		fi
	done
}

install_dependency() {
	clear
	install wget socat unzip tar
}

ldnmp_web_on() {
	clear
	echo "您的$WEB_NAME搭建好了!"
	echo "https://$domain"
	echo "------------------------"
	echo "$WEB_NAME安装信息如下:"
}

install_certbot() {
	local cron_job existing_cron

	if ! command -v certbot &> /dev/null; then
		install certbot || { _red "安装certbot失败"; return 1; }
	fi

	[ ! -d /data/script ] && mkdir -p /data/script
	cd /data/script || { _red "进入目录/data/script失败"; return 1; }

	# 下载并使脚本可执行
	curl -sS -o ./auto_cert_renewal.sh https://raw.githubusercontent.com/honeok8s/shell/main/callscript/autocert_certbot.sh
	chmod a+x auto_cert_renewal.sh

	# 设置定时任务字符串
	check_crontab_installed
	cron_job="0 0 * * * /data/script/auto_cert_renewal.sh >/dev/null 2>&1"

	# 检查是否存在相同的定时任务
	existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")

	# 如果不存在,则添加定时任务
	if [ -z "$existing_cron" ]; then
		(crontab -l 2>/dev/null; echo "$cron_job") | crontab -
		_green "续签任务已添加"
	fi
}

install_ssltls() {
	docker stop nginx > /dev/null 2>&1

	iptables_open > /dev/null 2>&1
	cd ~

	yes | certbot delete --cert-name $domain > /dev/null 2>&1

	certbot_version=$(certbot --version 2>&1 | grep -oP "\d+\.\d+\.\d+")

	version_ge() {
		[ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$1" ]
	}

	if version_ge "$certbot_version" "1.17.0"; then
		certbot certonly --standalone -d $domain --email your@email.com --agree-tos --no-eff-email --force-renewal --key-type ecdsa
	else
		certbot certonly --standalone -d $domain --email your@email.com --agree-tos --no-eff-email --force-renewal
	fi

	cp /etc/letsencrypt/live/$domain/fullchain.pem /data/docker_data/web/nginx/certs/${domain}_cert.pem > /dev/null 2>&1
	cp /etc/letsencrypt/live/$domain/privkey.pem /data/docker_data/web/nginx/certs/${domain}_key.pem > /dev/null 2>&1

	docker start nginx > /dev/null 2>&1
}

certs_status() {
	sleep 1
	file_path="/etc/letsencrypt/live/$domain/fullchain.pem"

	if [ ! -f "$file_path" ]; then
		_red "域名证书申请失败,请检测域名是否正确解析或更换域名重新尝试!"
		end_of
		linux_ldnmp
	fi
}

nginx_check() {
	docker exec -it nginx nginx -t > /dev/null 2>&1
	return $?
}

iptables_open(){
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -F

	ip6tables -P INPUT ACCEPT
	ip6tables -P FORWARD ACCEPT
	ip6tables -P OUTPUT ACCEPT
	ip6tables -F
}

default_server_ssl() {

	install openssl

	if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
		openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout /data/docker_data/web/nginx/certs/default_server.key -out /data/docker_data/web/nginx/certs/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
	else
		openssl genpkey -algorithm Ed25519 -out /data/docker_data/web/nginx/certs/default_server.key
		openssl req -x509 -key /data/docker_data/web/nginx/certs/default_server.key -out /data/docker_data/web/nginx/certs/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
	fi
}

ldnmp_version() {
	# 获取nginx版本
	nginx_version=$(docker exec nginx nginx -v 2>&1)
	nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
	echo -n -e "Nginx: ${yellow}v$nginx_version${white}"

	# 获取mysql版本
	DBROOT_PASSWD=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /data/docker_data/web/docker-compose.yml | tr -d '[:space:]')
	mysql_version=$(docker exec mysql mysql -u root -p"$DBROOT_PASSWD" -e "SELECT VERSION();" 2>/dev/null | tail -n 1)
	echo -n -e "     MySQL: ${yellow}v$mysql_version${white}"

	# 获取php版本
	php_version=$(docker exec php php -v 2>/dev/null | grep -oP "PHP \K[0-9]+\.[0-9]+\.[0-9]+")
	echo -n -e "     PHP: ${yellow}v$php_version${white}"

	# 获取redis版本
	redis_version=$(docker exec redis redis-server -v 2>&1 | grep -oP "v=+\K[0-9]+\.[0-9]+")
	echo -e "     Redis: ${yellow}v$redis_version${white}"

	echo "------------------------"
	echo ""
}

install_ldnmp() {
	check_swap
	cd /data/docker_data/web

	if docker compose version >/dev/null 2>&1; then
		docker compose up -d
	elif command -v docker-compose >/dev/null 2>&1; then
		docker-compose up -d
	fi

	clear
	_yellow "正在配置LDNMP环境,请耐心稍等"

	# 定义要执行的命令
	commands=(
		"docker exec nginx chmod -R 777 /var/www/html"
		"docker restart nginx > /dev/null 2>&1"

		"docker exec php apk update > /dev/null 2>&1"
		"docker exec php74 apk update > /dev/null 2>&1"

		# php安装包管理
		"curl -sL https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions -o /usr/local/bin/install-php-extensions > /dev/null 2>&1"
		"docker exec php mkdir -p /usr/local/bin/ > /dev/null 2>&1"
		"docker exec php74 mkdir -p /usr/local/bin/ > /dev/null 2>&1"
		"docker cp /usr/local/bin/install-php-extensions php:/usr/local/bin/ > /dev/null 2>&1"
		"docker cp /usr/local/bin/install-php-extensions php74:/usr/local/bin/ > /dev/null 2>&1"
		"docker exec php chmod +x /usr/local/bin/install-php-extensions > /dev/null 2>&1"
		"docker exec php74 chmod +x /usr/local/bin/install-php-extensions > /dev/null 2>&1"

		# php安装扩展
		"docker exec php sh -c '\
			apk add --no-cache imagemagick imagemagick-dev \
			&& apk add --no-cache git autoconf gcc g++ make pkgconfig \
			&& rm -rf /tmp/imagick \
			&& git clone https://github.com/Imagick/imagick /tmp/imagick \
			&& cd /tmp/imagick \
			&& phpize \
			&& ./configure \
			&& make \
			&& make install \
			&& echo 'extension=imagick.so' > /usr/local/etc/php/conf.d/imagick.ini \
			&& rm -rf /tmp/imagick' > /dev/null 2>&1"

		"docker exec php install-php-extensions imagick > /dev/null 2>&1"
		"docker exec php install-php-extensions mysqli > /dev/null 2>&1"
		"docker exec php install-php-extensions pdo_mysql > /dev/null 2>&1"
		"docker exec php install-php-extensions gd > /dev/null 2>&1"
		"docker exec php install-php-extensions intl > /dev/null 2>&1"
		"docker exec php install-php-extensions zip > /dev/null 2>&1"
		"docker exec php install-php-extensions exif > /dev/null 2>&1"
		"docker exec php install-php-extensions bcmath > /dev/null 2>&1"
		"docker exec php install-php-extensions opcache > /dev/null 2>&1"
		"docker exec php install-php-extensions redis > /dev/null 2>&1"

		# php配置参数
		"docker exec php sh -c 'echo \"upload_max_filesize=50M \" > /usr/local/etc/php/conf.d/uploads.ini' > /dev/null 2>&1"
		"docker exec php sh -c 'echo \"post_max_size=50M \" > /usr/local/etc/php/conf.d/post.ini' > /dev/null 2>&1"
		"docker exec php sh -c 'echo \"memory_limit=256M\" > /usr/local/etc/php/conf.d/memory.ini' > /dev/null 2>&1"
		"docker exec php sh -c 'echo \"max_execution_time=1200\" > /usr/local/etc/php/conf.d/max_execution_time.ini' > /dev/null 2>&1"
		"docker exec php sh -c 'echo \"max_input_time=600\" > /usr/local/etc/php/conf.d/max_input_time.ini' > /dev/null 2>&1"

		# php重启
		"docker exec php chmod -R 777 /var/www/html"
		"docker restart php > /dev/null 2>&1"

		# php7.4安装扩展
		"docker exec php74 install-php-extensions imagick > /dev/null 2>&1"
		"docker exec php74 install-php-extensions mysqli > /dev/null 2>&1"
		"docker exec php74 install-php-extensions pdo_mysql > /dev/null 2>&1"
		"docker exec php74 install-php-extensions gd > /dev/null 2>&1"
		"docker exec php74 install-php-extensions intl > /dev/null 2>&1"
		"docker exec php74 install-php-extensions zip > /dev/null 2>&1"
		"docker exec php74 install-php-extensions exif > /dev/null 2>&1"
		"docker exec php74 install-php-extensions bcmath > /dev/null 2>&1"
		"docker exec php74 install-php-extensions opcache > /dev/null 2>&1"
		"docker exec php74 install-php-extensions redis > /dev/null 2>&1"

		# php7.4配置参数
		"docker exec php74 sh -c 'echo \"upload_max_filesize=50M \" > /usr/local/etc/php/conf.d/uploads.ini' > /dev/null 2>&1"
		"docker exec php74 sh -c 'echo \"post_max_size=50M \" > /usr/local/etc/php/conf.d/post.ini' > /dev/null 2>&1"
		"docker exec php74 sh -c 'echo \"memory_limit=256M\" > /usr/local/etc/php/conf.d/memory.ini' > /dev/null 2>&1"
		"docker exec php74 sh -c 'echo \"max_execution_time=1200\" > /usr/local/etc/php/conf.d/max_execution_time.ini' > /dev/null 2>&1"
		"docker exec php74 sh -c 'echo \"max_input_time=600\" > /usr/local/etc/php/conf.d/max_input_time.ini' > /dev/null 2>&1"

		# php7.4重启
		"docker exec php74 chmod -R 777 /var/www/html"
		"docker restart php74 > /dev/null 2>&1"

		# redis调优
		"docker exec -it redis redis-cli CONFIG SET maxmemory 512mb > /dev/null 2>&1"
		"docker exec -it redis redis-cli CONFIG SET maxmemory-policy allkeys-lru > /dev/null 2>&1"

		# 最后一次php重启
		"docker restart php > /dev/null 2>&1"
		"docker restart php74 > /dev/null 2>&1"
      )

	total_commands=${#commands[@]}  # 计算总命令数

	for ((i = 0; i < total_commands; i++)); do
		command="${commands[i]}"
		eval $command  # 执行命令

		# 打印百分比和进度条
		percentage=$(( (i + 1) * 100 / total_commands ))
		completed=$(( percentage / 2 ))
		remaining=$(( 50 - completed ))
		progressBar="["
			for ((j = 0; j < completed; j++)); do
				progressBar+="#"
			done
			for ((j = 0; j < remaining; j++)); do
				progressBar+="."
			done
			progressBar+="]"
			echo -ne "\r[${orange}$percentage%${white}] $progressBar"
	done

	echo # 打印换行,以便输出不被覆盖

	clear
	_green "LDNMP环境安装完毕"
	echo "------------------------"
	ldnmp_version
}

fail2ban_status() {
	docker restart fail2ban
	sleep 5
	docker exec -it fail2ban fail2ban-client status
}

fail2ban_status_jail() {
	docker exec -it fail2ban fail2ban-client status $jail_name
}

fail2ban_sshd() {
	if grep -q 'Alpine' /etc/issue; then
		jail_name=alpine-sshd
		fail2ban_status_jail
	else
		jail_name=linux-sshd
		fail2ban_status_jail
	fi
}

fail2ban_install_sshd() {
	[ ! -d /data/docker_data/fail2ban ] && mkdir -p /data/docker_data/fail2ban
	wget -qO /data/docker_data/fail2ban/docker-compose.yml https://raw.githubusercontent.com/honeok8s/conf/main/fail2ban/fail2ban-docker-compose.yml
	cd /data/docker_data/fail2ban

	if docker compose version >/dev/null 2>&1; then
		docker compose up -d
	elif command -v docker-compose >/dev/null 2>&1; then
		docker-compose up -d
	fi

	sleep 3
	if grep -q 'Alpine' /etc/issue; then
		cd /data/docker_data/fail2ban/config/fail2ban/filter.d
		curl -sS -O https://raw.githubusercontent.com/kejilion/config/main/fail2ban/alpine-sshd.conf
		curl -sS -O https://raw.githubusercontent.com/kejilion/config/main/fail2ban/alpine-sshd-ddos.conf
		cd /data/docker_data/fail2ban/config/fail2ban/jail.d/
		curl -sS -O https://raw.githubusercontent.com/kejilion/config/main/fail2ban/alpine-ssh.conf
	else
		install rsyslog
		systemctl start rsyslog
		systemctl enable rsyslog
		cd /data/docker_data/fail2ban/config/fail2ban/jail.d/
		curl -sS -O https://raw.githubusercontent.com/honeok8s/conf/main/fail2ban/linux-ssh.conf
	fi
}

linux_ldnmp() {
	local choice
	while true; do
		clear
		echo "▶ LDNMP建站"
		echo "------------------------"
		echo "1. 安装LDNMP环境"
		echo "2. 安装WordPress"
		echo "3. 安装Discuz论坛"
		echo "4. 安装可道云桌面"
		echo "5. 安装苹果CMS网站"
		echo "6. 安装独角数发卡网"
		echo "7. 安装flarum论坛网站"
		echo "8. 安装Typecho轻量博客网站"
		echo "20. 自定义动态站点"
		echo "------------------------"
		echo "21. 仅安装nginx"
		echo "22. 站点重定向"
		echo "23. 站点反向代理-IP+端口"
		echo "24. 站点反向代理-域名"
		echo "25. 自定义静态站点"
		echo "26. 安装Bitwarden密码管理平台"
		echo "27. 安装Halo博客网站"
		echo "------------------------"
		echo "31. 站点数据管理"
		echo "32. 备份全站数据"
		echo "33. 定时远程备份"
		echo "34. 还原全站数据"
		echo "------------------------"
		echo "35. 站点防御程序"
		echo "------------------------"
		echo "36. 优化LDNMP环境"
		echo "37. 更新LDNMP环境"
		echo "38. 卸载LDNMP环境"
		echo "------------------------"
		echo "0. 返回主菜单"
		echo "------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read -r choice
		
		case $choice in
			1)
				need_root
				ldnmp_install_status_1
				check_ldnmp_port
				install_dependency
				install_docker
				install_certbot

				# 创建必要的目录和文件
				web_dir="/data/docker_data/web"
				nginx_dir="$web_dir/nginx"

				[ -d "$web_dir" ] && rm -fr "$web_dir"
				mkdir -p "$nginx_dir/certs" "$nginx_dir/conf.d" "$web_dir/redis" "$web_dir/mysql"

				cd "$web_dir" || { _red "无法进入目录 $web_dir"; return 1; }

				# 下载配置文件
				wget -qO "$nginx_dir/nginx.conf" "https://raw.githubusercontent.com/honeok8s/conf/main/nginx/nginx-2C2G.conf"
				wget -qO "$nginx_dir/conf.d/default.conf" "https://raw.githubusercontent.com/honeok8s/conf/main/nginx/conf.d/default2.conf"

				default_server_ssl

				wget -qO "$web_dir/docker-compose.yml" "https://raw.githubusercontent.com/honeok8s/conf/main/ldnmp/LDNMP-docker-compose.yml"

				DBROOT_PASSWD=$(openssl rand -base64 16)
				DB_USER=$(openssl rand -hex 4)
				DB_USER_PASSWD=$(openssl rand -base64 8)

				sed -i "s#HONEOK_ROOTPASSWD#$DBROOT_PASSWD#g" /data/docker_data/web/docker-compose.yml
				sed -i "s#HONEOK_USER#$DB_USER#g" /data/docker_data/web/docker-compose.yml
				sed -i "s#HONEOK_PASSWD#$DB_USER_PASSWD#g" /data/docker_data/web/docker-compose.yml

				install_ldnmp
				;;
			2)
				clear
				WEB_NAME="WordPress"

				ldnmp_install_status
				add_domain
				install_ssltls
				certs_status
				add_database

				nginx_conf="/data/docker_data/web/nginx/conf.d/$domain.conf"
				wget -qO "$nginx_conf" "https://raw.githubusercontent.com/kejilion/nginx/main/wordpress.com.conf"
				sed -i -e "s/yuming.com/$domain/g" -e "s/my_cache/fst_cache/g" "$nginx_conf"

				wordpress_dir="/data/docker_data/web/nginx/html/$domain"
				mkdir -p "$wordpress_dir"
				cd "$wordpress_dir" || { _red "无法进入目录 $wordpress_dir"; return 1; }
				wget -qO latest.zip "https://cn.wordpress.org/latest-zh_CN.zip" && unzip latest.zip && rm latest.zip

				# 配置WordPress
				wp_config="$wordpress_dir/wordpress/wp-config-sample.php"
				echo "define('FS_METHOD', 'direct');" >> "$wp_config"
				echo "define('WP_REDIS_HOST', 'redis');" >> "$wp_config"
				echo "define('WP_REDIS_PORT', '6379');" >> "$wp_config"

				restart_ldnmp
				ldnmp_web_on

				echo "数据库名:$DB_NAME"
				echo "用户名:$DB_USER"
				echo "密码:$DB_USER_PASSWD"
				echo "数据库地址:mysql"
				echo "表前缀:wp_"
				;;
			31)
				need_root
				while true; do
					clear
					echo "LDNMP环境"
					echo "------------------------"
					ldnmp_version

					echo "站点信息                      证书到期时间"
					echo "------------------------"
					for cert_file in /data/docker_data/web/nginx/certs/*_cert.pem; do
						domain=$(basename "$cert_file" | sed 's/_cert.pem//')
						if [ -n "$domain" ]; then
							expire_date=$(openssl x509 -noout -enddate -in "$cert_file" | awk -F'=' '{print $2}')
							formatted_date=$(date -d "$expire_date" '+%Y-%m-%d')
							printf "%-30s%s\n" "$domain" "$formatted_date"
						fi
					done

					echo "------------------------"
					echo ""
					echo "数据库信息"
					echo "------------------------"
					DBROOT_PASSWD=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /data/docker_data/web/docker-compose.yml | tr -d '[:space:]')
					docker exec mysql mysql -u root -p"$DBROOT_PASSWD" -e "SHOW DATABASES;" 2> /dev/null | grep -Evi "Database|information_schema|mysql|performance_schema|sys"
					echo "------------------------"
					echo ""
					echo "站点目录"
					echo "------------------------"
					echo "数据目录: /data/docker_data/web/nginx/html    证书目录: /data/docker_data/web/nginx/certs     配置文件目录: /data/docker_data/web/nginx/conf.d"
					echo "------------------------"
					echo ""
					echo "操作"
					echo "------------------------"
					echo "1. 申请/更新域名证书               2. 修改域名"
					echo "3. 清理站点缓存                    4. 查看站点分析报告"
					echo "5. 编辑全局配置                    6. 编辑站点配置"
					echo "------------------------"
					echo "7. 删除指定站点                    8. 删除指定数据库"
					echo "------------------------"
					echo "0. 返回上一级选单"
					echo "------------------------"

					echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
					read -r choice

					case $choice in
						1)
							read -r -p "请输入你的域名: " domain
							install_certbot
							install_ssltls
							certs_status
							;;
						2)
							read -r -p "请输入旧域名:" old_domain
							read -r -p "请输入新域名:" new_domain
							install_certbot
							install_ssltls
							certs_status
							mv "/data/docker_data/web/nginx/conf.d/$old_domain.conf" "/data/docker_data/web/nginx/conf.d/$new_domain.conf"
							sed -i "s/$old_domain/$new_domain/g" "/data/docker_data/web/nginx/conf.d/$new_domain.conf"
							mv "/data/docker_data/web/nginx/html/$old_domain" "/data/docker_data/web/nginx/html/$new_domain"

							rm -f "/data/docker_data/web/nginx/certs/${old_domain}_key.pem" "/data/docker_data/web/nginx/certs/${old_domain}_cert.pem"

							if nginx_check; then
								docker restart nginx >/dev/null 2>&1
							else
								_red "Nginx配置校验失败,请检查配置文件"
								return 1
							fi
							;;
						3)
							if nginx_check; then
								docker restart nginx
							else
								_red "Nginx配置校验失败,请检查配置文件"
								return 1
							fi
							docker exec php php -r 'opcache_reset();'
							docker restart php
							docker exec php74 php -r 'opcache_reset();'
							docker restart php74
							docker restart redis
							docker exec redis redis-cli FLUSHALL
							docker exec -it redis redis-cli CONFIG SET maxmemory 512mb
							docker exec -it redis redis-cli CONFIG SET maxmemory-policy allkeys-lru
							;;
						4)
							install goaccess
							goaccess --log-format=COMBINED /data/docker_data/web/nginx/log/access.log
							;;
						5)
							vim /data/docker_data/web/nginx/nginx.conf

							if nginx_check; then
								docker restart nginx >/dev/null 2>&1
							else
								_red "Nginx配置校验失败,请检查配置文件"
								return 1
							fi
							;;
						6)
							read -r -p "编辑站点配置,请输入你要编辑的域名:" edit_domain
							vim "/data/docker_data/web/nginx/conf.d/$edit_domain.conf"

							if nginx_check; then
								docker restart nginx >/dev/null 2>&1
							else
								_red "Nginx配置校验失败,请检查配置文件"
								return 1
							fi
							;;
						7)
							read -r -p "删除站点数据目录,请输入你的域名:" del_domain
							rm -fr "/data/docker_data/web/nginx/html/$del_domain"
							rm -f "/data/docker_data/web/nginx/conf.d/$del_domain.conf" "/data/docker_data/web/nginx/certs/${del_domain}_key.pem" "/data/docker_data/web/nginx/certs/${del_domain}_cert.pem"

							if nginx_check; then
								docker restart nginx >/dev/null 2>&1
							else
								_red "Nginx配置校验失败,请检查配置文件"
								return 1
							fi
							;;
						8)
							read -r -p "删除站点数据库,请输入数据库名:" del_database
							DBROOT_PASSWD=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /data/docker_data/web/docker-compose.yml | tr -d '[:space:]')
							docker exec mysql mysql -u root -p"$DBROOT_PASSWD" -e "DROP DATABASE $del_database;" >/dev/null 2>&1
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
			35)
				if docker inspect fail2ban &>/dev/null ; then
					while true; do
						clear
						echo "服务器防御程序已启动"
						echo "------------------------"
						echo "1. 开启SSH防暴力破解              2. 关闭SSH防暴力破解"
						echo "3. 开启网站保护                   4. 关闭网站保护"
						echo "------------------------"
						echo "5. 查看SSH拦截记录                6. 查看网站拦截记录"
						echo "7. 查看防御规则列表               8. 查看日志实时监控"
						echo "------------------------"
						echo "11. 配置拦截参数"
						echo "------------------------"
						echo "21. cloudflare模式                22. 高负载开启5秒盾"
						echo "------------------------"
						echo "9. 卸载防御程序"
						echo "------------------------"
						echo "0. 退出"
						echo "------------------------"
						
						echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
						read -r choice
						
						case $choice in
							1)
								[ -f /data/docker_data/fail2ban/config/fail2ban/jail.d/alpine-ssh.conf ] && sed -i 's/false/true/g' /data/docker_data/fail2ban/config/fail2ban/jail.d/alpine-ssh.conf
								[ -f /data/docker_data/fail2ban/config/fail2ban/jail.d/linux-ssh.conf ] && sed -i 's/false/true/g' /data/docker_data/fail2ban/config/fail2ban/jail.d/linux-ssh.conf
								[ -f /data/docker_data/fail2ban/config/fail2ban/jail.d/centos-ssh.conf ] && sed -i 's/false/true/g' /data/docker_data/fail2ban/config/fail2ban/jail.d/centos-ssh.conf
								fail2ban_status
								;;
							2)
								[ -f /data/docker_data/fail2ban/config/fail2ban/jail.d/alpine-ssh.conf ] && sed -i 's/true/false/g' /data/docker_data/fail2ban/config/fail2ban/jail.d/alpine-ssh.conf
								[ -f /data/docker_data/fail2ban/config/fail2ban/jail.d/linux-ssh.conf ] && sed -i 's/true/false/g' /data/docker_data/fail2ban/config/fail2ban/jail.d/linux-ssh.conf
								[ -f /data/docker_data/fail2ban/config/fail2ban/jail.d/centos-ssh.conf ] && sed -i 's/true/false/g' /data/docker_data/fail2ban/config/fail2ban/jail.d/centos-ssh.conf
								fail2ban_status
								;;
							3)
								[ -f /data/docker_data/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf ] && sed -i 's/false/true/g' /data/docker_data/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
								fail2ban_status
								;;
							4)
								[ -f /data/docker_data/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf ] && sed -i 's/true/false/g' /data/docker_data/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
								fail2ban_status
								;;
							5)
								echo "------------------------"
								fail2ban_sshd
								echo "------------------------"
								;;
							6)
								echo "------------------------"
								jail_name=fail2ban-nginx-cc
								fail2ban_status_jail
								echo "------------------------"
								jail_name=docker-nginx-bad-request
								fail2ban_status_jail
								echo "------------------------"
								jail_name=docker-nginx-botsearch
								fail2ban_status_jail
								echo "------------------------"
								jail_name=docker-nginx-http-auth
								fail2ban_status_jail
								echo "------------------------"
								jail_name=docker-nginx-limit-req
								fail2ban_status_jail
								echo "------------------------"
								jail_name=docker-php-url-fopen
								fail2ban_status_jail
								echo "------------------------"
								;;
							7)
								docker exec -it fail2ban fail2ban-client status
								;;
							8)
								timeout 5 tail -f /data/docker_data/fail2ban/config/log/fail2ban/fail2ban.log
								;;
							9)
								cd /data/docker_data/fail2ban || { _red "无法进入目录/data/docker_data/fail2ban"; return 1; }

								if docker compose version >/dev/null 2>&1; then
									docker compose down --rmi all --volumes
								elif command -v docker-compose >/dev/null 2>&1; then
									docker-compose down --rmi all --volumes
								fi

								[ -d /data/docker_data/fail2ban ] && rm -fr /data/docker_data/fail2ban
								crontab -l | grep -v "CF-Under-Attack.sh" | crontab - 2>/dev/null
								_green "Fail2Ban防御程序已卸载"
								break
								;;
							11)
								vim /data/docker_data/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
								fail2ban_status
								break
								;;
							21)
								echo "Cloudflare后台右上角我的个人资料,选择左侧API令牌,获取Global API Key"
								echo "https://dash.cloudflare.com/login"
								
								# 获取CFUSER
								while true; do
									echo -n "请输入你的Cloudflare管理员邮箱:"
									read -r CFUSER
									if [[ "$CFUSER" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
										break
									else
										_red "无效的邮箱格式,请重新输入"
									fi
								done
								# 获取CFKEY
								while true; do
									echo "cloudflare后台右上角我的个人资料,选择左侧API令牌,获取Global API Key"
									echo "https://dash.cloudflare.com/login"
									echo -n "请输入你的Global API Key:"
									read -r CFKEY
									if [[ -n "$CFKEY" ]]; then
										break
									else
										_red "CFKEY不能为空,请重新输入"
									fi
								done

								wget -qO /data/docker_data/web/nginx/conf.d/default.conf https://raw.githubusercontent.com/honeok8s/conf/main/nginx/conf.d/default11.conf

								if nginx_check; then
									docker restart nginx >/dev/null 2>&1
								else
									_red "Nginx配置校验失败,请检查配置文件"
									return 1
								fi

								cd /data/docker_data/fail2ban/config/fail2ban/jail.d || { _red "无法进入目录 /data/docker_data/fail2ban/config/fail2ban/jail.d"; return 1; }
								curl -sS -O https://raw.githubusercontent.com/honeok8s/conf/main/fail2ban/nginx-docker-cc.conf
								
								cd /data/docker_data/fail2ban/config/fail2ban/action.d || { _red "无法进入目录 /data/docker_data/fail2ban/config/fail2ban/action.d"; return 1; }
								curl -sS -O https://raw.githubusercontent.com/honeok8s/conf/main/fail2ban/cloudflare-docker.conf
								
								sed -i "s/kejilion@outlook.com/$CFUSER/g" /data/docker_data/fail2ban/config/fail2ban/action.d/cloudflare-docker.conf
								sed -i "s/APIKEY00000/$CFKEY/g" /data/docker_data/fail2ban/config/fail2ban/action.d/cloudflare-docker.conf

								fail2ban_status
								_green "已配置Cloudflare模式,可在Cloudflare后台站点-安全性-事件中查看拦截记录"
								;;
							22)
								echo "网站每5分钟自动检测,当达检测到高负载会自动开盾,低负载也会自动关闭5秒盾"
								echo "------------------------"

								# 获取CFUSER
								while true; do
									echo -n "请输入你的Cloudflare管理员邮箱:"
									read -r CFUSER
									if [[ "$CFUSER" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
										break
									else
										_red "无效的邮箱格式,请重新输入"
									fi
								done
								# 获取CFKEY
								while true; do
									echo "cloudflare后台右上角我的个人资料,选择左侧API令牌,获取Global API Key"
									echo "https://dash.cloudflare.com/login"
									echo -n "请输入你的Global API Key:"
									read -r CFKEY
									if [[ -n "$CFKEY" ]]; then
										break
									else
										_red "CFKEY不能为空,请重新输入"
									fi
								done
								# 获取ZoneID
								while true;do
									echo "Cloudflare后台域名概要页面右下方获取区域ID"
									echo -n "请输入你的ZoneID:"
									read -r CFZoneID
									if [[ -n "$CFZoneID" ]]; then
										break
									else
										_red "CFZoneID不能为空,请重新输入"
									fi
								done

								install jq bc
								check_crontab_installed

								[ ! -d /data/script ] && mkdir -p /data/script
								cd /data/script || { _red "进入目录/data/script失败"; return 1; }

								curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/CF-Under-Attack.sh
								chmod +x CF-Under-Attack.sh
								sed -i "s/AAAA/$CFUSER/g" /data/script/CF-Under-Attack.sh
								sed -i "s/BBBB/$CFKEY/g" /data/script/CF-Under-Attack.sh
								sed -i "s/CCCC/$CFZoneID/g" /data/script/CF-Under-Attack.sh

								cron_job="*/5 * * * * /data/script/CF-Under-Attack.sh >/dev/null 2>&1"
								existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")
								
								if [ -z "$existing_cron" ]; then
									(crontab -l 2>/dev/null; echo "$cron_job") | crontab -
									_green "高负载自动开盾脚本已添加"
								else
									_yellow "自动开盾脚本已存在,无需添加"
								fi
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
				elif [ -x "$(command -v fail2ban-client)" ] ; then
					clear
					echo "卸载旧版Fail2ban"
					echo -n "确定继续吗?(y/n):"
					read -r choice

					case "$choice" in
						[Yy])
							remove fail2ban
							rm -fr /etc/fail2ban
							_green "Fail2Ban防御程序已卸载"
							;;
						[Nn])
							:
							_yellow "已取消"
							;;
						*)
							_red "无效选项,请重新输入"
							;;
					esac
				else
					clear
					install_docker

					docker rm -f nginx
					
					[ ! -d /data/docker_data/web/nginx ] && mkdir -p /data/docker_data/web/nginx
					cd /data/docker_data/web/nginx || { _red "进入目录/data/docker_data/web/nginx失败"; return 1; }

					wget -qO nginx.conf https://raw.githubusercontent.com/honeok8s/conf/main/nginx/nginx-2C2G.conf

					for dir in ./conf.d ./certs; do
						[ ! -d "$dir" ] && mkdir -p "$dir"
					done
					wget -O ./conf.d/default.conf https://raw.githubusercontent.com/honeok8s/conf/main/nginx/conf.d/default11.conf

					default_server_ssl

					wget -O docker-compose.yml https://raw.githubusercontent.com/honeok8s/conf/main/nginx/docker-compose.yml
					
					if docker compose version >/dev/null 2>&1; then
						docker compose up -d
					elif command -v docker-compose >/dev/null 2>&1; then
						docker-compose up -d
					fi

					docker exec -it nginx chmod -R 777 /var/www/html

					fail2ban_install_sshd
					cd /data/docker_data/fail2ban/config/fail2ban/filter.d
					curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/fail2ban-nginx-cc.conf
					cd /data/docker_data/fail2ban/config/fail2ban/jail.d
					curl -sS -O https://raw.githubusercontent.com/kejilion/config/main/fail2ban/nginx-docker-cc.conf

					sed -i "/cloudflare/d" /data/docker_data/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf

					cd ~
					fail2ban_status
					_green "防御程序已开启"
				fi
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
#################### LDNMP建站END ####################

#################### 系统工具START ####################
restart_ssh() {
	restart sshd ssh > /dev/null 2>&1
}

add_sshpasswd() {
	_yellow "设置你的root密码"
	passwd
	sed -i 's/^\s*#\?\s*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
	sed -i 's/^\s*#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
	rm -fr /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*
	restart_ssh

	_green "ROOT登录设置完毕"
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

	if [[ "$(curl -s ipinfo.io/country)" == "CN" ]]; then
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

reinstall_system(){
	MollyLau_script(){
		wget --no-check-certificate -qO InstallNET.sh 'https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh' && chmod a+x InstallNET.sh
	}

	bin456789_script(){
		curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
	}

	dd_linux_mollyLau(){
		echo -e "重装后初始用户名:${yellow}root${white} 初始密码:${yellow}LeitboGi0ro${white} 初始端口:${yellow}22${white}"
		echo "详细参数参考Github 项目地址：https://github.com/leitbogioro/Tools"
		_yellow "按任意键继续"
		read -n 1 -s -r -p ""
		install wget
		MollyLau_script
	}

	dd_windows_mollyLau() {
		echo -e "重装后初始用户名:${yellow}Administrator${white} 初始密码:${yellow}Teddysun.com${white} 初始端口:${yellow}3389${white}"
		echo "详细参数参考Github 项目地址：https://github.com/leitbogioro/Tools"
		_yellow "按任意键继续"
		read -n 1 -s -r -p ""
		install wget
		MollyLau_script
	}

	dd_linux_bin456789() {
		echo -e "重装后初始用户名:${yellow}root${white} 初始密码:${yellow}123@@@${white} 初始端口:${yellow}22${white}"
		echo "详细参数参考Github 项目地址：https://github.com/bin456789/reinstall"
		_yellow "按任意键继续"
		read -n 1 -s -r -p ""
		bin456789_script
	}

	dd_windows_bin456789() {
		echo -e "重装后初始用户名:${yellow}Administrator${white} 初始密码:${yellow}123@@@${white} 初始端口:${yellow}3389${white}"
		echo "详细参数参考Github项目地址：https://github.com/bin456789/reinstall"
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
			return 1
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
		read -r choice

		case "$choice" in
			1)
				dd_linux_mollyLau
				bash InstallNET.sh -debian 12 && reboot || reboot
				exit
				;;
			2)
				dd_linux_mollyLau
				bash InstallNET.sh -debian 11 && reboot || reboot
				exit
				;;
			3)
				dd_linux_mollyLau
				bash InstallNET.sh -debian 10 && reboot || reboot
				exit
				;;
			4)
				dd_linux_mollyLau
				bash InstallNET.sh -debian 9 && reboot || reboot
				exit
				;;
			11)
				dd_linux_mollyLau
				bash InstallNET.sh -ubuntu 24.04 && reboot || reboot
				exit
				;;
			12)
				dd_linux_mollyLau
				bash InstallNET.sh -ubuntu 22.04 && reboot || reboot
				exit
				;;
			13)
				dd_linux_mollyLau
				bash InstallNET.sh -ubuntu 20.04 && reboot || reboot
				exit
				;;
			14)
				dd_linux_mollyLau
				bash InstallNET.sh -ubuntu 18.04 && reboot || reboot
				exit
				;;
			21)
				dd_linux_bin456789
				bash reinstall.sh rocky && reboot || reboot
				exit
				;;
			22)
				dd_linux_bin456789
				bash reinstall.sh rocky 8 && reboot || reboot
				exit
				;;
			23)
				dd_linux_bin456789
				bash reinstall.sh alma && reboot || reboot
				exit
				;;
			24)
				dd_linux_bin456789
				bash reinstall.sh alma 8 && reboot || reboot
				exit
				;;
			25)
				dd_linux_bin456789
				bash reinstall.sh oracle && reboot || reboot
				exit
				;;
			26)
				dd_linux_bin456789
				bash reinstall.sh oracle 8 && reboot || reboot
				exit
				;;
			27)
				dd_linux_bin456789
				bash reinstall.sh fedora && reboot || reboot
				exit
				;;
			28)
				dd_linux_bin456789
				bash reinstall.sh fedora 39 && reboot || reboot
				exit
				;;
			29)
				dd_linux_mollyLau
				bash InstallNET.sh -centos 7 && reboot || reboot
				exit
				;;
			31)
				dd_linux_mollyLau
				bash InstallNET.sh -alpine && reboot || reboot
				exit
				;;
			32)
				dd_linux_bin456789
				bash reinstall.sh arch && reboot || reboot
				exit
				;;
			33)
				dd_linux_bin456789
				bash reinstall.sh kali && reboot || reboot
				exit
				;;
			34)
				dd_linux_bin456789
				bash reinstall.sh openeuler && reboot || reboot
				exit
				;;
			35)
				dd_linux_bin456789
				bash reinstall.sh opensuse && reboot || reboot
				exit
				;;
			41)
				dd_windows_mollyLau
				bash InstallNET.sh -windows 11 -lang "cn" && reboot || reboot
				exit
				;;
			42)
				dd_windows_mollyLau
				bash InstallNET.sh -windows 10 -lang "cn" && reboot || reboot
				exit
				;;
			44)
				dd_windows_bin456789
				URL="https://massgrave.dev/windows_server_links"
				iso_link=$(wget -q -O - "$URL" | grep -oP '(?<=href=")[^"]*cn[^"]*windows_server[^"]*2022[^"]*x64[^"]*\.iso')
				bash reinstall.sh windows --iso="$iso_link" --image-name='Windows Server 2022 SERVERDATACENTER' && reboot || reboot
				exit
				;;
			45)
				dd_windows_mollyLau
				bash InstallNET.sh -windows 2019 -lang "cn" && reboot || reboot
				exit
				;;
			46)
				dd_windows_mollyLau
				bash InstallNET.sh -windows 2016 -lang "cn" && reboot || reboot
				exit
				;;
			100)
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
		read -r choice

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

xanmod_bbr3(){
	local choice
	need_root

	echo "XanMod BBR3管理"
	if dpkg -l | grep -q 'linux-xanmod'; then
		while true; do
			clear
			local kernel_version=$(uname -r)
			echo "已安装XanMod的BBRv3内核"
			echo "当前内核版本: $kernel_version"

			echo ""
			echo "内核管理"
			echo "-------------------------"
			echo "1. 更新BBRv3内核              2. 卸载BBRv3内核"
			echo "-------------------------"
			echo "0. 返回上一级选单"
			echo "-------------------------"

			echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
			read -r choice

			case $choice in
				1)
					remove 'linux-*xanmod1*'
					update-grub
					# wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes
					wget -qO - https://raw.githubusercontent.com/honeok8s/shell/main/callscript/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes

					# 添加存储库
					echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list

					# kernel_version=$(wget -q https://dl.xanmod.org/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')
					local kernel_version=$(wget -q https://raw.githubusercontent.com/honeok8s/shell/main/callscript/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')

					install linux-xanmod-x64v$kernel_version

					_green "XanMod内核已更新,重启后生效"
					rm -f /etc/apt/sources.list.d/xanmod-release.list
					rm -f check_x86-64_psabi.sh*

					server_reboot
					;;
				2)
					remove 'linux-*xanmod1*'
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
		read -r choice

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

				install linux-xanmod-x64v$kernel_version

				set_default_qdisc
				bbr_on

				_green "XanMod内核安装并启用BBR3成功,重启后生效!"
				rm -f /etc/apt/sources.list.d/xanmod-release.list
				rm -f check_x86-64_psabi.sh*
				
				server_reboot
				;;
			[Nn])
				:
				_yellow "已取消"
				;;
			*)
				_red "无效的选择,请输入Y或N"
				;;
		esac
	fi
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
		read -r choice
	
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
	if command -v crontab >/dev/null 2>&1; then
		_green "crontab已安装"
		return $?
	else
		install_crontab
		return 0
	fi
}

install_crontab() {
	if [ -f /etc/os-release ]; then
		. /etc/os-release
			case "$ID" in
				ubuntu|debian)
					install cron
					enable cron
					start cron
					;;
				centos)
					install cronie
					enable crond
					start crond
					;;
				alpine)
					apk add --no-cache cronie
					rc-update add crond
					rc-service crond start
					;;
				*)
					_red "不支持的发行版:$ID"
					return 1
					;;
			esac
	else
		_red "无法确定操作系统"
		return 1
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
		read -r choice

		case $choice in
			1)
				echo -n -e "${yellow}请输入新任务的执行命令:${white}"
				read -r newquest
				echo "-------------------------"
				echo "1. 每月任务                 2. 每周任务"
				echo "3. 每天任务                 4. 每小时任务"
				echo "-------------------------"

				echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
				read -r dingshi

				case $dingshi in
					1)
						echo -n -e "${yellow}选择每月的几号执行任务?(1-30):${white}"
						read -r day
						if [[ ! $day =~ ^[1-9]$|^[12][0-9]$|^30$ ]]; then
							_red "无效的日期输入"
							continue
						fi
						if ! (crontab -l ; echo "0 0 $day * * $newquest") | crontab - > /dev/null 2>&1; then
							_red "添加定时任务失败"
						fi
						;;
					2)
						echo -n -e "${yellow}选择周几执行任务?(0-6,0代表星期日):${white}"
						read -r weekday
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
						read -r hour
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
						read -r minute
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
				read -r kquest
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
	read -r choice

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
			echo -e "${white}Cloudflare ddns: ${green}已安装${white}"
			crontab -l | grep "/usr/local/bin/cf-ddns.sh"
		else
			echo -e "${white}Cloudflare ddns: ${yellow}未安装${white}"
			echo "使用动态解析之前请解析一个域名,如ddns.honeok.com到你的当前公网IP"
		fi
		echo "公网IPV4地址: ${ipv4_address}"
		echo "公网IPV6地址: ${ipv6_address}"
		echo "-------------------------"
		echo "1. 设置DDNS动态域名解析    2. 删除DDNS动态域名解析"
		echo "-------------------------"
		echo "0. 返回上一级"
		echo "-------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read -r choice

		case $choice in
			1)
				# 获取CFKEY
				while true; do
					echo "cloudflare后台右上角我的个人资料,选择左侧API令牌,获取Global API Key"
					echo "https://dash.cloudflare.com/login"
					echo -n "请输入你的Global API Key:"
					read -r CFKEY
					if [[ -n "$CFKEY" ]]; then
						break
					else
						_red "CFKEY不能为空,请重新输入"
					fi
				done

				# 获取CFUSER
				while true; do
					echo -n "请输入你的Cloudflare管理员邮箱:"
					read -r CFUSER
					if [[ "$CFUSER" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
						break
					else
						_red "无效的邮箱格式,请重新输入"
					fi
				done
				
				# 获取CFZONE_NAME
				while true; do
					echo -n "请输入你的顶级域名(如honeok.com):"
					read -r CFZONE_NAME
					if [[ "$CFZONE_NAME" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
						break
					else
						_red "无效的域名格式,请重新输入"
					fi
				done
				
				# 获取CFRECORD_NAME
				while true; do
					echo -n "请输入你的主机名(如ddns.honeok.com):"
					read -r CFRECORD_NAME
					if [[ -n "$CFRECORD_NAME" ]]; then
						break
					else
						_red "主机名不能为空,请重新输入"
					fi
				done

				# 获取CFRECORD_TYPE
				echo -n "请输入记录类型(A记录或AAAA记录,默认IPV4 A记录,回车使用默认值):"
				read -r CFRECORD_TYPE
				CFRECORD_TYPE=${CFRECORD_TYPE:-A}

				# 获取CFTTL
				echo -n "请输入TTL时间(120~86400秒,默认60秒,回车使用默认值):"
				read -r CFTTL
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

server_reboot(){
	local choice
	echo -n -e "${yellow}现在重启服务器吗?(y/n):${white}"
	read -r choice

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

# 系统工具主菜单
linux_system_tools(){
	local choice
	while true; do
		clear
		echo "▶ 系统工具"
		echo "------------------------"
		echo "3. root密码登录模式"
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
		echo "101. 卸载honeok脚本"
		echo "------------------------"
		echo "0. 返回主菜单"
		echo "------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read -r choice

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
					read -r choice

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
					read -r choice

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
							read -r new_swap
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
					read -r choice

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
			101)
				echo "NEW"
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

#################### 系统工具END ####################

#################### VPS测试脚本START ####################
servertest_script(){
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
		read -r choice

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
				read -r testip
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
#################### VPS测试脚本 END ####################

#################### 节点搭建脚本START ####################
node_create(){
	if [[ "$(curl -s ipinfo.io/country)" == "CN" ]]; then
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
		read -r choice

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
		end_of
	done
}
#################### 节点搭建脚本END ####################

#################### 甲骨文START ####################
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
		read -r choice

		case $choice in
			1)
				clear
				_yellow "活跃脚本: CPU占用10-20% 内存占用20%"
				echo -n -e "${yellow}确定安装吗?(y/n/):${white}"
				read -r ins
				
				case "$ins" in
					[Yy])
						install_docker
						# 设置默认值
						DEFAULT_CPU_CORE=1
						DEFAULT_CPU_UTIL="10-20"
						DEFAULT_MEM_UTIL=20
						DEFAULT_SPEEDTEST_INTERVAL=120

						# 提示用户输入CPU核心数和占用百分比,如果回车则使用默认值
						echo -n -e "${yellow}请输入CPU核心数[默认:$DEFAULT_CPU_CORE]:${white}"
						read -r cpu_core
						cpu_core=${cpu_core:-$DEFAULT_CPU_CORE}

						echo -n -e "${yellow}请输入CPU占用百分比范围(例如10-20)[默认:$DEFAULT_CPU_UTIL]:${white}"
						read -r cpu_util
						cpu_util=${cpu_util:-$DEFAULT_CPU_UTIL}

						echo -n -e "${yellow}请输入内存占用百分比[默认:$DEFAULT_MEM_UTIL]:${white}"
						read -r mem_util
						mem_util=${mem_util:-$DEFAULT_MEM_UTIL}

						echo -n -e "${yellow}请输入Speedtest间隔时间(秒)[默认:$DEFAULT_SPEEDTEST_INTERVAL]:${white}"
						read -r speedtest_interval
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
				read -r choice

				case "$choice" in
					[Yy])
						while true; do
							echo -n -e "${yellow}请选择要重装的系统:  1. Debian12 | 2. Ubuntu20.04${white}"
							read -r sys_choice

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
						read -r vpspasswd
				
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
#################### 甲骨文END ####################

#################### 幻兽帕鲁START ####################
palworld_script(){
	need_root
	while true; do
		clear

		if [ -f ~/palworld.sh ]; then
			echo -e "${white}幻兽帕鲁脚本: ${green}已安装${white}"
		else
			echo -e "${white}幻兽帕鲁脚本: ${yellow}未安装${white}"
		fi

		echo ""
		echo "幻兽帕鲁管理"
		echo "Author: kejilion"
		echo "-------------------------"
		echo "1. 安装脚本  2. 卸载脚本  3. 运行脚本"
		echo "-------------------------"
		echo "0. 返回主菜单"
		echo "-------------------------"

		echo -n -e "${yellow}请输入选项并按回车键确认:${white}"
		read -r choice

		case $choice in
			1)
				cd ~
				curl -fsSL -o ./palworld.sh https://raw.githubusercontent.com/honeok8s/shell/main/callscript/palworld.sh
				chmod a+x ./palworld.sh
				;;
			2)
				[ -f ~/palworld.sh ] && rm ~/palworld.sh
				[ -L /usr/local/bin/p ] && rm /usr/local/bin/p

				if [ ! -f ~/palworld.sh ] && [ ! -L /usr/local/bin/p ]; then
					_red "幻兽帕鲁开服脚本未安装"
				fi
				;;
			3)
				if [ -f ~/palworld.sh ]; then
					bash ~/palworld.sh
				else
					curl -fsSL -o palworld.sh https://raw.githubusercontent.com/honeok8s/shell/main/callscript/palworld.sh
					chmod a+x palworld.sh
					bash palworld.sh
				fi
				;;
			0)
				honeok
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
	done
}
#################### 幻兽帕鲁END ####################

#################### 脚本更新START ####################
honeok_update() {
	local remote_script_url="https://raw.githubusercontent.com/honeok8s/shell/main/honeok.sh"
	local local_script_path="$HOME/honeok.sh"

	# 检查本地脚本是否存在
	if [[ ! -f "$local_script_path" ]]; then
		_yellow "本地脚本不存在,正在下载"
		curl -s -o "$local_script_path" "$remote_script_url" && chmod a+x $local_script_path
		return 0
	fi

	# 从远程脚本中提取第29行的版本号
	local remote_version
	remote_version=$(curl -s "$remote_script_url" | sed -n '29p' | awk -F'=' '{print $2}' | tr -d '"')

	# 从本地脚本中提取第29行的版本号
	local local_version
	local_version=$(sed -n '29p' "$local_script_path" | awk -F'=' '{print $2}' | tr -d '"')

	# 检查版本号并更新脚本
	if [[ "$remote_version" != "$local_version" ]]; then
		echo -e "${white}远程版本: ${yellow}$remote_version${white} ${white}本地版本:${yellow}$local_version${white}" 
		curl -s -o "$local_script_path" "$remote_script_url" && chmod a+x $local_script_path
		echo -e "${white}脚本已更新到最新版本:${yellow}$remote_version${white}"
	else
		echo -e "${white}脚本已是最新版本: ${yellow}$local_version${white}"
	fi
}
#################### 脚本更新END ####################

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
		read -r choice

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
				clear
				linux_clean
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
				linux_ldnmp
				;;
			12)
				linux_panel
				;;
			13)
				linux_system_tools
				;;
			14)
				echo "敬请期待"
				;;
			15)
				servertest_script
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
				palworld_script
				;;
			00)
				honeok_update
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