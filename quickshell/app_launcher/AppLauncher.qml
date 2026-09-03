import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "../theme"

PanelWindow {
    id: root
    property var screen

    IpcHandler {
        target: "applauncher"
        function toggle() {
            AppLauncherState.toggle();
        }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: AppLauncherState.launcherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "app-launcher"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        item: AppLauncherState.launcherVisible ? maskCover : null
    }
    Item {
        id: maskCover
        anchors.fill: parent
    }

    color: "transparent"

    // ── State ──────────────────────────────────────────────────────────────
    property string searchQuery: ""
    property int selectedIndex: 0
    readonly property bool isSearching: searchQuery.trim() !== ""

    property var filteredApps: {
        var q = searchQuery.trim().toLowerCase();
        var vals = DesktopEntries.applications.values;

        if (q !== "") {
            return vals.filter(function (e) {
                if (e.name.toLowerCase().indexOf(q) !== -1)
                    return true;
                if (e.genericName && e.genericName.toLowerCase().indexOf(q) !== -1)
                    return true;
                for (var i = 0; i < e.keywords.length; i++)
                    if (e.keywords[i].toLowerCase().indexOf(q) !== -1)
                        return true;
                return false;
            }).sort(function (a, b) {
                return a.name.localeCompare(b.name);
            });
        }

        var recent = AppLauncherState.recentIds;
        return vals.slice().sort(function (a, b) {
            var ai = recent.indexOf(a.id);
            var bi = recent.indexOf(b.id);
            if (ai !== -1 && bi !== -1)
                return ai - bi;
            if (ai !== -1)
                return -1;
            if (bi !== -1)
                return 1;
            return a.name.localeCompare(b.name);
        });
    }

    onFilteredAppsChanged: selectedIndex = 0

    // ── Launch ─────────────────────────────────────────────────────────────
    function launchEntry(entry) {
        AppLauncherState.recordLaunch(entry.id);
        entry.execute();
        AppLauncherState.hide();
    }

    // ── Navigation ─────────────────────────────────────────────────────────
    function navigate(delta) {
        if (filteredApps.length === 0)
            return;
        selectedIndex = (selectedIndex + delta + filteredApps.length) % filteredApps.length;
        listView.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    Connections {
        target: AppLauncherState
        function onLauncherVisibleChanged() {
            if (AppLauncherState.launcherVisible) {
                searchInput.text = "";
                root.searchQuery = "";
                root.selectedIndex = 0;
                searchInput.forceActiveFocus();
            }
        }
    }

    // ── Terminal palette setup ─────────────────────────────────────────────
    readonly property color accentFill: Colors.colBlue
    readonly property color fgDim: Qt.rgba(Colors.colFg.r, Colors.colFg.g, Colors.colFg.b, 0.6)

    // ── Panel geometry ─────────────────────────────────────────────────────
    readonly property int maxVisible: 8
    readonly property int itemH: 32
    readonly property int panelW: 460
    readonly property int panelH: 64 + Math.min(filteredApps.length, maxVisible) * itemH

    // Click outside → close
    MouseArea {
        anchors.fill: parent
        enabled: AppLauncherState.launcherVisible
        onClicked: AppLauncherState.hide()
    }

    // ── Panel ──────────────────────────────────────────────────────────────
    Rectangle {
	id: panelBorder
	width: root.panelW
	height: root.panelH

	anchors {
	    bottom: parent.bottom
	    bottomMargin: 0 // distance from screen edge, adjust to taste
	    horizontalCenter: parent.horizontalCenter
	}
	visible: AppLauncherState.launcherVisible

	color: "transparent"
	border.color: Colors.colCyan
	border.width: 1
	radius: 0

        Rectangle {
            id: panel
	    anchors.fill: parent
            anchors.margins: 1
            
            color: Qt.rgba(Colors.colBg.r, Colors.colBg.g, Colors.colBg.b, 0.5)
            radius: 0
            clip: true

            // ── Content ────────────────────────────────────────────────────────
            Column {
                anchors {
                    top: parent.top
                    topMargin: 10
                    left: parent.left
                    leftMargin: 10
                    right: parent.right
                    rightMargin: 10
                }
                
                // ── Search box (Terminal Prompt Style) ──────────────────────────
                Rectangle {
                    width: parent.width
                    height: 36
                    radius: 0
                    color: Qt.rgba(1, 1, 1, 0.03)
                    border.color: searchInput.activeFocus ? Colors.colCyan : Colors.colBlue
                    border.width: 1

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ">"
                            color: Colors.colCyan
                            font {
                                pixelSize: 13
                                family: "JetBrainsMono Nerd Font"
                                weight: Font.Bold
                            }
                        }

                        Item {
                            width: parent.width - 20
                            height: parent.height

                            TextInput {
                                id: searchInput
                                anchors.fill: parent
                                color: Colors.colFg
                                selectionColor: root.accentFill
                                selectedTextColor: Colors.colBg
                                cursorVisible: true
                                font {
                                    pixelSize: 13
                                    family: "JetBrainsMono Nerd Font"
                                }
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true

                                onTextChanged: root.searchQuery = text

                                Keys.onPressed: function (event) {
                                    if (event.key === Qt.Key_Up) {
                                        root.navigate(-1);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Down) {
                                        root.navigate(1);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        if (root.filteredApps.length > 0)
                                            root.launchEntry(root.filteredApps[root.selectedIndex]);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Escape) {
                                        AppLauncherState.hide();
                                        event.accepted = true;
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    width: 1
                    height: 8
                }

                // ── App list ───────────────────────────────────────────────────
                ListView {
                    id: listView
                    width: parent.width
                    height: Math.min(root.filteredApps.length, root.maxVisible) * root.itemH
                    model: root.filteredApps
                    clip: true
                    interactive: false

                    MouseArea {
                        anchors.fill: parent
                        onWheel: function (wheel) {
                            if (wheel.angleDelta.y < 0)
                                root.navigate(1);
                            else
                                root.navigate(-1);
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.filteredApps.length === 0
                        text: "[ NO MATCHING EXECUTABLES ]"
                        color: Colors.colFg
                        opacity: 0.4
                        font {
                            pixelSize: 12
                            family: "JetBrainsMono Nerd Font"
                        }
                    }

                    delegate: Item {
                        id: appRow
                        width: listView.width
                        height: root.itemH

                        readonly property bool sel: root.selectedIndex === index
                        readonly property bool isRecent: !root.isSearching && AppLauncherState.recentIds.indexOf(modelData.id) !== -1 && AppLauncherState.recentIds.indexOf(modelData.id) < 5

                        Rectangle {
                            anchors.fill: parent
                            radius: 0
                            color: appRow.sel ? root.accentFill : "transparent"

                            Row {
                                anchors {
                                    fill: parent
                                    leftMargin: 8
                                    rightMargin: 8
                                }
                                spacing: 8

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: appRow.sel ? ">" : " "
                                    color: appRow.sel ? Colors.colBg : Colors.colBlue
                                    font {
                                        pixelSize: 12
                                        family: "JetBrainsMono Nerd Font"
                                        weight: Font.Bold
                                    }
                                }

                                Image {
                                    id: appIcon
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 24
                                    height: 24
                                    source: modelData.icon !== "" ? "image://icon/" + modelData.icon : ""
                                    smooth: false
                                    mipmap: false
                                }

                                Text {
                                    text: modelData.name
                                    anchors.verticalCenter: parent.verticalCenter
                                    font {
                                        pixelSize: 12
                                        family: "JetBrainsMono Nerd Font"
                                        weight: appRow.sel ? Font.Bold : Font.Normal
                                    }
                                    color: appRow.sel ? Colors.colBg : Colors.colFg
                                }

                                Text {
                                    visible: appRow.isRecent
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "[REC]"
                                    font {
                                        pixelSize: 10
                                        family: "JetBrainsMono Nerd Font"
                                    }
                                    color: appRow.sel ? Colors.colBg : Colors.colBlue
                                }

                                Text {
                                    visible: modelData.genericName !== ""
                                    text: "- " + modelData.genericName
                                    anchors.verticalCenter: parent.verticalCenter
                                    font {
                                        pixelSize: 11
                                        family: "JetBrainsMono Nerd Font"
                                    }
                                    color: appRow.sel ? Colors.colBg : root.fgDim
                                    opacity: appRow.sel ? 0.8 : 0.5
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.selectedIndex = index
                                onClicked: root.launchEntry(modelData)
                                onWheel: function (wheel) {
                                    if (wheel.angleDelta.y < 0)
                                        root.navigate(1);
                                    else
                                        root.navigate(-1);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
