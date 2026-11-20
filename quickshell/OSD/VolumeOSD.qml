import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root
    property var modelData
    screen: modelData

    property int  _lastVol:   -1
    property bool _lastMuted: false
    property bool osdVisible: false
    property int  vol:        0
    property bool muted:      false

    // ── Style ───────────────────────────────────────────────────────────────
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property color danger: "#e06c75"
    readonly property color accent: muted ? danger : Colors.colCyan
    readonly property color line: Qt.alpha(Colors.colCyan, 0.35)

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "qs-vol-osd-noanim"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: 0

    anchors.bottom: true
    anchors.left:   true
    anchors.right:  true
    implicitHeight: 100

    mask: Region {
	item: root.osdVisible ? maskCover : null
    }
    Item {
	id: maskCover
	anchors.fill: parent
    }

    color: "transparent"

    // ── Auto-hide ───────────────────────────────────────────────────────────
    Timer {
	id: hideTimer
	interval: 2000
	onTriggered: root.osdVisible = false
    }

    // ── Watchdog: revive pactl if it dies ──────────────────────────────────
    Timer {
	id: pactlRestartTimer
	interval: 1500
	onTriggered: {
	    if (!pactlSub.running)
	    pactlSub.running = true
	}
    }

    // ── PipeWire event watcher (long-lived) ────────────────────────────────
    Process {
	id: pactlSub
	command: ["pactl", "subscribe"]
	running: true
	onRunningChanged: {
	    if (!running) pactlRestartTimer.start()
	}
	stdout: SplitParser {
	    onRead: data => {
		if (data.includes("change") && data.includes("sink") && !volQuery.running)
		volQuery.running = true
	    }
	}
    }

    // ── Volume query (short-lived, re-run on each event) ───────────────────
    Process {
	id: volQuery
	command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
	stdout: SplitParser {
	    onRead: data => {
		const newMuted = data.includes("[MUTED]")
		const m        = data.match(/([\d.]+)/)
		if (!m) return
		const newVol = Math.round(parseFloat(m[1]) * 100)
		const volChanged   = newVol   !== root._lastVol
		const muteChanged  = newMuted !== root._lastMuted
		root._lastVol   = newVol
		root._lastMuted = newMuted
		root.vol = newVol
		root.muted = newMuted
		if (volChanged || muteChanged) {
		    root.osdVisible = true
		    hideTimer.restart()
		}
	    }
	}
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  OSD card: instant show/hide, no slide/fade
    // ═══════════════════════════════════════════════════════════════════════
    Rectangle {
	id: osdCard
	width:  440
	height: 52
	anchors.horizontalCenter: parent.horizontalCenter
	anchors.bottom:           parent.bottom
	anchors.bottomMargin:     22

	visible: root.osdVisible

	radius: 0
	color: Qt.alpha(Colors.colBg, 0.88)
	border.color: root.line
	border.width: 1

	RowLayout {
	    anchors {
		fill: parent
		leftMargin: 12
		rightMargin: 12
	    }
	    spacing: 10

	    // speaker icon, fixed width so the meter doesn't shift
	    Text {
		Layout.preferredWidth: 20
		horizontalAlignment: Text.AlignHCenter
		text: root.muted    ? "\uf026"
		: root.vol > 60 ? "\uf028"
		: root.vol > 0  ? "\uf027"
		:                 "\uf026"
		font.pixelSize: 16
		font.family:    root.fontFamily
		color: root.accent
	    }

	    // blocky inverted tag (red when muted)
	    Rectangle {
		implicitWidth: tagText.implicitWidth + 14
		implicitHeight: tagText.implicitHeight + 4
		color: root.accent

		Text {
		    id: tagText
		    anchors.centerIn: parent
		    text: "VOL"
		    font.family: root.fontFamily
		    font.pixelSize: 11
		    font.bold: true
		    font.letterSpacing: 1
		    color: Colors.colBg
		}
	    }

	    // ── Segmented volume meter ──────────────────────────────────────
	    Row {
		id: meter
		Layout.fillWidth: true
		Layout.preferredHeight: 12
		spacing: 3

		readonly property int segments: 20
		readonly property int filledSegments: Math.round(Math.min(root.vol / 100.0, 1.0) * segments)

		// Calculate exact width for each square based on total available width minus total spacing
		readonly property real availableWidth: width - (spacing * (segments - 1))
		readonly property real segmentWidth: Math.floor(availableWidth / segments)

		Repeater {
		    model: meter.segments
		    delegate: Rectangle {
			width: meter.segmentWidth
			height: 12
			radius: 0
			color: index < meter.filledSegments
			? root.accent
			: Qt.alpha(Colors.colCyan, 0.12)
		    }
		}
	    }
	    // value, zero-padded so the width never changes: 005%, 042%, 100%
	    Text {
		Layout.preferredWidth: 44
		horizontalAlignment: Text.AlignRight
		text: root.muted ? "MUTE" : String(root.vol).padStart(3, "0") + "%"
		font.pixelSize: 12
		font.family: root.fontFamily
		font.bold: true
		color: root.muted ? root.danger : Colors.colFg
	    }
	}

	// last child so it draws on top of the content
	CornerBrackets {
	    color: root.accent
	}
    }
}
