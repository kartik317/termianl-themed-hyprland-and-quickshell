import QtQuick
import QtQuick.Effects
import "../theme"

Rectangle {
    id: root

    property color glowColor: Colors.colCyan
    border.width: 1
    border.color: Qt.alpha(glowColor, 0.8) 
}
