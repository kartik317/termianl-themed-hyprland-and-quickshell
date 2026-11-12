pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Shared state for the notification center.
// NOTE: singletons are lazy, so NotificationCenter.qml must reference this
// (it does) or the server will never start.
Singleton {
    id: root

    property bool open: false

    // Do not disturb: notifications still land in history, but no toast.
    property bool dnd: false
    // Set true if critical notifications should still toast during DND.
    property bool dndAllowCritical: false

    // id -> arrival timestamp (ms). Notification has no time property.
    property var stamps: ({})

    // Notifications currently shown as toasts (oldest first).
    property var popups: []
    readonly property int maxPopups: 4

    // History, newest first.
    readonly property var items: Array.from(server.trackedNotifications.values).reverse()
    readonly property int count: items.length

    function clearAll() {
        var list = Array.from(server.trackedNotifications.values)
        for (var i = 0; i < list.length; i++)
            list[i].dismiss()
    }

    function removePopup(n) {
        popups = popups.filter(function(p) { return p !== n })
    }

    // Hide the newest toast (the one nearest the corner). Stays in history.
    function hideNewestPopup() {
        if (popups.length > 0)
            popups = popups.slice(0, -1)
    }

    function hideAllPopups() {
        popups = []
    }

    function shouldPopup(n) {
        if (open) return false
        if (dnd && !(dndAllowCritical && n.urgency === NotificationUrgency.Critical))
            return false
        return true
    }

    // Turning DND on or opening the center clears any visible toasts.
    onDndChanged: { if (dnd) popups = [] }
    onOpenChanged: { if (open) popups = [] }

    property NotificationServer server: NotificationServer {
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: false
        persistenceSupported: true

        onNotification: function(n) {
            n.tracked = true

            var s = root.stamps
            s[n.id] = Date.now()
            root.stamps = s

            if (root.shouldPopup(n)) {
                n.closed.connect(function() { root.removePopup(n) })
                root.popups = root.popups.concat([n]).slice(-root.maxPopups)
            }
        }
    }
}

