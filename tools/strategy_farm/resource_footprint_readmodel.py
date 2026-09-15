#!/usr/bin/env python
"""Empirical MT5 resource-footprint read-model (OWNER directive 3, 2026-09-15 §12).

Derives the *measured* per-run resource footprint of MT5 test classes from the
worker's own per-run ledger ``tester_memory_ledger.jsonl`` (written by
``terminal_worker._write_tester_memory_ledger``, schema
``qm.tester_memory_ledger/v1``) over a trailing window (default 14 days) and
emits two deterministic, idempotent artifacts:

  1. A runtime READ-MODEL ``D:/QM/reports/state/resource_footprints.json``
     (schema ``qm.resource-footprints/v1``): peak RAM percentiles, duration
     percentiles, sample counts and run-kind mix per footprint key, plus an
     explicit NOT_EVALUATED marker for the counters the ledger does not carry
     (CPU share, disk I/O -- the ledger records neither).

  2. A repo CONFIG PROPOSAL ``config/resource_footprints.v1.json`` (schema
     ``qm.resource-footprints-proposal/v1``): a *calibrated reservation table
     proposal* (n, p95, safety margin, proposed reservation) that the worker can
     opt into via ``QM_RAM_TABLE=calibrated`` for a staged rollout.  This
     generator NEVER switches the live reservation table -- it only writes the
     proposal for review.

Footprint key = (ram_class, symbol_class, phase, run_kind).  A coarser
(ram_class, symbol_class) roll-up and an index-by-symbol-base roll-up feed the
reservation proposal, because the live reservation math keys reservations on the
RAM class (and, for index-tick rows, on the symbol base).

Family attribution is optional: pass ``--family-map <json>`` mapping ea_id ->
family; without it the family dimension is reported EVIDENCE_MISSING rather than
guessed (directive: "strategy family ... where derivable").

Determinism: identical ledger + window + config -> byte-identical output
(sorted keys, values rounded, ``generated_at_utc`` is the only volatile field and
can be pinned with ``--now`` for tests).  CPU-modest: a single streaming pass
over the ledger; no MT5 process is touched.
"""
from __future__ import annotations

import argparse
import json
import math
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

READMODEL_SCHEMA = "qm.resource-footprints/v1"
PROPOSAL_SCHEMA = "qm.resource-footprints-proposal/v1"

DEFAULT_LEDGER = "D:/QM/reports/state/tester_memory_ledger.jsonl"
DEFAULT_READMODEL_OUT = "D:/QM/reports/state/resource_footprints.json"
# The repo config proposal lives beside the other farm config contracts.
DEFAULT_PROPOSAL_OUT = str(
    Path(__file__).resolve().parent / "config" / "resource_footprints.v1.json"
)

DEFAULT_WINDOW_DAYS = 14
# The RAM measure the reservation math cares about is the peak working set of the
# whole terminal+metatester subtree.
PEAK_FIELD = "peak_subtree_working_set_gb"

# Reservation-proposal calibration knobs (all overridable via --config).
DEFAULT_PROPOSAL_CONFIG: dict[str, Any] = {
    # A key needs at least this many samples before a data-driven proposal is
    # emitted; below it the proposal keeps the current live reservation and is
    # flagged low_evidence (never silently lowered).
    "min_samples_for_proposal": 8,
    # proposed = ceil(p95 * safety_factor + launch_margin_gb), clamped to
    # [floor_gb, cap_gb].
    "safety_factor": 1.5,
    "launch_margin_gb": 2.0,
    "floor_gb": 6.0,
    "cap_gb": 48.0,
    # Current live flat reservations (terminal_worker), reproduced here so the
    # proposal can show delta-vs-live without importing the worker.  Facts-only.
    "live_reservation_gb": {
        "ordinary": 8.0,
        "opt_census_cell": 4.0,
        "two_leg_fx_pair": 24.0,
        "two_leg_metal_pair": 24.0,
        "heavy_or_unknown_multisymbol": 44.0,
        "multi_leg_fx_basket": 44.0,
        "single_index_tick": 44.0,
    },
    # Live per-base index reservations (terminal_worker INDEX_TICK_RESERVATION_
    # GB_BY_BASE); the proposal recalibrates these from the ledger.
    "live_index_reservation_gb_by_base": {
        "SP500": 44.0,
        "NDX": 12.0,
        "GDAXI": 24.0,
        "WS30": 12.0,
        "UK100": 24.0,
    },
    "index_bases": ["SP500", "NDX", "GDAXI", "WS30", "UK100"],
}

PERCENTILES = (50, 90, 95, 99)


def _utc_now_iso(now: datetime | None = None) -> str:
    dt = now or datetime.now(timezone.utc)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).isoformat()


def _parse_ts(value: object) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None
    text = value.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(text)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _percentile(sorted_values: list[float], q: float) -> float:
    """Deterministic linear-interpolation percentile (q in [0,100])."""
    if not sorted_values:
        return 0.0
    if len(sorted_values) == 1:
        return float(sorted_values[0])
    rank = (q / 100.0) * (len(sorted_values) - 1)
    low = int(math.floor(rank))
    high = int(math.ceil(rank))
    if low == high:
        return float(sorted_values[low])
    frac = rank - low
    return float(sorted_values[low] * (1.0 - frac) + sorted_values[high] * frac)


def _base_symbol(symbol: object) -> str:
    return str(symbol or "").strip().upper().split(".")[0]


def iter_ledger(path: Path) -> Iterable[dict[str, Any]]:
    """Stream ledger records; skip malformed lines (fail-open, facts-only)."""
    try:
        handle = open(path, "r", encoding="utf-8")
    except OSError:
        return
    with handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except (ValueError, TypeError):
                continue
            if isinstance(rec, dict):
                yield rec


class _Accumulator:
    """Collects peak-RAM and duration samples for one footprint key."""

    __slots__ = ("peaks", "durations", "run_kinds", "reservations")

    def __init__(self) -> None:
        self.peaks: list[float] = []
        self.durations: list[float] = []
        self.run_kinds: dict[str, int] = {}
        self.reservations: set[float] = set()

    def add(self, peak: float, duration: float, run_kind: str, reservation: float) -> None:
        self.peaks.append(peak)
        self.durations.append(duration)
        self.run_kinds[run_kind] = self.run_kinds.get(run_kind, 0) + 1
        if math.isfinite(reservation):
            self.reservations.add(round(float(reservation), 3))

    def summary(self) -> dict[str, Any]:
        peaks = sorted(self.peaks)
        durs = sorted(self.durations)
        out: dict[str, Any] = {
            "n": len(peaks),
            "peak_ram_gb": {
                "max": round(peaks[-1], 3) if peaks else 0.0,
                "min": round(peaks[0], 3) if peaks else 0.0,
            },
            "duration_seconds": {
                "max": round(durs[-1], 1) if durs else 0.0,
                "min": round(durs[0], 1) if durs else 0.0,
            },
            "run_kinds": dict(sorted(self.run_kinds.items())),
            "observed_reservation_gb": sorted(self.reservations),
        }
        for q in PERCENTILES:
            out["peak_ram_gb"][f"p{q}"] = round(_percentile(peaks, q), 3)
            out["duration_seconds"][f"p{q}"] = round(_percentile(durs, q), 1)
        return out


def build(
    *,
    ledger_path: Path,
    window_days: int,
    proposal_config: dict[str, Any],
    family_map: dict[str, str] | None,
    now: datetime | None = None,
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Return (readmodel, proposal) dicts from the ledger. Pure over inputs."""
    now_dt = now or datetime.now(timezone.utc)
    cutoff = now_dt.timestamp() - float(window_days) * 86400.0

    by_key: dict[tuple[str, str, str, str], _Accumulator] = {}
    by_class: dict[str, _Accumulator] = {}
    by_class_symbol: dict[tuple[str, str], _Accumulator] = {}
    by_index_base: dict[str, _Accumulator] = {}
    by_family: dict[str, _Accumulator] = {}

    total_seen = 0
    total_in_window = 0
    earliest: str | None = None
    latest: str | None = None
    family_hits = 0

    for rec in iter_ledger(ledger_path):
        total_seen += 1
        ts = _parse_ts(rec.get("ts_utc"))
        if ts is None or ts.timestamp() < cutoff:
            continue
        peak = rec.get(PEAK_FIELD)
        try:
            peak_gb = float(peak)
        except (TypeError, ValueError):
            continue
        if not math.isfinite(peak_gb) or peak_gb <= 0.0:
            continue
        try:
            dur = float(rec.get("run_seconds") or 0.0)
        except (TypeError, ValueError):
            dur = 0.0
        try:
            reservation = float(rec.get("reservation_gb"))
        except (TypeError, ValueError):
            reservation = math.nan

        ram_class = str(rec.get("ram_class") or "UNKNOWN")
        symbol_class = str(rec.get("symbol_class") or "UNKNOWN")
        phase = str(rec.get("phase") or "UNKNOWN")
        run_kind = str(rec.get("run_kind") or "UNKNOWN")
        ea_id = str(rec.get("ea_id") or "")

        total_in_window += 1
        iso = ts.isoformat()
        if earliest is None or iso < earliest:
            earliest = iso
        if latest is None or iso > latest:
            latest = iso

        by_key.setdefault((ram_class, symbol_class, phase, run_kind), _Accumulator()).add(
            peak_gb, dur, run_kind, reservation
        )
        by_class.setdefault(ram_class, _Accumulator()).add(peak_gb, dur, run_kind, reservation)
        by_class_symbol.setdefault((ram_class, symbol_class), _Accumulator()).add(
            peak_gb, dur, run_kind, reservation
        )
        if ram_class == "single_index_tick":
            base = _base_symbol(rec.get("symbol"))
            if base:
                by_index_base.setdefault(base, _Accumulator()).add(
                    peak_gb, dur, run_kind, reservation
                )
        if family_map is not None:
            fam = family_map.get(ea_id)
            if fam:
                family_hits += 1
                by_family.setdefault(str(fam), _Accumulator()).add(
                    peak_gb, dur, run_kind, reservation
                )

    def _keyed(d: dict[tuple[str, str, str, str], _Accumulator]) -> dict[str, Any]:
        return {
            "|".join(k): acc.summary() for k, acc in sorted(d.items())
        }

    def _keyed2(d: dict[tuple[str, str], _Accumulator]) -> dict[str, Any]:
        return {"|".join(k): acc.summary() for k, acc in sorted(d.items())}

    def _keyed1(d: dict[str, _Accumulator]) -> dict[str, Any]:
        return {k: acc.summary() for k, acc in sorted(d.items())}

    generated = _utc_now_iso(now_dt)

    readmodel = {
        "schema": READMODEL_SCHEMA,
        "generated_at_utc": generated,
        "source_ledger": str(ledger_path),
        "window_days": int(window_days),
        "window_start_utc": _utc_now_iso(
            datetime.fromtimestamp(cutoff, tz=timezone.utc)
        ),
        "peak_field": PEAK_FIELD,
        "records": {
            "seen_total": total_seen,
            "in_window": total_in_window,
            "earliest_in_window_utc": earliest,
            "latest_in_window_utc": latest,
        },
        "not_evaluated": {
            "cpu_share": "EVIDENCE_MISSING: tester_memory_ledger/v1 records no "
            "per-run CPU counter; CPU share is not derivable from this source.",
            "disk_io": "EVIDENCE_MISSING: tester_memory_ledger/v1 records no "
            "per-run disk I/O counter; disk I/O is not derivable from this source.",
        },
        "family": (
            {
                "family_source": "MAPPED",
                "mapped_records": family_hits,
                "by_family": _keyed1(by_family),
            }
            if family_map is not None
            else {
                "family_source": "EVIDENCE_MISSING",
                "reason": "no ea_id->family map supplied (--family-map); the "
                "ledger carries ea_id but not family. Footprint by family is "
                "NOT_EVALUATED.",
            }
        ),
        "footprints": {
            "by_ram_class": _keyed1(by_class),
            "by_ram_class_symbol_class": _keyed2(by_class_symbol),
            "by_ram_class_symbol_class_phase_run_kind": _keyed(by_key),
            "by_index_symbol_base": _keyed1(by_index_base),
        },
    }

    proposal = _build_proposal(
        by_class=by_class,
        by_index_base=by_index_base,
        proposal_config=proposal_config,
        window_days=window_days,
        generated=generated,
        source_ledger=ledger_path,
        records_in_window=total_in_window,
    )
    return readmodel, proposal


def _propose_gb(p95: float, cfg: dict[str, Any]) -> float:
    raw = p95 * float(cfg["safety_factor"]) + float(cfg["launch_margin_gb"])
    proposed = math.ceil(raw)
    proposed = max(float(cfg["floor_gb"]), float(proposed))
    proposed = min(float(cfg["cap_gb"]), float(proposed))
    return float(proposed)


def _proposal_entry(
    acc: _Accumulator, live_gb: float | None, cfg: dict[str, Any]
) -> dict[str, Any]:
    s = acc.summary()
    n = s["n"]
    p95 = s["peak_ram_gb"]["p95"]
    max_gb = s["peak_ram_gb"]["max"]
    min_n = int(cfg["min_samples_for_proposal"])
    entry: dict[str, Any] = {
        "n": n,
        "p95_peak_ram_gb": p95,
        "max_peak_ram_gb": max_gb,
        "safety_factor": float(cfg["safety_factor"]),
        "launch_margin_gb": float(cfg["launch_margin_gb"]),
        "live_reservation_gb": live_gb,
    }
    if n < min_n:
        entry["proposed_reservation_gb"] = live_gb
        entry["low_evidence"] = True
        entry["note"] = (
            f"n={n} < min_samples_for_proposal={min_n}; keep live reservation "
            "(never lowered without evidence)."
        )
        return entry
    proposed = _propose_gb(p95, cfg)
    entry["proposed_reservation_gb"] = proposed
    entry["low_evidence"] = False
    if live_gb is not None:
        entry["delta_vs_live_gb"] = round(proposed - float(live_gb), 3)
    return entry


def _build_proposal(
    *,
    by_class: dict[str, _Accumulator],
    by_index_base: dict[str, _Accumulator],
    proposal_config: dict[str, Any],
    window_days: int,
    generated: str,
    source_ledger: Path,
    records_in_window: int,
) -> dict[str, Any]:
    cfg = proposal_config
    live_by_class = dict(cfg.get("live_reservation_gb") or {})
    live_by_base = dict(cfg.get("live_index_reservation_gb_by_base") or {})

    by_class_out: dict[str, Any] = {}
    for ram_class, acc in sorted(by_class.items()):
        # opt_census_cell keeps its flat 4 GB by policy (small-lane protection);
        # still report its measured footprint for transparency.
        by_class_out[ram_class] = _proposal_entry(
            acc, live_by_class.get(ram_class), cfg
        )
    # Classes with a live reservation but no in-window samples: report as
    # EVIDENCE_MISSING so the table is complete and honest.
    for ram_class, live_gb in sorted(live_by_class.items()):
        if ram_class not in by_class_out:
            by_class_out[ram_class] = {
                "n": 0,
                "proposed_reservation_gb": live_gb,
                "live_reservation_gb": live_gb,
                "low_evidence": True,
                "note": "EVIDENCE_MISSING: no run in window; keep live reservation.",
            }

    index_out: dict[str, Any] = {}
    for base in sorted(set(list(cfg.get("index_bases", [])) + list(by_index_base.keys()))):
        live_gb = live_by_base.get(base)
        acc = by_index_base.get(base)
        if acc is None:
            index_out[base] = {
                "n": 0,
                "proposed_reservation_gb": live_gb,
                "live_reservation_gb": live_gb,
                "low_evidence": True,
                "note": "EVIDENCE_MISSING: no full-window index run in window; "
                "keep live reservation (index full-window runs are rare in the "
                "ledger; see terminal_worker INDEX_TICK_RESERVATION_GB_BY_BASE).",
            }
        else:
            index_out[base] = _proposal_entry(acc, live_gb, cfg)

    return {
        "schema": PROPOSAL_SCHEMA,
        "generated_at_utc": generated,
        "source_ledger": str(source_ledger),
        "window_days": int(window_days),
        "records_in_window": int(records_in_window),
        "activation": {
            "env": "QM_RAM_TABLE",
            "value_to_activate": "calibrated",
            "default_behaviour": "unset/observed/0 -> live reservation table "
            "(terminal_worker) unchanged; this proposal is NOT applied.",
            "staged_rollout": "set QM_RAM_TABLE=calibrated at machine scope, then "
            "staggered worker reload; measure 1h; rollback by clearing the env.",
            "note": "This generator NEVER switches the live reservation table.",
        },
        "calibration_config": {
            "min_samples_for_proposal": int(cfg["min_samples_for_proposal"]),
            "safety_factor": float(cfg["safety_factor"]),
            "launch_margin_gb": float(cfg["launch_margin_gb"]),
            "floor_gb": float(cfg["floor_gb"]),
            "cap_gb": float(cfg["cap_gb"]),
            "formula": "proposed = clamp(ceil(p95*safety_factor + launch_margin_gb), floor, cap)",
        },
        "reservation_by_ram_class": by_class_out,
        "index_reservation_by_symbol_base": index_out,
    }


def _load_json(path: Path) -> dict[str, Any]:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def _write_json_atomic(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, sort_keys=True)
        handle.write("\n")
    os.replace(tmp, path)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ledger", default=DEFAULT_LEDGER)
    ap.add_argument("--readmodel-out", default=DEFAULT_READMODEL_OUT)
    ap.add_argument("--proposal-out", default=DEFAULT_PROPOSAL_OUT)
    ap.add_argument("--window-days", type=int, default=DEFAULT_WINDOW_DAYS)
    ap.add_argument("--config", default=None, help="JSON overriding calibration knobs")
    ap.add_argument("--family-map", default=None, help="JSON {ea_id: family}")
    ap.add_argument("--now", default=None, help="ISO ts to pin generated_at_utc (tests)")
    ap.add_argument(
        "--no-proposal",
        action="store_true",
        help="only write the runtime read-model, not the repo config proposal",
    )
    ap.add_argument("--stdout", action="store_true", help="print read-model to stdout")
    args = ap.parse_args(argv)

    proposal_config = dict(DEFAULT_PROPOSAL_CONFIG)
    if args.config:
        override = _load_json(Path(args.config))
        proposal_config.update(override)

    family_map = None
    if args.family_map:
        raw = _load_json(Path(args.family_map))
        family_map = {str(k): str(v) for k, v in raw.items()}

    now = _parse_ts(args.now) if args.now else None

    readmodel, proposal = build(
        ledger_path=Path(args.ledger),
        window_days=args.window_days,
        proposal_config=proposal_config,
        family_map=family_map,
        now=now,
    )

    _write_json_atomic(Path(args.readmodel_out), readmodel)
    if not args.no_proposal:
        _write_json_atomic(Path(args.proposal_out), proposal)

    if args.stdout:
        print(json.dumps(readmodel, indent=2, sort_keys=True))
    else:
        print(
            f"resource_footprints: {readmodel['records']['in_window']} runs in "
            f"{args.window_days}d -> {args.readmodel_out}"
            + ("" if args.no_proposal else f" + proposal {args.proposal_out}")
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
