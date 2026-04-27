import importlib.util
import sys
import types
from pathlib import Path
import unittest


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "dwx_hourly_check.py"


def load_module():
    fake_mt5 = types.SimpleNamespace()
    old = sys.modules.get("MetaTrader5")
    sys.modules["MetaTrader5"] = fake_mt5
    try:
        spec = importlib.util.spec_from_file_location("dwx_hourly_check", str(SCRIPT_PATH))
        module = importlib.util.module_from_spec(spec)
        assert spec and spec.loader
        spec.loader.exec_module(module)
        return module
    finally:
        if old is None:
            sys.modules.pop("MetaTrader5", None)
        else:
            sys.modules["MetaTrader5"] = old


class ReadinessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load_module()

    def test_all_good_is_ready(self):
        self.assertTrue(
            self.mod.compute_readiness(
                missing=[],
                pending=[],
                groups_ok=True,
                service_ok=True,
                spec_bad=[],
            )
        )

    def test_missing_only_is_not_ready(self):
        self.assertFalse(
            self.mod.compute_readiness(
                missing=["EURUSD.DWX"],
                pending=[],
                groups_ok=True,
                service_ok=True,
                spec_bad=[],
            )
        )

    def test_spec_bad_only_is_not_ready(self):
        self.assertFalse(
            self.mod.compute_readiness(
                missing=[],
                pending=[],
                groups_ok=True,
                service_ok=True,
                spec_bad=["WS30.DWX"],
            )
        )

    def test_mixed_is_not_ready(self):
        self.assertFalse(
            self.mod.compute_readiness(
                missing=["XAUUSD.DWX"],
                pending=[Path("x.import.txt")],
                groups_ok=True,
                service_ok=True,
                spec_bad=[],
            )
        )

    def test_all_bad_is_not_ready(self):
        self.assertFalse(
            self.mod.compute_readiness(
                missing=["EURUSD.DWX"],
                pending=[Path("x.import.txt")],
                groups_ok=False,
                service_ok=False,
                spec_bad=["EURUSD.DWX"],
            )
        )

    def test_symbol_spec_ok_accepts_within_five_percent(self):
        self.assertTrue(self.mod.is_symbol_spec_ok(10.2, 10.0))

    def test_symbol_spec_ok_rejects_zero_or_negative_tick_values(self):
        self.assertFalse(self.mod.is_symbol_spec_ok(0.0, 10.0))
        self.assertFalse(self.mod.is_symbol_spec_ok(10.0, 0.0))

    def test_symbol_spec_ok_rejects_five_percent_or_more(self):
        self.assertFalse(self.mod.is_symbol_spec_ok(10.5, 10.0))

    def test_source_symbol_for_target_applies_override(self):
        self.assertEqual(self.mod.source_symbol_for_target("NDXm.DWX"), "NDX")
        self.assertEqual(self.mod.source_symbol_for_target("EURUSD.DWX"), "EURUSD")


if __name__ == "__main__":
    unittest.main()
