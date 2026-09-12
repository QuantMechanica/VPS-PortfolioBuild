#!/usr/bin/env python3
"""Build a read-only, per-magic realised attribution from AccountMonitor deals."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

EXIT_MARKERS = {"OUT", "OUT_BY", "INOUT"}
TRADE_TYPES = {"BUY", "SELL"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def magic_of(rows: list[dict[str, str]]) -> int:
    for row in rows:
        for field in ("logical_magic", "deal_magic", "magic"):
            value = row.get(field, "").strip()
            if value and int(value):
                return int(value)
    return 0


def symbol_from_preset(path: str) -> str:
    name = Path(path).stem
    parts = name.split("_")
    return parts[1] if len(parts) >= 2 else ""


def source_identity(path: Path) -> dict[str, Any]:
    stat = path.stat()
    return {
        "path": str(path.resolve()),
        "sha256": sha256(path),
        "size_bytes": stat.st_size,
        "mtime_utc": datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat(),
    }


def closed_positions(rows: list[dict[str, str]], start_utc: str) -> list[dict[str, Any]]:
    by_position: dict[int, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        if row.get("type", "").upper() not in TRADE_TYPES:
            continue
        position_id = int(row.get("position_id") or 0)
        if position_id > 0:
            by_position[position_id].append(row)
    result = []
    for position_id, lifecycle in by_position.items():
        lifecycle.sort(key=lambda row: (row["time_utc"], int(row["deal_id"])))
        exits = [row for row in lifecycle if row["entry"].upper() in EXIT_MARKERS]
        entries = [row for row in lifecycle if row["entry"].upper() in {"IN", "INOUT"}]
        if not exits or not entries:
            continue
        closed_at = max(row["time_utc"] for row in exits)
        if closed_at < start_utc:
            continue
        opened = min(entries, key=lambda row: (row["time_utc"], int(row["deal_id"])))
        result.append({
            "position_id": position_id,
            "magic": magic_of(lifecycle),
            "symbol": next((row["symbol"] for row in lifecycle if row.get("symbol")), ""),
            "opened_at_utc": opened["time_utc"],
            "closed_at_utc": closed_at,
            "entry_hour_utc": int(opened["time_utc"][11:13]),
            "lots": sum(float(row.get("volume") or 0.0) for row in entries),
            "net": sum(float(row.get("net_actual") or 0.0) for row in lifecycle),
        })
    return sorted(result, key=lambda row: (row["closed_at_utc"], row["position_id"]))


def aggregate(magic: int, positions: list[dict[str, Any]], roster: dict[int, dict[str, Any]]) -> dict[str, Any]:
    wins = [row["net"] for row in positions if row["net"] > 0]
    losses = [row["net"] for row in positions if row["net"] < 0]
    gross_win = sum(wins)
    gross_loss = sum(losses)
    histogram = {str(hour): 0 for hour in range(24)}
    for row in positions:
        histogram[str(row["entry_hour_utc"])] += 1
    roster_row = roster.get(magic, {})
    symbols = sorted({row["symbol"] for row in positions if row["symbol"]})
    if not symbols and roster_row:
        symbol = symbol_from_preset(str(roster_row.get("deployed_preset", "")))
        symbols = [symbol] if symbol else []
    return {
        "magic": magic,
        "ea_id": None if magic == 0 else magic // 10000,
        "symbols": symbols,
        "in_current_roster": magic in roster,
        "closes": len(positions),
        "flat": len(positions) == 0,
        "net": round(sum(row["net"] for row in positions), 2),
        "gross_win": round(gross_win, 2),
        "gross_loss": round(gross_loss, 2),
        "profit_factor": None if gross_loss == 0 else round(gross_win / abs(gross_loss), 6),
        "lots": round(sum(row["lots"] for row in positions), 4),
        "entry_hour_utc": histogram,
    }


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Sunday live realised attribution",
        "",
        f"Generated UTC: `{report['generated_at_utc']}`  ",
        f"Window: `{report['window']['start_utc']}` through `{report['window']['last_deal_utc']}`  ",
        "Mode: `READ_ONLY_T_LIVE_INPUT`",
        "",
        "Net, gross win/loss and PF are net-of-cost by closed position (`net_actual` over the full lifecycle). Entry-hour histograms are UTC. `flat` means zero closes in this window, not zero open risk.",
        "",
        "| Magic | EA | Symbols | Roster | Closes | Net | Gross win | Gross loss | PF | Lots | Entry hours UTC |",
        "|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---|",
    ]
    for row in report["per_magic"]:
        histogram = ", ".join(f"{hour}:{count}" for hour, count in row["entry_hour_utc"].items() if count) or "none"
        pf = "N/A" if row["profit_factor"] is None else f"{row['profit_factor']:.3f}"
        lines.append(
            f"| {row['magic']} | {row['ea_id'] or ''} | {', '.join(row['symbols'])} | "
            f"{'yes' if row['in_current_roster'] else 'no'} | {row['closes']} | {row['net']:.2f} | "
            f"{row['gross_win']:.2f} | {row['gross_loss']:.2f} | {pf} | {row['lots']:.4f} | {histogram} |"
        )
    manual = report["manual_magic_0"]
    lines += [
        "",
        "## Manual magic 0 (separate)",
        "",
        f"Closed positions: **{manual['closes']}**; net: **{manual['net']:.2f}**; lots: **{manual['lots']:.4f}**. Balance and dividend rows are excluded from trade attribution.",
        "",
    ]
    return "\n".join(lines)


def build(source: Path, pointer_path: Path, start_utc: str, generated_at_utc: str) -> dict[str, Any]:
    with source.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows or "position_id" not in rows[0] or "net_actual" not in rows[0]:
        raise ValueError("deal export schema missing position_id/net_actual")
    pointer = json.loads(pointer_path.read_text(encoding="utf-8-sig"))
    roster_rows = pointer["binary_setfile_fingerprint"]["per_sleeve"]
    roster = {int(row["magic_number"]): row for row in roster_rows}
    positions = closed_positions(rows, start_utc)
    observed_nonzero = {row["magic"] for row in positions if row["magic"] != 0}
    magics = sorted(set(roster) | observed_nonzero)
    per_magic = [aggregate(magic, [row for row in positions if row["magic"] == magic], roster) for magic in magics]
    manual = aggregate(0, [row for row in positions if row["magic"] == 0], roster)
    return {
        "schema": "qm.sunday-live-realised-attribution/v1",
        "generated_at_utc": generated_at_utc,
        "mode": "READ_ONLY_T_LIVE_INPUT",
        "source": source_identity(source),
        "pointer": source_identity(pointer_path),
        "window": {"start_utc": start_utc, "last_deal_utc": max(row["time_utc"] for row in rows)},
        "definitions": {
            "close": "position lifecycle with OUT/OUT_BY/INOUT; assigned by final exit UTC",
            "net": "sum net_actual across all lifecycle deals",
            "profit_factor": "sum positive position net / absolute sum negative position net",
            "lots": "sum entry-deal volume",
            "entry_hour": "hour of first IN/INOUT deal in UTC",
        },
        "per_magic": per_magic,
        "manual_magic_0": manual,
        "non_trade_magic_0_rows_excluded": sum(row.get("type", "").upper() not in TRADE_TYPES and int(row.get("magic") or 0) == 0 for row in rows),
        "authorization": {"t_live_write": False, "terminal_control": False, "autotrading_toggle": False, "order_action": False},
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--pointer", type=Path, required=True)
    parser.add_argument("--start-utc", default="2026-07-24T00:00:00Z")
    parser.add_argument("--generated-at-utc", required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    report = build(args.source, args.pointer, args.start_utc, args.generated_at_utc)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    snapshot = args.out_dir / "live_deals_normalized.csv"
    shutil.copy2(args.source, snapshot)
    report["snapshot"] = source_identity(snapshot)
    json_path = args.out_dir / "sunday_live_attribution.json"
    md_path = args.out_dir / "sunday_live_attribution.md"
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    md_path.write_text(render_markdown(report), encoding="utf-8")
    print(json.dumps({"json": str(json_path), "markdown": str(md_path), "snapshot": str(snapshot), "per_magic": len(report["per_magic"]), "manual_closes": report["manual_magic_0"]["closes"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
