import QtQuick
import QtQuick.Shapes

// ════════════════════════════════════════════════════════════════
//  LunarWallpaperScene — живая сцена затмения на чистом QtQuick.
//
//  Здесь НЕТ типов Quickshell: файл можно запустить обычным `qml`
//  (см. preview.qml) и вставить в обои (LunarWallpaper.qml).
//
//  Фаза 1..9 (по активному столу):
//    · луна едет слева направо, на фазе 5 — кольцо;
//    · 3/4/6/7 — вспышка синего серпа nightfall (сторона из фазы);
//    · 4 — кровавая луна, метеоры, космическая пыль, яркие звёзды.
//  live=false — «лёгкий режим»: без звёзд/метеоров/пыли и без вспышек.
//
//  Геометрия повторяет сайт-спеку sait/ (контейнер 560px, солнце 250,
//  луна 246, смещения луны ±339 … 0), масштабируется от 1920×1080.
// ════════════════════════════════════════════════════════════════
Item {
    id: scene

    property int phase: 5
    property bool live: true

    // ── текущая фаза (1..9) и масштаб сцены ────────────────────
    readonly property int p: Math.max(1, Math.min(9, phase))
    readonly property real unit: Math.max(0.5, Math.min(width / 1920, height / 1080))
    readonly property real cxp: width / 2
    readonly property real cyp: height * 0.44

    // ── таблицы фаз (индекс = фаза; 0 не используется) ─────────
    readonly property var moonOffsets: [0, -339, -288, -230, -107, 0, 107, 230, 288, 339]
    readonly property var sunOps:      [0, 1, 0.95, 0.88, 0.95, 0.95, 0.88, 0.95, 1, 1]
    readonly property var moonGlowOps: [0, 0.2, 0.35, 0.6, 0.85, 0.6, 0.35, 0.2, 0, 0.2]
    readonly property var penumbraOps: [0, 0.5, 0.9, 1, 0.25, 1, 0.9, 0.5, 0, 0.5]
    readonly property var beadsOps:    [0, 0, 0.25, 0.7, 0.95, 0.7, 0.25, 0, 0, 0]
    readonly property var dustOps:     [0, 0, 0, 0.35, 0.9, 0.35, 0, 0, 0, 0]
    readonly property var horizonOps:  [0, 0, 0, 0.35, 1, 0.35, 0, 0, 0, 0]

    readonly property bool totality: p === 4
    readonly property bool ring: p === 3 || p === 5
    readonly property bool nightfallOn: live && (p === 3 || p === 4 || p === 6 || p === 7)
    readonly property bool nightfallRight: p <= 4

    property real nfOpacity: 0
    property real nfScale: 1
    onNightfallOnChanged: if (!nightfallOn) { nfOpacity = 0; nfScale = 1 }

    // ═══════════════ данные для градиентов ═══════════════
    function bgStops(ph) {
        switch (ph) {
        case 1: case 8: case 9:
            return [{ p: 0, c: "#10151c" }, { p: 0.6, c: "#05070c" }, { p: 1, c: "#000000" }]
        case 2: case 7:
            return [{ p: 0, c: "#0d1218" }, { p: 0.65, c: "#04060a" }, { p: 1, c: "#000000" }]
        case 3: case 6:
            return [{ p: 0, c: "#0e1018" }, { p: 0.6, c: "#06070d" }, { p: 1, c: "#000000" }]
        case 4:
            return [{ p: 0, c: "#14110f" }, { p: 0.22, c: "#1a0c0e" },
                    { p: 0.62, c: "#050307" }, { p: 1, c: "#000000" }]
        case 5:
            return [{ p: 0, c: "#0b1019" }, { p: 0.62, c: "#050812" }, { p: 1, c: "#000000" }]
        }
        return [{ p: 0, c: "#0c0c0c" }, { p: 1, c: "#000000" }]
    }

    readonly property var sunStops: [
        { p: 0, c: "#ffffff" }, { p: 0.40, c: "#ffffff" }, { p: 0.55, c: "#f7f7f7" },
        { p: 0.72, c: "rgba(255,255,255,0.60)" }, { p: 0.84, c: "rgba(255,255,255,0.14)" },
        { p: 1, c: "rgba(255,255,255,0)" }
    ]
    readonly property var sunGlowStops: [
        { p: 0, c: "rgba(255,255,255,0.18)" }, { p: 0.46, c: "rgba(255,255,255,0.08)" },
        { p: 0.70, c: "rgba(255,255,255,0.02)" }, { p: 0.84, c: "rgba(255,255,255,0)" },
        { p: 1, c: "rgba(255,255,255,0)" }
    ]
    readonly property var moonGlowStops: [
        { p: 0, c: "rgba(255,255,255,0)" }, { p: 0.63, c: "rgba(255,255,255,0)" },
        { p: 0.68, c: "rgba(180,200,255,0.10)" }, { p: 0.73, c: "rgba(150,180,255,0.24)" },
        { p: 0.80, c: "rgba(170,200,255,0.12)" }, { p: 0.88, c: "rgba(255,255,255,0)" },
        { p: 1, c: "rgba(255,255,255,0)" }
    ]
    readonly property var penumbraStops: [
        { p: 0, c: "rgba(0,0,0,0.85)" }, { p: 0.46, c: "rgba(0,0,0,0.55)" },
        { p: 0.62, c: "rgba(0,0,0,0.28)" }, { p: 0.78, c: "rgba(0,0,0,0)" },
        { p: 1, c: "rgba(0,0,0,0)" }
    ]
    readonly property var beadsStops: [
        { p: 0, c: "rgba(255,255,255,0)" }, { p: 0.63, c: "rgba(255,255,255,0)" },
        { p: 0.66, c: "rgba(255,255,255,0.25)" }, { p: 0.70, c: "rgba(255,255,255,0)" },
        { p: 1, c: "rgba(255,255,255,0)" }
    ]
    readonly property var coronaStops: ring
        ? [{ p: 0, c: "rgba(255,255,255,0)" }, { p: 0.55, c: "rgba(255,255,255,0)" },
           { p: 0.64, c: "rgba(255,255,255,0.07)" }, { p: 0.74, c: "rgba(255,255,255,0.11)" },
           { p: 0.86, c: "rgba(255,255,255,0.03)" }, { p: 1, c: "rgba(255,255,255,0)" }]
        : [{ p: 0, c: "rgba(255,255,255,0)" }, { p: 0.50, c: "rgba(255,255,255,0.06)" },
           { p: 0.60, c: "rgba(255,255,255,0.20)" }, { p: 0.72, c: "rgba(255,255,255,0.11)" },
           { p: 0.88, c: "rgba(255,255,255,0)" }, { p: 1, c: "rgba(255,255,255,0)" }]
    readonly property var coronaGlowStops: ring
        ? [{ p: 0, c: "rgba(255,255,255,0)" }, { p: 0.45, c: "rgba(255,255,255,0.06)" },
           { p: 0.72, c: "rgba(255,255,255,0)" }, { p: 1, c: "rgba(255,255,255,0)" }]
        : [{ p: 0, c: "rgba(255,255,255,0.16)" }, { p: 0.30, c: "rgba(255,255,255,0.16)" },
           { p: 0.52, c: "rgba(255,255,255,0.07)" }, { p: 0.74, c: "rgba(255,255,255,0)" },
           { p: 1, c: "rgba(255,255,255,0)" }]
    readonly property var moonRimStops: [
        { p: 0, c: "rgba(255,255,255,0)" }, { p: 0.90, c: "rgba(255,255,255,0)" },
        { p: 0.955, c: "rgba(255,255,255,0.55)" }, { p: 0.99, c: "rgba(255,255,255,0.10)" },
        { p: 1, c: "rgba(255,255,255,0)" }
    ]

    // горизонт: тёплый (кровавый) на 4, белый иначе
    readonly property var horizonStops: totality
        ? [{ p: 0, c: "rgba(210,40,55,0.55)" }, { p: 0.30, c: "rgba(180,30,50,0.32)" },
           { p: 0.55, c: "rgba(140,18,42,0.14)" }, { p: 0.75, c: "rgba(255,255,255,0.06)" },
           { p: 1, c: "rgba(255,255,255,0)" }]
        : [{ p: 0, c: "rgba(255,255,255,0.22)" }, { p: 0.35, c: "rgba(255,255,255,0.07)" },
           { p: 0.70, c: "rgba(255,255,255,0)" }, { p: 1, c: "rgba(255,255,255,0)" }]

    // ═══════════════ звёзды / метеоры / пыль ═══════════════
    // Детерминированный ГПСЧ — поле звёзд одинаково при каждом старте.
    function makeStars() {
        var a = [], s = 20240924
        function rnd() { s = (s * 1103515245 + 12345) % 2147483648; return s / 2147483648 }
        for (var i = 0; i < 150; i++) {
            a.push({
                x: rnd(), y: rnd(),
                size: rnd() < 0.08 ? 2 : 1,
                dur: 2000 + rnd() * 4000,
                max: 0.3 + rnd() * 0.7,
                delay: rnd() * 4000
            })
        }
        return a
    }
    function makeMeteors() {
        var a = [], s = 777
        function rnd() { s = (s * 1103515245 + 12345) % 2147483648; return s / 2147483648 }
        for (var i = 0; i < 7; i++) {
            a.push({
                x: 0.45 + rnd() * 0.55,
                y: -0.02 + rnd() * 0.25,
                dur: 1100 + rnd() * 1600,
                delay: 3000 + rnd() * 9000
            })
        }
        return a
    }
    function makeDust() {
        var a = [], s = 4242
        function rnd() { s = (s * 1103515245 + 12345) % 2147483648; return s / 2147483648 }
        for (var i = 0; i < 15; i++) {
            a.push({
                x: rnd(), y: rnd(),
                size: 1 + rnd() * 2,
                dur: 10000 + rnd() * 20000,
                drift: rnd() * 100 - 50,
                delay: rnd() * 15000
            })
        }
        return a
    }
    readonly property var starData: makeStars()
    readonly property var meteorData: makeMeteors()
    readonly property var dustData: makeDust()

    // ═══════════════ переиспользуемые рисовалки ═══════════════
    // Радиальный градиент, запекается один раз (перерисовка — при
    // смене stops/размера). Дешёвый статичный слой.
    component RadialCanvas: Canvas {
        id: rc
        property var stops: []
        property real gcx: width / 2
        property real gcy: height / 2
        property real gr: Math.max(width, height) / 2
        onStopsChanged: requestPaint()
        onGcxChanged: requestPaint()
        onGcyChanged: requestPaint()
        onGrChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var g = ctx.createRadialGradient(gcx, gcy, 0, gcx, gcy, gr)
            for (var i = 0; i < stops.length; i++)
                g.addColorStop(stops[i].p, stops[i].c)
            ctx.fillStyle = g
            ctx.fillRect(0, 0, width, height)
        }
    }

    // ── фон ────────────────────────────────────────────────────
    RadialCanvas {
        anchors.fill: parent
        stops: scene.bgStops(scene.p)
    }

    // ── звёзды ─────────────────────────────────────────────────
    Repeater {
        model: scene.live ? scene.starData : []
        delegate: Rectangle {
            required property var modelData
            x: modelData.x * scene.width
            y: modelData.y * scene.height
            width: modelData.size
            height: modelData.size
            radius: width / 2
            color: "#ffffff"
            opacity: 0.1
            SequentialAnimation on opacity {
                running: scene.live
                loops: Animation.Infinite
                PauseAnimation { duration: modelData.delay }
                NumberAnimation {
                    from: 0.1; to: scene.totality ? Math.min(1, modelData.max * 1.5) : modelData.max
                    duration: modelData.dur / 2; easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: scene.totality ? Math.min(1, modelData.max * 1.5) : modelData.max; to: 0.1
                    duration: modelData.dur / 2; easing.type: Easing.InOutSine
                }
            }
        }
    }

    // ── космическая пыль (лёгкий дрейф) ────────────────────────
    Repeater {
        model: (scene.live && scene.dustOps[scene.p] > 0) ? scene.dustData : []
        delegate: Rectangle {
            required property var modelData
            x: modelData.x * scene.width
            y: modelData.y * scene.height
            width: modelData.size
            height: modelData.size
            radius: width / 2
            color: "#ffffff"
            opacity: 0
            SequentialAnimation on opacity {
                running: scene.live
                loops: Animation.Infinite
                PauseAnimation { duration: modelData.delay }
                NumberAnimation { from: 0; to: 0.28 * scene.dustOps[scene.p]; duration: modelData.dur * 0.4 }
                NumberAnimation { from: 0.28 * scene.dustOps[scene.p]; to: 0; duration: modelData.dur * 0.6 }
            }
            NumberAnimation on x {
                running: scene.live
                loops: Animation.Infinite
                from: modelData.x * scene.width
                to: modelData.x * scene.width + modelData.drift * scene.unit
                duration: modelData.dur; easing.type: Easing.InOutSine
            }
            NumberAnimation on y {
                running: scene.live
                loops: Animation.Infinite
                from: modelData.y * scene.height
                to: modelData.y * scene.height - 40 * scene.unit
                duration: modelData.dur; easing.type: Easing.InOutSine
            }
        }
    }

    // ── горизонт (низ экрана) ──────────────────────────────────
    RadialCanvas {
        id: horizon
        x: 0
        y: 0
        width: scene.width
        height: scene.height
        gcx: width / 2
        gcy: height
        gr: height * 0.40
        stops: scene.horizonStops
        opacity: scene.horizonOps[scene.p]
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: 900 } }
    }
    // светлая линия у горизонта
    Rectangle {
        x: 0
        y: scene.height - 2
        width: scene.width
        height: 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: scene.totality ? "#F2F7606E" : "#E6FFFFFF" }
            GradientStop { position: 1; color: "transparent" }
        }
        opacity: scene.horizonOps[scene.p] * 0.9
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: 900 } }
    }

    // ── метеоры (только кровавая луна, фаза 4) ─────────────────
    Repeater {
        model: (scene.live && scene.totality) ? scene.meteorData : []
        delegate: Item {
            required property var modelData
            x: modelData.x * scene.width
            y: modelData.y * scene.height
            width: 2
            height: 2
            opacity: 0

            Rectangle {
                x: 1; y: -1
                width: 120 * scene.unit
                height: 2
                radius: 1
                rotation: -24
                transformOrigin: Item.Left
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#F2F0F8FF" }
                    GradientStop { position: 0.45; color: "#80BED7FF" }
                    GradientStop { position: 1; color: "#00BED7FF" }
                }
            }
            Rectangle {
                width: 2; height: 2; radius: 1; color: "#ffffff"
            }

            SequentialAnimation on opacity {
                running: scene.live && scene.totality
                loops: Animation.Infinite
                PauseAnimation { duration: modelData.delay }
                NumberAnimation { from: 0; to: 1; duration: modelData.dur * 0.07 }
                NumberAnimation { from: 1; to: 0; duration: modelData.dur * 0.55 }
                PauseAnimation { duration: modelData.dur * 0.4 }
            }
            NumberAnimation on x {
                running: scene.live && scene.totality
                loops: Animation.Infinite
                from: modelData.x * scene.width
                to: modelData.x * scene.width - 0.45 * scene.width
                duration: modelData.dur; easing.type: Easing.Linear
            }
            NumberAnimation on y {
                running: scene.live && scene.totality
                loops: Animation.Infinite
                from: modelData.y * scene.height
                to: modelData.y * scene.height + 0.34 * scene.height
                duration: modelData.dur; easing.type: Easing.Linear
            }
        }
    }

    // ═══════════════ затмение (центр сцены) ═══════════════
    Item {
        id: container
        x: scene.cxp
        y: scene.cyp
        width: 0
        height: 0

        // мягкое внешнее дыхание солнца
        RadialCanvas {
            id: sunGlowOuter
            x: -155 * scene.unit
            y: -155 * scene.unit
            width: 310 * scene.unit
            height: 310 * scene.unit
            stops: scene.sunGlowStops
            opacity: scene.sunOps[scene.p]
            SequentialAnimation on scale {
                running: scene.live
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 1.045; duration: 2500; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.045; to: 1; duration: 2500; easing.type: Easing.InOutSine }
            }
        }

        // гало короны (внешнее)
        RadialCanvas {
            id: coronaGlow
            x: -190 * scene.unit
            y: -190 * scene.unit
            width: 380 * scene.unit
            height: 380 * scene.unit
            stops: scene.coronaGlowStops
            opacity: scene.ring ? 0.9 : (scene.totality ? 1 : 0)
            visible: opacity > 0.001
            SequentialAnimation on opacity {
                running: scene.live && scene.totality
                loops: Animation.Infinite
                NumberAnimation { from: 0.8; to: 1; duration: 2000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0.8; duration: 2000; easing.type: Easing.InOutSine }
            }
            Behavior on opacity { NumberAnimation { duration: 800 } }
        }

        // корона — узкое кольцо вокруг луны
        RadialCanvas {
            id: corona
            x: -130 * scene.unit
            y: -130 * scene.unit
            width: 260 * scene.unit
            height: 260 * scene.unit
            stops: scene.coronaStops
            opacity: scene.ring ? 0.9 : (scene.totality ? 1 : 0)
            visible: opacity > 0.001
            Behavior on opacity { NumberAnimation { duration: 800 } }
        }

        // солнце (аннулярный диск)
        RadialCanvas {
            id: sun
            x: -125 * scene.unit
            y: -125 * scene.unit
            width: 250 * scene.unit
            height: 250 * scene.unit
            stops: scene.sunStops
            opacity: scene.sunOps[scene.p]
            Behavior on opacity { NumberAnimation { duration: 700 } }
        }

        // ── луна и её спутники (двигаются вместе) ──────────────
        Item {
            id: moonGroup
            x: scene.moonOffsets[scene.p] * scene.unit
            y: 0
            width: 0
            height: 0
            Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.InOutCubic } }

            // постоянное голубоватое гало
            RadialCanvas {
                x: -180 * scene.unit
                y: -180 * scene.unit
                width: 360 * scene.unit
                height: 360 * scene.unit
                stops: scene.moonGlowStops
                opacity: scene.moonGlowOps[scene.p]
                Behavior on opacity { NumberAnimation { duration: 800 } }
            }
            // тёмная полутень
            RadialCanvas {
                x: -150 * scene.unit
                y: -150 * scene.unit
                width: 300 * scene.unit
                height: 300 * scene.unit
                stops: scene.penumbraStops
                opacity: scene.penumbraOps[scene.p]
                Behavior on opacity { NumberAnimation { duration: 800 } }
            }
            // тонкий светящийся обод на 3/4/5
            RadialCanvas {
                x: -126 * scene.unit
                y: -126 * scene.unit
                width: 252 * scene.unit
                height: 252 * scene.unit
                stops: scene.moonRimStops
                opacity: scene.ring ? 0.55 : (scene.totality ? 0.75 : 0)
                visible: opacity > 0.001
                Behavior on opacity { NumberAnimation { duration: 600 } }
            }
            // диск луны
            Rectangle {
                x: -123 * scene.unit
                y: -123 * scene.unit
                width: 246 * scene.unit
                height: 246 * scene.unit
                radius: width / 2
                color: "#000000"
            }
            // кровавый оттенок — свечение внутри диска при полной фазе
            RadialCanvas {
                x: -123 * scene.unit
                y: -123 * scene.unit
                width: 246 * scene.unit
                height: 246 * scene.unit
                stops: [
                    { p: 0, c: "rgba(120,20,40,0)" },
                    { p: 0.55, c: "rgba(120,20,40,0.12)" },
                    { p: 0.82, c: "rgba(150,25,45,0.55)" },
                    { p: 0.95, c: "rgba(120,20,40,0.85)" },
                    { p: 1, c: "rgba(120,20,40,0)" }
                ]
                opacity: scene.totality ? 1 : 0
                visible: opacity > 0.001
                Behavior on opacity { NumberAnimation { duration: 800 } }
            }
            // жемчужины Бейли
            RadialCanvas {
                x: -126 * scene.unit
                y: -126 * scene.unit
                width: 252 * scene.unit
                height: 252 * scene.unit
                stops: scene.beadsStops
                opacity: scene.beadsOps[scene.p]
                Behavior on opacity { NumberAnimation { duration: 700 } }
            }
        }

        // ── nightfall — синий серп (сторона и вспышка из фазы) ─
        Shape {
            id: nightfall
            x: -280 * scene.unit
            y: -280 * scene.unit
            width: 560
            height: 560
            scale: scene.unit * scene.nfScale
            opacity: scene.nfOpacity
            visible: scene.nightfallOn
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillGradient: LinearGradient {
                    x1: scene.nightfallRight ? 273 : 150
                    y1: 0
                    x2: scene.nightfallRight ? 410 : 287
                    y2: 0
                    GradientStop { position: 0; color: scene.nightfallRight ? "#ffffff" : "#2e6bff" }
                    GradientStop { position: scene.nightfallRight ? 0.55 : 0.45; color: "#a6c8ff" }
                    GradientStop { position: 1; color: scene.nightfallRight ? "#2e6bff" : "#ffffff" }
                }
                PathPolyline {
                    path: scene.crescentPoints(scene.nightfallRight ? "right" : "left")
                }
            }
        }

        SequentialAnimation {
            running: scene.nightfallOn
            loops: Animation.Infinite
            PauseAnimation { duration: 4200 }
            ParallelAnimation {
                NumberAnimation { target: scene; property: "nfOpacity"; from: 0; to: 1; duration: 350 }
                NumberAnimation { target: scene; property: "nfScale"; from: 0.7; to: 0.95; duration: 350 }
            }
            ParallelAnimation {
                NumberAnimation { target: scene; property: "nfOpacity"; from: 1; to: 0.9; duration: 450 }
                NumberAnimation { target: scene; property: "nfScale"; from: 0.95; to: 1.22; duration: 450 }
            }
            ParallelAnimation {
                NumberAnimation { target: scene; property: "nfOpacity"; from: 0.9; to: 0; duration: 1600 }
                NumberAnimation { target: scene; property: "nfScale"; from: 1.22; to: 1.45; duration: 1600 }
            }
        }
    }

    // ── геометрия серпа (порт crescentPoints из sait/script.js) ─
    function crescentPoints(side) {
        var cx = 280, cy = 280, r = 130, off = 14, n = 80
        var cutCx = cx + off
        var hornX = cx + off / 2
        var hornD = Math.sqrt(r * r - off * off / 4)
        var botY = cy + hornD, topY = cy - hornD
        var aTopMain = Math.atan2(topY - cy, hornX - cx); if (aTopMain < 0) aTopMain += 2 * Math.PI
        var aBotMain = Math.atan2(botY - cy, hornX - cx)
        var aTopCut = Math.atan2(topY - cy, hornX - cutCx); if (aTopCut < 0) aTopCut += 2 * Math.PI
        var aBotCut = Math.atan2(botY - cy, hornX - cutCx)
        var pts = []
        for (var i = 0; i <= n; i++) {
            var a = aBotMain + (aTopMain - aBotMain) * i / n
            pts.push(Qt.point(cx + r * Math.cos(a), cy + r * Math.sin(a)))
        }
        for (var j = 0; j <= n; j++) {
            var b = aTopCut + (aBotCut - aTopCut) * j / n
            pts.push(Qt.point(cutCx + r * Math.cos(b), cy + r * Math.sin(b)))
        }
        if (side === "right") {
            var mirror = []
            for (var k = 0; k < pts.length; k++)
                mirror.push(Qt.point(2 * cx - pts[k].x, pts[k].y))
            return mirror
        }
        return pts
    }
}
