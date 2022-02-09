#!/bin/bash

rm -rf $0

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi：${plain} Tập lệnh này phải được chạy với tư cách người dùng root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Phiên bản hệ thống không được phát hiện, vui lòng liên hệ với tác giả kịch bản!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64-v8a"
else
  arch="64"
  echo -e "${red}Không phát hiện được giản đồ, hãy sử dụng lược đồ mặc định: ${arch}${plain}"
fi

echo "Ngành kiến ​​trúc: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "Phần mềm này không hỗ trợ hệ thống 32-bit (x86), vui lòng sử dụng hệ thống 64-bit (x86_64), nếu phát hiện sai, vui lòng liên hệ với tác giả"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui lòng sử dụng CentOS 7 trở lên!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui lòng sử dụng Ubuntu 16 hoặc cao hơn!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui lòng sử dụng Debian 8 trở lên!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
}

install_XrayR() {
    if [[ -e /usr/local/XrayR/ ]]; then
        rm /usr/local/XrayR/ -rf
    fi

    mkdir /usr/local/XrayR/ -p
	cd /usr/local/XrayR/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/AikoCute/XrayR/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Không thể phát hiện phiên bản XrayR, có thể đã vượt quá giới hạn API Github, vui lòng thử lại sau hoặc chỉ định phiên bản XrayR để cài đặt theo cách thủ công${plain}"
            exit 1
        fi
        echo -e "Đã phát hiện phiên bản mới nhất của XrayR:${last_version}，bắt đầu cài đặt"
        wget -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip https://github.com/AikoCute/XrayR/releases/download/${last_version}/XrayR-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Không tải xuống được XrayR, hãy đảm bảo máy chủ của bạn có thể tải xuống tệp Github${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/AikoCute/XrayR/releases/download/${last_version}/XrayR-linux-${arch}.zip"
        echo -e "bắt đầu cài đặt XrayR v$1"
        wget -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống XrayR v$1 không thành công, hãy đảm bảo rằng phiên bản này tồn tại${plain}"
            exit 1
        fi
    fi

    unzip XrayR-linux.zip
    rm XrayR-linux.zip -f
    chmod +x XrayR
    mkdir /etc/XrayR/ -p
    rm /etc/systemd/system/XrayR.service -f
    file="https://raw.githubusercontent.com/AikoCute/XrayR-release/data/XrayR.service"
    wget -N --no-check-certificate -O /etc/systemd/system/XrayR.service ${file}
    #cp -f XrayR.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop XrayR
    systemctl enable XrayR
    echo -e "${green}AikoCute XrayR ${last_version}${plain} Quá trình cài đặt hoàn tất, nó đã được thiết lập để bắt đầu tự động"
    cp geoip.dat /etc/XrayR/
    cp geosite.dat /etc/XrayR/ 

    if [[ ! -f /etc/XrayR/config.yml ]]; then
        cp config.yml /etc/XrayR/
        echo -e ""
        echo -e "Cài đặt mới, vui lòng tham khảo hướng dẫn trước：https://github.com/AikoCute/XrayR，Định cấu hình nội dung cần thiết"
    else
        systemctl start XrayR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR khởi động lại thành công${plain}"
        else
            echo -e "${red}XrayR Có thể không khởi động được, vui lòng sử dụng sau XrayR log Kiểm tra thông tin nhật ký, nếu không khởi động được, định dạng cấu hình có thể đã bị thay đổi, vui lòng vào wiki để kiểm tra：https://github.com/AikoCute/XrayR/wiki${plain}"
        fi
    fi

    if [[ ! -f /etc/XrayR/dns.json ]]; then
        cp dns.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/route.json ]]; then
        cp route.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/XrayR/
    fi
    curl -o /usr/bin/XrayR -Ls https://raw.githubusercontent.com/AikoCute/XrayR-release/data/XrayR.sh
    chmod +x /usr/bin/XrayR
    ln -s /usr/bin/XrayR /usr/bin/xrayr # chữ thường tương thích
    chmod +x /usr/bin/xrayr

        #pannel
    echo "Panel bạn đang sử dụng"
    echo -e "[1] SSpanel"
    echo -e "[2] V2board"
    read -p "Chọn Web Mà bạn sử Dụng:" panel_num
    if [ "$panel_num" == "1" ]; then
    panel_type="SSpanel"
    elif [ "$panel_num" == "2" ]; then
    panel_type="V2board"
    else
        if [ ! $panel_num ]; then 
    panel_type="V2board"
    fi
    echo "panel của bạn là :" ${panel_type}

        #đặt api hostname
    echo "Tên trang Web"
    echo ""
    read -p " Tên miền web : (https://aikocute.com):" api_host
    [ -z "${api_host}" ] && api_host="https://aikocute.com"
    echo "---------------------------"
    echo "Trang web của bạn là: ${api_host}"
    echo "---------------------------"
    echo ""
    #Nếu không nhập, mặc định là :
     if [ ! $api_host ]; then 
    api_host="https://aikocute.com"
    fi

        #đặt api key
    echo "API key"
    echo ""
    read -p " Apikey (web API):" api_key
    [ -z "${api_key}" ] && api_key="adminadminadminadminadmin"
    echo "---------------------------"
    echo "API key của bạn là: ${api_key}"
    echo "---------------------------"
    echo ""
    #nếu không Nhập mặc định là : 
    echo "chọn adminadminadminadminadmin làm mặc định"
    if [ ! $api_key ]; then
    api_key="adminadminadminadminadmin"
    fi

        # Đặt số nút
    echo "Đặt số nút"
    echo ""
    read -p "Vui lòng nhập node ID " node_id
    [ -z "${node_id}" ]
    echo "---------------------------"
    echo "Node ID của bạn đặt là: ${node_id}"
    echo "---------------------------"
    echo ""

        # Chọn một thỏa thuận
    echo "Chọn giao thức (V2ray mặc định)"
    echo ""
    read -p "Vui lòng nhập giao thức bạn đang sử dụng (V2ray, Shadowsocks, Trojan): " node_type
    [ -z "${node_type}" ]
    
    # Nếu không nhập, mặc định là V2ray
    if [ ! $node_type ]; then 
    node_type="V2ray"
    fi

    echo "---------------------------"
    echo "Giao thức bạn chọn là: ${node_type}"
    echo "---------------------------"
    echo ""


    # Writing config.yml
    echo "Đang cố gắng ghi tệp cấu hình ..."
    wget https://raw.githubusercontent.com/AikoCute/XrayR-release/main/config.yml -O /etc/XrayR/config.yml
    sed -i "s|ApiHost:.*|ApiHost: \"${api_host}\"|g" /etc/XrayR/config.yml
    sed -i "s/NodeID:.*/NodeID: ${node_id}/g" /etc/XrayR/config.yml
    sed -i "s/NodeType:.*/NodeType: ${node_type}/g" /etc/XrayR/config.yml
    sed -i "s/ApiKey:.*/ApiKey: ${api_key}/g" /etc/XrayR/config.yml
    sed -i "s|PanelType:.*|PanelType: \"${panel_type}\"|" /etc/XrayR/config.yml
    echo ""
    echo "Đã hoàn tất, đang khởi động lại dịch vụ XrayR ..."

    echo -e ""
    echo "XrayR Cách sử dụng tập lệnh quản lý (tương thích với thực thi xrayr, không phân biệt chữ hoa chữ thường): "
    echo "AikoCute Hột Me"
    echo "------------------------------------------"
    echo "  XrayR                    - Hiển thị menu quản lý (nhiều chức năng hơn)"
    echo "  XrayR start              - Khởi động XrayR"
    echo "  XrayR stop               - Dừng XrayR"
    echo "  XrayR restart            - Khởi động lại XrayR"
    echo "  XrayR status             - Kiểm tra trạng thái XrayR"
    echo "  XrayR enable             - Kích hoạt XrayR"
    echo "  XrayR disable            - Hủy tự động khởi động XrayR"
    echo "  XrayR log                - Xem nhật ký XrayR"
    echo "  XrayR update             - Cập nhật XrayR"
    echo "  XrayR update x.x.x       - Cập nhật phiên bản được chỉ định XrayR"
    echo "  XrayR config             - Hiển thị nội dung tệp cấu hình"
    echo "  XrayR install            - Cài đặt XrayR"
    echo "  XrayR uninstall          - Gỡ cài đặt XrayR"
    echo "  XrayR version            - Xem các phiên bản XrayR"
    echo "  AikoCute Hotme           - Lệnh Này méo có đâu nên đừng sài"
    echo "------------------------------------------"
}

echo -e "${green}bắt đầu cài đặt${plain}"
install_base
install_acme
install_XrayR $1
