function fish_user_key_bindings
    # Enable vi mode
    fish_vi_key_bindings

    # Ctrl-A goes to beginning of line in insert mode
    bind -M insert \ca beginning-of-line

    bind -M insert \ca beginning-of-line # Ctrl-A → start of line
    bind -M insert \ce end-of-line # Ctrl-E → end of line
    bind -M insert \ck kill-line # Ctrl-K → delete to end of line
    bind -M insert \cu backward-kill-line # Ctrl-U → delete to start of line
    # Your custom key
    bind ctrl-alt-f _fzf_search_directory
end
