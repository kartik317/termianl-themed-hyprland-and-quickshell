import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../theme"

Scope {
    id: root

    // qs ipc call notifs toggle | open | close | clear
    IpcHandler {
        target: "notifs"

        function toggle(): void { NotificationState.open = !NotificationState.open }
        function open(): void { NotificationState.open = true }
        function close(): void { NotificationState.open = false }
        function clear(): void { NotificationState.clearAll() }

        // qs ipc call notifs dismissToast | dismissAllToasts
        function dismissToast(): void { NotificationState.hideNewestPopup() }
        function dismissAllToasts(): void { NotificationState.hideAllPopups() }

        // qs ipc call notifs toggleDnd | dndOn | dndOff | dndState
        function toggleDnd(): void { NotificationState.dnd = !NotificationState.dnd }
        function dndOn(): void { NotificationState.dnd = true }
        function dndOff(): void { NotificationState.dnd = false }
        function dndState(): string { return NotificationState.dnd ? "on" : "off" }
    }

    NotificationToasts {}

    PanelWindow {
        id: win

        // Window only exists while open, so no input mask is needed.
        visible: NotificationState.open
        color: "transparent"

        anchors {
            bottom: true
            right: true
        }
        margins {
            bottom: 12
            right: 12
        }
        implicitWidth: 420
        implicitHeight: 560

        WlrLayershell.namespace: "notificationcenter"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        readonly property string mono: "JetBrainsMono Nerd Font"
        readonly property color critColor: "#ff5555"
        readonly property color dim: Qt.rgba(Colors.colFg.r, Colors.colFg.g, Colors.colFg.b, 0.55)
        readonly property color faint: Qt.rgba(Colors.colCyan.r, Colors.colCyan.g, Colors.colCyan.b, 0.3)
        readonly property color tint: Qt.rgba(Colors.colCyan.r, Colors.colCyan.g, Colors.colCyan.b, 0.08)

        Connections {
            target: NotificationState

            function onOpenChanged() {
                if (NotificationState.open) {
                    list.currentIndex = 0
                    keys.forceActiveFocus()
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Colors.colBg, 0.65)
            border.color: Colors.colCyan
            border.width: 1
            radius: 0

            Item {
                id: keys
                anchors.fill: parent
                focus: true

                Keys.onPressed: function(event) {
                    var n = NotificationState.items[list.currentIndex]
                    switch (event.key) {
                    case Qt.Key_Escape:
                    case Qt.Key_Q:
                        NotificationState.open = false
                        break
                    case Qt.Key_J:
                    case Qt.Key_Down:
                        list.incrementCurrentIndex()
                        break
                    case Qt.Key_K:
                    case Qt.Key_Up:
                        list.decrementCurrentIndex()
                        break
                    case Qt.Key_X:
                    case Qt.Key_Delete:
                        if (n) n.dismiss()
                        break
                    case Qt.Key_C:
                        NotificationState.clearAll()
                        break
                    case Qt.Key_D:
                        NotificationState.dnd = !NotificationState.dnd
                        break
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (n && n.actions.length > 0) n.actions[0].invoke()
                        break
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // ── header ─────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: ">"
                            color: Colors.colCyan
                            font.family: win.mono
                            font.pixelSize: 14
                            font.bold: true
                        }
                        Text {
                            text: "notifications"
                            color: Colors.colFg
                            font.family: win.mono
                            font.pixelSize: 14
                        }
                        Item { Layout.fillWidth: true }

                        // dnd tag
                        Rectangle {
                            implicitWidth: dndText.implicitWidth + 10
                            implicitHeight: 18
                            radius: 0
                            color: NotificationState.dnd ? win.critColor
                                 : dndArea.containsMouse ? win.faint : "transparent"
                            border.width: 1
                            border.color: NotificationState.dnd ? win.critColor : win.faint

                            Text {
                                id: dndText
                                anchors.centerIn: parent
                                text: NotificationState.dnd ? "DND ON" : "DND OFF"
                                color: NotificationState.dnd ? Colors.colBg : win.dim
                                font.family: win.mono
                                font.pixelSize: 10
                                font.bold: NotificationState.dnd
                            }
                            MouseArea {
                                id: dndArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: NotificationState.dnd = !NotificationState.dnd
                            }
                        }

                        // clear-all tag
                        Rectangle {
                            implicitWidth: clearText.implicitWidth + 10
                            implicitHeight: 18
                            radius: 0
                            visible: NotificationState.count > 0
                            color: clearArea.containsMouse ? win.critColor : "transparent"
                            border.width: 1
                            border.color: clearArea.containsMouse ? win.critColor : win.faint

                            Text {
                                id: clearText
                                anchors.centerIn: parent
                                text: "CLEAR"
                                color: clearArea.containsMouse ? Colors.colBg : win.dim
                                font.family: win.mono
                                font.pixelSize: 10
                            }
                            MouseArea {
                                id: clearArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: NotificationState.clearAll()
                            }
                        }

                        // count tag
                        Rectangle {
                            implicitWidth: countText.implicitWidth + 10
                            implicitHeight: 18
                            radius: 0
                            color: Colors.colCyan

                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: NotificationState.count
                                color: Colors.colBg
                                font.family: win.mono
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Colors.colCyan
                    }

                    // ── list ───────────────────────────────
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListView {
                            id: list
                            anchors.fill: parent
                            clip: true
                            spacing: 6
                            model: NotificationState.items
                            currentIndex: 0
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                id: card

                                required property var modelData
                                required property int index

                                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                                readonly property bool low: modelData.urgency === NotificationUrgency.Low
                                readonly property bool selected: ListView.isCurrentItem

                                width: ListView.view.width
                                implicitHeight: col.implicitHeight + 16
                                height: implicitHeight
                                radius: 0
                                color: selected ? win.tint : "transparent"
                                border.width: 1
                                border.color: selected ? Colors.colCyan : win.faint

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: list.currentIndex = card.index
                                }

                                ColumnLayout {
                                    id: col
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: parent.top
                                        margins: 8
                                    }
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        // urgency tag
                                        Rectangle {
                                            implicitWidth: tagText.implicitWidth + 8
                                            implicitHeight: 16
                                            radius: 0
                                            color: card.critical ? win.critColor
                                                 : card.low ? win.dim
                                                 : Colors.colCyan

                                            Text {
                                                id: tagText
                                                anchors.centerIn: parent
                                                text: card.critical ? "CRIT" : card.low ? "LOW" : "INFO"
                                                color: Colors.colBg
                                                font.family: win.mono
                                                font.pixelSize: 10
                                                font.bold: true
                                            }
                                        }

                                        Text {
                                            text: card.modelData.appName.toLowerCase()
                                            color: Colors.colFg
                                            font.family: win.mono
                                            font.pixelSize: 11
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: Qt.formatDateTime(
                                                new Date(NotificationState.stamps[card.modelData.id] || Date.now()),
                                                "HH:mm")
                                            color: win.dim
                                            font.family: win.mono
                                            font.pixelSize: 10
                                        }

                                        Text {
                                            text: "x"
                                            color: xArea.containsMouse ? win.critColor : win.dim
                                            font.family: win.mono
                                            font.pixelSize: 12
                                            font.bold: true

                                            MouseArea {
                                                id: xArea
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                hoverEnabled: true
                                                onClicked: card.modelData.dismiss()
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: text.length > 0
                                        text: card.modelData.summary
                                        color: Colors.colFg
                                        font.family: win.mono
                                        font.pixelSize: 13
                                        font.bold: true
                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: text.length > 0
                                        text: card.modelData.body
                                        textFormat: Text.PlainText
                                        color: win.dim
                                        font.family: win.mono
                                        font.pixelSize: 12
                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                        maximumLineCount: 4
                                        elide: Text.ElideRight
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        visible: card.modelData.actions.length > 0

                                        Repeater {
                                            model: card.modelData.actions

                                            delegate: Rectangle {
                                                id: btn
                                                required property var modelData

                                                implicitWidth: btnText.implicitWidth + 12
                                                implicitHeight: 20
                                                radius: 0
                                                color: btnArea.containsMouse ? Colors.colCyan : "transparent"
                                                border.width: 1
                                                border.color: Colors.colCyan

                                                Text {
                                                    id: btnText
                                                    anchors.centerIn: parent
                                                    text: btn.modelData.text
                                                    color: btnArea.containsMouse ? Colors.colBg : Colors.colCyan
                                                    font.family: win.mono
                                                    font.pixelSize: 11
                                                }
                                                MouseArea {
                                                    id: btnArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: btn.modelData.invoke()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: NotificationState.count === 0
                            anchors.centerIn: parent
                            text: "$ no notifications"
                            color: win.dim
                            font.family: win.mono
                            font.pixelSize: 13
                        }
                    }

                    // ── footer ─────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: win.faint
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "j/k move  x dismiss  ⏎ act  c clear  d dnd  esc close"
                        color: win.dim
                        font.family: win.mono
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
