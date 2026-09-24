import QtQuick
import QtQuick.Shapes

// ════════════════════════════════════════════════════════════════
//  LunarWallpaperScene — живая сцена затмения на чистом QtQuick.
//
//  Здесь НЕТ типов Quickshell: файл можно запустить обычным `qml6`
//  (см. preview.qml) и вставить в обои (LunarWallpaper.qml).
//
//  Геометрия и градиенты — порт сайта-спеки sait/ (контейнер 560px,
//  солнце 250, луна 246, смещения луны ±339 … 0). box-shadow из CSS
//  заменены слоями радиальных градиентов (Canvas) с теми же цветами,
//  радиусами и прозрачностями.
//
//  Фаза 1..9 (по активному столу):
//    · луна едет слева направо, на 5 — кольцо;
//    · 3/4/6/7 — вспышка синего серпа nightfall (сторона из фазы);
//    · 4 — кровавая луна, метеоры, космическая пыль, яркие звёзды.
//  live=false — «лёгкий режим»: без звёзд/метеоров/пыли и вспышек.
// ════════════════════════════════════════════════════════════════
Item {
    id: scene

    property int phase: 5
    property bool live: true

    // ── общее время сцены, обновляется ~25 раз/с ───────────────
    // Все анимации (звёзды, пыль, метеоры, дыхание, серп) считаются от `t`,
    // а не тикают на каждом кадре. Композитор перерисовывает фон 25 раз/с
    // вместо 60 — на слабом iGPU это главное облегчение без потери жизни.
    // темп анимации: 16 мс (≈60 fps, NORMAL) или 40 мс (≈25 fps, OPTIMIZE)
    property int tickMs: 16
    property real t: 0
    Timer {
        interval: scene.tickMs
        running: scene.live
        repeat: true
        onTriggered: scene.t += interval / 1000
    }

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
    readonly property var dustOps:     [0, 0, 0, 0.35, 0.9, 0.35, 0, 0, 0, 0]
    readonly property var horizonOps:  [0, 0, 0, 0.35, 1, 0.35, 0, 0, 0, 0]

    readonly property bool totality: p === 4
    readonly property bool ring: p === 3 || p === 5
    readonly property bool nightfallOn: live && (p === 3 || p === 4 || p === 6 || p === 7)
    readonly property bool nightfallRight: p <= 4

    // вспышка серпа считается от общего времени сцены
    readonly property real nfOpacity: {
        if (!nightfallOn) return 0
        var k = nfPhase()
        return k < 0 ? 0 : nfVal(k)[0]
    }
    readonly property real nfScale: {
        if (!nightfallOn) return 1
        var k = nfPhase()
        return k < 0 ? 1 : nfVal(k)[1]
    }

    // ═══════════════ фон по фазам (CSS #eclipse-bg) ═══════════════
    function bgStops(ph) {
        switch (ph) {
        case 1: case 8: case 9:
            return [{ p: 0, c: "#10151c" }, { p: 0.6, c: "#05070c" }, { p: 1, c: "#000000" }]
        case 2: case 7:
            return [{ p: 0, c: "#0d1218" }, { p: 0.65, c: "#04060a" }, { p: 1, c: "#000000" }]
        case 3: case 6:
            return [{ p: 0, c: "#0e1018" }, { p: 0.6, c: "#06070d" }, { p: 1, c: "#000000" }]
        case 4:
            return [{ p: 0, c: "#080a10" }, { p: 0.62, c: "#030407" }, { p: 1, c: "#000000" }]
        case 5:
            return [{ p: 0, c: "#0b1019" }, { p: 0.62, c: "#050812" }, { p: 1, c: "#000000" }]
        }
        return [{ p: 0, c: "#0c0c0c" }, { p: 1, c: "#000000" }]
    }

    // ── солнце ─────────────────────────────────────────────────
    // .sun radial-gradient + внешние box-shadow 36/80/150px
    readonly property var sunStops: [
        { p: 0, c: "#ffffff" }, { p: 0.52, c: "#ffffff" }, { p: 0.62, c: "#f7f7f7" },
        { p: 0.74, c: "rgba(255,255,255,0.70)" }, { p: 0.84, c: "rgba(255,255,255,0.20)" },
        { p: 0.94, c: "rgba(255,255,255,0.05)" }, { p: 1, c: "rgba(255,255,255,0)" }
    ]
    // 550px-бокс: свечение от края диска (125) до 125+150.
    // Начинается чуть внутри диска, чтобы не было тёмного зазора.
    readonly property var sunOuterStops: [
        { p: 0, c: "rgba(255,255,255,0)" }, { p: 0.30, c: "rgba(255,255,255,0)" },
        { p: 0.34, c: "rgba(255,255,255,0.50)" }, { p: 0.48, c: "rgba(255,255,255,0.24)" },
        { p: 0.64, c: "rgba(255,255,255,0.10)" }, { p: 0.82, c: "rgba(255,255,255,0.03)" },
        { p: 1, c: "rgba(255,255,255,0)" }
    ]
    // .sun-glow-outer 310px + blur(5px)
    readonly property var sunGlowStops: [
        { p: 0, c: "rgba(255,255,255,0.14)" }, { p: 0.46, c: "rgba(255,255,255,0.07)" },
        { p: 0.70, c: "rgba(255,255,255,0.02)" }, { p: 0.84, c: "rgba(255,255,255,0)" },
        { p: 1, c: "rgba(255,255,255,0)" }
    ]

    // ── луна и её гало ─────────────────────────────────────────
    // .moon-glow 360px — голубоватое кольцо 63..88%
    readonly property var moonGlowStops: [
        { p: 0, c: "rgba(255,255,255,0)" }, { p: 0.63, c: "rgba(255,255,255,0)" },
        { p: 0.68, c: "rgba(180,200,255,0.10)" }, { p: 0.73, c: "rgba(150,180,255,0.24)" },
        { p: 0.80, c: "rgba(170,200,255,0.12)" }, { p: 0.88, c: "rgba(255,255,255,0)" },
        { p: 1, c: "rgba(255,255,255,0)" }
    ]
    // .penumbra 300px — тёмная полутень (ребёнок луны)
    readonly property var penumbraStops: [
        { p: 0, c: "rgba(0,0,0,0.85)" }, { p: 0.46, c: "rgba(0,0,0,0.55)" },
        { p: 0.62, c: "rgba(0,0,0,0.28)" }, { p: 0.78, c: "rgba(0,0,0,0)" },
        { p: 1, c: "rgba(0,0,0,0)" }
    ]
    // .moon box-shadow 0 0 24px rgba(0,0,0,0.9) — тёмный ободок
    readonly property var moonDarkStops: [
        { p: 0, c: "rgba(0,0,0,0)" }, { p: 0.75, c: "rgba(0,0,0,0)" },
        { p: 0.78, c: "rgba(0,0,0,0.90)" }, { p: 0.95, c: "rgba(0,0,0,0.35)" },
        { p: 1, c: "rgba(0,0,0,0)" }
    ]

    // ── корона ─────────────────────────────────────────────────
    // .corona 260px (радиус 130) + внешние box-shadow:
    //   3/5 — 40/90px, 4 — 12/32/66px. Бокс 440px, чтобы свечение
    //   (130..220) не обрезалось диском луны (радиус 123).
    readonly property var coronaStops: ring
        ? [{ p: 0, c: "rgba(255,255,255,0)" }, { p: 0.54, c: "rgba(255,255,255,0)" },
           { p: 0.57, c: "rgba(255,255,255,0.30)" }, { p: 0.68, c: "rgba(255,255,255,0.16)" },
           { p: 0.85, c: "rgba(255,255,255,0.06)" }, { p: 1, c: "rgba(255,255,255,0)" }]
        : [{ p: 0, c: "rgba(255,255,255,0)" }, { p: 0.57, c: "rgba(255,255,255,0)" },
           { p: 0.60, c: "rgba(255,255,255,0.50)" }, { p: 0.67, c: "rgba(255,255,255,0.28)" },
           { p: 0.82, c: "rgba(255,255,255,0.12)" }, { p: 1, c: "rgba(255,255,255,0)" }]
    // .corona-glow 380px
    readonly property var coronaGlowStops: ring
        ? [{ p: 0, c: "rgba(255,255,255,0.06)" }, { p: 0.45, c: "rgba(255,255,255,0.06)" },
           { p: 0.72, c: "rgba(255,255,255,0)" }, { p: 1, c: "rgba(255,255,255,0)" }]
        : [{ p: 0, c: "rgba(255,255,255,0.16)" }, { p: 0.30, c: "rgba(255,255,255,0.16)" },
           { p: 0.52, c: "rgba(255,255,255,0.07)" }, { p: 0.74, c: "rgba(255,255,255,0)" },
           { p: 1, c: "rgba(255,255,255,0)" }]

    // ── горизонт ───────────────────────────────────────────────
    readonly property var horizonStops: [
        { p: 0, c: "rgba(255,255,255,0.26)" }, { p: 0.35, c: "rgba(255,255,255,0.09)" },
        { p: 0.70, c: "rgba(255,255,255,0)" }, { p: 1, c: "rgba(255,255,255,0)" }
    ]

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
                delay: rnd() * 4000,
                ph: rnd() * 6.28318
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
                delay: rnd() * 15000,
                ph: rnd() * 6.28318
            })
        }
        return a
    }
    // прогресс падения метеора (0..1) или -1, если он сейчас «спит».
    // Считается от общего времени сцены, а не анимацией на кадр.
    function meteorPhase(m) {
        var fall = Math.max(0.6, m.dur / 1000)
        var P = fall + 6.0 + (m.delay % 6000) / 1000
        var local = (scene.t + (m.delay % 9000) / 1000) % P
        return local < fall ? local / fall : -1
    }

    // цикл вспышки серпа: 2.5 с вспышка + пауза; k — прогресс 0..1 или -1
    function nfPhase() {
        var P = 6.7
        var local = scene.t % P
        return local > 2.5 ? -1 : local / 2.5
    }
    // кусочно-линейные кривые из CSS nightfallBurst: [opacity, scale]
    function nfVal(k) {
        var ks = [0, 0.14, 0.32, 0.55, 1.0]
        var os = [0, 1, 0.9, 0.55, 0]
        var ss = [0.7, 0.95, 1.22, 1.34, 1.45]
        for (var i = 0; i < ks.length - 1; i++) {
            if (k <= ks[i + 1]) {
                var f = (k - ks[i]) / (ks[i + 1] - ks[i])
                return [os[i] + (os[i + 1] - os[i]) * f, ss[i] + (ss[i + 1] - ss[i]) * f]
            }
        }
        return [0, 1.45]
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
            // мерцание считается от общего времени сцены (без анимации на кадр)
            opacity: {
                var hi = scene.totality ? Math.min(1, modelData.max * 1.5) : modelData.max
                var w = Math.PI / (modelData.dur / 1000)
                var k = 0.5 + 0.5 * Math.sin(scene.t * w + modelData.ph)
                return 0.1 + (hi - 0.1) * k
            }
        }
    }

    // ── космическая пыль (градиентная дымка + дрейф) ───────────
    Item {
        id: dustWrap
        anchors.fill: parent
        opacity: scene.dustOps[scene.p]
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: 1200 } }

        Canvas {
            id: dustHaze
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                function blob(fx, fy, col, rr) {
                    var g = ctx.createRadialGradient(fx * width, fy * height, 0, fx * width, fy * height, rr)
                    g.addColorStop(0, col)
                    g.addColorStop(1, "rgba(255,255,255,0)")
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
                blob(0.24, 0.28, "rgba(255,255,255,0.07)", width * 0.35)
                blob(0.78, 0.20, "rgba(230,238,255,0.05)", width * 0.32)
                blob(0.70, 0.72, "rgba(255,255,255,0.06)", width * 0.38)
                blob(0.18, 0.66, "rgba(220,232,255,0.04)", width * 0.32)
                blob(0.52, 0.42, "rgba(255,255,255,0.05)", width * 0.35)
            }
        }

        // лёгкое «дыхание» дымки от общего времени (без отдельной анимации)
        scale: 1 + 0.05 * (0.5 + 0.5 * Math.sin(scene.t * 0.9))
    }

    // ── пылинки (мелкие точки, дрейф) ──────────────────────────
    Repeater {
        model: (scene.live && scene.dustOps[scene.p] > 0) ? scene.dustData : []
        delegate: Rectangle {
            required property var modelData
            width: modelData.size
            height: modelData.size
            radius: width / 2
            color: "#ffffff"
            opacity: scene.live
                ? scene.dustOps[scene.p] * (0.12 + 0.12 * (0.5 + 0.5 * Math.sin(scene.t * 0.5 + modelData.ph)))
                : 0
            x: modelData.x * scene.width + modelData.drift * scene.unit * Math.sin(scene.t * 0.15 + modelData.ph)
            y: modelData.y * scene.height - 40 * scene.unit * (0.5 + 0.5 * Math.sin(scene.t * 0.12 + modelData.ph * 1.3))
        }
    }

    // ── горизонт (низ экрана) ──────────────────────────────────
    // Эллиптический радиальный градиент (как CSS ellipse at 50% 100%).
    Canvas {
        id: horizon
        x: 0
        y: 0
        width: scene.width
        height: scene.height
        opacity: scene.horizonOps[scene.p]
        visible: opacity > 0.001
        property int repaintKey: scene.p
        onRepaintKeyChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Behavior on opacity { NumberAnimation { duration: 900 } }
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var stops = scene.horizonStops
            var R = width * 0.62
            var squash = (height * 0.55) / R
            ctx.save()
            ctx.translate(width / 2, height)
            ctx.scale(1, squash)
            var g = ctx.createRadialGradient(0, 0, 0, 0, 0, R)
            for (var i = 0; i < stops.length; i++)
                g.addColorStop(stops[i].p, stops[i].c)
            ctx.fillStyle = g
            ctx.fillRect(-width, -height * 6, width * 2, height * 7)
            ctx.restore()
        }
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
            GradientStop { position: 0.5; color: "#E6FFFFFF" }
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
            readonly property real pr: (scene.live && scene.totality) ? scene.meteorPhase(modelData) : -1
            width: 2
            height: 2
            opacity: pr < 0 ? 0 : (pr < 0.1 ? pr / 0.1 : (pr > 0.6 ? (1 - pr) / 0.4 : 1))
            x: modelData.x * scene.width - 0.45 * scene.width * Math.max(0, pr)
            y: modelData.y * scene.height + 0.34 * scene.height * Math.max(0, pr)

            // хвост
            Rectangle {
                x: 1; y: -1
                width: 150 * scene.unit
                height: 2
                radius: 1
                rotation: -24
                transformOrigin: Item.Left
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#FFF0F8FF" }
                    GradientStop { position: 0.45; color: "#99BED7FF" }
                    GradientStop { position: 1; color: "#00BED7FF" }
                }
            }
            // головка с ореолом
            Rectangle {
                width: 3; height: 3; radius: 1.5; color: "#ffffff"
                x: -1; y: -1
            }
            Rectangle {
                width: 9; height: 9; radius: 4.5
                x: -4; y: -4
                color: "transparent"
                border.width: 2
                border.color: "#66BED7FF"
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

        // внешнее свечение солнца (box-shadow 36/80/150px)
        RadialCanvas {
            x: -275 * scene.unit
            y: -275 * scene.unit
            width: 550 * scene.unit
            height: 550 * scene.unit
            stops: scene.sunOuterStops
            opacity: scene.sunOps[scene.p]
            Behavior on opacity { NumberAnimation { duration: 700 } }
        }

        // мягкое внешнее дыхание солнца (.sun-glow-outer 310px)
        RadialCanvas {
            id: sunGlowOuter
            x: -155 * scene.unit
            y: -155 * scene.unit
            width: 310 * scene.unit
            height: 310 * scene.unit
            stops: scene.sunGlowStops
            opacity: scene.sunOps[scene.p]
            // дыхание солнца (период 5 с) от общего времени — без анимации на кадр
            scale: 1 + 0.045 * (0.5 + 0.5 * Math.sin(scene.t * 1.2566))
        }

        // гало короны (внешнее, .corona-glow 380px)
        RadialCanvas {
            id: coronaGlow
            x: -190 * scene.unit
            y: -190 * scene.unit
            width: 380 * scene.unit
            height: 380 * scene.unit
            stops: scene.coronaGlowStops
            opacity: scene.ring ? 0.9 : 0
            visible: opacity > 0.001
            Behavior on opacity { NumberAnimation { duration: 800 } }
        }

        // корона — кольцо вокруг луны (.corona 260px + внешнее свечение)
        RadialCanvas {
            id: corona
            x: -220 * scene.unit
            y: -220 * scene.unit
            width: 440 * scene.unit
            height: 440 * scene.unit
            stops: scene.coronaStops
            opacity: scene.ring ? 1 : 0
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

            // постоянное голубоватое гало (.moon-glow 360px)
            RadialCanvas {
                x: -180 * scene.unit
                y: -180 * scene.unit
                width: 360 * scene.unit
                height: 360 * scene.unit
                stops: scene.moonGlowStops
                opacity: scene.moonGlowOps[scene.p]
                Behavior on opacity { NumberAnimation { duration: 800 } }
            }
            // тёмная полутень (.penumbra 300px)
            RadialCanvas {
                x: -150 * scene.unit
                y: -150 * scene.unit
                width: 300 * scene.unit
                height: 300 * scene.unit
                stops: scene.penumbraStops
                opacity: scene.penumbraOps[scene.p]
                Behavior on opacity { NumberAnimation { duration: 800 } }
            }
            // тёмный ободок луны (box-shadow 0 0 24px black)
            RadialCanvas {
                x: -163 * scene.unit
                y: -163 * scene.unit
                width: 326 * scene.unit
                height: 326 * scene.unit
                stops: scene.moonDarkStops
                opacity: 0.55
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
