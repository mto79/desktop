---
name: visual-verification
description: Actually looking at the screen after a visual change - bar, panels, notifications, window rules, themes. Read before claiming any visual change works.
---

# Visual verification

A visual change is not done because the code looks right or the shell loaded without
warnings. Look at it. Loading cleanly only proves the QML parsed.

## Capture

`grim` captures the whole compositor space in **physical** pixels:

```bash
grim /tmp/shot.png
```

Crop to what you care about with ImageMagick, then **read the PNG** — the Read tool
renders images, so you can genuinely inspect it.

```bash
magick /tmp/shot.png -crop 1000x76+2840+0 +repage -filter point -resize 200% /tmp/bar.png
```

`-filter point` keeps text crisp when enlarging. Enlarge: bar text at 1:1 is unreadable.

### Converting Hyprland coordinates to crop coordinates

`hyprctl clients` and `hyprctl monitors` report **logical** coordinates. `grim` output is
physical. For a window on a monitor with origin `(mx, my)` and `scale`:

```
physical_x = (logical_x - mx) * scale
physical_y = (logical_y - my) * scale
width      = logical_w * scale
```

Getting this wrong crops the wrong window and produces confident nonsense — check the
crop shows what you expected before drawing conclusions from it.

The bar is `Style.barSize` (38) **logical** pixels tall, so 76 physical on a scale-2
display.

## Traps

- **`grim -o <NAME>` often fails** with "unknown output". Capture everything and crop.
- **`hyprshot -m output -m active`** works; `hyprshot -m <MONITOR_NAME>` produces an
  empty file. `hyprshot -m output` alone waits for you to *click* a monitor and will
  appear to hang.
- **An all-black capture usually means the screen is locked.** Check `pgrep -x hyprlock`
  before assuming the change broke rendering.
- **Monitors change between sessions.** The ultrawide has appeared as both DP-6 and
  DP-7. Never hardcode a connector; resolve it from `hyprctl monitors`.

## Comparing against before

For "is this my regression or was it always broken", check out the committed version,
restart, capture, then restore:

```bash
git show HEAD:shell/Bar/widgets/Tray.qml > shell/Bar/widgets/Tray.qml
desktop-restart-shell && sleep 6 && grim /tmp/before.png
```

This is how the tray's magenta checkerboards were shown to be pre-existing rather than
newly introduced — worth the two minutes before reporting a cause.

## Notifications

Send a realistic one rather than a placeholder. Multi-line bodies need building with
`printf`, because literal newlines inside a shell command get collapsed and silently
mangle the arguments:

```bash
BODY=$(printf 'example.com\n\nthe message')
notify-send --app-name="Brave" -h string:desktop-entry:brave-browser "Title" "$BODY"
```

To see what a real application sends, watch the bus:

```bash
dbus-monitor "interface='org.freedesktop.Notifications',member='Notify'"
```
