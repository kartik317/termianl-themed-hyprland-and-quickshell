import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../theme"

PanelWindow {
    id: root

    property var screen

    WlrLayershell.namespace: "powermenu"

    // ── Keyboard selection state ─────────────────────────────────────────────
    property int selectedIndex: -1
    readonly property int buttonCount: 5
    readonly property int itemH: 36

    function activateSelected() {
        switch (selectedIndex) {
            case 0: runAndClose(procLock); break;
            case 1: runAndClose(procSuspend); break;
            case 2: runAndClose(procHibernate); break;
            case 3: runAndClose(procReboot); break;
            case 4: runAndClose(procShutdown); break;
        }
    }

    // Reset selection / grab focus on visibility change
    Connections {
        target: PowerMenuState
        function onPowerVisibleChanged() {
            if (PowerMenuState.powerVisible)
                powerCard.forceActiveFocus()
            else
                root.selectedIndex = -1
        }
    }

    IpcHandler {
        target: "powermenu"
        function toggle() {
            PowerMenuState.toggle();
        }
    }

    // ── Layer / geometry ─────────────────────────────────────────────────────
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        item: PowerMenuState.powerVisible ? maskCover : null
    }

    Item {
        id: maskCover
        anchors.fill: parent
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: PowerMenuState.powerVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // ── Terminal palette setup (matches app launcher) ─────────────────────────
    readonly property color accentFill: Colors.colBlue
    readonly property color fgDim: Qt.rgba(Colors.colFg.r, Colors.colFg.g, Colors.colFg.b, 0.6)

    // ── Slide offset ─────────────────────────────────────────────────────────
    property real slideOffset: PowerMenuState.powerVisible ? 0 : powerCard.width + 8 

    // ── Process runners ──────────────────────────────────────────────────────
    Process { id: procLock; command: ["loginctl", "lock-session"] }
    Process { id: procSuspend; command: ["systemctl", "suspend"] }
    Process { id: procHibernate; command: ["systemctl", "hibernate"] }
    Process { id: procReboot; command: ["systemctl", "reboot"] }
    Process { id: procShutdown; command: ["systemctl", "poweroff"] }

    function runAndClose(proc) {
        PowerMenuState.hide();
        proc.running = true;
    }

    MouseArea {
        anchors.fill: parent
        enabled: PowerMenuState.powerVisible
        onClicked: PowerMenuState.hide()
    }

    // ── Menu card ────────────────────────────────────────────────────────────
    Rectangle {
        id: powerCard
        focus: true

        Keys.onPressed: function (event) {
            if (!PowerMenuState.powerVisible) return;
            if (event.key === Qt.Key_Up) {
                root.selectedIndex = (root.selectedIndex - 1 + root.buttonCount) % root.buttonCount;
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                root.selectedIndex = (root.selectedIndex + 1) % root.buttonCount;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.selectedIndex >= 0) root.activateSelected();
                event.accepted = true;
            }
        }
        Keys.onEscapePressed: PowerMenuState.hide()

        anchors.verticalCenter: parent.verticalCenter
        x: -root.slideOffset

        width: 220
        height: menuCol.implicitHeight + 20

        radius: 0
        color: "transparent"
        border.color: Colors.colCyan
        border.width: 1

        // Eat clicks so background doesn't dismiss on card clicks
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // ── Inner panel (matches app launcher's translucent fill) ────────────
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: Qt.rgba(Colors.colBg.r, Colors.colBg.g, Colors.colBg.b, 0.65)
            radius: 0
            clip: true

            ColumnLayout {
                id: menuCol
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 10
                }
                spacing: 8

                // ── Header (styled like the search prompt box) ────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 0
                    color: Qt.rgba(1, 1, 1, 0.03)
                    border.color: Colors.colBlue
                    border.width: 1

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ">"
                            color: Colors.colCyan
                            font {
                                pixelSize: 13
                                family: "JetBrainsMono Nerd Font"
                                weight: Font.Bold
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "POWER"
                            color: Colors.colFg
                            font {
                                pixelSize: 13
                                family: "JetBrainsMono Nerd Font"
                                weight: Font.Bold
                                letterSpacing: 2
                            }
                        }
                    }
                }

                // ── Options list ───────────────────────────────────────────────
                Column {
                    Layout.fillWidth: true
                    spacing: 0

                    PowerRow { idx: 0; label: "Lock";      icon: "󰌾"; onActivated: root.runAndClose(procLock) }
                    PowerRow { idx: 1; label: "Suspend";   icon: "󰒲"; onActivated: root.runAndClose(procSuspend) }
                    PowerRow { idx: 2; label: "Hibernate"; icon: "󰋊"; onActivated: root.runAndClose(procHibernate) }
                    PowerRow { idx: 3; label: "Reboot";    icon: "󰜉"; onActivated: root.runAndClose(procReboot) }
                    PowerRow { idx: 4; label: "Shutdown";  icon: "󰐥"; onActivated: root.runAndClose(procShutdown) }
                }

                Item { Layout.preferredHeight: 2 }
            }
        }
    }

    // ── Inner component: one menu row (matches app launcher delegate) ────────
    component PowerRow: Item {
        id: row
        required property int idx
        required property string label
        required property string icon
        signal activated

        readonly property bool sel: root.selectedIndex === idx

        Layout.fillWidth: true
        width: parent.width
        height: root.itemH

        Rectangle {
            anchors.fill: parent
            radius: 0
            color: row.sel ? root.accentFill : "transparent"

            Row {
                anchors {
                    fill: parent
                    leftMargin: 8
                    rightMargin: 8
                }
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.sel ? ">" : " "
                    color: row.sel ? Colors.colBg : Colors.colBlue
                    font {
                        pixelSize: 12
                        family: "JetBrainsMono Nerd Font"
                        weight: Font.Bold
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.icon
                    color: row.sel ? Colors.colBg : Colors.colBlue
                    font.pixelSize: 15
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.label
                    color: row.sel ? Colors.colBg : Colors.colFg
                    font {
                        pixelSize: 12
                        family: "JetBrainsMono Nerd Font"
                        weight: row.sel ? Font.Bold : Font.Normal
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selectedIndex = row.idx
                onClicked: row.activated()
            }
        }
    }
}
