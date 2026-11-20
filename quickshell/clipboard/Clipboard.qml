import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../setting_menu"

PanelWindow {
    id: root

    // Driven by ClipboardState.open (below) so the close animation can finish
    // before the window hides. ClipboardState.reallyVisible is no longer used.
    property bool reallyVisible: false
    visible: root.reallyVisible
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-clipboard"
    WlrLayershell.keyboardFocus: ClipboardState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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

    // ------------------------------------------------------------ geometry

    readonly property int cardW: 560
    readonly property int cardH: 400

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property color dim: Qt.alpha(Colors.colCyan, 0.35)
    readonly property color danger: "#e06c75"

    // ------------------------------------------------------- animation state

    property real openW: 0        // 0..1 horizontal expand
    property real openH: 0        // 0..1 vertical expand
    property real flick: 1        // card opacity multiplier (glitch flicker)
    property real revealRows: 999 // rows with index < revealRows are shown (hard step, no fade)

    // ---------------------------------------------------------- sound effects
    // (silent automatically when sound effects are off in the settings panel)

    Sfx {
        id: openSfx
        file: "default/open.wav"
    }
    Sfx {
        id: closeSfx
        file: "default/close.wav"
    }
    Sfx {
        id: navSfx
        file: "default/nav.wav"
    }
    Sfx {
        id: typeSfx
        file: "default/type.wav"
    }

    Connections {
        target: ClipboardState

        function onOpenChanged() {
            if (ClipboardState.open) {
                closeSfx.stop();
                openSfx.play();

                closeAnim.stop();
                root.reallyVisible = true;
                input.forceActiveFocus();

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

    // Open: line extends from the bottom-center, grows upward, flickers,
    // then entries print one by one
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
            property: "openW"
            to: 1
            duration: 80
            easing.type: Easing.OutCubic
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "openH"
                to: 1
                duration: 100
                easing.type: Easing.OutQuart
            }

            // glitch flicker once it's open
            SequentialAnimation {
                PauseAnimation {
                    duration: 100
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

            // entries print one by one, like terminal output
            SequentialAnimation {
                PauseAnimation {
                    duration: 50
                }
                NumberAnimation {
                    target: root
                    property: "revealRows"
                    to: 10
                    duration: 130
                    easing.type: Easing.Linear
                }
            }
        }

        // make sure every row (including scrolled ones) is visible afterwards
        ScriptAction {
            script: {
                root.revealRows = 999;
                root.flick = 1;
            }
        }
    }

    // Close: fast reverse, then hide
    SequentialAnimation {
        id: closeAnim

        NumberAnimation {
            target: root
            property: "openH"
            to: 0
            duration: 60
            easing.type: Easing.InQuart
        }
        NumberAnimation {
            target: root
            property: "openW"
            to: 0
            duration: 40
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                root.reallyVisible = false;
                root.flick = 1;
            }
        }
    }

    // ------------------------------------------------------------- frame

    Rectangle {
        id: frame

        // attached to the bottom edge, centered
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        // never smaller than 2px so the cyan "CRT line" is always visible
        width: Math.max(2, root.cardW * root.openW)
        height: Math.max(2, root.cardH * root.openH)
        radius: 0

        // translucent background only, so text stays full brightness
        // (opacity is reserved for the glitch flicker)
        color: Qt.alpha(Colors.colBg, 0.88)
        border.width: 1
        border.color: root.dim
        opacity: root.flick
        clip: true

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                ClipboardState.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier))) {
                var beforeDown = ClipboardState.selected;
                if (ClipboardState.selected < ClipboardState.filtered.length - 1)
                    ClipboardState.selected++;
                list.positionViewAtIndex(ClipboardState.selected, ListView.Contain);
                if (ClipboardState.selected !== beforeDown)
                    navSfx.play();
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier))) {
                var beforeUp = ClipboardState.selected;
                if (ClipboardState.selected > 0)
                    ClipboardState.selected--;
                list.positionViewAtIndex(ClipboardState.selected, ListView.Contain);
                if (ClipboardState.selected !== beforeUp)
                    navSfx.play();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (ClipboardState.filtered.length > 0)
                    ClipboardState.copyEntry(ClipboardState.filtered[ClipboardState.selected].line);
                event.accepted = true;
            } else if (event.key === Qt.Key_Delete) {
                if (ClipboardState.filtered.length > 0) {
                    ClipboardState.deleteEntry(ClipboardState.filtered[ClipboardState.selected].line);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier)) {
                ClipboardState.wipeAll();
                event.accepted = true;
            }
        }

        // fixed size + anchored bottom-center, so content is wiped in as the
        // card grows instead of reflowing
        ColumnLayout {
            width: root.cardW - 2
            height: root.cardH - 2
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 1
            }
            spacing: 0

            // ------------------------------------------------- title bar

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 34

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
                            text: "CLIPBOARD"
                            font.family: root.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 1
                            color: Colors.colBg
                        }
                    }

                    Text {
                        text: ("linuxguy") + "@cliphist"
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        color: Colors.colBrightBlack
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    // 003/120
                    Text {
                        text: String(ClipboardState.filtered.length).padStart(3, "0")
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: Colors.colCyan
                    }
                    Text {
                        text: "/" + String(ClipboardState.entries.length).padStart(3, "0")
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        color: Colors.colBrightBlack
                        Layout.leftMargin: -8
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: root.dim
                }
            }

            // ---------------------------------------------- search bar

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 48

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 8
                    radius: 0
                    color: Qt.alpha(Colors.colCyan, 0.05)
                    border.width: 1
                    border.color: input.activeFocus ? Colors.colCyan : root.dim

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: ">"
                            font.family: root.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Colors.colCyan
                        }

                        TextInput {
                            id: input
                            Layout.fillWidth: true
                            font.family: root.fontFamily
                            font.pixelSize: 13
                            color: Colors.colFg
                            selectionColor: Colors.colCyan
                            selectedTextColor: Colors.colBg
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            focus: true
                            selectByMouse: false

                            text: ClipboardState.search

                            onTextChanged: {
                                ClipboardState.search = text;
                                ClipboardState.selected = 0;
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "grep history..."
                                font: parent.font
                                color: Colors.colBrightBlack
                                visible: parent.text.length === 0
                            }

                            Keys.priority: Keys.BeforeItem
                            Keys.onPressed: function (event) {
                                if (event.key === Qt.Key_Delete) {
                                    if (ClipboardState.filtered.length > 0) {
                                        ClipboardState.deleteEntry(ClipboardState.filtered[ClipboardState.selected].line);
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier)) {
                                    ClipboardState.wipeAll();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Backspace
                                           || (event.text.length > 0 && event.text.charCodeAt(0) >= 32
                                               && !(event.modifiers & Qt.ControlModifier))) {
                                    // typing tick; doesn't set accepted, so the key still goes through
                                    typeSfx.play();
                                }
                            }
                        }
                    }
                }
            }

            // --------------------------------------------------- list

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    interactive: false   // no wheel scrolling / flicking
                    model: ClipboardState.filtered
                    currentIndex: ClipboardState.selected
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: row
                        required property int index
                        required property var modelData

                        readonly property bool active: index === ClipboardState.selected
                        readonly property bool hovered: rowMouse.containsMouse

                        // cheap content-type guess for the tag
                        readonly property string kind: {
                            var t = modelData.text || "";
                            if (/^https?:\/\//.test(t)) return "URL";
                            if (t.indexOf("[[ binary data") === 0) return "IMG";
                            if (t.indexOf("/") === 0 || t.indexOf("~/") === 0) return "PTH";
                            return "TXT";
                        }

                        width: list.width
                        height: 30
                        radius: 0

                        // selected = solid cyan block, hover = faint block, instant swaps
                        color: active ? Colors.colCyan
                             : hovered ? Qt.alpha(Colors.colCyan, 0.15)
                             : "transparent"

                        // hard step reveal (no fade) to match the instant-swap style
                        opacity: index < root.revealRows ? 1 : 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 14
                            spacing: 8

                            Text {
                                Layout.preferredWidth: 26
                                text: String(row.index + 1).padStart(3, "0")
                                font.family: root.fontFamily
                                font.pixelSize: 11
                                color: row.active ? Colors.colBg : Colors.colBrightBlack
                            }

                            // type tag
                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 16
                                color: row.active ? Colors.colBg : Qt.alpha(Colors.colCyan, 0.15)

                                Text {
                                    anchors.centerIn: parent
                                    text: row.kind
                                    font.family: root.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: Colors.colCyan
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.text
                                elide: Text.ElideRight
                                font.family: root.fontFamily
                                font.pixelSize: 12
                                color: row.active ? Colors.colBg : Colors.colFg
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function (event) {
                                ClipboardState.copyEntry(row.modelData.line);
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: ClipboardState.filtered.length === 0
                    text: ClipboardState.entries.length === 0 ? "-- clipboard empty --" : "-- no matches --"
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    color: Colors.colBrightBlack
                }
            }

            // -------------------------------------------------- footer

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 28

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
                            { k: "↑↓",  d: "nav",       danger: false },
                            { k: "⏎",   d: "copy",      danger: false },
                            { k: "DEL", d: "remove",    danger: true },
                            { k: "C-d", d: "clear all", danger: true },
                            { k: "ESC", d: "quit",      danger: false }
                        ]

                        Row {
                            spacing: 5

                            Rectangle {
                                width: keyText.implicitWidth + 8
                                height: keyText.implicitHeight + 2
                                color: modelData.danger ? root.danger : Colors.colCyan

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
