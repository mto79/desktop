# Privacy

This repository is public, and it is the configuration of one real machine. Those two
facts meet all the time: a comment showing a command's output shows the home network, a
default written for this machine names its NAS, a test fixture is pasted from the real
thing.

## Why there is a check

Private details arrive by accident, in small ways: a credential in an environment file, a
real hardware address pasted in as a test fixture, a build product tracked with absolute
paths in it, a commit made under the wrong email address. Deleting a line later does not
take it out of the history. Nothing automatic was looking for any of this, so now
something does.

## The check

`bin/desktop-privacy-check` looks, in three scopes:

    desktop-privacy-check             # what is staged: the lines about to be committed
    desktop-privacy-check --all       # every tracked file, as it is now
    desktop-privacy-check --history   # every line any commit ever added, on every branch

It exits 1 when it finds something and prints one finding per line: the kind, where, and
what. A secret is printed cut short, because the output ends up in terminals, logs and
agent transcripts.

| Kind | What it matches | What it leaves alone |
|---|---|---|
| `secret` | Private key blocks; GitHub, GitLab, AWS, Slack, DigitalOcean, Google and Proxmox token shapes; JWTs; `password = <long literal>` | `xxxx` placeholders, values read from a command or a variable |
| `home-path` | `/home/<login>/` | `/home/u`, `/home/user`, `/home/someone`, `/home/me`, `$HOME` |
| `mac-address` | Any MAC address | The documentation range `00:00:5E:00:53:xx` and obvious fillers |
| `email` | Any address | `example.com`, `noreply@`, systemd units like `getty@tty1.service` |
| `filename` | `*.pem`, `*.key`, `*.kdbx`, `*.ovpn`, `*.pyc`, `id_rsa`, `.env`, `.netrc`, vault and restic password files | |
| `denied` | Whatever your deny list names | |

A `home-path` finding is usually also a bug: a script with a home directory written into
it works on one machine.

## The hook

`.githooks/pre-commit` runs the first form, so a finding stops the commit and nothing is
recorded. Git only uses `.githooks` when `core.hooksPath` points there:

    git config core.hooksPath .githooks

`install/config/git-hooks.sh` sets that on a clean install and a migration sets it on a
machine that already exists. The setting is in the repository's own config, so every
worktree gets the hook, and each worktree runs its own branch's copy of the check.

Only added lines are checked. Removing a private line is the fix, and always commits.

## The deny list

The built-in rules know what a token looks like. They cannot know that a particular
hostname, employer or street is private to you. That goes in

    ~/.config/desktop/privacy-deny

one extended regular expression a line, matched whatever the case, `#` for comments:

    # work
    acme-internal
    vpn-[a-z]+\.acme\.example

    # home
    192\.168\.7\.\d+

It is deliberately **not in the repository**: a tracked list of private words is a
published list of private words. It is matched against added lines, file names, and the
name and address the commit is about to be made under, so denying a work domain also stops
a commit made with the work email address.

`DESKTOP_PRIVACY_DENY` points the check at a different file, which is how the test runs
without reading yours.

## When a finding is fine

Three ways, narrowest first:

1. Put `privacy: allow` anywhere on the line. Use this for a line of our own that can
   carry a comment.
2. Add a pattern to `.githooks/privacy-allow`. This is for what cannot carry a comment
   (JSON) or is not ours to edit (the author's address in a vendored theme). It is matched
   against the thing found, not the whole line.
3. `git commit --no-verify` skips the hook entirely. It skips every rule at once, so it
   is the wrong answer for a single false positive.

## Writing examples and fixtures

Pasting real output is the usual way something private gets in. Use the reserved values instead:

| For | Use |
|---|---|
| An IPv4 address | `192.0.2.x`, `198.51.100.x`, `203.0.113.x` (RFC 5737) |
| A MAC address | `00:00:5E:00:53:xx` (RFC 7042) |
| A hostname | `host.example`, `example.com`, `example.nl` |
| A home directory | `/home/u` in tests, `$HOME` or `~` in scripts |
| An email address | `someone@example.com` |
| A token | The prefix and `xxxx`: `glpat-xxxxxxxxxxxx` |

## Settings that are one machine's own

A value that only makes sense on this machine belongs in a file the script reads and the
repository does not carry. `config/` is the wrong place for it twice over: it is tracked,
and the installer copies it over whatever is deployed.

| Setting | Lives in | Read by |
|---|---|---|
| The chat's address | `~/.config/desktop/chat.conf`, as `CHAT_URL="..."` | `desktop-launch-chat` (`SUPER + ALT + M`), `desktop-workspace-start` |
| An employer's model service, or any other opencode provider of your own | `~/.config/opencode/local.json` | opencode, which merges it into `opencode.json` because `config/uwsm/env` sets `OPENCODE_CONFIG` |
| The backup repository and its host | `~/.config/desktop/backup.conf` | `desktop-backup`, which writes it once with empty defaults |
| Home Assistant's address and token | `~/.config/desktop/home.conf` and the secret service | `desktop-dash` |
| A model on a network of your own, for voice commands | `~/.config/desktop/voice.conf` | `desktop-voice` |
| Your own spoken phrases | `~/.config/desktop/voice.aliases` | `desktop-voice` |
| The names of the networks you are on | `~/.config/desktop/networks.conf` | `desktop-dash-network` |

None of these has to exist. Without `chat.conf` the key says no chat is set and the login
opens one window fewer; without `local.json` opencode has the repository's providers only.

These files are on this machine and nowhere else, so they are only as safe as its backup.

## When something got out anyway

In this order, because the first step is the only one that actually works:

1. **Revoke the credential.** Rotate the token, change the password, re-key. Assume it was
   copied: public repositories are scraped for secrets within minutes, and forks, clones
   and caches keep what the origin later removes.
2. **Take it out of the current tree** and commit that.
3. **Decide whether to rewrite history.** `git filter-repo` can remove a file or replace a
   string in every commit, followed by a force push of every branch. It changes every
   commit hash after the first one touched, breaks every existing clone and worktree, and
   does not reach copies other people already have. For a revoked credential it is
   tidiness, not safety. For something that cannot be revoked, such as a home address, it
   is worth doing, and GitHub support can be asked to drop cached views afterwards.
4. **Run `desktop-privacy-check --history`** to see what else is there before rewriting,
   so it is done once.

The author address on past commits is the same kind of problem: it can only be changed by
rewriting history. For new commits, set the address for this repository alone:

    git config user.email you@example.com

and put the other domain in the deny list, so the hook refuses a commit made under it.

## What the check does not do

It reads text. It does not see a screenshot with a hostname in it, a private detail in
prose it has no pattern for, or anything in a commit message. It checks commits made on a
machine where the hook is installed, and `--no-verify` goes past it. Run `--all` before
making anything public, and read the diff.
