#!/usr/bin/env bash
# desktop-privacy-check stops a commit that would publish something private, in a
# repository made for the test.
#
# This repository is public. A Proxmox API token was committed to it, deleted the next
# day, and stayed readable in the history for ten months; real MAC addresses came in as
# test fixtures pasted from nmcli; compiled Python was tracked, with this machine's paths
# in it. Nothing looked, so nothing said so.
#
# Everything private-looking below is assembled at run time. Written out whole, this file
# would be stopped by the check it tests.
source "$(dirname "$0")/lib.sh"

require git || finish
require python3 || finish

CHECK="$ROOT/bin/desktop-privacy-check"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
repo="$sandbox/repo"
mkdir -p "$repo/.githooks"

git -C "$repo" init -q
git -C "$repo" config user.name test
git -C "$repo" config user.email test@example.com
git -C "$repo" config commit.gpgsign false

: >"$sandbox/deny"

privacy() {
  (cd "$repo" && HOME="$sandbox" DESKTOP_PRIVACY_DENY="$sandbox/deny" PYTHONDONTWRITEBYTECODE=1 \
    "$CHECK" "$@") 2>&1
}

# Stage one file holding one line, and nothing else.
stage() { # path line
  git -C "$repo" reset -q
  mkdir -p "$(dirname "$repo/$1")"
  printf '%s\n' "$2" >"$repo/$1"
  git -C "$repo" add -f "$1"
}

# Exactly 1: a check that crashed has not found anything, and must not read as if it had.
blocked() { # path line
  stage "$1" "$2"
  privacy >/dev/null
  test $? = 1
}

clean() { # path line
  stage "$1" "$2"
  privacy >/dev/null
}

hex() { printf "%0${1}d" 0 | tr 0 a; }
login=mto
uuid="295520fc-0000-4b4e-b0b0-$(hex 12)"

check "an ordinary line is committed" clean a.sh 'echo "hello"'

check "a GitHub token is stopped" blocked a.sh "TOKEN=ghp""_$(hex 36)"
check "a GitLab token is stopped" blocked a.sh "set -x GITLAB glpat""-$(hex 24)"
check "a private key is stopped" blocked a.sh "-----BEGIN OPENSSH PRIVATE"" KEY-----"
check "a Proxmox API token is stopped, the one that got out" \
  blocked a.fish "set -x TF_VAR_pve_api_token terraform@pve!provider=$uuid"
check "a long literal password is stopped" blocked a.conf "smtp_password = \"Zq8$(hex 20)\""
check "the shape of a token, x-ed out, is not one" clean a.fish '# set -x GITLAB glpat-xxxxxxxxxxxxxxxxxxxxxxxx'
check "a password read from somewhere is not one" clean a.sh 'token=$(secret-tool lookup service desktop)'
check "a name with secret in it is not one" clean a.sh 'SECRET_HINT="x-kde-passwordManagerHint"'

stage a.sh "TOKEN=ghp""_$(hex 36)"
check "a secret is not printed back whole" lacks "$(hex 36)" <<<"$(privacy)"
check "the finding says where" grep -q 'a\.sh:1' <<<"$(privacy)"

check "a real home directory is stopped" blocked a.sh "cd /home/$login/Data"
check "nobody's home directory is not" clean a.sh 'HOME=/home/u cd /home/someone/proj'
check "\$HOME is not" clean a.sh 'cd "$HOME/Data"'

check "a MAC address is stopped" blocked a.sh "HWADDR:28:00:AF"":C5:28:CD"
check "one from the documentation range is not" clean a.sh 'HWADDR:00:00:5E:00:53:01'

check "an email address is stopped" blocked a.sh "# by marc""@mto.nu"
check "a placeholder address is not" clean a.sh 'git config user.email test@example.com'
check "a systemd unit is not an address" clean a.sh 'systemctl restart wayland-wm@hyprland.service'

git -C "$repo" reset -q
printf 'x\n' >"$repo/server.pem"
git -C "$repo" add -f server.pem
check "a key file is stopped by its name" grep -q '^filename' <<<"$(privacy)"

git -C "$repo" reset -q
mkdir -p "$repo/bin/__pycache__"
printf 'a\0b' >"$repo/bin/__pycache__/x.pyc"
git -C "$repo" add -f bin/__pycache__/x.pyc
check "so is compiled Python, binary as it is" grep -q '^filename.*x\.pyc' <<<"$(privacy)"

# Only what a commit adds is its business. A line taken out is the fix, and must commit.
git -C "$repo" reset -q
printf 'cd /home/%s\nkeep\n' "$login" >"$repo/old.sh"
git -C "$repo" add old.sh
git -C "$repo" commit -q --no-verify -m old
printf 'keep\n' >"$repo/old.sh"
git -C "$repo" add old.sh
check "taking a private line out is committed" privacy
git -C "$repo" commit -q --no-verify -m fixed

check "the history still has it, and --history says so" grep -q 'home-path.*old\.sh:1' <<<"$(privacy --history)"
check "the tree no longer does" privacy --all

check "a line that says it is fine is let through" clean a.sh "cd /home/$login  # privacy: allow"

printf '# upstream author\n%s\n' 'upstream@author\.dev' >"$repo/.githooks/privacy-allow"
check "so is what the allow list names" clean a.sh "# by upstream""@author.dev"
check "and nothing else" blocked a.sh "# by another""@author.dev"

# The deny list: words private to one person, kept outside the repository.
check "a private word is fine until it is denied" clean a.conf 'server = vpn.acme-internal.nl'
printf '# work\n%s\n' 'acme-internal' >"$sandbox/deny"
check "denied, it is stopped" blocked a.conf 'server = vpn.ACME-internal.nl'
check "in a file's name too" blocked acme-internal.conf 'x'

stage a.sh 'echo fine'
git -C "$repo" config user.email "someone""@acme-internal.nl"
check "and so is committing under a denied address" grep -q 'committing as' <<<"$(privacy)"
git -C "$repo" config user.email test@example.com
: >"$sandbox/deny"

printf '%s\n' '(unclosed' >"$sandbox/deny"
privacy >/dev/null
check "a deny list that cannot be read as patterns is an error, not a pass" test $? = 2
: >"$sandbox/deny"

# The hook itself, through git, as a commit meets it.
mkdir -p "$repo/bin"
cp "$ROOT/.githooks/pre-commit" "$repo/.githooks/pre-commit"
cp "$CHECK" "$repo/bin/desktop-privacy-check"
git -C "$repo" config core.hooksPath .githooks
commit() {
  (cd "$repo" && HOME="$sandbox" DESKTOP_PRIVACY_DENY="$sandbox/deny" PYTHONDONTWRITEBYTECODE=1 \
    git commit -q -m try) >/dev/null 2>&1
}
stage a.sh "cd /home/$login"
before=$(git -C "$repo" rev-parse HEAD)
commit
check "git commit is refused" test "$(git -C "$repo" rev-parse HEAD)" = "$before"
stage a.sh 'cd "$HOME"'
commit
check "and goes through once the line is fixed" test "$(git -C "$repo" rev-parse HEAD)" != "$before"

check "the hook is executable" test -x "$ROOT/.githooks/pre-commit"
check "a clean install points git at it" grep -q 'core.hooksPath .githooks' "$ROOT/install/config/git-hooks.sh"
check "and the deny list is not in the repository" test -z "$(git -C "$ROOT" ls-files '*privacy-deny*')"

# The repository itself, for the things that are never right. Home directories are left
# out: there are files here still written for one machine, and they are known.
tree=$(cd "$ROOT" && PYTHONDONTWRITEBYTECODE=1 DESKTOP_PRIVACY_DENY=/dev/null "$CHECK" --all 2>&1)
for kind in secret mac-address email filename; do
  check "no $kind is tracked in this repository" lacks "^$kind " <<<"$tree"
done

finish
