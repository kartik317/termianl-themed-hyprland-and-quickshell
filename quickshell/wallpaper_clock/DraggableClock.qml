import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"

Item {
    id: root
    property int posX: 50
    property int posY: 50
    required property var screen

    property int padding: 16

    IpcHandler {
        target: "clock-widget"
        function toggle() {
            ClockState.toggle()
        }
    }

    width: clockWidget.implicitWidth + padding * 2
    height: clockWidget.implicitHeight + padding * 2

    Component.onCompleted: {
        x = posX;
        y = posY;
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.SizeAllCursor
        drag.target: root
        drag.axis: Drag.XAndYAxis
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: root.screen.width - root.width
        drag.maximumY: root.screen.height - root.height
    }

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Qt.alpha(Colors.colBg, 0.5)
        border.color: Qt.alpha(Colors.colCyan, 0.85)
        border.width: 1
    }

    WallpaperClock {
        id: clockWidget
        anchors.centerIn: parent
    }
}
