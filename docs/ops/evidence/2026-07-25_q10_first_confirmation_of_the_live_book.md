# Q10 full-history confirmation — first ever run against the live book (2026-07-24/25)

Status: **finding, requires an OWNER decision before the Sunday 2026-07-26 wave.**

## Headline

The Q10 revalidation was commissioned to measure whether the P0/P1 framework fixes changed
sleeve behaviour. It did not answer that question, because there was nothing to compare
against: **no sleeve in the 24-sleeve live book had ever been through Q10.**

Q10 is the closing per-(EA, symbol) verdict in the pipeline spec (Q02–Q10 automated evidence
gates; Q10 confirms on full history with the Q03 plateau-median params and the Q09 news mode).
The book was sealed on Q09_PORTFOLIO admission without it.

## Evidence

Every Q10 `aggregate.json` on the box, both report roots, sorted by generation time:

```
36 Q10 aggregates total (D:/QM/reports/pipeline + D:/QM/reports/work_items)
   8 generated before 2026-07-24
```

The eight that predate tonight:

| generated (UTC) | EA | symbol | verdict | in the 24-sleeve book? |
|---|---|---|---|---|
| 2026-07-20T02:41 | 10123 | XAUUSD | PASS | no |
| 2026-07-20T05:57 | 13013 | NDX | PASS | no |
| 2026-07-20T14:12 | 10128 | XAUUSD | PASS | no |
| 2026-07-20T19:17 | 10145 | XAUUSD | PASS | no |
| 2026-07-20T21:58 | 10145 | XAUUSD | PASS | no |
| 2026-07-21T00:22 | 10145 | XAUUSD | PASS | no |
| 2026-07-21T14:50 | 10183 | XAUUSD | PASS | no |
| 2026-07-22T19:26 | 20048 | XTIUSD | PASS | no — OWNER-promoted candidate |

Corroborated independently by the Q13 kill-switch baseline store
(`…\Common\Files\QM\baselines\`), which `q10_confirmation.py` writes **only on PASS**: before
tonight it held baselines for 10123, 10128, 10145, 10183, 13013, 20048, 11422 — and for no book
sleeve. Two independent artifacts, same answer.

This is not a skipped gate in the sense of someone bypassing it. `q10_confirmation.py` has
existed since `133c44f66` (2026-05-23), but Q10 was first actually executed on 2026-07-20, and
the run queue since then has been working the harvest tranches rather than the deployed book.
The book simply predates Q10 ever being pointed at it.

## Tonight's result

23 live sleeves + 20048, on the freshly recompiled binaries. 10513/XAUUSD excluded (manifest
provenance defect, documented separately).

| outcome | n | note |
|---|---|---|
| PASS | 14 | first Q10 confirmation these sleeves have ever had |
| FAIL | 2 | 10706/GBPUSD, 13213/USDJPY — see below |
| INVALID (infra) | 8 | tester agent history-sync failure, retest running |

Driver `scratchpad/revalidate_q10.py`, results `scratchpad/q10_revalidation_results.json`,
per-sleeve evidence `D:/QM/reports/pipeline/QM5_<id>/Q10/<SYMBOL>/aggregate.json`.

### The 14 PASSes

| EA | symbol | pf | dd % | trades |
|---|---|---:|---:|---:|
| 20048_wti-preholiday | XTIUSD | 1.28 | 1.18 | 61 |
| 13128_pre-fomc-drift-ndx | NDX | 2.29 | 1.25 | 57 |
| 1556_aa-zak-mom12 | XAUUSD | 1.93 | 2.68 | 53 |
| 10919_grimes-overshoot | XTIUSD | 4.84 | 1.85 | 30 |
| 12567_cum-rsi2-commodity | XNGUSD | 1.31 | 2.25 | 58 |
| 11132_tm-cum-rsi2 | SP500 | 1.49 | 3.01 | 73 |
| 12969_usdjpy-gotobi-nakane-fix | USDJPY | 1.54 | 2.02 | 331 |
| 11421_ohlc-daily-squeeze-reversal-d1 | AUDUSD | 1.16 | 5.59 | 90 |
| 11165_weiss-rsi-ma | AUDCAD | 1.14 | 4.41 | 207 |
| 12567_cum-rsi2-commodity | XAUUSD | 1.61 | 2.37 | 73 |
| 10403_et-turtle20x | XAUUSD | 1.31 | 7.34 | 209 |
| 12989_grimes-nested-pb-v2 | XAUUSD | 1.72 | 6.48 | 51 |
| 10939_grimes-context-pb | GBPUSD | 1.58 | 6.19 | 92 |
| 13301_balke-minute-range-breakout | GDAXI | 1.28 | 14.49 | 742 |

Gate: PF > 1.0 AND DD < 15 %. 13301/GDAXI clears at 14.49 % — inside the gate, but with almost
no margin. Worth flagging, not worth blocking on.

### The 2 FAILs are not recompile regressions

| EA | symbol | Q10 pf | Q10 dd % | trades | live risk % |
|---|---|---:|---:|---:|---:|
| 10706_tv-mon-ls | GBPUSD | 1.51 | **19.93** | 284 | 0.0530 |
| 13213_balke-gmt3-range-breakout | USDJPY | 1.16 | **22.80** | 1624 | 0.0431 |

Both fail on drawdown, not on profitability. Both are consistent with their own recorded gate
history on the *old* binary, so the recompile did not cause this:

```
10706/GBPUSD   Q05 dd 19.63  Q06 dd 18.84  Q07 dd 22.52   ->  Q10 dd 19.93
13213/USDJPY   Q05 dd 21.50  Q06 dd 21.38  Q07 dd 24.24   ->  Q10 dd 22.80
```

Both also carry an unresolved Q08:

- **10706/GBPUSD** — Q08 `INFRA_FAIL` ×12, then `FAIL_HARD`. Q09_PORTFOLIO `PASS_PORTFOLIO`.
- **13213/USDJPY** — Q08 `INFRA_FAIL` ×5, never passed. Manifest flags it `new_candidate: true`.

So these two entered the book with a failed/never-passed Q08 and no Q10, and the first time the
closing gate was pointed at them, they failed it. The gate is doing its job.

Cost of removing both: 0.0530 + 0.0431 = **0.0961 of 9.75 total risk = 0.99 % of book risk.**

### The 8 INVALIDs are infrastructure, not strategy

Captured tester log, `…/QM5_11165/20260724_220132/raw/run_03/20260725.log`:

```
Tester   EURUSD.DWX: history data begins from 2017.10.02 00:00
Tester   EURUSD.DWX,H1 (Darwinex-Live): testing of Experts\QM\QM5_11165_weiss-rsi-ma.ex5
         from 2017.01.01 00:00 to 2025.12.31 00:00
Core 01  EURUSD.DWX: history synchronization error
Core 01  disconnected
Tester   automatical testing finished
```

The tester agent never ran the pass. `oninit_failure_detected: false`,
`model4_log_marker_detected: false`, `attempted_runs: 3`, `non_ok_attempts: 3`.

Ruled out as causes:

- **Disk / cache purge** — D: has 232 GB free; `tester_cache_purge.ps1` is a no-op above 80 GB.
- **Broken symbol store** — EURUSD.DWX holds 105 `.tkc` / 859 MB, in line with every symbol that
  passed (AUDCAD 106/928 MB, XAUUSD 106/1902 MB).
- **Broken binary** — the same `.ex5` passed on another symbol in the same batch: 11165 PASS on
  AUDCAD, 11421 PASS on AUDUSD, while both returned INVALID on EURUSD.
- **Missing history** — the terminal resolved the symbol and printed its true range; the failure
  is agent-side sync, downstream of that.

Remaining hypothesis: the 10-wide concurrent fan-out outran the tester agents' history
synchronisation. Retest at concurrency 3 in progress
(`scratchpad/retest_q10_invalid.py` → `q10_retest_results.json`).

Sub-observation worth its own follow-up: `D:/QM/mt5/T6/Tester/logs/20260724.log` reached
**3.97 GB** (2026-07-23: 2.27 GB; normal 80–100 MB) and `log_bomb_detected` stayed false. The
detector does not catch this shape.

## What this changes for Sunday

1. The book cannot be described as Q10-confirmed today. After tonight, 14 of 23 can.
2. 10706 and 13213 fail the closing gate and should not ship. Together they are ~1 % of book
   risk, so removing them is nearly free.
3. 10513/XAUUSD (0.3050) is still parked on the manifest-provenance defect.
4. The allocation must be rebuilt over whatever composition survives — the 24-sleeve table in
   `decisions/2026-07-24_dxz_total_risk_975_to_12.md` is superseded by any composition change.

## Recommendation

Ship the Sunday wave with the Q10-confirmed sleeves only, drop 10706 and 13213, and rebuild the
capped inverse-vol allocation at TOTAL_RISK 12.0 over the survivors. Re-running Q10 costs
minutes per sleeve and is now a standing prerequisite — it should become a hard assertion in
`gen_dxz_final_manifest.py` so a sleeve without a passing Q10 cannot enter a manifest at all.
