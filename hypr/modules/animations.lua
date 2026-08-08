-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 20,
        border_size = 2,
        col = {
            active_border   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding       = 0,
        rounding_power = 0,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },
        blur = {
            enabled   = true,
            size      = 3,
            passes    = 1,
            vibrancy  = 0.1696,
        },
    },
    animations = {
        enabled = true,
    },
})

hl.curve("linear",       { type = "bezier", points = { {0, 0},    {1, 1}    } })
hl.curve("quick",        { type = "bezier", points = { {0.15, 0}, {0.1, 1}  } })
hl.curve("cut",          { type = "bezier", points = { {0.4, 0},  {0.2, 1}  } })

hl.animation({ leaf = "global", enabled = true, speed = 1.5, bezier = "cut" })
hl.animation({ leaf = "border", enabled = true, speed = 1.5, bezier = "linear" })

-- windows — no popin/scale, just a fast cut
hl.animation({ leaf = "windows",    enabled = true, speed = 1.2, bezier = "cut" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 1.0, bezier = "cut" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 0.8, bezier = "quick" })

-- Fade — kept short, this reads fine even in a terminal-style setup
hl.animation({ leaf = "fade",    enabled = true, speed = 1.2, bezier = "quick" })
hl.animation({ leaf = "fadeIn",  enabled = true, speed = 1.0, bezier = "quick" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 0.8, bezier = "quick" })

-- Workspaces — instant slide, no easing overshoot
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.2, bezier = "linear", style = "slide" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.0, bezier = "linear", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 0.8, bezier = "linear", style = "slide" })

hl.animation({ leaf = "zoomFactor", enabled = true, speed = 2, bezier = "quick" })
