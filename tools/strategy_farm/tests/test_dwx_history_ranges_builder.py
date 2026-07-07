import importlib.util
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "infra" / "scripts" / "build_dwx_history_ranges.py"
spec = importlib.util.spec_from_file_location("build_dwx_history_ranges", SCRIPT)
assert spec and spec.loader
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class DwxHistoryRangesBuilderTests(unittest.TestCase):
    def test_build_rows_expands_derived_periods_and_excludes_weekly_monthly(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            matrix = root / "dwx_symbol_matrix.csv"
            matrix.write_text(
                "\n".join(
                    [
                        "symbol,asset_class,canonical_name_verified",
                        "EURUSD.DWX,forex,true",
                        "NDX.DWX,indices,true",
                        "MISSING.DWX,forex,true",
                        "",
                    ]
                ),
                encoding="utf-8",
            )
            for terminal in ("T1", "T2"):
                hist = root / "mt5" / terminal / "Bases" / "Custom" / "history" / "EURUSD.DWX"
                hist.mkdir(parents=True)
                for year in range(2017, 2023):
                    (hist / f"{year}.hcc").write_bytes(b"x" * 128)
            ndx = root / "mt5" / "T1" / "Bases" / "Custom" / "history" / "NDX.DWX"
            ndx.mkdir(parents=True)
            for year in (2018, 2019, 2021, 2022):
                (ndx / f"{year}.hcc").write_bytes(b"x" * 128)

            rows, summary = builder.build_rows(
                mt5_root=root / "mt5",
                matrix_path=matrix,
                periods=("D1", "M30", "M1", "W1", "MN1"),
                min_hcc_bytes=1,
            )

            periods = {(row["symbol"], row["period"]) for row in rows}
            self.assertIn(("EURUSD.DWX", "M30"), periods)
            self.assertIn(("EURUSD.DWX", "M1"), periods)
            self.assertNotIn(("EURUSD.DWX", "W1"), periods)
            self.assertNotIn(("EURUSD.DWX", "MN1"), periods)

            eurusd = next(row for row in rows if row["symbol"] == "EURUSD.DWX" and row["period"] == "M30")
            self.assertEqual(eurusd["first_year"], 2017)
            self.assertEqual(eurusd["last_year"], 2022)
            self.assertEqual(eurusd["source_terminals"], "T1,T2")

            ndx_row = next(row for row in rows if row["symbol"] == "NDX.DWX" and row["period"] == "M1")
            self.assertEqual(ndx_row["first_year"], 2021)
            self.assertEqual(ndx_row["last_year"], 2022)
            self.assertEqual(summary["skipped_symbols"], [{"symbol": "MISSING.DWX", "reason": "no_hcc_years_at_or_above_min_bytes"}])


if __name__ == "__main__":
    unittest.main()
