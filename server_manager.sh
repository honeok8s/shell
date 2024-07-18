#!/bin/bash

set -o errexit
clear

os_release=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d '"' -f 2 | sed 's/ (.*//')

# ANSI颜色码,用于彩色输出
yellow='\033[1;33m' # 提示信息
red='\033[1;31m'    # 警告信息
green='\033[1;32m'  # 成功信息
blue='\033[1;34m'   # 一般信息
cyan='\033[1;36m'   # 特殊信息
purple='\033[1;35m' # 紫色或粉色信息
gray='\033[1;30m'   # 灰色信息
white='\033[0m'     # 结束颜色设置

download_dir="/opt/software"

check_download_dir(){
	[ ! -d $download_dir ] && mkdir $download_dir -p || true
}

mysql_install() {
	check_download_dir

	printf "${yellow}在${os_release}上安装! ${white}\n"

	cd "$download_dir" || exit 1

	# 检查临时文件夹权限,由于mysql安装中会通过mysql用户在/tmp目录下新建tmp_db文件,所以给/tmp较大权限
	if [ "$(stat -c '%A' /tmp)" != "drwxrwxrwt" ]; then
		chmod -R 777 /tmp
		printf "${yellow}已更新/tmp目录权限为777${white}\n"
	fi

	# 检查并卸载冲突的包
	for package in mariadb-libs mysql-libs; do
		if rpm -q $package >/dev/null 2>&1; then
			yum remove $package -y >/dev/null 2>&1
			printf "${yellow} 正在卸载冲突文件${package}${white}\n"
		fi
	done

	# 检查并安装依赖
	for package in libaio net-tools; do
		if ! rpm -q $package >/dev/null 2>&1; then
			yum install $package -y >/dev/null 2>&1
			printf "${yellow} 安装并检查依赖${package}${white}\n"
		fi
	done

	# 下载 MySQL
	wget --progress=bar:force -P $download_dir https://downloads.mysql.com/archives/get/p/23/file/mysql-8.0.26-1.el7.x86_64.rpm-bundle.tar
	printf "${yellow}正在解压MySQL并执行安装.${white}\n"
	tar xvf mysql-8.0.26-1.el7.x86_64.rpm-bundle.tar
	rm -f mysql-8.0.26-1.el7.x86_64.rpm-bundle.tar

	# 安装MySQL,必须安装顺序执行
	for package in \
		mysql-community-common-8.0.26-1.el7.x86_64.rpm \
		mysql-community-client-plugins-8.0.26-1.el7.x86_64.rpm \
		mysql-community-libs-8.0.26-1.el7.x86_64.rpm \
		mysql-community-client-8.0.26-1.el7.x86_64.rpm \
		mysql-community-server-8.0.26-1.el7.x86_64.rpm; do
		if ! yum localinstall "$package" -y >/dev/null 2>&1; then
			printf "${red}安装失败: ${package}${white}\n"
			exit 1
		fi
		printf "${green}安装成功: ${package}${white}\n"
	done

	# 验证安装
	printf "${yellow}验证 MySQL 安装${white}\n"
	if mysql --version >/dev/null 2>&1 && mysqladmin --version >/dev/null 2>&1; then
		printf "${green}MySQL安装成功,MySQL 版本: $(mysql --version)${white}\n"
	else
		printf "${red}MySQL安装失败,未找到相关版本信息.${white}\n"
		exit 1
	fi

	# 清理安装包文件
	rm -f mysql-community*

	# MySQL初始化
	echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '1xBSKI7#*6QRdv';" > /tmp/mysql-init
	mysqld --initialize --user=mysql --init-file=/tmp/mysql-init
	rm -f /tmp/mysql-init
	printf "${green}通过指定配置文件初始化MySQL成功${white}\n"
}

mysql_uninstall() {
	local MAXDEPTH=5

	sudo systemctl is-active mysqld >/dev/null 2>&1 && sudo systemctl stop mysqld >/dev/null 2>&1

	# 遍历并卸载每个已安装的 MySQL 包
	for package in $(rpm -qa | grep -iE '^mysql-community-'); do
		if yum remove "$package" -y; then
			printf "${green}成功卸载: $package${white}\n"
		else
			printf "${red}卸载失败: $package${white}\n"
		fi
	done

	# 查找并删除与MySQL相关的文件夹
	find / -maxdepth $MAXDEPTH -type d -name '*mysql*' 2>/dev/null | xargs rm -rf

	[ -f /etc/my.cnf ] && rm -f /etc/my.cnf

}

##########
# 主菜单函数
main_menu() {
	while true; do
		clear
		printf "${cyan}=== 服务器管理菜单 ===${white}\n"
		printf "${cyan}1. MySQL管理${white}\n"
		printf "${cyan}2. 退出${white}\n"

		printf "${cyan}请输入选项数字并按Enter键: ${white}"
		read choice

		case $choice in
			1)
				mysql_menu
				;;
			2)
				printf "${yellow}退出菜单${white}\n"
				break  # 退出主菜单循环
				;;
			*)
				printf "${red}无效选项,请重新输入${white}\n"
				;;
		esac
		printf "${cyan}按任意键继续.${white}"
		read -n 1 -s -r -p ""
	done
}

# MySQL子菜单
mysql_menu() {
    while true; do
		clear
		printf "${cyan}=== MySQL 操作 ===${white}\n"
		printf "${cyan}1. 安装MySQL服务${white}\n"
		printf "${cyan}2. 卸载MySQL服务${white}\n"
		printf "${cyan}3. 返回主菜单.${white}\n"

		printf "${cyan}请输入选项数字并按Enter键: ${white}"
		read choice

		case $choice in
			1)
				mysql_install
				;;
			2)
				mysql_uninstall
				;;
			3)
				printf "${yellow}返回主菜单.${white}\n"
				return  # 返回主菜单循环
				;;
			*)
				printf "${red}无效选项,请重新输入${white}\n"
				;;
		esac
		printf "${cyan}按任意键继续.${white}"
		read -n 1 -s -r -p ""
	done
}

if [[ $EUID -ne 0 ]]; then
	printf "${red}此脚本必须以root用户身份运行. ${white}\n"
	exit 1
fi

main_menu
exit 0