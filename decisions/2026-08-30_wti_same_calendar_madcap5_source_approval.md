# WTI Same-Calendar Five-Sample MAD-Capped Location — Source Approval

Date: 2026-08-30

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and one-slot magic allocation, one branch-only non-live build, strict
Q01 validation, and one paced Q02 enqueue if the governed tester and whole-host
CPU ceilings permit. This decision does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy sleeve mission on
branch `agents/board-advisor`. The mission requires one genuinely different,
structural, low-frequency commodity exposure outside the certified
XAU/SP500/NDX/XNG book, requires reputable-source criteria and a
`RISK_FIXED` backtest preset, and excludes live and portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-samecal-madcap5`
- proposed strategy ID:
  `KELOHARJU-MOP-WTI-SAMECAL-MADCAP5-2026_S01`
- proposed source ID: `KELOHARJU-MOP-WTI-SAMECAL-MADCAP5-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- decision clock: first executable host D1 tick after a genuine normalized
  broker-month transition
- state: equal-weight mean of the exact prior five matching-calendar-month WTI
  log returns after symmetric clipping at three raw MADs around their median
- lifecycle: follow the capped location sign for one broker month, with one
  consumed attempt and a 40-calendar-day survivor repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Approved Source Basis And Complete-Read Evidence

The following durable repository records were read completely before this
decision:

1. Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016),
   "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590,
   DOI `10.1111/jofi.12398`. The complete open NBER Working Paper 20815 is
   represented by
   `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
   `54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`,
   last committed as `a1dd9e7751f843db82c0b230a46ed7fe6526accd`.
2. Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2),
   228-250, DOI `10.1016/j.jfineco.2011.11.003`. The complete-paper review
   record is `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   last committed as `1c312453ad3a61978bc59c3aa0d3f51153daf93c`.
3. The approved governed median/MAD-cap packet
   `strategy-seeds/sources/MOP-WTI-MADCAP-2026/source.md`, SHA-256
   `3038077FD9268BAAF923B0B3BE11E71126B48F92605B5726B86527D10E7D464B`,
   last committed as `256c6da0d0df32c150baa9fa3e8e963f6553b05f`.
   It fixes raw-MAD centering, symmetric three-MAD bounds, retention of all
   observations after clipping, equal weights, and the explicit boundary that
   this arithmetic is a QM mechanization rather than a paper result.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity
return information, monthly renewal, a five-year history floor, and explicit
crude-oil membership. Moskowitz, Ooi, and Pedersen supply explicit NYMEX WTI
membership, own-return direction, and monthly renewal. The governed MAD-cap
packet supplies a reproducible robust-location arithmetic contract and its
claim limitations.

No source tests this exact conjunction. The exact five-year sample,
five-observation odd median/MAD, single continuous Darwinex CFD, fixed-dollar
risk, ATR stop, spread cap, attempt ledger, and operational lifecycle are
transparent QM falsification choices. No source return, coefficient,
significance, alpha, Sharpe ratio, drawdown, density, cost, WTI-only result,
CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

At the first executable `XTIUSD.DWX` D1 tick after a genuine normalized
broker-calendar month transition in `(Y,M)`:

1. Repair malformed owned exposure and close the prior package before
   entry-only gates. Persist broker `yyyymm` before history, signal, news,
   spread, quote, ATR, sizing, or submission; never retry that month.
2. Under one uniform native or `+1` energy D1-label convention, reconstruct
   the completed WTI log return for calendar month `M` in each exact year
   `Y-5..Y-1`. Require strict adjacent-month endpoints, a confirming later
   D1 bar, positive finite closes, and all five returns. Missing or invalid
   history consumes the month flat; no substitute year or shorter sample is
   permitted.
3. Sort a copy of the five returns ascending and set `median=s[2]`. Sort the
   five absolute deviations from that median and set `MAD=d[2]`. Reject a
   nonpositive or nonfinite MAD. Freeze:

   ```text
   lower = median - 3 * MAD
   upper = median + 3 * MAD
   ```

4. Clip every original chronological return into the inclusive frozen bounds
   and average all five clipped values with equal weight:

   ```text
   capped[i] = min(upper, max(lower, r[i]))
   location  = sum(capped[0..4]) / 5
   ```

   Require finite bounds, capped values, sum, and location. There is no return
   deletion, replacement by an order statistic, data-dependent divisor,
   reweighting, iteration, fallback center, or scale normalization.
5. Above `+1e-12`, buy WTI. Below `-1e-12`, sell WTI. Equality inside the
   inclusive epsilon band consumes the month flat. Signal magnitude never
   changes risk.
6. Apply exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Attach one frozen `3.5 * ATR(20,D1)` broker hard
   stop, no target, and reject crossed or negative-spread quotes plus a
   genuinely positive spread above 1,500 points.
7. Close at the first later normalized broker-month boundary. A forty-day
   elapsed-calendar guard repairs only a survivor. Close duplicate,
   wrong-symbol, invalid-side, wrong-magic, or stopless owned exposure
   immediately.
8. Lock both current news axes and legacy news mode OFF and disable framework
   Friday flattening because the structural hold spans weekends.
9. Never retry, scale in, pyramid, grid, martingale, optimize, or substitute a
   raw mean, ordinary median, fixed trim, endpoint Winsorization, trimean,
   midhinge, pseudomedian, shortest interval, block median, Huber location,
   bisquare location, sign score, or fitted cap multiplier.

Exact calendar-year membership, original-return orientation, median and MAD
indexes, raw scale, three-MAD bounds, inclusive clipping, five-term divisor,
side, consumed attempt, fixed risk, hard stop, and monthly lifecycle are
load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_ROBUST_LOCATION_AND_SINGLE_CFD_TRANSLATION_RISK`: two
  named-author, DOI-bearing, peer-reviewed trading papers with complete-read
  evidence support the same-calendar information object, explicit WTI
  carrier, own-return direction, and monthly renewal. The governed MAD-cap
  packet makes the exact arithmetic reproducible. The five-sample conjunction
  remains explicitly untested.
- R2 `PASS`: month clock, label normalization, exact-year endpoints, exact
  sample, median/MAD convention, cap multiplier, inclusive clipping, divisor,
  side, epsilon, attempt state, risk, stop, spread, and exits are deterministic
  and locked.
- R3 `PASS_WITH_FIVE_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XTIUSD.DWX` D1 history plus MT5-native broker time,
  quotes, symbol metadata, positions, deals, and terminal state supply every
  runtime field. History, label, roll, financing, gap, and CFD-basis risks
  remain binding.
- R4 `PASS`: timestamps, completed closes, logarithms, sorting, absolute
  deviations, clipping, finite arithmetic, ATR risk controls, and execution
  state only; no trained output, banned signal indicator, external runtime
  feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_madcap5_preallocation_dedup_20260830.json`,
SHA-256
`8CCFC5CC92A0CAAE750997FC3DE0E1F2C103085666F5CB8115F8069155163F50`,
scanned 4,731 registry identities, 1,369 cards, and all 45 current Strategy
Wiki nodes. It found no exact identity and one expected slug-family fuzzy
neighbor, `QM5_20099_wti-samecal`, for mandatory manual review.

Manual executable review establishes non-equivalence:

- Sorted returns `[-0.20,-0.05,+0.01,+0.03,+0.19]` have median `+0.01`, raw
  MAD `0.06`, frozen bounds `[-0.17,+0.19]`, and capped location `+0.002`, so
  this candidate buys. The raw mean is `-0.004`, middle-three mean about
  `-0.0033333333`, endpoint-Winsor mean `-0.006`, midhinge `-0.01`,
  shortest-three mean about `-0.0033333333`, inclusive-pair pseudomedian
  `-0.005`, and fixed bisquare location about `-0.00298325869`; those siblings
  sell, while the trimean is flat.
- Sorted returns `[-0.15,-0.03,0,+0.03,+0.04]` have median `0`, raw MAD
  `0.03`, frozen bounds `[-0.09,+0.09]`, and capped location `-0.01`, so this
  candidate sells. The median, middle-three mean, endpoint-Winsor mean,
  trimean, midhinge, and inclusive-pair pseudomedian are flat, while the
  earliest narrowest-three and fixed bisquare siblings buy.
- Sign reflection reverses both candidate mappings, so neither disagreement
  is a one-sided numerical accident.
- `QM5_20099` and `QM5_41055` use an arithmetic mean or ordinary historical
  median. `QM5_41199`, `QM5_41201`, `QM5_41202`, `QM5_41227`, `QM5_41228`,
  `QM5_41229`, `QM5_41230`, and `QM5_41231` use a fixed trim,
  inclusive-pair pseudomedian, endpoint order-statistic Winsorization,
  chronological block median, shortest-three interval, trimean, midhinge, or
  redescending bisquare location. None computes data-dependent symmetric
  raw-MAD bounds and retains all five clipped observations at equal weight.
- `QM5_20282_wti-madcap-mom` applies the MAD-cap family to twelve adjacent
  recent monthly returns. This candidate samples one named calendar month
  across five separate years; its seasonal information object and five-year
  clock are not a contiguous-horizon parameter port.

Verdict:
`FUZZY_FAMILY_MATCH_RESOLVED_AS_SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_RAW_MAD_CAPPED_EQUAL_WEIGHT_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Kill And Safety Boundary

Expected cadence is approximately ten to twelve completed WTI positions per
full post-warm-up year. Q02 retires on zero positions, fewer than five in any
full scored year, nonpositive governed economics, wrong normalized endpoints,
missing exact years, wrong return orientation, median/MAD defect, wrong cap,
exclusive clipping, dropped observation, wrong divisor, current-month leakage,
wrong side, repeated entry, missing stop, wrong lifecycle, nondeterminism,
invalid risk mode, or insufficient history. Failure may not be rescued by
changing the sample, statistic, cap, direction, carrier, stop, spread, hold,
or retry policy.

The WTI carrier and recurring calendar clock target an exposure outside the
certified XAU/SP500/NDX/XNG set, but they do not prove low correlation. Only
unchanged Q09 may measure realized portfolio overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
if the governed exact-path tester count and whole-host CPU checks pass. At a
ceiling, stop before queue mutation and record a non-live handoff.
