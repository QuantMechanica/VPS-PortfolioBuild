import hashlib
import json
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
GOLDEN_PATH = REPO_ROOT / "artifacts" / "ftmo_governor_policy_golden_2026-07-17.json"

POLICY_FIELDS = (
    "policy_id",
    "start_balance",
    "target_enabled",
    "target_balance",
    "official_total_floor",
    "official_daily_loss",
    "internal_total_floor",
    "entry_daily_stop",
    "liquidation_daily_stop",
    "profit_room_retention",
    "full_risk_room",
    "minimum_trading_days",
    "taper_level_1",
    "taper_scale_1",
    "taper_level_2",
    "taper_scale_2",
)


def _load():
    data = json.loads(GOLDEN_PATH.read_text(encoding="utf-8"))
    policies = {item["policy_id"]: item for item in data["policies"]}
    return data, policies


def _canonical_policy(policy):
    return {key: policy[key] for key in POLICY_FIELDS}


def _fingerprint(policy):
    canonical = json.dumps(
        _canonical_policy(policy), sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    digest = hashlib.sha256(canonical).hexdigest()
    number = int(digest[:13], 16) & ((1 << 52) - 1)
    return digest, number


def _evaluate(policy, case):
    midnight = case["midnight_balance"]
    balance = case["balance"]
    equity = case["equity"]
    official_daily = midnight - policy["official_daily_loss"]
    protected = policy["internal_total_floor"] + policy["profit_room_retention"] * max(
        0.0, midnight - policy["internal_total_floor"]
    )
    liquidation = max(
        policy["official_total_floor"],
        policy["internal_total_floor"],
        official_daily,
        midnight - policy["liquidation_daily_stop"],
        protected,
    )
    entry = max(liquidation, midnight - policy["entry_daily_stop"])
    scale = min(1.0, max(0.0, (equity - entry) / policy["full_risk_room"]))
    if policy["target_enabled"]:
        if equity >= policy["target_balance"]:
            scale = 0.0
        elif equity >= policy["taper_level_2"]:
            scale = min(scale, policy["taper_scale_2"])
        elif equity >= policy["taper_level_1"]:
            scale = min(scale, policy["taper_scale_1"])

    minimum_complete = case["trading_days"] >= policy["minimum_trading_days"]
    target_reached = policy["target_enabled"] and equity >= policy["target_balance"]
    target_complete = (
        policy["target_enabled"]
        and balance >= policy["target_balance"]
        and case["positions_open"] == 0
        and case["orders_pending"] == 0
        and minimum_complete
    )
    if equity <= policy["internal_total_floor"]:
        reason = "TOTAL_FLOOR"
    elif equity <= liquidation:
        reason = "EFFECTIVE_DAILY_FLOOR"
    elif target_complete:
        reason = "TARGET_COMPLETE"
    elif target_reached:
        reason = "TARGET_CAPTURE"
    elif equity <= entry or scale <= 0.0:
        reason = "ENTRY_HALT"
    else:
        reason = "ALLOW"

    persist = reason in {
        "TOTAL_FLOOR",
        "EFFECTIVE_DAILY_FLOOR",
        "TARGET_CAPTURE",
        "TARGET_COMPLETE",
    }
    flatten = reason in {
        "TOTAL_FLOOR",
        "EFFECTIVE_DAILY_FLOOR",
        "TARGET_CAPTURE",
    } and (case["positions_open"] > 0 or case["orders_pending"] > 0)
    return {
        "official_daily_floor": official_daily,
        "protected_profit_floor": protected,
        "liquidation_floor": liquidation,
        "entry_floor": entry,
        "risk_scale": scale,
        "minimum_days_complete": minimum_complete,
        "target_reached": target_reached,
        "target_complete": target_complete,
        "reason": reason,
        "persist_lock": persist,
        "flatten_required": flatten,
    }


def test_policy_hashes_and_official_outer_limits():
    data, policies = _load()
    assert data["contract_revision"] == 2
    assert data["policy_version"] == 2.0
    assert set(policies) == {
        "FTMO_2S_P1_100K_V2",
        "FTMO_2S_P2_100K_V2",
        "FTMO_2S_FUNDED_100K_V2",
    }
    for policy in policies.values():
        digest, number = _fingerprint(policy)
        assert digest == policy["canonical_sha256"]
        assert number == policy["fingerprint_number"]
        assert policy["start_balance"] == 100000.0
        assert policy["official_total_floor"] == 90000.0
        assert policy["official_daily_loss"] == 5000.0
        assert policy["official_total_floor"] < policy["internal_total_floor"]
        assert 0 < policy["entry_daily_stop"] < policy["liquidation_daily_stop"]
        assert policy["liquidation_daily_stop"] < policy["official_daily_loss"]


def test_golden_decisions():
    data, policies = _load()
    for case in data["golden_cases"]:
        actual = _evaluate(policies[case["policy_id"]], case)
        for key, expected in case["expected"].items():
            if isinstance(expected, float):
                assert abs(actual[key] - expected) < 1e-9, (case["name"], key)
            else:
                assert actual[key] == expected, (case["name"], key)
