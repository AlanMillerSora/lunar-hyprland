pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ════════════════════════════════════════════════════════════════
//  Weather — погода для бара. Свой сервис, без внешних пакетов.
//
//  Город/координаты беру у ipinfo.io (один раз, с кэшем), погоду —
//  у wttr.in компактной строкой (большой j1 сервер обрезает).
//  Обновляю раз в 20 минут; последний удачный ответ помню в
//  ~/.cache/lunar/weather.txt, чтобы пережить перезапуск без сети.
//
//  Поля: city, temp, feels, desc, icon, wind, hum, ok, updated.
// ════════════════════════════════════════════════════════════════
QtObject {
    id: wx

    property string city: ""
    property string temp: ""
    property string feels: ""
    property string desc: ""
    property string wind: ""
    property string hum: ""
    property string icon: "\uf185"      // солнце по умолчанию
    property bool ok: false
    property double updated: 0

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/lunar"
    readonly property string cacheFile: wx.cacheDir + "/weather.txt"

    // город по IP — один раз, координаты не нужны: wttr.in поймёт и имя
    property Process geo: Process {
        running: false
        command: ["bash", "-c",
            "curl -s --max-time 8 https://ipinfo.io/json | " +
            "grep -o '\"city\": *\"[^\"]*\"' | head -1 | cut -d'\"' -f4"]
        stdout: StdioCollector {
            onStreamFinished: {
                var c = text.trim()
                if (c !== "") {
                    wx.city = c
                    wx.fetch()
                }
            }
        }
    }

    // текущая погода — компактной строкой
    property Process cur: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var s = text.trim()
                if (s === "" || s.indexOf("|") < 0)
                    return
                var p = s.split("|")
                wx.desc = (p[0] || "").trim()
                wx.temp = (p[1] || "").trim()
                wx.feels = (p[2] || "").trim()
                wx.hum = (p[3] || "").trim()
                wx.wind = (p[4] || "").trim()
                wx.icon = wx.iconFor(wx.desc)
                wx.ok = true
                wx.updated = Date.now()
                wx.saveCache()
            }
        }
    }

    function fetch() {
        var place = wx.city !== "" ? wx.city : "auto"
        wx.cur.command = ["bash", "-c",
            "curl -s --max-time 10 \"https://wttr.in/" + place.replace(/[^A-Za-zА-Яа-яЁё0-9 _-]/g, "") + "?format=%C|%t|%f|%h|%w&lang=ru\""]
        wx.cur.running = false
        wx.cur.running = true
    }

    function refresh() {
        if (wx.city === "")
            wx.geo.running = true
        else
            wx.fetch()
    }

    // описание → глиф Nerd Font (учу и английские, и русские слова)
    function iconFor(d) {
        d = ("" + d).toLowerCase()
        if (d.indexOf("thunder") >= 0 || d.indexOf("гроза") >= 0) return "\uf0e7"
        if (d.indexOf("blizzard") >= 0 || d.indexOf("метель") >= 0) return "\uf2dc"
        if (d.indexOf("snow") >= 0 || d.indexOf("снег") >= 0 || d.indexOf("sleet") >= 0) return "\uf2dc"
        if (d.indexOf("rain") >= 0 || d.indexOf("дожд") >= 0 || d.indexOf("ливень") >= 0
            || d.indexOf("морось") >= 0 || d.indexOf("drizzle") >= 0) return "\uf043"
        if (d.indexOf("fog") >= 0 || d.indexOf("mist") >= 0 || d.indexOf("туман") >= 0
            || d.indexOf("дымка") >= 0) return "\uf014"
        if (d.indexOf("overcast") >= 0 || d.indexOf("пасмур") >= 0) return "\uf0c2"
        if (d.indexOf("cloud") >= 0 || d.indexOf("облач") >= 0) return "\uf0c2"
        if (d.indexOf("clear") >= 0 || d.indexOf("sunny") >= 0
            || d.indexOf("ясно") >= 0 || d.indexOf("солнеч") >= 0) return "\uf185"
        return "\uf0c2"
    }

    // короткая подпись для бара: +9°
    readonly property string shortTemp: {
        if (wx.temp === "") return "—"
        var m = wx.temp.match(/[+-]?\d+/)
        return m ? m[0] + "°" : "—"
    }

    // описание по-русски: wttr.in отдаёт английский, если lang не сработал
    readonly property var ruDict: ({
        "sunny": "Солнечно", "clear": "Ясно",
        "partly cloudy": "Переменная облачность",
        "cloudy": "Облачно", "overcast": "Пасмурно",
        "mist": "Дымка", "fog": "Туман", "freezing fog": "Ледяной туман",
        "patchy rain nearby": "Местами дождь",
        "patchy rain possible": "Возможен дождь",
        "light rain": "Небольшой дождь", "light drizzle": "Морось",
        "freezing drizzle": "Ледяная морось",
        "light rain shower": "Небольшой ливень",
        "moderate rain": "Дождь",
        "moderate or heavy rain shower": "Ливень",
        "heavy rain": "Сильный дождь", "torrential rain shower": "Сильный ливень",
        "light snow": "Небольшой снег", "moderate snow": "Снег",
        "heavy snow": "Сильный снег", "blizzard": "Метель",
        "sleet": "Мокрый снег", "light sleet": "Мокрый снег",
        "thundery outbreaks possible": "Возможны грозы",
        "thunderstorm": "Гроза",
        "patchy light rain with thunder": "Дождь с грозой",
        "patchy light snow with thunder": "Снег с грозой"
    })
    readonly property string descRu: {
        var d = ("" + wx.desc).trim()
        if (d === "") return ""
        if (/[А-Яа-яЁё]/.test(d)) return d   // уже русский
        var k = d.toLowerCase()
        return wx.ruDict[k] !== undefined ? wx.ruDict[k] : d
    }

    function saveCache() {
        var line = wx.city + "\t" + wx.desc + "\t" + wx.temp + "\t"
            + wx.feels + "\t" + wx.hum + "\t" + wx.wind + "\t" + wx.icon
        wx.writeProc.command = ["bash", "-c",
            "mkdir -p \"$1\" && printf %s \"$2\" > \"$1/weather.txt\"",
            "--", wx.cacheDir, line]
        wx.writeProc.running = false
        wx.writeProc.running = true
    }

    property Process writeProc: Process { running: false }

    property Process readCache: Process {
        running: false
        command: ["bash", "-c", "cat \"$1\" 2>/dev/null", "--", wx.cacheFile]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = text.trim()
                if (s === "") return
                var p = s.split("\t")
                if (p.length < 7) return
                wx.city = p[0]; wx.desc = p[1]; wx.temp = p[2]
                wx.feels = p[3]; wx.hum = p[4]; wx.wind = p[5]; wx.icon = p[6]
                wx.ok = wx.temp !== ""
            }
        }
    }

    // обновление раз в 20 минут
    property Timer timer: Timer {
        interval: 20 * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: wx.refresh()
    }

    Component.onCompleted: wx.readCache.running = true
}
