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

    property int  _lastVol:   -1
    property bool _lastMuted: false
    property bool osdVisible: false
    property int  vol:        0
    property bool muted:      false

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "qs-vol-osd-noanim"
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

    // ── Watchdog: revive pactl if it dies ──────────────────────────────────
    Timer {
        id: pactlRestartTimer
        interval: 1500
        onTriggered: {
            if (!pactlSub.running)
                pactlSub.running = true
        }
    }

    // ── PipeWire event watcher (long-lived) ────────────────────────────────
    Process {
        id: pactlSub
        command: ["pactl", "subscribe"]
        running: true
        onRunningChanged: {
            if (!running) pactlRestartTimer.start()
        }
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("change") && data.includes("sink") && !volQuery.running)
                    volQuery.running = true
            }
        }
    }

    // ── Volume query (short-lived, re-run on each event) ───────────────────
    Process {
        id: volQuery
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                const newMuted = data.includes("[MUTED]")
                const m        = data.match(/([\d.]+)/)
                if (!m) return
                const newVol = Math.round(parseFloat(m[1]) * 100)
                const volChanged   = newVol   !== root._lastVol
                const muteChanged  = newMuted !== root._lastMuted
                root._lastVol   = newVol
                root._lastMuted = newMuted
                root.vol = newVol
                root.muted = newMuted
                if (volChanged || muteChanged) {
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
        width:  340
        height: 56
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     22

        visible: root.osdVisible

        radius: 0
        color: "transparent"
        border.color: Colors.colCyan
        border.width: 1

        // ── Inner fill (matches launcher/power menu/brightness panel) ───────
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
                    text: root.muted    ? "\uf026"
                        : root.vol > 60 ? "\uf028"
                        : root.vol > 0  ? "\uf027"
                        :                 "\uf026"
                    font.pixelSize: 16
                    font.family:    "JetBrainsMono Nerd Font"
                    color: root.muted ? Colors.colRed : Colors.colBlue
                }

                // ── Segmented volume meter (matches brightness slider style) ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    readonly property int segments: 20
                    readonly property int filledSegments: Math.round(Math.min(root.vol / 100.0, 1.0) * segments)

                    Repeater {
                        model: parent.segments
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 10
                            radius: 0
                            border.width: 1
                            border.color: Qt.rgba(Colors.colFg.r, Colors.colFg.g, Colors.colFg.b, 0.1)
                            color: index < parent.filledSegments
                                   ? (root.muted ? Colors.colRed : Colors.colBlue)
                                   : Qt.rgba(Colors.colFg.r, Colors.colFg.g, Colors.colFg.b, 0.12)
                        }
                    }
                }

                Text {
                    text:                  root.muted ? "MUTE" : root.vol + "%"
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
