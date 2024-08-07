#!/bin/bash
# Author: honeok
# Blog: https://www.honeok.com

set -o errexit

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
	local service_name="$1"
	if command -v apk &>/dev/null; then
		rc-update add "$service_name" default
	else
		/bin/systemctl enable "$service_name"
	fi

	_green "$service_name已设置为开机自启"
}