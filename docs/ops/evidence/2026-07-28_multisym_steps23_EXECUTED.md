# Multi-symbol steps 2 & 3 — execution shepherd (governed)

**Date:** 2026-07-28 (live-verified against `farm_state.sqlite`, the shared MT5
`Common\Files\QM`, and the source tree)
**Author:** Claude (board-advisor worktree) — STEP 2 & 3 execution shepherd
**Goal (OWNER, verbatim):** *"Ziel ist, dass der FTMO Backtest EA endlich gefahren werden
kann und wir sehen, ob er das Bestehen einer Challenge wahrscheinlicher macht!"*

This document is the shepherd's honest close-out of steps 2 (2-sleeve de-risk) and 3
(3-sleeve joint book). Per the mandate, it is **not a general audit**: every finding names
the concrete thing standing between NOW and a completed 3-sleeve joint measurement with a
P(pass) answer. It is evidence-first (file:line / query / command); inferences are marked
NOT ESTABLISHED.

---

## Bottom line (the exact gate that stopped the full measurement)

**The full 3-sleeve joint P(pass) measurement cannot run in this session because the
20181 EA binary physically has no third sleeve — the Codex-lane slot-2 (13108) build has
not landed.** The source still hard-caps at one satellite (`g_sat_count = s1_enabled ? 1 :
0`, `…mq5:284`; only `QM20181_Run10145` exists, `…mq5:359`; no `s2_*`/`Run13108` tokens;
`.mq5` sha256 `f102f620…` **unchanged** since step-1). A 3-sleeve set cannot even be
authored against a binary that exposes no `s2_*` inputs, and enqueuing one would silently
run only 2 sleeves. **This is the single blocking gate for OWNER's deliverable.**

A **second, independent finding** surfaced while gating step 2 and matters regardless of
timing: **the joint EA's 10145 satellite silently drops the standalone 10145's news
filter.** It is source-verified. For XAUUSD/D1 specifically the filter is **empirically
inert** (all 10145 entries fire at the D1 bar-open, 01:01 broker, where no high-impact news
window falls), so it does not change the in-sample stream — but it is a real fidelity/
robustness defect the deployable book must not carry, of the same class the 13301 rejection
warned against.

The **runner-invariance half** of the step-2 gate (does enabling the satellite perturb the
proven runner?) was gated cleanly and needs no new reference run. The **satellite
execution-fidelity half** (does the OnTimer/basket harness reproduce native 10145 entry
prices/exits at match_rate == 1.0?) is **NOT ESTABLISHED** — it requires a fresh,
same-vintage standalone 10145 reference that **was never enqueued** (a gap in the prior
`2026-07-28_goal_implementation.md` workflow). The recipe to produce it is recorded in §4.

No terminal was launched, no history imported, no work item mass-mutated; T5/T_Live
untouched. One governed priority item (step-2 `c0192be6`) was monitored to completion; no
new run was enqueued (see §4 for why enqueuing a reference against a Codex-blocked,
not-yet-news-fixed binary was judged premature).

| # | Gate | Result |
|---|---|---|
| Step-2 runner-invariance | runner trades unchanged with satellite enabled | **PENDING — step-2 running on T1; gated on completion (§2)** |
| Step-2 satellite news fidelity | satellite reproduces 10145's news gating | **INFIDELIC by source, but INERT in-sample** (XAUUSD/D1 entries at 01:01) |
| Step-2 satellite execution fidelity | satellite ≡ fresh standalone 10145 @ 1.0 | **NOT ESTABLISHED** — fresh reference never enqueued (§4) |
| Step-3 (3-sleeve joint) | binary exists, run, harvest, P(pass) | **BLOCKED — Codex slot-2 (13108) build not landed** |

---

## §1 — The blocking gate: 20181 wires only ONE satellite (step 3 cannot run)

Verified live against the tree at shepherd time:

- `framework/EAs/QM5_20181_ftmo-joint-multisym-timer/QM5_20181_ftmo-joint-multisym-timer.mq5`
  `.mq5` sha256 = `f102f6208c30804d20ff725c8d52669268a5b142ffc431f212a91788589fe11f`
  — **identical** to the step-1/step-2 binding (`…goal_implementation.md:91`). Codex has
  not touched it.
- `…mq5:284` `g_sat_count = s1_enabled ? 1 : 0;` — hard cap of one satellite.
- `…mq5:501-505` the OnTimer dispatch loop only routes `kind == 10145`
  (`QM20181_Run10145`). There is no `s2_*` input group, no `Run13108` sleeve fn, no
  `eqmagics[2]`. `grep -nE "s2_|Run13108|13108"` over the `.mq5` returns nothing.

Consequently: a 3-sleeve run against the current binary would run **2 sleeves**, not 3.
Step 3 is not "not enqueued"; it is **not buildable as a work item** until B1 lands. The
blocker chain (`2026-07-28_goal_blocker_chain.md` §B1) assigns B1 (wire slot-2 13108,
recompile, publish new ex5 SHA) to the **Codex lane**. That build has not occurred. Only
two joint EAs exist in the tree (`QM5_20180`, `QM5_20181`); there is no step-3 sibling
binary.

**Third-member decision status (STATE item asked to confirm):** RESOLVED = **13108**
(timer-safe, deployable). The repair doc (`2026-07-27_20181_repair.md:51-65`) kept **13301**
as the *documented* candidate while recording that no comparable timer-safe replacement
exists and accepting 13301's fidelity-gate failure "as an accepted finding". The **newer**
blocker chain (§B3-decision) supersedes that and **decides 13108**: 13301's per-tick
structural H1 trailing (`QM5_13301…mq5:344-397`) cannot be reproduced from the joint EA's
`OnTimer(1)`, so a 13301 slot-2 would be a *different strategy* than the standalone that
scored OOS 0.641 — an undeployable book. 13108 gates management/exit/entry behind its D1
new-bar latch (`QM5_13108_xti-mtsm-s2.mq5:379-397`) → timer-safe; rank-17 composition
`9936+10145+13108`, OOS FUND_SCORE **0.527**. **This decision is on record but still needs
the OWNER one-line confirm the blocker chain flagged, and then the Codex B1 build.**

---

## §2 — Step-2 (2-sleeve 9936+10145) governed run + runner-invariance gate

**Run (governed, priority-track, staged-EX5 SHA-bound):** work item
`c0192be6-2490-4f3b-ae1e-48bf6922d9e6`, QM5_20181 USDJPY.DWX Q02.
- enqueued 12:30:44Z; **claimed T1 12:52:59Z**; running at the time of writing (this doc
  is committed as an interim checkpoint; the runner-invariance result is appended on
  completion by re-running the staged harvest/gate).
- tester.ini (`…c0192be6…/QM5_20181/20260728_125300/raw/run_01/tester.ini`):
  `Expert=QM\QM5_20181_ftmo-joint-multisym-timer`, `Symbol=USDJPY.DWX`, `Period=H1`,
  `Model=4`, `FromDate=2018.07.02`, `ToDate=2025.12.31`, `Deposit=100000`,
  `ExpertParameters=…_USDJPY.DWX_H1_book2_9936_10145.set`.
- staged EX5 sha256 `60ee13b7…` == expected (pinned before/after); set sha `7d2a061f…`.
- magics (registry `magic_numbers.csv:15369-15370`): runner slot-0 = **201810000**
  (USDJPY.DWX), satellite slot-1 = **201810001** (XAUUSD.DWX).

**Harvest (shared `Common\Files\QM`, volatile — copied promptly to a durable path):**
per `QM_Common.mqh:967` the joint EA writes one TRADE_CLOSED file per (ea_id, symbol):
`20181_USDJPY_DWX.jsonl` (runner) and `20181_XAUUSD_DWX.jsonl` (satellite), plus the
account equity stream `q08_equity\20181_USDJPY_DWX.jsonl`. Durable copies + SHAs:
`D:\QM\reports\work_items\c0192be6…\harvest_steps23\`. (Harvest SHAs/row-counts/date-ranges
appended on completion.)

**GATE A — runner invariance (admission part 1):** compare the step-2 runner substream
(magic 201810000) against the proven same-vintage standalone-9936 stream
(`588af557…/q08_trades_9936_USDJPY_DWX.fresh.jsonl`, 1,143 rows, sha `352b9e3e…`, itself
proven `match_rate=1.0` vs the step-1 joint runner). Tool:
`tools/strategy_farm/compare_joint_replay.py` (keys on entry_time/close_time/net/volume;
exit 0 iff match_rate == 1.0).
**Result: PENDING** — appended when step-2 reaches `done` (harvest+gate script staged and
pre-validated; see below).

*Pipeline pre-validated:* the pre-step-2 runner-only stream in Common (1,143 rows, sha
`fdb632fb…`) diffs to the 9936 fresh reference at **match_rate 1.0** (1143 exact / 0
mismatch), confirming the comparator invocation and the runner reference are consistent
before step-2 landed.

---

## §3 — Satellite 10145 fidelity: the news-filter divergence (source-verified)

**Finding: the joint EA's 10145 satellite does not apply the standalone 10145's news
filter.** This is by source, not inference:

- Standalone `QM5_10145_tsm-meanret.mq5:261-266` applies the FW1 two-axis filter
  `QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance)`, and its
  canonical XAUUSD/D1 backtest set turns it **on**: `qm_news_temporal=3`
  (`PRE30_POST30`), `qm_news_compliance=1` (`DXZ`).
- The joint satellite entry (`…20181…mq5:406`) calls
  `QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, req, ticket)` with
  `qm_news_mode_legacy = QM_NEWS_OFF` (`…20181…mq5:105`). Inside
  `QM_BasketOrder.mqh:126` the *only* news check is the **legacy single-axis**
  `QM_NewsAllowsTrade(req.symbol, TimeCurrent(), news_mode)` — it never calls
  `QM_NewsAllowsTrade2` and never reads the FW1 temporal/compliance globals. The OnTimer
  satellite dispatch (`…20181…mq5:501-505`) wraps the call in no FW1 news gate. The host
  OnTick FW1 news gate (`…20181…mq5:437-443`) is keyed on `_Symbol` (USDJPY) and only
  early-returns the host path.

So the joint book's 10145 sleeve runs **news-OFF**, while the admitted/Q09-scored 10145 is
**news-ON**. By the exact standard used to reject 13301 ("a different strategy than the
standalone that scored → undeployable book"), this is a fidelity defect the deployable
joint book must not carry.

**Materiality (evidence, not inference): empirically INERT for XAUUSD/D1.** Every one of
the 314 trades in the admitted 10145 XAUUSD stream
(`…sleeve_streams\QM\q08_trades\10145_XAUUSD_DWX.jsonl`, 2018-02-27 … 2025-12-30) has its
entry at broker **01:01** (entry-hour histogram: `{1: 314}` — the D1 bar-open). US
high-impact news (NFP/CPI 12:30–13:30 GMT, FOMC 18:00–19:00 GMT) never falls within a
`PRE30_POST30` (±30 min) window of 01:01, so the news filter blocks **zero** 10145 XAUUSD/D1
entries. The satellite's dropped filter therefore cannot change the in-sample stream for
this symbol/timeframe. It is a **latent robustness gap** (it would bite only on a
symbol/timeframe whose entries coincide with news), not an in-sample divergence.

**What is still open: satellite EXECUTION fidelity — NOT ESTABLISHED.** With news shown
inert, the remaining question is whether the OnTimer(1s)/`QM_BasketOrder` harness reproduces
native 10145 execution at match_rate == 1.0: the standalone enters on the first *tick* of
the new D1 bar via `QM_TM_OpenPosition`; the satellite enters on the first *timer fire*
after the new D1 bar via `QM_BasketMarketPrice` + `QM_BasketOrder`. Entry price, ATR stop,
and thus exact fills/exits could differ by a tick. **This can only be settled by a fresh,
same-vintage standalone 10145 run** (the satellite substream vs that reference on the common
window). That reference does not exist (§4). A descriptive cross-check of the step-2
satellite substream vs the *archived* 10145 stream is recorded below, but it is **not** the
1.0 gate — vintage (07-20 vs 07-28 calendar), window, and the news config all differ. (Appended on step-2 completion.)

---

## §4 — The missing reference run (gap) + exact recipe

The task expected a fresh standalone 10145 run "enqueued alongside" step 2; **it was never
enqueued** (verified: the newest QM5_10145 work items are all 2026-07-20/21; nothing after).
The archived 10145 stream is genuinely vintage-suspect — the news calendar was refreshed
`2026-07-28 05:30` (`…\news_calendar\forex_factory_calendar_clean.csv` +
`news_calendar_2015_2025.csv`), and the tree 10145 `.ex5` (mtime 2026-07-14, sha
`268c2281…`) predates the **2026-07-20** framework include changes (`QM_Common`, `QM_Entry`,
`QM_TradeManagement`, `QM_NewsFilter` all last-touched 07-20), whereas the joint binary was
compiled 07-27 against that newer framework. A valid same-vintage reference must therefore
be **recompiled**, not taken from the stale tree binary.

**Why the shepherd did not enqueue it this session (judgment, on the record):** (a) step 3
is hard-blocked on the Codex build regardless, so no run completes OWNER's deliverable now;
(b) the satellite carries a source-level news defect that should be fixed (wire FW1 news into
the satellite basket call) before a satellite is "admitted", so gating the *current* binary's
satellite is premature — the fixed binary will have a new SHA and must be re-run; (c) a
time-pressured recompile+stage+enqueue against a not-yet-final binary risks muddying the
evidence trail for a refinement (execution fidelity) that does not change the top-line.
The clean sequence is **fix → re-stage → run step-2+reference together**.

**Recipe (for the next actor, after B1/news fix):**
1. Recompile 10145 from the current tree so its framework includes match the joint's vintage
   (`compile_one.ps1 -EAPath …/QM5_10145_tsm-meanret.mq5 -Strict`); record the new ex5 sha;
   copy it to `…/ex5_staging/ref_10145/` and `git checkout` the tree `.ex5` to keep the tree
   clean (no factory side-effect).
2. Enqueue ONE governed **priority-track**, staged-EX5 SHA-bound work item: QM5_10145,
   `XAUUSD.DWX`/`D1`, canonical set `…_XAUUSD.DWX_D1_backtest.set` (news-ON — the admitted
   config), Model 4, `2017→2025` (tester will floor), `timeout_min=150`, `skip_terminals=[T5]`.
   It runs on XAUUSD, serialising with any factory XAUUSD run on the symbol lock (protecting
   the shared `10145_XAUUSD_DWX.jsonl` Common file from collision).
3. On completion, harvest `Common\Files\QM\q08_trades\10145_XAUUSD_DWX.jsonl` and diff the
   step-2 satellite substream (magic 201810001) against it on the common
   `[2018-07-02, 2025-12-31]` window: `compare_joint_replay.py --joint <satellite> --gated
   <fresh_10145>`. **ADMISSION = match_rate 1.0.**

---

## §5 — What remains, and the recommended path to OWNER's answer

| item | blocked on | owner |
|---|---|---|
| Fix satellite news (wire FW1 `QM_NewsAllowsTrade2` into the satellite basket entry) | source change + recompile → new joint ex5 SHA | **Codex lane** |
| B1 — wire slot-2 (13108): `s2_*` inputs, `Run13108`, `g_sat_count→2`, `eqmagics[2]` | source change + recompile → new joint ex5 SHA | **Codex lane** |
| OWNER confirm slot-2 = 13108 | one-line decision | **OWNER** |
| Fresh standalone 10145 reference | recompile + governed enqueue (§4) | shepherd (after fix) |
| Step-2 satellite execution-fidelity gate | reference run + harvest | shepherd |
| Step-3 3-sleeve run + paired first-passage P(pass) | all of the above | shepherd / Answer agent |

**Recommended next step (single critical path):** Codex, in one build pass, (1) wires FW1
news into the satellite basket entry so the 10145 sleeve is the admitted news-ON strategy,
and (2) wires slot-2 (13108) per §B1 — both are the same file, one recompile, one new ex5
SHA. Then this workflow generates the 3-sleeve set, enqueues one governed priority-track
basket run **plus** the fresh standalone 10145 reference, gates satellite + 13108 fidelity in
isolation, confirms the runner and 10145 remain unperturbed in the joint run, and hands the
harvested per-magic trade streams + account equity path to the paired first-passage P(pass)
estimator (`…measurement_preregistration.md` §2). The runner-alone anchor is already fixed
at first-passage **85.1%** at 1× (`…goal_implementation.md` item 5); the joint run measures
whether the composed book clears that bar.

---

## Evidence index

- Step-3 blocker: `QM5_20181…mq5:284,359,501-505`; `.mq5` sha `f102f620…` (unchanged);
  `grep -nE "s2_|Run13108"` → empty; only `QM5_20180`,`QM5_20181` joint EAs in tree.
- Third-member: `2026-07-28_goal_blocker_chain.md` §B3-decision (13108);
  `2026-07-27_20181_repair.md:51-65` (13301 kept as documented candidate); `13108` timer-safe
  latch `QM5_13108_xti-mtsm-s2.mq5:379-397`.
- Satellite news divergence: satellite `…20181…mq5:105,406,501-505`; `QM_BasketOrder.mqh:126`;
  standalone `QM5_10145_tsm-meanret.mq5:261-266`; set `…10145…_XAUUSD.DWX_D1_backtest.set`
  (`qm_news_temporal=3`,`qm_news_compliance=1`). Inert: `10145_XAUUSD_DWX.jsonl` entry-hour
  histogram `{1:314}`.
- Step-2 run: work item `c0192be6…`; tester.ini
  `…c0192be6…/QM5_20181/20260728_125300/raw/run_01/tester.ini`; magics
  `magic_numbers.csv:15369-15370`.
- Runner reference: `588af557…/q08_trades_9936_USDJPY_DWX.fresh.jsonl` (sha `352b9e3e…`,
  1,143 rows); comparator `tools/strategy_farm/compare_joint_replay.py`.
- Reference-run gap/vintage: no QM5_10145 item after 2026-07-21; news calendar refreshed
  2026-07-28 05:30; tree 10145 ex5 07-14 (sha `268c2281…`) < framework 07-20 changes;
  joint compiled 07-27.
