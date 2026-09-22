-- Browser types
hl.window_rule({ match = { class = "([cC]hrom(e|ium)|[bB]rave-browser|Microsoft-edge|Vivaldi-stable)" }, tag = "+chromium-based-browser" })
hl.window_rule({ match = { class = "(Firefox|zen|librewolf)" }, tag = "+firefox-based-browser" })

-- Force chromium-based browsers into a tile to deal with --app bug
hl.window_rule({ match = { tag = "chromium-based-browser" }, tile = true })

-- Only a subtle opacity change, but not for video sites
hl.window_rule({ match = { tag = "chromium-based-browser" }, opacity = "1 0.97" })
hl.window_rule({ match = { tag = "firefox-based-browser" }, opacity = "1 0.97" })

-- Some video sites should never have opacity applied to them
hl.window_rule({ match = { initial_title = "(youtube\\.com_/|app\\.zoom\\.us_/wc/home)" }, opacity = "1.0 1.0" })
