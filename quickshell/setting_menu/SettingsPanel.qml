import Quickshell
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "../theme"

PanelWindow {
    id: root
    property var screen

    IpcHandler {
        target: "settings"
        function toggle() {
            Settings.toggle();
        }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Settings.panelVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "settings-panel"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        item: Settings.panelVisible ? maskCover : null
    }
    Item {
        id: maskCover
        anchors.fill: parent
    }

    color: "transparent"

    // ── Settings list ──────────────────────────────────────────────────────
    // To add a setting:
    //   1) add a property to the JsonAdapter in Settings.qml
    //   2) add one line below (headers are just visual dividers)
    readonly property var entries: [
        {
            type: "header",
            label: "AUDIO"
        },
        {
            type: "toggle",
            label: "SOUND EFFECTS",
            key: "soundEnabled"
        },
        {
            type: "header",
            label: "VISUAL"
        },
        {
            type: "toggle",
            label: "ANIMATIONS",
            key: "animationsEnabled"
        }
    ]

    // ── State ──────────────────────────────────────────────────────────────
    property int selectedIndex: 0

    // ── Animation state ────────────────────────────────────────────────────
    property bool reallyVisible: false
    property real openW: 0
    property real openH: 0
    property real flick: 1

    // ── Geometry / palette ─────────────────────────────────────────────────
    readonly property int panelW: 300
    readonly property int rowH: 32
    readonly property color accentFill: Colors.colBlue
    readonly property color fgDim: Qt.rgba(Colors.colFg.r, Colors.colFg.g, Colors.colFg.b, 0.6)

    // ── Sounds (silent automatically when sound effects are off) ───────────
    Sfx {
        id: openSfx
        file: "settings/open.wav"
    }
    Sfx {
        id: closeSfx
        file: "settings/close.wav"
    }
    Sfx {
        id: navSfx
        file: "settings/nav.wav"
    }
    Sfx {
        id: toggleSfx
        file: "settings/type.wav"
    }

    // ── Selection helpers ──────────────────────────────────────────────────
    function firstToggle() {
        for (var i = 0; i < entries.length; i++)
            if (entries[i].type === "toggle")
                return i;
        return 0;
    }

    // moves to the next/previous toggle row, skipping headers
    function move(delta) {
        var n = entries.length;
        var i = selectedIndex;
        for (var k = 0; k < n; k++) {
            i = (i + delta + n) % n;
            if (entries[i].type === "toggle") {
                if (i !== selectedIndex) {
                    selectedIndex = i;
                    navSfx.play();
                }
                return;
            }
        }
    }

    function activate() {
        var e = entries[selectedIndex];
        if (!e || e.type !== "toggle")
            return;
        Settings.set(e.key, !Settings.get(e.key));
        // plays when you just turned sound ON, silent when you turned it OFF
        toggleSfx.play();
    }

    Connections {
        target: Settings
        function onPanelVisibleChanged() {
            if (Settings.panelVisible) {
                closeSfx.stop();
                openSfx.play();

                closeAnim.stop();
                root.reallyVisible = true;
                root.selectedIndex = root.firstToggle();
                keyItem.forceActiveFocus();
                if (Settings.animationsEnabled) {
                    openAnim.restart();
                } else {
                    openAnim.stop();
                    root.openW = 1;
                    root.openH = 1;
                    root.flick = 1;
                }
            } else {
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

    // ── Open: line grows vertically at the right edge, then widens left ────
    SequentialAnimation {
        id: openAnim

        ScriptAction {
            script: {
                root.openW = 0;
                root.openH = 0;
                root.flick = 1;
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
        }

        ScriptAction {
            script: root.flick = 1
        }
    }

    // ── Close: fast reverse, then hide ─────────────────────────────────────
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

    // ── Keyboard ───────────────────────────────────────────────────────────
    Item {
        id: keyItem
        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                Settings.hide();
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                root.move(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                root.move(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.activate();
                event.accepted = true;
            }
        }
    }

    // Click outside → close
    MouseArea {
        anchors.fill: parent
        enabled: Settings.panelVisible
        onClicked: Settings.hide()
    }

    // ── Panel (middle of the right edge) ───────────────────────────────────
    Rectangle {
        id: panelBorder

        // 10px top + 10px bottom padding + 2px border
        readonly property real fullH: col.implicitHeight + 22

        width: Math.max(2, root.panelW * root.openW)
        height: Math.max(2, fullH * root.openH)
        opacity: root.flick
        visible: root.reallyVisible

        anchors {
            right: parent.right
            rightMargin: 0
            verticalCenter: parent.verticalCenter
        }

        color: "transparent"
        border.color: Colors.colCyan
        border.width: 1
        radius: 0

        Rectangle {
            id: panel
            anchors.fill: parent
            anchors.margins: 1

            color: Qt.rgba(Colors.colBg.r, Colors.colBg.g, Colors.colBg.b, 0.5)
            radius: 0
            clip: true

            // swallows clicks on empty panel area so they don't close it
            MouseArea {
                anchors.fill: parent
            }

            // fixed width + anchored right, so content is wiped in as the
            // panel widens instead of reflowing
            Column {
                id: col
                width: root.panelW - 22

                anchors {
                    top: parent.top
                    topMargin: 10
                    right: parent.right
                    rightMargin: 10
                }

                Text {
                    height: 24
                    verticalAlignment: Text.AlignVCenter
                    text: "> SETTINGS"
                    color: Colors.colCyan
                    font {
                        pixelSize: 13
                        family: "JetBrainsMono Nerd Font"
                        weight: Font.Bold
                    }
                }

                Item {
                    width: 1
                    height: 6
                }

                Repeater {
                    model: root.entries

                    delegate: Item {
                        id: row
                        width: col.width
                        height: modelData.type === "header" ? 24 : root.rowH

                        readonly property bool isToggle: modelData.type === "toggle"
                        readonly property bool sel: isToggle && root.selectedIndex === index
                        readonly property bool isOn: isToggle && Settings.get(modelData.key) === true

                        // section header
                        Text {
                            visible: !row.isToggle
                            anchors {
                                left: parent.left
                                leftMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            text: "// " + modelData.label
                            color: Colors.colBlue
                            font {
                                pixelSize: 11
                                family: "JetBrainsMono Nerd Font"
                            }
                        }

                        // toggle row
                        Rectangle {
                            visible: row.isToggle
                            anchors.fill: parent
                            radius: 0
                            color: row.sel ? root.accentFill : "transparent"

                            Text {
                                id: promptGlyph
                                anchors {
                                    left: parent.left
                                    leftMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }
                                text: row.sel ? ">" : " "
                                color: row.sel ? Colors.colBg : Colors.colBlue
                                font {
                                    pixelSize: 12
                                    family: "JetBrainsMono Nerd Font"
                                    weight: Font.Bold
                                }
                            }

                            Text {
                                anchors {
                                    left: promptGlyph.right
                                    leftMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }
                                text: modelData.label
                                color: row.sel ? Colors.colBg : Colors.colFg
                                font {
                                    pixelSize: 12
                                    family: "JetBrainsMono Nerd Font"
                                    weight: row.sel ? Font.Bold : Font.Normal
                                }
                            }

                            // blocky status tag, instant color swap
                            Text {
                                anchors {
                                    right: parent.right
                                    rightMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }
                                text: row.isOn ? "[ ON]" : "[OFF]"
                                color: row.sel ? Colors.colBg : (row.isOn ? Colors.colCyan : root.fgDim)
                                font {
                                    pixelSize: 12
                                    family: "JetBrainsMono Nerd Font"
                                    weight: Font.Bold
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: row.isToggle
                            hoverEnabled: true
                            onEntered: root.selectedIndex = index
                            onClicked: {
                                root.selectedIndex = index;
                                root.activate();
                            }
                        }
                    }
                }

                Item {
                    width: 1
                    height: 6
                }

                Text {
                    height: 20
                    verticalAlignment: Text.AlignVCenter
                    text: "[↑↓] MOVE  [ENTER] TOGGLE  [ESC] CLOSE"
                    color: root.fgDim
                    font {
                        pixelSize: 10
                        family: "JetBrainsMono Nerd Font"
                    }
                }
            }
        }
    }
}

