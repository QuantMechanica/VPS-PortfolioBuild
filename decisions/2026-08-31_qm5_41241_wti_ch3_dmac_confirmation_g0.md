# G0 Decision — QM5_41241 WTI CH3 / DMAC Confirmation

Date: 2026-08-31

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy sleeve mission,
bounded by the durable source approval
`decisions/2026-08-31_wti_ch3_dmac_confirmation_source_approval.md` at commit
`a3bbf2095` and the complete candidate packet committed at `a44017c5a`.

Approved card:
`strategy-seeds/cards/approved/QM5_41241_wti-ch3-dmac-confirm_card.md`.

## Identity

- EA ID: `QM5_41241`, atomically reserved at commit `8b0cc55e6`
- slug: `wti-ch3-dmac-confirm`
- strategy ID: `SZAKMARY-WTI-CH3-DMAC-CONFIRM-2026_S01`
- source ID: `SZAKMARY-WTI-CH3-DMAC-CONFIRM-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1, intended magic `412410000`
- mechanic: at each genuine broker-month transition, require the latest
  completed WTI month end to be both a strict prior-three closing breakout
  and beyond its six-close arithmetic mean by more than the symmetric 2.5%
  neutral band in the same direction, then hold one renewed monthly package

## Gate Findings

- R1 `PASS_WITH_UNTESTED_CONJUNCTION_AND_SINGLE_CFD_TRANSLATION_RISK`: one
  complete-reviewed, DOI-bearing, peer-reviewed commodity-futures study
  supplies both parent rule families and crude-oil membership. The AND
  conjunction and single-CFD port remain untested.
- R2 `PASS`: broker-month clock, exact six consecutive completed endpoints,
  strict prior-three channel, arithmetic six-close mean, exact symmetric band,
  AND state, consumed attempt, risk, stop, spread, and renewal are mechanical
  and locked.
- R3 `PASS_WITH_CONTINUOUS_FUTURES_CFD_BASIS_AND_MONTH_END_RECONSTRUCTION_RISK`:
  registered WTI D1 history and native MT5 state provide every runtime field.
  History, labels, financing, rolls, gaps, and CFD basis remain binding.
- R4 `PASS`: deterministic timestamps, closes, extrema, fixed arithmetic,
  comparisons, and V5 execution plumbing only; no trained signal, prohibited
  runtime feed, grid, martingale, scale-in, or pyramid.

## Duplicate Review

The corrected-root canonical receipt
`artifacts/qm5_wti_ch3_dmac_confirm_preallocation_dedup_20260831.json`,
SHA-256
`B61748E06968490A41476ED976043288A5C49046244B04EBFF0394B44364DF40`,
is clean across 4,740 registry identities, 1,378 cards, and 45 Strategy Wiki
nodes.

- `[103,100,99,98,120,120]`: CH3 buys, DMAC sells, candidate stays flat.
- `[110,111,109,108,80,80]`: CH3 is flat, DMAC buys, candidate stays flat.
- `[120,110,105,100,95,90]`: both parents and candidate buy.
- `[80,90,95,100,105,110]`: both parents and candidate sell.

The conjunction is neither the built `QM5_20008` CH3 parent nor the built
`QM5_13100` DMAC parent. It also renews every accepted package after one month
rather than carrying an unchanged DMAC state.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_MONTHLY_CH3_BREAKOUT_AND_DMAC16_NEUTRAL_BAND_CONFIRMATION_SLEEVE`.

## Approved Build Contract

Development may build exactly the approved card after deterministic magic
verification with:

- exact `XTIUSD.DWX` D1 slot 0 under registered magic `412410000`;
- first genuine broker-month transition and one persistent `yyyymm` attempt
  recorded before every fallible entry gate;
- exactly six consecutive completed broker-month endpoints, a confirming
  current-month bar, no substitute month, and no current-month price;
- exact `C0 > max(C1,C2,C3)` / `C0 < min(C1,C2,C3)` strict channel state;
- exact arithmetic mean of `C0..C5`, strict `1.025` / `0.975` band state, and
  same-direction AND agreement only;
- exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` in one D1
  backtest setfile;
- a frozen `4.0 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread
  ceiling;
- both current news axes and legacy news OFF, framework Friday close OFF,
  malformed-position repair, next-month renewal, and a 40-day survivor guard;
  and
- deterministic reference fixtures, card lint, strict compile, registry,
  resolver, setfile, and static Q01 validation before Q02 handoff.

No alternate horizon, band, mean, OR relation, vote, magnitude sizing,
current-month price, daily channel, season, event, inventory, curve, volume,
optimizer output, trained signal, external runtime input, retry, carry-through
renewal, scale-in, grid, martingale, pyramid, or after-result rescue is
approved.

## Pipeline And Safety Boundary

This G0 decision authorizes the branch-only non-live build, one `RISK_FIXED`
backtest setfile, strict Q01, and one paced Q02 enqueue only while the fresh
whole-host CPU window remains strictly below the 97% ceiling. It does not
authorize a manual tester dispatch or tester control.

Q02 must retire on zero positions, fewer than five in any full scored year,
nonpositive governed economics, wrong endpoints, current-month leakage, wrong
channel/mean/band/agreement state, repeated entry, missing stop, wrong renewal,
nondeterminism, invalid risk mode, or insufficient history. Q09 alone may
establish realized portfolio correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate edits;
portfolio admission; decorrelation claims; and correlation waivers.
