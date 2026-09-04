import QtQuick
import QtTest
import "../DockSettings.js" as DockSettings

TestCase {
    name: "DockSettings"

    function test_defaultsPreserveCurrentBehavior() {
        var settings = DockSettings.normalize({})
        compare(settings.visibilityMode, "always")
        compare(settings.overlayMode, false)
        compare(settings.visibleWorkspace, "all")
    }

    function test_legacyAutohideMigration_data() {
        return [
            { tag: "disabled", autohide: false, expected: "always" },
            { tag: "enabled", autohide: true, expected: "hover" }
        ]
    }

    function test_legacyAutohideMigration(data) {
        compare(DockSettings.normalize({ autohide: data.autohide }).visibilityMode, data.expected)
    }

    function test_explicitVisibilityModeWinsOverLegacyValue() {
        compare(DockSettings.normalize({ visibilityMode: "keybind", autohide: false }).visibilityMode, "keybind")
    }

    function test_invalidEnumsFallBackSafely() {
        var settings = DockSettings.normalize({
            visibilityMode: "invalid",
            autohide: true,
            spaceMode: "invalid"
        })
        compare(settings.visibilityMode, "hover")
        compare(settings.overlayMode, false)
    }

    function test_nativeOverlayModeWinsOverLegacySpaceMode() {
        compare(DockSettings.normalize({ overlayMode: true, spaceMode: "exclusive" }).overlayMode, true)
        compare(DockSettings.normalize({ overlayMode: false, spaceMode: "overlay" }).overlayMode, false)
    }

    function test_legacySpaceModeMigration() {
        compare(DockSettings.normalize({ spaceMode: "overlay" }).overlayMode, true)
        compare(DockSettings.normalize({ spaceMode: "exclusive" }).overlayMode, false)
    }

    function test_workspaceNormalization_data() {
        return [
            { tag: "missing", input: undefined, expected: "all" },
            { tag: "empty", input: "  ", expected: "all" },
            { tag: "all-case", input: "ALL", expected: "all" },
            { tag: "numeric", input: 3, expected: "3" },
            { tag: "named", input: " special:scratch ", expected: "special:scratch" }
        ]
    }

    function test_workspaceNormalization(data) {
        compare(DockSettings.normalizeVisibleWorkspace(data.input), data.expected)
    }

    function test_legacyAutohideSerialization_data() {
        return [
            { tag: "always", mode: "always", expected: false },
            { tag: "hover", mode: "hover", expected: true },
            { tag: "keybind", mode: "keybind", expected: true }
        ]
    }

    function test_legacyAutohideSerialization(data) {
        compare(DockSettings.legacyAutohide(data.mode), data.expected)
    }

    function test_workspaceMatching() {
        verify(DockSettings.workspaceMatches("all", 1, "1"))
        verify(DockSettings.workspaceMatches("2", 2, "2"))
        verify(DockSettings.workspaceMatches("0", 10, "10"))
        verify(DockSettings.workspaceMatches("10", 10, "10"))
        verify(DockSettings.workspaceMatches("special:scratch", -99, "special:scratch"))
        verify(!DockSettings.workspaceMatches("3", 2, "2"))
    }

    function test_keyboardToggleWorkspacePrefersFocusedMonitor() {
        var emptyWorkspace = { id: 4, name: "4", active: true }
        var staleToplevelWorkspace = { id: 2, name: "2", active: true }

        var selected = DockSettings.keyboardToggleWorkspace(
            emptyWorkspace,
            staleToplevelWorkspace,
            staleToplevelWorkspace
        )

        compare(selected, emptyWorkspace)
    }

    function test_keyboardToggleWorkspaceFallbacks() {
        var focusedWorkspace = { id: 3, name: "3", active: true }
        var toplevelWorkspace = { id: 2, name: "2", active: true }

        compare(DockSettings.keyboardToggleWorkspace(null, focusedWorkspace, toplevelWorkspace), focusedWorkspace)
        compare(DockSettings.keyboardToggleWorkspace(null, null, toplevelWorkspace), toplevelWorkspace)
        compare(DockSettings.keyboardToggleWorkspace(null, null, null), null)
    }

    function test_visibilityState_data() {
        return [
            { tag: "always-follow", mode: "always", override: 0, active: false, empty: false, hidden: false },
            { tag: "always-keybind-hidden", mode: "always", override: -1, active: false, empty: false, hidden: true },
            { tag: "always-keybind-shown", mode: "always", override: 1, active: false, empty: false, hidden: false },
            { tag: "hover-active", mode: "hover", override: 0, active: true, empty: false, hidden: false },
            { tag: "hover-inactive", mode: "hover", override: 0, active: false, empty: false, hidden: true },
            { tag: "hover-empty", mode: "hover", override: 0, active: false, empty: true, hidden: false },
            { tag: "hover-keybind-hidden", mode: "hover", override: -1, active: true, empty: true, hidden: true },
            { tag: "hover-keybind-shown", mode: "hover", override: 1, active: false, empty: false, hidden: false },
            { tag: "keybind-follow", mode: "keybind", override: 0, active: true, empty: true, hidden: true },
            { tag: "keybind-shown", mode: "keybind", override: 1, active: false, empty: false, hidden: false }
        ]
    }

    function test_visibilityState(data) {
        compare(DockSettings.shouldSlideOut(data.mode, data.override, data.active, data.empty), data.hidden)
    }

    function test_keyboardToggleAvailability_data() {
        return [
            { tag: "autohide-disabled", mode: "always", expected: true },
            { tag: "screen-edge-hover", mode: "hover", expected: false },
            { tag: "keyboard-shortcut", mode: "keybind", expected: true }
        ]
    }

    function test_keyboardToggleAvailability(data) {
        compare(DockSettings.keyboardToggleAllowed(data.mode), data.expected)
    }

    function test_revealRequestAvailability() {
        verify(!DockSettings.revealRequestAllowed("hover", "keyboard"))
        verify(DockSettings.revealRequestAllowed("hover", "internal"))
        verify(DockSettings.revealRequestAllowed("keybind", "keyboard"))
        verify(DockSettings.revealRequestAllowed("always", "keyboard"))
    }

    function test_keyboardAutoDismiss_data() {
        return [
            { tag: "always-shown", mode: "always", override: 1, expected: false },
            { tag: "hover-shown", mode: "hover", override: 1, expected: false },
            { tag: "keybind-follow", mode: "keybind", override: 0, expected: false },
            { tag: "keybind-shown", mode: "keybind", override: 1, expected: true }
        ]
    }

    function test_keyboardAutoDismiss(data) {
        compare(DockSettings.shouldAutoDismissKeyboardReveal(data.mode, data.override), data.expected)
    }

    function test_interactionRevealRelease() {
        compare(DockSettings.releaseInteractionVisibilityOverride(true, 0, 1), 0)
        compare(DockSettings.releaseInteractionVisibilityOverride(true, -1, 1), -1)
        compare(DockSettings.releaseInteractionVisibilityOverride(false, 0, 1), 1)
        compare(DockSettings.releaseInteractionVisibilityOverride(false, 0, -1), -1)
    }

    function test_dockScreenTarget_data() {
        return [
            { tag: "explicit-workspace", workspace: "7", mode: "hover", override: 0, expected: "configured" },
            { tag: "hover-all", workspace: "all", mode: "hover", override: 0, expected: "all" },
            { tag: "hover-all-hidden", workspace: "all", mode: "hover", override: -1, expected: "all" },
            { tag: "keybind-follow", workspace: "all", mode: "keybind", override: 0, expected: "all" },
            { tag: "always-follow", workspace: "all", mode: "always", override: 0, expected: "all" }
        ]
    }

    function test_dockScreenTarget(data) {
        compare(DockSettings.dockScreenTarget(data.workspace, data.mode, data.override), data.expected)
    }

    function test_screenShowsDock_data() {
        return [
            { tag: "all-any-screen", target: "all", screen: "DP-1", configured: "eDP-1", captured: "", focused: "eDP-1", expected: true },
            { tag: "configured-match", target: "configured", screen: "eDP-1", configured: "eDP-1", captured: "", focused: "DP-1", expected: true },
            { tag: "configured-miss", target: "configured", screen: "DP-1", configured: "eDP-1", captured: "", focused: "DP-1", expected: false },
            { tag: "focused-match", target: "focused", screen: "DP-1", configured: "", captured: "", focused: "DP-1", expected: true },
            { tag: "focused-miss", target: "focused", screen: "eDP-1", configured: "", captured: "", focused: "DP-1", expected: false },
            { tag: "missing-screen", target: "all", screen: "", configured: "", captured: "", focused: "DP-1", expected: false }
        ]
    }

    function test_screenShowsDock(data) {
        compare(DockSettings.screenShowsDock(data.target, data.screen, data.configured, data.captured, data.focused), data.expected)
    }

    function test_visibleDockClosesWithoutRetargeting() {
        var focusedWorkspace = { id: 2, name: "2", active: true }
        var decision = DockSettings.keyboardToggleDecision(true, "all", focusedWorkspace, null)

        compare(decision.action, "hide")
        compare(decision.targetWorkspace, "")
    }

    function test_hiddenDockCapturesFocusedWorkspaceForAll() {
        var focusedWorkspace = { id: 3, name: "3", active: true }
        var decision = DockSettings.keyboardToggleDecision(false, "all", focusedWorkspace, null)

        compare(decision.action, "show")
        compare(decision.targetWorkspace, "3")
    }

    function test_explicitWorkspaceDoesNotFollowFocus() {
        var focusedWorkspace = { id: 3, name: "3", active: true }
        var configuredWorkspace = { id: 7, name: "7", active: true }
        var decision = DockSettings.keyboardToggleDecision(false, "7", focusedWorkspace, configuredWorkspace)

        compare(decision.action, "show")
        compare(decision.targetWorkspace, "7")
    }

    function test_inactiveExplicitWorkspaceDoesNotOpen() {
        var focusedWorkspace = { id: 3, name: "3", active: true }
        var configuredWorkspace = { id: 7, name: "7", active: false }
        var decision = DockSettings.keyboardToggleDecision(false, "7", focusedWorkspace, configuredWorkspace)

        compare(decision.action, "workspace-inactive")
        compare(decision.targetWorkspace, "")
    }

    function test_missingWorkspaceDoesNotOpen() {
        var decision = DockSettings.keyboardToggleDecision(false, "all", null, null)

        compare(decision.action, "workspace-unavailable")
        compare(decision.targetWorkspace, "")
    }

    function test_dockPositionDefaultsToAuto() {
        compare(DockSettings.normalize({}).dockPosition, "auto")
    }

    function test_dockPositionNormalization_data() {
        return [
            { tag: "auto", value: "auto", expected: "auto" },
            { tag: "top", value: "top", expected: "top" },
            { tag: "bottom", value: "bottom", expected: "bottom" },
            { tag: "left", value: "left", expected: "left" },
            { tag: "right", value: "right", expected: "right" },
            { tag: "uppercase", value: "LEFT", expected: "left" },
            { tag: "padded", value: "  right  ", expected: "right" },
            { tag: "garbage", value: "diagonal", expected: "auto" },
            { tag: "empty", value: "", expected: "auto" },
            { tag: "null", value: null, expected: "auto" },
            { tag: "numeric", value: 3, expected: "auto" }
        ]
    }

    function test_dockPositionNormalization(data) {
        compare(DockSettings.normalizeDockPosition(data.value), data.expected)
        compare(DockSettings.normalize({ dockPosition: data.value }).dockPosition, data.expected)
    }

    function test_oppositeEdge_data() {
        return [
            { tag: "top", edge: "top", expected: "bottom" },
            { tag: "bottom", edge: "bottom", expected: "top" },
            { tag: "left", edge: "left", expected: "right" },
            { tag: "right", edge: "right", expected: "left" },
            { tag: "garbage", edge: "nonsense", expected: "top" }
        ]
    }

    function test_oppositeEdge(data) {
        compare(DockSettings.oppositeEdge(data.edge), data.expected)
    }

    function test_autoPositionSitsOppositeTheBar_data() {
        return [
            { tag: "bar-top", bar: "top", expected: "bottom" },
            { tag: "bar-bottom", bar: "bottom", expected: "top" },
            { tag: "bar-left", bar: "left", expected: "right" },
            { tag: "bar-right", bar: "right", expected: "left" }
        ]
    }

    function test_autoPositionSitsOppositeTheBar(data) {
        compare(DockSettings.resolveDockEdge("auto", data.bar), data.expected)
    }

    function test_explicitPositionIgnoresTheBar_data() {
        return [
            { tag: "left-under-top-bar", configured: "left", bar: "top", expected: "left" },
            { tag: "top-under-top-bar", configured: "top", bar: "top", expected: "top" },
            { tag: "bottom-under-left-bar", configured: "bottom", bar: "left", expected: "bottom" },
            { tag: "right-under-right-bar", configured: "right", bar: "right", expected: "right" }
        ]
    }

    function test_explicitPositionIgnoresTheBar(data) {
        compare(DockSettings.resolveDockEdge(data.configured, data.bar), data.expected)
    }

    function test_invalidConfiguredPositionFallsBackToAutoBehavior() {
        compare(DockSettings.resolveDockEdge("diagonal", "top"), "bottom")
    }

    function test_autoPositionFallsBackToTheDockDefaultForAnUnknownBar_data() {
        return [
            { tag: "missing", bar: undefined, expected: "bottom" },
            { tag: "null", bar: null, expected: "bottom" },
            { tag: "empty", bar: "   ", expected: "bottom" },
            { tag: "typo", bar: "botom", expected: "bottom" },
            { tag: "numeric", bar: 3, expected: "bottom" }
        ]
    }

    function test_autoPositionFallsBackToTheDockDefaultForAnUnknownBar(data) {
        compare(DockSettings.resolveDockEdge("auto", data.bar), data.expected)
    }

    function test_dockNeverSharesEdgeWithAnUnknownBar_data() {
        return [
            { tag: "missing", bar: undefined },
            { tag: "null", bar: null },
            { tag: "empty", bar: "   " },
            { tag: "typo", bar: "botom" }
        ]
    }

    function test_dockNeverSharesEdgeWithAnUnknownBar(data) {
        compare(DockSettings.sharesEdgeWithBar("bottom", data.bar), false)
        compare(DockSettings.sharesEdgeWithBar("top", data.bar), false)
    }

    // barClearanceFor(configuredPosition, barPosition, barSize, barHidden,
    //                 dockDeclaresExclusiveZone)
    function test_barClearanceOnlyAppliesWhenTheDockIgnoresExclusiveZones_data() {
        return [
            { tag: "ignore-zone", exclusive: false, expected: 26 },
            { tag: "declares-zone", exclusive: true, expected: 0 }
        ]
    }

    function test_barClearanceOnlyAppliesWhenTheDockIgnoresExclusiveZones(data) {
        compare(DockSettings.barClearanceFor("top", "top", 26, false, data.exclusive), data.expected)
    }

    function test_barClearanceIsReclaimedWhileTheBarIsHidden() {
        compare(DockSettings.barClearanceFor("top", "top", 26, true, false), 0)
        compare(DockSettings.barClearanceFor("top", "top", 26, false, false), 26)
    }

    function test_barClearanceIsZeroWhenTheDockDoesNotShareTheBarEdge_data() {
        return [
            { tag: "auto", configured: "auto", bar: "top" },
            { tag: "opposite", configured: "bottom", bar: "top" },
            { tag: "perpendicular", configured: "left", bar: "top" },
            { tag: "unknown-bar", configured: "top", bar: "botom" }
        ]
    }

    function test_barClearanceIsZeroWhenTheDockDoesNotShareTheBarEdge(data) {
        compare(DockSettings.barClearanceFor(data.configured, data.bar, 26, false, false), 0)
    }

    function test_barClearanceRejectsUnusableBarSizes_data() {
        return [
            { tag: "negative", size: -10 },
            { tag: "zero", size: 0 },
            { tag: "undefined", size: undefined },
            { tag: "garbage", size: "wide" }
        ]
    }

    function test_barClearanceRejectsUnusableBarSizes(data) {
        compare(DockSettings.barClearanceFor("top", "top", data.size, false, false), 0)
    }

    function test_dockIsVerticalOnSideEdges_data() {
        return [
            { tag: "left", edge: "left", expected: true },
            { tag: "right", edge: "right", expected: true },
            { tag: "top", edge: "top", expected: false },
            { tag: "bottom", edge: "bottom", expected: false }
        ]
    }

    function test_dockIsVerticalOnSideEdges(data) {
        compare(DockSettings.edgeIsVertical(data.edge), data.expected)
    }

    function test_dockSharesEdgeWithBarOnlyWhenTheyCollide() {
        compare(DockSettings.sharesEdgeWithBar("top", "top"), true)
        compare(DockSettings.sharesEdgeWithBar("bottom", "top"), false)
        compare(DockSettings.sharesEdgeWithBar("auto", "top"), false)
    }
}
