"""Guard against the test-import hazard found in task af1e6342 (2026-10-15).

``tools/strategy_farm/dwx_m1_overlap_export_work_item.py`` used to do::

    REPO_ROOT = Path("C:/QM/repo")
    sys.path.insert(0, str(REPO_ROOT))

A literal, hard-coded canonical path in a ``sys.path.insert``/``append`` call
means a test run from an agent worktree (or a git-archive extract) silently
imports sibling modules (``custom_history_contract``, ``farmctl``, ...) from
``C:/QM/repo`` instead of the code actually under review -- the independent
reviewer may believe it exercised a fix when it exercised canonical instead.

This test statically scans every ``.py`` file under ``tools/strategy_farm``
and ``framework/scripts`` *in this checkout* (never a hard-coded path -- see
below) for that pattern. New offenders fail the test. Pre-existing offenders
found in the 2026-10-16 board-advisor audit (task af1e6342) are grandfathered
via ``KNOWN_LEGACY_OFFENDERS`` so this test is actionable without a mass
rewrite; fixing one just means deleting its entry here.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

# Deliberately NOT a hard-coded "C:/QM/repo" -- that is exactly the bug this
# test exists to catch. Resolve our own checkout root from this file's
# location instead.
_CHECKOUT_ROOT = Path(__file__).resolve().parents[3]
_SCAN_DIRS = ("tools/strategy_farm", "framework/scripts")

# Matches e.g. sys.path.insert(0, "C:/QM/repo") or sys.path.insert(0, r"C:\QM\repo").
_HAZARD_RE = re.compile(
    r"sys\.path\.(insert|append)\s*\([^)]*C:[/\\]{1,2}QM[/\\]{1,2}repo",
    re.IGNORECASE,
)

# This file necessarily documents the hazard pattern in prose/examples above,
# which would otherwise flag itself.
_SELF = Path(__file__).resolve().relative_to(_CHECKOUT_ROOT).as_posix()

# Relative-to-checkout-root paths with a literal hard-coded canonical
# sys.path insertion, found via `git show agents/board-advisor:<path>` audit
# on 2026-10-16 (task af1e6342). None of these are fixed by this task; they
# are pre-existing debt, documented so this guard does not mass-fail and so
# removing an entry here is the signal that it got fixed.
KNOWN_LEGACY_OFFENDERS = frozenset(
    {
        "framework/scripts/mt5_diagnostics/news_calendar_export_e1b2.py",
        "framework/scripts/mt5_diagnostics/news_calendar_export_e1d2_m5.py",
        "framework/scripts/mt5_diagnostics/qm1537_native_d1_export.py",
        "tools/strategy_farm/ftmo_admission_census.py",
        "tools/strategy_farm/portfolio/dxz_composite_faithful_recompute.py",
        "tools/strategy_farm/portfolio/dxz_weight_oos_validation.py",
        "tools/strategy_farm/portfolio/ftmo_decorrelation_test.py",
        "tools/strategy_farm/portfolio/ftmo_density_compare.py",
        "tools/strategy_farm/portfolio/ftmo_density_speed_at_budget.py",
        "tools/strategy_farm/portfolio/ftmo_full_pipeline.py",
        "tools/strategy_farm/portfolio/ftmo_speed_parallel.py",
        "tools/strategy_farm/portfolio/gen_dxz23_20260726.py",
        "tools/strategy_farm/portfolio/gen_dxz24_weekend_manifest.py",
        "tools/strategy_farm/portfolio/gen_dxz24b_20260726.py",
        "tools/strategy_farm/portfolio/gen_dxz_23sleeve_manifest.py",
        "tools/strategy_farm/portfolio/gen_dxz_final_manifest.py",
        "tools/strategy_farm/portfolio/marginal_contribution_eval.py",
        "tools/strategy_farm/r_eval_drain.py",
        "tools/strategy_farm/session_tools/check_prose.py",
        "tools/strategy_farm/session_tools/interactive_heartbeat_detached.py",
        "tools/strategy_farm/session_tools/park_44gb_reservation_rows_0914.py",
    }
)

# The file this task fixed. A regression here must fail loudly, independent
# of whatever else the legacy list grows or shrinks to.
FIXED_FILE = "tools/strategy_farm/dwx_m1_overlap_export_work_item.py"


def _scan() -> set[str]:
    found: set[str] = set()
    for scan_dir in _SCAN_DIRS:
        root = _CHECKOUT_ROOT / scan_dir
        if not root.is_dir():
            continue
        for path in root.rglob("*.py"):
            rel = path.relative_to(_CHECKOUT_ROOT).as_posix()
            if rel == _SELF:
                continue
            text = path.read_text(encoding="utf-8", errors="ignore")
            if _HAZARD_RE.search(text):
                found.add(rel)
    return found


class NoHardcodedCanonicalSysPathTests(unittest.TestCase):
    def test_fixed_file_no_longer_hazardous(self) -> None:
        found = _scan()
        self.assertNotIn(
            FIXED_FILE,
            found,
            f"{FIXED_FILE} re-introduced a hard-coded canonical sys.path "
            "insertion (task af1e6342 regression).",
        )

    def test_no_new_offenders_beyond_known_legacy_list(self) -> None:
        found = _scan()
        new_offenders = found - KNOWN_LEGACY_OFFENDERS - {FIXED_FILE}
        self.assertEqual(
            new_offenders,
            set(),
            "New module(s) hard-code a canonical C:/QM/repo sys.path "
            f"insertion: {sorted(new_offenders)}. Either fix them (preferred: "
            "derive the checkout root from __file__, e.g. "
            "Path(__file__).resolve().parents[N]) or, if truly unavoidable, "
            "add them to KNOWN_LEGACY_OFFENDERS with a reason.",
        )


if __name__ == "__main__":
    unittest.main()
