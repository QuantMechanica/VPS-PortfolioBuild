# WTI Same-Calendar Jackknife Sign Stability — Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and one-slot magic allocation, one branch-only non-live build, strict
Q01 validation, and one paced Q02 enqueue only while the governed whole-host
CPU ceiling remains clear. This decision does not authorize a manual tester
run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. The mission requires one genuinely different,
structural, low-frequency commodity exposure outside the certified
XAU/SP500/NDX/XNG book, reputable-source criteria, and a `RISK_FIXED`
backtest preset. It excludes live and portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-samecal-jack6`
- proposed strategy ID:
  `KELOHARJU-NIST-WTI-SAMECAL-JACK6-2026_S01`
- proposed source ID: `KELOHARJU-NIST-WTI-SAMECAL-JACK6-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- decision clock: first executable host D1 tick after a genuine normalized
  broker-month transition
- state: the six arithmetic means obtained by deleting each observation once
  from the exact prior six matching-calendar-month WTI log returns
- participation: trade only when all six delete-one five-year means have the
  same strict sign
- lifecycle: follow that stable sign for one broker month, with one consumed
  attempt and a 40-calendar-day survivor repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Approved Source Basis And Complete-Read Evidence

The following durable repository records and bounded primary records were
read completely before this decision:

1. Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016),
   "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590,
   DOI `10.1111/jofi.12398`. The complete open NBER Working Paper 20815 is
   represented by
   `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
   `54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`.
2. Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2),
   228-250, DOI `10.1016/j.jfineco.2011.11.003`. Its complete-paper review
   record is `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
3. Heckert, N. A.; and Filliben, James J. (2003), *NIST Handbook 148:
   DATAPLOT Reference Manual*, Volumes I and II. The complete relevant
   `JACKNIFE INDEX` and `JACKNIFE ... PLOT` entries were reviewed at:
   `https://www.itl.nist.gov/div898/software/dataplot/refman2/ch2/jackindx.pdf`
   and
   `https://www.itl.nist.gov/div898/software/dataplot/refman1/ch2/jacknife.pdf`.
   NIST defines the construction by deleting each sample element in turn and
   recomputing the desired statistic, explicitly including the mean.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity
return information, monthly renewal, a five-year history floor, and explicit
crude-oil membership. Moskowitz, Ooi, and Pedersen supply explicit NYMEX WTI
membership, own-return direction, and monthly renewal. NIST supplies the
deterministic delete-one mean construction.

No source tests this conjunction. The exact six-year outer sample, all-six
same-sign participation gate, single continuous Darwinex CFD, epsilon,
fixed-dollar risk, ATR stop, spread cap, attempt ledger, and operational
lifecycle are transparent QM falsification choices. NIST describes jackknife
sampling-distribution analysis; it does not claim that sign agreement is a
trading signal. No source return, alpha, Sharpe ratio, drawdown, density,
cost, WTI-only result, CFD equivalence, decorrelation, or portfolio result
transfers.

## Locked Mechanic

At the first executable `XTIUSD.DWX` D1 tick after a genuine normalized
broker-calendar month transition in `(Y,M)`:

1. Repair malformed owned exposure and close the prior package before
   entry-only gates. Persist broker `yyyymm` before history, signal, news,
   spread, quote, ATR, sizing, or submission; never retry that month.
2. Under one uniform native or `+1` energy D1-label convention, reconstruct
   the completed WTI log return for calendar month `M` in each exact year
   `Y-6..Y-1`. Require strict adjacent-month endpoints, a confirming later D1
   bar, positive finite closes, and all six returns. Missing or invalid
   history consumes the month flat; no substitute year or shorter sample is
   permitted.
3. For chronological returns `r[0]..r[5]`, compute exactly six arithmetic
   means:

   ```text
   loo[k] = sum(r[i] for i=0..5 and i!=k) / 5,  k=0..5
   ```

   Every included value, sum, and mean must be finite. No return is deleted
   from runtime state; deletion exists only in each diagnostic recomputation.
4. With `epsilon=1e-12`, buy WTI only if every `loo[k] > +epsilon`. Sell WTI
   only if every `loo[k] < -epsilon`. Mixed signs or any value in the
   inclusive epsilon band consumes the month flat. Mean magnitude never
   changes risk.
5. Apply exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Attach one frozen `3.5 * ATR(20,D1)` broker hard
   stop, no target, and reject crossed or negative-spread quotes plus a
   genuinely positive spread above 1,500 points.
6. Close at the first later normalized broker-month boundary. A forty-day
   elapsed-calendar guard repairs only a survivor. Close duplicate,
   wrong-symbol, invalid-side, wrong-magic, or stopless owned exposure
   immediately.
7. Lock both current news axes and legacy news mode OFF and disable framework
   Friday flattening because the structural hold spans weekends.
8. Never retry, scale in, pyramid, grid, martingale, optimize, substitute an
   ordinary full-sample mean/median/trim/winsorization, drop a selected
   outlier, or weaken the unanimous sign condition.

Exact calendar-year membership, return orientation, six delete-one samples,
divisor five, epsilon, unanimity, consumed attempt, fixed risk, hard stop, and
monthly lifecycle are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_DELETE_ONE_GATE_AND_SINGLE_CFD_TRANSLATION_RISK`: two
  named-author, DOI-bearing, peer-reviewed trading papers with complete-read
  evidence support the same-calendar information object, explicit WTI
  carrier, own-return direction, and monthly renewal. NIST Handbook 148 makes
  the delete-one mean construction reproducible. The conjunction remains
  untested.
- R2 `PASS`: month clock, label normalization, exact endpoints, exact six
  years, all six delete-one subsets, divisor, epsilon, unanimous side,
  attempt state, risk, stop, spread, and exits are locked.
- R3 `PASS_WITH_SIX_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XTIUSD.DWX` D1 history plus MT5-native broker time,
  quotes, metadata, positions, deals, and terminal state supply every runtime
  field. History, label, roll, financing, gap, and CFD-basis risks remain
  binding.
- R4 `PASS`: timestamps, completed closes, logarithms, fixed sums, division,
  comparisons, ATR risk controls, and execution state only; no trained
  output, banned signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_jack6_preallocation_dedup_20260831.json`, SHA-256
`4A28903CEB2D62D74D3439D27552E892396CEA3171D55FDE133250946B1D7724`,
scanned 4,735 registry identities, 1,373 cards, and all 45 current Strategy
Wiki nodes. It found no exact identity and surfaced four expected fuzzy
same-calendar family matches for mandatory manual review.

For chronological returns
`[-0.020,-0.010,+0.001,+0.002,+0.003,+0.050]`, the full sum is `+0.026`.
The delete-one means are `+0.0092`, `+0.0072`, `+0.0050`, `+0.0048`,
`+0.0046`, and `-0.0048`; this card is flat because their signs disagree.
The existing exact last-five raw mean uses
`[-0.010,+0.001,+0.002,+0.003,+0.050]`, equals `+0.0092`, and buys. Its
last-five median is `+0.002` and buys. The four overlapping two-year means
used by `QM5_41227` have an even median of `+0.002` and buy.

For `[-0.001,+0.002,+0.003,+0.004,+0.005,+0.006]`, every delete-one mean
is strictly positive and this card buys. Sign reflection makes every
delete-one mean strictly negative and sells. Thus the sixth exact year and
all-six participation gate change whether risk exists; they are not a renamed
lookback or another robust-location estimate.

Verdict:
`FUZZY_FAMILY_MATCHES_RESOLVED_AS_SEMANTICALLY_DISTINCT_WTI_EXACT_SIX_YEAR_SAME_CALENDAR_DELETE_ONE_FIVE_YEAR_MEAN_UNANIMOUS_SIGN_MONTHLY_SLEEVE`.

## Kill And Safety Boundary

Expected cadence is approximately five to ten completed WTI positions per
full post-warm-up year; this is a pre-result estimate, not a source result.
Q02 retires on zero positions, fewer than five in any full scored year,
nonpositive governed economics, wrong normalized endpoints, missing exact
years, wrong subset membership, divisor, epsilon, unanimity or side,
current-month leakage, repeated entry, missing stop, wrong lifecycle,
nondeterminism, invalid risk mode, or insufficient history. Failure may not
be rescued by changing the sample, stability gate, direction, carrier, stop,
spread, hold, or retry policy.

The WTI carrier and recurring calendar clock target an exposure outside the
certified XAU/SP500/NDX/XNG set, but they do not prove low correlation. Only
unchanged Q09 may measure realized portfolio overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
if the governed whole-host CPU check remains clear. At a ceiling, stop before
queue mutation and record a non-live handoff.
