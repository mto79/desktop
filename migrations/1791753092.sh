#!/usr/bin/env bash

# Move codex and opencode out of /usr/local, where they could not update themselves.
#
# Both were installed with `sudo npm i -g` and so were owned by root. Each offers to update
# itself and runs `npm install -g` as you; against /usr/local that asks for administrator
# rights it does not have, and the agent's pane dies part-way through. They now live under
# ~/.local, which npm is told is where global packages go, and where the same update works.
#
# The copies in /usr/local are removed last: ~/.local/bin comes first on PATH, so they are
# never the ones run, but a second copy that never updates is a version to be confused by.

npm config set prefix "$HOME/.local" || exit 1

for package in @openai/codex opencode-ai; do
  if [[ ! -d $HOME/.local/lib/node_modules/$package ]]; then
    npm i -g "$package" || exit 1
    echo "  $package installed under ~/.local"
  fi
  if [[ -d /usr/local/lib/node_modules/$package ]]; then
    sudo npm rm -g --prefix /usr/local "$package" >/dev/null || exit 1
    echo "  removed the root-owned copy of $package from /usr/local"
  fi
done
