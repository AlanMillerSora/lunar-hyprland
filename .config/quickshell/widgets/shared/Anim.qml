import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  Anim — единый диспетчер анимаций (порт Material-3 Expressive).
//  Внутри рис задаю характер движения в одном месте: spatial (движение
//  и размер, с лёгким перелётом) и effects (прозрачность/цвет, без).
//
//  Использование:
//    Behavior on scale { Anim {} }                       // по умолчанию spatial
//    Anim { target: foo; property: "opacity"; to: 0; type: Anim.FastEffects }
//
//  Типы: Standard*/Emphasized* и Fast/Default/Slow Spatial/Effects.
// ════════════════════════════════════════════════════════════════
NumberAnimation {
    enum Type {
        StandardSmall = 0,
        Standard,
        StandardLarge,
        StandardExtraLarge,
        EmphasizedSmall,
        Emphasized,
        EmphasizedLarge,
        EmphasizedExtraLarge,
        FastSpatial,
        DefaultSpatial,
        SlowSpatial,
        FastEffects,
        DefaultEffects,
        SlowEffects
    }

    property int type: Anim.DefaultSpatial

    duration: {
        if (type === Anim.FastSpatial)
            return Theme.anim.fastSpatial
        if (type === Anim.DefaultSpatial)
            return Theme.anim.defaultSpatial
        if (type === Anim.SlowSpatial)
            return Theme.anim.slowSpatial
        if (type === Anim.FastEffects)
            return Theme.anim.fastEffects
        if (type === Anim.DefaultEffects)
            return Theme.anim.defaultEffects
        if (type === Anim.SlowEffects)
            return Theme.anim.slowEffects

        const types = ["small", "normal", "large", "extraLarge"]
        const idx = type % 4 // 0-7 — четыре размера standard/emphasized
        return Theme.anim[types[idx]]
    }
    easing.type: Easing.BezierSpline
    easing.bezierCurve: {
        if (type === Anim.FastSpatial)
            return Theme.anim.expressiveFastSpatial
        if (type === Anim.DefaultSpatial)
            return Theme.anim.expressiveDefaultSpatial
        if (type === Anim.SlowSpatial)
            return Theme.anim.expressiveSlowSpatial
        if (type === Anim.FastEffects)
            return Theme.anim.expressiveFastEffects
        if (type === Anim.DefaultEffects)
            return Theme.anim.expressiveDefaultEffects
        if (type === Anim.SlowEffects)
            return Theme.anim.expressiveSlowEffects

        if (type >= Anim.EmphasizedSmall && type <= Anim.EmphasizedExtraLarge)
            return Theme.anim.emphasized
        return Theme.anim.standard
    }
}
