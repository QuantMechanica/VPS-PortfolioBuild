# July 2026 Strategy-Card Factory Audit — Phase 1

Date: 2026-09-01  
Agent task: `f91d364b-9e23-4175-a8df-f26cb5b759ac`  
Scope: formation and implementation audit only; read-only against queue and verdict state

## Executive verdict

The July population is not one homogeneous failure cohort. The reproducible
inventory contains **402 unique EA identifiers** from **170 card files touched
in canonical git during July** plus **346 runtime cards with a July lifecycle
date** (`created`, `created_at`, `approved_at`, `g0_approved_at`, or
`last_updated`), with 113 identifiers in both sources. Current ledger heads are
172 `FAIL`, 55 `PASS`, 44 with no work item, 19 `ZERO_TRADES`, and 112 spread
across pending, draft-defect, retired, invalid, compile, and other states.

A 24-card outcome-weighted deep audit found:

- 17 `STRATEGY_GENUINE`: card mechanics and current code align; negative evidence
  is economic/robustness evidence, not a demonstrated factory translation error.
- 2 `CARD_MALFORMED`: the approved card itself permits material, non-source
  substitutions and leaves the builder a choice of entry algorithms.
- 1 `IMPLEMENTATION_UNFAITHFUL`: the current EA cannot reconstruct its card's
  held-day exit state after restart.
- 4 `INFRA_KILLED`: the run is infrastructure-contaminated or the ledger's
  evidence path is now missing, so the first failed layer cannot be reproduced.

This phase made **no queue, work-item, verdict, card, EA, setfile, registry, or
pipeline mutation**. It does not promote, reject, or reopen any strategy.

## Inventory method and limitations

The inventory is the union of:

1. every `artifacts/cards_approved/*.md` path appearing in canonical git commits
   from 2026-07-01 through 2026-07-31; and
2. every runtime `D:/QM/strategy_farm/artifacts/cards_approved/*.md` whose
   lifecycle header contains a July 2026 date.

This deliberately catches both version-controlled approvals and runtime-only
approvals. `last_updated` is included because the older schema often used it as
the only durable approval-era date. Consequently, the 402-EA union is a
conservative complete audit population, not a claim that all 402 were first
authored in July. There are 169 unique git-side IDs, 346 runtime-side IDs, 56
git-only IDs, and 233 runtime-only IDs.

Git history also records a transient collision: `QM5_13032` was assigned to
both `xng-cot-fade` and `novo-crt-h4-sweep-reversal`. Commit `a2d833f23b`
resolved it by moving Novo to `QM5_13033`; current approved state is unique.
The event is a recovered control defect, not a current collision.

The ledger snapshot used for the outcome join contained 121,904 work items:
64,509 done, 49,037 failed, 8,353 pending, and 5 active. Outcome below means
the most recently updated work-item head for that EA. Historical verdicts are
preserved and were consulted in the deep audit.

## Deep audit protocol

The 24-card sample is weighted toward current `FAIL`, never-built/compile-only,
zero-trade/draft-defect, and historically infrastructure-contaminated outcomes.
For every sample member the audit checked:

- formation: source identifier/citation, literal timeframe in card body/header,
  deterministic entry/exit/risk wording, and declared P3/sweep space;
- implementation: card-to-MQ5 symbol/timeframe and entry/exit shape, every MQL5
  `input` having a non-declaration reference, news-request slot wiring, OnInit,
  setfile numeric serialization, and fixed-risk settings;
- evidence: latest and material historical Q-only verdicts and, for zero-trade
  rows, the bound report before treating zero trades as economics.

Across the 24 EAs there were **0 unwired MQL5 inputs**, **0 scientific-notation
set values**, **0 setfiles with `RISK_FIXED <= 0` or `RISK_PERCENT != 0`**, and
all had an OnInit path, news calls, and a symbol-slot marker. Those mechanical
checks do not override the card-specific findings below.

Many cards carry a `source_id` or wiki-style source link whose source object is
not resolvable under the canonical repository or runtime source roots. In those
cases this audit can verify that the coded mechanics match the approved card,
but cannot independently re-prove the upstream source extraction. Phase 2 must
bind the original source packet before changing any mechanics.

## Twenty-four card findings

| EA | Current/deep outcome | Formation and implementation finding | Class | Recovery path / cost |
|---|---|---|---|---|
| QM5_12841 | Q04 FAIL | D1 weekday-premium card is deterministic; current XTI reroute is explicit and inputs/exit are wired. | STRATEGY_GENUINE | Retain failure; new economic variant only, medium. |
| QM5_13018 | Q03 FAIL | Literal D1 volatility-compression breakout; ATR/range/exit inputs are wired. Source object was not locally resolved. | STRATEGY_GENUINE | No same-lineage threshold loosening; new variant, medium. |
| QM5_13019 | Q02 FAIL, minimum trades | D1 crisis short breakout is faithfully represented; repeated valid low-cadence failures. | STRATEGY_GENUINE | Research a separately approved cadence variant, medium. |
| QM5_13020 | Q02 PASS after Q03/Q04 FAIL | D1 AUDNZD cointegration-reversion mechanics and dual-symbol route are wired. | STRATEGY_GENUINE | Retain downstream failures; no cheap salvage. |
| QM5_13021 | Q02 PASS, Q04 FAIL | H4 zone fade matches card geometry and failed economically (fold PF 0.590/0.740/1.000). | STRATEGY_GENUINE | New variant only, medium. |
| QM5_13022 | Q02 pending after INVALID/INFRA_FAIL history | Card/code are mechanically aligned, but a documented 98.6 GB tester-journal incident and contaminated history prevent an economic verdict. | INFRA_KILLED | Bound, rate-limited diagnostic smoke on a free non-live lane, medium. |
| QM5_13023 | Q02 FAIL | D1 risk-off short is mechanically faithful; negative Q02 is not a demonstrated translation defect. | STRATEGY_GENUINE | New variant only, medium. |
| QM5_13031 | Q02 PASS, Q04 FAIL | Literal M15 BB/RSI/stop-entry implementation; all 32 inputs wired. Q04 folds 0.791/1.141/0.437 reject robustness. | STRATEGY_GENUINE | Low priority; a new approved hypothesis, high. |
| QM5_13033 | Q04 PASS_SOFT, Q05 FAIL | M5 execution of H4 range-sweep card is explicit and wired; Q05 DD was 36%, above the 15% gate. | STRATEGY_GENUINE | Do not relax DD; new card variant only, high. |
| QM5_20004 | Q04 soft, Q05 PASS, Q06 PASS, Q07 INFRA_FAIL | Card requires exit after N trading days. Current globals reset at OnInit and merely adopt today's key for an inherited position, extending a held trade after restart. | IMPLEMENTATION_UNFAITHFUL | Rehydrate from `POSITION_TIME`, compile, then same-bound rerun; medium. |
| QM5_20005 | Q02 FAIL, minimum trades | M5 quad-rotation/retest card and implementation align; valid evidence says cadence is insufficient. | STRATEGY_GENUINE | New card variant only, high. |
| QM5_20006 | Q02 PASS, Q04 FAIL | M30 intraday momentum was previously repaired from a zero-trade implementation and now trades; Q04 PF 0.887/0.511/0.702 is economic. | STRATEGY_GENUINE | Retain failure; no same-lineage repair. |
| QM5_20035 | Q02 ZERO_TRADES | D1 day-27 card and code appear aligned, but the ledger evidence path is missing. The prior run also followed an OnInit failure. First failed gate is not reproducible. | INFRA_KILLED | Restore/bind evidence or rerun unchanged with bounded diagnostics, low. |
| QM5_20036 | Q02 PASS, Q04 FAIL | D1 day-8 long is literal and wired; Q04 pooled PF 0.503 is economic failure. | STRATEGY_GENUINE | Retain failure; new regime variant only, medium. |
| QM5_20090 | COMPILE_OK only | Card explicitly substitutes a generic N-bar box for sourced ii/oii/ioi patterns, supplies unsourced TP/SL, and says the builder may choose either algorithm. | CARD_MALFORMED | Return to Research for one literal rule set and source binding, medium. |
| QM5_20091 | Q02 ZERO_TRADES | Card explicitly adds 15% proximity and TP scaling as Codex-fill choices. A valid second run had zero trades, but its referenced tester log and logger sample are absent, so entry-gate diagnosis is impossible. | CARD_MALFORMED | First repair card determinism, then evidence-bound diagnostic rerun, medium. |
| QM5_20128 | Q02 FAIL, minimum trades | M30 storage-release fade card is literal; release/reclaim/exit inputs are wired. | STRATEGY_GENUINE | New approved cadence hypothesis only, high. |
| QM5_20132 | Q02 DRAFT_DEFECT, zero trades | M30 live release-range breakout code is explicit and inputs are wired, but both referenced summary bundles are absent; no first failed gate can be established. | INFRA_KILLED | Unchanged-card diagnostic rerun with attempt/reject markers, medium. |
| QM5_20133 | Q02 FAIL, minimum trades | M30 WPSR pullback matches the approved release, reclaim, entry, stop and target sequence. | STRATEGY_GENUINE | New approved variant only, high. |
| QM5_20134 | Q02 DRAFT_DEFECT, zero trades | M30 deep-reclaim failure code is explicit and wired, but both referenced zero-trade bundles are absent. | INFRA_KILLED | Unchanged-card diagnostic rerun with attempt/reject markers, medium. |
| QM5_20135 | Q04 low-frequency PASS, Q05/Q06 PASS, Q07 FAIL | D1 winter trend implementation matches card. Q07 failed genuine seed PF variance (34.67% >= 20%), not infrastructure. | STRATEGY_GENUINE | Research-only candidate for a new robustness variant, high. |
| QM5_20136 | Q02 FAIL, minimum trades | D1 same-calendar/trend agreement is explicitly implemented and wired. | STRATEGY_GENUINE | New variant only, high. |
| QM5_20141 | Q02/Q03 PASS, Q04 FAIL | D1 July-November weekly short is literal; fold failure is economic. | STRATEGY_GENUINE | Retain failure; new variant only, medium. |
| QM5_20172 | fresh Q02/Q03 PASS, Q04 FAIL | D1 Friday bear-regime bounce is now generation-bound and faithful; Q04 2.427/0.648/0.725 rejects stability. | STRATEGY_GENUINE | Retain failure; no stale-build workaround or mechanics edit. |

For `QM5_20091`, the surviving bound summary proves source/deployed EX5 and set
hash equality, M5/GDAXI, real-tick marker, and one valid zero-trade run. It also
references files that are no longer present (`logger_sample.jsonl` and tester
log). For `QM5_20035`, `QM5_20132`, and `QM5_20134`, even the ledger-referenced
summary paths are absent. Per the zero-trades recovery contract, these cannot be
called genuine strategy failures until harness/setup/entry layers are proven.

## Ranked Phase-2 treasure list

1. **QM5_20004 — high expected impact / medium cost.** NDX evidence reached
   Q04 soft (mean PF 1.457), Q05 PASS (PF 1.050, DD 3.67%), and Q06 PASS
   (PF 1.100, DD 3.31%). Q07 was infrastructure-only (`BARS_ZERO`, empty
   expert/symbol, invalid history context). Repairing restart reconstruction is
   a same-card fidelity correction, after which the same bound chain can be
   rerun. This is the only sampled item with both deep positive evidence and a
   concrete repairable implementation defect.
2. **QM5_20135 — medium expected impact / high research cost.** It passed Q04
   low-frequency, Q05, and Q06 under the DD limits, but genuinely failed Q07
   seed dispersion. There is no same-lineage implementation repair. Treasure
   value exists only as a new, OWNER-approved robustness variant, not a rerun.
3. **QM5_20035 / QM5_20132 / QM5_20134 — uncertain impact / low-to-medium
   diagnostic cost.** Their evidence retention failure makes them cheap to
   classify, not presumptive winners. An unchanged-card diagnostic run can
   determine whether an entry hook was unreachable. Any threshold/session
   change requires a new card.
4. **QM5_20090 / QM5_20091 — uncertain impact / medium formation cost.** The
   source family may be testable, but only after Research chooses one literal
   sourced entry algorithm and separates all extensions into declared P3 axes.

No other sampled failure has a cheaper faithful recovery than accepting its
pipeline evidence or creating a separately approved hypothesis.

## Full inventory by current ledger head

This annex enumerates all 402 unique IDs. `PENDING_Qxx` means the latest row is
pending at that phase; it is not a verdict.

### FAIL (172)

QM5_1494, QM5_2076, QM5_9501, QM5_9642, QM5_9643, QM5_9644, QM5_9645, QM5_10282, QM5_10648, QM5_11301, QM5_11302, QM5_11362, QM5_11363, QM5_11401, QM5_11402, QM5_11434, QM5_11435, QM5_11455, QM5_11457, QM5_11461, QM5_11465, QM5_11689, QM5_11897, QM5_11898, QM5_12352, QM5_12767, QM5_12768, QM5_12783, QM5_12838, QM5_12839, QM5_12840, QM5_12841, QM5_12842, QM5_12844, QM5_12845, QM5_12846, QM5_12852, QM5_12854, QM5_12856, QM5_12859, QM5_12860, QM5_12861, QM5_12862, QM5_12863, QM5_12865, QM5_12868, QM5_12869, QM5_12870, QM5_12871, QM5_12873, QM5_12874, QM5_12893, QM5_12894, QM5_12895, QM5_12896, QM5_12897, QM5_12898, QM5_12910, QM5_12911, QM5_12913, QM5_12914, QM5_12917, QM5_12959, QM5_12960, QM5_12961, QM5_12962, QM5_12963, QM5_12965, QM5_12967, QM5_12968, QM5_12970, QM5_12973, QM5_12974, QM5_12976, QM5_12977, QM5_12978, QM5_12979, QM5_12985, QM5_12988, QM5_12993, QM5_13002, QM5_13003, QM5_13004, QM5_13006, QM5_13008, QM5_13009, QM5_13010, QM5_13011, QM5_13015, QM5_13018, QM5_13019, QM5_13021, QM5_13023, QM5_13024, QM5_13028, QM5_13030, QM5_13031, QM5_13032, QM5_13033, QM5_13034, QM5_13035, QM5_13042, QM5_13043, QM5_13044, QM5_13045, QM5_13050, QM5_13051, QM5_13052, QM5_13063, QM5_13067, QM5_13071, QM5_13074, QM5_13075, QM5_13077, QM5_13078, QM5_13088, QM5_13089, QM5_13090, QM5_13094, QM5_13095, QM5_13096, QM5_13097, QM5_13099, QM5_13100, QM5_13101, QM5_13102, QM5_13103, QM5_13104, QM5_13105, QM5_13109, QM5_13111, QM5_13112, QM5_13114, QM5_13115, QM5_13116, QM5_13120, QM5_13121, QM5_13132, QM5_13133, QM5_13139, QM5_13141, QM5_13142, QM5_13151, QM5_13202, QM5_13207, QM5_20005, QM5_20006, QM5_20013, QM5_20017, QM5_20018, QM5_20027, QM5_20030, QM5_20031, QM5_20038, QM5_20040, QM5_20052, QM5_20056, QM5_20061, QM5_20070, QM5_20071, QM5_20074, QM5_20075, QM5_20076, QM5_20128, QM5_20133, QM5_20136, QM5_20137, QM5_20167, QM5_20168, QM5_20171, QM5_20182, QM5_20186

### PASS (55)

QM5_1354, QM5_9576, QM5_9578, QM5_10973, QM5_11364, QM5_11592, QM5_12354, QM5_12847, QM5_12915, QM5_12916, QM5_12958, QM5_12966, QM5_12969, QM5_12971, QM5_12984, QM5_13007, QM5_13014, QM5_13020, QM5_13029, QM5_13057, QM5_13058, QM5_13062, QM5_13073, QM5_13107, QM5_13108, QM5_13110, QM5_13119, QM5_13126, QM5_13131, QM5_13140, QM5_13143, QM5_13144, QM5_13146, QM5_13149, QM5_13150, QM5_20004, QM5_20008, QM5_20010, QM5_20014, QM5_20015, QM5_20016, QM5_20028, QM5_20036, QM5_20046, QM5_20057, QM5_20124, QM5_20135, QM5_20141, QM5_20157, QM5_20164, QM5_20165, QM5_20172, QM5_20176, QM5_20185, QM5_20188

### NO_WORK_ITEMS (44)

QM5_1321, QM5_1323, QM5_1338, QM5_1528, QM5_1541, QM5_1545, QM5_1564, QM5_1566, QM5_1627, QM5_1628, QM5_1630, QM5_1670, QM5_1750, QM5_1753, QM5_2245, QM5_11212, QM5_11213, QM5_11214, QM5_11375, QM5_11376, QM5_11380, QM5_11531, QM5_11532, QM5_11533, QM5_11537, QM5_11539, QM5_11563, QM5_12351, QM5_13200, QM5_13201, QM5_13208, QM5_13211, QM5_20042, QM5_20053, QM5_20058, QM5_20065, QM5_20077, QM5_20078, QM5_20079, QM5_20080, QM5_20081, QM5_20087, QM5_20088, QM5_20175

### ZERO_TRADES (19)

QM5_1286, QM5_9354, QM5_13038, QM5_13123, QM5_20023, QM5_20032, QM5_20034, QM5_20035, QM5_20043, QM5_20044, QM5_20091, QM5_20145, QM5_20166, QM5_20169, QM5_20170, QM5_20173, QM5_20174, QM5_20177, QM5_20179

### Pending (48)

- Q02 (15): QM5_12430, QM5_12512, QM5_12972, QM5_12975, QM5_13022, QM5_13037, QM5_13085, QM5_13098, QM5_13137, QM5_13138, QM5_13148, QM5_13203, QM5_20060, QM5_20110, QM5_20184
- Q03 (10): QM5_11904, QM5_13060, QM5_13113, QM5_13118, QM5_13129, QM5_13130, QM5_13145, QM5_13147, QM5_20012, QM5_20045
- Q04 (16): QM5_1287, QM5_10645, QM5_10649, QM5_12433, QM5_12618, QM5_12851, QM5_12858, QM5_13000, QM5_13012, QM5_13072, QM5_20026, QM5_20033, QM5_20037, QM5_20041, QM5_20068, QM5_20072
- Q09 (2): QM5_12864, QM5_13076
- Q10_NEWS (2): QM5_13013, QM5_13059
- Q12 (3): QM5_9641, QM5_12855, QM5_20086

### DRAFT_DEFECT (14)

QM5_13064, QM5_13084, QM5_13134, QM5_20011, QM5_20069, QM5_20092, QM5_20132, QM5_20134, QM5_20153, QM5_20155, QM5_20156, QM5_20158, QM5_20159, QM5_20160

### RETIRE (13)

QM5_12867, QM5_12999, QM5_13005, QM5_13053, QM5_13079, QM5_13082, QM5_13083, QM5_13086, QM5_13087, QM5_13092, QM5_13093, QM5_13117, QM5_13212

### COMPILE_OK (10)

QM5_11291, QM5_11292, QM5_11299, QM5_11300, QM5_11496, QM5_11516, QM5_11517, QM5_11518, QM5_12778, QM5_20090

### INFRA_FAIL (10)

QM5_1312, QM5_12986, QM5_13036, QM5_13106, QM5_13209, QM5_20039, QM5_20062, QM5_20082, QM5_20085, QM5_20178

### INVALID (8)

QM5_1560, QM5_1626, QM5_11325, QM5_11388, QM5_11619, QM5_12435, QM5_12436, QM5_20073

### Other terminal heads (9)

- FAIL_HARD (3): QM5_1355, QM5_12781, QM5_13017
- COMPILE_FAIL (2): QM5_12401, QM5_20089
- FAIL_DD_PORTFOLIO_REVIEW (1): QM5_13016
- INVALID_BUILD_STATIC_FIDELITY (1): QM5_13210
- PASS_LOWFREQ (1): QM5_12355
- REVIEW_REQUIRED (1): QM5_11294

## Phase-2 boundary

Phase 2 should be separately authorized and limited to the ranked items above.
It must begin by restoring execution identity and missing evidence, not by
changing thresholds. No selection rule, gate, candidate universe, or historical
verdict should be changed from this report.
