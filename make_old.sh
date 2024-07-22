#!/bin/bash

# ANSI颜色码，用于彩色输出
yellow='\033[1;33m'
red='\033[1;31m'
green='\033[1;32m'
cyan='\033[1;36m'
white='\033[0m'

# 安装路径和备份路径
SOFTWARE_DIR="/opt/software"
BACKUP_DIR="/opt/backup"

# 全局变量
MAKE_VERSION=""

# 获取用户输入的 make 版本
get_make_version() {
    local versions=("4.2" "4.3" "4.4")
    local choice

    while true; do
        printf "${cyan}请选择要安装的make版本:${white}\n"
        for i in "${!versions[@]}"; do
            printf "${cyan}%d. %s${white}\n" $((i + 1)) "${versions[i]}"
        done

        printf "${cyan}请输入选项 (1-${#versions[@]}): ${white}"
        read -r choice

        if [[ "$choice" =~ ^[1-${#versions[@]}]$ ]]; then
            MAKE_VERSION="${versions[choice-1]}"
            printf "${green}你选择的版本是 make ${MAKE_VERSION}${white}\n"
            break
        else
            printf "${red}无效的选项, 请重新选择.${white}\n"
        fi
    done
}

# 检查命令是否成功执行
check_command() {
    if [ $? -ne 0 ]; then
        printf "${red}$1${white}\n"
        return 1
    fi
}

# 创建安装目录(如果不存在)
create_software_dir() {
    if [ ! -d "$SOFTWARE_DIR" ]; then
        printf "${yellow}安装路径不存在, 创建路径: ${SOFTWARE_DIR}${white}\n"
        mkdir -p "$SOFTWARE_DIR"
        check_command "创建安装路径失败, 请检查权限或路径"
        printf "${green}安装路径 ${SOFTWARE_DIR} 创建成功.${white}\n"
    fi
}

# 备份当前环境的 make
backup_current_make() {
    if command -v make &> /dev/null 2>&1; then
        local current_version=$(make --version | head -n 1 | awk '{print $3}')
        printf "${yellow}检测到现有的make版本 (${current_version}), 正在备份.${white}\n"

        local make_backup_dir="${BACKUP_DIR}/make_backup"
        local backup_bin_dir="${make_backup_dir}/bin"
        local backup_man_dir="${make_backup_dir}/man"
        local backup_etc_dir="${make_backup_dir}/etc"

        # 备份目录列表
        local backup_dirs=("$backup_bin_dir" "$backup_man_dir" "$backup_etc_dir")

        # 遍历目录列表并创建目录(如果不存在)
        for dir in "${backup_dirs[@]}"; do
            if [ ! -d "$dir" ]; then
                mkdir -p "$dir"
                check_command "创建备份目录 $dir 失败."
                printf "${green}备份目录 $dir 创建成功.${white}\n"
            else
                printf "${red}备份目录 $dir 已存在.${white}\n"
            fi
        done

        # 备份可执行文件
        \cp -fr "$(command -v make)" "$backup_bin_dir/"
        check_command "备份 make 可执行文件失败."
        
        # 备份手册页(如果存在)
        if [ -d "/usr/share/man/man1" ]; then
            \cp -fr /usr/share/man/man1/make.1* "$backup_man_dir/" 2>/dev/null
        fi
        
        # 备份配置文件(如果存在)
        if [ -d "/etc/make" ]; then
            \cp -fr /etc/make "$backup_etc_dir/"
        fi
        
        printf "${green}现有的make环境已备份到: ${make_backup_dir}.${white}\n"
    else
        printf "${yellow}当前环境中没有检测到make.${white}\n"
    fi
}

# 还原备份的 make
restore_backup_make() {
    local make_backup_dir="${BACKUP_DIR}/make_backup"
    local backup_bin_dir="${make_backup_dir}/bin"
    local backup_man_dir="${make_backup_dir}/man"
    local backup_etc_dir="${make_backup_dir}/etc"

    if [ -d "$backup_bin_dir" ]; then
        printf "${yellow}正在还原备份的 make...${white}\n"
        
        # 还原可执行文件
        if [ -f "$backup_bin_dir/make" ]; then
            \cp -fr "$backup_bin_dir/make" "$(command -v make)"
            check_command "还原 make 可执行文件失败."
        fi
        
        # 还原手册页
        if [ -d "$backup_man_dir" ]; then
            \cp -fr "$backup_man_dir/make.1*" /usr/share/man/man1/ 2>/dev/null
        fi

        # 还原配置文件
        if [ -d "$backup_etc_dir" ]; then
            \cp -fr "$backup_etc_dir/make" /etc/
        fi

        printf "${green}备份的 make 环境已成功还原。${white}\n"
    else
        printf "${yellow}没有找到备份的 make 环境。${white}\n"
    fi
}

# 安装 make
install_make() {
    if [ -z "$MAKE_VERSION" ]; then
        printf "${red}请先选择要安装的 make 版本。${white}\n"
        return 1
    fi

    create_software_dir
    # 在安装新 make 时备份旧环境的 make
    backup_current_make

    local make_source_dir="${SOFTWARE_DIR}/make-${MAKE_VERSION}"
    local make_tar="${SOFTWARE_DIR}/make-${MAKE_VERSION}.tar.gz"
    
    printf "${yellow}安装 make ${MAKE_VERSION}...${white}\n"

    cd "$SOFTWARE_DIR" || { printf "${red}无法进入目录 ${SOFTWARE_DIR}.${white}\n"; return 1; }

    # 下载 make 源代码
    wget "https://mirrors.aliyun.com/gnu/make/make-${MAKE_VERSION}.tar.gz" -O "${make_tar}"
    check_command "下载 make 源代码失败。"

    # 解压源代码
    tar xvf "${make_tar}"
    check_command "解压 make 源代码失败。"

    cd "make-${MAKE_VERSION}/" || { printf "${red}无法进入 make-${MAKE_VERSION} 目录.${white}\n"; return 1; }

    # 创建构建目录
    mkdir build
    cd build || { printf "${red}无法进入 build 目录.${white}\n"; return 1; }

    # 配置、编译并安装
    ../configure --prefix=/usr
    check_command "配置 make 失败。"

    make
    check_command "编译 make 失败。"

    make install
    check_command "安装 make 失败。"

    printf "${green}make ${MAKE_VERSION} 安装成功！${white}\n"
}

# 卸载 make
uninstall_make() {
    local make_source_dir="${SOFTWARE_DIR}/make-${MAKE_VERSION}"

    printf "${yellow}卸载 make ${MAKE_VERSION}...${white}\n"

    if [ -d "$make_source_dir" ]; then
        cd "$make_source_dir/build" || { printf "${red}无法进入 make-${MAKE_VERSION} 构建目录.${white}\n"; return 1; }

        # 尝试使用 make uninstall 卸载
        make uninstall
        check_command "卸载 make 失败。"

        # 删除安装目录
        rm -rf "$make_source_dir"
        printf "${green}make ${MAKE_VERSION} 卸载成功。${white}\n"

        # 还原备份的旧版本
        restore_backup_make
    else
        printf "${red}make ${MAKE_VERSION} 未安装或无法找到安装目录.${white}\n"
        return 1
    fi
}

# 管理 Make 安装和卸载的函数
make_menu() {
    while true; do
        clear
        printf "${cyan}=================================${white}\n"
        printf "${cyan}       Make 管理菜单             ${white}\n"
        printf "${cyan}=================================${white}\n"
        printf "${cyan}1. 选择 make 版本并安装${white}\n"
        printf "${cyan}2. 卸载 make${white}\n"
        printf "${cyan}3. 退出${white}\n"
        printf "${cyan}=================================${white}\n"
        printf "${cyan}请输入选项并按回车: ${white}"
        read -r choice

        case "$choice" in
            1)
                get_make_version
                install_make
                ;;
            2)
                uninstall_make
                ;;
            3)
                printf "${green}退出程序。${white}\n"
                break
                ;;
            *)
                printf "${red}无效的选项，请重新选择。${white}\n"
                ;;
        esac
        printf "${cyan}按任意键继续.${white}\n"
        read -n 1 -s -r
    done
}

# 运行菜单
make_menu
