#!/bin/bash
# Author: honeok
# Blog: https://www.honeok.com

#set -o errexit

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
		linux_panel
	fi
}

# 获取公网IP地址
ip_address() {
	local ipv4_services=("ipv4.ip.sb" "api.ipify.org" "checkip.amazonaws.com" "ipinfo.io/ip")
	local ipv6_services=("ipv6.ip.sb" "api6.ipify.org" "v6.ident.me" "ipv6.icanhazip.com")

	# 获取IPv4地址
	for service in "${ipv4_services[@]}"; do
		ipv4_address=$(curl -s "$service")
		if [[ $ipv4_address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
			break
		fi
	done

	# 获取IPv6地址
	for service in "${ipv6_services[@]}"; do
		ipv6_address=$(curl -s --max-time 1 "$service")
		if [[ $ipv6_address =~ ^[0-9a-fA-F:]+$ ]]; then
			break
		else
			ipv6_address=""
		fi
	done
}
#################### 通用函数END ####################

manage_compose() {
	local compose_cmd
	# 检查docker compose版本
	if docker compose version >/dev/null 2>&1; then
		compose_cmd="docker compose"
	elif command -v docker-compose >/dev/null 2>&1; then
		compose_cmd="docker-compose"
	fi

	case "$1" in
		start)	# 启动容器
			$compose_cmd up -d
			;;
		restart)
			$compose_cmd restart
			;;
		stop)	# 停止容器
			$compose_cmd stop
			;;
		recreate)
			$compose_cmd up -d --force-recreate
			;;
		down)	# 停止并删除容器
			$compose_cmd down
			;;
		pull)
			$compose_cmd pull
			;;
		down_all) # 停止并删除容器,镜像,卷,未使用的网络
			$compose_cmd down --rmi all --volumes --remove-orphans
			;;
		version)
			$compose_cmd version
			;;
	esac
}


check_network_protocols() {
	ip_address
	has_ipv4=false
	has_ipv6=false

	[ -n "$ipv4_address" ] && has_ipv4=true
	[ -n "$ipv6_address" ] && has_ipv6=true
}

display_docker_access() {
	echo "------------------------"
	echo "访问地址:"
	$has_ipv4 && echo "http://$ipv4_address:$docker_port_1"
	$has_ipv6 && echo "http://[$ipv6_address]:$docker_port_1"
}

check_docker_status() {
	if docker inspect "$docker_name" &>/dev/null; then
		check_docker="${green}已安装${white}"
	else
		check_docker="${yellow}未安装${white}"
	fi
}

manage_docker_application() {
	local choice
	check_network_protocols
	while true; do
		clear
		check_docker_status
		echo -e "$docker_name $check_docker"
		echo "$docker_describe"
		echo "$docker_url"

		# 获取并显示当前端口
		if docker inspect "$docker_name" &>/dev/null; then
			display_docker_access
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
				#install_docker
				[ ! -d "$docker_workdir" ] && mkdir -p "$docker_workdir"
				cd "$docker_workdir" || { _red "无法进入目录$docker_workdir"; return 1; }

				# 判断$docker_port_1是否已硬性赋值
				if [ -n "$docker_port_1" ]; then
					echo "$docker_compose_content" > docker-compose.yml
				else		
					# 检查端口,如冲突则使用动态端口
					check_available_port
					# 构建sed命令生成compose文件
					sed_commands="s/\$default_port_1/$docker_port_1/g;"
					if [ -n "$docker_port_2" ]; then
						sed_commands+="s/\$default_port_2/$docker_port_2/g;"
					fi
					if [ -n "$docker_port_3" ]; then
						sed_commands+="s/\$default_port_3/$docker_port_3/g;"
					fi
					echo "$docker_compose_content" | sed "$sed_commands" > docker-compose.yml
				fi

				manage_compose start
				clear
				_green "${docker_name}安装完成"
				display_docker_access
				echo ""
				$docker_exec_command
				$docker_password
				;;
			2)
				cd "$docker_workdir" || { _red "无法进入目录$docker_workdir"; return 1; }
				manage_compose pull && manage_compose start

				clear
				_green "$docker_name更新完成"
				display_docker_access
				echo ""
				$docker_exec_command
				$docker_password
				;;
			3)
				cd "$docker_workdir" || { _red "无法进入目录$docker_workdir"; return 1; }

				vim docker-compose.yml
				manage_compose start

				if [ $? -eq 0 ]; then
					_green "$docker_name重启成功"
				else
					_red "$docker_name重启失败"
				fi
				;;
			4)
				cd "$docker_workdir" || { _red "无法进入目录$docker_workdir"; return 1; }
				manage_compose down_all
				[ -d "$docker_workdir" ] && rm -fr "${docker_workdir}"
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
				docker_port_1=81

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

				docker_exec_command="echo 初始用户名: admin@example.com"
				docker_password="echo 初始密码: changeme"
				manage_docker_application
				;;
			5)
				docker_name="alist"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="一个支持多种存储,支持网页浏览和WebDAV的文件列表程序,由gin和Solidjs驱动"
				docker_url="官网介绍: https://alist.nn.ci/zh/"
				default_port_1=5244
				docker_compose_content=$(curl -sS https://raw.githubusercontent.com/honeok8s/conf/main/docker_app/alist-docker-compose.yml)
				docker_exec_command="docker exec -it alist ./alist admin random"
				docker_password=""
				manage_docker_application
				;;
			6)
				docker_name="webtop-ubuntu"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="webtop基于Ubuntu的容器,包含官方支持的完整桌面环境,可通过任何现代Web浏览器访问"
				docker_url="官网介绍: https://docs.linuxserver.io/images/docker-webtop/"
				default_port_1=3000
				docker_compose_content=$(curl -sS https://raw.githubusercontent.com/honeok8s/conf/main/docker_app/webtop-ubuntu-docker-compose.yml)
				docker_exec_command=""
				docker_password=""
				manage_docker_application
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
				docker_compose_content=$(curl -sS https://raw.githubusercontent.com/honeok8s/conf/main/docker_app/qbittorrent-docker-compose.yml)
				docker_exec_command="sleep 3"
				docker_password="docker logs qbittorrent"
				manage_docker_application
				;;
			11)
				docker_name="zentao-server"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="禅道是通用的项目管理软件"
				docker_url="官网介绍: https://www.zentao.net/"
				default_port_1=8080
				default_port_2=3306
				docker_compose_content=$(curl -sS https://raw.githubusercontent.com/honeok8s/conf/main/docker_app/zentao-server-docker-compose.yml)
				docker_exec_command="echo 初始用户名: admin"
				docker_password="echo 初始密码: 123456"
				manage_docker_application
				;;
			12)
				docker_name="qinglong"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="青龙面板是一个定时任务管理平台"
				docker_url="官网介绍: https://github.com/whyour/qinglong"
				default_port_1=5700
				docker_compose_content=$(curl -sS https://raw.githubusercontent.com/honeok8s/conf/main/docker_app/qinglong-docker-compose.yml)
				docker_exec_command=""
				docker_password=""
				manage_docker_application
				;;
			14)
				docker_name="easyimage"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="简单图床是一个简单的图床程序"
				docker_url="官网介绍: https://github.com/icret/EasyImages2.0"
				default_port_1=8080
				docker_compose_content=$(curl -sS https://raw.githubusercontent.com/honeok8s/conf/main/docker_app/easyimage-docker-compose.yml)
				docker_exec_command=""
				docker_password=""
				manage_docker_application
				;;
			15)
				docker_name="emby"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="emby是一个主从式架构的媒体服务器软件,可以用来整理服务器上的视频和音频,并将音频和视频流式传输到客户端设备"
				docker_url="官网介绍: https://emby.media/"
				default_port_1=8096
				default_port_2=8920
				docker_compose_content=$(curl -sS https://raw.githubusercontent.com/honeok8s/conf/main/docker_app/emby-docker-compose.yml)
				docker_exec_command=""
				docker_password=""
				manage_docker_application
				;;
			16)
				docker_name="looking-glass"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="Speedtest测速面板是一个VPS网速测试工具,多项测试功能,还可以实时监控VPS进出站流量"
				docker_url="官网介绍: https://github.com/wikihost-opensource/als"
				default_port_1=8080
				default_port_2=30000
				docker_compose_content=$(curl -sS https://raw.githubusercontent.com/honeok8s/conf/main/docker_app/looking-glass-docker-compose.yml)
				docker_exec_command=""
				docker_password=""
				manage_docker_application
				;;
			17)
				docker_name="adguardhome"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="AdGuardHome是一款全网广告拦截与反跟踪软件,未来将不止是一个DNS服务器"
				docker_url="官网介绍: https://hub.docker.com/r/adguard/adguardhome"
				default_port_1=3000
				docker_compose_content=$(curl -sS https://raw.githubusercontent.com/honeok8s/conf/main/docker_app/adguardhome-docker-compose.yml)
				docker_exec_command=""
				docker_password=""
				manage_docker_application
				;;
			18)
				docker_name="onlyoffice"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="onlyoffice是一款开源的在线office工具,太强大了!"
				docker_url="官网介绍: https://www.onlyoffice.com/"
				default_port_1=8080
				docker_compose_content=$(curl -sS https://raw.githubusercontent.com/honeok8s/conf/main/docker_app/onlyoffice-docker-compose.yml)
				docker_exec_command=""
				docker_password=""
				manage_docker_application
				;;
			19)
				check_network_protocols
				docker_name="safeline-mgt"
				docker_port_1=9443
				while true; do
					check_docker_status
					clear
					echo -e "雷池服务 $check_docker"
					echo "雷池是长亭科技开发的WAF站点防火墙程序面板,可以反代站点进行自动化防御"

					if docker inspect "$docker_name" &>/dev/null; then
						display_docker_access
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
							#install_docker
							bash -c "$(curl -fsSLk https://waf-ce.chaitin.cn/release/latest/setup.sh)"
							clear
							_green "雷池WAF面板已经安装完成"
							display_docker_access
							docker exec safeline-mgt resetadmin
							;;
						2)
							bash -c "$(curl -fsSLk https://waf-ce.chaitin.cn/release/latest/upgrade.sh)"
							docker rmi $(docker images | grep "safeline" | grep "none" | awk '{print $3}')
							echo ""
							clear
							_green "雷池WAF面板已经更新完成"
							display_docker_access
							;;
						3)
							docker exec safeline-mgt resetadmin
							;;
						4)
							cd /data/safeline
							manage_compose down_all
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
				docker_compose_content=$(curl -sS https://raw.githubusercontent.com/honeok8s/conf/main/docker_app/portainer-docker-compose.yml)
				docker_exec_command=""
				docker_password=""
				manage_docker_application
				;;
			21)
				docker_name="vscode-web"
				docker_workdir="/data/docker_data/$docker_name"
				docker_describe="VScode是一款强大的在线代码编写工具"
				docker_url="官网介绍: https://github.com/coder/code-server"
				default_port_1=8080
				docker_compose_content=$(curl -sS https://raw.githubusercontent.com/honeok8s/conf/main/docker_app/vscode-web-docker-compose.yml)
				docker_exec_command="sleep 3"
				docker_password="docker exec vscode-web cat /home/coder/.config/code-server/config.yaml"
				manage_docker_application
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
				#install_docker
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
linux_panel