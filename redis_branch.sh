#!/bin/bash

set -o errexit

# ANSI颜色码,用于彩色输出
yellow='\033[1;33m' # 提示信息
red='\033[1;31m'    # 警告信息
green='\033[1;32m'  # 成功信息
blue='\033[1;34m'   # 一般信息
cyan='\033[1;36m'   # 特殊信息
purple='\033[1;35m' # 紫色或粉色信息
gray='\033[1;30m'   # 灰色信息
white='\033[0m'     # 结束颜色设置

os_release=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d '"' -f 2 | sed 's/ (.*//')

# 安装路径和备份路径
SOFTWARE_DIR="/opt/software"
BACKUP_DIR="/opt/backup"

# 检查命令是否成功执行
check_command() {
	local message=$1
	if [ $? -ne 0 ]; then
		printf "${red}${message}${white}\n"
		return 1
	fi
}

# 创建安装目录(如果不存在)
create_software_dir() {
	if [ ! -d "$SOFTWARE_DIR" ]; then
		printf "${yellow}创建软件包下载路径:${SOFTWARE_DIR}${white}\n"
		mkdir -p "$SOFTWARE_DIR"
		check_command "创建路径失败"
		printf "${green}软件包下载路径:${SOFTWARE_DIR}创建成功!${white}\n"
	fi
}

################################### Redis Start ###################################
# 检查Redis是否已安装
check_redis_installed() {
	# 查找Redis配置文件,限制在指定目录下,匹配一些可能的配置文件名
	local redis_conf_path=""
	local redis_install_dir=""

	# 分别在 /etc/opt 和 /usr目录下查找Redis配置文件
	for dir in /etc /opt /usr; do
		if [ -d "$dir" ]; then
			redis_conf_path=$(find "$dir" -maxdepth 5 -type f \( -name '*redis.conf' -o -name '*redis*.conf' \) 2>/dev/null | head -n 1)
			if [ -n "$redis_conf_path" ]; then
				printf "${yellow}找到Redis配置文件:$redis_conf_path${white}\n"
				redis_install_dir=$(dirname "$redis_conf_path")
				break
			fi
		fi
	done
	
	# 检查 Redis 配置文件是否存在，认为 Redis 已安装
	if [ -n "$redis_conf_path" ]; then
		printf "${yellow}Redis配置文件已找到,Redis已安装${white}\n"
		return 0
	fi
	
	# 检查 Redis 进程是否在运行，认为 Redis 已安装
	if pgrep -f 'redis-server' >/dev/null 2>&1; then
		printf "${yellow}Redis服务器正在运行,Redis已安装${white}\n"
		return 0
	fi

	# 检查端口6379是否被Redis使用
	local redis_port_process
	redis_port_process=$(netstat -tuln | grep ':6379' | grep 'redis-server' 2>/dev/null)

	if [ -n "$redis_port_process" ]; then
		printf "${yellow}端口6379正在被Redis占用,Redis已安装${white}\n"
		return 0
	fi
	
	# 如果以上检查都没有确认Redis已安装,则返回未安装
	printf "${yellow}未检测到Redis安装${white}\n"
	return 1
}

manage_redis_systemd() {
	local redis_version="$1"
	local redis_dir="/opt/redis-${redis_version}"
	local redis_service_file="/etc/systemd/system/redis.service"

	# 检查Redis目录是否存在
	if [ ! -d "$redis_dir" ]; then
		printf "${red}Redis 安装目录不存在:${redis_dir}${white}\n"
		return 1
	fi

	# 创建 systemd 服务文件
	if [ ! -f "$redis_service_file" ]; then
		tee "$redis_service_file" > /dev/null <<EOF
[Unit]
Description=Redis In-Memory Data Store
After=network.target

[Service]
Type=forking
ExecStart=${redis_dir}/src/redis-server ${redis_dir}/redis.conf
ExecStop=${redis_dir}/src/redis-cli -h 127.0.0.1 -p 6379 shutdown
Restart=always

# User=redis
# Group=redis

[Install]
WantedBy=multi-user.target
EOF
		check_command "创建systemd服务文件失败:${redis_service_file}"
		printf "${green}创建systemd服务文件成功:${redis_service_file}${white}\n"
	else
		printf "${yellow}systemd服务文件已存在:${redis_service_file}${white}\n"
	fi

    # 重新加载systemd配置
    systemctl daemon-reload
    check_command "重载systemd配置失败"

    systemctl enable redis --now >/dev/null 2>&1

	# 检查Redis服务是否处于活动状态
	if ! systemctl is-active redis >/dev/null 2>&1; then
		printf "${red}Redis状态检查失败或服务无法启动,请检查安装日志或手动启动Redis服务${white}\n"
		return 1
	else
		printf "${green}Redis已完成自检,启动并设置开机自启${white}\n"
	fi

	echo ""

    systemctl status redis --no-pager

}

# 安装指定版本的Redis(该函数为redis_version_selection_menu函数的调用子函数)
install_redis_version() {
	# 校验软件包下载路径
	create_software_dir

	# 校验Redis安装
	if ! check_redis_installed >/dev/null 2>&1; then
		printf "${yellow}正在${os_release}上安装!${white}\n"
	else
		printf "${red}Redis已安装${white}\n"
		return # 返回redis菜单
	fi

	# 定义版本号和下载目录
	local version="$1"
	local redis_download_dir="$SOFTWARE_DIR/redis"
	local redis_url="http://download.redis.io/releases/redis-${version}.tar.gz"
	local redis_dir="/opt/redis-${version}"

	# 删除旧的下载目录(包括其中的所有文件)
	if [ -d "$redis_download_dir" ]; then
		rm -fr "$redis_download_dir"
		printf "${yellow}历史下载目录已删除:${redis_download_dir}${white}\n"
	fi

	# 创建新的下载目录
	mkdir -p "$redis_download_dir"
	check_command "目录创建失败:${redis_download_dir}"
	if [ $? -eq 0 ]; then
		printf "${green}软件安装目录创建成功:${redis_download_dir}${white}\n"
	fi

	# 检查并安装依赖
	for package in net-tools wget; do
		if ! rpm -q $package >/dev/null 2>&1; then
			yum install $package -y >/dev/null 2>&1
			printf "${yellow}安装并检查依赖:${package}${white}\n"
		fi
	done

	# 下载Redis软件包
	wget --progress=bar:force -P "$redis_download_dir" "$redis_url"
	check_command "下载Redis安装包失败"

	# 创建安装目录
	mkdir -p "$redis_dir"
	check_command "创建Redis安装目录失败:${redis_dir}"

	# 解压Redis软件包
	tar xvf "$redis_download_dir/redis-${version}.tar.gz" -C "$redis_dir" --strip-components=1
	check_command "解压Redis安装包失败"

	# 编译Redis
	cd "$redis_dir" || return
	make
	check_command "编译Redis失败"

	# 运行测试
	make test

	# 备份当前的配置文件
	\cp -f redis.conf redis.conf.bak

	# 修改redis.conf文件
	sed -i 's/^daemonize no/daemonize yes/' redis.conf

	# 删除安装包
	rm -f "$redis_download_dir/redis-${version}.tar.gz"

	# 管理 Redis systemd 服务
	manage_redis_systemd ${version}

	# 清理安装包文件和下载路径
	if [ -d "$redis_download_dir" ]; then
		rm -rf "$redis_download_dir"
		printf "${green}安装包目录已清空并删除:${redis_download_dir}${white}\n"
	else
		printf "${red}文件下载目录不存在,无需清理${white}\n"
	fi
}

# 提供Redis版本选择菜单并调用install_redis_version函数的Redis安装总函数
redis_version_selection_menu() {
	local choice

	while true; do
		clear
		printf "${cyan}=================================${white}\n"
		printf "${cyan}         选择Redis版本           ${white}\n"
		printf "${cyan}=================================${white}\n"
		printf "${cyan}1. 安装Redis 7.0.5${white}\n"
		printf "${cyan}2. 安装Redis 7.0.9${white}\n"
		printf "${cyan}3. 安装Redis 7.2.5${white}\n"
		printf "${cyan}4. 返回上一级菜单${white}\n"
		printf "${cyan}=================================${white}\n"

		# 读取用户选择
		printf "${cyan}请输入选项并按回车:${white}"
		read -r choice

		case "$choice" in
			1)
				install_redis_version "7.0.5"
				;;
			2)
				install_redis_version "7.0.9"
				;;
			3)
				install_redis_version "7.2.5"
				;;
			4)
				return
				;;
			*)
				printf "${red}无效选项,请重新输入${white}\n"
				;;
		esac
		# 等待用户按任意键继续
		printf "${cyan}按任意键继续${white}\n"
		read -n 1 -s -r
	done
}

# 控制Redis服务的状态
control_redis() {
	local start_redis
	# 启动 Redis
	start_redis() {
	echo "启动 Redis ..."
	cd ${REDIS_DIR}/src
	./redis-server ${REDIS_CONF}
	}

	local shutdown_redis
	# 关闭 Redis
	stop_redis() {
		echo "关闭 Redis ..."
		cd ${REDIS_DIR}/src
	./redis-cli shutdown
	}
}

# 管理 Make 安装的菜单
redis_menu() {
	local choice
	while true; do
		clear
		printf "${cyan}=================================${white}\n"
		printf "${cyan}          Redis管理菜单          ${white}\n"
		printf "${cyan}=================================${white}\n"
		printf "${cyan}1. 查看Redis服务${white}\n"
		printf "${cyan}2. 启动Redis服务${white}\n"
		printf "${cyan}3. 停止Redis服务${white}\n"
		printf "${cyan}4. 安装Redis服务${white}\n"
		printf "${cyan}5. 卸载Redis服务${white}\n"
		printf "${cyan}6. 返回主菜单${white}\n"
		printf "${cyan}=================================${white}\n"

		printf "${cyan}请输入选项并按回车:${white}"
		read -r choice

		case "$choice" in
			1)
				control_redis status
				;;
			2)
				control_redis start
				;;
			3)
				control_redis stop
				;;
			4)
				redis_version_selection_menu
				;;
			5)
				echo "redis_uninstall"
				;;
			6)
				printf "${yellow}返回主菜单${white}\n"
				#return
				exit
				;;
			*)
				printf "${red}无效选项, 重新选择!${white}\n"
				;;
		esac
		printf "${cyan}按任意键继续${white}\n"
		read -n 1 -s -r
	done
}
################################### Redis END ###################################

redis_menu