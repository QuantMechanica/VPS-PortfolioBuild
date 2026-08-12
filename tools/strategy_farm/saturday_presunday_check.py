"""Saturday pre-Sunday prep — READ-ONLY briefing for the 2026-07-12 combined session.

Two jobs, no side effects on anything live:

  (#2) Book readiness: take the additive 20-sleeve Sunday draft
       (portfolio_manifest_sunday_20sleeve_DRAFT_20260708.json = current-15-live + 5
       admits) as the intended composition. Scan portfolio_candidates for any NEW
       Q12_REVIEW_READY EA that appeared after the draft and is not already in it
       -> if any, RECOMPUTE_NEEDED (a human/Claude decides admission incl. rework
       check). Verify each of the 20 sleeves has a q08 stream present. Do NOT re-run
       the greedy assembler: --book-source selected proposes challenger-SWAPS (drops
       live sleeves), which are never auto (OWNER decides at the session).

  (#3) FTMO trial P&L: book equity/DD trend from the pulse, per-EA fills,
       strict paid-challenge qualification, and buffer to the FTMO limits.

Writes: docs/ops/evidence/pre_sunday_prep_<date>.md + state/pre_sunday_prep.json.
Scheduled read-only Saturday; the deploy-staging build (presets/binaries/SHA) and any
AutoTrading remain the OWNER+Claude Sunday session per the Hard-Rule workflow.
"""
from __future__ import annotations
import json, sqlite3, glob, os, re, collections, sys
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(r"C:/QM/repo")
DB = Path(r"D:/QM/strategy_farm/state/farm_state.sqlite")
DRAFT = Path(r"D:/QM/reports/portfolio/portfolio_manifest_sunday_20sleeve_DRAFT_20260708.json")
PULSE_JSON = Path(r"D:/QM/reports/state/ftmo_trial_pulse.json")
PULSE_LOG = Path(r"D:/QM/reports/state/ftmo_trial_pulse.log")
FTMO_QM = Path(r"C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/81A933A9AFC5DE3C23B15CAB19C63850/MQL5/Files/QM")
COMMON_Q08 = Path(r"C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/Common/Files/QM/q08_trades")
DURABLE_Q08 = Path(r"D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades")
OUT_MD = REPO / "docs" / "ops" / "evidence"
STATE = Path(r"D:/QM/reports/state/pre_sunday_prep.json")


def acls(sym: str) -> str:
    s = (sym or "").upper().replace(".DWX", "").replace(".CASH", "")
    if any(s.startswith(k) for k in ("XAU", "XAG", "XPT", "XCU")):
        return "METAL"
    if any(k in s for k in ("SP500", "NDX", "US100", "US500", "WS30", "US30", "US2000", "GDAXI", "GER40", "DAX", "UK100", "STOXX", "225", "NAS")):
        return "INDEX"
    if any(s.startswith(k) for k in ("XTI", "XBR", "XNG", "WTI", "NGAS", "USOIL", "UKOIL")) or "OIL" in s:
        return "ENERGY"
    return "FX"


def book_readiness() -> dict:
    r: dict = {"section": "book_readiness"}
    draft = json.loads(DRAFT.read_text(encoding="utf-8"))
    sleeves = draft.get("sleeves", [])
    draft_eas = {str(s.get("ea_id")) for s in sleeves}
    draft_gen = draft.get("generated_at_utc", "")
    r["draft_sleeve_count"] = len(sleeves)
    r["draft_kpis"] = draft.get("kpis", {})
    r["draft_generated_at"] = draft_gen
    # Genuinely-admittable NEW candidates = eligible per the shared rework-guarded
    # reader, not already in the draft (by ea_id), AND materialized AFTER the draft.
    # The date filter drops stale-but-eligible rows (e.g. superseded swap 10940,
    # 06-27); read_candidates drops rework-flagged EAs (1556, 10706).
    sys.path.insert(0, str(REPO))
    sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
    try:
        from tools.strategy_farm.portfolio.portfolio_common import read_candidates
        eligible = read_candidates(DB)  # rework-excluded (ea_int, symbol)
        r["guard"] = "read_candidates (rework-excluded)"
    except Exception as e:
        eligible = []
        r["guard_error"] = str(e)
    con = sqlite3.connect(DB)
    ua = {}
    for ea_id, updated in con.execute(
        "SELECT ea_id, MAX(updated_at) FROM portfolio_candidates WHERE state='Q12_REVIEW_READY' GROUP BY ea_id"
    ).fetchall():
        ua[str(ea_id).replace("QM5_", "")] = updated
    con.close()
    new_cands = []
    for ea_int, symbol in eligible:
        ea = str(ea_int)
        if ea in draft_eas:
            continue
        updated = ua.get(ea, "")
        if draft_gen and updated and updated <= draft_gen:
            continue  # eligible but stale (pre-draft) — not a NEW admit
        new_cands.append({"ea_id": f"QM5_{ea}", "symbol": symbol, "updated_at": updated})
    r["new_q12_candidates_vs_draft"] = new_cands
    # stream presence for each draft sleeve
    missing_streams = []
    for s in sleeves:
        ea = str(s.get("ea_id")); sym = str(s.get("symbol") or "")
        hits = glob.glob(str(COMMON_Q08 / f"*{ea}*")) + glob.glob(str(DURABLE_Q08 / f"*{ea}*"))
        if not hits:
            missing_streams.append((ea, sym))
    r["missing_streams"] = missing_streams
    if new_cands:
        r["verdict"] = f"RECOMPUTE_REVIEW: {len(new_cands)} new Q12 candidate(s) since draft — a human/Claude must decide admission (check rework flag) and recompute weights."
    elif missing_streams:
        r["verdict"] = f"STREAM_GAP: {len(missing_streams)} sleeve(s) missing q08 stream."
    else:
        r["verdict"] = "READY: 20-sleeve additive draft current; no new candidates; all streams present. Deploy-staging + SHA remain the Sunday Claude step."
    return r


def trial_pnl() -> dict:
    r: dict = {"section": "ftmo_trial_pnl"}
    try:
        pulse = json.loads(PULSE_JSON.read_text(encoding="utf-8"))
        r["latest_pulse"] = {k: pulse.get(k) for k in (
            "checked_at_utc", "verdict", "equity", "day_pnl", "total_dd_pct",
            "day_loss_pct", "magics_seen", "expected_magics",
            "server_requests_lower_bound", "server_request_day_broker",
            "equity_snapshot_age_minutes", "kill_switch_day_anchor_magics",
            "kill_switch_book_tag_magics",
        )}
        eq = float(pulse.get("equity") or 0)
        r["buffer_to_total_limit_pp"] = round(10.0 - float(pulse.get("total_dd_pct") or 0), 3)
        r["buffer_to_daily_limit_pp"] = round(5.0 - abs(float(pulse.get("day_loss_pct") or 0)), 3)
    except Exception as e:
        r["pulse_error"] = str(e)
    # equity/DD trend: min equity over the pulse log
    try:
        lows = []
        for line in PULSE_LOG.read_text(encoding="utf-8", errors="ignore").splitlines():
            m = re.search(r"eq=([0-9.]+)", line)
            if m:
                lows.append((line.split()[0], float(m.group(1))))
        if lows:
            worst = min(lows, key=lambda x: x[1])
            r["worst_equity_seen"] = {"ts": worst[0], "equity": worst[1], "dd_pct": round((100000 - worst[1]) / 1000, 3)}
    except Exception as e:
        r["trend_error"] = str(e)
    try:
        sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
        from portfolio.ftmo_qualification import build_inventory

        qualification = build_inventory(DB, repo_root=REPO)
        r["qualification"] = {
            "counts": qualification["counts"],
            "challenge_ready_count": qualification["challenge_ready_count"],
            "research_leads": [
                {"ea_id": row["ea_id"], "symbol": row["symbol"], "blockers": row["blockers"]}
                for row in qualification["candidates"]
                if row["state"] == "RESEARCH_LEAD"
            ],
        }
        r["paid_challenge_verdict"] = (
            "QUALIFICATION_REVIEW_REQUIRED"
            if qualification["challenge_ready_count"] > 0
            else "NO_GO_NO_STRICTLY_QUALIFIED_EAS"
        )
    except Exception as e:
        r["qualification_error"] = str(e)
        r["paid_challenge_verdict"] = "NO_GO_QUALIFICATION_UNAVAILABLE"

    # Per-EA fills plus the account-wide snapshot observed at each EA's last tick.
    # The snapshot is not attributable per-EA PnL.
    byclass = collections.Counter()
    filled = collections.Counter()
    per_ea = []
    for fp in glob.glob(str(FTMO_QM / "QM5_*_ea-*.log")):
        sym = None; fills = 0; last_daypnl = None
        try:
            for line in Path(fp).read_text(encoding="utf-8", errors="ignore").splitlines():
                line = line.strip()
                if not line:
                    continue
                try:
                    o = json.loads(line)
                except Exception:
                    continue
                sym = sym or o.get("symbol")
                ev = o.get("event")
                if ev == "ENTRY_ACCEPTED":
                    fills += 1
                elif ev == "EQUITY_SNAPSHOT":
                    last_daypnl = o.get("payload", {}).get("day_pnl")
        except Exception:
            continue
        if not sym:
            continue
        cl = acls(sym)
        byclass[cl] += 1
        if fills > 0:
            filled[cl] += 1
        ea = os.path.basename(fp).split("_")[1]
        per_ea.append({
            "ea": ea,
            "symbol": sym,
            "class": cl,
            "fills": fills,
            "account_day_pnl_at_last_tick": last_daypnl,
        })
    per_ea.sort(key=lambda x: (x["class"], x["symbol"]))
    r["per_ea"] = per_ea
    r["fill_coverage"] = {cl: f"{filled[cl]}/{byclass[cl]}" for cl in ("METAL", "INDEX", "ENERGY", "FX")}
    return r


def main() -> int:
    now = datetime.now(timezone.utc)
    date = now.strftime("%Y-%m-%d")
    book = book_readiness()
    pnl = trial_pnl()
    state = {"generated_at_utc": now.isoformat(), "book_readiness": book, "ftmo_trial_pnl": pnl}
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(state, indent=2), encoding="utf-8")

    lines = [f"# Pre-Sunday prep briefing — {date} (read-only)", ""]
    lines += ["## #2 Book readiness (DXZ Sunday 20-sleeve)", "",
              f"- Draft: {book['draft_sleeve_count']} sleeves; KPIs {json.dumps(book.get('draft_kpis',{}))}",
              f"- **Verdict: {book['verdict']}**"]
    if book["new_q12_candidates_vs_draft"]:
        lines.append("- New Q12 candidates since draft:")
        for c in book["new_q12_candidates_vs_draft"]:
            lines.append(f"    - {c['ea_id']} / {c['symbol']} ({c['updated_at']})  — verify rework flag before admitting")
    if book["missing_streams"]:
        lines.append(f"- Missing streams: {book['missing_streams']}")
    lines += ["", "## #3 FTMO trial P&L", ""]
    lp = pnl.get("latest_pulse", {})
    lines += [f"- Latest pulse: verdict {lp.get('verdict')}, equity {lp.get('equity')}, total_dd {lp.get('total_dd_pct')}%, day {lp.get('day_pnl')}",
              f"- Buffer to limits: total {pnl.get('buffer_to_total_limit_pp')}pp (of 10%), daily {pnl.get('buffer_to_daily_limit_pp')}pp (of 5%)",
              f"- Paid Challenge: **{pnl.get('paid_challenge_verdict')}**; qualification {pnl.get('qualification')}",
              f"- Logged server-request lower bound: {lp.get('server_requests_lower_bound')} on {lp.get('server_request_day_broker')}",
              f"- Equity snapshot age: {lp.get('equity_snapshot_age_minutes')} minutes",
              f"- Kill-switch rollout proof: day-anchor {lp.get('kill_switch_day_anchor_magics')}/{lp.get('expected_magics')}, book-tag {lp.get('kill_switch_book_tag_magics')}/{lp.get('expected_magics')}",
              f"- Worst equity seen: {pnl.get('worst_equity_seen')}",
              f"- Fill coverage by class: {pnl.get('fill_coverage')}", ""]
    lines.append("| EA | symbol | class | fills | account_day_pnl_at_last_tick |")
    lines.append("|---|---|---|---|---|")
    for e in pnl.get("per_ea", []):
        lines.append(
            f"| {e['ea']} | {e['symbol']} | {e['class']} | {e['fills']} | "
            f"{e['account_day_pnl_at_last_tick']} |"
        )
    lines += ["", "_The per-EA snapshot column is account-wide and is not EA-level PnL attribution._"]
    lines += ["", "_Deploy-staging (presets/binaries/SHA) + AutoTrading remain the OWNER+Claude Sunday session._"]

    OUT_MD.mkdir(parents=True, exist_ok=True)
    md_path = OUT_MD / f"pre_sunday_prep_{date}.md"
    md_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {md_path}")
    print(f"BOOK: {book['verdict']}")
    print(f"TRIAL: equity {lp.get('equity')} dd {lp.get('total_dd_pct')}% buffer_total {pnl.get('buffer_to_total_limit_pp')}pp fills {pnl.get('fill_coverage')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
