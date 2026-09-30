import "../"

// ════════════════════════════════════════════════════════════════
//  NetworkPage — сеть и Bluetooth одной вкладкой (сегменты).
//  Разделы: NetworkSection (сеть) и BluetoothPage.
// ════════════════════════════════════════════════════════════════
SegmentedPage {
    items: [
        { label: "Сеть", src: "NetworkSection.qml" },
        { label: "Bluetooth", src: "BluetoothPage.qml" }
    ]
}
