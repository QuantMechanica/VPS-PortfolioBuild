#!/usr/bin/env python3
"""Generate the four preregistered QM5_20002 short-NY tester sets."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


TOOL_PATH = Path(__file__).resolve()
EA_ROOT = TOOL_PATH.parents[2]
CONTRACT_PATH = EA_ROOT / "docs" / "candidate-analysis" / "short_ny_reverse_time_contract.json"
OUTPUT_ROOT = EA_ROOT / "sets" / "candidate-analysis"
MANIFEST_PATH = OUTPUT_ROOT / "short_ny_reverse_time_manifest.json"
EXPECTED_CONTRACT_SHA256 = "3186d8294e73c3777d5447738aaeb5e2839c8b7768faf41b788cba8722514164"
CONTRACT_COMMIT = "6fbdaa0817324375ad25163194fbb9e6d6f50f9b"

INPUT_ORDER = (
    "qm_chartui_enabled",
    "qm_chartui_corner",
    "InpQMSimCommissionPerLot",
    "qm_ea_id",
    "qm_magic_slot_offset",
    "qm_rng_seed",
    "RISK_PERCENT",
    "RISK_FIXED",
    "PORTFOLIO_WEIGHT",
    "qm_news_temporal",
    "qm_news_compliance",
    "qm_news_stale_max_hours",
    "qm_news_min_impact",
    "qm_news_mode_legacy",
    "qm_friday_close_enabled",
    "qm_friday_close_hour_broker",
    "qm_stress_reject_probability",
    "TradeLongs",
    "TradeShorts",
    "ExecutionTF",
    "HTF_Context_M15",
    "HTF_Context_H1",
    "SwingLookback",
    "EqualTolerance_Pips",
    "EqualTolerance_ATRfrac",
    "SweepReturnBars",
    "DisplacementATR",
    "RequireFVGInImpulse",
    "FVG_MinPoints",
    "EntryMode",
    "PremiumDiscountFilter",
    "UseHTFBias",
    "HTFBiasLookback",
    "UseOTE",
    "SL_BufferPoints",
    "MinRR",
    "PartialPct",
    "PartialAt",
    "BreakevenAfterPartial",
    "MaxTradesPerKZ",
    "TZ_Offset_NYtoBroker",
    "KZ_London_on",
    "KZ_NewYork_on",
    "Setup_Judas",
    "Setup_TurtleSoup",
    "Setup_Unicorn",
    "Setup_SilverBullet",
    "Setup_TGIF",
    "Setup_3Drives",
    "Setup_MMxM",
    "Setup_IndexMacro",
    "UseSMT",
)


class GenerationError(RuntimeError):
    """The preregistered set family cannot be generated exactly."""


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def render_value(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        return format(value, ".15g")
    return str(value)


def load_contract() -> dict[str, Any]:
    raw = CONTRACT_PATH.read_bytes()
    actual = sha256_bytes(raw)
    if actual != EXPECTED_CONTRACT_SHA256:
        raise GenerationError(f"contract SHA256 drift: {actual}")
    contract = json.loads(raw.decode("utf-8"))
    if contract.get("schema_version") != 2 or contract.get("contract_revision") != 2:
        raise GenerationError("unexpected contract revision")
    if contract.get("analysis_id") != "QM5_20002_SHORT_NY_REVERSE_TIME_SCREEN_001":
        raise GenerationError("unexpected analysis_id")
    return contract


def build_outputs(contract: dict[str, Any]) -> dict[Path, bytes]:
    common = dict(contract["common_inputs"])
    if set(common) | {"UseHTFBias"} != set(INPUT_ORDER):
        missing = sorted(set(INPUT_ORDER) - (set(common) | {"UseHTFBias"}))
        extra = sorted((set(common) | {"UseHTFBias"}) - set(INPUT_ORDER))
        raise GenerationError(f"input surface drift: missing={missing}, extra={extra}")

    market_slots = {"EURUSD.DWX": 0, "GBPUSD.DWX": 1}
    arm_slugs = {
        "A_SHORT_NY_NO_HTF": "short_ny_no_htf",
        "B_SHORT_NY_H1_BIAS": "short_ny_h1_bias",
    }
    outputs: dict[Path, bytes] = {}
    manifest_rows: list[dict[str, Any]] = []
    for arm in contract["arms"]:
        arm_id = arm["id"]
        if arm_id not in arm_slugs or not isinstance(arm["UseHTFBias"], bool):
            raise GenerationError(f"unexpected arm: {arm!r}")
        for market in contract["markets"]:
            symbol = market["symbol"]
            if symbol not in market_slots or market["timeframe"] != "M1":
                raise GenerationError(f"unexpected market: {market!r}")
            inputs = dict(common)
            inputs["UseHTFBias"] = arm["UseHTFBias"]
            inputs["qm_magic_slot_offset"] = market_slots[symbol]
            safe_symbol = symbol.replace(".", "_")
            filename = f"QM5_20002_{safe_symbol}_M1_{arm_slugs[arm_id]}.set"
            lines = [
                "; QM5_20002 preregistered short-NY reverse-time candidate",
                f"; analysis_id={contract['analysis_id']}",
                f"; contract_commit={CONTRACT_COMMIT}",
                f"; contract_sha256={EXPECTED_CONTRACT_SHA256}",
                f"; arm={arm_id}",
                f"; symbol={symbol}",
                f"; window={contract['window']['from']}..{contract['window']['to']}",
            ]
            lines.extend(f"{key}={render_value(inputs[key])}" for key in INPUT_ORDER)
            payload = ("\n".join(lines) + "\n").encode("ascii")
            path = OUTPUT_ROOT / filename
            outputs[path] = payload
            manifest_rows.append(
                {
                    "arm": arm_id,
                    "symbol": symbol,
                    "timeframe": "M1",
                    "magic_slot": market_slots[symbol],
                    "path": path.relative_to(EA_ROOT).as_posix(),
                    "size": len(payload),
                    "sha256": sha256_bytes(payload),
                    "visible_input_count": len(INPUT_ORDER),
                }
            )

    manifest = {
        "schema_version": 1,
        "artifact_type": "QM5_20002_SHORT_NY_SET_MANIFEST",
        "analysis_id": contract["analysis_id"],
        "contract_commit": CONTRACT_COMMIT,
        "contract_sha256": EXPECTED_CONTRACT_SHA256,
        "sets": sorted(manifest_rows, key=lambda row: (row["arm"], row["symbol"])),
    }
    outputs[MANIFEST_PATH] = (
        json.dumps(manifest, indent=2, sort_keys=True, ensure_ascii=True) + "\n"
    ).encode("ascii")
    return outputs


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify outputs without writing them.")
    args = parser.parse_args(argv)
    outputs = build_outputs(load_contract())
    drift: list[str] = []
    for path, expected in outputs.items():
        if args.check:
            if not path.is_file() or path.read_bytes() != expected:
                drift.append(str(path))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(expected)
    if drift:
        raise GenerationError("generated output drift: " + ", ".join(drift))
    print(
        json.dumps(
            {
                "status": "PASS",
                "mode": "check" if args.check else "write",
                "output_count": len(outputs),
                "contract_sha256": EXPECTED_CONTRACT_SHA256,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (GenerationError, OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
