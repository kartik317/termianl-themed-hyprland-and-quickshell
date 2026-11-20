import QtQuick

Item {
    id: root
    anchors.fill: parent

    property int length: 10
    property int thickness: 2
    property color color: Colors.colCyan

    // which corners to draw (top-left + bottom-right by default)
    property bool topLeft: true
    property bool bottomRight: true
    property bool topRight: false
    property bool bottomLeft: false

    // top-left
    Rectangle {
        visible: root.topLeft
        anchors { top: parent.top; left: parent.left }
        width: root.length; height: root.thickness; color: root.color
    }
    Rectangle {
        visible: root.topLeft
        anchors { top: parent.top; left: parent.left }
        width: root.thickness; height: root.length; color: root.color
    }

    // bottom-right
    Rectangle {
        visible: root.bottomRight
        anchors { bottom: parent.bottom; right: parent.right }
        width: root.length; height: root.thickness; color: root.color
    }
    Rectangle {
        visible: root.bottomRight
        anchors { bottom: parent.bottom; right: parent.right }
        width: root.thickness; height: root.length; color: root.color
    }

    // top-right
    Rectangle {
        visible: root.topRight
        anchors { top: parent.top; right: parent.right }
        width: root.length; height: root.thickness; color: root.color
    }
    Rectangle {
        visible: root.topRight
        anchors { top: parent.top; right: parent.right }
        width: root.thickness; height: root.length; color: root.color
    }

    // bottom-left
    Rectangle {
        visible: root.bottomLeft
        anchors { bottom: parent.bottom; left: parent.left }
        width: root.length; height: root.thickness; color: root.color
    }
    Rectangle {
        visible: root.bottomLeft
        anchors { bottom: parent.bottom; left: parent.left }
        width: root.thickness; height: root.length; color: root.color
    }
}
