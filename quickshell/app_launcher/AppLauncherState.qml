pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool launcherVisible: false
    property var recentIds: []

    readonly property string cachePath: Quickshell.env("HOME") + "/.config/quickshell/app_launcher_recents.json"

    Component.onCompleted: {
        loadProcess.running = true
    }

    objectName: "appLauncherState"

    property Process loadProcess: Process {
        command: ["cat", root.cachePath]
        stdout: SplitParser {
            onRead: data => {
                try {
                    if (data.trim()) {
                        root.recentIds = JSON.parse(data.trim())
                    }
                } catch (e) {
                    console.warn("Failed to parse recent apps cache:", e)
                }
            }
        }
    }

    property Process saveProcess: Process {
        property string payload: "[]"
        command: ["sh", "-c", "mkdir -p $(dirname '" + root.cachePath + "') && echo '" + payload + "' > '" + root.cachePath + "'"]
    }

    function toggle() { launcherVisible = !launcherVisible }
    function show()   { launcherVisible = true }
    function hide()   { launcherVisible = false }

    function recordLaunch(id) {
        var list = recentIds.slice()
        var idx  = list.indexOf(id)
        if (idx !== -1) list.splice(idx, 1)
        list.unshift(id)
        if (list.length > 12) list = list.slice(0, 12)
        recentIds = list

        saveProcess.payload = JSON.stringify(list)
        saveProcess.running = true
    }

    function clearRecents() {
        recentIds = []
        saveProcess.payload = "[]"
        saveProcess.running = true
    }
}
