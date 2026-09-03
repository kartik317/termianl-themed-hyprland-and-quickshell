pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property var activePlayer: null

    property var manualPlayer: null   // user-selected player, null = auto

    function pickPlayer() {
	if (manualPlayer && players.indexOf(manualPlayer) !== -1) {
	    return manualPlayer;
	}
	if (manualPlayer && players.indexOf(manualPlayer) === -1) {
	    manualPlayer = null; // it closed, fall back to auto
	}
	for (let i = 0; i < players.length; i++) {
	    if (players[i].playbackState === MprisPlaybackState.Playing)
	    return players[i];
	}
	return players.length > 0 ? players[0] : null;
    }

    function cyclePlayer() {
	if (players.length === 0) return;
	const current = activePlayer;
	const idx = players.indexOf(current);
	const next = players[(idx + 1) % players.length];
	manualPlayer = next;
	activePlayer = next;
    }

    function playerName(player) {
	if (!player) return "";
	return player.identity && player.identity.length > 0
	? player.identity
	: (player.dbusName ?? "Unknown");
    }

    onPlayersChanged: activePlayer = pickPlayer()
    Component.onCompleted: activePlayer = pickPlayer()

    readonly property bool hasPlayer: activePlayer !== null
    readonly property string title: activePlayer?.metadata?.["xesam:title"] ?? "No media playing"
    readonly property string artist: activePlayer?.metadata?.["xesam:artist"]?.join(", ") ?? ""
    readonly property string artUrl: activePlayer?.metadata?.["mpris:artUrl"] ?? ""
    readonly property bool isPlaying: activePlayer?.playbackState === MprisPlaybackState.Playing
    readonly property bool canGoNext: activePlayer?.canGoNext ?? false
    readonly property bool canGoPrevious: activePlayer?.canGoPrevious ?? false
    readonly property bool shuffleOn: activePlayer?.shuffle ?? false

    readonly property int loopStatus: activePlayer?.loopState ?? MprisLoopState.None

    function togglePlaying() {
	if (activePlayer) activePlayer.togglePlaying();
    }

    function next() {
	if (activePlayer && activePlayer.canGoNext) activePlayer.next();
    }

    function previous() {
	if (activePlayer && activePlayer.canGoPrevious) activePlayer.previous();
    }

    function toggleShuffle() {
	if (activePlayer) activePlayer.shuffle = !activePlayer.shuffle;
    }

    function cycleLoop() {
	if (!activePlayer) return;

	if (activePlayer.loopState === MprisLoopState.None) {
	    activePlayer.loopState = MprisLoopState.Track;
	} else if (activePlayer.loopState === MprisLoopState.Track) {
	    activePlayer.loopState = MprisLoopState.Playlist;
	} else {
	    activePlayer.loopState = MprisLoopState.None;
	}
    }

    // Lets you drive this from hyprland keybinds via `qs ipc call`
    IpcHandler {
	target: "media"
	function playPause() { root.togglePlaying(); }
	function next() { root.next(); }
	function previous() { root.previous(); }
	function shuffle() { root.toggleShuffle(); }
	function loop() { root.cycleLoop(); }
	function changePlayer() { root.cyclePlayer(); }
    }
}
