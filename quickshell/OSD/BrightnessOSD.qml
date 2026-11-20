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

    // ── Style ───────────────────────────────────────────────────────────────
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property color accent: Colors.colCyan
    readonly property color line: Qt.alpha(Colors.colCyan, 0.35)

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "qs-brightness-osd-noanim"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: 0

    anchors.bottom: true
    anchors.left:   true
    anchors.right:  true
    implicitHeight: 100

    mask: Region {
        item: root.osdVisible ? maskCover : null
    }
    Item {
        id: maskCover
        anchors.fill: parent
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
    //  OSD card: instant show/hide, no slide/fade
    // ═══════════════════════════════════════════════════════════════════════
    Rectangle {
        id: osdCard
        width:  440
        height: 52
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     22

        visible: root.osdVisible

        radius: 0
        color: Qt.alpha(Colors.colBg, 0.88)
        border.color: root.line
        border.width: 1

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 12
                rightMargin: 12
            }
            spacing: 10

            // brightness icon, fixed width so the meter doesn't shift
            Text {
                Layout.preferredWidth: 20
                horizontalAlignment: Text.AlignHCenter
                text: root.brightness > 60 ? "\uf5fe"
                    : root.brightness > 20 ? "\uf042"
                    :                         "\uf5dd"
                font.pixelSize: 16
                font.family:    root.fontFamily
                color: root.accent
            }

            // blocky inverted tag
            Rectangle {
                implicitWidth: tagText.implicitWidth + 14
                implicitHeight: tagText.implicitHeight + 4
                color: root.accent

                Text {
                    id: tagText
                    anchors.centerIn: parent
                    text: "BRT"
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1
                    color: Colors.colBg
                }
	    }

	    // ── Segmented brightness meter ──────────────────────────────────
            Row {
                id: meter
                Layout.fillWidth: true
                Layout.preferredHeight: 12
                spacing: 3

                readonly property int segments: 20
                readonly property int filledSegments: Math.round(Math.min(root.brightness / 100.0, 1.0) * segments)

                // Calculate exact width for each square based on total available width minus total spacing
                readonly property real availableWidth: width - (spacing * (segments - 1))
                readonly property real segmentWidth: Math.floor(availableWidth / segments)

                Repeater {
                    model: meter.segments
                    delegate: Rectangle {
                        width: meter.segmentWidth
                        height: 12
                        radius: 0
                        color: index < meter.filledSegments
                               ? root.accent
                               : Qt.alpha(Colors.colCyan, 0.12)
                    }
                }
            }
            // value, zero-padded so the width never changes: 005%, 042%, 100%
            Text {
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignRight
                text: String(root.brightness).padStart(3, "0") + "%"
                font.pixelSize: 12
                font.family: root.fontFamily
                font.bold: true
                color: Colors.colFg
            }
        }

        // last child so it draws on top of the content
        CornerBrackets {}
    }
}
