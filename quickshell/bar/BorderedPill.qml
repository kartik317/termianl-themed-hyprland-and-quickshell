import QtQuick
import QtQuick.Effects
import "../theme"

Rectangle {
    id: root

    // Tweak per-instance
    property color glowColor: Colors.colCyan
    property real glowOpacity: 0.85   // intensity of the glow
    property real glowRadius: 18      // blur size in px — bigger = softer/wider glow
    property real glowSpread: 3       // how far the glow ring extends past the pill edge

    border.width: 1
    border.color: Qt.alpha(glowColor, 0.8) 
}
