import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

RowLayout {
    id: root
    spacing: 2

    // State properties
    property bool isSelecting: false
    property int selectedIndex: 0
    readonly property int totalApps: apps.length

    // Add or reorder apps here, everything else follows
    readonly property var apps: [
        { icon: "\uf16a",         size: 18, cmd: ["brave", "--app-id=agimnkijcaahngcdmfeangaknmldooml"] }, // YouTube
        { icon: "\uf1ff",         size: 18, cmd: ["com.discordapp.Discord"] },                            // Discord
        { icon: "\udb80\udf73",   size: 18, cmd: ["io.mrarm.mcpelauncher"] },                             // Minecraft
        { icon: "\uf1b7",         size: 18, cmd: ["steam"] },                                             // Steam
        { icon: "\udb80\ude39",   size: 20, cmd: ["brave"] },                                             // Brave
        { icon: "\udb80\udf86",   size: 20, cmd: ["brave", "--app-id=cinhimbnkkaeohfgghhklpknlkffjgod"] } // YT Music
    ]

    function launchIndex(idx) {
        if (idx < 0 || idx >= apps.length) return;
        Quickshell.execDetached(apps[idx].cmd);
    }

    IpcHandler {
        target: "appshortcuts"

        function off(): void {
            root.isSelecting = false;
        }

        function next(): void {
            if (!root.isSelecting) {
                root.isSelecting = true;
            } else {
                root.selectedIndex = (root.selectedIndex + 1) % root.totalApps;
            }
        }

        function prev(): void {
            if (!root.isSelecting) {
                root.isSelecting = true;
            } else {
                root.selectedIndex = (root.selectedIndex - 1 + root.totalApps) % root.totalApps;
            }
        }

        function launch(): void {
            if (root.isSelecting) {
                root.launchIndex(root.selectedIndex);
                root.isSelecting = false;
            }
        }
    }

    Repeater {
        model: root.apps

        Rectangle {
            id: cell
            Layout.preferredWidth: 26
            Layout.preferredHeight: 28

            property bool selected: root.isSelecting && root.selectedIndex === index
            property bool hovered: mouse.containsMouse

            // Selected = solid cyan block, hover = dim cyan block, else flat
            color: selected ? Colors.colCyan
                 : hovered ? Qt.alpha(Colors.colCyan, 0.2)
                 : "transparent"

            Text {
                anchors.centerIn: parent
                text: modelData.icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: modelData.size
                color: cell.selected ? Colors.colBg
                     : cell.hovered ? Colors.colCyan
                     : Colors.colFg
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selectedIndex = index;
                    root.launchIndex(index);
                    root.isSelecting = false;
                }
            }
        }
    }
}
