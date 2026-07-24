#!/usr/bin/env bash
#
# modules/vps.sh
# "VPS Manager" menu. Each option delegates to a dedicated script under
# vps/ so the individual operations can also be run standalone
# (e.g. from cron for scheduled backups).

vps_manager_menu() {
    while true; do
        clear
        print_header "VPS MANAGER"
        print_menu_item "1" "Create VPS"
        print_menu_item "2" "Start VPS"
        print_menu_item "3" "Stop VPS"
        print_menu_item "4" "Restart VPS"
        print_menu_item "5" "Delete VPS"
        print_menu_item "6" "List VPS"
        print_menu_item "7" "Console"
        print_menu_item "8" "Backup"
        print_menu_item "9" "Restore"
        print_menu_item "0" "Back to Main Menu"
        print_line "-"

        read -r -p "$(echo -e "${C_GREEN}Select an option: ${C_RESET}")" choice
        echo

        case "$choice" in
            1) bash "$VPS_DIR/create.sh" ;;
            2) bash "$VPS_DIR/start.sh" ;;
            3) bash "$VPS_DIR/stop.sh" ;;
            4) bash "$VPS_DIR/restart.sh" ;;
            5) bash "$VPS_DIR/delete.sh" ;;
            6) bash "$VPS_DIR/list.sh" ;;
            7) bash "$VPS_DIR/console.sh" ;;
            8) bash "$VPS_DIR/backup.sh" ;;
            9) bash "$VPS_DIR/restore.sh" ;;
            0) return ;;
            *) msg_error "Invalid option." ;;
        esac

        press_enter_to_continue
    done
}

vps_manager_menu
