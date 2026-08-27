# QM5_41183 WTI Monthly Signed-KS Distribution-Shift Trend — G0 Decision

Date: 2026-08-27

Decision: `APPROVED` at G0 for one branch-only non-live V5 build, strict Q01
validation, independent review, and at most one paced Q02 enqueue under the
source and safety boundary in
`decisions/2026-08-27_wti_monthly_ks_distribution_shift_trend_source_approval.md`.

Authority: the current explicit OWNER commodity/energy portfolio mission on
`agents/board-advisor` and the committed source approval at `7d4d275f4`.

## Approved Identity

- EA ID: `41183`
- slug: `wti-mks-shift-tr`
- strategy ID: `MOP-NIST-KS2-WTI-MDIST-SHIFT-2026_S01`
- source ID: `MOP-NIST-KS2-WTI-MDIST-SHIFT-2026`
- host/traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- intended magic: `411830000`
- card of record:
  `strategy-seeds/cards/approved/QM5_41183_wti-mks-shift-tr_card.md`

The ID was reserved atomically by `farmctl reserve-ea-ids` after the source
approval and canonical dedup receipt existed. The resulting active row in
`framework/registry/ea_id_registry.csv` matches the exact slug and strategy
identity.

## G0 Gate Findings

### R1 — `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`

The bounded source packet
`strategy-seeds/sources/MOP-NIST-KS2-WTI-MDIST-SHIFT-2026/source.md`, SHA-256
`CDCEC4537A50040C1074C94FA5B29EF1038B9E72EB0798FF24D940021C2054BA`,
combines:

- complete-read peer-reviewed WTI monthly-continuation evidence from
  Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
  104(2), DOI `10.1016/j.jfineco.2011.11.003`; and
- the complete official NIST two-sample Kolmogorov-Smirnov method page,
  retrieved content SHA-256
  `15EB4DF37FB991D41A6AE16CEF8CD341124C24DB8A7B7078B11DC42E2C90A289`.

The sources support monthly WTI continuation lineage and the maximum gap
between two empirical distribution functions. They do not test the fixed
six-plus-six WTI CFD trade, signed boundary, risk, or lifecycle.

### R2 — `PASS`

The execution contract fixes:

- one decision on the first executable tick of a genuine broker month;
- exactly twelve consecutive completed month-end closes;
- fixed older `C[0..5]` and newer `C[6..11]` blocks;
- strict positive finite no-tie values;
- one combined ascending scan and both signed ECDF count maxima;
- inclusive count boundary three, dominant-side direction, and tied-max flat;
- consumed monthly attempt before every fallible gate;
- fixed-dollar risk, frozen ATR hard stop, spread cap, and next-month exit.

There is no critical table, p-value, variable split, endpoint fallback,
adaptive threshold, parameter sweep, or result-conditioned rescue.

### R3 — `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`

Registered `XTIUSD.DWX` D1 history, broker time, native symbol metadata,
quotes, ATR, positions, deals, and terminal global variables supply every
runtime input. Continuous-CFD roll, basis, financing, label, gap, and history
staleness risks remain explicit and belong to governed testing.

### R4 — `PASS`

The signal uses fixed comparisons and integer counts only. Runtime has no
trained output, prohibited signal dependency, external feed, grid,
martingale, scale-in, pyramid, or discretionary state.

## Locked Formula

For positive, finite, pairwise-distinct completed-month prices `C[0..11]`:

```text
O = C[0..5]
N = C[6..11]

scan all twelve values from low to high
delta = count_seen(O) - count_seen(N)
Dplus  = maximum delta
Dminus = maximum -delta

BUY  iff Dplus  >= 3 and Dplus  > Dminus
SELL iff Dminus >= 3 and Dminus > Dplus
FLAT otherwise
```

`Dplus/6` and `Dminus/6` are the one-sided ECDF gaps. The count form avoids
floating boundary ambiguity. A dominant positive gap means the newer block is
displaced higher and is continued long; the reflected gap is continued short.

Exact enumeration of all 924 no-tie old/new rank assignments yields 218 BUY,
218 SELL, and 488 flat states. Directional qualification is `109/231`, or
about 5.662 opportunities per twelve decisions. This is pre-market arithmetic
only, not significance or WTI evidence.

## Non-Duplicate Adjudication

The pre-allocation checker returned `CLEAN` across 4,682 registry identities,
1,333 card files, and 45 current-vault Wiki nodes. Receipt:
`artifacts/qm5_wti_mks_shift_tr_preallocation_dedup_20260827.json`, SHA-256
`D8EF38827C409D0015C6BF87C64C7FE5083495EB6ECF044A304CE0E14EF96ABD`.

The exact state function was manually resolved against its nearest neighbors:

- `QM5_41176` sums 36 Mann-Whitney cross-block wins; `QM5_41183` retains the
  maximum signed vertical ECDF gap.
- `QM5_41172` searches all possible Pettitt split locations; this rule locks
  the split after observation six.
- `QM5_20264` counts 78 chronological pairs across thirteen endpoints; this
  rule is invariant to order inside each fixed block.
- `QM5_41173` uses squared calendar-rank displacement; this rule uses only
  the largest cumulative membership imbalance.
- `QM5_41182` counts median-dichotomized chronological runs; this rule has no
  median and no run count.
- certified `QM5_12567` is a two-day, long-only XNG oscillator pullback, so it
  shares neither the WTI carrier, monthly clock, symmetric direction, nor
  distribution-shift state.

Separating fixtures are locked in the card and reference tests. In particular,
`[1,2,3,5,11,12,4,6,7,8,9,10]` buys here at `(Dplus,Dminus)=(3,2)` while
Mann-Whitney is flat at `U_new=23`; `[1,2,4,6,8,10,3,5,7,9,11,12]` is flat
here at `(2,0)` while Mann-Whitney buys at `U_new=26`.

Verdict:
`CLEAN_WTI_MONTHLY_FIXED_SIX_BY_SIX_SIGNED_KS_ECDF_GAP3_DISTRIBUTION_SHIFT_CONTINUATION`.

## Build Authorization And Boundary

Development may create exactly:

- `framework/EAs/QM5_41183_wti-mks-shift-tr/`;
- one exact `XTIUSD.DWX` D1 `RISK_FIXED` backtest preset;
- one active slot-zero magic row and regenerated resolver mapping; and
- source-aligned pure reference tests, strict compile evidence, review
  evidence, and one paced Q02 queue receipt.

The build must use `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, both news axes OFF/NONE, legacy news OFF, Friday close
OFF, a frozen `3.5*ATR(20,D1)` hard stop, and no target. It must consume the
month before any fallible entry gate and close at the next month or forty-day
stale boundary.

Forbidden: manual tester runs; live/demo/shadow/stress or optimization
setfiles; `T_Live`; AutoTrading; deploy or live manifests; portfolio-gate
edits; portfolio admission; correlation waivers; external runtime data;
terminal control; a second queue row; and claims of profitability,
certification, or decorrelation before governed evidence.

## Kill Conditions

Retire on zero trades, fewer than five completed positions in any full post-
warm-up Q02 year, nonpositive governed economics, any downstream gate failure,
or any endpoint, split, tie, count, boundary, side, attempt, risk, stop,
lifecycle, or determinism defect. A failure may not be rescued by changing
the sample, split, boundary, direction, carrier, risk, hold, or adding another
filter.

Direct WTI exposure is economically different from the stated directional
XAU/SP500/NDX/XNG book, but realized independence is unproven. Unchanged Q09
alone owns portfolio overlap.
