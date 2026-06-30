"""Analyze the Q04 survivor cohort without post-hoc winner selection.

This report answers a specific operating question:

    If Q04/Q05 forward survivors look good, would the cohort already be a bank?

The script treats the first Q04 pass-ish result for each EA+symbol as the admission
event, then evaluates:

* the Q04 OOS fold economics available at admission,
* the first post-Q04 gate result per later phase, and
* the attrition/failure taxonomy through Q09_PORTFOLIO.

It deliberately does not call the result a true live/daily forward portfolio unless
daily forward equity exists. Most Q04 artifacts contain annual OOS folds, not a
post-admission live stream.
"""
from __future__ import annotations

import argparse
import csv
import json
import sqlite3
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from statistics import mean, median
from typing import Any


FARM_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
OUT_DIR = Path(r"D:\QM\reports\analysis")

PHASE_ORDER = ["Q04", "Q05", "Q06", "Q07", "Q08", "Q09_PORTFOLIO"]
PASSISH = {"PASS", "PASS_SOFT", "PASS_LOWFREQ", "PASS_PORTFOLIO"}
Q04_PASSISH = {"PASS", "PASS_SOFT", "PASS_LOWFREQ"}


def _parse_ts(value: str | None) -> datetime:
    if not value:
        return datetime.min.replace(tzinfo=timezone.utc)
    text = value.replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(text)
    except ValueError:
        return datetime.min.replace(tzinfo=timezone.utc)
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _load_json(path: str | None) -> dict[str, Any]:
    if not path:
        return {}
    p = Path(path)
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8-sig", errors="ignore"))
    except Exception:
        return {}


def _to_float(value: Any) -> float | None:
    if value in (None, ""):
        return None
    try:
        if isinstance(value, str):
            value = value.replace(" ", "").replace(",", "")
        return float(value)
    except (TypeError, ValueError):
        return None


def _to_int(value: Any) -> int | None:
    number = _to_float(value)
    return int(round(number)) if number is not None else None


def _candidate_key(ea_id: str, symbol: str) -> str:
    return f"{ea_id}|{symbol.upper()}"


@dataclass(frozen=True)
class WorkItem:
    id: str
    ea_id: str
    symbol: str
    phase: str
    verdict: str
    updated_at: datetime
    evidence_path: str | None
    payload: dict[str, Any]

    @property
    def candidate(self) -> str:
        return _candidate_key(self.ea_id, self.symbol)


def load_work_items(db_path: Path) -> list[WorkItem]:
    con = sqlite3.connect(str(db_path))
    con.row_factory = sqlite3.Row
    rows = con.execute(
        """
        SELECT id, ea_id, symbol, phase, verdict, updated_at, evidence_path, payload_json
        FROM work_items
        WHERE status='done'
          AND phase IN ('Q04','Q05','Q06','Q07','Q08','Q09_PORTFOLIO')
        ORDER BY updated_at ASC
        """
    ).fetchall()
    out: list[WorkItem] = []
    for row in rows:
        try:
            payload = json.loads(row["payload_json"] or "{}")
        except Exception:
            payload = {}
        out.append(
            WorkItem(
                id=row["id"],
                ea_id=row["ea_id"],
                symbol=row["symbol"],
                phase=row["phase"],
                verdict=row["verdict"] or "",
                updated_at=_parse_ts(row["updated_at"]),
                evidence_path=row["evidence_path"],
                payload=payload,
            )
        )
    return out


def q04_fold_rows(item: WorkItem) -> list[dict[str, Any]]:
    data = _load_json(item.evidence_path)
    rows: list[dict[str, Any]] = []
    for fold in data.get("folds") or []:
        gross = _to_float(fold.get("gross_total"))
        commission = _to_float(fold.get("sim_commission_total"))
        net = (gross - commission) if gross is not None and commission is not None else None
        rows.append(
            {
                "candidate": item.candidate,
                "ea_id": item.ea_id,
                "symbol": item.symbol,
                "q04_verdict": item.verdict,
                "q04_passed_at_utc": item.updated_at.isoformat(),
                "fold_id": fold.get("id"),
                "oos_start": fold.get("oos_start"),
                "oos_end": fold.get("oos_end"),
                "oos_year": (str(fold.get("oos_start") or "")[:4] or None),
                "pf_net": _to_float(fold.get("pf_net")),
                "gross_total": gross,
                "sim_commission_total": commission,
                "net_after_commission": net,
                "trades": _to_int(fold.get("trades")),
            }
        )
    return rows


def phase_metrics(item: WorkItem) -> dict[str, Any]:
    data = _load_json(item.evidence_path)
    metrics: dict[str, Any] = {
        "phase": item.phase,
        "verdict": item.verdict,
        "reason": item.payload.get("verdict_reason") or data.get("reason"),
        "trades": None,
        "pf": None,
        "net_profit": None,
        "dd_pct": None,
    }
    if item.phase == "Q04":
        folds = q04_fold_rows(item)
        nets = [r["net_after_commission"] for r in folds if r["net_after_commission"] is not None]
        pfs = [r["pf_net"] for r in folds if r["pf_net"] is not None]
        trades = [r["trades"] for r in folds if r["trades"] is not None]
        metrics.update(
            {
                "trades": sum(trades) if trades else None,
                "pf": mean(pfs) if pfs else None,
                "net_profit": sum(nets) if nets else None,
            }
        )
        return metrics

    if item.phase in {"Q05", "Q06"}:
        metrics.update(
            {
                "trades": _to_int(data.get("trades")),
                "pf": _to_float(data.get("pf")),
                "dd_pct": _to_float(data.get("dd_pct")),
            }
        )
        summary = _load_json(data.get("summary_path"))
        runs = summary.get("runs") or []
        nets = [_to_float(r.get("net_profit")) for r in runs]
        nets = [n for n in nets if n is not None]
        if nets:
            metrics["net_profit"] = sum(nets)
        return metrics

    if item.phase == "Q07":
        m = data.get("metrics") or {}
        seeds = data.get("per_seed_detail") or []
        metrics.update(
            {
                "trades": max([_to_int(s.get("trades")) for s in seeds if _to_int(s.get("trades")) is not None], default=None),
                "pf": _to_float(m.get("mean_pf")),
                "dd_pct": max([_to_float(s.get("dd_pct")) for s in seeds if _to_float(s.get("dd_pct")) is not None], default=None),
            }
        )
        return metrics

    if item.phase == "Q08":
        gross = _to_float(data.get("gross_total"))
        commission = _to_float(data.get("commission_total"))
        metrics.update(
            {
                "trades": _to_int(data.get("n_trades")),
                "net_profit": (gross - commission) if gross is not None and commission is not None else gross,
                "pf": _to_float((data.get("baseline_run") or {}).get("baseline_profit_factor")),
                "reason": item.payload.get("verdict_reason") or data.get("cost_cushion_tier") or data.get("verdict"),
            }
        )
        return metrics

    if item.phase == "Q09_PORTFOLIO":
        equity_curve = data.get("equity_curve") or []
        net_profit = None
        if equity_curve and isinstance(equity_curve[-1], dict):
            net_profit = _to_float(equity_curve[-1].get("equity"))
        metrics.update(
            {
                "trades": _to_int(data.get("trade_count")),
                "pf": _to_float(data.get("standalone_pf")),
                "net_profit": net_profit,
                "dd_pct": _to_float(data.get("maxdd_with")),
                "reason": item.payload.get("verdict_reason") or data.get("reason"),
            }
        )
        return metrics

    return metrics


def first_q04_survivors(items: list[WorkItem], hard_only: bool = False) -> dict[str, WorkItem]:
    allowed = {"PASS"} if hard_only else Q04_PASSISH
    survivors: dict[str, WorkItem] = {}
    for item in items:
        if item.phase == "Q04" and item.verdict in allowed and item.candidate not in survivors:
            survivors[item.candidate] = item
    return survivors


def first_post_phase(items: list[WorkItem], survivor: WorkItem, phase: str) -> WorkItem | None:
    for item in items:
        if (
            item.candidate == survivor.candidate
            and item.phase == phase
            and item.updated_at >= survivor.updated_at
        ):
            return item
    return None


def summarize_numbers(values: list[float]) -> dict[str, float | int | None]:
    if not values:
        return {"n": 0, "sum": None, "mean": None, "median": None, "min": None, "max": None}
    return {
        "n": len(values),
        "sum": round(sum(values), 2),
        "mean": round(mean(values), 4),
        "median": round(median(values), 4),
        "min": round(min(values), 4),
        "max": round(max(values), 4),
    }


def analyze_subset(name: str, items: list[WorkItem], hard_only: bool = False) -> dict[str, Any]:
    survivors = first_q04_survivors(items, hard_only=hard_only)
    fold_rows: list[dict[str, Any]] = []
    candidate_summaries: list[dict[str, Any]] = []
    post_rows: list[dict[str, Any]] = []

    for survivor in survivors.values():
        folds = q04_fold_rows(survivor)
        fold_rows.extend(folds)
        nets = [r["net_after_commission"] for r in folds if r["net_after_commission"] is not None]
        pfs = [r["pf_net"] for r in folds if r["pf_net"] is not None]
        candidate_summaries.append(
            {
                "candidate": survivor.candidate,
                "ea_id": survivor.ea_id,
                "symbol": survivor.symbol,
                "q04_verdict": survivor.verdict,
                "q04_passed_at_utc": survivor.updated_at.isoformat(),
                "q04_total_net": round(sum(nets), 2) if nets else None,
                "q04_mean_pf": round(mean(pfs), 4) if pfs else None,
                "q04_min_pf": round(min(pfs), 4) if pfs else None,
                "q04_positive_folds": sum(1 for n in nets if n > 0),
                "q04_fold_count": len(nets),
            }
        )
        for phase in PHASE_ORDER[1:]:
            post = first_post_phase(items, survivor, phase)
            if post is None:
                post_rows.append(
                    {
                        "candidate": survivor.candidate,
                        "ea_id": survivor.ea_id,
                        "symbol": survivor.symbol,
                        "q04_verdict": survivor.verdict,
                        "phase": phase,
                        "verdict": "NO_DATA",
                        "reason": "no_post_q04_work_item",
                    }
                )
            else:
                metrics = phase_metrics(post)
                post_rows.append(
                    {
                        "candidate": survivor.candidate,
                        "ea_id": survivor.ea_id,
                        "symbol": survivor.symbol,
                        "q04_verdict": survivor.verdict,
                        "phase": phase,
                        "verdict": post.verdict,
                        "updated_at_utc": post.updated_at.isoformat(),
                        **metrics,
                    }
                )

    yearly: dict[str, dict[str, Any]] = {}
    for year, rows in group_by(fold_rows, "oos_year").items():
        nets = [r["net_after_commission"] for r in rows if r["net_after_commission"] is not None]
        pfs = [r["pf_net"] for r in rows if r["pf_net"] is not None]
        yearly[str(year)] = {
            "folds": len(rows),
            "candidates": len({r["candidate"] for r in rows}),
            "net_sum": round(sum(nets), 2) if nets else None,
            "equal_weight_net_per_candidate": round(sum(nets) / len({r["candidate"] for r in rows}), 2)
            if nets and {r["candidate"] for r in rows}
            else None,
            "positive_fold_rate": round(sum(1 for n in nets if n > 0) / len(nets), 4) if nets else None,
            "mean_pf": round(mean(pfs), 4) if pfs else None,
            "median_pf": round(median(pfs), 4) if pfs else None,
        }

    phase_summary: dict[str, Any] = {}
    for phase in PHASE_ORDER[1:]:
        rows = [r for r in post_rows if r["phase"] == phase]
        verdict_counts = Counter(r["verdict"] for r in rows)
        reason_counts = Counter((r.get("reason") or "unknown") for r in rows if r["verdict"] not in PASSISH)
        phase_summary[phase] = {
            "verdict_counts": dict(verdict_counts),
            "passish_count": sum(1 for r in rows if r["verdict"] in PASSISH),
            "tested_count": sum(1 for r in rows if r["verdict"] != "NO_DATA"),
            "top_failure_reasons": reason_counts.most_common(12),
            "net_profit": summarize_numbers([r["net_profit"] for r in rows if isinstance(r.get("net_profit"), (int, float))]),
            "pf": summarize_numbers([r["pf"] for r in rows if isinstance(r.get("pf"), (int, float))]),
            "trades": summarize_numbers([float(r["trades"]) for r in rows if isinstance(r.get("trades"), int)]),
        }

    sequential_funnel: list[dict[str, Any]] = []
    current = set(survivors)
    for phase in PHASE_ORDER[1:]:
        rows = [r for r in post_rows if r["phase"] == phase and r["candidate"] in current]
        verdict_counts = Counter(r["verdict"] for r in rows)
        if phase in {"Q05", "Q06", "Q07"}:
            keep_verdicts = PASSISH
        elif phase == "Q08":
            # Current operating path: Q08 has no observed hard PASS rows in this
            # sample; FAIL_SOFT can still enter Q09_PORTFOLIO as a rescue/admission
            # candidate. Keep it separate from standalone pass language.
            keep_verdicts = PASSISH | {"FAIL_SOFT"}
        else:
            keep_verdicts = {"PASS", "PASS_PORTFOLIO"}
        next_current = {r["candidate"] for r in rows if r["verdict"] in keep_verdicts}
        sequential_funnel.append(
            {
                "phase": phase,
                "input_candidates": len(current),
                "verdict_counts": dict(verdict_counts),
                "kept_for_next_phase": len(next_current),
                "keep_rule": "PASS-ish" if phase in {"Q05", "Q06", "Q07"} else (
                    "PASS-ish or Q08 FAIL_SOFT" if phase == "Q08" else "PASS/PASS_PORTFOLIO"
                ),
            }
        )
        current = next_current

    q04_nets = [c["q04_total_net"] for c in candidate_summaries if isinstance(c["q04_total_net"], (int, float))]
    q04_pfs = [c["q04_mean_pf"] for c in candidate_summaries if isinstance(c["q04_mean_pf"], (int, float))]
    return {
        "name": name,
        "hard_only": hard_only,
        "survivor_count": len(survivors),
        "unique_eas": len({s.ea_id for s in survivors.values()}),
        "unique_symbols": len({s.symbol for s in survivors.values()}),
        "q04_candidate_net": summarize_numbers(q04_nets),
        "q04_candidate_mean_pf": summarize_numbers(q04_pfs),
        "q04_yearly_equal_weight": yearly,
        "phase_summary": phase_summary,
        "sequential_funnel": sequential_funnel,
        "candidate_summaries": candidate_summaries,
        "fold_rows": fold_rows,
        "post_rows": post_rows,
    }


def group_by(rows: list[dict[str, Any]], key: str) -> dict[Any, list[dict[str, Any]]]:
    out: dict[Any, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        out[row.get(key)].append(row)
    return dict(out)


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fields: list[str] = []
    for row in rows:
        for key in row:
            if key not in fields:
                fields.append(key)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def render_markdown(result: dict[str, Any], out_base: Path) -> str:
    all_subset = result["subsets"]["q04_passish"]
    hard_subset = result["subsets"]["q04_hard_pass"]
    lines = [
        "# Q04 Survivor Cohort Test",
        "",
        f"Generated UTC: `{result['generated_at_utc']}`",
        f"DB: `{result['db_path']}`",
        "",
        "## Test contract",
        "",
        "- Admission event: first Q04 pass-ish work item per EA+symbol candidate.",
        "- Pass-ish at Q04: PASS, PASS_SOFT, PASS_LOWFREQ. Hard subset: PASS only.",
        "- No post-hoc winner selection: later Q05-Q09 outcomes are evaluated for every admitted candidate where evidence exists.",
        "- Q04 economics use the OOS folds stored in Q04 aggregate.json. This is not a live-after-admission daily portfolio.",
        "",
        "## Headline",
        "",
        f"- Q04 pass-ish candidates: **{all_subset['survivor_count']}** "
        f"({all_subset['unique_eas']} EAs, {all_subset['unique_symbols']} symbols).",
        f"- Q04 hard-PASS candidates: **{hard_subset['survivor_count']}** "
        f"({hard_subset['unique_eas']} EAs, {hard_subset['unique_symbols']} symbols).",
        f"- Q04 pass-ish fold net sum: **{fmt_money(all_subset['q04_candidate_net']['sum'])}**; "
        f"median candidate net: **{fmt_money(all_subset['q04_candidate_net']['median'])}**; "
        f"median mean PF: **{fmt_num(all_subset['q04_candidate_mean_pf']['median'])}**.",
        f"- Q04 hard-PASS fold net sum: **{fmt_money(hard_subset['q04_candidate_net']['sum'])}**; "
        f"median candidate net: **{fmt_money(hard_subset['q04_candidate_net']['median'])}**; "
        f"median mean PF: **{fmt_num(hard_subset['q04_candidate_mean_pf']['median'])}**.",
        "",
        "## Q04 OOS Equal-Unit Cohort",
        "",
        "| Subset | Year | Candidates | Net sum | Equal-unit net/candidate | Positive fold rate | Median PF |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for subset in (all_subset, hard_subset):
        for year in sorted(subset["q04_yearly_equal_weight"]):
            y = subset["q04_yearly_equal_weight"][year]
            lines.append(
                f"| {subset['name']} | {year} | {y['candidates']} | {fmt_money(y['net_sum'])} | "
                f"{fmt_money(y['equal_weight_net_per_candidate'])} | {fmt_pct(y['positive_fold_rate'])} | {fmt_num(y['median_pf'])} median |"
            )
    lines.extend(
        [
            "",
            "PF note: Q04 contains zero-loss / tiny-loss fold outliers, so the table reports median PF in the PF column.",
            "",
            "## Sequential Funnel",
            "",
            "| Subset | Phase | Input candidates | Kept for next phase | Keep rule | Verdict counts |",
            "|---|---:|---:|---:|---|---|",
        ]
    )
    for subset in (all_subset, hard_subset):
        for row in subset["sequential_funnel"]:
            lines.append(
                f"| {subset['name']} | {row['phase']} | {row['input_candidates']} | "
                f"{row['kept_for_next_phase']} | {row['keep_rule']} | "
                f"{json.dumps(row['verdict_counts'], sort_keys=True)} |"
            )
    lines.extend(
        [
            "",
            "## Post-Q04 Attrition",
            "",
            "| Subset | Phase | Tested | Pass-ish | Verdict counts | Main failure reasons |",
            "|---|---:|---:|---:|---|---|",
        ]
    )
    for subset in (all_subset, hard_subset):
        for phase in PHASE_ORDER[1:]:
            s = subset["phase_summary"][phase]
            reasons = "; ".join(f"{reason} ({count})" for reason, count in s["top_failure_reasons"][:5])
            lines.append(
                f"| {subset['name']} | {phase} | {s['tested_count']} | {s['passish_count']} | "
                f"{json.dumps(s['verdict_counts'], sort_keys=True)} | {reasons} |"
            )
    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            "The Q04 survivor pool is economically positive on the same Q04 OOS folds that admitted it, "
            "but that is not enough to call it deployable. It is selection evidence, not a clean live-forward portfolio.",
            "",
            "The clean post-Q04 check is attrition: every admitted candidate is followed into the later gates without "
            "dropping losers. If the Q04 pool were already a bank, pass-ish counts and economics would remain strong "
            "through Q05/Q06/Q07/Q08/Q09. The observed funnel should therefore be read as the answer to the original "
            "question, not as a pipeline nuisance.",
            "",
            "## Artifacts",
            "",
            f"- JSON: `{out_base.with_suffix('.json')}`",
            f"- Candidate CSV: `{out_base.with_name(out_base.name + '_candidates.csv')}`",
            f"- Fold CSV: `{out_base.with_name(out_base.name + '_q04_folds.csv')}`",
            f"- Post-Q04 CSV: `{out_base.with_name(out_base.name + '_post_q04.csv')}`",
            "",
        ]
    )
    return "\n".join(lines)


def fmt_money(value: Any) -> str:
    if value is None:
        return "n/a"
    return f"${float(value):,.2f}"


def fmt_num(value: Any) -> str:
    if value is None:
        return "n/a"
    return f"{float(value):.3f}"


def fmt_pct(value: Any) -> str:
    if value is None:
        return "n/a"
    return f"{float(value) * 100:.1f}%"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=FARM_DB)
    parser.add_argument("--out-dir", type=Path, default=OUT_DIR)
    args = parser.parse_args()

    items = load_work_items(args.db)
    generated = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    args.out_dir.mkdir(parents=True, exist_ok=True)
    out_base = args.out_dir / f"q04_survivor_cohort_{generated}"

    passish = analyze_subset("q04_passish", items, hard_only=False)
    hard = analyze_subset("q04_hard_pass", items, hard_only=True)
    result = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "db_path": str(args.db),
        "subsets": {
            "q04_passish": {k: v for k, v in passish.items() if k not in {"candidate_summaries", "fold_rows", "post_rows"}},
            "q04_hard_pass": {k: v for k, v in hard.items() if k not in {"candidate_summaries", "fold_rows", "post_rows"}},
        },
    }

    out_base.with_suffix(".json").write_text(json.dumps(result, indent=2, sort_keys=True), encoding="utf-8")
    write_csv(out_base.with_name(out_base.name + "_candidates.csv"), passish["candidate_summaries"])
    write_csv(out_base.with_name(out_base.name + "_q04_folds.csv"), passish["fold_rows"])
    write_csv(out_base.with_name(out_base.name + "_post_q04.csv"), passish["post_rows"])
    out_base.with_suffix(".md").write_text(render_markdown(result, out_base), encoding="utf-8")

    print(out_base.with_suffix(".md"))
    print(out_base.with_suffix(".json"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
