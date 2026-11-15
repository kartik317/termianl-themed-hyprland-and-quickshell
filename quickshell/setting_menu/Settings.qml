pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Put this file next to Colors.qml and register it in the same qmldir:
//     singleton Settings 1.0 Settings.qml
//
// Values are saved to ~/.config/quickshell/settings.json
//
// ── Adding a new setting ───────────────────────────────────────────────────
//   1) add a property to the JsonAdapter below (the default is used until the
//      user changes it)
//   2) add one line to `entries` in SettingsPanel.qml
//   3) read it anywhere with Settings.get("yourKey")
//      (or add a readonly convenience property like soundEnabled)
Singleton {
    id: root

    // ── Panel visibility (toggled by the "settings" IpcHandler) ────────────
    property bool panelVisible: false

    function show() {
        panelVisible = true;
    }
    function hide() {
        panelVisible = false;
    }
    function toggle() {
        panelVisible = !panelVisible;
    }

    // ── Generic access (used by the panel's data-driven rows) ──────────────
    function get(key) {
        return adapter[key];
    }
    function set(key, value) {
        adapter[key] = value;
    }

    // ── Convenience readers for bindings ───────────────────────────────────
    readonly property bool soundEnabled: adapter.soundEnabled
    readonly property bool animationsEnabled: adapter.animationsEnabled

    // ── Persistence ────────────────────────────────────────────────────────
    property FileView store: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/settings.json"
        blockLoading: true // load synchronously so the first launch already has saved values

        onAdapterUpdated: writeAdapter()
        onLoadFailed: function (error) {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        adapter: JsonAdapter {
            id: adapter

            // AUDIO
            property bool soundEnabled: true

            // VISUAL
            property bool animationsEnabled: true
        }
    }
}

