import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../theme"

PanelWindow {
    id: root
    property var screen

    IpcHandler {
        target: "settings"
        function toggle(): void {
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

    // ── Geometry / style ───────────────────────────────────────────────────
    readonly property int panelW: 320
    readonly property int rowH: 34
    readonly property int headerH: 28
    readonly property int titleH: 34
    readonly property int footerH: 28

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property color dim: Qt.alpha(Colors.colCyan, 0.35)

    // total height of the entries list, so the panel height follows `entries`
    readonly property real listH: {
        var h = 0;
        for (var i = 0; i < entries.length; i++)
            h += entries[i].type === "header" ? headerH : rowH;
        return h;
    }
    readonly property real fullH: titleH + listH + footerH + 2

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

        width: Math.max(2, root.panelW * root.openW)
        height: Math.max(2, root.fullH * root.openH)
        visible: root.reallyVisible

        // flick only affects the frame as a whole; the background alpha is
        // set below so text stays full brightness
        opacity: root.flick

        anchors {
            right: parent.right
            rightMargin: 0
            verticalCenter: parent.verticalCenter
        }

        color: Qt.alpha(Colors.colBg, 0.88)
        border.color: root.dim
        border.width: 1
        radius: 0
        clip: true

        // swallows clicks on empty panel area so they don't close it
        MouseArea {
            anchors.fill: parent
        }

        // fixed size + anchored top-right, so content is wiped in as the
        // panel widens instead of reflowing
        ColumnLayout {
            width: root.panelW - 2
            height: root.fullH - 2
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 1
                rightMargin: 1
            }
            spacing: 0

            // ── Title bar ──────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.titleH

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    // blocky inverted tag
                    Rectangle {
                        implicitWidth: titleTag.implicitWidth + 14
                        implicitHeight: titleTag.implicitHeight + 4
                        color: Colors.colCyan

                        Text {
                            id: titleTag
                            anchors.centerIn: parent
                            text: "SETTINGS"
                            font.family: root.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 1
                            color: Colors.colBg
                        }
                    }

                    Text {
                        text: ("linuxguy") + "@config"
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        color: Colors.colBrightBlack
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: root.dim
                }
            }

            // ── Entries ────────────────────────────────────────────────────
            Column {
                id: listCol
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: root.entries

                    delegate: Item {
                        id: row
                        width: listCol.width
                        height: modelData.type === "header" ? root.headerH : root.rowH

                        readonly property bool isToggle: modelData.type === "toggle"
                        readonly property bool sel: isToggle && root.selectedIndex === index
                        readonly property bool hovered: rowMouse.containsMouse
                        readonly property bool isOn: isToggle && Settings.get(modelData.key) === true

                        // section header:  // AUDIO ─────────
                        RowLayout {
                            visible: !row.isToggle
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: "// " + modelData.label
                                color: Colors.colBrightBlack
                                font.pixelSize: 11
                                font.family: root.fontFamily
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                Layout.alignment: Qt.AlignVCenter
                                color: Qt.alpha(Colors.colCyan, 0.2)
                            }
                        }

                        // toggle row: selected = solid cyan block, hover = faint block
                        Rectangle {
                            visible: row.isToggle
                            anchors.fill: parent
                            radius: 0
                            color: row.sel ? Colors.colCyan
                                 : row.hovered ? Qt.alpha(Colors.colCyan, 0.15)
                                 : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 14
                                spacing: 8

                                Text {
                                    text: row.sel ? ">" : " "
                                    color: Colors.colBg
                                    font.pixelSize: 12
                                    font.family: root.fontFamily
                                    font.bold: true
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    color: row.sel ? Colors.colBg : Colors.colFg
                                    font.pixelSize: 12
                                    font.family: root.fontFamily
                                    font.bold: row.sel
                                }

                                // blocky status tag, instant color swap
                                Rectangle {
                                    Layout.preferredWidth: 38
                                    Layout.preferredHeight: 18
                                    color: row.sel ? Colors.colBg
                                         : row.isOn ? Colors.colCyan
                                         : Qt.alpha(Colors.colCyan, 0.15)

                                    Text {
                                        anchors.centerIn: parent
                                        text: row.isOn ? "ON" : "OFF"
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: row.sel ? (row.isOn ? Colors.colCyan : Colors.colBrightBlack)
                                             : row.isOn ? Colors.colBg
                                             : Colors.colBrightBlack
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            enabled: row.isToggle
                            hoverEnabled: true
                            cursorShape: row.isToggle ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onEntered: root.selectedIndex = index
                            onClicked: {
                                root.selectedIndex = index;
                                root.activate();
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

            // ── Footer ─────────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.footerH

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: root.dim
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    spacing: 12

                    Repeater {
                        model: [
                            { k: "↑↓",  d: "move" },
                            { k: "⏎",   d: "toggle" },
                            { k: "ESC", d: "close" }
                        ]

                        Row {
                            spacing: 5

                            Rectangle {
                                width: keyText.implicitWidth + 8
                                height: keyText.implicitHeight + 2
                                color: Colors.colCyan

                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: modelData.k
                                    font.family: root.fontFamily
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: Colors.colBg
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.d
                                font.family: root.fontFamily
                                font.pixelSize: 10
                                color: Colors.colBrightBlack
                            }
                        }
                    }
                }
            }
        }

	CornerBrackets {}
    }
}
