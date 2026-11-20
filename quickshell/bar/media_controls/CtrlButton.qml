import QtQuick
import "../../theme"

Rectangle {
    id: btn

    property string icon
    property int iconSize: 18
    property bool lit: true        // false = dimmed (disabled / toggle off)
    property bool solid: false     // true = filled cyan block (play/pause)
    property string fontFamily: "JetBrainsMono Nerd Font"
    signal clicked()

    implicitWidth: 26
    implicitHeight: 26

    color: solid ? Colors.colCyan
         : mouse.containsMouse ? Qt.alpha(Colors.colCyan, 0.2)
         : "transparent"

    Text {
        anchors.centerIn: parent
        text: btn.icon
        font.family: btn.fontFamily
        font.pixelSize: btn.iconSize
        color: btn.solid ? Colors.colBg
             : !btn.lit ? Colors.colBrightBlack
             : mouse.containsMouse ? Colors.colCyan
             : Colors.colFg
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: function(event) { btn.clicked(); }
    }
}
