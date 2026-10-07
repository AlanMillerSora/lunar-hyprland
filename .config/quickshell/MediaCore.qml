pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// ════════════════════════════════════════════════════════════════
//  MediaCore — один источник медиа для панели бара (режим media).
//  Свести наш mpv (MPRIS org.mpris.MediaPlayer2.mpv) и чужие плееры
//  в одно место: выбор активного, трек, прогресс с локальным тиком,
//  shuffle/repeat и очередь «далее».
//  Позицию MPRIS отдаёт редко, поэтому тикаю сам и синхронизируюсь
//  по positionChanged — иначе полоса «прыгает».
// ════════════════════════════════════════════════════════════════
QtObject {
    id: mc

    // наш mpv узнаю по имени: identity/desktopEntry начинаются с «mpv»
    function isMpvPlayer(p) {
        if (!p)
            return false
        var names = [p.identity || "", p.desktopEntry || "", p.dbusName || ""]
        for (var i = 0; i < names.length; i++)
            if (names[i].toLowerCase().indexOf("mpv") === 0)
                return true
        return false
    }

    // активный плеер: сперва играющий наш mpv, иначе любой играющий,
    // лишь в последнюю очередь — первый из списка
    readonly property var player: {
        var ps = Mpris.players.values
        var playingAny = null
        for (var i = 0; i < ps.length; i++) {
            if (!ps[i].isPlaying) {
                if (playingAny === null && ps[i].trackTitle)
                    playingAny = ps[i]
                continue
            }
            if (mc.isMpvPlayer(ps[i]))
                return ps[i]
            if (playingAny === null)
                playingAny = ps[i]
        }
        if (playingAny !== null)
            return playingAny
        return ps.length > 0 ? ps[0] : null
    }

    readonly property bool has: player !== null
    readonly property bool playing: player !== null && player.isPlaying
    readonly property string title: player && player.trackTitle ? player.trackTitle : ""
    readonly property string artist: player && player.trackArtist ? player.trackArtist : ""
    readonly property string album: player && player.trackAlbum ? player.trackAlbum : ""
    readonly property string art: player && player.trackArtUrl ? player.trackArtUrl : ""
    readonly property real len: (player && player.length) ? player.length : 0
    // писать position можно только если canSeek И positionSupported;
    // length нужен валидный (lengthSupported) — иначе полоса бессмысленна
    readonly property bool seekable: player !== null && player.canSeek === true
        && player.positionSupported === true && player.lengthSupported === true && len > 0
    readonly property bool shuffleSupported: player !== null && player.canControl === true
        && player.shuffleSupported === true
    readonly property bool shuffle: player !== null && player.shuffle === true
    readonly property bool loopSupported: player !== null && player.canControl === true
        && player.loopSupported === true
    // 0 = выкл, 1 = трек, 2 = плейлист (MprisLoopState)
    readonly property int loopState: player !== null ? player.loopState : 0

    // ── локальный тик позиции ──
    property real shownPos: 0
    readonly property real pos: shownPos
    readonly property real progress: len > 0 ? Math.min(1, pos / len) : 0

    function syncPos() {
        mc.shownPos = (mc.player && mc.player.position) ? mc.player.position : 0
    }
    onPlayerChanged: {
        syncPos()
        posTimer.restart()
    }
    Component.onCompleted: syncPos()

    property Timer posTimer: Timer {
        interval: 500
        running: mc.playing && mc.seekable
        repeat: true
        onTriggered: mc.shownPos = Math.min(mc.len, mc.shownPos + 0.5)
    }

    property Connections posConn: Connections {
        target: mc.player
        function onPositionChanged() { mc.syncPos() }
        function onTrackChanged() { mc.syncPos() }
    }

    function fmt(s) {
        if (!s || s < 0 || !isFinite(s))
            s = 0
        var m = Math.floor(s / 60)
        var sec = Math.floor(s % 60)
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }

    function seekTo(sec) {
        if (!mc.seekable || !mc.player || mc.len <= 0)
            return
        var t = Math.max(0, Math.min(mc.len, sec))
        if (mc.player.positionSupported) {
            mc.player.position = t
        } else {
            // фолбэк: относительный seek от текущей позиции
            mc.player.seek(t - (mc.player.position || 0))
        }
        mc.shownPos = t
    }

    function seekFrac(frac) {
        mc.seekTo(Math.max(0, Math.min(1, frac)) * mc.len)
    }

    function toggleShuffle() {
        if (mc.player && mc.shuffleSupported)
            mc.player.shuffle = !mc.player.shuffle
    }

    // цикл по кругу: выкл → все → один
    function cycleLoop() {
        if (!mc.player || !mc.loopSupported)
            return
        var s = mc.loopState
        mc.player.loopState = (s === 0) ? 2 : (s === 2 ? 1 : 0)
    }

    // Очередь у MPRIS недоступна: интерфейсы TrackList/Playlist в
    // Quickshell 0.3.1 не реализованы (свойство trackList у MprisPlayer
    // отсутствует). Поэтому в панели показываю не «ДАЛЕЕ», а вход в
    // терминальный плеер (Lunar TUI).
    readonly property bool queueAvailable: false
}
