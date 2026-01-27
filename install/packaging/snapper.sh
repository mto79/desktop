#!/usr/bin/env bash

sudo grub2-editenv - unset menu_auto_hide

sudo dnf install snapper libdnf5-plugin-actions btrfs-assistant -y

sudo tee /etc/dnf/libdnf5-plugins/actions.d/snapper.actions >/dev/null <<'EOF'
# The next two actions emulate the DNF4 snapper plugin...
pre_transaction::::/usr/bin/sh -c echo\ "tmp.snapper_desc=$(ps\ -o\ command\ --no-headers\ -p\ '${pid}')"
pre_transaction::::/usr/bin/sh -c echo\ "tmp.snapper_pre_number=$(snapper\ create\ -t\ pre\ -p\ -d\ '${tmp.snapper_desc}')"
post_transaction::::/usr/bin/sh -c [\ -n\ "${tmp.snapper_pre_number}"\ ]\ &&\ snapper\ create\ -t\ post\ --pre-number\ "${tmp.snapper_pre_number}"\ -d\ "${tmp.snapper_desc}";\ echo\ tmp.snapper_pre_number\ ;\ echo\ tmp.snapper_desc
EOF

echo "Now create Snapper configurations for the root (/) and home (/home) subvolumes"
# 3️⃣ Create configs only if they don’t exist
for subvol in root home; do
  if ! sudo snapper -c "$subvol" list >/dev/null 2>&1; then
    echo "Creating Snapper config for $subvol..."
    if [ "$subvol" = "root" ]; then
      sudo snapper -c root create-config /
    else
      sudo snapper -c home create-config /home
    fi
  else
    echo "Snapper config for $subvol already exists. Skipping..."
  fi
done

echo "Enable quota"
sudo btrfs quota enable /

echo "Verify the configurations"
sudo snapper list-configs

# echo "Restore the correct SELinux contexts for the .snapshots directories"
# sudo restorecon -RFv /.snapshots
# sudo restorecon -RFv /home/.snapshots

echo "Enable user access to Snapper and synchronize file ACLs"
sudo snapper -c root set-config ALLOW_USERS=$USER SYNC_ACL=yes
sudo snapper -c home set-config ALLOW_USERS=$USER SYNC_ACL=yes

echo "Prevent updatedb from indexing the .snapshots directories."
grep -qxF 'PRUNENAMES = ".snapshots"' /etc/updatedb.conf ||
  echo 'PRUNENAMES = ".snapshots"' | sudo tee -a /etc/updatedb.conf

echo "Install and enable grub-btrfs"
sudo dnf install grub-btrfs -y

# echo "🚀 Enabling grub-btrfs.service..."
# sudo systemctl enable --now grub-btrfs.service

WRAPPER_SERVICE="/etc/systemd/system/grub-btrfs-auto.service"
TIMER_FILE="/etc/systemd/system/grub-btrfs-auto.timer"

echo "🚀 Creating systemd wrapper service..."
sudo tee "$WRAPPER_SERVICE" >/dev/null <<EOF
[Unit]
Description=Automatically regenerate grub-btrfs.cfg for new snapshots
Wants=local-fs.target
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl start grub-btrfs.service
EOF

echo "⏱ Creating systemd timer..."
sudo tee "$TIMER_FILE" >/dev/null <<EOF
[Unit]
Description=Run grub-btrfs-auto service every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

echo "🔄 Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Enabling and starting timer..."
sudo systemctl enable --now grub-btrfs-auto.timer

echo "Enable Automatic Timeline Snapshots except /home"
sudo snapper -c home set-config TIMELINE_CREATE=no
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
