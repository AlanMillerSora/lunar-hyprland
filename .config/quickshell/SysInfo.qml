pragma Singleton
import QtQuick

// ════════════════════════════════════════════════════════════════
//  SysInfo — телеметрия риса одним местом: CPU/RAM/GPU с температурой и
//  скорость сети. Заполняет lunar-statsd (читает LunarPanel, тик 1 с),
//  читают бар, «Пульт» и «Телеметрия». Плюс история для спарклайнов.
// ════════════════════════════════════════════════════════════════
QtObject {
    id: sys

    property int cpu: 0
    property int cpuTemp: 0
    property int ram: 0
    property int ramTotal: 0
    property int gpu: -1
    property int gpuTemp: -1
    property real rx: 0          // КБ/с (дельта счётчиков)
    property real tx: 0
    // «горячо» для систем-острова: у 90% подсветить опасным
    readonly property bool hot: cpu >= 90 || ram >= 90 || gpu >= 90

    // история последних замеров — для спарклайнов
    // 120 точек × 1 с = 2 мин, как было при 40 точках × 3 с
    readonly property int histMax: 120
    property var cpuHist: []
    property var ramHist: []
    property var gpuHist: []

    property real _prevRx: -1
    property real _prevTx: -1
    property double _prevTs: 0

    function fmtRate(kb) {
        if (kb >= 1024)
            return (kb / 1024).toFixed(1) + " МБ/с"
        return Math.round(kb) + " КБ/с"
    }

    // скорость по дельте сырых счётчиков и времени опроса
    function feedNet(rxRaw, txRaw, now) {
        if (sys._prevRx >= 0 && now > sys._prevTs) {
            var dt = (now - sys._prevTs) / 1000
            sys.rx = Math.max(0, (rxRaw - sys._prevRx) / 1024 / dt)
            sys.tx = Math.max(0, (txRaw - sys._prevTx) / 1024 / dt)
        }
        sys._prevRx = rxRaw
        sys._prevTx = txRaw
        sys._prevTs = now
    }

    // один замер — добавить точку истории (зовёт LunarPanel после парсинга)
    function sample() {
        var c = sys.cpuHist.slice(); c.push(sys.cpu); sys.cpuHist = c.slice(-sys.histMax)
        var r = sys.ramHist.slice(); r.push(sys.ram); sys.ramHist = r.slice(-sys.histMax)
        var g = sys.gpuHist.slice(); g.push(sys.gpu); sys.gpuHist = g.slice(-sys.histMax)
    }
}
