import csv, datetime as dt, hashlib, itertools, json
from pathlib import Path
P=Path(__file__).parent
s=json.loads((P/'2026-09-09_balke_baseline_summary.json').read_text())
rows=[]
for i,(clock,outside,buffer) in enumerate(itertools.product(('GMT3_FIXED','BROKER_DST','CET_LOCAL'),('AS_IS','SKIP_DAY','MARKET_ENTRY_IN_BREAKOUT_DIRECTION','OPPOSITE_STOP_ONLY'),(0,5,10)),1):
    rows.append(dict(cell=i,clock=clock,outside_rule=outside,buffer_pct=buffer,status='NOT_RUN_DEPENDENCY',trades='',net_gross='',net_dxz='',pf='',maxdd='',per_year_pf='',winter_pf='',summer_pf='',reason='magic precondition 2e7d5619; later WINSWEEP plan sequences comparison after window selection'))
with (P/'2026-09-09_balke_clock_matrix_plan.csv').open('w',encoding='utf-8',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]),lineterminator='\n');w.writeheader();w.writerows(rows)
deals=list(csv.DictReader((P/'2026-09-09_balke_baseline_deals.csv').open(encoding='utf-8')))
late=[d for d in deals if d['direction']=='out' and int(d['utc_hour'])>15]
with (P/'2026-09-09_balke_late_exits.csv').open('w',encoding='utf-8',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(deals[0]),lineterminator='\n');w.writeheader();w.writerows(late)
card=Path('D:/QM/strategy_farm/artifacts/cards_review/QM5_41405_balke-clock-audit-opt.md')
ea=Path('C:/QM/repo/framework/EAs/QM5_41398_balke-pattern-repair-opt')
identity={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (ea/(ea.name+'.mq5'),ea/(ea.name+'.ex5'),card)}
text=f'''# Balke clock and outside-range audit — 2026-09-09

Task `d444a7a8-f998-4ab2-820a-6f7bc017d475` (priority 88).
RESULT: PARTIAL_REVIEW / DEPENDENCY_PENDING. Baseline trace and placement-day evidence verified;
sibling identity QM5_41405 reserved, draft specification and governed magic ticket delivered.
No sibling source/binary, fidelity rerun, or comparison cells have run. Existing verdicts unchanged.

## Findings established from this baseline

The exact baseline is **2018-07-02 through 2022-12-31 exclusive**, Model 4, USDJPY.DWX H1,
not a 2018–2025 result. It contains **888 trades / 1,776 deals**. Native total net is
**$46,636.78**, gross price P&L $72,559.82, commission -$25,923.04, swap zero.
The native report PF is 1.12; recomputed round-trip net PF is {s['pf_native'][:8]}.
Report max equity DD is **19.86% ($21,852.77)**. These figures do not meet an Edge Lab
10% total-DD target and do not constitute a new pipeline verdict.

The native report already charges approximately $5/lot round trip. Replacing its rounded
commission with exactly $5/lot RT gives net **$46,641.37**; subtracting that cost again
from native net would double-charge it. The $4.59 difference is per-side rounding.
The previously quoted lineage OOS PF 1.168 is a different result, not this baseline.
Evidence: `2026-09-09_balke_baseline_trades.csv`, `2026-09-09_balke_baseline_summary.json`,
and native `report.htm` under the baseline directory cited in that JSON.

All **1,810 stop attempts** were made in strategy hour 6 = **03 UTC**:
1,160 attempts in summer broker hour 6; 650 in winter broker hour 5.
Source `QM5_41398_balke-pattern-repair-opt.mq5`:128-142 converts broker to UTC then adds
a fixed three hours; :225-255 builds the closed-hour range. Thus the range is 00–03 UTC,
02–05 broker winter / 03–06 broker summer. Entries are fills and occur from 03 through
14 UTC; their histogram must not be confused with range-construction or placement time.
Evidence: `2026-09-09_balke_order_attempts.csv` and `2026-09-09_balke_hour_distribution.csv`.

The journal is cumulative across many EAs. Exact-run isolation is lines **62,331–73,514**.
Across the whole file there are 47 invalid-price lines; **only seven belong to this run**.
Each is a rejected buy stop with an accepted sell stop, and the accepted-side quote is
above the range high. All seven are confirmed fade-only *order days*; six never fill.
One fills, on **2022-04-21**, losing **$869.92** net. It is incorrect to call these seven
losing trades. Evidence: `2026-09-09_balke_invalid_price.csv`,
`2026-09-09_balke_order_attempts.csv`, `2026-09-09_balke_outside_days.csv`.

This covers all 905 days on which the parent attempted orders. It does **not** establish
the price at exactly 06:00 for every calendar day, including ATR/news-blocked days.
That full census needs instrumented quote/range data in a governed test. Quote observation
at placement can occur later within strategy hour 6. No missing day is silently counted zero.

## Outside-range and exit code path

`QM5_41398...mq5`:303-339 constructs both stops with no outside-range branch.
`QM_PatternPermissionStraddle.mqh`:75-103 decides permission only; it does not place orders.
EA :622-637 attempts buy then sell independently through `QM_TM_OpenPosition`.
`QM_TradeManagement.mqh`:335-357 calls `QM_Entry`; `QM_Entry.mqh`:448-459 resolves the
request price, then :544-553 constructs the pending request without a market-entry fallback.
An invalid buy does not prevent the following sell attempt. The EA ignores both return
values and marks the day complete from permission intent, even if both fail. This is a
separate day-consumption defect; a faithful cell zero must preserve it before testing changes.

The exit distribution contains **{len(late)} exits after 15 UTC**, so the intended 18:00
strategy clock is not an unconditional hard-flat guarantee. For example, 2018-07-11
closes at 19:00 broker / 16 UTC. EA :551-568 returns on a kill-switch or news denial
*before* calling position management and exit logic (:573 onward). This establishes a
possible delay path; the sampled logs do not identify the blocking reason for every late
exit. Do not assert that all 53 were caused by news. Evidence: `2026-09-09_balke_late_exits.csv`;
native journal/report and logger sample in the pinned baseline raw directory.

## Hypotheses and matrix disposition

- H-CLOCK: untested. Refutation requires no >=10% winter PF/expectancy improvement under
  the proposed clock over the specified full period; present evidence is only the shorter baseline.
- H-OUTSIDE: not refuted **in this baseline** (confirmed fade-only net is negative).
  One trade is insufficient evidence of persistent edge; a skip rule's counterfactual is unmeasured.
- H-BUFFER: untested. Neither 5% nor 10% has been measured against zero in both period halves.

`2026-09-09_balke_clock_matrix_plan.csv` enumerates the 36 combinations with empty result
fields and explicit NOT_RUN_DEPENDENCY status. It is a plan, not a results table.
No winner or single configuration is recommended without measurements.

The **later** pre-registered `docs/research/BALKE_WINDOW_SWEEP_PLAN_2026-09-09.md` section 1
and 7 sequences clock/buffer/outside variants after window selection, on the winner only.
That assigned task `49af4f08` therefore supplies an additional sequencing dependency;
this cycle did not start an obsolete independent 36-cell matrix on the old window.
The video ticket `4a3a4a02` is still TODO; its captions-only note reports Balke USDJPY
00:00–07:30, no trailing/range filter. It does not establish a confirmed broker offset,
so reducing clock modes to one would be unsupported. A source-faithful minute-granularity
replica is a distinct mechanism and must not be silently inserted into the +3-input audit.

## Governed sibling and cost

Canonical `farmctl reserve-ea-ids` reserved **QM5_41405 / balke-clock-audit-opt**, under this
task's strategy UUID. Draft card: `{card.as_posix()}`. It records inherited build authority
from the assigned S4 request, separate from unapproved execution/promotion status.
Three new inputs are declared; buffered entries keep SL at the original opposite boundary.
Magic precheck is **never_allocated**, active identity rows=1, active magic rows=0.
`ensure_magic_precondition_task` created **2e7d5619-d79c-4a02-8688-62157abbb9a4**, TODO,
for the governed allocator sequence. Receipt: `2026-09-09_balke_magic_precondition.json`.
The scheduled-cycle rule forbids choosing this unassigned dependency as extra work.
After it is routed and passes, build and COMPILE_EA can proceed; no manual compile or terminal launch.

Fidelity must first use the exact short baseline window and pinned inputs. A full 2018–2025
control cannot have an identical trade list to a 2018–2022 baseline by construction.
Native parent runtime is **449.167s (7m29s)** (journal :73511). Linear duration scaling
estimates ~12.5 minutes per full-period cell, ~7.5 aggregate worker-hours for 36 cells,
plus fidelity/queue time. **GELB: >1h cost**, historical projection only. Measure the sibling
fidelity cell and publish the updated projection before scheduling further cells.

## Verification

`2026-09-09_balke_baseline_audit.py` matched every entry/exit by ordered single-position
round trip with equal volume and opposite side; reconciled all 888 pairs to final native
balance within one cent; isolated the exact journal segment; verified every placement
was strategy hour 6. Inputs are SHA-256 pinned in the summary. The 41398 source hash
matches baseline summary identity. No existing source, binary, setfile, or work-item
verdict was changed. Source/card pins are in `2026-09-09_balke_identity.json`.

Reports are stored under canonical docs/ops/evidence per the scheduled-task instruction.
Remaining acceptance is explicit: all-day quote census, magic allocation/build/compile,
fidelity match, selected-window matrix, yearly/frequency/DD tables and hypothesis synthesis.
'''
(P/'BALKE_CLOCK_AUDIT_2026-09-09.md').write_text(text,encoding='utf-8',newline='\n')
assert len(rows)==36 and len({(r['clock'],r['outside_rule'],r['buffer_pct']) for r in rows})==36
assert identity[str(ea/(ea.name+'.mq5'))]=='fdbb7499f349a6bd238231e7eb3d4a6257290af650e363ba78b0f95518890540'
(P/'2026-09-09_balke_identity.json').write_text(json.dumps({'files':identity,'matrix_unique_cells':36,'parent_source_matches_baseline':True,'card':str(card),'acceptance':'PARTIAL_REVIEW'},indent=2)+'\n',encoding='utf-8',newline='\n')
print('Balke report verification PASS; 36 planned, zero measured cells')
