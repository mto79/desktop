if status is-interactive
    # Commands to run in interactive sessions can go here

    # Use a persistent SSH_AUTH_SOCK so multiple terminals share the same agent
    set -Ux SSH_AUTH_SOCK ~/.ssh/ssh-agent.sock

    # Start ssh-agent if not already running
    if not test -S $SSH_AUTH_SOCK
        echo "🔑 Starting ssh-agent..."
        ssh-agent -a $SSH_AUTH_SOCK >/dev/null
    end

    # Optional: automatically list loaded keys for debugging
    if ssh-add -l >/dev/null 2>&1
        echo "🧠 SSH agent ready, keys loaded:"
        ssh-add -l
    else
        echo "🧠 SSH agent ready, no keys loaded yet."
    end
end
