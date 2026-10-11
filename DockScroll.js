// DockScroll.js — Smooth wheel & trackpad delta accumulator for Omarchy Dock
.pragma library

// Smooth trackpads and high-res scroll wheels emit dozens of tiny deltas.
// Accumulate delta until a threshold is crossed before stepping through windows.
function step(previous, pixelX, pixelY, angleX, angleY) {
    var hasPixels = (pixelX !== 0 || pixelY !== 0);
    var x = hasPixels ? pixelX : angleX;
    var y = hasPixels ? pixelY : angleY;
    var delta = Math.abs(x) > Math.abs(y) ? x : -y;
    var threshold = hasPixels ? 40 : 120;

    if (!delta) {
        return { pending: previous, direction: 0 };
    }

    // Reset accumulated delta if user reverses direction
    if (previous * delta < 0) {
        previous = 0;
    }

    var total = previous + delta;
    if (Math.abs(total) < threshold) {
        return { pending: total, direction: 0 };
    }

    return { pending: 0, direction: total > 0 ? 1 : -1 };
}
