import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../theme"

Item {
    property string fontFamily
    property int fontSize

    readonly property int cellWidth: 24

    implicitWidth: 9 * cellWidth
    implicitHeight: 30
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: 9

            Rectangle {
                id: cell
                Layout.preferredWidth: 24
                Layout.fillHeight: true

                property var workspace: Hyprland.workspaces.values.find(ws => ws.id === index + 1) ?? null
                property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
                property bool hasWindows: (workspace?.toplevels?.values?.length ?? 0) > 0
                property bool hovered: mouse.containsMouse

                // Active = solid cyan block (inverted), hover = dim cyan block, else flat
                color: isActive ? Colors.colCyan
                     : hovered ? Qt.alpha(Colors.colCyan, 0.2)
                     : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: index + 1
                    font.pixelSize: fontSize
                    font.family: fontFamily
                    font.bold: true
                    color: cell.isActive ? Colors.colBg
                         : cell.hasWindows ? Colors.colCyan
                         : cell.hovered ? Colors.colFg
                         : Colors.colBrightBlack
                }

                // Occupied marker: small tick at the bottom of inactive-but-used workspaces
                Rectangle {
                    visible: cell.hasWindows && !cell.isActive
                    width: 6
                    height: 2
                    color: Colors.colCyan
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + (index + 1) + " })")
                }
            }
        }
    }
}
