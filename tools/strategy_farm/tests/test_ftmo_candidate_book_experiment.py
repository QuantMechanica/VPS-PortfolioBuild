from tools.strategy_farm.portfolio.ftmo_candidate_book_experiment import parse_scenario


def test_parse_scenario_with_multiple_candidate_sleeves():
    name, additions = parse_scenario(
        "speed=12986:GDAXI.DWX:1500,12969:USDJPY.DWX:1000"
    )

    assert name == "speed"
    assert additions == [
        (12986, "GDAXI.DWX", 1500.0),
        (12969, "USDJPY.DWX", 1000.0),
    ]


def test_parse_baseline_scenario():
    assert parse_scenario("baseline=") == ("baseline", [])
