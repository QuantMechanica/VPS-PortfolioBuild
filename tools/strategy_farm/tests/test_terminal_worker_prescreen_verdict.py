from tools.strategy_farm import terminal_worker


def _summary() -> dict:
    return {
        "result": "PASS",
        "reason_classes": ["OK"],
        "evidence_class": "PRESCREEN",
        "model": 1,
        "model4_log_marker_detected": False,
        "runs": [{"status": "OK", "total_trades": 20, "real_ticks_marker": False}],
    }


def test_worker_uses_model_one_classifier_for_prescreen() -> None:
    payload = {"evidence_class": "PRESCREEN", "prescreen_model": 1}
    verdict, reason = terminal_worker._derive_worker_run_verdict(
        "OPT_CENSUS", payload, _summary(), min_trades=5
    )
    assert (verdict, reason) == ("PASS", "")


def test_worker_prescreen_projects_to_disjoint_measurement_verdict() -> None:
    payload = {"evidence_class": "PRESCREEN", "prescreen_model": 1}
    verdict, reason = terminal_worker._derive_worker_run_verdict(
        "OPT_CENSUS", payload, _summary(), min_trades=5
    )
    projected = terminal_worker.farmctl._apply_measurement_phase_verdict(
        "OPT_CENSUS", verdict, reason, payload
    )
    assert projected == (
        "PRESCREEN_MEASURED",
        "opt_census_prescreen_measured",
        "prescreen_measurement",
    )


def test_worker_rejects_model_four_under_prescreen_class() -> None:
    payload = {"evidence_class": "PRESCREEN", "prescreen_model": 1}
    summary = _summary()
    summary["model"] = 4
    verdict, reason = terminal_worker._derive_worker_run_verdict(
        "OPT_CENSUS", payload, summary, min_trades=5
    )
    assert (verdict, reason) == (
        "INFRA_FAIL",
        "PRESCREEN_EVIDENCE_CLASS_MISMATCH",
    )
