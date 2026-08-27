"""Read-only preflight/protocol probe for DL-089 native MT5 optimization.

This tool intentionally does not launch MetaTrader.  It proves whether the
commissioned one-input/154-value experiment can be represented by the current
EA binary and ledger before a disposable profile consumes resources.  When the
contract cannot be represented exactly, it emits:

* the minimal exact complete-search decomposition that preserves the binary;
* a cold-receipt comparison CSV with the missing native-pass side explicit;
* an adapter-gap analysis and a no-launch feasibility verdict.

The farm database is opened in URI ``mode=ro`` with ``query_only`` enabled.
Only files below the caller's output directory are written.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_LEDGER = Path(
    r"D:\QM\strategy_farm\artifacts\opt_census\DL089_QM5_10706_GBPUSD_DWX_2019_2025\ledger.json"
)
DEFAULT_EA_DIR = Path(
    r"C:\QM\repo\framework\EAs\QM5_41161_tv-mon-ls-opt"
)
EXPECTED_LEDGER_SCHEMA = "qm.opt-census.v1"
EXPECTED_CELL_COUNT = 155
EXPECTED_DIRECTION_COUNT = 77
OPT_INPUTS = (
    "opt_pp_buy1",
    "opt_pp_buy2",
    "opt_pp_buy3",
    "opt_pp_sell1",
    "opt_pp_sell2",
    "opt_pp_sell3",
)
_INPUT_RE = re.compile(r"^\s*input\s+int\s+(opt_pp_(?:buy|sell)[123])\s*=", re.MULTILINE)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def contiguous_segments(values: Iterable[int]) -> list[tuple[int, int]]:
    ordered = sorted(set(int(value) for value in values))
    if not ordered:
        return []
    segments: list[tuple[int, int]] = []
    start = previous = ordered[0]
    for value in ordered[1:]:
        if value == previous + 1:
            previous = value
            continue
        segments.append((start, previous))
        start = previous = value
    segments.append((start, previous))
    return segments


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _load_json(path: Path) -> dict[str, Any]:
    value = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def _year_cells(ledger: Mapping[str, Any], year: int) -> list[dict[str, Any]]:
    return [
        dict(cell)
        for cell in ledger.get("cells", [])
        if int(cell.get("year") or 0) == int(year)
    ]


def _replace_input(text: str, name: str, replacement: str) -> str:
    pattern = re.compile(rf"(?m)^{re.escape(name)}=.*$")
    if len(pattern.findall(text)) != 1:
        raise ValueError(f"base setfile must contain exactly one {name}= line")
    return pattern.sub(f"{name}={replacement}", text)


def optimizer_setfile(
    base_text: str,
    *,
    target_input: str,
    start: int,
    stop: int,
) -> str:
    if target_input not in OPT_INPUTS:
        raise ValueError(f"unsupported optimization input: {target_input}")
    rendered = base_text
    for name in OPT_INPUTS:
        value = f"{start}||{start}||1||{stop}||Y" if name == target_input else "0"
        rendered = _replace_input(rendered, name, value)
    # Build guardrails are checked again on the rendered artifact, not inferred
    # from the source setfile.
    risk_fixed = re.search(r"(?m)^RISK_FIXED=([^\r\n]+)$", rendered)
    try:
        risk_fixed_value = float(risk_fixed.group(1)) if risk_fixed else 0.0
    except ValueError:
        risk_fixed_value = 0.0
    if risk_fixed_value <= 0:
        raise ValueError("optimizer setfile requires RISK_FIXED > 0")
    risk_percent = re.search(r"(?m)^RISK_PERCENT=([^\r\n]+)$", rendered)
    try:
        risk_percent_value = float(risk_percent.group(1)) if risk_percent else 1.0
    except ValueError:
        risk_percent_value = 1.0
    if risk_percent_value != 0:
        raise ValueError("optimizer setfile requires RISK_PERCENT = 0")
    stale = re.search(r"(?m)^qm_news_stale_max_hours=(\d+)$", rendered)
    if stale and int(stale.group(1)) > 336:
        raise ValueError("qm_news_stale_max_hours may not exceed 336")
    return rendered


def tester_ini(*, job_id: str, setfile_name: str) -> str:
    lines = [
        "[Tester]",
        r"Expert=QM\QM5_41161_tv-mon-ls-opt",
        "ExpertParameters=" + setfile_name,
        "Symbol=GBPUSD.DWX",
        "Period=H1",
        "Model=4",
        "ExecutionMode=0",
        "Optimization=1",
        "OptimizationCriterion=0",
        "FromDate=2019.01.01",
        "ToDate=2019.12.31",
        "ForwardMode=0",
        "Deposit=100000",
        "Currency=USD",
        "Leverage=100",
        "UseLocal=1",
        "UseRemote=0",
        "UseCloud=0",
        "Visual=0",
        "ReplaceReport=1",
        "ShutdownTerminal=1",
        f"Report=reports\\{job_id}.xml",
    ]
    return "\n".join(lines) + "\n"


def build_protocol(
    *,
    ledger_path: Path,
    ea_dir: Path,
    year: int = 2019,
) -> dict[str, Any]:
    ledger = _load_json(ledger_path)
    if ledger.get("schema") != EXPECTED_LEDGER_SCHEMA:
        raise ValueError(f"ledger schema must be {EXPECTED_LEDGER_SCHEMA}")
    cells = _year_cells(ledger, year)
    if len(cells) != EXPECTED_CELL_COUNT:
        raise ValueError(
            f"year {year} must contain {EXPECTED_CELL_COUNT} cells, found {len(cells)}"
        )
    baseline = [cell for cell in cells if str(cell.get("direction")) == "NONE"]
    buy = [cell for cell in cells if str(cell.get("direction")) == "BUY"]
    sell = [cell for cell in cells if str(cell.get("direction")) == "SELL"]
    if len(baseline) != 1 or len(buy) != 77 or len(sell) != 77:
        raise ValueError("expected baseline + 77 BUY + 77 SELL cells")
    buy_ids = [int(cell["predicate_id"]) for cell in buy]
    sell_ids = [int(cell["predicate_id"]) for cell in sell]
    if sorted(buy_ids) != sorted(sell_ids):
        raise ValueError("BUY and SELL predicate universes differ")

    mq5 = Path(ea_dir) / "QM5_41161_tv-mon-ls-opt.mq5"
    ex5 = Path(ea_dir) / "QM5_41161_tv-mon-ls-opt.ex5"
    source = mq5.read_text(encoding="utf-8-sig")
    declared_inputs = sorted(set(_INPUT_RE.findall(source)))
    if declared_inputs != sorted(OPT_INPUTS):
        raise ValueError(
            "current EA does not expose the expected six directional pattern inputs"
        )
    base_setfile = Path(str(ledger["base_setfile_path"]))
    base_text = base_setfile.read_text(encoding="utf-8-sig")
    segments = contiguous_segments(buy_ids)

    jobs: list[dict[str, Any]] = []
    for direction, target_input in (("BUY", "opt_pp_buy1"), ("SELL", "opt_pp_sell1")):
        for start, stop in segments:
            job_id = f"{direction.lower()}_{start:03d}_{stop:03d}"
            setfile_name = f"QM5_41161_native_{year}_{job_id}.set"
            set_text = optimizer_setfile(
                base_text,
                target_input=target_input,
                start=start,
                stop=stop,
            )
            jobs.append(
                {
                    "job_id": job_id,
                    "direction": direction,
                    "target_input": target_input,
                    "range_start": start,
                    "range_step": 1,
                    "range_stop": stop,
                    "pass_count": stop - start + 1,
                    "algorithm": "SLOW_COMPLETE",
                    "setfile_name": setfile_name,
                    "setfile_sha256": hashlib.sha256(set_text.encode("utf-8")).hexdigest(),
                    "setfile_text": set_text,
                    "tester_ini_text": tester_ini(job_id=job_id, setfile_name=setfile_name),
                }
            )

    sparse_span = max(buy_ids) - min(buy_ids) + 1
    return {
        "schema": "qm.mt5-native-optimizer-feasibility/v1",
        "generated_at_utc": _utc_now(),
        "launch_performed": False,
        "launch_refusal": "ONE_INPUT_154_VALUE_CONTRACT_NOT_REPRESENTABLE_BY_CURRENT_BINARY",
        "year": year,
        "ea_id": "QM5_41161",
        "symbol": "GBPUSD.DWX",
        "period": "H1",
        "model": 4,
        "seed": 42,
        "ledger_path": str(Path(ledger_path).resolve()),
        "ledger_sha256": sha256_file(ledger_path),
        "base_setfile_path": str(base_setfile.resolve()),
        "base_setfile_sha256": sha256_file(base_setfile),
        "mq5_path": str(mq5.resolve()),
        "mq5_sha256": sha256_file(mq5),
        "ex5_path": str(ex5.resolve()),
        "ex5_sha256": sha256_file(ex5),
        "declared_pattern_inputs": declared_inputs,
        "matrix": {
            "baseline_cells": 1,
            "buy_cells": len(buy),
            "sell_cells": len(sell),
            "searched_hypotheses": len(buy) + len(sell),
            "total_cells_including_baseline": len(cells),
            "predicate_ids": sorted(buy_ids),
            "predicate_id_segments": [[start, stop] for start, stop in segments],
            "naive_arithmetic_span_count_per_direction": sparse_span,
            "invalid_gap_values_per_direction": sparse_span - len(buy_ids),
        },
        "single_input_154_exact": {
            "feasible": False,
            "reasons": [
                "BUY and SELL are distinct EA inputs; one input cannot select both directions.",
                (
                    f"The {len(buy_ids)} valid predicate IDs are sparse across "
                    f"{min(buy_ids)}..{max(buy_ids)} ({sparse_span} arithmetic values)."
                ),
                "The neutral baseline is a separate 155th configuration.",
                "Adding a signed arm-index adapter would change the EX5 hash and break exact cold-receipt identity.",
            ],
        },
        "exact_binary_preserving_decomposition": {
            "job_count": len(jobs),
            "complete_passes": sum(int(job["pass_count"]) for job in jobs),
            "baseline_replay_required": True,
            "jobs": jobs,
            "agent_contract": {
                "profile": "fresh disposable portable profile",
                "optimization": 1,
                "genetic_forbidden": True,
                "remote_agents": False,
                "cloud_agents": False,
                "local_agent_allowlist_must_be_hash_sealed": True,
                "cache_must_be_empty_before_first_job": True,
            },
        },
    }


def _read_only_connection(path: Path) -> sqlite3.Connection:
    con = sqlite3.connect(Path(path).resolve().as_uri() + "?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA query_only=ON")
    return con


def _job_for_arm(protocol: Mapping[str, Any], direction: str, predicate_id: int) -> str:
    for job in protocol["exact_binary_preserving_decomposition"]["jobs"]:
        if (
            job["direction"] == direction
            and int(job["range_start"]) <= predicate_id <= int(job["range_stop"])
        ):
            return str(job["job_id"])
    return "UNMAPPED"


def cold_comparison_rows(
    con: sqlite3.Connection,
    *,
    protocol: Mapping[str, Any],
) -> list[dict[str, Any]]:
    rows = con.execute(
        """
        SELECT id, evidence_path, payload_json, ex5_sha256, setfile_sha256,
               mq5_sha256, updated_at
        FROM work_items
        WHERE ea_id=? AND symbol=? AND phase='OPT_CENSUS'
          AND status='done' AND verdict='MEASURED'
        ORDER BY updated_at, id
        """,
        (protocol["ea_id"], protocol["symbol"]),
    ).fetchall()
    output: list[dict[str, Any]] = []
    for row in rows:
        payload = json.loads(row["payload_json"] or "{}")
        if int(payload.get("year") or 0) != int(protocol["year"]):
            continue
        summary_path = Path(str(row["evidence_path"] or ""))
        try:
            summary = _load_json(summary_path)
            ok_runs = [run for run in summary.get("runs", []) if run.get("status") == "OK"]
            run = ok_runs[0] if len(ok_runs) == 1 else {}
        except (OSError, ValueError, json.JSONDecodeError):
            summary = {}
            run = {}
        direction = str(payload.get("direction") or "NONE").upper()
        predicate_id = int(payload.get("predicate_id") or 0)
        job_id = (
            "baseline_cold_only"
            if direction == "NONE"
            else _job_for_arm(protocol, direction, predicate_id)
        )
        report_path = Path(str(run.get("report_canonical_path") or ""))
        output.append(
            {
                "cell_key": payload.get("cell_key"),
                "work_item_id": row["id"],
                "direction": direction,
                "predicate_id": predicate_id,
                "mapped_native_job": job_id,
                "cold_ex5_sha256": row["ex5_sha256"] or payload.get("expected_ex5_sha256"),
                "cold_mq5_sha256": row["mq5_sha256"] or payload.get("expected_mq5_sha256"),
                "cold_setfile_sha256": row["setfile_sha256"] or payload.get("expected_setfile_sha256"),
                "cold_report_sha256": run.get("report_sha256") or (
                    sha256_file(report_path) if report_path.is_file() else None
                ),
                "cold_total_trades": run.get("total_trades"),
                "cold_profit_factor": run.get("profit_factor"),
                "cold_net_profit": run.get("net_profit"),
                "cold_max_drawdown": run.get("drawdown"),
                "cold_logger_sha256": (summary.get("logger_sample") or {}).get("sha256"),
                "native_pass_status": "NOT_RUN_PREFLIGHT_CONTRACT_MISMATCH",
                "native_total_trades": None,
                "native_profit_factor": None,
                "native_net_profit": None,
                "native_max_drawdown": None,
                "field_exact_match": None,
                "trade_list_byte_match": None,
            }
        )
    return output


def render_report(
    protocol: Mapping[str, Any], comparisons: Sequence[Mapping[str, Any]]
) -> str:
    matrix = protocol["matrix"]
    decomposition = protocol["exact_binary_preserving_decomposition"]
    hashes = {
        str(row.get("cold_ex5_sha256") or "") for row in comparisons
    } - {""}
    lines = [
        "# V4b MT5-native optimizer feasibility — preflight stop",
        "",
        "**Verdict:** `NOT_REPRODUCIBLE_AS_SPECIFIED`",
        "**Execution:** `NO_MT5_LAUNCH`",
        "",
        "The exact commissioned experiment cannot be encoded by the current, hash-bound "
        "EA. The fail-closed preflight therefore stopped before creating or launching a "
        "terminal profile. T1–T10, T_Live, the queue, and the farm database were untouched.",
        "",
        "## Acceptance result",
        "",
        "| Criterion | Result |",
        "|---|---|",
        "| Exact prototype protocol/configs | PASS: exact binary-preserving decomposition emitted in the JSON artifact |",
        (
            "| Native pass versus cold receipt | DEVIATION: 0 native passes; "
            f"{len(comparisons)} authenticated cold receipts inventoried in CSV |"
        ),
        "| Feasibility verdict + adapter design | PASS: drop-in replacement rejected; bounded alternative specified |",
        "| Durable evidence | PASS: Markdown + JSON protocol + CSV comparison |",
        "",
        "## Why the requested one-input/154-value run has no exact config",
        "",
        f"The 2019 ledger contains **{matrix['total_cells_including_baseline']}** cells: "
        f"one neutral baseline plus {matrix['buy_cells']} BUY and {matrix['sell_cells']} SELL "
        "hypotheses. The current EA exposes six directional inputs (`opt_pp_buy1..3`, "
        "`opt_pp_sell1..3`); one input cannot express both directions.",
        "",
        (
            f"The predicate IDs are also sparse: {matrix['predicate_ids'][0]} through "
            f"{matrix['predicate_ids'][-1]} contains "
            f"{matrix['naive_arithmetic_span_count_per_direction']} integer values but only "
            f"{matrix['buy_cells']} valid predicates. A naive start/step/stop range would "
            f"run {matrix['invalid_gap_values_per_direction']} invalid INIT configurations per side."
        ),
        "",
        "A new signed `arm_index` input could map 154 values, but compiling it would change "
        f"the sealed EX5 `{protocol['ex5_sha256']}`. It could no longer be an exact "
        "reproduction of the existing cold receipts.",
        "",
        "## Exact binary-preserving alternative (not run)",
        "",
        "Use slow complete search (`Optimization=1`) in eight jobs, each varying one "
        "directional input over one contiguous valid-ID segment, plus one separate baseline. "
        "Remote and cloud agents are disabled. The full INI and setfile bytes for every job "
        "are embedded in the protocol JSON.",
        "",
        "| Job | Input | Range | Passes |",
        "|---|---|---:|---:|",
    ]
    for job in decomposition["jobs"]:
        lines.append(
            f"| {job['job_id']} | `{job['target_input']}` | "
            f"{job['range_start']}..{job['range_stop']} step {job['range_step']} | "
            f"{job['pass_count']} |"
        )
    lines.extend(
        [
            "",
            f"Total: {decomposition['complete_passes']} valid optimizer passes + one "
            "standalone baseline = 155 configurations. This changes orchestration shape "
            "but not strategy mechanics or the binary.",
            "",
            "## Cold-reference inventory versus native-pass side",
            "",
            f"Cold receipts available at snapshot: **{len(comparisons)}**. Distinct cold "
            f"EX5 hashes: **{len(hashes)}**. Native passes: **0**, because preflight refused "
            "the non-representable experiment. The CSV records every cold value/hash and "
            "its proposed native job, with native fields explicitly null—never fabricated.",
            "",
            "| Cold arm | Trades | PF | Net | Max DD | Native comparison |",
            "|---|---:|---:|---:|---:|---|",
        ]
    )
    for row in comparisons:
        lines.append(
            f"| {row['direction']} {int(row['predicate_id']):03d} | "
            f"{row['cold_total_trades']} | {row['cold_profit_factor']} | "
            f"{row['cold_net_profit']} | {row['cold_max_drawdown']} | NOT RUN |"
        )
    lines.extend(
        [
            "",
            "## Evidence-adapter design and hard gap",
            "",
            "A future reviewed prototype can hash-bind each XML row to: EX5/MQ5/include "
            "closure, ledger, exact tester INI, optimization setfile, custom-history manifest, "
            "agent allowlist, MT5 build, date/model/seed, direction, predicate ID, and the "
            "canonical cell key. The adapter can map aggregate XML columns such as trades, "
            "profit, profit factor, drawdown, Sharpe and the optimized input into an "
            "append-only candidate receipt.",
            "",
            "That is not yet a DL-089 cell receipt. The standard optimization report does "
            "not supply a per-pass closed-trade list, entry trading days, the cold HTML "
            "report bytes, the authenticated logger sample, or the real-tick marker. "
            "`entry_trading_days` is load-bearing for the sealed frequency floor. Cache/XML "
            "aggregates therefore cannot replace cold receipts field-for-field.",
            "",
            "Closing the gap requires either (a) EA-side frame instrumentation, which changes "
            "the binary and demands fresh parity evidence, or (b) individual cold replay of "
            "each selected pass, which forfeits most of the claimed 154-cell speedup. A Phase-2 "
            "proposal should first choose that governance tradeoff, then wait for at least 20 "
            "authenticated cold references before any parity claim.",
            "",
            "## Effort estimate for a revised Phase 2",
            "",
            "- 0.5–1 day: reviewed disposable-profile launcher, unique agent ports, sealed "
            "agent allowlist, cache hygiene and exact-PID/job containment.",
            "- 1–2 days: eight-job XML/cache adapter and append-only candidate receipts.",
            "- 1–2 days: authenticated entry-day/trade-list channel plus tests.",
            "- 1 day after reference availability: ≥20-cell field/trade parity and repeated "
            "complete-run determinism check.",
            "",
            "## Authoritative MT5 contract used",
            "",
            "- [MetaTrader 5 platform-start configuration](https://www.metatrader5.com/en/terminal/help/start_advanced/start) "
            "defines `Optimization=1` as slow complete search, `Model=4` as real ticks, XML "
            "optimization reports, and the local/remote/cloud switches.",
            "- [MetaTester and remote agents](https://www.metatrader5.com/en/terminal/help/algotrading/metatester) "
            "documents agent isolation and the absence of EA Print/trade-operation journal "
            "messages on remote agents.",
            "- [MQL5 optimization-report analysis](https://www.mql5.com/en/articles/5436) "
            "documents the aggregate XML pass fields and optimized-parameter columns.",
            "",
            "## Safety proof",
            "",
            f"- `launch_performed=false`; refusal: `{protocol['launch_refusal']}`.",
            "- Database connection: URI `mode=ro` + `PRAGMA query_only=ON`.",
            "- No terminal process was started; no worker, queue, verdict, policy file, "
            "T_Live, or AutoTrading state was changed.",
            "- Generated setfiles preserve `RISK_FIXED > 0`, `RISK_PERCENT = 0`, and never "
            "raise `qm_news_stale_max_hours` above 336.",
            "",
        ]
    )
    return "\n".join(lines)


def _atomic_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temp.write_text(value, encoding="utf-8", newline="\n")
    os.replace(temp, path)


def write_outputs(
    *,
    protocol: Mapping[str, Any],
    comparisons: Sequence[Mapping[str, Any]],
    output_dir: Path,
    output_stem: str,
) -> dict[str, Path]:
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    protocol_path = output_dir / f"{output_stem}_protocol.json"
    csv_path = output_dir / f"{output_stem}_comparison.csv"
    report_path = output_dir / f"{output_stem}.md"
    _atomic_text(protocol_path, json.dumps(protocol, indent=2, sort_keys=True) + "\n")
    fields = list(comparisons[0].keys()) if comparisons else [
        "cell_key", "native_pass_status", "field_exact_match", "trade_list_byte_match"
    ]
    temp = csv_path.with_name(f".{csv_path.name}.{os.getpid()}.tmp")
    with temp.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(comparisons)
    os.replace(temp, csv_path)
    _atomic_text(report_path, render_report(protocol, comparisons))
    return {"report": report_path, "protocol": protocol_path, "comparison": csv_path}


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--ea-dir", type=Path, default=DEFAULT_EA_DIR)
    parser.add_argument("--year", type=int, default=2019)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument(
        "--output-stem", default="3e129337_v4b_mt5_native_optimizer_feasibility_2026-08-27"
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    protocol = build_protocol(
        ledger_path=args.ledger,
        ea_dir=args.ea_dir,
        year=args.year,
    )
    with _read_only_connection(args.db) as con:
        con.execute("BEGIN")
        comparisons = cold_comparison_rows(con, protocol=protocol)
        con.rollback()
    outputs = write_outputs(
        protocol=protocol,
        comparisons=comparisons,
        output_dir=args.output_dir,
        output_stem=args.output_stem,
    )
    print(
        json.dumps(
            {
                "status": "NOT_REPRODUCIBLE_AS_SPECIFIED",
                "launch_performed": False,
                "cold_receipts": len(comparisons),
                "native_passes": 0,
                "exact_alternative_jobs": protocol[
                    "exact_binary_preserving_decomposition"
                ]["job_count"],
                "outputs": {key: str(path.resolve()) for key, path in outputs.items()},
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
