---
source_id: BOROWSKI-SCHWEIKERT-XAUXAG-WGAPFADE-2026
title: Gold/silver opposed weekend-gap ratio fade
publisher: Journal of Management and Financial Sciences / Applied Financial Economics / Journal of Banking & Finance
source_type: governed_composite_lineage
status: cards_ready
approval_basis: OWNER commodity/energy portfolio mission 2026-08-20
approval_ref: decisions/2026-08-20_xauxag_opposed_weekend_gap_fade_source_approval.md
created: 2026-08-20
created_by: Research+Development
parent_sources:
  - BOROWSKI-LUKASIK-METALS-2017
  - LUCEY-TULLY-DOW-2006
  - SCHWEIKERT-XAUXAG-RATIO-2026
strategy_ids:
  - BOROWSKI-SCHWEIKERT-XAUXAG-WGAPFADE-2026_S01
---

# Gold/Silver Opposed Weekend-Gap Fade Source Packet

## Approval And Complete-Read Scope

The OWNER mission dated 2026-08-20 directs one new structural, low-frequency
commodity edge and explicitly permits a market-neutral `XAUUSD` / `XAGUSD`
basket. The following bounded governed packets were read completely before
this extraction:

1. `strategy-seeds/sources/BOROWSKI-LUKASIK-METALS-2017/source.md`, which
   records the complete-paper review of Borowski and Lukasik (2017), the
   Friday-close-to-Monday-open definition, and the unequal reported gold and
   silver weekend effects.
2. `strategy-seeds/sources/LUCEY-TULLY-DOW-2006/source.md`, which records the
   complete 39-page author-copy review of Lucey and Tully (2006), weak and
   non-robust individual Monday means, and the untested positive historical
   gold-minus-silver Monday differential.
3. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, which
   records named peer-reviewed gold/silver cointegration evidence and the
   adverse finding that a constant relationship can fail across states.

The first two packets support the precious-metals weekend/Monday observation
clock. The third supports treating gold and silver as a related but
state-dependent relative-value carrier. None tests opposite-signed Darwinex
CFD weekend gaps, a one-session contrarian basket, equal-notional execution,
or the V5 lifecycle below. The conjunction and fade direction are a
pre-result QM falsification hypothesis, not an author claim.

## Findings Used

- Borowski and Lukasik define the weekend observation as Friday close to
  Monday open and report different gold and silver sample behavior.
- Lucey and Tully document both metals on the Monday clock while warning that
  the futures first-moment result is weak and statistically non-robust.
- Schweikert supports a long-run but potentially state-dependent gold/silver
  relationship, so a short-lived relative dislocation is testable but not
  presumed stationary.

No source return, profit factor, trade count, drawdown, hedge ratio, gap-fade
coefficient, CFD equivalence, market-neutrality statistic, or portfolio
correlation transfers.

## Bounded Mechanization

`BOROWSKI-SCHWEIKERT-XAUXAG-WGAPFADE-2026_S01` locks one D1 paired package:

- carrier: exact `XAUUSD.DWX` host and `XAGUSD.DWX` companion on D1, magic
  slots zero and one;
- decision clock: first executable tick of a genuine broker-Monday D1 bar,
  no later than 180 minutes after the synchronized bar open;
- observations: synchronized current Monday opens and the immediately prior
  synchronized completed Friday closes only;
- component gaps:
  `g_xau = ln(XAU_monday_open / XAU_friday_close)` and
  `g_xag = ln(XAG_monday_open / XAG_friday_close)`;
- signal: trade only when the two finite non-zero gaps have strictly opposite
  signs. When `g_xau > 0` and `g_xag < 0`, SELL XAU and BUY XAG. When
  `g_xau < 0` and `g_xag > 0`, BUY XAU and SELL XAG. Equality, zero, same-sign
  gaps, missing Friday, or timestamp disagreement is flat;
- attempt: persist the current broker-Monday date before spread, quote, ATR,
  sizing, news, or order gates once strict opposition exists; never retry that
  Monday;
- package: target one-to-one absolute entry notional with at most 20 percent
  lot-step mismatch while keeping combined broker-normalized stop risk at or
  below one `RISK_FIXED=1000` budget;
- risk: frozen `3.0 * ATR(20,D1)` hard stop on each leg, no target, XAU spread
  at or below 1,500 points, and XAG spread at or below 500 points; and
- lifecycle: close the complete package at the first synchronized later D1
  boundary, with immediate orphan/malformed repair and a four-calendar-day
  stale guard.

Both news axes are OFF, framework Friday close remains ON as an emergency
guard, and the backtest contract is `RISK_PERCENT=0`, `RISK_FIXED=1000`,
`PORTFOLIO_WEIGHT=1`. There is no magnitude threshold or parameter sweep.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,549 EA-registry rows and 625 root
cards and returned `CLEAN` for slug `xauxag-wgap-fade`, strategy ID
`BOROWSKI-SCHWEIKERT-XAUXAG-WGAPFADE-2026_S01`, and the declared mechanic.
Manual family review fixes the closest boundaries:

- `QM5_20019_xauxag-wkend` always buys XAU and sells XAG from Friday 21:00
  through Monday; this candidate observes the completed weekend gap first,
  requires strict component opposition, and fades either relative direction.
- `QM5_20095_auag-mon-diff` is an unconditional XAU-long/XAG-short Monday
  package; this candidate has a conditional two-sided direction and may remain
  flat.
- `QM5_20157_xau-xag-ratio`, `QM5_20161_xauxag-ols-rv`,
  `QM5_20263_xauxag-mad-rv`, and `QM5_20268_xauxag-qtail-rv` estimate rolling
  multi-session centers, residuals, or tails. This candidate estimates no
  center, beta, scale, quantile, or channel.
- `QM5_20275_gsr-runfade` requires five same-sign synchronized D1 relative
  returns. This candidate uses exactly one Friday-close-to-Monday-open event
  and requires the individual metal gaps to oppose.
- `QM5_41030`, `QM5_41039`, `QM5_41040`, and `QM5_41057` use weekly or monthly
  overnight/session flow decompositions. This candidate reads no within-day
  session return and exits at the next D1 boundary.
- `QM5_12533` supplies only the validated two-leg manifest/order recipe; its
  signal is an EURJPY/GBPJPY FX cointegration spread.

The exact carrier pair, synchronized Friday/Monday endpoints, strict opposed
component gaps, two-sided contrarian mapping, one-Monday attempt,
equal-notional aggregate-risk package, and next-D1 exit are jointly
load-bearing. Verdict:
`CLEAN_XAUXAG_OPPOSED_WEEKEND_GAP_ONE_SESSION_FADE_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: named peer-reviewed metals
  calendar and gold/silver relationship lineages support the observation
  clock and carrier; the opposed-gap fade is explicitly untested.
- R2 `PASS`: synchronized endpoints, strict opposition, direction, attempt,
  sizing, stops, spreads, and exit clock are fixed and deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: both registered DWX D1
  symbols provide every runtime observation; Q02 owns alignment, execution,
  density, and CFD-basis falsification.
- R4 `PASS`: native timestamp, OHLC, logarithm, ATR risk plumbing, quote,
  position, deal, and terminal state only; no ML, banned signal, external
  runtime feed, adaptive fit, grid, martingale, scale-in, or pyramid.

## Kill And Safety Boundary

Expected cadence is approximately five to twenty completed packages per full
post-warm-up year. Q02 must retire the unchanged identity on zero trades,
fewer than five completed packages per year, nonpositive governed economics,
wrong weekday endpoints, unsynchronized observations, same-sign or zero-gap
entry, wrong fade side, repeated/late entry, malformed basket, invalid fixed-
risk mode, or nondeterminism. A weak result may not be rescued by adding a
gap threshold, changing the weekdays, estimating a beta, changing the side,
or extending the hold.

This packet authorizes no manual backtest, terminal control, live/demo/shadow/
stress/optimization preset, AutoTrading action, `T_Live` change, deploy or
T_Live manifest, portfolio-gate mutation, portfolio admission, decorrelation
claim, or correlation waiver.
