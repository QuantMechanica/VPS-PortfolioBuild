from framework.scripts import audit_pattern_warmup as subject


def test_all_77_predicates_are_measured_by_depth():
    payload = subject.measure()
    assert payload["predicate_count"] == 77
    assert payload["depth_distribution"] == {
        "1": 2,
        "3": 47,
        "4": 3,
        "6": 6,
        "7": 1,
        "8": 1,
        "11": 7,
        "12": 2,
        "21": 3,
        "22": 3,
        "101": 2,
    }


def test_progressive_short_history_denies_until_required_depth():
    measured = subject.reproduce_depth(6)
    assert measured["reference_unavailable_denied_bars"] == 1
    assert measured["insufficient_history_denied_bars"] == 5
    assert measured["total_start_bars_denied"] == 6
    assert measured["first_tradable_current_bar_index"] == 6


def test_worst_case_is_reported_for_every_authorized_horizon():
    payload = subject.measure()
    rows = {row["timeframe"]: row for row in payload["timeframe_worst_case"]}
    assert set(rows) == {"M5", "M15", "H1", "H4", "D1"}
    assert all(row["worst_total_start_bars_denied"] == 101 for row in rows.values())
    assert rows["D1"]["nominal_elapsed_minutes_to_first_tradable_bar"] == 101 * 1440


def test_cache_verdict_quotes_reference_bar_scope():
    cache = subject.measure()["cache_scope"]
    assert cache["verdict"] == "NO_DEFECT_REFERENCE_BAR_SCOPED"
    assert cache["components"] == [
        "symbol",
        "reference_tf",
        "ref_bar",
        "QM_PP_ProfileKey(profile)",
    ]
