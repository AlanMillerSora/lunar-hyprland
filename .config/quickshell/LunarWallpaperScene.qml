import QtQuick

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
//  Фаза 1..9 (по активному столу), все зеркально симметричны (1↔9,
//  2↔8, 3↔7, 4↔6):
//    · луна едет слева направо;
//    · 5 — ПОЛНОЕ затмение: тонкая корона, свечение горизонта, пыль, метеоры;
//    · чем дальше от 5, тем бледнее гало и полутень.
//  live=false — «лёгкий режим»: без звёзд/метеоров/пыли.
//  optimize=true — реже звёзды, без пыли/метеоров и «дыхания» (см. LunarWallpaper).
// ════════════════════════════════════════════════════════════════
Item {
    id: scene

    property int phase: 5
    property bool live: true
    // OPTIMIZE: небо реже, без пыли/метеоров/«дыхания» (см. LunarWallpaper).
    property bool optimize: false

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
    // Все фазы симметричны относительно центра (5): 1↔9, 2↔8, 3↔7, 4↔6.
    // Эталон зеркальных пар — правая сторона (6..9). Полное затмение
    // (кольцо, метеоры, пыль, свечение горизонта) — фаза 5.
    readonly property var moonOffsets: [0, -339, -288, -230, -107, 0, 107, 230, 288, 339]
    readonly property var sunOps:      [0, 1, 1, 0.95, 0.88, 0.95, 0.88, 0.95, 1, 1]
    readonly property var moonGlowOps: [0, 0.2, 0, 0.2, 0.35, 0.22, 0.35, 0.2, 0, 0.2]
    readonly property var penumbraOps: [0, 0.5, 0, 0.5, 0.9, 1, 0.9, 0.5, 0, 0.5]
    readonly property var dustOps:     [0, 0, 0, 0, 0, 0.9, 0, 0, 0, 0]
    readonly property var horizonOps:  [0, 0, 0, 0, 0, 1, 0, 0, 0, 0]

    readonly property bool fullEclipse: p === 5

    // На пике солнце скрыто луной — его широкое внешнее свечение глушим,
    // чтобы «шуба» не спорила с тонкой короной (иначе видны ступени).
    readonly property real sunHaloMask: fullEclipse ? 0.35 : 1.0

    // ═══════════════ фон по фазам (CSS #eclipse-bg) ═══════════════
    function bgStops(ph) {
        switch (ph) {
        case 1: case 9:
            return [{ p: 0, c: "#10151c" }, { p: 0.6, c: "#05070c" }, { p: 1, c: "#000000" }]
        case 2: case 8:
            return [{ p: 0, c: "#0d1218" }, { p: 0.65, c: "#04060a" }, { p: 1, c: "#000000" }]
        case 3: case 4: case 6: case 7:
            return [{ p: 0, c: "#0e1018" }, { p: 0.6, c: "#06070d" }, { p: 1, c: "#000000" }]
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
    // .moon-glow 360px — нейтральное (монохром) кольцо 63..88%
    readonly property var moonGlowStops: [
        { p: 0, c: "rgba(255,255,255,0)" }, { p: 0.63, c: "rgba(255,255,255,0)" },
        { p: 0.68, c: "rgba(255,255,255,0.10)" }, { p: 0.73, c: "rgba(235,240,250,0.22)" },
        { p: 0.80, c: "rgba(255,255,255,0.10)" }, { p: 0.88, c: "rgba(255,255,255,0)" },
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
    // Рисуется отдельным Canvas-компонентом (см. CoronaCanvas ниже):
    // тонкое монохромное кольцо у края диска + плавный спад наружу.
    // Прежние слои corona/corona-glow давали видимые ступени.


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
        for (var i = 0; i < 170; i++) {
            a.push({
                x: rnd(), y: rnd(),
                size: rnd() < 0.07 ? 2 : 1,
                dur: 1600 + rnd() * 5200,
                max: 0.25 + rnd() * 0.75,
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
        for (var i = 0; i < 20; i++) {
            a.push({
                x: rnd(), y: rnd(),
                size: 1 + rnd() * 2.2,
                dur: 9000 + rnd() * 22000,
                drift: rnd() * 140 - 70,
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

    readonly property var starData: makeStars()
    readonly property var meteorData: makeMeteors()
    readonly property var dustData: makeDust()

    // OPTIMIZE: та же карта неба, но каждая третья звезда — небо реже.
    readonly property var starDataOpt: {
        var a = []
        for (var i = 0; i < starData.length; i += 3)
            a.push(starData[i])
        return a
    }

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

    // ── корона (Canvas) ────────────────────────────────────────
    // Тонкое монохромное кольцо у края диска луны плюс гладкий спад
    // наружу. Профиль считается по формуле и раскладывается в 96 стопов
    // градиента — без резких ступеней и наложений слоёв, которые давали
    // видимые «белые» кольца. Лёгкий псевдослучайный разброс стопов
    // дополнительно маскирует 8-битный бандинг.
    component CoronaCanvas: Canvas {
        id: cc
        property real moonR: 123 * scene.unit
        property real ringW: 10 * scene.unit
        property real ringA: 0.85
        property real glowA: 0.28
        property real glowK: 62 * scene.unit
        readonly property int steps: 96

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onMoonRChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var R = Math.max(width, height) / 2
            var cx = width / 2, cy = height / 2
            var g = ctx.createRadialGradient(cx, cy, 0, cx, cy, R)
            var n = cc.steps
            var s = 2654435761
            function hash() { s = (s * 1103515245 + 12345) % 2147483648; return s / 2147483648 }
            for (var i = 0; i <= n; i++) {
                var p = i / n
                var r = p * R
                var a
                if (r < cc.moonR) {
                    a = 0
                } else {
                    var d = r - cc.moonR
                    a = cc.ringA * Math.exp(-Math.pow(d / cc.ringW, 2))
                      + cc.glowA * Math.exp(-d / cc.glowK)
                    // плавно в ноль к краю бокса (иначе видна кромка)
                    var t = Math.min(1, Math.max(0, (p - 0.5) / 0.5))
                    a *= 1 - t * t * (3 - 2 * t)
                    // разброс против идеально ровных колец
                    a *= 0.98 + 0.04 * hash()
                }
                g.addColorStop(p, "rgba(255,255,255," + a.toFixed(4) + ")")
            }
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
        model: scene.live ? (scene.optimize ? scene.starDataOpt : scene.starData) : []
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
                var hi = scene.fullEclipse ? Math.min(1, modelData.max * 1.5) : modelData.max
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
        opacity: scene.optimize ? 0 : scene.dustOps[scene.p]
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
                blob(0.78, 0.20, "rgba(245,248,255,0.05)", width * 0.32)
                blob(0.70, 0.72, "rgba(255,255,255,0.06)", width * 0.38)
                blob(0.18, 0.66, "rgba(240,245,255,0.04)", width * 0.32)
                blob(0.52, 0.42, "rgba(255,255,255,0.05)", width * 0.35)
            }
        }

        // лёгкое «дыхание» дымки убрано: масштаб полноэкранного слоя
        // заставлял перерисовывать весь кадр каждый тик. Дымка статична,
        // живость дают дрейфующие пылинки и мерцание звёзд.
        scale: 1
    }

    // ── пылинки (мелкие точки, дрейф) ──────────────────────────
    Repeater {
        model: (scene.live && !scene.optimize && scene.dustOps[scene.p] > 0) ? scene.dustData : []
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

    // ── метеоры (только полное затмение, фаза 5) ───────────────
    Repeater {
        model: (scene.live && !scene.optimize && scene.fullEclipse) ? scene.meteorData : []
        delegate: Item {
            required property var modelData
            readonly property real pr: (scene.live && scene.fullEclipse) ? scene.meteorPhase(modelData) : -1
            width: 2
            height: 2
            opacity: pr < 0 ? 0 : (pr < 0.1 ? pr / 0.1 : (pr > 0.6 ? (1 - pr) / 0.4 : 1))
            x: modelData.x * scene.width - 0.45 * scene.width * Math.max(0, pr)
            y: modelData.y * scene.height + 0.34 * scene.height * Math.max(0, pr)

            // хвост (монохром)
            Rectangle {
                x: 1; y: -1
                width: 150 * scene.unit
                height: 2
                radius: 1
                rotation: -24
                transformOrigin: Item.Left
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#FFFFFFFF" }
                    GradientStop { position: 0.45; color: "#99FFFFFF" }
                    GradientStop { position: 1; color: "#00FFFFFF" }
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
                border.color: "#66FFFFFF"
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

        // внешнее свечение солнца (box-shadow 36/80/150px).
        // На пике солнце скрыто — глушим (sunHaloMask), иначе «шуба».
        RadialCanvas {
            x: -275 * scene.unit
            y: -275 * scene.unit
            width: 550 * scene.unit
            height: 550 * scene.unit
            stops: scene.sunOuterStops
            opacity: scene.sunOps[scene.p] * scene.sunHaloMask
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
            opacity: scene.sunOps[scene.p] * scene.sunHaloMask
            // дыхание солнца (период 5 с) от общего времени — без анимации на кадр.
            // В OPTIMIZE дыхание выключено: меньше перерисовок.
            scale: scene.optimize ? 1 : 1 + 0.045 * (0.5 + 0.5 * Math.sin(scene.t * 1.2566))
        }

        // корона — тонкое кольцо вокруг луны (Canvas, без ступеней)
        CoronaCanvas {
            id: corona
            x: -300 * scene.unit
            y: -300 * scene.unit
            width: 600 * scene.unit
            height: 600 * scene.unit
            opacity: scene.fullEclipse ? 1 : 0
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
    }
}
