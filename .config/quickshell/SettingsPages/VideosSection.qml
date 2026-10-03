import "../"
import Quickshell

// ════════════════════════════════════════════════════════════════
//  VideosSection — видео из ~/Videos (сюда пишет запись экрана).
// ════════════════════════════════════════════════════════════════
MediaGrid {
    folders: [
        Quickshell.env("HOME") + "/Videos"
    ]
    videos: true
}
