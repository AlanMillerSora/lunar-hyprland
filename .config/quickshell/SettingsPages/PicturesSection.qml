import "../"
import Quickshell

// ════════════════════════════════════════════════════════════════
//  PicturesSection — картинки из ~/Pictures.
// ════════════════════════════════════════════════════════════════
MediaGrid {
    folders: [
        Quickshell.env("HOME") + "/Pictures"
    ]
    videos: false
}
