## VPS工具箱
```shell
bash <(wget -qO- https://raw.githubusercontent.com/honeok8s/shell/main/honeok.sh)
```
```shell
curl -fsSL -O https://raw.githubusercontent.com/honeok8s/shell/main/honeok.sh && chmod +x ./honeok.sh && ./honeok.sh
```
## Docker一键安装
根据IP归属地优化配置文件，安装镜像加速
```shell
bash <(wget -qO- https://raw.githubusercontent.com/honeok8s/shell/main/docker/get-docker.sh)
```
```shell
curl -fsSL https://raw.githubusercontent.com/honeok8s/shell/main/docker/get-docker.sh | bash -
```
下载到本地
```shell
curl -fsSL -O https://raw.githubusercontent.com/honeok8s/shell/main/docker/get-docker.sh && chmod +x ./get-docker.sh
```
一键卸载Docker
```shell
./get-docker.sh uninstall
```
## Serverstatus探针，客户端探针存活监控
项目地址：https://github.com/cppla/serverstatus
```shell
# 下载完成后自行修改Server端服务器IP地址

# KVM & XEN
curl -fsSL -O https://raw.githubusercontent.com/honeok8s/shell/main/serverstatus/serverstatus_kvm.sh && chmod +x ./serverstatus_kvm.sh
sed -i 's/127\.0\.0\.1/107.174.0.197/g' ./serverstatus_kvm.sh

# LXC & OpenVZ
curl -fsSL -O https://raw.githubusercontent.com/honeok8s/shell/main/serverstatus/serverstatus_lxc.sh && chmod +x ./serverstatus_lxc.sh
sed -i 's/127\.0\.0\.1/107.174.0.197/g' ./serverstatus_lxc.sh
```
## NGINX日志管理
```shell
# 适用编译安装NGINX及基于NGINX二次开发的高性能WEB服务器日志切割备份删除
# LOG_DIR="/usr/local/nginx/logs"              日志路径可自行定义
# BAK_DIR="/usr/local/nginx/logs/backup"       日志备份路径可自行定义

curl -fsSL -O https://raw.githubusercontent.com/honeok8s/shell/main/nginx/ngx_logrotate.sh && chmod +x ./logrotate_ngx.sh
```

## JDS Games
```shell
bash <(wget -qO- https://raw.githubusercontent.com/honeok8s/shell/main/jds/main.sh)
```
```shell
curl -fsSL -O https://raw.githubusercontent.com/honeok8s/shell/main/jds/main.sh && chmod +x ./main.sh
```