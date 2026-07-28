# Goal blocker chain — NOW → a completed 3-sleeve joint QM5_20181 run with a P(pass) answer

**Date:** 2026-07-28 (~12:05 UTC, live-verified against `farm_state.sqlite` and the tree)
**Author:** Claude (board-advisor worktree)
**Goal (OWNER, verbatim):** *"Ziel ist, dass der FTMO Backtest EA endlich gefahren werden
kann und wir sehen, ob er das Bestehen einer Challenge wahrscheinlicher macht!"*

This is the operational half. The measurement-design half is preregistered in
`docs/ops/evidence/2026-07-28_measurement_preregistration.md` (committed 409a3986b) and
is cited, not repeated. Every item below was verified against the live state DB or the
source tree, not from prose.

---

## Bottom line

**Exactly one thing is on the true critical path that is not yet built: the 20181 EA
source supports only ONE satellite. A 3-sleeve run needs a second satellite slot wired
and compiled.** Everything else — the USDJPY lock, history warmth, the queue, the
runner-alone baseline, the vintage probe — is either already resolved or is a
minutes-to-hours governed-queue step, not a wall.

Two findings collapse blockers the STATE brief still listed as open:

- **The vintage probe is data-complete and f0301ecf is NOT the causal commit.** Both
  arms ran; their streams are identical except the news-calendar snapshot (§B0).
- **The runner-alone baseline is NOT a separate run.** The preregistration extracts
  Arm R (runner-alone) as the slot-0 substream of the *same* 3-sleeve joint run
  (`…preregistration.md` §2.1). So the P(pass) comparison needs ONE run, not three.

---

## Critical path (ordered, blocking)

| # | Blocker | Unblock action | Owner |
|---|---|---|---|
| B1 | **20181 EA wires only 1 satellite** (`…20181….mq5:284` `g_sat_count = s1_enabled ? 1 : 0`; only `QM20181_Run10145` exists, `:359`). No slot-2 path. | Extend source: `s2_*` input group, `Run13108` sleeve fn, kind-dispatched `OnTimer`, `g_sat_count`→2, eqmagics[2]. Recompile → new ex5 SHA. | **Codex lane** |
| B2 | **No set file enables any satellite** (all 3 sets have `s1_enabled=0`). | Generate the 3-sleeve set (`s0_enabled=1,s1_enabled=1,s2_enabled=1`, `s2_symbol=XTIUSD.DWX`, `RISK_FIXED=1000/RISK_PERCENT=0`). Record mq5/ex5/set SHAs. | this workflow |
| B3 | **Not enqueued.** | Enqueue ONE governed priority-track basket run, `basket_symbol_count=3`, staged-ex5 SHA-bound, same form as step-1 `a343f66e` (`timeout_min=150`, Model 4, USDJPY.DWX/H1, 2017→2025 requested). | this workflow |
| B4 | **USDJPY symbol lock + multisym serialization** (passive gate, not a wall). | None structural — priority-track bypasses the FIFO. Item admits once the current USDJPY holder releases and no multisym is active. | passive / queue |
| B5 | **P(pass) machinery does not consume a joint run.** | Harvest per-slot substreams + account equity path from the one run; run the **paired first-passage** statistic per `…preregistration.md` §2. | this workflow / Answer agent |

**Blocking OWNER decision (gates B1):** which sleeve is slot-2 — **13108 (timer-safe,
deployable, OOS 0.527)** vs **13301 (OOS 0.641 but timer-infidelic → undeployable book)**.
Recommendation and evidence in §B3-decision. The preregistration already binds the run to
the *deployable, timer-safe* book (§6.2), i.e. 13108.

---

## B0 — The USDJPY lock and the vintage probe (STATE item 1) — RESOLVED

**What the lock IS.** Not a file lock. It is the symbol-dedup inside the atomic claim:
`tools/strategy_farm/terminal_worker.py:1185-1187` — a pending item whose `symbol` is
already `active` anywhere farm-wide is skipped. Multi-symbol (basket) items carry a
second interlock: at most ONE multisym backtest active farm-wide
(`terminal_worker.py:1122-1125, 1194`). USDJPY-hosted 20181 runs are subject to both.

**Is it held right now?** Yes, but not against the probe. Live at 12:04 UTC:
`QM5_1236` is running a **Q04 USDJPY.DWX** backtest on T10 (item `ea15bca7…`, last
progress 11:46:30, still active). It holds the USDJPY symbol. No multisym is currently
active.

**Does it defer the probe?** No — the probe already ran. The staged-EX5 vintage probe was
a **single** arm (the parent build), and it is **done**:

- Parent arm `f0301ecf^` (= commit `c0918247`), staged binary
  `…/ex5_staging/ab474bb0…/parent_c0918247.ex5` (sha `f46b73c7…`): work item
  `9f79065c-87ed-4f00-97e5-70c32e2d55f1`, QM5_9936 USDJPY.DWX Q02, **DONE / PASS**,
  20260728 10:20→10:44. It claimed the USDJPY slot cleanly while it was free.
- Child arm `f0301ecf` (canonical tip) = the step-1 fresh standalone
  `588af557-300f-4e25-82a4-81974b04380a`, **DONE / PASS** (2026-07-27).

**Causal verdict: f0301ecf (the prop-firm include) has ZERO execution effect.** The two
arms' emitted logger streams (10,961 rows each) are **identical except 2 lines**, and both
differing lines are the **news-calendar snapshot**, not the code:

```
NEWS_TESTER_CALENDAR_SELFTEST  matches 34109 vs 34107   rows 96309 vs 96303
NEWS_CALENDAR_LOADED           hash 932D45E5… vs E7B48081…   modified 2026.07.28 vs 2026.07.27
```

Every trade event is byte-identical after dropping the wall-clock `ts_utc`: 2478
`ENTRY_ACCEPTED`, 2492 `TM_OPEN`, 413 `TM_CLOSE`, 1838 `TM_MODIFY`, 0 differences.
Streams:
`…/9f79065c…/QM5_9936/20260728_103040/logger_sample.jsonl` vs
`…/588af557…/QM5_9936/20260727_215505/logger_sample.jsonl`.

**Therefore the fresh-vs-archive divergence** (archive 1,252 trades → fresh 1,143;
72 shifted exits + 25 entry diffs, `…multisym_step1_EXECUTED.md:51`) **is news-calendar
vintage, not f0301ecf.** The archived sleeve stream is stale-calendar
(`D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades\9936_USDJPY_DWX.jsonl`, 1,252 rows).

**Unblock action:** none for the run. To convert this logger-level finding into a signed
q08-level verdict, run `compare_joint_replay.py` on the two arms' q08 trade streams — a
pure analysis step, **parallel to and independent of** the queue. *Owner: this workflow /
Codex lane.* This also retires the "runner-alone baseline is suspect" cloud, because the
baseline is now taken from the fresh joint run itself (§B5), not the archive.

---

## B2/B3 — Step-2 (2-sleeve) prerequisites (STATE item 2)

**Does the repaired 20181 have a set enabling the 10145 satellite? No.** All three sets
(`…/sets/*.set`) carry `s1_enabled=0`. Values verified: `s0_enabled=1`, `s1_enabled=0`,
`s1_symbol=XAUUSD.DWX`, `RISK_FIXED=1000`, `RISK_PERCENT=0`, `host_symbol=USDJPY.DWX`.
The **EA binary already supports 10145** (slot-1 path `…mq5:284-306`, sleeve fn
`QM20181_Run10145` `:359`), so a **2-sleeve run needs no source change** — only a new set
with `s1_enabled=1`.

**Is 10145's XAUUSD.DWX history warm? Yes.** Registry
(`farmctl._dwx_symbol_history_registry`): `XAUUSD.DWX` first_year 2017, last 2025, all
timeframes incl. D1/H1, sourced T1–T10. Same for `GDAXI.DWX`, `USDJPY.DWX`, `XTIUSD.DWX`.
**History is not a blocker for any sleeve.**

**Work-item form for a joint run** (from step-1 `a343f66e` payload, verified):
`kind=backtest`, `setfile_path=<the joint set>`, `basket_symbol_count=2`,
`portfolio_scope=basket`, `priority_track=True`, `evidence_binding_required=True`,
`evidence_provenance=real_mt5`, `expected_ex5_sha256/expected_mq5_sha256/expected_setfile_sha256`
(the immutable staged-EX5 contract, da0183209/41372ec98), `timeout_min=150`,
`expected_symbol=USDJPY.DWX`, `expected_period=H1`, `from_date=2018.07.02`
(effective — the tester floored FromDate at 2018-07-02 despite the 2017-01-01 request;
pre-2018-07-02 is NOT ESTABLISHED, `…multisym_step1_EXECUTED.md:69-72`), `to_date=2025.12.31`,
Model 4. Step 2 = this exact form with `basket_symbol_count=2` and the `s1_enabled=1` set.

**Status of Step 2 as a lever:** *optional but valuable.* It needs **no EA build** and can
be enqueued now; it is the cheapest end-to-end proof that the joint-run → harvest →
P(pass) pipeline works before the slot-2 build lands. It is **not** on the 3-sleeve
critical path.

---

## B3-decision — Step-3 third sleeve: 13301 vs a timer-safe alternative (STATE item 3) — RESOLVED

**What the repair doc decided:** it *kept* 13301 as the documented candidate and recorded
that **no comparable timer-safe replacement exists** — accepting 13301's fidelity-gate
failure as "an accepted finding, not a surprise" (`2026-07-27_20181_repair.md:51-65`).
That is a recorded decision, but it points the run at an **undeployable** book.

**Independently verified exit cadences (evidence over the doc):**

- **13301** (`QM5_13301_balke-minute-range-breakout.mq5:344-353`):
  `Strategy_ManageOpenPosition()` is *"Called every tick … Runs every tick (not
  bar-gated) so the exit/cancel minute fires at real-time precision."* Per-tick
  structural H1 trailing (`:390-397`). In the joint EA's `OnTimer(1)` (1-second model
  timer, `…20181….mq5:320,504`) this **cannot** be reproduced → slot-2 would be a
  *different strategy* than the standalone 13301 that scored OOS 0.641.
- **13108** (`QM5_13108_xti-mtsm-s2.mq5:379-385`): `Strategy_ManageOpenPosition()` is
  gated behind `if(is_new_bar)` — once per closed D1 bar. **Timer-safe**; replays
  faithfully in the joint OnTimer harness. Symbol XTIUSD.DWX (history warm).
- **12969, 9403**: per-tick time/sign exits (`…repair.md:61-63`), not timer-safe.

**Decision:** slot-2 = **13108**. It is the highest-OOS **timer-safe** composition that
retains both 9936 and 10145: rank-17 `9936+10145+13108`, OOS FUND_SCORE **0.527**
(`…runner_satellite_composition.md:35`) vs 0.641 for the 13301 book. The 0.641 headline is
**not achievable by a faithful, deployable joint EA** — it was measured on a per-tick
standalone 13301. The preregistration binds the run to the timer-safe/deployable book
(`…preregistration.md:253-265, §6.2`); 13108 is that book. *This choice must be locked
before B1 so it does not surface at run time.* **OWNER confirms 13108 vs a conscious
decision to measure a non-deployable 13301 variant.**

---

## B5 — Same-vintage P(pass) machinery (STATE item 4)

**The problem is deeper than "recompute the baseline."** The existing driver
`tools/strategy_farm/portfolio/challenge_book_60d.py` reads **per-sleeve standalone**
q08 streams (`…:74,120`), requires `entry_time` (`…:153-158`), and — decisively — models
a book as **independent accounts**: *"separate FTMO accounts, separate equity, separate
caps. So a book's outcome is the OR over its members"* (`…:32-34`). That is a
multi-account campaign, **not** the joint EA's single shared account with shared caps. It
answers a different question and must not be used as-is for the joint verdict.

**What the joint run supplies (verified in the fresh streams):**

- **Joint account equity path:** `EQUITY_SNAPSHOT` `scope=account`, daily (`day_key`,
  `equity`, `day_pnl`) — 1,926 snapshots ≈ one/trading day over 2018-07→2025-12.
- **Per-slot separability:** `ENTRY_ACCEPTED` carries `symbol_slot` + `magic`;
  `TM_CLOSE`/harvested `TRADE_CLOSED` carry `magic`, `entry_time`, `net`, `mae_acct`
  (intraday adverse excursion). The equity sampler is configured per-sleeve magic
  (`…20181….mq5:308-315`). So Arm R (slot-0 only) and Arm B (all slots) are both
  extractable from the **one** run.

**Vintage:** the runner-alone baseline (the 35.7% / first-passage 75.3% numbers) MUST be
recomputed on the truncated 2018-07-02→2025-12-31 window from **the joint run's own
slot-0 substream**, not the archived 1,252-trade stale-calendar file
(`…preregistration.md:148-152, §2.2`). Because both arms come from the same fresh-vintage
run, calendar drift **cancels in the paired difference** (`…preregistration.md:247-251`).

**Unblock action:** implement/point the paired **first-passage** statistic
(`…preregistration.md §2.4,§2.7`; the first-passage KPI, not the 60/30 OR-model) at the
one joint run's slot-0 (Arm R) and all-slot (Arm B) substreams. *Owner: this workflow /
Answer agent.* Preconditions in `…preregistration.md §6` (10145 in-runner fidelity, 13108
timer-safety, union dormancy, vintage) are gates on the answer, checked from the same run.

---

## B4 — Queue latency (STATE item 5)

**Drain:** fleet-wide ~30 done/hr (hourly `done` 15–49 across 2026-07-28), 8 terminals
active, **2,452 pending**. But the pending pool is FIFO-ish by priority; **priority-track
items bypass it**. Evidence: step-1 priority items ran within ~20–40 min of enqueue
(`a343f66e` created 21:28 → done 22:22; probe `9f79065c` created 10:20 → done 10:44 = 24
min) despite **219 pending USDJPY items** and 2,450+ total pending.

**Latency for the 3-sleeve run:** a priority-track basket item waits only for (a) the
current USDJPY holder `QM5_1236` Q04 to release the symbol, and (b) no multisym active
(currently none). Then it claims the next free terminal. Realistic: **minutes to ~1–2 h**,
not days. If a 2-sleeve de-risk run is also enqueued, the two serialize (multisym
single-active + USDJPY dedup) — expect them back-to-back, ~1.5–4 h total.

**Priority legitimacy:** these 1–2 items are the explicit OWNER FTMO objective and use the
same `priority_track` mechanism step-1 already used. Legitimate against 2,452 pending;
this is not a mass-requeue.

---

## Non-blockers (verified, so they are not re-litigated later)

- **History warmth** — all sleeve symbols (USDJPY/XAUUSD/GDAXI/XTIUSD.DWX) 2017–2025, all
  TFs, all terminals. ✓
- **Runner fidelity** — 20181 runner ≡ standalone 9936 at 1.000000 same-vintage
  (`…multisym_step1_EXECUTED.md:50`). ✓
- **Runner-alone separate run** — not needed; it is the slot-0 substream (§B5). ✓
- **Vintage probe** — data-complete, non-causal (§B0). ✓
- **Staged-EX5 / SHA binding** — contract live (da0183209, 41372ec98); step-1 and the
  probe both used it. ✓

---

## Recommended next step

1. **OWNER:** confirm slot-2 = **13108** (timer-safe, deployable) — one-line decision,
   gates everything.
2. **Codex lane:** B1 — wire slot-2 (13108) into the 20181 EA, recompile, publish new ex5
   SHA. Optionally, before that lands, **this workflow** enqueues the free 2-sleeve
   de-risk run (B2/B3 with `basket_symbol_count=2`, `s1_enabled=1`) to prove the
   harvest→P(pass) pipeline end-to-end.
3. **This workflow:** on the new binary, generate the 3-sleeve set, enqueue one
   priority-track basket run (B2/B3), harvest per-slot substreams, run the paired
   first-passage P(pass) (B5) per the preregistration.
4. **Parallel:** run `compare_joint_replay.py` on the probe arms to sign off f0301ecf
   non-causality at q08 level (§B0).

*No terminal was launched, no work item mutated, no history imported, T5/T_Live
untouched. All state read-only from `farm_state.sqlite`.*
