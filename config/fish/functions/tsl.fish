function tsl
    # Usage check
    if test (count $argv) -lt 2
        echo "Usage: tsl <pane_count> <command>"
        return 1
    end

    # Ensure we're inside tmux
    if test -z "$TMUX"
        echo "You must start tmux to use tsl."
        return 1
    end

    set count $argv[1]
    set cmd $argv[2]
    set current_dir (pwd)
    set -a panes

    # Rename window after current directory
    tmux rename-window -t $TMUX_PANE (basename $current_dir)

    # Add current pane
    set panes $TMUX_PANE

    # Split panes until we have enough
    while (count $panes) -lt $count
        set split_target $panes[-1]
        set new_pane (tmux split-window -h -t $split_target -c $current_dir -P -F '#{pane_id}')
        set panes $panes $new_pane
        tmux select-layout -t $panes[1] tiled
    end

    # Run the command in each pane
    for pane in $panes
        tmux send-keys -t $pane $cmd C-m
    end

    # Focus the first pane
    tmux select-pane -t $panes[1]
end
