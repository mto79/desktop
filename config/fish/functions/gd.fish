# Remove worktree and branch from within active worktree directory
function gd
    # Ask for confirmation
    if gum confirm "Remove worktree and branch?"
        set cwd (pwd)
        set worktree (basename $cwd)

        # split on first `--`
        set root (string split -- '--' $worktree)[1]
        set branch (string split -- '--' $worktree)[2]

        # Only proceed if root differs from worktree (protect non-worktree dirs)
        if test "$root" != "$worktree"
            cd "../$root"
            git worktree remove $cwd --force
            git branch -D $branch
        end
    end
end
