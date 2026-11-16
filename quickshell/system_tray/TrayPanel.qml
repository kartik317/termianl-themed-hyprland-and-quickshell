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
        opacity: win.flick
        clip: true

        radius: 0
        color: Qt.alpha(Colors.colBg, 0.65)
        border.width: 1
        border.color: Colors.colCyan

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

                        // hard step reveal (no fade) to match the instant-swap style
                        opacity: index < win.revealRows ? 1 : 0

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

