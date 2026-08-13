# QM5_20303 WTI Self-Relative Smooth-Volatility-Beta Regime G0 Authorization

Date: 2026-08-13

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded V5 Strategy Card and non-live build for
`QM5_20303_wti-volbeta-reg`. On the first processed WTI D1 bar after a genuine
broker-month transition, the candidate estimates WTI's sensitivity to changes
in a price-native smooth common-energy realized-volatility proxy over two
consecutive, non-overlapping 272-return blocks. It buys WTI when the recent
smooth-volatility beta is higher than the preceding beta and sells WTI when it
is lower.

The candidate may proceed through bounded source/card extraction, schema and
G0 lint, deterministic registry and magic allocation, resolver regeneration,
strict compile, one `RISK_FIXED` backtest setfile, Q01 validation, and one
paced Q02 enqueue. Authorization does not pre-approve efficacy,
diversification, decorrelation, certification, execution-contract promotion,
or portfolio admission.

## Source Boundary

The approved source is Hollstein, Prokopczuk, and Tharann (2021), "Anomalies
in Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017, DOI `10.1142/S2010139221500178`. The governed complete-read packet at
`strategy-seeds/sources/HOLLSTEIN-AGGVOL-2021/source.md`, SHA-256
`F8DB880A24BD0F24D75AFA0DF4DF192EE019321391E304B8B45A84929BA334DC`,
records the accepted manuscript and online-appendix review. It defines a
prior-twelve-month aggregate smooth-volatility-beta characteristic, monthly
commodity sorts, and a positive high-minus-low direction.

The source factor is option-derived and market-wide and includes an equity-
market control. It does not test an outright WTI continuous CFD, a two-name
realized energy benchmark, return-based jump exclusion, or an own-history
beta comparison. The existing two-leg sibling `QM5_13151_energy-volbeta`
recorded Q02 PF 1.46, net profit 1,894.48, and 46 trades, passed Q03 through
Q07, then failed Q08 hard because its runs-test p-value was `0.02295`; it also
lost money in the Q08 low-volatility regime. Those facts are material family
evidence but do not transfer to this carrier or waive any gate.

The realized-volatility proxy, two-CFD benchmark, two-block comparison,
outright direction, fixed-dollar sizing, ATR hard stop, spread ceiling,
restart ledger, and lifecycle controls are transparent QM mechanizations. No
source or sibling return, alpha, significance, trade density, CFD equivalence,
correlation result, or portfolio conclusion transfers.

## Locked Rule

Load exactly 545 synchronized completed `XTIUSD.DWX` and `XNGUSD.DWX` D1
closes and form 544 chronological simple returns. Split them into a preceding
block `b=0` and a recent block `b=272`, each containing exactly 272 returns.
The blocks share only their boundary close and share no return observation.

For each block independently:

```text
rank span                 = return indices 20..271 (252 observations)
sd_XTI, sd_XNG            = sample standard deviation on the rank span
w_i                       = (1 / sd_i) / ((1 / sd_XTI) + (1 / sd_XNG))
m_t                       = w_XTI * r_XTI,t + w_XNG * r_XNG,t, t=0..271
mean_m, sd_m              = mean and sample sd of m_t on indices 20..271
RV20_t                    = sample sd(m_[t-19..t]), t=20..271
smooth_t                  = 0 when abs(m_t - mean_m) >= 2 * sd_m
                            else RV20_t - RV20_[t-1]

r_XTI,t = alpha + beta_energy * m_t + beta_smooth * smooth_t + error_t
           by intercept OLS on exactly t=20..271
```

Require at least 200 non-jump observations, positive finite sample standard
deviations, a full-rank three-column normal equation, and a finite
`beta_smooth` in each block. The two blocks calculate their inverse-volatility
weights, mean, standard deviation, jump classification, realized-volatility
series, and OLS coefficients independently.

```text
BUY  when beta_smooth_recent > beta_smooth_preceding + 1e-12
SELL when beta_smooth_recent < beta_smooth_preceding - 1e-12
FLAT otherwise or when either state is invalid
```

Require exact timestamp synchronization between XTI and XNG, strictly ordered
completed series, positive finite closes, a newest completed endpoint before
the decision bar and no more than ten calendar days stale, exactly 252 OLS
observations per block, and no shared return between blocks. Do not substitute
log returns, population standard deviations, equal weights, pooled weights,
an alternate realized-volatility window, a fitted jump threshold, dropped
jump-day rows, ridge regression, a beta normalization, a trend/calendar
filter, score-sized risk, or an alternate direction.

Consume and persist the broker month before history, signal, spread, quote,
news, ATR, sizing, or order gates. Use one `RISK_FIXED=1000` WTI position with
a frozen `3.5 * ATR(20,D1)` hard stop, a 1,500-point entry-spread cap, and no
take-profit. Close before monthly replacement or after forty calendar days.
Friday close and both news axes are OFF. XNG is a read-only signal input and
must never be ordered, assigned a magic, or counted as a package leg. At most
one registered WTI position exists.

## Reputable-Source Criteria

- R1: PASS with translation and adverse-family caveats retained: named peer-
  reviewed QJF source, DOI, complete accepted-manuscript/appendix read, exact
  aggregate smooth-volatility-beta direction, and sibling Q08 failure.
- R2: PASS: exact synchronized return support, block offsets, inverse-volatility
  benchmark, 20-return sample volatility, two-sigma exclusion, three-column
  OLS, direction, attempt ledger, risk, stop, rollover, and stale guard.
- R3: PASS for the disclosed proxy: registered `XTIUSD.DWX` and
  `XNGUSD.DWX` D1 OHLC suffice, but realized two-CFD volatility is not the
  source option-implied aggregate factor. XNG is read-only.
- R4: PASS: deterministic native arithmetic only, without trained output,
  prohibited signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,368 EA-registry rows and 479
cards. It found no exact slug or strategy-ID identity and surfaced one fuzzy
source-family neighbor. Manual mechanic review resolves it:

- `QM5_13151_energy-volbeta` estimates concurrent XTI and XNG betas in one
  272-return block, ranks the two values, opens opposite legs, splits package
  risk, and repairs orphans. This candidate estimates WTI beta in two disjoint
  history blocks, compares recent with preceding, owns one WTI position, and
  treats XNG only as a read-only benchmark component.
- `QM5_20298_wti-vov-regime` measures dispersion-over-mean across 252 rolling
  WTI realized-volatility levels in each block. It fits no return regression,
  common-energy factor, jump exclusion, or smooth-volatility coefficient.
- `QM5_20300`, `QM5_20301`, and `QM5_20302` compare MAX, expected-shortfall,
  and activity-scaled absolute-return statistics; none estimates a factor
  sensitivity.
- WTI trend, calendar, event, breakout, reversal, variance-ratio, skewness,
  kurtosis, and robust-location EAs use different information objects or
  clocks. `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback.

The synchronized XTI/XNG inputs, block-local inverse-volatility weights,
20-return sample-volatility changes, locked two-sigma zeroing, intercept plus
two-regressor OLS, offsets `0/272`, high-beta direction, outright WTI topology,
and consumed monthly lifecycle are jointly load-bearing. Verdict:
`CLEAN_AUTHORIZED_WTI_TIME_SERIES_SMOOTH_VOL_BETA_AFTER_MANUAL_REVIEW`.

## Allocation And Kill Boundary

- intended EA ID: `QM5_20303`, subject to deterministic registry allocation;
- slug: `wti-volbeta-reg`;
- strategy ID: `HOLLSTEIN-AGGVOL-2021_XTI_TS_S02`;
- intended symbol/slot/magic: `XTIUSD.DWX` / 0 / `203030000`;
- read-only signal symbol: `XNGUSD.DWX`, with no magic or order authority;
- expected cadence: approximately eleven to twelve completed monthly WTI
  positions per full post-warm-up year;
- retire below five completed positions per year, on nonpositive governed
  economics, or at later portfolio-correlation rejection;
- fail on timestamp misalignment, wrong block support, pooled block weights,
  wrong standard-deviation denominator, wrong RV window, wrong jump handling,
  too few smooth days, singular OLS, reversed direction, retry, XNG order,
  missing stop, risk mismatch, hold beyond forty days, or nondeterminism; and
- no post-result return type, block, estimator, threshold, direction, stop,
  hold, spread, retry, or carrier rescue is authorized.

The WTI carrier and smooth common-energy volatility sensitivity are
diversification hypotheses, not correlation evidence. Q09 alone may establish
realized overlap with the current XAU/SP500/NDX/XNG book.

## Safety Boundary

This authorization excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 uses
exactly one `XTIUSD.DWX` D1 setfile with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. If the paced factory reaches its binding backtest
CPU ceiling before enqueue, record the stop and do not enqueue or run a manual
test.
