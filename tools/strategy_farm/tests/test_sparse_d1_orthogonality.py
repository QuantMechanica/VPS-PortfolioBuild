"""Tests for the two-layer sparse-D1 orthogonality standard (Q15 supplement).

Standard: docs/research/SPARSE_D1_ORTHOGONALITY_STANDARD_2026-09-03.md
Authority: OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904
           (decisions/2026-09-04_owner_receipts_briefing_2_4.md).

Coverage:
  * synthetic streams (independent, clone, partial-clone, disjoint activity)
    reproduce CERTIFIED / ABSTAIN / FLAGGED exactly as the standard predicts,
    including the load-bearing property that Layer B (COS) catches same-timing
    redundancy that Layer A (daily-r) certifies orthogonal;
  * the signed concordance Psi is a same-instrument flag statistic (None for
    cross-symbol; positive under same-direction stacking);
  * the Layer-A circular-rotation negative control has a ~0 false-positive rate;
  * the live 5-pair qualified-pool run (read-only, sha-gated to the exact streams
    the standard was measured on) reproduces the standard's Tier-1 numbers.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import random
from pathlib import Path

import pytest

from tools.strategy_farm.portfolio import portfolio_correlation as pc
from tools.strategy_farm.portfolio.commission import load_model
from tools.strategy_farm.portfolio.portfolio_common import Trade, _load_one_stream, to_daily_pnl

np = pytest.importorskip("numpy")

REPO_ROOT = Path(__file__).resolve().parents[3]
_EPOCH = dt.datetime(2018, 1, 1, tzinfo=dt.UTC)  # a Monday


def _ts(day: dt.date, hour: int = 12) -> int:
    return int(dt.datetime(day.year, day.month, day.day, hour, tzinfo=dt.UTC).timestamp())


def _mk(entry: dt.date, exit_: dt.date, net: float, *, side: str = "BUY", notional: float = 100000.0) -> Trade:
    return Trade(
        ea_id=0,
        symbol="X",
        time=_ts(exit_, 20),
        net=net,
        volume=1.0,
        notional=notional,
        commission_cost=0.0,
        net_of_cost=net,
        entry_time=_ts(entry, 9),
        mae_acct=None,
        side=side,
    )


def _monday(week_index: int) -> dt.date:
    return (_EPOCH + dt.timedelta(weeks=week_index)).date()


def _one_pair(sa: list[Trade], sb: list[Trade], **kwargs) -> dict:
    res = pc.evaluate_sparse_orthogonality({(1, "AAA"): sa, (2, "BBB"): sb}, **kwargs)
    assert res["n_pairs"] == 1
    return res["pairs"][0]


# --------------------------------------------------------------- synthetic verdicts
def test_independent_streams_certify():
    """Independent activity + independent P&L: Layer A CI tight around 0, Layer B
    co-occupancy at chance -> CERTIFIED."""
    rng = random.Random(1)
    weeks_a = sorted(rng.sample(range(0, 380), 70))
    weeks_b = sorted(rng.sample(range(0, 380), 70))
    sa = [_mk(_monday(w), _monday(w) + dt.timedelta(days=3), rng.gauss(50, 300)) for w in weeks_a]
    sb = [_mk(_monday(w) + dt.timedelta(days=1), _monday(w) + dt.timedelta(days=4), rng.gauss(50, 300)) for w in weeks_b]
    pair = _one_pair(sa, sb)
    assert pair["status"] == "CERTIFIED"
    assert pair["verdict_detail"] == "CERTIFY_ORTHOGONAL"
    assert pair["layer_a"]["verdict"] == "CERTIFY_A"
    assert pair["layer_a"]["abs_upper"] < pc.Q15_HARD_RULE_MAX_ABS_R
    assert pair["layer_b"]["flag"] is False
    assert pair["layer_b"]["bh_reject"] is False


def test_clone_streams_abstain():
    """A perfect clone (identical returns) has daily-r = 1: Layer A CI reaches the
    |r| < 0.5 rule -> ABSTAIN.  The Q15 estimand is honoured, not gamed."""
    rng = random.Random(22)
    weeks = sorted(rng.sample(range(0, 380), 90))
    sa = [_mk(_monday(w), _monday(w) + dt.timedelta(days=3), rng.gauss(50, 300)) for w in weeks]
    sb = list(sa)
    pair = _one_pair(sa, sb)
    assert pair["status"] == "ABSTAIN"
    assert pair["layer_a"]["verdict"] == "ABSTAIN"
    assert pair["layer_a"]["r_hat"] == pytest.approx(1.0, abs=1e-9)
    assert pair["layer_a"]["abs_upper"] >= pc.Q15_HARD_RULE_MAX_ABS_R


def test_partial_clone_flagged_by_layer_b_not_layer_a():
    """Same-timing redundancy: two sleeves occupy the SAME irregular weeks (Layer B
    Lambda >> 1) but their exit-day P&L never coincides so daily-r ~ 0 (Layer A
    certifies).  This is exactly the same-EA/two-symbol case the standard keeps
    Layer B mandatory for -> FLAGGED (REVIEW), not a silent CERTIFY."""
    rng = random.Random(33)
    weeks = sorted(rng.sample(range(0, 380), 60))
    sa = [_mk(_monday(w), _monday(w) + dt.timedelta(days=3), rng.gauss(50, 300)) for w in weeks]
    sb = [_mk(_monday(w) + dt.timedelta(days=1), _monday(w) + dt.timedelta(days=4), rng.gauss(50, 300)) for w in weeks]
    pair = _one_pair(sa, sb)
    # Layer A alone would wave it through:
    assert pair["layer_a"]["verdict"] == "CERTIFY_A"
    assert pair["layer_a"]["abs_upper"] < pc.Q15_HARD_RULE_MAX_ABS_R
    # Layer B catches the co-timing:
    assert pair["layer_b"]["status"] == "FLAG_B"
    assert pair["layer_b"]["flag"] is True
    assert pair["layer_b"]["lambda"] > pc.WORKING_DEFAULT_OPEN_OWNER_ITEM_LAMBDA_STAR
    assert pair["layer_b"]["bh_reject"] is True
    # Combined (sparse regime, co-active exit days < 60):
    assert pair["overlap_days"] < 60
    assert pair["status"] == "FLAGGED"
    assert pair["verdict_detail"] == "REVIEW"


def test_disjoint_activity_certifies():
    """Non-overlapping occupancy (A even weeks, B odd weeks): O_ab = 0, Lambda = 0,
    Layer B not flagged, Layer A daily-r ~ 0 -> CERTIFIED (temporally orthogonal)."""
    rng = random.Random(44)
    sa = [_mk(_monday(w), _monday(w) + dt.timedelta(days=3), rng.gauss(50, 300)) for w in range(0, 380, 2)]
    sb = [_mk(_monday(w), _monday(w) + dt.timedelta(days=3), rng.gauss(50, 300)) for w in range(1, 380, 2)]
    pair = _one_pair(sa, sb)
    assert pair["layer_b"]["co_occupied_days_O"] == 0
    assert pair["layer_b"]["lambda"] == pytest.approx(0.0)
    assert pair["layer_b"]["flag"] is False
    assert pair["layer_a"]["verdict"] == "CERTIFY_A"
    assert pair["status"] == "CERTIFIED"


# ------------------------------------------------------------------ caution band
def test_caution_band_downgrades_certify_to_abstain():
    """A CI that clears +/-0.5 but sits inside the working caution band is
    PROVISIONAL (treated as ABSTAIN), never a hard CERTIFY."""
    # borderline CI wholly inside +/-0.5 but with |r|_upper in [0.45, 0.5)
    borderline = {"lo": -0.10, "hi": 0.47, "abs_upper": 0.47}
    verdict, reason = pc._layer_a_verdict(
        borderline, caution_band=pc.WORKING_DEFAULT_OPEN_OWNER_ITEM_CAUTION_BAND,
        max_abs_r=pc.Q15_HARD_RULE_MAX_ABS_R,
    )
    assert verdict == "PROVISIONAL"
    assert reason
    clear = {"lo": -0.10, "hi": 0.20, "abs_upper": 0.20}
    assert pc._layer_a_verdict(
        clear, caution_band=pc.WORKING_DEFAULT_OPEN_OWNER_ITEM_CAUTION_BAND,
        max_abs_r=pc.Q15_HARD_RULE_MAX_ABS_R,
    )[0] == "CERTIFY_A"
    over = {"lo": -0.60, "hi": 0.20, "abs_upper": 0.60}
    assert pc._layer_a_verdict(
        over, caution_band=pc.WORKING_DEFAULT_OPEN_OWNER_ITEM_CAUTION_BAND,
        max_abs_r=pc.Q15_HARD_RULE_MAX_ABS_R,
    )[0] == "ABSTAIN"
    assert pc._layer_a_verdict(
        None, caution_band=pc.WORKING_DEFAULT_OPEN_OWNER_ITEM_CAUTION_BAND,
        max_abs_r=pc.Q15_HARD_RULE_MAX_ABS_R,
    )[0] == "ABSTAIN"


# ------------------------------------------------------------------ signed Psi
def test_signed_psi_same_instrument_same_direction():
    """Same-symbol sleeves stacking the SAME direction on co-occupied days report a
    positive signed concordance Psi; cross-symbol pairs report Psi = None (never
    guessed)."""
    rng = random.Random(7)
    weeks = sorted(rng.sample(range(0, 380), 60))
    # both BUY, same irregular weeks, overlapping occupancy, different exit days
    sa = [_mk(_monday(w), _monday(w) + dt.timedelta(days=3), rng.gauss(50, 300), side="BUY") for w in weeks]
    sb = [_mk(_monday(w) + dt.timedelta(days=1), _monday(w) + dt.timedelta(days=4), rng.gauss(50, 300), side="BUY") for w in weeks]
    res = pc.evaluate_sparse_orthogonality({(1, "AAA"): sa, (2, "AAA"): sb})
    pair = res["pairs"][0]
    assert pair["same_symbol"] is True
    assert pair["layer_b"]["co_occupied_days_O"] >= pc.WORKING_DEFAULT_OPEN_OWNER_ITEM_SIGNED_MIN_CODAYS
    assert pair["layer_b"]["psi"] == pytest.approx(1.0)  # every co-day same direction

    # cross-symbol -> Psi undefined
    res2 = pc.evaluate_sparse_orthogonality({(1, "AAA"): sa, (2, "BBB"): sb})
    assert res2["pairs"][0]["layer_b"]["psi"] is None


# ----------------------------------------------------- rotation-null false positives
def test_rotation_null_false_positive_rate_is_zero():
    """Layer-A honesty negative control: the circular-rotation null of an
    independent pair must not manufacture |r| >= 0.5 (false-positive rate ~0)."""
    rng = random.Random(1)
    weeks_a = sorted(rng.sample(range(0, 380), 70))
    weeks_b = sorted(rng.sample(range(0, 380), 70))
    sa = [_mk(_monday(w), _monday(w) + dt.timedelta(days=3), rng.gauss(50, 300)) for w in weeks_a]
    sb = [_mk(_monday(w) + dt.timedelta(days=1), _monday(w) + dt.timedelta(days=4), rng.gauss(50, 300)) for w in weeks_b]
    pv = pc.pair_daily_vectors(to_daily_pnl(sa), to_daily_pnl(sb))
    assert pv is not None
    nrng = np.random.default_rng(20260903)
    null = pc.circular_rotation_null(pv["x"], pv["y"], nrng, reps=3000)
    assert null is not None
    assert null["frac_ge_rule"] == 0.0
    assert null["p975_abs"] < pc.Q15_HARD_RULE_MAX_ABS_R


# ------------------------------------------------------------ deterministic COS
def test_circular_shift_null_matches_brute_force():
    """The FFT circular-shift null equals the brute-force rotation enumeration."""
    rng = np.random.default_rng(0)
    for _ in range(5):
        T = int(rng.integers(20, 60))
        a = (rng.random(T) < 0.3).astype(np.float64)
        b = (rng.random(T) < 0.4).astype(np.float64)
        fft_null = pc.circular_shift_null_counts(a, b)
        brute = np.array([int(np.dot(a, np.roll(b, delta))) for delta in range(T)], dtype=np.int64)
        assert np.array_equal(fft_null, brute)


def test_working_default_constants_are_named_and_documented():
    """Every numeric knob other than the 0.50 rule is a WORKING_DEFAULT_OPEN_OWNER_ITEM."""
    assert pc.Q15_HARD_RULE_MAX_ABS_R == 0.50
    assert pc.WORKING_DEFAULT_OPEN_OWNER_ITEM_ALPHA == 0.05
    assert pc.WORKING_DEFAULT_OPEN_OWNER_ITEM_LAMBDA_STAR == 1.5
    assert pc.WORKING_DEFAULT_OPEN_OWNER_ITEM_CAUTION_BAND == 0.05
    assert pc.WORKING_DEFAULT_OPEN_OWNER_ITEM_COS_MIN_EXPECTED_OVERLAP == 5.0
    assert pc.WORKING_DEFAULT_OPEN_OWNER_ITEM_COS_MIN_OCCUPANCY_DAYS == 30
    assert pc.WORKING_DEFAULT_OPEN_OWNER_ITEM_SIGNED_MIN_CODAYS == 20
    assert pc.WORKING_DEFAULT_OPEN_OWNER_ITEM_BOOTSTRAP_B == 4000
    assert pc.WORKING_DEFAULT_OPEN_OWNER_ITEM_BOOTSTRAP_SEED == 20260903


# -------------------------------------------------- live 5-pair pool reproduction
_COMMON = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\q08_trades"
)
# (ea_id, symbol, filename, sha256[:16]) -- sha from the standard's Tier-1 meta
# (docs/ops/evidence/2026-09-03_sparse_d1_orthogonality_results.json, qualified_pool).
_POOL = [
    (10706, "GBPUSD.DWX", "10706_GBPUSD_DWX", "85d7abd4d1cb9ed3"),
    (11421, "EURUSD.DWX", "11421_EURUSD_DWX", "072b0c82ebdf96e4"),
    (11422, "USDCAD.DWX", "11422_USDCAD_DWX", "539567527f312817"),
    (13054, "XTIUSD.DWX", "13054_XTIUSD_DWX", "261c2de68a544b29"),
    (1537, "XAGUSD.DWX", "1537_XAGUSD_DWX", "6b1ae9ee1c6357d0"),
]
_ZK_RESULTS = REPO_ROOT / "docs/ops/evidence/2026-09-03_sparse_d1_orthogonality_results.json"
_COS_RESULTS = REPO_ROOT / "docs/research/2026-09-03_sparse_coactivity_orthogonality_results.json"


def _sha16(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()[:16]


def _pool_ready() -> str | None:
    for ea, _sym, fn, sha in _POOL:
        p = _COMMON / (fn + ".jsonl")
        if not p.exists():
            return f"{fn} absent"
        if _sha16(p) != sha:
            return f"{fn} sha drift (streams live in a mutable Common/Files export)"
    if not (_ZK_RESULTS.exists() and _COS_RESULTS.exists()):
        return "committed result JSONs absent"
    return None


def _key(record_pair: list[str]) -> frozenset:
    return frozenset(int(lbl.split(":")[0]) for lbl in record_pair)


def test_qualified_pool_reproduces_standard_tier1_numbers():
    reason = _pool_ready()
    if reason:
        pytest.skip(f"live qualified-pool streams not reproducible here: {reason}")

    model = load_model()
    streams = {
        (ea, sym): _load_one_stream(_COMMON / (fn + ".jsonl"), ea, sym, model)
        for ea, sym, fn, _sha in _POOL
    }
    res = pc.evaluate_sparse_orthogonality(streams)

    # ---- deterministic reference maps keyed by the {ea_a, ea_b} pair ----
    zk = json.loads(_ZK_RESULTS.read_text(encoding="utf-8"))["qualified_pool"]
    zk_by = {}
    for p in zk["pairs"]:
        eas = frozenset(int(lbl.split("/")[0]) for lbl in p["pair"])
        zk_by[eas] = p
    cos = json.loads(_COS_RESULTS.read_text(encoding="utf-8"))["qualified_pool"]
    cos_by = {}
    for p in cos["pairs"]:
        eas = frozenset(int(s.split(":")[0].replace("QM5_", "")) for s in (p["a"], p["b"]))
        cos_by[eas] = p

    assert res["ring_T_days"] == cos["ring_T_days"]  # 3004, exact
    assert res["n_pairs"] == 10

    for record in res["pairs"]:
        eas = _key(record["pair"])
        ref_zk = zk_by[eas]
        ref_cos = cos_by[eas]
        # Layer A deterministic point estimate + co-active exit days (exact/tol)
        assert record["overlap_days"] == ref_zk["coactive_days"]
        assert record["n_business_days"] == ref_zk["n_businessdays"]
        assert record["layer_a"]["r_hat"] == pytest.approx(ref_zk["r_pearson_zeroskept"], abs=2e-3)
        # Layer B statistics are exact (no RNG)
        lb = record["layer_b"]
        assert lb["co_occupied_days_O"] == ref_cos["co_occupied_days_O"]
        assert lb["expected_overlap_E"] == pytest.approx(ref_cos["expected_overlap_E"], abs=1e-2)
        assert lb["lambda"] == pytest.approx(ref_cos["lift_lambda"], abs=1e-2)
        assert lb["p_upper"] == pytest.approx(ref_cos["p_upper_exact_allshifts"], abs=1e-4)

    # ---- standard's headline verdicts (sec 7b): 9 certify, 1 abstain, 0 flag ----
    assert res["status_counts"] == {"CERTIFIED": 9, "ABSTAIN": 1, "FLAGGED": 0}
    # 0 pairs survive BH-FDR (the pool is co-orthogonal today)
    assert sum(1 for p in res["pairs"] if p["layer_b"]["bh_reject"]) == 0
    # the one fragile, data-starved pair 11421:EURUSD x 1537:XAGUSD -> caution-band ABSTAIN
    fragile = next(p for p in res["pairs"] if _key(p["pair"]) == frozenset({11421, 1537}))
    assert fragile["status"] == "ABSTAIN"
    assert fragile["verdict_detail"] == "ABSTAIN_CAUTION_BAND"
    assert fragile["overlap_days"] == 2
    assert 0.42 <= fragile["layer_a"]["abs_upper"] < pc.Q15_HARD_RULE_MAX_ABS_R
