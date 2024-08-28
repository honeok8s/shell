#!/bin/bash
# Author: honeok
# Blog: www.honeok.com

clear

gitdocker_version="2024.8.28 v2.0"
os_release=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')

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

print_getdocker_logo() {
cat << 'EOF'
   ______     __         __           __            
  / _______  / /_   ____/ ____  _____/ /_____  _____
 / / __/ _ \/ __/  / __  / __ \/ ___/ //_/ _ \/ ___/
/ /_/ /  __/ /_   / /_/ / /_/ / /__/ ,< /  __/ /    
\____/\___/\__/   \__,_/\____/\___/_/|_|\___/_/     
                                                    
EOF

	_yellow "Author: honeok"
	_blue "Version: $gitdocker_version"
	_purple "Project: https://github.com/honeok8s"
}

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
	if command -v apk &>/dev/null; then
		service "$service_name" start
	else
		systemctl start "$service_name"
	fi
	if [ $? -eq 0 ]; then
		_green "$service_name已启动"
	else
		_red "$service_name启动失败"
	fi
}

# 检查用户是否为root
need_root(){
	clear
	if [ "$(id -u)" -ne "0" ]; then
		_red "该脚本需要root用户才能运行"
		exit 0
	fi
}

# 获取公网IP地址
ip_address() {
	local ipv4_services=("ipv4.ip.sb" "api.ipify.org" "checkip.amazonaws.com" "ipinfo.io/ip")
	local ipv6_services=("ipv6.ip.sb" "api6.ipify.org" "v6.ident.me" "ipv6.icanhazip.com")
	local isp_info=$(curl -s https://ipinfo.io | grep '"org":' | awk -F'"' '{print $4}')
	local location=$(curl -s ipinfo.io/city)

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

	_yellow "公网IPv4地址: ${ipv4_address}"
	if [ -n "$ipv6_address" ];then
		_yellow "公网IPv6地址: ${ipv6_address}"
	fi
	_yellow "运营商: ${isp_info}"
	_yellow "地理位置: ${location}"
}

#################### 通用函数END ####################

#################### Docker START ####################

# 检查Docker或Docker Compose是否已安装
check_docker_install() {
	if ! command -v docker >/dev/null 2>&1; then
		install_docker
	else
		_red "Docker已安装,正在退出安装程序"
		exit 0
	fi
}

install_docker() {
	local repo_url=""
	local gpg_key_url=""
	local codename="$(lsb_release -cs)"
	local os_name="$(lsb_release -si)"

	if [ ! -f "/etc/alpine-release" ]; then
		_yellow "正在安装docker"
	fi

	install_common_docker() {
		generate_docker_config
		docker_main_version
	}

	if command -v dnf &>/dev/null; then
		if ! dnf config-manager --help >/dev/null 2>&1; then
			install dnf-plugins-core
		fi

		[ -f /etc/yum.repos.d/docker*.repo ] && rm -f /etc/yum.repos.d/docker*.repo > /dev/null

		if [[ "$(curl -s --connect-timeout 5 ipinfo.io/country)" == "CN" ]]; then
			dnf config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo > /dev/null
		else
			dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null
		fi

		install docker-ce docker-ce-cli containerd.io
		enable docker
		start docker
		install_common_docker
	elif command -v apt &>/dev/null; then
		if [[ "$(curl -s --connect-timeout 5 ipinfo.io/country)" == "CN" ]]; then
			repo_url="https://mirrors.aliyun.com/docker-ce/linux/${os_name,,}"
			gpg_key_url="https://mirrors.aliyun.com/docker-ce/linux/${os_name,,}/gpg"
		else
			repo_url="https://download.docker.com/linux/${os_name,,}"
			gpg_key_url="https://download.docker.com/linux/${os_name,,}/gpg"
		fi

		apt install sudo >/dev/null 2>&1
		for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
			remove $pkg >/dev/null 2>&1
		done
		install apt-transport-https ca-certificates curl gnupg lsb-release
		/usr/bin/install -m 0755 -d /etc/apt/keyrings
		curl -fsSL \"$gpg_key_url\" -o /etc/apt/keyrings/docker.asc >/dev/null 2>&1
		chmod a+r /etc/apt/keyrings/docker.asc >/dev/null 2>&1
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] $repo_url $codename stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

		install docker-ce docker-ce-cli containerd.io
		enable docker
		start docker
		install_common_docker
	elif command -v yum &>/dev/null; then
		if [[ "$(curl -s --connect-timeout 5 ipinfo.io/country)" == "CN" ]]; then
			repo_url="http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo"
		else
			repo_url="https://download.docker.com/linux/centos/docker-ce.repo"
		fi
		remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine >/dev/null 2>&1
		install yum-utils
		yum-config-manager --add-repo \"$repo_url\" && yum makecache fast

		install docker-ce docker-ce-cli containerd.io
		enable docker
		start docker
		install_common_docker
	else
		install docker docker-compose
		enable docker
		start docker
		install_common_docker
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

	_yellow "已安装Docker版本: v$docker_version"
	_yellow "已安装Docker Compose版本: $docker_compose_version"

	_yellow "正在获取Docker信息"
	sleep 2s
	docker version

	# intentionally mixed spaces and tabs here -- tabs are stripped by "<<-EOF", spaces are kept in the output
	echo
	echo "================================================================================"
 	echo
	echo "To run Docker as a non-privileged user, consider setting up the"
	echo "Docker daemon in rootless mode for your user:"
	echo
	echo "    dockerd-rootless-setuptool.sh install"
	echo
	echo "Visit https://docs.docker.com/go/rootless/ to learn about rootless mode."
	echo
	echo
	echo "To run the Docker daemon as a fully privileged service, but granting non-root"
	echo "users access, refer to https://docs.docker.com/go/daemon-access/"
	echo
	echo "WARNING: Access to the remote API on a privileged Docker daemon is equivalent"
	echo "         to root access on the host. Refer to the 'Docker daemon attack surface'"
	echo "         documentation for details: https://docs.docker.com/go/attack-surface/"
	echo
	echo "================================================================================"
 	echo
}

# Docker调优
generate_docker_config() {
	local config_file="/etc/docker/daemon.json"
	local config_dir="$(dirname "$config_file")"
	local registry_url="https://raw.githubusercontent.com/honeok8s/conf/main/docker/registry_mirrors.txt"
	local is_china_server='false'
	local cgroup_driver

	if ! command -v docker &> /dev/null; then
		_red "Docker未安装在系统上,无法优化"
		return 1
	fi

	if [ -f "$config_file" ]; then
		# 如果文件存在,检查是否已经优化过
		if grep -q '"default-shm-size": "128M"' "$config_file"; then
			_yellow "Docker配置文件已经优化,无需再次优化"
			return 0
		fi
	fi

	# 创建配置目录(如果不存在)
	if [ ! -d "$config_dir" ]; then
		mkdir -p "$config_dir"
	fi

	# 创建配置文件的基础配置(如果文件不存在)
	if [ ! -f "$config_file" ]; then
		echo "{}" > "$config_file"
	fi

	install python3

	# 检查服务器是否在中国
	if [[ "$(curl -s --connect-timeout 5 ipinfo.io/country)" == "CN" ]]; then
		is_china_server='true'
	fi

	# 获取 registry mirrors 内容
	registry_mirrors=$(curl -s "$registry_url" | grep -v '^#' | sed '/^$/d')

	# 判断操作系统是否为 Alpine
	if grep -q 'Alpine' /etc/issue; then
		cgroup_driver="native.cgroupdriver=cgroupfs"
	else
		cgroup_driver="native.cgroupdriver=systemd"
	fi

	# Python脚本
	python3 - <<EOF
import json

registry_mirrors = """$registry_mirrors""".splitlines()
cgroup_driver = "$cgroup_driver"

base_config = {
    "exec-opts": [
        cgroup_driver
    ],
    "max-concurrent-downloads": 10,
    "max-concurrent-uploads": 5,
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "30m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "default-shm-size": "128M",
    "debug": False,
    "ipv6": False
}

# 如果是中国服务器,将registry-mirrors放在前面
if "$is_china_server" == "true" and registry_mirrors:
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

# 卸载Docker
uninstall_docker() {
	local os_name
	local docker_data_files=("/var/lib/docker" "/var/lib/containerd" "/etc/docker" "/opt/containerd" "/data/docker_data")
	local docker_depend_files=("/etc/yum.repos.d/docker*" "/etc/apt/sources.list.d/docker.*" "/etc/apt/keyrings/docker.*" "/var/log/docker.*")
	local binary_files=("/usr/bin/docker" "/usr/bin/docker-compose")  # 删除二进制文件路径

	need_root

	# 停止并删除Docker服务和容器
	stop_and_remove_docker() {
		local running_containers=$(docker ps -aq)
		[ -n "$running_containers" ] && docker rm -f "$running_containers" >/dev/null 2>&1
		stop docker >/dev/null 2>&1
		disable docker >/dev/null 2>&1
	}

	# 移除Docker文件和仓库文件
	cleanup_files() {
		for pattern in "${docker_depend_files[@]}"; do
			for file in $pattern; do
				[ -e "$file" ] && rm -fr "$file" >/dev/null 2>&1
			done
		done

		for file in "${docker_data_files[@]}" "${binary_files[@]}"; do
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
		ubuntu|debian|centos|rhel|almalinux|rocky|fedora)
			remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
			;;
		alpine)
			remove docker docker-compose
			;;
		*)
			_red "此脚本不支持您的Linux发行版"
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

# 退出脚本前显示执行完成信息
script_completion_message() {
	local timezone=$(timedatectl | awk '/Time zone/ {print $3}')
	local current_time=$(date '+%Y-%m-%d %H:%M:%S')

	printf "${green}服务器当前时间: ${current_time} 时区: ${timezone} 脚本执行完成${white}\n"

	_purple "感谢使用本脚本!如有疑问,请访问honeok.com获取更多信息"
}

# 参数检查
if [ -n "$1" ] && [ "$1" != "uninstall" ]; then
	print_getdocker_logo
	_red "无效参数! (可选: 没有参数/uninstall)"
	script_completion_message
	exit 1
fi

if [ -n "$2" ]; then
	print_getdocker_logo
	_red "只能提供一个参数 (可选: uninstall)"
	script_completion_message
	exit 1
fi

# 检查操作系统是否受支持
case "$os_release" in
	ubuntu|debian|centos|rhel|almalinux|rocky|fedora|alpine)
		_yellow "检测到本脚本支持的Linux发行版: $os_release"
		;;
	*)
		_red "此脚本不支持的Linux发行版: $os_release"
		exit 1
		;;
esac

# 开始脚本
main(){
	need_root
	print_getdocker_logo

	if [ "$1" == "uninstall" ]; then
		uninstall_docker
		script_completion_message
		exit 0
	fi

	# 获取IP地址
	ip_address

	# 检查操作系统兼容性并执行安装或卸载
	case "$os_release" in
		ubuntu|debian|centos|rhel|almalinux|rocky|fedora|alpine)
			check_docker_install
			;;
		*)
			_red "使用方法: ./get_docker.sh [uninstall]"
			exit 1
			;;
	esac

	# 完成脚本
	script_completion_message
}

main "$@"
exit 0