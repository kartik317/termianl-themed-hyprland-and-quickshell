import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    visible: ClipboardState.reallyVisible
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-clipboard"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        item: ClipboardState.open ? frame : null
    }

    onVisibleChanged: {
        if (visible)
            input.forceActiveFocus();
    }

    // --------------------------------------------------------------- dim

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.0

        MouseArea {
            anchors.fill: parent
            onClicked: ClipboardState.close()
        }
    }

    // ------------------------------------------------------------- frame

    Rectangle {
        id: frame

        anchors.centerIn: parent
        width: 680
        height: 520
        radius: 0
        color: Colors.colBg
        border.width: 1
        border.color: Colors.colCyan
        opacity: 0.65
        scale: ClipboardState.open ? 1.0 : 0.98

        Behavior on opacity {
            NumberAnimation {
                duration: 70
                easing.type: Easing.Linear
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 70
                easing.type: Easing.Linear
            }
        }

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                ClipboardState.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier))) {
                if (ClipboardState.selected < ClipboardState.filtered.length - 1)
                    ClipboardState.selected++;
                list.positionViewAtIndex(ClipboardState.selected, ListView.Contain);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier))) {
                if (ClipboardState.selected > 0)
                    ClipboardState.selected--;
                list.positionViewAtIndex(ClipboardState.selected, ListView.Contain);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (ClipboardState.filtered.length > 0)
                    ClipboardState.copyEntry(ClipboardState.filtered[ClipboardState.selected].line);
                event.accepted = true;
            } else if (event.key === Qt.Key_Delete || (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier))) {
                if (ClipboardState.filtered.length > 0)
                    ClipboardState.deleteEntry(ClipboardState.filtered[ClipboardState.selected].line);
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            // ------------------------------------------------- title bar

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                color: Colors.colCyan
                radius: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 4
                    spacing: 8

                    Text {
                        text: "clipboard@" + (Quickshell.env("USER") || "kartik")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.bold: true
                        color: Colors.colBg
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: ClipboardState.filtered.length + "/" + ClipboardState.entries.length
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: Colors.colBg
                    }

                    Rectangle {
                        Layout.preferredWidth: clearLabel.implicitWidth + 14
                        Layout.preferredHeight: 22
                        radius: 0
                        color: clearArea.containsMouse ? Colors.colBg : "transparent"
                        border.width: 1
                        border.color: Colors.colBg

                        Text {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: "[ CLEAR ALL ]"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            font.bold: true
                            color: clearArea.containsMouse ? Colors.colCyan : Colors.colBg
                        }

                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ClipboardState.wipeAll()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 0
                        color: closeArea.containsMouse ? Colors.colBg : "transparent"

                        Text {
			    anchors.centerIn: parent
			    text: "✕"
			    font.family: "JetBrainsMono Nerd Font"
			    font.pixelSize: 11
			    font.bold: true
			    color: closeArea.containsMouse ? Colors.colCyan : Colors.colBg
			}

			MouseArea {
			    id: closeArea
			    anchors.fill: parent
			    hoverEnabled: true
			    cursorShape: Qt.PointingHandCursor
			    onClicked: ClipboardState.close()
			}
		    }
		}
	    }

	    // ---------------------------------------------- search line

	    Rectangle {
		Layout.fillWidth: true
		Layout.preferredHeight: 34
		color: "transparent"

		Rectangle {
		    anchors.bottom: parent.bottom
		    width: parent.width
		    height: 1
		    color: Colors.colCyan
		    opacity: 0.65
		}

		RowLayout {
		    anchors.fill: parent
		    anchors.leftMargin: 10
		    anchors.rightMargin: 10
		    spacing: 6

		    Text {
			text: ">"
			font.family: "JetBrainsMono Nerd Font"
			font.pixelSize: 13
			font.bold: true
			color: Colors.colCyan
		    }

		    TextInput {
			id: input
			Layout.fillWidth: true
			font.family: "JetBrainsMono Nerd Font"
			font.pixelSize: 13
			color: Colors.colFg
			selectionColor: Colors.colCyan
			selectedTextColor: Colors.colBg
			clip: true
			focus: true

			text: ClipboardState.search

			onTextChanged: {
			    ClipboardState.search = text;
			    ClipboardState.selected = 0;
			}

			Text {
			    anchors.verticalCenter: parent.verticalCenter
			    text: "grep history..."
			    font: parent.font
			    color: Colors.colFg
			    opacity: 0.6
			    visible: parent.text.length === 0
			}

			Keys.priority: Keys.BeforeItem
			Keys.onPressed: function (event) {
			    if (event.key === Qt.Key_Delete
			    || (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier))) {
				if (ClipboardState.filtered.length > 0)
				ClipboardState.deleteEntry(ClipboardState.filtered[ClipboardState.selected].line);
				event.accepted = true;
			    }
			}
		    }
		}
	    }

            // --------------------------------------------------- list

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: ClipboardState.filtered
                currentIndex: ClipboardState.selected
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: row
                    required property int index
                    required property var modelData

                    readonly property bool active: index === ClipboardState.selected || rowArea.containsMouse

                    width: list.width
                    height: 30
                    radius: 0
                    color: active ? Colors.colCyan : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        spacing: 8

                        Text {
                            Layout.preferredWidth: 42
                            text: String(row.index + 1).padStart(3, "0")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: row.active ? Colors.colBg : Colors.colCyan
                            opacity: 1
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.text
                            elide: Text.ElideRight
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: row.active ? Colors.colBg : Colors.colFg
                        }

                        Rectangle {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 20
                            radius: 0
                            visible: row.active
                            color: delArea.containsMouse ? Colors.colBg : "transparent"
                            border.width: 1
                            border.color: row.active ? Colors.colBg : Colors.colCyan

                            Text {
                                anchors.centerIn: parent
                                text: "\udb80\uddb4"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.bold: true
                                color: delArea.containsMouse ? Colors.colCyan : (row.active ? Colors.colBg : Colors.colCyan)
                            }

                            MouseArea {
                                id: delArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ClipboardState.deleteEntry(row.modelData.line)
                            }
                        }
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        z: -1
                        onEntered: ClipboardState.selected = row.index
                        onClicked: function (mouse) {
                            if (mouse.button === Qt.MiddleButton)
                                ClipboardState.deleteEntry(row.modelData.line);
                            else
                                ClipboardState.copyEntry(row.modelData.line);
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: ClipboardState.filtered.length === 0
                    text: ClipboardState.entries.length === 0 ? "-- clipboard empty --" : "-- no matches --"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Colors.colFg
                    opacity: 0.4
                }
            }

            // -------------------------------------------------- footer

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                color: "transparent"

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: Colors.colCyan
                    opacity: 0.4
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    text: "↑↓ nav   ⏎ copy   DEL/C-d remove   ESC quit"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    color: Colors.colCyan
                    opacity: 1
                }
            }
        }
    }
}

