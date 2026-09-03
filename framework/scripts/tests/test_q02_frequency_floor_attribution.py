"""Regression: Q02 frequency-floor coverage must only use THIS RUN's markers.

The tester day-log is a SHARED terminal artifact. Before 2026-09-03 the
frequency-floor parser text-scanned it for ``QM_PATTERN_FIRST_TRADABLE_BAR``
and adopted whatever it found. Two distinct leaks followed:

* cross-EA -- work item ``95e706ea-531c-504b-ae46-4e16f7d79134`` (QM5_41321,
  NDX.DWX, run_tag 20260903_012953) reported
  ``first_tradable_bar.symbol=XAGUSD.DWX`` (emitted by QM5_41195), moving
  ``coverage_start`` 2021.01.01 -> 2022.01.12, ``year_count`` 2 -> 1 and
  ``min_trades_required`` 10 -> 5;
* cross-RUN -- the same day-log holds four QM5_41196 / XAUUSD.DWX markers from
  four DL089 census cells (1-year windows). An (EA, symbol)-only attribution
  rule adopts the latest of them for the canonical
  2018.07.02-2022.12.31 Q02 run and understates the floor 25 -> 5.

Both are fail-open. The parser is now scoped to the run's own tester window,
anchored on the tester's run-start line for this expert + symbol + requested
window, and rejects everything else with a distinct reason.

These tests drive the real PowerShell helper against synthetic UTF-16 LE
day-logs (the on-disk encoding MetaTester actually writes) in both production
source-column layouts.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
HELPER = REPO / "framework" / "scripts" / "pattern_warmup_evidence.ps1"

TAB = "\t"

OWN_EXPERT = "QM5_41321_grimes-trendday-v2-opt"
OWN_SYMBOL = "NDX.DWX"


def run_start(
    clock: str,
    expert: str,
    symbol: str,
    from_date: str,
    to_date: str,
    period: str = "M15",
    source: str = "Tester",
) -> str:
    """The tester's own run-start line -- the run-window anchor."""
    return (
        f"CS{TAB}0{TAB}{clock}{TAB}{source}{TAB}{symbol},{period}: testing of "
        f"Experts\\QM\\{expert}.ex5 from {from_date} 00:00 to {to_date} 00:00 "
        "started with inputs:"
    )


def expert_added(clock: str, expert: str, source: str = "Tester") -> str:
    return (
        f"CS{TAB}0{TAB}{clock}{TAB}{source}{TAB}expert file added: "
        f"Experts\\QM\\{expert}.ex5. 425604 bytes loaded"
    )


def marker(
    clock: str,
    source_column: str,
    symbol: str,
    date: str,
    profile_key: str = "DL089_OPT|0|16408|1|B|S:12",
    tag: str = "CS",
) -> str:
    return (
        f"{tag}{TAB}0{TAB}{clock}{TAB}{source_column}{TAB}{date} 01:01:00   "
        "QM_PATTERN_FIRST_TRADABLE_BAR schema=qm.pattern-first-tradable-bar/v1 "
        f"symbol={symbol} reference_timeframe=16408 tradable_bar_date={date} "
        "tradable_bar_time=1612137600 reference_bar_time=1612051200 "
        f"required_bars=5 profile_key={profile_key}"
    )


PREAMBLE = [
    f"CS{TAB}0{TAB}00:20:34.641{TAB}Startup{TAB}MetaTester 5 build 6140, 21 Aug 2026",
    f"CS{TAB}0{TAB}00:20:34.642{TAB}Startup{TAB}Windows Server 2022",
]

DRIVER = """param(
    [Parameter(Mandatory = $true)][string]$LogPath,
    [Parameter(Mandatory = $true)][string]$OutPath,
    [string]$ExpectedExpert = '',
    [int]$ExpectedEaId = 0,
    [string]$RunSymbol = '',
    [Parameter(Mandatory = $true)][string]$FromDate,
    [Parameter(Mandatory = $true)][string]$ToDate
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. '{helper}'
$evidence = Get-QmPatternFrequencyFloorEvidence `
    -TesterLogPaths @($LogPath) `
    -FallbackStartDate $FromDate `
    -EndDate $ToDate `
    -RatePerYear 5 `
    -ExpectedExpert $ExpectedExpert `
    -ExpectedEaId $ExpectedEaId `
    -RunSymbol $RunSymbol
$evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutPath -Encoding utf8
"""


def _pwsh() -> str | None:
    return shutil.which("pwsh") or shutil.which("pwsh.exe")


class Q02FrequencyFloorAttributionTests(unittest.TestCase):
    """The helper is PowerShell, so the regression drives the real script."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.shell = _pwsh()
        if not cls.shell:
            raise unittest.SkipTest("pwsh not available")
        if not HELPER.is_file():
            raise AssertionError(f"missing helper {HELPER}")

    def _evidence(
        self,
        lines: list[str],
        *,
        expert: str = f"QM\\{OWN_EXPERT}",
        ea_id: int = 41321,
        symbol: str = OWN_SYMBOL,
        from_date: str = "2021.01.01",
        to_date: str = "2022.12.31",
    ) -> dict:
        with tempfile.TemporaryDirectory() as tmp:
            tmpdir = Path(tmp)
            log_path = tmpdir / "20260903.log"
            # MetaTester writes the day-log as UTF-16 LE with a BOM and CRLF.
            log_path.write_bytes(("\r\n".join(lines) + "\r\n").encode("utf-16"))
            driver = tmpdir / "driver.ps1"
            driver.write_text(DRIVER.format(helper=str(HELPER)), encoding="utf-8")
            out_path = tmpdir / "evidence.json"
            proc = subprocess.run(
                [
                    self.shell,
                    "-NoProfile",
                    "-File",
                    str(driver),
                    "-LogPath",
                    str(log_path),
                    "-OutPath",
                    str(out_path),
                    "-ExpectedExpert",
                    expert,
                    "-ExpectedEaId",
                    str(ea_id),
                    "-RunSymbol",
                    symbol,
                    "-FromDate",
                    from_date,
                    "-ToDate",
                    to_date,
                ],
                capture_output=True,
                text=True,
            )
            if proc.returncode != 0:
                raise AssertionError(
                    f"driver failed rc={proc.returncode}\n"
                    f"stdout={proc.stdout}\nstderr={proc.stderr}"
                )
            return json.loads(out_path.read_text(encoding="utf-8"))

    # -- cross-EA leak (the original 95e706ea shape) ----------------------

    def test_foreign_ea_markers_never_shorten_the_coverage_window(self) -> None:
        lines = PREAMBLE + [
            run_start("01:19:46.353", "QM5_41196_qs-kama-trend-xau-opt", "XAUUSD.DWX", "2021.01.01", "2022.12.31", "Daily"),
            marker("01:20:33.391", "QM5_41196_qs-kama-trend-xau-opt (XAUUSD.DWX,D1)", "XAUUSD.DWX", "2021.01.04"),
            run_start("02:42:38.294", "QM5_41195_aa-vol-sma10-opt", "XAGUSD.DWX", "2021.01.01", "2022.12.31", "Daily"),
            marker("02:43:27.869", "QM5_41195_aa-vol-sma10-opt (XAGUSD.DWX,D1)", "XAGUSD.DWX", "2022.01.12"),
            run_start("03:30:39.592", OWN_EXPERT, OWN_SYMBOL, "2021.01.01", "2022.12.31"),
        ]
        evidence = self._evidence(lines)

        self.assertEqual(evidence["marker_count"], 2)
        self.assertEqual(evidence["attributed_marker_count"], 0)
        self.assertEqual(evidence["rejected_marker_count"], 2)
        self.assertIsNone(evidence["first_tradable_bar"])
        self.assertEqual(evidence["marker_status"], "present_not_attributable")
        self.assertEqual(
            evidence["coverage_start_source"],
            "test_window_start_fallback_marker_not_attributable",
        )
        # The pre-fix defect: 2022.01.12 / 1 year / floor 5.
        self.assertEqual(evidence["coverage_start"], "2021.01.01")
        self.assertEqual(evidence["year_count"], 2)
        self.assertEqual(evidence["min_trades_required"], 10)
        self.assertTrue(evidence["attribution_enforced"])
        self.assertTrue(evidence["run_window_enforced"])
        self.assertEqual(evidence["rejected_marker_reasons"]["outside_run_window"], 2)
        window = evidence["run_scope"]["tester_log_windows"][0]
        self.assertTrue(window["resolved"])
        self.assertEqual(window["window_source"], "tester_log_run_start_exact")
        self.assertEqual(window["window_start"], "03:30:39.592")

    # -- cross-RUN leak (same EA, same symbol, other run windows) ---------

    def test_same_ea_same_symbol_other_run_markers_are_rejected(self) -> None:
        """The refutation case: four census cells of the run's own EA+symbol."""
        expert = "QM5_41196_qs-kama-trend-xau-opt"
        symbol = "XAUUSD.DWX"
        lines = PREAMBLE + [
            expert_added("01:19:46.217", expert),
            run_start("01:19:46.353", expert, symbol, "2021.01.01", "2021.12.31", "Daily"),
            marker("01:20:33.391", f"{expert} ({symbol},D1)", symbol, "2021.01.04", "DL089_OPT|0|16408|1|B|S:93"),
            expert_added("01:38:56.944", expert),
            run_start("01:38:57.041", expert, symbol, "2021.01.01", "2021.12.31", "Daily"),
            marker("01:39:42.324", f"{expert} ({symbol},D1)", symbol, "2021.01.04", "DL089_OPT|0|16408|1|B|S:100"),
            expert_added("02:16:19.044", expert),
            run_start("02:16:19.164", expert, symbol, "2022.01.01", "2022.12.31", "Daily"),
            marker("02:17:03.458", f"{expert} ({symbol},D1)", symbol, "2022.01.03", "DL089_OPT|0|16408|1|B:9|S"),
            expert_added("03:26:05.758", expert),
            run_start("03:26:05.872", expert, symbol, "2022.01.01", "2022.12.31", "Daily"),
            marker("03:26:45.023", f"{expert} ({symbol},D1)", symbol, "2022.01.03", "DL089_OPT|0|16408|1|B:22|S"),
        ]
        evidence = self._evidence(
            lines,
            expert=f"QM\\{expert}",
            ea_id=41196,
            symbol=symbol,
            from_date="2018.07.02",
            to_date="2022.12.31",
        )

        # Pre-fix / (EA, symbol)-only: coverage_start 2022.01.03, 1 year, floor 5.
        self.assertEqual(evidence["attributed_marker_count"], 0)
        self.assertEqual(evidence["marker_status"], "present_not_attributable")
        self.assertEqual(evidence["coverage_start"], "2018.07.02")
        self.assertEqual(evidence["year_count"], 5)
        self.assertEqual(evidence["min_trades_required"], 25)
        self.assertEqual(evidence["rejected_marker_reasons"]["run_window_unresolved"], 4)
        window = evidence["run_scope"]["tester_log_windows"][0]
        self.assertFalse(window["resolved"])
        self.assertEqual(window["window_source"], "unresolved_no_matching_run_start")
        # The own EA+symbol ran four times -- exactly the ambiguity that the
        # (EA, symbol)-only rule silently collapsed into "the" marker.
        self.assertEqual(window["own_ea_symbol_run_start_count"], 4)
        self.assertEqual(window["exact_run_start_count"], 0)

    def test_last_matching_run_start_scopes_the_window(self) -> None:
        """Same file, but this run IS the second 2022 census cell."""
        expert = "QM5_41196_qs-kama-trend-xau-opt"
        symbol = "XAUUSD.DWX"
        lines = PREAMBLE + [
            run_start("02:16:19.164", expert, symbol, "2022.01.01", "2022.12.31", "Daily"),
            marker("02:17:03.458", f"{expert} ({symbol},D1)", symbol, "2022.01.03", "DL089_OPT|0|16408|1|B:9|S"),
            expert_added("03:26:05.758", expert),
            run_start("03:26:05.872", expert, symbol, "2022.01.01", "2022.12.31", "Daily"),
            marker("03:26:45.023", f"{expert} ({symbol},D1)", symbol, "2022.02.03", "DL089_OPT|0|16408|1|B:22|S"),
        ]
        evidence = self._evidence(
            lines,
            expert=f"QM\\{expert}",
            ea_id=41196,
            symbol=symbol,
            from_date="2022.01.01",
            to_date="2022.12.31",
        )

        self.assertEqual(evidence["attributed_marker_count"], 1)
        self.assertEqual(evidence["coverage_start"], "2022.02.03")
        self.assertEqual(evidence["first_tradable_bar"]["source_line_time"], "03:26:45.023")
        self.assertEqual(evidence["first_tradable_bar"]["run_window_state"], "inside")
        self.assertEqual(evidence["rejected_marker_reasons"]["outside_run_window"], 1)
        self.assertEqual(evidence["run_scope"]["tester_log_windows"][0]["exact_run_start_count"], 2)

    def test_own_marker_inside_own_window_is_used(self) -> None:
        lines = PREAMBLE + [
            run_start("01:19:46.353", "QM5_41196_qs-kama-trend-xau-opt", "XAUUSD.DWX", "2021.01.01", "2022.12.31", "Daily"),
            marker("01:20:33.391", "QM5_41196_qs-kama-trend-xau-opt (XAUUSD.DWX,D1)", "XAUUSD.DWX", "2021.01.04"),
            run_start("01:32:00.000", OWN_EXPERT, OWN_SYMBOL, "2021.01.01", "2022.12.31"),
            marker("01:33:00.000", f"{OWN_EXPERT} ({OWN_SYMBOL},M15)", OWN_SYMBOL, "2021.02.01"),
            marker("01:33:05.000", "QM5_41195_aa-vol-sma10-opt (XAGUSD.DWX,D1)", "XAGUSD.DWX", "2022.01.12"),
        ]
        evidence = self._evidence(lines)

        self.assertEqual(evidence["attributed_marker_count"], 1)
        self.assertEqual(evidence["rejected_marker_count"], 2)
        self.assertEqual(evidence["marker_status"], "present_consistent")
        self.assertEqual(evidence["coverage_start_source"], "pattern_first_tradable_bar")
        self.assertEqual(evidence["coverage_start"], "2021.02.01")
        found = evidence["first_tradable_bar"]
        self.assertEqual(found["symbol"], OWN_SYMBOL)
        self.assertEqual(found["emitting_expert"], OWN_EXPERT)
        self.assertEqual(found["attribution_reason"], "own_ea_run_symbol")
        self.assertEqual(evidence["attributed_profile_key_count"], 1)
        # A foreign EA printing INSIDE the window is still rejected on identity.
        self.assertEqual(evidence["rejected_marker_reasons"]["foreign_ea"], 1)
        self.assertEqual(evidence["rejected_marker_reasons"]["outside_run_window"], 1)
        self.assertEqual(evidence["year_count"], 2)
        self.assertEqual(evidence["min_trades_required"], 10)

    def test_marker_of_own_ea_on_a_foreign_symbol_is_rejected(self) -> None:
        """Same EA id, different chart: not this run, so not this run's marker."""
        lines = PREAMBLE + [
            run_start("01:32:00.000", OWN_EXPERT, OWN_SYMBOL, "2021.01.01", "2022.12.31"),
            marker("01:33:00.000", f"{OWN_EXPERT} (GDAXI.DWX,M15)", "GDAXI.DWX", "2021.02.01"),
        ]
        evidence = self._evidence(lines)

        self.assertEqual(evidence["attributed_marker_count"], 0)
        self.assertEqual(evidence["marker_status"], "present_not_attributable")
        self.assertEqual(evidence["coverage_start"], "2021.01.01")
        self.assertEqual(evidence["min_trades_required"], 10)
        self.assertEqual(evidence["rejected_marker_reasons"]["foreign_symbol"], 1)

    # -- day-log layout 2: the source column is the tester core -----------

    def test_tester_core_layout_uses_run_window_plus_symbol(self) -> None:
        """`IE 0 <clock> Core 01 ...` carries no EA identity at all."""
        expert = "QM5_41097_balke-gmt3-range-breakout-opt"
        symbol = "USDJPY.DWX"
        lines = PREAMBLE + [
            marker("02:24:24.187", "Core 01", "XAGUSD.DWX", "2021.01.21", tag="FF"),
            expert_added("19:38:17.966", expert, source="Core 01"),
            run_start("19:38:17.966", expert, symbol, "2022.01.01", "2022.12.31", "H1", source="Core 01"),
            marker("19:38:54.630", "Core 01", symbol, "2022.01.03", "DL089_OPT|0|16408|1|B|S:39", tag="IE"),
            marker("19:38:55.630", "Core 01", "XAUUSD.DWX", "2022.02.03", tag="IE"),
        ]
        evidence = self._evidence(
            lines,
            expert=f"QM\\{expert}",
            ea_id=41097,
            symbol=symbol,
            from_date="2022.01.01",
            to_date="2022.12.31",
        )

        found = evidence["first_tradable_bar"]
        self.assertIsNotNone(found)
        self.assertEqual(found["attribution_reason"], "core_source_window")
        self.assertEqual(found["source_column_kind"], "tester_core")
        self.assertEqual(found["source_column"], "Core 01")
        self.assertEqual(evidence["coverage_start"], "2022.01.03")
        self.assertEqual(evidence["rejected_marker_reasons"]["outside_run_window"], 1)
        self.assertEqual(evidence["rejected_marker_reasons"]["foreign_symbol"], 1)

    def test_tester_core_layout_without_a_run_window_fails_closed(self) -> None:
        expert = "QM5_41097_balke-gmt3-range-breakout-opt"
        symbol = "USDJPY.DWX"
        lines = PREAMBLE + [
            run_start("19:38:17.966", expert, symbol, "2021.01.01", "2021.12.31", "H1", source="Core 01"),
            marker("19:38:54.630", "Core 01", symbol, "2022.01.03", tag="IE"),
        ]
        evidence = self._evidence(
            lines,
            expert=f"QM\\{expert}",
            ea_id=41097,
            symbol=symbol,
            from_date="2022.01.01",
            to_date="2022.12.31",
        )

        self.assertEqual(evidence["attributed_marker_count"], 0)
        self.assertEqual(evidence["marker_status"], "present_not_attributable")
        self.assertEqual(evidence["rejected_marker_reasons"]["run_window_unresolved"], 1)
        self.assertEqual(evidence["min_trades_required"], 5)

    # -- midnight rollover -------------------------------------------------

    def test_rollover_day_log_without_any_run_start_is_this_run(self) -> None:
        """run_smoke copies the CURRENT day-log; a run may start before 00:00."""
        lines = [
            f"CS{TAB}0{TAB}00:00:00.196{TAB}Trade{TAB}2019.10.02 06:00:00   buy stop 7.47 {OWN_SYMBOL} at 107.787",
            marker("00:00:12.500", f"{OWN_EXPERT} ({OWN_SYMBOL},M15)", OWN_SYMBOL, "2021.02.01"),
            f"CS{TAB}0{TAB}00:01:05.288{TAB}Tester{TAB}final balance 104146.76 USD",
        ]
        evidence = self._evidence(lines)

        window = evidence["run_scope"]["tester_log_windows"][0]
        self.assertTrue(window["resolved"])
        self.assertEqual(window["window_source"], "rollover_continuation_no_run_start")
        self.assertEqual(window["run_start_count"], 0)
        self.assertEqual(evidence["coverage_start"], "2021.02.01")
        self.assertEqual(evidence["attributed_marker_count"], 1)

    # -- no identity -------------------------------------------------------

    def test_run_without_identity_cannot_consume_any_marker(self) -> None:
        """No expert / ea_id / symbol anchor -> no window, nothing attributable."""
        lines = PREAMBLE + [
            run_start("01:32:00.000", OWN_EXPERT, OWN_SYMBOL, "2021.01.01", "2022.12.31"),
            marker("01:33:00.000", f"{OWN_EXPERT} ({OWN_SYMBOL},M15)", OWN_SYMBOL, "2021.02.01"),
        ]
        evidence = self._evidence(lines, expert="", ea_id=0, symbol="")

        self.assertEqual(evidence["attributed_marker_count"], 0)
        self.assertEqual(evidence["marker_status"], "present_not_attributable")
        self.assertEqual(evidence["coverage_start"], "2021.01.01")
        self.assertEqual(evidence["min_trades_required"], 10)
        self.assertEqual(
            evidence["rejected_marker_reasons"]["no_expected_run_identity"], 1
        )
        self.assertEqual(
            evidence["run_scope"]["tester_log_windows"][0]["window_source"],
            "unresolved_no_expected_run_identity",
        )


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
