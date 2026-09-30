import "../"

// ════════════════════════════════════════════════════════════════
//  DevicesPage — устройства одной вкладкой (сегменты).
//  Разделы: MonitorsSection (дисплей, запись) и SoundSection (звук).
// ════════════════════════════════════════════════════════════════
SegmentedPage {
    items: [
        { label: "Дисплей", src: "MonitorsSection.qml" },
        { label: "Звук", src: "SoundSection.qml" }
    ]
}
