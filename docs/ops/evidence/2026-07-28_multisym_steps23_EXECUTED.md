# Multi-symbol steps 2 & 3 — execution shepherd (governed)

**Date:** 2026-07-28 (live-verified against `farm_state.sqlite`, the shared MT5
`Common\Files\QM`, the step-2 run logger, and the source tree)
**Author:** Claude (board-advisor worktree) — STEP 2 & 3 execution shepherd
**Goal (OWNER, verbatim):** *"Ziel ist, dass der FTMO Backtest EA endlich gefahren werden
kann und wir sehen, ob er das Bestehen einer Challenge wahrscheinlicher macht!"*

This is the shepherd's honest close-out of step 2 (2-sleeve de-risk) and step 3 (3-sleeve
book). Per the mandate a failed gate is a **complete outcome**: this document reports the
exact gate that stopped the full measurement, with the mismatch decomposition. No gate was
tuned; no run beyond the one governed step-2 item was launched; T5/T_Live untouched.

---

## Bottom line

**Step 2 FAILED its admission gate, and the failure is more fundamental than the step-3
Codex build blocker: the joint EA cannot produce a harvestable, faithful satellite in a
single-symbol tester.** The step-2 run completed (`done/PASS`, account net 204,018 / PF
1.35), and the 10145 satellite *did* trade the account (149 XAUUSD fills, ~$73.7k of the
account P&L) — but:

1. **The satellite's trades are un-harvestable.** Zero satellite TRADE_CLOSED rows reach the
   q08 stream every downstream gate and the P(pass) machinery consume. Root cause is a
   design conflict (§3.1): the EA deliberately stays **out of basket mode** to keep the
   runner byte-identical, but `QM_FrameworkOwnsMagicSymbol` only recognises a foreign-symbol
   satellite as *owned* when in basket mode (or via a registered magic-context the satellite
   never got). So the satellite fidelity gate — the entire point of step 2 — **cannot be
   computed**.
2. **The satellite is not the admitted 10145 anyway.** 34 of its ~183 entry attempts were
   dropped "Market closed" (retcode 10018) because its fixed `OnTimer` entry fires at 01:00
   broker when XAUUSD is sometimes shut; the native standalone enters on the first open tick
   and would not drop these. It also fired far fewer entries than the standalone (149 vs 314
   archived) — a further execution divergence (§3.2).
3. **Runner invariance missed 1.0:** step-2 runner vs the proven runner-alone reference =
   **0.999125** (1142/1143 exact; one 2020-08-11 4.12-lot trade with a shifted exit that flips
   +1401 → −714). Attributable to enabling the satellite, not vintage (§2).

**Step 3 remains independently blocked:** the 20181 binary still wires only ONE satellite
(`g_sat_count = s1_enabled ? 1 : 0`, `…mq5:284`; `.mq5` sha `f102f620…` unchanged; no
`s2_*`/`Run13108`). The Codex-lane slot-2 (13108) build has not landed. But even once it
does, findings §3.1 and §3.2 must be fixed first, or the 3-sleeve run will be un-harvestable
and infidelic the same way.

| Gate | Criterion | Result |
|---|---|---|
| Step-2 runner-invariance | runner unchanged with satellite on | **FAIL — 0.999125** (1 shifted exit) |
| Step-2 satellite fidelity | satellite ≡ fresh standalone 10145 @ 1.0 | **CANNOT COMPUTE — satellite un-harvestable** (§3.1) |
| Step-2 satellite deployability | satellite reproduces admitted 10145 | **FAIL — 34 market-closed drops + entry shortfall** (§3.2) |
| Step-3 (3-sleeve joint) | binary exists, run, P(pass) | **BLOCKED — Codex slot-2 build not landed** |

**Decision: STOP. Do not proceed to step 3; do not tune.** The 2-sleeve de-risk did its job
— it caught two blocking defects (un-harvestable satellite, timer-entry market-closed drops)
and a runner-invariance miss, before any 3-sleeve run was built.

---

## §1 — Step-2 run provenance (governed, integrity-verified)

Work item `c0192be6-2490-4f3b-ae1e-48bf6922d9e6` (QM5_20181 USDJPY.DWX Q02, priority-track):
- enqueued 12:30:44Z; **claimed T1 12:52:59Z; done 13:16:40Z** (~24 min wall-clock); `PASS`.
- **terminal T1**; Model 4; H1; FromDate 2018.07.02; ToDate 2025.12.31; Deposit 100000.
- **staged-EX5 integrity:** `pre_run_sha256 == post_run_sha256 == required == 60ee13b7…`
  (`…/20260728_125300/summary.json:staged_ex5`) — the immutable binary contract held; set
  sha `7d2a061f…`; mq5 sha `f102f620…`.
- magics (registry `magic_numbers.csv:15369-15370`): runner slot-0 = **201810000** (USDJPY);
  satellite slot-1 = **201810001** (XAUUSD).
- account net (runner+satellite combined) 204,018.36 / PF 1.35 (`summary.json`).

**Harvested (shared `Common\Files\QM`, volatile — copied promptly):**
- runner q08 stream → `…/c0192be6…/harvest_steps23/step2_runner_20181_USDJPY_DWX.jsonl`
  (1,143 rows, sha `d8d3733b…`).
- account equity stream (per-bar + intraday lows, 309,018 rows) →
  `…/harvest_steps23/step2_equity_20181_USDJPY_DWX.jsonl` (sha `81c8bf19…`).
- full event logger (satellite evidence) →
  `…/c0192be6…/QM5_20181/20260728_125300/logger_sample.jsonl` (4.09 MB).
- tester report → `…/20260728_125300/raw/run_01/report.htm`.
- **satellite q08 trade stream → DOES NOT EXIST** (`20181_XAUUSD_DWX.jsonl` never written;
  and the runner file carries zero magic-201810001 rows). This is finding §3.1.

---

## §2 — GATE A: runner invariance — FAIL (0.999125)

`compare_joint_replay.py --joint <step2 runner> --gated <588af557 standalone-9936 fresh>`
(the reference itself proven `match_rate=1.0` vs the step-1 joint runner):

```
joint_trades 1143  gated_trades 1143  matched 1142  match_rate 0.999125
mismatch_categories: exact 1142, same_entry_same_volume_shifted_exit 1
mismatch: joint entry=1597138045 (2020-08-11) close=… net=-713.84 vol=4.12  -> shifted exit
```

The two streams reconcile exactly: `Σnet` differs by 2115.00, wholly explained by that one
trade (step-2 −713.84 vs the reference's paired +1401.16). Same entry, same 4.12-lot volume,
**shifted exit** — enabling the satellite turned one runner winner into a loser.

**Attribution (satellite, not vintage).** The reference is 07-27 vintage; step-2 is 07-28
(the news calendar refreshed 07-28 05:30). The vintage probe already established that the
07-27→07-28 calendar change does **not** move 9936's trades (`2026-07-28_goal_blocker_chain.md`
§B0: standalone-9936 07-28 arm `9f79065c` ≡ 07-27 `588af557`, trade-event symdiff 0). Since
the calendar is inert for the runner, the one shifted exit is attributable to **enabling the
satellite** — the satellite's open XAUUSD positions and the tester's now multi-symbol tick
interleaving perturbed one runner trailing-stop exit. This contradicts the F3 "runner
invariant by construction" claim (`2026-07-27_20181_repair.md` §F3). *A maximally rigorous
attribution would diff step-2's runner against a same-07-28-vintage runner-alone TRADE_CLOSED
stream; that stream was not harvested (only `9f79065c`'s raw logger exists), so this rests on
the probe's symdiff-0 result.* Either way the strict gate (1.0) is **not met**.

---

## §3 — GATE B: satellite fidelity — CANNOT COMPUTE / FAIL

The satellite fired exactly as designed and at the predicted time — every attempt at **01:00
broker** (the XAUUSD D1 bar-open). From the step-2 logger (magic 201810001):

- **149 `BASKET_ORDER_ACCEPTED`** (retcode 10009 `DONE`) — XAUUSD positions really opened
  (e.g. ticket 215, XAUUSD BUY 1.46 lots @ 1226.35, SL 1219.54).
- **34 `BASKET_ORDER_REJECTED` / `BROKER_OTHER` retcode 10018 "Market closed"**.
- **12 `TM_CLOSE` (QM_EXIT_STRATEGY)** satellite strategy-exits.

### §3.1 — The satellite is un-harvestable (blocking) — root cause

Despite 149 opens and ≥12 closes, **zero** satellite trades reach the q08 TRADE_CLOSED
stream. Mechanism, by source:

- The q08 emitter names its output file by the **chart symbol** (`QM_Common.mqh:965-967`,
  `q08_sym = _Symbol` = USDJPY) → there is only ever `20181_USDJPY_DWX.jsonl`; a satellite
  XAUUSD close could only appear *inside* it, tagged by `symbol`/`magic`. It does not: the
  harvested file is 1,143 rows, **all magic 201810000**.
- Pass 1 of the emitter (`QM_Common.mqh:900-904`) keeps only deals whose opening magic is
  *owned* per `QM_FrameworkOwnsMagicSymbol` (`QM_Common.mqh:400-429`). That predicate returns
  true for a foreign-symbol satellite magic only (a) if the magic is a **registered
  magic-context** (`:405-412`) or (b) **when in basket mode** (`:414-415`
  `if(!QM_SymbolGuardIsBasket()) return false;`).
- The joint EA **deliberately stays out of basket mode** to keep the runner byte-identical
  (`…mq5:280-283`; F3), and bound the satellite magic with `QM_MagicChecked` (`…mq5:298`),
  which does **not** register a `(magic, symbol)` context (unlike the runner's `QM_MagicFor`,
  `…mq5:256`). So `QM_FrameworkOwnsMagicSymbol(201810001, "XAUUSD.DWX")` returns **false** →
  the satellite's XAUUSD closing deals are excluded → never emitted.

**This is a design contradiction, not a tuning issue:** runner-fidelity-by-avoiding-basket-
mode is mutually exclusive with satellite-harvest-via-ownership, as the framework is written.
Consequence: the satellite fidelity gate (satellite vs fresh standalone 10145) **cannot be
computed** — there is no satellite trade stream — and the per-sleeve inputs the paired
first-passage P(pass) needs (`…measurement_preregistration.md` §2) do not exist for any
non-host sleeve. **Fix (Codex lane):** register each satellite's `(magic, symbol)` as a
framework magic-context at init so `QM_FrameworkOwnsMagicSymbol` (`:405-412`) recognises it
without basket mode — then the existing q08 Pass-2 loop emits the satellite closes (already
symbol-tagged) into the single stream, and the harvester splits by `magic`/`symbol`.

### §3.2 — Even if harvestable, the satellite ≠ admitted 10145 (blocking)

- **34 dropped entries.** The standalone 10145 enters on the first available tick of the new
  D1 bar; the joint satellite enters on the first `OnTimer` fire at ~01:00 broker and is
  refused when XAUUSD is closed (weekend/holiday D1 opens, session gaps). Those 34 entries
  simply vanish. This is an `OnTimer`-vs-native execution divergence intrinsic to the timer
  harness.
- **Entry shortfall.** 149 fills + 34 refusals = 183 attempts vs 314 in the admitted XAUUSD
  stream (`10145_XAUUSD_DWX.jsonl`, overlapping-and-then-some window). The satellite fires
  materially fewer entries than the native EA — a signal/bar-detection divergence
  (`iTime(XAUUSD,D1,1)` polled from a USDJPY-primary tester vs native XAUUSD/D1 new-bar) that
  cannot be quantified further without a harvestable stream + a fresh reference.

### §3.3 — The news-filter divergence (source-verified, but secondary here)

Independently, the satellite drops the standalone's FW1 news filter: it calls
`QM_BasketOpenPosition(…, qm_news_mode_legacy=QM_NEWS_OFF, …)` (`…mq5:406`) and the basket
path applies only the legacy single-axis `QM_NewsAllowsTrade` (`QM_BasketOrder.mqh:126`),
never the `QM_NewsAllowsTrade2(PRE30_POST30, DXZ)` the standalone uses
(`QM5_10145…mq5:261-266`, set `qm_news_temporal=3/qm_news_compliance=1`). For XAUUSD/D1 this
is **empirically inert** — all 314 admitted entries fire at 01:01 broker (entry-hour
histogram `{1:314}`), where no high-impact news window falls — so it does not change the
in-sample stream. It remains a latent robustness gap the deployable book must not carry, and
the satellite fix should wire FW1 news at the same time.

---

## §4 — The missing reference run (context)

The task expected a fresh standalone 10145 run "enqueued alongside" step 2; it was **never
enqueued** (newest QM5_10145 items are all 2026-07-20/21). The shepherd did **not** enqueue
one this session because §3.1 makes the comparison moot — there is no satellite stream to
compare against a reference, and the satellite binary is not final (needs the ownership +
timer + news fixes). Recompiling a reference now would burn a governed slot against a build
that must change. The reference belongs **after** the §3 fixes, run alongside a re-staged
2-sleeve binary. Recipe (for that point): recompile 10145 from the current tree (its ex5 is
07-14, pre the 07-20 framework changes — stale), stage it, enqueue one governed priority-track
XAUUSD/D1 item with the canonical news-ON set, then diff the (now harvestable) satellite
substream vs it on `[2018-07-02, 2025-12-31]`; ADMISSION = 1.0.

---

## §5 — What must happen before a valid 3-sleeve P(pass) is possible

| # | Blocker | Fix | Owner |
|---|---|---|---|
| 1 | Satellite un-harvestable (§3.1) | register satellite `(magic,symbol)` context at init so `QM_FrameworkOwnsMagicSymbol` owns it without basket mode; verify q08 emits per-magic satellite closes | **Codex lane** |
| 2 | Satellite drops market-closed entries + entry shortfall (§3.2) | reconcile the `OnTimer` new-bar/entry path with native 10145 (entry on first open tick, not a fixed 01:00 timer); re-establish signal parity | **Codex lane** |
| 3 | Runner not invariant (§2) | diagnose the satellite→runner exit perturbation (margin/tick-interleave); restore F3 or accept+document | **Codex lane** |
| 4 | Satellite drops FW1 news (§3.3) | wire `QM_NewsAllowsTrade2(PRE30_POST30,DXZ)` into the satellite basket entry | **Codex lane** |
| 5 | 3rd sleeve not wired (step 3) | B1: `s2_*`, `Run13108`, `g_sat_count→2`, `eqmagics[2]`, recompile → new ex5 SHA | **Codex lane** |
| 6 | OWNER confirm slot-2 = 13108 | one-line decision | **OWNER** |
| 7 | Re-run 2-sleeve + fresh 10145 reference, gate; then 3-sleeve + paired P(pass) | governed enqueue + harvest + `challenge_firstpassage` | shepherd / Answer agent |

**Third-member decision (confirmed):** slot-2 = **13108** (timer-safe, deployable, OOS
FUND_SCORE 0.527), superseding the repair doc's provisionally-kept 13301 (per-tick trailing
`QM5_13301…mq5:344-397` is not reproducible from `OnTimer` → undeployable). Still needs the
OWNER one-line confirm before B1.

**Recommended next step:** one Codex build pass fixes §3.1 (satellite ownership/harvest),
§3.2 (timer entry vs native), §3.3 (satellite news), §2 (runner invariance), and §5.5 (wire
slot-2 13108) — they are all the same file and one recompile. Then this workflow re-runs the
2-sleeve de-risk (now harvestable) + the fresh 10145 reference, gates satellite + 13108
fidelity in isolation, confirms the runner is unperturbed, and only then enqueues the
3-sleeve run and hands the per-magic streams + account equity to the paired first-passage
estimator. The runner-alone anchor is already fixed at first-passage **85.1%** at 1×
(`…goal_implementation.md` item 5); the joint run then measures whether the composed book
clears it. **Until §3.1 in particular is fixed, no multi-symbol joint run can be measured at
the per-sleeve level — this is the single highest-leverage fix for OWNER's goal.**

---

## Evidence index

- Step-2 run: `c0192be6…` (`done/PASS`, T1, 12:52:59Z→13:16:40Z); staged-EX5 pre==post==
  required `60ee13b7…` (`…/20260728_125300/summary.json`); tester.ini Model 4 / H1 /
  2018.07.02–2025.12.31; magics `magic_numbers.csv:15369-15370`.
- Harvest: `…/c0192be6…/harvest_steps23/step2_runner_20181_USDJPY_DWX.jsonl` (1143, sha
  `d8d3733b…`); `…/step2_equity_20181_USDJPY_DWX.jsonl` (309018, sha `81c8bf19…`);
  `…/20260728_125300/logger_sample.jsonl`; `…/raw/run_01/report.htm`.
- GATE A: `compare_joint_replay.py` step2 runner vs `588af557…/q08_trades_9936_USDJPY_DWX.fresh.jsonl`
  → 0.999125, 1 shifted exit (2020-08-11); pre-step-2 runner (sha `fdb632fb…`) vs same ref → 1.0.
  Vintage inertness: `2026-07-28_goal_blocker_chain.md` §B0 (`9f79065c` ≡ `588af557` symdiff 0).
- GATE B: step-2 logger magic 201810001 — 149 `BASKET_ORDER_ACCEPTED` (rc 10009), 34 `BROKER_OTHER`
  rc 10018 "Market closed", 12 `TM_CLOSE`; zero satellite rows in the q08 stream.
- Un-harvestable root cause: `QM_Common.mqh:965-967` (file keyed on `_Symbol`),
  `QM_Common.mqh:400-429` (`QM_FrameworkOwnsMagicSymbol`; `:414-415` basket-mode gate),
  `…20181…mq5:280-283,298` (isolation, `QM_MagicChecked` no context).
- News divergence: `…20181…mq5:406`; `QM_BasketOrder.mqh:126`; `QM5_10145…mq5:261-266`;
  entry-hour histogram `{1:314}` from `10145_XAUUSD_DWX.jsonl`.
- Step-3 blocker: `…20181…mq5:284,359,501-505`; `.mq5` sha `f102f620…` unchanged; only
  `QM5_20180`,`QM5_20181` joint EAs exist.
