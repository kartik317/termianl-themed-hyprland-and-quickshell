import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../../theme"

Item {
    id: root

    // Dynamically size based on content, capped strictly at 350px
    implicitWidth: Math.min(350, layout.implicitWidth + 24)
    implicitHeight: 36

    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    RowLayout {
        id: layout
        anchors.centerIn: parent
        // Constrain within the root width minus horizontal padding
        width: Math.min(implicitWidth, root.width - 24)
        spacing: 8

        // Cycle player source
        CtrlButton {
            visible: MediaState.players.length > 1
            icon: "\uf443"
            iconSize: 14
            onClicked: MediaState.cyclePlayer()
        }

        // Album art (sharp, 1px cyan frame)
        Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 26
            radius: 0
            color: Qt.alpha(Colors.colCyan, 0.15)
            border.width: 1
            border.color: Colors.colCyan
            visible: MediaState.hasPlayer 
            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: MediaState.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                clip: true 
            }
        }

        // Title / artist
        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Layout.maximumWidth: 160

            RowLayout {
                spacing: 6
                Layout.fillWidth: true

                Text {
                    text: ">"
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: Colors.colCyan
                }
                Text {
                    text: MediaState.hasPlayer ? MediaState.title : "no_signal"
                    color: MediaState.hasPlayer ? Colors.colFg : Colors.colBrightBlack
                    font.pixelSize: 12
                    font.family: root.fontFamily
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            Text {
                text: MediaState.artist
                color: Colors.colBrightBlack
                font.pixelSize: 10
                font.family: root.fontFamily
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.leftMargin: 14   // lines up under the title, past the > glyph
                visible: MediaState.artist.length > 0
            }
        }

        // Transport controls
        RowLayout {
            spacing: 2

            CtrlButton {
                icon: "󰒮"
                iconSize: 20
                lit: MediaState.canGoPrevious
                onClicked: MediaState.previous()
            }

            // Play/Pause: solid cyan block while playing, dim block while paused
            CtrlButton {
                icon: MediaState.isPlaying ? "󰏤" : "󰐊"
                iconSize: 20
                solid: MediaState.isPlaying
                onClicked: MediaState.togglePlaying()
            }

            CtrlButton {
                icon: "󰒭"
                iconSize: 20
                lit: MediaState.canGoNext
                onClicked: MediaState.next()
            }
        }

        // Toggles: cyan when on, dim when off
        RowLayout {
            spacing: 2

            CtrlButton {
                icon: "󰒝"
                iconSize: 17
                lit: MediaState.shuffleOn
                onClicked: MediaState.toggleShuffle()
            }

            CtrlButton {
                icon: MediaState.loopStatus === MprisLoopState.Track ? "󰑘" : "󰑖"
                iconSize: 17
                lit: MediaState.loopStatus !== MprisLoopState.None
                onClicked: MediaState.cycleLoop()
            }
        }
    }
}
