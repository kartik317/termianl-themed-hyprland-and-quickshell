import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../theme"
import "../setting_menu"
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
        readonly property color danger: "#e06c75"
        readonly property color line: Qt.alpha(Colors.colCyan, 0.35)
        readonly property color chip: Qt.alpha(Colors.colCyan, 0.15)

        // ── Sound effects (silent automatically when sound is off) ───────────
        // One sound per change in the number of toasts, so dismissing all
        // toasts at once plays a single close sound.
        Sfx {
            id: popSfx
            file: "notification/popup.wav"
        }
        Sfx {
            id: popCloseSfx
            file: "notification/close.wav"
        }

        property int popupCount: NotificationState.popups.length
        property int lastPopupCount: 0

        onPopupCountChanged: {
            if (popupCount > lastPopupCount)
                popSfx.play()
            else if (popupCount < lastPopupCount)
                popCloseSfx.play()
            lastPopupCount = popupCount
        }

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

                // The root item keeps the full layout size (so the stack and
                // the window size never jitter); the frame inside it is what
                // animates, growing from the bottom-right corner.
                delegate: Item {
                    id: toast

                    required property var modelData

                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                    readonly property bool low: modelData.urgency === NotificationUrgency.Low
                    readonly property color accent: critical ? win.danger : Colors.colCyan

                    property real openW: 0
                    property real openH: 0
                    property real flick: 1

                    width: stack.width
                    height: col.height + 16

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

                    // ── Appear: line extends left, grows upward, then flickers ─
                    Component.onCompleted: {
                        if (Settings.animationsEnabled) {
                            appearAnim.start()
                        } else {
                            toast.openW = 1
                            toast.openH = 1
                        }
                    }

                    SequentialAnimation {
                        id: appearAnim

                        NumberAnimation {
                            target: toast
                            property: "openW"
                            to: 1
                            duration: 70
                            easing.type: Easing.OutCubic
                        }

                        ParallelAnimation {
                            NumberAnimation {
                                target: toast
                                property: "openH"
                                to: 1
                                duration: 90
                                easing.type: Easing.OutQuart
                            }

                            SequentialAnimation {
                                PauseAnimation {
                                    duration: 90
                                }
                                NumberAnimation {
                                    target: toast
                                    property: "flick"
                                    to: 0.4
                                    duration: 25
                                }
                                NumberAnimation {
                                    target: toast
                                    property: "flick"
                                    to: 1.0
                                    duration: 25
                                }
                                NumberAnimation {
                                    target: toast
                                    property: "flick"
                                    to: 0.7
                                    duration: 25
                                }
                                NumberAnimation {
                                    target: toast
                                    property: "flick"
                                    to: 1.0
                                    duration: 25
                                }
                            }
                        }

                        ScriptAction {
                            script: toast.flick = 1
                        }
                    }

                    Rectangle {
                        id: frame
                        anchors {
                            right: parent.right
                            bottom: parent.bottom
                        }

                        // never smaller than 2px so the "CRT line" is always visible
                        width: Math.max(2, toast.width * toast.openW)
                        height: Math.max(2, toast.height * toast.openH)

                        // flick only affects the frame as a whole; the background
                        // alpha is set below so text stays full brightness
                        opacity: toast.flick
                        clip: true

                        radius: 0
                        color: Qt.alpha(Colors.colBg, 0.88)
                        border.width: 1
                        border.color: toast.critical ? toast.accent : win.line

                        // solid accent bar down the left edge (cyan, red for critical)
                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            width: 3
                            color: toast.accent
                        }

                        // fixed width + anchored bottom-right, so content is
                        // wiped in as the frame grows instead of reflowing
                        Column {
                            id: col
                            width: toast.width - 24
                            anchors {
                                right: parent.right
                                bottom: parent.bottom
                                rightMargin: 8
                                bottomMargin: 8
                            }
                            spacing: 4

                            Row {
                                spacing: 6

                                Rectangle {
                                    width: tagText.implicitWidth + 10
                                    height: 16
                                    color: toast.critical ? win.danger
                                         : toast.low ? win.chip
                                         : Colors.colCyan

                                    Text {
                                        id: tagText
                                        anchors.centerIn: parent
                                        text: toast.critical ? "CRIT" : toast.low ? "LOW" : "INFO"
                                        color: toast.low ? Colors.colBrightBlack : Colors.colBg
                                        font.family: win.mono
                                        font.pixelSize: 9
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
                                color: Colors.colBrightBlack
                                font.family: win.mono
                                font.pixelSize: 12
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }

                        // last child so it draws on top of the content
                        CornerBrackets {
                            color: toast.accent
                        }
                    }
                }
            }
        }
    }
}
