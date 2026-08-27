# QM5_41140_nzdjpy-carry-unwind-crisis-momentum - Strategy Spec

**EA ID:** QM5_41140

**Slug:** `nzdjpy-carry-unwind-crisis-momentum`

**Source ID:** `BRUNNERMEIER-NAGEL-PEDERSEN-CARRY-CRASH-2008`

**Last revised:** 2026-08-27

## 1. Strategy Logic

At each new `NZDJPY.DWX` D1 bar, the EA reads the immediately completed D1
bar from `AUDJPY.DWX`, `NZDJPY.DWX`, `CADJPY.DWX`, and `EURJPY.DWX`. It fails
closed unless all four completed bars have the exact same timestamp. The
equal-weight mean five-session simple return must be at most -1.0%.

The target's completed close must also be strictly below the lowest low of the
20 preceding completed D1 bars. Its current 10-session realized volatility
must be strictly above the median of the 60 preceding rolling 10-session
realized-volatility observations. A qualifying state opens one market short in
`NZDJPY.DWX`; the other three symbols are signal data only.

Realized volatility is the root mean square of completed daily log returns.
The current observation is excluded from the 60-observation baseline. Because
all windows have the same length, the RMS scale does not alter the ordering
against the median. "Prior 20" excludes the signal bar for both entry and exit.

## 2. Parameters

| Parameter | Baseline | Meaning |
|---|---:|---|
| `breadth_return_days` | 5 | completed-session return horizon |
| `breadth_threshold` | -0.010 | maximum equal-weight JPY-cross return |
| `breakout_lookback` | 20 | prior target range window |
| `vol_short_days` | 10 | realized-volatility window |
| `vol_baseline_days` | 60 | prior rolling-volatility sample count |
| `atr_period` | 14 | completed D1 ATR period |
| `hard_stop_atr` | 2.0 | frozen initial stop distance |
| `max_hold_bars` | 10 | completed D1 time stop |

No undeclared strategy parameter or adaptive state is present.

## 3. Symbol Universe

- Host/execution symbol: exact `NZDJPY.DWX`, D1, slot 0, magic `411400000`.
- Signal-only symbols: `AUDJPY.DWX`, `CADJPY.DWX`, and `EURJPY.DWX` plus the
  host series.
- Only the host magic is registered; auxiliary series cannot receive orders.
- Cross-series data is loaded only from completed D1 bars behind the framework
  new-bar gate.

## 4. Timeframe

- Literal signal and execution timeframe: completed broker D1 bars.
- Breadth horizon: five completed sessions ending at the shared signal time.
- Target volatility state: current 10-session window versus 60 preceding
  rolling 10-session windows.
- Entry range: signal close versus the preceding 20 completed bars.
- Exit range: latest completed close versus the midpoint of the preceding 20
  completed bars; the independent time stop is ten completed D1 bars.

The entry decision runs once behind `QM_IsNewBar(NZDJPY.DWX, PERIOD_D1)`.
Position integrity runs on every tick, while channel and bar-count exits are
bounded to one evaluation per newly completed target D1 bar.

## 5. Expected Behaviour

The card estimates roughly 100 opportunities per year before pipeline gates;
Q02 owns observed trade density and expectancy. This implementation tests a
crisis-continuation carrier on a forex cross absent from the surviving
index/metal/energy concentration. No decorrelation or certification claim is
made at build time.

## 6. Source Citation

Markus K. Brunnermeier, Stefan Nagel, and Lasse H. Pedersen (2009), "Carry
Trades and Currency Crashes," *NBER Macroeconomics Annual* 23, 313-347, DOI
`10.1086/593088`; working-paper landing page:
`https://www.nber.org/papers/w14473`.

The source motivates forced carry-unwind behavior. The four-cross breadth,
breakout, volatility, stop, and exit boundaries are disclosed QuantMechanica
hypotheses and do not import a source profitability claim.

## 7. Risk Model

Entries are short-only and require valid quote, trade, volume, tick-value,
contract-size, ATR, and swap metadata. A finite zero short-swap value is valid
for `.DWX`; the EA never requires a positive or nonzero swap.

The entry request carries a hard stop two completed D1 ATR(14) above the
current executable bid. Framework risk sizing uses `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1` in the Q02 baseline. The stop is
never trailed, widened, or removed.

The position closes after ten completed D1 bars or when a completed target
close is strictly above the midpoint of the preceding 20-bar high/low channel.
The framework kill switch, account controls, and broker stop remain
authoritative. Position integrity and exits run before the entry-only news
gate. Friday close is disabled because it is not a card exit.

This is a Q01 build and Q02 research handoff only. It creates no live, demo,
shadow, optimization, stress, or portfolio authorization. It does not touch
AutoTrading, `T_Live`, a deploy manifest, or the portfolio gate. There is no
ML, banned indicator, averaging, grid, martingale, scale-in, pyramid,
break-even move, partial exit, or discretionary input.

## Revision history

| Version | Date | Reason |
|---|---|---|
| v1-build | 2026-08-27 | deterministic implementation from OWNER-approved G0 card |
