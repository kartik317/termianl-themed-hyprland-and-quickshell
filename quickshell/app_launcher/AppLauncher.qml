import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../theme"
import "../setting_menu"

PanelWindow {
    id: root
    property var screen

    IpcHandler {
	target: "applauncher"
	function toggle(): void {
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

    // ── Style ──────────────────────────────────────────────────────────────
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property color dim: Qt.alpha(Colors.colCyan, 0.35)

    // ── Animation state ────────────────────────────────────────────────────
    // reallyVisible stays true until the close animation finishes
    property bool reallyVisible: false
    property real openW: 0        // 0..1 horizontal expand
    property real openH: 0        // 0..1 vertical expand
    property real flick: 1        // panel opacity (glitch flicker)
    property real revealRows: 999 // rows with index < revealRows are shown (hard step, no fade)

    // ── Sound effects (all respect Settings.soundEnabled via Sfx) ──────────
    Sfx {
	id: openSfx
	file: "app_launcher/open.wav"
    }
    Sfx {
	id: closeSfx
	file: "app_launcher/close.wav"
    }
    Sfx {
	id: typeSfx
	file: "app_launcher/type.wav"
    }
    Sfx {
	id: navSfx
	file: "app_launcher/nav.wav"
    }

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
	navSfx.play();
    }

    Connections {
	target: AppLauncherState
	function onLauncherVisibleChanged() {
	    if (AppLauncherState.launcherVisible) {
		closeSfx.stop();
		openSfx.play();

		closeAnim.stop();
		root.reallyVisible = true;
		if (Settings.animationsEnabled) {
		    openAnim.restart();
		} else {
		    openAnim.stop();
		    root.openW = 1;
		    root.openH = 1;
		    root.flick = 1;
		    root.revealRows = 999;
		}

		searchInput.text = "";
		root.searchQuery = "";
		root.selectedIndex = 0;
		searchInput.forceActiveFocus();
	    } else {
		openSfx.stop();
		closeSfx.play();

		openAnim.stop();
		if (Settings.animationsEnabled) {
		    closeAnim.restart();
		} else {
		    closeAnim.stop();
		    root.reallyVisible = false;
		    root.flick = 1;
		}
	    }
	}
    }

    // ── Open animation: CRT line → expand → glitch flicker + line-by-line rows
    SequentialAnimation {
	id: openAnim

	ScriptAction {
	    script: {
		root.openW = 0;
		root.openH = 0;
		root.flick = 1;
		root.revealRows = 0;
	    }
	}

	// 1) 2px cyan line stretches out horizontally
	NumberAnimation {
	    target: root
	    property: "openW"
	    to: 1
	    duration: 70
	    easing.type: Easing.OutCubic
	}

	ParallelAnimation {
	    // 2) snaps open vertically
	    NumberAnimation {
		target: root
		property: "openH"
		to: 1
		duration: 90
		easing.type: Easing.OutQuart
	    }

	    // 3) glitch flicker once it's open
	    SequentialAnimation {
		PauseAnimation {
		    duration: 90
		}
		NumberAnimation {
		    target: root
		    property: "flick"
		    to: 0.4
		    duration: 25
		}
		NumberAnimation {
		    target: root
		    property: "flick"
		    to: 1.0
		    duration: 25
		}
		NumberAnimation {
		    target: root
		    property: "flick"
		    to: 0.7
		    duration: 25
		}
		NumberAnimation {
		    target: root
		    property: "flick"
		    to: 1.0
		    duration: 25
		}
	    }

	    // 4) rows print one by one, like terminal output
	    SequentialAnimation {
		PauseAnimation {
		    duration: 50
		}
		NumberAnimation {
		    target: root
		    property: "revealRows"
		    to: root.maxVisible + 1
		    duration: 120
		    easing.type: Easing.Linear
		}
	    }
	}

	// make sure every row (including scrolled ones) is visible afterwards
	ScriptAction {
	    script: {
		root.revealRows = 999;
		root.flick = 1;
	    }
	}
    }

    // ── Close animation: fast reverse, then hide ───────────────────────────
    SequentialAnimation {
	id: closeAnim

	NumberAnimation {
	    target: root
	    property: "openH"
	    to: 0
	    duration: 60
	    easing.type: Easing.InQuart
	}
	NumberAnimation {
	    target: root
	    property: "openW"
	    to: 0
	    duration: 40
	    easing.type: Easing.InCubic
	}
	ScriptAction {
	    script: {
		root.reallyVisible = false;
		root.flick = 1;
	    }
	}
    }

    // ── Panel geometry ─────────────────────────────────────────────────────
    readonly property int maxVisible: 8
    readonly property int itemH: 32
    readonly property int panelW: 460
    readonly property int titleH: 34
    readonly property int searchH: 48
    readonly property int footerH: 28
    // always reserve at least one row so the empty-state text has room
    readonly property int listRows: Math.max(1, Math.min(filteredApps.length, maxVisible))
    readonly property int panelH: titleH + searchH + listRows * itemH + footerH + 2

    // Click outside → close
    MouseArea {
	anchors.fill: parent
	enabled: AppLauncherState.launcherVisible
	onClicked: AppLauncherState.hide()
    }

    // ── Panel ──────────────────────────────────────────────────────────────
    Rectangle {
	id: panelBorder
	width: Math.max(2, root.panelW * root.openW)
	height: Math.max(2, root.panelH * root.openH)

	opacity: root.flick
	anchors {
	    bottom: parent.bottom
	    bottomMargin: 0
	    horizontalCenter: parent.horizontalCenter
	}
	visible: root.reallyVisible

	color: "transparent"
	border.color: root.dim
	border.width: 1
	radius: 0

	Rectangle {
	    anchors.fill: parent
	    anchors.margins: 1 // Keeps content inside the 1px border
	    color: Qt.alpha(Colors.colBg, 0.88)
	    radius: 0
	    clip: true
	    // swallow clicks on the panel so they don't hit the close-on-click area
	    MouseArea {
		anchors.fill: parent
	    }

	    ColumnLayout {
		width: root.panelW - 2
		height: root.panelH - 2
		anchors {
		    horizontalCenter: parent.horizontalCenter
		    bottom: parent.bottom
		    bottomMargin: 1
		}
		spacing: 0

		// ── Title bar ──────────────────────────────────────────────────
		Item {
		    Layout.fillWidth: true
		    Layout.preferredHeight: root.titleH

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
				text: "LAUNCH"
				font.family: root.fontFamily
				font.pixelSize: 11
				font.bold: true
				font.letterSpacing: 1
				color: Colors.colBg
			    }
			}

			Text {
			    text: ("linuxguy") + "@exec"
			    font.family: root.fontFamily
			    font.pixelSize: 11
			    color: Colors.colBrightBlack
			}

			Item {
			    Layout.fillWidth: true
			}

			Text {
			    text: String(root.filteredApps.length).padStart(3, "0")
			    font.family: root.fontFamily
			    font.pixelSize: 11
			    font.bold: true
			    color: Colors.colCyan
			}
			Text {
			    text: "/" + String(DesktopEntries.applications.values.length).padStart(3, "0")
			    font.family: root.fontFamily
			    font.pixelSize: 11
			    color: Colors.colBrightBlack
			    Layout.leftMargin: -8
			}
		    }

		    Rectangle {
			anchors.bottom: parent.bottom
			width: parent.width
			height: 1
			color: root.dim
		    }
		}

		// ── Search box (terminal prompt) ───────────────────────────────
		Item {
		    Layout.fillWidth: true
		    Layout.preferredHeight: root.searchH

		    Rectangle {
			anchors.fill: parent
			anchors.margins: 8
			radius: 0
			color: Qt.alpha(Colors.colCyan, 0.05)
			border.width: 1
			border.color: searchInput.activeFocus ? Colors.colCyan : root.dim

			RowLayout {
			    anchors.fill: parent
			    anchors.leftMargin: 10
			    anchors.rightMargin: 10
			    spacing: 8

			    Text {
				text: ">"
				color: Colors.colCyan
				font.pixelSize: 13
				font.family: root.fontFamily
				font.bold: true
			    }

			    TextInput {
				id: searchInput
				Layout.fillWidth: true
				color: Colors.colFg
				selectionColor: Colors.colCyan
				selectedTextColor: Colors.colBg
				cursorVisible: true
				font.pixelSize: 13
				font.family: root.fontFamily
				verticalAlignment: TextInput.AlignVCenter
				clip: true

				onTextChanged: root.searchQuery = text

				Text {
				    anchors.verticalCenter: parent.verticalCenter
				    text: "run..."
				    font: parent.font
				    color: Colors.colBrightBlack
				    visible: parent.text.length === 0
				}

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
				    } else if (event.text.length > 0 || event.key === Qt.Key_Backspace) {
					// typing tick; doesn't set accepted, so the character still gets typed
					typeSfx.play();
				    }
				}
			    }
			}
		    }
		}

		// ── App list ───────────────────────────────────────────────────
		Item {
		    Layout.fillWidth: true
		    Layout.fillHeight: true

		    ListView {
			id: listView
			anchors.fill: parent
			model: root.filteredApps
			clip: true
			interactive: false

			delegate: Item {
			    id: appRow
			    width: listView.width
			    height: root.itemH

			    opacity: index < root.revealRows ? 1 : 0

			    readonly property bool sel: root.selectedIndex === index
			    readonly property bool hovered: rowMouse.containsMouse
			    readonly property bool isRecent: !root.isSearching
			    && AppLauncherState.recentIds.indexOf(modelData.id) !== -1
			    && AppLauncherState.recentIds.indexOf(modelData.id) < 5

			    Rectangle {
				anchors.fill: parent
				radius: 0

				color: appRow.sel ? Colors.colCyan
				: appRow.hovered ? Qt.alpha(Colors.colCyan, 0.15)
				: "transparent"

				RowLayout {
				    anchors.fill: parent
				    anchors.leftMargin: 10
				    anchors.rightMargin: 14
				    spacing: 8

				    Text {
					text: appRow.sel ? ">" : " "
					color: Colors.colBg
					font.pixelSize: 12
					font.family: root.fontFamily
					font.bold: true
				    }

				    Image {
					Layout.preferredWidth: 24
					Layout.preferredHeight: 24
					source: modelData.icon !== "" ? "image://icon/" + modelData.icon : ""
					smooth: false
					mipmap: false
				    }

				    Text {
					text: modelData.name
					font.pixelSize: 12
					font.family: root.fontFamily
					font.bold: appRow.sel
					color: appRow.sel ? Colors.colBg : Colors.colFg
				    }

				    // recent tag
				    Rectangle {
					visible: appRow.isRecent
					Layout.preferredWidth: 32
					Layout.preferredHeight: 16
					color: appRow.sel ? Colors.colBg : Qt.alpha(Colors.colCyan, 0.15)

					Text {
					    anchors.centerIn: parent
					    text: "REC"
					    font.family: root.fontFamily
					    font.pixelSize: 9
					    font.bold: true
					    color: Colors.colCyan
					}
				    }

				    Text {
					Layout.fillWidth: true
					visible: modelData.genericName !== ""
					text: modelData.genericName
					elide: Text.ElideRight
					font.pixelSize: 11
					font.family: root.fontFamily
					color: appRow.sel ? Colors.colBg : Colors.colBrightBlack
				    }

				    Item {
					Layout.fillWidth: modelData.genericName === ""
				    }
				}

				MouseArea {
				    id: rowMouse
				    anchors.fill: parent
				    hoverEnabled: true
				    cursorShape: Qt.PointingHandCursor
				    onClicked: function (event) {
					root.launchEntry(modelData);
				    }
				}
			    }
			}
		    }

		    Text {
			anchors.centerIn: parent
			visible: root.filteredApps.length === 0
			text: "-- no matching executables --"
			color: Colors.colBrightBlack
			font.pixelSize: 12
			font.family: root.fontFamily
		    }
		}

		// ── Footer ─────────────────────────────────────────────────────
		Item {
		    Layout.fillWidth: true
		    Layout.preferredHeight: root.footerH

		    Rectangle {
			anchors.top: parent.top
			width: parent.width
			height: 1
			color: root.dim
		    }

		    Row {
			anchors.verticalCenter: parent.verticalCenter
			anchors.left: parent.left
			anchors.leftMargin: 10
			spacing: 12

			Repeater {
			    model: [
				{ k: "↑↓",  d: "nav" },
				{ k: "⏎",   d: "launch" },
				{ k: "ESC", d: "quit" }
			    ]

			    Row {
				spacing: 5

				Rectangle {
				    width: keyText.implicitWidth + 8
				    height: keyText.implicitHeight + 2
				    color: Colors.colCyan

				    Text {
					id: keyText
					anchors.centerIn: parent
					text: modelData.k
					font.family: root.fontFamily
					font.pixelSize: 10
					font.bold: true
					color: Colors.colBg
				    }
				}

				Text {
				    anchors.verticalCenter: parent.verticalCenter
				    text: modelData.d
				    font.family: root.fontFamily
				    font.pixelSize: 10
				    color: Colors.colBrightBlack
				}
			    }
			}
		    }
		}
	    }
	    CornerBrackets {}
	}
    }
}
