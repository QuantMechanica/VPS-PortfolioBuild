"""Commission the Balke USDJPY time-window audit (OWNER 2026-09-09 ~20:40Z):
V1 OWNER video lane (source clock / outside-range / buffer / claimed PF), A1 Astra Balke lineage audit +
governed clock/outside-range/buffer comparison, A2 Astra fleet-wide session-clock semantics audit (read-only)."""
import json
import subprocess
import time

REPO = "C:/QM/repo"
EA = "framework/EAs/QM5_41398_balke-pattern-repair-opt/QM5_41398_balke-pattern-repair-opt.mq5"
FACTS = [
    "QM5_41398 (lineage 13213 -> 41097 -> 41398) computes the session clock as UTC+3 FIXED all year (Strategy_Gmt3Hour: QM_BrokerToUTC(broker)+3h). Range = closed H1 bars with hour 3,4,5 of that clock (needs >=3 bars), straddle placed only while hour==6, hard flat at hour>=18, pending orders cancelled at 18.",
    "Darwinex broker time is GMT+2 outside US DST and GMT+3 inside US DST. Hence the traded UTC window is 00:00-03:00 UTC all year; in broker terms that is 03:00-06:00 broker in summer but 02:00-05:00 broker in winter.",
    "The recorded source statement (memory 2026-07-14, agy captions-only analysis, no on-screen evidence) says Balke: range 03:00-06:00 'broker GMT+2/+3', stops at range high/low, close ~18:00. Whether Balke means broker/chart time (which broker, DST-following?) or German local time (CET/CEST) is an undocumented evidence GAP.",
    "No buffer input exists: BUY_STOP exactly at range_high, SELL_STOP exactly at range_low; SL = opposite range boundary; exit also when price re-crosses the opposite boundary; trailing trigger +1R; ATR(14,H1) range band 0.4-2.5 skips the day (this band is NOT a Balke rule as far as recorded).",
    "Undetermined: what happens when price at 06:xx is already outside the range (BUY_STOP below Ask is an MT5 invalid-price rejection, retcode 10015) - the day would then carry only the opposite pending order, i.e. a fade instead of a breakout. Must be established from the tester journal / QM_PPS placement code, not assumed.",
    "Known results: 13213 USDJPY walk-forward OOS PF 1.20 gross / 1.168 DXZ-costed (docs/research/BALKE_RANGE_BREAKOUT_WALKFORWARD_2026-07-14.md). OWNER reports Balke's own backtests/live are materially better; Balke's actual numbers are NOT on file.",
]
HARD = [
    "No verdict, threshold or gate change; existing work_items/verdicts are never modified; a rebuilt EX5 is a NEW identity from Q02 (E1/E2 rule) - never overwrite QM5_41398's active binary, use a new sibling ea_id via the governed magic precondition ticket path",
    "Backtests only under governed factory claims (RISK_FIXED=1000, RISK_PERCENT=0); no manual terminal start; never T_Live; no live/FTMO action",
    "Symbols are inputs/chart symbol, never literals; live builds never read the backtest news archive",
    "Commit with explicit pathspecs, LF, co-author trailer; RESULT line in docs/ops/OPEN_ITEMS_STATUS.md; every claim with a CSV/report/log path",
]
COMMON = {
    "requested_by": "Orchestrator Claude interactive session 2026-09-09 (OWNER instruction 2026-09-09 ~20:40Z: 'Kontrolliere bitte nochmal alles und beauftrage Astra')",
    "facts_established_by_orchestrator": FACTS,
    "hard_limits": HARD,
    "evidence": [
        EA,
        "framework/EAs/QM5_41398_balke-pattern-repair-opt/docs/strategy_card.md",
        "framework/include/QM/QM_Common.mqh (QM_BrokerToUTC, NY-close GMT+2/+3 rule)",
        "docs/research/BALKE_RANGE_BREAKOUT_WALKFORWARD_2026-07-14.md",
        "D:/QM/reports/work_items/2fc84747-27db-5e88-9568-3fdda6c30769/QM5_41398/20260909_135814 (Q02 baseline PASS)",
    ],
}
V1 = dict(COMMON, **{
    "title": "OWNER-VID-BALKE-CLOCK: Balke USDJPY Time-Range-Breakout - which clock are 03:00-06:00 / 18:00 in, what happens when price is already outside the range at 06:00, is there a buffer, and what PF/period does Balke show?",
    "objective": "Close the source evidence GAP that decides whether QM5_41398's fixed-UTC+3 window is the strategy Balke actually trades. Only a human can read the on-screen chart clock; captions cannot.",
    "questions_for_owner": [
        "Q1 CLOCK: In the video/backtest you refer to, are 03:00-06:00 and 18:00 read off the MT5 chart clock (which broker? does its server time follow US DST like Darwinex GMT+2/+3?) or stated as German local time (MEZ/MESZ)? Timestamp [hh:mm:ss] of the frame; NICHT GEZEIGT if never visible.",
        "Q2 OUTSIDE-RANGE: If at 06:00 the price already sits above/below the range, does Balke enter at market, place only the opposite stop, or skip the day? Timestamp or NICHT GEZEIGT.",
        "Q3 BUFFER: Are the stop orders placed exactly at the range high/low or with an offset (pips / % of range / ATR)? Timestamp or NICHT GEZEIGT.",
        "Q4 STOP/TARGET: Is the stop the opposite range boundary (as implemented) or a fixed distance / % of range? Any take-profit before 18:00? Timestamp or NICHT GEZEIGT.",
        "Q5 FILTERS: Does Balke apply any range-size filter (our ATR 0.4-2.5 band is not on file as his rule), day-of-week or news filter? Timestamp or NICHT GEZEIGT.",
        "Q6 NUMBERS: The PF / net / drawdown / period / lot sizing Balke shows for USDJPY (backtest and live). Timestamp per number; NICHT GEZEIGT otherwise. Also: which video/URL is the rule source (the one on file, XgfpXQzpJtk, is a tooling video and does not contain the rules).",
    ],
    "decision_this_unblocks": "Astra ticket A1 chooses the clock mode and outside-range rule to test; without Q1 the comparison matrix must carry all three clock hypotheses (fixed UTC+3, broker DST-following, CET/CEST) and the result stays hypothesis-ranked.",
    "vault_mirror": "12 ToDo/AI ToDos/OWNER Videoanalysen.md (Tier 1)",
})
A1 = dict(COMMON, codex_model_tier="astra", scalpel=True, model_tier="astra", codex_reasoning_effort="high", required_capabilities=["code", "ops", "research"], **{
    "title": "ASTRA-BALKE-CLOCK-AUDIT: prove which UTC window QM5_41398 really trades per season, establish the outside-range behaviour from the journal, then run a governed comparison (clock mode x outside-range rule x buffer) on USDJPY H1 as a new sibling instrument",
    "objective": "Answer OWNER 2026-09-09: 'Fenster 3-6, Close 18 - welcher Offset? Einstieg wenn die Range um 6 schon verlassen ist? Pufferzone 5/10 %? PF 1.16 << Balke.' Deliver evidence, not opinion.",
    "steps": [
        "S1 Trace: from the Q02 baseline (2fc84747, D:/QM/reports/work_items/.../QM5_41398/20260909_135814/raw) build the entry-time distribution by UTC hour and by broker hour, split winter/summer (US DST), plus the 18:00 exit distribution -> CSV. This proves the traded window per season (expected: 00-03 UTC all year = 02-05 broker in winter).",
        "S2 Outside-range: count days where the 06:00 price was already beyond range_high/low; from the tester journal count invalid-price rejections (retcode 10015 / 'invalid price') and days that ended up with a single pending order (fade). Report the P&L of those fade-only days separately. Read the QM_PPS placement path to document the exact behaviour.",
        "S3 Hypotheses (Q14 lever contract, GELB): H-CLOCK 'the source window is broker DST-following (or CET); the fixed UTC+3 clock shifts the winter window 1h early and costs edge' - refutation: PF/trade and expectancy per winter month do not improve by >=10% relative under the DST-following clock over 2018-2025; H-OUTSIDE 'fade-only days are net negative; skipping them raises PF' - refutation: fade-only-day P&L >= 0; H-BUFFER 'a 5-10% range-height buffer cuts false breakouts' - refutation: no buffer level beats 0 on PF AND net over both halves (2018-2021 / 2022-2025). Frequency check: >=5 trades/yr floor and expected ~140/yr must hold in every cell. Parameter count: +2 inputs (strategy_clock_mode enum, strategy_entry_buffer_pct), +1 (strategy_outside_range_rule enum) -> declare all three.",
        "S4 Implement as NEW sibling EA (governed magic precondition, new ea_id; defaults reproduce 41398 bit-for-bit: clock_mode=GMT3_FIXED, outside_range_rule=AS_IS, buffer=0): clock modes GMT3_FIXED | BROKER_DST (raw broker hour, NY-close GMT+2/+3) | CET_LOCAL (Europe/Berlin via UTC offset rule); outside-range rules AS_IS | SKIP_DAY | MARKET_ENTRY_IN_BREAKOUT_DIRECTION | OPPOSITE_STOP_ONLY; buffer in % of range height applied symmetrically to entry stops (SL stays at the opposite boundary minus buffer or as-is - state the choice). Compile via COMPILE_EA queue only.",
        "S5 Governed matrix on USDJPY.DWX H1 2018.07-2025.12 (Model per tester_defaults, RISK_FIXED): 3 clocks x 4 outside rules x buffer {0,5,10} = 36 cells, plus the 41398 baseline reproduced as cell 0 (must match the Q02 baseline trade list exactly - proves the sibling is faithful). Report per cell: trades, net gross, net DXZ-costed ($5/lot RT), PF, maxDD, per-year PF, winter vs summer PF. Runtime budget: measure cell 0 first and report projected wall time before starting the remaining 36 (>1h factory time is GELB: report cost).",
        "S6 Verdict-free synthesis for OWNER: ranked table, which hypothesis survived its refutation criterion, and the recommended single configuration to carry into a fresh Q02-Q10 chain (never promote by overwriting 41398).",
    ],
    "acceptance": [
        "CSV evidence for S1 and S2 with paths; cell-0 trade list identical to 2fc84747",
        "New sibling ea_id registered via the governed magic precondition path; 41398 binary untouched",
        "36-cell result table + hypothesis outcomes under docs/research/BALKE_CLOCK_AUDIT_2026-09-XX.md; OPEN_ITEMS RESULT line",
        "If OWNER video ticket OWNER-VID-BALKE-CLOCK is answered before S5, restrict the matrix to the confirmed clock and say so",
    ],
    "expected_artifact": "docs/research/BALKE_CLOCK_AUDIT_2026-09-XX.md + CSVs under docs/ops/evidence/",
})
A2 = dict(COMMON, codex_model_tier="astra", scalpel=True, model_tier="astra", codex_reasoning_effort="high", required_capabilities=["code", "research", "ops"], **{
    "title": "ASTRA-FLEET-SESSION-CLOCK-AUDIT (read-only): find every active EA whose time-window semantics may not match its source (raw broker hour vs fixed GMT+x vs DST-following vs local time), plus straddle/range EAs with undefined 'price already outside the range' behaviour",
    "objective": "OWNER 2026-09-09: 'Solche Gedanken und Fehler gibt es vielleicht bei anderen EAs auch.' Produce a ranked suspect list with evidence, no fixes.",
    "scope": "All EAs in the active inventory with at least one Q02+ PASS or any Q14/opt-census lineage (query work_items), whose Strategy input group has hour/session/time inputs or whose source uses TimeCurrent()/TimeToStruct hour comparisons. Exclude the framework-wide qm_friday_close_hour_broker input from the trigger condition.",
    "steps": [
        "S1 Inventory: script that lists per EA: clock construct used (raw TimeCurrent hour | QM_BrokerToUTC + fixed offset | QM_BrokerToUTC only | local-time helper), the window inputs and defaults, and the clock stated in docs/strategy_card.md (quote the line) -> CSV.",
        "S2 Classify mismatch risk: MATCH / MISMATCH / UNSTATED-IN-CARD (evidence gap) / N-A. For MISMATCH and UNSTATED give the seasonal shift in hours vs the most plausible source clock and cite the card/source line.",
        "S3 Straddle/range class: for every EA placing pending stops at a computed level at a fixed time, state what the code does when price is already beyond the level (skip / market / opposite-only / undefined) with file:line.",
        "S4 Rank by (PASS depth reached) x (shift hours) x (trades affected), top 10 with a one-line hypothesis each; propose which deserve a governed re-measurement (do not start any).",
    ],
    "acceptance": [
        "CSV inventory with one row per EA and file:line evidence; ranked top-10 table in docs/research/FLEET_SESSION_CLOCK_AUDIT_2026-09-XX.md",
        "Zero source changes, zero work_items created; OPEN_ITEMS RESULT line",
    ],
    "expected_artifact": "docs/research/FLEET_SESSION_CLOCK_AUDIT_2026-09-XX.md + CSV under docs/ops/evidence/",
})

if __name__ == "__main__":
    ids = {}
    for key, prio, payload, extra in (("V1", 90, V1, ["--skills", "video_analysis"]),
                                      ("A1", 88, A1, ["--assigned-agent", "codex"]),
                                      ("A2", 80, A2, ["--assigned-agent", "codex"])):
        for _ in range(6):
            r = subprocess.run(["python", "tools/strategy_farm/agent_router.py", "enqueue", "ops_issue", "--priority", str(prio),
                                *extra, "--payload-json", json.dumps(payload, ensure_ascii=False)],
                               capture_output=True, text=True, cwd=REPO)
            if r.returncode == 0:
                tid = json.loads(r.stdout)["task_id"]
                ids[key] = tid
                print("enqueue ok", key, tid[:8], prio, payload["title"][:50])
                break
            print("retry", key, r.stderr.strip()[-200:])
            time.sleep(8)
    print("IDS", json.dumps(ids))
