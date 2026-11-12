import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../theme"
// Small popups for incoming notifications.
//   left click  -> hide the toast (stays in history)
//   right click -> dismiss it completely
// Hovering pauses the timeout.
//
// Uses Column (not ColumnLayout) on purpose: layouts compute their
// implicit height before wrapped text is laid out, which clips the
// bottom of the card. Column sizes from the actual child heights.

Scope {
    PanelWindow {
        id: win

        // Window only exists while there are toasts, and is sized to fit
        // them exactly, so it never blocks clicks on anything else.
        visible: NotificationState.popups.length > 0
        color: "transparent"

        anchors {
            bottom: true
            right: true
        }
        margins {
            bottom: 12
            right: 12
        }
        implicitWidth: 360
        implicitHeight: stack.height

        WlrLayershell.namespace: "notificationtoast"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        readonly property string mono: "JetBrainsMono Nerd Font"
        readonly property color crit: "#ff5555"
        readonly property color dim: Qt.rgba(Colors.colFg.r, Colors.colFg.g, Colors.colFg.b, 0.55)

        Column {
            id: stack
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            spacing: 6

            Repeater {
                // ScriptModel diffs the list, so existing toasts keep
                // their timers when a new one arrives.
                model: ScriptModel {
                    values: NotificationState.popups
                }

                delegate: Rectangle {
                    id: toast

                    required property var modelData

                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                    readonly property bool low: modelData.urgency === NotificationUrgency.Low

                    width: stack.width
                    height: col.height + 16
                    radius: 0
                    color: Qt.alpha(Colors.colBg, 0.65)
                    border.width: 1
                    border.color: critical ? win.crit : Colors.colCyan

                    Timer {
                        // critical: 10s, otherwise the app's timeout or 5s
                        interval: toast.critical ? 10000
                                : (toast.modelData.expireTimeout > 0
                                   ? toast.modelData.expireTimeout * 1000 : 5000)
                        running: !area.containsMouse
                        onTriggered: NotificationState.removePopup(toast.modelData)
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton)
                                toast.modelData.dismiss()
                            else
                                NotificationState.removePopup(toast.modelData)
                        }
                    }

                    Column {
                        id: col
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 8
                        }
                        spacing: 4

                        Row {
                            spacing: 6

                            Rectangle {
                                width: tagText.implicitWidth + 8
                                height: 16
                                radius: 0
                                color: toast.critical ? win.crit
                                     : toast.low ? win.dim
                                     : Colors.colCyan

                                Text {
                                    id: tagText
                                    anchors.centerIn: parent
                                    text: toast.critical ? "CRIT" : toast.low ? "LOW" : "INFO"
                                    color: Colors.colBg
                                    font.family: win.mono
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: toast.modelData.appName.toLowerCase()
                                color: Colors.colFg
                                font.family: win.mono
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            width: col.width
                            visible: text.length > 0
                            text: toast.modelData.summary
                            color: Colors.colFg
                            font.family: win.mono
                            font.pixelSize: 13
                            font.bold: true
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            width: col.width
                            visible: text.length > 0
                            text: toast.modelData.body
                            textFormat: Text.PlainText
                            color: win.dim
                            font.family: win.mono
                            font.pixelSize: 12
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
