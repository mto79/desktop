#!/usr/bin/env bash

# Let the security check read the firewall's zones without a prompt.
#
# desktop-security, every fifteen minutes, asked firewalld which ports each zone admits.
# firewalld counts that as config.info and polkit asks an admin for it, so the check
# brought up a fingerprint prompt four times an hour. It no longer asks at all -- it checks
# with pkcheck first and skips the ports instead -- and this rule is what lets it read
# them: for an admin at the local session, reading only.

RULE="$HOME/.local/share/desktop/default/polkit/49-desktop-firewall-read.rules"
DEST=/etc/polkit-1/rules.d/49-desktop-firewall-read.rules

if sudo cmp -s "$RULE" "$DEST"; then
  echo "  the firewall read rule is already in place"
  exit 0
fi

sudo install -m 0644 "$RULE" "$DEST" || exit 1
echo "  the security check may now read the firewall's zones without asking"
