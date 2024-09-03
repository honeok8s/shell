#!/bin/bash

yellow='\033[1;33m'
red='\033[1;31m'
magenta='\033[1;35m'
green='\033[1;32m'
blue='\033[1;34m'
cyan='\033[1;36m'
purple='\033[1;35m'
gray='\033[1;30m'
orange='\033[1;38;5;208m'
white='\033[0m'
_yellow() { echo -e ${yellow}$@${white}; }
_red() { echo -e ${red}$@${white}; }
_magenta() { echo -e ${magenta}$@${white}; }
_green() { echo -e ${green}$@${white}; }
_blue() { echo -e ${blue}$@${white}; }
_cyan() { echo -e ${cyan}$@${white}; }
_purple() { echo -e ${purple}$@${white}; }
_gray() { echo -e ${gray}$@${white}; }
_orange() { echo -e ${orange}$@${white}; }

cd /data/tool/
if pgrep -f processcontrol-allserver.sh > /dev/null; then
	kill -9 $(pgrep -f processcontrol-allserver.sh)
	> control.txt
	> dump.txt
	_green "processcontrol进程已终止文件已清空"
else
	_red "processcontrol进程未运行无需终止"
fi

cd /data/server/login/ && ./server.sh stop &
cd /data/server/gate/ && ./server.sh stop &

# 等待Login和Gate服务器停止后再继续执行
wait
_green "login和gate服务器已停止"

for i in {1..5}; do
	_yellow "正在处理server$i"
	cd /data/server$i/game/
	./server.sh flush &

	sleep 60s && ./server.sh stop &
done

# 等待所有并行操作完成
wait
_green "所有Game服务器已完成Flush和Stop操作"