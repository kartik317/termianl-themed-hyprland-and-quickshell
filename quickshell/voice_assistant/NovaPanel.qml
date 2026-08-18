import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: novaPanel

    anchors {
        bottom: true
    }

    property real restingMargin: 24

    visible: NovaState.isSpeaking

    implicitWidth: wave.implicitWidth + 32
    implicitHeight: maxBarHeight + 24
    property real maxBarHeight: 36
    color: "transparent"

    WlrLayershell.namespace: "nova-wave-noanim"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusiveZone: -1

    margins.bottom: restingMargin

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Colors.colBg
        opacity: 0.8
        border.color: Colors.colCyan
        border.width: 1
    } 
    NovaWave {
        id: wave
        anchors.centerIn: parent
    }
}
