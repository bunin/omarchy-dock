import QtQuick
import QtTest
import "../DockMatcher.js" as DockMatcher

TestCase {
    name: "DockMatcher"

    function test_stripDesktop() {
        compare(DockMatcher.stripDesktop("google-chrome.desktop"), "google-chrome")
        compare(DockMatcher.stripDesktop("Photoshop.exe"), "Photoshop")
        compare(DockMatcher.stripDesktop("code"), "code")
        compare(DockMatcher.stripDesktop(""), "")
    }

    function test_desktopEntryIndex_fastLookup() {
        var mockEntries = [
            { id: "google-chrome.desktop", name: "Google Chrome", exec: "/usr/bin/google-chrome-stable", icon: "google-chrome" },
            { id: "org.kde.dolphin.desktop", name: "Dolphin", exec: "dolphin %u", icon: "system-file-manager" },
            { id: "com.mitchellh.ghostty.desktop", name: "Ghostty", exec: "ghostty", icon: "com.mitchellh.ghostty" }
        ]

        var index = DockMatcher.createDesktopEntryIndex(mockEntries)
        verify(index != null)

        // Exact ID lookup O(1)
        var chromeEntry = DockMatcher.findEntryFast(index, "google-chrome")
        verify(chromeEntry != null)
        compare(chromeEntry.name, "Google Chrome")

        // Exact Name lookup O(1)
        var dolphinEntry = DockMatcher.findEntryFast(index, "dolphin")
        verify(dolphinEntry != null)
        compare(dolphinEntry.id, "org.kde.dolphin.desktop")

        // Exec binary lookup O(1)
        var ghosttyEntry = DockMatcher.findEntryFast(index, "ghostty")
        verify(ghosttyEntry != null)
        compare(ghosttyEntry.name, "Ghostty")
    }

    function test_collectMatchingToplevels_activeAndMinimized() {
        var top1 = { appId: "google-chrome", title: "GitHub - Omarchy Dock" }
        var top2 = { appId: "google-chrome", title: "YouTube" }
        var toplevels = [top1, top2]
        var assigned = {}

        // Mock min check: top1 is not min, top2 is min
        var isMin = function(top) { return top === top2 }

        var res = DockMatcher.collectMatchingToplevels(
            "google-chrome",
            { id: "google-chrome.desktop", name: "Google Chrome", icon: "google-chrome" },
            [],
            toplevels,
            assigned,
            null,
            top1, // active top
            isMin,
            null
        )

        compare(res.windowCount, 2)
        compare(res.isActive, true)
        compare(res.isMinimized, false)
        compare(res.activeTopIndex, 0)

        // All minimized scenario
        var assigned2 = {}
        var isAllMin = function(top) { return true }
        var resAllMin = DockMatcher.collectMatchingToplevels(
            "google-chrome",
            { id: "google-chrome.desktop", name: "Google Chrome", icon: "google-chrome" },
            [],
            toplevels,
            assigned2,
            null,
            top1,
            isAllMin,
            null
        )

        compare(resAllMin.windowCount, 2)
        compare(resAllMin.isActive, false) // Minimized cannot be active
        compare(resAllMin.isMinimized, true)
    }
}
