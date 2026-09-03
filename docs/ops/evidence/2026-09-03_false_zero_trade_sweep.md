# False zero-trade sweep — Q02-Q06 run_smoke FAIL/ZERO_TRADES/INVALID since 2026-08-15

Date: 2026-09-03
Branch: `agents/board-advisor` (worktree `wf_2dc8f552-a32-2`)
Merge baseline: fast-forward `ab8aa8584d` -> `cb8acbff29` (= `agents/board-advisor` HEAD).
Companion diagnosis (verified root cause): `docs/ops/evidence/2026-09-03_qm5_12580_audusd_q03_zero_trade_diagnosis.md`.
Companion harness fix (this session): `framework/scripts/run_smoke.ps1` (see section 6).
Full per-row table: `docs/ops/evidence/2026-09-03_false_zero_trade_sweep.csv` (133 rows).

Read-only throughout: farm DB opened `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`;
no writes to the DB, `D:/QM/reports`, or `C:/QM/mt5`; no enqueue/hold/restart; no gate/verdict/
threshold change. The only repo writes are this doc, the `.csv`, the `run_smoke.ps1` harness fix,
and its Pester test.

## 1. Scope and candidate set

Universe: `work_items` rows with `kind=backtest`, `phase in (Q02,Q03,Q04,Q05,Q06)` (the
`run_smoke` phases), `updated_at >= 2026-08-15`, `verdict in (FAIL, ZERO_TRADES, INVALID)`,
AND either `payload.verdict_reason` contains `MIN_TRADES_NOT_MET` or `ZERO_TRADES`, OR the run
`summary.json` shows `total_trades = 0` on every run.

Union candidate set: **133 rows** (122 by the verdict_reason clause + 11 added only by the
"all runs total_trades = 0" clause; the 20 `ZERO_TRADES`-verdict rows all carry
`Q02_ZERO_TRADES` and were already in the reason clause).

## 2. Classification result

| Class | Count | Meaning |
| --- | ---: | --- |
| **FALSE_ZERO** | **1** | Report shell latched AND independent evidence (tester journal deals and/or EA logger `ENTRY_ACCEPTED`) proves the EA actually traded. The recorded zero is a harness artifact. |
| GENUINE_ZERO | 18 | The EA genuinely made 0 trades: a **complete** report (`Initial Deposit>0`, `Bars>0`, `Total Deals=0`), or an EA logger that ran the full window with 0 `ENTRY_ACCEPTED`. |
| OTHER | 109 | Not a zero-trade phenomenon. Breakdown below. |
| EVIDENCE_PURGED | 5 | Report/journal/logger deleted; only an empty directory skeleton remains. Unclassifiable from surviving evidence. |

OTHER (109) subclasses:
- **BELOW_FLOOR_GENUINE — 96.** `MIN_TRADES_NOT_MET` with **real, non-zero** trades in a
  complete report (e.g. 15 trades < 25-trade floor). These are genuine economic below-floor
  FAILs swept in by the `MIN_TRADES_NOT_MET` reason string; they never were zero-trade.
- **EMPTY_RUN_NO_MODELING — 11.** `OWNER_APPROVED_Q02_DEAD16_INVALID`: reports show `Bars=0`
  (no tick modeling at all). Dead/empty runs deliberately invalidated by OWNER; outside the
  harness shell-race, which requires `Bars>0`.
- **SHELL_UNVERIFIABLE — 2.** A report shell (`Deposit=0.00/Symbols=0/Deals=0` with `Bars>0`)
  survives, but the confirming layer (tester journal and EA logger) was purged, so trade
  occurrence cannot be proven either way. Not upgraded to FALSE_ZERO without positive proof.

### Method and discriminators (why journal-alone is insufficient)

The tester journal `raw/run_NN/*.log` is the **shared per-terminal daily journal**, not a
per-run file: one file holds every EA that ran on that terminal that day (T3's 2026-09-03
journal held 4 EAs). Naive `grep 'deal #'` over the whole file counts other EAs' deals and
would false-flag almost everything. Deal counting is therefore **scoped to this work item's own
test block** — from the `Tester <symbol>,<tf>: testing of Experts\QM\<EA>.ex5 ... started` line
matching this `ea_id` to the next `testing of Experts` line (tests are sequential per terminal).

Three independent evidence layers are read; the **report `Initial Deposit`** is the primary
discriminator, not `Total Trades`:
- A **settled** MT5 report always carries `Initial Deposit = 100000.00`. A completed run with
  `Deposit=100000 / Total Deals=0` is an authoritative GENUINE_ZERO.
- A **shell** carries `Initial Deposit = 0.00 / Symbols=0 / Total Deals=0` with `Bars>0` — an
  unsettled capture. A shell alone does NOT prove a false zero: it is upgraded to FALSE_ZERO
  only if the tester-journal block shows this EA's deals OR the EA logger shows `ENTRY_ACCEPTED`.
  Counter-example: **QM5_20292** (`FX_CARRY_UNWIND`, `257d153d`) has a shell report but its
  `logger_sample.jsonl` ran the full window (512 `EQUITY_SNAPSHOT`) with **0** `ENTRY_ACCEPTED`
  -> the EA truly did not trade -> GENUINE_ZERO, verdict correct despite the shell.
- For older rows the journal/logger were purged (D: cleanups); the settled-vs-shell report
  signature then decides, and a shell with no confirming layer is SHELL_UNVERIFIABLE.

## 3. The one FALSE_ZERO — QM5_12580 / AUDUSD.DWX / Q03

| Field | Value |
| --- | --- |
| work item | `a64d18d3-bce6-4112-a13e-f610617405c1` |
| verdict | FAIL / `run_smoke_fail:MIN_TRADES_NOT_MET` / `verdict_taxonomy=strategy` |
| report (both runs) | `Initial Deposit 0.00`, `Symbols 0`, `Total Deals 0`, `Bars 958` -> shell 2/2 |
| tester journal (scoped block) | 140 `deal #` lines + `Test passed` |
| EA logger | 146 `ENTRY_ACCEPTED`/`TM_OPEN` (run_01: 34 `ENTRY_ACCEPTED`, retcode 10009) |
| sibling control | Q02 `d53328e2` (same ex5 `9541ef44`, same window) **PASS**, 47 trades |
| moot? | **No** — it is the newest row for the pair (nothing supersedes it) |
| cohort | **Yes** — OWNER-DEC-PRE0803 batch-2 (`QM5_12580/AUDUSD`), see the amendment-B doc |
| census `highest_contiguous_valid_gate` | Q08 (old identity); the recompiled `9541ef44` identity has only Q02 PASS then this Q03 FAIL |

The EA executed and traded the full Q03 window on a governed real-ticks run; the recorded zero
is `run_smoke` latching MetaTester's incomplete report shell before `terminal64` flushed the
settled report. Root cause and evidence: the companion diagnosis doc.

### Governed append-only re-entry command (verified, NOT executed)

The false-zero identity binary is **unchanged**: canonical repo
`C:/QM/repo/framework/EAs/QM5_12580_fx-usd-exhaustion-reversal/QM5_12580_fx-usd-exhaustion-reversal.ex5`
= T3-deployed = the run's ex5 = `9541ef44456367b95e77a8b2334ec5e1b4782fd0ef8b7c7861196f8e3772d17b`.
(A stale `1494d2ef` copy exists in the board-advisor worktree and on T1's July deployment; neither
is the canonical execution binding `_expected_current_execution_bindings` reads, which is the
repo EA dir via `_preferred_ea_dir`.)

```
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_12580 --phase Q03 \
  --from-work-item-id d53328e2-ea8b-4cf8-a016-7b3e7a34c09c \
  --append-only-rerun-of a64d18d3-bce6-4112-a13e-f610617405c1 \
  --expected-current-ex5-sha256 9541ef44456367b95e77a8b2334ec5e1b4782fd0ef8b7c7861196f8e3772d17b \
  --rerun-reason "INFRA false zero-trade: run_smoke latched MT5 report shell (Deposit=0.00/Symbols=0/Total Deals=0, Bars=958) on a completed 7-leg basket; journal deals #2-#69 + Test passed, logger 34 ENTRY_ACCEPTED, sibling Q02 d53328e2 PASS 47 trades. See docs/ops/evidence/2026-09-03_false_zero_trade_sweep.md and 2026-09-03_qm5_12580_audusd_q03_zero_trade_diagnosis.md"
```

Verified against the `farmctl enqueue-backtest` cascade guards (`tools/strategy_farm/farmctl.py`):
- `Q03` is in `CASCADE_BACKTEST_PHASES` (line ~27842). Q03 append-only rerun **requires** an
  exact predecessor (`--from-work-item-id`, guard line 27847) — the diagnosis doc's rerun-of-only
  form would be rejected; this is the correct form.
- `--rerun-reason` is required (line 27854).
- Predecessor `d53328e2`: Q02 (prev phase of Q03), verdict PASS, ea `QM5_12580`, symbol
  `AUDUSD.DWX`, done, not claimed -> passes the predecessor query.
- Rerun target `a64d18d3` matches (line ~28053-28070): same ea, `phase=Q03`,
  `symbol == predecessor.symbol`, `setfile_path == predecessor.setfile_path` (identical:
  `...QM5_12580_..._AUDUSD.DWX_D1_backtest.set`), `status=done`, `verdict=FAIL` (non-null,
  a supported terminal verdict), not claimed.
- Binding (target verdict FAIL != INFRA_FAIL): `_expected_current_execution_bindings` reads the
  canonical repo ex5 = `9541ef44...` == the supplied sha (line 24262/25050). MQ5 + setfile present.
- No prior `append_only_rerun_of_work_item = a64d18d3` row exists, and no open pending/active Q03
  row for the pair+setfile (both verified = 0), so neither dedupe guard trips.

Because the underlying cause is the harness race, this rerun should be paired with the harness
fix in section 6 (or a low-contention T3 window) or it can re-hit the shell.

## 4. GENUINE_ZERO (18) and the rest — no action

- **GENUINE_ZERO (18)** — all Q02 `ZERO_TRADES`, thin/no-signal single-symbol or basket
  strategies (16x XTIUSD/XNG/EURUSD/USDJPY/SP500 single, `QM5_21526`/`QM5_20292` baskets).
  17 have a complete report (`Deposit=100000`, `Total Deals=0`); `QM5_20292` is logger-confirmed.
  All are the newest row for their pair (frontier), none moot. Verdicts are correct; no rerun.
  `QM5_10025/USDJPY` here matches the separately-instrumented Q02 zero
  (`docs/ops/evidence/2026-09-02_qm5_10025_usdjpy_zero_trade_instrumented_q02.md`).
- **BELOW_FLOOR_GENUINE (96)** — genuine economic below-floor FAILs with real trades; not zeros.
- **EMPTY_RUN_NO_MODELING (11)** — `OWNER_APPROVED_Q02_DEAD16_INVALID`, `Bars=0` dead runs.
- **SHELL_UNVERIFIABLE (2)** — `QM5_1537/SP500` (`32bc1b80`, Q02 ZERO_TRADES, **not moot**) and
  `QM5_1537/XAGUSD` (`d6165caf`, **moot** — superseded by a fresh Q02 PASS `e9e72e6f` on new ex5
  `142a019e` and a full chain to Q11/Q14). Both have 1/3 shell + 2/3 empty(`Bars=0`) runs and no
  surviving journal/logger. SP500 is worth a clean append-only Q02 rerun to settle it but cannot
  be confirmed FALSE_ZERO from surviving evidence; it is **not** a confirmed false-zero and so gets
  no re-entry command here.
- **EVIDENCE_PURGED (5)** — all Q03 FAIL, empty directory skeletons: `QM5_41034/XTIUSD` (not moot),
  `QM5_13018/XAGUSD` (not moot), `QM5_20199/EURJPY_EURAUD` (not moot), `QM5_11881/NZDUSD` (moot:
  newer Q04 FAIL), `QM5_12938/USDJPY` (moot: newer Q04 FAIL). Unclassifiable; the two moot ones
  need no action, the three non-moot ones would need a fresh run to obtain any verdict.

## 5. Moot analysis

"Moot" = a strictly-newer `done` row exists for the same `(ea_id, symbol)` at `phase >=` this
row's phase carrying a real terminal verdict (identity-aware; the census pair-level
`highest_contiguous_valid_gate` alone is NOT used, because a recompile makes a new identity from
Q02 and the pair's old-identity chain does not un-block the new identity's frontier — exactly the
QM5_12580 case). Of 133 rows, 4 are moot (`QM5_1537/XAGUSD`, `QM5_11881/NZDUSD`,
`QM5_12938/USDJPY`, one DEAD16). The one FALSE_ZERO is **not** moot.

## 6. Durable harness fix (this session) — `framework/scripts/run_smoke.ps1`

Root cause (companion diagnosis, verified with file:line): the post-completion capture path gates
report completeness on `Test-TesterReportHasCompleteMetrics`, which required only `Bars>0`;
`Wait-ForMetaTesterQuiescence` proves the MetaTester **agents** stopped but not the main
`terminal64`, so `Get-ReportExportWaitSeconds` returned `0` and the shell was latched before
`terminal64` flushed the settled report. The early-stop latch (`Test-TesterReportSafeToLatch`)
already rejected the shell and is untouched.

Three ASCII, CRLF-preserving surgical edits (file 154767 -> 158057 bytes; +58 CRLF lines; 0 lone
LF; 68 pre-existing non-ASCII bytes unchanged):
- **New `Test-TesterReportIsShell`** (line 1667): true iff `Initial Deposit<=0 AND Symbols<=0 AND
  Total Deals<=0 AND Bars>0` — the exact documented shell signature; single source of truth.
- **`Test-TesterReportHasCompleteMetrics`** (line 1706): after the `Bars>0` check, returns `$false`
  when `Test-TesterReportIsShell` is true (line 1752), so `Wait-ForReportExport -RequireCompleteMetrics`
  keeps polling for the settled report instead of accepting the shell.
- **`Get-ReportExportWaitSeconds`** (line 2312): the quiescent-nonempty fast-path (`return 0`) now
  also requires `-not Test-TesterReportIsShell` (line 2334), so a shell retains the full export grace.

Effect (verified by dot-sourcing against the real QM5_12580 shell and synthetic fixtures):
real shell -> `IsShell=True, HasCompleteMetrics=False, WaitSeconds=240`; genuine zero-trade
(`Deposit=100000, 0 trades`) -> `IsShell=False, HasCompleteMetrics=True, WaitSeconds=0` (NOT
broken); settled 47-trade report -> `HasCompleteMetrics=True, SafeToLatch=True`. The shell
signature keys on `Initial Deposit`, so the existing `Symbols=0/Trades=0` fixtures (which omit the
deposit label) are unaffected and the early-latch assertions still hold.

Residual (noted, not fixed here to keep the edit minimal and off verdict logic): a **persistently**
stuck shell that never settles within the 240s grace still falls through to the existing
publish-incomplete path and is parsed as `total_trades=0`. That is the pre-existing behavior for a
genuinely stuck report (e.g. history-sync failure) and is a separate, rarer infra case; classifying
it as INVALID vs ZERO_TRADES would touch downstream verdict classification and is out of scope.

Tests: `framework/scripts/tests/Test-RunSmokeWaitForCompleteReport.ps1` extended (imports
`Test-TesterReportIsShell`; adds shell/settled/genuine-zero regression assertions) -> **PASS**.
`C:/Python311/python.exe -m pytest -q framework/scripts/tests` -> **580 passed, 1 skipped, 4 failed**;
the 4 failures (`test_framework_p1_evidence_contracts::test_tester_news_selftest...` and 3x
`test_q08_setfile_parser_fallback::test_real_10582_markerless_ablation...`) are **pre-existing**:
they read `framework/include/QM/QM_NewsFilter.mqh` and QM5_10582 `.set` files this change never
touched, and reproduce identically with the change stashed. `git status --short
framework/calibrations/` is empty (no QM5_9993 autostub written; no revert needed).

## 7. Prioritisation (cohort / Q11-contiguity)

Only one confirmed FALSE_ZERO exists and it is the highest-priority row on both axes: it is an
OWNER-DEC-PRE0803 (batch-2) cohort member and the live frontier of that recompile identity. The
amendment-B doc's warning stands: every multi-leg FX basket re-running Q02/Q03 on a fresh recompiled
identity is exposed to this same shell race (heavier basket = larger finalize lag = higher hit rate;
it struck both Q03 runs here). The harness fix in section 6 is the durable mitigation for the whole
cohort. No other cohort member appears as a FALSE_ZERO/zero-trade FAIL in this window.

## 8. Recommended next steps (for the Orchestrator; none executed here)

1. Deploy the `run_smoke.ps1` fix (merge; it self-heals the race for all future runs).
2. Enqueue the section-3 append-only Q03 rerun for `QM5_12580/AUDUSD` (paired with the fix).
3. Optional: a clean append-only Q02 rerun for `QM5_1537/SP500` (SHELL_UNVERIFIABLE, not moot) to
   obtain a trustworthy verdict; the 3 non-moot EVIDENCE_PURGED Q03 rows likewise need a fresh run
   only if their verdicts are still wanted.
