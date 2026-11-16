import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../theme"
import "../setting_menu"

PanelWindow {
    id: root

    property var screen

    WlrLayershell.namespace: "powermenu"

    // ── Keyboard selection state ─────────────────────────────────────────────
    property int selectedIndex: -1
    readonly property int buttonCount: 5
    readonly property int itemH: 36
    readonly property int cardW: 220

    function activateSelected() {
        switch (selectedIndex) {
            case 0: runAndClose(procLock); break;
            case 1: runAndClose(procSuspend); break;
            case 2: runAndClose(procHibernate); break;
            case 3: runAndClose(procReboot); break;
            case 4: runAndClose(procShutdown); break;
        }
    }

    // ── Animation state ──────────────────────────────────────────────────────
    // reallyVisible stays true until the close animation finishes
    property bool reallyVisible: false
    property real openW: 0        // 0..1 horizontal expand
    property real openH: 0        // 0..1 vertical expand
    property real flick: 1        // card opacity (glitch flicker)
    property real revealRows: 999 // rows with idx < revealRows are shown (hard step, no fade)

    // ── Sound effects (silent automatically when sound is off) ───────────────
    Sfx {
        id: openSfx
        file: "power_menu/open.wav"
    }
    Sfx {
        id: closeSfx
        file: "power_menu/close.wav"
    }
    Sfx {
        id: navSfx
        file: "power_menu/nav.wav"
    }

    // Reset selection / grab focus / run animations on visibility change
    Connections {
        target: PowerMenuState
        function onPowerVisibleChanged() {
            if (PowerMenuState.powerVisible) {
                closeSfx.stop();
                openSfx.play();

                closeAnim.stop();
                root.reallyVisible = true;
                powerCard.forceActiveFocus();

                if (Settings.animationsEnabled) {
                    openAnim.restart();
                } else {
                    openAnim.stop();
                    root.openW = 1;
                    root.openH = 1;
                    root.flick = 1;
                    root.revealRows = 999;
                }
            } else {
                root.selectedIndex = -1;
                openSfx.stop();
                closeSfx.play();

                openAnim.stop();
                if (Settings.animationsEnabled) {
                    closeAnim.restart();
                } else {
                    closeAnim.stop();
                    root.reallyVisible = false;
                    root.flick = 1;
                }
            }
        }
    }

    // ── Open: line grows vertically at the left edge, widens right, flickers,
    //    then rows print one by one ───────────────────────────────────────────
    SequentialAnimation {
        id: openAnim

        ScriptAction {
            script: {
                root.openW = 0;
                root.openH = 0;
                root.flick = 1;
                root.revealRows = 0;
            }
        }

        NumberAnimation {
            target: root
            property: "openH"
            to: 1
            duration: 80
            easing.type: Easing.OutCubic
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "openW"
                to: 1
                duration: 90
                easing.type: Easing.OutQuart
            }

            // glitch flicker once it's open
            SequentialAnimation {
                PauseAnimation {
                    duration: 90
                }
                NumberAnimation {
                    target: root
                    property: "flick"
                    to: 0.4
                    duration: 25
                }
                NumberAnimation {
                    target: root
                    property: "flick"
                    to: 1.0
                    duration: 25
                }
                NumberAnimation {
                    target: root
                    property: "flick"
                    to: 0.7
                    duration: 25
                }
                NumberAnimation {
                    target: root
                    property: "flick"
                    to: 1.0
                    duration: 25
                }
            }

            // rows print one by one, like terminal output
            SequentialAnimation {
                PauseAnimation {
                    duration: 50
                }
                NumberAnimation {
                    target: root
                    property: "revealRows"
                    to: root.buttonCount + 1
                    duration: 120
                    easing.type: Easing.Linear
                }
            }
        }

        ScriptAction {
            script: {
                root.revealRows = 999;
                root.flick = 1;
            }
        }
    }

    // ── Close: fast reverse, then hide ───────────────────────────────────────
    SequentialAnimation {
        id: closeAnim

        NumberAnimation {
            target: root
            property: "openW"
            to: 0
            duration: 50
            easing.type: Easing.InQuart
        }
        NumberAnimation {
            target: root
            property: "openH"
            to: 0
            duration: 50
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                root.reallyVisible = false;
                root.flick = 1;
            }
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

    // ── Menu card (left edge, vertically centered) ───────────────────────────
    Rectangle {
        id: powerCard
        focus: true
        visible: root.reallyVisible
        opacity: root.flick

        Keys.onPressed: function (event) {
            if (!PowerMenuState.powerVisible) return;
            if (event.key === Qt.Key_Up) {
                root.selectedIndex = (root.selectedIndex - 1 + root.buttonCount) % root.buttonCount;
                navSfx.play();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                root.selectedIndex = (root.selectedIndex + 1) % root.buttonCount;
                navSfx.play();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.selectedIndex >= 0) root.activateSelected();
                event.accepted = true;
            }
        }
        Keys.onEscapePressed: PowerMenuState.hide()

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left

        // never smaller than 2px so the cyan "CRT line" is always visible
        readonly property real fullH: menuCol.implicitHeight + 20
        width: Math.max(2, root.cardW * root.openW)
        height: Math.max(2, fullH * root.openH)

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

            // fixed width + anchored left, so content is wiped in as the card
            // widens instead of reflowing
            ColumnLayout {
                id: menuCol
                width: root.cardW - 22
                anchors {
                    top: parent.top
                    left: parent.left
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

        // hard step reveal (no fade) to match the instant-swap style
        opacity: idx < root.revealRows ? 1 : 0

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

