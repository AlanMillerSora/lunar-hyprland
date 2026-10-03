import "../"
import Quickshell

// ════════════════════════════════════════════════════════════════
//  ScreenshotsSection — скриншоты из ~/Pictures/Screenshots.
//  (PRINT и SUPER+SHIFT+PRINT складывают снимки сюда же.)
// ════════════════════════════════════════════════════════════════
MediaGrid {
    folders: [
        Quickshell.env("HOME") + "/Pictures/Screenshots"
    ]
    videos: false
}
