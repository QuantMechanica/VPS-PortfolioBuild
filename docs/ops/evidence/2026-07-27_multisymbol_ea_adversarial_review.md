# Adversarial review — multi-symbol OnTimer joint EA (QM5_20181, Step 1)

Date: 2026-07-27 · Branch `agents/board-advisor` · `C:\QM\repo` · Reviewer: Claude (adversary).
Posture: assume the multi-symbol timer EA is unfaithful; verify against SOURCE and ARTIFACTS,
never against the plan/SPEC claims. Default to REFUTED when uncertain.

## What is actually built (as of this review)

- Plan: `docs/ops/evidence/2026-07-27_multisymbol_timer_ea_plan.md` (design only).
- Shipped Step-1 EA: `framework/EAs/QM5_20181_ftmo-joint-multisym-timer/QM5_20181_ftmo-joint-multisym-timer.mq5`
  (422 lines) + `SPEC.md`, reusing `QM_Mod_FtmoJointRangeBreakout_20180.mqh` and
  `QM_Mod_FtmoJointEquitySampler_20180.mqh` UNCHANGED.
- Sets: `..._USDJPY.DWX_H1_backtest.set`, `..._USDJPY.DWX_H1_replay_runner.set`. No live/demo/ftmo set.
- Step-1 run is IN FLIGHT: `D:/QM/reports/joint_20181/` holds only the fresh control_9936
  `tester.ini` (started 17:13); `s0_runner/` and `harvest/` are empty. **No match_rate exists yet.**
- Steps 2–3 (the non-host `OnTimer` satellites) are NOT built. In the shipped EA the satellite
  registry is empty and the `OnTimer` dispatch loop body is comments (`...mq5:395-408`).

Both binaries are the SAME vintage: `QM5_9936...ex5` and `QM5_20181...ex5` mtime 2026-07-27 19:08;
9936 recompiled today (`framework/build/compile/20260727_170840/QM5_9936...compile.log`). This is
the fix the 20180 diagnosis demanded, and it holds for the Step-1 control.

## Bottom line

The Step-1 runner is faithful **by construction** and the classic 20180 cross-vintage control
defect is fixed for Step 1. But the review confirms one HIGH finding that the `match_rate == 1.0`
Step-1 gate cannot see, plus three MEDIUM findings about tooling and the unbuilt non-host path.
**The Step-1 gate proves the wrong thing relative to what OWNER is buying:** it proves the
instrument reproduces *today's* 9936, not the 9936 the Q09 book was measured on.

---

## SURVIVES (verified, not asserted)

1. **Runner exit fidelity by construction (attack #5).** The runner's per-tick management and
   exits run on `OnTick` from `QM_Mod_FtmoJointRangeBreakout_20180.mqh`, which is line-identical
   to standalone 9936: trailing-stop trigger (`module:283-344` vs `QM5_9936...mq5:321-383`),
   opposite-touch + 20:00 exit (`module:347-374` vs `9936:387-416`), entry (`module:237-280` vs
   `9936:267-317`). Same `_Symbol` BID/ASK reads, same H1 structural reads, same tick stream. The
   only textual deltas are reason strings (e.g. module `"FF_RANGE_CANCEL_HOUR"` vs 9936
   `"FF_RANGE_CANCEL_13_GMT3"`) which are order comments, ignored by the comparator
   (`compare_joint_replay.py:46-48`) and inert to execution. Exits reproduce exactly.

2. **The default entry path is byte-identical (attack #1).** Both runner legs open via
   `QM_TM_OpenPosition(req, ticket, explicit_magic=0)` (`module:272,279`). Verified that the 3-arg
   form with `explicit_magic=0, risk=0.0` reduces to `QM_Entry(req,ticket,0,0.0,default)` — the
   exact call the 2-arg default makes (`QM_TradeManagement.mqh:276-298`), and `magic==0` resolves
   `QM_MagicChecked(ea_id, symbol_slot=0, _Symbol)` = host magic (`QM_Entry.mqh:225-227`). Same as
   9936's `QM_TM_OpenPosition(req, ticket)` (`9936:312,550`).

3. **The equity sampler cannot perturb the trade stream (attack #1 self-perturbation).**
   `QM_FJ_Eq_OnTick` (`sampler:139-161`) and `QM_FJ_Eq_OnNewBar` (`:164-167`) only read
   `ACCOUNT_EQUITY` / `PositionGetDouble(PROFIT|SWAP)` and append to a SEPARATE file
   `QM\q08_equity\20181_USDJPY_DWX.jsonl` (`:94`). No trade call, no RNG draw. The entry-reject RNG
   is guarded off at stress 0 (`QM_Entry.mqh:264` requires `g_qm_entry_stress_reject_prob > 0.0`;
   set is 0.0). Adding `EventSetTimer(1)` + read-only file I/O does not change the deterministic
   Model-4 tick replay. `OnTick` order matches 9936 with only these read-only insertions
   (`...mq5:322-374`).

4. **No look-ahead in Step 1 (attack #3).** Host-only; every read is `_Symbol` on `OnTick`. No
   non-host `iClose`/`CopyRates` path exists yet (`...mq5:395-396` returns before any non-host read).

5. **No Step-1 idempotence exposure (attack #2).** `OnTimer` does zero trade work while
   `g_sat_count == 0` (`...mq5:395-396`); only the read-only equity sampler runs, which emits solely
   on a new intraday low / day rollover (`sampler:145-160`). Restart/history-refresh idempotence is
   moot: the EA refuses to init outside the tester (`...mq5:164-168`), so there is no live re-arm.

6. **Param binding is faithful (attack #1 prerequisite).** All 9 strategy params in the 9936 gated
   `backtest.set:38-46` (atr 14, range 1–6, cancel 13, close 20, min 0.4, max 2.5, trail 1.0, scan
   36) equal the 20181 `s0_*` bindings (`replay_runner.set:26-35`). The `qm_filter_*` lines in the
   9936 set are inert (no matching EA input). Both use EA-default two-axis news PRE30_POST30+DXZ.
   The 2.25 max-range neighborhood hazard the 20180 diagnosis flagged is NOT present (both 2.5).

7. **No live-capital path (attack #6).** `ea_id_registry.csv:4240` = `backtest-only`; refuses
   non-tester init, `RISK_PERCENT>0`, `prop_phase!=OFF`, `stress!=0` (`...mq5:164-188`); no
   live/demo/ftmo set exists. `RISK_FIXED` only.

8. **No magic collision (attack #6).** `magic_numbers.csv:15369-15370` = 201810000 (slot0/USDJPY),
   201810001 (slot1/XAUUSD), each appearing exactly once; formula `ea_id*10000+slot`, ea_id 20181
   newly reserved and unique. Kill-switch registers only slot 0 in Step 1 (`...mq5:259-264`).

9. **No shared include altered by THIS build that changes other pipeline EAs (attack #6).** The two
   `_20180` modules are included only by 20180/20181. `QM_MagicResolver.mqh` changed today is an
   additive regen from `magic_numbers.csv`. `QM_PropFirm.mqh` changed today is a SEPARATE FTMO
   initiative, and its OFF path short-circuits at the first statement
   (`QM_PropEntryAllowed`: `if(prop_phase==OFF || !initialized) return true;`), so the trade path of
   every OFF-phase EA (9936 included) is unchanged. The runner's magic ownership is via the explicit
   context list (`QM_Common.mqh:405-412`), independent of the basket flag.

10. **The pinned control is genuinely pinned for Step 1 (attack #1).** Fresh control_9936 `tester.ini`
    = USDJPY.DWX, H1, Model 4, 2017.01.01–2025.12.31, Deposit 100000, Leverage 100, same reserved
    terminal, 9936 gated `backtest.set`. Both binaries 19:08 today. The 20180 July-14-vs-July-27
    cross-vintage defect does not recur at Step 1.

---

## FINDINGS — most severe first

### F1 — HIGH — CONFIRMED. The Step-1 gate validates today's 9936, not the 9936 the book was measured on.
`match_rate == 1.0` at Step 1 compares 20181-runner against a FRESHLY-recompiled 9936 (both 19:08
today). That soundly proves module-extraction fidelity. It does NOT prove the instrument reproduces
the **Q09-admitted book**, because that book was measured on the DURABLE GATED 9936 stream, whose
binary is dated **2026-07-14** (`2026-07-27_joint_ea_fidelity_diagnosis.md:69-79`: executable SHA
`a1de7a7b…` last written 2026-07-14, 1252 trades). The composition
(`2026-07-27_runner_satellite_composition.md:9,13,19`; runner OOS FUND_SCORE 0.487, OOS wDD p90
9.290%; book rank-1 0.641 / 3.464%) was built from that gated pool
(`D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/9936_USDJPY_DWX.jsonl`, 1252 trades).

The 20180 diagnosis already established that July-14 vs July-27 vintages of 9936 produce SAME
entries with 77 SHIFTED exits (`:44-58`). Framework includes changed again today
(`QM_PropFirm.mqh`, `QM_MagicResolver.mqh`, both mtime 2026-07-27). So current-vintage 9936 very
likely does NOT reproduce the gated stream at 1.0 — meaning the instrument, admitted at Step-1
`match_rate == 1.0` vs fresh 9936, would trade a book whose OOS drawdown/return differ from the
numbers that justified building it.

- **Failure scenario:** Step 1 passes at 1.0. Steps 2–3 pass. The instrument's own Q08 stream goes
  to Q09 (plan `§6:428-429`). The book re-derived from the CURRENT-vintage instrument shows a
  different runner drawdown than `runner_satellite_composition.md` (which OWNER was shown), because
  the composition's runner curve was the July-14 exit path. OWNER approves a book measured on a
  9936 the instrument never reproduces.
- **Concrete check (cheap, do before Step 2):** diff the fresh control_9936 stream against the
  durable gated stream `9936_USDJPY_DWX.jsonl` (1252) with `compare_joint_replay.py`. If < 1.0, the
  runner drifted vintage and `runner_satellite_composition` MUST be recomputed at current vintage
  before its FUND_SCORE/wDD can be attributed to the instrument. This is the same class of drift the
  20180 diagnosis found; it is simply invisible to the Step-1 gate as designed (gate is fresh-vs-fresh).

### F2 — MEDIUM — CONFIRMED. The comparator was never extended with the mandated diagnostic categories.
The 20180 fidelity diagnosis §4 step 4 required: "Extend the comparator report with the five
categories in section 1 while retaining the exact `match_rate == 1.0` admission rule." The shipped
`compare_joint_replay.py` still reports only `matched / unmatched_joint / unmatched_gated /
match_rate` and a flat list of "no gated match" lines (`:99-109`); it does NOT categorize
same-entry/shifted-exit, same-close/different-net, joint-only, gated-only. The plan then leans on
exactly those categories twice — the ≤1 s non-host entry-quantisation refinement decision
(`plan §3:279-283`) and the early-detection story (`plan §7 risk 1:435-442`) both say "diagnosed via
the diagnostic categories the 20180 review told us to add."
- **Failure scenario:** a Step-2 XAUUSD run scores 0.98. The operator sees only opaque "no gated
  match" lines — the precise presentation the diagnosis condemned — and cannot cheaply tell a benign
  ≤1 s same-bar entry shift from a real exit-drift defect, so either relaxes the gate on a hunch or
  stalls. Does not bite Step 1 (expected exactly 1.0), so it is MEDIUM, but it must land before Step 2.

### F3 — MEDIUM — CONFIRMED (unproven risk). The Step-2 basket-mode flip breaks the mode the Step-1 1.0 was measured in.
Step 1 runs single-symbol mode (`basket_mode=false`, `...mq5:222`); the header itself states warming
a second symbol "would flip the framework to basket ownership (QM_Common.mqh:414-431) and perturb
the very path the 1.0 gate measures" (`...mq5:61-70`). So the Step-1 `match_rate == 1.0` is a
single-symbol-mode result; the actual book runs in BASKET mode. The plan's own regression check
(`§6:377-380`, re-diff every admitted sleeve after adding one) is the only guard and has not run.
The runner's magic ownership survives the flip via the explicit-context path
(`QM_Common.mqh:405-412`), which is reassuring, but every other basket-gated framework behaviour
(`QM_SymbolGuardIsBasket()` branches, history-sync scope, MAE ownership `:414-431`) is unverified
against the runner.
- **Failure scenario:** Step 2 enables XAUUSD, basket mode activates, and the runner's slot-0 trades
  shift versus its own Step-1 stream — the "already-admitted sleeve still 1.0" regression fails, and
  the piece-by-piece guarantee ("admitted at 1.0 stays at 1.0") is void. REFUTED as *proven-safe*;
  CONFIRMED as a real, currently-unmeasured risk.

### F4 — MEDIUM — NOT ESTABLISHED. The entire non-host machinery is declared but unexercised.
The plan asserts reuse of existing multi-symbol machinery (`QM_SymbolGuardInit`,
`QM_BasketWarmupHistory`, symbol-aware basket order path, per-sleeve news `symbol_slot`, per-symbol
`QM_IsNewBar`). In the shipped EA NONE of it runs: `basket_mode=false`, no `QM_SymbolGuardInit`, no
warmup, and the satellite loop is an empty stub (`...mq5:395-408`). Therefore for the non-host path,
idempotence (attack #2), look-ahead (attack #3) and isolation (attack #4) are NOT ESTABLISHED — they
rest on the 3-simulated-day `ontimer_probe` (RECON A) and static analysis, not on this instrument.
The one structural hazard to watch when it IS built: `QM_IsNewBar` is a single MUTATING global latch
keyed `"sym|tf"` (`QM_Indicators.mqh:108-137`) — whichever handler calls a given key first consumes
the new-bar edge. The plan's disjoint-key partition (host `USDJPY|H1` on `OnTick`, satellites on
`OnTimer`) is a discipline, not an enforced invariant; the 12969 fallback (a co-hosted USDJPY sleeve)
is where that partition is easiest to violate and must be checked at build time, not assumed.

### F5 — LOW/MEDIUM — CONFIRMED (process). The hand-authored EA source is uncommitted.
`git status`: `?? framework/EAs/QM5_20181_.../QM5_20181_....mq5` and `SPEC.md` are untracked. The
build pump has previously swept hand-authored source into unlabeled "build: pump auto-commit"
commits (repo memory; recent `git log`). Commit the Step-1 source under a semantic label with
explicit pathspecs before the next pump, or its provenance is lost.

---

## Attack-vector verdicts

| # | Vector | Step 1 verdict | Notes |
|---|---|---|---|
| 1 | Fidelity control soundness | control SOUND; gate scope WRONG → **F1 (HIGH)** | fresh-vs-fresh pinned; but not vs the gated book stream |
| 2 | Idempotence | REFUTED (no exposure) for Step 1; NOT ESTABLISHED for steps 2–3 (**F4**) | timer does no trade work at `g_sat_count==0` |
| 3 | Look-ahead | REFUTED for Step 1; NOT ESTABLISHED for steps 2–3 (**F4**) | host-only OnTick; probe-only evidence for non-host |
| 4 | Isolation | REFUTED for Step 1 (single sleeve); **F3 (MEDIUM)** risk at Step 2 | basket-mode flip unmeasured |
| 5 | Exit reproduction | REFUTED (exits faithful by construction) | line-identical module on host ticks; comparator keys close_time+net |
| 6 | Live path / magic / dirs / includes | REFUTED (all clean) | backtest-only, unique magics, additive regen, OFF path inert |

Tooling: comparator lacks the mandated diagnostic categories → **F2 (MEDIUM)**.

## Recommended gates before proceeding

1. **Before trusting any Step-1 1.0:** confirm the pending `s0_runner` run uses the identical
   2017.01.01–2025.12.31 / Model 4 / Deposit 100000 window as the control (verified for control_9936;
   pending for the joint side).
2. **F1:** diff fresh control_9936 vs the durable gated `9936_USDJPY_DWX.jsonl` (1252). If < 1.0,
   recompute `runner_satellite_composition` at current vintage before attributing its numbers to the
   instrument, or state explicitly that the instrument's book will be re-derived at Q09 and the
   composition figures are indicative only.
3. **F2:** extend `compare_joint_replay.py` with the five diagnostic categories (retaining the exact
   1.0 gate) before Step 2, so the XAUUSD run's mismatches are legible.
4. **F3:** treat the first two-sleeve run as a runner-regression test — re-diff slot 0 against its
   Step-1 stream and require 1.0 in BASKET mode, not just single mode.
5. **F5:** commit `QM5_20181_....mq5` + `SPEC.md` under a semantic label now.
