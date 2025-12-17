set -gx PATH $HOME/.cargo/bin $PATH
set -gx PATH $HOME/.local/bin $PATH
set -gx SUDO_EDITOR "$EDITOR"
set -gx BAT_THEME ansi
set -g fish_greeting
set -gx KITTY_WINDOW_ID 1

## Terraform/Opentofu
### DigitalOcean
# set -x TF_VAR_digitalocean_api_token dop_xxxxxxx
### Pve
set -x TF_VAR_pve_api_url https://mto-pve.mto.lan:8006/
set -x TF_VAR_pve_api_token terraform@pve!provider=295520fc-9571-4b4e-b0b0-17ad7b6962b1

## Git
# set -g -x GITLAB_ACCESS_TOKEN glpat-xxxxxxxxxxxxx

## Scans
set -x SCANS_DIR ~/Data/MTO/Documents/Scans
set -x SCANS_TMP_DIR ~/Data/MTO/Documents/Scans/tmp

## Tmux
set -x TMUX_SESSIONIZER_CONFIG_FILE ~/.tmux/configs/tmux-sessionizer

# History configuration - match bash HISTSIZE
set -g fish_history_max_size 32768

# fzf configuration - use default layout (opens above prompt)
set -gx FZF_DEFAULT_OPTS '--cycle --layout=default --height=90% --preview-window=wrap --marker="*"'

# Ensure fzf history search shows preview (empty to not override the built-in preview)
set -gx fzf_history_opts
