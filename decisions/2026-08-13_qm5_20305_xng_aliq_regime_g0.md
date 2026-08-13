# QM5_20305 XNG Self-Relative ALIQ Regime G0 Authorization

Date: 2026-08-13

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded V5 Strategy Card and non-live build for
`QM5_20305_xng-aliq-regime`. On the first processed natural-gas D1 bar after
a genuine broker-month transition, the candidate compares the source-defined
Amihud illiquidity proxy over two consecutive, non-overlapping 252-return
blocks. It buys XNG when recent illiquidity is higher than the preceding
block's value and sells XNG when it is lower.

This is a carrier extension of the governed ALIQ characteristic, not a rescue
or performance transfer from another EA. It may proceed through bounded
source/card extraction, schema and G0 lint, deterministic registry and magic
allocation, resolver regeneration, strict compile, one `RISK_FIXED` backtest
setfile, Q01 validation, and one paced Q02 enqueue. Authorization does not
pre-approve efficacy, diversification, decorrelation, certification,
execution-contract promotion, or portfolio admission.

## Source Boundary

The approved primary source is Qin, Cai, Zhu, and Webb (2025), "Commodity
Futures Characteristics and Asset Pricing Models," *Journal of Futures
Markets* 45(3), 176-207, DOI `10.1002/fut.22559`. The governed complete-read
packet at `strategy-seeds/sources/YIYI-ALIQ-2025/source.md`, SHA-256
`EB8D48BA2F04350634370358961686F24E7842AF09CBE30614FC001452558B85`,
records the open prepublication paper, exact ALIQ definition, broad-universe
high-minus-low direction, and all translation caveats.

The publisher URL was routed again on 2026-08-13 under the governed source-
reader policy and returned `DEFERRED:SOURCE_POLICY`; no new content was
inferred from that route. The durable complete-read parent packet remains the
source of record.

The paper defines ALIQ as the prior-year average of absolute daily return
divided by dollar volume, renews the characteristic monthly, and reports a
positive broad-universe high-minus-low result. It does not test XNG alone,
MT5 quote-tick counts, a two-block own-history comparison, a continuous CFD,
or the incumbent QM book. Those translations remain explicit hypotheses.

Material family evidence is mixed and must travel with the card:

- `QM5_13140_energy-aliq-rank` passed Q02 through Q07, then failed Q08 hard
  because the runs-test p-value was `0.00226`. Its Q08 baseline recorded 134
  trades, PF 1.44, and gross total 5,484.30 before recorded commission.
- `QM5_20302_wti-aliq-regime` passed Q02 on its governed 2018-2022 window with
  39 trades, PF 1.01, net profit 182.72, and drawdown 6,667.30.

Neither sibling result proves, disproves, rescues, or waives this XNG carrier.

## Locked Rule

On the first processed `XNGUSD.DWX` D1 bar after a genuine broker-month
transition, load exactly 505 completed rates, newest first. For block offset
`b`, calculate exactly 252 log returns and divide each absolute return by the
tick volume of its ending bar:

```text
r[b,k]       = ln(close[b+k] / close[b+k+1]), k = 0..251
aliq[b,k]    = abs(r[b,k]) / tick_volume[b+k] * 1,000,000
ALIQ[b]      = arithmetic_mean(aliq[b,0..251])

recent block:    b = 0
preceding block: b = 252
```

The blocks share only close index 252 and share no return or tick-volume
observation. Require positive finite closes, strictly positive used tick
volumes, finite terms, strictly older timestamps as series index increases,
exact counts, and a newest completed endpoint before the decision bar and no
more than ten calendar days stale.

```text
BUY  when ALIQ[0] > ALIQ[252] + 1e-12
SELL when ALIQ[0] < ALIQ[252] - 1e-12
FLAT otherwise or when either state is invalid
```

Do not substitute simple returns, dollar volume, price volume, volume change,
a percentile, a fitted scale, overlapping blocks, a trend/calendar/oscillator
filter, score-sized risk, or an alternate direction. Consume and persist the
broker month before history, signal, spread, quote, news, ATR, sizing, or
order gates.

Use one `RISK_FIXED=1000` XNG position with a frozen
`3.5 * ATR(20,D1)` broker hard stop, a 3,000-point entry-spread cap, and no
take-profit. Close before monthly replacement or after forty calendar days.
Friday close and both news axes are OFF. At most one registered XNG position
exists.

## Reputable-Source Criteria

- R1: PASS with translation and family-evidence caveats retained: named peer-
  reviewed Journal of Futures Markets source, DOI, complete-read record,
  exact ALIQ transform and direction, source correlation context, paired
  sibling Q08 failure, and WTI-carrier Q02 evidence.
- R2: PASS: exact two-block 252-term log-return/activity estimator, fixed
  one-million scale, offsets, source direction, attempt ledger, risk, stop,
  rollover, and stale guard.
- R3: PASS for the disclosed proxy: registered `XNGUSD.DWX` D1 closes and
  native tick volume suffice; MT5 quote-tick counts are not source dollar
  volume.
- R4: PASS: deterministic native arithmetic only, without trained output,
  prohibited signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,370 EA-registry rows and 481
root cards. It found no exact slug or strategy-ID identity and returned three
expected fuzzy neighbors. Manual mechanic review resolves them:

- `QM5_13140_energy-aliq-rank` estimates concurrent XTI and XNG ALIQ values
  over one trailing year, ranks the two carriers, opens two opposite legs,
  splits package risk, and repairs orphans. This candidate compares two
  disjoint XNG-only history blocks and owns one XNG position.
- `QM5_20302_wti-aliq-regime` uses the identical locked statistic and
  lifecycle on WTI. This predeclared carrier extension changes the traded
  return stream to natural gas and inherits no performance or correlation
  result; it is not a parameter variant.
- `QM5_12567_cum-rsi2-commodity`, the certified XNG sleeve, is a short-horizon
  long-only cumulative-RSI pullback. This candidate is indicator-free,
  monthly, symmetric long/short, and driven by a one-year activity-scaled
  return state.
- XNG skewness, kurtosis, volatility-of-volatility, seasonality, weekday,
  storage-event, trend, variance-ratio, and relative-value EAs use different
  information objects or clocks.

The XNG carrier, two exact block offsets, disjoint return/activity support,
log-return/tick-volume transform, fixed scale, high-ALIQ direction, and
consumed monthly lifecycle are jointly load-bearing. Verdict:
`CLEAN_AUTHORIZED_XNG_ALIQ_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Allocation And Kill Boundary

- intended EA ID: `QM5_20305`, subject to deterministic registry allocation;
- slug: `xng-aliq-regime`;
- strategy ID: `YIYI-ALIQ-2025_XNG_TS_S03`;
- intended symbol/slot/magic: `XNGUSD.DWX` / 0 / `203050000`;
- expected cadence: approximately eleven to twelve completed monthly XNG
  positions per full post-warm-up year;
- retire below five completed positions per year, on nonpositive governed
  economics, or at later portfolio-correlation rejection; and
- fail on wrong return type, wrong volume alignment or scale, nonpositive
  used tick volume, overlapping blocks, reversed direction, retry, missing
  stop, risk mismatch, hold beyond forty days, or nondeterminism.

The slow symmetric ALIQ state is structurally different from the incumbent
short-horizon long-only XNG pullback, but realized independence is unproven.
Q09 alone may establish overlap with the XAU/SP500/NDX/XNG book.

## Safety Boundary

This authorization excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 uses
exactly one `XNGUSD.DWX` D1 setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. If the paced factory reaches its
binding seven-terminal backtest CPU ceiling before enqueue, record the stop
and do not enqueue or run a manual test.
