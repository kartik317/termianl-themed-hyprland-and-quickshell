import Quickshell
import Quickshell.Wayland
import QtQuick
import "../theme"

PanelWindow {
    id: panel

    visible: LiveWallpaperState.visible

    exclusiveZone: 0

    WlrLayershell.namespace: "qs-liveWallpaperSwitcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: LiveWallpaperState.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        item: LiveWallpaperState.visible ? maskCover : null
    }
    Item {
        id: maskCover
        anchors.fill: parent
    }

    implicitHeight: 260
    color: "transparent"

    readonly property color accentFill: Colors.colBlue

    MouseArea {
        anchors.fill: parent
        enabled: LiveWallpaperState.visible
        onClicked: LiveWallpaperState.hide()
    }

    // ── Outer border (matches launcher/power menu/wallpaper switcher) ─────────
    Rectangle {
        id: container
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 1220
        height: 240

        radius: 0
        color: "transparent"
        border.color: Colors.colCyan
        border.width: 1

        focus: true
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Right) {
                LiveWallpaperState.selectedIndex = Math.min(LiveWallpaperState.selectedIndex + 1, LiveWallpaperState.wallpapers.length - 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                LiveWallpaperState.selectedIndex = Math.max(LiveWallpaperState.selectedIndex - 1, 0);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                LiveWallpaperState.selectAndApply();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                LiveWallpaperState.hide();
                event.accepted = true;
            }
        }

        Component.onCompleted: forceActiveFocus()
        onVisibleChanged: if (visible) forceActiveFocus()

        // ── Inner fill ─────────────────────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: Qt.rgba(Colors.colBg.r, Colors.colBg.g, Colors.colBg.b, 0.8)
            radius: 0
            clip: true

            Column {
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 8

                // ── Header (terminal prompt style) ─────────────────────────────
                Rectangle {
                    width: parent.width
                    height: 28
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
                            text: "LIVE WALLPAPER [" + (LiveWallpaperState.selectedIndex + 1) + "/" + LiveWallpaperState.wallpapers.length + "]"
                            color: Colors.colFg
                            font {
                                pixelSize: 12
                                family: "JetBrainsMono Nerd Font"
                                weight: Font.Bold
                                letterSpacing: 1
                            }
                        }
                    }
                }

                // ── Wallpaper strip ───────────────────────────────────────────
                ListView {
                    id: strip
                    width: parent.width
                    height: parent.height - 36
                    orientation: ListView.Horizontal
                    spacing: 10
                    model: LiveWallpaperState.wallpapers
                    currentIndex: LiveWallpaperState.selectedIndex
                    highlightMoveDuration: 0
                    onCurrentIndexChanged: strip.positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Item {
                        id: thumb
                        width: 160
                        height: strip.height
                        readonly property bool isSelected: index === LiveWallpaperState.selectedIndex
                        readonly property bool isVideo: {
                            var s = String(modelData).toLowerCase();
                            return s.endsWith('.mp4') || s.endsWith('.webm') || s.endsWith('.mkv') || s.endsWith('.mov')
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 0
                            color: "transparent"
                            border.width: 1
                            border.color: thumb.isSelected ? Colors.colCyan : Qt.rgba(Colors.colFg.r, Colors.colFg.g, Colors.colFg.b, 0.15)

                            Image {
                                id: previewImage
                                anchors.fill: parent
                                anchors.margins: 3
                                source: "file://" + LiveWallpaperState.thumbFor(modelData)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                sourceSize.width: 320
                                sourceSize.height: 200
                                opacity: thumb.isSelected ? 1.0 : 0.55
                            }

                            // Video overlay — play glyph, no motion
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 3
                                visible: thumb.isVideo
                                color: Qt.rgba(0, 0, 0, 0.15)
                                radius: 0

                                Text {
                                    anchors.centerIn: parent
                                    text: "▶"
                                    color: Colors.colFg
                                    font.pixelSize: 24
                                    opacity: thumb.isSelected ? 0.95 : 0.6
                                }
                            }

                            // [VID] tag, top-right
                            Rectangle {
                                visible: thumb.isVideo
                                anchors {
                                    top: parent.top
                                    right: parent.right
                                    margins: 4
                                }
                                width: vidTag.implicitWidth + 8
                                height: 16
                                radius: 0
                                color: Qt.rgba(Colors.colBg.r, Colors.colBg.g, Colors.colBg.b, 0.85)
                                border.color: Colors.colFg
                                border.width: 1

                                Text {
                                    id: vidTag
                                    anchors.centerIn: parent
                                    text: "VID"
                                    color: Colors.colFg
                                    font {
                                        pixelSize: 9
                                        family: "JetBrainsMono Nerd Font"
                                        weight: Font.Bold
                                    }
                                }
                            }

                            // [SEL] tag, top-left (matches wallpaper switcher)
                            Rectangle {
                                visible: thumb.isSelected
                                anchors {
                                    top: parent.top
                                    left: parent.left
                                    margins: 4
                                }
                                width: selTag.implicitWidth + 8
                                height: 16
                                radius: 0
                                color: panel.accentFill

                                Text {
                                    id: selTag
                                    anchors.centerIn: parent
                                    text: "SEL"
                                    color: Colors.colBg
                                    font {
                                        pixelSize: 9
                                        family: "JetBrainsMono Nerd Font"
                                        weight: Font.Bold
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                LiveWallpaperState.selectedIndex = index;
                                LiveWallpaperState.selectAndApply();
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: wheelOverlay
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: function (wheel) {
                if (wheel.angleDelta.y < 0) {
                    LiveWallpaperState.selectedIndex = Math.min(LiveWallpaperState.selectedIndex + 1, LiveWallpaperState.wallpapers.length - 1);
                } else if (wheel.angleDelta.y > 0) {
                    LiveWallpaperState.selectedIndex = Math.max(LiveWallpaperState.selectedIndex - 1, 0);
                }
                wheel.accepted = true;
            }
        }
    }
}
