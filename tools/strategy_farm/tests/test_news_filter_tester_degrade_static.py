from __future__ import annotations

from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
NEWS_FILTER = REPO / "framework" / "include" / "QM" / "QM_NewsFilter.mqh"

# MNT-045: the tester must degrade on a mid-init CSV problem exactly as the
# live path already does, instead of failing OnInit hard. The preflight claim
# gate (_news_calendar_preflight) is what stops a truly missing calendar from
# ever reaching a backtest; these three branches cover a gate-passed run whose
# data still turns out to be unreadable/unparseable/empty at QM_NewsInit time.
DEGRADE_REASONS = (
    "calendar_file_missing_or_unreadable",
    "calendar_csv_parse_failed",
    "calendar_zero_rows_parsed",
)


def _function_body(source: str, name: str) -> str:
    signature = source.index(f"{name}(")
    opening = source.index("{", signature)
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated function: {name}")


def test_tester_degrades_instead_of_failing_init_for_each_reason() -> None:
    source = NEWS_FILTER.read_text(encoding="utf-8")
    init_body = _function_body(source, "QM_NewsInit")

    for reason in DEGRADE_REASONS:
        marker = f'"{{\\"detail\\":\\"{reason}\\",\\"tester_source\\":\\"none\\"}}"'
        assert marker in init_body, f"missing tester NEWS_CSV_DEGRADED payload for {reason}"

        marker_index = init_body.index(marker)
        # The tester branch for this reason must log NEWS_CSV_DEGRADED (not the
        # ERROR-level QM_NewsLogSetupMissing) and return true (OnInit succeeds).
        branch_start = init_body.rindex("if(MQLInfoInteger(MQL_TESTER) != 0)", 0, marker_index)
        branch_end = init_body.index("return true;", marker_index) + len("return true;")
        branch = init_body[branch_start:branch_end]

        assert '"NEWS_CSV_DEGRADED"' in branch
        assert "QM_NewsLogSetupMissing" not in branch
        assert "return false;" not in branch
        assert branch.strip().endswith("return true;")


def test_live_degrade_marker_and_contract_are_unchanged() -> None:
    source = NEWS_FILTER.read_text(encoding="utf-8")
    init_body = _function_body(source, "QM_NewsInit")

    for reason in DEGRADE_REASONS:
        live_marker = (
            f'"{{\\"detail\\":\\"{reason}\\",\\"live_source\\":\\"native_mt5_calendar\\"}}"'
        )
        assert live_marker in init_body
        assert init_body.count(f'"NEWS_CSV_DEGRADED_LIVE"') >= len(DEGRADE_REASONS)


def test_preflight_claim_gate_reference_untouched() -> None:
    # This change is scoped to what happens after the preflight gate already
    # passed; it must not touch the gate itself.
    farmctl_source = (REPO / "tools" / "strategy_farm" / "farmctl.py").read_text(encoding="utf-8")
    assert "_news_calendar_preflight" in farmctl_source
