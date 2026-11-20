import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"

Item {
    id: clockRoot

    // ═══════════════════════════════════════════════════════════════════════
    //  TWEAK THESE: everything else derives from this block
    // ═══════════════════════════════════════════════════════════════════════
    property real baseFontSize: 48          // time size; everything scales off this
    property real tagFontScale: 0.28        // day tag size, relative to baseFontSize
    property real dateFontScale: 0.26       // date size, relative to baseFontSize
    property real promptFontScale: 0.22     // prompt line size, relative to baseFontSize

    property real lineSpacing: 10
    property real cursorSpacing: 6
    property real cursorWidthScale: 0.2    // block cursor width, relative to time size
    property real cursorHeightScale: 0.8    // block cursor height, relative to time size

    property string promptText: "linuxguy@arch:~$"   // change the hostname part to match yours
    property string promptCommand: "date"

    property bool blink: false               // bind this to your animations toggle
    property int blinkInterval: 530
    property bool showDayProgress: true
    property int progressCells: 20

    property string fontFamily: "JetBrainsMono Nerd Font"
    property color textColor: Colors.colCyan

    // ═══════════════════════════════════════════════════════════════════════
    //  Derived values
    // ═══════════════════════════════════════════════════════════════════════
    readonly property real timeFontSize: baseFontSize
    readonly property real tagFontSize: baseFontSize * tagFontScale
    readonly property real dateFontSize: baseFontSize * dateFontScale
    readonly property real promptFontSize: baseFontSize * promptFontScale

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    readonly property string dayOfWeek: Qt.formatDateTime(sysClock.date, "dddd").toUpperCase()
    readonly property string fullDate: Qt.formatDateTime(sysClock.date, "dd MMMM, yyyy").toUpperCase()
    readonly property string timeStr: Qt.formatDateTime(sysClock.date, "HH:mm")

    readonly property real dayProgress:
        (sysClock.date.getHours() * 60 + sysClock.date.getMinutes()) / 1440
    readonly property int filledCells: Math.round(dayProgress * progressCells)

    // Hard on/off cursor blink (no fading)
    property bool cursorOn: true
    Timer {
        interval: clockRoot.blinkInterval
        running: clockRoot.blink && clockRoot.visible
        repeat: true
        onTriggered: clockRoot.cursorOn = !clockRoot.cursorOn
    }

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: clockRoot.lineSpacing

        // ── Prompt line ─────────────────────────────────────────────────────
        Row {
            spacing: 8

            Text {
                text: clockRoot.promptText
                font.family: clockRoot.fontFamily
                font.pixelSize: clockRoot.promptFontSize
                color: clockRoot.textColor
                opacity: 0.5
            }
            Text {
                text: clockRoot.promptCommand
                font.family: clockRoot.fontFamily
                font.pixelSize: clockRoot.promptFontSize
                font.bold: true
                color: clockRoot.textColor
            }
        }

        // ── Time + block cursor ─────────────────────────────────────────────
        Row {
            spacing: clockRoot.cursorSpacing

            Text {
                text: clockRoot.timeStr
                font.family: clockRoot.fontFamily
                font.bold: true
                font.pixelSize: clockRoot.timeFontSize
                color: clockRoot.textColor
            }

            Rectangle {
                width: clockRoot.timeFontSize * clockRoot.cursorWidthScale
                height: clockRoot.timeFontSize * clockRoot.cursorHeightScale
                anchors.verticalCenter: parent.verticalCenter
                color: clockRoot.textColor
                visible: !clockRoot.blink || clockRoot.cursorOn
            }
        }

        // ── Divider (stretches to the widest line) ──────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(clockRoot.textColor, 0.35)
        }

        // ── Day tag + date ──────────────────────────────────────────────────
        Row {
            spacing: 10

            // Blocky inverted tag
            Rectangle {
                width: dayText.implicitWidth + 16
                height: dayText.implicitHeight + 4
                color: clockRoot.textColor

                Text {
                    id: dayText
                    anchors.centerIn: parent
                    text: clockRoot.dayOfWeek
                    font.family: clockRoot.fontFamily
                    font.bold: true
                    font.pixelSize: clockRoot.tagFontSize
                    font.letterSpacing: clockRoot.tagFontSize * 0.1
                    color: Colors.colBg
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: clockRoot.fullDate
                font.family: clockRoot.fontFamily
                font.pixelSize: clockRoot.dateFontSize
                color: clockRoot.textColor
                opacity: 0.7
            }
        }

        // ── Day progress bar: [████░░░░] 62% ────────────────────────────────
        Row {
            visible: clockRoot.showDayProgress
            spacing: 0

            Text {
                text: "["
                font.family: clockRoot.fontFamily
                font.pixelSize: clockRoot.dateFontSize
                color: clockRoot.textColor
                opacity: 0.5
            }
            Text {
                text: "█".repeat(clockRoot.filledCells)
                font.family: clockRoot.fontFamily
                font.pixelSize: clockRoot.dateFontSize
                color: clockRoot.textColor
            }
            Text {
                text: "░".repeat(clockRoot.progressCells - clockRoot.filledCells)
                font.family: clockRoot.fontFamily
                font.pixelSize: clockRoot.dateFontSize
                color: clockRoot.textColor
                opacity: 0.3
            }
            Text {
                text: "] " + Math.round(clockRoot.dayProgress * 100) + "%"
                font.family: clockRoot.fontFamily
                font.pixelSize: clockRoot.dateFontSize
                color: clockRoot.textColor
                opacity: 0.5
            }
        }
    }
}
