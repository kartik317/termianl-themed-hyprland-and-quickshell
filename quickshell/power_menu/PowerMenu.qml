import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../theme"
import "../setting_menu"

PanelWindow {
    id: root

    property var screen

    WlrLayershell.namespace: "powermenu"

    // ── Style ────────────────────────────────────────────────────────────────
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property color dim: Qt.alpha(Colors.colCyan, 0.35)
    readonly property color danger: "#e06c75"

    // ── Keyboard selection state ─────────────────────────────────────────────
    property int selectedIndex: -1
    readonly property int buttonCount: 5
    readonly property int itemH: 36
    readonly property int cardW: 240
    readonly property int titleH: 34
    readonly property int footerH: 28

    function activateSelected() {
	switch (selectedIndex) {
	    case 0: runAndClose(procLock); break;
	    case 1: runAndClose(procSuspend); break;
	    case 2: runAndClose(procHibernate); break;
	    case 3: runAndClose(procReboot); break;
	    case 4: runAndClose(procShutdown); break;
	}
    }

    // ── Animation state ──────────────────────────────────────────────────────
    // reallyVisible stays true until the close animation finishes
    property bool reallyVisible: false
    property real openW: 0        // 0..1 horizontal expand
    property real openH: 0        // 0..1 vertical expand
    property real flick: 1        // card opacity (glitch flicker)
    property real revealRows: 999 // rows with idx < revealRows are shown (hard step, no fade)

    // ── Sound effects (silent automatically when sound is off) ───────────────
    Sfx {
	id: openSfx
	file: "power_menu/open.wav"
    }
    Sfx {
	id: closeSfx
	file: "power_menu/close.wav"
    }
    Sfx {
	id: navSfx
	file: "power_menu/nav.wav"
    }

    // Reset selection / grab focus / run animations on visibility change
    Connections {
	target: PowerMenuState
	function onPowerVisibleChanged() {
	    if (PowerMenuState.powerVisible) {
		closeSfx.stop();
		openSfx.play();

		closeAnim.stop();
		root.reallyVisible = true;
		powerCard.forceActiveFocus();

		if (Settings.animationsEnabled) {
		    openAnim.restart();
		} else {
		    openAnim.stop();
		    root.openW = 1;
		    root.openH = 1;
		    root.flick = 1;
		    root.revealRows = 999;
		}
	    } else {
		root.selectedIndex = -1;
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

    // ── Open: line grows vertically at the left edge, widens right, flickers,
    //    then rows print one by one ───────────────────────────────────────────
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

	NumberAnimation {
	    target: root
	    property: "openH"
	    to: 1
	    duration: 80
	    easing.type: Easing.OutCubic
	}

	ParallelAnimation {
	    NumberAnimation {
		target: root
		property: "openW"
		to: 1
		duration: 90
		easing.type: Easing.OutQuart
	    }

	    // glitch flicker once it's open
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

	    // rows print one by one, like terminal output
	    SequentialAnimation {
		PauseAnimation {
		    duration: 50
		}
		NumberAnimation {
		    target: root
		    property: "revealRows"
		    to: root.buttonCount + 1
		    duration: 120
		    easing.type: Easing.Linear
		}
	    }
	}

	ScriptAction {
	    script: {
		root.revealRows = 999;
		root.flick = 1;
	    }
	}
    }

    // ── Close: fast reverse, then hide ───────────────────────────────────────
    SequentialAnimation {
	id: closeAnim

	NumberAnimation {
	    target: root
	    property: "openW"
	    to: 0
	    duration: 50
	    easing.type: Easing.InQuart
	}
	NumberAnimation {
	    target: root
	    property: "openH"
	    to: 0
	    duration: 50
	    easing.type: Easing.InCubic
	}
	ScriptAction {
	    script: {
		root.reallyVisible = false;
		root.flick = 1;
	    }
	}
    }

    IpcHandler {
	target: "powermenu"
	function toggle(): void {
	    PowerMenuState.toggle();
	}
    }

    // ── Layer / geometry ─────────────────────────────────────────────────────
    anchors {
	top: true
	bottom: true
	left: true
	right: true
    }

    mask: Region {
	item: PowerMenuState.powerVisible ? maskCover : null
    }

    Item {
	id: maskCover
	anchors.fill: parent
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: PowerMenuState.powerVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── Process runners ──────────────────────────────────────────────────────
    Process { id: procLock; command: ["loginctl", "lock-session"] }
    Process { id: procSuspend; command: ["systemctl", "suspend"] }
    Process { id: procHibernate; command: ["systemctl", "hibernate"] }
    Process { id: procReboot; command: ["systemctl", "reboot"] }
    Process { id: procShutdown; command: ["systemctl", "poweroff"] }

    function runAndClose(proc) {
	PowerMenuState.hide();
	proc.running = true;
    }

    MouseArea {
	anchors.fill: parent
	enabled: PowerMenuState.powerVisible
	onClicked: PowerMenuState.hide()
    }

    // ── Menu card (left edge, vertically centered) ───────────────────────────
    Item {
	id: powerCard
	focus: true
	visible: root.reallyVisible

	anchors.verticalCenter: parent.verticalCenter
	anchors.left: parent.left

	readonly property real fullH: root.titleH + root.buttonCount * root.itemH + root.footerH + 2

	// Scale the whole outer wrapper container
	width: Math.max(2, root.cardW * root.openW)
	height: Math.max(4, fullH * root.openH)

	opacity: root.flick

	Keys.onPressed: function (event) {
	    if (!PowerMenuState.powerVisible) return;
	    if (event.key === Qt.Key_Up) {
		root.selectedIndex = (root.selectedIndex - 1 + root.buttonCount) % root.buttonCount;
		navSfx.play();
		event.accepted = true;
	    } else if (event.key === Qt.Key_Down) {
		root.selectedIndex = (root.selectedIndex + 1) % root.buttonCount;
		navSfx.play();
		event.accepted = true;
	    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
		if (root.selectedIndex >= 0) root.activateSelected();
		event.accepted = true;
	    } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_5) {
		root.selectedIndex = event.key - Qt.Key_1;
		root.activateSelected();
		event.accepted = true;
	    }
	}
	Keys.onEscapePressed: PowerMenuState.hide()

	// 1. Outer Border Container (No clip, draws border safely)
	Rectangle {
	    anchors.fill: parent
	    color: "transparent"
	    border.color: root.dim
	    border.width: 1
	    radius: 0

	    // 2. Inner Content Container (Clips children, has background and padding)
	    Rectangle {
		anchors.fill: parent
		anchors.margins: 1 // Keeps content strictly inside the 1px border so it never overlaps
		color: Qt.alpha(Colors.colBg, 0.88)
		radius: 0
		clip: true

		// Eat clicks so background doesn't dismiss on card clicks
		MouseArea {
		    anchors.fill: parent
		    onClicked: {}
		}

		// Fixed size + anchored top-left, so content is wiped in as the card grows
		ColumnLayout {
		    width: root.cardW - 2
		    height: powerCard.fullH - 2
		    anchors {
			top: parent.top
			left: parent.left
		    }
		    spacing: 0

		    // ── Title bar ────────────────────────────────────────────────────
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
				    text: "POWER"
				    font.family: root.fontFamily
				    font.pixelSize: 11
				    font.bold: true
				    font.letterSpacing: 1
				    color: Colors.colBg
				}
			    }

			    Text {
				text: ("linuxguy") + "@systemd"
				font.family: root.fontFamily
				font.pixelSize: 11
				color: Colors.colBrightBlack
			    }

			    Item {
				Layout.fillWidth: true
			    }
			}

			Rectangle {
			    anchors.bottom: parent.bottom
			    width: parent.width
			    height: 1
			    color: root.dim
			}
		    }

		    // ── Options list ─────────────────────────────────────────────────
		    PowerRow { idx: 0; label: "Lock";      icon: "󰌾"; onActivated: root.runAndClose(procLock) }
		    PowerRow { idx: 1; label: "Suspend";    icon: "󰒲"; onActivated: root.runAndClose(procSuspend) }
		    PowerRow { idx: 2; label: "Hibernate"; icon: "󰋊"; onActivated: root.runAndClose(procHibernate) }
		    PowerRow { idx: 3; label: "Reboot";     icon: "󰜉"; danger: true; onActivated: root.runAndClose(procReboot) }
		    PowerRow { idx: 4; label: "Shutdown";   icon: "󰐥"; danger: true; onActivated: root.runAndClose(procShutdown) }

		    // ── Footer ───────────────────────────────────────────────────────
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
			    spacing: 10

			    Repeater {
				model: [
				    { k: "↑↓",  d: "nav" },
				    { k: "⏎",   d: "run" },
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
	    }
	}

	CornerBrackets {}
    }
    // ── Inner component: one menu row ────────────────────────────────────────
    component PowerRow: Item {
	id: row
	required property int idx
	required property string label
	required property string icon
	property bool danger: false
	signal activated

	readonly property bool sel: root.selectedIndex === idx
	readonly property color accent: danger ? root.danger : Colors.colCyan

	Layout.fillWidth: true
	Layout.preferredHeight: root.itemH

	// hard step reveal (no fade) to match the instant-swap style
	opacity: idx < root.revealRows ? 1 : 0

	// selected = solid block (cyan, or red for destructive actions), instant swap
	Rectangle {
	    anchors.fill: parent
	    radius: 0
	    color: row.sel ? row.accent : "transparent"

	    RowLayout {
		anchors.fill: parent
		anchors.leftMargin: 10
		anchors.rightMargin: 14
		spacing: 10

		// index number, dim
		Text {
		    text: String(row.idx + 1).padStart(2, "0")
		    font.family: root.fontFamily
		    font.pixelSize: 11
		    color: row.sel ? Colors.colBg : Colors.colBrightBlack
		}

		Text {
		    Layout.preferredWidth: 18
		    horizontalAlignment: Text.AlignHCenter
		    text: row.icon
		    font.family: root.fontFamily
		    font.pixelSize: 15
		    color: row.sel ? Colors.colBg : row.accent
		}

		Text {
		    Layout.fillWidth: true
		    text: row.label
		    font.family: root.fontFamily
		    font.pixelSize: 12
		    font.bold: row.sel
		    color: row.sel ? Colors.colBg : Colors.colFg
		}

		Text {
		    text: row.sel ? ">" : ""
		    font.family: root.fontFamily
		    font.pixelSize: 12
		    font.bold: true
		    color: Colors.colBg
		}
	    }

	    MouseArea {
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onEntered: root.selectedIndex = row.idx
		onClicked: row.activated()
	    }
	}
    }
}
