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

###############################################################

break_end() {
      echo -e "${green}操作完成${white}"
      echo "按任意键继续..."
      read -n 1 -s -r -p ""
      echo ""
      clear
}

root_use() {
clear
[ "$EUID" -ne 0 ] && echo -e "${yellow}提示: ${white}该功能需要root用户才能运行！" && break_end && linux_ldnmp
}

ldnmp_install_status_one() {

   if docker inspect "php" &>/dev/null; then
    echo "无法再次安装LDNMP环境"
    echo -e "${yellow}提示: ${white}LDNMP环境已安装。无法再次安装。可以使用37. 更新LDNMP环境。"
    break_end
    linux_ldnmp
   else
    :
   fi

}

check_port() {

    docker rm -f nginx >/dev/null 2>&1

    # 定义要检测的端口
    PORT=80

    # 检查端口占用情况
    result=$(ss -tulpn | grep ":\b$PORT\b")

    # 判断结果并输出相应信息
    if [ -n "$result" ]; then
            clear
            echo -e "${red}注意: ${white}端口 ${yellow}$PORT${white} 已被占用，无法安装环境，卸载以下程序后重试！"
            echo "$result"
            echo "端口冲突无法安装建站环境"
            break_end
            linux_ldnmp

    fi
}

install_dependency() {
      clear
      install wget socat unzip tar
}

install_certbot() {

    install certbot

    cd ~

    # 下载并使脚本可执行
    curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/auto_cert_renewal.sh
    chmod +x auto_cert_renewal.sh

    # 设置定时任务字符串
    check_crontab_installed
    cron_job="0 0 * * * ~/auto_cert_renewal.sh"

    # 检查是否存在相同的定时任务
    existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")

    # 如果不存在，则添加定时任务
    if [ -z "$existing_cron" ]; then
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        echo "续签任务已添加"
    fi
}

default_server_ssl() {
install openssl

if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout /home/web/certs/default_server.key -out /home/web/certs/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
else
    openssl genpkey -algorithm Ed25519 -out /home/web/certs/default_server.key
    openssl req -x509 -key /home/web/certs/default_server.key -out /home/web/certs/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
fi


}

install_ldnmp() {

      #check_swap
      cd /home/web && docker compose up -d
      clear
      echo "正在配置LDNMP环境，请耐心稍等……"

      # 定义要执行的命令
      commands=(
          "docker exec nginx chmod -R 777 /var/www/html"
          "docker restart nginx > /dev/null 2>&1"

          # "docker exec php sed -i "s/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g" /etc/apk/repositories > /dev/null 2>&1"
          # "docker exec php74 sed -i "s/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g" /etc/apk/repositories > /dev/null 2>&1"

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
          echo -ne "\r[${green}$percentage%${white}] $progressBar"
      done

      echo  # 打印换行，以便输出不被覆盖


      clear
      echo "LDNMP环境安装完毕"
      echo "------------------------"
      ldnmp_version

}

ldnmp_version() {

      # 获取nginx版本
      nginx_version=$(docker exec nginx nginx -v 2>&1)
      nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
      echo -n -e "nginx : ${yellow}v$nginx_version${white}"

      # 获取mysql版本
      dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
      mysql_version=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SELECT VERSION();" 2>/dev/null | tail -n 1)
      echo -n -e "            mysql : ${yellow}v$mysql_version${white}"

      # 获取php版本
      php_version=$(docker exec php php -v 2>/dev/null | grep -oP "PHP \K[0-9]+\.[0-9]+\.[0-9]+")
      echo -n -e "            php : ${yellow}v$php_version${white}"

      # 获取redis版本
      redis_version=$(docker exec redis redis-server -v 2>&1 | grep -oP "v=+\K[0-9]+\.[0-9]+")
      echo -e "            redis : ${yellow}v$redis_version${white}"

      echo "------------------------"
      echo ""

}

ldnmp_install_status() {

   if docker inspect "php" &>/dev/null; then
    echo "LDNMP环境已安装，开始部署 $webname"
   else
    send_stats "请先安装LDNMP环境"
    echo -e "${gl_huang}提示: ${gl_bai}LDNMP环境未安装，请先安装LDNMP环境，再部署网站"
    break_end
    linux_ldnmp

   fi

}

add_yuming() {
      ip_address
      echo -e "先将域名解析到本机IP: ${gl_huang}$ipv4_address  $ipv6_address${gl_bai}"
      read -p "请输入你解析的域名: " yuming
      repeat_add_yuming

}

ip_address() {
ipv4_address=$(curl -s ipv4.ip.sb)
ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb)
}

install_ssltls() {
      docker stop nginx > /dev/null 2>&1
      iptables_open > /dev/null 2>&1
      cd ~

      yes | certbot delete --cert-name $yuming > /dev/null 2>&1

      certbot_version=$(certbot --version 2>&1 | grep -oP "\d+\.\d+\.\d+")

      version_ge() {
          [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$1" ]
      }

      if version_ge "$certbot_version" "1.17.0"; then
          certbot certonly --standalone -d $yuming --email your@email.com --agree-tos --no-eff-email --force-renewal --key-type ecdsa
      else
          certbot certonly --standalone -d $yuming --email your@email.com --agree-tos --no-eff-email --force-renewal
      fi

      cp /etc/letsencrypt/live/$yuming/fullchain.pem /home/web/certs/${yuming}_cert.pem > /dev/null 2>&1
      cp /etc/letsencrypt/live/$yuming/privkey.pem /home/web/certs/${yuming}_key.pem > /dev/null 2>&1
      docker start nginx > /dev/null 2>&1
}

certs_status() {

    sleep 1
    file_path="/etc/letsencrypt/live/$yuming/fullchain.pem"
    if [ -f "$file_path" ]; then
        send_stats "域名证书申请成功"
    else
        send_stats "域名证书申请失败"
        echo -e "${gl_hong}注意: ${gl_bai}检测到域名证书申请失败，请检测域名是否正确解析或更换域名重新尝试！"
        break_end
        linux_ldnmp
    fi

}

add_db() {
      dbname=$(echo "$yuming" | sed -e 's/[^A-Za-z0-9]/_/g')
      dbname="${dbname}"

      dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
      dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
      dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
      docker exec mysql mysql -u root -p"$dbrootpasswd" -e "CREATE DATABASE $dbname; GRANT ALL PRIVILEGES ON $dbname.* TO \"$dbuse\"@\"%\";"
}

#####################################
linux_ldnmp() {

  while true; do
    clear
    # echo "LDNMP建站"
    echo -e "${yellow}▶ LDNMP建站"
    echo -e "${yellow}------------------------"
    echo -e "${yellow}1.   ${white}安装LDNMP环境 ${yellow}★${white}"
    echo -e "${yellow}2.   ${white}安装WordPress ${yellow}★${white}"
    echo -e "${yellow}3.   ${white}安装Discuz论坛"
    echo -e "${yellow}4.   ${white}安装可道云桌面"
    echo -e "${yellow}5.   ${white}安装苹果CMS网站"
    echo -e "${yellow}6.   ${white}安装独角数发卡网"
    echo -e "${yellow}7.   ${white}安装flarum论坛网站"
    echo -e "${yellow}8.   ${white}安装typecho轻量博客网站"
    echo -e "${yellow}20.  ${white}自定义动态站点"
    echo -e "${yellow}------------------------"
    echo -e "${yellow}21.  ${white}仅安装nginx ${yellow}★${white}"
    echo -e "${yellow}22.  ${white}站点重定向"
    echo -e "${yellow}23.  ${white}站点反向代理-IP+端口 ${yellow}★${white}"
    echo -e "${yellow}24.  ${white}站点反向代理-域名"
    echo -e "${yellow}25.  ${white}自定义静态站点"
    echo -e "${yellow}26.  ${white}安装Bitwarden密码管理平台"
    echo -e "${yellow}27.  ${white}安装Halo博客网站"
    echo -e "${yellow}------------------------"
    echo -e "${yellow}31.  ${white}站点数据管理 ${yellow}★${white}"
    echo -e "${yellow}32.  ${white}备份全站数据"
    echo -e "${yellow}33.  ${white}定时远程备份"
    echo -e "${yellow}34.  ${white}还原全站数据"
    echo -e "${yellow}------------------------"
    echo -e "${yellow}35.  ${white}站点防御程序"
    echo -e "${yellow}------------------------"
    echo -e "${yellow}36.  ${white}优化LDNMP环境"
    echo -e "${yellow}37.  ${white}更新LDNMP环境"
    echo -e "${yellow}38.  ${white}卸载LDNMP环境"
    echo -e "${yellow}------------------------"
    echo -e "${yellow}0.   ${white}返回主菜单"
    echo -e "${yellow}------------------------${white}"
    read -p "请输入你的选择: " sub_choice


    case $sub_choice in
      1)
      echo "安装LDNMP环境"
      root_use
      ldnmp_install_status_one
      check_port
      install_dependency
      #install_docker
      install_certbot

      # 创建必要的目录和文件
      cd /home && mkdir -p web/html web/mysql web/certs web/conf.d web/redis web/log/nginx && touch web/docker-compose.yml

      wget -O /home/web/nginx.conf https://raw.githubusercontent.com/kejilion/nginx/main/nginx10.conf
      wget -O /home/web/conf.d/default.conf https://raw.githubusercontent.com/kejilion/nginx/main/default10.conf
      default_server_ssl

      # 下载 docker-compose.yml 文件并进行替换
      wget -O /home/web/docker-compose.yml https://raw.githubusercontent.com/kejilion/docker/main/LNMP-docker-compose-10.yml

      dbrootpasswd=$(openssl rand -base64 16) && dbuse=$(openssl rand -hex 4) && dbusepasswd=$(openssl rand -base64 8)

      # 在 docker-compose.yml 文件中进行替换
      sed -i "s#webroot#$dbrootpasswd#g" /home/web/docker-compose.yml
      sed -i "s#kejilionYYDS#$dbusepasswd#g" /home/web/docker-compose.yml
      sed -i "s#kejilion#$dbuse#g" /home/web/docker-compose.yml

      install_ldnmp

        ;;
      2)
      clear
      # wordpress
      webname="WordPress"
      echo "安装$webname"

      ldnmp_install_status
      add_yuming
      install_ssltls
      certs_status
      add_db

      wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/kejilion/nginx/main/wordpress.com.conf
      sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

      cd /home/web/html
      mkdir $yuming
      cd $yuming
      wget -O latest.zip https://cn.wordpress.org/latest-zh_CN.zip
      unzip latest.zip
      rm latest.zip

      echo "define('FS_METHOD', 'direct'); define('WP_REDIS_HOST', 'redis'); define('WP_REDIS_PORT', '6379');" >> /home/web/html/$yuming/wordpress/wp-config-sample.php

      restart_ldnmp

      ldnmp_web_on
      echo "数据库名: $dbname"
      echo "用户名: $dbuse"
      echo "密码: $dbusepasswd"
      echo "数据库地址: mysql"
      echo "表前缀: wp_"

        ;;

      3)
      clear
      # Discuz论坛
      webname="Discuz论坛"
      echo "安装$webname"
      ldnmp_install_status
      add_yuming
      install_ssltls
      certs_status
      add_db

      wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/kejilion/nginx/main/discuz.com.conf

      sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

      cd /home/web/html
      mkdir $yuming
      cd $yuming
      wget -O latest.zip https://github.com/kejilion/Website_source_code/raw/main/Discuz_X3.5_SC_UTF8_20240520.zip
      unzip latest.zip
      rm latest.zip

      restart_ldnmp


      ldnmp_web_on
      echo "数据库地址: mysql"
      echo "数据库名: $dbname"
      echo "用户名: $dbuse"
      echo "密码: $dbusepasswd"
      echo "表前缀: discuz_"


        ;;

      4)
      clear
      # 可道云桌面
      webname="可道云桌面"
      echo "安装$webname"
      ldnmp_install_status
      add_yuming
      install_ssltls
      certs_status
      add_db

      wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/kejilion/nginx/main/kdy.com.conf
      sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

      cd /home/web/html
      mkdir $yuming
      cd $yuming
      wget -O latest.zip https://github.com/kalcaddle/kodbox/archive/refs/tags/1.50.02.zip
      unzip -o latest.zip
      rm latest.zip
      mv /home/web/html/$yuming/kodbox* /home/web/html/$yuming/kodbox
      restart_ldnmp

      ldnmp_web_on
      echo "数据库地址: mysql"
      echo "用户名: $dbuse"
      echo "密码: $dbusepasswd"
      echo "数据库名: $dbname"
      echo "redis主机: redis"

        ;;

      5)
      clear
      # 苹果CMS
      webname="苹果CMS"
      echo "安装$webname"
      ldnmp_install_status
      add_yuming
      install_ssltls
      certs_status
      add_db

      wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/kejilion/nginx/main/maccms.com.conf

      sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

      cd /home/web/html
      mkdir $yuming
      cd $yuming
      # wget https://github.com/magicblack/maccms_down/raw/master/maccms10.zip && unzip maccms10.zip && rm maccms10.zip
      wget https://github.com/magicblack/maccms_down/raw/master/maccms10.zip && unzip maccms10.zip && mv maccms10-*/* . && rm -r maccms10-* && rm maccms10.zip
      cd /home/web/html/$yuming/template/ && wget https://github.com/kejilion/Website_source_code/raw/main/DYXS2.zip && unzip DYXS2.zip && rm /home/web/html/$yuming/template/DYXS2.zip
      cp /home/web/html/$yuming/template/DYXS2/asset/admin/Dyxs2.php /home/web/html/$yuming/application/admin/controller
      cp /home/web/html/$yuming/template/DYXS2/asset/admin/dycms.html /home/web/html/$yuming/application/admin/view/system
      mv /home/web/html/$yuming/admin.php /home/web/html/$yuming/vip.php && wget -O /home/web/html/$yuming/application/extra/maccms.php https://raw.githubusercontent.com/kejilion/Website_source_code/main/maccms.php

      restart_ldnmp


      ldnmp_web_on
      echo "数据库地址: mysql"
      echo "数据库端口: 3306"
      echo "数据库名: $dbname"
      echo "用户名: $dbuse"
      echo "密码: $dbusepasswd"
      echo "数据库前缀: mac_"
      echo "------------------------"
      echo "安装成功后登录后台地址"
      echo "https://$yuming/vip.php"

        ;;

      6)
      clear
      # 独脚数卡
      webname="独脚数卡"
      echo "安装$webname"
      ldnmp_install_status
      add_yuming
      install_ssltls
      certs_status
      add_db

      wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/kejilion/nginx/main/dujiaoka.com.conf

      sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

      cd /home/web/html
      mkdir $yuming
      cd $yuming
      wget https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz && tar -zxvf 2.0.6-antibody.tar.gz && rm 2.0.6-antibody.tar.gz

      restart_ldnmp


      ldnmp_web_on
      echo "数据库地址: mysql"
      echo "数据库端口: 3306"
      echo "数据库名: $dbname"
      echo "用户名: $dbuse"
      echo "密码: $dbusepasswd"
      echo ""
      echo "redis地址: redis"
      echo "redis密码: 默认不填写"
      echo "redis端口: 6379"
      echo ""
      echo "网站url: https://$yuming"
      echo "后台登录路径: /admin"
      echo "------------------------"
      echo "用户名: admin"
      echo "密码: admin"
      echo "------------------------"
      echo "登录时右上角如果出现红色error0请使用如下命令: "
      echo "我也很气愤独角数卡为啥这么麻烦，会有这样的问题！"
      echo "sed -i 's/ADMIN_HTTPS=false/ADMIN_HTTPS=true/g' /home/web/html/$yuming/dujiaoka/.env"

        ;;

      7)
      clear
      # flarum论坛
      webname="flarum论坛"
      echo "安装$webname"
      ldnmp_install_status
      add_yuming
      install_ssltls
      certs_status
      add_db

      wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/kejilion/nginx/main/flarum.com.conf
      sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

      cd /home/web/html
      mkdir $yuming
      cd $yuming

      docker exec php sh -c "php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\""
      docker exec php sh -c "php composer-setup.php"
      docker exec php sh -c "php -r \"unlink('composer-setup.php');\""
      docker exec php sh -c "mv composer.phar /usr/local/bin/composer"

      docker exec php composer create-project flarum/flarum /var/www/html/$yuming
      docker exec php sh -c "cd /var/www/html/$yuming && composer require flarum-lang/chinese-simplified"
      docker exec php sh -c "cd /var/www/html/$yuming && composer require fof/polls"

      restart_ldnmp


      ldnmp_web_on
      echo "数据库地址: mysql"
      echo "数据库名: $dbname"
      echo "用户名: $dbuse"
      echo "密码: $dbusepasswd"
      echo "表前缀: flarum_"
      echo "管理员信息自行设置"

        ;;

      8)
      clear
      # typecho
      webname="typecho"
      echo "安装$webname"
      ldnmp_install_status
      add_yuming
      install_ssltls
      certs_status
      add_db

      wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/kejilion/nginx/main/typecho.com.conf
      sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

      cd /home/web/html
      mkdir $yuming
      cd $yuming
      wget -O latest.zip https://github.com/typecho/typecho/releases/latest/download/typecho.zip
      unzip latest.zip
      rm latest.zip

      restart_ldnmp


      clear
      ldnmp_web_on
      echo "数据库前缀: typecho_"
      echo "数据库地址: mysql"
      echo "用户名: $dbuse"
      echo "密码: $dbusepasswd"
      echo "数据库名: $dbname"

        ;;

      20)
      clear
      webname="PHP动态站点"
      echo "安装$webname"
      ldnmp_install_status
      add_yuming
      install_ssltls
      certs_status
      add_db

      wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/kejilion/nginx/main/index_php.conf
      sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

      cd /home/web/html
      mkdir $yuming
      cd $yuming

      clear
      echo -e "[${yellow}1/6${white}] 上传PHP源码"
      echo "-------------"
      echo "目前只允许上传zip格式的源码包，请将源码包放到/home/web/html/${yuming}目录下"
      read -p "也可以输入下载链接，远程下载源码包，直接回车将跳过远程下载： " url_download

      if [ -n "$url_download" ]; then
          wget "$url_download"
      fi

      unzip $(ls -t *.zip | head -n 1)
      rm -f $(ls -t *.zip | head -n 1)

      clear
      echo -e "[${yellow}2/6${white}] index.php所在路径"
      echo "-------------"
      find "$(realpath .)" -name "index.php" -print

      read -p "请输入index.php的路径，类似（/home/web/html/$yuming/wordpress/）： " index_lujing

      sed -i "s#root /var/www/html/$yuming/#root $index_lujing#g" /home/web/conf.d/$yuming.conf
      sed -i "s#/home/web/#/var/www/#g" /home/web/conf.d/$yuming.conf

      clear
      echo -e "[${yellow}3/6${white}] 请选择PHP版本"
      echo "-------------"
      read -p "1. php最新版 | 2. php7.4 : " pho_v
      case "$pho_v" in
        1)
          sed -i "s#php:9000#php:9000#g" /home/web/conf.d/$yuming.conf
          PHP_Version="php"
          ;;
        2)
          sed -i "s#php:9000#php74:9000#g" /home/web/conf.d/$yuming.conf
          PHP_Version="php74"
          ;;
        *)
          echo "无效的选择，请重新输入。"
          ;;
      esac


      clear
      echo -e "[${yellow}4/6${white}] 安装指定扩展"
      echo "-------------"
      echo "已经安装的扩展"
      docker exec php php -m

      read -p "$(echo -e "输入需要安装的扩展名称，如 ${yellow}SourceGuardian imap ftp${white} 等等。直接回车将跳过安装 ： ")" php_extensions
      if [ -n "$php_extensions" ]; then
          docker exec $PHP_Version install-php-extensions $php_extensions
      fi


      clear
      echo -e "[${yellow}5/6${white}] 编辑站点配置"
      echo "-------------"
      echo "按任意键继续，可以详细设置站点配置，如伪静态等内容"
      read -n 1 -s -r -p ""
      install nano
      nano /home/web/conf.d/$yuming.conf


      clear
      echo -e "[${yellow}6/6${white}] 数据库管理"
      echo "-------------"
      read -p "1. 我搭建新站        2. 我搭建老站有数据库备份： " use_db
      case $use_db in
          1)
              echo
              ;;
          2)
              echo "数据库备份必须是.gz结尾的压缩包。请放到/home/目录下，支持宝塔/1panel备份数据导入。"
              read -p "也可以输入下载链接，远程下载备份数据，直接回车将跳过远程下载： " url_download_db

              cd /home/
              if [ -n "$url_download_db" ]; then
                  wget "$url_download_db"
              fi
              gunzip $(ls -t *.gz | head -n 1)
              latest_sql=$(ls -t *.sql | head -n 1)
              dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
              docker exec -i mysql mysql -u root -p"$dbrootpasswd" $dbname < "/home/$latest_sql"
              echo "数据库导入的表数据"
              docker exec -i mysql mysql -u root -p"$dbrootpasswd" -e "USE $dbname; SHOW TABLES;"
              rm -f *.sql
              echo "数据库导入完成"
              ;;
          *)
              echo
              ;;
      esac

      restart_ldnmp

      ldnmp_web_on
      prefix="web$(shuf -i 10-99 -n 1)_"
      echo "数据库地址: mysql"
      echo "数据库名: $dbname"
      echo "用户名: $dbuse"
      echo "密码: $dbusepasswd"
      echo "表前缀: $prefix"
      echo "管理员登录信息自行设置"

        ;;


      21)
      echo "安装nginx环境"
      root_use
      check_port
      install_dependency
      #install_docker
      install_certbot

      cd /home && mkdir -p web/html web/mysql web/certs web/conf.d web/redis web/log/nginx && touch web/docker-compose.yml

      wget -O /home/web/nginx.conf https://raw.githubusercontent.com/kejilion/nginx/main/nginx10.conf
      wget -O /home/web/conf.d/default.conf https://raw.githubusercontent.com/kejilion/nginx/main/default10.conf
      default_server_ssl
      docker rmi nginx nginx:alpine >/dev/null 2>&1
      docker run -d --name nginx --restart always -p 80:80 -p 443:443 -p 443:443/udp -v /home/web/nginx.conf:/etc/nginx/nginx.conf -v /home/web/conf.d:/etc/nginx/conf.d -v /home/web/certs:/etc/nginx/certs -v /home/web/html:/var/www/html -v /home/web/log/nginx:/var/log/nginx nginx:alpine

      clear
      nginx_version=$(docker exec nginx nginx -v 2>&1)
      nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
      echo "nginx已安装完成"
      echo -e "当前版本: ${yellow}v$nginx_version${white}"
      echo ""
        ;;

      22)
      clear
      webname="站点重定向"
      echo "安装$webname"
      nginx_install_status
      ip_address
      add_yuming
      read -p "请输入跳转域名: " reverseproxy

      install_ssltls
      certs_status

      wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/kejilion/nginx/main/rewrite.conf
      sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
      sed -i "s/baidu.com/$reverseproxy/g" /home/web/conf.d/$yuming.conf

      docker restart nginx

      nginx_web_on


        ;;

      23)
      clear
      webname="反向代理-IP+端口"
      echo "安装$webname"
      nginx_install_status
      ip_address
      add_yuming
      read -p "请输入你的反代IP: " reverseproxy
      read -p "请输入你的反代端口: " port

      install_ssltls
      certs_status

      wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/kejilion/nginx/main/reverse-proxy.conf
      sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
      sed -i "s/0.0.0.0/$reverseproxy/g" /home/web/conf.d/$yuming.conf
      sed -i "s/0000/$port/g" /home/web/conf.d/$yuming.conf

      docker restart nginx

      nginx_web_on

        ;;

      24)
      clear
      webname="反向代理-域名"
      echo "安装$webname"
      nginx_install_status
      ip_address
      add_yuming
      echo -e "域名格式: ${yellow}http://www.google.com${white}"
      read -p "请输入你的反代域名: " fandai_yuming

      install_ssltls
      certs_status

      wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/kejilion/nginx/main/reverse-proxy-domain.conf
      sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
      sed -i "s|fandaicom|$fandai_yuming|g" /home/web/conf.d/$yuming.conf

      docker restart nginx

      nginx_web_on

        ;;


      25)
      clear
      webname="静态站点"
      echo "安装$webname"
      nginx_install_status
      add_yuming
      install_ssltls
      certs_status

      wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/kejilion/nginx/main/html.conf
      sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

      cd /home/web/html
      mkdir $yuming
      cd $yuming


      clear
      echo -e "[${yellow}1/2${white}] 上传静态源码"
      echo "-------------"
      echo "目前只允许上传zip格式的源码包，请将源码包放到/home/web/html/${yuming}目录下"
      read -p "也可以输入下载链接，远程下载源码包，直接回车将跳过远程下载： " url_download

      if [ -n "$url_download" ]; then
          wget "$url_download"
      fi

      unzip $(ls -t *.zip | head -n 1)
      rm -f $(ls -t *.zip | head -n 1)

      clear
      echo -e "[${yellow}2/2${white}] index.html所在路径"
      echo "-------------"
      find "$(realpath .)" -name "index.html" -print

      read -p "请输入index.html的路径，类似（/home/web/html/$yuming/index/）： " index_lujing

      sed -i "s#root /var/www/html/$yuming/#root $index_lujing#g" /home/web/conf.d/$yuming.conf
      sed -i "s#/home/web/#/var/www/#g" /home/web/conf.d/$yuming.conf

      docker exec nginx chmod -R 777 /var/www/html
      docker restart nginx

      nginx_web_on

        ;;


      26)
      clear
      webname="Bitwarden"
      echo "安装$webname"
      nginx_install_status
      add_yuming
      install_ssltls
      certs_status

      docker run -d \
        --name bitwarden \
        --restart always \
        -p 3280:80 \
        -v /home/web/html/$yuming/bitwarden/data:/data \
        vaultwarden/server
      duankou=3280
      reverse_proxy

      nginx_web_on

        ;;

      27)
      clear
      webname="halo"
      echo "安装$webname"
      nginx_install_status
      add_yuming
      install_ssltls
      certs_status

      docker run -d --name halo --restart always -p 8010:8090 -v /home/web/html/$yuming/.halo2:/root/.halo2 halohub/halo:2
      duankou=8010
      reverse_proxy

      nginx_web_on

        ;;



    31)
    root_use
    while true; do
        clear
        echo "LDNMP站点管理"
        echo "LDNMP环境"
        echo "------------------------"
        ldnmp_version

        # ls -t /home/web/conf.d | sed 's/\.[^.]*$//'
        echo "站点信息                      证书到期时间"
        echo "------------------------"
        for cert_file in /home/web/certs/*_cert.pem; do
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
        dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
        docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SHOW DATABASES;" 2> /dev/null | grep -Ev "Database|information_schema|mysql|performance_schema|sys"

        echo "------------------------"
        echo ""
        echo "站点目录"
        echo "------------------------"
        echo -e "数据 ${hui}/home/web/html${white}     证书 ${hui}/home/web/certs${white}     配置 ${hui}/home/web/conf.d${white}"
        echo "------------------------"
        echo ""
        echo "操作"
        echo "------------------------"
        echo "1. 申请/更新域名证书"
        echo "3. 清理站点缓存                    4. 查看站点分析报告"
        echo "5. 编辑全局配置                    6. 编辑站点配置"
        echo "------------------------"
        echo "7. 删除指定站点                    8. 删除指定数据库"
        echo "------------------------"
        echo "0. 返回上一级选单"
        echo "------------------------"
        read -p "请输入你的选择: " sub_choice
        case $sub_choice in
            1)
                echo "申请域名证书"
                read -p "请输入你的域名: " yuming
                install_certbot
                install_ssltls
                certs_status

                ;;

            2)
                read -p "请输入旧域名: " oddyuming
                read -p "请输入新域名: " yuming
                install_certbot
                install_ssltls
                certs_status
                mv /home/web/conf.d/$oddyuming.conf /home/web/conf.d/$yuming.conf
                sed -i "s/$oddyuming/$yuming/g" /home/web/conf.d/$yuming.conf
                mv /home/web/html/$oddyuming /home/web/html/$yuming

                rm /home/web/certs/${oddyuming}_key.pem
                rm /home/web/certs/${oddyuming}_cert.pem

                docker restart nginx


                ;;


            3)
                echo "清理站点缓存"
                # docker exec -it nginx rm -rf /var/cache/nginx
                docker restart nginx
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
                echo "查看站点数据"
                install goaccess
                goaccess --log-format=COMBINED /home/web/log/nginx/access.log

                ;;

            5)
                echo "编辑全局配置"
                install nano
                nano /home/web/nginx.conf
                docker restart nginx
                ;;

            6)
                echo "编辑站点配置"
                read -p "编辑站点配置，请输入你要编辑的域名: " yuming
                install nano
                nano /home/web/conf.d/$yuming.conf
                docker restart nginx
                ;;

            7)
                echo "删除站点数据目录"
                read -p "删除站点数据目录，请输入你的域名: " yuming
                rm -r /home/web/html/$yuming
                rm /home/web/conf.d/$yuming.conf
                rm /home/web/certs/${yuming}_key.pem
                rm /home/web/certs/${yuming}_cert.pem
                docker restart nginx
                ;;
            8)
                echo "删除站点数据库"
                read -p "删除站点数据库，请输入数据库名: " shujuku
                dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
                docker exec mysql mysql -u root -p"$dbrootpasswd" -e "DROP DATABASE $shujuku;" 2> /dev/null
                ;;
            0)
                break  # 跳出循环，退出菜单
                ;;
            *)
                break  # 跳出循环，退出菜单
                ;;
        esac
    done

      ;;


    32)
      clear
      echo "LDNMP环境备份"
      cd /home/ && tar czvf web_$(date +"%Y%m%d%H%M%S").tar.gz web

      while true; do
        clear
        read -p "要传送文件到远程服务器吗？(Y/N): " choice
        case "$choice" in
          [Yy])
            read -p "请输入远端服务器IP:  " remote_ip
            if [ -z "$remote_ip" ]; then
              echo "错误: 请输入远端服务器IP。"
              continue
            fi
            latest_tar=$(ls -t /home/*.tar.gz | head -1)
            if [ -n "$latest_tar" ]; then
              ssh-keygen -f "/root/.ssh/known_hosts" -R "$remote_ip"
              sleep 2  # 添加等待时间
              scp -o StrictHostKeyChecking=no "$latest_tar" "root@$remote_ip:/home/"
              echo "文件已传送至远程服务器home目录。"
            else
              echo "未找到要传送的文件。"
            fi
            break
            ;;
          [Nn])
            break
            ;;
          *)
            echo "无效的选择，请输入 Y 或 N。"
            ;;
        esac
      done
      ;;

    33)
      clear
      echo "定时远程备份"
      read -p "输入远程服务器IP: " useip
      read -p "输入远程服务器密码: " usepasswd

      cd ~
      wget -O ${useip}_beifen.sh https://raw.githubusercontent.com/kejilion/sh/main/beifen.sh > /dev/null 2>&1
      chmod +x ${useip}_beifen.sh

      sed -i "s/0.0.0.0/$useip/g" ${useip}_beifen.sh
      sed -i "s/123456/$usepasswd/g" ${useip}_beifen.sh

      echo "------------------------"
      echo "1. 每周备份                 2. 每天备份"
      read -p "请输入你的选择: " dingshi

      case $dingshi in
          1)
              check_crontab_installed
              read -p "选择每周备份的星期几 (0-6，0代表星期日): " weekday
              (crontab -l ; echo "0 0 * * $weekday ./${useip}_beifen.sh") | crontab - > /dev/null 2>&1
              ;;
          2)
              check_crontab_installed
              read -p "选择每天备份的时间（小时，0-23）: " hour
              (crontab -l ; echo "0 $hour * * * ./${useip}_beifen.sh") | crontab - > /dev/null 2>&1
              ;;
          *)
              break  # 跳出
              ;;
      esac

      install sshpass

      ;;

    34)
      root_use
      echo "LDNMP环境还原"
      ldnmp_install_status_two
      echo "请确认home目录中已经放置网站备份的gz压缩包，按任意键继续……"
      read -n 1 -s -r -p ""
      echo -e "${yellow}正在解压...${white}"
      cd /home/ && ls -t /home/*.tar.gz | head -1 | xargs -I {} tar -xzf {}
      check_port
      install_dependency
      #install_docker
      install_certbot

      install_ldnmp

      ;;

    35)
        echo "LDNMP环境防御"
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
              read -p "请输入你的选择: " sub_choice
              case $sub_choice in
                  1)
                      sed -i 's/false/true/g' /path/to/fail2ban/config/fail2ban/jail.d/alpine-ssh.conf
                      sed -i 's/false/true/g' /path/to/fail2ban/config/fail2ban/jail.d/linux-ssh.conf
                      sed -i 's/false/true/g' /path/to/fail2ban/config/fail2ban/jail.d/centos-ssh.conf
                      f2b_status
                      ;;
                  2)
                      sed -i 's/true/false/g' /path/to/fail2ban/config/fail2ban/jail.d/alpine-ssh.conf
                      sed -i 's/true/false/g' /path/to/fail2ban/config/fail2ban/jail.d/linux-ssh.conf
                      sed -i 's/true/false/g' /path/to/fail2ban/config/fail2ban/jail.d/centos-ssh.conf
                      f2b_status
                      ;;
                  3)
                      sed -i 's/false/true/g' /path/to/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
                      f2b_status
                      ;;
                  4)
                      sed -i 's/true/false/g' /path/to/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
                      f2b_status
                      ;;
                  5)
                      echo "------------------------"
                      f2b_sshd
                      echo "------------------------"
                      ;;
                  6)

                      echo "------------------------"
                      xxx=fail2ban-nginx-cc
                      f2b_status_xxx
                      echo "------------------------"
                      xxx=docker-nginx-bad-request
                      f2b_status_xxx
                      echo "------------------------"
                      xxx=docker-nginx-botsearch
                      f2b_status_xxx
                      echo "------------------------"
                      xxx=docker-nginx-http-auth
                      f2b_status_xxx
                      echo "------------------------"
                      xxx=docker-nginx-limit-req
                      f2b_status_xxx
                      echo "------------------------"
                      xxx=docker-php-url-fopen
                      f2b_status_xxx
                      echo "------------------------"

                      ;;

                  7)
                      docker exec -it fail2ban fail2ban-client status
                      ;;
                  8)
                      tail -f /path/to/fail2ban/config/log/fail2ban/fail2ban.log

                      ;;
                  9)
                      docker rm -f fail2ban
                      rm -rf /path/to/fail2ban
                      crontab -l | grep -v "CF-Under-Attack.sh" | crontab - 2>/dev/null
                      echo "Fail2Ban防御程序已卸载"
                      break
                      ;;

                  11)
                      install nano
                      nano /path/to/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
                      f2b_status

                      break
                      ;;
                  21)
                      echo "cloudflare模式"
                      echo "到cf后台右上角我的个人资料，选择左侧API令牌，获取Global API Key"
                      echo "https://dash.cloudflare.com/login"
                      read -p "输入CF的账号: " cfuser
                      read -p "输入CF的Global API Key: " cftoken

                      wget -O /home/web/conf.d/default.conf https://raw.githubusercontent.com/kejilion/nginx/main/default11.conf
                      docker restart nginx

                      cd /path/to/fail2ban/config/fail2ban/jail.d/
                      curl -sS -O https://raw.githubusercontent.com/kejilion/config/main/fail2ban/nginx-docker-cc.conf

                      cd /path/to/fail2ban/config/fail2ban/action.d
                      curl -sS -O https://raw.githubusercontent.com/kejilion/config/main/fail2ban/cloudflare-docker.conf

                      sed -i "s/kejilion@outlook.com/$cfuser/g" /path/to/fail2ban/config/fail2ban/action.d/cloudflare-docker.conf
                      sed -i "s/APIKEY00000/$cftoken/g" /path/to/fail2ban/config/fail2ban/action.d/cloudflare-docker.conf
                      f2b_status

                      echo "已配置cloudflare模式，可在cf后台，站点-安全性-事件中查看拦截记录"
                      ;;

                  22)
                      echo "高负载开启5秒盾"
                      echo -e "${yellow}网站每5分钟自动检测，当达检测到高负载会自动开盾，低负载也会自动关闭5秒盾。${white}"
                      echo "--------------"
                      echo "获取CF参数: "
                      echo -e "到cf后台右上角我的个人资料，选择左侧API令牌，获取${yellow}Global API Key${white}"
                      echo -e "到cf后台域名概要页面右下方获取${yellow}区域ID${white}"
                      echo "https://dash.cloudflare.com/login"
                      echo "--------------"
                      read -p "输入CF的账号: " cfuser
                      read -p "输入CF的Global API Key: " cftoken
                      read -p "输入CF中域名的区域ID: " cfzonID

                      cd ~
                      install jq bc
                      check_crontab_installed
                      curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/CF-Under-Attack.sh
                      chmod +x CF-Under-Attack.sh
                      sed -i "s/AAAA/$cfuser/g" ~/CF-Under-Attack.sh
                      sed -i "s/BBBB/$cftoken/g" ~/CF-Under-Attack.sh
                      sed -i "s/CCCC/$cfzonID/g" ~/CF-Under-Attack.sh

                      cron_job="*/5 * * * * ~/CF-Under-Attack.sh"

                      existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")

                      if [ -z "$existing_cron" ]; then
                          (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
                          echo "高负载自动开盾脚本已添加"
                      else
                          echo "自动开盾脚本已存在，无需添加"
                      fi

                      ;;
                  0)
                      break
                      ;;
                  *)
                      echo "无效的选择，请重新输入。"
                      ;;
              esac
              break_end

          done

      elif [ -x "$(command -v fail2ban-client)" ] ; then
          clear
          echo "卸载旧版fail2ban"
          read -p "确定继续吗？(Y/N): " choice
          case "$choice" in
            [Yy])
              remove fail2ban
              rm -rf /etc/fail2ban
              echo "Fail2Ban防御程序已卸载"
              ;;
            [Nn])
              echo "已取消"
              ;;
            *)
              echo "无效的选择，请输入 Y 或 N。"
              ;;
          esac

      else
          clear
          #install_docker

          docker rm -f nginx
          wget -O /home/web/nginx.conf https://raw.githubusercontent.com/kejilion/nginx/main/nginx10.conf
          wget -O /home/web/conf.d/default.conf https://raw.githubusercontent.com/kejilion/nginx/main/default10.conf
          default_server_ssl
          docker run -d --name nginx --restart always --network web_default -p 80:80 -p 443:443 -p 443:443/udp -v /home/web/nginx.conf:/etc/nginx/nginx.conf -v /home/web/conf.d:/etc/nginx/conf.d -v /home/web/certs:/etc/nginx/certs -v /home/web/html:/var/www/html -v /home/web/log/nginx:/var/log/nginx nginx:alpine
          docker exec -it nginx chmod -R 777 /var/www/html

          f2b_install_sshd

          cd /path/to/fail2ban/config/fail2ban/filter.d
          curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/fail2ban-nginx-cc.conf
          cd /path/to/fail2ban/config/fail2ban/jail.d/
          curl -sS -O https://raw.githubusercontent.com/kejilion/config/main/fail2ban/nginx-docker-cc.conf
          sed -i "/cloudflare/d" /path/to/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf

          cd ~
          f2b_status

          echo "防御程序已开启"
      fi

        ;;

    36)
          while true; do
              clear
              echo "优化LDNMP环境"
              echo "优化LDNMP环境"
              echo "------------------------"
              echo "1. 标准模式              2. 高性能模式 (推荐2H2G以上)"
              echo "------------------------"
              echo "0. 退出"
              echo "------------------------"
              read -p "请输入你的选择: " sub_choice
              case $sub_choice in
                  1)
                  echo "站点标准模式"
                  # nginx调优
                  sed -i 's/worker_connections.*/worker_connections 1024;/' /home/web/nginx.conf

                  # php调优
                  wget -O /home/optimized_php.ini https://raw.githubusercontent.com/kejilion/sh/main/optimized_php.ini
                  docker cp /home/optimized_php.ini php:/usr/local/etc/php/conf.d/optimized_php.ini
                  docker cp /home/optimized_php.ini php74:/usr/local/etc/php/conf.d/optimized_php.ini
                  rm -rf /home/optimized_php.ini

                  # php调优
                  wget -O /home/www.conf https://raw.githubusercontent.com/kejilion/sh/main/www-1.conf
                  docker cp /home/www.conf php:/usr/local/etc/php-fpm.d/www.conf
                  docker cp /home/www.conf php74:/usr/local/etc/php-fpm.d/www.conf
                  rm -rf /home/www.conf

                  # mysql调优
                  wget -O /home/custom_mysql_config.cnf https://raw.githubusercontent.com/kejilion/sh/main/custom_mysql_config-1.cnf
                  docker cp /home/custom_mysql_config.cnf mysql:/etc/mysql/conf.d/
                  rm -rf /home/custom_mysql_config.cnf

                  docker exec -it redis redis-cli CONFIG SET maxmemory 512mb
                  docker exec -it redis redis-cli CONFIG SET maxmemory-policy allkeys-lru

                  docker restart nginx
                  docker restart php
                  docker restart php74
                  docker restart mysql

                  echo "LDNMP环境已设置成 标准模式"

                      ;;
                  2)
                  echo "站点高性能模式"
                  # nginx调优
                  sed -i 's/worker_connections.*/worker_connections 10240;/' /home/web/nginx.conf

                  # php调优
                  wget -O /home/www.conf https://raw.githubusercontent.com/kejilion/sh/main/www.conf
                  docker cp /home/www.conf php:/usr/local/etc/php-fpm.d/www.conf
                  docker cp /home/www.conf php74:/usr/local/etc/php-fpm.d/www.conf
                  rm -rf /home/www.conf

                  # mysql调优
                  wget -O /home/custom_mysql_config.cnf https://raw.githubusercontent.com/kejilion/sh/main/custom_mysql_config.cnf
                  docker cp /home/custom_mysql_config.cnf mysql:/etc/mysql/conf.d/
                  rm -rf /home/custom_mysql_config.cnf

                  docker exec -it redis redis-cli CONFIG SET maxmemory 1024mb
                  docker exec -it redis redis-cli CONFIG SET maxmemory-policy allkeys-lru

                  docker restart nginx
                  docker restart php
                  docker restart php74
                  docker restart mysql

                  echo "LDNMP环境已设置成 高性能模式"

                      ;;
                  0)
                      break
                      ;;
                  *)
                      echo "无效的选择，请重新输入。"
                      ;;
              esac
              break_end

          done
        ;;


    37)
      root_use
      while true; do
          clear
          echo "更新LDNMP环境"
          echo "更新LDNMP环境"
          echo "------------------------"
          ldnmp_version
          echo "1. 更新nginx               2. 更新mysql              3. 更新php              4. 更新redis"
          echo "------------------------"
          echo "5. 更新完整环境"
          echo "------------------------"
          echo "0. 返回上一级"
          echo "------------------------"
          read -p "请输入你的选择: " sub_choice
          case $sub_choice in
              1)
              ldnmp_pods="nginx"
              echo "更新$ldnmp_pods"
              cd /home/web/
              docker rm -f $ldnmp_pods
              docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi > /dev/null 2>&1
              docker compose up -d --force-recreate $ldnmp_pods
              docker exec $ldnmp_pods chmod -R 777 /var/www/html
              docker restart $ldnmp_pods > /dev/null 2>&1
              echo "更新${ldnmp_pods}完成"

                  ;;

              2)
              ldnmp_pods="mysql"
              read -p "请输入${ldnmp_pods}版本号 （如: 8.0 8.3 8.4 9.0）（回车获取最新版）: " version
              version=${version:-latest}

              echo "更新$ldnmp_pods"
              cd /home/web/
              cp /home/web/docker-compose.yml /home/web/docker-compose1.yml
              sed -i "s/image: mysql/image: mysql:${version}/" /home/web/docker-compose.yml
              docker rm -f $ldnmp_pods
              docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi > /dev/null 2>&1
              docker compose up -d --force-recreate $ldnmp_pods
              docker restart $ldnmp_pods
              cp /home/web/docker-compose1.yml /home/web/docker-compose.yml
              echo "更新${ldnmp_pods}完成"

                  ;;
              3)
              ldnmp_pods="php"
              read -p "请输入${ldnmp_pods}版本号 （如: 7.4 8.0 8.1 8.2 8.3）（回车获取最新版）: " version
              version=${version:-8.3}
              echo "更新$ldnmp_pods"
              cd /home/web/
              cp /home/web/docker-compose.yml /home/web/docker-compose1.yml
              sed -i "s/image: php:fpm-alpine/image: php:${version}-fpm-alpine/" /home/web/docker-compose.yml
              docker rm -f $ldnmp_pods
              docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi > /dev/null 2>&1
              docker compose up -d --force-recreate $ldnmp_pods
              docker exec $ldnmp_pods chmod -R 777 /var/www/html

              # docker exec php sed -i "s/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g" /etc/apk/repositories > /dev/null 2>&1

              docker exec php apk update
              curl -sL https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions -o /usr/local/bin/install-php-extensions
              docker exec php mkdir -p /usr/local/bin/
              docker cp /usr/local/bin/install-php-extensions php:/usr/local/bin/
              docker exec php chmod +x /usr/local/bin/install-php-extensions

              docker exec php sh -c "\
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
                            && rm -rf /tmp/imagick"


              docker exec php install-php-extensions mysqli pdo_mysql gd intl zip exif bcmath opcache redis


              docker exec php sh -c 'echo "upload_max_filesize=50M " > /usr/local/etc/php/conf.d/uploads.ini' > /dev/null 2>&1
              docker exec php sh -c 'echo "post_max_size=50M " > /usr/local/etc/php/conf.d/post.ini' > /dev/null 2>&1
              docker exec php sh -c 'echo "memory_limit=256M" > /usr/local/etc/php/conf.d/memory.ini' > /dev/null 2>&1
              docker exec php sh -c 'echo "max_execution_time=1200" > /usr/local/etc/php/conf.d/max_execution_time.ini' > /dev/null 2>&1
              docker exec php sh -c 'echo "max_input_time=600" > /usr/local/etc/php/conf.d/max_input_time.ini' > /dev/null 2>&1

              docker restart $ldnmp_pods > /dev/null 2>&1
              cp /home/web/docker-compose1.yml /home/web/docker-compose.yml
              echo "更新${ldnmp_pods}完成"

                  ;;
              4)
              ldnmp_pods="redis"
              echo "更新$ldnmp_pods"
              cd /home/web/
              docker rm -f $ldnmp_pods
              docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi > /dev/null 2>&1
              docker compose up -d --force-recreate $ldnmp_pods
              docker exec -it redis redis-cli CONFIG SET maxmemory 512mb
              docker exec -it redis redis-cli CONFIG SET maxmemory-policy allkeys-lru
              docker restart $ldnmp_pods > /dev/null 2>&1
              echo "更新${ldnmp_pods}完成"

                  ;;
              5)
                read -p "$(echo -e "${yellow}提示: ${white}长时间不更新环境的用户，请慎重更新LDNMP环境，会有数据库更新失败的风险。确定更新LDNMP环境吗？(Y/N): ")" choice
                case "$choice" in
                  [Yy])
                    echo "完整更新LDNMP环境"
                    cd /home/web/
                    docker compose down
                    docker compose down --rmi all

                    check_port
                    install_dependency
                    #install_docker
                    install_certbot
                    install_ldnmp
                    ;;
                  *)
                    ;;
                esac
                  ;;
              0)
                  break
                  ;;
              *)
                  echo "无效的选择，请重新输入。"
                  ;;
          esac
          break_end
      done


      ;;

    38)
        root_use
        echo "卸载LDNMP环境"
        read -p "$(echo -e "${red}强烈建议：${white}先备份全部网站数据，再卸载LDNMP环境。确定删除所有网站数据吗？(Y/N): ")" choice
        case "$choice" in
          [Yy])
            cd /home/web/
            docker compose down
            docker compose down --rmi all
            rm -rf /home/web
            ;;
          [Nn])

            ;;
          *)
            echo "无效的选择，请输入 Y 或 N。"
            ;;
        esac
        ;;

    0)
        kejilion
      ;;

    *)
        echo "无效的输入!"
    esac
    break_end

  done

}
linux_ldnmp