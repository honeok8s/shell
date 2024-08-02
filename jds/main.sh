#!/bin/bash
# Author: honeok
# Describe: 挖矿二测main

set -o errexit
clear

# 颜色代码
yellow='\033[1;33m'  # 提示信息
red='\033[1;31m'     # 警告信息
magenta='\033[0;35m' # 品红色
green='\033[1;32m'   # 成功信息
blue='\033[1;34m'    # 一般信息
cyan='\033[1;36m'    # 特殊信息
purple='\033[1;35m'  # 紫色或粉色信息
gray='\033[1;30m'    # 灰色信息
white='\033[0m'      # 结束颜色设置

# 打印带颜色的消息
_yellow() { echo -e ${yellow}$@${white}; }
_red() { echo -e ${red}$@${white}; }
_magenta() { echo -e ${magenta}$@${white}; }
_green() { echo -e ${green}$@${white}; }
_blue() { echo -e ${blue}$@${white}; }
_cyan() { echo -e ${cyan}$@${white}; }
_purple() { echo -e ${purple}$@${white}; }
_gray() { echo -e ${gray}$@${white}; }

# 启动所有服务器
all_start(){
    # 动态生成服务器目录
    local start_dirs=()
    for i in {1..5}; do
        start_dirs+=("/data/server${i}/game/")
    done
    start_dirs+=("/data/server/gate/")
    start_dirs+=("/data/server/login/")

    # 启动
    for dir in "${start_dirs[@]}"; do
        cd "$dir"
        rm -f nohup.txt
        ./server.sh start
        echo ""
    done

	sleep 5s

	cd /data/tool/
	if ! pgrep -f 'processcontrol-allserver' > /dev/null; then
		sh processcontrol-allserver.sh > /dev/null 2>&1 &
		_green "processcontrol-allserver 启动成功"
	else
		_yellow "processcontrol-allserver 正在运行"
	fi 

	_green "GameServer全部启动成功"
}

# 停止所有服务器
all_stop() {
    # 检查并停止守护进程
    cd /data/tool/
    if pgrep -f 'processcontrol-allserver' > /dev/null; then
        kill -9 $(pgrep -f 'processcontrol-allserver' | head -n 1)
        > control.txt
        > dump.txt
        _green "processcontrol-allserver 守护进程停止成功!"
    else
        _yellow "processcontrol-allserver 守护进程不存在无需停止"
    fi

    # 停止服务器
    stop_server() {
        local dir=$1
        cd "$dir"
        ./server.sh flush
        sleep 60s
        ./server.sh stop
        _green "在 $dir 停止成功"
    }

    # 停止登录服务器
    cd /data/server/login/
    ./server.sh stop
    _green "Login 停止成功"

    # 停止网关服务器
    cd /data/server/gate/
    ./server.sh stop
    sleep 120s
    _green "Gate 停止成功"

    # 动态生成游戏服务器目录
    local stop_dirs=()
    for i in {1..5}; do
        stop_dirs+=("/data/server${i}/game/")
    done

    # 停止所有游戏服务器
    for dir in "${stop_dirs[@]}"; do
        stop_server "$dir"
    done
}

all_reload(){
	cd /data/update/ || { _red "无法进入目录 $dir"; exit 1; }

    if [ "$(ls -A)" ]; then
        rm -rf *
		_green "目录/data/update/已清空"
	else
		_yellow "目录/data/update/为空"
    fi

    sshpass -p 'c4h?itwj5ENi' scp -o StrictHostKeyChecking=no root@10.47.7.242:/data/update/updategame.tar.gz ./
    if [ $? -ne 0 ]; then
        _red "文件下载失败"; exit 1
    fi

	tar xvf updategame.tar.gz

    # 定义服务器目录
    local reload_dirs=()
    for i in {1..5}; do
        reload_dirs+=("/data/server${i}/game/")
    done

    # 复制更新文件到每个服务器目录
    for dir in "${server_dirs[@]}"; do
        \cp -rf /data/update/app/* "$dir"
    done

    # 重新加载
    for dir in "${reload_dirs[@]}"; do
        cd "$dir" || { _red "无法进入目录 $dir"; exit 1; }
        ./server.sh reload
		_green "$dir 重新加载成功"
    done

	_green "所有服务器重新加载成功"
}

update_start(){
	cd /data/update/ || { _red "无法进入目录 $dir"; exit 1; }

    if [ "$(ls -A)" ]; then
        rm -rf *
		_green "目录/data/update/已清空"
	else
		_yellow "目录/data/update/为空"
    fi

    sshpass -p 'c4h?itwj5ENi' scp -o StrictHostKeyChecking=no root@10.47.7.242:/data/update/updategame.tar.gz ./
    if [ $? -ne 0 ]; then
        _red "文件下载失败"; exit 1
    fi

	tar xvf updategame.tar.gz

\cp -rf /data/update/app/* /data/server1/game/

\cp -rf /data/update/app/* /data/server2/game/

\cp -rf /data/update/app/* /data/server3/game/

\cp -rf /data/update/app/* /data/server4/game/

\cp -rf /data/update/app/* /data/server5/game/

\cp -rf /data/update/app/* /data/server/gate/

\cp -rf /data/update/app/* /data/server/login/

cd /data/server1/game/
rm -rf nohup.txt
./server.sh start
echo

cd /data/server2/game/
rm -rf nohup.txt
./server.sh start
echo

cd /data/server3/game/
rm -rf nohup.txt
./server.sh start
echo

cd /data/server4/game/
rm -rf nohup.txt
./server.sh start
echo

cd /data/server5/game/
rm -rf nohup.txt
./server.sh start
echo

cd /data/server/gate/
rm -rf nohup.txt
./server.sh start
echo

cd /data/server/login/
rm -rf nohup.txt
./server.sh start
echo
sleep 5s

cd /data/tool/
sa=`ps -aux | grep 'processcontrol-allserver' | grep -v grep`
if [ "$?" != "0" ];
then
sh processcontrol-allserver.sh > /dev/null 2>&1 & 
else
echo "processcontrol-allserver-is-runing"
fi 

echo ALLsuccess
}

main(){
	local choice
	while true; do
		_purple "-------------------------"
		_purple "1. 启动服务器"
		_purple "2. 停止服务器(默认执行存盘)"
		_purple "3. 重读服务器"
		_purple "4. 维护更新启动"
		_purple "0. 退出脚本"
		_purple "-------------------------"
		echo -e "${cyan}请输入选项并按Enter: ${white}"
		read choice

		case "$choice" in
			1)
				all_start
				;;
			2)
				all_stop
				;;
			3)
				all_reload
				;;
			4)
				update_start
			0)
				_yellow "Bye!"
				exit 0
				;;
			*)
				_red "无效选项,请重新输入"
				;;
		esac
		_yellow "按任意键继续"	
		read -n 1 -s -r
	done
}

main
exit 0