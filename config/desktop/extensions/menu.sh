# Overwrite parts of the desktop-menu with user-specific submenus.
# See $DESKTOP_PATH/bin/desktop-menu for functions that can be overwritten.
#
# WARNING: Overwritten functions will obviously not be updated when desktop changes.
#
# Example of minimal system menu:
#
# show_system_menu() {
#   case $(menu "System" "  Lock\n󰐥  Shutdown") in
#   *Lock*) desktop-lock-screen ;;
#   *Shutdown*) desktop-cmd-shutdown ;;
#   *) back_to show_main_menu ;;
#   esac
# }
