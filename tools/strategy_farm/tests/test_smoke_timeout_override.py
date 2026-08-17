"""The payload timeout_min override must budget the smoke layer, not only the
worker watchdog (2026-08-16: XAU/XAG 2-member baskets burned every attempt on
the flat 2h floor while carrying timeout_min=450)."""

import json
import sqlite3

import farmctl


def test_payload_floor_unset_or_invalid_is_zero():
    assert farmctl._payload_timeout_floor_seconds({}) == 0
    assert farmctl._payload_timeout_floor_seconds({"timeout_min": None}) == 0
    assert farmctl._payload_timeout_floor_seconds({"timeout_min": "abc"}) == 0
    assert farmctl._payload_timeout_floor_seconds({"timeout_min": -5}) == 0


def test_payload_floor_scales_and_caps():
    assert farmctl._payload_timeout_floor_seconds({"timeout_min": 450}) == 25200
    assert farmctl._payload_timeout_floor_seconds({"timeout_min": 10}) == 600
    # 7h cap like the member-count formula
    assert farmctl._payload_timeout_floor_seconds({"timeout_min": 10000}) == 25200


def test_q02_full_two_member_basket_with_override_beats_2h_floor():
    payload = {"basket_symbol_count": 2, "timeout_min": 450}
    got = farmctl._p2_full_timeout_seconds(payload, "2018.07.02", "2022.12.31")
    assert got == 25200  # 450min capped at 7h, well above the 7200 floor


def test_q02_member_floor_fires_for_small_medium_and_large_baskets():
    assert farmctl._p2_basket_member_timeout_floor_seconds(2) == 14400
    assert farmctl._p2_basket_member_timeout_floor_seconds(9) == 17200
    assert farmctl._p2_basket_member_timeout_floor_seconds(28) == 24800


def test_q02_single_symbol_budget_is_unchanged():
    got = farmctl._p2_full_timeout_seconds(
        {"basket_symbol_count": 1}, "2018.07.02", "2022.12.31"
    )
    assert got == farmctl.P2_FULL_TIMEOUT_MIN_SECONDS


def test_override_never_shrinks_many_member_budget():
    payload = {"basket_symbol_count": 28, "timeout_min": 450}
    got = farmctl._p2_full_timeout_seconds(payload, "2018.07.02", "2022.12.31")
    assert got == farmctl.P2_BASKET_TIMEOUT_MAX_SECONDS


def test_prescreen_estimate_has_basket_only_seven_hour_ceiling():
    common = {
        "p2_prescreen_runtime_sec": 1800,
        "p2_prescreen_from_date": "2022.07.01",
        "p2_prescreen_to_date": "2022.12.31",
    }
    basket = farmctl._p2_full_timeout_seconds(
        {**common, "basket_symbol_count": 2}, "2017.01.01", "2022.12.31"
    )
    single = farmctl._p2_full_timeout_seconds(
        {**common, "basket_symbol_count": 1}, "2017.01.01", "2022.12.31"
    )
    assert basket == farmctl.P2_BASKET_TIMEOUT_MAX_SECONDS
    assert single == farmctl.P2_FULL_TIMEOUT_MAX_SECONDS


def _wall_summary(timestamp: str = "2026-08-17T02:00:30+00:00") -> dict:
    return {
        "result": "FAIL",
        "attempted_runs": 1,
        "max_run_attempts": 3,
        "timestamp_utc": timestamp,
        "oninit_failure_detected": False,
        "log_bomb_detected": False,
        "model4_log_marker_detected": False,
        "reason_classes": ["TIMEOUT", "INCOMPLETE_RUNS"],
        "runs": [{"failure": "TIMEOUT", "error": "timed out after 7200 seconds"}],
    }


def _wall_payload() -> dict:
    return {
        "portfolio_scope": "basket",
        "basket_symbol_count": 2,
        "timeout_seconds": 7200,
        "started_at_iso": "2026-08-17T00:00:00+00:00",
    }


def test_budget_wall_classifier_excludes_oninit_and_log_bombs():
    matched, detail = farmctl._q02_budget_wall_failure(_wall_payload(), _wall_summary())
    assert matched, detail

    oninit = _wall_summary()
    oninit["oninit_failure_detected"] = True
    assert farmctl._q02_budget_wall_failure(_wall_payload(), oninit)[0] is False

    log_bomb = _wall_summary()
    log_bomb["log_bomb_detected"] = True
    assert farmctl._q02_budget_wall_failure(_wall_payload(), log_bomb)[0] is False


def test_two_consecutive_clean_wall_deaths_open_the_breaker(tmp_path):
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute(
        """CREATE TABLE work_items (
        id TEXT, phase TEXT, ea_id TEXT, symbol TEXT, setfile_path TEXT,
        status TEXT, verdict TEXT, evidence_path TEXT, payload_json TEXT,
        updated_at TEXT)"""
    )
    for index in (1, 2):
        summary_path = tmp_path / f"summary_{index}.json"
        summary_path.write_text(json.dumps(_wall_summary()), encoding="utf-8")
        conn.execute(
            "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?)",
            (
                f"wall-{index}", "Q02", "QM5_90000", "QM5_90000_BASKET_D1",
                "basket.set", "done", "INFRA_FAIL", str(summary_path),
                json.dumps(_wall_payload()), f"2026-08-17T0{index}:00:00+00:00",
            ),
        )
    conn.commit()

    streak = farmctl._q02_budget_wall_streak(
        conn, "QM5_90000", "QM5_90000_BASKET_D1", "basket.set"
    )
    assert [row["work_item_id"] for row in streak] == ["wall-2", "wall-1"]
