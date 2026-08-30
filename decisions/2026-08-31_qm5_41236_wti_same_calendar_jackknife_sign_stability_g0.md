# G0 Decision — QM5_41236 WTI Same-Calendar Jackknife Sign Stability

Date: 2026-08-31

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy sleeve mission,
bounded by the durable source approval
`decisions/2026-08-31_wti_same_calendar_jackknife_sign_stability_source_approval.md`
at commit `2e2bdf203` and the complete candidate packet committed at
`a3750fa20`.

Approved card:
`strategy-seeds/cards/approved/QM5_41236_wti-samecal-jack6_card.md`.

## Identity

- EA ID: `QM5_41236`, atomically reserved at commit `040d7e37b`
- slug: `wti-samecal-jack6`
- strategy ID: `KELOHARJU-NIST-WTI-SAMECAL-JACK6-2026_S01`
- source ID: `KELOHARJU-NIST-WTI-SAMECAL-JACK6-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1, intended magic `412360000`
- mechanic: at each genuine normalized broker-month transition, reconstruct
  the exact prior six matching-calendar-month WTI returns, compute all six
  delete-one five-year arithmetic means, follow their sign only when every
  mean agrees, and renew next month

## Gate Findings

- R1 `PASS_WITH_DELETE_ONE_GATE_AND_SINGLE_CFD_TRANSLATION_RISK`: two
  complete-read, DOI-bearing, peer-reviewed trading papers support recurring
  same-calendar commodity information, explicit WTI membership, own-return
  direction, and monthly renewal. NIST Handbook 148 fixes the deterministic
  delete-one mean construction. The unanimous-sign trading conjunction
  remains untested.
- R2 `PASS`: month clock, label normalization, exact endpoints, exact six
  years, all six five-observation subsets, divisor five, epsilon, unanimous
  side, attempt, risk, stop, spread, and lifecycle are mechanical and locked.
- R3
  `PASS_WITH_SIX_YEAR_WARMUP_SESSION_LABEL_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered XTI D1 history and native MT5 state provide every runtime field.
  Warm-up, label, roll, financing, gap, and CFD-basis risks remain binding Q02
  items.
- R4 `PASS`: deterministic timestamps, logarithms, finite sums, division,
  comparisons, and V5 execution plumbing only; no trained signal, prohibited
  runtime feed, grid, martingale, scale-in, or pyramid.

## Duplicate Review

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_jack6_preallocation_dedup_20260831.json`, SHA-256
`4A28903CEB2D62D74D3439D27552E892396CEA3171D55FDE133250946B1D7724`,
found no exact identity across 4,735 registry identities, 1,373 cards, and 45
Strategy Wiki nodes. Four expected same-calendar fuzzy matches were manually
resolved.

- On chronological
  `[-0.020,-0.010,+0.001,+0.002,+0.003,+0.050]`, this card is flat because
  its delete-one means include both positive values and `-0.0048`.
- The existing exact newest-five raw mean is `+0.0092`, the newest-five
  median is `+0.002`, and `QM5_41227`'s block-median state is `+0.002`; those
  siblings buy the same fixture.
- On `[-0.001,+0.002,+0.003,+0.004,+0.005,+0.006]`, every delete-one mean is
  positive and this card buys; sign reflection sells.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_SIX_YEAR_SAME_CALENDAR_DELETE_ONE_FIVE_YEAR_MEAN_UNANIMOUS_SIGN_MONTHLY_SLEEVE`.

## Approved Build Contract

Development may build exactly the approved card after deterministic magic
verification with:

- exact `XTIUSD.DWX` D1 slot 0 under registered magic `412360000`;
- native same-day or one uniform `+1` energy-label normalization, with the
  normalized current D1 date equal to broker date;
- first genuine broker-month transition and one persistent `yyyymm` attempt
  recorded before every fallible entry gate;
- exact years `Y-6..Y-1`, strict adjacent calendar endpoints, later
  confirming bars, no substitute year, and no current-month data;
- exactly six delete-one five-return arithmetic means, exact divisor five,
  finite arithmetic, strict epsilon `1e-12`, and unanimous sign;
- every mean above `+1e-12` mapped to buy, every mean below `-1e-12` mapped
  to sell, and mixed/tied states consumed flat;
- exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` in one D1
  backtest setfile;
- a frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread
  ceiling;
- both current news axes and legacy news OFF, framework Friday close OFF,
  malformed-position repair, next-month renewal, and a 40-day survivor guard;
  and
- deterministic reference fixtures, card lint, strict compile, registry,
  resolver, setfile, and static Q01 validation before Q02 handoff.

No full-sample fallback, selected return deletion, mean magnitude sizing,
median, trim, Winsorization, pseudomedian, robust fitted location, majority
vote, t-score, confidence interval, current-month price, fixed-month
direction, recent trend, curve, storage, inventory, event, volume, optimizer
output, trained signal, external runtime input, retry, scale-in, grid,
martingale, pyramid, or after-result rescue is approved.

## Pipeline And Safety Boundary

This G0 decision authorizes the branch-only non-live build, one `RISK_FIXED`
backtest setfile, strict Q01, and one paced Q02 enqueue only while the fresh
whole-host CPU window remains strictly below the 97% ceiling. It does not
authorize a manual tester dispatch or tester control.

Q02 must retire on zero positions, fewer than five in any full post-warm-up
year, nonpositive governed economics, wrong endpoints, missing exact years,
wrong return orientation, subset membership, divisor, epsilon, unanimity,
current-month leakage, wrong side, repeated entry, missing stop, wrong
lifecycle, nondeterminism, invalid risk mode, or insufficient history. Q09
alone may establish realized portfolio correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate edits;
portfolio admission; decorrelation claims; and correlation waivers.

