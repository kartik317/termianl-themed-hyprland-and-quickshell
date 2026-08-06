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

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 0,
        rounding_power = 0,

        -- Change transparency of focused and unfocused windows
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

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("snappy",         { type = "bezier", points = { {0.1, 0.9},   {0.2, 1}     } })

hl.animation({ leaf = "global", enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border", enabled = true,  speed = 5.39, bezier = "easeOutQuint" })

-- windows
hl.animation({ leaf = "windows",    enabled = true, speed = 3.2, bezier = "snappy" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 2.6, bezier = "snappy", style = "popin 95%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.8, bezier = "quick",  style = "popin 95%" })

-- Fade
hl.animation({ leaf = "fade",    enabled = true, speed = 2.2, bezier = "quick" })
hl.animation({ leaf = "fadeIn",  enabled = true, speed = 2.0, bezier = "quick" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.5, bezier = "quick" })

-- Layers
hl.animation({ leaf = "layers",        enabled = true, speed = 3.2, bezier = "snappy" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 2.6, bezier = "quick", style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.8, bezier = "quick", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.5, bezier = "quick" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.2, bezier = "quick" })

-- Workspace
hl.animation({ leaf = "workspaces",    enabled = true, speed = 2.6, bezier = "snappy", style = "slide" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 2.3, bezier = "snappy", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 2.0, bezier = "quick",  style = "slide" })

hl.animation({ leaf = "zoomFactor", enabled = true, speed = 6, bezier = "quick" })
