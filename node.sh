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

######################## Node Start ########################

check_node_installed() {
	# 检查 node 和 npm 是否存在
	if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
	local node_version
		node_version=$(node --version 2>&1)

		# 提取版本号（去掉前面的 'v' 字符）
		if [[ "$node_version" =~ v([0-9]+\.[0-9]+\.[0-9]+) ]]; then
			node_version="${BASH_REMATCH[1]}"
			printf "${yellow}Node.js已安装,版本为:${node_version}${white}\n"
			return 0
		else
			printf "${red}无法确定Node.js版本${white}\n"
			return 1
		fi
	else
		printf "${red}Node.js未安装,请执行安装程序${white}\n"
		return 1
	fi
}

install_node_version() {
	# 校验Node安装
	if ! check_node_installed >/dev/null 2>&1; then
		printf "${yellow}正在${os_release}上安装! ${white}\n"
	else
		printf "${red}Node已安装${white}\n"
		return # 返回Node菜单
	fi

	# 定义版本参数
	local version="$1"


	# 检查并安装依赖
	for package in wget curl; do
		if ! rpm -q $package >/dev/null 2>&1; then
			yum install $package -y >/dev/null 2>&1
			printf "${yellow}安装依赖:${package}${white}\n"
		fi
	done

	# 添加 NodeSource 的仓库
	curl -fsSL https://rpm.nodesource.com/setup_$VERSION.x | bash -

	# 安装 Node.js
	yum install nodejs -y

	# 验证安装
	check_node_installed
}

uninstall_node() {
  echo "卸载 Node.js..."

  # 卸载 Node.js
  yum remove -y nodejs

  # 移除 NodeSource 仓库
  rm -f /etc/yum.repos.d/nodesource.repo

  echo "Node.js 已卸载。"
}

# 提供Node版本选择菜单并调用install_mysql_version函数的MySQL安装总函数
mysql_version_selection_menu() {
	local choice

	while true; do
		clear
		printf "${cyan}=================================${white}\n"
		printf "${cyan}          选择Node版本           ${white}\n"
		printf "${cyan}=================================${white}\n"
		printf "${cyan}1. 安装MySQL 8.0.26${white}\n"
		printf "${cyan}2. 安装MySQL 8.0.28${white}\n"
		printf "${cyan}3. 安装MySQL 8.0.30${white}\n"
		printf "${cyan}4. 返回上一级菜单${white}\n"
		printf "${cyan}=================================${white}\n"

		# 读取用户选择
		printf "${cyan}请输入选项并按回车:${white}"
		read -r choice

		case "$choice" in
			1)
				install_mysql_version "8.0.26"
				;;
			2)
				install_mysql_version "8.0.28"
				;;
			3)
				install_mysql_version "8.0.30"
				;;
			4)
				printf "${yellow}返回上一级菜单${white}\n"
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

case $ACTION in
  install)
    install_node
    ;;
  uninstall)
    uninstall_node
    ;;
  *)
    show_help
    exit 1
    ;;
esac

