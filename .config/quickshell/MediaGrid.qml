import QtQuick
import Quickshell
import Quickshell.Io

// ════════════════════════════════════════════════════════════════
//  MediaGrid — сетка-галерея файлов для вкладки Media (Hub).
//
//  Сканирую заданные папки, показываю миниатюры, клик открывает файл
//  (xdg-open). Картинки ужимаю magick, видео — первым кадром ffmpeg.
//  Ключ кэша миниатюр — md5 пути, поэтому одноимённые файлы из разных
//  папок не путаются. Тяжёлый декод — один раз, фоном.
//
//  folders — список папок; videos — собирать видео, иначе картинки.
// ════════════════════════════════════════════════════════════════
Item {
    id: grid

    property var folders: []
    property bool videos: false

    // [[md5, path], ...]
    property var files: []
    // md5 -> 1 (какие миниатюры уже готовы)
    property var thumbSet: ({})
    property bool busy: true
    property string thumbDir: Quickshell.env("HOME") + "/.cache/lunar/media-thumbs"

    // маски расширений
    readonly property string imgMask:
        "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' "
        + "-o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \\)"
    readonly property string vidMask:
        "\\( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' "
        + "-o -iname '*.mov' -o -iname '*.avi' -o -iname '*.m4v' \\)"

    // кавычу пути для вставки в shell (пробелы, кавычки)
    function shq(s) { return "'" + ("" + s).replace(/'/g, "'\\''") + "'" }

    function folderArgs() {
        var a = ""
        var fs = grid.folders || []
        for (var i = 0; i < fs.length; i++)
            a += " " + shq(fs[i])
        return a
    }

    function scan() {
        grid.busy = true
        grid.thumbSet = ({})
        // команду ставлю явно перед запуском: собираю из текущих folders/videos,
        // иначе Process стартует раньше, чем заданы свойства, и висит с пустой
        mediaScan.command = scanCmd()
        mediaScan.running = true
    }

    // команда скана: пары md5|путь, чтобы не зависеть от имён файлов
    function scanCmd() {
        return ["bash", "-c",
            "for d in " + grid.folderArgs() + "; do [ -d \"$d\" ] && find \"$d\" -maxdepth 1 -type f "
            + (grid.videos ? grid.vidMask : grid.imgMask)
            + " 2>/dev/null; done | sort | head -300 | while IFS= read -r p; do "
            + "printf '%s|%s\\n' \"$(printf '%s' \"$p\" | md5sum | cut -c1-16)\" \"$p\"; done"]
    }

    function thumbCmd() {
        return ["bash", "-c",
            "C=\"" + grid.thumbDir + "\"; mkdir -p \"$C\"; "
            + "for d in " + grid.folderArgs() + "; do [ -d \"$d\" ] && find \"$d\" -maxdepth 1 -type f "
            + (grid.videos ? grid.vidMask : grid.imgMask)
            + " 2>/dev/null; done | sort | head -300 | while IFS= read -r p; do "
            + "m=$(printf '%s' \"$p\" | md5sum | cut -c1-16); t=\"$C/$m.jpg\"; "
            + "if [ -s \"$t\" ] && [ \"$t\" -nt \"$p\" ]; then continue; fi; "
            + (grid.videos
                ? "ffmpeg -y -ss 1 -i \"$p\" -frames:v 1 -an -sn -vf 'scale=320:-2' \"$t\" >/dev/null 2>&1 || "
                + "ffmpeg -y -i \"$p\" -frames:v 1 -an -sn -vf 'scale=320:-2' \"$t\" >/dev/null 2>&1 || true; "
                : "magick \"$p\" -thumbnail x320 -strip -quality 82 \"$t\" 2>/dev/null || true; ")
            + "done; true"]
    }

    Component.onCompleted: scan()

    // ── скан: отдаю пары md5|путь, чтобы не зависеть от имён ──
    Process {
        id: mediaScan
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var ln = lines[i]
                    if (!ln) continue
                    var k = ln.indexOf("|")
                    if (k < 0) continue
                    out.push([ln.substring(0, k), ln.substring(k + 1)])
                }
                grid.files = out
                grid.busy = false
                if (out.length > 0) {
                    thumbGen.command = thumbCmd()
                    thumbGen.running = true
                } else {
                    grid.thumbSet = ({})
                }
            }
        }
    }

    // ── миниатюры: картинки magick, видео — кадр ffmpeg ──
    Process {
        id: thumbGen
        running: false
        onExited: (exitCode) => { thumbList.running = true }
    }

    Process {
        id: thumbList
        running: false
        command: ["bash", "-c", "ls -1 \"" + grid.thumbDir.replace(/"/g, "\\\"") + "\"/*.jpg 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = ({})
                var l = text.split("\n")
                for (var i = 0; i < l.length; i++) {
                    if (!l[i]) continue
                    var b = l[i].substring(l[i].lastIndexOf("/") + 1).replace(/\.jpg$/, "")
                    s[b] = 1
                }
                grid.thumbSet = s
            }
        }
    }

    function openFile(path) {
        Quickshell.execDetached(["xdg-open", path])
    }

    Column {
        anchors.fill: parent
        spacing: Theme.space3

        // ── строка: счётчик, обновить ──
        Row {
            spacing: Theme.space2

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: grid.busy ? "сканирую…"
                    : (grid.files.length === 0 ? "пусто"
                       : grid.files.length + " файлов")
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
            }

            Item { width: 1; height: 1 }

            Rectangle {
                width: 92
                height: Theme.rowHCompact
                radius: Theme.radiusM
                color: refreshMouse.containsMouse ? Theme.hover : Theme.fill
                border.width: 1
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "ОБНОВИТЬ"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                }
                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: grid.scan()
                }
            }
        }

        // ── пустая галерея ──
        Text {
            width: parent.width
            visible: !grid.busy && grid.files.length === 0
            text: grid.videos
                ? "видео нет — записи ложатся в ~/Videos"
                : "картинок нет — кладу в ~/Pictures и ~/Pictures/Screenshots"
            color: Theme.textFaint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            topPadding: Theme.space4
        }

        // ── сетка миниатюр ──
        GridView {
            id: gv
            width: parent.width
            height: parent.height - y
            visible: grid.files.length > 0
            clip: true
            cellWidth: 208
            cellHeight: 148
            boundsBehavior: Flickable.StopAtBounds
            model: grid.files

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: gv.cellWidth - 10
                height: gv.cellHeight - 10
                radius: Theme.radius
                color: tileMouse.containsMouse ? Theme.hover : Theme.fill
                border.width: 1
                border.color: tileMouse.containsMouse ? Theme.borderAccent : Theme.border
                clip: true

                Image {
                    id: thumb
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: parent.height - 24
                    source: grid.thumbSet[modelData[0]]
                        ? "file://" + grid.thumbDir + "/" + modelData[0] + ".jpg"
                        : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    sourceSize.width: 400
                    sourceSize.height: 400
                }

                // заглушка, пока миниатюра не готова
                Text {
                    anchors.centerIn: thumb
                    visible: thumb.status !== Image.Ready
                    text: grid.videos ? "▶" : "\uf03e"
                    color: Theme.textFaint
                    font.family: grid.videos ? Theme.fontFamily : Theme.iconFont
                    font.pixelSize: grid.videos ? 28 : 22
                }

                // видео: метка и длительность не считаю — просто значок
                Rectangle {
                    visible: grid.videos
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 6
                    width: 22
                    height: 16
                    radius: 4
                    color: Theme.bgPanel

                    Text {
                        anchors.centerIn: parent
                        text: "▶"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMicro
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 6
                    text: {
                        var p = modelData[1]
                        return p.substring(p.lastIndexOf("/") + 1)
                    }
                    color: Theme.textDim
                    elide: Text.ElideMiddle
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                }

                MouseArea {
                    id: tileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: grid.openFile(modelData[1])
                }
            }
        }
    }
}
