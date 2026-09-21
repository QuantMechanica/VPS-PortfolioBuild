"""Deterministic baseline extraction for the H-V1/H-V2/H-V3 velocity hypotheses
(task 31012467-dde7-4b74-995c-def2241b28c0, QM-RESEARCH-2026-0009/0010/0011).

Reads the frozen 2026-09-20 velocity evidence (README + q02_velocity_screen.json)
from the canonical checkout and emits one small, deterministic, re-runnable JSON
per hypothesis containing only the specific baseline figures each source.md cites
as `computed_outputs`. No number here is invented: every field is either copied
verbatim from an existing evidence file (with that file's own sha256 recorded for
cross-check) or a straightforward arithmetic aggregate (min/max/mean/count) over
rows already present in q02_velocity_screen.json. Run with no arguments; writes
into each hypothesis's own strategy-seeds/sources/<id>/ directory so the
research_source.py manifest can hash it as a same-directory computed output.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

CANONICAL_REPO = Path(r"C:\QM\repo")
WORKTREE_ROOT = Path(__file__).resolve().parents[3]
STORE_ROOT = WORKTREE_ROOT / "strategy-seeds" / "sources"

Q02_SCREEN = CANONICAL_REPO / "docs/ops/evidence/2026-09-20_velocity_book/q02_velocity_screen.json"
README = CANONICAL_REPO / "docs/ops/evidence/2026-09-20_velocity_book/README.md"
FTMO_GAP = CANONICAL_REPO / "docs/ftmo/FTMO_PORTFOLIO_GAP_CURRENT.md"


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_screen() -> list[dict]:
    return json.loads(Q02_SCREEN.read_text(encoding="utf-8"))


def rows_for(screen: list[dict], prefixes: tuple[str, ...], tfs: tuple[str, ...] | None = None) -> list[dict]:
    out = []
    for r in screen:
        if any(r["sym"].startswith(p) for p in prefixes) and (tfs is None or r["tf"] in tfs):
            out.append(r)
    return out


def summarize(rows: list[dict]) -> dict:
    if not rows:
        return {"n_configs": 0}
    r_bd = [r["R_bd"] for r in rows]
    dens = [r["dens"] for r in rows]
    return {
        "n_configs": len(rows),
        "R_bd_min": min(r_bd),
        "R_bd_max": max(r_bd),
        "dens_min": min(dens),
        "dens_max": max(dens),
        "bd_window": sorted({r["bd"] for r in rows}),
    }


def main() -> None:
    screen = load_screen()
    source_hashes = {
        "q02_velocity_screen.json": sha256_file(Q02_SCREEN),
        "README.md": sha256_file(README),
        "FTMO_PORTFOLIO_GAP_CURRENT.md": sha256_file(FTMO_GAP),
    }

    # H-V1 — London-open EURUSD/GBPUSD baseline (existing non-session-anchored configs)
    london_rows = rows_for(screen, ("EURUSD", "GBPUSD"))
    hv1 = {
        "schema": "qm.velocity-baseline-extract/v1",
        "hypothesis": "H-V1",
        "upstream_sources": source_hashes,
        "measured_baseline_configs_EURUSD_GBPUSD_non_session_anchored": [
            {k: r[k] for k in ("ea", "sym", "tf", "n", "dens", "eR", "R_bd", "pf", "bd")}
            for r in sorted(london_rows, key=lambda r: -r["R_bd"])[:8]
        ],
        "summary": summarize(london_rows),
        "note": (
            "None of these measured configurations gates entry to the 07:00-08:00 UTC "
            "London-open range; they are the closest existing intraday evidence on the "
            "same two symbols and establish that no measured non-session-anchored "
            "EURUSD/GBPUSD H1/M15 configuration exceeds R_bd shown above (max "
            f"{summarize(london_rows).get('R_bd_max')})."
        ),
        "balke_13213_template_reference": {
            "source": "README.md table row 13213 USDJPY H1",
            "trades_per_bd": 0.74,
            "eR": 0.064,
            "R_bd": 0.048,
            "hold_h": 7.2,
            "overnight_pct": 0,
            "note": "cited only as the fastest measured session-flat profile in the inventory; not transplanted onto EURUSD/GBPUSD (that transplant already failed for non-JPY majors per the 41484 fan-out, see README.md section 2c).",
        },
    }

    # H-V2 — XAUUSD baseline (existing always-on H1 gold configs, incl. the two Q05 DD failures)
    xau_rows = rows_for(screen, ("XAUUSD",))
    xau_named = {r["ea"]: r for r in xau_rows}
    hv2 = {
        "schema": "qm.velocity-baseline-extract/v1",
        "hypothesis": "H-V2",
        "upstream_sources": source_hashes,
        "measured_baseline_configs_XAUUSD_always_on": [
            {k: r[k] for k in ("ea", "sym", "tf", "n", "dens", "eR", "R_bd", "pf", "bd")}
            for r in sorted(xau_rows, key=lambda r: -r["R_bd"])[:8]
        ],
        "summary": summarize(xau_rows),
        "q05_dd_failures_readme_table": {
            "QM5_10423": {"trades_per_bd": 0.82, "eR": 0.086, "note": "Q05 FAIL dd 41% at 1%/trade (README.md table row)"},
            "QM5_11690": {"trades_per_bd": 1.84, "eR": 0.028, "note": "Q05 FAIL dd 59% (README.md table row)"},
        },
        "demo_roster_10700_reference": {
            "source": "FTMO_PORTFOLIO_GAP_CURRENT.md table 1a",
            "trades_per_bd": 0.18,
            "eR": 0.165,
            "hold_h": 19.7,
            "overnight_pct": 58,
        },
    }

    # H-V3 — JPY crosses baseline (existing breakout/momentum configs, all measured negative)
    jpy_rows = rows_for(screen, ("AUDJPY", "GBPJPY", "EURJPY", "CHFJPY", "NZDJPY"))
    hv3 = {
        "schema": "qm.velocity-baseline-extract/v1",
        "hypothesis": "H-V3",
        "upstream_sources": source_hashes,
        "measured_baseline_configs_JPY_crosses_breakout_style": [
            {k: r[k] for k in ("ea", "sym", "tf", "n", "dens", "eR", "R_bd", "pf", "bd")}
            for r in sorted(jpy_rows, key=lambda r: -r["R_bd"])
        ],
        "summary": summarize(jpy_rows),
        "note": (
            "All measured breakout/momentum-continuation configurations on AUDJPY/GBPJPY/"
            "EURJPY/CHFJPY in the frozen Q02 screen are net-negative R_bd; this is the "
            "evidence base for excluding another breakout-family trigger and requiring a "
            "mean-reversion / fade trigger instead (task acceptance criterion)."
        ),
        "balke_41484_fanout_reference": {
            "source": "README.md section 2c / finds log 20:23Z-21:23Z entries",
            "AUDJPY_R": 0.005,
            "GBPJPY_R": -0.001,
            "USDJPY_control_R_bd": 0.053,
            "note": "the Balke GMT+3 03-06 window + range-breakout-with-stop-bracket trigger, transplanted verbatim onto AUDJPY/GBPJPY, measured flat/flat; lineage QM5_41484 RETIRED 2026-09-20.",
        },
    }

    for hyp_id, payload in (
        ("QM-RESEARCH-2026-0009", hv1),
        ("QM-RESEARCH-2026-0010", hv2),
        ("QM-RESEARCH-2026-0011", hv3),
    ):
        out_dir = STORE_ROOT / hyp_id
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / "baseline_extract.json"
        out_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(out_path, sha256_file(out_path))


if __name__ == "__main__":
    main()
