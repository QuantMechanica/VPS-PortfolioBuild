# QM5_11408_robles-continuation-method-ema50-wpct-d1 — Strategy Spec

**EA ID:** QM5_11408
**Slug:** `robles-continuation-method-ema50-wpct-d1`
**Source:** `57e63f96-cb59-5968-8c30-e25af1f40c93` (Cecil Robles, "The Continuation Method", in "6 Simple Strategies for Trading Forex", TradingPub)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Trade in the direction of the D1 EMA50 trend after a pullback exhausts. The trend
is a STATE: long only while EMA50 is rising over the slope lookback
(`EMA50[1] > EMA50[1+slope_lookback]`), short only while it is falling. The single
trigger EVENT is a Williams %R pullback-and-resume: for longs, Williams %R(14) was
oversold on the bar before the signal (`WPR[2] <= -80`) and crossed back above -80
on the signal bar (`WPR[1] > -80`); shorts mirror this around the -20 level. Because
the trigger is one bar-to-bar cross it encodes both the dip and the recovery without
needing two events on the same bar. On the signal a stop order is placed beyond the
signal bar's extreme (`BUY_STOP at High[1] + buffer`, `SELL_STOP at Low[1] - buffer`)
and expires after `pending_expiry_bars` D1 bars; a new signal bar supersedes any
unfilled order. The initial stop is the nearest structural swing extreme before the
signal bar, capped at `sl_cap_pips`. Once price reaches `trail_trigger_rr`× the
initial risk in profit, the stop trails to the SMA5 once two consecutive closes
confirm on the profitable side of the SMA.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 50 | 30-100 | EMA period defining the trend state |
| `strategy_ema_slope_lookback` | 10 | 5-20 | Bars back used for the EMA slope test |
| `strategy_wpr_period` | 14 | 7-21 | Williams %R period |
| `strategy_wpr_os_level` | -80.0 | -90..-70 | Oversold level for the long resume trigger |
| `strategy_wpr_ob_level` | -20.0 | -30..-10 | Overbought level for the short resume trigger |
| `strategy_entry_buffer_pips` | 1 | 0-10 | Stop-order offset beyond the signal-bar extreme |
| `strategy_sl_structure_bars` | 10 | 5-30 | Swing-extreme lookback for the initial stop |
| `strategy_sl_cap_pips` | 100 | 30-300 | Cap on the structural stop distance |
| `strategy_pending_expiry_bars` | 1 | 1-5 | D1 bars a pending stop order stays live |
| `strategy_trail_trigger_rr` | 2.0 | 1.0-4.0 | R multiple in profit before trailing arms |
| `strategy_trail_sma_period` | 5 | 3-10 | SMA period for the trailing stop |
| `strategy_spread_pct_of_stop` | 25.0 | 5-50 | Block if spread exceeds this % of the stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid major; clean D1 trend/pullback behaviour, primary smoke symbol.
- `GBPUSD.DWX` — liquid major with strong D1 trends suited to continuation entries.
- `USDJPY.DWX` — trending major; Williams %R pullback timing applies cleanly.
- `AUDUSD.DWX` — commodity-linked major with persistent D1 swings.
- `USDCAD.DWX` — oil-correlated major; trends offer continuation opportunities.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the card scopes this to the FX D1 continuation basket only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~20` |
| Typical hold time | `days (D1 swing continuation)` |
| Expected drawdown profile | `moderate; structural stop capped at 100 pips, SMA5 trail caps give-back` |
| Regime preference | `trend (continuation after pullback)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `57e63f96-cb59-5968-8c30-e25af1f40c93`
**Source type:** `book`
**Pointer:** Cecil Robles, "The Continuation Method", in "6 Simple Strategies for Trading Forex" (TradingPub) — local PDF lineage per card frontmatter
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11408_robles-continuation-method-ema50-wpct-d1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | QM5_11408 Williams %R continuation |
