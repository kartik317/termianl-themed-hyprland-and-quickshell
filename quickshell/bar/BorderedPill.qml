import QtQuick
import "../theme"

Rectangle {
    id: root

    // Set to false on pills where you don't want the corner brackets
    property bool brackets: true
    property color accent: Colors.colCyan

    radius: 0
    border.width: 1
    border.color: Qt.alpha(root.accent, 0.35)

    CornerBrackets {
        visible: root.brackets
        color: root.accent
    }
}
