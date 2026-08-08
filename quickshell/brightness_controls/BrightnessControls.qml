import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    property var modelData
    screen: modelData

    property bool open: BrightnessControlsState.panelVisible
    property int  brightnessValue: 50
    property int  maxBrightness:   1000

    // ── IPC ────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "brightness-controls"
        function toggle() {
            BrightnessControlsState.toggle();
        }
    }

    // ── Layer shell ────────────────────────────────────────────────────────
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace:     "qs-volbri-noanim"
    WlrLayershell.exclusiveZone: 0

    anchors.right:  true
    anchors.top:    true
    anchors.bottom: true

    implicitWidth: 80

    mask: Region {
        item: panelCard
    }

    color: "transparent"

    // ── Slide (instant, no animation) ────────────────────────────────────────
    property real slideOffset: open ? 0 : panelCard.width

    // ── Detect backlight device once at startup ─────────────────────────────
    Process {
        id: backlightDeviceProc
        command: ["sh", "-c", "ls /sys/class/backlight | head -n1"]
        running: true
        stdout: StdioCollector {
            id: backlightDevice
            onStreamFinished: {
                maxBrightnessProc.running = true
            }
        }
    }

    // ── Read max brightness once (doesn't change at runtime) ───────────────
    Process {
        id: maxBrightnessProc
        running: false
        command: ["cat", "/sys/class/backlight/" + backlightDevice.text.trim() + "/max_brightness"]
        stdout: StdioCollector {
            onStreamFinished: {
                const mx = parseInt(text.trim())
                if (!isNaN(mx) && mx > 0) {
                    root.maxBrightness = mx
                }
                brightnessWatcher.reload()
            }
        }
    }

    // ── Live brightness watcher ────────────────────────────────────────────
    FileView {
        id: brightnessWatcher
        path: backlightDevice.text.trim().length > 0
              ? "/sys/class/backlight/" + backlightDevice.text.trim() + "/brightness"
              : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const cur = parseInt(text().trim())
            if (!isNaN(cur) && root.maxBrightness > 0) {
                root.brightnessValue = Math.round(cur / root.maxBrightness * 100)
            }
        }
    }

    function setBrightness(percent) {
        root.brightnessValue = percent
        const proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        proc.command = ["brightnessctl", "set", percent + "%"]
        proc.running = true
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Panel card — docked flush to the right screen edge, terminal style
    // ═══════════════════════════════════════════════════════════════════════
    Rectangle {
        id: panelCard

        width:  80
        height: 340
        anchors.verticalCenter: parent.verticalCenter

        x: root.slideOffset

        radius: 0
        color: "transparent"
        border.color: Colors.colCyan
        border.width: 1

        // Inner fill (matches launcher/power menu/wallpaper panels)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: Qt.rgba(Colors.colBg.r, Colors.colBg.g, Colors.colBg.b, 0.8)
            radius: 0
            clip: true

            VSliderBlock {
                anchors { fill: parent; margins: 14 }

                iconText:    "\uf185"
                label:       "BRI"
                sliderValue: root.brightnessValue
                muted:       false

                onSlide:   val => root.setBrightness(val)
                onIconTap: {}
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  VSliderBlock  —  terminal-style, no animation
    // ═══════════════════════════════════════════════════════════════════════
    component VSliderBlock: ColumnLayout {
        id: block

        property string iconText:    ""
        property string label:       ""
        property int    sliderValue: 50
        property bool   muted:       false

        signal slide(int value)
        signal iconTap()

        spacing: 8

        // Icon button
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 32; height: 32; radius: 0
            color: "transparent"
            border.width: 1
            border.color: block.muted ? Colors.colRed : Colors.colBlue

            Text {
                anchors.centerIn: parent
                text: block.iconText; font.pixelSize: 15
                color: block.muted ? Colors.colRed : Colors.colBlue
            }
            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                onClicked:    block.iconTap()
            }
        }

        // Value readout
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: block.sliderValue + "%"
            font {
                pixelSize: 11
                family: "JetBrainsMono Nerd Font"
                weight: Font.Bold
            }
            color: Colors.colFg
        }

        // ── Custom vertical slider — segmented, terminal meter style ───────
        Item {
            id: sliderItem
            Layout.fillHeight: true
            Layout.alignment:  Qt.AlignHCenter
            implicitWidth:     40

            readonly property int trackH:    height
            readonly property real fraction: Math.max(0, Math.min(1, block.sliderValue / 100.0))
            readonly property int segments:  16
            readonly property int filledSegments: Math.round(fraction * segments)

            // Track — segmented blocks, bottom to top
            Column {
                id: segCol
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: sliderItem.trackH
                spacing: 2
                // top-to-bottom, so reverse index for "filled from bottom"
                Repeater {
                    model: sliderItem.segments
                    delegate: Rectangle {
                        readonly property int segIndexFromBottom: sliderItem.segments - 1 - index
                        width: segCol.width
                        height: (sliderItem.trackH - (sliderItem.segments - 1) * segCol.spacing) / sliderItem.segments
                        radius: 0
                        color: segIndexFromBottom < sliderItem.filledSegments
                               ? (block.muted ? Colors.colBlack : Colors.colBlue)
                               : Qt.rgba(Colors.colFg.r, Colors.colFg.g, Colors.colFg.b, 0.12)
                        border.width: 1
                        border.color: Qt.rgba(Colors.colFg.r, Colors.colFg.g, Colors.colFg.b, 0.1)
                    }
                }
            }

            // Cursor marker — square, sits at current level
            Rectangle {
                id: handle
                width: 16; height: 3; radius: 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: (1.0 - sliderItem.fraction) * sliderItem.trackH - height / 2
                color: dragArea.pressed ? Colors.colCyan
                       : block.muted    ? Colors.colBlack
                       :                  Colors.colFg
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent

                function valueFromY(my) {
                    const clamped = Math.max(0, Math.min(sliderItem.trackH, my))
                    const ratio   = 1.0 - clamped / sliderItem.trackH
                    return Math.round(ratio * 100)
                }

                onPressed:         mouse => block.slide(valueFromY(mouse.y))
                onPositionChanged: mouse => { if (pressed) block.slide(valueFromY(mouse.y)) }
            }
        }

        // Label
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: block.label
            font {
                pixelSize: 11
                family: "JetBrainsMono Nerd Font"
                weight: Font.Bold
                letterSpacing: 1
            }
            color: Colors.colFg
            opacity: 0.7
        }
    }
}
