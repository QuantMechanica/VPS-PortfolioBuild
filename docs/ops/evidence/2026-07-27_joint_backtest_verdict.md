# Joint FTMO Backtest-Only EA — VERDICT (2026-07-27)

Branch `agents/board-advisor`. Author: Claude (board-advisor). This is the closing
verdict on OWNER's joint-backtest idea (2026-07-27: hardcode the `.DWX` symbols into one
FTMO EA, run all sleeves together on one account, "get their correlation instantly and
they trade jointly"). It consumes the six workflow artifacts (recon ×2, design,
adversarial review, build, run-results) and independently re-verified the load-bearing
facts. Every claim is anchored to a `file:line`, a command, or a stream; where a fact was
not established it says **NOT ESTABLISHED**.

---

## Executive answer (read this first)

The idea produced a **compiled, turnkey instrument and zero measured numbers.** It works
as an engineering pattern for the narrow case it was ultimately built for, it was correctly
cut down from OWNER's ambitious version by an adversarial review that found a *fundamental*
MT5-tester limitation, and then it **was never actually run** — so as of this verdict the
three gaps it set out to close are closed **on paper, not in evidence.**

The one sentence for OWNER: **OWNER's cross-asset correlation goal — the headline of the
idea — cannot be delivered by a joint tester run at all; the surviving USDJPY-only
instrument is faithful and cheap but nearly redundant with the Python model on correlation;
and nobody has yet pulled the trigger to produce a single real number.**

---

## 1. Does the joint-backtest approach WORK here?

**Partially — and less than the idea promised. Three-way split:**

**(a) The multi-symbol tester machinery WORKS — established, in production.** A joint
multi-symbol `.DWX` real-tick run is not hypothetical: `QM5_12781` (USDJPY/AUDJPY
cointegration) reached Q05→Q08 as a 2-symbol basket
(`2026-07-27_mt5_multisymbol_tester_recon.md` §1; `D:/QM/reports/pipeline/QM5_12781/{Q05..Q08}`).
The reuse surface the task named (`host_symbol`, `basket_manifest.json`,
`QM_SymbolGuardInit`+`QM_BasketWarmupHistory`, `QM_BasketOrder.mqh`) exists and is correct
(`2026-07-27_multisymbol_machinery_recon.md` §1–§3). So the *plumbing* is a solved problem.

**(b) OWNER's specific cross-asset framing does NOT work — a hard tester limitation, not a
design miss.** The adversarial review's C1–C4 findings are correct and rooted in MT5
semantics: in a multi-currency test **`OnTick` fires only on the chart (host) symbol's
ticks** (`QM_SymbolGuard.mqh:100-108`, FW9). Any sleeve that manages positions *per tick* on
a **non-host** symbol is therefore driven at the host's tick cadence — its trailing stop,
its market-fill price, and its contribution to the intraday equity low are all computed from
the foreign symbol sampled at the *wrong* times. For the dropped gold sleeve (10848, a
continuous high-water-mark trailer, `QM5_10848…mq5:406-432`) this means **the joint run would
measure a different strategy than the one that was gated** (review C1), and the design's only
fidelity control — singleton replay with XAUUSD *as host* — is **structurally blind** to it,
because replay and the joint run put the sleeve in different tick environments (review C2).
This is not fixable by a better host choice: **no host assignment makes all heterogeneous
per-tick sleeves faithful** (review C3). It is a fundamental property of one-chart testing.

**(c) The surviving instrument is real but UNRUN.** The build correctly retreated to
**USDJPY-only** (9936 + 13213, host USDJPY), where both sleeves are host-symbol and C1–C4
do not arise. It compiles clean (**`Result: 0 errors, 0 warnings`**,
`framework/build/compile/20260727_100733/…compile.log`), carries genuine binary-level
backtest-only guards (`…20180….mq5:114-145`: refuses non-tester, `RISK_PERCENT>0`,
`prop_phase!=OFF`, `stress!=0`, and any chart other than USDJPY.DWX), and ships a real
equity sampler and a validated diff tool. **But the backtest was never executed** — the
run-results doc's four headline measurements are each **NOT ESTABLISHED**
(`2026-07-27_joint_backtest_run_results.md` §4). I re-confirmed the block is live and
structural, not a transient: right now 7 factory terminals are busy (T1,T2,T3,T4,T7,T8,T10)
and the queue is **2071 pending** (2001 in Q02) against 8 active
(`farmctl.py mt5-slots`; `farm_state.sqlite work_items`).

**Verdict on Q1: YES as an engineering pattern for a homogeneous same-symbol book; NO for
the cross-asset case that motivated the idea; and empirically NOTHING yet, because no run
was executed.**

---

## 2. What did it buy us that stream-stitching could not?

**As of now: nothing, because nothing ran.** What the built USDJPY-only instrument *would*
buy on execution, mapped to the three target gaps:

- **Equity gap (task a5768d03) — closable, cleanly, for USDJPY-only; NOT ESTABLISHED until
  run.** The built sampler (`QM_Mod_FtmoJointEquitySampler_20180.mqh`) emits a real per-bar
  `EQUITY_BAR` plus an `EQUITY_LOW` on every new intraday low, with a per-sleeve floating-P&L
  breakdown — the exact "sample per bar plus every new intraday low" that a5768d03 asked for,
  with **no invented intratrade equity**. Because the instrument is single-symbol, review C4
  (foreign-symbol troughs falling between host ticks) genuinely **does not bite**: every
  account-equity move happens on a host tick, so the −5% daily / −10% total predicates would
  be exact reads. This is the one gap the joint approach closes *better* than stitching — but
  only for a same-symbol book, and only once the run actually happens.

- **Intraday interleaving (single-account adversarial review §3) — closable for these two
  sleeves.** A joint run orders the two USDJPY sleeves by real tick time on one account,
  removing the Python model's date-only stitching. Genuine, but narrow.

- **Correlation — NOT delivered, and this is the gut-punch.** OWNER's headline
  ("sofort auch immer ihre Korrelation") is *not* delivered by the surviving instrument. The
  two USDJPY sleeves are **near-collinear by construction** — both are USDJPY range breakouts
  firing at the *same* 06:00 GMT+3 hour off overlapping windows (9936 range 01–06, 13213
  03–06); the build's own `compare_joint_replay.py` already found **269 bit-identical trades**
  between the two gated streams (build doc §5, review H1). Measuring their correlation
  "settles nothing" — it is a tautology. The *interesting* correlation is cross-asset
  (JPY↔gold), and that is exactly what C1 makes unfaithful. **To get a real cross-asset
  correlation you must run XAUUSD in its own host chart and infer correlation across two runs
  — which is precisely the stream-stitching the joint EA was meant to replace.**

**Net: the joint approach can close two of the three gaps (equity, interleaving) but only
for a homogeneous same-symbol subset and only once run; it cannot close the third
(cross-asset correlation) at all. Right now it has closed zero, because it is unrun.**

---

## 3. Cost per run, and sustainability against factory throughput

**The surviving instrument is CHEAP — the cost problem was dropped with the gold sleeve.**
The design budgeted the multi-symbol figure (20–44 GB, 1.5–3 h,
`…tester_recon.md` §4) — but that applies to a *2-symbol* load. By cutting to USDJPY-only the
build made this a **single-symbol run**, which inherits the measured 9936 anchor: **~6–7 GB
working set, ~19–20 min wall-clock** for USDJPY.DWX H1 over 9 years / 336M real ticks
(recon §4). The added per-tick equity sampler does **not** materially change that: I verified
its O(`PositionsTotal`) scan runs **only inside `EmitRow`** — i.e. only on a new bar or a new
intraday low — while the per-tick path is a single `ACCOUNT_EQUITY` read and one comparison
(`QM_Mod_FtmoJointEquitySampler_20180.mqh:139-161`). So review M3 is genuinely mitigated. The
full protocol is **3 runs** (replay_s0, replay_s1, joint) ≈ **~1 hour on one terminal**.

**The binding cost is not compute — it is terminal exclusivity.** ~1 hour of one terminal is
trivial against factory throughput *if a terminal is free*. It never is: with a 2071-deep
queue every worker re-claims within seconds, and there is **no sanctioned way to hold a
factory terminal** without stopping its worker or `Factory_OFF` (both forbidden). That — not
RAM or wall-clock — is why the run didn't happen. **Sustainability answer: as a periodic run
routed through the factory phase-runner (which owns the terminal legitimately and does the
shared-Common compare-and-swap, build doc §3/§8), it is 3 more items against a 2071 queue —
negligible. Hand-launched on a "free" terminal it is unsafe and starves nothing only because
it cannot be done safely at all.**

---

## 4. Standard replacement, or periodic confirmation?

**Periodic confirmation — emphatically NOT a replacement.** Argument:

1. **Generality.** The Python single-account stitching evaluates *any* subset of the
   209-sleeve book, at *any* leverage vector, instantly, with no compile and no terminal. The
   joint EA is a **bespoke hand-built instrument per book composition** — copy each sleeve's
   logic into a namespaced module, reserve `ea_id`+magics, regenerate the resolver, prove
   singleton replay. That does not scale to book search.

2. **Fidelity ceiling.** The joint EA is faithful *only* for a homogeneous same-symbol
   subset. The moment a book mixes symbols under per-tick management — which every interesting
   prop book does — the joint run measures a different strategy (C1–C4). It is unfaithful on
   exactly the books that matter, and there is a **fundamental trilemma** governing it:

   > **A single joint tester run can give at most two of {multiple symbols, per-tick /
   > intraday-equity fidelity, one faithful run}.** Homogeneous single-symbol buys
   > intraday-fidelity + one run (the surviving instrument). Heterogeneous symbols buys
   > multiple-symbols + one run but *loses* intraday fidelity for every non-host symbol.
   > You never get all three from one tester run.

   This is the general law the workflow implied but never stated. It is why the joint EA
   cannot be the standard evaluator: the standard book is heterogeneous, and the trilemma
   forces it to sacrifice the very intraday-equity fidelity the equity gap needed.

3. **Its real value is as a calibration oracle, not a workhorse.** The one thing the joint
   run provides that the Python model must *approximate* is the true intraday joint equity
   path and real tick-time interleaving — on a case where it is faithful (same-symbol). So the
   correct role is: **run the faithful USDJPY-only joint once, and use it to certify that the
   Python stitching reproduces the same equity path / breach counts on that same pair.** If
   the general approximate model matches the exact instrument where the exact instrument is
   trustworthy, that retroactively *licenses* the Python model on the heterogeneous cases the
   joint EA cannot do faithfully. Replacing the Python model with the joint EA would be
   strictly worse — slower, book-specific, and unfaithful on heterogeneous books. Anchoring
   the Python model *with* the joint EA is strictly better than either alone.

**Verdict: Python stitching stays the fast, general screening/ranking tool for the whole book
at any leverage; the joint EA becomes a periodic, same-symbol confirmation that (a) calibrates
the stitching model's interleaving/equity approximation and (b) produces the authoritative
equity path for a final candidate book before any OWNER go/no-go on a challenge account.**

---

## 5. Single next action, concretely

**Execute sleeve-0 singleton replay through the factory phase-runner — nothing else, first.**

Concretely: enqueue `QM5_20180` with `…_replay_s0.set` on USDJPY.DWX H1, Model 4,
FromDate 2017.01.01 / ToDate 2025.12.31, Deposit 100000 USD, Leverage 100, **via the factory
phase-runner** (the sanctioned collision-free path the run-results doc itself named, §3/§4) —
*not* by waiting for the 2071-deep queue to drain (it won't) and *not* by hand-launching on a
factory terminal (unsafe). Then:

```
python tools/strategy_farm/compare_joint_replay.py \
  --joint <harvested Common/.../q08_trades/20180_USDJPY_DWX.jsonl> \
  --gated D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/9936_USDJPY_DWX.jsonl
```

**Why this and not the menu options.** Extending the joint EA to more sleeves, or testing
9936 optimisation variants against FUND_SCORE, both **presuppose the instrument is faithful
and produces a real equity path — which is currently NOT ESTABLISHED.** Building on an unrun,
empirically-unvalidated instrument compounds unverified fidelity. Sleeve-0 replay is the
cheapest single step (~20 min, one terminal) that converts the entire "static confidence,
empirically NOT ESTABLISHED" fidelity claim into either a confirmed `match_rate = 1.0` (which
unblocks *everything* downstream — the joint run, the equity path, the calibration diff) or a
real finding to report. Sleeve 0 opens through the **default** `QM_Entry` path
(`explicit_magic=0`), which the build asserts is byte-identical to standalone 9936 (build doc
§2) — so a clean `1.0` is the expected, and load-bearing, result.

**The strategic prize it unlocks (the thing nobody proposed):** once sleeve-0 replay passes
and the 2-sleeve joint run yields a real equity path, run the **Python single-account model on
the identical 9936+13213 pair at the same leverage and diff the two equity paths / −5%-daily
breach counts.** That single comparison tells OWNER whether the entire Python campaign
methodology — which will remain the daily workhorse (§4) — is trustworthy on interleaving. It
is higher-leverage than extending sleeves or sweeping 9936 variants, because it validates the
tool we actually use to evaluate every book.

---

## 6. What this workflow got WRONG or left unfinished (handover — unsparing)

**Wrong / weak:**

1. **The design's central control was structurally blind to the failure that mattered.** The
   design (this workflow's own §3) claimed fidelity was "verified, not asserted" via singleton
   replay, while that replay ran each sleeve *as its own host* and therefore could not detect
   the non-host cadence divergence (C2) that made the gold sleeve unfaithful. The design's
   confidence outran its control; only the adversarial review caught it. Process lesson: a
   fidelity control that validates a refactor is not a fidelity control for the *coupling*.

2. **The design shipped factual errors about the sleeves.** It claimed 9936/13213 have
   "line-for-line identical `Strategy_*` functions"; in fact 13213 uses **one** evening hour
   for both pending-cancel and session-close (`13213…mq5:330,396`) where 9936 uses **two**
   (cancel 13, close 20). The design's "bind the rest to 9936's defaults" recipe would have
   mis-set 13213's cancel hour to 13 (review M2). The build fixed it (`s1_cancel_hr=18`), but
   the design as written was wrong.

3. **Cost was never plainly restated after the scope cut.** The docs carry the 20–44 GB /
   1.5–3 h multi-symbol figure throughout, but the *surviving* instrument is a ~20-minute
   single-symbol run. No doc states this plainly; a reader could wrongly believe the built
   instrument is the expensive one. (It is not — §3.)

**Unfinished (the big ones):**

4. **THE RUN NEVER HAPPENED — the single most important deliverable is absent.** A workflow
   that set out to close the equity gap *with a real run* closed it only on paper. Empirical
   fidelity `match_rate`, the joint equity path, the realised correlation, the −5%-daily breach
   count, wall-clock and peak RAM — **all NOT ESTABLISHED** (run-results §4). OWNER's idea has
   been designed, critiqued, built, and **not tested.**

5. **The terminal-exclusivity blocker was diagnosed but not solved.** The run-results doc
   correctly identifies that there is no sanctioned way to hold a factory terminal and that the
   phase-runner is the answer — then **stops at a "ready-to-run protocol" without routing the
   run through the phase-runner.** The workflow named its own unblock and did not pull the
   trigger. That is the concrete unfinished action (§5), and it is *available now* — the queue
   will not self-drain.

6. **The correlation goal — OWNER's headline motivation — was quietly abandoned rather than
   surfaced.** The workflow reasoned its way correctly out of the faithful cross-asset version,
   but it buried the consequence in an H1 finding instead of telling OWNER plainly:
   **the joint-EA approach cannot deliver a real cross-asset correlation; the only path to it
   is a separate XAUUSD-hosted run plus cross-run inference — i.e. the stream-stitching the
   idea meant to replace.** That flat conclusion should have been the headline of the
   run-results doc; it was not.

7. **The as-designed cross-asset instrument, had it not been reviewed, would have shipped a
   precise-looking equity curve and correlation number for a gold sleeve that was not the gated
   gold sleeve.** That is the exact "waste the entire exercise" failure — narrowly averted by
   the adversarial pass, and worth recording as the reason the review step is non-optional for
   any future multi-symbol measurement instrument.

8. **The backtest-only safety guarantee is partly asserted, not proven.** The binary now
   refuses live/percent/enforcing/stress configs at OnInit (good, `…20180….mq5:114-145`), and
   the `ea_id_registry` status is `backtest-only` — but that **the router will never enqueue a
   `backtest-only`-status EA** with registered magic rows is **asserted in the build doc, NOT
   ESTABLISHED by reading the router's status filter.** Low risk (single-symbol run, no basket
   manifest, no live set), but the safety claim is unverified and should be confirmed against
   `farmctl`'s EA-selection filter before this `ea_id` is left standing.

---

## Status / evidence / risk / next step

- **Status.** Idea designed, adversarially reviewed (correctly cut to USDJPY-only), built and
  compiled (0/0), tooling validated — **and not run.** No factory slot touched, no terminal
  launched, nothing under `T_Live` read or modified for this verdict.
- **Evidence.** Six workflow artifacts under `docs/ops/evidence/2026-07-27_*`; build tree
  `framework/EAs/QM5_20180_ftmo-joint-sim-backtest-only/` (`.ex5` 374,162 B, compile log 0/0);
  `framework/include/QM/modules/QM_Mod_FtmoJoint*_20180.mqh`;
  `tools/strategy_farm/compare_joint_replay.py`; commits `e40e3b94d`, `1b9c45eab`,
  `be1a3076b`, `16fd2a4e1`; live fleet state `farmctl.py mt5-slots` + `farm_state.sqlite`
  (2071 pending, 8 active, 7 terminals busy, 2026-07-27).
- **Risk.** The instrument is unvalidated empirically; do not extend or generalise it before
  sleeve-0 replay returns `match_rate = 1.0`. The `backtest-only` router-exclusion is
  unverified (item 8).
- **Recommended next step.** §5: route `replay_s0` through the factory phase-runner, diff with
  `compare_joint_replay.py`; on `1.0`, run the joint 2-sleeve config and then the calibration
  diff against the Python single-account model. Surface to OWNER, plainly, that cross-asset
  correlation is not obtainable from a joint run (item 6).
