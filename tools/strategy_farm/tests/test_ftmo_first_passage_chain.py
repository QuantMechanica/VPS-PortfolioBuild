"""Tests for the FTMO first-passage CHAIN (schema v2, engine 2.1.0).

KPI contract `docs/ftmo/FTMO_KPI_CONTRACT.md` section 2: Phase 1 -> Verification ->
funded account -> first net cash payout. Covers: degenerate always-win / always-lose
streams, the pathwise product bound, seeded determinism, the minimum-trading-day
continuation rule, the fee/refund economics, and v1 schema-field preservation.
"""
from __future__ import annotations

import datetime as dt
import json
from zoneinfo import ZoneInfo

import numpy as np

from tools.strategy_farm.ftmo import first_passage as fp


TZ = ZoneInfo("Europe/Prague")


# --------------------------------------------------------------------------- #
# Synthetic book grids
# --------------------------------------------------------------------------- #
def _grid(net, low, opened):
    """Hand-built book grid (same shape build_grid() produces)."""
    n = len(net)
    sleeve = fp.SleeveInput(ea_id=1, ftmo_symbol="X", dwx_symbol="X.DWX", magic=1,
                            risk_pct=1.0, stream_path="mem", stream_sha256="0",
                            trades=[], daily={})
    return {
        "ok": True,
        "active_sleeves": [sleeve],
        "grid": [dt.date(2026, 1, 1) + dt.timedelta(days=i) for i in range(n)],
        "business_days": n,
        "net": np.array(net, dtype=float),
        "low": np.array(low, dtype=float),
        "lots": np.zeros(n),
        "commission": np.zeros(n),
        "opened": np.array(opened, dtype=bool),
        "dom_idx": np.zeros(n, dtype=int),
        "weekday": np.zeros(n, dtype=int),
    }


def _flat_grid(net_per_day, low_per_day, n=20, opened=True):
    return _grid([net_per_day] * n, [low_per_day] * n, [opened] * n)


def _chain(grid, **kw):
    params = dict(seed=4242, n_paths=400, block_len=5, horizon=120,
                  funded_horizon=60, n_batches=20)
    params.update(kw)
    return fp.simulate_chain(grid, fp.load_rules(), fp.load_economics(), **params)


# --------------------------------------------------------------------------- #
# Degenerate streams: the chain must saturate at 1 and at 0
# --------------------------------------------------------------------------- #
def test_always_winning_stream_passes_whole_chain():
    chain = _chain(_flat_grid(3000.0, 0.0))
    probs = chain["probabilities"]
    assert probs["P_CHALLENGE_PASS"] == 1.0
    assert probs["P_VERIFICATION_PASS_GIVEN_CHALLENGE"] == 1.0
    assert probs["P_FTMO_ACCOUNT_SURVIVAL_TO_FIRST_REWARD"] == 1.0
    assert probs["P_END_TO_END_FIRST_PAYOUT"] == 1.0
    assert probs["P_FIRST_NET_FTMO_PAYOUT"] == 1.0
    assert probs["P_FIRST_NET_FTMO_PAYOUT_LCB"] == 1.0
    # +3000/day: target +10000 on day 4, which is also the 4th trading day.
    assert chain["time_business_days"]["phase1_target"]["p50"] == 4.0
    # funded payout: first trade day 1 + 10 business days eligibility + 4 processing
    assert chain["time_business_days"]["first_payout"]["p50"] == 15.0
    frontier = chain["payout_frontier"]
    assert frontier["payout_by_calendar_day"]["30"]["probability"] == 0.0
    assert frontier["payout_by_calendar_day"]["45"]["lcb_90pct"] == 1.0
    assert frontier["unconditional_t80"]["status"] == "REACHED_IN_MARKET_PATH_MODEL"
    assert frontier["unconditional_t80"]["business_day"] == 23
    assert frontier["conditional_on_positive_net_payout"]["business_days"]["p50"] == 23.0
    assert frontier["outcome_partition_unconditional"]["positive_net_payout"]["probability"] == 1.0


def test_always_losing_stream_fails_whole_chain():
    chain = _chain(_flat_grid(-3000.0, -3000.0))
    probs = chain["probabilities"]
    assert probs["P_CHALLENGE_PASS"] == 0.0
    assert probs["P_END_TO_END_FIRST_PAYOUT"] == 0.0
    assert probs["P_FIRST_NET_FTMO_PAYOUT"] == 0.0
    assert probs["P_FIRST_NET_FTMO_PAYOUT_LCB"] == 0.0
    # it dies on the static 10% Maximum Loss, not on the 5% daily limit
    assert chain["stages"]["phase1"]["p_max_loss_breach"] == 1.0
    assert chain["stages"]["phase1"]["p_daily_loss_breach"] == 0.0
    # the funded stage never reaches a positive closed balance -> no reward
    assert chain["stages"]["funded"]["p_survive_to_first_reward"] == 0.0
    frontier = chain["payout_frontier"]
    assert frontier["unconditional_t80"]["status"] == "NOT_REACHED"
    assert frontier["outcome_partition_unconditional"]["phase1_max_loss_breach"]["probability"] == 1.0


def test_reward_scenarios_keep_fee_refund_separate() -> None:
    rows = fp._reward_scenarios(100000.0, fp.load_economics())
    by_name = {row["scenario"]: row for row in rows}
    first = by_name["ENGINE_FIRST_POSITIVE_NET_REWARD"]
    assert first["payment_method_minimum_usd"] is None
    assert first["status"] == "MODEL_THRESHOLD_ONLY_PAYMENT_METHOD_MINIMUM_UNBOUND"
    assert by_name["FUNDED_GAIN_0.5PCT"] == {
        "scenario": "FUNDED_GAIN_0.5PCT",
        "funded_gain_fraction": 0.005,
        "funded_profit_usd": 500.0,
        "reward_usd": 400.0,
        "fee_paid_usd": 540.0,
        "fee_refund_usd": 540.0,
        "net_cash_usd": 400.0,
    }
    assert by_name["FUNDED_GAIN_1PCT"]["net_cash_usd"] == 800.0
    assert by_name["FUNDED_GAIN_2PCT"]["net_cash_usd"] == 1600.0


def test_conditional_probability_is_none_when_no_path_reaches_the_stage():
    chain = _chain(_flat_grid(-3000.0, -3000.0))
    # never invent a conditional probability on an empty conditioning set
    assert chain["probabilities"]["P_VERIFICATION_PASS_GIVEN_CHALLENGE"] is None
    assert chain["probabilities"]["P_FTMO_ACCOUNT_SURVIVAL_TO_FIRST_REWARD"] is None


# --------------------------------------------------------------------------- #
# Pathwise vs product of marginals
# --------------------------------------------------------------------------- #
def _mixed_grid(n=40, seed=7):
    """Deterministic mixed book: positive drift, real intraday drawdown."""
    rng = np.random.default_rng(seed)
    net = rng.normal(400.0, 700.0, size=n)
    low = np.minimum(net, 0.0) - np.abs(rng.normal(400.0, 200.0, size=n))
    return _grid(net.tolist(), low.tolist(), [True] * n)


def test_pathwise_end_to_end_never_exceeds_any_marginal():
    chain = _chain(_mixed_grid(), n_paths=2000)
    pathwise = chain["probabilities"]["P_END_TO_END_FIRST_PAYOUT"]
    marginals = chain["marginals_unconditional"]
    assert 0.0 < pathwise < 1.0, pathwise  # a genuinely mixed book
    assert pathwise <= min(marginals.values()) + 1e-9, (pathwise, marginals)
    # the net-positive condition can only remove paths from the end-to-end set
    assert chain["probabilities"]["P_FIRST_NET_FTMO_PAYOUT"] <= pathwise + 1e-9
    # and the LCB can only sit at or below the point estimate
    assert chain["probabilities"]["P_FIRST_NET_FTMO_PAYOUT_LCB"] <= (
        chain["probabilities"]["P_FIRST_NET_FTMO_PAYOUT"] + 1e-9)


def test_product_of_marginals_reported_next_to_pathwise():
    chain = _chain(_mixed_grid(), n_paths=2000)
    probs = chain["probabilities"]
    product = probs["P_END_TO_END_FIRST_PAYOUT_PRODUCT_OF_MARGINALS"]
    marginals = chain["marginals_unconditional"]
    assert product is not None
    expected = marginals["phase1"] * marginals["verification"] * marginals["funded_survival"]
    assert abs(product - expected) < 1e-4  # both reported rounded to 4 decimals
    # both are reported; the pathwise figure is the one the contract binds
    assert probs["P_END_TO_END_FIRST_PAYOUT"] is not None


def test_credible_interval_brackets_the_point_estimate():
    chain = _chain(_mixed_grid(), n_paths=2000)
    ci = chain["credible_intervals_90pct"]["P_END_TO_END_FIRST_PAYOUT"]
    point = chain["probabilities"]["P_END_TO_END_FIRST_PAYOUT"]
    assert ci["n_batches"] == 20
    assert ci["batch_size"] == 100
    assert ci["p05"] <= point <= ci["p95"]


# --------------------------------------------------------------------------- #
# Independent draws per stage, seeded determinism
# --------------------------------------------------------------------------- #
def test_stage_draws_are_independent_not_a_replay():
    a = fp._stage_index_matrix(2026, 1, 40, 50, 30, 5)
    b = fp._stage_index_matrix(2026, 2, 40, 50, 30, 5)
    c = fp._stage_index_matrix(2026, 3, 40, 50, 30, 5)
    assert not np.array_equal(a, b)
    assert not np.array_equal(b, c)
    # ... but each stage stream is itself reproducible
    assert np.array_equal(b, fp._stage_index_matrix(2026, 2, 40, 50, 30, 5))


def test_chain_is_deterministic_for_a_fixed_seed():
    grid = _mixed_grid()
    a = _chain(grid, n_paths=1000)
    b = _chain(grid, n_paths=1000)
    assert json.dumps(a, sort_keys=True) == json.dumps(b, sort_keys=True)


# --------------------------------------------------------------------------- #
# Minimum trading days (4 CE(S)T days with a newly opened position)
# --------------------------------------------------------------------------- #
def test_target_before_min_days_must_keep_trading_and_can_still_breach():
    """Target on day 1, only one opening day, then a max-loss breach -> no pass."""
    n = 30
    # +11000 on day 1 (target met) but only ONE opening day; the book then bleeds
    # -4000/day, each day inside the 5% daily limit, until the static 10% Maximum
    # Loss is breached. The path may not pass and must not be scored as a pass.
    net = [11000.0, 0.0] + [-4000.0] * 8 + [0.0] * (n - 10)
    low = [0.0, 0.0] + [-4000.0] * 8 + [0.0] * (n - 10)
    opened = [True] + [False] * (n - 1)
    chain = _chain(_grid(net, low, opened), block_len=n, horizon=n, funded_horizon=n)
    phase1 = chain["stages"]["phase1"]
    assert phase1["min_trading_days"]["required"] == 4
    assert phase1["p_pass"] == 0.0
    assert phase1["p_max_loss_breach"] == 1.0
    assert phase1["p_daily_loss_breach"] == 0.0
    assert phase1["min_trading_days"]["p_target_before_min_days"] == 1.0
    assert phase1["min_trading_days"]["p_breached_after_target_before_min_days"] == 1.0


def test_min_trading_days_delay_is_reported_when_it_only_postpones_the_pass():
    """Target on day 1 but the 4th opening day arrives later -> pass is delayed."""
    n = 30
    net = [11000.0] + [0.0] * (n - 1)
    chain = _chain(_grid(net, [0.0] * n, [True] * n), block_len=n, horizon=n,
                   funded_horizon=n)
    phase1 = chain["stages"]["phase1"]
    assert phase1["p_pass"] == 1.0
    assert phase1["min_trading_days"]["p_pass_delayed_by_min_days"] == 1.0
    assert chain["time_business_days"]["phase1_target"]["p50"] == 4.0


# --------------------------------------------------------------------------- #
# Payout economics
# --------------------------------------------------------------------------- #
def test_fee_comes_from_the_rulepack_and_can_be_overridden():
    pack = fp.load_economics()
    assert pack["fee_usd"] == 540.0
    assert pack["fee_source"] == "RULEPACK_LIST_FEE"
    assert pack["reward_split_percent"] == 80.0
    assert pack["fee_refund_percent"] == 100.0
    assert fp.load_economics(fee_usd=725.0)["fee_source"] == "CLI_OVERRIDE"


def test_fee_defaults_are_flagged_when_the_rulepack_carries_none(tmp_path):
    absent = fp.load_economics(tmp_path / "no_such_rulepack.json")
    assert absent["fee_usd"] == fp.DEFAULT_FEE_USD
    assert absent["fee_source"] == "ASSUMED_DEFAULT"


def test_net_cash_applies_split_and_refund():
    econ = fp.load_economics()
    cash = fp.net_cash_from_profit(np.array([0.0, 1000.0]), econ)
    # 100% refund: net cash is exactly the 80% split of the funded profit
    assert cash[0] == 0.0
    assert abs(cash[1] - 800.0) < 1e-9
    assert fp.min_profit_for_net_positive(econ) == 0.0
    # without a refund the first reward has to cover the fee itself
    no_refund = dict(econ, fee_refund_percent=0.0)
    assert abs(fp.min_profit_for_net_positive(no_refund) - 675.0) < 1e-9
    assert fp.net_cash_from_profit(np.array([675.0]), no_refund)[0] == 0.0


# --------------------------------------------------------------------------- #
# Schema: v2 is additive, every v1 field survives
# --------------------------------------------------------------------------- #
def _fixture_roster(tmp_path):
    rng = np.random.default_rng(3)
    base = dt.datetime(2020, 1, 1, tzinfo=dt.timezone.utc)
    path = tmp_path / "2001_GBPUSD_DWX.jsonl"
    lines = []
    day = 0
    for _ in range(300):
        day += int(rng.integers(1, 3))
        close = base + dt.timedelta(days=day, hours=15)
        lines.append(json.dumps({
            "event": "TRADE_CLOSED", "time": int(close.timestamp()),
            "entry_time": int((close - dt.timedelta(hours=2)).timestamp()),
            "net": round(float(rng.normal(150.0, 700.0)), 2),
            "mae_acct": round(-abs(float(rng.normal(250.0, 150.0))), 2),
            "volume": 1.0, "commission": -5.0, "symbol": "GBPUSD.DWX"}))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return fp.roster_from_spec([{"ea_id": 2001, "symbol": "GBPUSD", "risk_pct": 1.0,
                                 "stream_path": str(path)}], TZ)


def _model(tmp_path, **kw):
    params = dict(roster=_fixture_roster(tmp_path), rules=fp.load_rules(), seed=99,
                  n_paths=1000, horizon=300, funded_horizon=60,
                  now=dt.datetime(2026, 9, 18, tzinfo=dt.timezone.utc))
    params.update(kw)
    return fp.build(**params)


def test_v1_fields_are_preserved_under_schema_v2(tmp_path):
    model = _model(tmp_path)
    assert model["schema"] == "qm.ftmo-first-passage/v2"
    assert model["engine_version"] == "2.1.0"
    assert model["kpi_contract_version"] == "v1"
    assert model["status"] == "OK"
    for key in ("p_target_hit", "p_daily_loss_breach", "p_max_loss_breach",
                "p_censored", "time_to_target_business_days",
                "pass_within_calendar_days", "conditional_failure_modes",
                "p_target_hit_conditional_on_resolution"):
        assert key in model["headline"], key
    for key in ("p_target_hit", "p_target_hit_eventual", "p_pass_30d", "p_pass_60d",
                "median_days", "p_daily_loss_breach", "p_max_loss_breach",
                "p_censored", "horizon_note"):
        assert key in model["compact_for_readiness"], key
    assert len(model["sensitivity"]) == len(fp.DEFAULT_SENSITIVITY)
    for key in ("roster", "dropped_sleeves", "rulepack", "params", "window",
                "input_manifest", "input_manifest_sha256", "method"):
        assert key in model, key


def test_chain_block_and_readiness_keys_are_additive(tmp_path):
    model = _model(tmp_path)
    chain = model["chain"]
    assert set(chain["stages"]) == {"phase1", "verification", "funded"}
    assert len(chain["sensitivity"]) == len(fp.DEFAULT_SENSITIVITY)
    for scenario in chain["sensitivity"]:
        assert "P_END_TO_END_FIRST_PAYOUT" in scenario
    compact = model["compact_for_readiness"]
    for key in ("p_challenge_pass", "p_end_to_end_first_payout",
                "p_first_net_ftmo_payout", "p_first_net_ftmo_payout_lcb",
                "end_to_end_median_business_days"):
        assert key in compact, key
    assert chain["payout_frontier"]["schema"] == "qm.ftmo-payout-speed-frontier/v1"
    # Phase-1 headline and the chain's Phase-1 stage share the same draws.
    assert chain["probabilities"]["P_CHALLENGE_PASS"] == model["headline"]["p_target_hit"]


def test_build_is_deterministic_including_the_chain(tmp_path):
    a = _model(tmp_path)
    b = _model(tmp_path)
    assert json.dumps(a["chain"], sort_keys=True) == json.dumps(b["chain"], sort_keys=True)
    assert a["input_manifest_sha256"] == b["input_manifest_sha256"]


def test_chain_can_be_disabled_for_a_phase1_only_run(tmp_path):
    model = _model(tmp_path, chain=False)
    assert "chain" not in model
    assert model["headline"]["p_target_hit"] is not None
    assert "p_end_to_end_first_payout" not in model["compact_for_readiness"]


def test_load_for_readiness_still_consumes_the_read_model(tmp_path):
    model = _model(tmp_path)
    out = tmp_path / "ftmo_first_passage.json"
    out.write_text(json.dumps(model), encoding="utf-8")
    compact = fp.load_for_readiness(out)
    assert compact is not None
    assert compact["p_target_hit"] == model["headline"]["p_target_hit"]
    assert compact["input_manifest_sha256"] == model["input_manifest_sha256"]
