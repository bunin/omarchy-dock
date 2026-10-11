import QtQuick
import QtTest
import "../DockScroll.js" as DockScroll

TestCase {
    name: "DockScroll"

    function test_smoothScrollStep_accumulation() {
        // Small pixel deltas (like smooth trackpad swipes) accumulate until threshold (40)
        var s1 = DockScroll.step(0, 10, 0, 0, 0);
        compare(s1.direction, 0);
        compare(s1.pending, 10);

        var s2 = DockScroll.step(s1.pending, 15, 0, 0, 0);
        compare(s2.direction, 0);
        compare(s2.pending, 25);

        // Threshold reached (25 + 20 = 45 >= 40)
        var s3 = DockScroll.step(s2.pending, 20, 0, 0, 0);
        compare(s3.direction, 1);
        compare(s3.pending, 0);
    }

    function test_smoothScrollStep_reversal() {
        // Scrolling forward
        var s1 = DockScroll.step(0, 25, 0, 0, 0);
        compare(s1.pending, 25);

        // Reversing direction immediately clears pending
        var s2 = DockScroll.step(s1.pending, -10, 0, 0, 0);
        compare(s2.pending, -10);
        compare(s2.direction, 0);

        // Continue backward until threshold
        var s3 = DockScroll.step(s2.pending, -35, 0, 0, 0);
        compare(s3.direction, -1);
        compare(s3.pending, 0);
    }

    function test_angleDelta_wheel() {
        // Standard mouse wheel angle deltas (120 per notch)
        var resDown = DockScroll.step(0, 0, 0, 0, -120);
        compare(resDown.direction, 1); // forward/down
        compare(resDown.pending, 0);

        var resUp = DockScroll.step(0, 0, 0, 0, 120);
        compare(resUp.direction, -1); // backward/up
        compare(resUp.pending, 0);
    }
}
