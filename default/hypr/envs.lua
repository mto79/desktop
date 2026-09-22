-- Cursor size
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Force all apps to use Wayland
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("OZONE_PLATFORM", "wayland")

hl.config({
  xwayland = {
    force_zero_scaling = true,
  },
})

-- Use XCompose file. The path in full: a value set here is not a shell word, and nothing
-- promises to expand a ~ in it.
hl.env("XCOMPOSEFILE", os.getenv("HOME") .. "/.XCompose")

-- Don't show update on first launch
hl.config({
  ecosystem = {
    no_update_news = true,
  },
})
