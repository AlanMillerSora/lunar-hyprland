import "../"

// ════════════════════════════════════════════════════════════════
//  InterfacePage — интерфейс, бар и аватар одной вкладкой (сегменты).
//  Разделы: InterfaceSection (вид/обои), BarSection (состав бара)
//  и UserPage (аватар).
// ════════════════════════════════════════════════════════════════
SegmentedPage {
    items: [
        { label: "Интерфейс", src: "InterfaceSection.qml" },
        { label: "Бар", src: "BarSection.qml" },
        { label: "Аватар", src: "UserPage.qml" }
    ]
}
