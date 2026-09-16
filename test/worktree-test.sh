#!/usr/bin/env bash
# A task in its own worktree, branch and window -- and, more to the point, getting rid of one
# without losing work.
#
# Everything a task can lose is guarded: a worktree is never removed while its changes are
# uncommitted, its push failed, or its review could not be opened, and a branch is only
# deleted once the forge says its review was merged, because a branch gone from origin may
# equally have been closed and thrown away. The untracked files a task needs are linked in,
# and a .worktree arriving inside a cloned repository may neither run commands nor reach
# outside it.
#
# A bare repository stands in for the remote, glab and gh are stubs that remember what they
# were asked, and tmux is a server of its own. Nothing here reaches GitLab, GitHub, or the
# tmux server the suite may be running inside.
source "$(dirname "$0")/lib.sh"

require git || finish
require tmux || finish
require jq || finish

WT="$ROOT/bin/desktop-worktree"

sandbox=$(mktemp -d)
server="worktree-test-$$"
TMUX_BIN=$(command -v tmux)
cleanup() {
  "$TMUX_BIN" -L "$server" kill-server 2>/dev/null
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$server"
  rm -rf "$sandbox"
}
trap cleanup EXIT

# Git with no user configuration: no signing, no URL rewriting, no hooks from outside.
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$sandbox/gitconfig"
git config --global user.name Test
git config --global user.email test@example.com
git config --global init.defaultBranch main
git config --global advice.detachedHead false

export XDG_CONFIG_HOME="$sandbox/config" DESKTOP_WORKTREE_NO_SWITCH=1
unset TMUX TMUX_PANE

stubs="$sandbox/stubs"
forge="$sandbox/forge"
mkdir -p "$stubs" "$forge"

cat >"$stubs/tmux" <<STUB
#!/usr/bin/env bash
exec "$TMUX_BIN" -L "$server" "\$@"
STUB
printf '#!/usr/bin/env bash\necho "$*" >>"%s/layout.log"\n' "$sandbox" >"$stubs/desktop-agent-layout"
printf '#!/usr/bin/env bash\nexec sleep 600\n' >"$stubs/lazygit"

# glab and gh: a review is a file named after its branch, holding its URL and state.
cat >"$stubs/glab" <<'STUB'
#!/usr/bin/env bash
echo "glab $*" >>"$FORGE/calls"
key() { printf '%s' "$1" | tr '/' '-'; }
case "$1 $2" in
"mr view")
  [[ -f $FORGE/review-$(key "$3") ]] || exit 1
  cat "$FORGE/review-$(key "$3")" ;;
"mr create")
  [[ -f $FORGE/fail ]] && { echo "error: 403 forbidden" >&2; exit 1; }
  while (($#)); do [[ $1 == --source-branch ]] && branch=$2; shift; done
  printf '{"web_url":"https://git.example/mr/%s","state":"opened"}' "$(key "$branch")" >"$FORGE/review-$(key "$branch")"
  echo "https://git.example/mr/$(key "$branch")" ;;
esac
STUB
cat >"$stubs/gh" <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >>"$FORGE/calls"
key() { printf '%s' "$1" | tr '/' '-'; }
case "$1 $2" in
"pr view")
  [[ -f $FORGE/review-$(key "$3") ]] || exit 1
  jq -r '.web_url' "$FORGE/review-$(key "$3")" ;;
"pr create")
  while (($#)); do [[ $1 == --head ]] && branch=$2; shift; done
  printf '{"web_url":"https://github.example/pr/%s","state":"OPEN"}' "$(key "$branch")" >"$FORGE/review-$(key "$branch")"
  echo "https://github.example/pr/$(key "$branch")" ;;
esac
STUB
chmod +x "$stubs"/*
export PATH="$stubs:$ROOT/bin:$PATH" FORGE="$forge"

# A remote and a clone of it, the way a repository sits under Repositories/Projects.
projects="$sandbox/Repositories/Projects"
mkdir -p "$projects"
git init -q --bare "$sandbox/remote/repo.git"
git clone -q "$sandbox/remote/repo.git" "$projects/repo" 2>/dev/null
repo="$projects/repo"
# What a setup command produces is ignored, as installed collections are: a "run" line that
# left untracked files behind would make every task look uncommitted to done.
#
# The other two ignore rules are ansible_infra's, and the reason this test has them: a
# directory ignored as `collections/ansible_collections/` stops matching once it is a
# symlink, and a nested `**/.claude/settings.local.json` leaves a directory that plain `git
# status` reports as untracked. Either one made every task look uncommitted.
(cd "$repo" && printf '.vault_pass\nran-from-trusted-config\ncollections/ansible_collections/\n**/.claude/settings.local.json\n' >.gitignore &&
  git add .gitignore && git commit -qm init && git push -q origin main && git remote set-head origin -a >/dev/null)
printf 'secret\n' >"$repo/.vault_pass"
mkdir -p "$repo/collections/ansible_collections/community" "$repo/.claude"
printf '{}\n' >"$repo/.claude/settings.local.json"

mkdir -p "$XDG_CONFIG_HOME/desktop/worktrees"
printf 'symlink .vault_pass\nsymlink .not_there\nsymlink collections/ansible_collections\nsymlink .claude/settings.local.json\nrun touch ran-from-trusted-config\n' \
  >"$XDG_CONFIG_HOME/desktop/worktrees/repo"

tm() { "$TMUX_BIN" -L "$server" "$@"; }
in_repo() { (cd "$1" && shift && bash "$WT" "$@"); }

# --- new
output=$(in_repo "$repo" new feature/runner-cache)
task="$projects/repo.worktrees/feature-runner-cache"
check "a task gets a worktree beside the repository, named after its branch" test -d "$task"
check "on its own branch" test "$(git -C "$task" symbolic-ref --short HEAD)" = feature/runner-cache
check "starting from origin's default branch" \
  test "$(git -C "$task" rev-parse HEAD)" = "$(git -C "$repo" rev-parse origin/main)"
check "the repository's session is made the usual way, ide and git" \
  test "$(tm list-windows -t =repo -F '#{window_name}' | head -2 | tr '\n' ' ')" = "ide git "
window=$(tm list-windows -t =repo -F '#{window_id} #{window_name}' | awk '$2 == "feature-runner-cache" { print $1 }')
check "the task has a window of its own in that session" test -n "$window"
check "which knows its worktree" test "$(tm show-options -wqv -t "$window" @worktree)" = "$task"
check "and is laid out for an agent" grep -q "^$window claude$" "$sandbox/layout.log"
check "the vault password is linked in, not copied" \
  test "$(readlink "$task/.vault_pass")" = "$repo/.vault_pass"
check "an entry with nothing to link is reported, not fatal" grep -q "skipped .not_there" <<<"$output"
check "a trusted config may run a command in the new worktree" test -f "$task/ran-from-trusted-config"
check "a linked directory whose ignore rule does not match a link is still ignored in the task" \
  test -z "$(git -C "$task" status --porcelain --untracked-files=all)"
check "by the repository's local exclude file, which is never committed" \
  grep -qx "/collections/ansible_collections" "$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
check "and the repository itself is none the wiser" \
  test -z "$(git -C "$repo" status --porcelain --untracked-files=all)"

in_repo "$repo" new feature/runner-cache >/dev/null
check "asking for the same branch again goes back to the task instead of failing" \
  test "$(tm list-windows -t =repo -F '#{@worktree}' | grep -cx "$task")" = 1

check "list names the task" grep -q "feature/runner-cache" <<<"$(in_repo "$repo" list)"

# --- a .worktree that arrived with a clone
git clone -q "$sandbox/remote/repo.git" "$projects/cloned" 2>/dev/null
printf 'run touch pwned\nsymlink ../../outside\ncopy /etc/hostname\n' >"$projects/cloned/.worktree"
output=$(in_repo "$projects/cloned" new try-it)
check "a .worktree inside a repository may not run commands" \
  test ! -e "$projects/cloned.worktrees/try-it/pwned"
check "and says so" grep -q "may not run commands" <<<"$output"
check "nor reach outside the repository" \
  test "$(grep -c "outside the repository" <<<"$output")" = 2

# --- done: everything it must refuse
check "done refuses in the repository itself" \
  lacks . <<<"$(cd "$repo" && bash "$WT" done 2>/dev/null)"
check "done refuses with nothing committed on the branch" \
  grep -q "nothing to review" <<<"$(cd "$task" && bash "$WT" done 2>&1)"
printf 'change\n' >"$task/file"
check "done refuses uncommitted changes" \
  grep -q "uncommitted changes" <<<"$(cd "$task" && bash "$WT" done 2>&1)"
(cd "$task" && git add file && git commit -qm "the change")

output=$(cd "$task" && bash "$WT" done --dry-run)
check "a dry run says what it would do" grep -q "would open a merge request into main with glab" <<<"$output"
check "and does none of it" test -z "$(git -C "$sandbox/remote/repo.git" branch --list feature/runner-cache)"

# The review cannot be opened: the push has happened, but the task must stay.
touch "$forge/fail"
(cd "$task" && bash "$WT" done >/dev/null 2>&1)
check "when the review cannot be opened, the task is left in place" test -d "$task"
rm "$forge/fail"

# The push cannot happen at all.
git -C "$repo" remote set-url origin "$sandbox/nowhere.git"
(cd "$task" && bash "$WT" done >/dev/null 2>&1)
check "when the push fails, the task is left in place" test -d "$task"
git -C "$repo" remote set-url origin "$sandbox/remote/repo.git"

# --- done, for real
output=$(cd "$task" && bash "$WT" done 2>&1)
check "done pushes the branch" test -n "$(git -C "$sandbox/remote/repo.git" branch --list feature/runner-cache)"
check "and opens a merge request from it into main" \
  grep -q "glab mr create --source-branch feature/runner-cache --target-branch main --fill --yes" "$forge/calls"
check "then removes the worktree, symlinked secret and all" test ! -d "$task"
check "and closes its window" test -z "$(tm list-windows -t =repo -F '#{@worktree}' | grep -x "$task")"
check "but keeps the branch until the review is merged" \
  git -C "$repo" show-ref --verify --quiet refs/heads/feature/runner-cache

# From inside tmux the close is handed to the server, since the window being closed is very
# likely the one running done.
in_repo "$repo" new second-task >/dev/null
second="$projects/repo.worktrees/second-task"
(cd "$second" && printf 'x\n' >x && git add x && git commit -qm x)
(cd "$second" && TMUX="fake,1,0" bash "$WT" done >/dev/null 2>&1)
for _ in $(seq 50); do [[ -d $second ]] || break; sleep 0.1; done
check "from inside tmux, the task is closed by the server" test ! -d "$second"

# A review already open is reused, not opened twice.
in_repo "$repo" new again >/dev/null
again="$projects/repo.worktrees/again"
(cd "$again" && printf 'y\n' >y && git add y && git commit -qm y)
printf '{"web_url":"https://git.example/mr/existing","state":"opened"}' >"$forge/review-again"
: >"$forge/calls"
output=$(cd "$again" && bash "$WT" done 2>&1)
check "a review that already exists is not opened again" lacks "mr create" "$forge/calls"
check "and its address is given instead" grep -q "mr/existing" <<<"$output"

# --- prune: only what the forge says was merged
git -C "$sandbox/remote/repo.git" branch -D feature/runner-cache >/dev/null
git -C "$sandbox/remote/repo.git" branch -D again >/dev/null
printf '{"web_url":"x","state":"merged"}' >"$forge/review-feature-runner-cache"
printf '{"web_url":"x","state":"closed"}' >"$forge/review-again"
output=$(in_repo "$repo" prune)
check "a branch whose review was merged is pruned" \
  lacks -E . <<<"$(git -C "$repo" branch --list feature/runner-cache)"
check "a branch whose review was closed unmerged is kept, though origin lost it too" \
  git -C "$repo" show-ref --verify --quiet refs/heads/again
check "and prune says why" grep -q "kept again" <<<"$output"

# --- GitHub
git clone -q "$sandbox/remote/repo.git" "$projects/hubrepo" 2>/dev/null
# Configured as GitHub, fetched from the bare repository: the forge is read from the URL as
# written, not as rewritten.
git -C "$projects/hubrepo" remote set-url origin https://github.com/someone/hubrepo.git
git config --global "url.$sandbox/remote/repo.git.insteadOf" https://github.com/someone/hubrepo.git
in_repo "$projects/hubrepo" new hub-task >/dev/null
(cd "$projects/hubrepo.worktrees/hub-task" && printf 'z\n' >z && git add z && git commit -qm z)
: >"$forge/calls"
(cd "$projects/hubrepo.worktrees/hub-task" && bash "$WT" done >/dev/null 2>&1)
check "a GitHub repository gets a pull request from gh" \
  grep -q "gh pr create --head hub-task --base main --fill" "$forge/calls"

# --- the sessionizer
mkdir -p "$projects/repo.worktrees/listed"
git -C "$repo" worktree add -q "$projects/repo.worktrees/listed" -b listed
printf '%s\n' "$projects" >"$sandbox/sessionizer-dirs"
printf '#!/usr/bin/env bash\ncat >"%s/fzf-input"\n' "$sandbox" >"$stubs/fzf"
chmod +x "$stubs/fzf"
TMUX_SESSIONIZER_CONFIG_FILE="$sandbox/sessionizer-dirs" bash "$ROOT/config/tmux/bin/tmux-sessionizer.sh"
check "the sessionizer offers tasks under their repository" grep -qx "$projects/repo.worktrees/listed" "$sandbox/fzf-input"
check "and not the directory that holds them" lacks -x "$projects/repo.worktrees" "$sandbox/fzf-input"

finish
