-- Layer rules for the Quickshell desktop shell surfaces.

-- Keep the bar instant: no layer-shell fade or slide on map.
hl.layer_rule({ match = { namespace = "desktop-bar" }, no_anim = true })

-- The dashboard is a window of the shell's, and lives on workspace 6. Silently: it is
-- created whenever the shell starts or restarts, and that must not drag you there.
hl.window_rule({ match = { class = "^(org\\.quickshell)$", title = "^(Dashboard)$" }, workspace = "6 silent" })
