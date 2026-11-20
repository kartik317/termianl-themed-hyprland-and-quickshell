import Quickshell
import QtQuick
import QtQuick.Layouts
import "../theme"
import Quickshell.Services.UPower

RowLayout {
    id: root
    spacing: 6

    property string fontFamily: "JetBrainsMono Nerd Font"

    property var battery: UPower.displayDevice
    property bool charging: battery.state === UPowerDeviceState.Charging

    readonly property int level: Math.round(battery.percentage * 100)
    readonly property bool low: level <= 20 && !charging

    readonly property string icon: {
        if (charging) return String.fromCodePoint(0xF0084)
        if (level >= 100) return String.fromCodePoint(0xF0079)
        if (level < 10) return String.fromCodePoint(0xF0083)
        return String.fromCodePoint(0xF007A + (Math.floor(level / 10) - 1))
    }

    Text {
        text: root.icon
        color: root.low ? "#e06c75" : root.charging ? Colors.colCyan : Colors.colFg
        font.family: root.fontFamily
        font.pixelSize: 14
    }

    // Low battery becomes a solid red block, charging is cyan
    Rectangle {
        implicitWidth: pct.implicitWidth + 8
        implicitHeight: pct.implicitHeight + 2
        color: root.low ? "#e06c75" : "transparent"

        Text {
            id: pct
            anchors.centerIn: parent
            text: root.level + "%"
            color: root.low ? Colors.colBg : root.charging ? Colors.colCyan : Colors.colFg
            font.family: root.fontFamily
            font.pixelSize: 13
            font.bold: true
        }
    }
}
