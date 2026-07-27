from tools.strategy_farm.compare_joint_replay import classify


def trade(entry, close, volume=1.0, net=10.0):
    return {"entry_time": entry, "time": close, "volume": volume, "net": net}


def test_mismatch_categories_are_exhaustive():
    gated = [trade(1, 2), trade(3, 4), trade(5, 6), trade(7, 8)]
    joint = [trade(1, 2), trade(3, 40), trade(50, 60), trade(70, 80)]
    assert classify(joint, gated, .005, .005) == {
        "exact": 1,
        "same_entry_same_volume_shifted_exit": 1,
        "different_entry": 2,
        "extra": 0,
        "missing": 0,
    }


def test_extra_and_missing():
    assert classify([trade(1, 2)], [], .005, .005)["extra"] == 1
    assert classify([], [trade(1, 2)], .005, .005)["missing"] == 1
