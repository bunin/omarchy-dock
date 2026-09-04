"""Unit tests for scripts/dock-minimize.py.

Run with:  python3 -m unittest discover -s tests
"""

import importlib.util
import os
import unittest

_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       os.pardir, "scripts", "dock-minimize.py")


def _load_script():
    spec = importlib.util.spec_from_file_location("dock_minimize", _SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


dm = _load_script()


def _client(addr, workspace="1"):
    return {"address": addr, "workspace": {"name": workspace}}


class SplitQueriesTest(unittest.TestCase):
    def test_an_address_is_a_selector_and_leaves_the_app_identifiers_alone(self):
        # A dock click sends the app's identifiers *and* which window to act on.
        # Narrowing the match down to the address hides the app's siblings.
        identifiers, index, addr = dm.split_queries(
            ["firefox", "firefox.desktop", "/usr/bin/firefox", "0xDEADBEEF"])
        self.assertEqual(identifiers, ["firefox", "firefox.desktop", "/usr/bin/firefox"])
        self.assertEqual(index, -1)
        self.assertEqual(addr, "0xdeadbeef")

    def test_the_legacy_index_selector_still_works(self):
        self.assertEqual(dm.split_queries(["firefox", "--index=2"]), (["firefox"], 2, ""))
        self.assertEqual(dm.split_queries(["firefox", "2"]), (["firefox"], 2, ""))

    def test_no_selector_at_all(self):
        self.assertEqual(dm.split_queries(["firefox"]), (["firefox"], -1, ""))

    def test_an_app_identifier_that_merely_looks_like_hex_is_kept(self):
        identifiers, _, addr = dm.split_queries(["deface", "facade"])
        self.assertEqual(identifiers, ["deface", "facade"])
        self.assertEqual(addr, "")


class PickTargetTest(unittest.TestCase):
    def setUp(self):
        self.first = _client("0xAAA")
        self.second = _client("0xBBB")
        self.hidden = _client("0xCCC", "special:minimized")
        self.matching = [self.first, self.second, self.hidden]
        self.visible = [self.first, self.second]
        self.minimized = [self.hidden]

    def _pick(self, addr="", index=-1, active=""):
        return dm.pick_target(self.matching, self.visible, self.minimized, addr, index, active)

    def test_an_address_names_the_window_outright(self):
        self.assertIs(self._pick(addr="0xbbb"), self.second)

    def test_an_address_wins_over_an_index(self):
        self.assertIs(self._pick(addr="0xbbb", index=0), self.second)

    def test_an_index_is_used_when_no_address_was_given(self):
        self.assertIs(self._pick(index=1), self.second)

    def test_an_address_that_is_gone_falls_through_to_the_heuristics(self):
        self.assertIs(self._pick(addr="0xffff", active="0xbbb"), self.second)

    def test_the_active_window_comes_before_the_first_visible_one(self):
        self.assertIs(self._pick(active="0xbbb"), self.second)

    def test_the_first_visible_window_is_the_default(self):
        self.assertIs(self._pick(), self.first)

    def test_a_minimized_window_is_the_last_resort(self):
        self.assertIs(
            dm.pick_target(self.matching, [], self.minimized, "", -1, ""), self.hidden)

    def test_nothing_matched_at_all(self):
        self.assertIsNone(dm.pick_target([], [], [], "", -1, ""))


if __name__ == "__main__":
    unittest.main()
