import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../theme"
import "../setting_menu"

PanelWindow {
    id: win

    // stays true until the close animation finishes
    property bool reallyVisible: false
    visible: win.reallyVisible
    color: "transparent"

    anchors { top: true; right: true }
    margins {
        top: TrayState.gap + TrayState.barOffset
        right: TrayState.gap
    }

    // Normal = respect other layers' exclusive zones (so we sit below the bar)
    // while reserving no space of our own (exclusiveZone stays 0).
    exclusionMode: ExclusionMode.Normal

    // ── Style ────────────────────────────────────────────────────────────────
    readonly property string fontFamily: TrayState.fontFamily
    readonly property color dim: Qt.alpha(Colors.colCyan, 0.35)

    // The window is always full size while visible; the frame inside it is
    // what animates (grows from the top-right corner).
    readonly property int fullW: 380
    readonly property real fullH: col.implicitHeight + 2

    implicitWidth: fullW
    implicitHeight: fullH

    WlrLayershell.namespace: "qs-tray"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: TrayState.open
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    onVisibleChanged: if (visible) keys.forceActiveFocus()

    // ── Animation state ──────────────────────────────────────────────────────
    property real openW: 0        // 0..1 horizontal expand
    property real openH: 0        // 0..1 vertical expand
    property real flick: 1        // frame opacity (glitch flicker)
    property real revealRows: 999 // rows with index < revealRows are shown (hard step, no fade)

    // ── Sound effects (silent automatically when sound is off) ───────────────
    Sfx {
        id: openSfx
        file: "systray/open.wav"
    }
    Sfx {
        id: closeSfx
        file: "systray/close.wav"
    }
    Sfx {
        id: navSfx
        file: "systray/nav.wav"
    }

    Connections {
        target: TrayState
        function onOpenChanged() {
            if (TrayState.open) {
                closeSfx.stop();
                openSfx.play();

                closeAnim.stop();
                win.reallyVisible = true;

                if (Settings.animationsEnabled) {
                    openAnim.restart();
                } else {
                    openAnim.stop();
                    win.openW = 1;
                    win.openH = 1;
                    win.flick = 1;
                    win.revealRows = 999;
                }
            } else {
                openSfx.stop();
                closeSfx.play();

                openAnim.stop();
                if (Settings.animationsEnabled) {
                    closeAnim.restart();
                } else {
                    closeAnim.stop();
                    win.reallyVisible = false;
                    win.flick = 1;
                }
            }
        }
    }

    // ── Open: line extends left from the corner, drops down, flickers,
    //    then rows print one by one ───────────────────────────────────────────
    SequentialAnimation {
        id: openAnim

        ScriptAction {
            script: {
                win.openW = 0;
                win.openH = 0;
                win.flick = 1;
                win.revealRows = 0;
            }
        }

        NumberAnimation {
            target: win
            property: "openW"
            to: 1
            duration: 80
            easing.type: Easing.OutCubic
        }

        ParallelAnimation {
            NumberAnimation {
                target: win
                property: "openH"
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
                    target: win
                    property: "flick"
                    to: 0.4
                    duration: 25
                }
                NumberAnimation {
                    target: win
                    property: "flick"
                    to: 1.0
                    duration: 25
                }
                NumberAnimation {
                    target: win
                    property: "flick"
                    to: 0.7
                    duration: 25
                }
                NumberAnimation {
                    target: win
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
                    target: win
                    property: "revealRows"
                    to: 10
                    duration: 130
                    easing.type: Easing.Linear
                }
            }
        }

        // make sure every row is visible afterwards (menus can be long)
        ScriptAction {
            script: {
                win.revealRows = 999;
                win.flick = 1;
            }
        }
    }

    // ── Close: fast reverse, then hide ───────────────────────────────────────
    SequentialAnimation {
        id: closeAnim

        NumberAnimation {
            target: win
            property: "openH"
            to: 0
            duration: 50
            easing.type: Easing.InQuart
        }
        NumberAnimation {
            target: win
            property: "openW"
            to: 0
            duration: 50
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                win.reallyVisible = false;
                win.flick = 1;
            }
        }
    }

    Rectangle {
        id: frame
        anchors { top: parent.top; right: parent.right }

        // never smaller than 2px so the cyan "CRT line" is always visible
        width: Math.max(2, win.fullW * win.openW)
        height: Math.max(2, win.fullH * win.openH)

        // flick only affects the frame as a whole; the background alpha is
        // set below so text stays full brightness
        opacity: win.flick
        clip: true

        radius: 0
        color: Qt.alpha(Colors.colBg, 0.88)
        border.width: 1
        border.color: win.dim

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true

            Keys.onPressed: function(event) {
                var before = TrayState.sel;
                event.accepted = TrayState.handleKey(event.key, event.text);
                // tick only for keyboard-driven selection changes
                if (TrayState.open && TrayState.sel !== before)
                    navSfx.play();
            }

            // fixed width + anchored right, so content is wiped in as the
            // frame widens instead of reflowing
            ColumnLayout {
                id: col
                width: win.fullW - 2
                anchors { right: parent.right; top: parent.top; margins: 1 }
                spacing: 0

                // ── Title bar ───────────────────────────────────────────────
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
                                text: TrayState.inMenu ? "MENU" : "TRAY"
                                font.family: win.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                font.letterSpacing: 1
                                color: Colors.colBg
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: TrayState.inMenu
                                ? "tray/" + TrayState.labelFor(TrayState.menuOwner).toLowerCase()
                                : ("linuxguy") + "@systray"
                            font.family: win.fontFamily
                            font.pixelSize: 11
                            color: Colors.colBrightBlack
                        }

                        Text {
                            text: String(TrayState.count).padStart(2, "0")
                            font.family: win.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: Colors.colCyan
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: win.dim
                    }
                }

                // ── Entries ─────────────────────────────────────────────────
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
                        implicitHeight: isSep ? 9 : 30

                        // hard step reveal (no fade) to match the instant-swap style
                        opacity: index < win.revealRows ? 1 : 0

                        // separator
                        Rectangle {
                            visible: row.isSep
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
                            height: 1
                            color: Qt.alpha(Colors.colCyan, 0.2)
                        }

                        // row body: selected = solid cyan block, instant swap
                        Rectangle {
                            visible: !row.isSep
                            anchors.fill: parent
                            color: row.isSel ? Colors.colCyan : "transparent"

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: row.dim ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onEntered: if (row.modelData && !row.dim) TrayState.sel = row.index
                                onClicked: { TrayState.sel = row.index; TrayState.activate() }
                            }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 14 }
                                spacing: 8

                                Text {
                                    text: row.isSel ? ">" : " "
                                    color: Colors.colBg
                                    font.family: win.fontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                // 1-9 jump number, dim (fixed width so rows stay aligned)
                                Text {
                                    visible: !TrayState.inMenu
                                    Layout.preferredWidth: 10
                                    text: row.index < 9 ? (row.index + 1).toString() : ""
                                    color: row.isSel ? Colors.colBg : Colors.colBrightBlack
                                    font.family: win.fontFamily
                                    font.pixelSize: 12
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
                                    color: row.isSel ? Colors.colBg
                                         : row.dim ? Colors.colBrightBlack
                                         : Colors.colFg
                                    font.family: win.fontFamily
                                    font.pixelSize: 13
                                    font.bold: row.isSel
                                }

                                // tray item that has a context menu: boxed MENU tag
                                Rectangle {
                                    readonly property bool shown: !TrayState.inMenu
                                        && row.modelData && row.modelData.hasMenu
                                    visible: shown
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 16
                                    color: row.isSel ? Colors.colBg : Qt.alpha(Colors.colCyan, 0.15)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "MENU"
                                        font.family: win.fontFamily
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: Colors.colCyan
                                    }
                                }

                                // menu entry that opens a submenu
                                Text {
                                    visible: TrayState.inMenu && row.modelData && row.modelData.hasChildren
                                    text: ">"
                                    color: row.isSel ? Colors.colBg : Colors.colCyan
                                    font.family: win.fontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }
                        }
                    }
                }

                // ── Empty state ─────────────────────────────────────────────
                Text {
                    visible: TrayState.count === 0
                    Layout.fillWidth: true
                    Layout.margins: 10
                    horizontalAlignment: Text.AlignHCenter
                    text: "-- no tray items --"
                    color: Colors.colBrightBlack
                    font.family: win.fontFamily
                    font.pixelSize: 12
                }

                // ── Footer ──────────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28

                    Rectangle {
                        anchors.top: parent.top
                        width: parent.width
                        height: 1
                        color: win.dim
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        spacing: 12

                        Repeater {
                            model: TrayState.inMenu
                                ? [
                                    { k: "j/k", d: "move" },
                                    { k: "⏎",   d: "run" },
                                    { k: "h",   d: "back" },
                                    { k: "ESC", d: "close" }
                                  ]
                                : [
                                    { k: "j/k", d: "move" },
                                    { k: "⏎",   d: "open" },
                                    { k: "l",   d: "menu" },
                                    { k: "1-9", d: "jump" }
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
                                        font.family: win.fontFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: Colors.colBg
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.d
                                    font.family: win.fontFamily
                                    font.pixelSize: 10
                                    color: Colors.colBrightBlack
                                }
                            }
                        }
                    }
                }
            }
        }

        // last child so it draws on top of the content
        CornerBrackets {}
    }
}
