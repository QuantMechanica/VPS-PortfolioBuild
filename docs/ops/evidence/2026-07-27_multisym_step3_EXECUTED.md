# Multi-symbol step 3 (satellite 13301:GDAXI + full-book measurement) — GATE STOP

Date: 2026-07-27 · Branch `agents/board-advisor` · Author: Claude
EA under test: `QM5_20181_ftmo-joint-multisym-timer`
Satellite requested this step: `13301:GDAXI` (own symbol input, own magic, own state)
Then: runs E (13301 only), F (all three sleeves), and the full-book FTMO accounting.

Verdict: **STOP AT GATE — step 2 did not admit 10145 at match_rate == 1.0 with the
runner unperturbed. In fact step 2 was itself a GATE STOP: no satellite was ever
enabled, no runner-fidelity control ever completed, and step 1 was never resolved.**
No satellite was enabled, no terminal was reserved, no measurement (E or F) was run.
T_Live, AutoTrading, Factory OFF/ON and `.DWX` history were untouched.

## The gate (verbatim from the step-3 protocol)

> GATE: if step 2 did not admit 10145 at 1.0 with the runner unperturbed, STOP and
> report.

Step 2's own outcome, on record and committed, fails this gate three ways.

## Why the gate fails — evidence

### 1. Step 2 is a documented GATE STOP, not an admission

`docs/ops/evidence/2026-07-27_multisym_step2_EXECUTED.md:6-7` (the committed step-2
artifact, git HEAD `da6712c2d "evidence: multi-symbol step 2 GATE STOP — step 1 diff
(a) unproven"`):

> Verdict: **STOP AT GATE — step 1 is not resolved. No satellite was enabled, no
> terminal was reserved, no measurement was run.**

Step 2 did not admit 10145 at all — it stopped before touching a terminal. `match_rate`
for 10145 (joint-vs-standalone) is therefore **NOT ESTABLISHED**, not 1.0.

### 2. Step 1 (runner bit-fidelity) was never proven — the "runner unperturbed" clause has no operand

`ls docs/ops/evidence/2026-07-27_multisym_step1_EXECUTED.md` → **No such file**. The
step-1 admission diff (a) — joint runner-only vs same-vintage standalone 9936 — was
never produced (`2026-07-27_multisym_step2_EXECUTED.md:24-48`). The runner's own
`match_rate == 1.0` is unestablished, so "with the runner unperturbed" cannot be
evaluated: there is no admitted runner baseline to be perturbed away from.

The one completed runner-vs-reference diff is the **pre-repair** EA QM5_20180 against a
**stale archived** stream and it FAILED:
`{ joint_trades:1255, gated_trades:1252, matched:1148, match_rate:0.914741 }`
(`2026-07-27_joint_backtest_run_EXECUTED.md:13-27`; recapped
`2026-07-27_multisym_step2_EXECUTED.md:62-81`). 0.914741 < 1.0, wrong EA (20180 not the
repaired 20181), wrong control (2026-07-14-vintage archive, not a same-vintage
standalone).

### 3. On-disk state is unchanged since step 2 — no runner-only or 10145 joint stream exists

`D:/QM/reports/joint_20181/` (verified this step):
- `s0_runner/` — **empty** (no runner-only joint replay stream).
- `harvest/` — **empty** (no harvested trade stream).
- `control_9936/QM5_9936/20260727_171318/raw/run_01/` — contains only `tester.ini`
  (473 bytes); no `report.htm`, no `summary.json`, no `9936_USDJPY_DWX.jsonl`. The
  same-vintage standalone control was launched (INI 17:13) but produced no completed
  backtest.
- A repo-wide `find /d/QM/reports -path '*20181*'` returns **zero** real 20181 streams
  (the apparent hits are timestamp substrings `_201818/_201812/_201814/_201815`, all
  unrelated EAs — 10403, 10463, 1371, 10845).

There is no runner-only joint stream and no 10145 joint stream, so neither diff (a)
[step 1] nor the 10145 admission diff [step 2] has any operands. Both are NOT
ESTABLISHED.

### 4. The same-vintage standalone control has failed to complete twice, on record

Both documented attempts died to immediate worker reclaim at 19% progress with
`"some error after pass finished"`, no report, T2 lane reclaimed within ~3 minutes:
`2026-07-27_evidence_vintage_check.md:54-58` and
`2026-07-27_timer_fidelity_curve.md:39-51`. The scaffold's base fidelity remains
unproven, exactly as step 2 recorded.

## Conclusion

The gate condition — step 2 admitted 10145 at `match_rate == 1.0` with the runner
unperturbed — is not met. Step 2 admitted nothing (it was a gate stop), step 1 never
established the runner's own 1.0, and no joint stream for either the runner or 10145
exists on disk. Stacking the 13301:GDAXI satellite and running the full-book
measurement (E and F) now would layer isolation, correlation and FTMO-equity readings
on top of a scaffold whose base fidelity — runner and first satellite — is unproven.
Any resulting number would be unattributable: a satellite perturbation, a runner
cross-vintage gap, and a harness cadence defect would be mutually indistinguishable.
This is precisely what the ladder in `2026-07-27_multisymbol_timer_ea_plan.md:374-429`
(§6, "a later sleeve is not started until the earlier one is admitted at
match_rate == 1.0") and the step-3 gate forbid.

## The 13301:GDAXI question — the plan's answer, read and recorded (not executed)

Per step-3 instruction #1, the hybrid plan's disposition of 13301 is read from
`docs/ops/evidence/2026-07-27_multisymbol_timer_ea_plan.md`. The plan does **not** leave
it unresolved; it resolves it with an evidence gate and a fallback, and it agrees with
the step-3 note that a GDAXI **OnTick host is not possible** (the host is USDJPY,
reserved for the runner):

- **13301 is TIMER-RISKY.** It carries a +1R 2-bar-swing trailing stop evaluated **per
  tick on live BID/ASK**, and it is a **non-host** symbol; a non-host per-tick trailing
  stop cannot reach `match_rate == 1.0` under `OnTimer` at any interval (plan
  `:26-32,54-58,444-448`; RECON B `2026-07-27_sleeve_exit_cadence.md:106-123`). So its
  `OnTimer` path does **not** achieve 1.0 by assumption — its fidelity is conditional
  and must be measured.
- **The plan's resolution (plan `:60-78`, §6 Step 3 `:415-426`):** BEFORE any
  satellite-2 code ships, measure from the **durable gated 13301:GDAXI Q08 stream** how
  many closed-trade exits are **+1R-trail-stop hits** vs **18:00 time-exit /
  opposite-range-touch** (the latter are minute-aligned and reproduce under an M5 poll).
  - **Zero trail-stop-hit exits in full history** → the trail never binds before the
    evening flat; realised exits are time/structure-driven and reproducible → admit
    **13301:GDAXI** on `OnTimer` (M5 poll); `match_rate == 1.0` is then reachable.
  - **Any trail-stop-hit exits** → 1.0 unreachable → **replace** satellite-2 with
    **12969:USDJPY.DWX**, a host-symbol damper co-hosted on the USDJPY chart and driven
    by `OnTick` (byte-faithful like the runner, zero cadence risk).
- **Fidelity its OnTimer path achieves, stated honestly (not assumed 1.0):** for the
  minute-aligned exits (18:00 time-exit, opposite-range-touch) an M5 `OnTimer` poll
  reproduces the exit bar; for any per-tick +1R-trail-stop hit it **cannot** reach
  exact-second/exact-net fidelity, so 1.0 is achievable **iff** the trail-materiality
  measurement returns zero trail-hits — otherwise GDAXI is a non-host fidelity dead-end
  and the 12969 host fallback is used. Its admission gate may therefore legitimately
  fail; that is designed-for, not an error.

That trail-materiality measurement reads 13301's own archived Q08 stream (no terminal),
but it is step-3 sub-action 1 whose purpose is to decide **which sleeve to enable and
run** in the joint EA — an action the gate forbids until the scaffold is proven. It was
therefore **not executed** this step; it is recorded here as the plan's standing
disposition so whoever resolves steps 1–2 can run it immediately at the correct point.

## What this step did NOT do (nothing touches state)

- Did **not** enable sleeve 13301 (or any sleeve) in QM5_20181.
- Did **not** reserve or run any terminal; no `terminal64.exe` was started; no run E
  (13301-only) and no run F (all-three) were launched.
- Did **not** touch T_Live, AutoTrading, Factory OFF/ON, or `.DWX` history. T5 untouched.
- Did **not** edit `farmctl.py` / `terminal_worker.py` (Codex's reaper-fix collision
  files).

Because runs E and F did not execute, every step-3 deliverable is **NOT ESTABLISHED /
NOT RUN**:
- 13301 satellite match rate vs its archived gated stream (run E diff): **NOT RUN**
- run F runner/10145 trade-list invariance (B and C unchanged): **NOT RUN**
- TRUE joint account equity path (per-bar + intraday lows): **NOT ESTABLISHED**
- observed max daily loss / max drawdown vs FTMO −5% / −10%: **NOT ESTABLISHED**
- observed −5% daily breach count vs the MAE proxy (optimistic/pessimistic, by how
  much): **NOT ESTABLISHED**
- realised pairwise sleeve correlations: **NOT ESTABLISHED**
- JOINT-equity FUND_SCORE (med60, |wDay|, wDD_p90) vs the stream-stitched 0.641:
  **NOT ESTABLISHED**

## Wall-clock and RAM

No measurement run was launched, so there is no backtest wall-clock or peak-RAM to
record for runs E/F. This step was desk verification only (evidence reads + directory
inspection).

## Required next step (unchanged from step 2, now blocking step 3 as well)

Resolve step 1 first: obtain a terminal whose reservation is **honored at claim time**
by its persistent worker (both documented controls died to immediate reclaim at 19%),
run to completion (i) the runner-only joint QM5_20181 replay and (ii) a same-vintage
standalone 9936 control, then diff (a) with `tools/strategy_farm/compare_joint_replay.py`.
Only at `match_rate == 1.0` does step 2 (10145) become admissible; only when step 2
admits 10145 at 1.0 **with the runner still 1.0 in the two-sleeve joint run** does this
step 3 (13301 + full-book measurement) become admissible.
