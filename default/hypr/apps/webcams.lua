-- A webcam's timelapse from the dashboard's globe: Windy's player in a web app window,
-- floating over the dashboard rather than tiling it away. The class is the browser's own
-- for an --app window, made from the address, so it matches the player and nothing else.
hl.window_rule({ match = { class = "brave-webcams\\.windy\\.com__webcams_public_embed_player_.*" }, tag = "+webcam" })
hl.window_rule({ match = { tag = "webcam" }, float = true })
hl.window_rule({ match = { tag = "webcam" }, size = { 960, 600 } })
hl.window_rule({ match = { tag = "webcam" }, center = true })
