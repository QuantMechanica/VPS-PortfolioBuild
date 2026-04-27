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

    def test_summarize_verify_failures_flags_systemic_zero_bars(self):
        output = "\n".join(
            [
                f"[ FAIL_tail_bars] S{i}.DWX: mid_ticks_5min=10; bars expected=12,345/got=0"
                for i in range(1, 11)
            ]
        )
        summary = self.mod.summarize_verify_failures(output)
        self.assertEqual(summary["fail_count"], 10)
        self.assertTrue(summary["systemic_zero_bars"])
        self.assertFalse(summary["systemic_zero_mid_ticks"])

    def test_summarize_verify_failures_flags_systemic_zero_mid_ticks(self):
        output = "\n".join(
            [
                f"[FAIL_tail_mid_bars] S{i}.DWX: mid_ticks_5min=0; bars expected=999/got=0"
                for i in range(1, 10 + 1)
            ]
        )
        summary = self.mod.summarize_verify_failures(output)
        self.assertEqual(summary["fail_count"], 10)
        self.assertTrue(summary["systemic_zero_bars"])
        self.assertTrue(summary["systemic_zero_mid_ticks"])

    def test_summarize_verify_failures_ignores_small_or_mixed_batches(self):
        output = "\n".join(
            [
                "[ FAIL_tail_bars] WS30.DWX: mid_ticks_5min=1561; bars expected=445,870/got=0",
                "[ FAIL_tail_mid_bars] XAUUSD.DWX: mid_ticks_5min=0; bars expected=446,753/got=0",
                "[ FAIL_tail_bars] EURUSD.DWX: mid_ticks_5min=1; bars expected=446,100/got=100",
            ]
        )
        summary = self.mod.summarize_verify_failures(output)
        self.assertEqual(summary["fail_count"], 3)
        self.assertFalse(summary["systemic_zero_bars"])
        self.assertFalse(summary["systemic_zero_mid_ticks"])

    def test_summarize_verify_failures_parses_real_xagusd_line(self):
        output = (
            "[ FAIL_tail_bars] XAGUSD.DWX: source=XAGUSD; custom_tv=5.0; broker_tv=5.0; "
            "rel_err=0.0000; head_ms expected=1506906002441/got=1506906002441; "
            "tail_ms expected=1775444390467/got=1775437249841; mid_ticks_5min=255; "
            "bars expected=446,113/got=0 drift=-446,113; path=Custom\\Commodities\\Metals\\XAGUSD.DWX"
        )
        summary = self.mod.summarize_verify_failures(output)
        self.assertEqual(summary["fail_count"], 1)
        self.assertFalse(summary["systemic_zero_bars"])
        self.assertFalse(summary["systemic_zero_mid_ticks"])
        row = summary["fail_rows"][0]
        self.assertEqual(row["symbol"], "XAGUSD.DWX")
        self.assertEqual(row["verdict"], "FAIL_tail_bars")
        self.assertEqual(row["mid_ticks_5min"], 255)
        self.assertEqual(row["bars_expected"], 446113)
        self.assertEqual(row["bars_got"], 0)

if __name__ == "__main__":
    unittest.main()
