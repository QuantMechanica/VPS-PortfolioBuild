"""Create FTMO challenge set files from measured backtest sets, fail-closed.

This is the deployment-config generation path for the legacy challenge book.
It does not start a terminal or authorize trading.  A frozen qualification
inventory is mandatory: every sleeve must be ``challenge_ready`` and carry an
FTMO-admitted Q09_NEWS decision.  Q09's ``chosen_temporal`` is written into the
derived set together with the FTMO compliance profile; it can no longer be
silently dropped while risk is converted from fixed to percent sizing.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from .ftmo_q09_admission import (
        admission_from_inventory,
        deployment_news_inputs,
    )
except ImportError:  # pragma: no cover - direct script execution
    from ftmo_q09_admission import (  # type: ignore
        admission_from_inventory,
        deployment_news_inputs,
    )


# (slug, symbol, RISK_PERCENT, peak concurrent notional x equity, FTMO leverage)
BOOK = [
    ("QM5_13213_balke-gmt3-range-breakout", "USDJPY", 4.0, 73.8, 100),
    ("QM5_10848_tv-mtf-ambush", "XAUUSD", 4.0, 17.2, 30),
    ("QM5_10553_mql5-rsioma", "XAUUSD", 8.0, 19.9, 30),
    ("QM5_13036_balke-go-long-regime", "GDAXI", 8.0, 5.2, 50),
]


class ChallengeSetError(ValueError):
    """Fail-closed qualification or set-file derivation error."""


def _set_values(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for line_number, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = (part.strip() for part in line.split("=", 1))
        if key in values:
            raise ChallengeSetError(f"duplicate set input {key!r} on line {line_number}")
        values[key] = value
    return values


def patch(text: str, risk_percent: float, admission: Mapping[str, Any]) -> str:
    """Render one Q09-bound FTMO set without mutating the measured source."""

    if risk_percent <= 0:
        raise ChallengeSetError("RISK_PERCENT must be positive")
    news_inputs = deployment_news_inputs(admission)
    replacements = {
        "RISK_FIXED": "0",
        "RISK_PERCENT": f"{risk_percent:g}",
        **news_inputs,
    }
    source_values = _set_values(text)
    stale = source_values.get("qm_news_stale_max_hours")
    if stale is not None:
        try:
            stale_value = float(stale)
        except ValueError as exc:
            raise ChallengeSetError("qm_news_stale_max_hours is not numeric") from exc
        if stale_value > 336:
            raise ChallengeSetError("qm_news_stale_max_hours exceeds 336")

    output: list[str] = []
    seen: set[str] = set()
    for raw in text.splitlines():
        stripped = raw.strip()
        key = stripped.split("=", 1)[0].strip() if "=" in stripped else ""
        if key in replacements:
            output.append(f"{key}={replacements[key]}")
            seen.add(key)
        elif stripped.startswith("; environment:"):
            output.append("; environment:  demo")
        elif stripped.startswith("; risk_mode:"):
            output.append("; risk_mode:    PERCENT")
        elif stripped.startswith("; set_version:"):
            output.append(raw)
            output.append(
                "; derived_from: measured backtest set; risk + OWNER Q09 FTMO lock only"
            )
        else:
            output.append(raw)
    for key in ("RISK_FIXED", "RISK_PERCENT", "qm_news_temporal", "qm_news_compliance"):
        if key not in seen:
            output.append(f"{key}={replacements[key]}")
    rendered = "\n".join(output) + "\n"
    values = _set_values(rendered)
    if values["RISK_FIXED"] != "0" or float(values["RISK_PERCENT"]) != risk_percent:
        raise ChallengeSetError("derived risk inputs do not match the requested FTMO sizing")
    if values["qm_news_temporal"] != news_inputs["qm_news_temporal"]:
        raise ChallengeSetError("chosen_temporal was not preserved in the derived set")
    if values["qm_news_compliance"] != news_inputs["qm_news_compliance"]:
        raise ChallengeSetError("FTMO compliance was not preserved in the derived set")
    return rendered


def _numeric_ea(slug: str) -> int:
    match = re.match(r"QM5_(\d+)_", slug)
    if not match:
        raise ChallengeSetError(f"invalid EA slug: {slug}")
    return int(match.group(1))


def _load_inventory(path: Path) -> Mapping[str, Any]:
    try:
        document = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ChallengeSetError(f"qualification inventory is unreadable: {path}") from exc
    if not isinstance(document, Mapping):
        raise ChallengeSetError("qualification inventory must be a JSON object")
    return document


def build(
    inventory: Mapping[str, Any],
    *,
    repo_root: Path,
    manifest_path: Path,
    replace: bool = False,
) -> dict[str, Any]:
    """Preflight the whole book, then write all sets and one bound receipt."""

    plans: list[dict[str, Any]] = []
    for slug, symbol, multiplier, exposure, leverage in BOOK:
        candidates = sorted(
            (repo_root / "framework" / "EAs" / slug / "sets").glob(
                f"*{symbol}.DWX_*_backtest.set"
            )
        )
        if len(candidates) != 1:
            raise ChallengeSetError(
                f"{slug}/{symbol}: expected exactly one measured backtest set, got {len(candidates)}"
            )
        source = candidates[0]
        match = re.search(r"\.DWX_([A-Z0-9]+)_", source.name)
        if not match:
            raise ChallengeSetError(f"cannot derive timeframe from {source.name}")
        timeframe = match.group(1)
        admission = admission_from_inventory(
            inventory, _numeric_ea(slug), f"{symbol}.DWX"
        )
        if admission.get("admitted") is not True:
            raise ChallengeSetError(
                f"{slug}/{symbol}: {admission.get('reason_code')}"
            )
        candidate_row = next(
            (
                row
                for row in inventory.get("candidates") or []
                if isinstance(row, Mapping)
                and str(row.get("ea_id") or "").upper()
                in {str(_numeric_ea(slug)), f"QM5_{_numeric_ea(slug)}"}
                and str(row.get("symbol") or "").upper() == f"{symbol}.DWX"
            ),
            None,
        )
        if not isinstance(candidate_row, Mapping) or candidate_row.get("challenge_ready") is not True:
            raise ChallengeSetError(f"{slug}/{symbol}: qualification is not challenge_ready")
        rendered = patch(source.read_text(encoding="utf-8-sig"), multiplier, admission)
        destination = source.with_name(
            f"{slug}_{symbol}.DWX_{timeframe}_ftmo_challenge.set"
        )
        if destination.exists() and not replace:
            raise ChallengeSetError(f"refusing to replace {destination}")
        plans.append(
            {
                "slug": slug,
                "symbol": symbol,
                "timeframe": timeframe,
                "risk_percent": multiplier,
                "exposure": exposure,
                "leverage": leverage,
                "source": source,
                "destination": destination,
                "rendered": rendered,
                "admission": admission,
            }
        )

    accounts: list[dict[str, Any]] = []
    for plan in plans:
        destination = plan["destination"]
        destination.write_text(plan["rendered"], encoding="utf-8", newline="\n")
        margin_fraction = plan["exposure"] / plan["leverage"]
        accounts.append(
            {
                "ea": plan["slug"],
                "symbol": f"{plan['symbol']}.DWX",
                "timeframe": plan["timeframe"],
                "risk_percent": plan["risk_percent"],
                "risk_fixed": 0,
                "setfile": str(destination.resolve()),
                "setfile_sha256": hashlib.sha256(plan["rendered"].encode("utf-8")).hexdigest(),
                "derived_from": str(plan["source"].resolve()),
                "peak_concurrent_notional_x_equity": plan["exposure"],
                "ftmo_leverage": f"1:{plan['leverage']}",
                "margin_used_pct": round(margin_fraction * 100, 1),
                "q09_news_work_item_id": plan["admission"]["q09_news_work_item_id"],
                "q09_aggregate_sha256": plan["admission"]["aggregate_sha256"],
                "chosen_temporal": plan["admission"]["chosen_temporal"],
                "deployment_compliance": "FTMO",
            }
        )
    receipt = {
        "schema": "qm.ftmo-challenge-config-manifest/v2",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "purpose": "FTMO Phase 1 campaign configuration generation only",
        "trading_authorized": False,
        "q09_consumption_contract": "OWNER_2026_08_04",
        "accounts": accounts,
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    if manifest_path.exists() and not replace:
        raise ChallengeSetError(f"refusing to replace {manifest_path}")
    manifest_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return receipt


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--qualification", required=True, type=Path)
    parser.add_argument("--repo-root", type=Path, default=Path(r"C:\QM\repo"))
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--replace", action="store_true")
    args = parser.parse_args(argv)
    try:
        receipt = build(
            _load_inventory(args.qualification),
            repo_root=args.repo_root.resolve(),
            manifest_path=args.manifest.resolve(),
            replace=args.replace,
        )
    except (ChallengeSetError, ValueError) as exc:
        parser.error(str(exc))
    print(f"wrote {args.manifest} accounts={len(receipt['accounts'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
