# Unger-Style Reference Portability Audit — 2026-08-12

## Scope and source identity

This is an independent static audit of the UTF-16LE source bundle at:

`C:/Users/Administrator/Downloads/QuantRangePRO - vers2/Hyonix/Breakout7/QuantRangePRO - vers2/`

In citations below, `REF/` means that exact directory. The audited file hashes are:

| File | SHA-256 |
|---|---|
| `QuantRangePRO.mq5` | `e710e4294018952ee9d2419cce4b1b8dec377ba19825286e3dca26d11c8ca332` |
| `TimeRangeBreakoutStrategy.mqh` | `990ee5675743d9eb98783c16c08d94d55052e1fc48524f0b674f3708f1b2f915` |
| `IFilter.mqh` | `f1003376a7ea68e4d7113b10dff8b01009db6ae2d269aea4ae0c0d93e6ccf267` |
| `PatternFilter.mqh` | `875885f8a51df6c87e92b942c2aceadbc8c922f74a6629891d1fd08d3a759034` |
| `Patterns.mqh` | `784fe0770a1f09ac2b49e1cbaf9cc62c4a37d7800d439f47414a952fafedc489` |
| `PriceActionContextFilter.mqh` | `c80016b7a27b4fa5ab0b6fa286eb1f6ff1e393f470ec67605ce96dcdb528ae64` |
| `HiddenMarkovFilter.mqh` | `2d2f394ef52e7226efce83bd5b53b181a550e7f4da4ea7d0814fecd908c53ac8` |
| `NewsFilter.mqh` | `6abbcb5033105f6316e04b834848c4abac07414c08a2e289e31a28f5954686cf` |

No code was compiled or run, and no EA, set file, terminal, process, or factory row was
changed. The reference directory and its parent contain no `.set`, `.xml`, `.ini`, `.csv`,
or `.opt` sweep definition; that negative result is reproducible with:

```powershell
Get-ChildItem -LiteralPath 'C:\Users\Administrator\Downloads\QuantRangePRO - vers2' -Recurse |
  Where-Object { -not $_.PSIsContainer -and $_.Extension -in '.set','.xml','.ini','.csv','.opt' }
```

Therefore this audit can establish the exposed optimization surface and ranking objective,
but not the actual tester ranges, population size, or selection history used by the author.

## Bottom line

The reusable idea is a **direction-aware trade-permission result** evaluated before an
entry. The reference implementation is **not portable unchanged**.

There is no ordinary Monday/Tuesday/Wednesday/Thursday/Friday mask. “Trade only on
certain days based on patterns” means: once per trading day, test a configurable OR-list
of D1 pattern predicates independently for buy and sell; whitelist mode permits matching
directions, while blacklist mode blocks matching directions. The only explicit weekday
predicate is a simplified third-Friday options-expiry rule; a second calendar predicate
marks the last week of quarter-end months (`REF/Patterns.mqh:1018-1034`).

The code's most important portability defect is look-ahead/repainting exposure: it requests
D1 bars from shift zero, makes the array series-style, and evaluates `bar[0]`, the current
unfinished D1 bar (`REF/PatternFilter.mqh:237-274`; `REF/Patterns.mqh:276-304`). A V5 port
must evaluate only closed bars, normally shift one or greater, at a bar-keyed deterministic
event.

## Exact gating mechanics

### 1. Exposed controls

The top-level EA exposes:

- mode `OFF`, `BLACKLIST`, or `WHITELIST`;
- five buy pattern slots and five sell pattern slots;
- a logging toggle (`REF/QuantRangePRO.mq5:138-150`).

The `PatternFilterParams` structure repeats those two five-slot arrays and fixes the D1
lookback at 22 bars; lookback is not a top-level EA input (`REF/PatternFilter.mqh:33-54`).
The pattern catalogue assigns IDs from 0 through 100, including disabled and two test
controls (`REF/Patterns.mqh:19-149`).

### 2. When the decision is made

At the start of each strategy day, the EA clears the cached direction permissions
(`REF/TimeRangeBreakoutStrategy.mqh:1188-1206`). Starting one hour before the configured
range begins, it calls the filter manager once; if both directions are blocked, it skips
all range calculation for that day (`REF/TimeRangeBreakoutStrategy.mqh:252-280` and
`REF/TimeRangeBreakoutStrategy.mqh:1257-1305`).

If at least one direction remains allowed, the range is built normally. Later entry
generation reads only the cached `allowBuy` / `allowSell` booleans: the permitted side gets
its stop order and the blocked side does not (`REF/TimeRangeBreakoutStrategy.mqh:636-720`).

This is a **daily entry gate**, not an exit rule. It does not change an existing position's
management.

### 3. How slots combine

For buys, the filter scans enabled buy slots and stops at the first detected predicate;
sells are processed separately the same way (`REF/PatternFilter.mqh:300-376` and
`REF/PatternFilter.mqh:387-458`). Therefore slots within a direction are logical OR, not
AND. Slot order affects the reported first-hit name but not the direction permission when
all predicates are pure.

- **Whitelist:** a detected buy predicate permits buys; no detected buy predicate blocks
  buys. Sell permission is independent. Both blocked means the day is skipped
  (`REF/PatternFilter.mqh:476-537`).
- **Blacklist:** a detected buy predicate blocks buys; no detected buy predicate permits
  buys. Sell permission is independent (`REF/PatternFilter.mqh:539-601`).
- The manager ANDs direction permissions across filters and short-circuits a critical
  filter failure (`REF/IFilter.mqh:280-337`).

The base `FilterResult` defaults to pass/allow (`REF/IFilter.mqh:11-27`). That creates a
fail-open defect: when fewer than the required D1 bars are copied, `PatternFilter.Check()`
sets only a reason and returns the still-allowing default, despite its debug text claiming
trading is not allowed (`REF/PatternFilter.mqh:237-260`).

### 4. It is not a clean closed-day classifier

The check is normally performed before the session range, but the data call is
`CopyRates(..., PERIOD_D1, 0, ...)`; after `ArraySetAsSeries(..., true)`, the predicates
use the current partial day as `bar[0]` (`REF/PatternFilter.mqh:237-274`). Candlestick,
trend, volatility, “HMM” labels, and statistical predicates repeatedly read `bar[0]`
(`REF/Patterns.mqh:292-365`, `REF/Patterns.mqh:698-785`, and
`REF/Patterns.mqh:904-1015`).

The result is cached after that one intraday snapshot, so it will not change later that
day, but it still depends on the exact tick/time at which the pre-range check first fires.
It is neither a prior-close pattern nor a stable end-of-day feature.

## Parameter surface and degrees of freedom

The filter alone has two active modes and ten labeled slots. Each slot can select disabled
or one of the 100 enumerated pattern IDs, so the raw labeled configuration surface is
`2 × 101^10` before accounting for the base breakout parameters. OR semantics make many
slot permutations decision-equivalent, but that does not cure selection bias if the tester
evaluates them and retains a winner. The source for the ten slots is
`REF/QuantRangePRO.mq5:138-150`; the 0-to-100 catalogue is
`REF/Patterns.mqh:19-149`.

The surrounding breakout adds range start/minute/duration, daily close, direction, order
management, order distance, stop, target, trailing, break-even, sizing, range-size, and
Friday-close controls (`REF/QuantRangePRO.mq5:98-157`). A “pattern-slot sweep” performed
alongside those controls is an interaction search, not a one-variable filter test.

The custom `OnTester()` ranks the same test run through a composite of return, Sharpe,
drawdown, loss streak, payoff shape, recovery, cadence, and expected payoff, with only a
minimum-trade/blow-up validity guard (`REF/QuantRangePRO.mq5:1500-1676`). It provides no
IS/OOS separation, no family-wise trial correction, and no incumbent holdout comparison.
Worse, the pass CSV records only buy slot 1 and sell slot 1, omitting slots 2 through 5
from each direction (`REF/QuantRangePRO.mq5:1719-1757`). A multi-slot winner cannot be
fully reconstructed from that log.

News is also deliberately disabled during optimization even when the input is on
(`REF/QuantRangePRO.mq5:491-516`) while the pass log records the input value
(`REF/QuantRangePRO.mq5:1744-1751`). That is train/evidence versus runtime configuration
skew.

**Methodology verdict: REJECT.** The source exposes a hypothesis generator; it does not
provide an admissible selection protocol. A QM experiment may test one preregistered
pattern profile against the unfiltered incumbent, with every attempted profile included
in Q08 DSR/PBO/FDR trial accounting. It may not optimize the generic slot surface and
promote the best result.

## Filter-by-filter portability judgment

| Component | What it actually does | V5 judgment |
|---|---|---|
| `IFilter.mqh` / manager | Common result with buy/sell permissions, reason, recheck time; priority-sorted filters; directional permissions are AND-composed (`REF/IFilter.mqh:9-27,93-159,280-337`). | **PORT THE CONCEPT, NOT THE CLASS TREE.** Direction-specific permission and structured reason are useful. V5 already has simpler functional hooks and entry controls. |
| `PatternFilter.mqh` | Daily whitelist/blacklist OR-lists, five slots per direction, current D1 shift-zero inputs, cached for the day (`REF/PatternFilter.mqh:33-54,180-274,300-601`). | **PORT A NARROW REWRITE ONLY.** One card-declared profile, closed bars, fail closed, deterministic cache key, no generic slot optimizer. |
| `Patterns.mqh` | A 0-to-100 enum spanning candles, trends, volatility, SMC labels, regime heuristics, “statistical” labels, and two calendar rules (`REF/Patterns.mqh:19-149`). | **DO NOT WHOLESALE PORT.** Individually audit and re-specify only a tiny, sourced subset. Names such as HMM/Hurst do not make their simplified predicates validated models. |
| `PriceActionContextFilter.mqh` | H1 FVGs, H4 order-block heuristics, D1 equal highs/lows, live-BID proximity checks, and many exposed settings (`REF/PriceActionContextFilter.mqh:15-56,120-329,365-489`). | **REJECT AS-IS.** It is not wired into the EA; it uses mutable live-price/hourly state, includes unfinished bars, never updates `mitigated`, and its `requireStructureBreak` branch does not block. A closed-bar FVG rule could only return as a separately sourced Strategy Card. |
| `HiddenMarkovFilter.mqh` | A six-state hand-coded HMM-like Viterbi classifier on M15 returns, with mutable priors/history and regime-direction permissions (`REF/HiddenMarkovFilter.mqh:15-50,69-193,368-483`). | **REJECT.** V5 explicitly forbids ML-predicted entries/exits (`C:/QM/repo/framework/V5_FRAMEWORK_DESIGN.md:34-45`). It also consumes the current M15 bar, mutates state on each check, resets on restart, computes volatility/volume but feeds only returns to Viterbi, and uses hand-coded transition rows that are not all normalized (`REF/HiddenMarkovFilter.mqh:69-93,236-289,376-406`). |
| `NewsFilter.mqh` | Pulls the MT5 calendar for the next 24 hours, keyword/currency-filters high-impact events, and blocks before/after a detected event (`REF/NewsFilter.mqh:14-32,101-176,240-302`). | **REPLACE WITH V5 CENTRAL NEWS FILTER.** Calendar/API failure empties the list and allows trading, so it is fail-open. In this EA all filters are checked only once before the range, so a later event can be missed. Optimization disables it. V5 requires the seeded, stale-aware, fail-closed central filter (`C:/QM/repo/framework/V5_FRAMEWORK_DESIGN.md:380-384`). |
| `TimeRangeBreakoutStrategy.mqh` | Calls all filters pre-range, caches direction permissions, skips the day if both block, and applies allowed sides to pending breakout orders (`REF/TimeRangeBreakoutStrategy.mqh:252-280,636-720,1257-1305`). | **PORT THE LIFECYCLE IDEA WITH A DIFFERENT CLOCK.** Evaluate permission immediately before each new entry on a closed reference bar; cache by that bar's timestamp, never by first tick near a wall-clock hour. |
| `QuantRangePRO.mq5` wiring | Includes pattern, news, price-action, and HMM headers, but constructs only pattern and news filters (`REF/QuantRangePRO.mq5:8-15,458-516`; `REF/TimeRangeBreakoutStrategy.mqh:1488-1505`). | **DO NOT INFER ACTIVE HMM/SMC FEATURES.** Price-action and HMM are dead, unwired code in this build. |

## Concrete V5 bolt-on design

### Design objective

Add an optional, direction-aware **entry-permission** gate to a new filtered challenger
without changing the incumbent or weakening central kill-switch/news/risk behavior. The
V5 architecture already defines No-Trade before Trade Entry, treats filters as entry
conditions, and requires any filter change to re-enter the normal Q pipeline
(`C:/QM/repo/framework/V5_FRAMEWORK_DESIGN.md:47-58` and
`C:/QM/repo/framework/V5_FRAMEWORK_DESIGN.md:386-406`).

### Proposed API

Use a small pure include, for example `QM_FilterPatternPermission.mqh`:

```mql5
struct QM_PermissionResult
  {
   bool allow_buy;
   bool allow_sell;
   bool valid;
   datetime reference_bar_time;
   string reason;
  };

QM_PermissionResult QM_PatternPermissionEvaluate(
   const string symbol,
   const ENUM_TIMEFRAMES reference_tf,
   const int closed_shift,
   const QM_PatternProfile profile);
```

Hard requirements:

- `closed_shift >= 1`; the helper rejects shift zero at initialization;
- the profile maps to card-reviewed compiled predicates, not arbitrary arrays of IDs;
- missing/invalid history returns `valid=false` and both directions false;
- every predicate is pure over supplied closed OHLCV/calendar inputs;
- cache key is `(symbol, reference_tf, reference_bar_time, profile)`, so restart and tick
  cadence do not change the decision;
- one structured log records profile, source-bar timestamp, direction result, and reason;
- it never changes stops, exits, risk size, kill-switch, news, or open positions.

### Exact lifecycle insertion point

Do **not** put the optional pattern gate inside `QM_Common`, `QM_NewsFilter`, or
`QM_Entry`; that would widen the blast radius to every EA. Put it in the new challenger
EA after the base entry signal is formed and immediately before the standard entry call:

```mql5
if(!QM_IsNewBar(_Symbol, signal_tf))
   return;

QM_EntryRequest req;
if(!Strategy_EntrySignal(req))
   return;

const QM_PermissionResult permission =
   QM_PatternPermissionEvaluate(_Symbol, PERIOD_D1, 1, qm_pattern_profile);
if(!permission.valid)
   return; // fail closed and log
if(req.type == QM_BUY && !permission.allow_buy)
   return;
if(req.type == QM_SELL && !permission.allow_sell)
   return;

ulong ticket = 0;
QM_TM_OpenPosition(req, ticket);
```

This matches real V5 lifecycle practice: `QM5_12567` performs kill-switch, current news,
Friday-close, strategy No-Trade, management/exit, then one closed-bar entry evaluation
(`C:/QM/repo/framework/EAs/QM5_12567_cum-rsi2-commodity/QM5_12567_cum-rsi2-commodity.mq5:226-287`).
Its signal reads D1 shifts one and two, not the forming bar
(`C:/QM/repo/framework/EAs/QM5_12567_cum-rsi2-commodity/QM5_12567_cum-rsi2-commodity.mq5:91-136`).
The range-breakout example likewise confirms its breakout and volume on closed bars and
enters through `QM_TM_OpenPosition`
(`C:/QM/repo/framework/EAs/QM5_12700_balke-range-breakout/QM5_12700_balke-range-breakout.mq5:161-220,259-286`).

The central entry path remains the last authority: V5 `QM_Entry` rechecks kill-switch,
news, risk, magic, and duplicate-position controls
(`C:/QM/repo/framework/V5_FRAMEWORK_DESIGN.md:486-519`). The optional gate cannot bypass
mandatory news blackout.

### What flows through `.set` files

Avoid the reference's ten generic slots. A filtered variant should add only:

```text
Filters=════════════════════════════════════════════════════════════
qm_filter_pattern_enabled=true||false||0||true||N
qm_pattern_profile=QM_PATTERN_PROFILE_<CARD_DECLARED_NAME>||...||0||...||N
```

The compiled profile pins:

- reference timeframe;
- closed shift;
- buy predicate;
- sell predicate;
- whitelist or blacklist semantics;
- missing-data behavior.

Those details also appear in the Strategy Card and structured init log. They are not ten
independently optimizable set inputs. Every set file must explicitly carry the profile,
including `OFF` for the incumbent control. The existing V5 convention already requires
filter declarations in the card and reproducible filter values in set files
(`C:/QM/repo/framework/V5_FRAMEWORK_DESIGN.md:386-396`).

Backtest sets retain `RISK_FIXED > 0` and `RISK_PERCENT = 0`; current real EAs expose that
contract (`C:/QM/repo/framework/EAs/QM5_12700_balke-range-breakout/QM5_12700_balke-range-breakout.mq5:19-34`).
The news configuration remains the central two-axis FTMO/DXZ policy, and
`qm_news_stale_max_hours` must never exceed 336
(`C:/QM/repo/framework/EAs/QM5_12700_balke-range-breakout/QM5_12700_balke-range-breakout.mq5:29-38`).

### Identity and blast radius

The filtered challenger receives a new EA/version identity, registry rows, magic rows,
binary hash, setfiles, and card lineage. The incumbent files and binary remain byte-for-byte
unchanged. Initial implementation touches only:

1. one new pure filter include plus unit fixtures;
2. one new challenger EA directory;
3. that challenger's explicit `.set` files and input schema;
4. deterministic registry/magic additions.

Do not add a default virtual hook to every current EA in the first experiment. A shared
framework hook would force a broad recompile and create needless evidence/hash churn.
Generalize only after a challenger proves the concept and a separate framework review
approves the migration.

### Focused implementation verification

Before any pipeline result, require:

- compile proof with no warnings/errors;
- unit vectors for every approved predicate;
- shift-zero rejection;
- missing-history fail-closed behavior;
- identical permission after EA restart at the same closed reference bar;
- identical permission across different tick arrival sequences;
- timezone/DST fixture where calendar predicates are used;
- log evidence that central news rejection wins even when pattern permission allows;
- incumbent-versus-`OFF` equivalence on identical binary logic where feasible;
- setfile guardrails, including fixed backtest risk and stale-news maximum.

## Pipeline re-entry and anti-overfit contract

A filtered variant changes who may enter, so it inherits **no** incumbent PASS. V5 says
entry-filter changes invalidate prior evidence (`C:/QM/repo/framework/V5_FRAMEWORK_DESIGN.md:20-32`).

1. Register the incumbent and exactly one filtered profile before viewing holdout results.
   Record every attempted profile in the family trial count.
2. Run Q02 from scratch and enforce the frequency floor. Filtering is not allowed to
   rescue PF by collapsing trade count.
3. Use Q03 only for a preregistered compact profile comparison; do not sweep the reference
   slot catalogue. The unfiltered parent is the mandatory control.
4. Preserve Q04 OOS chronology. No profile change after any holdout result is observed.
5. Re-run Q05 and Q06 on the filtered trade path under current cost/execution stress.
6. Re-run Q07 multiseed.
7. Rebuild Q08 DSR/FDR, PBO, neighborhood, tail/regime, concentration, and decay evidence.
   The number of profiles inspected—not merely the final profile—feeds the trial count.
8. Re-run Q09 news configuration and portfolio marginal contribution. The central news
   policy is never replaced by the pattern gate.
9. Run hash-bound Q10 confirmation with the locked profile and Q09 configuration.
10. Compare the filtered challenger directly with the contemporaneous unfiltered
    incumbent on the untouched holdout and sealed portfolio. A Q02–Q10 PASS alone does not
    authorize a swap.

## Final recommendation

**PURSUE_CONDITIONAL** for one narrow experiment: a source-derived, card-declared,
closed-D1 permission profile on one proven EA, implemented as an isolated challenger.

Reject the following:

- wholesale import of `Patterns.mqh`;
- any generic five-slot-per-direction sweep;
- shift-zero/current-bar predicates;
- the reference HMM;
- the reference news filter;
- the unwired price-action filter as a bolt-on;
- promotion based on the custom `OnTester()` rank.

The useful artifact is the small interface—`allow_buy`, `allow_sell`, evidence-bearing
reason—not the reference's pattern catalogue or optimization method.
