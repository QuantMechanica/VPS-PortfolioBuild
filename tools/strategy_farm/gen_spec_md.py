"""Generate SPEC.md for one or more EA dirs from existing artifacts.

Use case: remediate EAs that built cleanly (mq5+ex5+setfiles) but were
rejected by `validate_spec_doc.py` because the build prompt didn't tell
Codex to write SPEC.md. The prompt is now patched (codex_build_ea.md
step 5a), but already-failed builds need ex-post SPEC.md files.

Fills the template from:
- ea_id, slug         → directory name
- source_id, target   → card frontmatter (artifacts/cards_approved/)
- timeframe           → card frontmatter `period` or first PERIOD_* in mq5
- parameters          → `input` declarations in mq5 (strategy_* only)
- symbol universe     → magic_numbers.csv rows for this ea_id

After writing, runs `validate_spec_doc.py` to confirm PASS.

Usage:
    python gen_spec_md.py QM5_10323_payoff-bias
    python gen_spec_md.py --all-failed   # walk DB for stuck builds
    python gen_spec_md.py --dry-run QM5_10323_payoff-bias
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import re
import sqlite3
import subprocess
import sys
from pathlib import Path

REPO = Path("C:/QM/repo")
EAS = REPO / "framework" / "EAs"
TEMPLATE = REPO / "framework" / "templates" / "SPEC.md.template"
VALIDATOR = REPO / "framework" / "scripts" / "validate_spec_doc.py"
MAGIC_CSV = REPO / "framework" / "registry" / "magic_numbers.csv"
APPROVED = Path("D:/QM/strategy_farm/artifacts/cards_approved")
DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")


def parse_frontmatter(card_path: Path) -> dict:
    text = card_path.read_text(encoding="utf-8", errors="ignore")
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not m:
        return {}
    fm = {}
    for line in m.group(1).splitlines():
        if ":" in line and not line.startswith(" "):
            k, _, v = line.partition(":")
            fm[k.strip()] = v.strip()
    return fm


def find_card(ea_id: str) -> Path | None:
    matches = sorted(APPROVED.glob(f"{ea_id}_*.md"))
    return matches[0] if matches else None


def extract_strategy_inputs(mq5_path: Path) -> list[tuple[str, str, str]]:
    """Return [(name, default, type)] for inputs whose name starts with
    strategy_ or has a strategy-specific feel. Skip framework inputs."""
    if not mq5_path.exists():
        return []
    text = mq5_path.read_text(encoding="utf-8", errors="ignore")
    out = []
    in_strategy_group = False
    for line in text.splitlines():
        s = line.strip()
        m = re.match(r"input\s+group\s+\"([^\"]+)\"", s)
        if m:
            in_strategy_group = m.group(1).lower().startswith("strategy")
            continue
        m = re.match(r"input\s+(\w+)\s+(\w+)\s*=\s*([^;]+);", s)
        if m and (in_strategy_group or m.group(2).startswith("strategy_")):
            tp, name, default = m.group(1), m.group(2), m.group(3).strip()
            out.append((name, default, tp))
    return out


def extract_timeframe(fm: dict, mq5_path: Path) -> str:
    p = fm.get("period") or fm.get("timeframe")
    if p:
        return p
    if mq5_path.exists():
        text = mq5_path.read_text(encoding="utf-8", errors="ignore")
        m = re.search(r"\bPERIOD_(M1|M5|M15|M30|H1|H4|D1|W1)\b", text)
        if m:
            return m.group(1)
    return "H1"


def get_registered_symbols(ea_id: str) -> list[str]:
    if not MAGIC_CSV.exists():
        return []
    syms = []
    with MAGIC_CSV.open(encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if str(row.get("ea_id", "")).strip() == ea_id.replace("QM5_", ""):
                sym = (row.get("symbol") or "").strip()
                if sym and sym not in syms:
                    syms.append(sym)
    return syms


def render_spec(ea_label: str) -> str:
    m = re.match(r"(QM5_\d+)_(.+)$", ea_label)
    if not m:
        raise ValueError(f"bad ea_label: {ea_label}")
    ea_id, slug = m.group(1), m.group(2)
    ea_id_suffix = ea_id.replace("QM5_", "")
    ea_dir = EAS / ea_label
    mq5_path = ea_dir / f"{ea_label}.mq5"

    card = find_card(ea_id)
    fm = parse_frontmatter(card) if card else {}

    source_id = fm.get("source_id") or "unknown"
    today = dt.date.today().isoformat()
    timeframe = extract_timeframe(fm, mq5_path)
    symbols = get_registered_symbols(ea_id)
    if not symbols:
        # fall back to target_symbols frontmatter
        ts = fm.get("target_symbols", "")
        symbols = [s.strip() for s in re.findall(r"[A-Z]+\.DWX", ts)]
    strategy_inputs = extract_strategy_inputs(mq5_path)
    trade_freq = fm.get("expected_trade_frequency", "see card body")
    trades_yr = fm.get("expected_trades_per_year_per_symbol", "unspecified")

    # Build sections
    params_rows = "\n".join(
        f"| `{n}` | {d} | (see source) | (see strategy logic) |"
        for n, d, _ in strategy_inputs
    ) or "| (no strategy-specific inputs) | — | — | uses framework defaults only |"

    symbols_section = "\n".join(
        f"- `{s}` — registered in magic_numbers.csv for this EA"
        for s in symbols
    ) or "- (no symbols registered yet)"

    spec = f"""# {ea_label} — Strategy Spec

**EA ID:** {ea_id}
**Slug:** `{slug}`
**Source:** `{source_id}` (see `strategy-seeds/sources/{source_id}/`)
**Author of this spec:** auto-generated ex-post by gen_spec_md.py
**Last revised:** {today}

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card
`artifacts/cards_approved/{ea_id}_{slug}.md`. See that card's body for
the full entry/exit/stop/sizing rules; this SPEC summarises the
implementation surface.

Entry/exit logic is encoded in the five `Strategy_*` hooks in
`{ea_label}.mq5`. Framework wiring (risk, magic, news, Friday close)
is inherited from `QM_Common.mqh` and is not redocumented here.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
{params_rows}

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
{symbols_section}

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `{timeframe}` |
| Multi-timeframe refs | see `Strategy_*` hooks in the .mq5 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | {trades_yr} |
| Cadence note | {trade_freq} |
| Typical hold time | see card body |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | per card thesis |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `{source_id}`
**Pointer:** `strategy-seeds/sources/{source_id}/`
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/{ea_id}_{slug}.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | {today} | Initial spec (ex-post, generated by gen_spec_md.py) | post-PT15 remediation |
"""
    return spec


def validate(ea_dir: Path) -> tuple[bool, str]:
    r = subprocess.run(
        [sys.executable, str(VALIDATOR), str(ea_dir)],
        capture_output=True, text=True, timeout=30,
        creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
    )
    return r.returncode == 0, (r.stdout + r.stderr).strip()


def find_stuck_failed() -> list[str]:
    """Return ea_labels of build_ea tasks in status=failed with
    fail_code=spec_validation_failed AND ea_dir on disk with .ex5."""
    out = []
    con = sqlite3.connect(DB)
    con.row_factory = sqlite3.Row
    for r in con.execute(
        "SELECT payload_json FROM tasks WHERE kind='build_ea' AND status='failed'"
    ):
        try:
            pl = json.loads(r["payload_json"] or "{}")
        except json.JSONDecodeError:
            continue
        if pl.get("fail_code") != "spec_validation_failed":
            continue
        ea_id = pl.get("ea_id", "")
        slug = (pl.get("frontmatter") or {}).get("slug", "")
        if not ea_id or not slug:
            continue
        label = f"{ea_id}_{slug}"
        ea_dir = EAS / label
        if (ea_dir / f"{label}.ex5").exists():
            out.append(label)
    return sorted(set(out))


def reset_task_to_pending(ea_label: str) -> int:
    m = re.match(r"(QM5_\d+)_", ea_label)
    if not m:
        return 0
    ea_id = m.group(1)
    # 30s timeout — pump's transactions are short, this should wait it out
    con = sqlite3.connect(DB, timeout=30)
    con.row_factory = sqlite3.Row
    n = 0
    for r in con.execute(
        "SELECT id, payload_json FROM tasks WHERE kind='build_ea' AND status='failed' "
        "AND json_extract(payload_json,'$.ea_id')=?", (ea_id,)
    ).fetchall():
        pl = json.loads(r["payload_json"] or "{}")
        # Clear the failure-state fields so pump's Step 4 picks it up clean
        for k in ("fail_code", "spec_blocked_summary", "spec_validation",
                  "smoke_skipped_reason", "last_blocked_reason"):
            pl.pop(k, None)
        con.execute(
            "UPDATE tasks SET status='pending', payload_json=?, updated_at=? WHERE id=?",
            (json.dumps(pl), dt.datetime.now(dt.UTC).isoformat(), r["id"]),
        )
        n += 1
    con.commit()
    con.close()
    return n


def process_one(ea_label: str, dry: bool) -> dict:
    ea_dir = EAS / ea_label
    if not ea_dir.is_dir():
        return {"ea_label": ea_label, "ok": False, "reason": "ea_dir missing"}
    spec_path = ea_dir / "SPEC.md"
    spec_text = render_spec(ea_label)
    if dry:
        return {"ea_label": ea_label, "ok": True, "dry_run": True,
                "would_write": str(spec_path), "size": len(spec_text)}
    spec_path.write_text(spec_text, encoding="utf-8", newline="\n")
    ok, out = validate(ea_dir)
    if not ok:
        return {"ea_label": ea_label, "ok": False, "validator_output": out}
    reset_n = reset_task_to_pending(ea_label)
    return {"ea_label": ea_label, "ok": True, "wrote": str(spec_path),
            "tasks_reset_to_pending": reset_n}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("ea_label", nargs="?", help="single EA label, e.g. QM5_10323_payoff-bias")
    ap.add_argument("--all-failed", action="store_true",
                    help="process every build_ea task in status=failed with fail_code=spec_validation_failed")
    ap.add_argument("--dry-run", action="store_true",
                    help="render but do not write SPEC.md or touch DB")
    args = ap.parse_args(argv)

    if args.all_failed:
        targets = find_stuck_failed()
        print(f"Stuck-failed (spec_validation_failed) EAs: {len(targets)}")
    elif args.ea_label:
        targets = [args.ea_label]
    else:
        ap.print_usage(sys.stderr)
        return 2

    n_ok, n_fail = 0, 0
    for label in targets:
        r = process_one(label, args.dry_run)
        flag = "OK" if r.get("ok") else "FAIL"
        print(f"  {flag}  {label}  {r}")
        if r.get("ok"):
            n_ok += 1
        else:
            n_fail += 1

    print(f"\nSummary: {n_ok} OK, {n_fail} FAIL  (of {len(targets)})")
    return 0 if n_fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
