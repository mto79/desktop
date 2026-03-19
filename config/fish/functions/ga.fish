# Create a new worktree and branch from within current git directory
function ga
    if test (count $argv) -eq 0
        echo "Usage: ga [branch name]"
        return 1
    end

    set branch $argv[1]
    set base (basename (pwd))
    set path "../$base--$branch"

    git worktree add -b $branch $path
    mise trust $path
    cd $path
end
