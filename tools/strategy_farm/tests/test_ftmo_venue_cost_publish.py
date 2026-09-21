from tools.strategy_farm.ftmo import venue_cost_publish as publish


def test_publish_only_changes_venue_block() -> None:
    state = {
        "schema": "qm.ftmo-book-current/v1",
        "financing": {"label": "FINANCED"},
        "result": {"P_FIRST_NET_FTMO_PAYOUT_LCB": 0.8},
        "venue_adjusted": {"old": True},
    }
    updated, stable_hash = publish.publish(state, {"status": "NEW"})
    assert updated["venue_adjusted"]["status"] == "NEW"
    assert updated["venue_adjusted"]["non_venue_state_sha256"] == stable_hash
    assert publish._without_venue(updated) == publish._without_venue(state)


def test_publish_refuses_unfinanced_state() -> None:
    try:
        publish.publish({"financing": {"label": "UNFINANCED"}}, {})
    except ValueError as exc:
        assert "not FINANCED" in str(exc)
    else:
        raise AssertionError("unfinanced state must be refused")
