import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../theme"

PanelWindow {
    id: win

    visible: TrayState.open
    color: "transparent"

    anchors { top: true; right: true }
    margins {
        top: TrayState.gap + TrayState.barOffset
        right: TrayState.gap
    }

    // Normal = respect other layers' exclusive zones (so we sit below the bar)
    // while reserving no space of our own (exclusiveZone stays 0).
    exclusionMode: ExclusionMode.Normal

    implicitWidth: 380
    implicitHeight: frame.implicitHeight

    WlrLayershell.namespace: "qs-tray"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: TrayState.open
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    onVisibleChanged: if (visible) keys.forceActiveFocus()

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 0
        color: Qt.alpha(Colors.colBg, 0.65)
        border.width: 1
        border.color: Colors.colCyan
        implicitHeight: col.implicitHeight + 2

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true

            Keys.onPressed: function(event) {
                event.accepted = TrayState.handleKey(event.key, event.text)
            }

            ColumnLayout {
                id: col
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
                spacing: 0

                // header
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    color: Colors.colCyan

                    Text {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        text: TrayState.inMenu
                            ? "tray/" + TrayState.labelFor(TrayState.menuOwner).toLowerCase()
                            : "systray"
                        color: Colors.colBg
                        font.family: TrayState.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: "[" + TrayState.count + "]"
                        color: Colors.colBg
                        font.family: TrayState.fontFamily
                        font.pixelSize: 13
                    }
                }

                // entries
                Repeater {
                    model: TrayState.model

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index

                        readonly property bool isSep: TrayState.inMenu && modelData.isSeparator
                        readonly property bool isSel: index === TrayState.sel && !isSep
                        readonly property bool dim: TrayState.inMenu && !modelData.enabled

                        Layout.fillWidth: true
                        implicitHeight: isSep ? 9 : 28

                        // separator
                        Rectangle {
                            visible: row.isSep
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
                            height: 1
                            color: Colors.colCyan
                            opacity: 0.35
                        }

                        // row body
                        Rectangle {
                            visible: !row.isSep
                            anchors.fill: parent
                            color: row.isSel ? Colors.colCyan : "transparent"

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: if (row.modelData && !row.dim) TrayState.sel = row.index
                                onClicked: { TrayState.sel = row.index; TrayState.activate() }
                            }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                spacing: 8

                                Text {
                                    text: row.isSel ? ">" : " "
                                    color: row.isSel ? Colors.colBg : Colors.colCyan
                                    font.family: TrayState.fontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                Text {
                                    visible: !TrayState.inMenu && row.index < 9
                                    text: (row.index + 1).toString()
                                    color: row.isSel ? Colors.colBg : Colors.colCyan
                                    opacity: row.isSel ? 1 : 0.6
                                    font.family: TrayState.fontFamily
                                    font.pixelSize: 13
                                }

                                Image {
                                    visible: !TrayState.inMenu
                                    source: !TrayState.inMenu && row.modelData ? row.modelData.icon : ""
                                    sourceSize: Qt.size(16, 16)
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    smooth: false
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData ? TrayState.labelFor(row.modelData) : ""
                                    elide: Text.ElideRight
                                    color: row.isSel ? Colors.colBg : Colors.colFg
                                    opacity: row.dim ? 0.4 : 1
                                    font.family: TrayState.fontFamily
                                    font.pixelSize: 13
                                }

                                Text {
                                    visible: (!TrayState.inMenu && row.modelData && row.modelData.hasMenu)
                                          || (TrayState.inMenu && row.modelData && row.modelData.hasChildren)
                                    text: TrayState.inMenu ? "[>]" : "[menu]"
                                    color: row.isSel ? Colors.colBg : Colors.colCyan
                                    font.family: TrayState.fontFamily
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                }

                // empty state
                Text {
                    visible: TrayState.count === 0
                    Layout.fillWidth: true
                    Layout.margins: 10
                    text: "> no tray items"
                    color: Colors.colFg
                    opacity: 0.6
                    font.family: TrayState.fontFamily
                    font.pixelSize: 13
                }

                // footer
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Colors.colCyan
                    opacity: 0.35
                }
                Text {
                    Layout.fillWidth: true
                    Layout.margins: 8
                    text: TrayState.inMenu
                        ? "j/k move  enter run  h back  esc close"
                        : "j/k move  enter open  l menu  1-9 jump"
                    color: Colors.colFg
                    opacity: 0.55
                    elide: Text.ElideRight
                    font.family: TrayState.fontFamily
                    font.pixelSize: 11
                }
            }
        }
    }
}

