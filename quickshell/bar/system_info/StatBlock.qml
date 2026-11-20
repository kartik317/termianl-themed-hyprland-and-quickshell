import QtQuick
import QtQuick.Layouts
import "../../theme"

Item {
    id: block

    property string label
    property real value: 0
    property string suffix: "%"
    property real warnAt: 80          // value at which the block turns red
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14

    readonly property bool warn: value >= warnAt
    readonly property color accent: warn ? "#e06c75" : Colors.colCyan

    implicitWidth: row.implicitWidth
    implicitHeight: 30

    // Reserves width for two digits so the layout never shifts
    TextMetrics {
	id: widest
	font.family: block.fontFamily
	font.pixelSize: block.fontSize
	font.bold: true
	text: "99" + block.suffix
    }

    RowLayout {
	id: row
	anchors.verticalCenter: parent.verticalCenter
	anchors.verticalCenterOffset: -2
	spacing: 6

	// Blocky status tag (inverted)
	Rectangle {
	    implicitWidth: tag.implicitWidth + 10
	    implicitHeight: tag.implicitHeight + 2
	    color: block.accent

	    Text {
		id: tag
		anchors.centerIn: parent
		text: block.label
		font.family: block.fontFamily
		font.pixelSize: block.fontSize - 2
		font.bold: true
		color: Colors.colBg
	    }
	}

	Text {
	    Layout.preferredWidth: widest.width
	    horizontalAlignment: Text.AlignLeft
	    // Zero-padded and capped at 99 so it's always two digits: 05%, 42%, 99%
	    text: String(Math.min(99, Math.round(block.value))).padStart(2, "0") + block.suffix
	    font.family: block.fontFamily
	    font.pixelSize: block.fontSize
	    font.bold: true
	    color: block.warn ? block.accent : Colors.colFg
	}
    }

    // Level bar along the bottom: dim track, solid fill
    Rectangle {
	anchors.left: parent.left
	anchors.right: parent.right
	anchors.bottom: parent.bottom
	height: 2
	color: Qt.alpha(Colors.colCyan, 0.2)

	Rectangle {
	    height: parent.height
	    width: parent.width * Math.max(0, Math.min(block.value, 100)) / 100
	    color: block.accent
	}
    }
}
