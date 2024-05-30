#!/bin/bash

# ┏━━━┳━━┳━┓┏━┳━━━┳┓╋╋┏━━┳━┓┏━┓
# ┗┓┏┓┣┫┣┫┃┗┛┃┃┏━━┫┃╋╋┗┫┣┻┓┗┛┏┛
# ╋┃┃┃┃┃┃┃┏┓┏┓┃┗━━┫┃╋╋╋┃┃╋┗┓┏┛
# ╋┃┃┃┃┃┃┃┃┃┃┃┃┏━━┫┃╋┏┓┃┃╋┏┛┗┓
# ┏┛┗┛┣┫┣┫┃┃┃┃┃┃╋╋┃┗━┛┣┫┣┳┛┏┓┗┓
# ┗━━━┻━━┻┛┗┛┗┻┛╋╋┗━━━┻━━┻━┛┗━┛
# The program was created by DIMFLIX
# https://github.com/DIMFLIX-OFFICIAL/rofi-openvpn


VPN_DIR="$HOME/.rofivpnmenu/vpns"
PID_DIR="$HOME/.rofivpnmenu/pids"
VPN_CONNECTED_ICON=" "
POLYBAR_VPN_CONNECTED_ICON="%{F#A3BE8C}󰯄%{F-}"
POLYBAR_VPN_DISCONNECTED_ICON="%{F#D35F5E}󰯄%{F-}"

# Создание директорий для хранения конфигураций и PID файлов, если они не существуют
mkdir -p "$VPN_DIR" "$PID_DIR"КУ

# Функция для загрузки конфигурации
upload_config() {
  CONFIGS=$(zenity --file-selection --multiple --separator="|" \
                   --title="Select VPN configurations" \
                   --file-filter="OpenVPN configuration files | *.ovpn")
  if [ $? -eq 0 ]; then
    IFS='|' read -ra ADDR <<< "$CONFIGS"
    for i in "${ADDR[@]}"; do
      # Проверяем, что файл имеет расширение .ovpn
      if [[ $i == *.ovpn ]]; then
        cp "$i" "$VPN_DIR"
        notify-send "OpenVPN" "Configuration files have been successfully added!"
      else
        zenity --error --text="Only files with the extension .ovpns are allowed to download."
      fi
    done
  fi
}

# Функция для удаления конфигурации VPN
delete_vpn_config() {
  SELECTED_VPN="$1"

  # Находим файл с PID
  PID_FILE="$PID_DIR/$SELECTED_VPN.pid"

  # Если файл с PID существует, читаем PID и принудительно завершаем процесс
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if [ -n "$PID" ]; then
      kill -9 "$PID"
    fi

    # Удаляем файл с PID
    rm -f "$PID_FILE"
  fi

  # Удаляем файл конфигурации VPN
  VPN_CONFIG_FILE="$VPN_DIR/$SELECTED_VPN"
  if [ -f "$VPN_CONFIG_FILE" ]; then
    rm -f "$VPN_CONFIG_FILE"
  fi

  notify-send "OpenVPN" "The $VPN_PID configuration has been successfully deleted!"
}

# Функция для отключения всех активных VPN подключений
disconnect_all_vpns() {
  for PID_PATH in "$PID_DIR"/*.pid; do
    # Если путь не существует, пропускаем итерацию
    [[ ! -e $PID_PATH ]] && continue

    VPN_PID=$(basename "$PID_PATH" .pid) # Получаем только имя файла VPN без расширения .pid
    PID=$(cat "$PID_PATH")
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
      sudo -S kill "$PID"
      notify-send "OpenVPN" "Disconnected from $VPN_PID"
    fi
    rm -f "$PID_PATH"
  done
}

# Функция для переключения VPN (подключиться/отключиться)
toggle_vpn() {
  VPN="$1"
  PID_FILE="$PID_DIR/$VPN.pid"

  if [ -f "$PID_FILE" ]; then
    # Если уже подключены к этому VPN, отключаемся
    PID=$(cat "$PID_FILE")
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
      sudo -S kill "$PID"
    fi
    rm -f "$PID_FILE"
    notify-send "OpenVPN" "Disconnected from $VPN"
  else
    # Запрашиваем пароль sudo с помощью rofi
    PASSWORD=$(rofi -dmenu -password -p "Enter the sudo password:")

    # Проверяем, был ли ввод отменен
    if [ $? -ne 0 ]; then
      notify-send "OpenVPN" "Connection canceled"
      return
    fi

	# Отключаем все активные VPN перед подключением к новому
	disconnect_all_vpns

    echo $PASSWORD | sudo -S nohup openvpn --config "$VPN_DIR/$VPN" >/dev/null 2>&1 &
    PID=$!
    echo $PID > "$PID_FILE"
    notify-send "OpenVPN" "Connecting to $VPN initiated"
  fi
}

# Функция для отображения меню действий
vpn_action_menu() {
  VPN="$1"
  PID_FILE="$PID_DIR/$VPN.pid"
  ACTIONS="  Connect\n  Delete the config file"

  if [ -f "$PID_FILE" ]; then
    ACTIONS="  Disconnect\n  Delete the config file"
  fi

  ACTION=$(echo -e "$ACTIONS" | rofi -dmenu -p "Action with $VPN:")

  if [ $? -eq 0 ]; then
    case "$ACTION" in
      "  Connect"|"  Disconnect")
        toggle_vpn "$VPN"
        ;;
      "  Delete the config file")
        delete_vpn_config "$VPN"
        ;;
    esac
  fi
}

# Функция для отображения меню Rofi
show_rofi_menu() {
  VPN_LIST=("$VPN_DIR"/*.ovpn) # Читаем список .ovpn файлов в массив
  MENU_ITEMS=("󰩍  Upload configuration files") # Начинаем массив элементов меню с опции загрузки конфига

  # Проверяем, существуют ли конфигурационные файлы .ovpn
  if compgen -G "$VPN_DIR"/*.ovpn > /dev/null; then
    for VPN_PATH in "${VPN_LIST[@]}"; do
      # Если путь не существует, пропускаем итерацию
      [[ ! -e $VPN_PATH ]] && continue

      VPN=$(basename "$VPN_PATH") # Получаем только имя файла
      VPN_STATUS=""
      PID_FILE="$PID_DIR/$VPN.pid"
      if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        # Проверяем, активен ли процесс с таким PID
        if [ -n "$PID" ] && ps -p $PID > /dev/null; then
          # Получаем полную команду запуска процесса
          COMMAND=$(ps -p $PID -o args=)
          # Проверяем, содержит ли она упоминание openvpn
          if [[ "$COMMAND" == *"openvpn"* ]]; then
            VPN_STATUS="$VPN_CONNECTED_ICON "
          fi
        else
          # Если процесса нет, удаляем файл PID
          rm -f "$PID_FILE"
        fi
      fi
      MENU_ITEMS+=("$VPN_STATUS$VPN")
    done
  fi

  IFS=$'\n' # Устанавливаем внутренний разделитель полей в новую строку
  SELECTED_VPN=$(printf "%s\n" "${MENU_ITEMS[@]}" | rofi -dmenu -p "Select VPN:" -matching fuzzy)

  if [ $? -ne 0 ]; then
    return
  fi

  if [[ "$SELECTED_VPN" == "󰩍  Upload configuration files" ]]; then
    upload_config
    return
  fi

  # Убираем символы галочки и обрабатываем возможные пробелы в имени файла
  SELECTED_VPN="${SELECTED_VPN#$VPN_CONNECTED_ICON }"
  vpn_action_menu "$SELECTED_VPN"
}

# Функция для проверки статуса VPN
vpn_status() {
  local connected=false

  # Проверяем, есть ли активные VPN подключения
  for PID_PATH in "$PID_DIR"/*.pid; do
    [[ ! -e $PID_PATH ]] && continue
    PID=$(cat "$PID_PATH")
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
      connected=true
      break
    fi
  done

  # Выводим соответствующий индикатор
  if $connected; then
    echo "$POLYBAR_VPN_CONNECTED_ICON"
  else
    echo "$POLYBAR_VPN_DISCONNECTED_ICON"
  fi
}

# Обработка аргументов командной строки
case "$1" in
  status)
    vpn_status
    ;;
  *)
    show_rofi_menu
    ;;
esac
