import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root
    property var modelData
    screen: modelData

    property int  _lastBrightness: -1
    property bool osdVisible:      false
    property int  brightness:      0
    property int  maxBrightness:   100

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "qs-brightness-osd-noanim"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: 0

    anchors.bottom: true
    anchors.left:   true
    anchors.right:  true
    implicitHeight: 100

    mask: Region {
        item: osdCard
    }

    color: "transparent"

    // ── Auto-hide ───────────────────────────────────────────────────────────
    Timer {
        id: hideTimer
        interval: 2000
        onTriggered: root.osdVisible = false
    }

    // ── Watchdog: revive the watcher if it dies ─────────────────────────────
    Timer {
        id: watchRestartTimer
        interval: 1500
        onTriggered: {
            if (!brightnessWatch.running)
                brightnessWatch.running = true
        }
    }

    // ── Brightness event watcher (long-lived) ───────────────────────────────
    // brightnessctl has no native "subscribe" mode, so we watch the backlight
    // sysfs node for writes via inotifywait and re-query on each change.
    Process {
        id: brightnessWatch
        command: ["sh", "-c",
            "inotifywait -q -m -e modify --format '%f' " +
            "/sys/class/backlight/$(ls /sys/class/backlight | head -n1)/brightness"
        ]
        running: true
        onRunningChanged: {
            if (!running) watchRestartTimer.start()
        }
        stdout: SplitParser {
            onRead: data => {
                if (!brightnessQuery.running)
                    brightnessQuery.running = true
            }
        }
    }

    // ── Brightness query (short-lived, re-run on each event) ───────────────
    Process {
        id: brightnessQuery
        command: ["brightnessctl", "info"]
        stdout: SplitParser {
            onRead: data => {
                const curM = data.match(/Current brightness:\s*\d+\s*\((\d+)%\)/)
                if (!curM) return
                const newBrightness = parseInt(curM[1])
                const changed = newBrightness !== root._lastBrightness
                root._lastBrightness = newBrightness
                root.brightness = newBrightness
                if (changed) {
                    root.osdVisible = true
                    hideTimer.restart()
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  OSD card — instant show/hide, no slide/fade
    // ═══════════════════════════════════════════════════════════════════════
    Rectangle {
        id: osdCard
        width:  400
        height: 56
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     22

        visible: root.osdVisible

        radius: 0
        color: "transparent"
        border.color: Colors.colCyan
        border.width: 1

        // ── Inner fill (matches launcher/power menu/volume OSD) ─────────────
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: Qt.rgba(Colors.colBg.r, Colors.colBg.g, Colors.colBg.b, 0.8)
            radius: 0
            clip: true

            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 12

                Text {
                    text: root.brightness > 60 ? "\uf5fe"
                        : root.brightness > 20 ? "\uf042"
                        :                         "\uf5dd"
                    font.pixelSize: 16
                    font.family:    "JetBrainsMono Nerd Font"
                    color: Colors.colBlue
                }

                // ── Segmented brightness meter (matches volume OSD style) ────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    readonly property int segments: 20
                    readonly property int filledSegments: Math.round(Math.min(root.brightness / 100.0, 1.0) * segments)

                    Repeater {
                        model: parent.segments
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 10
                            radius: 0
                            border.width: 1
                            border.color: Qt.rgba(Colors.colFg.r, Colors.colFg.g, Colors.colFg.b, 0.1)
                            color: index < parent.filledSegments
                                   ? Colors.colBlue
                                   : Qt.rgba(Colors.colFg.r, Colors.colFg.g, Colors.colFg.b, 0.12)
                        }
                    }
                }

                Text {
                    text:                  root.brightness + "%"
                    font.pixelSize:        12
                    font.family:           "JetBrainsMono Nerd Font"
                    font.weight:           Font.Bold
                    color:                 Colors.colFg
                    Layout.preferredWidth: 44
                    horizontalAlignment:   Text.AlignRight
                }
            }
        }
    }
}

