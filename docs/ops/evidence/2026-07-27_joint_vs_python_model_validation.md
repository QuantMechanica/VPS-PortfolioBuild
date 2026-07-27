# Joint MT5 run vs the Python FTMO models — VALIDATION (2026-07-27)

Branch `agents/board-advisor`. Author: Claude.

Consumes `docs/ops/evidence/2026-07-27_joint_backtest_run_results.md` and compares
against `tools/strategy_farm/portfolio/challenge_book_60d.py` and
`tools/strategy_farm/portfolio/challenge_single_account.py`.

## 0. Verdict

**The joint MT5 run still has not executed, so the primary cross-check — real
account-equity path vs the pessimistic proxy — cannot be performed.** The fleet is
saturated exactly as `2026-07-27_joint_backtest_run_results.md` recorded (verified
below), and no `20180_*` trade or equity stream exists anywhere. The one comparison
the task's payoff section presupposes (Python model vs real joint equity) is
therefore **NOT ANSWERABLE** on the equity-path axis.

**But three of the five questions do not require the equity path** — they are
properties of the two sleeves' existing Q08 trade streams (which carry full
intraday timestamps and per-trade account MAE), and I measured them directly.
The headline results:

1. For the specific joint book the EA implements — `{9936, 13213}`, both USDJPY,
   both **100% intraday-flat** — the −5% **daily** cap is nearly never the binding
   breach at the operating leverage (fires on **~1 day in the whole 8-year
   history** at 1.5x per sleeve). The MAE proxy's over-pessimism on that daily
   channel is **negligible** (≤6 breach-days out of 1621 across all leverages, **0**
   at leverage ≤2). The account's real killer is the **−10% total** streak, which
   the model computes largely from **exact realised P&L**, not from the proxy.
2. The intraday-interleaving infidelity the adversarial review "could not test"
   produces **zero** daily-cap misclassifications for this book (measured, after I
   caught and killed a spurious 168-flip artifact in my own first cut — §Q2).
3. The two sleeves are near-collinear: **realised daily-P&L correlation r = 0.84
   (union) / 0.905 (both-traded), 269 bit-identical trades, 89% same-sign days.**
   This **confirms** every prior doc's assumption that 9936 and 13213 are one edge.
4. Consequently the Python joint `{9936,13213}` book is measured **worse** than the
   single 9936 sleeve — **28.8% vs 35.7% OOS P(fund)** — for a mechanical reason
   (leverage dilution with no diversification offset), and the real run would not
   rescue it because the proxy error I could bound is small.

Every load-bearing number below is anchored to the durable streams
`D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/{9936,13213}_USDJPY_DWX.jsonl`
and reproduced by
`scratchpad joint_vs_python.py` / `verify_order.py` (analysis scripts, retained;
they reuse `challenge_single_account.py`'s engine by import — no re-implementation).
Nothing is from a joint equity path — that run did not happen.

## 1. Joint run state — still not executed (evidenced)

- No `20180` output exists: `q08_trades/20180*` and `q08_equity/20180*` are absent
  in both the shared Common (`…/MetaQuotes/Terminal/Common/Files/QM/…`) and the
  durable portfolio dir; **no `q08_equity/` durable directory exists at all**; no
  `20180*.htm` tester report in `D:/QM/reports/portfolio` or `D:/QM/exports`.
- The build is real and ready: `.ex5` (374,162 B, 2026-07-27) + `.mq5` + sets under
  `framework/EAs/QM5_20180_ftmo-joint-sim-backtest-only/`; build doc present.
- Fleet saturated now (`farmctl.py mt5-slots`, 2026-07-27): **7 factory terminals
  actively backtesting** (T1 Q05, T2 Q02, T4 Q04, T6 Q04, T7 pipeline, T8 Q04,
  T10 Q02); **2076 pending work items** (2006 Q02). Same structural block as the
  run-results doc. Under the hard constraints (no Factory_OFF/ON, no interrupting a
  factory backtest, DEV lanes are the wrong build, T5 dead) the run cannot be forced
  this session. It remains a turnkey phase-runner job.

## 2. What the existing streams settle (method)

Both sleeves are **100% intraday-flat** (9936: 1252/1252 same-day; 13213: 1596/1596)
— every position opens and closes inside one UTC day, so each trade's MAE is charged
on exactly one day and the "multi-day full-MAE-per-day" pessimism does not even
engage here. That makes the streams sufficient to measure the daily channel and the
cross-sleeve interleaving directly; only the **inter-trade intraday equity path**
(the shape between closes) needs the real run.

Convention note (a real, disclosed gap): the Python model buckets days by **UTC
calendar date** (`datetime.fromtimestamp(..., tz=utc).date()`), whereas FTMO's daily
−5% reset is **broker-server midnight** (GMT+2/+3). The joint EA's `EQUITY_LOW`
sampler uses the correct per-broker-day. For these sleeves (which trade the European/US
sessions, not the 21:00–22:00 UTC rollover) the mismatch is unlikely to move a daily
low, but it is **NOT ESTABLISHED** to be zero and only the real run settles it.

---

## Q1 — Does the observed intraday path breach −5% daily more or less than the MAE proxy predicts?

**The observed path is NOT ESTABLISHED (run not executed). The proxy's error on the
−5% daily channel is measured to be negligible for this book, and the −5% daily cap
is not the binding constraint anyway.**

The model's daily-cap test has two channels: a **floating** charge (sum of that day's
open positions' MAE, assumed simultaneously at worst — the proxy) and a **realised**
running sum of closed net. At each per-sleeve leverage L (equal split, both sleeves
at L), count the days that trip the −5,000 daily cap:

| per-sleeve L | proxy (Σ day-MAE) | maxConcurrent-MAE | realised endpoint | proxy − maxConc |
|--:|--:|--:|--:|--:|
| 1.0 | 0 | 0 | 0 | 0 |
| 1.5 | **1** | 1 | 1 | 0 |
| 2.0 | 7 | 7 | 7 | 0 |
| 2.5 | 404 | 401 | 396 | 3 |
| 3.0 | 506 | 502 | 410 | 4 |
| 4.0 | 663 | 657 | 440 | 6 |
| 5.0 | 901 | 901 | 609 | 0 |

`maxConcurrent-MAE` uses the trade timestamps to charge only positions **open at the
same instant** (the tightest MAE bound the streams permit) instead of every trade in
the day. The proxy − maxConcurrent gap is **≤6 days out of 1621 (0.4%), and 0 at
L ≤ 2** — because both sleeves trade the overlapping USDJPY session, so on any
breach-relevant day their positions are genuinely concurrent (on the worst 8 days
proxy = maxConcurrent = realised net to the dollar; those are the 269 bit-identical
double-position days). **Direction where any gap exists:** proxy over-predicts daily
breaches → the reported pass rates were, on this channel, marginally **too LOW** →
the real numbers are marginally **better**. **Size: negligible** (<0.5% of days,
zero at the operating leverage).

**The −5% daily cap is essentially inactive for this book at the operating point.**
At B=3 (1.5x each — the IS-selected joint config, §Q4) the floating channel trips on
**exactly one day in eight years**. So of the ~46% of starts the model marks
"breach," almost none come from the daily cap; they come from the **−10% total**
streak. And the total cap is driven by the running **realised** P&L (exact closed-trade
net) plus at most one day's floating dip — so the proxy contaminates the dominant
failure channel only weakly.

**Unresolved residual (needs the run):** `maxConcurrent` still assumes concurrent
positions hit their worst tick simultaneously. The true intraday low is ≤ that in
magnitude; the gap between `maxConcurrent` and the true tick path is **NOT
ESTABLISHED**. For the 21% of trades that are literally the same trade the worst tick
genuinely coincides; for the rest it is bounded above by `maxConcurrent` and expected
small (same-session, r=0.9), but I put **no number** on it without the equity export.

---

## Q2 — Does date-level stitching materially misstate the joint result vs true intraday interleaving?

**No — for this book the effect is zero at the operating leverage, measured.** This is
the specific infidelity the adversarial review
(`2026-07-27_single_account_adversarial_review.md` §3) flagged as the one new-code
hazard its self-check could not reach: the model appends a day's cross-sleeve trades
in **sleeve order**, not **close-time order**, so the running daily-cap sum can dip
transiently in an order that never occurred.

Measured, comparing the running-min under model-order vs true close-time order,
counting days where the −5,000 breach classification **flips**:

| per-sleeve L | flip days (model vs time order) |
|--:|--:|
| 1.5 | **0** |
| 2.0 | **0** |
| 2.5 | 1 |
| 3.0 | 1 |
| 4.0 | 3 |
| 5.0 | 4 |

**Zero flips at the operating leverage; ≤4 across the whole grid.** The reason is
structural: the pooled book has **at most 2 trades on any day** (394 single-trade
days, 1227 two-trade days, none with 3+), so within-day ordering has almost no room
to matter, and the two sleeves are near-collinear so their two trades usually move
together. This **confirms and sharpens** the review's "small for the actual winners"
— and **refutes its stronger hedge that the effect "cannot be bounded to zero"**: for
`{9936,13213}` at the operating leverage it **is** zero.

### Honesty note — a spurious 168-flip artifact I caught and killed

My first cut reported 168 flips at L=1.5. That was **wrong** — an artifact of
classifying trades by `t in b` (Python list-equality), which mis-sorted the 269
bit-identical trades into the wrong sleeve bucket and scrambled the ordering.
Re-running with **explicit per-trade sleeve tags** gave **0 flips**
(`verify_order.py`). The 168 number never left this analysis. It is recorded here
because the class of error (a measurement artifact masquerading as an interleaving
finding) is exactly what the last three errors on this problem were, and the
correction is the evidence that this one was caught.

---

## Q3 — Is the measured inter-sleeve correlation consistent with what the separate-stream analysis assumed?

**Yes — the streams confirm near-collinearity, exactly what every prior doc assumed.**

Measured on realised daily P&L (`joint_vs_python.py`):

- **269 bit-identical trades** shared by 9936 and 13213 — same entry, close, net,
  volume — 21% of 9936's trades, 17% of 13213's. (Matches the build doc's H1 count
  exactly.)
- **Pearson r = 0.839** over the union of 1621 active days (0-filled);
  **r = 0.905** over the 1227 days both sleeves traded.
- **89%** of shared days have same-sign P&L; **76%** of active days are shared.

The "separate-stream analysis" never asserted a diversification benefit for this
pair — it assumed the opposite. `2026-07-27_sleeve_improvement_targets.md` §5.2:
"both 9936 and 13213 are USDJPY — likely the **same underlying edge**; treat 13213
as a fallback/variant of 9936, **not an independent second bet**." The build doc H1:
the correlation "is near-collinear by construction … **must not be read as
independent-alpha evidence**." The Python models are consistent with r≈0.9: the
parallel model (`challenge_book_60d.py`) never claims a correlation, and the coupled
single-account model (`challenge_single_account.py`) **sums** the two P&L streams
(correlation-agnostic), so neither is falsified by the measurement. **The r=0.9
number confirms the assumption and, per Q4, explains why the joint book underperforms.**

The one correlation the separate streams **cannot** deliver is the **intraday equity-
path** correlation (the co-movement of the two sleeves' floating P&L between closes) —
that needs the joint run. **NOT ESTABLISHED.** The realised daily correlation, which
is what both Python models actually consume, **is** established here.

---

## Q4 — Re-derive P(Phase 1 ≤ 60d) for the joint book from the real path, vs the Python figure

**Real-path re-derivation: NOT ANSWERABLE (no equity path).** The Python figure for
the *exact* book the joint EA implements, computed by reusing
`challenge_single_account.py`'s coupled engine on membership `{9936, 13213}`
(equal split, budget B swept, IS-selected, OOS-reported; window 2017-10-09..2025-12-30,
IS/OOS cut 2022-09-15):

| B | each | P(P1≤60) OOS | P(fund) IS | P(fund) OOS | breach OOS |
|--:|--:|--:|--:|--:|--:|
| 1 | 0.50x | 16.2% | 3.7% | 3.8% | 4% |
| 2 | 1.00x | 46.6% | 23.5% | 23.8% | 32% |
| **3** | **1.50x** | **59.1%** | **26.3%** | **28.8%** | **46%** |
| 4 | 2.00x | 59.2% | 26.1% | 31.4% | 61% |
| 5 | 2.50x | 17.2% | 3.8% | 2.4% | 98% |

IS selects **B=3** (highest IS P(fund), 26.3%). **Joint `{9936,13213}` @ B=3:
P(P1≤60) = 59.1% OOS, P(fund) = 28.8% OOS, breach 46%.**

Compare the single lead sleeve (also reused engine, reproduced exactly):
**9936 @ 3x: P(P1≤60) = 61.4%, P(fund) = 35.7%, breach 44%** — matching
`sleeve_improvement_targets.md`'s headline to the decimal.

**The joint two-sleeve book is worse than the single sleeve (28.8% vs 35.7% P(fund);
59.1% vs 61.4% P(P1)). Mechanism, not hand-waving:** with r=0.9 the second sleeve
adds no diversification, so equal-split at B=3 simply runs the *same edge* at
**1.5x per sleeve** instead of 9936 alone at **3x**. Under a fixed-deadline sprint the
drift-per-window scales with leverage, so halving the lead's leverage to accommodate a
near-duplicate lowers the probability of clearing +10% in 60 days. Adding 13213 buys a
touch more trade cadence but no independent return — a leverage-dilution loss with no
correlation offset. (Note B=4 shows higher OOS P(fund) 31.4% than the IS-chosen B=3,
but IS does not pick it; reporting the IS-selected config is the no-leak discipline.)

**Direction the *real* run would move the joint P(P1):** the proxy is pessimistic, so
real ≥ Python, but §Q1/§Q2 bound the proxy error small for this book (daily channel
~0, ordering 0, total channel on exact realised P&L). So the real P(P1) is expected
to sit **at or marginally above 59.1%**, not dramatically higher — the exact value is
**NOT ESTABLISHED**. What the real run would *not* do is overturn the qualitative
result: the joint book underperforms the single sleeve, and that gap (−6.9pp P(fund))
is a leverage/collinearity effect the equity path does not touch.

---

## Q5 — Which specific claims are CONFIRMED, REFUTED, or untestable

| # | Claim (document) | Verdict |
|---|---|---|
| 1 | Joint run "NOT executed, no numbers produced" (`joint_backtest_run_results.md` §0) | **CONFIRMED** — still no `20180_*` output; fleet still saturated (7 terminals busy, 2076 pending). |
| 2 | Fleet "deeply saturated … 2072 pending, not a transient" (same §1.1) | **CONFIRMED** — 2076 pending, 7 active terminals, same block. |
| 3 | "Correlation NOT ESTABLISHED" (same §4) | **PARTIALLY REFUTED** — the *realised daily-P&L* correlation IS establishable from the streams (r=0.84/0.905) and did not need the run; only the *intraday equity-path* correlation remains NOT ESTABLISHED. |
| 4 | 269 bit-identical 9936↔13213 trades; "near-collinear, not independent-alpha" (`joint_backtest_ea_build.md` H1) | **CONFIRMED** — 269 exact-duplicate trades; r=0.905 on shared days. |
| 5 | Cross-sleeve within-day trades ordered by sleeve not time; "small for the actual winners"; "cannot be bounded to zero" (`single_account_adversarial_review.md` §3) | **CONFIRMED (small) + REFUTED (the zero-bound hedge)** — 0 flips at operating leverage, ≤4 across the grid; for `{9936,13213}` it *is* bounded to zero at 1.5x. |
| 6 | 9936@3x = P(P1) 61.4%, P(fund) 35.7%, breach 44% (`sleeve_improvement_targets.md` §2) | **CONFIRMED** — reproduced to the decimal via the reused engine. |
| 7 | "9936 & 13213 are probably one edge; 13213 a fallback not a second bet" (same §5.2) | **CONFIRMED** — r=0.9, 269 identical trades; joint book underperforms single (Q4). |
| 8 | 80.7% campaign "cannot be re-measured without inventing intratrade equity … floating delta unknown, not zero" (`a5768d03_equity_export_gap.md`) | **PARTIALLY REFUTED** — for *intraday-flat* sleeves the floating delta is now **bounded small** (daily-cap proxy error ≤0.4% of days; dominant −10% channel runs on exact realised P&L), not "unknown." It remains nonzero and the *exact* re-measurement still needs the equity export, but the claim that it is unbounded overstates the dependence for this sleeve class. |
| 9 | Singleton replay `match_rate` (fidelity of the joint EA) NOT ESTABLISHED (`joint_backtest_ea_build.md` §3) | **STILL NOT ESTABLISHED** — needs the controlled replay run; untestable from streams. |
| 10 | Single-account CI "±18.8% understates uncertainty; honest lower bound ~5–11% overlaps the 9.1% baseline" (`single_account_adversarial_review.md` §5) | **UNTESTABLE by the joint run** — a statistical-power question (overlapping-start deflator), not a fidelity question; one real equity path adds no independent samples and cannot settle it. |
| 11 | Intraday equity path breaches −5% daily vs the MAE proxy (the task's Q1 primary axis) | **UNTESTABLE without the run** on the true-tick residual; the *daily-channel* proxy error is bounded negligible (Q1), but the `maxConcurrent`→true-path gap is NOT ESTABLISHED. |

---

## 3. Status / evidence / risks / next step

- **Status.** Joint MT5 run still blocked (fleet saturated; hard constraints forbid
  forcing it). Primary equity-path cross-check NOT ANSWERABLE. Three of five questions
  answered from the existing streams; a fourth bounded; the fifth adjudicated
  claim-by-claim. Net finding: the joint `{9936,13213}` book is **worse** than the
  single 9936 sleeve (28.8% vs 35.7% OOS P(fund)) and the real run would not overturn
  that, because the proxy error I could measure is small.
- **Evidence.** Streams `…/q08_trades/{9936,13213}_USDJPY_DWX.jsonl`; engines
  `tools/strategy_farm/portfolio/challenge_book_60d.py`,
  `…/challenge_single_account.py` (reused by import, not re-implemented); run-state
  `farmctl.py mt5-slots` + `farm_state.sqlite` (2076 pending); build/run docs
  `2026-07-27_joint_backtest_ea_build.md`, `2026-07-27_joint_backtest_run_results.md`.
  Analysis scripts retained in scratchpad (`joint_vs_python.py`, `verify_order.py`).
- **Risks / caveats.** (a) All daily/ordering findings are on the MAE bound and
  realised endpoints, **not** the true tick path — the `maxConcurrent`→true residual
  is unquantified (small, expected). (b) UTC-day vs broker-day bucketing is a
  disclosed, unquantified convention gap the model carries and the EA fixes. (c) The
  coupled-engine reuse inherits the adversarial review's open flags (the self-check
  validates the refactor, not the coupling); my independent stream measurement
  partially fills that gap for this membership only.
- **Recommended next step.** Run QM5_20180 turnkey via the **factory phase-runner**
  (protocol fixed in `joint_backtest_run_results.md` §3) to (i) confirm singleton
  replay `match_rate = 1.0`, (ii) close the `maxConcurrent`→true-path residual on the
  −5% daily channel, and (iii) measure the intraday equity-path correlation. **But
  the joint book is not the priority the run would suggest:** the measured verdict is
  that a second collinear USDJPY sleeve dilutes the lead. The factory effort belongs
  on the `sleeve_improvement_targets.md` route — cut 9936's p90 60-day drawdown so 3x
  runs without the 44% blow-up — not on productionising a joint book that already
  loses to the single sleeve in the Python model.
