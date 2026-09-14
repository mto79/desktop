# The layout itself lives in bin/desktop-agent-layout, so that the login script and the
# sessionizer can build the same one against a session nobody is attached to. This is
# the version for the pane you are sitting in.
function tdl --description "Lay this window out for a coding agent"
    if test (count $argv) -lt 1
        echo "Usage: tdl <cx|c|x|claude|opencode|codex> [<second_agent>]"
        return 1
    end

    if test -z "$TMUX"
        echo "You must start tmux to use tdl."
        return 1
    end

    desktop-agent-layout $TMUX_PANE $argv
end
