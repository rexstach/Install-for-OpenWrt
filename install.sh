#!/bin/sh

PKG_MANAGER=""
PKG_EXT=""

URL_PODKOP="https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh"
URL_PODKOP2="https://mirror.podkop.net/urjw/scripts/bootstrap.sh"
NAME_SCRIPT="podkop_install"

URL_SING_BOX="https://sing-box.app/install.sh"
NAME_SCRIPT_SIN="sing-box.install"



VERSION="1.13.18"  # значение по умолчанию

# цикл проверяет наличие аргументов для установки при необходимости нужной версии sing_box
while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        echo "Ошибка: укажите значение после --version" >&2
        exit 1
      fi
      VERSION=$2
      shift 2
      ;;
    --version=*)
      VERSION=${1#*=}
      shift
      ;;
    *)
      echo "Неизвестный аргумент: $1" >&2
      exit 1
      ;;
  esac
done

echo " Будет установлена версия sing_box : $VERSION"



run_install_podkop() {
#   curl -sL "$URL_PODKOP" -o /tmp/podkop_install.sh
    wget -qO /tmp/"$NAME_SCRIPT".sh "$URL_PODKOP2"
    if [ -f /tmp/"$NAME_SCRIPT".sh ]; then
       chmod +x /tmp/"$NAME_SCRIPT".sh
       sh /tmp/"$NAME_SCRIPT".sh
       rm /tmp/"$NAME_SCRIPT".sh

    else
      echo " Не удалось скачать скрипт $NAME_SCRIPT"

      return 1
fi



}

run_install_singbox() {
#   curl -sL "$URL_PODKOP" -o /tmp/podkop_install.sh
    wget -qO /tmp/"$NAME_SCRIPT_SIN".sh "$URL_SING_BOX"
    if [ -f /tmp/"$NAME_SCRIPT_SIN".sh ]; then
       chmod +x /tmp/"$NAME_SCRIPT_SIN".sh
       sh /tmp/"$NAME_SCRIPT_SIN".sh --version "$VERSION"
       rm /tmp/"$NAME_SCRIPT_SIN".sh
       sing-box version
       echo "waiting 7 seconds"
       sleep 7
    else
      echo " Не удалось скачать скрипт $NAME_SCRIPT_SIN"

      return 1
fi



}



detect_package_manager() {
     if command -v apk >/dev/null 2>&1; then
        printf '\033[1;33mPKG_MANAGER\033[0m is apk\n'
        PKG_MANAGER="apk"
        echo $PKG_MANAGER
        PKG_EXT="apk"
     elif command -v opkg >/dev/null 2>&1; then
        printf '\033[1;33mPKG_MANAGER\033[0m is opkg\n'
        PKG_MANAGER="opkg"
        PKG_EXT="opkg"
     else 
        printf '\033[1;33mNo supported package manager found (apk/opkg).\033[0m\n'
        exit 1
     fi
}

pkg_update(){
    if [ "$PKG_MANAGER" = "apk" ]; then
       apk update || echo "Error: apk update failed"
    else 
       opkg update || echo "Error: opkg update failed"
    fi
}

is_pkg_installed(){
    pkg_name="$1"
    if [ "$PKG_MANAGER" = "apk" ]; then
       apk info -e "$pkg_name" >/dev/null 2>&1
    else 
       opkg list-installed 2>/dev/null | grep -q "^${pkg_name} "
    fi
}

install_local_pkg() {
      pkg_file="$1"
      if [ "$PKG_MANAGER" = "apk" ]; then
         apk  add "$pkg_file"
      else
         opkg install "$pkg_file"
     fi
}

add_new_interface () {
 local name_interface="$1"
 
 # 1. Проверка на наличие аргумента
 if [[ -z "$name_interface" ]]; then
     echo "Error: do not set name of interface." 1>&2
     return 1
 fi
# 2. Проверка: не существует ли уже такой интерфейс (опционально)
    if uci get network."$name_interface" >/dev/null 2>&1; then
        echo "Предупреждение: Интерфейс $name_interface уже существует. Перезаписываю..."
    fi

    echo "Настройка интерфейса $name_interface..."

    # 3. Выполнение команд с проверкой каждой из них
    # Используем оператор && (выполнить следующее, если предыдущее успешно)
    if uci set network."$name_interface"="interface" && \
       uci set network."$name_interface".proto="wireguard" && \
       uci commit network; then
        
        echo "Конфигурация $name_interface успешно сохранена."
    else
        echo "Ошибка: Не удалось настроить интерфейс $name_interface через UCI." >&2
        return 1
    fi


}

   
restart_network() {
     if service network restart; then
        echo "Сеть перезапущена."
    else
        echo "Ошибка при перезапуске сети." >&2
        return 1
   fi
}

setup_firewall_awg_for_local() {
   printf '\033[1;31mConfigure Firewall for wg0.\033[0m\n'
   

   { 
      #Zone
    uci set firewall.wg0=zone
    uci set firewall.wg0.name='wg0'
    uci set firewall.wg0.input='REJECT'
    uci set firewall.wg0.output='ACCEPT'
    uci set firewall.wg0.mtu_fix='1'
    uci set firewall.wg0.masq='1'
    uci add_list firewall.wg0.network='wg0'

     # Forwarding
        uci add firewall forwarding
        uci set firewall.@forwarding[-1].src='lan'
        uci set firewall.@forwarding[-1].dest='wg0'


        uci commit firewall
    } || {
        echo "Ошибка при настройке UCI firewall" >&2
        return 1
    }
    }

setup_firewall_awg_for_remote() {
   printf '\033[1;31mConfigure Firewall for wg0.\033[0m\n'
   

   { 
      #Zone
    uci set firewall.wg0=zone
    uci set firewall.wg0.name='wg0'
    uci set firewall.wg0.input='REJECT'
    uci set firewall.wg0.output='ACCEPT'
    uci set firewall.wg0.mtu_fix='1'
    uci set firewall.wg0.masq='1'
    uci add_list firewall.wg0.network='wg0'

     # Forwarding
        uci add firewall forwarding
        uci set firewall.@forwarding[-1].src='lan'
        uci set firewall.@forwarding[-1].dest='wg0'

        # Правило HTTP
        uci add firewall rule
        uci set firewall.@rule[-1].name='allow_http'
        uci set firewall.@rule[-1].src='wg0'
        uci set firewall.@rule[-1].target='ACCEPT'
        uci set firewall.@rule[-1].dest_port='80'
        uci add_list firewall.@rule[-1].proto='tcp'
        uci add_list firewall.@rule[-1].proto='udp'
        uci add_list firewall.@rule[-1].src_ip='10.0.0.5'

        # Правило SSH
        uci add firewall rule
        uci set firewall.@rule[-1].name='allow_ssh'
        uci set firewall.@rule[-1].src='wg0'
        uci set firewall.@rule[-1].dest_port='22'
        uci set firewall.@rule[-1].target='ACCEPT'
        uci add_list firewall.@rule[-1].src_ip='10.0.0.5/24'

        uci commit firewall
    } || {
        echo "Ошибка при настройке UCI firewall" >&2
        return 1
    }
    

    /etc/init.d/firewall restart
     

}
#---------------------------------------------------------

detect_package_manager

pkg_update





if is_pkg_installed "wireguard-tools"; then
   printf '\033[1;31mwireguard-tools is installed.\033[0m\n'
else 
   echo "wireguard-tools not installed"
   install_local_pkg "wireguard-tools"
fi

if is_pkg_installed "luci-proto-wireguard"; then
   printf '\033[1;31mluci-proto-wireguard is installed.\033[0m\n'
else 
   echo "luci-proto-wireguard not installed"
   install_local_pkg "luci-proto-wireguard"
fi

 printf "\033[32;1mНастроить роутер как (по умолчан локал):\n 1.локальный\n 2.удаленный  \033[0m\n"
        read ROUTER_TYPE </dev/tty
        ROUTER_TYPE=${ROUTER_TYPE:-1}
          if [ "$ROUTER_TYPE" = "1" ]; then
            printf "\033[1;33mВы выбрали локальный\033[0m\n"
          add_new_interface wg0
          setup_firewall_awg_for_local
          

          elif [ "$ROUTER_TYPE" = "2" ]; then    
            printf "\033[1;33mВы выбрали удаленный\033[0m\n"
          add_new_interface wg0
          setup_firewall_awg_for_remote
          
          else 
            printf '\033[1;33mError incorrect choice.\033[0m\n'
        exit 1
          fi
printf '\033[1;33mINSTALL SING_BOX WAITING..\033[0m\n'
sleep 1
run_install_singbox

printf '\033[1;33mINSTALL PODKOP WAITING..\033[0m\n'
sleep 1
run_install_podkop
