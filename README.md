```shell
bash <(wget -qO- https://raw.githubusercontent.com/honeok8s/shell/main/honeok.sh)
```

## Serverstatus探针，客户端探针存活监控
* 项目地址：https://github.com/cppla/serverstatus
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

curl -fsSL -O https://raw.githubusercontent.com/honeok8s/shell/main/nginx/logrotate_ngx.sh && chmod +x ./logrotate_ngx.sh
```

## JDS Games CentOS7游戏服务器组件和服务管理脚本
```shell
bash <(wget -qO- https://raw.githubusercontent.com/honeok8s/shell/main/jds/server_manager_main_7.27.sh)
```