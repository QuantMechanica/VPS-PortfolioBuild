# QM5_12580 AUDUSD Q03 zero-trade FAIL — diagnosis

Date: 2026-09-03
Branch: `agents/board-advisor` (worktree)
Merge baseline: fast-forward `a92cda60fe` -> `6c8e7af1f2` (= `agents/board-advisor` HEAD at diagnosis time)
Work item: `a64d18d3-bce6-4112-a13e-f610617405c1` (QM5_12580, AUDUSD.DWX, **Q03**, append-only rerun of `6ce2cb7c`)
Outcome recorded by farm: **FAIL / run_smoke_fail:MIN_TRADES_NOT_MET**, `verdict_taxonomy=strategy`

## Verdict

**False zero-trade. Root cause is INFRA (harness report-capture race), not strategy.**
The Q03 run actually executed the full window and traded on AUDUSD.DWX. The recorded
FAIL comes from `run_smoke.ps1` latching MetaTester's intermediate **report shell**
(`Symbols=0 / Total Trades=0 / Initial Deposit=0.00`) as if it were the final report,
before the main terminal process flushed the completed report. The strategy fail
classification (`verdict_taxonomy=strategy`, `MIN_TRADES_NOT_MET`) is a misclassification.
A same-day, same-binary, same-window control (Q02 `d53328e2`) captured the full report
(47 trades) and PASSED.

## The contradiction, and how it resolves

The summary (`.../20260903_184237/summary.json`) reports both runs with
`total_trades=0, net_profit=0.00, drawdown=0.00, profit_factor=0.00`, `oninit_failure=false`,
`real_ticks_marker=true`, `model=4`, window `2018.07.02`–`2022.12.31`, `min_trades_required=25`.
Three independent lower layers disagree with that "0 trades":

1. **MT5 tester journal (authoritative execution record).**
   `raw/run_01/20260903.log` (UTF-16), at journal time `20:44:01.782`:
   `Tester AUDUSD.DWX,Daily: testing of Experts\QM\QM5_12580_fx-usd-exhaustion-reversal.ex5 from 2018.07.02 00:00 to 2022.12.31 00:00 started`.
   Real deals follow, e.g. `20:47:10.314 Trades 2018.07.10 00:05:00 deal #2 sell 1.1 AUDUSD.DWX at 0.74642 done` … through `deal #69`. The block ends:
   `20:54:26.919 Tester AUDUSD.DWX,Daily: 119049418 ticks, 958 bars generated. Environment synchronized … Test passed in 0:10:25.184`.
   The run **completed the full window and traded.**

2. **EA structured logger** (`logger_sample.jsonl`, run_02, 1276 events):
   `INIT_OK {slot:2, universe:7}`, `BASKET_WARMUP {requested:7, loaded:7, skipped:0, warmup_bars:142}`,
   **36 `ENTRY_ACCEPTED`** each with `retcode:10009` (TRADE_RETCODE_DONE) on `AUDUSD.DWX / symbol_slot:2`
   (e.g. ticket 2 `QM_SELL 1.1 @ 0.74642` — identical to journal deal #2),
   39 `TM_OPEN`, 43 `TM_CLOSE`, final `EQUITY_SNAPSHOT equity=107428.86`.

3. **Positive control — Q02 `d53328e2-ea8b-4cf8-a016-7b3e7a34c09c`** (farm DB `work_items`):
   same `ex5_sha256=9541ef44…`, same window, run 16:17Z the same day, verdict **PASS**.
   Its summary run_01: `total_trades=47, net_profit=8508.59, profit_factor=1.71, drawdown=4186.86`,
   `report_size_bytes=132656` (a full report with a trade table).

The captured Q03 `report.htm` (both runs, `report_size_bytes=34714`) parses to:
`Initial Deposit: 0.00`, `Symbols: 0`, `Total Trades: 0`, `Total Deals: 0`, **but**
`Bars: 958`, `Ticks: 119049418`, `History Quality: 100% real ticks`,
`Period: Daily (2018.07.02 - 2022.12.31)`. Bars/ticks are deterministic for AUDUSD.DWX
D1 2018–2022 model-4 and match the journal's `119049418 ticks, 958 bars` — i.e. the
capture is from **this** run's tick-generation phase, but before trade/deposit
consolidation. This is exactly the "report shell" the harness itself documents.

## Why the shell was captured (harness gap)

`framework/scripts/run_smoke.ps1`:

- `Test-TesterReportSafeToLatch` (line ~1770) already knows this failure mode verbatim:
  *"MT5 can publish a stable, fully shaped report shell while the tester agent is still
  running. The shell contains the requested period and ordinary metric labels, but
  Symbols=0 / Total Trades=0. Treating that shell as a completed result … turns real
  basket trades into a false zero-trade report."* It requires `symbols>0 && trades>0`.
- That guard is only wired into the **early-stop** latch inside `Start-TesterRun`
  (line ~1953: `if ($sizeAfter -eq $sizeBefore -and (Test-TesterReportSafeToLatch …))`).
  Here the run was **not** early-stopped — the journal shows natural completion
  (`Test passed`), so `Start-TesterRun` returned `finished=true`.
- The **post-completion** capture path does **not** use the safe-to-latch guard. It uses
  `Get-ReportExportWaitSeconds` (line 2260) → returns `0` when the *metatester* writer is
  quiescent and a non-empty report exists ("an existing non-empty report cannot gain
  missing metrics"), then `Wait-ForReportExport -RequireCompleteMetrics` (line 2225) →
  `Test-TesterReportHasCompleteMetrics` (line ~1667), whose completeness test is
  **`Bars>0` + labels present — it never requires Total Deals/Symbols>0 or a settled
  deposit.** The 958-bar shell satisfies it, so run_smoke copies the shell and moves on.

The gap: "metatester writer quiescent" is judged only against MetaTester agent processes;
the **main `terminal64` process** writes the final report during `ShutdownTerminal=1`
shutdown, a moment later. For a heavy 7-leg basket (888,537,619 total ticks across the
seven legs, ~22 GB tick cache; journal `20:54:26.919`) that finalization lag is large
enough that the on-disk report is still the modeling-phase shell when the wait returns 0.
It is a **race**, which is why Q02 (16:17Z) captured the full report and Q03 (18:42Z, and
in both of its runs) captured the shell.

## Ruled-out hypotheses (reference-case `QM5_10025` mechanism does not apply here)

- **Non-host-leg tick availability / model-4 (the QM5_10025 concern):** ruled out. The
  run_01 journal shows every leg's ticks generated and passed to the tester —
  AUDUSD 119,216,159 · EURUSD 131,137,034 · GBPUSD 177,017,016 · NZDUSD 94,199,795 ·
  USDCAD 138,405,839 · USDCHF 99,291,827 · USDJPY 130,277,594 — and `BASKET_WARMUP
  {requested:7, loaded:7, skipped:0}`. The basket signal computed and the EA traded.
- **Custom-history privatization / slot mismatch:** ruled out.
  `payload.custom_history_copy_on_claim` = `already_private_file_count:756, copied_file_count:0`;
  `INIT_OK slot:2` matches `qm_magic_slot_offset=2` (AUDUSD). No `SETUP_SYMBOL_SLOT_MISMATCH`.
- **OnInit / news / setfile / binary drift:** ruled out. `oninit_failure=false`;
  `news_calendar.status=OK` (age 15h); staged EX5 `verified=true`, deployed==source==required
  `9541ef44…`; setfile source==deployed `c00ba1d7…`, stable during run;
  `NEWS_TESTER_CALENDAR_SELFTEST {applicable:true}` in the logger.
- **Deposit/window/contract change since June:** ruled out. `tester.ini` for both runs:
  `Deposit=100000, Currency=USD, Leverage=100, Model=4, FromDate=2018.07.02,
  ToDate=2022.12.31`. The `min_trades_required=25` floor (`rate_per_year=5 × year_count=5`)
  is real, but the identical-binary Q02 cleared it with 47 trades — so the floor is not
  the cause of the zero.

Secondary note (not the gate driver): the `frequency_floor` block shows
`valid_marker_count=0`, and its 6 rejected markers are cross-contamination from other EAs
on the shared T3 daily journal (`QM5_41198` XTIUSD, `QM5_41301`/`QM5_41196` XAUUSD,
all `outside_run_window`). Marker attribution reads the shared daily journal and finds no
attributable QM5_12580 markers **even for the PASSING Q02** — so it does not drive the
verdict; the gate keys off report `Total Trades`, which was the shell's `0`.

## Evidence table

| Layer | Source (cite) | Observation |
| --- | --- | --- |
| Farm verdict | DB `work_items.id=a64d18d3…` | `phase=Q03, status=done, verdict=FAIL, verdict_taxonomy=strategy`, evidence `…/20260903_184237/summary.json` |
| Captured report | `raw/run_01/report.htm` & `run_02/report.htm` (34714 B) | `Initial Deposit 0.00`, `Symbols 0`, `Total Trades 0`, `Total Deals 0`; `Bars 958`, `Ticks 119049418`, `History Quality 100% real ticks` |
| Tester journal | `raw/run_01/20260903.log` @ `20:44:01.782`…`20:54:26.919` | test started full window; deals `#2`…`#69` on AUDUSD.DWX; `119049418 ticks, 958 bars generated. Test passed in 0:10:25` |
| EA logger | `logger_sample.jsonl` (run_02) | `INIT_OK slot 2 universe 7`; `BASKET_WARMUP 7/7/0`; 36 `ENTRY_ACCEPTED retcode 10009`; `equity 107428.86` |
| tester.ini | `raw/run_0N/tester.ini` | `Deposit=100000, Model=4, D1, 2018.07.02→2022.12.31, ShutdownTerminal=1` |
| Leg ticks | `raw/run_01/20260903.log` tail | all 7 USD legs generated+passed real ticks (94M–177M each) |
| **Control Q02** | DB `d53328e2…` + its `summary.json` | same `ex5 9541ef44…`, same window; run_01 `total_trades 47, net 8508.59, pf 1.71`; report `132656 B`; **verdict PASS** |
| News | `summary.json news_calendar` | `status OK`, `age_hours 15` |
| Custom history | `payload.custom_history_copy_on_claim` | `756 already private, 0 copied` |

## Root cause class

**INFRA / harness report-capture race.** Not strategy, not history, not a June contract
change. The EA executed and traded the full Q03 window on a governed real-ticks run; the
recorded zero is an artifact of `run_smoke.ps1` accepting MetaTester's incomplete report
shell as the final report on a heavy multi-leg basket.

## Governed remedy

This is an infra false-zero, so the FAIL row should be preserved and an append-only Q03
rerun enqueued (GRÜN: re-enqueue a row whose verdict is not a real result; old row stays as
evidence). Read-only diagnosis — the command below is for the Orchestrator to run; it was
**not** executed here.

```powershell
cd C:/QM/repo
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_12580 --phase Q03 `
  --append-only-rerun-of a64d18d3-bce6-4112-a13e-f610617405c1 `
  --rerun-reason "INFRA false zero-trade: run_smoke latched MT5 report shell (Symbols=0/Trades=0/Deposit=0.00) on a completed 7-leg basket run; tester journal shows deals #2-#69 and 'Test passed', Q02 d53328e2 (same ex5/window) PASS with 47 trades. See docs/ops/evidence/2026-09-03_qm5_12580_audusd_q03_zero_trade_diagnosis.md"
```

Because the underlying cause is an unfixed race, a bare rerun can re-hit it under T3
contention. The **durable fix** (Codex ops task, does not touch verdict thresholds) is to
close the post-completion capture gap in `framework/scripts/run_smoke.ps1`: when the run
finished naturally (not early-latched, not timed out) but the on-disk report shows the
shell signature (`Total Deals=0` **and** `Initial Deposit=0.00` **and** `Symbols=0`), do not
accept it as complete — keep waiting until the **main terminal** process (not just the
MetaTester agent) has exited and the report gains `Total Deals>0`/a settled deposit, or
cross-check the tester journal for `deal … done` lines / `OnTester` before finalizing.
Until then, pair the rerun with either the harness fix or a low-contention T3 window.

## Consequence for the OWNER-DEC-PRE0803 (RECOMPILE-SLOTORDER-AMENDB) batch-2 cohort

`payload.rerun_reason` binds this row to
**`OWNER-DEC-PRE0803-RECOMPILE-SLOTORDER-AMENDB-20260903`** (Q03 on the new identity
`9541ef44` after Q02 `d53328e2` PASS; see
`docs/ops/evidence/2026-09-03_owner_dec_pre0803_recompile_slot_order_amendment_b.md`).

Implication: every cohort member that is a **multi-leg FX basket** re-running Q02/Q03 on
the new recompiled identity is exposed to the same report-shell race (heavier baskets =
larger finalize lag = higher hit rate; it struck **both** Q03 runs here at 18:42Z). Any
`MIN_TRADES_NOT_MET` / zero-trade FAIL in this cohort on a basket EA must be treated as
**suspect infra, not strategy**, and verified against the tester journal (`deal … done`
lines + `Test passed`) and the sibling Q02 result before the verdict is trusted. Single-leg
cohort members are far less exposed (short finalize lag) but should still be spot-checked.
Recommend the Orchestrator: (1) enqueue the append-only Q03 rerun above; (2) commission the
run_smoke hardening to Codex; (3) audit the batch-2 cohort for other zero-trade Q02/Q03
FAILs on multi-leg baskets and rerun any that the journal shows traded. No gate threshold,
verdict stream, live account, or containment scope is touched by any of this.

## Hard-limit compliance

Read-only throughout: farm DB opened `…?mode=ro`; no writes under `D:/QM` or `C:/QM/mt5`;
no enqueue/hold/restart/recompile; no commit/push; the only file written is this evidence
doc under the worktree `docs/ops/evidence/`. A governed FAIL is not overwritten — the
remedy is append-only and left for the Orchestrator to dispatch.
