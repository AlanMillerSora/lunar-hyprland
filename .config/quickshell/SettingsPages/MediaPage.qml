import "../"

// ════════════════════════════════════════════════════════════════
//  MediaPage — вкладка Media: мои файлы одной вкладкой (сегменты).
//  СКРИНШОТЫ (~/Pictures/Screenshots) · КАРТИНКИ (~/Pictures) ·
//  ВИДЕО (~/Videos). Клик по миниатюре открывает файл xdg-open.
// ════════════════════════════════════════════════════════════════
SegmentedPage {
    items: [
        { label: "Скриншоты", src: "ScreenshotsSection.qml" },
        { label: "Картинки", src: "PicturesSection.qml" },
        { label: "Видео", src: "VideosSection.qml" }
    ]
}
