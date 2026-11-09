#!/usr/bin/env bash
set -euo pipefail

# kubie, from upstream's newest release. desktop-update-releases does the work and checks the
# download against the digest GitHub publishes for it, so an install and every update agree.
"$DESKTOP_PATH/bin/desktop-update-releases" kubie

# Completions from the same project, which moved from sbstp/kubie to kubie-org/kubie.
completions="$HOME/.config/fish/completions/kubie.fish"
mkdir -p "$(dirname "$completions")"
curl -fsSL --max-time 30 -o "$completions" \
  https://raw.githubusercontent.com/kubie-org/kubie/master/completion/kubie.fish ||
  echo "kubie: no fish completions fetched; kubie works without them" >&2
