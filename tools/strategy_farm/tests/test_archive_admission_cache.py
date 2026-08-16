"""The admission path must be memoized without changing what it returns.

2026-08-16: the per-card admission gate re-validated the full archive manifest
and re-parsed every relative_path on every call, which froze agent_router on
its 600s wall clock and stopped the whole agent lane. These tests pin both
halves of the fix: identical results, and validation not repeated for the same
manifest object.
"""

import custom_history_copy_on_claim as coc


def _manifest():
    return {
        "schema": "qm.custom-history-archive-manifest/v1",
        "manifest_sha256": "a" * 64,
        "owner_approval": {"approved": True},
        "files": [
            {"relative_path": "history/EURUSD.DWX/2019.hcc", "sha256": "1" * 64, "size": 1},
            {"relative_path": "ticks/EURUSD.DWX/2019.tkc", "sha256": "2" * 64, "size": 2},
            {"relative_path": "history/XAUUSD.DWX/2019.hcc", "sha256": "3" * 64, "size": 3},
            {"relative_path": "ticks/XAUUSD.DWX/2019.tkc", "sha256": "4" * 64, "size": 4},
            {"relative_path": "history/GBPUSD.DWX/2019.hcc", "sha256": "5" * 64, "size": 5},
        ],
    }


def _patch_validate(monkeypatch, counter):
    def fake_validate(manifest, require_owner_approval=True):
        counter.append(require_owner_approval)
        return manifest

    monkeypatch.setattr(coc, "validate_manifest", fake_validate)


def test_rows_preserve_manifest_order_across_symbols(monkeypatch):
    coc._VALIDATED_INDEX_CACHE.clear()
    _patch_validate(monkeypatch, [])
    rows, selected, ignored = coc.select_archive_rows_for_symbols(
        _manifest(), ["XAUUSD.DWX", "EURUSD.DWX", "QM5_BASKET_LABEL"]
    )
    assert [r["relative_path"] for r in rows] == [
        "history/EURUSD.DWX/2019.hcc",
        "ticks/EURUSD.DWX/2019.tkc",
        "history/XAUUSD.DWX/2019.hcc",
        "ticks/XAUUSD.DWX/2019.tkc",
    ]
    assert sorted(selected) == ["EURUSD.DWX", "XAUUSD.DWX"]
    assert ignored == ["QM5_BASKET_LABEL"]


def test_missing_symbol_still_fails_closed(monkeypatch):
    coc._VALIDATED_INDEX_CACHE.clear()
    _patch_validate(monkeypatch, [])
    try:
        coc.select_archive_rows_for_symbols(_manifest(), ["XCUUSD.DWX"])
    except coc.CustomHistoryCopyOnClaimError as exc:
        assert "XCUUSD.DWX" in str(exc)
    else:                                    # pragma: no cover - guard
        raise AssertionError("uncovered symbol must fail closed")


def test_same_manifest_object_validates_once(monkeypatch):
    coc._VALIDATED_INDEX_CACHE.clear()
    calls: list[bool] = []
    _patch_validate(monkeypatch, calls)
    manifest = _manifest()
    for _ in range(25):
        coc.select_archive_rows_for_symbols(manifest, ["EURUSD.DWX"])
    assert calls == [True]          # 25 admissions, one validation


def test_different_manifest_object_revalidates(monkeypatch):
    coc._VALIDATED_INDEX_CACHE.clear()
    calls: list[bool] = []
    _patch_validate(monkeypatch, calls)
    coc.select_archive_rows_for_symbols(_manifest(), ["EURUSD.DWX"])
    coc.select_archive_rows_for_symbols(_manifest(), ["EURUSD.DWX"])
    assert calls == [True, True]    # a new object is never trusted from cache


def test_returned_rows_are_copies(monkeypatch):
    coc._VALIDATED_INDEX_CACHE.clear()
    _patch_validate(monkeypatch, [])
    manifest = _manifest()
    first, _, _ = coc.select_archive_rows_for_symbols(manifest, ["EURUSD.DWX"])
    first[0]["sha256"] = "tampered"
    second, _, _ = coc.select_archive_rows_for_symbols(manifest, ["EURUSD.DWX"])
    assert second[0]["sha256"] == "1" * 64
