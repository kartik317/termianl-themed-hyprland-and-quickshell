import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import Quickshell.Io
import "../theme"

MouseArea {
    id: root
    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: function(event) { nmProcess.running = true; }

    property string fontFamily: "JetBrainsMono Nerd Font"

    Process {
        id: nmProcess
        command: ["kitty", "-e", "nmtui"]
    }

    property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
    property var active: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) : null

    readonly property real signal: active ? active.signalStrength : 0
    readonly property int maxNameLength: 12
    readonly property bool hovered: root.containsMouse

    readonly property string displayName: {
        if (!active) return ""
        let name = active.name
        return name.length > maxNameLength
            ? name.substring(0, maxNameLength) + "…"
            : name
    }

    readonly property string icon: {
        if (!Networking.wifiEnabled) return String.fromCodePoint(0xF05AA)
        if (!active) return String.fromCodePoint(0xF092D)

        let tier = signal >= 0.75 ? 4
            : signal >= 0.5 ? 3
            : signal >= 0.25 ? 2
            : 1

        return String.fromCodePoint(0xF091F + (tier - 1) * 3)
    }

    readonly property color tone: !Networking.wifiEnabled ? Colors.colBrightBlack
                                : !active ? "#e06c75"
                                : hovered ? Colors.colCyan
                                : Colors.colFg

    RowLayout {
        id: layout
        anchors.fill: parent
        spacing: 6

        Text {
            text: root.icon
            color: root.tone
            font.family: root.fontFamily
            font.pixelSize: 14
        }

        Text {
            text: {
                if (!Networking.wifiEnabled) return "off"
                if (!root.active) return "no_link"
                return root.displayName
            }
            color: root.tone
            font.family: root.fontFamily
            font.pixelSize: 13
            font.bold: true
        }
    }
}
