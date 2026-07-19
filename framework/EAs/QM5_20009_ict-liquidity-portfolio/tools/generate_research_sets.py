"""Generate the frozen center/OAAT research sets for QM5_20009.

The generator is intentionally deterministic: no wall-clock timestamp enters a
set or its manifest.  ``--check`` proves that checked-in files still match the
EA/contract hashes and the preregistered 13-point stars.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


EA_ROOT = Path(__file__).resolve().parents[1]
SETS_ROOT = EA_ROOT / "sets"
EA_SOURCE = EA_ROOT / "QM5_20009_ict-liquidity-portfolio.mq5"
RULES_SOURCE = EA_ROOT / "ICT_LiquidityRules.mqh"
CONTRACT = EA_ROOT / "docs" / "strategy_contract.md"
FREEZE_DATE = "2026-07-19"

MARKETS = (
    ("NDX.DWX", "M1", 0, 0, "index"),
    ("GDAXI.DWX", "M1", 1, 0, "index"),
    ("GBPUSD.DWX", "M5", 2, 1, "fx"),
    ("EURUSD.DWX", "M5", 5, 1, "fx"),
)

A_CENTER = {
    "strategy_a_pivot_wing": "2",
    "strategy_a_reclaim_bars": "3",
    "strategy_a_max_bars_to_mss": "9",
    "strategy_a_min_fvg_atr": "0.05",
    "strategy_a_sl_buffer_atr": "0.10",
    "strategy_a_min_rr": "2.0",
}
B_CENTER = {
    "strategy_b_pivot_wing": "2",
    "strategy_b_reclaim_bars": "3",
    "strategy_b_max_bars_to_mss": "12",
    "strategy_b_min_fvg_atr": "0.05",
    "strategy_b_sl_buffer_atr": "0.10",
    "strategy_b_min_rr": "2.0",
}

STARS = {
    "index": (
        ("pivot_low", "strategy_a_pivot_wing", "1"),
        ("pivot_high", "strategy_a_pivot_wing", "3"),
        ("reclaim_low", "strategy_a_reclaim_bars", "1"),
        ("reclaim_high", "strategy_a_reclaim_bars", "5"),
        ("mss_low", "strategy_a_max_bars_to_mss", "6"),
        ("mss_high", "strategy_a_max_bars_to_mss", "12"),
        ("fvg_low", "strategy_a_min_fvg_atr", "0.0"),
        ("fvg_high", "strategy_a_min_fvg_atr", "0.10"),
        ("stop_low", "strategy_a_sl_buffer_atr", "0.05"),
        ("stop_high", "strategy_a_sl_buffer_atr", "0.15"),
        ("rr_low", "strategy_a_min_rr", "1.5"),
        ("rr_high", "strategy_a_min_rr", "2.5"),
    ),
    "fx": (
        ("pivot_low", "strategy_b_pivot_wing", "1"),
        ("pivot_high", "strategy_b_pivot_wing", "3"),
        ("reclaim_low", "strategy_b_reclaim_bars", "1"),
        ("reclaim_high", "strategy_b_reclaim_bars", "5"),
        ("mss_low", "strategy_b_max_bars_to_mss", "6"),
        ("mss_high", "strategy_b_max_bars_to_mss", "18"),
        ("fvg_low", "strategy_b_min_fvg_atr", "0.0"),
        ("fvg_high", "strategy_b_min_fvg_atr", "0.10"),
        ("stop_low", "strategy_b_sl_buffer_atr", "0.05"),
        ("stop_high", "strategy_b_sl_buffer_atr", "0.15"),
        ("rr_low", "strategy_b_min_rr", "1.5"),
        ("rr_high", "strategy_b_min_rr", "2.5"),
    ),
}


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def source_hashes() -> dict[str, str]:
    return {
        "ea_sha256": sha256_bytes(EA_SOURCE.read_bytes()),
        "rules_sha256": sha256_bytes(RULES_SOURCE.read_bytes()),
        "contract_sha256": sha256_bytes(CONTRACT.read_bytes()),
    }


def parameter_map(slot: int, mode: int) -> dict[str, str]:
    values = {
        "qm_ea_id": "20009",
        "qm_magic_slot_offset": str(slot),
        "qm_rng_seed": "42",
        "RISK_PERCENT": "0.0",
        "RISK_FIXED": "1000.0",
        "PORTFOLIO_WEIGHT": "1.0",
        "qm_news_temporal": "3",
        "qm_news_compliance": "2",
        "qm_news_stale_max_hours": "336",
        "qm_news_min_impact": "high",
        "qm_news_mode_legacy": "0",
        "qm_friday_close_enabled": "true",
        "qm_friday_close_hour_broker": "23",
        "qm_stress_reject_probability": "0.0",
        "strategy_mode": str(mode),
        "strategy_replay_bars_index": "2500",
        "strategy_replay_bars_fx": "10000",
        **A_CENTER,
        **B_CENTER,
        "strategy_governor_policy_id": "",
        "strategy_challenge_instance_id": "",
        "strategy_governor_heartbeat_max_age_seconds": "5",
    }
    return values


def variants(kind: str) -> list[tuple[str, str | None, str | None]]:
    return [("center", None, None), *STARS[kind]]


def filename(symbol: str, timeframe: str, kind: str, variant: str) -> str:
    safe_symbol = symbol.replace(".", "_")
    return f"QM5_20009_{safe_symbol}_{timeframe}_{kind}_{variant}.set"


def render_set(
    symbol: str,
    timeframe: str,
    slot: int,
    mode: int,
    kind: str,
    variant: str,
    changed_parameter: str | None,
    changed_value: str | None,
    hashes: dict[str, str],
) -> bytes:
    values = parameter_map(slot, mode)
    if changed_parameter is not None:
        assert changed_value is not None
        values[changed_parameter] = changed_value
    lines = [
        ";==========================================================",
        "; QM5_20009 frozen ICT research set",
        f"; contract_freeze: {FREEZE_DATE}",
        f"; symbol: {symbol}",
        f"; timeframe: {timeframe}",
        f"; sleeve: {kind}",
        f"; variant: {variant}",
        f"; changed_parameter: {changed_parameter or 'none'}",
        f"; ea_sha256: {hashes['ea_sha256']}",
        f"; rules_sha256: {hashes['rules_sha256']}",
        f"; contract_sha256: {hashes['contract_sha256']}",
        ";==========================================================",
    ]
    lines.extend(f"{key}={value}" for key, value in values.items())
    return ("\r\n".join(lines) + "\r\n").encode("ascii")


def expected_files() -> tuple[dict[str, bytes], bytes]:
    hashes = source_hashes()
    files: dict[str, bytes] = {}
    rows: list[dict[str, object]] = []
    for symbol, timeframe, slot, mode, kind in MARKETS:
        for variant, changed_parameter, changed_value in variants(kind):
            name = filename(symbol, timeframe, kind, variant)
            payload = render_set(
                symbol,
                timeframe,
                slot,
                mode,
                kind,
                variant,
                changed_parameter,
                changed_value,
                hashes,
            )
            files[name] = payload
            rows.append(
                {
                    "file": name,
                    "symbol": symbol,
                    "timeframe": timeframe,
                    "slot": slot,
                    "mode": mode,
                    "sleeve": kind,
                    "variant": variant,
                    "changed_parameter": changed_parameter,
                    "changed_value": changed_value,
                    "set_sha256": sha256_bytes(payload),
                }
            )
    manifest = {
        "schema_version": 1,
        "ea_id": 20009,
        "contract_freeze": FREEZE_DATE,
        "generation": "deterministic_no_wall_clock",
        **hashes,
        "set_count": len(rows),
        "sets": rows,
    }
    manifest_bytes = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode("utf-8")
    return files, manifest_bytes


def check() -> list[str]:
    files, manifest = expected_files()
    issues: list[str] = []
    expected_names = set(files) | {"manifest.json"}
    actual_names = {path.name for path in SETS_ROOT.glob("QM5_20009_*.set")}
    if (SETS_ROOT / "manifest.json").exists():
        actual_names.add("manifest.json")
    for extra in sorted(actual_names - expected_names):
        issues.append(f"unexpected:{extra}")
    for name, payload in files.items():
        path = SETS_ROOT / name
        if not path.exists():
            issues.append(f"missing:{name}")
        elif path.read_bytes() != payload:
            issues.append(f"drift:{name}")
    manifest_path = SETS_ROOT / "manifest.json"
    if not manifest_path.exists():
        issues.append("missing:manifest.json")
    elif manifest_path.read_bytes() != manifest:
        issues.append("drift:manifest.json")
    return issues


def write() -> None:
    files, manifest = expected_files()
    SETS_ROOT.mkdir(parents=True, exist_ok=True)
    for stale in SETS_ROOT.glob("QM5_20009_*.set"):
        if stale.name not in files:
            stale.unlink()
    for name, payload in files.items():
        (SETS_ROOT / name).write_bytes(payload)
    (SETS_ROOT / "manifest.json").write_bytes(manifest)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check:
        issues = check()
        if issues:
            print("\n".join(issues))
            return 1
        print("PASS: 52 frozen research sets and manifest match")
        return 0
    write()
    print("WROTE: 52 frozen research sets and manifest")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
