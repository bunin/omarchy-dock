.pragma library

var VISIBILITY_ALWAYS = "always"
var VISIBILITY_HOVER = "hover"
var VISIBILITY_KEYBIND = "keybind"
var VISIBILITY_HYBRID = "hybrid"

var VISIBILITY_OVERRIDE_HIDDEN = -1
var VISIBILITY_OVERRIDE_FOLLOW = 0
var VISIBILITY_OVERRIDE_SHOWN = 1

function normalizeVisibilityMode(value, legacyAutohide) {
    var mode = String(value === undefined || value === null ? "" : value).trim().toLowerCase()
    if (mode === VISIBILITY_ALWAYS || mode === VISIBILITY_HOVER || mode === VISIBILITY_KEYBIND || mode === VISIBILITY_HYBRID) {
        return mode
    }
    return legacyAutohide === true ? VISIBILITY_HOVER : VISIBILITY_ALWAYS
}

function hasHover(visibilityMode) {
    var mode = normalizeVisibilityMode(visibilityMode, false)
    return mode === VISIBILITY_HOVER || mode === VISIBILITY_HYBRID
}

function hasKeybind(visibilityMode) {
    var mode = normalizeVisibilityMode(visibilityMode, false)
    return mode === VISIBILITY_KEYBIND || mode === VISIBILITY_HYBRID
}

function normalizeOverlayMode(value, legacySpaceMode) {
    if (value === true || value === "true") return true
    if (value === false || value === "false") return false
    var mode = String(legacySpaceMode === undefined || legacySpaceMode === null ? "" : legacySpaceMode).trim().toLowerCase()
    return mode === "overlay"
}

var DOCK_POSITION_AUTO = "auto"
var DOCK_EDGES = ["top", "bottom", "left", "right"]

// The edge the dock sits on when nothing valid is configured and the bar
// position is unknown. Matches the dock's historical default.
var DOCK_EDGE_FALLBACK = "bottom"

var OPPOSITE_EDGES = {
    top: "bottom",
    bottom: "top",
    left: "right",
    right: "left"
}

function normalizeEdge(value) {
    var edge = String(value === undefined || value === null ? "" : value).trim().toLowerCase()
    return DOCK_EDGES.indexOf(edge) !== -1 ? edge : DOCK_EDGE_FALLBACK
}

// Configured dock edge: one of the four screen edges, or "auto" to keep
// sitting opposite the status bar the way the dock always has.
function normalizeDockPosition(value) {
    var position = String(value === undefined || value === null ? "" : value).trim().toLowerCase()
    if (position === DOCK_POSITION_AUTO) return DOCK_POSITION_AUTO
    return DOCK_EDGES.indexOf(position) !== -1 ? position : DOCK_POSITION_AUTO
}

function oppositeEdge(value) {
    return OPPOSITE_EDGES[normalizeEdge(value)]
}

// A status bar edge we recognize, or "" when the shell reported something we
// cannot place. Unlike normalizeEdge() this never invents an edge: the dock's
// own fallback is not a sensible guess for where the *bar* is.
function normalizeBarEdge(value) {
    var edge = String(value === undefined || value === null ? "" : value).trim().toLowerCase()
    return DOCK_EDGES.indexOf(edge) !== -1 ? edge : ""
}

// Where the dock actually lives. An explicit setting wins outright; "auto"
// (and anything unrecognized) falls back to the historical behaviour of
// sitting opposite the status bar.
function resolveDockEdge(configuredPosition, barPosition) {
    var configured = normalizeDockPosition(configuredPosition)
    if (configured !== DOCK_POSITION_AUTO) return configured
    var bar = normalizeBarEdge(barPosition)
    return bar === "" ? DOCK_EDGE_FALLBACK : OPPOSITE_EDGES[bar]
}

function edgeIsVertical(value) {
    var edge = normalizeEdge(value)
    return edge === "left" || edge === "right"
}

// True only when the user has explicitly parked the dock on the same edge the
// status bar occupies, so the dock has to step aside for it.
function sharesEdgeWithBar(configuredPosition, barPosition) {
    var configured = normalizeDockPosition(configuredPosition)
    if (configured === DOCK_POSITION_AUTO) return false
    var bar = normalizeBarEdge(barPosition)
    return bar !== "" && configured === bar
}

// Room the dock leaves for the status bar. Only ever non-zero when the user
// parked the dock on the bar's own edge -- "auto" always picks the opposite
// edge. wlr-layer-shell already keeps a surface that declares an exclusive
// zone clear of the bar's own, so this is the manual equivalent for the cases
// where the dock declares none (overlay mode, or while it is slid out). It
// mirrors the compositor deliberately, hidden bar included: the bar drops its
// exclusive zone while hidden, so the dock reclaims the space either way and
// does not shift when overlay mode is toggled.
function barClearanceFor(configuredPosition, barPosition, barSize, barHidden, dockDeclaresExclusiveZone) {
    if (dockDeclaresExclusiveZone === true) return 0
    if (barHidden === true) return 0
    if (!sharesEdgeWithBar(configuredPosition, barPosition)) return 0
    var size = Number(barSize)
    return isFinite(size) && size > 0 ? size : 0
}

function normalizeVisibleWorkspace(value) {
    if (value === undefined || value === null) return "all"
    var workspace = String(value).trim()
    return workspace === "" || workspace.toLowerCase() === "all" ? "all" : workspace
}

function normalize(raw) {
    var settings = raw && typeof raw === "object" ? raw : {}
    return {
        visibilityMode: normalizeVisibilityMode(settings.visibilityMode, settings.autohide),
        overlayMode: normalizeOverlayMode(settings.overlayMode, settings.spaceMode),
        visibleWorkspace: normalizeVisibleWorkspace(settings.visibleWorkspace),
        dockPosition: normalizeDockPosition(settings.dockPosition)
    }
}

function legacyAutohide(visibilityMode) {
    return normalizeVisibilityMode(visibilityMode, false) !== VISIBILITY_ALWAYS
}

function workspaceMatches(selector, workspaceId, workspaceName) {
    var normalized = normalizeVisibleWorkspace(selector)
    if (normalized === "all") return true
    if (normalized === "0" && (String(workspaceId) === "10" || String(workspaceName) === "10")) return true
    if (normalized === "10" && (String(workspaceId) === "0" || String(workspaceName) === "0")) return true
    return String(workspaceId) === normalized || String(workspaceName) === normalized
}

function normalizeVisibilityOverride(value) {
    var override = Number(value)
    if (override < 0) return VISIBILITY_OVERRIDE_HIDDEN
    if (override > 0) return VISIBILITY_OVERRIDE_SHOWN
    return VISIBILITY_OVERRIDE_FOLLOW
}

function shouldSlideOut(visibilityMode, visibilityOverride, dockActive, workspaceEmpty) {
    var override = normalizeVisibilityOverride(visibilityOverride)
    if (override === VISIBILITY_OVERRIDE_HIDDEN) return true
    if (override === VISIBILITY_OVERRIDE_SHOWN) return false

    var mode = normalizeVisibilityMode(visibilityMode, false)
    if (mode === VISIBILITY_ALWAYS) return false
    if (mode === VISIBILITY_KEYBIND) return true
    return dockActive !== true && workspaceEmpty !== true
}

// Whether the keyboard shortcut may toggle the dock. Everything but "hover"
// accepts it; "hover" is the screen-edge trigger's alone, because a dock that
// reveals on approach has nothing for a keypress to add and the two would fight
// over visibilityOverride.
function keyboardToggleAllowed(visibilityMode) {
    return normalizeVisibilityMode(visibilityMode, false) !== VISIBILITY_HOVER
}

function revealRequestAllowed(visibilityMode, source) {
    return source === "internal" || keyboardToggleAllowed(visibilityMode)
}

// In "keybind" mode a dock summoned by the shortcut hides itself again once the
// inactivity timer runs out, the same way hover mode does. A dock the user
// asked to keep on screen in any other mode stays put.
function shouldAutoDismissKeyboardReveal(visibilityMode, visibilityOverride) {
    var mode = normalizeVisibilityMode(visibilityMode, false)
    var isDismissable = mode === VISIBILITY_KEYBIND || mode === VISIBILITY_HYBRID
    return isDismissable
        && normalizeVisibilityOverride(visibilityOverride) === VISIBILITY_OVERRIDE_SHOWN
}

function releaseInteractionVisibilityOverride(owned, previousOverride, currentOverride) {
    return owned === true
        ? normalizeVisibilityOverride(previousOverride)
        : normalizeVisibilityOverride(currentOverride)
}

function dockScreenTarget(visibleWorkspace, visibilityMode, visibilityOverride) {
    if (normalizeVisibleWorkspace(visibleWorkspace) !== "all") return "configured"
    return "all"
}

function screenShowsDock(target, screenName, configuredMonitorName, capturedMonitorName, focusedMonitorName) {
    var name = String(screenName || "")
    if (name === "") return false
    if (target === "configured") return name === String(configuredMonitorName || "")
    if (target === "captured") return name === String(capturedMonitorName || "")
    if (target === "focused") return name === String(focusedMonitorName || "")
    return true
}

function workspaceIdentity(workspace) {
    if (!workspace) return ""
    var name = workspace.name === undefined || workspace.name === null ? "" : String(workspace.name).trim()
    if (name !== "") return name
    if (workspace.id === undefined || workspace.id === null) return ""
    return String(workspace.id)
}

function keyboardToggleWorkspace(monitorWorkspace, focusedWorkspace, toplevelWorkspace) {
    if (monitorWorkspace) return monitorWorkspace
    if (focusedWorkspace) return focusedWorkspace
    if (toplevelWorkspace) return toplevelWorkspace
    return null
}

function keyboardToggleDecision(dockRevealed, configuredSelector, focusedWorkspace, configuredWorkspace) {
    if (dockRevealed === true) {
        return { action: "hide", targetWorkspace: "" }
    }

    var selector = normalizeVisibleWorkspace(configuredSelector)
    var workspace = selector === "all" ? focusedWorkspace : configuredWorkspace
    if (!workspace) {
        return { action: "workspace-unavailable", targetWorkspace: "" }
    }
    if (workspace.active === false) {
        return { action: "workspace-inactive", targetWorkspace: "" }
    }

    var identity = workspaceIdentity(workspace)
    return { action: "show", targetWorkspace: identity || "all" }
}
