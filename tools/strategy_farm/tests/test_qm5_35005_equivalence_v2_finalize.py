from __future__ import annotations

from tools.strategy_farm import qm5_35005_equivalence_v2_finalize as finalize


def _row(path: str, digest: str = "a") -> dict[str, object]:
    return {"relative_path": path, "size": 1, "sha256": digest * 64}


def _inventory(*rows: dict[str, object]) -> dict[str, object]:
    return {"files": list(rows)}


def test_history_mutation_scope_allows_only_outside_window_changes() -> None:
    before = _inventory(
        _row("history/EURUSD.DWX/2022.hcc"),
        _row("ticks/EURUSD.DWX/202207.tkc"),
        _row("history/EURUSD.DWX/2026.hcc"),
    )
    after = _inventory(
        _row("history/EURUSD.DWX/2022.hcc"),
        _row("ticks/EURUSD.DWX/202207.tkc"),
        _row("history/EURUSD.DWX/2026.hcc", "b"),
    )
    scope = finalize.history_mutation_scope(before, after)
    assert scope["tested_window_unchanged"] is True
    assert scope["changed_file_count"] == 1
    assert scope["changed_outside_test_window"][0]["relative_path"].endswith("2026.hcc")


def test_history_mutation_scope_rejects_test_window_change() -> None:
    before = _inventory(_row("history/EURUSD.DWX/2022.hcc"))
    after = _inventory(_row("history/EURUSD.DWX/2022.hcc", "b"))
    scope = finalize.history_mutation_scope(before, after)
    assert scope["tested_window_unchanged"] is False
    assert scope["changed_inside_test_window"][0]["relative_path"].endswith("2022.hcc")


def test_history_mutation_scope_treats_unknown_changed_file_as_in_window() -> None:
    before = _inventory(
        _row("history/EURUSD.DWX/2022.hcc"),
        _row("history/EURUSD.DWX/unknown.bin"),
    )
    after = _inventory(
        _row("history/EURUSD.DWX/2022.hcc"),
        _row("history/EURUSD.DWX/unknown.bin", "b"),
    )
    scope = finalize.history_mutation_scope(before, after)
    assert scope["tested_window_unchanged"] is False
