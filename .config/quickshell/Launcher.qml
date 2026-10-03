pragma Singleton
import QtQuick

// ════════════════════════════════════════════════════════════════
//  Launcher — оркестрация поиска: запрос, результаты, выбор, запуск.
//  Индекс приложений — SearchModel, режим — BarState. Панель поиска
//  биндится к Launcher, а не к корню.
// ════════════════════════════════════════════════════════════════
QtObject {
    id: l

    property string query: ""
    property var results: []
    property int index: 0

    property Timer debounce: Timer {
        interval: 120
        repeat: false
        onTriggered: {
            l.results = SearchModel.search(l.query)
            l.index = l.firstSelectable(0)
        }
    }

    function setQuery(q) {
        l.query = q
        l.debounce.restart()
    }
    // первый выбираемый (не заголовок-секция) результат
    function firstSelectable(from) {
        var n = l.results.length
        for (var i = from; i < n; i++)
            if (!l.results[i].isHeader)
                return i
        for (var j = 0; j < n; j++)
            if (!l.results[j].isHeader)
                return j
        return -1
    }
    function move(d) {
        var n = l.results.length
        if (n === 0)
            return
        var i = l.index
        for (var k = 0; k < n; k++) {
            i = (i + d + n) % n
            if (!l.results[i].isHeader) {
                l.index = i
                return
            }
        }
    }
    function run() {
        var r = l.results[l.index]
        if (!r || r.isHeader) {
            var f = l.firstSelectable(0)
            if (f < 0)
                return
            r = l.results[f]
        }
        SearchModel.activate(r)
        BarState.closePanel()
        l.reset()
    }
    // открытие поиска: пустой запрос — показать недавние
    function open() {
        // заполняю недавними сразу, без 120-мс дебаунса: иначе в момент
        // открытия виден прошлый список, а поле уже пустое — рассинхрон
        l.query = ""
        l.debounce.stop()
        l.results = SearchModel.search("")
        l.index = l.firstSelectable(0)
    }
    function reset() {
        l.query = ""
        l.results = []
        l.index = 0
    }
}
