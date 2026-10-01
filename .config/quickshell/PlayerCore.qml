pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ════════════════════════════════════════════════════════════════
//  PlayerCore — бэкенд моего плеера Lunar Player.
//  Говорю с mpv напрямую по JSON IPC (--input-ipc-server), потому что
//  MPRIS не отдаёт очередь и правку плейлиста (см. player-research.md).
//  yt-dlp ищу тут же, плеер поднимаю юнитом lunar-player.service.
//
//  Главная боль 0.3.1 — issue #1180: неудачный ПЕРВЫЙ коннект навсегда
//  застревает, спасает только пересоздание Socket. Поэтому Socket не
//  создаю, пока файла сокета нет: держу test -S, а сам объект живу в
//  LazyLoader и пересоздаю его при обрыве. Свой таймер позиции не пложу —
//  слушаю time-pos.
// ════════════════════════════════════════════════════════════════
QtObject {
    id: root

    // путь сокета должен совпадать с юнитом: lunar-player.sock
    readonly property string sockPath: Quickshell.env("XDG_RUNTIME_DIR") + "/lunar-player.sock"

    // ── наружу (это ждёт UI) ──
    property bool ready: false        // файл сокета существует
    property bool connected: false    // по умолчанию false и только явно
    property string title: ""
    property string artist: ""
    property string artUrl: ""        // mpv не отдаёт обложку по IPC, поле для UI
    property string artKey: ""        // трек, для которого artUrl уже решён (не спамить пробами)
    property real length: 0
    property real position: 0
    property bool playing: false
    property bool paused: true        // отдельно от playing: играю = есть медиа, не пауза и не idle
    property bool hasMedia: false
    property bool seekable: false
    property bool shuffle: false
    property real volume: 100       // громкость mpv, 0..100
    property bool muted: false
    property var queue: []            // [{id,title,duration,filename,current}]
    property int queueIndex: -1       // playlist-pos, -1 = ничего не играет
    property string error: ""         // ошибки воспроизведения
    property string searchError: ""   // отдельно: «ничего не нашлось» и т.п.
    property bool searching: false
    property var searchResults: []    // [{id,title,duration,uploader,url}]
    property bool libraryBusy: false
    property var library: []          // [{path,name}]
    property var pendingLibrary: []   // коплю список тут, отдаю один раз при выходе find

    // ── внутреннее состояние ──
    property bool sockWanted: false   // хочу ли держать Socket (файл есть)
    property int reqSeq: 0            // request_id, чтобы mpv отвечал адресно
    property var pendingUrls: []      // что нажали запустить до коннекта
    property var durationMap: ({})    // id -> длительность (mpv её в playlist не кладёт)
    property var titleMap: ({})       // url -> название (из поиска), иначе в очереди будет URL
    property var rawPlaylist: []      // сырое событие playlist от mpv — пересобираю очередь из него
    property int queueCount: 0
    property bool idleActive: false
    property bool eofReached: false
    property bool endedPending: false // был end-file eof, жду чистого idle
    property string lastEndReason: ""

    // ═══════════════ сокет: test -S → LazyLoader → отложенный connected ═══════════════

    // 1) раз в секунду проверяю, есть ли файл сокета
    property Process probeProc: Process {
        command: ["test", "-S", root.sockPath]
        onExited: (code, st) => root.onProbe(code === 0)
    }

    property Timer probeTimer: Timer {
        interval: 1000
        // пробу держу только когда она нужна: файл есть (следить за обрывом),
        // плеер открыт или есть отложенный запуск. Иначе не плодим `test -S`.
        running: root.ready || Theme.playerOpen || root.pendingUrls.length > 0
        repeat: true
        onTriggered: {
            // перезапускаю пробу: так узнаю и о появлении, и об исчезновении
            root.probeProc.running = false
            root.probeProc.running = true
            // самолечение: файл есть, а соединения нет — поднимаю Socket заново
            // (после обрыва sockWanted снимается, и без этого он не вернётся)
            if (root.ready && !root.connected)
                root.sockWanted = true
        }
    }

    // 2) Socket рождается только когда файл уже лежит — иначе ловлю #1180.
    //    При обрыве активность снимается и объект пересоздаётся с нуля.
    property LazyLoader sockLoader: LazyLoader {
        active: root.ready && root.sockWanted
        component: Component {
            Socket {
                path: root.sockPath
                parser: SplitParser {
                    onRead: (line) => root.onMpvLine(line)
                }
                // у connected notify назван connectionStateChanged — слушаю его
                onConnectionStateChanged: root.onConnChanged(connected)
                onError: (err) => root.onSockError(err)
            }
        }
        onItemChanged: root.connectTimer.restart()
    }

    // 3) connected ставлю явно и чуть погодя, когда объект уже с path
    property Timer connectTimer: Timer {
        interval: 120
        onTriggered: {
            var it = root.sockLoader.item
            if (it && !it.connected)
                it.connected = true
        }
    }

    // после обрыва даю чуть времени и пересоздаю объект (лечение #1180)
    property Timer recreateTimer: Timer {
        interval: 500
        onTriggered: {
            if (root.ready && !root.connected)
                root.sockWanted = true
        }
    }

    // подписки шлю отдельным тиком — соединение уже точно поднято
    property Timer subscribeTimer: Timer {
        interval: 60
        onTriggered: {
            if (!root.connected)
                return
            root.subscribeAll()
            root.flushPending()
        }
    }

    function onProbe(isSock) {
        if (isSock) {
            // файл на месте: держу Socket живым. Здесь НЕ выхожу по «ready уже true»:
            // после обрыва sockWanted мог остаться снятым, и тогда связи не будет
            ready = true
            sockWanted = true
            return
        }
        if (!ready && !sockWanted)
            return
        // плеер ушёл — сношу Socket и затираю всё «живое», иначе в UI
        // остаётся последний трек с недостоверными позицией/очередью
        ready = false
        sockWanted = false
        connected = false
        playing = false
        paused = true
        position = 0
        length = 0
        title = ""
        artist = ""
        artUrl = ""
        artKey = ""
        coverProc.running = false
        hasMedia = false
        seekable = false
        idleActive = false
        endedPending = false
        eofReached = false
        queue = []
        queueIndex = -1
        queueCount = 0
        rawPlaylist = []
        volume = 100
        muted = false
        titleMap = ({})
        durationMap = ({})
        error = ""
        searchError = ""
    }

    function onConnChanged(c) {
        connected = c
        if (c) {
            error = ""
            subscribeTimer.restart()
        } else if (sockWanted) {
            // обрыв при живом файле — сам сокет не переподключится
            scheduleRecreate()
        }
    }

    function onSockError(e) {
        // ServerNotFound/PeerClosed и прочее: объект застревает, поэтому
        // не чиню его, а выбрасываю и создаю заново
        if (sockWanted)
            scheduleRecreate()
    }

    function scheduleRecreate() {
        sockWanted = false
        connected = false
        recreateTimer.restart()
    }

    // ═══════════════ запись в mpv ═══════════════

    // единственная точка, где рождается JSON: кавычки и переводы строк
    // экранирует stringify — конкатенацией это ломается
    function writeCmd(cmd) {
        var it = sockLoader.item
        if (!it || !connected)
            return false
        it.write(JSON.stringify({ command: cmd, request_id: ++reqSeq }) + "\n")
        return true
    }

    // команда, которая не теряется молча: нет связи — поднимаю демон и выхожу
    function cmd(args) {
        if (connected)
            return writeCmd(args)
        ensurePlayer()
        return false
    }

    // после коннекта сначала подписки, и только потом команды
    function subscribeAll() {
        observe("pause", 1)
        observe("time-pos", 2)
        observe("duration", 3)
        observe("media-title", 4)
        observe("metadata", 5)
        observe("playlist", 6)
        observe("playlist-pos", 7)
        observe("playlist-count", 8)
        observe("eof-reached", 9)
        observe("idle-active", 10)
        observe("shuffle", 11)
        observe("volume", 12)
        observe("mute", 13)
    }

    function observe(name, id) {
        writeCmd(["observe_property", id, name])
    }

    // ═══════════════ разбор входящего ═══════════════

    function onMpvLine(line) {
        if (!line)
            return
        var msg
        try {
            msg = JSON.parse(line)
        } catch (e) {
            return
        }
        if (msg.event === "property-change")
            handleProperty(msg.name, msg.data)
        else if (msg.event === "end-file")
            handleEndFile(msg)
        else if (msg.event === "start-file") {
            endedPending = false
            error = "" // новый файл грузится — старая ошибка больше не актуальна
        }
    }

    function handleProperty(name, data) {
        if (name === "pause") {
            // pause=true значит «на паузе»; «играю» считаю из этого в refreshDerived
            paused = (data === true)
        } else if (name === "time-pos") {
            position = (data === null || data === undefined) ? 0 : Number(data)
        } else if (name === "duration") {
            length = (data === null || data === undefined) ? 0 : Number(data)
            rememberDuration()
        } else if (name === "media-title") {
            title = (data === null || data === undefined) ? "" : String(data)
            rememberTitle()
        } else if (name === "metadata") {
            artist = pickArtist(data)
        } else if (name === "playlist") {
            buildQueue(data)
        } else if (name === "playlist-pos") {
            queueIndex = (data === null || data === undefined) ? -1 : Number(data)
            updateArt()
        } else if (name === "playlist-count") {
            queueCount = (data === null || data === undefined) ? 0 : Number(data)
        } else if (name === "eof-reached") {
            eofReached = (data === true)
        } else if (name === "idle-active") {
            idleActive = (data === true)
            if (idleActive) {
                playing = false
                position = 0
            }
        } else if (name === "shuffle") {
            shuffle = (data === true)
        } else if (name === "volume") {
            volume = (data === null || data === undefined) ? 0 : Number(data)
        } else if (name === "mute") {
            muted = (data === true)
        }
        refreshDerived()
    }

    // end-file нужен ради причины: eof — доиграл, error — не загрузка.
    // «Очередь кончилась» считаю сам: eof + idle-active + playlist-pos == -1.
    function handleEndFile(msg) {
        lastEndReason = msg.reason ? String(msg.reason) : ""
        if (msg.reason === "error")
            error = msg.file_error ? String(msg.file_error) : "не удалось загрузить файл"
        if (msg.reason === "eof")
            endedPending = true
    }

    // ═══════════════ очередь ═══════════════

    function buildQueue(data) {
        if (data && data.length !== undefined)
            rawPlaylist = data
        data = rawPlaylist
        var out = []
        if (data && data.length !== undefined) {
            for (var i = 0; i < data.length; i++) {
                var e = data[i] || {}
                var id = (e.id === undefined || e.id === null) ? 0 : Number(e.id)
                var fn = e.filename ? String(e.filename) : ""
                var d = durationMap[id]
                out.push({
                    id: id,
                    title: e.title ? String(e.title)
                         : (root.titleMap[fn] ? String(root.titleMap[fn]) : labelFor(fn)),
                    duration: (d === undefined || d === null) ? 0 : d,
                    filename: fn,
                    current: e.current === true
                })
            }
        }
        queue = out
        refreshDerived()
        updateArt()
    }

    // обложка: у ссылок YouTube беру превью по id (mpv картинку по IPC не отдаёт)
    function youtubeArt(url) {
        var m = /(?:v=|youtu\.be\/|\/shorts\/)([A-Za-z0-9_-]{11})/.exec(String(url))
        return (m && m[1].length === 11) ? "https://i.ytimg.com/vi/" + m[1] + "/mqdefault.jpg" : ""
    }

    function updateArt() {
        var fn = (queueIndex >= 0 && queueIndex < queue.length)
            ? String(queue[queueIndex].filename)
            : ""
        var yt = youtubeArt(fn)
        if (yt !== "") {
            artKey = fn
            coverProc.running = false
            artUrl = yt
            return
        }
        // этим треком уже занимался — повторно пробу не гоняю
        if (fn === artKey)
            return
        artKey = fn
        coverProc.running = false
        artUrl = ""
        // локальный трек — только абсолютный путь; ссылки (http/https) отсекаю
        if (fn === "" || fn.charAt(0) !== "/")
            return
        var slash = fn.lastIndexOf("/")
        if (slash <= 0)
            return
        var dir = fn.substring(0, slash + 1)
        // одна проба на смену трека: bash перебирает кандидатов через test -f,
        // пути передаю argv, без склейки в шелл
        coverProc.command = ["bash", "-c",
            "for f in \"$@\"; do if test -f \"$f\"; then printf '%s' \"$f\"; break; fi; done",
            "--", dir + "cover.jpg", dir + "cover.png", dir + "folder.jpg"]
        coverProc.running = true
    }

    // обложка локального файла: одна проба на смену трека, не на каждый тик
    property Process coverProc: Process {
        command: []
        stdout: StdioCollector {
            id: coverOut
            onStreamFinished: root.applyLocalCover(coverOut.text)
        }
        stderr: StdioCollector {}
    }

    function applyLocalCover(text) {
        var p = (text === undefined || text === null) ? "" : String(text).trim()
        if (p === "")
            return
        // старая проба могла доехать после смены трека — беру только свою папку
        var fn = artKey
        var slash = fn.lastIndexOf("/")
        if (slash <= 0)
            return
        if (p.indexOf(fn.substring(0, slash + 1)) !== 0)
            return
        artUrl = fileUrl(p)
    }

    // file:// с процентным кодированием: пробелы/решётки в пути не ломают Image
    function fileUrl(path) {
        var parts = String(path).split("/")
        for (var i = 0; i < parts.length; i++)
            parts[i] = encodeURIComponent(parts[i])
        return "file://" + parts.join("/")
    }

    // у mpv в очереди нет заголовков — запоминаю текущий по ссылке и
    // пересобираю список, чтобы вместо URL был человеческий трек
    function rememberTitle() {
        if (!title || queueIndex < 0 || queueIndex >= queue.length)
            return
        var fn = queue[queueIndex].filename
        if (!fn || titleMap[fn] === title)
            return
        var tm = titleMap
        tm[fn] = title
        titleMap = tm
        rebuildQueue()
    }

    function rebuildQueue() { buildQueue(rawPlaylist) }

    // mpv кладёт duration только у играющего — запоминаю по id
    function rememberDuration() {
        if (queueIndex < 0 || queueIndex >= queue.length)
            return
        var id = queue[queueIndex].id
        if (!id)
            return
        var m = durationMap
        m[id] = length
        durationMap = m
        var q = queue.slice()
        q[queueIndex] = {
            id: q[queueIndex].id,
            title: q[queueIndex].title,
            duration: length,
            filename: q[queueIndex].filename,
            current: q[queueIndex].current
        }
        queue = q
    }

    function refreshDerived() {
        hasMedia = queueIndex >= 0 && queue.length > 0
        // «играю» = есть медиа, не на паузе и не idle — так не мигает при коннекте
        playing = hasMedia && !paused && !idleActive
        seekable = hasMedia && length > 0 && !idleActive
        // связка «доиграли и ушли в idle» — вот это и есть конец очереди
        if (endedPending && idleActive && queueIndex === -1) {
            endedPending = false
            position = 0
            hasMedia = false
            seekable = false
            playing = false
        }
    }

    // ═══════════════ запуск и загрузка ═══════════════

    // юнит поднимает mpv с --idle и этим же сокетом; сокета нет — стартую
    property Process ensureProc: Process {
        command: ["systemctl", "--user", "--no-block", "start", "lunar-player.service"]
        stderr: StdioCollector {}
    }

    function ensurePlayer() {
        if (ready)
            return
        ensureProc.running = false
        ensureProc.running = true
    }

    property Process stopProc: Process {
        command: ["systemctl", "--user", "--no-block", "stop", "lunar-player.service"]
        stderr: StdioCollector {}
    }

    // гашу демон, когда он больше не нужен: плеер закрыт, ничего не играет и
    // очередь пуста. Иначе mpv висел бы до перезагрузки (это заметил аудит).
    function maybeStopDaemon() {
        if (!Theme.playerOpen && !playing && queue.length === 0 && ready) {
            stopProc.running = false
            stopProc.running = true
        }
    }

    function normUrls(urls) {
        if (urls === undefined || urls === null)
            return []
        if (typeof urls === "string")
            return urls.length > 0 ? [urls] : []
        if (urls.length === undefined)
            return []
        var out = []
        for (var i = 0; i < urls.length; i++) {
            var u = String(urls[i])
            if (u.length > 0)
                out.push(u)
        }
        return out
    }

    // флаги только 0.41: replace|append|append-play|insert-next (без append+play)
    function playUrls(urls) {
        var list = normUrls(urls)
        if (list.length === 0)
            return
        if (!connected) {
            pendingUrls = list
            ensurePlayer()
            return
        }
        sendLoad(list, false)
    }

    function enqueue(urls) {
        var list = normUrls(urls)
        if (list.length === 0)
            return
        if (!connected) {
            pendingUrls = pendingUrls.concat(list)
            ensurePlayer()
            return
        }
        sendLoad(list, true)
    }

    function sendLoad(list, enq) {
        for (var i = 0; i < list.length; i++) {
            var flag = enq ? "append-play" : (i === 0 ? "replace" : "append")
            writeCmd(["loadfile", String(list[i]), flag])
        }
    }

    function flushPending() {
        if (pendingUrls.length === 0)
            return
        var list = pendingUrls
        pendingUrls = []
        sendLoad(list, false)
    }

    // ═══════════════ управление воспроизведением ═══════════════

    function toggle() {
        if (!connected) {
            ensurePlayer()
            return
        }
        // «cycle pause» переключает паузу силами самого mpv: не завишу от
        // того, насколько свежо успел приехать observe-статус (иначе кнопка
        // могла слать уже актуальное значение и «не работала»)
        writeCmd(["cycle", "pause"])
    }

    function next() {
        cmd(["playlist-next", "weak"])
    }

    function prev() {
        cmd(["playlist-prev", "weak"])
    }

    function seekTo(sec) {
        var s = Number(sec)
        if (!isFinite(s))
            return
        cmd(["seek", s, "absolute"])
    }

    function seekBy(sec) {
        var s = Number(sec)
        if (!isFinite(s) || s === 0)
            return
        cmd(["seek", s, "relative"])
    }

    function jumpTo(index) {
        var i = Math.round(Number(index))
        if (i < 0 || i >= queue.length)
            return
        cmd(["playlist-play-index", i])
    }

    function removeAt(index) {
        var i = Math.round(Number(index))
        if (i < 0 || i >= queue.length)
            return
        cmd(["playlist-remove", i])
    }

    // перестановка треков в очереди (перетаскивание): playlist-move <from> <to>.
    // Грабля mpv: при движении ВНИЗ запись встаёт ПЕРЕД целевой (на слот выше),
    // поэтому целимся на to+1; to == count валиден и кладёт запись в конец.
    function moveInQueue(from, to) {
        var a = Math.round(Number(from))
        var b = Math.round(Number(to))
        if (!isFinite(a) || !isFinite(b))
            return
        if (a < 0 || a >= queue.length || b < 0 || b >= queue.length || a === b)
            return
        var target = (a < b) ? Math.min(queue.length, b + 1) : b
        cmd(["playlist-move", a, target])
    }

    // ── «смотреть в mpv»: демон аудио-only и держит общий сокет, поэтому
    //    видео открываю отдельным процессом без IPC-сокета, отвязав от шелла
    function currentUrl() {
        if (queueIndex >= 0 && queueIndex < queue.length)
            return String(queue[queueIndex].filename)
        return ""
    }

    property Process videoProc: Process {
        // без StdioCollector: setsid --fork отвязывается, коллектор мог бы не закрыться
        command: []
    }

    function watchInMpv() {
        var u = currentUrl()
        if (u.length === 0)
            return
        // защита от двойного клика: тот же трек подряд игнорирую пару секунд
        var now = Date.now()
        if (u === lastVideoUrl && (now - lastVideoAt) < 2000)
            return
        lastVideoUrl = u
        lastVideoAt = now
        videoProc.running = false
        videoProc.command = ["setsid", "--fork", "mpv",
            "--input-ipc-server=",                    // не воюю за сокет демона
            "--ytdl-format=bestvideo+bestaudio/best", // для ссылок; локальный файл игнорирует
            "--", u]
        videoProc.running = true
    }

    property string lastVideoUrl: ""
    property double lastVideoAt: 0

    function setVolume(v) {
        var n = Number(v)
        if (!isFinite(n))
            return
        n = Math.max(0, Math.min(100, n))
        // до коннекта не выставляю «оптимистично»: observe всё равно перезапишет
        if (connected)
            volume = n // сразу в UI, mpv подтвердит через observe
        cmd(["set_property", "volume", n])
    }

    function volumeStep(delta) { setVolume(volume + Number(delta)) }

    function toggleMute() { cmd(["cycle", "mute"]) }

    function toggleShuffle() {
        shuffle = !shuffle
        cmd(["set_property", "shuffle", shuffle])
    }

    function clearQueue() {
        writeCmd(["playlist-clear"])
        queue = []
        queueIndex = -1
        queueCount = 0
        position = 0
        length = 0
        hasMedia = false
        seekable = false
        playing = false
        title = ""
        artist = ""
        error = ""
        idleActive = true
    }

    // ═══════════════ поиск (yt-dlp, плоский) ═══════════════

    property Process searchProc: Process {
        command: []
        stdout: SplitParser {
            onRead: (line) => root.onSearchLine(line)
        }
        stderr: StdioCollector {}
        onExited: (code, st) => root.onSearchDone(code)
    }

    function search(query) {
        var q = (query === undefined || query === null) ? "" : String(query).trim()
        if (q.length === 0)
            return
        searchResults = []
        searching = true
        searchError = ""
        searchProc.running = false
        searchProc.command = [
            "yt-dlp",
            "--flat-playlist",
            "--quiet",
            "--no-warnings",
            "--ignore-config",
            "--socket-timeout", "8",
            "--playlist-end", "20",
            "--print", "%(id)s\t%(title)s\t%(duration)s\t%(uploader)s\t%(ie_key)s\t%(url)s",
            "ytsearch20:" + q
        ]
        searchProc.running = true
    }

    // yt-dlp печатает строку на видео: id \t title \t duration \t uploader \t ie_key \t url
    function onSearchLine(line) {
        var t = "" + line
        if (t.length === 0)
            return
        var p = t.split("\t")
        var id = (p.length > 0 ? p[0] : "").trim()
        if (id.length === 0)
            return
        // ytsearch подмешивает каналы и плейлисты (ie_key=YoutubeTab): их
        // watch?v=… не играется — mpv отвечает «unrecognized file format».
        // Беру только настоящие видео и их готовую ссылку.
        var ie = (p.length > 4) ? p[4].trim() : ""
        var url = (p.length > 5) ? p[5].trim() : ""
        // каналы/плейлисты (YoutubeTab) не играются — отбрасываю; видео беру по
        // ссылке, а если yt-dlp отдал только id — собираю watch-ссылку сам
        if (ie === "YoutubeTab")
            return
        var isVideo = url.indexOf("watch?v=") >= 0 || url.indexOf("/shorts/") >= 0
        if (!isVideo && id.length === 11) {
            url = "https://www.youtube.com/watch?v=" + id
            isVideo = true
        }
        if (!isVideo)
            return
        var dur = (p.length > 2) ? parseFloat(p[2]) : NaN
        if (!isFinite(dur) || dur < 0)
            dur = 0 // у лайвов duration = null/NA, делить на него нельзя
        var res = searchResults.slice()
        if (searchError !== "")
            searchError = "" // пришёл результат — старая ошибка неактуальна
        var tt = (p.length > 1 && p[1].length > 0) ? p[1] : id
        // запоминаю название по ссылке — иначе очередь покажет сырой URL
        var tm = titleMap
        tm[url] = tt
        titleMap = tm
        res.push({
            id: id,
            title: tt,
            duration: dur,
            uploader: (p.length > 3) ? p[3] : "",
            url: url
        })
        searchResults = res
    }

    function onSearchDone(code) {
        // отменённый/устаревший поиск (поле очистили) не должен ругаться ошибкой
        if (!searching)
            return
        searching = false
        if (code !== 0 && searchResults.length === 0)
            searchError = "поиск не удался (yt-dlp код " + code + ")"
        else if (code === 0 && searchResults.length === 0)
            searchError = "ничего не нашлось"
    }

    function clearResults() {
        searchProc.running = false
        searching = false
        searchResults = []
        searchError = ""
    }

    // ═══════════════ библиотека (find по дому) ═══════════════

    property Process findProc: Process {
        command: []
        stdout: SplitParser {
            onRead: (line) => root.onLibraryLine(line)
        }
        stderr: StdioCollector {}
        onExited: (code, st) => {
            // отдаю список один раз — на большой фонотеке это дешевле построчных присвоений
            root.library = root.pendingLibrary
            root.libraryBusy = false
        }
    }

    // без аргумента иду по ~/Music — по всему дому find слишком тяжёл
    function scanLibrary(dir) {
        var home = Quickshell.env("HOME")
        var base = (dir === undefined || dir === null || String(dir).length === 0)
            ? home + "/Music"
            : String(dir)
        library = []
        pendingLibrary = []
        libraryBusy = true
        findProc.running = false
        findProc.command = [
            "find", base,
            "-type", "f",
            "(", "-iname", "*.mp3", "-o", "-iname", "*.flac",
            "-o", "-iname", "*.ogg", "-o", "-iname", "*.opus",
            "-o", "-iname", "*.wav", "-o", "-iname", "*.m4a",
            "-o", "-iname", "*.aac", "-o", "-iname", "*.wma", ")"
        ]
        findProc.running = true
    }

    function onLibraryLine(line) {
        var p = ("" + line).trim()
        if (p.length === 0)
            return
        // коплю в отдельный массив: не перестраиваю список на каждый файл
        pendingLibrary.push({ path: p, name: baseName(p) })
    }

    // ═══════════════ мелкие помощники ═══════════════

    function baseName(path) {
        var i = path.lastIndexOf("/")
        return i >= 0 ? path.substring(i + 1) : path
    }

    // в очереди у несыгравшей ссылки нет заголовка — даю читаемую подпись
    function labelFor(fn) {
        var s = String(fn)
        var m = /(?:v=|youtu\.be\/|\/shorts\/)([A-Za-z0-9_-]{11})/.exec(s)
        if (m)
            return "YouTube · " + m[1]
        if (/^https?:/.test(s))
            return "ссылка"
        return baseName(s)
    }

    // тегов много и в разном регистре — перебираю до первого непустого
    function pickArtist(data) {
        if (!data)
            return ""
        var keys = ["artist", "ARTIST", "album_artist", "ALBUMARTIST",
                    "albumartist", "uploader", "UPLOADER", "channel"]
        for (var i = 0; i < keys.length; i++) {
            var v = data[keys[i]]
            if (v !== undefined && v !== null && String(v).length > 0)
                return String(v)
        }
        return ""
    }

    function fmt(s) {
        var v = Number(s)
        if (!isFinite(v) || v < 0)
            v = 0
        var m = Math.floor(v / 60)
        var sec = Math.floor(v % 60)
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }
}
