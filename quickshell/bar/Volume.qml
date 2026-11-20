import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../theme"

MouseArea {
    id: root
    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    property string fontFamily: "JetBrainsMono Nerd Font"

    property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink && sink.ready
    readonly property bool muted: ready && sink.audio.muted
    readonly property int vol: ready ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool hovered: root.containsMouse

    readonly property string icon: {
        if (!ready) return String.fromCodePoint(0xF0581)
        if (muted) return "\udb81\udd81"
        if (vol === 0) return String.fromCodePoint(0xF0581)
        if (vol < 34) return String.fromCodePoint(0xF057F)
        if (vol < 67) return String.fromCodePoint(0xF0580)
        return String.fromCodePoint(0xF057E)
    }

    // Reserve width so the pill doesn't resize between 5% and 100%
    TextMetrics {
        id: widest
        font.family: root.fontFamily
        font.pixelSize: 13
        font.bold: true
        text: "100%"
    }

    onWheel: function(wheel) {
        if (!root.ready) return;
        let step = 0.01;
        let currentVol = root.sink.audio.volume;
        if (wheel.angleDelta.y > 0) {
            root.sink.audio.volume = Math.min(1.0, currentVol + step);
        } else if (wheel.angleDelta.y < 0) {
            root.sink.audio.volume = Math.max(0.0, currentVol - step);
        }
    }

    onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) {
            wiremixProcess.running = true;
        } else if (mouse.button === Qt.LeftButton) {
            if (root.ready) {
                root.sink.audio.muted = !root.sink.audio.muted;
            }
        }
    }

    Process {
        id: wiremixProcess
        command: ["kitty", "-e", "wiremix"]
    }

    PwObjectTracker {
        objects: [root.sink]
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        spacing: 6

        Text {
            text: root.icon
            color: root.muted ? Colors.colBrightBlack : root.hovered ? Colors.colCyan : Colors.colFg
            font.family: root.fontFamily
            font.pixelSize: 16
        }

        Rectangle {
            Layout.preferredWidth: widest.width + 8
            implicitHeight: label.implicitHeight + 2
            color: root.muted ? Colors.colCyan : "transparent"

            Text {
                id: label
                anchors.centerIn: parent
                text: {
                    if (!root.ready) return "_"
                    if (root.muted) return "MUTE"
                    return root.vol + "%"
                }
                color: root.muted ? Colors.colBg : root.hovered ? Colors.colCyan : Colors.colFg
                font.family: root.fontFamily
                font.pixelSize: 13
                font.bold: true
            }
        }
    }
}
