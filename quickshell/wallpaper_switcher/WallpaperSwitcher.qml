import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../theme"
import "../setting_menu"

PanelWindow {
    id: panel

    // stays true until the close animation finishes
    property bool reallyVisible: false
    visible: panel.reallyVisible

    exclusiveZone: 0

    WlrLayershell.namespace: "wallpaper-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WallpaperState.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        item: WallpaperState.visible ? maskCover : null
    }
    Item {
        id: maskCover
        anchors.fill: parent
    }

    implicitHeight: 260
    color: "transparent"

    // ── Style ────────────────────────────────────────────────────────────────
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property color dim: Qt.alpha(Colors.colCyan, 0.35)

    // ── Geometry ─────────────────────────────────────────────────────────────
    readonly property int cardW: 1220
    readonly property int cardH: 240
    readonly property int titleH: 34
    readonly property int footerH: 28
    readonly property int thumbW: 180

    // ── Animation state ──────────────────────────────────────────────────────
    property real openW: 0        // 0..1 horizontal expand
    property real openH: 0        // 0..1 vertical expand
    property real flick: 1        // card opacity (glitch flicker)
    property real revealRows: 999 // thumbnails with index < revealRows are shown (hard step, no fade)

    // ── Sound effects (silent automatically when sound is off) ───────────────
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

    // ── Selection ────────────────────────────────────────────────────────────
    function step(delta) {
        var n = WallpaperState.wallpapers.length;
        if (n === 0)
            return;
        WallpaperState.selectedIndex = (WallpaperState.selectedIndex + delta + n) % n;
        navSfx.play();
    }

    Connections {
        target: WallpaperState

        function onVisibleChanged() {
            if (WallpaperState.visible) {
                closeSfx.stop();
                openSfx.play();

                closeAnim.stop();
                panel.reallyVisible = true;
                container.forceActiveFocus();

                if (Settings.animationsEnabled) {
                    openAnim.restart();
                } else {
                    openAnim.stop();
                    panel.openW = 1;
                    panel.openH = 1;
                    panel.flick = 1;
                    panel.revealRows = 999;
                }
            } else {
                openSfx.stop();
                closeSfx.play();

                openAnim.stop();
                if (Settings.animationsEnabled) {
                    closeAnim.restart();
                } else {
                    openAnim.stop();
                    panel.reallyVisible = false;
                    panel.flick = 1;
                }
            }
        }
    }

    // ── Open: line extends from the center, grows upward, flickers,
    //    then thumbnails print one by one ─────────────────────────────────────
    SequentialAnimation {
        id: openAnim

        ScriptAction {
            script: {
                panel.openW = 0;
                panel.openH = 0;
                panel.flick = 1;
                panel.revealRows = 0;
            }
        }

        NumberAnimation {
            target: panel
            property: "openW"
            to: 1
            duration: 90
            easing.type: Easing.OutCubic
        }

        ParallelAnimation {
            NumberAnimation {
                target: panel
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
                    target: panel
                    property: "flick"
                    to: 0.4
                    duration: 25
                }
                NumberAnimation {
                    target: panel
                    property: "flick"
                    to: 1.0
                    duration: 25
                }
                NumberAnimation {
                    target: panel
                    property: "flick"
                    to: 0.7
                    duration: 25
                }
                NumberAnimation {
                    target: panel
                    property: "flick"
                    to: 1.0
                    duration: 25
                }
            }

            // thumbnails print one by one, left to right
            SequentialAnimation {
                PauseAnimation {
                    duration: 50
                }
                NumberAnimation {
                    target: panel
                    property: "revealRows"
                    to: 8
                    duration: 140
                    easing.type: Easing.Linear
                }
            }
        }

        // make sure every thumbnail (including scrolled ones) is visible afterwards
        ScriptAction {
            script: {
                panel.revealRows = 999;
                panel.flick = 1;
            }
        }
    }

    // ── Close: fast reverse, then hide ───────────────────────────────────────
    SequentialAnimation {
        id: closeAnim

        NumberAnimation {
            target: panel
            property: "openH"
            to: 0
            duration: 60
            easing.type: Easing.InQuart
        }
        NumberAnimation {
            target: panel
            property: "openW"
            to: 0
            duration: 50
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                panel.reallyVisible = false;
                panel.flick = 1;
            }
        }
    }

    // Click outside → close
    MouseArea {
        anchors.fill: parent
        enabled: WallpaperState.visible
        onClicked: WallpaperState.hide()
    }

    // ── Card Outer Wrapper (Handles scaling & unclipped border rendering) ───
    Item {
        id: container
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        // never smaller than 4px so the borders have room to render cleanly
        width: Math.max(4, panel.cardW * panel.openW)
        height: Math.max(4, panel.cardH * panel.openH)

        opacity: panel.flick
        visible: panel.reallyVisible

        focus: true
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                panel.step(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                panel.step(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                WallpaperState.selectAndApply();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                WallpaperState.hide();
                event.accepted = true;
            }
        }
        Component.onCompleted: if (WallpaperState.visible) forceActiveFocus()
        onVisibleChanged: if (visible) forceActiveFocus()

        // 1. Outer Border Frame (No clip, draws all borders safely)
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: panel.dim
            border.width: 1
            radius: 0

            // 2. Inner Content Container (Clips content, has background, inset by 1px)
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                color: Qt.alpha(Colors.colBg, 0.88)
                radius: 0
                clip: true

                // swallows clicks on empty card area so they don't close the switcher
                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                // fixed size + anchored top-left, so content is wiped in as the card grows
                ColumnLayout {
                    width: panel.cardW - 2
                    height: panel.cardH - 2
                    anchors {
                        top: parent.top
                        left: parent.left
                        topMargin: 0
                        leftMargin: 0
                    }
                    spacing: 0

                    // ── Title bar ────────────────────────────────────────────
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: panel.titleH

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
                                    text: "WALLPAPER"
                                    font.family: panel.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.letterSpacing: 1
                                    color: Colors.colBg
                                }
                            }

                            Text {
                                text: ("linuxguy") + "@awww"
                                font.family: panel.fontFamily
                                font.pixelSize: 11
                                color: Colors.colBrightBlack
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: String(WallpaperState.wallpapers.length === 0 ? 0 : WallpaperState.selectedIndex + 1).padStart(3, "0")
                                font.family: panel.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: Colors.colCyan
                            }
                            Text {
                                text: "/" + String(WallpaperState.wallpapers.length).padStart(3, "0")
                                font.family: panel.fontFamily
                                font.pixelSize: 11
                                color: Colors.colBrightBlack
                                Layout.leftMargin: -8
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: panel.dim
                        }
                    }

                    // ── Wallpaper strip ──────────────────────────────────────
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListView {
                            id: strip
                            anchors {
                                fill: parent
                                margins: 10
                            }
                            orientation: ListView.Horizontal
                            spacing: 10
                            clip: true
                            model: WallpaperState.wallpapers
                            currentIndex: WallpaperState.selectedIndex
                            highlightMoveDuration: 0
                            onCurrentIndexChanged: strip.positionViewAtIndex(currentIndex, ListView.Contain)

                            delegate: Item {
                                id: thumb
                                width: panel.thumbW
                                height: strip.height

                                readonly property bool isSelected: index === WallpaperState.selectedIndex
                                readonly property bool hovered: thumbMouse.containsMouse
                                readonly property string fileName: {
                                    var p = String(modelData).split("/");
                                    return p[p.length - 1];
                                }

                                opacity: index < panel.revealRows ? 1 : 0

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 0
                                    color: "transparent"
                                    border.width: thumb.isSelected ? 2 : 1
                                    border.color: thumb.isSelected ? Colors.colCyan
                                                : thumb.hovered ? Qt.alpha(Colors.colCyan, 0.6)
                                                : Qt.alpha(Colors.colCyan, 0.2)

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        source: "file://" + modelData
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: false
                                        sourceSize.width: 360
                                        sourceSize.height: 240
                                        opacity: thumb.isSelected ? 1.0 : thumb.hovered ? 0.85 : 0.55
                                    }

                                    Rectangle {
                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            bottom: parent.bottom
                                            margins: 3
                                        }
                                        height: 18
                                        color: thumb.isSelected ? Colors.colCyan : Qt.alpha(Colors.colBg, 0.85)

                                        Text {
                                            anchors {
                                                fill: parent
                                                leftMargin: 6
                                                rightMargin: 6
                                            }
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideMiddle
                                            text: thumb.fileName
                                            font.family: panel.fontFamily
                                            font.pixelSize: 10
                                            font.bold: thumb.isSelected
                                            color: thumb.isSelected ? Colors.colBg : Colors.colBrightBlack
                                        }
                                    }

                                    Rectangle {
                                        visible: thumb.isSelected
                                        anchors {
                                            top: parent.top
                                            left: parent.left
                                            margins: 6
                                        }
                                        width: selTag.implicitWidth + 10
                                        height: 16
                                        color: Colors.colCyan

                                        Text {
                                            id: selTag
                                            anchors.centerIn: parent
                                            text: "SEL"
                                            color: Colors.colBg
                                            font.family: panel.fontFamily
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: thumbMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        WallpaperState.selectedIndex = index;
                                        WallpaperState.selectAndApply();
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: WallpaperState.wallpapers.length === 0
                            text: "-- no wallpapers found --"
                            font.family: panel.fontFamily
                            font.pixelSize: 12
                            color: Colors.colBrightBlack
                        }
                    }

                    // ── Footer ───────────────────────────────────────────────
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: panel.footerH

                        Rectangle {
                            anchors.top: parent.top
                            width: parent.width
                            height: 1
                            color: panel.dim
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            spacing: 12

                            Repeater {
                                model: [
                                    { k: "←→",  d: "browse" },
                                    { k: "⏎",   d: "apply" },
                                    { k: "ESC", d: "quit" }
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
                                            font.family: panel.fontFamily
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: Colors.colBg
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.d
                                        font.family: panel.fontFamily
                                        font.pixelSize: 10
                                        color: Colors.colBrightBlack
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // mouse wheel browses the strip
        MouseArea {
            id: wheelOverlay
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: function (wheel) {
                if (wheel.angleDelta.y < 0)
                    panel.step(1);
                else if (wheel.angleDelta.y > 0)
                    panel.step(-1);
                wheel.accepted = true;
            }
        }

        CornerBrackets {}
    }
}
