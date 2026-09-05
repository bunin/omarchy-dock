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

    function test_tooltipTextIsEmptyWithoutAnItem() {
        compare(DockMatcher.tooltipTextFor(null), "")
        compare(DockMatcher.tooltipTextFor(undefined), "")
    }

    function test_tooltipShowsTheAppNameWhenNotRunning() {
        compare(DockMatcher.tooltipTextFor({
            name: "Firefox", isRunning: false, windowCount: 0, toplevels: []
        }), "Firefox")
    }

    function test_tooltipShowsTheFolderNameForAStack() {
        compare(DockMatcher.tooltipTextFor({
            name: "Media", isStack: true, isRunning: true, windowCount: 3,
            toplevels: [{ title: "Some window" }]
        }), "Media")
    }

    function test_tooltipShowsTheWindowTitleForASingleWindow() {
        compare(DockMatcher.tooltipTextFor({
            name: "Firefox", isRunning: true, windowCount: 1,
            toplevels: [{ title: "Hyprland Wiki - Variables" }]
        }), "Hyprland Wiki - Variables")
    }

    function test_tooltipFallsBackToTheAppNameWhenTheTitleIsBlank_data() {
        return [
            { tag: "empty", title: "" },
            { tag: "whitespace", title: "   " },
            { tag: "missing", title: undefined }
        ]
    }

    function test_tooltipFallsBackToTheAppNameWhenTheTitleIsBlank(data) {
        compare(DockMatcher.tooltipTextFor({
            name: "Alacritty", isRunning: true, windowCount: 1,
            toplevels: [{ title: data.title }]
        }), "Alacritty")
    }

    function test_tooltipCountsWindowsInsteadOfPickingOneTitle() {
        compare(DockMatcher.tooltipTextFor({
            name: "Nautilus", isRunning: true, windowCount: 3,
            toplevels: [{ title: "Home" }, { title: "Downloads" }, { title: "Music" }]
        }), "Nautilus \u00b7 3 windows")
    }

    function test_tooltipUsesTheSingularCountLabelDefensively() {
        // windowCount disagreeing with toplevels.length must not read as "1 windows"
        compare(DockMatcher.tooltipTextFor({
            name: "Slack", isRunning: true, windowCount: 2, toplevels: []
        }), "Slack \u00b7 2 windows")
    }

    function test_tooltipTruncatesOverlongTitles() {
        var long = "A window title that runs on well past what any sensible tooltip should ever display"
        var out = DockMatcher.tooltipTextFor({
            name: "Editor", isRunning: true, windowCount: 1, toplevels: [{ title: long }]
        })
        compare(out.length, 60)
        compare(out.charAt(59), "\u2026")
        compare(out.slice(0, 59), long.slice(0, 59))
    }

    function test_tooltipLeavesTitlesAtTheLimitAlone() {
        var exact = new Array(61).join("x") // 60 chars
        compare(exact.length, 60)
        compare(DockMatcher.tooltipTextFor({
            name: "Editor", isRunning: true, windowCount: 1, toplevels: [{ title: exact }]
        }), exact)
    }

    function test_sameDockItemMatchesTheIdenticalObject() {
        var item = { id: "firefox", appId: "firefox" }
        verify(DockMatcher.isSameDockItem(item, item))
    }

    function test_sameDockItemMatchesARebuiltCopyById() {
        verify(DockMatcher.isSameDockItem({ id: "firefox" }, { id: "firefox" }))
    }

    function test_sameDockItemFallsBackToAppId() {
        verify(DockMatcher.isSameDockItem({ appId: "slack" }, { appId: "slack" }))
    }

    function test_differentDockItemsDoNotMatch() {
        verify(!DockMatcher.isSameDockItem({ id: "firefox" }, { id: "slack" }))
    }

    function test_dockItemsWithoutIdentityNeverMatch() {
        // Two anonymous objects must not be treated as the same icon, or one
        // icon's exit would cancel another icon's tooltip.
        verify(!DockMatcher.isSameDockItem({}, {}))
        verify(!DockMatcher.isSameDockItem({ id: "" }, { id: "" }))
    }

    function test_sameDockItemHandlesMissingOperands() {
        verify(!DockMatcher.isSameDockItem(null, { id: "firefox" }))
        verify(!DockMatcher.isSameDockItem({ id: "firefox" }, null))
        verify(!DockMatcher.isSameDockItem(null, null))
    }

    function test_dockItemStillPresentTracksTheRebuiltDock() {
        var firefox = { id: "firefox" }
        var slack = { id: "slack" }
        verify(DockMatcher.dockItemStillPresent(firefox, [slack, firefox]))
        verify(!DockMatcher.dockItemStillPresent(firefox, [slack]))
    }

    // The Repeater hands out fresh objects on every rebuild, so identity has to
    // go through isSameDockItem rather than ===.
    function test_dockItemStillPresentMatchesARebuiltCopy() {
        verify(DockMatcher.dockItemStillPresent({ id: "firefox" }, [{ id: "firefox" }]))
        verify(DockMatcher.dockItemStillPresent({ appId: "slack" }, [{ appId: "slack" }]))
    }

    function test_dockItemStillPresentOnAnEmptyOrMissingDock_data() {
        return [
            { tag: "empty", items: [] },
            { tag: "null", items: null },
            { tag: "undefined", items: undefined },
            { tag: "not-a-list", items: 3 }
        ]
    }

    function test_dockItemStillPresentOnAnEmptyOrMissingDock(data) {
        verify(!DockMatcher.dockItemStillPresent({ id: "firefox" }, data.items))
    }

    function test_dockItemStillPresentWithoutAnItem() {
        verify(!DockMatcher.dockItemStillPresent(null, [{ id: "firefox" }]))
        verify(!DockMatcher.dockItemStillPresent(undefined, [{ id: "firefox" }]))
    }
}
