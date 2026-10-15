pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

Singleton {
    id: root

    // ---------- config ----------
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int gap: 8          // distance from screen edge / bar
    readonly property int barOffset: 0    // extra top offset; raise this if your bar
                                          // doesn't reserve an exclusive zone

    // ---------- state ----------
    property bool open: false
    property int sel: 0
    property var currentMenu: null   // QsMenuHandle (top level) or QsMenuEntry (submenu)
    property var menuParents: []     // stack for backing out of submenus
    property var menuOwner: null     // tray item whose menu is open
    readonly property bool inMenu: currentMenu !== null

    readonly property var model: inMenu ? opener.children : SystemTray.items
    readonly property int count: model ? model.values.length : 0

    onOpenChanged: resetState()

    QsMenuOpener {
        id: opener
        menu: root.currentMenu
    }

    // ---------- IPC ----------
    IpcHandler {
        target: "tray"

        function toggle(): void { root.open = !root.open }
        function open(): void   { root.open = true }
        function close(): void  { root.open = false }
    }

    // ---------- helpers ----------
    function entries() {
        return root.model ? root.model.values : []
    }

    function selectable(e) {
        if (!e) return false
        if (root.inMenu) return !e.isSeparator && e.enabled
        return true
    }

    function labelFor(e) {
        if (!e) return ""
        if (root.inMenu) return (e.text || "").replace(/&([^&])/g, "$1")
        return e.tooltipTitle || e.title || e.id
    }

    function move(delta) {
        var list = entries()
        var n = list.length
        if (n === 0) return
        var i = root.sel
        for (var step = 0; step < n; step++) {
            i = (i + delta + n) % n
            if (selectable(list[i])) { root.sel = i; return }
        }
    }

    function jump(index) {
        var list = entries()
        if (list.length === 0) return
        root.sel = Math.max(0, Math.min(index, list.length - 1))
        if (!selectable(list[root.sel])) move(1)
    }

    function resetState() {
        root.sel = 0
        root.currentMenu = null
        root.menuParents = []
        root.menuOwner = null
    }

    function openMenuFor(item) {
        if (!item || !item.hasMenu) return
        root.menuOwner = item
        root.menuParents = []
        root.currentMenu = item.menu
        root.sel = 0
        Qt.callLater(function() { root.jump(0) })
    }

    function back() {
        if (!root.inMenu) { root.open = false; return }
        if (root.menuParents.length > 0) {
            var p = root.menuParents.slice()
            root.currentMenu = p.pop()
            root.menuParents = p
        } else {
            root.currentMenu = null
            root.menuOwner = null
        }
        root.sel = 0
    }

    function activate() {
        var e = entries()[root.sel]
        if (!e) return

        if (!root.inMenu) {
            if (e.onlyMenu && e.hasMenu) { openMenuFor(e); return }
            e.activate()
            root.open = false
        } else if (e.hasChildren) {
            var p = root.menuParents.slice()
            p.push(root.currentMenu)
            root.menuParents = p
            root.currentMenu = e
            root.sel = 0
            Qt.callLater(function() { root.jump(0) })
        } else {
            e.triggered()
            root.open = false
        }
    }

    // Returns true if the key was consumed.
    function handleKey(key, text) {
        if (key === Qt.Key_Escape || text === "q") {
            root.open = false
        } else if (key === Qt.Key_Down || text === "j") {
            move(1)
        } else if (key === Qt.Key_Up || text === "k") {
            move(-1)
        } else if (text === "g") {
            jump(0)
        } else if (text === "G") {
            jump(entries().length - 1)
        } else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) {
            activate()
        } else if (key === Qt.Key_Right || text === "l" || text === "m") {
            if (!root.inMenu) openMenuFor(entries()[root.sel])
            else activate()
        } else if (key === Qt.Key_Left || text === "h" || key === Qt.Key_Backspace) {
            back()
        } else if (text === "s") {
            var it = entries()[root.sel]
            if (!root.inMenu && it) { it.secondaryActivate(); root.open = false }
        } else if (text >= "1" && text <= "9") {
            jump(parseInt(text) - 1)
            activate()
        } else {
            return false
        }
        return true
    }
}

