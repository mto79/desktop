-- Layer rules for the Quickshell desktop shell surfaces.

-- Keep the bar instant: no layer-shell fade or slide on map.
hl.layer_rule({ match = { namespace = "desktop-bar" }, no_anim = true })
