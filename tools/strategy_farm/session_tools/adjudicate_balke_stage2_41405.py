"""Tool-adjudication of the QM5_41405 stage-2 matrix (card D:/QM/strategy_farm/artifacts/cards_approved/
QM5_41405_balke-clock-audit-opt.md, pre-registered 2026-09-11; program WINSWEEP_QM5_41405_USDJPY_DWX_2019_2025).

Scoring, DEV/OOS split, admissibility and plateau logic exactly as the stage-A plan sections 4-5
(docs/research/BALKE_WINDOW_SWEEP_PLAN_2026-09-09.md), measured through window_sweep.measure (costed out-deal
P&L, strict net reconciliation, ledger authentication). Plateau neighbourhood for stage 2 (card): adjacent
buffer and band values within the same clock/outside cell (the two Balke configs form their own pair).
Refutation criteria (card, fixed before any cell ran): H-CLOCK, H-OUTSIDE, H-BUFFER, H-BAND, H-BALKE at 1.10x.
Outputs: docs/research/balke_stage2_41405/{surface_20260912.csv, result_20260912.json} and
docs/research/BALKE_STAGE2_RESULT_2026-09-12.md. Read-only against the factory DB.
"""
from __future__ import annotations

import csv
import json
import sqlite3
import statistics
import sys
from pathlib import Path

REPO = Path("C:/QM/repo")
sys.path.insert(0, str(REPO))
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
import config_sweep  # noqa: E402
import window_sweep  # noqa: E402

ART = Path("D:/QM/strategy_farm/artifacts/opt_census/WINSWEEP_QM5_41405_USDJPY_DWX_2019_2025")
DB = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
OUT = REPO / "docs" / "research" / "balke_stage2_41405"
DEV, OOS = (2019, 2020, 2021, 2022), (2023, 2024, 2025)
CLOCK = {0: "GMT3_FIXED", 1: "BROKER_DST", 2: "CET_LOCAL"}
OUTSIDE = {0: "AS_IS", 1: "SKIP_DAY", 2: "MARKET_ENTRY_BREAKOUT_DIR", 3: "OPPOSITE_STOP_ONLY"}
MARGIN = 1.10


def load_matrix(decl):
    rows = list(csv.DictReader(open(decl["matrix_csv_path"], encoding="utf-8")))
    configs = {}
    for r in rows:
        cid = int(r["config_id"])
        configs.setdefault(cid, {k: r[k] for k in r if k != "year"})
    return configs


def main() -> int:
    plan = config_sweep.plan(ART / "declaration.json", ART)
    decl = plan["declaration"]
    configs = load_matrix(decl)
    conn = sqlite3.connect(DB, uri=True, timeout=10)
    conn.row_factory = sqlite3.Row
    per_config: dict[int, dict] = {}
    surface = []
    errors = []
    for cell in plan["cells"]:
        cid = int(cell["config"]) if str(cell.get("config", "")).isdigit() else int(str(cell["arm"]).lstrip("c"))
        row = conn.execute("SELECT status,verdict,evidence_path,payload_json FROM work_items WHERE id=?", (cell["work_item_id"],)).fetchone()
        entry = {"cell_key": cell["cell_key"], "config": cid, "year": cell["year"], "status": row["status"] if row else "NOT_ENQUEUED", "verdict": row["verdict"] if row else ""}
        if row and row["status"] == "done" and row["verdict"] == "MEASURED":
            try:
                payload = json.loads(row["payload_json"])
                config_sweep.authenticate_ledger(payload)
                m = window_sweep.measure(row["evidence_path"], payload)
                per_config.setdefault(cid, {})[int(cell["year"])] = m
                entry.update({k: v for k, v in m.items() if k != "costed_trade_pnl"})
            except Exception as exc:  # noqa: BLE001 - surfaced per cell
                entry["error"] = f"{type(exc).__name__}: {exc}"
                errors.append(entry["cell_key"])
        else:
            errors.append(entry["cell_key"])
        surface.append(entry)
    conn.close()
    OUT.mkdir(parents=True, exist_ok=True)
    with open(OUT / "surface_20260912.csv", "w", encoding="utf-8", newline="") as fh:
        keys = sorted({k for e in surface for k in e}, key=lambda k: (k not in ("cell_key", "config", "year", "status", "verdict"), k))
        w = csv.DictWriter(fh, fieldnames=keys)
        w.writeheader()
        w.writerows(surface)
    if errors:
        result = {"complete": False, "errors": errors[:50], "error_count": len(errors)}
        (OUT / "result_20260912.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
        print(json.dumps(result)[:800])
        return 2

    # --- per-config statistics (plan sections 4-5) ---
    stats = {}
    for cid, years in per_config.items():
        c = configs[cid]
        vals = [years[y] for y in DEV + OOS]
        admissible = all(v["entry_days"] >= 10 and v["trades"] >= 5 for v in vals) and statistics.mean(v["trades"] for v in vals) >= 40
        dev = statistics.median(years[y]["score"] for y in DEV)
        oos_scores = [years[y]["score"] for y in OOS]
        pnls = [n for y in OOS for n in years[y]["costed_trade_pnl"]]
        profit = sum(n for n in pnls if n > 0)
        loss = -sum(n for n in pnls if n < 0)
        stats[cid] = {
            "config": cid,
            "clock": CLOCK.get(int(c["clock_mode"]), c["clock_mode"]),
            "outside": OUTSIDE.get(int(c["outside_rule"]), c["outside_rule"]),
            "buffer": int(c["buffer_points"]),
            "band": str(c["range_band_enabled"]).lower() == "true",
            "balke": int(c["range_end_minute"]) == 30,
            "admissible": admissible,
            "dev_score": dev,
            "oos_median": statistics.median(oos_scores),
            "oos_pooled_pf": (profit / loss) if loss else None,
            "costed_net_7y": sum(years[y]["net_costed_plan"] for y in DEV + OOS),
            "trades_7y": sum(years[y]["trades"] for y in DEV + OOS),
            "years": {y: {k: years[y][k] for k in ("trades", "entry_days", "net_native", "net_costed_plan", "score", "profit_factor") if k in years[y]} for y in DEV + OOS},
        }
    # plateau: neighbourhood = same clock/outside, buffer {0,20} x band {on,off}; Balke pair = {48,49}
    for cid, s in stats.items():
        if s["balke"]:
            neigh = [t for t in stats.values() if t["balke"]]
        else:
            neigh = [t for t in stats.values() if not t["balke"] and t["clock"] == s["clock"] and t["outside"] == s["outside"]]
        s["plateau_score"] = statistics.median(t["dev_score"] for t in neigh)
        s["neighbourhood"] = sorted(t["config"] for t in neigh)

    def best(pred):
        cands = [s for s in stats.values() if s["admissible"] and pred(s)]
        return max(cands, key=lambda s: s["plateau_score"]) if cands else None

    def hyp(name, challenger, incumbent, keep_text):
        ok = challenger is not None and incumbent is not None and challenger["plateau_score"] >= MARGIN * incumbent["plateau_score"]
        return {"hypothesis": name, "challenger": None if challenger is None else {k: challenger[k] for k in ("config", "clock", "outside", "buffer", "band", "plateau_score", "dev_score")},
                "incumbent": None if incumbent is None else {k: incumbent[k] for k in ("config", "clock", "outside", "buffer", "band", "plateau_score", "dev_score")},
                "margin": MARGIN, "survives": bool(ok), "verdict": (name + " SURVIVES (challenger >= 1.10x)") if ok else (name + " REFUTED -> " + keep_text)}

    fixed = lambda s: s["clock"] == "GMT3_FIXED" and not s["balke"]  # noqa: E731
    hyps = [
        hyp("H-CLOCK", best(lambda s: s["clock"] != "GMT3_FIXED" and not s["balke"]), best(fixed), "keep GMT3_FIXED"),
        hyp("H-OUTSIDE", best(lambda s: s["outside"] != "AS_IS" and not s["balke"]), best(lambda s: s["outside"] == "AS_IS" and not s["balke"]), "keep AS_IS"),
        hyp("H-BUFFER", best(lambda s: s["buffer"] == 20 and not s["balke"]), best(lambda s: s["buffer"] == 0 and not s["balke"]), "keep buffer 0"),
        hyp("H-BAND", best(lambda s: not s["band"] and not s["balke"]), best(lambda s: s["band"] and not s["balke"]), "keep band on"),
        hyp("H-BALKE", best(lambda s: s["balke"]), best(fixed), "keep our configuration"),
    ]
    control = stats.get(0)
    ranked = sorted((s for s in stats.values() if s["admissible"]), key=lambda s: (-s["plateau_score"], s["config"]))
    winner = ranked[0] if ranked else None
    oos_confirm = None
    if winner and control:
        oos_confirm = winner["oos_median"] >= control["oos_median"] and ((winner["oos_pooled_pf"] or 0) >= 1.0)
    result = {
        "complete": True, "program_id": decl["program_id"], "cells": len(surface), "configs": len(stats),
        "control_config_0": None if not control else {k: control[k] for k in ("dev_score", "plateau_score", "oos_median", "oos_pooled_pf", "costed_net_7y", "trades_7y", "admissible")},
        "hypotheses": hyps,
        "top_ten": [{k: s[k] for k in ("config", "clock", "outside", "buffer", "band", "balke", "plateau_score", "dev_score", "oos_median", "oos_pooled_pf", "costed_net_7y", "trades_7y")} for s in ranked[:10]],
        "top_plateau_config": None if not winner else winner["config"],
        "top_config_oos_confirmation_vs_control": oos_confirm,
        "inadmissible_configs": sorted(s["config"] for s in stats.values() if not s["admissible"]),
        "configs_detail": {str(k): v for k, v in sorted(stats.items())},
    }
    (OUT / "result_20260912.json").write_text(json.dumps(result, indent=2, default=str), encoding="utf-8")
    md = ["# Balke stage-2 matrix result (QM5_41405, 2026-09-12, tool-adjudicated)", "",
          f"Program `{decl['program_id']}`, {len(surface)} cells MEASURED (real ticks, Model 4, 2019-2025), {len(stats)} configurations.",
          "Rules: card QM5_41405 (pre-registered 2026-09-11) + stage-A plan sections 4-5; script `tools/strategy_farm/session_tools/adjudicate_balke_stage2_41405.py`;",
          "surface `docs/research/balke_stage2_41405/surface_20260912.csv`, JSON `result_20260912.json`.", "",
          "## Hypotheses (1.10x plateau margin, fixed before any cell ran)", "", "| Hypothesis | Challenger (best plateau) | Incumbent (best plateau) | Verdict |", "|---|---|---|---|"]
    for h in hyps:
        ch, inc = h["challenger"], h["incumbent"]
        f = lambda s: "n/a" if s is None else f"c{s['config']:02d} {s['clock']}/{s['outside']}/buf{s['buffer']}/band{'on' if s['band'] else 'off'}: {s['plateau_score']:.2f}"  # noqa: E731
        md.append(f"| {h['hypothesis']} | {f(ch)} | {f(inc)} | **{h['verdict']}** |")
    md += ["", "## Control and top configurations (plateau order)", "",
           "Score = costed net / max-DD per year (costed = native net - 5 USD per lot RT); DEV median 2019-2022; OOS median 2023-2025.", "",
           "| cfg | clock | outside | buffer | band | Balke | plateau | DEV | OOS median | OOS pooled PF | costed net 7y | trades |", "|---|---|---|---|---|---|---|---|---|---|---|---|"]
    rows_md = ([control] if control else []) + [s for s in ranked[:10] if s is not control]
    for s in rows_md:
        pf = "n/a" if s["oos_pooled_pf"] is None else f"{s['oos_pooled_pf']:.2f}"
        md.append(f"| c{s['config']:02d} | {s['clock']} | {s['outside']} | {s['buffer']} | {'on' if s['band'] else 'off'} | {'yes' if s['balke'] else ''} | {s['plateau_score']:.2f} | {s['dev_score']:.2f} | {s['oos_median']:.2f} | {pf} | {s['costed_net_7y']:,.0f} | {s['trades_7y']} |")
    md += ["", f"Inadmissible configurations: {result['inadmissible_configs'] or 'none'}.",
           f"Top plateau configuration: c{winner['config']:02d}; OOS confirmation versus control c00: {oos_confirm}." if winner else "No admissible configuration.",
           "", "## Not claimed", "", "No live authorisation, no verdict/counter change. Fade-only-day economics and the winter/summer split are reported separately (Astra stage-2 ticket); this document adjudicates the five pre-registered hypotheses only."]
    (REPO / "docs" / "research" / "BALKE_STAGE2_RESULT_2026-09-12.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    print(json.dumps({"complete": True, "hypotheses": [(h["hypothesis"], h["verdict"]) for h in hyps], "top": result["top_ten"][:3], "control": result["control_config_0"]}, default=str)[:3000])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
