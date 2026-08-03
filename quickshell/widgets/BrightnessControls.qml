import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../state"
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

    // ── Slide ──────────────────────────────────────────────────────────────
    property real slideOffset: open ? 0 : panelCard.width
    Behavior on slideOffset {
        NumberAnimation { duration: 300; easing.type: Easing.OutQuint }

    }

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
    //  Panel card — docked flush to the right screen edge
    // ═══════════════════════════════════════════════════════════════════════
    Rectangle {
        id: panelCard

        width:  80
        height: 340
        anchors.verticalCenter: parent.verticalCenter

        x: root.slideOffset

        color: Qt.rgba(Colors.colBg.r, Colors.colBg.g, Colors.colBg.b, 0.85)

        // Left corners rounded, right corners flush with screen edge
        topLeftRadius:     0
        bottomLeftRadius:  0
        topRightRadius:    0
	bottomRightRadius: 0

        // Border — only on left + top + bottom (right border clipped off-screen)
        Rectangle {
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                rightMargin: -1 // Extends overlay 1px past the right screen edge to hide right border
            }
            z: 1
            color: "transparent"
            topLeftRadius:     parent.topLeftRadius
            bottomLeftRadius:  parent.bottomLeftRadius
            topRightRadius:    0
            bottomRightRadius: 0
	    border.color: Qt.alpha(Colors.colCyan, 0.8)
            border.width: 1
        }

        // ── Brightness ─────────────────────────────────────────────────────
        VSliderBlock {
            anchors { fill: parent; margins: 18 }

            iconText:    "\uf185"
            label:       "Bri"
            sliderValue: root.brightnessValue
            muted:       false

            onSlide:   val => root.setBrightness(val)
            onIconTap: {}
        }
    }
    // ═══════════════════════════════════════════════════════════════════════
    //  VSliderBlock  —  fully custom, no Qt Quick Controls
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
            width: 34; height: 34; radius: 0
            color: block.muted ? Qt.alpha(Colors.colRed,  0.25)
                               : Qt.alpha(Colors.colBlue, 0.18)
            Behavior on color { ColorAnimation { duration: 60 } }

            Text {
                anchors.centerIn: parent
                text: block.iconText; font.pixelSize: 16
                color: block.muted ? Colors.colRed : Colors.colBlue
                Behavior on color { ColorAnimation { duration: 60 } }
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
            font.pixelSize: 11
            color: Colors.colBrightBlack
        }

        // ── Custom vertical slider ─────────────────────────────────────────
        Item {
            id: sliderItem
            Layout.fillHeight: true
            Layout.alignment:  Qt.AlignHCenter
            implicitWidth:     40

            readonly property int trackH:    height - handle.height
            readonly property real fraction: Math.max(0, Math.min(1, block.sliderValue / 100.0))

            // Track background
            Rectangle {
                id: track
                width:  4
                height: sliderItem.trackH
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                radius: 0
                color: Qt.alpha(Colors.colBlack, 0.7)

                // Fill — grows from bottom
                Rectangle {
                    width:          parent.width
                    height:         sliderItem.fraction * parent.height
                    anchors.bottom: parent.bottom
                    radius:         parent.radius
                    color:          block.muted ? Colors.colBlack : Colors.colBlue
                    Behavior on height { NumberAnimation { duration: 40  } }
                    Behavior on color  { ColorAnimation  { duration: 200 } }
                }
            }

            // Handle
            Rectangle {
                id: handle
                width: 16; height: 16; radius: 8
                anchors.horizontalCenter: parent.horizontalCenter
                y: (1.0 - sliderItem.fraction) * sliderItem.trackH
                color: dragArea.pressed ? Colors.colPurple
                       : block.muted    ? Colors.colBlack
                       :                  Colors.colBlue
                scale: dragArea.pressed ? 1.25 : 1.0
                Behavior on color { ColorAnimation  { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 90  } }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent

                function valueFromY(my) {
                    const clamped = Math.max(handle.height / 2,
                                            Math.min(sliderItem.height - handle.height / 2, my))
                    const ratio   = 1.0 - (clamped - handle.height / 2) / sliderItem.trackH
                    return Math.round(ratio * 100)
                }

                onPressed:         mouse => block.slide(valueFromY(mouse.y))
                onPositionChanged: mouse => { if (pressed) block.slide(valueFromY(mouse.y)) }
            }
        }

        // Label
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: block.label; font.pixelSize: 11; font.weight: Font.Medium
            color: Colors.colBrightBlack
        }
    }
}
