pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ════════════════════════════════════════════════════════════════
//  NotifModel — уведомления mako (история + активные) одним местом.
//  Перенёс из правого сайдбара, чтобы показывать их в панели бара.
//  mako не чистит историю (`dismiss --all` её не трогает) — «очистить»
//  перезапускает mako.
// ════════════════════════════════════════════════════════════════
QtObject {
    id: nm

    property var raw: []          // сырой список от mako (история + активные)
    property var items: []        // показываемый список (без скрытых)
    property bool dnd: false
    property int hideBefore: -1   // «очистить»: прячем всё с id <= этого
    property var hiddenIds: ({})  // точечно скрытые (dismiss)
    property var expandedId: -1   // развёрнутое уведомление (клик — раскрыть)

    function toggleExpand(id) {
        expandedId = (expandedId === id) ? -1 : id
    }

    function rebuild() {
        var out = []
        for (var i = 0; i < raw.length; i++) {
            var n = raw[i]
            if (n.id <= hideBefore) continue
            if (hiddenIds[n.id] === true) continue
            out.push({
                id: n.id,
                app: n.app_name || "",
                summary: n.summary || "",
                body: (n.body || "").replace(/\n/g, " ")
            })
        }
        items = out
    }

    function load() {
        nm.listProc.running = true
        nm.modeProc.running = true
    }

    function dismiss(id) {
        hiddenIds[id] = true
        if (expandedId === id) expandedId = -1
        rebuild()
        nm.actionProc.command = ["bash", "-c", "makoctl dismiss -n " + id]
        nm.actionProc.running = true
    }

    function clear() {
        // id начнутся заново, так что фильтры сбрасываю
        hideBefore = -1
        hiddenIds = ({})
        expandedId = -1
        rebuild()
        nm.actionProc.command = ["bash", "-c",
            "pkill -x mako; sleep 0.3; setsid mako >/dev/null 2>&1 &"]
        nm.actionProc.running = true
    }

    function toggleDnd() {
        nm.actionProc.command = ["bash", "-c", "makoctl mode -t do-not-disturb"]
        nm.actionProc.running = true
    }

    property Process listProc: Process {
        running: false
        // история mako (ограничена max-history=20) + активные, свежие сверху
        command: ["bash", "-c", "jq -s 'add | unique_by(.id) | sort_by(.id) | reverse | .[0:20]' <(makoctl history -j 2>/dev/null || echo '[]') <(makoctl list -j 2>/dev/null || echo '[]')"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    nm.raw = JSON.parse(text)
                    nm.rebuild()
                } catch (e) {
                    // L25: не затираем список уведомлений при сбое разбора
                    console.warn("уведомления: не удалось разобрать вывод makoctl: " + e)
                }
            }
        }
    }

    property Process modeProc: Process {
        running: false
        command: ["bash", "-c", "makoctl mode 2>/dev/null | grep -q '^do-not-disturb$' && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: nm.dnd = (text.trim() === "1")
        }
    }

    property Process actionProc: Process {
        running: false
        onExited: {
            nm.load()
            nm.refreshTimer.restart()
        }
    }

    property Timer refreshTimer: Timer {
        interval: 250
        onTriggered: nm.load()
    }
}
