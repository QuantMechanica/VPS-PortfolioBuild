from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Sequence

try:
    from .prop_challenge_optimizer import (
        _extract_report_stats,
        _normalize_cell,
        _parse_report_datetime,
        _parse_report_number,
        _report_rows,
    )
except ImportError:  # pragma: no cover - direct script execution
    from prop_challenge_optimizer import (  # type: ignore
        _extract_report_stats,
        _normalize_cell,
        _parse_report_datetime,
        _parse_report_number,
        _report_rows,
    )


DEV_YEARS = frozenset({2020, 2021, 2022})
VALIDATION_YEARS = frozenset({2023})
HOLDOUT_YEARS = frozenset({2024})
SESSION_OPEN_MINUTE = 16 * 60 + 30
ENTRY_CUTOFF_MINUTES = (60, 120, 180, 240, 360)
WEEKDAY_MASKS = {
    "mon_fri": frozenset({0, 1, 2, 3, 4}),
    "mon_thu": frozenset({0, 1, 2, 3}),
    "tue_fri": frozenset({1, 2, 3, 4}),
    "tue_thu": frozenset({1, 2, 3}),
}


@dataclass(frozen=True)
class OrbTrade:
    entry_time: dt.datetime
    exit_time: dt.datetime
    side: str
    volume: float
    net: float
    exit_comment: str

    @property
    def entry_delay_minutes(self) -> int:
        minute = self.entry_time.hour * 60 + self.entry_time.minute
        return minute - SESSION_OPEN_MINUTE


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def extract_orb_trades(report_path: Path, expected_symbol: str) -> tuple[list[OrbTrade], dict[str, Any]]:
    rows = _report_rows(report_path)
    report_stats = _extract_report_stats(rows)
    in_deals = False
    headers: list[str] = []
    open_entries: dict[str, list[dict[str, Any]]] = {"buy": [], "sell": []}
    trades: list[OrbTrade] = []

    for row in rows:
        if len(row) == 1 and _normalize_cell(row[0]) == "deals":
            in_deals = True
            headers = []
            continue
        if not in_deals:
            continue
        if row and _normalize_cell(row[0]) == "time":
            headers = row
            continue
        if not headers or len(row) < len(headers):
            continue

        deal = dict(zip(headers, row))
        if str(deal.get("Symbol") or "").strip() != expected_symbol:
            continue
        direction = _normalize_cell(str(deal.get("Direction") or ""))
        commission = _parse_report_number(str(deal.get("Commission") or "0")) or 0.0
        swap = _parse_report_number(str(deal.get("Swap") or "0")) or 0.0
        profit = _parse_report_number(str(deal.get("Profit") or "0")) or 0.0

        if direction == "in":
            side = _normalize_cell(str(deal.get("Type") or ""))
            if side not in open_entries:
                raise ValueError(f"{report_path}: unsupported entry type {side!r}")
            open_entries[side].append({
                "time": _parse_report_datetime(str(deal.get("Time") or "")),
                "side": side,
                "volume": _required_number(deal.get("Volume"), "Volume"),
                "commission": commission,
                "swap": swap,
            })
            continue
        if direction != "out":
            continue
        exit_type = _normalize_cell(str(deal.get("Type") or ""))
        entry_side = closing_entry_side(exit_type)
        if not open_entries[entry_side]:
            raise ValueError(f"{report_path}: {exit_type} exit has no matching {entry_side} entry")
        entry = open_entries[entry_side].pop(0)
        exit_volume = _required_number(deal.get("Volume"), "Volume")
        if abs(exit_volume - float(entry["volume"])) > 1e-9:
            raise ValueError(f"{report_path}: partial closes are unsupported")
        exit_time = _parse_report_datetime(str(deal.get("Time") or ""))
        trades.append(
            OrbTrade(
                entry_time=entry["time"],
                exit_time=exit_time,
                side=str(entry["side"]),
                volume=exit_volume,
                net=profit + swap + commission + float(entry["commission"]) + float(entry["swap"]),
                exit_comment=str(deal.get("Comment") or ""),
            )
        )

    remaining = sum(len(queue) for queue in open_entries.values())
    if remaining:
        raise ValueError(f"{report_path}: {remaining} entries remain open")
    if report_stats.get("total_trades") != len(trades):
        raise ValueError(
            f"{report_path}: parsed {len(trades)} trades, report says {report_stats.get('total_trades')}"
        )
    return trades, report_stats


def closing_entry_side(exit_type: str) -> str:
    if exit_type == "sell":
        return "buy"
    if exit_type == "buy":
        return "sell"
    raise ValueError(f"unsupported exit type {exit_type!r}")


def _required_number(raw: Any, label: str) -> float:
    value = _parse_report_number(str(raw or ""))
    if value is None:
        raise ValueError(f"missing numeric deal field {label}: {raw!r}")
    return float(value)


def filter_trades(
    trades: Iterable[OrbTrade],
    *,
    years: frozenset[int],
    entry_cutoff_minutes: int,
    weekdays: frozenset[int],
) -> list[OrbTrade]:
    return [
        trade
        for trade in trades
        if trade.entry_time.year in years
        and trade.entry_time.weekday() in weekdays
        and 0 <= trade.entry_delay_minutes <= entry_cutoff_minutes
    ]


def summarize(trades: Sequence[OrbTrade]) -> dict[str, Any]:
    nets = [trade.net for trade in trades]
    gross_profit = sum(value for value in nets if value > 0.0)
    gross_loss = sum(value for value in nets if value < 0.0)
    pf = None if gross_loss == 0.0 else gross_profit / abs(gross_loss)
    balance = 0.0
    peak = 0.0
    max_drawdown = 0.0
    for value in nets:
        balance += value
        peak = max(peak, balance)
        max_drawdown = max(max_drawdown, peak - balance)
    return {
        "trades": len(nets),
        "net_profit": round(sum(nets), 2),
        "gross_profit": round(gross_profit, 2),
        "gross_loss": round(gross_loss, 2),
        "profit_factor": None if pf is None else round(pf, 6),
        "win_rate_pct": None if not nets else round(100.0 * sum(value > 0.0 for value in nets) / len(nets), 3),
        "close_to_close_max_drawdown": round(max_drawdown, 2),
    }


def evaluate_rule(
    trades: Sequence[OrbTrade],
    *,
    cutoff: int,
    weekday_name: str,
    include_holdout: bool,
) -> dict[str, Any]:
    weekdays = WEEKDAY_MASKS[weekday_name]
    row: dict[str, Any] = {
        "entry_cutoff_minutes": cutoff,
        "weekday_mask": weekday_name,
        "weekdays": sorted(weekdays),
        "dev": summarize(filter_trades(trades, years=DEV_YEARS, entry_cutoff_minutes=cutoff, weekdays=weekdays)),
        "validation": summarize(
            filter_trades(trades, years=VALIDATION_YEARS, entry_cutoff_minutes=cutoff, weekdays=weekdays)
        ),
    }
    if include_holdout:
        row["holdout"] = summarize(
            filter_trades(trades, years=HOLDOUT_YEARS, entry_cutoff_minutes=cutoff, weekdays=weekdays)
        )
        row["pooled"] = summarize(
            filter_trades(
                trades,
                years=DEV_YEARS | VALIDATION_YEARS | HOLDOUT_YEARS,
                entry_cutoff_minutes=cutoff,
                weekdays=weekdays,
            )
        )
    return row


def pre_holdout_eligible(row: dict[str, Any]) -> bool:
    dev = row["dev"]
    validation = row["validation"]
    return bool(
        dev["trades"] >= 300
        and validation["trades"] >= 75
        and dev["profit_factor"] is not None
        and validation["profit_factor"] is not None
        and dev["profit_factor"] >= 1.15
        and validation["profit_factor"] >= 1.10
        and dev["net_profit"] > 0.0
        and validation["net_profit"] > 0.0
    )


def selection_key(row: dict[str, Any]) -> tuple[float, float, float, int]:
    dev_pf = float(row["dev"]["profit_factor"] or 0.0)
    val_pf = float(row["validation"]["profit_factor"] or 0.0)
    return (
        min(dev_pf, val_pf),
        (dev_pf + val_pf) / 2.0,
        float(row["dev"]["net_profit"]) + float(row["validation"]["net_profit"]),
        int(row["dev"]["trades"]) + int(row["validation"]["trades"]),
    )


def run_research(report_path: Path, expected_symbol: str) -> dict[str, Any]:
    trades, report_stats = extract_orb_trades(report_path, expected_symbol)
    pre_holdout_rows = [
        evaluate_rule(
            trades,
            cutoff=cutoff,
            weekday_name=weekday_name,
            include_holdout=False,
        )
        for cutoff in ENTRY_CUTOFF_MINUTES
        for weekday_name in WEEKDAY_MASKS
    ]
    eligible = [row for row in pre_holdout_rows if pre_holdout_eligible(row)]
    selected_pre_holdout = max(eligible, key=selection_key) if eligible else None
    selected = None
    verdict = "NO_PRE_HOLDOUT_SURVIVOR"
    if selected_pre_holdout is not None:
        selected = evaluate_rule(
            trades,
            cutoff=int(selected_pre_holdout["entry_cutoff_minutes"]),
            weekday_name=str(selected_pre_holdout["weekday_mask"]),
            include_holdout=True,
        )
        holdout = selected["holdout"]
        pooled = selected["pooled"]
        strict_pass = bool(
            holdout["trades"] >= 75
            and holdout["profit_factor"] is not None
            and holdout["profit_factor"] >= 1.20
            and holdout["net_profit"] > 0.0
            and pooled["profit_factor"] is not None
            and pooled["profit_factor"] >= 1.20
        )
        verdict = "ADVANCE_TO_EXACT_EA" if strict_pass else "HOLDOUT_FAIL"

    side_diagnostics = {
        side: summarize(
            [
                trade
                for trade in trades
                if trade.entry_time.year in DEV_YEARS | VALIDATION_YEARS
                and (side == "all" or trade.side == side)
            ]
        )
        for side in ("all", "buy", "sell")
    }
    return {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "research_contract": {
            "dev_years": sorted(DEV_YEARS),
            "validation_years": sorted(VALIDATION_YEARS),
            "holdout_years": sorted(HOLDOUT_YEARS),
            "selection_uses_holdout": False,
            "candidate_axes": {
                "entry_cutoff_minutes_after_1630_broker": list(ENTRY_CUTOFF_MINUTES),
                "weekday_masks": {name: sorted(days) for name, days in WEEKDAY_MASKS.items()},
            },
            "unchanged": ["ATR period", "entry ATR", "target ATR", "stop", "spread gate", "news gate"],
            "screen_semantics": "causal removal of existing trades; exact EA backtest still required",
        },
        "report": {
            "path": str(report_path),
            "sha256": file_sha256(report_path),
            "native_stats": report_stats,
            "parsed_trades": len(trades),
            "cost_basis": "native MT5 spread plus both 5.5 USD/lot round-trip index commission sides",
        },
        "pre_holdout_candidates": pre_holdout_rows,
        "eligible_pre_holdout_count": len(eligible),
        "selected_rule": selected,
        "side_diagnostics_pre_holdout_only": side_diagnostics,
        "verdict": verdict,
    }


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Holdout-safe research screen for a session ORB v2")
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--symbol", default="NDX.DWX")
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args(list(argv) if argv is not None else None)
    artifact = run_research(args.report, args.symbol)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, default=str) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "eligible_pre_holdout_count": artifact["eligible_pre_holdout_count"],
                "selected_rule": artifact["selected_rule"],
                "side_diagnostics": artifact["side_diagnostics_pre_holdout_only"],
                "verdict": artifact["verdict"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
