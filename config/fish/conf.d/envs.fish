set -gx PATH $HOME/.cargo/bin $PATH
set -gx PATH $HOME/.local/bin $PATH
set -gx SUDO_EDITOR "$EDITOR"
set -gx BAT_THEME ansi
set -g fish_greeting
set -gx KITTY_WINDOW_ID 1

## Tmux
set -x TMUX_SESSIONIZER_CONFIG_FILE ~/.tmux/configs/tmux-sessionizer

# History configuration - match bash HISTSIZE
set -g fish_history_max_size 32768

# fzf configuration - use default layout (opens above prompt)
set -gx FZF_DEFAULT_OPTS '--cycle --layout=default --height=90% --preview-window=wrap --marker="*"'

# Ensure fzf history search shows preview (empty to not override the built-in preview)
set -gx fzf_history_opts
