# A command that ran for a while and ended in a tmux tab nobody was looking at gets a mark
# on that tab: done, or failed. desktop-terminal-tabs decides whether anyone was looking;
# all this does is tell it, and only for commands long enough to have been walked away from.
if status is-interactive; and set -q TMUX_PANE; and command -q desktop-terminal-tabs
    function __desktop_tmux_finished --on-event fish_postexec
        set -l code $status
        test "$CMD_DURATION" -ge 10000; or return
        desktop-terminal-tabs finished $TMUX_PANE $code >/dev/null 2>&1 &
        disown 2>/dev/null
    end
end
