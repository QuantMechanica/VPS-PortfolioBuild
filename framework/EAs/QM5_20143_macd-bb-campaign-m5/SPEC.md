# QM5_20143_macd-bb-campaign-m5 - Strategy Spec

**EA ID:** QM5_20143
**Slug:** `macd-bb-campaign-m5`
**Source:** `BP-ELITEFXP-SCALP5M-1266726`
**Last revised:** 2026-09-10

---

## 1. Strategy Logic

On closed M5 bars, an EMA(6)/EMA(17) cross starts a directional campaign. The
EA then requires a close outside a Bollinger Band (period 10, plot shift 1,
deviation 0.66), a wick-contact pullback into that band, and a later close
beyond the tracked campaign extreme. It places a stop order one pip beyond the
confirming candle. Wick-only breaks replace the reference extreme; an opposite
EMA cross cancels an unfilled campaign, but does not close a filled position.
Only one order may fill per campaign.

The Method-1 baseline places the stop one pip beyond the confirming candle's
opposite extreme and the take profit at exactly 1R. Invalid risk or broker stop
geometry rejects the setup without chasing or widening.

## 2. Parameters

| Parameter | Default | Admissible value | Meaning |
|---|---:|---:|---|
| `strategy_fast_ema` | 6 | 6 | Fast EMA for the campaign cross. |
| `strategy_slow_ema` | 17 | 17 | Slow EMA for the campaign cross. |
| `strategy_bb_period` | 10 | 10 | Bollinger Band lookback. |
| `strategy_bb_shift` | 1 | 1 | Source-defined plot shift, verified causally at initialization. |
| `strategy_bb_dev` | 0.66 | 0.66 | Bollinger Band deviation. |
| `strategy_entry_offset_pips` | 1.0 | 1.0 | Stop-entry offset beyond the confirming candle. |
| `strategy_sl_offset_pips` | 1.0 | 1.0 | Stop-loss offset beyond the confirming candle. |
| `strategy_tp_r` | 1.0 | 1.0 | Method-1 take-profit multiple. |

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` - primary major-FX falsification cell.
- `GBPUSD.DWX` - sibling major-FX diversity cell.

**Explicitly not for:**

- Non-DWX broker symbols, because the governed test cohort is bound to local
  `.DWX` history and deterministic magic rows.
- Non-FX assets, which are outside the approved source cohort.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe references | none |
| Bar gating | strategy-owned forming-M5 timestamp guards; decisions use closed bars |
| Warmup | at least 40 bars for EMA and Bollinger handles |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 400 in the approved card; falsification queue uses a conservative 20/year prior |
| Typical hold time | intraday |
| Expected drawdown profile | clustered losses in choppy, cost-heavy M5 regimes |
| Regime preference | directional extension, pullback, then breakout continuation |
| Evidence expectation | weak candidate; source-thread critics reported poor live results |

## 6. Source Citation

Eliteforexpartner, "A Scalping/Day Trading strategy 5minute timeframe,"
BabyPips forum thread 1266726, 2024-12-14. The approved card records the primary
rules from post 1, the EMA-equivalence observation from post 2, and the adverse
live-result comments from posts 7-10. Build authority is the reconciled
`STR-104` final spec and the OWNER-approved Strategy Card for QM5_20143.

## 7. Risk Model

| Context | Model |
|---|---|
| Entry stop | confirming-candle opposite extreme plus one pip |
| Profit target | exactly 1R from fill to initial stop |
| Position concurrency | one position or pending order per magic |
| Campaign concurrency | one fill per campaign |
| Backtest risk | fixed monetary risk only |
| Live authority | none; this recovery does not authorize deployment or AutoTrading |
