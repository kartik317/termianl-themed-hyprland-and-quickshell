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

    property int padding: 20

    readonly property bool dragging: mouse.drag.active
    readonly property int bracketLen: 10
    readonly property int bracketThickness: 2

    IpcHandler {
        target: "clock-widget"
        function toggle(): void {
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
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.SizeAllCursor
        drag.target: root
        drag.axis: Drag.XAndYAxis
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: root.screen.width - root.width
        drag.maximumY: root.screen.height - root.height
    }

    // Frame: dim at rest, brighter on hover, solid while dragging (instant swaps)
    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Qt.alpha(Colors.colBg, root.dragging ? 0.75 : 0.55)
        border.width: 1
        border.color: Qt.alpha(Colors.colCyan,
            root.dragging ? 1.0 : mouse.containsMouse ? 0.6 : 0.35)
    }

    // Corner brackets (top-left, bottom-right), same as the bar pills
    Rectangle { x: 0; y: 0; width: root.bracketLen; height: root.bracketThickness; color: Colors.colCyan }
    Rectangle { x: 0; y: 0; width: root.bracketThickness; height: root.bracketLen; color: Colors.colCyan }
    Rectangle {
        x: root.width - width; y: root.height - height
        width: root.bracketLen; height: root.bracketThickness; color: Colors.colCyan
    }
    Rectangle {
        x: root.width - width; y: root.height - height
        width: root.bracketThickness; height: root.bracketLen; color: Colors.colCyan
    }

    WallpaperClock {
        id: clockWidget
        anchors.centerIn: parent
    }
}
