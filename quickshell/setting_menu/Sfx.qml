import QtQuick
import QtMultimedia
import Quickshell
import "../theme"

// Drop-in sound effect for any component:
//
//     Sfx { id: clickSfx; file: "click.wav" }
//     ...
//     clickSfx.play()
//
// It loads ~/.config/quickshell/sounds/<file> and stays silent when sound
// effects are turned off in the settings panel.
//
// Per-component toggles later: override the gate, e.g.
//     Sfx { file: "ping.wav"; gate: Settings.soundEnabled && Settings.get("soundNotifications") }
QtObject {
    id: root

    property string file: ""
    property real volume: 1.0
    property bool gate: Settings.soundEnabled

    function play() {
        if (gate && file !== "")
            fx.play();
    }

    function stop() {
        fx.stop();
    }

    property SoundEffect fx: SoundEffect {
        id: fx
        source: root.file !== "" ? "file://" + Quickshell.env("HOME") + "/.config/quickshell/sounds/" + root.file : ""
        volume: root.volume
    }
}

