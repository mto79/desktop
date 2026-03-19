function tdl
    # Usage check
    if test (count $argv) -lt 1
        echo "Usage: tdl <c|cx|codex|other_ai> [<second_ai>]"
        return 1
    end

    # Ensure we're inside tmux
    if test -z "$TMUX"
        echo "You must start tmux to use tdl."
        return 1
    end

    set current_dir (pwd)
    set ai $argv[1]
    set ai2 $argv[2]

    # Use current pane
    set editor_pane $TMUX_PANE

    # Name window after directory
    tmux rename-window -t $editor_pane (basename $current_dir)

    # Bottom pane (15%)
    tmux split-window -v -p 15 -t $editor_pane -c $current_dir

    # Right pane (30%) - capture pane id
    set ai_pane (tmux split-window -h -p 30 -t $editor_pane -c $current_dir -P -F '#{pane_id}')

    # Optional second AI
    if test -n "$ai2"
        set ai2_pane (tmux split-window -v -t $ai_pane -c $current_dir -P -F '#{pane_id}')
        tmux send-keys -t $ai2_pane "$ai2" C-m
    end

    # Run AI
    tmux send-keys -t $ai_pane "$ai" C-m

    # Run editor
    if test -n "$EDITOR"
        tmux send-keys -t $editor_pane "$EDITOR ." C-m
    else
        tmux send-keys -t $editor_pane "nvim ." C-m
    end

    # Focus editor pane
    tmux select-pane -t $editor_pane
end
