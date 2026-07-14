import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))

from tools.strategy_farm.portfolio import ftmo_book_readiness as readiness  # noqa: E402


def test_book_requires_both_contracts_for_every_sleeve() -> None:
    book = {
        (1001, "NDX.DWX"): {"risk_fixed": 500, "tf": "H1"},
        (1002, "GBPUSD.DWX"): {"risk_fixed": 400, "tf": "H4"},
    }
    qualification = {
        "candidates": [
            {"ea_id": "QM5_1001", "symbol": "NDX.DWX", "challenge_ready": True, "state": "CHALLENGE_READY", "blockers": []},
            {"ea_id": "QM5_1002", "symbol": "GBPUSD.DWX", "challenge_ready": False, "state": "NOT_QUALIFIED", "blockers": ["q08_not_pass"]},
        ],
    }
    reconciliation = {
        "results": [
            {"ea_id": 1001, "symbol": "NDX.DWX", "status": "PASS", "reasons": []},
            {"ea_id": 1002, "symbol": "GBPUSD.DWX", "status": "PASS", "reasons": []},
        ],
    }

    result = readiness.build_readiness(book, qualification, reconciliation)

    assert result["status"] == "NO_GO"
    assert result["ready_count"] == 1
    assert result["qualification_ready_count"] == 1
    assert result["reconciliation_pass_count"] == 2
    assert result["nominal_risk_fixed_sum"] == 900.0


def test_missing_reconciliation_is_fail_closed() -> None:
    book = {(1001, "NDX.DWX"): {"risk_fixed": 500, "tf": "H1"}}
    qualification = {
        "candidates": [{
            "ea_id": "QM5_1001",
            "symbol": "NDX.DWX",
            "challenge_ready": True,
            "state": "CHALLENGE_READY",
            "blockers": [],
        }],
    }

    result = readiness.build_readiness(book, qualification, {"results": []})

    assert result["status"] == "NO_GO"
    assert result["sleeves"][0]["blockers"] == ["stream_reconciliation_missing"]


def test_complete_book_is_ready() -> None:
    book = {(1001, "NDX.DWX"): {"risk_fixed": 500, "tf": "H1"}}
    qualification = {
        "candidates": [{
            "ea_id": "QM5_1001",
            "symbol": "NDX.DWX",
            "challenge_ready": True,
            "state": "CHALLENGE_READY",
            "blockers": [],
        }],
    }
    reconciliation = {
        "results": [{"ea_id": 1001, "symbol": "NDX.DWX", "status": "PASS", "reasons": []}],
    }

    result = readiness.build_readiness(book, qualification, reconciliation)

    assert result["status"] == "READY"
    assert result["ready_count"] == 1
