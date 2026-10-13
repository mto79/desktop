#!/usr/bin/env bash

# The repository is public, and it named an employer: the address of their chat in a key
# binding, and their model service as an opencode provider. Both now live in files that
# are this machine's alone -- ~/.config/desktop/chat.conf and ~/.config/opencode/local.json
# -- and the repository's copies no longer carry them. A machine set up before that has
# them only in the deployed copies, which the next refresh from config/ would overwrite.
# So they are lifted out of the deployed copies here, into where they are now read from.

BINDINGS="$HOME/.config/hypr/bindings.conf"
CHAT_CONF="$HOME/.config/desktop/chat.conf"
BOUND='^(bindd = SUPER ALT, M, Mattermost, exec, )desktop-launch-webapp "([^"]+)"[[:space:]]*$'

if [[ -f $BINDINGS ]]; then
  url=$(sed -nE "s/$BOUND/\2/p" "$BINDINGS" | head -1)
  if [[ -n $url ]]; then
    if [[ ! -f $CHAT_CONF ]]; then
      mkdir -p "$(dirname "$CHAT_CONF")"
      (umask 077 && printf 'CHAT_URL="%s"\n' "$url" >"$CHAT_CONF") || exit 1
      echo "  the chat's address is kept in $CHAT_CONF"
    fi
    sed -i -E "s/$BOUND/\1desktop-launch-chat/" "$BINDINGS" || exit 1
    echo "  SUPER + ALT + M opens the chat that file names"
  fi
fi

OPENCODE="$HOME/.config/opencode/opencode.json"
OPENCODE_LOCAL="$HOME/.config/opencode/local.json"
OPENCODE_REPO="$HOME/.local/share/desktop/config/opencode/opencode.json"

# Whatever provider the deployed file has and the repository's does not is this machine's.
if [[ -f $OPENCODE && -f $OPENCODE_REPO && ! -f $OPENCODE_LOCAL ]]; then
  own=$(jq --slurpfile repo "$OPENCODE_REPO" \
    '{provider: ((.provider // {}) | with_entries(select(.key as $k | ($repo[0].provider // {}) | has($k) | not)))}' \
    "$OPENCODE") || exit 1
  if [[ $(jq '.provider | length' <<<"$own") -gt 0 ]]; then
    (umask 077 && printf '%s\n' "$own" >"$OPENCODE_LOCAL") || exit 1
    echo "  this machine's own opencode providers are kept in $OPENCODE_LOCAL"
  fi
fi

# And opencode is told to read that file. config/ is copied into ~/.config only by the
# installer, so the line is placed here.
ENV="$HOME/.config/uwsm/env"
if [[ -f $ENV ]] && ! grep -q '^export OPENCODE_CONFIG=' "$ENV"; then
  printf '\n# This machine'"'"'s own opencode providers, merged into opencode.json. See config/uwsm/env.\nexport OPENCODE_CONFIG=$HOME/.config/opencode/local.json\n' >>"$ENV" || exit 1
  echo "  opencode reads it from the next login"
fi
