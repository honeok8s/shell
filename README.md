## Serverstatus探针，客户端探针存活监控
* 项目地址：https://github.com/cppla/serverstatus
```shell
# 下载完成后自行修改Server端服务器IP地址

# KVM & XEN
sed -i 's/127\.0\.0\.1/107.174.0.197/g' ./serverstatus_kvm.sh
curl -fsSL -O https://raw.githubusercontent.com/honeok8s/shell/main/serverstatus_kvm.sh && chmod +x ./serverstatus_kvm.sh

# LXC & OpenVZ
sed -i 's/127\.0\.0\.1/107.174.0.197/g' ./serverstatus_lxc.sh
curl -fsSL -O https://raw.githubusercontent.com/honeok8s/shell/main/serverstatus_lxc.sh && chmod +x ./serverstatus_lxc.sh
```
## NGINX日志管理
```shell
# 适用编译安装NGINX及基于NGINX二次开发的高性能WEB服务器日志切割备份删除
# LOG_DIR="/usr/local/nginx/logs"              日志路径可自行定义
# BAK_DIR="/usr/local/nginx/logs/backup"       日志备份路径可自行定义

curl -fsSL -O https://raw.githubusercontent.com/honeok8s/shell/main/logrotate_ngx.sh && chmod +x ./logrotate_ngx.sh
```
## Docker日志截断
```shell
# 自用
curl -fsSL -O https://raw.githubusercontent.com/honeok8s/shell/main/docker_clear_log_own.sh && chmod +x ./docker_clear_log_own.sh
(crontab -l;echo "0 0 * * * /root/docker_clear_log_own.sh >/dev/null 2>&1 ") | crontab

# 生产
curl -fsSL -O https://raw.githubusercontent.com/honeok8s/shell/main/docker_clear_log_pro.sh && chmod +x ./docker_clear_log_pro.sh
(crontab -l;echo "0 0 * * * /root/docker_clear_log_pro.sh >/dev/null 2>&1 ") | crontab
```

## JDS Games CentOS7游戏服务器组件和服务管理脚本
```shell
bash <(wget -qO- https://raw.githubusercontent.com/honeok8s/shell/main/server_manager_main.sh)
                                              或
curl -fsSL https://raw.githubusercontent.com/honeok8s/shell/main/server_manager_main.sh | bash -
```