function tdlm
    # Usage check
    if test (count $argv) -lt 1
        echo "Usage: tdlm <c|cx|codex|other_ai> [<second_ai>]"
        return 1
    end

    # Ensure we're inside tmux
    if test -z "$TMUX"
        echo "You must start tmux to use tdlm."
        return 1
    end

    set ai $argv[1]
    set ai2 $argv[2]
    set base_dir (pwd)
    set first true

    # Rename session to current directory name (replace dots/colons with dashes)
    tmux rename-session (basename $base_dir | string replace -a '.' '-' | string replace -a ':' '-')

    # Iterate over subdirectories
    for dir in $base_dir/*/
        if test -d $dir
            set dirpath (string trim -r '/' $dir)

            if test $first = true
                # Reuse current window for first subdir
                tmux send-keys -t $TMUX_PANE "cd '$dirpath' && tdl $ai $ai2" C-m
                set first false
            else
                # New window per subdir
                set pane_id (tmux new-window -c $dirpath -P -F '#{pane_id}')
                tmux send-keys -t $pane_id "tdl $ai $ai2" C-m
            end
        end
    end
end
