#!/usr/bin/env bash
# Give people a chance to retry running the installation
catch_errors() {
  echo -e "\n\e[31mInstallation failed!\e[0m"
  echo
  echo "This command halted with exit code $?:"
  echo "$BASH_COMMAND"
  echo
  if command -v gum >/dev/null && gum confirm "Retry installation?"; then
    bash ~/.local/share/desktop/install.sh
  else
    echo "You can retry later by running: bash ~/.local/share/desktop/install.sh"
  fi
}

trap catch_errors ERR
