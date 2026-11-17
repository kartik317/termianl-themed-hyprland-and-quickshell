import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../theme"
import "../setting_menu"

Scope {
    id: root

    // qs ipc call notifs toggle | open | close | clear
    IpcHandler {
        target: "notifs"

        function toggle(): void { NotificationState.open = !NotificationState.open }
        function open(): void { NotificationState.open = true }
        function close(): void { NotificationState.open = false }
        function clear(): void { NotificationState.clearAll() }

        // qs ipc call notifs dismissToast | dismissAllToasts
        function dismissToast(): void { NotificationState.hideNewestPopup() }
        function dismissAllToasts(): void { NotificationState.hideAllPopups() }

        // qs ipc call notifs toggleDnd | dndOn | dndOff | dndState
        function toggleDnd(): void { NotificationState.dnd = !NotificationState.dnd }
        function dndOn(): void { NotificationState.dnd = true }
        function dndOff(): void { NotificationState.dnd = false }
        function dndState(): string { return NotificationState.dnd ? "on" : "off" }
    }

    NotificationToasts {}

    PanelWindow {
        id: win

        // stays true until the close animation finishes
        property bool reallyVisible: false

        // Window only exists while open, so no input mask is needed.
        visible: win.reallyVisible
        color: "transparent"

        anchors {
            bottom: true
            right: true
        }
        margins {
            bottom: 12
            right: 12
        }

        // The window is always full size while visible; the frame inside it is
        // what animates (grows from the bottom-right corner).
        readonly property int fullW: 420
        readonly property int fullH: 560
        implicitWidth: fullW
        implicitHeight: fullH

        WlrLayershell.namespace: "notificationcenter"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // ── Style ────────────────────────────────────────────────────────────
        readonly property string mono: "JetBrainsMono Nerd Font"
        readonly property color danger: "#e06c75"
        readonly property color line: Qt.alpha(Colors.colCyan, 0.35)
        readonly property color chip: Qt.alpha(Colors.colCyan, 0.15)

        // ── Animation state ──────────────────────────────────────────────────
        property real openW: 0        // 0..1 horizontal expand
        property real openH: 0        // 0..1 vertical expand
        property real flick: 1        // frame opacity (glitch flicker)
        property real revealRows: 999 // rows with index < revealRows are shown (hard step, no fade)

        // ── Sound effects (silent automatically when sound is off) ───────────
        Sfx {
            id: openSfx
            file: "notification/open.wav"
        }
        Sfx {
            id: closeSfx
            file: "notification/close.wav"
        }
        Sfx {
            id: navSfx
            file: "notification/nav.wav"
        }

        Connections {
            target: NotificationState

            function onOpenChanged() {
                if (NotificationState.open) {
                    closeSfx.stop()
                    openSfx.play()

                    closeAnim.stop()
                    win.reallyVisible = true
                    list.currentIndex = 0
                    keys.forceActiveFocus()

                    if (Settings.animationsEnabled) {
                        openAnim.restart()
                    } else {
                        openAnim.stop()
                        win.openW = 1
                        win.openH = 1
                        win.flick = 1
                        win.revealRows = 999
                    }
                } else {
                    openSfx.stop()
                    closeSfx.play()

                    openAnim.stop()
                    if (Settings.animationsEnabled) {
                        closeAnim.restart()
                    } else {
                        closeAnim.stop()
                        win.reallyVisible = false
                        win.flick = 1
                    }
                }
            }
        }

        // ── Open: line extends left from the corner, grows upward, flickers,
        //    then notifications print one by one ──────────────────────────────
        SequentialAnimation {
            id: openAnim

            ScriptAction {
                script: {
                    win.openW = 0
                    win.openH = 0
                    win.flick = 1
                    win.revealRows = 0
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
                    duration: 110
                    easing.type: Easing.OutQuart
                }

                // glitch flicker once it's open
                SequentialAnimation {
                    PauseAnimation {
                        duration: 110
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
                        to: 9
                        duration: 130
                        easing.type: Easing.Linear
                    }
                }
            }

            // make sure every row (including scrolled ones) is visible afterwards
            ScriptAction {
                script: {
                    win.revealRows = 999
                    win.flick = 1
                }
            }
        }

        // ── Close: fast reverse, then hide ───────────────────────────────────
        SequentialAnimation {
            id: closeAnim

            NumberAnimation {
                target: win
                property: "openH"
                to: 0
                duration: 60
                easing.type: Easing.InQuart
            }
            NumberAnimation {
                target: win
                property: "openW"
                to: 0
                duration: 40
                easing.type: Easing.InCubic
            }
            ScriptAction {
                script: {
                    win.reallyVisible = false
                    win.flick = 1
                }
            }
        }

        Rectangle {
            id: frame
            anchors {
                bottom: parent.bottom
                right: parent.right
            }

            // never smaller than 2px so the cyan "CRT line" is always visible
            width: Math.max(2, win.fullW * win.openW)
            height: Math.max(2, win.fullH * win.openH)

            // flick only affects the frame as a whole; the background alpha is
            // set below so text stays full brightness
            opacity: win.flick
            clip: true

            color: Qt.alpha(Colors.colBg, 0.88)
            border.color: win.line
            border.width: 1
            radius: 0

            Item {
                id: keys
                anchors.fill: parent
                focus: true

                Keys.onPressed: function(event) {
                    var n = NotificationState.items[list.currentIndex]
                    var before = list.currentIndex
                    switch (event.key) {
                    case Qt.Key_Escape:
                    case Qt.Key_Q:
                        NotificationState.open = false
                        break
                    case Qt.Key_J:
                    case Qt.Key_Down:
                        list.incrementCurrentIndex()
                        break
                    case Qt.Key_K:
                    case Qt.Key_Up:
                        list.decrementCurrentIndex()
                        break
                    case Qt.Key_X:
                    case Qt.Key_Delete:
                        if (n) n.dismiss()
                        break
                    case Qt.Key_C:
                        NotificationState.clearAll()
                        break
                    case Qt.Key_D:
                        NotificationState.dnd = !NotificationState.dnd
                        break
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (n && n.actions.length > 0) n.actions[0].invoke()
                        break
                    }
                    // tick only when the selection actually moved
                    if (NotificationState.open && list.currentIndex !== before)
                        navSfx.play()
                }

                // fixed size + anchored to the bottom-right corner, so content is
                // wiped in as the frame grows instead of reflowing
                ColumnLayout {
                    width: win.fullW - 2
                    height: win.fullH - 2
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        rightMargin: 1
                        bottomMargin: 1
                    }
                    spacing: 0

                    // ── Title bar ──────────────────────────────────────────
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
                                    text: "NOTIFS"
                                    font.family: win.mono
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.letterSpacing: 1
                                    color: Colors.colBg
                                }
                            }

                            Text {
                                text: ("linuxguy") + "@notifd"
                                font.family: win.mono
                                font.pixelSize: 11
                                color: Colors.colBrightBlack
                            }

                            Item { Layout.fillWidth: true }

                            // DND tag: solid red when on, boxed chip when off
                            Rectangle {
                                implicitWidth: dndText.implicitWidth + 12
                                implicitHeight: 18
                                color: NotificationState.dnd ? win.danger
                                     : dndArea.containsMouse ? Qt.alpha(Colors.colCyan, 0.3)
                                     : win.chip

                                Text {
                                    id: dndText
                                    anchors.centerIn: parent
                                    text: NotificationState.dnd ? "DND ON" : "DND OFF"
                                    color: NotificationState.dnd ? Colors.colBg : Colors.colBrightBlack
                                    font.family: win.mono
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                                MouseArea {
                                    id: dndArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NotificationState.dnd = !NotificationState.dnd
                                }
                            }

                            // clear-all tag: turns solid red on hover
                            Rectangle {
                                implicitWidth: clearText.implicitWidth + 12
                                implicitHeight: 18
                                visible: NotificationState.count > 0
                                color: clearArea.containsMouse ? win.danger : win.chip

                                Text {
                                    id: clearText
                                    anchors.centerIn: parent
                                    text: "CLEAR"
                                    color: clearArea.containsMouse ? Colors.colBg : Colors.colBrightBlack
                                    font.family: win.mono
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                                MouseArea {
                                    id: clearArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NotificationState.clearAll()
                                }
                            }

                            Text {
                                text: String(NotificationState.count).padStart(3, "0")
                                font.family: win.mono
                                font.pixelSize: 11
                                font.bold: true
                                color: Colors.colCyan
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: win.line
                        }
                    }

                    // ── List ───────────────────────────────────────────────
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListView {
                            id: list
                            anchors {
                                fill: parent
                                margins: 10
                            }
                            clip: true
                            spacing: 6
                            model: NotificationState.items
                            currentIndex: 0
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                id: card

                                required property var modelData
                                required property int index

                                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                                readonly property bool low: modelData.urgency === NotificationUrgency.Low
                                readonly property bool selected: ListView.isCurrentItem
                                readonly property bool hovered: cardArea.containsMouse

                                width: ListView.view.width
                                implicitHeight: col.implicitHeight + 16
                                height: implicitHeight
                                radius: 0

                                // selected = faint tint + bright border + solid accent bar
                                color: selected ? Qt.alpha(Colors.colCyan, 0.08)
                                     : hovered ? Qt.alpha(Colors.colCyan, 0.04)
                                     : "transparent"
                                border.width: 1
                                border.color: critical ? (selected ? win.danger : Qt.alpha(win.danger, 0.5))
                                            : selected ? Colors.colCyan
                                            : Qt.alpha(Colors.colCyan, 0.2)

                                // hard step reveal (no fade) to match the instant-swap style
                                opacity: index < win.revealRows ? 1 : 0

                                MouseArea {
                                    id: cardArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: list.currentIndex = card.index
                                }

                                // selection accent bar
                                Rectangle {
                                    visible: card.selected
                                    anchors {
                                        left: parent.left
                                        top: parent.top
                                        bottom: parent.bottom
                                    }
                                    width: 3
                                    color: card.critical ? win.danger : Colors.colCyan
                                }

                                ColumnLayout {
                                    id: col
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: parent.top
                                        leftMargin: 12
                                        rightMargin: 8
                                        topMargin: 8
                                    }
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        // row number, dim
                                        Text {
                                            text: String(card.index + 1).padStart(2, "0")
                                            color: Colors.colBrightBlack
                                            font.family: win.mono
                                            font.pixelSize: 10
                                        }

                                        // urgency tag
                                        Rectangle {
                                            implicitWidth: tagText.implicitWidth + 10
                                            implicitHeight: 16
                                            color: card.critical ? win.danger
                                                 : card.low ? win.chip
                                                 : Colors.colCyan

                                            Text {
                                                id: tagText
                                                anchors.centerIn: parent
                                                text: card.critical ? "CRIT" : card.low ? "LOW" : "INFO"
                                                color: card.low ? Colors.colBrightBlack : Colors.colBg
                                                font.family: win.mono
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                        }

                                        Text {
                                            text: card.modelData.appName.toLowerCase()
                                            color: Colors.colFg
                                            font.family: win.mono
                                            font.pixelSize: 11
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: Qt.formatDateTime(
                                                new Date(NotificationState.stamps[card.modelData.id] || Date.now()),
                                                "HH:mm")
                                            color: Colors.colBrightBlack
                                            font.family: win.mono
                                            font.pixelSize: 10
                                        }

                                        // dismiss: flat, solid red block on hover
                                        Rectangle {
                                            implicitWidth: 18
                                            implicitHeight: 16
                                            color: xArea.containsMouse ? win.danger : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "x"
                                                color: xArea.containsMouse ? Colors.colBg : Colors.colBrightBlack
                                                font.family: win.mono
                                                font.pixelSize: 11
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: xArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: card.modelData.dismiss()
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: text.length > 0
                                        text: card.modelData.summary
                                        color: Colors.colFg
                                        font.family: win.mono
                                        font.pixelSize: 13
                                        font.bold: true
                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: text.length > 0
                                        text: card.modelData.body
                                        textFormat: Text.PlainText
                                        color: Colors.colBrightBlack
                                        font.family: win.mono
                                        font.pixelSize: 12
                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                        maximumLineCount: 4
                                        elide: Text.ElideRight
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        visible: card.modelData.actions.length > 0

                                        Repeater {
                                            model: card.modelData.actions

                                            delegate: Rectangle {
                                                id: btn
                                                required property var modelData

                                                implicitWidth: btnText.implicitWidth + 14
                                                implicitHeight: 20
                                                color: btnArea.containsMouse ? Colors.colCyan : win.chip

                                                Text {
                                                    id: btnText
                                                    anchors.centerIn: parent
                                                    text: btn.modelData.text
                                                    color: btnArea.containsMouse ? Colors.colBg : Colors.colCyan
                                                    font.family: win.mono
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                                MouseArea {
                                                    id: btnArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: btn.modelData.invoke()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: NotificationState.count === 0
                            anchors.centerIn: parent
                            text: "-- no notifications --"
                            color: Colors.colBrightBlack
                            font.family: win.mono
                            font.pixelSize: 12
                        }
                    }

                    // ── Footer ─────────────────────────────────────────────
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28

                        Rectangle {
                            anchors.top: parent.top
                            width: parent.width
                            height: 1
                            color: win.line
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            spacing: 10

                            Repeater {
                                model: [
                                    { k: "j/k", d: "move",    danger: false },
                                    { k: "x",   d: "dismiss", danger: true },
                                    { k: "⏎",   d: "act",     danger: false },
                                    { k: "c",   d: "clear",   danger: true },
                                    { k: "d",   d: "dnd",     danger: false },
                                    { k: "ESC", d: "close",   danger: false }
                                ]

                                Row {
                                    spacing: 5

                                    Rectangle {
                                        width: keyText.implicitWidth + 8
                                        height: keyText.implicitHeight + 2
                                        color: modelData.danger ? win.danger : Colors.colCyan

                                        Text {
                                            id: keyText
                                            anchors.centerIn: parent
                                            text: modelData.k
                                            font.family: win.mono
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: Colors.colBg
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.d
                                        font.family: win.mono
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
}
