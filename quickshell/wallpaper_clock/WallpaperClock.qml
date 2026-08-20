import QtQuick
import Quickshell
import "../theme"

Item {
    id: clockRoot

    // ═══════════════════════════════════════════════════════════════════════
    //  TWEAK THESE — everything else derives from this block
    // ═══════════════════════════════════════════════════════════════════════
    property real baseFontSize: 36      // day-of-week size; everything scales off this
    property real dateFontScale: 0.5   // date line size, relative to baseFontSize
    property real timeFontScale: 0.55   // time line size, relative to baseFontSize
    property real promptFontScale: 0.7  // ">" prompt size, relative to baseFontSize

    property real letterSpacingScale: 0.11  // day-of-week letter spacing, relative to its font size
    property real promptSpacing: 6          // gap between ">" and day-of-week text
    property real cursorSpacing: 4          // gap between time text and block cursor
    property real lineSpacing: 8            // vertical gap between the three lines

    property real cursorWidthScale: 0.4   // block cursor width, relative to timeFontSize
    property real cursorHeightScale: 0.85 // block cursor height, relative to timeFontSize

    property color textColor: Colors.colCyan

    // ═══════════════════════════════════════════════════════════════════════
    //  Derived sizes — no need to touch these
    // ═══════════════════════════════════════════════════════════════════════
    readonly property real dateFontSize: baseFontSize * dateFontScale
    readonly property real timeFontSize: baseFontSize * timeFontScale
    readonly property real promptFontSize: baseFontSize * promptFontScale

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    property string dayOfWeek: Qt.formatDateTime(sysClock.date, "dddd").toUpperCase()
    property string fullDate: Qt.formatDateTime(sysClock.date, "dd MMMM, yyyy").toUpperCase()
    property string timeStr: Qt.formatDateTime(sysClock.date, "HH:mm")

    Column {
        id: col
        anchors.centerIn: parent
        spacing: clockRoot.lineSpacing

        // ── Day of week ─────────────────────────────────────────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: clockRoot.promptSpacing

            Text {
                text: ">"
                font.family: "JetBrainsMono Nerd Font"
                font.weight: Font.Bold
                font.pixelSize: clockRoot.promptFontSize
                color: clockRoot.textColor
                opacity: 0.6
            }

            Text {
                text: clockRoot.dayOfWeek
                font.family: "JetBrainsMono Nerd Font"
                font.weight: Font.Bold
                font.pixelSize: clockRoot.baseFontSize
                font.letterSpacing: clockRoot.baseFontSize * clockRoot.letterSpacingScale
                color: clockRoot.textColor
            }
        }

        // ── Full date ───────────────────────────────────────────────────────
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: clockRoot.fullDate
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: clockRoot.dateFontSize
            color: clockRoot.textColor
            opacity: 0.7
        }

        // ── Time ────────────────────────────────────────────────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: clockRoot.cursorSpacing

            Text {
                text: clockRoot.timeStr
                font.family: "JetBrainsMono Nerd Font"
                font.weight: Font.Bold
                font.pixelSize: clockRoot.timeFontSize
                color: clockRoot.textColor
            }

            // Static block cursor, terminal-style
            Rectangle {
                width: clockRoot.timeFontSize * clockRoot.cursorWidthScale
                height: clockRoot.timeFontSize * clockRoot.cursorHeightScale
                anchors.verticalCenter: parent.verticalCenter
                color: clockRoot.textColor
            }
        }
    }
}
