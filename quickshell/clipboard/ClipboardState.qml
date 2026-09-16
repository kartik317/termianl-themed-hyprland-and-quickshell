pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ------------------------------------------------------------- state

    property bool open: false
    property bool reallyVisible: false
    property var entries: []          // [{ id, line, text }]
    property string search: ""
    property int selected: 0

    readonly property var filtered: {
        if (search.length === 0)
            return entries;
        var q = search.toLowerCase();
        var out = [];
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].text.toLowerCase().indexOf(q) !== -1)
                out.push(entries[i]);
        }
        return out;
    }

    // ----------------------------------------------------------- control

    function show() {
        reallyVisible = true;
        open = true;
        search = "";
        selected = 0;
        reload();
    }

    function close() {
        open = false;
        closeTimer.restart();
    }

    function toggle() {
        open ? close() : show();
    }

    // ----------------------------------------------------------- actions

    function reload() {
        listProc.running = false;
        listProc.running = true;
    }

    function copyEntry(line) {
        actionProc.running = false;
        actionProc.command = ["sh", "-c", "printf '%s' \"$0\" | cliphist decode | wl-copy", line];
        actionProc.running = true;
        close();
    }

    function deleteEntry(line) {
        actionProc.running = false;
        actionProc.command = ["sh", "-c", "printf '%s' \"$0\" | cliphist delete", line];
        actionProc.running = true;
        refreshTimer.restart();
    }

    function wipeAll() {
        actionProc.running = false;
        actionProc.command = ["sh", "-c", "cliphist wipe"];
        actionProc.running = true;
        refreshTimer.restart();
    }

    // ---------------------------------------------------------- children
    // QtObject-derived: every child must be assigned to a named property

    property Process listProc: Process {
        command: ["sh", "-c", "cliphist list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var out = [];
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i];
                    if (l.length === 0)
                        continue;
                    var tab = l.indexOf("\t");
                    if (tab === -1)
                        continue;
                    out.push({
                        "id": l.substring(0, tab),
                        "line": l,
                        "text": l.substring(tab + 1)
                    });
                }
                root.entries = out;
                if (root.selected >= root.filtered.length)
                    root.selected = Math.max(0, root.filtered.length - 1);
            }
        }
    }

    property Process actionProc: Process {}

    property Timer closeTimer: Timer {
        interval: 90
        onTriggered: root.reallyVisible = false
    }

    // cliphist's db write isn't synchronous with process exit
    property Timer refreshTimer: Timer {
        interval: 60
        onTriggered: root.reload()
    }

    property IpcHandler ipc: IpcHandler {
        target: "clipboard"

        function toggle(): void {
            root.toggle();
        }
        function show(): void {
            root.show();
        }
        function hide(): void {
            root.close();
        }
    }
}

