# Goal implementation — unblocks executed toward a 3-sleeve joint P(pass) answer

**Date:** 2026-07-28 (~13:00 UTC, live-verified against `farm_state.sqlite` and the tree)
**Author:** Claude (board-advisor worktree)
**Goal (OWNER, verbatim):** *"Ziel ist, dass der FTMO Backtest EA endlich gefahren werden
kann und wir sehen, ob er das Bestehen einer Challenge wahrscheinlicher macht!"*

Executes the unblock actions assigned to this workflow by
`2026-07-28_goal_blocker_chain.md` (60380f0e4) and
`2026-07-28_measurement_preregistration.md` (409a3986b). The third doc named in the
task brief — `2026-07-28_throughput_truth.md` — **does not exist in the tree**; the
authoritative operational doc is the blocker chain, and this implementation follows it
where it differs from the task's STATE brief. All evidence is file/query/command, not
inference.

---

## Summary of what this workflow changed

| # | Item | Result |
|---|---|---|
| 1 | Vintage probe q08 sign-off | **DONE.** Probe already ran (both arms done); `f0301ecf` signed off NON-CAUSAL at q08 event level. |
| 2 | 2-sleeve (9936+10145) governed run | **ENQUEUED** — item `c0192be6-2490-4f3b-ae1e-48bf6922d9e6`, priority-track, staged EX5. |
| 3 | 3-sleeve third member | **DECIDED = 13108**; enqueue **BLOCKED** on Codex slot-2 EA build (B1) + step-2 fidelity admission. |
| 4 | Throughput fix (age escalation) | **VERIFIED biting** (already landed a4bea4483); no new mutation needed. |
| 5 | Runner-alone P(pass) baseline | **RECOMPUTED** on fresh vintage, truncated window. First-passage **85.1%** (full window). |

No terminal was launched, no history imported, T5/T_Live untouched. One governed
priority item was enqueued; no other work-item row was mutated (the pre-existing pending
Q03 runner-only cascade `f8a90af2` was left untouched).

---

## Item 1 — vintage probe: DONE and NON-CAUSAL (differs from task STATE)

The task STATE said the probe pair was "governed-queued but DEFERRED by an active USDJPY
lock." The **blocker chain (newer) supersedes this**: both arms already ran. Verified in
`farm_state.sqlite`:

- Parent `f0301ecf^` (commit `c0918247`, staged EX5 sha `f46b73c7…`): work item
  `9f79065c-87ed-4f00-97e5-70c32e2d55f1`, QM5_9936 USDJPY.DWX Q02, **status=done**,
  created 10:20:50Z → updated 10:44:46Z.
- Child `f0301ecf` (canonical tip) = step-1 fresh standalone
  `588af557-300f-4e25-82a4-81974b04380a`, **status=done**.

So the probe did not "need executing" — the remaining action (blocker chain §B0 unblock)
was the **q08-level sign-off**. `compare_joint_replay.py` requires harvested
`TRADE_CLOSED` streams (net/volume); the parent arm's harvested stream lived in volatile
FILE_COMMON and is now overwritten by the child, so a direct `compare_joint_replay` run is
not reproducible. Both arms' **full event loggers (10,961 rows each)** are durably
retained, and `TRADE_CLOSED` is derived from those same ENTRY/TM_OPEN/TM_CLOSE events, so
a deterministic event-stream diff is the strongest terminal-free q08-equivalent sign-off.

**Result (reproducible; script inline in this cycle):**

- rows each: 10,961
- full-stream line diffs (dropping non-deterministic `ts_utc`): **2** — both are the
  news-calendar snapshot (`NEWS_TESTER_CALENDAR_SELFTEST`, `NEWS_CALENDAR_LOADED`), not code
- **trade-event multiset symmetric difference: 0** over 8,951 trade events per arm
- **Verdict: `f0301ecf` (the prop-firm include) is NON-CAUSAL at the q08 event level.**

Therefore the 72 shifted exits + ~25 entry diffs (fresh-vs-archive) are **archived-vintage
news-calendar drift**, not the prop-firm wrapper, confirming `2026-07-28_vintage_bisect.md`.
Streams:
`…/9f79065c…/QM5_9936/20260728_103040/logger_sample.jsonl` vs
`…/588af557…/QM5_9936/20260727_215505/logger_sample.jsonl`.

---

## Item 2 — 2-sleeve (runner 9936 + satellite 10145) governed run — ENQUEUED

The repaired 20181 binary **already supports slot-1 (10145)** (`…mq5:284-306`, sleeve fn
`QM20181_Run10145 :359`), so a 2-sleeve run needs **no source change** — only a set with
`s1_enabled=1` (blocker chain §B2).

**Fidelity of the satellite parameterisation (checked, not assumed):** the EA exposes
`s1_lookback_n / s1_atr_period / s1_atr_stop_mult / s1_shorts_enabled / s1_min_abs_mean_return`
as overridable inputs. The QM5_10145 EA's own defaults are `15 / 14 / 3.0 / false / 0.0`
(`QM5_10145_tsm-meanret.mq5:76-80`), and the canonical 10145 XAUUSD **base** backtest set
overrides none of them (`…_XAUUSD.DWX_D1_backtest.set`). The set below writes exactly
those values, so slot-1 is a faithful standalone-10145 XAUUSD replay for the §6.2 fidelity
gate.

**Artifacts (SHA256 recorded):**

| artifact | value |
|---|---|
| set file | `framework/EAs/QM5_20181_ftmo-joint-multisym-timer/sets/QM5_20181_ftmo-joint-multisym-timer_USDJPY.DWX_H1_book2_9936_10145.set` |
| set sha256 | `7d2a061f27372c2fd489e2a58867e7b7208461f70581c95dd1a1ab94fd5d312d` |
| EA ex5 sha256 (staged) | `60ee13b7828ca2ddda11a1264cb2391ea2283da9af034915895d3de4852221f9` |
| EA mq5 sha256 | `f102f6208c30804d20ff725c8d52669268a5b142ffc431f212a91788589fe11f` (unchanged since step-1 a343f66e) |
| staged EX5 path | `D:\QM\strategy_farm\artifacts\ex5_staging\step2_2sleeve_9936_10145\QM5_20181_ftmo-joint-multisym-timer.ex5` |

**Work item (governed, priority-track, immutable staged-EX5 contract da0183209/41372ec98):**

- **id: `c0192be6-2490-4f3b-ae1e-48bf6922d9e6`** · kind=backtest · phase=Q02 · ea_id=QM5_20181
- `measurement=multisym_step2_2sleeve_9936_10145`, `basket_symbol_count=2`,
  `portfolio_scope=basket`, `priority_track=true`, `evidence_binding_required=true`,
  `evidence_provenance=real_mt5`
- `expected_symbol=USDJPY.DWX`, `expected_period=H1`, `from_date=2018.07.02`,
  `to_date=2025.12.31`, Model 4, `timeout_min=150`, `skip_terminals=[T5]`
- `staged_ex5_sha256` == `expected_ex5_sha256` == `60ee13b7…` (binary pinned before/after run)

Payload contract replicates the KNOWN-GOOD step-1 `a343f66e` (which produced runner
fidelity 1.000000). A dedup guard confirmed no pre-existing step-2 item.

**Admission ETA:** the USDJPY symbol lock is **currently free** and no multisym is active
(live at ~13:00 UTC), so this priority-track item admits as soon as the claim loop reaches
a free terminal — realistically **minutes to ~1–2 h** (step-1 priority items admitted in
~20–40 min against 2,450+ pending). It serialises behind any USDJPY holder / active
multisym via the passive interlock (`terminal_worker.py:1122-1125,1185-1194`).

---

## Item 3 — 3-sleeve third member: DECIDED = 13108; enqueue BLOCKED (differs from task STATE)

**Decision (blocker chain §B3-decision, confirming over the repair doc's 13301):
slot-2 = 13108 (timer-safe, deployable).** 13301 uses per-tick structural trailing
(`QM5_13301…mq5:344-397`) that the joint EA's `OnTimer(1)` cannot reproduce → it would be
a *different* strategy than the standalone that scored OOS 0.641, i.e. an **undeployable**
book. 13108 gates management/exit/entry behind its D1 new-bar latch
(`QM5_13108_xti-mtsm-s2.mq5:379-397`) → timer-safe; it is the highest-OOS timer-safe
composition retaining 9936+10145: rank-17 `9936+10145+13108`, OOS FUND_SCORE **0.527**.

**Why this workflow cannot enqueue step 3:** the 20181 **source wires only ONE satellite**
(`…mq5:284` `g_sat_count = s1_enabled ? 1 : 0`; only `QM20181_Run10145` exists). There is
no slot-2 path, so a 3-sleeve run against the current binary would silently run 2 sleeves.
Wiring slot-2 (B1) is a **Codex-lane EA build** (`s2_*` input group, `Run13108` sleeve fn,
kind-dispatched `OnTimer`, `g_sat_count`→2, eqmagics[2], recompile → new ex5 SHA). Even the
3-sleeve set cannot be finalised until the binary exposes `s2_*` inputs. The fidelity-gate
discipline also holds: **step 3 runs only after step 2 admits 10145 at the agreed match
threshold** (§6.2).

**13108 canonical config recorded so the future s2 set is trivial to author**
(`…_XTIUSD.DWX_D1_backtest.set`): symbol `XTIUSD.DWX`; `strategy_momentum_days=30`,
`strategy_partial_moment_days=5`, `strategy_percentile_history=252`,
`strategy_tail_percentile=80.0`, `strategy_atr_period=20`, `strategy_atr_sl_mult=3.0`,
`strategy_max_hold_days=8`, `strategy_max_spread_points=1500`, `RISK_FIXED=1000`,
`RISK_PERCENT=0`. (13108 holds up to 8 days → multi-day; the P(pass) models handle span via
`entry_time`/MAE.)

**PENDING → gated on:** (a) Codex B1 slot-2 build (new ex5 SHA), then (b) step-2 fidelity
admission. **ETA:** governed by the Codex lane, not this workflow.

---

## Item 4 — throughput: age escalation VERIFIED biting (no new code)

The named throughput doc does not exist; the blocker chain's only throughput item is queue
latency (§B4), already handled by priority-track. The task's example — "age escalation not
biting" — was already **implemented and tested** by Codex in `a4bea4483` (claim-time
effective priority `priority_track*10 + phase_rank − whole_age_weeks`; 32 tests pass). The
open question was whether it actually *bites* given the stored `created_at` format.

**Verified against live data** (`farm_state.sqlite`): SQLite `julianday()` correctly parses
the stored ISO8601-with-offset format (e.g. `2026-05-23T15:22:09.189623+00:00` →
`age_weeks=9`), and **2,097 of 2,440 pending rows carry a nonzero age credit** (max 9
weeks). The escalation is functioning as designed; nothing has crossed the 16-week Q02↔
priority-Q08 parity threshold yet, but the mechanism is live and biting. **No new mutation
made** — inventing a change here would violate the no-unnecessary-mutation constraint.

---

## Item 5 — runner-alone P(pass) baseline, recomputed on the FRESH vintage

Per preregistration §2.2, the runner (Arm R) baseline must be recomputed on the truncated
common window from the fresh slot-0 stream, **not** the archived stale-calendar file. The
runner slot-0 is proven 1.000000 identical to standalone 9936 at the same vintage, so the
fresh standalone `588af557` stream is the valid Arm-R proxy the task directs us to use.

**Input:** fresh 9936 USDJPY.DWX q08 TRADE_CLOSED stream harvested from the 588af557 run —
1,143 rows, `sum(net)=132405.79` (matches `2026-07-28_vintage_bisect.md`),
2018-07-06..2025-12-30, `entry_time`+`mae_acct` present. Stable copy:
`D:\QM\reports\work_items\588af557-…\QM5_9936\20260727_215505\q08_trades_9936_USDJPY_DWX.fresh.jsonl`
(sha256 `352b9e3ed8ed705431753e1106aaffcf1842beef984740adfca6016cf45ce733`).

**Method:** first-passage algorithm copied **verbatim** from
`challenge_firstpassage.outcomes()` (:157-235), single sleeve at 1× (the preregistered
policy), window 2018-07-02..2025-12-31. Script (committed):
`tools/strategy_farm/portfolio/recompute_runner_alone_baseline.py`.

**PRIMARY KPI — first passage (+10% before −5%/day or −10% total, no deadline), 1×:**

| framing | P(pass) | pass/breach/censored | median d | ESS | 95% band (pp) |
|---|---:|---|---:|---:|---|
| **full truncated window (all 1,142 starts)** | **0.851** | 972 / 135 / 35 | 52 | 21 | [69.9, 100.3] |
| OOS split (SPLIT=0.60, from 2022-11-30, 457 starts) | 0.718 | 328 / 94 / 35 | 40 | 11 | [45.2, 98.4] |

The OOS-split **71.8%** brackets the prior published archived-vintage **75.3%** (same
estimator, later starts) — confirming the estimator is consistent and the gap to the
full-window 85.1% is the **window**, not the vintage. The full-window **85.1%** is the
preregistered Arm-R anchor for the paired comparison.

**SECONDARY KPI — 60/30 deadline sprint, 1× (OWNER objective, NOT an FTMO rule):**
P(pass) = **3.06%** (funded 35; decomposition p1_expired 893, p1_breach 23, p2_expired
165, p1_censored 26). Consistent with the pool being 1–2 orders short of a 60/30 sprint
edge at 1× — the whole reason first-passage is the primary KPI.

**Bottom line for the Answer agent:** at 1× — the only deployable sizing — the runner alone
already carries **~85%** first-passage P(pass) on the fresh vintage. Per preregistration §1
(ESS ~9–21, paired clear-zero bar ~10–16 pp) and the +13 pp prior point estimate, the most
probable joint-book verdict is **(C) indistinguishable**: the composed book raises the
point estimate modestly but not resolvably at this horizon. The joint run measures whether
Arm B clears that bar.

---

## What remains pending

| item | blocked on | owner | ETA |
|---|---|---|---|
| Step-2 run result + slot-1 fidelity gate | queue admission (USDJPY free now) | governed queue | minutes–~2 h |
| Slot-2 (13108) EA build (B1) | source wire `s2_*` + recompile | **Codex lane** | Codex-scheduled |
| Step-3 3-sleeve enqueue | B1 build **and** step-2 fidelity admission | this workflow (after B1) | after both gates |
| Paired first-passage P(pass) verdict | step-2 (and step-3) joint run harvest | Answer agent | after runs |

## Evidence index

- Probe done + non-causal: `farm_state.sqlite` work_items `9f79065c` (done), `588af557` (done);
  event-diff over the two `logger_sample.jsonl` (2 diffs, both news; trade-event symdiff 0).
- Step-2 enqueue: work item `c0192be6-2490-4f3b-ae1e-48bf6922d9e6`; set sha `7d2a061f…`;
  staged ex5 sha `60ee13b7…`; staged path under `D:\QM\strategy_farm\artifacts\ex5_staging\step2_2sleeve_9936_10145\`.
- Satellite fidelity params: `QM5_10145_tsm-meanret.mq5:76-80`; base set overrides none.
- Slot-2 decision: `2026-07-28_goal_blocker_chain.md` §B3-decision; `QM5_20181…mq5:284`;
  13108 params `…_XTIUSD.DWX_D1_backtest.set`.
- Age escalation: `a4bea4483`; `farmctl.pending_claim_order_sql`; live 2,097/2,440 pending
  rows nonzero age credit (max 9 wk).
- Runner-alone baseline: `tools/strategy_farm/portfolio/recompute_runner_alone_baseline.py`;
  fresh stream sha `352b9e3e…`; first-passage full-window 0.851 / OOS-split 0.718; 60/30 0.031.
