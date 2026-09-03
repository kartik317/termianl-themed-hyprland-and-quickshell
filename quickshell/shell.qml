import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import Quickshell.Io
import "./bar"
import "./wallpaper_switcher"
import "./live_wallpaper_switcher"
import "./lock_screen"
import "./power_menu"
import "./app_launcher"
import "./brightness_controls"
import "./widgets"
import "./wallpaper_clock"
import "./voice_assistant"

ShellRoot {
    // ── Bar ────────────────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        Bar {
            property var modelData
            screen: modelData
        }
    }
    // ── Draggable clock overlay ────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: clockWindow
            property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            mask: Region {
                item: ClockState.clockVisible ? draggableClock : null
            }
	    WlrLayershell.layer: WlrLayer.Bottom
	    WlrLayershell.namespace: "clock-widget"
            visible: ClockState.clockVisible
            DraggableClock {
                id: draggableClock
                screen: clockWindow.screen
            }
        }
    }
    
    // ── Brightness Control ───────────────────
    Variants {
        model: Quickshell.screens
        BrightnessControls {
            property var modelData
            screen: modelData
        }
    }
    // ── Volume OSD (auto-shows on PipeWire sink events) ────────────────────
    Variants {
        model: Quickshell.screens
        VolumeOSD {
            property var modelData
            screen: modelData
        }
    }
    // ── Power menu overlay ─────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        PowerMenu {
            property var modelData
            screen: modelData
        }
    }
    // ── App launcher (slides up from bottom center) ────────────────────────
    Variants {
        model: Quickshell.screens
        AppLauncher {
            property var modelData
            screen: modelData
        }
    }

    LockScreen {} 

    NovaPanel {}

    WallpaperSwitcher {}

    LiveWallpaperSwitcher {}
}

