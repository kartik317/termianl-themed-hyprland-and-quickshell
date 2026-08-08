pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland

QtObject {
    id: root
    property bool panelVisible: false
 
    function toggle() { panelVisible = !panelVisible }
    function show()   { panelVisible = true }
    function hide()   { panelVisible = false }
}
