# FTMO 2-Step: Break & Retest / NNFX intake, 2026-09-21

Programme: `FTMO_BR_NNFX_20260921`. Authority: current OWNER request, recorded in
`decisions/2026-09-21_owner_ftmo_br_nnfx_research_intake.md`.
Status: commissioned research and recovery; no new performance result or G0 approval.
Canonical runtime receipt: `scheduling_receipt.json` alongside this document.

## Outcome and evidence boundary

There are relevant untested inventory gaps. There is **no newly demonstrated fast strategy
with an 80% probability of reaching payout** in this intake. The new session variants below
are hypotheses with partial semantic deduplication, not discoveries of proven alpha.

Read-only census: 28 distinct NNFX identities and 26 retest-labelled identities (one retest
identity has duplicate registry rows). Six NNFX identities have no work_items rows; a seventh
has one pending Q02 and no economic result. Three active retest identities have no work_items
rows. `inventory.json` contains the row-level evidence, code/spec hashes and existing task IDs.
Scope: current authoritative ledger and matched names, not every archived/external backtest.
An EX5 file is not compile acceptance; an old PASS is not current qualification.

The current financed book report (`docs/ftmo/FTMO_BOOK_CURRENT.md`, v2) reports 289 business
days to Challenge and 489 business days to first payout, payout LCB 0.8668. Its venue-cost
stress moves that LCB to 0.6072. These are model outputs, not a promise or evidence of actual
cash receipt. The headline is not yet venue-validated. The older living readiness report's
286-day number refers to Phase 1 only. This intake uses the newer full-chain book context.

## What is already tested

| Existing line | Observed current-ledger evidence | Consequence |
|---|---|---|
| 10181 XAU NY ORB retest; 10659 ORB retest | Q02 FAIL rows | Another generic ORB is not new. Compare explicit execution/session changes against these parents. |
| 10216 break/retest; 11886 floor-pivot retest; 20076 diagonal retest | Q04 FAIL rows | Do not rename these as fresh families. |
| 10989 FTMO breakout/retest | Q02 FAIL and RETIRED_LOW_FREQ rows | Rolling M30 Donchian retest is already represented. |
| 2010 H4-bias/H1-pullback; 2011 H4-bias/H1-breakout | Q02 FAIL rows | Faster timeframe alone is not a new NNFX thesis. |
| 12534 canonical D1; 12741 pooled; 12742 configurable | Q04 failures; 12742 reaches Q06 FAIL | Indicator slot permutations have already been explored. |
| 12958 HMA/WAE; 36002 Kijun/strength/Damiani | Q08 FAIL_HARD exists; other historical states also exist | Read per-symbol lineage; neither is an untested winner. |

Additional semantic neighbours found in SPEC.md: 10668 VWAP/ORB pullback, 10724 ORB Burdiga,
10094 prior-day/H4-zone retest, 9903 daily-open failure, 9725 trendline retest, 9987 session
break/reentry/retest. These and Track-B H-B1..H-B8 must enter final deduplication. A proposed
previous-day-high/low retest is deliberately **not** commissioned separately: 10094 overlaps.

## Recovery pack N: seven NNFX identities without economic verdicts

| EA | Name | Actual state | Next action |
|---|---|---|---|
| QM5_36001 | McGinley / SSL / WAE | MQ5 + EX5 present; no work_items; TODO build, failed review | Reconcile the original build/review, compile identity, signal fidelity and setfiles before first Q02. |
| QM5_36003 | HMA / zero-lag MACD / STC | MQ5 + EX5 present; no work_items; TODO build | Same governed intake; preserve the existing task. |
| QM5_36004 | ALMA / QQE / volume flow | MQ5 + EX5 present; no work_items; TODO build, failed review | Same, explicitly resolve review failure first. |
| QM5_36008 | Gold KAMA / Vortex / TSI / WAE | MQ5 + EX5; Q02 pending; conflicting historical reviews | Reconcile latest valid review/build and existing pending row; do not enqueue a second Q02. |
| QM5_11963 | McGinley / TDFI | Registry only in inspected EA tree; no work_items | Recover source/card, mechanical rules and existing approvals; build only if intake becomes valid. |
| QM5_11964 | Supercycle Surge | Registry only; no work_items | Same; opaque marketing name is not a complete specification. |
| QM5_11965 | Algotrade Pro | Registry only; no work_items | Same. |

Card bodies for 36003/36004/36008 advertise pass rates 84.8/87.0/87.5%, without corresponding
test evidence in this census. Quarantine those claims as **UNVERIFIED** in the recovery
delivery; preserve original artifacts and do not use their expected PF/win-rate as selection
evidence. Audit actual indicator implementations against names and equations. These are
NNFX-labelled community configurations, not VP's disclosed personal algorithm.

D1 versions are secondary for speed: first measure net R/day and marginal portfolio value.
Do not blindly port failed D1 configurations to M5. Keep finite, recorded comparison counts.

## Recovery pack R: three active retest identities without ledger tests

| EA | Name | Actual state | Next action |
|---|---|---|---|
| QM5_9241 | MQL5 engulf/retest | MQ5, no EX5; existing build BLOCKED | Read and resolve the original blocker, then governed build intake. |
| QM5_12038 | POC retest / volume | No EA directory or work_items found | Recover source/card and verify profile inputs exist. |
| QM5_20078 | Intraday volume-profile POC retest | MQ5, no EX5; existing build BLOCKED | Resolve original task; verify volume-profile construction and data fidelity. |

Spot-FX/CFD tick volume is not exchange traded volume. A tick-volume or time-at-price proxy
must be labelled as such, not passed off as a genuine traded-volume profile. Missing data is
a DATA_GAP, not strategy failure. Retired 9712/11883 are not resurrected by this order.

## Three new Break & Retest hypotheses (internal variants, not source claims)

These are explicit first specifications for research. Freeze them, code/data hashes and
comparison controls before reading results. If semantic deduplication finds an exact existing
cell, reuse its evidence. Only a documented difference in mechanics/execution warrants a new
lineage. No statistical result has been computed for these proposed variants.

Common M5 engine: levels are frozen before the entry window; signal uses completed bars;
ATR(14) is Wilder M5 ATR frozen at breakout. Long breakout = close above level + 0.10 ATR,
with the previous close at/below that boundary. Retest must be a **later** bar within 6 bars:
low <= level + 0.10 ATR, low >= level - 0.25 ATR, close > level and close > open. Reverse
inequalities for shorts. Enter at the next available M5 open with actual bid/ask/costs.
Cancel the setup if any intervening close is more than 0.25 ATR through the wrong side,
the time window expires, or the next-open entry is over 0.50 ATR past the retest close.
Stop = retest extreme +/- 0.10 ATR, widened to a minimum entry-stop distance of 0.50 ATR;
skip if distance exceeds 1.50 ATR or the next-open price has already crossed the stop.
Target 1.5R from actual fill. First completed close back through the broken level exits next
open; hard stop is always active. At most one entry per symbol/session/day, no re-entry.
Time exit takes precedence over a new entry. All limits must be executable under broker lot,
margin and stop-distance constraints. This describes a hypothesis, not a fill guarantee.
Only the first qualifying breakout whose close is inside the entry window may arm a setup;
an invalidation/expiry ends that symbol's session with no re-arm. Missing range bars, stale
peer quotes or missing required warm-up history skip the session with a data-quality reason.

| ID / priority | Markets and anchors | Distinct hypothesis / control | Entry/flat window |
|---|---|---|---|
| BR1 / 79 | NDX, SP500, WS30; 09:30-09:45 America/New_York opening range | First accepted OR retest with cross-index confirmation: peer SP500 for NDX/WS30, NDX for SP500 must have a completed M5 close outside its own OR in the same direction at retest close. Paired control removes only peer confirmation. Differs from 10659 limit-touch fills and 10181 H1/impulse filtering. | Entries 09:45-11:30 NY; flat 15:45 NY. |
| BR2 / 78 | EURUSD, GBPUSD, USDJPY; 00:00-07:00 Europe/London range | London takeover after a compressed overnight range: range <= median of preceding 20 complete same-window ranges. First accepted retest. Paired control removes only compression. This is continuation; 9987 is break-back-inside reversal. Compare 13213 USDJPY exposure explicitly. | Entries 08:00-10:30 London; flat 12:00 London. |
| BR3 / 78 | XAUUSD, XAGUSD; 08:00-12:00 Europe/London range | NY breaks/retests the already completed London range; no H1 directional/strong-body gate. Paired control enters next open after breakout, without waiting for retest, with 1 ATR stop and 1.5R target. This control tests the entire retest/structural-stop package, not an isolated causal retest effect. | Entries 08:00-11:00 NY, only after the London range has closed; flat 13:00 NY. |

Hypothesized economic mechanisms: cash-open participation/market breadth (BR1), regional
liquidity handoff following compression (BR2), cross-session price discovery in metals (BR3).
These are falsifiable rationales, not measured structural advantages. Total first grid:
8 symbol cells x 2 arms = **16 cells**. No tuning of six retest parameters after the outcome.
GDAXI/UK100 are second-wave transfers only after a US cash-open survivor: local cash-open
anchors and non-US peer selection need separate pre-registration. XTIUSD is deferred to a
separate energy/session mechanism; no automatic symbol expansion because data exists.

## NNFX research gap: fidelity first, bounded faster adaptation second

External leads: AlgoMasterNNFX-V1 README (new literal-match lead in inspected local corpus)
and stfl/backtestd-doc rule text (already cited by `VARIANT_REALIZATION_SURVEY_2026-06.md`).
They document implementations, not profitable strategies. The AlgoMaster author flags D1
emphasis, synchronisation pitfalls and omission of costs outside MT5 real-trades mode.
Do not import its headline results or binaries. The stfl text has unfinished state-machine
sections; do not invent missing canonical continuation rules.

N1: map implemented Standard/C1, Baseline, one-candle delay, baseline pullback, continuation,
ATR proximity and partial-exit states against 12534/12742 and the June fidelity survey.
Produce a source/spec/code/test coverage table. Existing covered behaviour is CLOSED_DUPLICATE.
Only a proved missing or defective transition earns a separately reviewed successor. The
external documents are community interpretations; canonical attribution requires the primary
NNFX material or existing approved source evidence.

N2: a deliberately **NNFX-inspired** intraday comparison, not canonical NNFX: one already
implemented stack (McGinley + SSL + WAE, after recovery/fidelity check), same fully specified
indicator periods and formulas frozen from its reviewed spec; EURUSD, GBPUSD, USDJPY, XAUUSD;
paired H1 all-hours versus H1 session-flat. Session arm accepts entries at hourly opens
09:00 through 16:00 Europe/London and closes at 17:00 London; no new trades after the cutoff,
one position per symbol, at most two entries per day. Common ATR(14) stop 1.5 ATR, 50% partial
at 1 ATR, residual stop to entry after partial, exit on opposite SSL closed-bar state.
Both arms use identical signal rules; all-hours arm preserves news/rollover/weekend controls
and charges financing. **8 cells**, after final deduplication against 2010/2011/12742. D1
recovery results are descriptive context, not a third optimized arm. A defect repair is a new
lineage and must not overwrite historical verdicts. If no unique mechanics remain, stop N2.

## Shared experiment and payout contract

1. Preserve current Q gates. This is an additive research objective, not a production contract
   rewrite or automatic relaxation of stricter existing admission rules. Prioritise marginal
   reduction in **time to first net cash payout**, measured on the whole account.
2. OWNER's 80/20 refers to the full chain: Challenge -> Verification -> funded survival ->
   eligible reward -> processing/receipt. Three legs each at 80% would give only 51.2% if those
   were their conditional probabilities. Report total-chain success, breach, rejection and
   unresolved/censored outcomes separately. Do not label censored paths failures or successes.
3. Planning assumption pending optional OWNER preference: USD 100k. Test first permitted
   positive reward and funded account gains of 0.5%, 1%, 2%. At the standard 80% reward share,
   these latter gains correspond to USD 400/800/1600 before other cash costs; fee refund is a
   separate cash ledger item. A USD 1,000 reward needs USD 1,250 account profit at 80% share.
4. Diagnostic objective: minimise calendar time while full-chain payout LCB >= 0.80. Report
   unconditional payout-by-day probabilities at days 30/45/60/90 and the earliest day at which
   its lower bound reaches 0.80; if none, say NOT_REACHED. Also report conditional median/p90
   with the conditioning stated. Simulation can model payment lags, but actual bank receipt
   and administrative rejection risk remain unobserved until evidenced. Do not promise an
   80% real-world payout probability from market-only paths.
5. Preserve joint calendar dependence and portfolio open equity; include spreads, commission,
   financing and gap/slippage. Measured FTMO venue costs bind. Report base, x1.5 costs and
   venue-calibrated stress. Use the existing account book simulator, fixed seeds and contract
   uncertainty methodology; more simulated paths do not create more independent history.
6. Use the accepted v2/golden-tested prescreen (dependency 7088da77), next-bar market fills,
   worse gap-through stop fills, conservative same-bar stop/target ordering and actual
   intraday floating equity. No touching-bar fills at a favourable level. Compare at least
   one candidate to MT5 real-tick trades before treating a Python result as test-worthy.
7. Pre-register training/validation partitions and all 24 proposed comparison cells. The
   factory's 2018-2025 data have already been repeatedly inspected; 2023-2025 is **reused
   historical validation**, not pristine holdout. A new untouched sealed window and/or
   prospective demo is required for final confirmation. Record all trials and apply existing
   multiple-testing controls, including shared programme/parent experiments.
8. Intake triage, not Q-gate replacement: kill if net expectancy <=0 on validation or on
   reasonable measured venue cost stress; deprioritise for this speed programme if net R/day
   fails to improve the incumbent at matched account risk, or if a new candidate adds no
   resolved marginal speed benefit under the payout constraint. Do not demand 80% from each
   standalone EA; the book is the decision unit. State a density hypothesis before testing,
   then measure it; do not fabricate trade counts or force trades for minimum-day credit.
9. Freeze risk policy before final validation; no automatic increases in live/demo risk. Risk
   frontiers are offline, bounded by the existing account/correlation contract and include
   clustered USD/index/metals exposures. Choose among acceptable policies, not a target 20%
   failure rate when a safer equally fast policy exists.
10. Surviving unique hypotheses follow source/critic -> mechanical Strategy Card -> approved
    intake/registry -> governed build -> Q02 onward -> financed marginal book evaluation ->
    independent acceptance. Pipeline names are Qxx. Research delivery never grants G0/PASS.

## Official rules checked 2026-09-21

FTMO CFD **2-Step**: +10% Challenge, +5% Verification; 5% daily loss, 10% static overall loss,
4 entry days per evaluation phase. Equity includes floating P/L and trading costs; daily
boundary is CE(S)T. No maximum evaluation period. [Trading objectives](https://ftmo.com/en/trading-objectives/).

First reward request: day 14 or later after the first funded-account trade, all positions
and orders closed; account review and invoice/payment processing add time. Standard reward
share is 80%; initial planning does not assume premium status.
[Reward FAQ](https://ftmo.com/en/faq/how-do-i-withdraw-my-profits/).

Standard funded accounts restrict opening/closing, including SL/TP execution, during selected
news +/-2 minutes; Swing is exempt. Evaluation rules differ. The test must use the funded
restrictions throughout the planned frozen execution policy. An entry blackout alone does
not prevent a stop/target execution breach: flatten affected Standard positions safely before
the window or skip that exposure. Validate official event/instrument mapping. Existing wider
framework blackouts remain binding. [News FAQ](https://ftmo.com/en/faq/can-i-trade-news/).

For speed, even the theoretical evaluation floor is 4 + 4 trading days, followed by the
funded waiting period and administration; no promised fixed payout date.
[Evaluation timing](https://ftmo.com/en/faq/how-long-does-it-take-to-become-an-ftmo-trader/).

## Commissioning and dependencies

Seven packets: N-RECOVERY, R-RECOVERY, BR1, BR2, BR3, N-GAPS, PAYOUT80. Exact payloads,
priorities, lane pins and runtime IDs are in `task_packets.json` and `scheduling_receipt.json`.
Existing build/review/Q02 rows are referenced, not duplicated. Payload dependencies are
worker preconditions, not claimed scheduler-enforced dependency edges. A worker can deliver
deduplication/pre-registration while a harness is pending, but cannot issue a prescreen PASS.

Integrate with existing Track B, especially 2caa90f8 (alternative ideas), 7088da77 (harness),
73434cab (venue fidelity), bc00c556 (book simulator hygiene). Do not start a competing book
simulator or change the incumbent roster. Every packet returns an evidence artifact and
normal review; its owner commissions survivor build/Q rows using the canonical router.

This turn completes inventory, explicit experiment planning and durable scheduling. New
backtests, successful survivors and payout validation remain future work in those packets.
