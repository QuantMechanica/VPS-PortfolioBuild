# QM5_20304 WTI Self-Relative Common-Jump-Beta Regime G0 Authorization

Date: 2026-08-13

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded V5 Strategy Card and non-live build for
`QM5_20304_wti-jumpbeta-reg`. On the first processed WTI D1 bar after a genuine
broker-month transition, the candidate estimates WTI's incremental sensitivity
to a price-native common-energy jump proxy over two consecutive, non-overlapping
252-return blocks. It buys WTI when the recent jump beta is lower than the
preceding beta and sells WTI when it is higher.

The candidate may proceed through bounded source/card extraction, schema and G0
lint, deterministic registry and magic allocation, resolver regeneration,
strict compile, one `RISK_FIXED` backtest setfile, Q01 validation, and one paced
Q02 enqueue. Authorization does not pre-approve efficacy, diversification,
decorrelation, certification, execution-contract promotion, or portfolio
admission.

## Source Boundary

The approved primary source is Hollstein, Prokopczuk, and Tharann (2021),
"Anomalies in Commodity Futures Markets," *Quarterly Journal of Finance* 11(4),
article 2150017, DOI `10.1142/S2010139221500178`. The governed complete-read
packet at `strategy-seeds/sources/HOLLSTEIN-AGGJUMP-2021/source.md`, SHA-256
`88E56C93892D2382B7EFA4DB9130991EB1B7C0999C549520F9D3BA9510684D44`, records
the accepted manuscript, online appendix, and aggregate-jump characteristic.
Nguyen and Prokopczuk (2019), "Jumps in Commodity Markets," *Journal of
Commodity Markets* 13, 55-70, DOI `10.1016/j.jcomm.2018.10.002`, supplies only
peer-reviewed energy co-jump context.

The primary source estimates each commodity's sensitivity to an option-derived
aggregate jump factor while controlling for market return, sorts a broad
commodity-futures cross-section monthly, and reports a negative high-minus-low
spread. That orientation fixes low jump beta long and high jump beta short. It
does not test an outright WTI continuous CFD, a two-name realized energy factor,
or an own-history beta comparison.

The existing two-leg sibling `QM5_13147_energy-jumpbeta` is material adverse
family evidence. It reached Q08 after passing earlier deterministic phases, but
Q08 failed hard on runs-test `p=0.04487`; its low- and normal-volatility regime
P&L were negative. The Q08 baseline recorded PF 1.10 and 83 trades. Those facts
do not transfer performance to this carrier and authorize no rescue or waiver.

## Locked Rule

Load exactly 505 synchronized completed `XTIUSD.DWX` and `XNGUSD.DWX` D1 closes
and form 504 chronological simple returns. Split them into a preceding block
`b=0` and recent block `b=252`, each containing exactly 252 returns. The blocks
share only their boundary close and share no return observation.

For each block independently:

```text
sd_XTI, sd_XNG = sample standard deviations over all 252 block returns
w_i             = (1 / sd_i) / ((1 / sd_XTI) + (1 / sd_XNG))
m_t             = w_XTI * r_XTI,t + w_XNG * r_XNG,t
mean_m, sd_m    = mean and sample sd of all 252 m_t observations
jump_t          = m_t - mean_m when abs(m_t - mean_m) >= 2 * sd_m
                  else 0

r_XTI,t = alpha + beta_energy * m_t + beta_jump * jump_t + error_t
           by intercept OLS on exactly 252 rows
```

Require positive finite sample deviations, at least six nonzero jump rows, a
full-rank three-column normal equation, and a finite `beta_jump` in each block.
Each block calculates its own weights, factor mean, factor sample deviation,
jump classification, and OLS coefficients.

```text
BUY  when beta_jump_recent < beta_jump_preceding - 1e-12
SELL when beta_jump_recent > beta_jump_preceding + 1e-12
FLAT otherwise or when either state is invalid
```

Require exact timestamp synchronization, strictly ordered completed series,
positive finite closes, a newest completed endpoint before the decision bar and
no more than ten calendar days stale, and no shared return between blocks. Do
not substitute log returns, population deviations, equal or pooled weights, a
different jump threshold, dropped non-jump rows, total beta, ridge regression,
a trend/calendar filter, score-sized risk, or an alternate direction.

Consume and persist the broker month before history, signal, spread, quote,
news, ATR, sizing, or order gates. Use one `RISK_FIXED=1000` WTI position with a
frozen `3.5 * ATR(20,D1)` hard stop, a 1,500-point entry-spread cap, and no
take-profit. Close before monthly replacement or after forty calendar days.
Friday close and both news axes are OFF. XNG is read-only and must never be
ordered, assigned a magic, or counted as a package leg.

## Reputable-Source Criteria

- R1: PASS with translation and adverse-family caveats retained: named peer-
  reviewed QJF source, DOI, complete accepted-manuscript/appendix evidence,
  exact aggregate-jump direction, peer-reviewed energy-jump supplement, and
  sibling Q08 failure.
- R2: PASS: exact synchronized return support, disjoint block offsets,
  inverse-volatility benchmark, fixed two-sigma jump factor, three-column OLS,
  source-consistent direction, consumed attempt, risk, stop, rollover, and
  stale guard.
- R3: PASS for the disclosed proxy: registered `XTIUSD.DWX` and `XNGUSD.DWX`
  D1 OHLC suffice, but a realized two-CFD factor is not the source option
  factor. XNG is read-only.
- R4: PASS: deterministic native arithmetic only, without trained output,
  prohibited signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,369 EA-registry rows and 480
cards. It found no exact slug or strategy-ID identity and surfaced one expected
source-family fuzzy neighbor. Manual mechanic review resolves it:

- `QM5_13147_energy-jumpbeta` estimates concurrent XTI and XNG coefficients in
  one block, ranks the two values, opens opposite legs, and splits package risk.
  This candidate estimates WTI's coefficient in two disjoint blocks, compares
  recent with preceding state, owns one WTI position, and treats XNG as a
  read-only factor input.
- `QM5_20303_wti-volbeta-reg` estimates sensitivity to changes in rolling
  smooth realized volatility on non-jump days. This candidate estimates the
  coefficient on the extreme-day jump residual itself and has no rolling-
  volatility series or smooth-day count.
- `QM5_20295`, `QM5_20298`, `QM5_20300`, `QM5_20301`, and `QM5_20302` use
  kurtosis, volatility-of-volatility, MAX, expected shortfall, or activity-
  scaled absolute return, not a controlled common-jump regression.
- WTI trend, calendar, event, breakout, reversal, robust-location, and
  variance-ratio EAs use different information objects or clocks.
  `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG oscillator
  pullback.

The synchronized inputs, block-local inverse-volatility weights, fixed
two-sigma jump factor, intercept plus two-regressor OLS, offsets `0/252`,
source low-beta direction, one-leg WTI topology, and consumed monthly lifecycle
are jointly load-bearing. Verdict:
`CLEAN_AUTHORIZED_WTI_TIME_SERIES_COMMON_JUMP_BETA_AFTER_MANUAL_REVIEW`.

## Allocation And Kill Boundary

- intended EA ID: `QM5_20304`, subject to deterministic registry allocation;
- slug: `wti-jumpbeta-reg`;
- strategy ID: `HOLLSTEIN-AGGJUMP-2021_XTI_TS_S02`;
- intended symbol/slot/magic: `XTIUSD.DWX` / 0 / `203040000`;
- read-only signal symbol: `XNGUSD.DWX`, with no magic or order authority;
- expected cadence: approximately eleven to twelve completed monthly WTI
  positions per full post-warm-up year;
- retire below five completed positions per year, on nonpositive governed
  economics, or at later portfolio-correlation rejection; and
- fail on timestamp misalignment, wrong block support, pooled block weights,
  wrong deviation denominator, wrong jump factor, too few jump rows, singular
  OLS, reversed direction, retry, XNG order, missing stop, risk mismatch, hold
  beyond forty days, or nondeterminism.

The WTI carrier and common-energy jump sensitivity are diversification
hypotheses, not correlation evidence. Q09 alone may establish realized overlap
with the current XAU/SP500/NDX/XNG book.

## Safety Boundary

This authorization excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 uses
exactly one `XTIUSD.DWX` D1 setfile with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. If the paced factory reaches its binding backtest CPU
ceiling before enqueue, record the stop and do not enqueue or run a manual test.
