import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"

RowLayout {
    id: root
    spacing: 8

    property string fontFamily: "JetBrainsMono Nerd Font"

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Dim date, bright time
    Text {
        text: Qt.formatDateTime(clock.date, "ddd dd MMM").toUpperCase()
        color: Colors.colBrightBlack
        font.family: root.fontFamily
        font.pixelSize: 12
        font.bold: true
    }

    Text {
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Colors.colCyan
        font.family: root.fontFamily
        font.pixelSize: 15
        font.bold: true
    }
}
