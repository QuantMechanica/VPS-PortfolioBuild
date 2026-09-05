#!/usr/bin/env python3
"""Generate guarded live-like set files for the eight FTMO trial sleeves.

This is intentionally separate from ``ftmo_lane_runner``: that runner remains
backtest-only and its RISK_FIXED guard is not weakened.  Outputs are accepted
only below D:/QM/reports/ftmo_trial/sets_<timestamp>/.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REPO = Path(r"C:\QM\repo")
ALLOWED_ROOT = Path(r"D:\QM\reports\ftmo_trial")
POLICY = REPO / "tools/strategy_farm/config/concentration_tail_limits.v1.json"
MAGIC_REGISTRY = REPO / "framework/registry/magic_numbers.csv"
RISK_TOTAL = 2.5


class TrialSetError(ValueError):
    pass


@dataclass(frozen=True)
class Candidate:
    ea_id: int
    slug: str
    source_symbol: str
    trial_symbol: str
    timeframe: str
    asset_class: str

    @property
    def label(self) -> str:
        return f"QM5_{self.ea_id}_{self.slug}"


CANDIDATES = (
    Candidate(10706, "tv-mon-ls", "GBPUSD.DWX", "GBPUSD", "H1", "FX"),
    Candidate(11421, "ohlc-daily-squeeze-reversal-d1", "EURUSD.DWX", "EURUSD", "D1", "FX"),
    Candidate(11422, "williams-18ma-outside-bar-entry-d1", "USDCAD.DWX", "USDCAD", "D1", "FX"),
    Candidate(11910, "larry-williams-18ma-2outside-bars-d1", "NZDUSD.DWX", "NZDUSD", "D1", "FX"),
    Candidate(13054, "brent-tom-mom", "XTIUSD.DWX", "USOIL.cash", "D1", "ENERGY"),
    Candidate(1537, "aa-vol-sma10", "XAGUSD.DWX", "XAGUSD", "D1", "METAL"),
    Candidate(20048, "wti-preholiday", "XTIUSD.DWX", "USOIL.cash", "D1", "ENERGY"),
    Candidate(21505, "xag-weekly-lowvol-momentum", "XAGUSD.DWX", "XAGUSD", "D1", "METAL"),
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def safe_output_dir(path: Path) -> Path:
    resolved = path.resolve()
    root = ALLOWED_ROOT.resolve()
    if root not in resolved.parents or not resolved.name.startswith("sets_"):
        raise TrialSetError(f"output_not_declared_trial_directory:{resolved}")
    if "T_Live".casefold() in str(resolved).casefold():
        raise TrialSetError("tlive_output_forbidden")
    return resolved


def assignments(text: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for match in re.finditer(r"(?m)^(?!\s*;)([A-Za-z_][A-Za-z0-9_]*)=([^\r\n]*)$", text):
        key, value = match.group(1), match.group(2).strip()
        if key in result:
            raise TrialSetError(f"duplicate_assignment:{key}")
        result[key] = value
    return result


def _replace_one(text: str, pattern: str, replacement: str, label: str) -> str:
    result, count = re.subn(pattern, replacement, text, flags=re.MULTILINE)
    if count != 1:
        raise TrialSetError(f"rewrite_count:{label}:{count}")
    return result


def source_set(candidate: Candidate) -> Path:
    folder = REPO / "framework/EAs" / candidate.label / "sets"
    exact = folder / f"{candidate.label}_{candidate.source_symbol}_{candidate.timeframe}_backtest.set"
    if not exact.is_file():
        raise TrialSetError(f"source_set_missing:{exact}")
    return exact


def binary(candidate: Candidate) -> Path:
    path = REPO / "framework/EAs" / candidate.label / f"{candidate.label}.ex5"
    if not path.is_file():
        raise TrialSetError(f"binary_missing:{path}")
    return path


def registry_slots() -> dict[tuple[int, str], int]:
    result = {}
    with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            if row.get("status") == "active":
                result[(int(row["ea_id"]), row["symbol"])] = int(row["symbol_slot"])
    return result


def render(candidate: Candidate, *, risk_percent: float, slot: int, build_hash: str) -> str:
    path = source_set(candidate)
    text = path.read_text(encoding="utf-8-sig")
    before = assignments(text)
    if int(before.get("qm_ea_id", candidate.ea_id)) != candidate.ea_id:
        raise TrialSetError(f"ea_id_mismatch:{candidate.ea_id}")
    if int(before.get("qm_magic_slot_offset", -1)) != slot:
        raise TrialSetError(f"magic_slot_mismatch:{candidate.ea_id}")
    if float(before.get("RISK_FIXED", "nan")) <= 0 or float(before.get("RISK_PERCENT", "nan")) != 0:
        raise TrialSetError(f"source_not_backtest_risk:{candidate.ea_id}")
    text = _replace_one(text, r"^(\s*;\s*environment:\s*).*$", rf"\g<1>trial", "environment")
    text = _replace_one(text, r"^(\s*;\s*risk_mode:\s*).*$", rf"\g<1>PERCENT", "risk_mode")
    text = _replace_one(text, r"^(\s*;\s*build_hash:\s*).*$", rf"\g<1>{build_hash}", "build_hash")
    text = _replace_one(text, r"^RISK_FIXED=.*$", "RISK_FIXED=0", "RISK_FIXED")
    text = _replace_one(text, r"^RISK_PERCENT=.*$", f"RISK_PERCENT={risk_percent:.4f}", "RISK_PERCENT")
    # The FTMO Swing provider imposes no temporal news restriction, but QM's
    # Edge-Lab blackout remains mandatory. The candidate EAs enable it in
    # source; the trial set pins its fail-closed freshness ceiling.
    if "qm_news_stale_max_hours" in before:
        text = _replace_one(text, r"^qm_news_stale_max_hours=.*$", "qm_news_stale_max_hours=336", "news_stale")
    else:
        text += "qm_news_stale_max_hours=336\n"
    banner = (
        "; FTMO_TRIAL_ONLY; DO_NOT_COPY_TO_T_LIVE\n"
        "; provider_temporal_news_restriction=OFF; qm_internal_news_blackout=ON\n"
        f"; trial_chart_symbol={candidate.trial_symbol}; OWNER_CONFIRM_CLIENT_SYMBOL_BEFORE_RUN\n"
    )
    return banner + text


def validate(text: str, *, candidate: Candidate, expected_risk: float, expected_slot: int) -> None:
    values = assignments(text)
    if "; environment:  trial" not in text or "; risk_mode:    PERCENT" not in text:
        raise TrialSetError("trial_header_invalid")
    if float(values.get("RISK_FIXED", "nan")) != 0 or float(values.get("RISK_PERCENT", "nan")) != expected_risk:
        raise TrialSetError("trial_risk_mode_invalid")
    if int(values.get("qm_magic_slot_offset", -1)) != expected_slot:
        raise TrialSetError("trial_magic_slot_invalid")
    if candidate.ea_id * 10000 + expected_slot <= 0:
        raise TrialSetError("trial_magic_invalid")
    stale = float(values.get("qm_news_stale_max_hours", "nan"))
    if not math_is_finite(stale) or stale > 336:
        raise TrialSetError("trial_news_stale_ceiling_invalid")
    if "qm_internal_news_blackout=ON" not in text or "provider_temporal_news_restriction=OFF" not in text:
        raise TrialSetError("trial_news_semantics_missing")


def math_is_finite(value: float) -> bool:
    return value == value and value not in (float("inf"), float("-inf"))


def generate(output_dir: Path) -> dict[str, Any]:
    destination = safe_output_dir(output_dir)
    if destination.exists():
        raise TrialSetError(f"output_already_exists:{destination}")
    policy = json.loads(POLICY.read_text(encoding="utf-8-sig"))
    if policy.get("status") != "OWNER_RATIFIED" or float(policy.get("stop_risk_budget_pct")) != RISK_TOTAL:
        raise TrialSetError("concentration_policy_not_ratified_or_changed")
    per_sleeve = RISK_TOTAL / len(CANDIDATES)
    slots = registry_slots()
    rows = []
    rendered: list[tuple[Path, str]] = []
    for candidate in CANDIDATES:
        key = (candidate.ea_id, candidate.source_symbol)
        if key not in slots:
            raise TrialSetError(f"active_magic_missing:{key}")
        slot = slots[key]
        ex5 = binary(candidate)
        content = render(candidate, risk_percent=per_sleeve, slot=slot, build_hash=sha256(ex5))
        validate(content, candidate=candidate, expected_risk=per_sleeve, expected_slot=slot)
        name = f"{candidate.label}_{candidate.trial_symbol}_{candidate.timeframe}_trial.set"
        target = destination / name
        rendered.append((target, content))
        rows.append({
            "ea_id": candidate.ea_id,
            "source_symbol": candidate.source_symbol,
            "trial_symbol": candidate.trial_symbol,
            "timeframe": candidate.timeframe,
            "asset_class": candidate.asset_class,
            "risk_percent": per_sleeve,
            "magic_slot": slot,
            "magic": candidate.ea_id * 10000 + slot,
            "source_set": str(source_set(candidate)),
            "source_set_sha256": sha256(source_set(candidate)),
            "binary": str(ex5),
            "binary_sha256": sha256(ex5),
            "output": str(target),
        })
    symbol_risk: dict[str, float] = {}
    class_risk: dict[str, float] = {}
    for row in rows:
        symbol_risk[row["trial_symbol"]] = symbol_risk.get(row["trial_symbol"], 0.0) + row["risk_percent"]
        class_risk[row["asset_class"]] = class_risk.get(row["asset_class"], 0.0) + row["risk_percent"]
    symbol_cap = RISK_TOTAL * float(policy["caps_percent_of_budget"]["symbol"]) / 100
    class_cap = RISK_TOTAL * float(policy["caps_percent_of_budget"]["asset_class"]) / 100
    if max(symbol_risk.values()) > symbol_cap or max(class_risk.values()) > class_cap:
        raise TrialSetError("static_concentration_cap_breach")
    destination.mkdir(parents=True)
    for target, content in rendered:
        target.write_text(content, encoding="utf-8", newline="\n")
    for row in rows:
        row["output_sha256"] = sha256(Path(row["output"]))
    manifest = {
        "schema": "qm.ftmo-trial-setfiles/v1",
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "mode": "TRIAL_ONLY_NO_DEPLOYMENT",
        "output_dir": str(destination),
        "policy": {"path": str(POLICY), "sha256": sha256(POLICY), "status": policy["status"]},
        "risk": {"total_percent": RISK_TOTAL, "per_sleeve_percent": per_sleeve, "symbol_cap_percent": symbol_cap, "asset_class_cap_percent": class_cap, "symbol_totals": symbol_risk, "asset_class_totals": class_risk},
        "news": {"provider_temporal_restriction": "OFF_FTMO_SWING", "qm_internal_blackout": "ON_MANDATORY", "stale_max_hours": 336},
        "client_symbol_status": "OWNER_CONFIRM_BEFORE_RUN",
        "sets": rows,
        "authorization": {"deployment": False, "tlive": False, "autotrading": False},
    }
    manifest_path = destination / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    manifest = generate(args.output_dir)
    print(json.dumps({"status": "PASS", "sets": len(manifest["sets"]), "output_dir": manifest["output_dir"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
