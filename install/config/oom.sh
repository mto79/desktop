#!/usr/bin/env bash

# Something has to kill a runaway before it takes the desktop with it.
#
# The kernel's own OOM killer only fires when an allocation cannot be satisfied, and a
# machine that is thrashing postpones that almost indefinitely: it spends its time
# reclaiming and compressing instead, and everything else -- the compositor, the bar, the
# keyboard -- gets starved of memory and CPU at once. That is a hang, not a crash, and
# nothing is logged because nothing failed. One terminal running a loop against a cluster
# reached 54.9G of this machine's 62G that way and froze it for good.
#
# systemd-oomd acts on pressure instead of on failure: once a user slice stalls on memory
# for twenty seconds it kills the worst cgroup underneath it. Both halves are needed --
# the daemon without systemd-oomd-defaults monitors nothing at all, and the defaults
# without the daemon are a policy no one reads. Fedora's presets enable the service; this
# machine had it disabled, which is the state this undoes.
sudo systemctl enable --now systemd-oomd.service

# Ghostty puts every window in a scope of its own, so the cgroup oomd picks is one
# terminal rather than the session -- as long as the session is not the easier target. The
# compositor is asked to be chosen last: killing it ends everything, and it is large
# enough to look attractive while an app starves it. A user-owned cgroup's preference is
# respected because the slices oomd watches here are owned by the same user.
systemctl --user daemon-reload
