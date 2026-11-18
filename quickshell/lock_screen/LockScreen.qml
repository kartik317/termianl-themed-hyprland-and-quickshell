import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../theme"
import "../setting_menu"

WlSessionLock {
    id: lock

    // ── customize these ────────────────────────────────────────
    readonly property string promptUser: "LinuxGuy"
    readonly property string timezoneLabel: "IST"
    readonly property color accent: Colors.colCyan
    readonly property color danger: "#e06c75"
    readonly property color line: Qt.alpha(Colors.colCyan, 0.35)
    readonly property color chip: Qt.alpha(Colors.colCyan, 0.15)
    readonly property string termFont: "JetBrainsMono Nerd Font"
    readonly property int cardW: 440
    // ────────────────────────────────────────────────────────────

    // ── Lock / unlock sequencing ───────────────────────────────
    // wantLocked is what actually drives the session lock. On a successful
    // unlock we keep it true for a moment so the glitch-out can play on the
    // surface; the compositor reveals the desktop the instant the lock is
    // released, so there is nothing to animate after that.
    property bool wantLocked: false
    property bool stateLocked: LockScreenState.locked

    signal glitchRequested(string mode)

    // WlSessionLock only takes surfaces as children, so helpers live in
    // explicitly named properties
    property QtObject lockSfx: Sfx {
        file: "lock_screen/locking.wav"
    }
    property QtObject unlockSfx: Sfx {
        file: "lock_screen/unlocking.wav"
    }
    property QtObject releaseTimer: Timer {
        interval: 280 // a little longer than the unlock glitch (8 frames x 32ms)
        onTriggered: lock.wantLocked = false
    }

    onStateLockedChanged: {
        if (stateLocked) {
            releaseTimer.stop();
            wantLocked = true;
            lockSfx.play();
            // surfaces created by this lock run the glitch in Component.onCompleted;
            // this covers re-locking while an unlock glitch is still playing
            glitchRequested("lock");
        } else {
            unlockSfx.play();
            if (Settings.animationsEnabled && wantLocked) {
                glitchRequested("unlock");
                releaseTimer.restart();
            } else {
                wantLocked = false;
            }
        }
    }

    Component.onCompleted: wantLocked = LockScreenState.locked

    locked: wantLocked
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

            // Snaps in and out instantly (stays up during the unlock glitch)
            visible: lock.wantLocked

            // ── Glitch state ──────────────────────────────────────
            property real gO: 1          // card opacity
            property var gOff: [0, 0, 0, 0, 0]   // per-slice horizontal offset (px)
            property real gSplit: 0      // color-split ghost offset (px)
            property real gBeamW: 0      // beam width, 0..1 of card width (0 = hidden)
            property real gBeamH: 2      // beam thickness (px)
            property real gFlash: 0      // faint cyan flash, card area only
            property bool sliceActive: false
            property var gFrames: []
            property int gIndex: -1
            property string gMode: ""

            // each frame lasts one timer tick (32ms)
            // o = card opacity, off = slice offsets, sp = color split,
            // bw/bh = CRT beam width/height, fl = card flash
            readonly property var lockFrames: [
                { o: 0.0, off: [0, 0, 0, 0, 0],            sp: 0, bw: 0.12, bh: 2, fl: 0.00 },
                { o: 0.0, off: [0, 0, 0, 0, 0],            sp: 0, bw: 1.00, bh: 2, fl: 0.00 },
                { o: 1.0, off: [-24, 18, -10, 30, -16],    sp: 6, bw: 0,    bh: 2, fl: 0.12 },
                { o: 1.0, off: [14, -20, 8, -12, 22],      sp: 5, bw: 0,    bh: 2, fl: 0.00 },
                { o: 1.0, off: [-8, 0, 12, -6, 0],         sp: 4, bw: 0,    bh: 2, fl: 0.00 },
                { o: 0.8, off: [0, 6, 0, -4, 0],           sp: 2, bw: 0,    bh: 2, fl: 0.06 },
                { o: 1.0, off: [0, 0, 0, 0, 0],            sp: 3, bw: 0,    bh: 2, fl: 0.00 },
                { o: 1.0, off: [0, 0, 0, 0, 0],            sp: 0, bw: 0,    bh: 2, fl: 0.00 }
            ]
            readonly property var unlockFrames: [
                { o: 1.0, off: [6, -4, 0, 8, -6],          sp: 2, bw: 0,    bh: 2, fl: 0.00 },
                { o: 1.0, off: [-14, 20, -8, 16, -22],     sp: 5, bw: 0,    bh: 2, fl: 0.06 },
                { o: 0.7, off: [26, -30, 14, -18, 28],     sp: 8, bw: 0,    bh: 2, fl: 0.00 },
                { o: 1.0, off: [-10, 0, 22, -14, 0],       sp: 4, bw: 0,    bh: 2, fl: 0.12 },
                { o: 0.0, off: [0, 0, 0, 0, 0],            sp: 0, bw: 1.00, bh: 5, fl: 0.00 },
                { o: 0.0, off: [0, 0, 0, 0, 0],            sp: 0, bw: 0.60, bh: 2, fl: 0.00 },
                { o: 0.0, off: [0, 0, 0, 0, 0],            sp: 0, bw: 0.04, bh: 3, fl: 0.00 },
                { o: 0.0, off: [0, 0, 0, 0, 0],            sp: 0, bw: 0,    bh: 2, fl: 0.00 }
            ]

            function resetGlitch() {
                gO = 1;
                gOff = [0, 0, 0, 0, 0];
                gSplit = 0;
                gBeamW = 0;
                gBeamH = 2;
                gFlash = 0;
                sliceActive = false;
            }

            function stepGlitch() {
                gIndex++;
                if (gIndex >= gFrames.length) {
                    glitchTimer.stop();
                    // after the unlock glitch the card stays hidden until the lock is released
                    if (gMode !== "unlock")
                        resetGlitch();
                    return;
                }
                var f = gFrames[gIndex];
                var active = false;
                for (var i = 0; i < f.off.length; i++) {
                    if (f.off[i] !== 0)
                        active = true;
                }
                gO = f.o;
                gOff = f.off;
                gSplit = f.sp;
                gBeamW = f.bw;
                gBeamH = f.bh;
                gFlash = f.fl;
                sliceActive = active && f.o > 0;
            }

            function startGlitch(mode) {
                glitchTimer.stop();
                if (!Settings.animationsEnabled) {
                    resetGlitch();
                    return;
                }
                gMode = mode;
                gFrames = mode === "unlock" ? unlockFrames : lockFrames;
                gIndex = -1;
                stepGlitch();
                glitchTimer.start();
            }

            Timer {
                id: glitchTimer
                interval: 32
                repeat: true
                onTriggered: mainContainer.stepGlitch()
            }

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

            // Heavier dark overlay so the terminal card pops
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.65
            }

            // ── Terminal card ─────────────────────────────────────
            Rectangle {
                id: card
                width: lock.cardW
                height: contentCol.implicitHeight + 2
                anchors.centerIn: parent

                radius: 0
                color: Qt.alpha(Colors.colBg, 0.88)
                border.width: 1
                border.color: LockScreenState.authFailed ? lock.danger : lock.line

                // glitch: while sliced, the slices carry the opacity, otherwise the card does
                // (wallpaper is never touched, so the pre-warmed background still shows with no flash)
                opacity: mainContainer.sliceActive ? 1 : mainContainer.gO

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
                    return dow + " " + mon + " " + dom + " " + hh + ":" + mi + " " + ampm
                        + (lock.timezoneLabel.length ? " " + lock.timezoneLabel : "") + " " + d.getFullYear()
                }

                ColumnLayout {
                    id: contentCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 1
                    }
                    spacing: 0

                    // ── Title bar ─────────────────────────────────────
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            // blocky inverted tag (red after a failed attempt)
                            Rectangle {
                                implicitWidth: titleTag.implicitWidth + 14
                                implicitHeight: titleTag.implicitHeight + 4
                                color: LockScreenState.authFailed ? lock.danger : lock.accent

                                Text {
                                    id: titleTag
                                    anchors.centerIn: parent
                                    text: "LOCKED"
                                    font.family: lock.termFont
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.letterSpacing: 1
                                    color: Colors.colBg
                                }
                            }

                            Text {
                                text: lock.promptUser.toLowerCase() + "@lock"
                                font.family: lock.termFont
                                font.pixelSize: 11
                                color: Colors.colBrightBlack
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: Qt.formatDateTime(dateLine.currentTime, "HH:mm")
                                font.family: lock.termFont
                                font.pixelSize: 11
                                font.bold: true
                                color: lock.accent
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: lock.line
                        }
                    }

                    // ── Body ──────────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: 14
                        spacing: 6

                        // > date
                        RowLayout {
                            spacing: 8
                            Text {
                                text: ">"
                                font.family: lock.termFont
                                font.pixelSize: 14
                                font.bold: true
                                color: lock.accent
                            }
                            Text {
                                text: "date"
                                font.family: lock.termFont
                                font.pixelSize: 14
                                color: Colors.colFg
                            }
                        }

                        // date output
                        Text {
                            id: dateLine
                            Layout.leftMargin: 18
                            text: card.formatDateLine(currentTime)
                            font.family: lock.termFont
                            font.pixelSize: 13
                            color: Colors.colBrightBlack

                            property date currentTime: new Date()
                            Timer {
                                interval: 1000
                                running: true
                                repeat: true
                                onTriggered: dateLine.currentTime = new Date()
                            }
                        }

                        Item { Layout.preferredHeight: 6 }

                        // > sudo -u user  (password prompt)
                        RowLayout {
                            spacing: 8
                            Text {
                                text: ">"
                                font.family: lock.termFont
                                font.pixelSize: 14
                                font.bold: true
                                color: LockScreenState.authFailed ? lock.danger : lock.accent
                            }
                            Text {
                                text: "login " + lock.promptUser.toLowerCase()
                                font.family: lock.termFont
                                font.pixelSize: 14
                                color: Colors.colFg
                            }
                        }

                        // password box
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: 0
                            color: Qt.alpha(Colors.colCyan, 0.05)
                            border.width: 1
                            border.color: LockScreenState.authFailed ? lock.danger
                                        : pwField.activeFocus ? lock.accent
                                        : lock.line

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: "pass:"
                                    font.family: lock.termFont
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: LockScreenState.authFailed ? lock.danger : lock.accent
                                }

                                TextInput {
                                    id: pwField
                                    Layout.fillWidth: true
                                    font.family: lock.termFont
                                    font.pixelSize: 15
                                    color: Colors.colFg
                                    echoMode: TextInput.Password
                                    passwordCharacter: "•"
                                    passwordMaskDelay: 0
                                    selectByMouse: true
                                    selectionColor: lock.accent
                                    selectedTextColor: Colors.colBg
                                    verticalAlignment: TextInput.AlignVCenter
                                    enabled: !LockScreenState.authenticating && lock.wantLocked && LockScreenState.locked
                                    clip: true

                                    // static block cursor (no blinking)
                                    cursorVisible: true
                                    cursorDelegate: Rectangle {
                                        width: 9
                                        height: pwField.font.pixelSize + 2
                                        color: lock.accent
                                    }

                                    onAccepted: {
                                        if (text.length > 0)
                                            LockScreenState.authenticate(text)
                                    }

                                    // dim hint while empty
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 14
                                        visible: parent.text.length === 0
                                        text: "password"
                                        font.family: lock.termFont
                                        font.pixelSize: 13
                                        color: Colors.colBrightBlack
                                    }
                                }
                            }
                        }

                        // status slot: fixed height so the card never jumps
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22

                            // verifying
                            Row {
                                visible: LockScreenState.authenticating
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Rectangle {
                                    width: authTag.implicitWidth + 10
                                    height: 16
                                    color: lock.accent

                                    Text {
                                        id: authTag
                                        anchors.centerIn: parent
                                        text: "AUTH"
                                        font.family: lock.termFont
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: Colors.colBg
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "verifying..."
                                    font.family: lock.termFont
                                    font.pixelSize: 12
                                    color: Colors.colBrightBlack
                                }
                            }

                            // failed (appears instantly)
                            Row {
                                visible: LockScreenState.authFailed && !LockScreenState.authenticating
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Rectangle {
                                    width: failTag.implicitWidth + 10
                                    height: 16
                                    color: lock.danger

                                    Text {
                                        id: failTag
                                        anchors.centerIn: parent
                                        text: "DENIED"
                                        font.family: lock.termFont
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: Colors.colBg
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "bash: authentication failed"
                                    font.family: lock.termFont
                                    font.pixelSize: 12
                                    color: lock.danger
                                }
                            }
                        }
                    }

                    // ── Footer ────────────────────────────────────────
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28

                        Rectangle {
                            anchors.top: parent.top
                            width: parent.width
                            height: 1
                            color: lock.line
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            spacing: 5

                            Rectangle {
                                width: keyText.implicitWidth + 8
                                height: keyText.implicitHeight + 2
                                color: lock.accent

                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: "⏎"
                                    font.family: lock.termFont
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: Colors.colBg
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "unlock"
                                font.family: lock.termFont
                                font.pixelSize: 10
                                color: Colors.colBrightBlack
                            }
                        }
                    }
                }

                // last child so it draws on top of the content
                CornerBrackets {
                    color: LockScreenState.authFailed ? lock.danger : lock.accent
                }
            }
            // ──────────────────────────────────────────────────────

            // ── Glitch overlays (all anchored to the card) ────────
            // card cut into horizontal slices, each shifted sideways
            Repeater {
                model: 5
                delegate: Item {
                    id: slice
                    required property int index
                    readonly property real sh: Math.ceil(card.height / 5)

                    x: card.x + (mainContainer.gOff[index] || 0)
                    y: card.y + index * sh
                    width: card.width
                    height: sh
                    clip: true
                    visible: mainContainer.sliceActive
                    opacity: mainContainer.gO

                    ShaderEffectSource {
                        sourceItem: card
                        width: card.width
                        height: card.height
                        y: -slice.index * slice.sh
                        hideSource: mainContainer.sliceActive
                        live: true
                    }
                }
            }

            // color-split ghosts (red left, cyan right), quick chromatic flash
            MultiEffect {
                source: card
                x: card.x - mainContainer.gSplit
                y: card.y
                width: card.width
                height: card.height
                colorization: 1.0
                colorizationColor: lock.danger
                opacity: mainContainer.gSplit > 0 ? 0.25 : 0
                visible: mainContainer.gSplit > 0
            }
            MultiEffect {
                source: card
                x: card.x + mainContainer.gSplit
                y: card.y
                width: card.width
                height: card.height
                colorization: 1.0
                colorizationColor: lock.accent
                opacity: mainContainer.gSplit > 0 ? 0.25 : 0
                visible: mainContainer.gSplit > 0
            }

            // faint flash, card area only
            Rectangle {
                x: card.x
                y: card.y
                width: card.width
                height: card.height
                visible: mainContainer.gFlash > 0
                color: lock.accent
                opacity: mainContainer.gFlash
            }

            // CRT beam: lock starts as this line, unlock ends as this line
            Rectangle {
                anchors.centerIn: parent
                width: lock.cardW * mainContainer.gBeamW
                height: mainContainer.gBeamH
                visible: mainContainer.gBeamW > 0
                color: lock.accent
            }

            Connections {
                target: lock
                function onGlitchRequested(mode) {
                    mainContainer.startGlitch(mode)
                }
            }

            Connections {
                target: LockScreenState
                function onAuthFailedChanged() {
                    if (LockScreenState.authFailed) {
                        // input just clears instantly
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

            Component.onCompleted: {
                pwField.forceActiveFocus()
                // surfaces are created when the lock is established
                startGlitch("lock")
            }
        }
    }
}

