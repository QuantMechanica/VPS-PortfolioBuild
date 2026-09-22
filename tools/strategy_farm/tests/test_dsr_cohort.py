import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import dsr_cohort


def write_json(path: Path, value) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value), encoding="utf-8")
    return path


def fixture(tmp_path: Path, monkeypatch):
    monkeypatch.setattr(dsr_cohort, "DL089_DECLARED_TRIALS", 2)
    con = sqlite3.connect(":memory:")
    con.row_factory = sqlite3.Row
    con.execute("""CREATE TABLE work_items(
        id TEXT PRIMARY KEY, phase TEXT, ea_id TEXT, symbol TEXT, setfile_path TEXT,
        status TEXT, verdict TEXT, evidence_path TEXT, payload_json TEXT, updated_at TEXT)""")
    source = write_json(tmp_path / "source.json", {"runs": []})
    common = ("QM5_42", "EURUSD.DWX", "x.set", "done")
    for phase in ("Q02", "Q03"):
        con.execute(
            "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?)",
            (phase, phase, *common, "PASS", str(source),
             json.dumps({"expected_period": "D1", "expected_setfile_sha256": "b" * 64}),
             "2026-09-06T00:00:00+00:00"),
        )
    q12 = write_json(tmp_path / "q12.json", {"schema": "receipt"})
    con.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?)",
        ("q12", "Q12", *common, "OPT_ELIGIBLE", str(q12), "{}",
         "2026-09-06T00:00:00+00:00"),
    )
    cells = []
    for arm in ("buy_001", "sell_001"):
        for year in (2024, 2025):
            key = f"P:{year}:{arm}"
            wid = f"{arm}-{year}"
            cells.append({"cell_key": key, "arm": arm, "year": year})
            con.execute(
                "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?)",
                (wid, "OPT_CENSUS", *common, "MEASURED", str(source),
                 json.dumps({"program_id": "P", "cell_key": key, "arm": arm,
                             "year": year, "from_date": f"{year}.01.01",
                             "to_date": f"{year}.12.31"}),
                 "2026-09-06T00:00:00+00:00"),
            )
    ledger = {
        "schema": "qm.opt-census.v1", "authority": "DL-089", "program_id": "P",
        "subject_ea_id": "QM5_42", "symbol": "EURUSD.DWX", "timeframe": "D1",
        "years": [2024, 2025], "declared_trial_count": 2,
        "declared_trial_count_effective": 2, "sealed_rule_sha256": "a" * 64,
        "q12_work_item_id": "q12", "cells": cells,
        "driver": {"state": "PATTERN_SELECTION_READY", "numeric": {}},
    }
    write_json(tmp_path / "ledgers" / "P" / "ledger.json", ledger)
    candidate = {"id": "q07", "ea_id": "QM5_42", "symbol": "EURUSD.DWX",
                 "setfile_path": "x.set", "payload_json": "{}"}
    payload = {"expected_period": "D1", "from_date": "2024.01.01",
               "to_date": "2025.12.31"}
    monkeypatch.setattr(
        dsr_cohort, "_peer_metric",
        lambda trial_id, trial_index, rows, role: {
            "trial_index": trial_index, "trial_id": trial_id, "role": role,
            "frequency": "CALENDAR_DAY", "return_unit": "NET_CASH",
            "n_calendar_days": 731, "net_return_input": -1 if trial_index == 0 else 2,
            "sharpe_daily": -0.1 if trial_index == 0 else 0.2,
            "series_sha256": hashlib.sha256(trial_id.encode()).hexdigest(),
            "provenance": [],
        },
    )
    monkeypatch.setattr(
        dsr_cohort, "_pipeline_peer_metric",
        lambda row, trial_id, trial_index: {
            "trial_index": trial_index, "trial_id": trial_id, "role": "research",
            "frequency": "CALENDAR_DAY", "return_unit": "NET_CASH",
            "n_calendar_days": 731, "net_return_input": 1,
            "sharpe_daily": 0.05,
            "series_sha256": hashlib.sha256(trial_id.encode()).hexdigest(),
            "provenance": [],
        },
    )
    return con, candidate, payload


def test_complete_history_seals_and_attaches_deterministically(tmp_path, monkeypatch):
    con, candidate, payload = fixture(tmp_path, monkeypatch)
    kwargs = {"ledger_root": tmp_path / "ledgers", "artifact_root": tmp_path / "out"}
    status = dsr_cohort.attach(con, candidate, payload, **kwargs)
    assert status["status"] == "SEALED"
    assert set(payload["dsr_context"]) == {"path", "sha256"}
    path = Path(payload["dsr_context"]["path"])
    assert hashlib.sha256(path.read_bytes()).hexdigest() == payload["dsr_context"]["sha256"]
    first = payload["dsr_context"]
    payload2 = {"expected_period": "D1", "from_date": "2024.01.01",
                "to_date": "2025.12.31"}
    dsr_cohort.attach(con, candidate, payload2, **kwargs)
    assert payload2["dsr_context"] == first


def test_incomplete_loser_history_refuses_without_context(tmp_path, monkeypatch):
    con, candidate, payload = fixture(tmp_path, monkeypatch)
    con.execute("DELETE FROM work_items WHERE id='sell_001-2025'")
    status = dsr_cohort.attach(
        con, candidate, payload, ledger_root=tmp_path / "ledgers",
        artifact_root=tmp_path / "out",
    )
    assert status["status"] == "UNAVAILABLE"
    assert "MATRIX_CELL_MISSING" in status["reason"]
    assert "dsr_context" not in payload


def test_existing_payload_context_is_removed_on_refusal(tmp_path, monkeypatch):
    con, candidate, payload = fixture(tmp_path, monkeypatch)
    payload["dsr_context"] = {"path": "stale", "sha256": "0" * 64}
    con.execute("DELETE FROM work_items WHERE id='buy_001-2024'")
    dsr_cohort.attach(
        con, candidate, payload, ledger_root=tmp_path / "ledgers",
        artifact_root=tmp_path / "out",
    )
    assert "dsr_context" not in payload
    assert payload["dsr_context_status"]["status"] == "UNAVAILABLE"


def test_claimability_precheck_agrees_with_attach_on_a_sealed_dl089_candidate(tmp_path, monkeypatch):
    con, candidate, payload = fixture(tmp_path, monkeypatch)
    result = dsr_cohort.claimability_precheck(
        con, candidate, payload, ledger_root=tmp_path / "ledgers"
    )
    assert result == {"claimable": True, "reason": None}
    # Precheck must never mutate the caller's payload (it is speculative,
    # run before the row is claimed; the real seal below still needs a
    # pristine payload to attach dsr_context to).
    assert "dsr_context" not in payload
    status = dsr_cohort.attach(
        con, candidate, payload, ledger_root=tmp_path / "ledgers",
        artifact_root=tmp_path / "out",
    )
    assert status["status"] == "SEALED"


def test_claimability_precheck_rejects_unresolvable_window_same_as_assemble(tmp_path, monkeypatch):
    """2026-09-15 head-of-line starvation fix: a Q08 row whose window can never
    resolve (no from_date/to_date, no data_window_start/end, no lineage) must
    be predicted False by the cheap precheck -- and that False must agree
    with what attach() would find at real claim time, so the claim-order
    preflight can safely skip it without ever paying for the out-of-lock
    history preflight."""
    con, candidate, payload = fixture(tmp_path, monkeypatch)
    broken_payload = {"expected_period": "D1"}  # from_date/to_date removed
    result = dsr_cohort.claimability_precheck(con, candidate, broken_payload)
    assert result["claimable"] is False
    assert result["reason"] == "CANDIDATE_WINDOW_UNAVAILABLE"
    broken_payload["claimed_at_iso"] = "2026-09-15T09:30:00+00:00"
    status = dsr_cohort.attach(
        con, candidate, broken_payload, ledger_root=tmp_path / "ledgers",
        artifact_root=tmp_path / "out",
    )
    assert status["status"] == "UNAVAILABLE"
    assert status["reason"] == "CANDIDATE_WINDOW_UNAVAILABLE"


def test_claimability_precheck_rejects_unresolvable_timeframe(tmp_path, monkeypatch):
    con, candidate, payload = fixture(tmp_path, monkeypatch)
    broken_payload = {"from_date": "2024.01.01", "to_date": "2025.12.31"}
    broken_candidate = dict(candidate, setfile_path="no_timeframe_token.set")
    result = dsr_cohort.claimability_precheck(con, broken_candidate, broken_payload)
    assert result == {"claimable": False, "reason": "CANDIDATE_TIMEFRAME_UNAVAILABLE"}


def test_claimability_precheck_never_needs_claimed_at_iso_on_the_single_configuration_path(
    tmp_path, monkeypatch
):
    """The single-configuration fallback's factory-search-ledger step is the
    ONE part of assemble() that depends on payload['claimed_at_iso'] (the
    claim timestamp is not known until the row is actually claimed). The
    precheck must never reach it -- if it did, this monkeypatched sentinel
    would raise on a payload that deliberately has no claimed_at_iso."""
    import dsr_cohort as dc

    def _boom(*_args, **_kwargs):
        raise AssertionError(
            "claimability_precheck must never call the claim-time-dependent "
            "factory-search-ledger step"
        )

    monkeypatch.setattr(dc, "_find_ledger", lambda **_k: (_ for _ in ()).throw(
        dc.CohortUnavailable("SEALED_SEARCH_LEDGER_UNAVAILABLE")
    ))
    monkeypatch.setattr(dc, "_factory_search_before_q08_claim", _boom)
    monkeypatch.setattr(
        dc,
        "_resolve_single_configuration_identity",
        lambda candidate, payload, timeframe: (
            {"ea_id": "QM5_42", "symbol": "EURUSD.DWX", "timeframe": timeframe},
            {},
            {},
        ),
    )
    con = sqlite3.connect(":memory:")
    candidate = {
        "id": "q08-single", "ea_id": "QM5_42", "symbol": "EURUSD.DWX",
        "setfile_path": "x_D1_x.set",
    }
    payload_without_claim_time = {"from_date": "2024.01.01", "to_date": "2025.12.31"}
    result = dc.claimability_precheck(con, candidate, payload_without_claim_time)
    assert result == {"claimable": True, "reason": None}


def test_claimability_precheck_reports_unbound_identity_not_mismatch(
    tmp_path, monkeypatch
):
    monkeypatch.setattr(
        dsr_cohort,
        "_find_ledger",
        lambda **_kwargs: (_ for _ in ()).throw(
            dsr_cohort.CohortUnavailable("SEALED_SEARCH_LEDGER_UNAVAILABLE")
        ),
    )
    con = sqlite3.connect(":memory:")
    candidate = {
        "id": "q08-unbound",
        "ea_id": "QM5_42",
        "symbol": "EURUSD.DWX",
        "setfile_path": str(tmp_path / "QM5_42_EURUSD.DWX_D1_backtest.set"),
        "mq5_sha256": None,
        "ex5_sha256": None,
        "setfile_sha256": None,
    }
    payload = {
        "expected_period": "D1",
        "from_date": "2024.01.01",
        "to_date": "2025.12.31",
    }

    result = dsr_cohort.claimability_precheck(con, candidate, payload)

    assert result == {
        "claimable": False,
        "reason": "SINGLE_CONFIGURATION_UNAVAILABLE:BUILD_IDENTITY_UNBOUND",
        "binding_required": True,
    }


def test_claimability_precheck_preserves_genuine_mismatch_semantics(
    tmp_path, monkeypatch
):
    monkeypatch.setattr(
        dsr_cohort,
        "_find_ledger",
        lambda **_kwargs: (_ for _ in ()).throw(
            dsr_cohort.CohortUnavailable("SEALED_SEARCH_LEDGER_UNAVAILABLE")
        ),
    )
    monkeypatch.setattr(
        dsr_cohort,
        "_resolve_single_configuration_identity",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            dsr_cohort.CohortUnavailable(
                "SINGLE_CONFIGURATION_UNAVAILABLE:BUILD_IDENTITY_MISMATCH:mq5"
            )
        ),
    )
    con = sqlite3.connect(":memory:")
    candidate = {
        "id": "q08-drifted",
        "ea_id": "QM5_42",
        "symbol": "EURUSD.DWX",
        "setfile_path": str(tmp_path / "QM5_42_EURUSD.DWX_D1_backtest.set"),
    }
    payload = {
        "expected_period": "D1",
        "from_date": "2024.01.01",
        "to_date": "2025.12.31",
    }

    result = dsr_cohort.claimability_precheck(con, candidate, payload)

    assert result == {
        "claimable": False,
        "reason": "SINGLE_CONFIGURATION_UNAVAILABLE:BUILD_IDENTITY_MISMATCH:mq5",
    }


def test_window_pair_accepts_bare_year_edges():
    """2026-09-14: Q08 reruns declare expected_from_date='2017'/expected_to_date='2022'; a bare year is a
    whole-year edge (first day for from, last day for to); partial or malformed dates stay refused."""
    import dsr_cohort as dc

    assert dc._window_pair("2017", "2022") == {"from": "2017-01-01", "to": "2022-12-31"}
    assert dc._window_pair("2018.07.02", "2022") == {"from": "2018-07-02", "to": "2022-12-31"}
    assert dc._window_pair("2022", "2017") is None
    assert dc._window_pair("2017-13", "2022") is None
    assert dc._window_pair("", "2022") is None
