if status is-interactive
    # Commands to run in interactive sessions can go here

    # SSH_AUTH_SOCK comes from the systemd user manager (see
    # config/environment.d/ssh-agent.conf and config/systemd/user/ssh-agent.service),
    # so every process in the session shares one agent -- terminals and the
    # desktop alike. Fall back to starting our own only outside that session,
    # e.g. an SSH login to this box.
    if not set -q SSH_AUTH_SOCK
        set -gx SSH_AUTH_SOCK $XDG_RUNTIME_DIR/ssh-agent.socket
    end

    # ssh-add -l exits 0 with keys, 1 when the agent answers but holds none,
    # and 2 when it cannot connect. Only 2 means we need an agent. `test -S`
    # used to stand in for this, but it is true for the leftover socket file
    # of an agent that already died, so a dead agent was never restarted.
    ssh-add -l >/dev/null 2>&1
    if test $status -eq 2
        rm -f $SSH_AUTH_SOCK
        echo "🔑 Starting ssh-agent..."
        ssh-agent -a $SSH_AUTH_SOCK >/dev/null
    end

    # Report what the agent actually is. The old version printed "ready" even
    # when it could not be reached, which is how a dead agent went unnoticed
    # for ten days.
    ssh-add -l >/dev/null 2>&1
    switch $status
        case 0
            echo "🧠 SSH agent ready, keys loaded:"
            ssh-add -l
        case 1
            echo "🧠 SSH agent ready, no keys loaded yet."
        case '*'
            echo "⚠️  SSH agent unreachable at $SSH_AUTH_SOCK"
    end
end
