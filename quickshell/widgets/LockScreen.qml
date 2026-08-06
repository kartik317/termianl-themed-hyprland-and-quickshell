import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import "../state"

WlSessionLock {
    id: lock

    // ── customize these ────────────────────────────────────────
    readonly property string promptUser: "thelinuxguy"
    readonly property string timezoneLabel: "IST"
    readonly property color termGreen: "#50FA7B"
    readonly property color termDim: Qt.rgba(1, 1, 1, 0.55)
    readonly property color termFg: "#F8F8F2"
    readonly property string termFont: "JetBrainsMono Nerd Font"
    // ────────────────────────────────────────────────────────────

    locked: LockScreenState.locked
    onLockedChanged: {
        if (LockScreenState.locked !== locked) {
            LockScreenState.locked = locked
        }
    }

    WlSessionLockSurface {
        id: surface

        Rectangle {
            id: mainContainer
            anchors.fill: parent
            color: "#000000"

            // Snaps in and out instantly
            visible: LockScreenState.locked

            // Background Wallpaper
            Image {
                id: wallpaper
                anchors.fill: parent
                source: "file://" + Quickshell.env("HOME") + "/.cache/wallpaper_frame.png"
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: false
                cache: true

                sourceSize.width: surface.width
                sourceSize.height: surface.height

                visible: false
            }

            MultiEffect {
                id: blurredWallpaper
                anchors.fill: wallpaper
                source: wallpaper
                blurEnabled: true
                blur: 0.9
                blurMax: 48

                visible: wallpaper.status === Image.Ready
            }

            // Heavier dark overlay so the terminal text pops
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.65
            }

            // ── Terminal card ─────────────────────────────────────
            Item {
                id: card
                // Wraps exactly around the text for perfect visual centering
                width: contentColumn.implicitWidth
                height: contentColumn.height
                anchors.centerIn: parent

                // live "date" command output
                function formatDateLine(d) {
                    var days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
                    var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
                    var dow = days[d.getDay()]
                    var mon = months[d.getMonth()]
                    var dom = d.getDate() < 10 ? " " + d.getDate() : "" + d.getDate()
                    var h = d.getHours()
                    var ampm = h >= 12 ? "PM" : "AM"
                    var h12 = h % 12; if (h12 === 0) h12 = 12
                    var hh = h12 < 10 ? "0" + h12 : "" + h12
                    var mi = d.getMinutes() < 10 ? "0" + d.getMinutes() : "" + d.getMinutes()
                    var ss = d.getSeconds() < 10 ? "0" + d.getSeconds() : "" + d.getSeconds()
                    return dow + " " + mon + " " + dom + " " + hh + ":" + mi + ":" + ss + " " + ampm
                        + (lock.timezoneLabel.length ? " " + lock.timezoneLabel : "") + " " + d.getFullYear()
                }

                Column {
                    id: contentColumn
                    spacing: 6

                    // ❯ date
                    Row {
                        spacing: 8
                        Text {
                            text: "❯"
                            font.family: lock.termFont
                            font.pixelSize: 16
                            font.bold: true
                            color: lock.termGreen
                        }
                        Text {
                            text: "date"
                            font.family: lock.termFont
                            font.pixelSize: 16
                            color: lock.termFg
                        }
                    }

                    // date output
                    Text {
                        id: dateLine
                        text: card.formatDateLine(currentTime)
                        font.family: lock.termFont
                        font.pixelSize: 15
                        color: lock.termDim

                        property date currentTime: new Date()
                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: dateLine.currentTime = new Date()
                        }
                    }

                    Item { height: 14; width: 1 }

                    // ~ thelinuxguy
                    Row {
                        spacing: 8
                        Text {
                            text: "~"
                            font.family: lock.termFont
                            font.pixelSize: 16
                            font.bold: true
                            color: "#8BE9FD"
                        }
                        Text {
                            text: lock.promptUser
                            font.family: lock.termFont
                            font.pixelSize: 16
                            color: lock.termFg
                        }
                    }

                    Item { height: 6; width: 1 }

                    // Password: <input>
                    Row {
                        spacing: 0
                        Text {
                            text: "Password: "
                            font.family: lock.termFont
                            font.pixelSize: 16
                            // Color changes to red instantly on failure
                            color: LockScreenState.authFailed ? Colors.colRed : lock.termFg
                        }

                        TextInput {
                            id: pwField
                            width: 220
                            font.family: lock.termFont
                            font.pixelSize: 16
                            color: lock.termFg
                            echoMode: TextInput.Password
                            passwordCharacter: "•"
                            passwordMaskDelay: 120
                            selectByMouse: true
                            enabled: !LockScreenState.authenticating
                            clip: true

                            cursorVisible: true
                            cursorDelegate: Rectangle {
                                id: termCursor
                                width: 9
                                height: pwField.font.pixelSize + 2
                                color: lock.termGreen
                                
                                // Hard terminal blink instead of smooth fade
                                Timer {
                                    interval: 500
                                    running: true
                                    repeat: true
                                    onTriggered: termCursor.visible = !termCursor.visible
                                }
                            }

                            onAccepted: {
                                if (text.length > 0)
                                    LockScreenState.authenticate(text)
                            }
                        }

                        BusyIndicator {
                            visible: LockScreenState.authenticating
                            running: LockScreenState.authenticating
                            implicitWidth: 16
                            implicitHeight: 16
                        }
                    }

                    // bash-style error line
                    Text {
                        text: "bash: authentication failed"
                        font.family: lock.termFont
                        font.pixelSize: 13
                        color: Colors.colRed
                        // Appears instantly
                        visible: LockScreenState.authFailed 
                    }
                }
            }
            // ──────────────────────────────────────────────────────

            Connections {
                target: LockScreenState
                function onAuthFailedChanged() {
                    if (LockScreenState.authFailed) {
                        // Shake animation removed. Input just clears instantly.
                        pwField.text = ""
                        pwField.forceActiveFocus()
                    }
                }
                function onLockedChanged() {
                    if (!LockScreenState.locked) {
                        pwField.text = ""
                    } else {
                        pwField.forceActiveFocus()
                    }
                }
            }

            Component.onCompleted: pwField.forceActiveFocus()
        }
    }
}
