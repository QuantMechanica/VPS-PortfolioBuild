# QM5_20302 WTI Self-Relative Illiquidity Regime G0 Authorization

Date: 2026-08-13

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded V5 Strategy Card and non-live build for
`QM5_20302_wti-aliq-regime`. At each genuine broker-month transition, the
candidate computes a transparent Amihud-style illiquidity proxy over two
consecutive, non-overlapping 252-return blocks of `XTIUSD.DWX` D1 history. It
buys WTI when the recent block is more illiquid than the preceding block and
sells WTI when it is less illiquid.

The candidate may proceed through bounded source/card extraction, schema and
G0 lint, deterministic registry and magic allocation, resolver regeneration,
strict compile, one `RISK_FIXED` backtest setfile, Q01 validation, and one
paced Q02 enqueue. Authorization does not pre-approve efficacy,
diversification, decorrelation, certification, execution-contract promotion,
or portfolio admission.

## Source Boundary

The approved source is Qin, Cai, Zhu, and Webb (2025), "Commodity Futures
Characteristics and Asset Pricing Models," *Journal of Futures Markets*
45(3), 176-207, DOI `10.1002/fut.22559`. The governed packet at
`strategy-seeds/sources/YIYI-ALIQ-2025/source.md`, SHA-256
`EB8D48BA2F04350634370358961686F24E7842AF09CBE30614FC001452558B85`, records
a complete read of the open prepublication paper, including appendices. It
defines ALIQ as the prior-year average of daily absolute return divided by
dollar volume, ranks commodities monthly, and holds the higher-ALIQ group
against the lower-ALIQ group during month t.

The source studies 34 exchange-traded commodity futures, not an outright WTI
continuous CFD or an own-history comparison. MT5 tick volume is an activity
proxy, not source dollar volume. The existing two-energy-CFD sibling
`QM5_13140_energy-aliq-rank` reached Q07 but failed Q08 hard because its runs
test p-value was `0.00226`; its 2024 Q02 row had 82 trades, PF 1.19, and net
profit 1,787.12 at fixed risk. Those results are material family evidence but
do not transfer to this carrier or waive any gate.

The two-block self-relative comparison, outright WTI direction, tick-volume
proxy, fixed-dollar sizing, ATR hard stop, spread ceiling, restart ledger, and
lifecycle controls are transparent QM mechanizations. The source does not test
any of them. No source or sibling return, alpha, significance, trade density,
CFD equivalence, correlation result, or portfolio conclusion transfers.

## Locked Rule

On the first processed WTI D1 bar after a genuine broker-month transition,
load exactly 505 completed `MqlRates` bars, newest first. For block offset
`b`, where `b=0` is recent and `b=252` is preceding, calculate exactly 252
same-bar activity-adjusted absolute log returns and average them:

```text
r[b,k]       = ln(close[b+k] / close[b+k+1]), k = 0..251
aliq[b,k]    = abs(r[b,k]) / tick_volume[b+k] * 1,000,000
ALIQ[b]      = arithmetic_mean(aliq[b,0..251])

recent block b=0:       close pairs 0/1 through 251/252; volumes 0..251
preceding block b=252:  close pairs 252/253 through 503/504; volumes 252..503

BUY  when ALIQ[0] > ALIQ[252] + 1e-12
SELL when ALIQ[0] < ALIQ[252] - 1e-12
FLAT otherwise or when state is invalid
```

The blocks share only boundary close index 252 and share no return or volume
observation. Require strictly decreasing series indices to map to strictly
older timestamps, positive finite closes, strictly positive tick volumes,
finite log returns and ALIQ terms, exactly 252 terms per block, and a newest
completed endpoint before the decision bar and no more than ten calendar days
stale.

Do not substitute simple returns, dollar or real volume, range, spread,
turnover, a rank percentile, a fitted threshold, block overlap, normalization,
a trend or calendar filter, score-sized risk, or an alternate direction.
Consume and persist the broker month before history, signal, spread, quote,
news, ATR, sizing, or order gates. Use one `RISK_FIXED=1000` WTI position with
a frozen `3.5 * ATR(20,D1)` hard stop, a 1,500-point entry-spread cap, and no
take-profit. Close before monthly replacement or after forty calendar days.
Friday close and both news axes are OFF. At most one registered WTI position
exists.

## Reputable-Source Criteria

- R1: PASS with translation caveats retained: named peer-reviewed source,
  DOI, publisher record, complete open-paper read, exact ALIQ transform and
  high-minus-low direction, plus sibling Q08 failure disclosed.
- R2: PASS: two fixed 252-return blocks, exact log-return/activity transform,
  offsets, direction, attempt ledger, risk, stop, rollover, and stale guard.
- R3: PASS with binding proxy risk: registered `XTIUSD.DWX` D1 OHLC and native
  tick volume suffice, but quote-tick counts are not source dollar volume.
- R4: PASS: deterministic native arithmetic only, without trained output,
  prohibited signal indicator, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,367 EA-registry rows and 478
root cards. It found no exact identity and surfaced two fuzzy neighbors.
Manual mechanic review resolves them:

- `QM5_13140_energy-aliq-rank` measures the same source proxy concurrently on
  XTI and XNG over the prior twelve completed calendar months, ranks the two
  instruments, opens opposite legs, and manages package risk and orphan state.
  This candidate compares two fixed WTI history blocks and owns one outright
  leg. Its Q08 failure is adverse evidence, not an identity or a reason to
  alter this baseline.
- `QM5_20301_wti-es-regime` shares the one-leg WTI, two-block, and monthly
  lifecycle architecture but uses simple returns, sorts the lower five-percent
  tail, and averages exactly thirteen tail observations. This candidate uses
  log returns, every observation, and same-day tick volume to estimate price
  impact per activity unit.
- WTI trend, calendar, event, breakout, reversal, variance-ratio, skewness,
  kurtosis, MAX, expected-shortfall, and volatility-of-volatility EAs use
  different information objects or clocks.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only oscillator
  pullback on the incumbent XNG carrier rather than a monthly symmetric WTI
  activity-price-impact regime.

The log return, same-bar tick-volume divisor, one-million scale, 252-term
arithmetic means, disjoint offsets `0/252`, source high-ALIQ-long direction,
outright WTI carrier, and consumed monthly lifecycle are jointly load-bearing.
Verdict: `CLEAN_AUTHORIZED_WTI_TIME_SERIES_ALIQ_AFTER_MANUAL_REVIEW`.

## Allocation And Kill Boundary

- intended EA ID: `QM5_20302`, subject to deterministic registry allocation;
- slug: `wti-aliq-regime`;
- strategy ID: `YIYI-ALIQ-2025_XTI_TS_S02`;
- intended symbol/slot/magic: `XTIUSD.DWX` / 0 / `203020000`;
- expected cadence: approximately eleven to twelve completed monthly WTI
  positions per full post-warm-up year;
- retire below five completed positions per year, on nonpositive governed
  economics, or at later portfolio-correlation rejection;
- fail on wrong block support, wrong return or volume alignment, a nonpositive
  volume, wrong scale, block overlap, reversed direction, retry, missing stop,
  risk mismatch, hold beyond forty days, or nondeterminism; and
- no post-result formation, offset, transform, scale, direction, stop, hold,
  spread, retry, or carrier rescue is authorized.

The WTI carrier and activity-price-impact state are diversification
hypotheses, not correlation evidence. Q09 alone may establish realized overlap
with the current XAU/SP500/NDX/XNG book.

## Safety Boundary

This authorization excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 uses
exactly one `XTIUSD.DWX` D1 setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. If the paced factory reaches its
binding seven-terminal backtest CPU ceiling before enqueue, record the stop
and do not enqueue or run a manual test.
