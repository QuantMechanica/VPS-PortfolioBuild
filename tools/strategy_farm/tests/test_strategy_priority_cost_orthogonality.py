import json
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import strategy_priority as subject  # noqa: E402


def _venue_model() -> dict:
    return {
        "_artifact": "venue_cost_model",
        "generated": "test-fixture",
        "canonical_engine": {
            "class_model": {
                "forex": {"flat_per_lot_rt": 5.0, "pct_rate_rt": 0.00005},
                "index": {"flat_per_lot_rt": 5.5, "pct_rate_rt": 0.00005},
                "commodity": {"flat_per_lot_rt": 0.0, "pct_rate_rt": 0.00005},
            }
        },
        "symbols": {
            "EURUSD": {"asset_class": "forex", "worst_case_rt_per_lot_usd": 5.85},
            "US100": {"asset_class": "index", "worst_case_rt_per_lot_usd": 5.5},
            "NDX": {"asset_class": "index", "alias_of": "US100"},
            "WS30": {"asset_class": "index", "worst_case_rt_per_lot_usd": 0.7},
            "US30": {"asset_class": "index", "alias_of": "WS30"},
            "SP500": {"asset_class": "index", "worst_case_rt_per_lot_usd": None},
        },
    }


def _fm(symbol: str) -> dict:
    return {
        "target_symbols": [symbol],
        "period": "H1",
        "expected_pf": "1.5",
        "expected_dd_pct": "15",
        "expected_trades_per_year_per_symbol": "100",
    }


def test_cheaper_registry_cost_class_scores_higher() -> None:
    model = _venue_model()
    cheap = subject.metrics_breakdown(_fm("WS30.DWX"), model, {})
    dear = subject.metrics_breakdown(_fm("EURUSD.DWX"), model, {})

    assert cheap["cost"] == 1.0
    assert dear["cost"] == 0.3
    assert cheap["value"] > dear["value"]
    assert cheap["cost_detail"]["symbols"][0]["worst_case_rt_per_lot_usd"] == 0.7


def test_symbol_absent_from_live_book_scores_more_orthogonal() -> None:
    model = _venue_model()
    book_counts = {"US100": 3}

    present, present_detail = subject.orthogonality_component(
        _fm("NDX.DWX"), book_counts, model
    )
    absent, absent_detail = subject.orthogonality_component(
        _fm("WS30.DWX"), book_counts, model
    )

    assert present == 0.25
    assert present_detail["overlap_count"] == 3
    assert absent == 1.0
    assert absent_detail["overlap_count"] == 0


def test_registry_aliases_normalize_manifest_and_card_symbols(tmp_path: Path) -> None:
    model = _venue_model()
    manifest = tmp_path / "book.json"
    manifest.write_text(
        json.dumps({"book": "fixture", "status": "TEST", "sleeves": [{"symbol": "US30.DWX"}]}),
        encoding="utf-8",
    )

    counts, provenance = subject.load_live_book_counts(manifest, model)
    score, detail = subject.orthogonality_component(_fm("WS30"), counts, model)

    assert subject.normalize_symbol("NDX.DWX", model) == "US100"
    assert subject.normalize_symbol("US30", model) == "WS30"
    assert counts == {"WS30": 1}
    assert score == 0.5
    assert detail["canonical_symbols"] == ["WS30"]
    assert provenance["load_status"] == "loaded"


def test_malformed_or_count_drifted_book_is_neutral_not_empty_book_reward(
    tmp_path: Path,
) -> None:
    model = _venue_model()
    malformed = tmp_path / "malformed.json"
    malformed.write_text(
        json.dumps({"n_sleeves": 2, "sleeves": [{"symbol": "US30"}, {}]}),
        encoding="utf-8",
    )
    counts, provenance = subject.load_live_book_counts(malformed, model)
    score, detail = subject.orthogonality_component(_fm("WS30"), counts, model)

    assert counts is None
    assert provenance["load_status"] == "invalid"
    assert provenance["error"] == "sleeve_symbol_not_string"
    assert score == subject.NEUTRAL_COMPONENT
    assert detail["status"] == "manifest_unavailable"

    count_drift = tmp_path / "count-drift.json"
    count_drift.write_text(
        json.dumps({"n_sleeves": 2, "sleeves": [{"symbol": "US30"}]}),
        encoding="utf-8",
    )
    counts, provenance = subject.load_live_book_counts(count_drift, model)
    assert counts is None
    assert provenance["load_status"] == "invalid"
    assert provenance["error"] == "n_sleeves_mismatch"

    non_string = tmp_path / "non-string.json"
    non_string.write_text(
        json.dumps({"n_sleeves": 1, "sleeves": [{"symbol": 123}]}),
        encoding="utf-8",
    )
    counts, provenance = subject.load_live_book_counts(non_string, model)
    assert counts is None
    assert provenance["load_status"] == "invalid"
    assert provenance["error"] == "sleeve_symbol_not_string"


def test_missing_or_unresolved_inputs_are_neutral_not_rewarded() -> None:
    fm = _fm("SP500.DWX")
    model = _venue_model()

    missing_cost, _ = subject.cost_component(fm, None)
    unresolved_cost, detail = subject.cost_component(fm, model)
    missing_book, _ = subject.orthogonality_component(fm, None, model)
    all_missing = subject.metrics_breakdown({}, None, None)
    placeholder = subject.metrics_breakdown(
        {"target_symbols": ["UNKNOWN.DWX"]}, model, {}
    )

    assert missing_cost == subject.NEUTRAL_COMPONENT
    assert unresolved_cost == subject.NEUTRAL_COMPONENT
    assert detail["symbols"][0]["source"] == "registry_unresolved"
    assert missing_book == subject.NEUTRAL_COMPONENT
    assert all_missing["value"] == subject.NEUTRAL_COMPONENT
    assert placeholder["cost"] == subject.NEUTRAL_COMPONENT
    assert placeholder["orthogonality"] == subject.NEUTRAL_COMPONENT


def test_score_is_deterministic_and_preserves_65_35_structure() -> None:
    model = _venue_model()
    cards = [
        {"ea_id": "QM5_9001", "slug": "cheap", "fm": _fm("WS30")},
        {"ea_id": "QM5_9002", "slug": "dear", "fm": _fm("EURUSD")},
    ]
    kwargs = {
        "venue_model": model,
        "book_symbol_counts": {"EURUSD": 2},
        "cost_provenance": {"path": "cost.json", "load_status": "loaded"},
        "book_provenance": {"path": "book.json", "load_status": "loaded"},
    }

    first = subject.score_cards(cards, {}, set(), **kwargs)
    second = subject.score_cards(cards, {}, set(), **kwargs)

    assert first == second
    for row in first:
        expected_score = round(
            100.0 * (subject.W_DIV_DEFAULT * row["div"] + subject.W_MET_DEFAULT * row["met"]),
            2,
        )
        assert row["score"] == expected_score
        assert row["met_weights"] == {"expected": 0.5, "cost": 0.2, "orthogonality": 0.3}
        assert row["cost_model_provenance"]["path"] == "cost.json"
        assert row["live_book_provenance"]["path"] == "book.json"


def test_compute_scores_emits_file_hash_provenance(tmp_path: Path) -> None:
    cards = tmp_path / "cards"
    cards.mkdir()
    (cards / "QM5_9003_fixture.md").write_text(
        "---\nea_id: QM5_9003\nslug: fixture\ntarget_symbols: [WS30.DWX]\nperiod: H1\n---\n",
        encoding="utf-8",
    )
    model_path = tmp_path / "venue.json"
    model_path.write_text(json.dumps(_venue_model()), encoding="utf-8")
    manifest_path = tmp_path / "manifest.json"
    manifest_path.write_text(
        json.dumps({"book": "fixture", "status": "TEST", "n_sleeves": 0, "sleeves": []}),
        encoding="utf-8",
    )

    result = subject.compute_scores(
        cards_dir=cards,
        db=tmp_path / "missing.sqlite",
        venue_cost_model_path=model_path,
        live_book_manifest_path=manifest_path,
    )["QM5_9003"]

    assert result["cost_model_provenance"]["load_status"] == "loaded"
    assert result["cost_model_provenance"]["path"] == str(model_path)
    assert len(result["cost_model_provenance"]["sha256"]) == 64
    assert result["live_book_provenance"]["load_status"] == "loaded"
    assert result["live_book_provenance"]["path"] == str(manifest_path)
    assert len(result["live_book_provenance"]["sha256"]) == 64

    neutral = subject.compute_scores(
        cards_dir=cards,
        db=tmp_path / "missing.sqlite",
        venue_cost_model_path=tmp_path / "missing-venue.json",
        live_book_manifest_path=tmp_path / "missing-book.json",
    )["QM5_9003"]
    assert neutral["met_cost"] == subject.NEUTRAL_COMPONENT
    assert neutral["met_orthogonality"] == subject.NEUTRAL_COMPONENT
    assert neutral["cost_model_provenance"]["load_status"] == "unavailable"
    assert neutral["live_book_provenance"]["load_status"] == "unavailable"


def test_compute_scores_cache_invalidates_when_evidence_files_change(
    tmp_path: Path,
) -> None:
    subject._SCORE_CACHE.clear()
    cards = tmp_path / "cards"
    cards.mkdir()
    (cards / "QM5_9004_fixture.md").write_text(
        "---\nea_id: QM5_9004\nslug: fixture\ntarget_symbols: [WS30.DWX]\nperiod: H1\n---\n",
        encoding="utf-8",
    )
    model_path = tmp_path / "venue.json"
    model_path.write_text(json.dumps(_venue_model()), encoding="utf-8")
    manifest_path = tmp_path / "manifest.json"
    manifest_path.write_text(
        json.dumps({"n_sleeves": 1, "sleeves": [{"symbol": "US30"}]}),
        encoding="utf-8",
    )

    first = subject.compute_scores(
        cards_dir=cards,
        db=tmp_path / "missing.sqlite",
        venue_cost_model_path=model_path,
        live_book_manifest_path=manifest_path,
    )["QM5_9004"]

    model_path.write_text(json.dumps(_venue_model(), indent=2), encoding="utf-8")
    manifest_path.write_text(
        json.dumps(
            {
                "n_sleeves": 2,
                "sleeves": [{"symbol": "US30"}, {"symbol": "WS30.DWX"}],
            }
        ),
        encoding="utf-8",
    )
    second = subject.compute_scores(
        cards_dir=cards,
        db=tmp_path / "missing.sqlite",
        venue_cost_model_path=model_path,
        live_book_manifest_path=manifest_path,
    )["QM5_9004"]

    assert first["cost_model_provenance"]["sha256"] != second["cost_model_provenance"]["sha256"]
    assert first["live_book_provenance"]["sha256"] != second["live_book_provenance"]["sha256"]
    assert first["met_orthogonality"] == 0.5
    assert second["met_orthogonality"] == 0.333
    subject._SCORE_CACHE.clear()
